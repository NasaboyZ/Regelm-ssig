# MLQR: Erzeugung und Kameraempfang

## Start der separaten Testansicht

```sh
flutter run -t lib/main_mlqr_demo.dart
```

Die Demo ist nur im Debug-Modus startbar. Sie verwendet feste UTF-8-Testtexte,
keine Datenbank, Gesundheitsdaten, Kamera oder Netzwerkverbindung. Standard:
drei Nutzdatenebenen, Dummy-Ergänzung aktiviert. Die Auswahl reicht von 1 bis 15.
In der normalen App öffnet „Datentransfer → Von diesem Gerät senden“ ebenfalls
eine Vorschau mit einem echten MLQR aus drei festen Testdatenpaketen. Diese
Sendeseite zeigt noch keine Gesundheitsdaten und verwendet keine Datenbank.
Sie besitzt einen Zurück-Pfeil und „Transfer abbrechen“, die beide zur
Transferübersicht zurückführen. Der Fortschritt bleibt bei null: Es werden
weder Scan-Bestätigungen simuliert noch Codes automatisch weitergeschaltet.
„Auf diesem Gerät empfangen“ öffnet den Kamera-Scanner für diesen einzelnen
Testcode. Verschlüsselte Transfersessions und Gesundheitsdatenimport sind noch
nicht angebunden.

Im Debug-Modus gibt es in der Transferübersicht zusätzlich den aufklappbaren
Bereich „Ergebnisansichten testen“. „Erfolg ansehen“ und „Fehler ansehen“ öffnen
die gekennzeichneten Ergebnisvorschauen. Übertragungsdetails zeigen Beispielwerte;
„Zur Übersicht“ kehrt zurück. „Erneut versuchen“ öffnet einen neuen Kamerascan. Der Sendebildschirm wechselt
nicht automatisch auf einen erfundenen Erfolg.

Die Ergebnisansicht erhält einen `TransferResultViewModel` mit
`TransferCodeRead`, `TransferSucceeded` oder `TransferFailed`. Der spätere Empfänger darf Erfolg
erst nach Datenprüfung und erfolgreichem Datenbank-Commit melden; aufgeführt
werden nur die übergebenen `importedCategories`. Fehler setzen voraus, dass
keine Änderungen übernommen wurden beziehungsweise ein Rollback abgeschlossen
ist. Unvollständige, unlesbare, nicht verifizierbare und nicht speicherbare
Übertragungen haben eigene Meldungen. Die Ansicht liefert `overview` oder
`retry` als Navigationsergebnis an ihren Aufrufer zurück. Diese UI-Schnittstelle
implementiert selbst weder Datenprüfung noch Import.

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
Paper-Abbildung. Der Kamera-Decoder verwendet genau diese Geometrie.

Der Balken transportiert noch keine Nutzdatenanzahl oder Protokollversion.
Der aktuelle Decoder erkennt ausschliesslich das exakte Dummy-Muster des
Encoders und erlaubt höchstens zwei Dummys am Ende. Für das spätere
Transferprotokoll müssen Nutzdatenanzahl und Protokollversion explizit mitgeführt werden.

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

## Kamera-Scanner

Die Haupt-App öffnet unter „Datentransfer → Auf diesem Gerät empfangen“ den
Scan-Screen: Zurück-Pfeil, Livebild der rückseitigen Kamera, Scanrahmen und
Abbruch. Der Rahmen dient nur der Orientierung; ausgewertet wird das gesamte
Bild. Code, Ruhezone und Referenzbalken müssen vollständig sichtbar sein.
Die Kamera wird beim Verlassen oder beim Hintergrundwechsel freigegeben.
Bei Rückkehr startet eine neue Sitzung; verspätete Ergebnisse einer alten
Sitzung werden ignoriert. Nach 45 Sekunden ohne vollständiges Ergebnis folgt
die Fehleransicht. Ein unlesbares Einzelbild beendet den Scan nicht.

