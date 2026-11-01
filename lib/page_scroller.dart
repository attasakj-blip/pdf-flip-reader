import 'package:flutter/material.dart';

/// A scroll bar along the right side of the reader: drag the thumb (or tap
/// the track) to jump quickly through a long book. While dragging, a bubble
/// shows which page you would land on.
class PageScroller extends StatefulWidget {
  const PageScroller({
    super.key,
    required this.count,
    required this.index,
    required this.labelFor,
    required this.onChanged,
    required this.onEnd,
    this.tooltip,
  });

  /// Number of positions (spreads) and the one shown now.
  final int count;
  final int index;

  /// Page label for a position, such as "12 / 300".
  final String Function(int index) labelFor;
  final ValueChanged<int> onChanged;
  final VoidCallback onEnd;
  final String? tooltip;

  @override
  State<PageScroller> createState() => _PageScrollerState();
}

class _PageScrollerState extends State<PageScroller> {
  static const _thumb = 46.0;
  bool _dragging = false;
  bool _hover = false;

  int _indexAt(double dy, double height) {
    final room = height - _thumb;
    if (room <= 0 || widget.count < 2) return 0;
    final f = ((dy - _thumb / 2) / room).clamp(0.0, 1.0);
    return (f * (widget.count - 1)).round();
  }

  void _move(double dy, double height) {
    final i = _indexAt(dy, height);
    if (i != widget.index) widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        final f = widget.count < 2 ? 0.0 : widget.index / (widget.count - 1);
        final top = f * (h - _thumb);
        final active = _dragging || _hover;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (d) {
              _move(d.localPosition.dy, h);
              widget.onEnd();
            },
            onVerticalDragStart: (d) {
              setState(() => _dragging = true);
              _move(d.localPosition.dy, h);
            },
            onVerticalDragUpdate: (d) => _move(d.localPosition.dy, h),
            onVerticalDragEnd: (_) {
              setState(() => _dragging = false);
              widget.onEnd();
            },
            onVerticalDragCancel: () => setState(() => _dragging = false),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track.
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 12,
                  width: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: active ? 0.35 : 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Thumb.
                Positioned(
                  top: top,
                  right: 4,
                  width: 20,
                  height: _thumb,
                  child: Tooltip(
                    message: widget.tooltip ?? '',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: active ? Colors.amberAccent : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.unfold_more, size: 16, color: Colors.black87),
                    ),
                  ),
                ),
                // Page bubble while dragging.
                if (_dragging)
                  Positioned(
                    top: (top + _thumb / 2 - 18).clamp(0.0, h - 36),
                    right: 32,
                    child: Material(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          widget.labelFor(widget.index),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
