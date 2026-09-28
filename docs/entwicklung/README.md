# Entwicklung

Hier stehen die Anleitungen zum Starten, Prüfen und Anschauen der App-Daten.

## Verschlüsselungsstand vom 26.09.2026

- **Implementiert:** SQLCipher verschlüsselt die gesamte Datenbank. Zusätzlich
  verschlüsselt AES-256-GCM alle fachlichen Daten einschliesslich Datum,
  Tagesinhalten und eigenen Kategorien.
- **Erfolgreich geprüft:** 32 Unit-/Widget-Tests, 16 native iOS-Integrationstests
  auf dem iPhone-17-Simulator (iOS 26.5) und die statische Dart-Analyse.
  Die Integrationstests prüfen auch die Migration von Schema 1 auf 2 und deren
  Rollback bei Fehlern. Android wurde mangels installiertem Android SDK nicht geprüft.
- **Noch nicht bestätigt:** Die Migration der bestehenden, zuvor in TablePlus
  angeschauten Simulator-Datenbank. Der abschliessende Neustart der normalen App
  wurde unterbrochen. Beim nächsten Datenbankzugriff mit der neuen App-Version
  wird eine vorhandene Version-1-Datenbank automatisch migriert. Die erfolgreichen
  Migrationstests allein bestätigen nicht den Zustand dieser konkreten Datei.
- **Weiterhin offen:** Die produktive Schlüsselverwaltung. Beide derzeitigen
  Schlüssel sind öffentliche Testschlüssel und nur für erfundene Testdaten gedacht.

## Anleitungen

- [SQLCipher-Speicherung](sqlcipher_speicherung.md): Datenfluss, Tabellen,
  Verhalten beim Speichern, Datenbankkopien und automatisierte Tests.
- [Daten in TablePlus anschauen](tableplus_datenbank_anschauen.md): die am
  26.09.2026 ausgeführten Schritte, Originalpfad und Aktualisierung der Anzeige.
- [Erkenntnisse zur Datenbank](../erkenntnisse/003_sqlcipher_speicherung_und_tableplus.md):
  was wir aus der zunächst leeren TablePlus-Anzeige gelernt haben.

## Welche Passphrase wurde wo verwendet?

Für die in TablePlus gezeigte App-Datenbank lautet die Passphrase:

```text
regelmaessig-debug-test-key-v1
```

Das ist ein öffentlicher Entwicklungsschlüssel für erfundene Testdaten.
Die folgenden Werte sind Testwerte aus dem Quellcode, keine persönlichen
Passphrasen oder produktiven Zugangsdaten.

| Wert | Einsatzort | Zweck |
| --- | --- | --- |
| `regelmaessig-debug-test-key-v1` | [`debug_tracking_keys.dart`](../../lib/services/debug_tracking_keys.dart), nur im Debug-Modus | Öffnen und Verschlüsseln von `regelmaessig_tracking_debug.db` beim normalen App-Start. `main_sqlcipher_debug.dart` ruft denselben Einstieg auf. |
| `regelmaessig-debug-test-key-v1` | TablePlus, Feld **Passphrase** | Verwendet beim Öffnen der ursprünglichen Datenbankkopie und der Originaldatei unter **Regelmässig – Simulator aktuell**. Es wurde dafür kein neuer Schlüssel erzeugt. |
| `regelmaessig-debug-test-key-v1` | SQLCipher-CLI-Beispiel in der [Speicheranleitung](sqlcipher_speicherung.md#kopie-entschlüsseln-und-abfragen) | Derselbe Schlüssel wird dort über `PRAGMA key` gesetzt. |
| `regelmaessig-debug-test-key-v1` | [Integrationstest](../../integration_test/sqlcipher_tracking_storage_test.dart) zum normalen App-Start | Prüft, ob der reguläre Speichern-Ablauf in die Debug-Datenbank schreibt. |
| `integration-test-only-key` | Übrige SQLCipher-Integrationstests in derselben Testdatei | Öffnet die eigens angelegten temporären Testdatenbanken; gilt nicht für die in TablePlus gezeigte App-Datenbank. |
| `incorrect-key` | Negativtest in derselben Testdatei | Absichtlich falscher Schlüssel; der Datenzugriff muss scheitern. Auch ein leerer Schlüssel wird separat auf Ablehnung geprüft. |

## Separater AES-256-Datenschlüssel

Die App verwendet für die zweite Ebene folgende **32 Bytes**, hier als Hexwert:

```text
000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

Dies ist ein öffentlicher Testschlüssel, keine neu einzurichtende Passphrase.
Er wird in [`DebugTrackingKeys.dataKey()`](../../lib/services/debug_tracking_keys.dart)
als Bytefolge `00` bis `1f` bereitgestellt. Er wird **nicht** in TablePlus eingegeben.
TablePlus öffnet mit der bisherigen Passphrase die Datenbank und zeigt danach
weiterhin verschlüsselte Payloads. Die App entschlüsselt diese mit dem AES-Schlüssel.

Die isolierten AES- und SQLCipher-Tests verwenden stattdessen 32 Bytes mit dem
Wert `42` (hex `2a`), für falsche Schlüssel 32 Bytes mit dem Wert `43` (hex `2b`).
Tests ungültiger Schlüssellängen verwenden zusätzlich bewusst zu kurze oder zu
lange Bytefolgen. Diese Werte gelten nicht für die normale Debug-App.

Der [SQLCipher-Dienst](../../lib/services/sqlcipher_tracking_storage.dart) erhält
über `keyProvider` den SQLCipher-Schlüssel und über `dataKeyProvider` den separaten
AES-Schlüssel. Die Registrierung erfolgt in
[`lib/dependencies.dart`](../../lib/dependencies.dart). Der Dienst legt keine
Schlüssel dauerhaft ab; beide öffentlichen Debug-Testschlüssel stehen jedoch im
App-Quellcode. Auch der normale App-Start-Integrationstest verwendet dieses Paar.

Eine produktive Passphrase wurde nicht eingerichtet. Die spätere Lösung für
Passphrase, Biometrie, Keychain/Keystore und Transfer bleibt offen. Im
Profile-/Release-Modus ist der Datenzugriff bis zur Anbindung eines produktiven
Schlüsselanbieters gesperrt.
