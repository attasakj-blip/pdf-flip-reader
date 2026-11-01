import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ambient.dart';
import 'book_painter.dart';
import 'desktop.dart';
import 'edge_menu.dart';
import 'edit_tools.dart';
import 'flip_sounds.dart';
import 'goto_dialog.dart';
import 'l10n.dart';
import 'markup.dart';
import 'native_files.dart';
import 'ocr.dart';
import 'ocr_dialog.dart';
import 'page_cache.dart';
import 'page_clipboard.dart';
import 'page_scroller.dart';
import 'pdf_edit.dart';
import 'save_flow.dart';
import 'settings.dart';
import 'sound_settings.dart';
import 'strings.g.dart' show languageNames;
import 'translate_flow.dart';
import 'translator.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, required this.settings, required this.sounds});

  final RecentBook book;
  final Settings settings;
  final FlipSounds sounds;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _Tool { none, sign, area, translate, markup, ocr }

/// One edit that can be undone: the working copy after it, what it was
/// (shown in the undo list), the page to go back to and when it happened.
typedef _Step = ({String path, String label, String suffix, int page, bool translated, DateTime at});

enum _Gesture { none, turn, pan, zoom }

class _ReaderScreenState extends State<ReaderScreen> with TickerProviderStateMixin {
  /// The book on screen; saving an edit as a new file switches to it.
  late RecentBook _book = widget.book;

  /// Edits not saved yet: one copy of the book per step, newest last, so
  /// each step can be undone. Saving writes the newest out.
  final _history = <_Step>[];
  static const _maxUndo = 25;
  String? get _working => _history.isEmpty ? null : _history.last.path;
  String? get _editSuffix => _history.isEmpty
      ? null
      : _history.length == 1
      ? _history.first.suffix
      : 'edited';

  /// Showing the book as it was before the first translation (view only).
  bool _showOriginal = false;

  /// The copy from just before the first translation step, if any.
  String? get _beforeTranslation {
    final i = _history.indexWhere((h) => h.translated);
    if (i < 0) return null;
    return i == 0 ? _book.localPath : _history[i - 1].path;
  }

  String get _path => (_showOriginal ? _beforeTranslation : null) ?? _working ?? _book.localPath;
  PageCache? _cache;
  MirroredPages? _mirrored;
  bool _loading = true;

  Settings get _settings => widget.settings;
  bool get _twoPage => _settings.twoPage;
  bool get _coverAlone => _settings.coverAlone;

  /// Right-to-left books are drawn as a mirror image of a normal book (with
  /// mirrored pages, so the content still reads correctly).
  bool _rtl = false;
  List<Spread> _spreads = const [];
  int _index = 0;

  bool _controlsVisible = true;
  _Tool _tool = _Tool.none;
  final _marks = <Mark>[];
  Signature? _signature;
  Size _bookSize = Size.zero;

  // Pinch zoom. The book is drawn scaled by [_zoom] and moved by [_pan]
  // (in the book's own coordinates, which are mirrored for right-to-left).
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _renderZoom = 1;
  _Gesture _gesture = _Gesture.none;
  bool _waitForLift = false; // a finger left over from a pinch
  double _zoomAtStart = 1;
  Offset _panAtStart = Offset.zero;
  Offset _focalAtStart = Offset.zero;
  // The scale recognizer reports velocity in screen coordinates; page turns
  // need it in the (possibly mirrored or rotated) book's own.
  VelocityTracker? _velocity;
  final _clock = Stopwatch()..start();
  late final AmbientPlayer _ambient = AmbientPlayer(_settings);
  final _focus = FocusNode();

