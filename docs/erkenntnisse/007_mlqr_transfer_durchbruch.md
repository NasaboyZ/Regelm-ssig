# MLQR-Transfer-Durchbruch durch eine kompaktere Sequenz

## Datum

03-11-2026

## Beobachtung

Die Übertragung eines Jahres zyklischer Daten zwischen zwei physischen
Geräten funktioniert mit der aktuellen MLQR-/temporalen Transfersequenz. Im
praktischen Test fühlt sich der Transfer ungefähr 30-mal schneller an als
zuvor. Diese Zahl ist eine subjektive Beobachtung und keine reproduzierte
Benchmark-Messung.

Die relevante Änderung liegt in der Sendesequenz:

- `temporalRounds` wurde von `3` auf `1` reduziert.
- Das Anzeigeintervall der echten Transfersequenz wurde von `3 s` auf `1,5 s`
  reduziert.
- Die temporalen Frames bleiben als einmaliger Recovery-Pass erhalten.
- Doppelte Chunks bleiben durch den `TransferChunkAccumulator` idempotent;
  sie werden nicht doppelt importiert.

Damit muss die Kamera nicht mehr drei vollständige temporale Durchläufe
scannen. Die grobe Frame-Anzahl sinkt von `L + 3C` auf `L + C`, wobei `L` die
MLQR-Sequenzen und `C` die temporalen Frames bezeichnet.

Für das vorhandene Jahres-Testfixture entstehen 1 MLQR-Bild und 7 temporale
Frames. Die reine Anzeigezeit beträgt damit rechnerisch:

```text
alt:  (1 + 3 × 7) × 3,0 s = 66 s
neu:  (1 + 1 × 7) × 1,5 s = 12 s
```

Das sind Anzeigezeiten für einen vollständigen Durchlauf, nicht automatisch
die gesamte Kamera-zu-Datenbank-Zeit. Die Flutter-Entwicklungsansicht zeigt
die aktuelle berechnete Anzeigezeit an. Zusätzlich werden unter
`flutter run`/Device Hub die Ereignisse `transfer.encode`,
`transfer.display_ready`, `transfer.receive_started` und
`transfer.receive_finished` ausgegeben.

## Erkenntnis

Der wesentliche Geschwindigkeitsgewinn stammt aus der Reduktion unnötiger
Wiederholungen im optischen Kanal, nicht aus einer bereits nachgewiesenen
Go-Ausführung. Die lokale Go-Engine ist in Flutter optional angebunden:
`GoTransferCodec.tryLoad()` und `GoMlqrRenderer.tryLoad()` fallen auf Dart
zurück, wenn kein natives Plattformartefakt geladen werden kann. Für die
aktuelle mobile Ausführung ist daher nicht belegt, dass Go die beobachtete
Beschleunigung verursacht.

Auch die theoretische Untergrenze erklärt nicht automatisch eine 30-fache
Beschleunigung. Bei gleicher Chunk-Anzahl und den aktuellen Parametern ergibt
die grobe Modellrechnung:

```text
vorher = (L + 3C) * 3,0 s
nachher = (L + C) * 1,5 s
vorher / nachher = 2 * (L + 3C) / (L + C)
```

Der Faktor liegt in diesem Modell höchstens ungefähr bei 8, wenn die
temporalen Frames dominieren. Die subjektive 30-fache Wahrnehmung kann daher
zusätzlich durch frühere Abbrüche, verlorene Frames, erneute Versuche oder
Wartezeiten in der Kamera-Pipeline entstanden sein. Das ist eine plausible
Erklärung, aber noch keine Messung.

Die Architekturentscheidung lautet deshalb:

1. Die robuste Standardsequenz verwendet genau einen temporalen Recovery-Pass.
2. Weitere Wiederholungen werden nicht pauschal gesendet, sondern später nur
   adaptiv bei nachgewiesen schlechter Scanqualität aktiviert.
3. Go bleibt eine austauschbare Optimierungsgrenze. Die fachliche Transfer-
   und Verschlüsselungslogik bleibt über die Flutter-Schnittstellen testbar.
4. Flutter bleibt für MVVM, UI-State, Kamera-Lifecycle und Darstellung
   verantwortlich; die Transferengine liefert Daten und Raster, aber keine
   UI-Entscheidungen.

## Auswirkung auf das Projekt

Die aktuelle Lösung erreicht das Ziel eines deutlich kürzeren optischen
Transfers, ohne die Kamerarobustheit vollständig aufzugeben. Die
Messinstrumentierung ist vorhanden. Als nächster Schritt braucht es einen
reproduzierbaren Benchmark auf mindestens einem Sender-/Empfänger-Paar:

- gleiche Jahresdaten und gleiche Chunk-Grösse,
- Messung von Encoding, Anzeigezeit, erkannter Chunk-Rate und Commit-Zeit,
- mindestens zehn Wiederholungen pro Sequenzprofil,
- Vergleich von `1` und `3` temporalen Runden,
- getrennte Messung mit geladenem Go-Artefakt und Dart-Fallback.

Die Architektur- und Ablaufgrafik steht in
[`qr_transfer_durchbruch.adoc`](../entwicklung/qr_transfer_durchbruch.adoc).
Die historische Diagnose bleibt in
[`006_transferproblem_aktueller_stand.md`](006_transferproblem_aktueller_stand.md)
erhalten und wird durch diese Erkenntnis ergänzt.
