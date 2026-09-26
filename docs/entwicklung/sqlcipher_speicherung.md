# Tageserfassung mit SQLCipher und AES-256-GCM testen

## Aktueller Stand

Die Tageserfassung speichert beim normalen Entwicklungsstart (`lib/main.dart`,
Debug-Modus) in einer verschlüsselten SQLite-Datenbank. Zusätzlich sind alle
fachlichen Datensätze mit AES-256-GCM verschlüsselt (Schema-Version 2). Die bisherige
separate Startdatei `lib/main_sqlcipher_debug.dart` ruft denselben Einstieg auf. Beide
verwenden dieselbe Datei und dieselben zwei Schlüssel. Dies ist ausschliesslich für
erfundene Testdaten vorgesehen: Beide Testschlüssel sind öffentlich im Quellcode
enthalten und bieten deshalb keinen Schutz für persönliche Gesundheitsdaten.

Neue Einträge werden nicht mehr in Secure Storage geschrieben. Der bisherige
Eintrag `regelmaessig.tracking.v1` bleibt unangetastet, wird aber nicht automatisch
in die Datenbank mit öffentlichem Testschlüssel importiert. Alte Secure-Storage-
Einträge werden daher in diesem Entwicklungsstand nicht angezeigt.

Passphrase, Biometrie, System-Schlüsselablage, Transfer und Wiederherstellung sind
bewusst noch nicht festgelegt. Der SQLCipher-Dienst erhält seine Schlüssel über
einen injizierten `keyProvider` für SQLCipher und einen `dataKeyProvider` für
AES-256-GCM. Er legt selbst keine Schlüssel ab. SQLCipher verschlüsselt
die Datenbankdatei; das bereits installierte Paket `cryptography` übernimmt die
zusätzliche Verschlüsselung der Datensätze mit einem separaten 32-Byte-Schlüssel.

## Starten und Einträge wieder ansehen

In VS Code die normale Startkonfiguration oder **Regelmässig – SQLCipher (nur
Testdaten)** wählen und ein Android-Gerät oder einen iOS-Simulator auswählen.
Alternativ:

```sh
flutter devices
flutter run --debug -d <geraete-id>
```

1. Die Einführung abschliessen. Das Banner **TESTDATEN** kennzeichnet diesen Start.
2. Über **Heute erfassen** einen oder mehrere Tage bearbeiten und speichern.
3. Die App vollständig beenden und im Debug-Modus erneut starten.
4. In der Erfassung oder im Kalender den gespeicherten Tag öffnen. Die Angaben
   und Markierungen müssen wieder vorhanden sein.
5. Einen Tag leeren und speichern. Beim erneuten Öffnen muss er leer bleiben;
   selbst definierte Kategorien bleiben verfügbar.

Nach dieser Umstellung einmal vollständig neu starten; Hot Reload tauscht die
bereits registrierten Abhängigkeiten nicht aus.
Die Testdatenbank ist eine andere Datenquelle als der bisherige Secure Storage.
Der Testschlüssel wird nur im `kDebugMode`-Zweig bereitgestellt. Im normalen
Profile-/Release-Start scheitert der Datenzugriff kontrolliert, solange kein
produktiver Schlüsselanbieter angebunden ist. Es gibt keinen Rückfall auf Secure
Storage oder unverschlüsseltes SQLite. Der alte Debug-Einstieg verweigert in
Profile- und Release-Builds weiterhin den Start vollständig.

## Aufbau und Verhalten

Der Datenfluss bleibt `RecordView → RecordViewModel → TrackingRepository →
TrackingStorage`. `TrackingStorage.read()` liefert einen `TrackingSnapshot`;
`write(snapshot)` speichert den vollständigen Stand. Die Storage-Adapter übernehmen
die Serialisierung. UI und Repository kennen keine SQL-Befehle oder Schlüssel.

Dateiname: `regelmaessig_tracking_debug.db`, Schema-Version: `2` (`user_version`).

