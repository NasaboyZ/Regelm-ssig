import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/mlqr_code.dart';

/// Displays a prepared raster. All color computation belongs to the encoder.
class MlqrRasterView extends StatelessWidget {
  const MlqrRasterView({super.key, required this.raster, this.maxExtent = 400});

  final MlqrRgbRaster raster;
  final double maxExtent;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.min(constraints.maxWidth, maxExtent);
        final scale = math.min(
          availableWidth / raster.width,
          maxExtent / raster.height,
        );
        final physicalModuleSize = (scale * pixelRatio).floor();
        if (physicalModuleSize < 1) {
          return const Text('Zu wenig Platz für eine unverzerrte Darstellung.');
        }
        final moduleSize = physicalModuleSize / pixelRatio;
        return Center(
          child: CustomPaint(
            size: Size(raster.width * moduleSize, raster.height * moduleSize),
            painter: _RasterPainter(raster, moduleSize),
          ),
        );
      },
    );
  }
}

class _RasterPainter extends CustomPainter {
  const _RasterPainter(this.raster, this.moduleSize);

  final MlqrRgbRaster raster;
  final double moduleSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var row = 0; row < raster.height; row++) {
      for (var col = 0; col < raster.width; col++) {
        paint.color = Color(0xff000000 | raster.pixelAt(row, col));
        canvas.drawRect(
          Rect.fromLTWH(
            col * moduleSize,
            row * moduleSize,
            moduleSize,
            moduleSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RasterPainter oldDelegate) =>
      oldDelegate.raster != raster || oldDelegate.moduleSize != moduleSize;
}
