# Go-Transferengine – TODO und Betriebsnotizen

## Ziel

Das Go-Modul unter `native/transferengine` ist eine lokale, eingebettete
Transferengine für Kompression, Transferverschlüsselung, Chunking, MLQR und
Flutter-FFI. Es verwendet weder Netzwerkzugriff noch eine Datenbankverbindung.

Flutter bleibt Besitzer von SQLCipher, Repository, MVVM, Kamera und UI.

## Struktur

- [x] Modul in `native/transferengine` umbenennen.
- [x] Öffentliche Fassade im Root des Go-Moduls behalten.
- [x] Implementierungen nach `internal/protocol`, `internal/payload`,
      `internal/crypto`, `internal/mlqr`, `internal/ffi` und `internal/logging`
      aufteilen.
- [x] C-ABI-Einstiegspunkt unter `cmd/bridge` halten.
- [x] Build-Skript nach `scripts/build_native.sh` verschieben.
- [ ] Plattformartefakte in Android und iOS reproduzierbar bundlen.

## Logging für Flutter Run und Apple Device Hub

- [x] Strukturierte Logs mit `log/slog` einführen.
- [x] Debuglogs über `stderr` ausgeben.
- [x] Laufzeit, Payload-Größe, Chunk-Anzahl, Sequenzen und Ergebnis loggen.
- [x] Passphrases, Klartext-Payloads und Gesundheitsdaten nicht loggen.
- [x] Logger über `Engine` injizierbar machen.
- [ ] Apple-spezifische Unified-Logging-Ausgabe für Xcode/Device Hub prüfen.
- [ ] Android-Gerätelogging mit einem physischen Debuggerät prüfen.
- [ ] Release-Build mit deaktivierten ausführlichen Logs verifizieren.

Beispiel:

```text
transfer.encode duration_ms=184 payload_bytes=42800 chunks=8 encrypted=true success=true
mlqr.render duration_ms=71 packets=8 sequences=2 max_layers=5 success=true
```

## Sicherheit und Robustheit

- [x] PBKDF2 über `golang.org/x/crypto/pbkdf2` verwenden.
- [ ] KDF-Parameter und Protokollversion vor produktiver Nutzung extern prüfen.
- [x] GZIP-Ausgabe beim Dekomprimieren begrenzen.
- [x] Transfer-ID, Chunk-Anzahl und Chunk-Größe begrenzen.
- [ ] FFI-Eingaben zusätzlich mit fuzz tests prüfen.
- [ ] Keine Datenbankseiten oder SQLCipher-Schlüssel an Go übergeben.
- [ ] Verschlüsselte Payloads mit bekannten Dart-Testvektoren vergleichen.

## Performance und optischer Transfer

- [ ] Ein Jahr reale Zyklusdaten als Benchmark fixieren.
- [ ] Encoding p50/p95 und Peak-Speicher auf Android messen.
- [ ] Encoding p50/p95 und Peak-Speicher auf iOS messen.
- [ ] Chunk-Anzahl, MLQR-Sequenzen und sichtbare Frames getrennt messen.
- [ ] Ziel: normaler Transfer unter zwei Minuten.
- [ ] 3-, 4-, 5- und 7-Layer-Profile mit echten Kameras vergleichen.
- [x] Robustes 1-Datenebenen-Profil als optische Fallback-Strategie in der
      Transfer-API implementieren.
- [ ] 1-Datenebenen-Profil mit echten Geräten prüfen.
- [x] Für das 1-Datenebenen-Profil bestätigen, dass dieselben logischen
      Transfer-Chunks verwendet werden; nur die Gruppierung in MLQR-Codes
      darf sich ändern.
- [ ] Anzeigezeit und Erfolgsquote für 1, 3, 5 und 7 Datenebenen getrennt
      erfassen; „weniger Layer“ darf nicht mit „weniger Daten“ verwechselt
      werden.
- [ ] Temporale Recovery nur begrenzt und nicht pauschal dreifach abspielen.

### Optisches Profil mit einer Datenebene

Der Plan bleibt trotz der aktuellen Erkenntnis vollständig verfolgbar. Eine
MLQR-Datenebene kann weiterhin genau einen vollständigen Transfer-Chunk
enthalten. Mit `maxPayloadLayersPerCode = 1` wird also nicht weniger Payload
übertragen und es werden auch keine Chunks verworfen; es entstehen lediglich
mehr einzelne MLQR-Bilder. Die logische Chunk-Anzahl, Verschlüsselung,
Reihenfolge und der Empfänger bleiben unverändert.

Das ist ein Robustheitsprofil für schwierige Kamerasituationen, kein Ersatz
für das kompakte Mehr-Ebenen-Profil. „Eine Datenebene“ bedeutet dabei einen
Nutzdaten-QR pro MLQR-Code. Die Darstellung kann weiterhin Dummy-Ebenen für
die definierte MLQR-Geometrie enthalten; „nur eine optische Ebene insgesamt“
wäre dagegen ein temporaler Schwarzweiss-QR-Transfer und kein MLQR-Profil.

Die Umsetzung sollte deshalb in dieser Reihenfolge erfolgen:

1. Profilkonfiguration zentral machen (`1`, `3`, `5`, `7` Datenebenen).
2. Für jedes Profil dieselben Chunks und denselben Decoder-Roundtrip testen.
3. Anzeigezeit, verlorene Frames, erfolgreiche Transfers und Peak-Speicher
   auf realen Android- und iOS-Geräten messen.
4. Das Profil abhängig von QR-Version, Chunk-Grösse und Kameratest wählen;
   nicht pauschal alle Transfers auf eine Ebene umstellen.

Die vorhandene `MlqrTransferService` besitzt mit `MlqrTransferProfile` jetzt
eine benannte Profilwahl. `singleDataLayer` verwendet intern weiterhin die
einmalig erzeugte Chunk-Liste aus `GoTransferCodec` und verändert nur deren
Gruppierung in MLQR-Codes. Offen sind vor allem die sichtbare Profilwahl und
die Hardwaremessung.

## Tests

- [x] Go Unit-Tests für Verschlüsselung, Chunks und MLQR.
- [x] Go `go vet` ausführen.
- [x] Host-C-Shared-Build prüfen.
- [ ] `go test -race ./...` im CI ausführen.
- [ ] FFI-ABI-Roundtrip aus Dart gegen ein gebautes Host-Artefakt prüfen.
- [ ] Android arm64 Build auf Gerät prüfen.
- [ ] iOS arm64 Build auf Gerät und Simulator prüfen.
- [ ] Device-Hub-/Xcode-Logs während eines echten Transfers prüfen.

## Verifikation

```sh
cd native/transferengine
GOCACHE=/tmp/regelmaessig-go-cache go test ./...
GOCACHE=/tmp/regelmaessig-go-cache go test -race ./...
GOCACHE=/tmp/regelmaessig-go-cache go vet ./...
GOCACHE=/tmp/regelmaessig-go-cache ./scripts/build_native.sh host /tmp/regelmaessig-native
```
