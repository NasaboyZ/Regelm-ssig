import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Decorative vector artwork; the QR-like marks contain no transfer data.
class TransferIllustration extends StatelessWidget {
  const TransferIllustration({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 300 / 160,
      child: CustomPaint(painter: _TransferPainter()),
    ),
  );
}

class _TransferPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 160);

    void phone(double x, Color color) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 7, 78, 143),
        const Radius.circular(12),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.07));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 24, 10, 30, 7),
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );
    }

    phone(12, AppColors.primary);
    phone(210, const Color(0xFFDEC9A6));

    final arrowPaint = Paint()
      ..color = AppColors.burntOrange
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    canvas.drawPath(
      Path()
        ..moveTo(112, 29)
        ..quadraticBezierTo(156, 0, 198, 32),
      arrowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(193, 21)
        ..lineTo(198, 32)
        ..lineTo(187, 32),
      arrowPaint,
    );

    void card(double x, double y, double angle, Color color, Color ink) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, -25, 50, 50),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      final mark = Paint()..color = ink;
      for (final origin in [
        const Offset(-13, -13),
        const Offset(2, -13),
        const Offset(-13, 2),
      ]) {
        canvas.drawRect(
          origin & const Size(10, 10),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7,
        );
        canvas.drawRect((origin + const Offset(3, 3)) & const Size(4, 4), mark);
      }
      for (final offset in [
        const Offset(2, 2),
        const Offset(8, 2),
        const Offset(5, 5),
        const Offset(11, 8),
        const Offset(2, 11),
        const Offset(8, 14),
        const Offset(14, 2),
      ]) {
        canvas.drawRect(offset & const Size(3, 3), mark);
      }
      canvas.restore();
    }

    card(105, 72, -0.23, const Color(0xFFE3DDEA), const Color(0xFF7E748D));
    card(151, 70, -0.12, const Color(0xFFF8E6BF), const Color(0xFF89806B));
    card(198, 74, 0.12, const Color(0xFFD4ECEB), const Color(0xFF456C70));

    final line = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(103, 130), const Offset(128, 130), line);
    canvas.drawLine(const Offset(172, 130), const Offset(197, 130), line);
    final gold = const Color(0xFFDCB97B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(143, 115, 14, 18),
        const Radius.circular(8),
      ),
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(139, 124, 22, 18),
        const Radius.circular(4),
      ),
      Paint()..color = gold,
    );
    canvas.drawCircle(const Offset(150, 132), 2, Paint()..color = Colors.white);
    canvas.drawLine(
      const Offset(150, 132),
      const Offset(150, 136),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TransferPainter oldDelegate) => false;
}
