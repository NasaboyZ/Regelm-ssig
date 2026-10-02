# Versuchsergebnisse

Durchlauf: `20261002T144228.273771Z` (UTC)

PASS bedeutet: Das erwartete Versuchsergebnis ist eingetreten. Es bedeutet nicht, dass die App sicher ist.

| Prüfung | Status | Beobachtung |
| --- | --- | --- |
| Dateikopie ohne SQLCipher-Schlüssel abgewiesen | PASS | DatabaseError: file is not a database |
| Dateikopie mit falschem SQLCipher-Schlüssel abgewiesen | PASS | DatabaseError: file is not a database |
| Gewöhnliches SQLite kann die Dateikopie nicht lesen | PASS | DatabaseError: file is not a database |
| Dateien enthalten keine bekannten Klartextmarker | PASS | Kein SQLite-Klartextheader und keine Testmarker; nur ergänzende Indizien. |
| Nur Datenbankschlüssel: verschlüsselte Payload lesbar | PASS | Korrekte Passphrase öffnet Tabellen; id und AES-BLOB sind sichtbar. |
| Beide Debug-Schlüssel: Testeintrag entschlüsselt | PASS | Dateikopie mit beiden öffentlichen Debug-Schlüsseln vollständig entschlüsselt. |
| Falscher AES-Schlüssel abgewiesen | PASS | InvalidTag: Authentication rejected |
| Manipulation an Nonce abgewiesen | PASS | InvalidTag: Authentication rejected |
| Manipulation an Ciphertext abgewiesen | PASS | InvalidTag: Authentication rejected |
| Manipulation an Tag abgewiesen | PASS | InvalidTag: Authentication rejected |
| Vertauschte Tabellenbindung abgewiesen | PASS | InvalidTag: Authentication rejected |
| Vertauschte Zeilenbindung abgewiesen | PASS | InvalidTag: Authentication rejected |
| Unbekannte Payloadversion abgewiesen | PASS | ValueError: Unsupported or truncated payload |
| Abgeschnittene Payload abgewiesen | PASS | ValueError: Unsupported or truncated payload |
| HTTP-Gegenproben vor sqlmap | PASS | Alle drei Routen erreichbar; Baseline liefert nur Kontrollzeile 2. |
| sqlmap: vulnerable/plain | PASS | sqlmap extrahiert Zeile 1 im Klartext trotz SQLCipher-Dateiverschlüsselung (Hex ist nur Transportdarstellung). |
| sqlmap: vulnerable/encrypted | PASS | sqlmap extrahiert AES-BLOB. Separater Schritt mit öffentlichem Debug-AES-Schlüssel entschlüsselt den Testeintrag. |
| sqlmap: safe/encrypted | PASS | Keine Injection im Umfang level=1, risk=1, technique=BU erkannt; kein allgemeiner Sicherheitsbeweis. |
| Angriffsversuche verändern keine Datenbankdatei | PASS | SHA-256 aller drei geschlossenen Datenbankdateien unverändert. |

19/19 Prüfungen entsprechen der Erwartung.

Konfiguration: [environment.json](environment.json). Rohdaten: [checks.json](checks.json).
sqlmap-Protokolle: [Klartext](sqlmap-plain/console.log), [AES-Payload](sqlmap-encrypted/console.log), [parametrisierte Abfrage](sqlmap-safe/console.log).

Keine bestehende App-Datenbank wurde gelesen oder verändert. Nur eine lokale Labornachbildung wurde angegriffen.
