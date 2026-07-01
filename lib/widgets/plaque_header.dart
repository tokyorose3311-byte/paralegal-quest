import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

class PlaqueHeader extends StatelessWidget {
  final GameColors colors;
  const PlaqueHeader({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C3157), Color(0xFF0E1C34)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.accent, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.brassBright,
                    colors.brass,
                    const Color(0xFF7A5A1D),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ).createShader(bounds),
                child: Text(
                  'Paralegal Quest',
                  textAlign: TextAlign.center,
                  style: AppText.cinzel(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.accent2,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'CIVIL LITIGATION ADVENTURE',
                  style: AppText.cinzel(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Knowledge is your best argument.',
          style: AppText.spectral(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: colors.cream.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
