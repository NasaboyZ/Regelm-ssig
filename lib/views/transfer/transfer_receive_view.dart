import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../models/transfer_result.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/transfer_receive_view_model.dart';

class TransferReceiveView extends StatefulWidget {
  const TransferReceiveView({super.key, this.viewModel});
  final TransferReceiveViewModel? viewModel;

  @override
  State<TransferReceiveView> createState() => _TransferReceiveViewState();
}

class _TransferReceiveViewState extends State<TransferReceiveView>
    with WidgetsBindingObserver {
  late final TransferReceiveViewModel _model;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _model = widget.viewModel ?? TransferReceiveViewModel();
    WidgetsBinding.instance.addObserver(this);
    _model.addListener(_changed);
    _model.resume();
  }

  void _changed() {
    if (!mounted) return;
    final result = _model.result;
    if (result != null && !_finished) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop<TransferResult>(result);
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _model.resume();
    } else {
      _model.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.removeListener(_changed);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _model.camera;
    final ready =
        !_model.initializing &&
        !_model.paused &&
        camera != null &&
        camera.value.isInitialized;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('QR-Code scannen'),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Multi-Layer-QR scannen',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Richte die Kamera auf den farbigen Code des bisherigen '
                    'Geräts. Der ganze Code und der schmale Farbbalken links '
                    'müssen sichtbar sein.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: const Color(0xFF172C30),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (ready)
                              Center(child: CameraPreview(camera))
                            else
                              Center(
                                child: _model.paused
                                    ? const Icon(
                                        Icons.videocam_off_outlined,
                                        color: Colors.white,
                                        size: 48,
                                      )
                                    : const CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                              ),
                            const IgnorePointer(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _ScanFramePainter(),
                                ),
                              ),
                            ),
                            if (ready)
                              const Positioned(
                                left: 16,
                                right: 16,
                                bottom: 20,
                                child: Text(
                                  'Code mit Farbbalken im Rahmen halten',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 5,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _model.paused
                        ? 'Kamera pausiert'
                        : _model.initializing
                        ? 'Kamera wird geöffnet …'
                        : 'Geräte ruhig halten',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Die QR-Codes werden gesammelt und erst nach vollständiger '
                    'Prüfung in die lokale Datenbank übernommen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.burntOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Empfangen abbrechen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An aiming aid only: the decoder searches the entire original camera frame.
class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.82;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    final paint = Paint()
      ..color = const Color(0xFFB7DEDE)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const arm = 28.0;
    for (final (x, y, dx, dy) in [
      (rect.left, rect.top, 1.0, 1.0),
      (rect.right, rect.top, -1.0, 1.0),
      (rect.left, rect.bottom, 1.0, -1.0),
      (rect.right, rect.bottom, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * arm)
          ..lineTo(x, y)
          ..lineTo(x + dx * arm, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) => false;
}
