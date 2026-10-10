# 004: Verschlüsselung an einer echten Flutter-Datenbank geprüft

## Datum und Fragestellung

02.10.2026. Kann jemand eine kopierte Regelmässig-Datenbank lesen, und welche
Aussage über den Schutz lässt sich tatsächlich belegen?

**Ergebnis:** Die mit dem echten Flutter-Speicherdienst erzeugte Testdatenbank
liess sich ohne passenden SQLCipher-Schlüssel nicht abfragen. Mit diesem
Schlüssel waren Tabellen, technische IDs und AES-GCM-Payloads sichtbar. Mit
**beiden öffentlichen Debug-Schlüsseln** liessen sich alle künstlichen Inhalte
unabhängig in Python entschlüsseln. Das ist erwartetes Verhalten und kein
Brechen der Verschlüsselung. Der derzeitige Debug-Build bietet wegen dieser
öffentlichen Schlüssel keinen belastbaren Schutz für persönliche Daten.

Der separate sqlmap-Versuch griff ausschliesslich einen absichtlich verwundbaren
lokalen Laborserver an. **Er weist keine SQL-Injection in der Flutter-App nach.**

## Versuchsaufbau und Angreiferwissen

Der [Baseline-Beleg](belege/verschluesselungspruefung/20261002T142700Z/baseline.json)
enthält Git-Stand, anfänglichen Arbeitsbaumzustand und Quellcode-Hashes. Die
Versuche verwenden nur erfundene Notizen, Kategorien, Messwerte und Termine.
Die unabhängig gelesene Datenbank stammt aus dem tatsächlichen
`SqlCipherTrackingStorage` und dem nativen iOS-Plugin, nicht aus einer
Python-Nachbildung. Der Integrationstest prüft den vollständigen Snapshot vor
und nach dem Schliessen und Wiederöffnen.

- Separater Simulator: **Regelmaessig Verschluesselungstest**, iPhone 17, iOS 26.5;
  ID `B71714F1-F91C-435B-8D71-09891391F569`.
- Beide Simulator-Testläufe verwenden ausdrücklich **`--no-uninstall`**. Der
  Datencontainer war nach jedem Lauf noch vorhanden; siehe
  [Simulatornachweis](belege/verschluesselungspruefung/20261002T142700Z/simulator.json).
- SQLCipher meldet `4.10.0 community`, CommonCrypto, `aes-256-cbc`, 4096-Byte-Seiten,
  PBKDF2-HMAC-SHA512 mit 256000 Iterationen und HMAC-SHA512. App-Schema: Version 2.
  Das [Flutter-Manifest](belege/verschluesselungspruefung/20261002T142700Z/flutter-evidence/manifest.json)
  enthält die vollständigen gemessenen Parameter und die erwarteten Testinhalte.
- Die zweite Ebene nutzt AES-256-GCM; Tabelle und Zeilen-ID sind authentifizierte
  Zusatzdaten. Die Prüfungen verändern nur Bytekopien im Arbeitsspeicher.
- Die geschlossene Datenbank wird schreibgeschützt geöffnet. Hashes vor und nach
  den Prüfungen sowie beim Kopieren sichern die Zuordnung der Belege.

Der simulierte Angreifer besitzt zunächst nur eine Dateikopie. Weitere Szenarien
geben ihm bewusst zuerst den SQLCipher-Schlüssel und anschliessend auch den
AES-Schlüssel. In der aktuellen App sind **beide** im Quellcode öffentlich;
„Angreifer ohne Schlüssel“ ist deshalb nur ein isolierter Prüfzustand und keine
realistische Zusage für einen Angreifer mit Zugriff auf den Debug-Code.

