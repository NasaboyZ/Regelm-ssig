# Dynamische Multi-Layer-QR-Übertragung

## Erkenntnis und Ziel

Die Anzahl der Multi-Layer-QR-Codes (MLQR) ist ein Ergebnis der Transferplanung. Sie soll sich automatisch aus der tatsächlichen Datenmenge und einem zuverlässig lesbaren Transferprofil ergeben. Eine feste Anzahl von zwei, drei oder vier Codes ist keine Anforderung.

Ein repräsentativer Jahresdatensatz mit Zyklusdaten soll unter definierten Testbedingungen in weniger als 120 Sekunden vollständig übertragen werden. Einzelne Codes sollen zügig erkannt werden, damit Nutzer die Kamera nicht lange auf dasselbe Bild richten müssen. Als vorläufiges, noch zu prüfendes Ziel gelten höchstens fünf Sekunden Erkennungsdauer je Code.

Weniger Codes bedeuten nicht automatisch einen schnelleren Transfer. Eine höhere Layerzahl erhöht die Kapazität, kann aber die Farbtrennung und damit die Kameraerkennung erschweren. Mehrere einfachere Codes können deshalb schneller übertragen werden als wenige komplexe Codes. Welche Kombination geeignet ist, muss gemessen werden.

Dieses Dokument beschreibt das Konzept und die Anforderungen. Es belegt weder eine bereits erfolgte Implementierung noch gemessene Übertragungszeiten.

## Begriffe

| Begriff         | Bedeutung                                                                          |
| --------------- | ---------------------------------------------------------------------------------- |
| Chunk           | Teil der zu übertragenden Daten                                                    |
| Nutzdaten-Layer | Schicht, die einen Datenchunk trägt; diese Zuordnung ist im Projekt zu prüfen      |
| MLQR-Code       | Ein sichtbares Bild mit mehreren kombinierten QR-Layern                            |
| Transferprofil  | Unterstützte Kombination aus Chunkgrösse, QR-Dichte, Fehlerkorrektur und Layerzahl |

## Mathematische Grundlage

### Datenmenge und Chunks

Ausgangspunkt ist die tatsächliche Byteanzahl nach der im Projekt vorgesehenen Serialisierung, Kompression und Verschlüsselung. Die erwähnten zehn Chunks für ein Jahr sind nur ein Rechenbeispiel.

Wenn `B` die aufzuteilende Byteanzahl und `C` die maximal verfügbare Nutzdatenkapazität je Chunk bezeichnet, gilt:

```text
K = ceil(B / C)
```

- `K`: Anzahl Datenchunks
- `ceil`: auf die nächste ganze Zahl aufrunden

Die Formel setzt eine konstante effektive Chunkkapazität voraus. Header, Verschlüsselungsaufwand, Metadaten und Redundanz müssen entsprechend ihrer tatsächlichen Position im Format berücksichtigt werden. Sie dürfen weder vergessen noch doppelt abgezogen werden. Wenn die Kapazität vom Chunkindex oder von der Gesamtzahl abhängt, muss die Berechnung dies berücksichtigen.

### Codeanzahl

Wenn genau ein Datenchunk in einen Nutzdaten-Layer passt und ein Profil maximal `L` solche Layer pro Code zulässt:

```text
N = ceil(K / L)
```

Als mathematische Gleichung:

$$
N = \left\lceil \frac{\text{Chunkanzahl}}{\text{Nutzdaten-Layer pro Code}} \right\rceil
$$

Die Klammern bedeuten: Das Ergebnis wird auf die nächste ganze Zahl aufgerundet.

- `N`: benötigte MLQR-Codeanzahl
- `L`: maximale Nutzdaten-Layer je Code, ohne reservierte Layer

Beispiel: `ceil(10 / 4) = ceil(2.5) = 3`. Zwei Codes hätten nur Platz für acht Chunks. Deshalb wird ein dritter benötigt.