  // Page-turn state.
  BookLayout? _layout;
  FlipState? _flip;
  int _dragDir = 0; // -1 forward (finger moves left), +1 backward
  bool _bottom = true;
  Offset _dragStart = Offset.zero;
  Offset _dragLast = Offset.zero;
  Offset _cornerStart = Offset.zero;
  late final AnimationController _anim;
  Offset _animFrom = Offset.zero;
  Offset _animTo = Offset.zero;
  VoidCallback? _onAnimDone;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(_tickAnim)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finishAnim();
      });
    _edge = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    NativeFiles.edgeSwipes(true);
    _load();
    _ambient.start();
  }

  @override
  void dispose() {
    _anim.dispose();
    _edge.dispose();
    NativeFiles.edgeSwipes(false);
    _focus.dispose();
    _ambient.dispose();
    _dropHistory();
    _mirrored?.dispose();
    _cache?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------------------------------------------------------------- file ---

  Future<void> _load({int? keepPage}) async {
    try {
      final doc = await PdfDocument.openFile(_path);
      final cache = PageCache(doc);
      await cache.init();
      if (!mounted) {
        cache.dispose();
        return;
      }
      setState(() {
        _cache = cache;
        _mirrored = MirroredPages(cache);
        _rtl = _book.rtl ?? Directionality.of(context) == TextDirection.rtl;
        _rebuildSpreads(keepPage: (keepPage ?? _book.lastPage).clamp(0, cache.pageCount - 1));
      });
      WakelockPlus.enable();
      if (!_settings.zoomTipShown && mounted) {
        _settings.zoomTipShown = true;
        _toast(S.of(context).zoomHint);
      } else if (!_settings.edgeTipShown && mounted) {
        _settings.edgeTipShown = true;
        _toast(S.of(context).edgeTip);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).openFailed(e))));
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Remembers where the reader is, so the book reopens at the same page.
  void _saveProgress() {
    if (_spreads.isEmpty) return;
    _book.lastPage = _firstVisiblePage;
    final list = _settings.recents;
    for (final b in list) {
      if (b.localPath == _book.localPath) b.lastPage = _firstVisiblePage;
    }
    _settings.saveRecents(list);
  }

  // ------------------------------------------------------------- spreads ---

  void _rebuildSpreads({required int keepPage}) {
    final n = _cache?.pageCount ?? 0;
    final list = <Spread>[];
    if (!_twoPage) {
      for (var i = 0; i < n; i++) {
        list.add(Spread(null, i));
      }
    } else {
      var i = 0;
      if (_coverAlone && n > 0) {
        list.add(const Spread(null, 0));
        i = 1;
      }
      for (; i < n; i += 2) {
        list.add(Spread(i, i + 1 < n ? i + 1 : null));
      }
    }
    _spreads = list;
    _index = _spreadOf(keepPage);
    _prefetch();
  }

  int _spreadOf(int page) {
    for (var i = 0; i < _spreads.length; i++) {
      if (_spreads[i].pages.contains(page)) return i;
    }
    return 0;
  }

  int get _firstVisiblePage => _spreads.isEmpty ? 0 : _spreads[_index].pages.first;

  void _prefetch() {
    final c = _cache;
    if (c == null || _spreads.isEmpty) return;
    final order = <int?>[];
    for (final d in [0, 1, -1, 2, -2]) {
      final i = _index + d;
      if (i >= 0 && i < _spreads.length) order.addAll([_spreads[i].left, _spreads[i].right]);
    }
    c.request(order);
  }

  void _setMode({bool? twoPage, bool? coverAlone}) {
    if (_flip != null) return;
    final keep = _firstVisiblePage;
    if (twoPage != null) _settings.twoPage = twoPage;
    if (coverAlone != null) _settings.coverAlone = coverAlone;
    setState(() => _rebuildSpreads(keepPage: keep));
  }

  void _setRtl(bool v) {
    if (_flip != null) return;
    setState(() => _rtl = v);
    _book.rtl = v;
    final list = _settings.recents;
    for (final b in list) {
      if (b.localPath == _book.localPath) b.rtl = v;
    }
    _settings.saveRecents(list);
  }

  void _goToPage(int page) {
    _anim.stop();
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
      _flip = null;
      _index = _spreadOf(page);
    });
    _prefetch();
    _saveProgress();
  }

  bool get _hasNext => _index < _spreads.length - 1;
  bool get _hasPrev => _index > 0;

  // ---------------------------------------------------------- page turns ---

  /// How far the corner moves per pixel of finger travel. A full turn moves
  /// the corner two page widths; let a swipe across the screen do that.
  double _dragScale(BookLayout l, double screenWidth) =>
      math.max(1.0, (2 * l.pageWidth) / math.max(1.0, screenWidth * 0.9));

  void _onDragStart(Offset pos) {
    if (_anim.isAnimating || _layout == null) return;
    _dragDir = 0;
    _dragStart = pos;
    _bottom = pos.dy > _layout!.right.center.dy;
  }

  void _onDragUpdate(Offset pos, double screenWidth) {
    final l = _layout;
    if (l == null || _anim.isAnimating) return;
    if (_dragDir == 0) {
      final dx = pos.dx - _dragStart.dx;
      if (dx < -2 && _hasNext) {
        _dragDir = -1;
        _cornerStart = l.corner(_bottom);
      } else if (dx > 2 && _hasPrev) {
        _dragDir = 1;
        _cornerStart = l.turnedCorner(_bottom);
      } else {
        return;
      }
    }
    if (!_settings.flipAnimation) {
      _dragLast = pos;
      return;
    }
    final k = _dragScale(l, screenWidth);
    final p = l.clampCorner(_cornerStart + (pos - _dragStart) * k, _bottom);
    setState(() => _flip = _flipWith(p));
  }

  FlipState _flipWith(Offset corner) {
    final forward = _dragDir < 0;
    final from = forward ? _spreads[_index] : _spreads[_index - 1];
    final to = forward ? _spreads[_index + 1] : _spreads[_index];
    return FlipState(from: from, to: to, corner: corner, bottom: _bottom);
  }

  void _onDragEnd(Velocity velocity) {
    if (!_settings.flipAnimation && _flip == null) {
      // No page curl: a swipe just shows the next or previous page.
      final dir = _dragDir;
      _dragDir = 0;
      if (dir == 0) return;
      final dx = _dragLast.dx - _dragStart.dx, vx = velocity.pixelsPerSecond.dx;
      final complete = dir < 0 ? (dx < -40 || vx < -250) : (dx > 40 || vx > 250);
      if (complete) _jump(dir < 0);
      return;
    }
    final l = _layout;
    final f = _flip;
    if (l == null || f == null || _dragDir == 0) {
      _dragDir = 0;
      return;
    }
    final vx = velocity.pixelsPerSecond.dx; // in book space, like positions
    final pastSpine = f.corner.dx < l.spineX;
    if (_dragDir < 0) {
      final complete = vx < -250 || (pastSpine && vx < 400);
      if (complete) widget.sounds.playTurn();
      _animateCorner(complete ? l.turnedCorner(_bottom) : l.corner(_bottom), () {
        if (complete) _index++;
      });
    } else {
      final complete = vx > 250 || (!pastSpine && vx > -400);
      if (complete) widget.sounds.playTurn();
      _animateCorner(complete ? l.corner(_bottom) : l.turnedCorner(_bottom), () {
        if (complete) _index--;
      });
    }
  }

  // ---------------------------------------------------------- edge menus ---

  late final AnimationController _edge;
  // Which edge menu is out: true left, false right, null none.
  bool? _edgeLeft;

  bool get _edgeAllowed => _tool == _Tool.none && _cache != null && !_loading;

  void _edgeDragStart(bool left) {
    if (!_edgeAllowed || _flip != null) return;
    setState(() => _edgeLeft = left);
    _edge.value = 0;
  }

  void _edgeDragUpdate(bool left, DragUpdateDetails d) {
    if (_edgeLeft != left) return;
    _edge.value += (left ? d.delta.dx : -d.delta.dx) / EdgeMenu.panelWidth(MediaQuery.sizeOf(context));
  }

  void _edgeDragEnd(bool left, DragEndDetails d) {
    if (_edgeLeft != left) return;
    final v = (left ? 1 : -1) * d.velocity.pixelsPerSecond.dx;
    if (v > 300 || (v > -300 && _edge.value > 0.35)) {
      _edge.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _closeEdge();
    }
  }

  void _openEdge(bool left) {
    if (!_edgeAllowed) return;
    setState(() => _edgeLeft = left);
    _edge.animateTo(1, curve: Curves.easeOutCubic);
  }

  Future<void> _closeEdge() async {
    await _edge.animateTo(0, curve: Curves.easeInCubic, duration: const Duration(milliseconds: 200));
    if (mounted) setState(() => _edgeLeft = null);
  }

  /// Closes the menu, then runs [action].
  void Function() _fromEdge(void Function() action) => () {
    _closeEdge();
    action();
  };

  // The middle half of each side edge; the bars' buttons sit above and
  // below it.
  Widget _edgeStrip(bool left) => Positioned(
    top: MediaQuery.sizeOf(context).height * 0.25,
    bottom: MediaQuery.sizeOf(context).height * 0.25,
    left: left ? 0 : null,
    right: left ? null : 0,
    width: 24,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEdge(left),
      onHorizontalDragStart: (_) => _edgeDragStart(left),
      onHorizontalDragUpdate: (d) => _edgeDragUpdate(left, d),
      onHorizontalDragEnd: (d) => _edgeDragEnd(left, d),
      child: EdgeHandle(left: left, visible: _controlsVisible),
    ),
  );

  /// The edit tools (left) or the translate and view tools (right). Phones
  /// show them in the edge menus; Windows shows them as icon rails.
  List<EdgeMenuItem> _edgeItems(bool left) {
    final s = S.of(context);
    if (left) {
      return [
        EdgeMenuItem(icon: Icons.draw, label: s.signDocument, onTap: _fromEdge(_startSigning)),
        EdgeMenuItem(
          icon: Icons.format_color_text,
          label: s.markup,
          onTap: _fromEdge(() {
            if (_editAllowed()) setState(() => _tool = _Tool.markup);
          }),
        ),
        EdgeMenuItem(icon: Icons.copy, label: s.copyPage, onTap: _fromEdge(_copyPage)),
        EdgeMenuItem(
          icon: Icons.crop,
          label: s.copyAreaImage,
          onTap: _fromEdge(() => setState(() => _tool = _Tool.area)),
        ),
        EdgeMenuItem(icon: Icons.delete_outline, label: s.deletePages, onTap: _fromEdge(_askDelete)),
        if (_history.isNotEmpty)
          EdgeMenuItem(icon: Icons.history, label: s.undoChanges, onTap: _fromEdge(_showUndoList)),
      ];
    }
    return [
      EdgeMenuItem(
        icon: Icons.translate,
        label: s.translateArea,
        onTap: _fromEdge(() => setState(() => _tool = _Tool.translate)),
      ),
      // Windows has no translator on the computer, so whole-document
      // translation is left out there ("Translate text" stays).
      if (DocTranslator.inApp)
        EdgeMenuItem(
          icon: Icons.g_translate,
          label: s.translateDoc.replaceAll('…', ''),
          onTap: _fromEdge(_translateDoc),
        ),
      EdgeMenuItem(
        icon: Icons.document_scanner,
        label: s.ocrArea,
        onTap: _fromEdge(() => setState(() => _tool = _Tool.ocr)),
      ),
      if (_beforeTranslation != null)
        EdgeMenuItem(icon: Icons.compare, label: s.showOriginal, on: _showOriginal, onTap: _fromEdge(_toggleOriginal)),
      EdgeMenuItem(
        icon: Icons.auto_stories_outlined,
        label: s.flipEffect,
        on: _settings.flipAnimation,
        onTap: _fromEdge(_chooseFlipStyle),
      ),
      EdgeMenuItem(
        icon: Icons.auto_stories,
        label: s.coverAlone,
        on: _coverAlone,
        enabled: _twoPage,
        onTap: () => _setMode(coverAlone: !_coverAlone),
      ),
      EdgeMenuItem(icon: Icons.swap_horiz, label: s.rtlPages, on: _rtl, onTap: () => _setRtl(!_rtl)),
      EdgeMenuItem(
        icon: Icons.dark_mode,
        label: s.nightMode,
        on: _settings.nightMode,
        onTap: () => setState(() => _settings.nightMode = !_settings.nightMode),
      ),
    ];
  }

  Widget _edgeMenu(bool left) {
    final s = S.of(context);
    return Positioned.fill(
      child: EdgeMenu(
        left: left,
        progress: _edge,
        title: left ? s.edgeEditTitle : s.edgeViewTitle,
        icon: left ? Icons.edit_document : Icons.auto_awesome,
        onClose: _closeEdge,
        items: _edgeItems(left),
      ),
    );
  }

  /// Windows: the edge menus' tools as a column of icons down each side.
  static const _railWidth = 60.0;
  bool get _rails => Desktop.active;

  Widget _rail(bool left) => Positioned(
    top: 0,
    bottom: 0,
    left: left ? 0 : null,
    right: left ? null : 0,
    width: _railWidth,
    child: EdgeRail(left: left, items: _edgeItems(left)),
  );

  // ---------------------------------------------------------------- zoom ---

  static const _maxZoom = 5.0;

  void _onScaleStart(ScaleStartDetails d) {
    _zoomAtStart = _zoom;
    _panAtStart = _pan;
    _focalAtStart = d.localFocalPoint;
    if (d.pointerCount >= 2) {
      _gesture = _flip == null ? _Gesture.zoom : _Gesture.none;
    } else if (_waitForLift) {
      _gesture = _Gesture.none;
    } else if (_zoom > 1) {
      _gesture = _Gesture.pan;
    } else {
      _gesture = _Gesture.turn;
      _velocity = VelocityTracker.withKind(PointerDeviceKind.touch)
        ..addPosition(d.sourceTimeStamp ?? _clock.elapsed, d.localFocalPoint);
      _onDragStart(d.localFocalPoint);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    switch (_gesture) {
      case _Gesture.turn:
        _velocity?.addPosition(d.sourceTimeStamp ?? _clock.elapsed, d.localFocalPoint);
        _onDragUpdate(d.localFocalPoint, size.width);
      case _Gesture.pan:
        setState(() => _pan = _clampPan(_panAtStart + d.localFocalPoint - _focalAtStart, _zoom, size));
      case _Gesture.zoom:
        final z = (_zoomAtStart * d.scale).clamp(1.0, _maxZoom);
        // Keep the spot under the fingers under the fingers.
        final anchor = (_focalAtStart - _panAtStart) / _zoomAtStart;
        setState(() {
          _zoom = z;
          _pan = _clampPan(d.localFocalPoint - anchor * z, z, size);
        });
      case _Gesture.none:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final g = _gesture;
    _gesture = _Gesture.none;
    _waitForLift = d.pointerCount > 0 && (g == _Gesture.zoom || _waitForLift);
    if (g == _Gesture.turn) {
      _onDragEnd(_velocity?.getVelocity() ?? Velocity.zero);
      _velocity = null;
    } else if (g == _Gesture.zoom) {
      if (_zoom < 1.05) {
        _resetZoom();
      } else {
        setState(() => _renderZoom = math.min(_zoom, 2.5));
      }
    }
  }

  /// Keeps the zoomed book covering the screen.
  Offset _clampPan(Offset p, double z, Size size) =>
      Offset(p.dx.clamp(size.width * (1 - z), 0.0), p.dy.clamp(size.height * (1 - z), 0.0));

  void _resetZoom() => setState(() {
    _zoom = 1;
    _pan = Offset.zero;
    _renderZoom = 1;
  });

  void _animateCorner(Offset target, VoidCallback onDone) {
    final l = _layout!;
    _animFrom = _flip!.corner;
    _animTo = target;
    _onAnimDone = onDone;
    final dist = (_animTo - _animFrom).distance / (2 * l.pageWidth);
    _anim.duration = Duration(milliseconds: (120 + 480 * dist).round());
    _anim.forward(from: 0);
  }

  void _tickAnim() {
    final l = _layout;
    if (l == null || _flip == null) return;
    final t = Curves.easeOutCubic.transform(_anim.value);
    var p = Offset.lerp(_animFrom, _animTo, t)!;
    // Lift the corner slightly in an arc, as a hand would.
    final lift = math.sin(math.pi * t) * l.right.height * 0.06 * (_bottom ? -1 : 1);
    p = l.clampCorner(p + Offset(0, lift), _bottom);
    setState(() => _flip = FlipState(from: _flip!.from, to: _flip!.to, corner: p, bottom: _bottom));
  }

  void _finishAnim() {
    setState(() {
      _onAnimDone?.call();
      _onAnimDone = null;
      _flip = null;
      _dragDir = 0;
    });
    _prefetch();
    _saveProgress();
  }

  /// Shows the next or previous page straight away, without the curl.
  void _jump(bool forward) {
    if (forward ? !_hasNext : !_hasPrev) return;
    widget.sounds.playTurn();
    setState(() => _index += forward ? 1 : -1);
    _prefetch();
    _saveProgress();
  }

  /// Lets the reader pick how pages turn, or turn the animation off.
  Future<void> _chooseFlipStyle() async {
    final s = S.of(context);
    final names = [
      s.flipCurl,
      s.flipFold,
      s.flipSlide,
      s.flipFade,
      s.flipHinge,
      s.flipCover,
      s.flipUncover,
      s.flipZoom,
    ];
    final current = _settings.flipAnimation ? _settings.flipStyle : -1;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.flipEffect),
        children: [
          for (var i = -1; i < names.length; i++)
            ListTile(
              leading: Icon(i == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(i < 0 ? s.flipNone : names[i]),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _settings.flipAnimation = picked >= 0;
      if (picked >= 0) _settings.flipStyle = picked;
    });
  }

  /// Animated turn for buttons, keyboard and presentation clickers.
  void _turn(bool forward) {
    if (_zoom > 1) _resetZoom();
    final l = _layout;
    if (l == null || _anim.isAnimating || _flip != null) return;
    if (forward ? !_hasNext : !_hasPrev) return;
    if (!_settings.flipAnimation) {
      _jump(forward);
      return;
    }
    _bottom = true;
    _dragDir = forward ? -1 : 1;
    final start = forward ? l.corner(true) : l.turnedCorner(true);
    setState(() => _flip = _flipWith(start));
    widget.sounds.playTurn();
    _animateCorner(forward ? l.turnedCorner(true) : l.corner(true), () {
      _index += forward ? 1 : -1;
    });
  }

  DateTime _lastWheel = DateTime(2000);

  /// Mouse wheel (Windows): one page per notch, unless zoomed in.
  void _onWheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || _zoom != 1 || _tool != _Tool.none || !_idle) return;
    if (HardwareKeyboard.instance.isControlPressed) return;
    final dy = e.scrollDelta.dy;
    if (dy.abs() < 1) return;
    final now = DateTime.now();
    if (now.difference(_lastWheel) < const Duration(milliseconds: 300)) return;
    _lastWheel = now;
    _turn(dy > 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final nextArrow = _rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final prevArrow = _rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    if (k == nextArrow ||
        k == LogicalKeyboardKey.pageDown ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowDown) {
      _turn(true);
      return KeyEventResult.handled;
    }
    if (k == prevArrow || k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.arrowUp) {
      _turn(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------- editing ---

  /// Visible pages and where they are on screen. Right-to-left books are
  /// drawn mirrored, so their page slots swap sides.
  List<PageSlot> get _slots {
    final l = _layout;
    if (l == null || _spreads.isEmpty) return const [];
    final spread = _spreads[_index];
    final w = _bookSize.width;
    Rect place(Rect r) => _rtl ? Rect.fromLTRB(w - r.right, r.top, w - r.left, r.bottom) : r;
    return [
      if (spread.left != null) (page: spread.left!, rect: place(l.left)),
      if (spread.right != null) (page: spread.right!, rect: place(l.right)),
    ]..sort((a, b) => a.rect.left.compareTo(b.rect.left));
  }

  /// [_slots] as they appear with the current zoom.
  List<PageSlot> get _zoomedSlots {
    final z = _zoom, sp = _screenPan;
    return [
      for (final s in _slots)
        (
          page: s.page,
          rect: Rect.fromLTWH(s.rect.left * z + sp.dx, s.rect.top * z + sp.dy, s.rect.width * z, s.rect.height * z),
        ),
    ];
  }

  /// The zoom offset in screen space ([_pan] is in the book's own, mirrored
  /// for right-to-left books).
  Offset get _screenPan => _rtl ? Offset(_bookSize.width * (1 - _zoom) - _pan.dx, _pan.dy) : _pan;

  void _setScreenZoom(double z, Offset screenPan) {
    final p = _rtl ? Offset(_bookSize.width * (1 - z) - screenPan.dx, screenPan.dy) : screenPan;
    setState(() {
      _zoom = z;
      _pan = _clampPan(p, z, _bookSize);
    });
  }

  Future<void> _saveMarks() async {
    final aspects = {for (final s in _slots) s.page: s.rect.height / s.rect.width};
    final marks = List<Mark>.of(_marks);
    setState(() {
      _tool = _Tool.none;
      _marks.clear();
    });
    await _runEdit(
      keepPage: marks.first.page,
      suffix: 'marked',
      label: S.of(context).stepMarkup(_pageList(marks.map((m) => m.page))),
      edit: (dest) async => PdfEditor.stampAll(_path, dest, await markStamps(marks, aspects)),
    );
  }

  bool get _idle => _flip == null && !_anim.isAnimating && !_loading && _cache != null;

  /// Edits are made on the newest copy: not while the original is shown.
  bool _editAllowed() {
    if (!_idle) return false;
    if (_showOriginal) {
      _toast(S.of(context).backToTranslationFirst);
      return false;
    }
    return true;
  }

  /// Page numbers for the undo list: "3", "3, 4" or "3, 4, 5…".
  static String _pageList(Iterable<int> pages) {
    final list = (pages.toSet().toList()..sort()).map((p) => '${p + 1}').toList();
    return list.length > 3 ? '${list.take(3).join(', ')}…' : list.join(', ');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  Future<String> _scratchPdf() async {
    final tmp = (await getTemporaryDirectory()).path;
    PdfEditor.cacheDir ??= tmp;
    return '$tmp/edit_${DateTime.now().microsecondsSinceEpoch}.pdf';
  }

  Future<void> _startSigning() async {
    if (!_editAllowed()) return;
    final sig = await showSignaturePad(
      context,
      color: Color(_settings.signColor),
      width: _settings.signWidth,
      onStyle: (c, w) {
        _settings.signColor = c.toARGB32();
        _settings.signWidth = w;
      },
    );
    if (sig == null || !mounted) return;
    setState(() {
      _signature = sig;
      _tool = _Tool.sign;
    });
  }

  Future<void> _placeSignature(PageSlot slot, Rect box) async {
    final sig = _signature!;
    setState(() {
      _tool = _Tool.none;
      _signature = null;
    });
    await _runEdit(
      keepPage: slot.page,
      suffix: 'signed',
      label: S.of(context).stepSign(_pageList([slot.page])),
      edit: (dest) async {
        // Roughly 300 dpi for the signature image on a typical page.
        final px = (box.width / slot.rect.width * 2400).clamp(120, 1800).round();
        final img = await sig.toRgba(px);
        await PdfEditor.stamp(_path, dest, slot.page, img.rgba, img.w, img.h, pageRectOf(slot, box));
      },
    );
  }

  Future<void> _askDelete() async {
    if (!_editAllowed()) return;
    _resetZoom();
    final s = S.of(context);
    final pages = _slots.map((e) => e.page).toList();
    final total = _cache!.pageCount;
    List<int>? chosen;
    if (pages.length == 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.deleteTitle),
          content: Text(s.deleteThisPage(pages.first + 1)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
          ],
        ),
      );
      if (ok == true) chosen = pages;
    } else {
      chosen = await showDialog<List<int>>(
        context: context,
        builder: (_) => _DeletePagesDialog(pages: pages),
      );
    }
    if (chosen == null || chosen.isEmpty || !mounted) return;
    if (chosen.length >= total) {
      _toast(s.keepOnePage);
      return;
    }
    final first = chosen.reduce(math.min);
    final del = chosen;
    await _runEdit(
      keepPage: math.min(first, total - del.length - 1),
      suffix: 'edited',
      label: s.stepDelete(_pageList(del)),
      edit: (dest) => PdfEditor.deletePages(_path, dest, del),
    );
  }

  /// Makes an edited copy with [edit], asks how to save it and shows the
  /// result. The original stays as it was if anything fails or the user
  /// backs out.
  Future<void> _runEdit({
    required int keepPage,
    required String suffix,
    required String label,
    required Future<void> Function(String dest) edit,
    bool translated = false,
  }) async {
    final dest = await _scratchPdf();
    setState(() => _loading = true);
    try {
      await edit(dest);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _toast(S.of(context).saveFailed(e));
      }
      File(dest).delete().ignore();
      return;
    }
    if (!mounted) {
      File(dest).delete().ignore();
      return;
    }
    _history.add((
      path: dest,
      label: label,
      suffix: suffix,
      page: keepPage,
      translated: translated,
      at: DateTime.now(),
    ));
    if (_history.length > _maxUndo) File(_history.removeAt(0).path).delete().ignore();
    _showOriginal = false;
    await _reload(keepPage);
  }

  /// Deletes every unsaved step's copy.
  void _dropHistory() {
    for (final h in _history) {
      File(h.path).delete().ignore();
    }
    _history.clear();
    _showOriginal = false;
  }

  /// Undoes the steps from [from] (index in [_history]) to the newest.
  Future<void> _undoFrom(int from) async {
    if (!_idle || from < 0 || from >= _history.length) return;
    final removed = _history.sublist(from);
    _history.removeRange(from, _history.length);
    if (_beforeTranslation == null) _showOriginal = false;
    await _reload(removed.first.page);
    for (final h in removed) {
      File(h.path).delete().ignore();
    }
    if (mounted) _toast(S.of(context).undoneSteps(removed.length));
  }

  /// The list of steps: pick how far back to go.
  Future<void> _showUndoList() async {
    if (!_idle || _history.isEmpty) return;
    final from = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UndoSheet(steps: _history.map((h) => (label: h.label, at: h.at)).toList()),
    );
    if (from != null) await _undoFrom(from);
  }

  Future<void> _toggleOriginal() async {
    if (!_idle || _beforeTranslation == null) return;
    _showOriginal = !_showOriginal;
    await _reload(_firstVisiblePage);
  }

  Future<void> _reload(int keepPage) async {
    _anim.stop();
    setState(() {
      _loading = true;
      _flip = null;
      _book.lastPage = keepPage;
      _mirrored?.dispose();
      _cache?.dispose();
      _mirrored = null;
      _cache = null;
    });
    await _load(keepPage: keepPage);
    _saveProgress();
  }

  /// Asks where to save the edits; true once they are saved.
  Future<bool> _saveWorking() async {
    final working = _working;
    if (working == null) return true;
    final saved = await saveEdited(context, _settings, _book, working, suffix: _editSuffix ?? 'edited');
    if (saved == null || !mounted) return false;
    final old = _book;
    final keep = _firstVisiblePage;
    _book = saved.book;
    _dropHistory();
    await _reload(keep);
    if (saved.replaced && old.localPath != saved.book.localPath) File(old.localPath).delete().ignore();
    return true;
  }

  /// Before leaving the book: offers to save unsaved edits. False means stay.
  Future<bool> _confirmLeave() async {
    if (_working == null) return true;
    final s = S.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.unsavedTitle),
        content: Text(s.unsavedBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(s.discardChanges)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(s.saveChanges)),
        ],
      ),
    );
    if (choice == 'save') return _saveWorking();
    if (choice == 'discard') {
      setState(_dropHistory);
      return true;
    }
    return false;
  }

  Future<void> _leave() async {
    if (!await _confirmLeave() || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _copyPage() async {
    if (!_idle) return;
    _resetZoom();
    final s = S.of(context);
    final pages = _slots.map((e) => e.page).toList();
    var page = pages.first;
    if (pages.length > 1) {
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(s.whichPage),
          children: [
            for (final p in pages)
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, p), child: Text(s.pageN(p + 1))),
          ],
        ),
      );
      if (picked == null) return;
      page = picked;
    }
    await _copy(() => PageClipboard(_cache!).pagePng(page));
  }

  Future<void> _copyArea(Rect area) async {
    setState(() => _tool = _Tool.none);
    final slots = _zoomedSlots;
    await _copy(() => PageClipboard(_cache!).areaPng(slots, area));
  }

  /// Copies an image to the clipboard, and offers to share it straight to
  /// another app (some apps can't paste images).
  Future<void> _copy(Future<Uint8List> Function() png) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final file = await PageClipboard.copy(await png());
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(s.copied),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: s.shareImage,
              onPressed: () => NativeFiles.shareImage(file).catchError((_) {}),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _toast(s.saveFailed(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ----------------------------------------------------------- translate ---

  Future<void> _translateArea(Rect area) async {
    setState(() => _tool = _Tool.none);
    final s = S.of(context);
    final segments = <({int page, TextBlock block})>[];
    for (final slot in _zoomedSlots) {
      final part = slot.rect.intersect(area);
      if (part.width <= 0 || part.height <= 0) continue;
      final b = await PdfEditor.textIn(_path, slot.page, pageRectOf(slot, part));
      if (b != null && b.text.trim().isNotEmpty) segments.add((page: slot.page, block: b));
    }
    if (!mounted) return;
    if (segments.isEmpty) {
      // Probably a scanned page: offer to read the text from the picture.
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(s.scannedOffer),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.ocrButton)),
          ],
        ),
      );
      if (ok == true && mounted) await _ocrArea(area, thenTranslate: true);
      return;
    }
    final to = await pickTargetLanguage(context, _settings);
    if (to == null || !mounted) return;
    if (!DocTranslator.inApp) {
      // Windows: no translator on the computer; Google Translate's website
      // opens with the text filled in.
      await showWebTranslation(context, segments.map((g) => cleanText(g.block.text)).join('\n\n'), to);
      return;
    }
    final message = ValueNotifier(s.translating);
    List<String>? out;
    try {
      out = await withProgress(
        context,
        message,
        () => translateAll([for (final g in segments) g.block.text], to, message: message, s: s),
      );
    } catch (e) {
      if (mounted) _toast(s.translateFailed(e));
      return;
    }
    if (!mounted) return;
    if (out == null) {
      _toast(s.unknownLanguage);
      return;
    }
    final texts = out;
    final put = await showTranslation(
      context,
      segments.map((g) => g.block.text).join('\n\n'),
      texts.join('\n\n'),
      to: to,
      canPlace: !_showOriginal,
    );
    if (!put || !mounted) return;
    await _runEdit(
      keepPage: segments.first.page,
      suffix: 'translated_$to',
      label: s.stepTranslateArea(_pageList(segments.map((g) => g.page)), languageNames[to] ?? to),
      translated: true,
      edit: (dest) async {
        final stamps = <Stamp>[];
        for (var i = 0; i < segments.length; i++) {
          stamps.addAll(await translatedStamps(_path, segments[i].page, [segments[i].block], [texts[i]]));
        }
        await PdfEditor.stampAll(_path, dest, stamps, replaceText: true);
      },
    );
  }

  /// Translates chosen pages into a new PDF file: the pages keep their
  /// pictures, tables and layout, with the translation where the text was.
  /// The book on screen is not changed. Windows has no translator on the
  /// computer, so there it opens Google Translate's document page instead.
  Future<void> _translateDoc() async {
    final s = S.of(context);
    if (!DocTranslator.inApp) {
      await openGoogleTranslateDocs(context);
      return;
    }
    _resetZoom();
    final total = _cache!.pageCount;
    final visible = _slots.map((e) => e.page).toList();
    final ask = await askDocTranslation(
      context,
      _settings,
      total,
      total <= 20 ? List.generate(total, (i) => i) : visible,
    );
    if (ask == null || !mounted) return;
    final message = ValueNotifier(s.translating);
    final stamps = <Stamp>[];
    bool? unknown;
    var anyText = false;
    String? out;
    try {
      out = await withProgress(context, message, () async {
        for (var k = 0; k < ask.pages.length; k++) {
          final page = ask.pages[k];
          message.value = '${s.translating} ${s.pageProgress(k + 1, ask.pages.length)}';
          // Every bit of text is redrawn on the new page; only blocks with
          // letters are translated (page numbers and figures stay as they are).
          final blocks = await PdfEditor.textBlocks(_path, page);
          final words = translatable(blocks);
          if (words.isEmpty) continue;
          anyText = true;
          final translated = await translateAll(
            [for (final b in words) b.text],
            ask.to,
            message: message,
            s: s,
            onProgress: (_) => message.value = '${s.translating} ${s.pageProgress(k + 1, ask.pages.length)}',
          );
          if (translated == null) {
            unknown ??= true;
            continue;
          }
          unknown = false;
          final byBlock = {for (var i = 0; i < words.length; i++) words[i]: translated[i]};
          final texts = [for (final b in blocks) byBlock[b] ?? b.text];
          stamps.addAll(await translatedPageStamps(_path, page, blocks, texts));
        }
        if (stamps.isEmpty) return null;
        final dest = await _scratchPdf();
        await PdfEditor.translatedCopy(_path, dest, ask.pages, stamps);
        return dest;
      });
    } catch (e) {
      if (mounted) _toast(s.translateFailed(e));
      return;
    }
    if (!mounted) return;
    if (out == null) {
      if (anyText && unknown == true) {
        _toast(s.unknownLanguage);
      } else {
        // No text layer: likely a scan. Point to reading text from the image.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.scannedOffer),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(label: s.ocrButton, onPressed: () => setState(() => _tool = _Tool.ocr)),
          ),
        );
      }
      return;
    }
    final base = _book.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    final saved = await saveAsNewFile(context, _settings, _book, out, suggested: '${base}_${ask.to}.pdf');
    File(out).delete().ignore();
    if (saved == null || !mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.openTranslatedQuestion(saved.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.close)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.openTranslated)),
        ],
      ),
    );
    if (open == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(book: saved, settings: _settings, sounds: widget.sounds),
        ),
      );
    }
  }

  // ------------------------------------------------------ text from scans ---

  /// Reads the text inside [area] from the page pictures (for scanned PDFs),
  /// then lets the user fix, copy or translate it.
  Future<void> _ocrArea(Rect area, {bool thenTranslate = false}) async {
    setState(() => _tool = _Tool.none);
    final s = S.of(context);
    final slots = _zoomedSlots;
    final png = await PageClipboard(_cache!).areaPng(slots, area, side: 3600, maxScale: 6);
    if (!mounted) return;
    var langs = _ocrLangs;
    while (true) {
      if (!mounted) return;
      final message = ValueNotifier(s.ocrReading);
      String text;
      try {
        text = await withProgress(
          context,
          message,
          () => Ocr.instance.read(png, langs, onDownload: () => message.value = s.ocrDownloading),
        );
      } on MissingPluginException {
        if (mounted) _toast(s.ocrNotSupported);
        return;
      } catch (e) {
        if (mounted) _toast(s.ocrFailed(e));
        return;
      }
      if (!mounted) return;
      final result = await showDialog<OcrResult>(
        context: context,
        builder: (_) => OcrResultDialog(text: text, langs: langs, autoTranslate: thenTranslate),
      );
      if (result == null || !mounted) return;
      if (result.langs != null) {
        // Read again in other languages.
        langs = result.langs!;
        _settings.ocrLangs = langs.join('+');
        thenTranslate = false;
        continue;
      }
      if (result.translate != null) await _translateText(result.translate!);
      return;
    }
  }

  List<String> get _ocrLangs {
    final saved = _settings.ocrLangs;
    if (saved != null && saved.isNotEmpty) {
      final list = saved.split('+').where(Ocr.tesseract.containsKey).toList();
      if (list.isNotEmpty) return list;
    }
    return Ocr.defaultsFor(S.of(context).code);
  }

  /// Translates text that is not on the page (read from a scan).
  Future<void> _translateText(String text) async {
    final s = S.of(context);
    final to = await pickTargetLanguage(context, _settings);
    if (to == null || !mounted) return;
    if (!DocTranslator.inApp) {
      await showWebTranslation(context, cleanText(text), to);
      return;
    }
    final message = ValueNotifier(s.translating);
    List<String>? out;
    try {
      out = await withProgress(context, message, () => translateAll([text], to, message: message, s: s));
    } catch (e) {
      if (mounted) _toast(s.translateFailed(e));
      return;
    }
    if (!mounted) return;
    if (out == null) {
      _toast(s.unknownLanguage);
      return;
    }
    await showTranslation(context, text, out.first, to: to, canPlace: false);
  }

  // ------------------------------------------------------------- dialogs ---

  Future<void> _askPage() async {
    final total = _cache?.pageCount ?? 0;
    if (total == 0) return;
    final page = await showGoToPageDialog(context, total);
    if (page != null) _goToPage(page - 1);
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    SystemChrome.setEnabledSystemUIMode(_controlsVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  }

  // --------------------------------------------------------------- build ---

  String get _pageLabel => _labelFor(_index);

  String _labelFor(int index) {
    final total = _cache?.pageCount ?? 0;
    if (_spreads.isEmpty) return '';
    final pages = _spreads[index.clamp(0, _spreads.length - 1)].pages.map((p) => p + 1).toList();
    final range = pages.length == 2 ? '${pages[0]}–${pages[1]}' : '${pages.first}';
    return S.of(context).pageLabel(range, total);
  }

  @override
  Widget build(BuildContext context) {
    final cache = _cache;
    return PopScope(
      canPop: _working == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _scaffold(cache),
    );
  }

  Widget _scaffold(PageCache? cache) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B18),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(
              left: _rails ? _railWidth : 0,
              right: _rails ? _railWidth : 0,
              child: cache == null
                  ? const SizedBox.shrink()
                  : Listener(onPointerSignal: _onWheel, child: _bookView(cache)),
            ),
            if (cache != null && _tool == _Tool.none) _topBar(),
            if (cache != null && _spreads.length > 1 && _tool == _Tool.none) _bottomBar(),
            if (cache != null && _spreads.length > 2 && _tool == _Tool.none) _scroller(),
            if (_tool == _Tool.sign && _signature != null)
              Positioned.fill(
                child: PlaceSignature(
                  signature: _signature!,
                  slots: _zoomedSlots,
                  onDone: _placeSignature,
                  onCancel: () => setState(() => _tool = _Tool.none),
                ),
              ),
            if (_tool == _Tool.markup)
              Positioned.fill(
                child: MarkupLayer(
                  slots: _zoomedSlots,
                  marks: _marks,
                  pageChars: (page) => PdfEditor.pageChars(_path, page),
                  zoom: _zoom,
                  pan: _screenPan,
                  onZoom: _setScreenZoom,
                  onDone: _saveMarks,
                  onCancel: () => setState(() {
                    _tool = _Tool.none;
                    _marks.clear();
                  }),
                ),
              ),
            if (_tool == _Tool.translate)
              Positioned.fill(
                child: SelectArea(
                  hint: S.of(context).selectTextHint,
                  confirm: S.of(context).translateButton,
                  onDone: _translateArea,
                  onCancel: () => setState(() => _tool = _Tool.none),
                ),
              ),
            if (_tool == _Tool.area)
              Positioned.fill(
                child: SelectArea(onDone: _copyArea, onCancel: () => setState(() => _tool = _Tool.none)),
              ),
            if (_tool == _Tool.ocr)
              Positioned.fill(
                child: SelectArea(
                  hint: S.of(context).ocrHint,
                  confirm: S.of(context).ocrButton,
                  onDone: _ocrArea,
                  onCancel: () => setState(() => _tool = _Tool.none),
                ),
              ),
            if (cache != null && _tool == _Tool.none && _beforeTranslation != null) _originalSwitch(),
            if (cache != null && _tool == _Tool.none && !_rails) ...[_edgeStrip(true), _edgeStrip(false)],
            if (cache != null && _tool == _Tool.none && _rails) ...[_rail(true), _rail(false)],
            if (_edgeLeft != null) _edgeMenu(_edgeLeft!),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _bookView(PageCache cache) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      _bookSize = size;
      final layout = BookLayout.compute(size, cache.aspect, _twoPage);
      if (_layout != null && _layout!.right != layout.right) {
        // New screen size or mode: start unzoomed.
        _zoom = 1;
        _pan = Offset.zero;
        _renderZoom = 1;
      }
      if (_layout != null && _layout!.right != layout.right && _flip != null) {
        // Screen rotated mid-turn: drop the turn rather than draw it wrong.
        _anim.stop();
        _flip = null;
        _dragDir = 0;
      }
      _layout = layout;
      // Sharper pages once a zoom has settled.
      cache.setRenderWidth(layout.pageWidth * MediaQuery.of(context).devicePixelRatio * _renderZoom);
      _prefetch();
      final book = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTap: _zoom > 1 ? _resetZoom : _askPage,
        onScaleStart: _onScaleStart,
        onScaleUpdate: (d) => _onScaleUpdate(d, size),
        onScaleEnd: _onScaleEnd,
        child: ClipRect(
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(_pan.dx, _pan.dy, 0, 1)
              ..scaleByDouble(_zoom, _zoom, 1, 1),
            child: CustomPaint(
              size: size,
              painter: BookPainter(
                cache: _rtl ? _mirrored! : cache,
                night: _settings.nightMode,
                layout: layout,
                spread: _spreads.isEmpty ? const Spread(null, null) : _spreads[_index],
                flip: _flip,
                style: FlipStyle.values[_settings.flipStyle],
              ),
            ),
          ),
        ),
      );
      // Inside the flip, drag positions arrive already mirrored.
      return _rtl ? Transform.flip(flipX: true, child: book) : book;
    },
  );

  Widget _topBar() => AnimatedPositioned(
    duration: const Duration(milliseconds: 200),
    top: _controlsVisible ? 0 : -120,
    // On Windows the bar sits between the icon rails, so neither hides the other.
    left: _rails ? _railWidth : 0,
    right: _rails ? _railWidth : 0,
    child: Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(tooltip: S.of(context).backToFiles, icon: const Icon(Icons.arrow_back), onPressed: _leave),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    _working == null ? _pageLabel : '$_pageLabel  •  ${S.of(context).unsavedMark}',
                    style: TextStyle(fontSize: 12, color: _working == null ? Colors.white70 : Colors.amberAccent),
                  ),
                ],
              ),
            ),
            if (_history.isNotEmpty) ...[
              IconButton(
                tooltip: '${S.of(context).undo} (${S.of(context).undoChanges}…)',
                icon: Badge.count(count: _history.length, child: const Icon(Icons.undo)),
                onPressed: () => _undoFrom(_history.length - 1),
                onLongPress: _showUndoList,
              ),
              // Narrow phones: the list is a long press on undo, or in the menu.
              if (MediaQuery.sizeOf(context).width >= 420)
                IconButton(
                  tooltip: S.of(context).undoChanges,
                  icon: const Icon(Icons.history),
                  onPressed: _showUndoList,
                ),
            ],
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.crop_portrait), tooltip: S.of(context).singlePage),
                ButtonSegment(value: true, icon: const Icon(Icons.menu_book), tooltip: S.of(context).twoPage),
              ],
              selected: {_twoPage},
              onSelectionChanged: (s) => _setMode(twoPage: s.first),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'goto') _askPage();
                if (v == 'cover') _setMode(coverAlone: !_coverAlone);
                if (v == 'rtl') _setRtl(!_rtl);
                if (v == 'night') setState(() => _settings.nightMode = !_settings.nightMode);
                if (v == 'rotate' && _flip == null) setState(() => _settings.quarterTurns += 1);
                if (v == 'sound') showSoundSettings(context, _settings, widget.sounds);
                if (v == 'ambient') showAmbientSettings(context, _settings, _ambient);
                if (v == 'sign') _startSigning();
                if (v == 'copyPage') _copyPage();
                if (v == 'copyArea' && _idle) setState(() => _tool = _Tool.area);
                if (v == 'markup' && _editAllowed()) setState(() => _tool = _Tool.markup);
                if (v == 'ocr' && _idle) setState(() => _tool = _Tool.ocr);
                if (v == 'undoList') _showUndoList();
                if (v == 'original') _toggleOriginal();
                if (v == 'flip') _chooseFlipStyle();
                if (v == 'licenses') showLicensePage(context: context, applicationName: 'Pagelume');
                if (v == 'delete') _askDelete();
                if (v == 'translateArea' && _idle) setState(() => _tool = _Tool.translate);
                if (v == 'translateDoc') _translateDoc();
                if (v == 'files') _leave();
                if (v == 'save') _saveWorking();
                if (v == 'exit') {
                  _confirmLeave().then((ok) {
                    if (ok) Desktop.quit();
                  });
                }
                if (v == 'lang') {
                  showLanguagePicker(context, _settings.language).then((code) {
                    if (code != null) _settings.language = code.isEmpty ? null : code;
                  });
                }
              },
              itemBuilder: (_) => [
                if (_working != null) _iconItem('save', Icons.save, S.of(context).saveMenu),
                if (_history.isNotEmpty) _iconItem('undoList', Icons.history, S.of(context).undoChanges),
                PopupMenuItem(value: 'goto', child: Text(S.of(context).goToPageMenu)),
                _iconItem('sign', Icons.draw, S.of(context).signDocument),
                _iconItem('markup', Icons.format_color_text, S.of(context).markup),
                _iconItem('copyPage', Icons.copy, S.of(context).copyPage),
                _iconItem('copyArea', Icons.crop, S.of(context).copyAreaImage),
                _iconItem('delete', Icons.delete_outline, S.of(context).deletePages),
                _iconItem('translateArea', Icons.translate, S.of(context).translateArea),
                if (DocTranslator.inApp) _iconItem('translateDoc', Icons.g_translate, S.of(context).translateDoc),
                _iconItem('ocr', Icons.document_scanner, S.of(context).ocrArea),
                if (_beforeTranslation != null)
                  _iconItem(
                    'original',
                    Icons.compare,
                    _showOriginal ? S.of(context).showTranslated : S.of(context).showOriginal,
                  ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'cover',
                  checked: _coverAlone,
                  enabled: _twoPage,
                  child: Text(S.of(context).coverAlone),
                ),
                CheckedPopupMenuItem(value: 'rtl', checked: _rtl, child: Text(S.of(context).rtlPages)),
                PopupMenuItem(value: 'flip', child: Text('${S.of(context).flipEffect}…')),
                CheckedPopupMenuItem(
                  value: 'night',
                  checked: _settings.nightMode,
                  child: Text(S.of(context).nightMode),
                ),
                PopupMenuItem(
                  value: 'rotate',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.screen_rotation),
                    title: Text(S.of(context).rotateScreen),
                    trailing: Text('${_settings.quarterTurns * 90}°'),
                  ),
                ),
                PopupMenuItem(value: 'sound', child: Text('${S.of(context).flipSoundMenu}…')),
                PopupMenuItem(value: 'ambient', child: Text('${S.of(context).ambientMenu}…')),
                PopupMenuItem(value: 'lang', child: Text('${S.of(context).language}…')),
                PopupMenuItem(value: 'licenses', child: Text(S.of(context).licenses)),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'files', child: Text(S.of(context).otherFile)),
                PopupMenuItem(value: 'exit', child: Text(S.of(context).exitApp)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  PopupMenuItem<String> _iconItem(String value, IconData icon, String text) => PopupMenuItem(
    value: value,
    child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(text)),
  );

  /// "Show original" / "Show translation" while a translation is unsaved.
  Widget _originalSwitch() {
    final s = S.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: _controlsVisible && _spreads.length > 1 ? 76 : 16,
      child: SafeArea(
        top: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showOriginal)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                  child: Text(s.viewingOriginal, style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                ),
              FilledButton.tonalIcon(
                icon: Icon(_showOriginal ? Icons.translate : Icons.compare),
                label: Text(_showOriginal ? s.showTranslated : s.showOriginal),
                onPressed: _idle ? _toggleOriginal : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows spread [i] at once (slider, scroll bar), without a page turn.
  void _showIndex(int i) {
    if (_flip != null || _anim.isAnimating || i == _index) return;
    setState(() {
      _index = i.clamp(0, _spreads.length - 1);
      _zoom = 1;
      _pan = Offset.zero;
    });
    _prefetch();
  }

  /// The scroll bar on the right: drag to move quickly through long books.
  /// It sits just inside the right edge strip, which opens the edge menu.
  Widget _scroller() {
    final pad = MediaQuery.paddingOf(context);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: pad.top + 72,
      bottom: pad.bottom + 72,
      right: _controlsVisible ? pad.right + 26 + (_rails ? _railWidth : 0) : -80,
      width: 36,
      child: PageScroller(
        count: _spreads.length,
        index: _index,
        labelFor: _labelFor,
        onChanged: _showIndex,
        onEnd: _saveProgress,
        tooltip: S.of(context).goToPageMenu,
      ),
    );
  }

  Widget _bottomBar() => AnimatedPositioned(
    duration: const Duration(milliseconds: 200),
    bottom: _controlsVisible ? 0 : -120,
    // On Windows the bar sits between the icon rails, so neither hides the other.
    left: _rails ? _railWidth : 0,
    right: _rails ? _railWidth : 0,
    // The slider and arrows follow the page-turn direction, not the menu
    // language.
    child: Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _hasPrev ? () => _turn(false) : null),
              Expanded(
                child: Slider(
                  value: _index.toDouble(),
                  min: 0,
                  max: (_spreads.length - 1).toDouble(),
                  divisions: _spreads.length - 1,
                  label: _pageLabel,
                  onChanged: _flip != null ? null : (v) => _showIndex(v.round()),
                  onChangeEnd: (_) => _saveProgress(),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _hasNext ? () => _turn(true) : null),
              IconButton(
                tooltip: S.of(context).goToPageMenu,
                icon: const Icon(Icons.pin_outlined),
                onPressed: _askPage,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Two-page view: tick which of the two pages to delete.
class _DeletePagesDialog extends StatefulWidget {
  const _DeletePagesDialog({required this.pages});
  final List<int> pages;

  @override
  State<_DeletePagesDialog> createState() => _DeletePagesDialogState();
}

class _DeletePagesDialogState extends State<_DeletePagesDialog> {
  final _chosen = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.deleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.deleteChoose),
          for (final p in widget.pages)
            CheckboxListTile(
              value: _chosen.contains(p),
              title: Text(s.pageN(p + 1)),
              onChanged: (v) => setState(() => v == true ? _chosen.add(p) : _chosen.remove(p)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, _chosen.toList()..sort()),
          child: Text(s.delete),
        ),
      ],
    );
  }
}

/// The undo list: newest step first. Tapping a step marks it and every
/// later step; the button undoes them all.
class _UndoSheet extends StatefulWidget {
  const _UndoSheet({required this.steps});
  final List<({String label, DateTime at})> steps;

  @override
  State<_UndoSheet> createState() => _UndoSheetState();
}

class _UndoSheetState extends State<_UndoSheet> {
  late int _from = widget.steps.length - 1;

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final n = widget.steps.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.undoChanges, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(s.undoHint),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = n - 1; i >= 0; i--)
                    ListTile(
                      key: ValueKey('undo_$i'),
                      selected: i >= _from,
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                      title: Text(
                        widget.steps[i].label,
                        style: i >= _from ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                      ),
                      trailing: Text(_time(widget.steps[i].at), style: const TextStyle(fontSize: 12)),
                      onTap: () => setState(() => _from = i),
                    ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(s.undoOpened, style: const TextStyle(color: Colors.white60)),
                    onTap: () => setState(() => _from = 0),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.undo),
                    label: Text(s.undoSteps(n - _from)),
                    onPressed: () => Navigator.pop(context, _from),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
