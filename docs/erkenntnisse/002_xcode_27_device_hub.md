# Device Hub ersetzt die Simulator-App in Xcode 27

## Datum

2026-09-17

## Beobachtung

Nach dem Start der App war zunächst kein gewohntes Simulator-Fenster sichtbar.
Die Prüfung mit folgendem Befehl zeigte jedoch bereits ein gestartetes Gerät:

```bash
xcrun simctl list devices booted
```

Ausgabe: `iPhone 17`, iOS 26.5, Zustand `Booted`.

`open -a Simulator` fand keine App. Auch der bisher übliche Pfad
`/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app`
existierte in dieser Xcode-27-Installation nicht. Vorhanden war stattdessen
`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`.
Nach deren Öffnen wurde ein Fenster mit dem Titel `iPhone 17` und der
Geräteangabe `iPhone 17 iOS 26.5` festgestellt.

## Erkenntnis

Apple ersetzt mit Xcode 27 die bisherige Simulator-App durch Device Hub.
Die neue App bündelt die Arbeit mit simulierten und physischen Geräten.
Diese Änderung kommt mit Xcode und wird nicht durch die Anpassung unseres
Deployment Targets verursacht.

Ein gestarteter Simulator (`Booted`) bedeutet nicht automatisch, dass sein
Fenster sichtbar ist. Simulatorzustand und sichtbare Oberfläche müssen bei
der Fehlersuche getrennt geprüft werden.

Laut Apple gibt es weiterhin eine Kompaktansicht, die den Gerätebildschirm
anzeigt. Die vollständige Geräteverwaltung muss dafür nicht dauerhaft
sichtbar sein. Der Wechsel in die Kompaktansicht wurde in dieser Sitzung
nicht separat überprüft.

Quellen:

- [Apple: Meet Device Hub](https://www.youtube.com/watch?v=inLLynVCBD8)
- [Apple: Device Hub und Kompaktansicht](https://developer.apple.com/documentation/xcode/device-hub)
- [Apple: Geräte in Device Hub verwalten](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)

## Auswirkung auf das Projekt

Bei Xcode 27 wird die Simulator-Oberfläche über **Device Hub** geöffnet.
In Xcode lautet der Menüpfad **Xcode → Open Developer Tool → Device Hub**.
Für die hier vorgefundene Installation funktioniert auch:

```bash
open /Applications/Xcode.app/Contents/Applications/DeviceHub.app
```

Wenn nach `flutter run` kein Gerätefenster erscheint, zuerst mit `simctl`
prüfen, ob das gewünschte Gerät läuft, und danach Device Hub öffnen.
Allein wegen eines fehlenden Fensters ist keine Änderung am App-Code nötig.
