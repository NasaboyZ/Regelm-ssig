# iOS Deployment Target und Simulator-Build

## Datum

2026-09-17

## Beobachtung

Beim Start auf dem iPhone-17-Simulator brach der Build mit folgender Meldung ab:

```text
The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0,
but the range of supported deployment target versions is 15.0 to 27.0.x.
```

Im [Podfile](../../ios/Podfile) waren die Plattform und die Pod-Build-Einstellungen
bereits auf iOS 15.0 gesetzt. Im
[Runner-Projekt](../../ios/Runner.xcodeproj/project.pbxproj) stand das Deployment
Target für Debug, Profile und Release hingegen noch auf 13.0.

## Erkenntnis

Eine Anpassung des Podfiles allein ändert nicht das Deployment Target des
Runner-Projekts. Beide Konfigurationen müssen zur eingesetzten Xcode-Version
und zu den Anforderungen der Abhängigkeiten passen.

Das Deployment Target bezeichnet die minimale unterstützte iOS-Version der
App. Es ist nicht die iOS-Version des ausgewählten Simulators.

## Auswirkung auf das Projekt

Die drei Einträge `IPHONEOS_DEPLOYMENT_TARGET` im Runner-Projekt wurden auf
`15.0` angehoben. Damit setzt das Projekt mindestens iOS 15 voraus.

Die Projektdatei bestand `plutil -lint`. Der generische Prüfbuild mit
`flutter build ios --simulator --debug --no-pub` scheiterte anschliessend an
einem separaten Architekturfehler im Flutter-Schritt `debug_unpack_ios`:
Die Kombination `arm64 x86_64` wurde beanstandet, obwohl `lipo` beide
Architekturen im Framework auflistete. Die Ursache dieses Folgefehlers ist
noch nicht geklärt.

Ein gezielter ARM64-Simulator-Build war dagegen erfolgreich:

```bash
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

Ergebnis: `BUILD SUCCEEDED`. Das bestätigt den ARM64-Simulator-Build;
ein erfolgreicher generischer Flutter-Build ist damit noch nicht belegt.
Die Architektur wurde nur für diesen Prüfaufruf eingeschränkt, nicht dauerhaft
in der Projektkonfiguration.