`MlqrCameraSource` kapselt die native Kamera. Das Paket `camera` liefert rohe
Farbbilder, auch wenn ein Standard-Barcode-Scanner den MLQR nicht erkennt.
BGRA8888 (iOS) und dreiplanares YUV420 (Android) werden unter Berücksichtigung
der Zeilen- und Pixelabstände in RGB umgerechnet. Es wird kein Audio
aufgenommen; Bilder werden weder als Dateien abgelegt noch hochgeladen.
Bis zu zwei Bilder pro Sekunde werden übernommen; maximal eine Dekodierung
läuft gleichzeitig in einem Isolate. Die längste Bildseite wird auf maximal
1280 Pixel reduziert, was bei sehr kleinen Modulen die Lesbarkeit begrenzt.

`MlqrDecoderService.decodeRaster(core, opticalLayerCount: ...)` rekonstruiert
mit den Teilmengensummen der Paper-Partition die Schwarzweissmatrizen.
`decodeImage(image)` sucht zunächst die Positionsmuster, berechnet die
Abbildung auf das Modulraster, liest den Referenzbalken und normalisiert die
Kanäle anhand des schwarzen Positionsmusters und der weissen Ruhezone.
Dies ist eine einfache kanalseparate Farbkorrektur, keine allgemeine
Kalibrierung für beliebige Kameras, Reflexionen oder Farbmischungen.

Der isolierte `MlqrQrAdapter` verwendet `zxing2` 0.2.4 für Lokalisierung,
Standard-QR-Dekodierung und deren Reed-Solomon-Fehlerkorrektur. Die Version ist
fixiert, weil die Bibliothek die benötigten Matrix-APIs nur intern exportiert.
Zurückgegeben werden die QR-Byte-Segmente, nicht die QR-Datencodewörter oder
ein verlustbehaftet dekodierter Text. Alle Nutzdatenebenen müssen dekodierbar
sein. Mehrdeutige Farben, fehlende Referenzen oder beschädigte Ebenen führen
zu keinem Erfolg; Standard-QR ohne Referenzbalken wird nicht akzeptiert.

### Praktische Grenze der 15 Ebenen

Die Ebenen werden bei jedem MLQR tatsächlich in den drei RGB-Kanälen gestapelt.
Die Grenze von 15 Ebenen ist deshalb keine fehlende Überlagerung, sondern eine
Grenze der optischen Trennbarkeit. Bei 15 Ebenen verwendet die Partition
`[8, 16, 32, 64, 135]`; die kleinste Teilmengensumme liegt damit nur acht
RGB-Werte auseinander. Der Kamera-Decoder akzeptiert in diesem Fall bewusst nur
eine Abweichung von höchstens `3,5` RGB-Werten zur nächstgelegenen gültigen
Summe.

Bei kleineren Transfers, zum Beispiel zwei Monaten, entstehen oft nur wenige
Chunks und Ebenen. Die Farbabstände sind dann größer: Bei drei Ebenen lautet
die Partition beispielsweise `[36, 72, 147]`, die Toleranz beträgt `17,5`.
Deshalb ist der Kameraempfang in diesem Fall stabiler. Bei einem Jahresbestand
werden dagegen häufig 15 Ebenen gefüllt. Der erzeugte Code kann mathematisch
korrekt sein und auf dem Display vollständig erscheinen, während Beleuchtung,
Display- und Kameraabweichungen, Reflexionen, Skalierung sowie Kompression die
gemessenen RGB-Werte stärker verschieben als die erlaubte Toleranz. Eine Ebene
ist dann nicht mehr eindeutig erkennbar. Der Decoder verwirft den gesamten Code;
fehlt dadurch ein Chunk, wird die Transfersession nicht importiert.

