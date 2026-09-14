import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

const phaseColors = [
  AppColors.burntOrange,
  AppColors.pluto,
  AppColors.primary,
  AppColors.secondary,
];

class CycleRing extends StatelessWidget {
  const CycleRing({
    super.key,
    required this.cycleDay,
    required this.cycleLength,
    required this.phase,
  });
  final int cycleDay;
  final int cycleLength;
  final String phase;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Zyklustag $cycleDay von $cycleLength, $phase',
    child: ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _RingPainter(cycleDay / cycleLength),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Zyklustag', style: TextStyle(fontSize: 12)),
                Text(
                  '$cycleDay',
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  phase,
                  style: const TextStyle(
                    color: Color(0xFFB47D32),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    4,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0
                            ? AppColors.secondary
                            : const Color(0xFFE0DFE3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final colors = [
      AppColors.burntOrange,
      const Color(0xFFDEDEDE),
      AppColors.primary,
      AppColors.pluto,
      const Color(0xFFDEDEDE),
    ];
    final portions = [.32, .13, .23, .21, .11];
    var angle = -math.pi / 2;
    for (var i = 0; i < portions.length; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        rect,
        angle + .009,
        portions[i] * math.pi * 2 - .018,
        false,
        paint,
      );
      angle += portions[i] * math.pi * 2;
    }
    final markerAngle = -math.pi / 2 + progress.clamp(0, 1) * math.pi * 2;
    final marker =
        center + Offset(math.cos(markerAngle), math.sin(markerAngle)) * radius;
    canvas.drawCircle(marker, 8, Paint()..color = Colors.white);
    canvas.drawCircle(marker, 6, Paint()..color = AppColors.fontColor);
    canvas.drawCircle(marker, 2, Paint()..color = Colors.white);
    final label = TextPainter(
      text: const TextSpan(
        text: 'Heute',
        style: TextStyle(fontSize: 9, color: AppColors.fontColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(
        (marker.dx - label.width / 2).clamp(0, size.width - label.width),
        marker.dy - 22,
      ),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class PhaseLegend extends StatelessWidget {
  const PhaseLegend({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, label) in [
        'Periode',
        'Follikelphase',
        'Ovulation',
        'Lutealphase',
      ].indexed)
        Expanded(
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: phaseColors[i],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 8, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
