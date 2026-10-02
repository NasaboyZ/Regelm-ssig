# Flutter-Dateiprüfung

PASS bedeutet erwartetes Verhalten, keine Sicherheitszertifizierung.

| Prüfung | Status | Beobachtung |
| --- | --- | --- |
| Flutter evidence is complete | PASS | Complete Flutter fixture manifest and database present |
| Both public keys decrypt actual Flutter database | PASS | All fields and metadata independently decrypted with both public keys; exact Flutter snapshot match |
| No SQLCipher key rejected | PASS | DatabaseError |
| Wrong SQLCipher key rejected | PASS | DatabaseError |
| Ordinary SQLite cannot query database | PASS | DatabaseError |
| SQLCipher key alone exposes encrypted payloads | PASS | Only technical IDs and encrypted BLOBs; row counts, ordering and lengths remain visible |
| Known plaintext markers absent from captured DB files | PASS | {'scanned': ['open-flutter.db', 'closed-flutter.db'], 'marker_count': 5, 'limitation': 'Known-marker scan only; absent sidecars not tested'} |
| Wrong AES key rejected | PASS | InvalidTag |
| Nonce manipulation rejected | PASS | InvalidTag |
| Ciphertext manipulation rejected | PASS | InvalidTag |
| Tag manipulation rejected | PASS | InvalidTag |
| Changed table binding rejected | PASS | InvalidTag |
| Changed row binding rejected | PASS | InvalidTag |
| Unknown payload version rejected | PASS | ValueError |
| Truncated payload rejected | PASS | ValueError |
| Source evidence unchanged | PASS | SHA-256 and file inventory unchanged; mutations used in-memory byte copies only |

16/16 PASS. Details: [checks.json](checks.json).