Die adaptive QR-Größenwahl begrenzt inzwischen die QR-Version auf einen
kamerafreundlicheren Zielbereich. Sie beseitigt jedoch nicht die enge Farbstufung
bei 15 Ebenen. Für eine robuste Hardwareübertragung muss die Layer-Anzahl daher
künftig adaptiv gewählt werden: bis zu 15 Ebenen bei ausreichender
Farbtrennbarkeit, ansonsten 9 oder 7 Ebenen und entsprechend mehr MLQR-Bilder.
Das erhöht die Bildanzahl, kann aber die zuverlässige Übertragung eines Jahres-
oder Mehrjahresbestands ermöglichen.

Ein `TransferCodeRead` zeigt „Multi-Layer-QR gelesen“, Ebenenzahl und in den
Details begrenzte Textvorschauen der gelesenen Pakete. Es bestätigt weder
kryptografische Authentizität noch Speicherung von Gesundheitsdaten.
`TransferSucceeded` bleibt dem späteren geprüften Datenbankimport vorbehalten.
Es gibt noch kein Sequenzprotokoll, keinen Paket-Hash/MAC und keinen Rückkanal
für Bestätigungen auf dem Sender. Die optische Lesbarkeit allein schützt nicht
vor fremden Lesern.

### Prüfung des Empfangs

```sh
flutter test test/mlqr_decoder_test.dart test/transfer_receive_test.dart test/transfer_result_test.dart test/transfer_send_test.dart test/mlqr_encoder_test.dart test/navigation_test.dart
dart analyze lib test integration_test
```

Automatisiert geprüft werden rohe Bytes für 1–15 Ebenen mit/ohne Dummys,
Lokalisierung in synthetischen gedrehten und farbveränderten Bildern,
Referenzbalken, beschädigte Ebenen, BGRA-/YUV-Strides, der Isolate-Pfad,
Navigation, Berechtigungsfehler, Timeout und Freigabe der Kamera.
Diese Prüfungen ersetzen keinen Display-zu-Kamera-Test mit echten Smartphones.
Insbesondere die zuverlässige Kameraerkennung von 15 Ebenen ist nicht belegt.

Für einen Gerätetest die App vollständig stoppen und neu bauen (`flutter run`
auf dem gewählten Smartphone). Hot Reload integriert die neue native
Kamera-Bibliothek nicht. Auf Gerät A die Sendeseite öffnen, auf Gerät B den
Empfang wählen und die Kamerafreigabe bestätigen. Erwartet werden ein Livebild,
die drei ursprünglichen Testpakete und keine importierten Gesundheitsdaten.
Anschliessend Abbruch, verweigerte Freigabe, Hintergrundwechsel und erneuten
Versuch prüfen. Der Hardwaretest steht noch aus.

Nächster Meilenstein: Messung und Verbesserung der Kamera-Lesbarkeit auf echten
Geräten, danach das authentifizierte verschlüsselte Transferprotokoll mit
Sequenz-Rekonstruktion und atomarem Datenbankimport.

Prüfstand Kamera-Screen: Die 32 betroffenen Encoder-, Decoder-, Empfangs-,
Sende-, Ergebnis- und Navigationstests bestehen nach der Layoutkorrektur
(die Empfangstests wurden gezielt erneut ausgeführt). Die neuen/geänderten
Dart-Dateien haben keine Analyzer-Befunde; projektweit verbleiben die
13 bestehenden Stilhinweise. Die Startansicht wurde gerendert und visuell
geprüft, zusätzlich bei 320 Pixeln Breite mit 1,5-facher Textgrösse getestet.

Die native iOS-Kamera-Einbindung kompiliert mit folgendem ARM64-Simulator-Build:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
```

Der allgemeine `flutter build ios --simulator --debug` scheitert in dieser
lokalen Toolchain in `debug_unpack_ios` bei der Prüfung von `arm64 x86_64`,
obwohl `lipo -info` beide Architekturen meldet. Der gezielte ARM64-Build ist
erfolgreich. Es wurden dafür keine dauerhaften Architektur-Einstellungen
im Projekt geändert. Android-Build und echte Smartphone-Scans wurden hier
noch nicht verifiziert.
