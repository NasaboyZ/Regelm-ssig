# Technische Transfermodelle

## 11. Transfer – getrennte technische Modelle

Der Transfer ist eine rein optische Übertragung zwischen zwei Geräten:
Gerät A zeigt einen MLQR an, Gerät B liest die Kamerabilder. Dafür werden
weder ein Konto noch eine Cloud oder ein Server benötigt.

Ein Session-QR kennzeichnet die Übertragung, erzeugt aber keine
Netzwerkverbindung. Die fachlichen Tagesdaten und die technischen
Transfermodelle bleiben getrennt.

### `TransferManifest`

Das Manifest beschreibt eine vollständige Transfersession und ihre erwarteten
Teile.

| Feld              | Modelltyp  | Inhalt und Regel                         |
| ----------------- | ---------- | ---------------------------------------- |
| `transferId`      | `String`   | Stabile ID der Transfersession           |
| `protocolVersion` | `int`      | Pflichtfeld; mindestens `1`              |
| `schemaVersion`   | `int`      | Pflichtfeld; mindestens `1`              |
| `chunkCount`      | `int`      | Pflichtfeld; mindestens `1`              |
| `entryCount`      | `int`      | Pflichtfeld; `0` oder größer             |
| `createdAtUtc`    | `DateTime` | Erstellungszeitpunkt der Transfersession |

### `TransferChunk`

Ein Chunk enthält einen verschlüsselten Teil des Payloads.

| Feld         | Modelltyp     | Inhalt und Regel                               |
| ------------ | ------------- | ---------------------------------------------- |
| `transferId` | `String`      | Muss zum `TransferManifest` passen             |
| `index`      | `int`         | Nullbasierter Chunk-Index; kleiner als `total` |
| `total`      | `int`         | Gesamtanzahl der Chunks                        |
| `ciphertext` | `Byte-Puffer` | Verschlüsselter Payload-Teil                   |

Für eine gültige Session müssen alle Chunks dieselbe `transferId` und eine
konsistente Gesamtanzahl verwenden. Die Indizes müssen im Bereich von `0`
bis `total - 1` liegen.

### Importstrategie: `ImportStrategy`

| Wert             | Bedeutung                                          |
| ---------------- | -------------------------------------------------- |
| `merge`          | Import in bestehende Daten mit Zusammenführung     |
| `replaceInRange` | Ersetzt Daten innerhalb eines definierten Bereichs |

Die genaue Konfliktregel und der von `replaceInRange` betroffene Zeitraum
müssen vor der produktiven Implementierung definiert werden. Ohne diese
Festlegungen ist keine sichere produktive Importsemantik gegeben.

Jeder Import erfolgt transaktional: Entweder werden alle validierten Daten
übernommen oder keine Änderung wird dauerhaft gespeichert.

### Validierung einer Session

Vor dem Import müssen mindestens folgende Fälle geprüft und abgelehnt werden:

- Chunks aus unterschiedlichen Sessions, erkennbar an nicht passenden
  `transferId`-Werten
- fehlende Chunks innerhalb der erwarteten Menge
- widersprüchliche doppelte Chunk-Indizes; identische Wiederholungen werden
  idempotent ignoriert
- ungültige Indizes oder widersprüchliche `total`-Werte
- nicht passende Versionen oder ungültige Mindestwerte im Manifest
- beschädigte, nicht entschlüsselbare oder unvollständige Payloads

Chunks sind nicht dasselbe wie optische QR-Ebenen. Chunks bezeichnen
Datenpakete; QR-Ebenen bezeichnen die Darstellung beziehungsweise den
optischen Übertragungsvorgang. Die Zuordnung zwischen beiden Begriffen ist
Aufgabe des Codec- und Transferprotokolls.

### Session-Identität und Authentizität

`transferId` identifiziert eine Transfersession. Ein Session-QR dient zur
Zuordnung der Übertragung, beweist aber keine Authentizität. Insbesondere
beweist ein Manifest allein nicht, dass die Daten von einem vertrauenswürdigen
Gerät stammen oder unverändert sind.

### Implementierter Codec-Stand

Die erste Transfer-Pipeline ist als `TransferCodec` und `MlqrTransferService`
implementiert. Ein `TrackingSnapshot` wird als CBOR serialisiert, mit GZIP
komprimiert und in versionierte Chunks geteilt. Der aktuelle
Entwicklungsmodus überträgt diese Chunks ohne Passphrase und damit ohne
Verschlüsselung; der verschlüsselte Pfad bleibt als separater Codec-Pfad
vorhanden.
Bis zu 15 Chunks werden zu einem MLQR gebündelt; mehrere MLQRs können über
`transferId`, `index` und `total` wieder zu einer Transfersession zusammengesetzt
werden. Der sitzungsbezogene `TransferChunkAccumulator` hält bestätigte Chunks
bis zur Vollständigkeit nur im Arbeitsspeicher. Der Import wird erst nach
vollständiger Entschlüsselung, Dekompression, CBOR-Deserialisierung und
Snapshot-Validierung freigegeben.

Die Repository-Integration nutzt beim Sender den echten `TrackingSnapshot` und
speichert beim Empfänger erst nach vollständigem Empfang und erfolgreichem
Zusammenführen. Die UI zeigt mehrere Codes automatisch nacheinander an.

### Noch auszuarbeitendes Transferprotokoll

Die folgenden technischen Entscheidungen gehören in ein versioniertes
Transfer-Envelope beziehungsweise DTO und sind vor der produktiven
Implementierung festzulegen:

- Serialisierung, zum Beispiel CBOR
- Kompression
- KDF-Parameter
- Salt
- Nonce
- authentifizierte Verschlüsselung
- Payload-Limits
- Versionskompatibilität

Diese Metadaten dürfen nicht implizit aus der Darstellung des QR oder aus der
Position eines Chunks abgeleitet werden. Das versionierte Envelope muss sie
explizit und eindeutig transportieren.
