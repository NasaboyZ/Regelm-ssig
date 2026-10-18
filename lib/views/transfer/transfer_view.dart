import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/transfer/transfer_illustration.dart';

class TransferView extends StatelessWidget {
  const TransferView({super.key});

  void _showAvailability(BuildContext context, {required bool sending}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sending
                ? 'Das Senden per QR-Code ist noch nicht verfügbar.'
                : 'Das Empfangen per QR-Code ist noch nicht verfügbar.',
          ),
        ),
      );
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
              'Übertrage deine verschlüsselten Zyklusdaten direkt zwischen '
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
                  'Verschlüsselte QR-Codes auf deinem bisherigen Gerät anzeigen.',
              icon: Icons.mobile_screen_share_outlined,
              accent: AppColors.burntOrange,
              tint: const Color(0xFFFCF4EF),
              onTap: () => _showAvailability(context, sending: true),
            ),
            const SizedBox(height: 10),
            _TransferAction(
              title: 'Auf diesem Gerät empfangen',
              description: 'QR-Codes mit deinem neuen Gerät scannen.',
              icon: Icons.camera_alt_outlined,
              accent: const Color(0xFF456C70),
              tint: const Color(0xFFF1F8F8),
              borderColor: AppColors.pluto,
              onTap: () => _showAvailability(context, sending: false),
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
                  'Die Übertragung per QR-Code ist noch nicht verfügbar.',
            ),
            const Divider(height: 1),
            const _TransferExplanation(
              title: 'Datenschutz und Verschlüsselung',
              icon: Icons.shield_outlined,
              color: Color(0xFF857995),
              background: Color(0xFFEDE8F1),
              text:
                  'Deine Zyklusdaten werden lokal verschlüsselt gespeichert. '
                  'Für den Gerätewechsel ist eine direkte Übertragung über '
                  'verschlüsselte QR-Codes vorgesehen – ohne Konto, Cloud oder Server. '
                  'Diese Funktion ist noch nicht verfügbar.',
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
