import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiPiece {
  final double left; // 0..1
  final double delay; // seconds
  final double duration; // seconds
  final Color color;
  final double rotSpeed;

  _ConfettiPiece(
    this.left,
    this.delay,
    this.duration,
    this.color,
    this.rotSpeed,
  );
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<_ConfettiPiece> _pieces = [];
  static const _colors = [
    Color(0xFFC9A24B),
    Color(0xFFB3322F),
    Color(0xFF2F4F8F),
    Color(0xFFE6CF8A),
    Color(0xFFEFE2C4),
  ];

  @override
  void initState() {
    super.initState();
    final rand = Random();
    for (int i = 0; i < 70; i++) {
      _pieces.add(
        _ConfettiPiece(
          rand.nextDouble(),
          rand.nextDouble() * 0.6,
          2.0 + rand.nextDouble() * 1.6,
          _colors[i % _colors.length],
          1.5 + rand.nextDouble() * 2.5,
        ),
      );
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Stack(
                children: _pieces.map((p) {
                  final t = ((_ctrl.value * 4 - p.delay) / p.duration).clamp(
                    0.0,
                    1.0,
                  );
                  final y = t * (constraints.maxHeight + 40) - 20;
                  final opacity = t >= 1.0 ? 0.0 : 1.0;
                  return Positioned(
                    left: p.left * constraints.maxWidth,
                    top: y,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.rotate(
                        angle: t * p.rotSpeed * 6.28,
                        child: Container(
                          width: 8,
                          height: 13,
                          decoration: BoxDecoration(
                            color: p.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
