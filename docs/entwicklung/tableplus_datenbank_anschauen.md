# App-Daten in TablePlus anschauen

## Aktueller Stand: zwei Verschlüsselungsebenen

Seit Schema-Version 2 verschlüsselt AES-256-GCM zusätzlich alle fachlichen Werte.
Nach dem Öffnen in TablePlus sind deshalb nur `id` und `payload` sichtbar. Dies
ist beabsichtigt. Die App kann die Inhalte weiterhin anzeigen, weil sie zusätzlich
den separaten Datenschlüssel erhält. Beide Testschlüssel sind in der
[Entwicklungs-README](README.md) dokumentiert.

Die folgenden Beobachtungen beschreiben die erste Kontrolle mit Schema-Version 1.
Beim nächsten vollständigen App-Start mit dem neuen Code wird diese Datenbank
atomar auf Version 2 migriert. Hot Reload allein genügt dafür nicht.

## Was wir am 26.09.2026 zunächst gemacht haben

Die bisherige TablePlus-Verbindung **regelmässig** zeigte auf diese Kopie:

```text
/private/tmp/regelmaessig-tableplus-btgp2pza/regelmaessig_tracking_debug.db
```

Sie enthielt keine Tageszeilen. Neue Einträge aus der App erschienen dort nicht,
weil die App in ihre Originaldatei im Simulator schreibt. Ein Klick auf
**Reload** aktualisiert nur den Inhalt der verbundenen Datei, nicht die Kopie
aus ihrer Quelle.

Wir haben deshalb eine SQLite-Verbindung mit dem Namen
**Regelmässig – Simulator aktuell** geöffnet und den Originalpfad eingetragen:

```text
/Users/josef/Library/Developer/CoreSimulator/Devices/BB6EBC97-1193-466B-B2E6-03574E643243/data/Containers/Data/Application/1BB5656E-7276-4C5B-8BB0-7CE6BA43E0DA/Documents/regelmaessig_tracking_debug.db
```

Im Feld **Passphrase** haben wir `regelmaessig-debug-test-key-v1` verwendet.
Anschliessend war unter `day_entries` eine Zeile vom **16.09.2026** sichtbar.
Die Erfassungsdaten standen in der Spalte `data_json`. Für diese Kontrolle
wurden keine Datensätze in TablePlus geändert.

Der obige Pfad dokumentiert den Stand dieser Sitzung. Nach einer Neuinstallation
oder beim Wechsel des Simulators kann der App-Datenordner anders heissen.

## Aktuellen Originalpfad ermitteln

Die App im gewünschten iOS-Simulator im Debug-Modus starten und mindestens
einmal einen Tag speichern. Danach im Terminal ausführen:

```sh
xcrun simctl get_app_container booted com.example.regelmaessig data
```

An den ausgegebenen Ordner diesen Teil anhängen:

```text
/Documents/regelmaessig_tracking_debug.db
```

Falls mehrere Simulatoren laufen, `booted` durch die gewünschte Geräte-ID
ersetzen. Die IDs lassen sich mit `xcrun simctl list devices booted` anzeigen.
Zum reinen Anschauen der Originaldatei muss die App nicht beendet werden.

## Verbindung in TablePlus öffnen

1. Oben **Connection** öffnen und **New…** wählen.
2. **SQLite** auswählen und **Create** anklicken.
3. Als Namen beispielsweise **Regelmässig – Simulator aktuell** eintragen.
4. Den vollständigen Originalpfad in **File path** eintragen.
5. In **Passphrase** diesen Wert eintragen:

   ```text
   regelmaessig-debug-test-key-v1
   ```

6. **Connect** anklicken und links `day_entries` doppelklicken.

In dieser Sitzung wurde die Verbindung über **Connect** geöffnet. Zum
Nachvollziehen ist kein Speichern der Passphrase über **Save** erforderlich.
Eine Übersicht aller verwendeten Testschlüssel steht in der [README](README.md).

**Datei → Öffnen** nicht für diesen Ablauf verwenden: Damit wurde die
verschlüsselte Datei bei uns als Text im SQL-Editor geöffnet. Falls das passiert,
den Dateitab ohne Speichern oder Ausführen schliessen und stattdessen die
SQLite-Verbindung wie oben öffnen.

## Einträge lesen und aktualisieren

| Stelle | Was dort zu sehen ist |
| --- | --- |
| `day_entries.id` | Technische Zeilennummer, kein Datum. |
| `day_entries.payload` | AES-256-GCM-verschlüsselter Tagesdatensatz einschliesslich Datum. |
| `custom_categories.payload` | Verschlüsselte fachliche Kategorie-ID und Bezeichnung. |
| `tracking_metadata` | Verschlüsselter Prüfwert zur Kontrolle des Datenschlüssels, auch bei leerer Datenbank. |

Nach einem weiteren Speichern in der App oben rechts auf **Reload ↻** klicken.
Die Anzeige fragt dann die Originaldatei erneut ab. Nach der Schema-Migration
gegebenenfalls die Verbindung erneut öffnen, damit TablePlus auch die neuen
Spalten lädt. Tagesinhalte jetzt in der App prüfen, nicht im BLOB-Feld. Beim erneuten Speichern
desselben Tages bleibt genau ein Datensatz für diesen Tag erhalten; es entsteht keine zusätzliche
Zeile für jede Auswahl.

Falls die Anzeige leer bleibt, zuerst den Verbindungspfad prüfen: Zeigt er auf
den aktuellen Simulator-Container oder auf eine Kopie unter `/tmp` beziehungsweise
`/private/tmp`? Danach `day_entries` öffnen, gegebenenfalls aktive Filter entfernen
und **Reload** anklicken. Nach einer Neuinstallation den Pfad neu ermitteln.

Die Originaldatei hier nur lesen und Tagesdaten über die App bearbeiten. Für
SQL-Experimente eine Kopie nach dem Stoppen der App verwenden; siehe
[Datenbank kopieren](sqlcipher_speicherung.md#ios-simulator).
