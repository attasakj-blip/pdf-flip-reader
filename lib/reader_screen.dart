import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'book_painter.dart';
import 'flip_sounds.dart';
import 'goto_dialog.dart';
import 'l10n.dart';
import 'page_cache.dart';
import 'settings.dart';
import 'sound_settings.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, required this.settings, required this.sounds});

  final RecentBook book;
  final Settings settings;
  final FlipSounds sounds;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _anim.dispose();
    _focus.dispose();
    _mirrored?.dispose();
    _cache?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------------------------------------------------------------- file ---

  Future<void> _load() async {
    try {
      final doc = await PdfDocument.openFile(widget.book.localPath);
      final cache = PageCache(doc);
      await cache.init();
      if (!mounted) {
        cache.dispose();
        return;
      }
      setState(() {
        _cache = cache;
        _mirrored = MirroredPages(cache);
        _rtl = widget.book.rtl ?? Directionality.of(context) == TextDirection.rtl;
        _rebuildSpreads(keepPage: widget.book.lastPage.clamp(0, cache.pageCount - 1));
      });
      WakelockPlus.enable();
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
    widget.book.lastPage = _firstVisiblePage;
    final list = _settings.recents;
    for (final b in list) {
      if (b.localPath == widget.book.localPath) b.lastPage = _firstVisiblePage;
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
    widget.book.rtl = v;
    final list = _settings.recents;
    for (final b in list) {
      if (b.localPath == widget.book.localPath) b.rtl = v;
    }
    _settings.saveRecents(list);
  }

  void _goToPage(int page) {
    _anim.stop();
    setState(() {
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

  void _onDragStart(DragStartDetails d) {
    if (_anim.isAnimating || _layout == null) return;
    _dragDir = 0;
    _dragStart = d.localPosition;
    _bottom = d.localPosition.dy > _layout!.right.center.dy;
  }

  void _onDragUpdate(DragUpdateDetails d, double screenWidth) {
    final l = _layout;
    if (l == null || _anim.isAnimating) return;
    if (_dragDir == 0) {
      final dx = d.localPosition.dx - _dragStart.dx;
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
    final p = l.clampCorner(_cornerStart + (d.localPosition - _dragStart) * k, _bottom);
    setState(() => _flip = _flipWith(p));
  }

  FlipState _flipWith(Offset corner) {
    final forward = _dragDir < 0;
    final from = forward ? _spreads[_index] : _spreads[_index - 1];
    final to = forward ? _spreads[_index + 1] : _spreads[_index];
    return FlipState(from: from, to: to, corner: corner, bottom: _bottom);
  }

  void _onDragEnd(DragEndDetails d) {
    final l = _layout;
    final f = _flip;
    if (l == null || f == null || _dragDir == 0) {
      _dragDir = 0;
      return;
    }
    final vx = d.velocity.pixelsPerSecond.dx; // in book space, like positions
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B18),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(child: cache == null ? const SizedBox.shrink() : _book(cache)),
            if (cache != null) _topBar(),
            if (cache != null && _spreads.length > 1) _bottomBar(),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _book(PageCache cache) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final layout = BookLayout.compute(size, cache.aspect, _twoPage);
      if (_layout != null && _layout!.right != layout.right && _flip != null) {
        // Screen rotated mid-turn: drop the turn rather than draw it wrong.
        _anim.stop();
        _flip = null;
        _dragDir = 0;
      }
      _layout = layout;
      cache.setRenderWidth(layout.pageWidth * MediaQuery.of(context).devicePixelRatio);
      _prefetch();
      final book = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTap: _askPage,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, size.width),
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: () {
          if (_flip != null && !_anim.isAnimating) {
            _onDragEnd(DragEndDetails(velocity: Velocity.zero));
          }
        },
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
            IconButton(
              tooltip: S.of(context).backToFiles,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_pageLabel, style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                if (v == 'files') Navigator.of(context).maybePop();
                if (v == 'exit') SystemNavigator.pop();
                if (v == 'lang') {
                  showLanguagePicker(context, _settings.language).then((code) {
                    if (code != null) _settings.language = code.isEmpty ? null : code;
                  });
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'goto', child: Text(S.of(context).goToPageMenu)),
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
                          setState(() => _index = v.round());
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