| Datenchunks K | Maximale Nutzdaten-Layer L | Codes N | Gleichmässige Belegung |
| ------------- | -------------------------- | ------- | ---------------------- |
| 10            | 3                          | 4       | 3 + 3 + 2 + 2          |
| 10            | 4                          | 3       | 4 + 3 + 3              |
| 10            | 7                          | 2       | 5 + 5                  |
| 10            | 15                         | 1       | 10                     |

Diese Werte sind Kapazitätsbeispiele, keine Empfehlung für konkrete Layerprofile. Unterschiedliche Belegungen oder Layerzahlen müssen vom Format unterstützt werden. Ein Profil mit maximal 15 Layern benötigt nicht zwangsläufig 15 aktive Nutzdaten-Layer.

Die Formel berechnet die Codeanzahl erst, nachdem Chunkgrösse und Layerkapazität gewählt wurden. Sie optimiert die Kameraerkennung nicht.

### Gleichmässige Verteilung

Für `K > 0` und `N` benötigte Codes:

```text
q = floor(K / N)
r = K mod N

r Codes erhalten jeweils q + 1 Chunks.
Die übrigen N - r Codes erhalten jeweils q Chunks.
```

Bei zehn Chunks und drei Codes sind `q = 3` und `r = 1`. Daraus folgt `4 + 3 + 3`. Das gilt bei gleicher Chunkkapazität und sofern der Encoder diese Belegung erlaubt. Bei ungleich grossen Chunks muss zusätzlich die Bytekapazität pro Layer eingehalten werden. Für einen leeren Datensatz ist das Verhalten separat festzulegen; die Verteilungsformel darf nicht durch null teilen.

### Gesamtdauer

```text
Gesamtdauer = Vorbereitungszeit
            + Erkennungszeit aller Codes zusammen
            + Zeit für alle Codewechsel
            + zusätzliche Zeit für Wiederholungen
            + Abschlusszeit

Ziel: Gesamtdauer < 120 Sekunden
```

Als Gleichung ohne Summenzeichen:

$$
\begin{aligned}
\text{Gesamtdauer} ={}& \text{Vorbereitungszeit} \\
&+ \text{Erkennungszeit aller Codes zusammen} \\
&+ \text{Zeit für alle Codewechsel} \\
&+ \text{zusätzliche Zeit für Wiederholungen} \\
&+ \text{Abschlusszeit}
\end{aligned}
$$

Dabei bedeutet:

- **Vorbereitungszeit:** Daten aufbereiten und die Codes erzeugen.
- **Erkennungszeit aller Codes zusammen:** Die benötigte Erkennungszeit für Code 1, Code 2 und alle weiteren Codes addieren.
- **Zeit für alle Codewechsel:** Die zusätzlichen Zeitabschnitte zwischen den angezeigten Codes.
- **Zusätzliche Zeit für Wiederholungen:** Zeit, die durch erfolglose Versuche und erneutes Scannen entsteht.
- **Abschlusszeit:** Empfangene Daten zusammensetzen, entschlüsseln und prüfen.

Rechenbeispiel mit frei gewählten, nicht gemessenen Zeiten: Die Vorbereitung dauert 2 Sekunden. Drei Codes benötigen jeweils 4 Sekunden zur Erkennung, also zusammen 12 Sekunden. Alle Codewechsel dauern zusammen 2 Sekunden, Wiederholungen benötigen 3 Sekunden und der Abschluss 1 Sekunde.

$$
\text{Gesamtdauer} = 2 + (4 + 4 + 4) + 2 + 3 + 1 = 20\,\text{Sekunden}
$$

Dieses Beispiel erklärt nur die Rechnung; es ist kein Nachweis der tatsächlichen Transfergeschwindigkeit.

Die Erkennungszeiten beziehen sich hier auf erfolgreiche Erkennungsversuche. Zusätzlicher Aufwand durch fehlgeschlagene Versuche wird unter Wiederholungen erfasst. Zeitabschnitte dürfen nicht doppelt gezählt werden; für den Nachweis zählt die direkt gemessene verstrichene Gesamtdauer. Überlappende Verarbeitung muss bei der Auswertung berücksichtigt werden.