| Tabelle | Spalten | Inhalt der verschlüsselten Payload |
| --- | --- | --- |
| `day_entries` | `id INTEGER PRIMARY KEY`, `payload BLOB` | Vollständiger `DayEntry`, einschliesslich Datum, Auswahlen, eigenen Werten, Messwerten, Notizen und Terminen. |
| `custom_categories` | `id INTEGER PRIMARY KEY`, `payload BLOB` | Fachliche Kategorie-ID und Name; Definitionen bleiben auch ohne Tageswerte erhalten. |
| `tracking_metadata` | `id INTEGER PRIMARY KEY`, `payload BLOB` | Ein verschlüsselter Prüfwert unter ID 1, um den Datenschlüssel auch bei leerer Datenbank zu prüfen. |

Alle Spalten sind `NOT NULL`. Die sichtbaren IDs sind technische Zeilennummern.
Sie enthalten keine Datums- oder Kategoriebezeichnungen. Die Tage werden nach
Datum sortiert gespeichert; Kategorien behalten ihre bisherige Reihenfolge.
Anzahl, Reihenfolge und ungefähre Grösse der Datensätze bleiben nach Öffnen der
SQLCipher-Ebene sichtbar.

### Zweite Ebene: AES-256-GCM

Vor der Verschlüsselung werden die Modelle als UTF-8-JSON serialisiert. JSON wird
nicht mehr als lesbare SQL-Spalte gespeichert. CBOR bleibt für den späteren
QR-Transfer vorgesehen; dieser Schritt implementiert noch keinen Transfer.

Das binäre Payload-Format lautet:

`Version (1 Byte, Wert 1) | zufällige Nonce (12 Byte) | Chiffrat | GCM-Tag (16 Byte)`

