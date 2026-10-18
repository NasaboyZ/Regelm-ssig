# MLQR-Encoder: digitale Erzeugung

## Start der separaten Testansicht

```sh
flutter run -t lib/main_mlqr_demo.dart
```

Die Demo ist nur im Debug-Modus startbar. Sie verwendet feste UTF-8-Testtexte,
keine Datenbank, Gesundheitsdaten, Kamera oder Netzwerkverbindung. Standard:
drei Nutzdatenebenen, Dummy-Ergänzung aktiviert. Die Auswahl reicht von 1 bis 15.
Die normale App und deren Transferansicht bleiben unverändert.

## Quelle und Abgrenzung

Eigenständige Implementierung nach Noppakaew, Khomkuth und Sriwilas (2018),
*Construction of multi-layered QR codes utilizing partitions of positive integers*,
Abschnitte 2.1–2.4, DOI: https://doi.org/10.22436/jmcs.018.03.06.
Das lokale Paper liegt unter `assets/refer/`. Es wurde kein Code aus der früheren
praktischen Vorarbeit übernommen. Code und diese Dokumentation wurden mit
Unterstützung von Codex erstellt.

Implementiert ist die Erzeugung, noch kein Decoder oder optischer Transfer.
Die Grenze von 15 Ebenen ist ein Implementierungslimit in Anlehnung an das Paper,
kein Nachweis für Kameratauglichkeit.

Das Format verhindert weder Fotografieren noch die Implementierung eines
anderen MLQR-Decoders. Die Testtexte sind unverschlüsselt. Vertraulichkeit muss
vor der Verwendung echter Gesundheitsdaten durch authentifizierte
Transfer-Verschlüsselung abgesichert werden, nicht durch die Unlesbarkeit mit
einer gewöhnlichen Scanner-App.

## Schnittstelle und Berechnung

`MlqrEncoderService.encode(List<Uint8List>, {padWithDummies: true})` erzeugt pro
Paket eine QR-Ebene. Es findet keine automatische Paketaufteilung statt.
Binärdaten werden direkt im Byte-Modus kodiert, ohne Base64 oder Textumwandlung.
Leere Byte-Pakete sind erlaubt; eine leere Paketliste ist ungültig.

Die reine Dart-Bibliothek `qr` übernimmt die Standard-QR-Kodierung inklusive
Reed-Solomon-Fehlerkorrektur M. Alle Ebenen erhalten die kleinste gemeinsam
passende QR-Version (1–40). Jede Ebene darf ihre eigene QR-Maske verwenden.
Zu grosse Pakete werden als `FormatException` zurückgewiesen.

Für k Nutzdatenebenen gilt l = ceil(k/3), s = floor(255/(2^l−1)). Die ersten
l−1 Gewichte sind s·2^i; das letzte ergänzt auf 255. Für l=1 gilt [255].
Dies ist eine gemeinsame Partition für alle drei Kanäle.

Die Ebenenreihenfolge ist fest: Rot, Grün, Blau, jeweils aufsteigende Gewichte.
Beispiel k=7: R36, R72, R147, G36, G72, G147, B36. Das entspricht Beispiel 3.1
des Papers. Beispiel 2.4 enthält beim letzten Farbvektor offenbar einen
Druckfehler; seine rote Wiederholung wird nicht übernommen.

Standardmässig werden Dummys bis zu 3·l Ebenen angehängt. Sie sind weiss bis
auf die drei 7×7-Positionsmuster. Sie sind keine dekodierbaren Nutzdaten-QRs.
Sie bekommen die noch freien Gewichte; bei sieben Paketen also B72 und B147.
Mit `padWithDummies: false` entsteht die ungepolsterte Paper-Variante.

`QrModuleMatrix` verwendet true für Schwarz. Im Encoder trägt dagegen nur ein
weisses Modul sein Gewicht zum Kanal bei. Gewichte werden addiert, ohne
Transparenz, Mittelwertbildung oder Farbraumtransformation.