Die Messung beginnt mit dem Start des Transfers einschliesslich Datenvorbereitung und endet nach vollständiger Rekonstruktion und erfolgreicher Prüfung beim Empfänger. Geräte, Licht, Bildschirm, Abstand und der verwendete Jahresdatensatz müssen für vergleichbare Tests dokumentiert werden.

## Ablauf der automatischen Transferplanung

1. **Datenmenge bestimmen.** Den Datensatz mit der vorhandenen Verarbeitung vorbereiten und den tatsächlich erforderlichen Übertragungsumfang ermitteln.
2. **Geeignete Profile ermitteln.** Nur Kombinationen berücksichtigen, die Encoder und Decoder unterstützen. QR-Dichte, Chunkgrösse, Layerzahl und Fehlerkorrektur gemeinsam betrachten.
3. **Aufteilung je Profil berechnen.** Effektive Kapazitäten, Chunkanzahl und Codeanzahl inklusive aller Formatgrenzen berechnen.
4. **Geschwindigkeit und Zuverlässigkeit bewerten.** Gemessene Erkennungszeiten, Erfolgsquoten, Wechselzeiten und Wiederholungen verwenden. Keine Geschwindigkeit allein aus der Codeanzahl ableiten.
5. **Profil auswählen.** Ein geeignetes Profil anhand kurzer erwarteter Gesamtdauer und ausreichender gemessener Zuverlässigkeit wählen. Solange Messdaten fehlen, ein konfigurierbares konservatives Standardprofil verwenden und Annahmen kenntlich machen.
6. **Daten möglichst gleichmässig verteilen.** Kapazitätsgrenzen einhalten und die Unterstützung unterschiedlicher Belegungen prüfen.
7. **Transfer durchführen.** Bereits empfangene Chunks erkennen, fehlende Codes erneut anbieten und den Fortschritt anzeigen. Bei automatischem Bildwechsel müssen Anzeigedauer und Wiederholungsschleife ausreichend Gelegenheit zur Erkennung geben. Eine Empfangsbestätigung setzt einen tatsächlich vorhandenen Rückkanal voraus.
8. **Rekonstruieren und prüfen.** Erst nach vollständiger Rekonstruktion und den vorgesehenen Integritätsprüfungen Erfolg melden.
9. **Messen und verbessern.** Tatsächliche Erkennungsdauer je Code, Wiederholungen, Erfolgsquote und Gesamtdauer erfassen und damit die Profilwahl verbessern.

Eine Auswahl anhand zuvor gemessener Profile ist bereits automatisch. Eine zusätzliche Anpassung während des Transfers ist ein weiterer Mechanismus und benötigt passende Messwerte sowie gegebenenfalls einen Rückkanal.

## Validierung und Grenzen

- Funktionstests prüfen Chunkaufteilung, Kapazitätsgrenzen, Reihenfolge, doppelte und fehlende Chunks sowie die vollständige Rekonstruktion.
- Reale Kameratests prüfen Erkennungsdauer, Wiederholungen und Gesamtdauer für kleine Datensätze und einen definierten Jahresdatensatz.
- Neben Durchschnittswerten sollen Streuung, langsame Durchläufe und fehlgeschlagene Transfers dokumentiert werden.
- Wenn kein getestetes Profil das Ziel erreicht, muss dies als Ergebnis ausgewiesen werden. Die Mathematik allein garantiert keine Übertragung unter zwei Minuten.

## Anforderung für die Bachelorarbeit

Das System soll die Chunkgrösse, die Anzahl der Nutzdaten-Layer und die daraus resultierende Anzahl der Multi-Layer-QR-Codes anhand der tatsächlichen Datenmenge und empirisch geprüfter Transferprofile automatisch bestimmen. Die Auswahl soll eine kurze Erkennungsdauer je Code und eine Gesamtübertragungsdauer von unter zwei Minuten für einen definierten Jahresdatensatz anstreben. Die Daten sollen unter Einhaltung der Kapazitätsgrenzen möglichst gleichmässig auf die benötigten Codes verteilt werden. Die Zielerreichung ist durch reale Kameramessungen unter dokumentierten Bedingungen nachzuweisen.