Die Schlüsselverwaltung gehört nicht zum SQLCipher-Verschlüsselungsmechanismus
und muss von der Anwendung gelöst werden. [SQLCipher: Key Material](https://www.zetetic.net/sqlcipher/database-key-material/)

## Ergebnisse und Belege

| Prüfung | Beobachtung | Beleg |
| --- | --- | --- |
| Bestehende Unit-/Widget-Tests | 32 bestanden | [Protokoll](belege/verschluesselungspruefung/20261002T142700Z/flutter-unit.txt) |
| Export aus echtem Flutter-Speicherdienst | 1 Integrationstest bestanden; Wiederlesen nach erneutem Öffnen erfolgreich | [Protokoll](belege/verschluesselungspruefung/20261002T142700Z/flutter-evidence.txt) |
| Native Speicher-, UI- und Migrationstests | 16 bestanden, einschliesslich Migrations-Rollback und Ablehnung beschädigter Inhalte | [Protokoll](belege/verschluesselungspruefung/20261002T142700Z/flutter-storage.txt) |
| Unabhängige Python-Dateiprüfung | 16/16 erwartete Ergebnisse | [Einzelresultate](belege/verschluesselungspruefung/20261002T142700Z/flutter-verification/bericht.md) |
| sqlmap-Labor mit Live-Ausgabe | 19/19 erwartete Ergebnisse | [Laborbericht](belege/verschluesselungspruefung/20261002T142700Z/sqlmap-lab/bericht.md) |
| Fehlerfälle des Prüfwerkzeugs | 4 bestanden: fehlende/defekte Datei, abweichende Fixture, abgebrochener Flutter-Lauf | [Protokoll](belege/verschluesselungspruefung/20261002T142700Z/verifier-negative-tests.txt) |
| Statische Dart-Analyse | Keine Befunde nach Entfernen eines unbenutzten Imports | [Protokoll](belege/verschluesselungspruefung/20261002T142700Z/dart-analyze.txt) |

Die unabhängige Prüfung zeigt:

- Gewöhnliches SQLite sowie SQLCipher ohne beziehungsweise mit falschem Schlüssel
  scheitern bei einer tatsächlichen Tabellenabfrage.
- Der richtige SQLCipher-Schlüssel öffnet Tabellen mit `id` und `payload`;
  die fachlichen Felder liegen weiterhin als verschlüsselte BLOBs vor.
- Beide richtigen Schlüssel liefern einen exakten Abgleich **aller** exportierten
  Testfelder und des verschlüsselten Prüfwerts. Der
  [entschlüsselte Test-Snapshot](belege/verschluesselungspruefung/20261002T142700Z/flutter-verification/decrypted-public-fixture.json)
  ist als positive Gegenprobe dokumentiert.
- Falscher AES-Schlüssel, Änderungen an Nonce, Ciphertext oder Tag, falsche
  Tabellen-/Zeilenbindung, unbekannte Payloadversion und abgeschnittene Payload
  werden abgewiesen.
- Fünf bekannte Klartextmarker fehlen in den beiden gesicherten Datenbankdateien
  (je 16384 Bytes). Dieser Suchtest ist nur ein ergänzendes Indiz.
- Bei beiden Momentaufnahmen existierten **keine** `-wal`, `-journal` oder `-shm`
  Dateien. Deren Inhalte wurden folglich **nicht geprüft**. Die Verbindung meldete
  `journal_mode=delete`. Ein nicht vorhandenes Journal ist kein Nachweis über alle
  möglichen Journalzustände.

Im Labor extrahiert sqlmap über die verwundbare Klartextroute einen Datensatz,
obwohl die zugrunde liegende Datei mit SQLCipher verschlüsselt ist: Der Server
hat die äussere Ebene bereits geöffnet. Über die verwundbare verschlüsselte Route
extrahiert sqlmap eine AES-Payload. Erst der getrennte Schritt mit dem öffentlichen
AES-Schlüssel macht diese lesbar. Die parametrisierte Vergleichsroute zeigt im
getesteten Umfang (`level=1`, `risk=1`, `technique=BU`) keine Injection.
[sqlmap-Bedienungsanleitung](https://github.com/sqlmapproject/sqlmap/wiki/Usage)

`PASS` bedeutet erwartetes Verhalten, nicht pauschal „sicher“. Die erfolgreiche
Entschlüsselung ist eine zwingende Gegenprobe: Fehlt sie, dürfen die anschliessenden
Ablehnungen ohne Schlüssel nicht als Schutz zählen. Infrastrukturfehler und
unvollständige Werkzeugresultate werden als `NOT_TESTED` beziehungsweise als
abgebrochener Gesamtlauf behandelt. `FAIL` bezeichnet eine überprüfbare Abweichung.

## Wiederholen und bekannte Ablaufprobleme

Die [Labor-README](../../../angreifer/README.md) enthält kopierbare Terminalbefehle
für Einrichtung, Live-Ausgabe, eigenen Test-Simulator, Flutter-Export und
unabhängige Prüfung. Die [Befehlsliste dieses Laufs](belege/verschluesselungspruefung/20261002T142700Z/commands.json)
verknüpft die verwendeten Aufrufe mit ihren Belegen. Werkzeugquellen und Lockdateien
sind zusätzlich als [Quellstand](belege/verschluesselungspruefung/20261002T142700Z/tool-sources/)
archiviert; zum Ausführen die Skripte im ursprünglichen `angreifer`-Ordner verwenden.

Beim ersten Flutter-Lauf fehlte `--no-uninstall`. Der Test bestand, Flutter
entfernte danach jedoch die Test-App und deren Datencontainer vom bisherigen
Simulator. Die ausgegebene Datei konnte nicht mehr eingesammelt werden. Dieser
Lauf ist **kein unabhängiger Dateinachweis**; das
[erste Protokoll](belege/verschluesselungspruefung/20261002T142700Z/flutter-evidence-first-run.txt)
bleibt erhalten. Eine Wiederherstellung früherer Simulator-Daten wurde nicht
geprüft oder durchgeführt. Die anschliessenden Läufe erfolgten auf dem neu
angelegten, separaten Test-Simulator mit `--no-uninstall`. Vor dem nächsten
Test-Build wurden die exportierten Dateien in den Belegordner kopiert, weil auch
bei erhaltener Installation ein weiterer Test den App-Container ersetzen kann.

Der frühere Laboraufbau scheiterte unter anderem beim erneuten Überschreiben
schreibgeschützter CocoaPods-Quelldateien. `setup.py` ersetzt nun seine eigenen
Vendor-Kopien atomar durch beschreibbare Kopien. Die Originalquellen werden nicht
verändert. Zusätzlich blockierte die Ausführungs-Sandbox Downloads, SDK-Cache und
lokale Serverports; nach Freigabe liefen die Schritte erfolgreich. Die
Fehlversuche sind als `*-sandbox.txt` erhalten und werden nicht als Testerfolg
gewertet. Ein unbenutzter Dart-Import wurde nach den Integrationstests entfernt;
die anschliessende statische Analyse war sauber. Der funktionale App-Code blieb
unverändert.

## Konsequenz für die App und ihre Aussage

Belegbare Formulierung für **diesen Entwicklungsstand und diesen Versuch**:

> Die getestete Datenbankkopie war ohne passende Schlüssel nicht lesbar.
> Mit beiden öffentlichen Debug-Schlüsseln konnten die Testdaten vollständig
> entschlüsselt werden.

Die Aussage „Niemand kann deine Daten lesen“ ist damit **nicht belegt**. Die App
selbst muss die Inhalte entschlüsseln können. Der aktuelle Schlüsselanbieter
verweigert ausserhalb des Debug-Modus den Zugriff; eine produktive
Schlüsselverwaltung ist noch nicht angebunden. Dieser letzte Punkt folgt aus
der Codeprüfung, nicht aus einem ausgeführten Release-Test.

Nicht geprüft sind Android, produktive Schlüsselablage, Zugang zu einem echten
Gerät, Arbeitsspeicher einer laufenden App, Betriebssystemkompromittierung,
Backups, Benachrichtigungen und Transfer. Die Dateigrösse bleibt auch ohne
Schlüssel sichtbar; nach Öffnen der SQLCipher-Ebene sind Tabellenstruktur,
Anzahl, Reihenfolge und Länge der Datensätze erkennbar. AES-GCM verhindert nicht
von sich aus das Löschen ganzer Zeilen oder das Zurückspielen eines früheren
gültigen Datenbestands. Der Versuch ist ein reproduzierbarer Funktionsnachweis,
keine umfassende Sicherheitszertifizierung.