`compose` bietet dieselbe Überlagerung für bereits vorhandene binäre Matrizen.
Alle Matrizen müssen quadratisch und gleich gross sein. Für Dummy-Ergänzung
wird ein Raster ab 21 Modulen vorausgesetzt. Dieser Einstieg prüft keine
QR-Syntax und liefert deshalb keine QR-Versionsnummer.

## Ergebnis und Darstellung

`MlqrCode` enthält das unveränderte Kernraster, ein dekoriertes Anzeigeraster,
QR-Version, Nutzdatenanzahl, Partition sowie Ebenen mit Matrix, Kanal, Gewicht
und Paketindex. Ein fehlender Paketindex kennzeichnet einen Dummy. Listen sind
unveränderlich; RGB-Pixel sind als 0xRRGGBB gespeichert.

Der Kern beginnt im Anzeigeraster bei Spalte 5 und Zeile 4 (nullbasiert).
Seine Ruhezone ist ringsum vier Module breit. Links ausserhalb der Ruhezone
liegt in Spalte 0 der ein Modul breite Referenzbalken, beginnend auf Höhe der
ersten Kernzeile. Seine Farben wechseln Grün, Blau, Rot; die Kästchenzahl
entspricht allen optischen Ebenen inklusive Dummys. Das ist eine ausdrücklich
festgelegte Layoutvariante mit intakter QR-Ruhezone, keine pixelgenaue Kopie der
Paper-Abbildung. Ein späterer Decoder muss diese Geometrie kennen.

Der Balken transportiert noch keine Nutzdatenanzahl oder Protokollversion.
Diese Angaben müssen später im Transferprotokoll enthalten sein, damit der
Empfänger Dummys sicher von Nutzdaten unterscheiden kann.

`MlqrRasterView` zeichnet vorbereitete Pixel ohne Kantenglättung und mit
ganzzahliger physischer Modulgrösse. Der ViewModel koordiniert Testdaten und
Encoder. Die Berechnung selbst importiert weder Flutter noch UI-Code.

## Prüfung

```sh
flutter test test/mlqr_encoder_test.dart test/mlqr_demo_test.dart
dart analyze lib test integration_test
```

Die Tests prüfen die Paper-Partitionen, eindeutige Teilmengensummen,
handberechnete Farbwerte, das Sieben-Ebenen-Beispiel, Dummys und Referenzbalken,
gemeinsame QR-Versionen, rohe Bytes und Kapazitätsgrenzen. Die Anzeige lässt
sich zusätzlich als temporäres Bild für die Sichtprüfung erfassen:

```sh
MLQR_PREVIEW_PATH=/tmp/mlqr-preview.png flutter test test/mlqr_demo_test.dart
```

Für lesbaren Text statt der Flutter-Testschrift kann zusätzlich
`MLQR_PREVIEW_FONT` auf eine lokal vorhandene TTF-Schrift gesetzt werden.

Prüfstand 18.10.2026: Alle 13 neuen MLQR-Tests bestehen. Die neuen Dart-Dateien
sind ohne Analyzer-Befund; projektweit bleiben 13 vorhandene Stilhinweise.
Die gesamte Unit-/Widget-Suite liefert 53 erfolgreiche und vier fehlgeschlagene
Tests. Dieselben vier Fehler wurden separat am unveränderten Git-Stand
`db7eb7b` reproduziert: zwei Home-Tests und der Startup-Test laufen bei
`pumpAndSettle` in einen Timeout; der alte JSON-Speichertest erwartet weiterhin
Schema 1 statt des aktuellen Schema 2. Sie wurden in dieser Änderung nicht
bearbeitet. Die Debug-Darstellung wurde als Widget gerendert und visuell
geprüft; ein Hardware-Kameratest ist noch nicht erfolgt.

Nächster Meilenstein: digitale Entschichtung und Rückgewinnung der ursprünglichen
Bytes über einen normalen QR-Decoder. Erst danach folgen Kamera-Lokalisierung,
Farbkalibrierung und der vollständige verschlüsselte Transfer.
