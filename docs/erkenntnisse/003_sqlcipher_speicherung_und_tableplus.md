# SQLCipher-Speicherung und aktuelle Daten in TablePlus

## Datum

26-09-2026

## Nachtrag: zweite Verschlüsselungsebene

Dieser Eintrag beschreibt die erste TablePlus-Kontrolle mit Schema-Version 1.
Mit Schema-Version 2 werden nun zusätzlich sämtliche fachlichen Werte mit
AES-256-GCM verschlüsselt. Datum und Kategoriebezeichnungen stehen ebenfalls
innerhalb der Payloads. Nach dem Öffnen mit nur dem SQLCipher-Schlüssel zeigt
TablePlus technische IDs und verschlüsselte BLOBs; die App benötigt beide Schlüssel.
Die Migration übernimmt bestehende Testdaten atomar. Vorgehen und Grenzen stehen
in der [aktuellen Entwicklungsanleitung](../entwicklung/sqlcipher_speicherung.md).

Die Implementierung und die Migration wurden in automatisierten Tests erfolgreich
geprüft. Die Migration der damals in TablePlus geöffneten Originaldatei ist jedoch
noch nicht bestätigt: Der abschliessende Neustart der normalen App wurde
unterbrochen. Testergebnisse und offene Punkte sind im
[Verschlüsselungsstand vom 26.09.2026](../entwicklung/README.md#verschlüsselungsstand-vom-26092026)
festgehalten.

## Beobachtung

Die Tageserfassung speichert beim normalen Debug-Start in
`regelmaessig_tracking_debug.db`. In TablePlus blieb die Tabelle zunächst leer,
obwohl in der App ein Tag gespeichert worden war. Die geöffnete Verbindung
zeigte auf eine zuvor erstellte Kopie unter `/private/tmp/`.

Nach dem Verbinden mit der Originaldatei im Datenordner des iOS-Simulators war
in `day_entries` ein gespeicherter Eintrag vom 16.09.2026 sichtbar. Die neue
Verbindung wurde beim Öffnen **Regelmässig – Simulator aktuell** genannt.
Damit war für diesen Eintrag bestätigt: Die App speichert, aber die bisherige
TablePlus-Verbindung zeigte eine andere Datei.

TablePlus konnte die verschlüsselte Datenbank mit dem im Debug-Code hinterlegten
Testschlüssel öffnen. Beim Öffnen über **Datei → Öffnen** wurde die Datenbank
dagegen als Text im SQL-Editor angezeigt. Dieser Editor wurde ohne Ausführen
oder Speichern wieder geschlossen.

## Erkenntnis

### Was gespeichert wird

Der Datenfluss lautet:

`RecordView → RecordViewModel → TrackingRepository → TrackingStorage → SQLCipher`

Gespeichert werden die erfassten Tagesdaten aus dem Modell. Die auswählbaren
UI-Items sind nicht jeweils eigene Datenbankzeilen. Der damals verwendete Aufbau in Schema-Version 1 war:

| Tabelle             | Inhalt                                                                                                                                                                 |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `day_entries`       | Eine Zeile pro Datum. `date` ist der Primärschlüssel; `data_json` enthält den serialisierten `DayEntry` mit Auswahlen, eigenen Werten, Terminen, Notiz und Messwerten. |
| `custom_categories` | Selbst definierte Kategorien mit `id` und `name`, unabhängig davon, ob bereits Tageswerte dazu existieren.                                                             |

Tage und Kategorien werden gemeinsam in einer Transaktion gespeichert. Ein
erneutes Speichern desselben Tages aktualisiert die vorhandene Zeile. Ein
vollständig geleerter Tag wird entfernt. Der bisherige Secure-Storage-Stand
wird nicht automatisch übernommen.

### Verschlüsselung und aktueller Testschlüssel

SQLCipher übernimmt die Verschlüsselung der Datenbank einschliesslich
Tabellenstruktur und JSON-Inhalten. TablePlus benötigt deshalb einen Schlüssel,
bevor es die Tabellen lesen kann. Die lesbare Anzeige nach dem Entsperren bedeutet
nicht, dass die Datei unverschlüsselt gespeichert ist.

Der aktuelle öffentliche Schlüssel für erfundene Debug-Testdaten lautet:

```text
regelmaessig-debug-test-key-v1
```

Dieser Schlüssel wird nur im Debug-Modus über
[`DebugTrackingKeys`](../../lib/services/debug_tracking_keys.dart) bereitgestellt. Er ist keine persönliche
Passphrase und bietet keinen Schutz für echte Gesundheitsdaten. Der
SQLCipher-Dienst erhält den Schlüssel über einen `keyProvider` und legt ihn
selbst nicht ab. Die produktive Lösung mit Passphrase, Biometrie und
System-Schlüsselablage bleibt offen; Profile-/Release-Datenzugriff ist bis zur
Anbindung eines produktiven Schlüsselanbieters gesperrt.

### Originaldatei und Kopie unterscheiden

Eine Kopie ist eine Momentaufnahme. **Reload** in TablePlus liest nur die bereits
verbundene Datei erneut; es holt keine neuen Daten aus der Simulator-Datei in
eine Kopie. Für die laufende Kontrolle der Debug-App kann TablePlus direkt mit
der Originaldatei verbunden werden. Dabei nur lesen und Änderungen weiterhin
über die App vornehmen.

Den aktuellen App-Datenordner des gestarteten iOS-Simulators ermitteln:

```sh
xcrun simctl get_app_container booted com.example.regelmaessig data
```

Daran `Documents/regelmaessig_tracking_debug.db` anhängen. Der vollständige Pfad
enthält Geräte- und App-Container-IDs; insbesondere nach einer Neuinstallation
muss er erneut ermittelt werden.

In der hier verwendeten TablePlus-Version funktionierte dieser Ablauf:

1. Über **Connection → New…** eine **SQLite**-Verbindung erstellen.
2. Den vollständigen Originalpfad unter **File path** eintragen.
3. Den oben genannten Debug-Schlüssel unter **Passphrase** eintragen und
   **Connect** wählen.
4. Links `day_entries` mit einem Doppelklick öffnen. Die Tageswerte stehen in
   `data_json`; `custom_categories` enthält die eigenen Kategoriebezeichnungen.
5. Nach dem Speichern in der App oben rechts **Reload ↻** anklicken.

**Datei → Öffnen** ist hierfür nicht der richtige Einstieg: In dieser Sitzung
öffnete es die verschlüsselte Datei als SQL-Text statt als Datenbankverbindung.

## Auswirkung auf das Projekt

Bei vermeintlich fehlenden Einträgen zuerst den Verbindungspfad, die Tabelle und
die Aktualisierung in TablePlus prüfen. Die leere Kopie war kein Beleg für einen
Fehler beim Speichern; für dieses Anzeigeproblem war keine Codeänderung nötig.

Für Experimente mit SQL-Änderungen weiterhin eine Kopie nach dem Stoppen der App
verwenden. Für die lesende Kontrolle neuer Einträge die Originaldatei verbinden.
Details zu Kopien, Begleitdateien und automatisierten Tests stehen in der
[Entwicklungsanleitung zur SQLCipher-Speicherung](../entwicklung/sqlcipher_speicherung.md).
