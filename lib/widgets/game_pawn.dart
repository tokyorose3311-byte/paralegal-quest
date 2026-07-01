import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player.dart';

class GamePawn extends StatefulWidget {
  final GamePlayer player;
  final bool isTurn;
  final bool hopping;
  final double size;

  const GamePawn({
    super.key,
    required this.player,
    required this.isTurn,
    required this.hopping,
    this.size = 26,
  });

  @override
  State<GamePawn> createState() => _GamePawnState();
}

class _GamePawnState extends State<GamePawn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _hopCtrl;
  late final Animation<double> _hopAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _hopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _hopAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_hopCtrl);
  }

  @override
  void didUpdateWidget(covariant GamePawn old) {
    super.didUpdateWidget(old);
    if (widget.hopping && !old.hopping) {
      _hopCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _hopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _hopCtrl]),
      builder: (context, _) {
        final glow = widget.isTurn ? (0.5 + 0.5 * _pulseCtrl.value) : 0.35;
        // hop: rise then settle (parabola-ish via sin curve using value 0..1)
        final t = _hopAnim.value;
        final hopLift = widget.hopping
            ? (-14.0 * (t < 0.5 ? t * 2 : (1 - t) * 2))
            : 0.0;
        final scale = widget.hopping
            ? (1.0 + 0.18 * (t < 0.5 ? t * 2 : (1 - t) * 2))
            : 1.0;
        return Transform.translate(
          offset: Offset(0, hopLift),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.player.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: widget.player.color.withValues(alpha: glow),
                    blurRadius: widget.isTurn ? 14 : 8,
                    spreadRadius: widget.isTurn ? 3 : 1,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text(
                    widget.player.tag,
                    style: GoogleFonts.cinzel(
                      fontWeight: FontWeight.w700,
                      color: widget.player.textColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
