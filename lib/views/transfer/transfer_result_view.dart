import 'package:flutter/material.dart';

import '../../models/transfer_result.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/transfer_result_view_model.dart';
import '../../widgets/app_button.dart';

class TransferResultView extends StatelessWidget {
  const TransferResultView({super.key, required this.viewModel});

  final TransferResultViewModel viewModel;

  void _finish(BuildContext context, TransferResultAction action) =>
      Navigator.of(context).pop(action);

  void _showDetails(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.backgroundColor,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Übertragungsdetails',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (viewModel.isPreview) ...[
              const Text(
                'Beispielwerte – es wurde keine Übertragung durchgeführt.',
              ),
              const SizedBox(height: 12),
            ],
            Text(viewModel.codeSummary, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text(viewModel.dataSummary, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text(viewModel.verificationLabel),
            for (final packet in viewModel.packetPreviews) ...[
              const SizedBox(height: 16),
              SelectableText(packet),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Schliessen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final success = viewModel.succeeded;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Daten übertragen',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (viewModel.isPreview)
                    const Center(
                      child: Text(
                        'VORSCHAU · KEINE ECHTE ÜBERTRAGUNG',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  _ResultIllustration(
                    success: success,
                    codeReadOnly: viewModel.codeReadOnly,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    viewModel.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    viewModel.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DataSummary(viewModel: viewModel),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _IconDisc(
                        icon: viewModel.codeReadOnly
                            ? Icons.layers_outlined
                            : success
                            ? Icons.verified_user_outlined
                            : Icons.shield_outlined,
                        foreground: success
                            ? const Color(0xFF756586)
                            : const Color(0xFFAA572F),
                        background: success
                            ? const Color(0xFFEDE8F1)
                            : const Color(0xFFFAEEE5),
                        size: 46,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          viewModel.verificationLabel,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    viewModel.reassurance,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    label: success ? 'Zur Übersicht' : 'Erneut versuchen',
                    onPressed: () => _finish(
                      context,
                      success
                          ? TransferResultAction.overview
                          : TransferResultAction.retry,
                    ),
                  ),
                  if (!success) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          _finish(context, TransferResultAction.overview),
                      child: const Text('Zur Übersicht'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF857995),
                    ),
                    onPressed: () => _showDetails(context),
                    child: const Text('Übertragungsdetails ansehen'),
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

class _ResultIllustration extends StatelessWidget {
  const _ResultIllustration({
    required this.success,
    required this.codeReadOnly,
  });
  final bool success;
  final bool codeReadOnly;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      child: SizedBox(
        width: 136,
        height: 128,
        child: Stack(
          children: [
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: success
                    ? const Color(0xFFF4FAFA)
                    : const Color(0xFFFCF5F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: success
                      ? const Color(0xFFB7DEDE)
                      : const Color(0xFFE5B79B),
                  width: 4,
                ),
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.priority_high_rounded,
                size: 64,
                color: success ? AppColors.fontColor : const Color(0xFFAA572F),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: _IconDisc(
                  icon: codeReadOnly
                      ? Icons.qr_code_rounded
                      : success
                      ? Icons.lock_outline_rounded
                      : Icons.refresh_rounded,
                  foreground: const Color(0xFF756586),
                  background: const Color(0xFFEDE8F1),
                  size: 52,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DataSummary extends StatelessWidget {
  const _DataSummary({required this.viewModel});
  final TransferResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final success = viewModel.succeeded;
    final categories = viewModel.categories;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF4F9F9) : const Color(0xFFFCF7F3),
        border: Border.all(
          color: success ? AppColors.pluto : const Color(0xFFEBD5C6),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.codeReadOnly
                ? 'Gelesen'
                : success
                ? 'Übernommen'
                : 'Nicht übernommen',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            Text(
              viewModel.codeReadOnly
                  ? viewModel.codeSummary
                  : 'Keine Einträge im übertragenen Datensatz.',
            ),
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const Divider(height: 24, color: Color(0xFFE0E5E5)),
            Row(
              children: [
                _categoryIcon(categories[i]),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    viewModel.categoryLabel(categories[i]),
                    style: const TextStyle(fontSize: 16, height: 1.35),
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: _IconDisc(
                    icon: success ? Icons.check_rounded : Icons.remove_rounded,
                    foreground: success
                        ? const Color(0xFF456C70)
                        : const Color(0xFFAA572F),
                    background: success
                        ? const Color(0xFFE3F1F1)
                        : const Color(0xFFF6E8DE),
                    size: 30,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryIcon(TransferDataCategory category) => switch (category) {
    TransferDataCategory.cycleAndDayData => const _IconDisc(
      icon: Icons.water_drop_outlined,
      foreground: Color(0xFF456C70),
      background: Color(0xFFE3F1F1),
    ),
    TransferDataCategory.notesAndMeasurements => const _IconDisc(
      icon: Icons.article_outlined,
      foreground: Color(0xFFC08B3B),
      background: Color(0xFFFAF0DF),
    ),
    TransferDataCategory.appointments => const _IconDisc(
      icon: Icons.calendar_today_outlined,
      foreground: Color(0xFF756586),
      background: Color(0xFFEDE8F1),
    ),
  };
}

class _IconDisc extends StatelessWidget {
  const _IconDisc({
    required this.icon,
    required this.foreground,
    required this.background,
    this.size = 44,
  });
  final IconData icon;
  final Color foreground;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: background),
    child: Icon(icon, color: foreground, size: size * 0.55),
  );
}
