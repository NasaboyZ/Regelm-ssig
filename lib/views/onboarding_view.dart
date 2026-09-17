import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../viewmodels/onboarding_view_model.dart';

const _ink = Color(0xFF1E1C1A);
const _muted = Color(0xFF605C58);
const _accent = Color(0xFFC8733D);
const _border = Color(0xFFE5E3E1);

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key, required this.viewModel});

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => PopScope(
      canPop: viewModel.stepNumber == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) viewModel.back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.backgroundColor,
        ),
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      const Text('Regelmässig', style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: _ink,
                      )),
                      const SizedBox(height: 12),
                      Semantics(
                        label: 'Schritt ${viewModel.stepNumber} von ${viewModel.stepCount}',
                        child: Column(
                          children: [
                            Row(children: List.generate(viewModel.stepCount, (index) => Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: index < viewModel.stepCount - 1 ? 8 : 0),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: index < viewModel.stepNumber ? const Color(0xFFDE7541) : _border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ))),
                            const SizedBox(height: 12),
                            ExcludeSemantics(child: Text(
                              'SCHRITT ${viewModel.stepNumber} VON ${viewModel.stepCount}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: _muted),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Expanded(
                        child: SingleChildScrollView(
                          key: ValueKey(viewModel.step),
                          child: SizedBox(
                            width: double.infinity,
                            child: switch (viewModel.step) {
                              OnboardingStep.cycle => const _CyclePage(),
                              OnboardingStep.privacy => const _PrivacyPage(),
                              OnboardingStep.transfer => const _TransferPage(),
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: viewModel.next,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(viewModel.buttonLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Intro extends StatelessWidget {
  const _Intro(this.title, this.description);
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 30, height: 1.23, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.6))),
      const SizedBox(height: 22),
      Text(description, style: const TextStyle(fontSize: 14, height: 1.5, color: _muted)),
      const SizedBox(height: 26),
    ],
  );
}

class _Item extends StatelessWidget {
  const _Item(this.text, {this.number});
  final String text;
  final int? number;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, color: number == null ? const Color(0xFFE4F3EA) : _border),
        child: number == null
          ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF59A68D))
          : Center(child: Text('$number', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.25, fontWeight: FontWeight.w600, color: number == null ? _ink : _muted))),
    ]),
  );
}

class _CyclePage extends StatelessWidget {
  const _CyclePage();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Intro('Dein Zyklus.\nDeine Daten.', 'Regelmässig ist eine private Zyklus-App. Du kannst deine Periode erfassen und beobachten, wie du dich im Verlauf deines Zyklus fühlst.'),
      const _Item('Periode und Zyklus erfassen'),
      const _Item('Stimmung, Schmerzen und Symptome dokumentieren'),
      const _Item('Temperatur, Gewicht und Notizen festhalten'),
      const SizedBox(height: 22),
      for (final item in const [
        (Icons.water_drop_outlined, 'Periode', 'Erfasse deine Periode und behalte deinen Zyklus im Blick.'),
        (Icons.sentiment_satisfied_alt_outlined, 'Stimmung', 'Halte fest, wie du dich im Verlauf deines Zyklus fühlst.'),
        (Icons.monitor_heart_outlined, 'Schmerzen', 'Dokumentiere Schmerzen und weitere Symptome.'),
        (Icons.balance_outlined, 'Temperatur & Gewicht', 'Halte Temperatur, Gewicht und ergänzende Notizen fest.'),
      ]) Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(item.$3),
                ]),
              )),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(item.$1, size: 20, color: const Color(0xFFDD7036)),
                const SizedBox(width: 12),
                Expanded(child: Text(item.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink))),
                const Icon(Icons.chevron_right, color: _muted, size: 20),
              ]),
            ),
          ),
        ),
      ),
    ],
  );
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Intro('Lokal gespeichert.\nImmer verschlüsselt.', 'Jeder Eintrag wird vom ersten Moment an verschlüsselt auf deinem Gerät gespeichert.'),
      const _Item('Kein Konto erforderlich'),
      const _Item('Keine Speicherung in einer Cloud'),
      const _Item('Keine Weitergabe an Drittanbieter'),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(24)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lokal & Verschlüsselt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
          SizedBox(height: 6),
          Text('Deine Gesundheitsdaten werden nicht automatisch hochgeladen oder weitergegeben. Sie bleiben absolut geschützt.', style: TextStyle(fontSize: 12, height: 1.3, color: _muted)),
        ]),
      ),
      const SizedBox(height: 20),
      const _Notice(
        icon: Icons.lock_outline, background: Color(0xFFF5F2FF), border: Color(0xFFDED2FF), foreground: Color(0xFF5900D9),
        text: 'Deine Passphrase schützt den Zugriff auf deine gespeicherten Daten.',
      ),
    ],
  );
}

class _TransferPage extends StatelessWidget {
  const _TransferPage();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Intro('Auch beim Transfer\nverschlüsselt.', 'Beim Gerätewechsel werden deine Daten verschlüsselt als Multi-Layer-QR-Code direkt auf dein neues Gerät übertragen.'),
      _Item('Transfer mit Passphrase starten', number: 1),
      _Item('QR-Code mit dem neuen Gerät scannen', number: 2),
      _Item('Daten auf dem neuen Gerät wiederherstellen', number: 3),
      SizedBox(height: 6),
      _Notice(
        icon: Icons.info_outline, background: Color(0xFFFFF4C8), border: Color(0xFFFFA000), foreground: Color(0xFF853508),
        title: 'Keine Cloud. Kein Zwischenserver.',
        text: 'Keine unverschlüsselten Gesundheitsdaten im Transfer.',
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.background, required this.border, required this.foreground, required this.text, this.title});
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: background, border: Border.all(color: border), borderRadius: BorderRadius.circular(16)),
    child: Row(crossAxisAlignment: title == null ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
      Icon(icon, color: title == null ? const Color(0xFF883CFF) : border, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: foreground)),
          const SizedBox(height: 3),
        ],
        Text(text, style: TextStyle(fontSize: title == null ? 13 : 12, height: 1.35, color: foreground)),
      ])),
    ]),
  );
}
