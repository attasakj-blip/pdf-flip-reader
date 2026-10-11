import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One entry of an [EdgeMenu]. Give [on] for a setting that is switched on
/// and off; the menu then stays open so the change can be seen.
class EdgeMenuItem {
  const EdgeMenuItem({required this.icon, required this.label, required this.onTap, this.on, this.enabled = true});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool? on;
  final bool enabled;
}

const _gold = Color(0xFFFFC45C);
const _goldDeep = Color(0xFFF08A3C);

/// A glass panel that slides out from the [left] or right side of the
/// screen, following the finger while [progress] is dragged from 0 to 1.
class EdgeMenu extends StatelessWidget {
  const EdgeMenu({
    super.key,
    required this.left,
    required this.progress,
    required this.title,
    required this.icon,
    required this.items,
    required this.onClose,
  });

  final bool left;

  /// 0 closed, 1 open. The menu drags it while the panel is pulled back.
  final AnimationController progress;
  final String title;
  final IconData icon;
  final List<EdgeMenuItem> items;

  /// Asks the owner to animate the menu shut.
  final VoidCallback onClose;

  static double panelWidth(Size screen) => math.min(300, screen.width * 0.78);

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = panelWidth(screen);
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final p = progress.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          // Pull the panel back towards its edge to close it.
          onHorizontalDragUpdate: (d) => progress.value += (left ? d.delta.dx : -d.delta.dx) / width,
          onHorizontalDragEnd: (d) {
            final v = (left ? 1 : -1) * d.velocity.pixelsPerSecond.dx;
            if (v < -300 || (v < 300 && progress.value < 0.6)) {
              onClose();
            } else {
              progress.animateTo(1, curve: Curves.easeOutCubic);
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.45 * p)),
              ),
              Align(
                alignment: left ? Alignment.centerLeft : Alignment.centerRight,
                child: Transform.translate(
                  offset: Offset((left ? -1 : 1) * (1 - p) * (width + 24), 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: GestureDetector(
                      onTap: () {}, // taps on the panel itself don't close it
                      child: SizedBox(width: width, child: _panel(context, p)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _panel(BuildContext context, double p) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(left ? 18 : 32),
      bottomLeft: Radius.circular(left ? 18 : 32),
      topRight: Radius.circular(left ? 32 : 18),
      bottomRight: Radius.circular(left ? 32 : 18),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: _gold.withValues(alpha: 0.22 * p), blurRadius: 32, spreadRadius: 1),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5 * p),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE6352276), Color(0xEB130E38)],
              ),
              border: Border.all(color: _gold.withValues(alpha: 0.35)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 10),
                  for (var i = 0; i < items.length; i++) _staggered(i, p, _tile(items[i])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        Icon(icon, color: _gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Color(0xFFFFF3E0), fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          width: 28,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(colors: [_gold, _goldDeep]),
          ),
        ),
      ],
    ),
  );

  /// Items slide in one after another as the panel opens.
  Widget _staggered(int i, double p, Widget child) {
    final t = Curves.easeOutCubic.transform(((p - 0.25 - i * 0.07) / 0.45).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset((left ? -1 : 1) * (1 - t) * 40, 0), child: child),
    );
  }

  Widget _tile(EdgeMenuItem item) {
    final toggle = item.on != null;
    final lit = !toggle || item.on!;
    return Opacity(
      opacity: item.enabled ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: _gold.withValues(alpha: 0.25),
            onTap: item.enabled ? item.onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: lit
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_gold, _goldDeep],
                            )
                          : null,
                      color: lit ? null : Colors.white.withValues(alpha: 0.12),
                      boxShadow: lit ? [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 12)] : null,
                    ),
                    child: Icon(item.icon, size: 22, color: lit ? const Color(0xFF2A1A55) : Colors.white70),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  if (toggle) _Pill(on: item.on!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small on/off switch drawn to match the panel.
class _Pill extends StatelessWidget {
  const _Pill({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 38,
    height: 22,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      color: on ? _gold.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.18),
    ),
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFF2A1A55) : Colors.white70),
      ),
    ),
  );
}

/// The thin glowing tab at a side edge that shows where an edge menu lives;
/// a tap opens the menu too.
class EdgeHandle extends StatelessWidget {
  const EdgeHandle({super.key, required this.left, required this.visible});
  final bool left;
  final bool visible;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: visible ? 1 : 0,
    child: Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 5,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(left ? 0 : 3),
            right: Radius.circular(left ? 3 : 0),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_gold, _goldDeep],
          ),
          boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.6), blurRadius: 10)],
        ),
      ),
    ),
  );
}
