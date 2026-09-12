# Erkenntnisse

In diesem Ordner halten wir Erkenntnisse fest, die während der Entwicklung,
bei Tests oder bei der Auswertung entstehen. Ein Eintrag beschreibt eine
tatsächliche Beobachtung und welche Schlussfolgerung wir daraus für das
Projekt ziehen. Vermutungen und offene Fragen werden ausdrücklich als solche
gekennzeichnet.

Begründungen für gewählte Lösungen und Architekturentscheidungen stehen im
Ordner [begruendungen](../begruendungen/). Wenn eine Erkenntnis zu einer
Entscheidung führt, werden die beiden Dokumente miteinander verlinkt.

Pro Erkenntnis wird eine Markdown-Datei mit einem aussagekräftigen Namen
angelegt, beispielsweise `001_kurzer_titel.md`. Die folgende Vorlage wird
kopiert und anhand der tatsächlichen Beobachtung ausgefüllt.

## Vorlage

```markdown
# Titel der Erkenntnis

## Datum

JJJJ-MM-TT

## Beobachtung

Was haben wir konkret beobachtet? In welchem Zusammenhang trat es auf?
Wenn vorhanden: Test, Messung oder andere Belege verlinken.

## Erkenntnis

Was lernen wir daraus? Welche Unsicherheiten oder offenen Fragen bleiben?

## Auswirkung auf das Projekt

Welche konkrete Anpassung oder weitere Untersuchung folgt daraus?
Falls keine Änderung nötig ist, dies kurz begründen.
Zugehörige Architekturentscheidungen bei Bedarf verlinken.
```
