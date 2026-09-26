# Entwicklung

Hier stehen die Anleitungen zum Starten, Prüfen und Anschauen der App-Daten.

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
| `regelmaessig-debug-test-key-v1` | [`lib/dependencies.dart`](../../lib/dependencies.dart), nur im Debug-Modus | Öffnen und Verschlüsseln von `regelmaessig_tracking_debug.db` beim normalen App-Start. `main_sqlcipher_debug.dart` ruft denselben Einstieg auf. |
| `regelmaessig-debug-test-key-v1` | TablePlus, Feld **Passphrase** | Verwendet beim Öffnen der ursprünglichen Datenbankkopie und der Originaldatei unter **Regelmässig – Simulator aktuell**. Es wurde dafür kein neuer Schlüssel erzeugt. |
| `regelmaessig-debug-test-key-v1` | SQLCipher-CLI-Beispiel in der [Speicheranleitung](sqlcipher_speicherung.md#kopie-entschlüsseln-und-abfragen) | Derselbe Schlüssel wird dort über `PRAGMA key` gesetzt. |
| `regelmaessig-debug-test-key-v1` | [Integrationstest](../../integration_test/sqlcipher_tracking_storage_test.dart) zum normalen App-Start | Prüft, ob der reguläre Speichern-Ablauf in die Debug-Datenbank schreibt. |
| `integration-test-only-key` | Übrige SQLCipher-Integrationstests in derselben Testdatei | Öffnet die eigens angelegten temporären Testdatenbanken; gilt nicht für die in TablePlus gezeigte App-Datenbank. |
| `incorrect-key` | Negativtest in derselben Testdatei | Absichtlich falscher Schlüssel; der Datenzugriff muss scheitern. Auch ein leerer Schlüssel wird separat auf Ablehnung geprüft. |

Der [SQLCipher-Dienst](../../lib/services/sqlcipher_tracking_storage.dart)
übernimmt den gelieferten Schlüssel über `keyProvider` und reicht ihn als
`password` an SQLCipher weiter. Er speichert selbst keinen Schlüssel. Der
öffentliche Debug-Schlüssel ist aktuell allerdings im App-Quellcode enthalten.

Eine produktive Passphrase wurde nicht eingerichtet. Die spätere Lösung für
Passphrase, Biometrie, Keychain/Keystore und Transfer bleibt offen. Im
Profile-/Release-Modus ist der Datenzugriff bis zur Anbindung eines produktiven
Schlüsselanbieters gesperrt.
