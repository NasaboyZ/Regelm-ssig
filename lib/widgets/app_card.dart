import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppCardVariant {
  /// Große Inhaltsbereiche, etwa Zyklus oder Auswertungen.
  standard,

  /// Kleine Karten, etwa Temperatur oder Gewicht.
  compact,

  /// Farbige Kacheln, etwa Symptome oder Stimmung.
  tinted,
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.standard,
    this.padding,
    this.color,
    this.borderRadius,
    this.border,
  });

  final Widget child;
  final AppCardVariant variant;

  /// Optionale Anpassungen haben Vorrang vor den Vorgaben der Variante.
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;

  /// Mit Border.all(style: BorderStyle.none) die Umrandung entfernen.
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final isTinted = variant == AppCardVariant.tinted;
    final defaultPadding = switch (variant) {
      AppCardVariant.standard => const EdgeInsets.all(16),
      AppCardVariant.compact => const EdgeInsets.all(12),
      AppCardVariant.tinted => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
    };

    return Container(
      padding: padding ?? defaultPadding,
      decoration: BoxDecoration(
        color:
            color ??
            (isTinted
                ? AppColors.pluto.withValues(alpha: 0.45)
                : AppColors.backgroundColor),
        borderRadius:
            borderRadius ??
            BorderRadius.circular(variant == AppCardVariant.standard ? 20 : 16),
        border:
            border ??
            (isTinted
                ? null
                : Border.all(
                    color: AppColors.fontColor.withValues(alpha: 0.08),
                  )),
      ),
      child: child,
    );
  }
}
