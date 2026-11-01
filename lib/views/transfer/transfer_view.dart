import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/transfer_result.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/transfer_result_view_model.dart';
import '../../viewmodels/transfer_send_view_model.dart';
import '../../viewmodels/transfer_receive_view_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../services/mlqr_transfer_service.dart';
import 'transfer_receive_view.dart';
import '../../widgets/transfer/transfer_illustration.dart';
import 'transfer_send_view.dart';
import 'transfer_result_view.dart';

class TransferView extends StatelessWidget {
  const TransferView({
    super.key,
    this.trackingRepository,
    this.receiveViewModelFactory,
  });

  final TrackingRepository? trackingRepository;
  final TransferReceiveViewModel Function()? receiveViewModelFactory;

  Future<void> _openSend(BuildContext context) async {
    final repository = trackingRepository;
    if (repository == null) {
      final viewModel = TransferSendViewModel.preview();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransferSendView(viewModel: viewModel),
        ),
      );
      return;
    }
    await repository.load();
    final sequence = await MlqrTransferService()
        .encodeUnencryptedSnapshotForDevelopment(
          repository.snapshot,
          transferId: 'transfer-${DateTime.now().microsecondsSinceEpoch}',
        );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransferSendView(
          viewModel: TransferSendViewModel.sequence(sequence),
        ),
      ),
    );
  }

  Future<void> _openReceive(BuildContext context) async {
    while (true) {
      if (!context.mounted) return;
      final result = await Navigator.of(context).push<TransferResult>(
        MaterialPageRoute(
          builder: (_) => TransferReceiveView(
            viewModel:
                receiveViewModelFactory?.call() ??
                TransferReceiveViewModel(repository: trackingRepository),
          ),
        ),
      );
      if (!context.mounted || result == null) return;
      final action = await Navigator.of(context).push<TransferResultAction>(
        MaterialPageRoute(
          builder: (_) => TransferResultView(
            viewModel: TransferResultViewModel(result: result),
          ),
        ),
      );
      if (action != TransferResultAction.retry) return;
    }
  }

  Future<void> _previewResult(
    BuildContext context, {
    required bool success,
  }) async {
    final result = success
        ? TransferSucceeded(
            codeCount: 12,
            importedCategories: TransferDataCategory.values.toSet(),
          )
        : TransferFailed(
            reason: TransferFailureReason.incomplete,
            receivedCodeCount: 9,
            expectedCodeCount: 12,
          );
    final action = await Navigator.of(context).push<TransferResultAction>(
      MaterialPageRoute(
        builder: (_) => TransferResultView(
          viewModel: TransferResultViewModel(result: result, isPreview: true),
        ),
      ),
    );
    if (context.mounted && action == TransferResultAction.retry) {
      _openReceive(context);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('transfer'),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Daten übertragen',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              child: TransferIllustration(),
            ),
            const Text(
              'Auf ein neues Gerät wechseln?',
              style: TextStyle(
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Übertrage deine lokal gespeicherten Zyklusdaten direkt zwischen '
              'deinen Geräten – ohne Konto und ohne Cloud.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Was möchtest du tun?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _TransferAction(
              title: 'Von diesem Gerät senden',
              description:
                  'Gespeicherte Daten als Multi-Layer-QR-Codes senden.',
              icon: Icons.mobile_screen_share_outlined,
              accent: AppColors.burntOrange,
              tint: const Color(0xFFFCF4EF),
              onTap: () => _openSend(context),
            ),
            const SizedBox(height: 10),
            _TransferAction(
              title: 'Auf diesem Gerät empfangen',
              description: 'QR-Codes mit deinem neuen Gerät scannen.',
              icon: Icons.camera_alt_outlined,
              accent: const Color(0xFF456C70),
              tint: const Color(0xFFF1F8F8),
              borderColor: AppColors.pluto,
              onTap: () => _openReceive(context),
            ),
            const SizedBox(height: 26),
            const Divider(height: 1),
            const _TransferExplanation(
              title: 'So funktioniert der Transfer',
              icon: Icons.description_outlined,
              color: Color(0xFFC99B50),
              background: Color(0xFFFAF0DD),
              text:
                  '1. Wähle auf deinem bisherigen Gerät „Von diesem Gerät senden“.\n\n'
                  '2. Wähle auf deinem neuen Gerät „Auf diesem Gerät empfangen“.\n\n'
                  '3. Scanne mit dem neuen Gerät die QR-Codes auf dem bisherigen Gerät.\n\n'
                  'Die Daten werden im aktuellen Entwicklungsmodus ohne Passphrase übertragen und erst nach vollständigem Empfang importiert.',
            ),
            const Divider(height: 1),
            const _TransferExplanation(
              title: 'Datenschutz und Verschlüsselung',
              icon: Icons.shield_outlined,
              color: Color(0xFF857995),
              background: Color(0xFFEDE8F1),
              text:
                  'Die lokale Speicherung bleibt verschlüsselt. Der aktuelle '
                  'Entwicklungsmodus überträgt die QR-Payload jedoch ohne '
                  'Passphrase. Biometrische Freigabe folgt später.',
            ),
            const Divider(height: 1),
            const SizedBox(height: 24),
            const Row(
              children: [
                _IconBadge(
                  icon: Icons.lock_outline_rounded,
                  color: Color(0xFF527F83),
                  background: Color(0xFFE4F1F1),
                  size: 36,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deine Daten bleiben auf deinen Geräten.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Ergebnisansichten testen'),
                subtitle: const Text('Vorschau ohne Datenübertragung'),
                children: [
                  TextButton.icon(
                    onPressed: () => _previewResult(context, success: true),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Erfolg ansehen'),
                  ),
                  TextButton.icon(
                    onPressed: () => _previewResult(context, success: false),
                    icon: const Icon(Icons.error_outline),
                    label: const Text('Fehler ansehen'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TransferAction extends StatelessWidget {
  const _TransferAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.onTap,
    this.borderColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color tint;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: tint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(color: borderColor ?? accent),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Row(
          children: [
            _IconBadge(
              icon: icon,
              color: accent,
              background: accent.withValues(alpha: 0.07),
              size: 58,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 27, color: accent),
          ],
        ),
      ),
    ),
  );
}

class _TransferExplanation extends StatelessWidget {
  const _TransferExplanation({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
    shape: const Border(),
    collapsedShape: const Border(),
    iconColor: AppColors.muted,
    collapsedIconColor: AppColors.muted,
    textColor: AppColors.fontColor,
    collapsedTextColor: AppColors.fontColor,
    leading: _IconBadge(
      icon: icon,
      color: color,
      background: background,
      size: 42,
    ),
    title: Text(title, style: const TextStyle(fontSize: 15, height: 1.4)),
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.muted,
        ),
      ),
    ],
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.background,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.55),
    ),
  );
}
