import 'package:flutter/material.dart';
import '../theme/text_styles.dart';

class DieWidget extends StatefulWidget {
  final int value;
  final bool rolling;

  const DieWidget({super.key, required this.value, required this.rolling});

  @override
  State<DieWidget> createState() => _DieWidgetState();
}

class _DieWidgetState extends State<DieWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.rolling) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant DieWidget old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _ctrl.repeat();
    } else if (!widget.rolling && old.rolling) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shake = widget.rolling ? (5 * ((_ctrl.value * 4) % 2 - 1)) : 0.0;
        final angle = widget.rolling
            ? (0.14 * ((_ctrl.value * 4) % 2 - 1))
            : 0.0;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFE7DDC4)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          widget.rolling ? '?' : '${widget.value}',
          style: AppText.cinzel(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A140C),
          ),
        ),
      ),
    );
  }
}
