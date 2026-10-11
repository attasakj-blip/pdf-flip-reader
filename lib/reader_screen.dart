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
import 'edit_tools.dart';
import 'flip_sounds.dart';
import 'goto_dialog.dart';
import 'l10n.dart';
import 'markup.dart';
import 'page_cache.dart';
import 'page_clipboard.dart';
import 'pdf_edit.dart';
import 'save_flow.dart';
import 'settings.dart';
import 'sound_settings.dart';
import 'translate_flow.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, required this.settings, required this.sounds});

  final RecentBook book;
  final Settings settings;
  final FlipSounds sounds;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _Tool { none, sign, area, translate, markup }

enum _Gesture { none, turn, pan, zoom }

class _ReaderScreenState extends State<ReaderScreen> with SingleTickerProviderStateMixin {
  /// The book on screen; saving an edit as a new file switches to it.
  late RecentBook _book = widget.book;

  /// Edits not saved yet live in this copy of the book; saving writes it out.
  String? _working;
  String? _editSuffix;
  String get _path => _working ?? _book.localPath;
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
    _load();
    _ambient.start();
  }

  @override
  void dispose() {
    _anim.dispose();
    _focus.dispose();
    _ambient.dispose();
    final w = _working;
    if (w != null) File(w).delete().ignore();
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

  /// Animated turn for buttons, keyboard and presentation clickers.
  void _turn(bool forward) {
    if (_zoom > 1) _resetZoom();
    final l = _layout;
    if (l == null || _anim.isAnimating || _flip != null) return;
    if (forward ? !_hasNext : !_hasPrev) return;
    _bottom = true;
    _dragDir = forward ? -1 : 1;
    final start = forward ? l.corner(true) : l.turnedCorner(true);
    setState(() => _flip = _flipWith(start));
    widget.sounds.playTurn();
    _animateCorner(forward ? l.turnedCorner(true) : l.corner(true), () {
      _index += forward ? 1 : -1;
    });
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
      edit: (dest) async => PdfEditor.stampAll(_path, dest, await markStamps(marks, aspects)),
    );
  }

  bool get _idle => _flip == null && !_anim.isAnimating && !_loading && _cache != null;

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  Future<String> _scratchPdf() async {
    final tmp = (await getTemporaryDirectory()).path;
    PdfEditor.cacheDir ??= tmp;
    return '$tmp/edit_${DateTime.now().microsecondsSinceEpoch}.pdf';
  }

  Future<void> _startSigning() async {
    if (!_idle) return;
    final sig = await showSignaturePad(context);
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
      edit: (dest) async {
        // Roughly 300 dpi for the signature image on a typical page.
        final px = (box.width / slot.rect.width * 2400).clamp(120, 1800).round();
        final img = await sig.toRgba(px);
        await PdfEditor.stamp(_path, dest, slot.page, img.rgba, img.w, img.h, pageRectOf(slot, box));
      },
    );
  }

  Future<void> _askDelete() async {
    if (!_idle) return;
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
      edit: (dest) => PdfEditor.deletePages(_path, dest, del),
    );
  }

  /// Makes an edited copy with [edit], asks how to save it and shows the
  /// result. The original stays as it was if anything fails or the user
  /// backs out.
  Future<void> _runEdit({
    required int keepPage,
    required String suffix,
    required Future<void> Function(String dest) edit,
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
    final previous = _working;
    _working = dest;
    _editSuffix = _editSuffix == null ? suffix : 'edited';
    await _reload(keepPage);
    if (previous != null) File(previous).delete().ignore();
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
    _working = null;
    _editSuffix = null;
    await _reload(keep);
    File(working).delete().ignore();
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
      File(_working!).delete().ignore();
      setState(() {
        _working = null;
        _editSuffix = null;
      });
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

  Future<void> _copy(Future<Uint8List> Function() png) async {
    final s = S.of(context);
    setState(() => _loading = true);
    try {
      await PageClipboard.copy(await png());
      if (mounted) _toast(s.copied);
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
      _toast(s.noText);
      return;
    }
    final to = await pickTargetLanguage(context, _settings);
    if (to == null || !mounted) return;
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
    final put = await showTranslation(context, segments.map((g) => g.block.text).join('\n\n'), texts.join('\n\n'));
    if (!put || !mounted) return;
    await _runEdit(
      keepPage: segments.first.page,
      suffix: 'translated_$to',
      edit: (dest) async {
        final stamps = <Stamp>[];
        for (var i = 0; i < segments.length; i++) {
          stamps.addAll(await translatedStamps(_path, segments[i].page, [segments[i].block], [texts[i]]));
        }
        await PdfEditor.stampAll(_path, dest, stamps, replaceText: true);
      },
    );
  }

  Future<void> _translateDoc() async {
    if (!_idle) return;
    _resetZoom();
    final s = S.of(context);
    final total = _cache!.pageCount;
    final visible = _slots.map((e) => e.page).toList();
    final ask = await askDocTranslation(
      context,
      _settings,
      total,
      total <= 10 ? List.generate(total, (i) => i) : visible,
    );
    if (ask == null || !mounted) return;
    final message = ValueNotifier(s.translating);
    final stamps = <Stamp>[];
    bool? unknown;
    try {
      await withProgress(context, message, () async {
        for (var k = 0; k < ask.pages.length; k++) {
          final page = ask.pages[k];
          message.value = '${s.translating} ${s.pageProgress(k + 1, ask.pages.length)}';
          final blocks = translatable(await PdfEditor.textBlocks(_path, page));
          if (blocks.isEmpty) continue;
          final out = await translateAll(
            [for (final b in blocks) b.text],
            ask.to,
            message: message,
            s: s,
            onProgress: (_) => message.value = '${s.translating} ${s.pageProgress(k + 1, ask.pages.length)}',
          );
          if (out == null) {
            unknown ??= true;
            continue;
          }
          unknown = false;
          stamps.addAll(await translatedStamps(_path, page, blocks, out));
        }
      });
    } catch (e) {
      if (mounted) _toast(s.translateFailed(e));
      return;
    }
    if (!mounted) return;
    if (stamps.isEmpty) {
      _toast(unknown == true ? s.unknownLanguage : s.noText);
      return;
    }
    await _runEdit(
      keepPage: ask.pages.first,
      suffix: 'translated_${ask.to}',
      edit: (dest) => PdfEditor.stampAll(_path, dest, stamps, replaceText: true),
    );
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

  String get _pageLabel {
    final total = _cache?.pageCount ?? 0;
    if (_spreads.isEmpty) return '';
    final pages = _spreads[_index].pages.map((p) => p + 1).toList();
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
            Positioned.fill(child: cache == null ? const SizedBox.shrink() : _bookView(cache)),
            if (cache != null && _tool == _Tool.none) _topBar(),
            if (cache != null && _spreads.length > 1 && _tool == _Tool.none) _bottomBar(),
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
    left: 0,
    right: 0,
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
                if (v == 'markup' && _idle) setState(() => _tool = _Tool.markup);
                if (v == 'delete') _askDelete();
                if (v == 'translateArea' && _idle) setState(() => _tool = _Tool.translate);
                if (v == 'translateDoc') _translateDoc();
                if (v == 'files') _leave();
                if (v == 'save') _saveWorking();
                if (v == 'exit') {
                  _confirmLeave().then((ok) {
                    if (ok) SystemNavigator.pop();
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
                PopupMenuItem(value: 'goto', child: Text(S.of(context).goToPageMenu)),
                _iconItem('sign', Icons.draw, S.of(context).signDocument),
                _iconItem('markup', Icons.edit_note, S.of(context).markup),
                _iconItem('copyPage', Icons.copy, S.of(context).copyPage),
                _iconItem('copyArea', Icons.crop, S.of(context).copyArea),
                _iconItem('delete', Icons.delete_outline, S.of(context).deletePages),
                _iconItem('translateArea', Icons.translate, S.of(context).translateArea),
                _iconItem('translateDoc', Icons.g_translate, S.of(context).translateDoc),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'cover',
                  checked: _coverAlone,
                  enabled: _twoPage,
                  child: Text(S.of(context).coverAlone),
                ),
                CheckedPopupMenuItem(value: 'rtl', checked: _rtl, child: Text(S.of(context).rtlPages)),
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

  Widget _bottomBar() => AnimatedPositioned(
    duration: const Duration(milliseconds: 200),
    bottom: _controlsVisible ? 0 : -120,
    left: 0,
    right: 0,
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
                  onChanged: _flip != null
                      ? null
                      : (v) {
                          setState(() {
                            _index = v.round();
                            _zoom = 1;
                            _pan = Offset.zero;
                          });
                          _prefetch();
                        },
                  onChangeEnd: (_) => _saveProgress(),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _hasNext ? () => _turn(true) : null),
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