Jeder Schreibvorgang erzeugt für jede Payload eine neue Nonce. Als authentifizierte
Zusatzdaten (AAD) werden die UTF-8-Bytes des JSON-Arrays
`["regelmaessig.tracking",1,"<Tabellenname>",<technische ID>]` verwendet.
Damit scheitert auch das Verschieben einer Payload in eine andere Zeile oder
Tabelle. AES-GCM prüft die Authentizität vor der Auswertung des JSON.
Siehe [cryptography: AesGcm](https://pub.dev/documentation/cryptography/latest/cryptography/AesGcm-class.html).

Das Tagesdatum bleibt ein lokales Kalenderdatum; Terminzeitpunkte werden wie
bisher als UTC gespeichert und beim Lesen in die lokale Zeit umgewandelt.

### Transaktionen und Migration

Beim Speichern wird der vollständige Snapshot vorab verschlüsselt und dann in
einer Transaktion in beiden fachlichen Tabellen ersetzt. Vollständig geleerte
Tage entfallen. Technische IDs sind keine stabilen fachlichen Identifikatoren.
Vor dem Ersetzen werden der Prüfwert und die vorhandenen Datensätze authentifiziert
und gelesen. Auch nach einem früheren erfolgreichen Laden verhindert ein später
beschädigter Datensatz somit das Überschreiben. Bei Fehlern bleiben der bisherige
Stand und der ungespeicherte Entwurf erhalten.

Beim ersten Öffnen einer Version-1-Datenbank übernimmt die App automatisch die
bisherigen `date`-/`data_json`- und Kategorie-Werte. Sie validiert die Daten,
verschlüsselt sie und ersetzt die Tabellen innerhalb der Schema-Transaktion.
Schlägt ein Schritt fehl, bleiben Schema-Version 1 und die bisherigen Daten
bestehen. Die Migration erzeugt keine Klartext-Exportdateien. `secure_delete = ON`
bereinigt gelöschte SQLite-Inhalte. Bereits bestehende Kopien oder Backups werden
nicht nachträglich geändert; dies ist keine Zusage einer forensisch sicheren
Löschung aller früheren Dateiversionen auf dem Gerät.

Beide Schlüssel werden vor dem Anlegen oder Migrieren einer Datenbank angefordert.
Ein leerer SQLCipher-Schlüssel oder ein Datenschlüssel mit falscher Länge wird
abgewiesen. Bei einer bestehenden Version-2-Datenbank wird der Datenschlüssel
anhand des Prüfwerts geprüft. Unbekannte Schema-/Payload-Versionen, falsche
Schlüssel und beschädigte Daten führen zu einem Fehler, niemals zu automatischem
Löschen oder einem Klartext-Fallback. Fehlgeschlagenes Öffnen lässt sich wiederholen.
`close()` schliesst die Verbindung; zum erneuten Öffnen wird eine neue Instanz erstellt.

SQLCipher verschlüsselt weiterhin Datenbankseiten einschliesslich Tabellenstruktur
und Payloads. Temporäre SQL-Daten bleiben im Arbeitsspeicher. Dechiffrierte Inhalte
werden für die App im Arbeitsspeicher benötigt; sie werden nicht protokolliert oder
an Fehlermeldungen angehängt.

Die zwei Ebenen schützen nicht gegen die vollständige Kontrolle über die laufende
App oder das Betriebssystem. Die Datensatz-Authentifizierung erkennt weder das
Löschen ganzer Zeilen noch das Zurückspielen eines früheren gültigen Datenbestands.
Die öffentliche Debug-Schlüsselkonfiguration ist kein produktiver Sicherheitsnachweis.

## Die Testdatenbank ausserhalb der App anschauen

Benötigt wird eine SQLCipher-4-kompatible CLI oder ein Datenbankwerkzeug mit
SQLCipher-Unterstützung. Ein gewöhnlicher SQLite-Browser kann die verschlüsselte
Datei nicht öffnen. Für Experimente mit SQL-Änderungen eine **Kopie der
Testdatenbank** untersuchen. Zur lesenden Kontrolle neuer Einträge im
iOS-Simulator kann TablePlus direkt mit der Originaldatei verbunden werden;
Änderungen weiterhin über die App vornehmen. Die konkreten Schritte samt dem
verwendeten Originalpfad stehen in [Daten in TablePlus anschauen](tableplus_datenbank_anschauen.md).
Eine Übersicht der verwendeten Testschlüssel steht in der [README](README.md).

Eine bereits in TablePlus geöffnete Kopie ist eine Momentaufnahme. Neue Einträge
aus der App erscheinen darin erst, nachdem eine neue Kopie erstellt und geöffnet
wurde; der Refresh-Knopf allein aktualisiert keine kopierte Datei.

### iOS-Simulator

Die Debug-App vollständig stoppen. Für den aktuell gestarteten Simulator:

```sh
xcrun simctl terminate booted com.example.regelmaessig
xcrun simctl get_app_container booted com.example.regelmaessig data
```

Der zweite Befehl liefert den App-Datenordner. Darin befindet sich die Datei unter
`Documents/regelmaessig_tracking_debug.db`. Falls die App schon gestoppt war,
kann der erste Befehl melden, dass kein Prozess läuft.

Die Datei in einen Arbeitsordner kopieren. Falls daneben Dateien mit den Endungen
`-wal`, `-shm` oder `-journal` liegen, diese ebenfalls unter ihrem unveränderten
Namen in denselben Arbeitsordner kopieren. So bleibt eine eventuell noch nicht
abgeschlossene Journal-Verarbeitung möglich. Die laufende Datenbank nicht einzeln
kopieren.

### Android-Debug-Gerät oder Emulator

Die Debug-App stoppen und den Datenbankordner prüfen:

```sh
adb shell am force-stop com.example.regelmaessig
adb shell run-as com.example.regelmaessig ls databases
adb exec-out run-as com.example.regelmaessig cat databases/regelmaessig_tracking_debug.db > /tmp/regelmaessig_tracking_debug.db
```

Vorhandene Journal-/WAL-Begleitdateien entsprechend ebenfalls kopieren. `run-as`
funktioniert für die debuggable App. Diese Schritte benötigen ein eingerichtetes
Android SDK und ein verbundenes Gerät.

### Kopie entschlüsseln und abfragen

Die Kopie mit der SQLCipher-CLI öffnen:

```sh
sqlcipher /pfad/zur/kopie/regelmaessig_tracking_debug.db
```

In dieser SQLCipher-Sitzung:

```sql
PRAGMA key = 'regelmaessig-debug-test-key-v1';
PRAGMA cipher_version;
PRAGMA user_version;
SELECT name FROM sqlite_master WHERE type = 'table';
SELECT id, hex(payload) FROM day_entries ORDER BY id;
SELECT id, hex(payload) FROM custom_categories ORDER BY id;
PRAGMA integrity_check;
.quit
```

Der obige Schlüssel öffnet nur die SQLCipher-Ebene dieses Debug-Einstiegs.
Die Abfragen zeigen verschlüsselte BLOBs. Die App benötigt zusätzlich den
AES-Datenschlüssel, um die fachlichen Inhalte anzuzeigen. Für diesen Test ist keine
eigene Passphrase oder Biometrie nötig. Den Schlüssel vor der ersten Abfrage
setzen. Zum Gegencheck die Datei in einer neuen Sitzung mit falschem Schlüssel
oder über die gewöhnliche `sqlite3`-CLI öffnen und eine Tabelle abfragen: Der
Zugriff muss scheitern. Die Dateigrösse allein beweist keine Verschlüsselung.

## Automatisierte Prüfungen

```sh
flutter test
dart analyze lib test integration_test
flutter test integration_test/sqlcipher_tracking_storage_test.dart -d <ios-oder-android-geraete-id>
```

Die Unit-/Widget-Tests sichern die bisherigen Erfassungsabläufe und die
Kompatibilität mit bestehenden Secure-Storage-Daten. Die Integrationstests nutzen
das echte native SQLCipher-Plugin und eigene temporäre Testdatenbanken:

- Der normale App-Start nutzt SQLCipher ohne Storage-Override; eine über den
  Speichern-Knopf erfasste Auswahl bleibt nach Schliessen der Verbindung lesbar.
- Alle Feldtypen und mehrere Tage überleben Schliessen und erneutes Öffnen.
- Wiederholtes Speichern erzeugt keine doppelten Tage; Leeren und Kategorien
  funktionieren unabhängig voneinander.
- Ein absichtlich ausgelöster SQL-Fehler rollt Änderungen vollständig zurück und
  erhält den ungespeicherten Entwurf.
- Falsche und fehlende Schlüssel erlauben keinen Tabellenzugriff; der richtige
  Schlüssel funktioniert anschliessend weiterhin.
- Falsche AES-Schlüssel werden auch bei leeren Tabellen abgewiesen.
- Veränderte oder vertauschte Payloads sowie ein fehlender Prüfwert sperren den Zugriff.
- Fehler beim Migrieren beschädigter Version-1-Daten und während des Schemaumbaus
  lassen das ursprüngliche Schema samt Daten unverändert.
- Alle Felder und die Kategorie-Reihenfolge bleiben bei der Migration erhalten.
- SQL-Abfragen mit nur dem Datenbankschlüssel sehen ausschliesslich technische IDs
  und BLOBs, keine fachlichen Klartextspalten.
- Unbekannte Schema-Versionen werden nicht zurückgesetzt.
- Der echte Speichern-Knopf schreibt in SQLCipher; ein neuer Editor lädt die Auswahl.

Ein erfolgreicher iOS-Lauf ersetzt keinen Android-Lauf. Dafür müssen Android SDK,
Emulator oder Gerät vorhanden sein. Die produktive Freischaltung und die Migration
der alten Secure-Storage-Daten bleiben ein separater Schritt nach der
Schlüsselentscheidung. Die SQLCipher-Migration von Schema 1 auf 2 ist dagegen
Bestandteil dieses Entwicklungsstands.

Prüfstand vom 26.09.2026: 32 Unit-/Widget-Tests und 16 native Integrationstests
auf dem iPhone-17-Simulator (iOS 26.5) erfolgreich. Android wurde mangels
installiertem Android SDK nicht geprüft.
