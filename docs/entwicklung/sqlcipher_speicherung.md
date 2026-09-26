# Tageserfassung mit SQLCipher testen

## Aktueller Stand

Die Tageserfassung kann über einen eigenen Debug-Einstieg in einer verschlüsselten
SQLite-Datenbank gespeichert werden. Dieser Einstieg ist ausschliesslich für
erfundene Testdaten vorgesehen: Sein Schlüssel ist öffentlich im Quellcode
enthalten und bietet deshalb keinen Schutz für persönliche Gesundheitsdaten.

Die reguläre App (`lib/main.dart`) verwendet weiterhin den bisherigen
Secure-Storage-Eintrag `regelmaessig.tracking.v1`. Dessen JSON-Format und Inhalt
bleiben erhalten. Es erfolgt noch keine Migration in die Datenbank.

Passphrase, Biometrie, System-Schlüsselablage, Transfer und Wiederherstellung sind
bewusst noch nicht festgelegt. Der SQLCipher-Dienst nimmt seinen Schlüssel über
einen injizierten `keyProvider` entgegen. Er legt selbst keinen Schlüssel ab.
`cryptography` wird für diese Speicherung nicht zusätzlich benötigt: Die
Datenbankverschlüsselung übernimmt SQLCipher.

## Starten und Einträge wieder ansehen

In VS Code die Startkonfiguration **Regelmässig – SQLCipher (nur Testdaten)** wählen
und ein Android-Gerät oder einen iOS-Simulator auswählen. Alternativ:

```sh
flutter devices
flutter run --debug -t lib/main_sqlcipher_debug.dart -d <geraete-id>
```

1. Die Einführung abschliessen. Das Banner **TESTDATEN** kennzeichnet diesen Start.
2. Über **Heute erfassen** einen oder mehrere Tage bearbeiten und speichern.
3. Die App vollständig beenden und mit demselben Debug-Einstieg erneut starten.
4. In der Erfassung oder im Kalender den gespeicherten Tag öffnen. Die Angaben
   und Markierungen müssen wieder vorhanden sein.
5. Einen Tag leeren und speichern. Beim erneuten Öffnen muss er leer bleiben;
   selbst definierte Kategorien bleiben verfügbar.

Zwischen regulärem Start und SQLCipher-Start immer vollständig neu starten;
Hot Reload tauscht die bereits registrierten Abhängigkeiten nicht aus.
Die Testdatenbank ist eine andere Datenquelle als der bisherige Secure Storage.
Der Debug-Einstieg verweigert in Profile- und Release-Builds den Start; die
Testschlüssel-Konfiguration steht ausschliesslich im `kDebugMode`-Zweig.

## Aufbau und Verhalten

Der Datenfluss bleibt `RecordView → RecordViewModel → TrackingRepository →
TrackingStorage`. `TrackingStorage.read()` liefert einen `TrackingSnapshot`;
`write(snapshot)` speichert den vollständigen Stand. Die Storage-Adapter übernehmen
die Serialisierung. UI und Repository kennen keine SQL-Befehle oder Schlüssel.

Dateiname: `regelmaessig_tracking_debug.db`, Schema-Version: `1` (`user_version`).

| Tabelle | Spalten | Zweck |
| --- | --- | --- |
| `day_entries` | `date TEXT PRIMARY KEY`, `data_json TEXT` | Ein Eintrag je lokalem Datum im Format `YYYY-MM-DD`; JSON enthält alle Angaben einschliesslich Messwerten und Terminen. |
| `custom_categories` | `id TEXT PRIMARY KEY`, `name TEXT` | Eigene Kategorien, auch wenn noch kein Tag Werte dafür enthält. |

Alle Spalten sind `NOT NULL`. Die JSON-Struktur entspricht `DayEntry.toJson()`.
Das Tagesdatum bleibt ein lokales Kalenderdatum; Terminzeitpunkte werden wie
bisher als UTC gespeichert und beim Lesen in die lokale Zeit umgewandelt.

Ein Speichervorgang aktualisiert die Tageszeilen und Kategorien in einer einzigen
Transaktion. Nicht mehr enthaltene Tage werden entfernt. Ein Fehler rollt alle
Änderungen zurück; Repository und Entwurf werden nicht als gespeichert markiert.
Auch das Lesen beider Tabellen erfolgt in einer gemeinsamen Transaktion.

Ein fehlender oder leerer Schlüssel wird abgewiesen. Öffnungsfehler, beschädigte
Daten und unbekannte Schema-Versionen führen niemals zu einem automatischen
Löschen oder einem unverschlüsselten Ersatz. Fehlgeschlagenes Öffnen lässt sich
wiederholen. `close()` schliesst die Verbindung endgültig; zum erneuten Öffnen
wird eine neue Storage-Instanz erstellt.

SQLCipher verschlüsselt Datenbankseiten, einschliesslich Tabellenstruktur und
JSON-Inhalten. Temporäre SQL-Daten werden im Arbeitsspeicher gehalten. Die App
aktiviert keine SQL-Debug-Logs und gibt weder Schlüssel noch Einträge aus.
Siehe [SQLCipher Security Design](https://www.zetetic.net/sqlcipher/design/) und
[Flutter-Plugin](https://pub.dev/packages/sqflite_sqlcipher/versions/3.4.1).

## Die Testdatenbank ausserhalb der App anschauen

Benötigt wird eine SQLCipher-4-kompatible CLI oder ein Datenbankwerkzeug mit
SQLCipher-Unterstützung. Ein gewöhnlicher SQLite-Browser kann die verschlüsselte
Datei nicht öffnen. Immer eine **Kopie der Testdatenbank** untersuchen.

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
SELECT date, data_json FROM day_entries ORDER BY date;
SELECT id, name FROM custom_categories ORDER BY rowid;
PRAGMA integrity_check;
.quit
```

Der obige Schlüssel gilt nur für diesen Debug-Einstieg. Für diesen Test ist keine
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

- Alle Feldtypen und mehrere Tage überleben Schliessen und erneutes Öffnen.
- Wiederholtes Speichern erzeugt keine doppelten Tage; Leeren und Kategorien
  funktionieren unabhängig voneinander.
- Ein absichtlich ausgelöster SQL-Fehler rollt Änderungen vollständig zurück und
  erhält den ungespeicherten Entwurf.
- Falsche und fehlende Schlüssel erlauben keinen Tabellenzugriff; der richtige
  Schlüssel funktioniert anschliessend weiterhin.
- Beschädigtes JSON wird nicht durch einen leeren Stand überschrieben.
- Der echte Speichern-Knopf schreibt in SQLCipher; ein neuer Editor lädt die Auswahl.

Ein erfolgreicher iOS-Lauf ersetzt keinen Android-Lauf. Dafür müssen Android SDK,
Emulator oder Gerät vorhanden sein. Die produktive Freischaltung und die Migration
der bisherigen Daten bleiben ein separater Schritt nach der Schlüsselentscheidung.
