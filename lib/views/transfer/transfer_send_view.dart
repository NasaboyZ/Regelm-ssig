import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/mlqr_code.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/transfer_send_view_model.dart';
import '../../widgets/transfer/mlqr_raster_view.dart';

class TransferSendView extends StatefulWidget {
  const TransferSendView({super.key, required this.viewModel});

  final TransferSendViewModel viewModel;

  @override
  State<TransferSendView> createState() => _TransferSendViewState();
}

class _TransferSendViewState extends State<TransferSendView> {
  Timer? _timer;
  int _index = 0;

  TransferSendViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    if (viewModel.codeCount > 1) {
      _timer = Timer.periodic(viewModel.codeInterval, (_) {
        if (mounted) {
          setState(() => _index = (_index + 1) % viewModel.codeCount);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.backgroundColor,
    appBar: AppBar(
      backgroundColor: AppColors.backgroundColor,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.fontColor,
      elevation: 0,
      centerTitle: true,
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      title: const Text(
        'QR-Codes zeigen',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÜBERTRAGUNG · ENTWICKLUNGSMODUS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Code ${_index + 1} von ${viewModel.codeCount}',
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fontColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'QR-Code Sceenen um '
                  'Gesundheitsdaten zu übertragen.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                if (!viewModel.isPreview) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${viewModel.codeCount} Bilder · ${viewModel.chunkCount} Chunks · '
                    'bis zu ${viewModel.maxLayersPerCode} Ebenen · '
                    'QR-Version ${viewModel.maxQrVersion}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _CodeCard(
                  code: viewModel.codeAt(_index),
                  label: '${_index + 1} / ${viewModel.codeCount}',
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: viewModel.progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.burntOrange,
                  backgroundColor: const Color(0xFFF0E0D8),
                  semanticsLabel:
                      'Bestätigte QR-Codes: ${viewModel.confirmedCodeCount} '
                      'von ${viewModel.codeCount}',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      color: AppColors.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        viewModel.isPreview
                            ? '${viewModel.confirmedCodeCount} Codes bestätigt · Testvorschau'
                            : '${viewModel.confirmedCodeCount} Codes bestätigt · ohne Passphrase',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _PositionHint(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA84416),
                      side: const BorderSide(color: Color(0xFFA84416)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Transfer abbrechen',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
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

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.label});

  final MlqrCode code;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBF6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D5769),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Multi-Layer-QR-Code mit Transferdaten',
              image: true,
              child: MlqrRasterView(raster: code.displayRaster),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PositionHint extends StatelessWidget {
  const _PositionHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F8F8),
      border: Border.all(color: AppColors.pluto),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFE3F1F1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.stay_current_portrait_outlined,
            size: 32,
            color: Color(0xFF456C70),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Geräte ruhig halten',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Der Code muss auf dem neuen Gerät vollständig '
                'im Kamerabild sichtbar sein.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
