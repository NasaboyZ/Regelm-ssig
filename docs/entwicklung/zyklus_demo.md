# Ein Jahr Zyklusdaten im Simulator

```sh
flutter run -t lib/main_cycle_demo.dart
```

Nach dem Onboarding zeigt die App 365 Tage erfundene Beobachtungen bis zum
Startdatum. Der Kalender enthält 13 Perioden mit jeweils 4–6 Blutungstagen,
3 Schmierblutungen mit jeweils 2 Tagen und Tageserfassungen für Stimmung,
Symptome, Notizen, Temperatur und Gewicht. Manche Tage bleiben bewusst leer.
Das Banner «ZYKLUS-DEMO» kennzeichnet diesen Start.

Die Daten liegen im Arbeitsspeicher. Änderungen funktionieren über die normalen
Views, ViewModels und das Repository. Ein vollständiger Neustart oder Hot Restart
setzt die Demo zurück und richtet sie wieder am heutigen Datum aus.
Die normale SQLCipher-Datenbank wird dabei nicht geöffnet oder überschrieben.
Zum normalen Start zurückkehren: `flutter run -t lib/main.dart`.

## Erwartete Ergebnisse direkt nach dem Start

Die zwölf abgeschlossenen Zykluslängen sind chronologisch:
`26, 28, 30, 27, 29, 28, 26, 30, 27, 29, 28, 31` Tage.
Der Rechner verwendet die letzten sechs: sortiert `26, 27, 28, 29, 30, 31`.
Der Median ist 28,5, gerundet **29 Tage**.

| Anzeige | Erwartung |
| --- | --- |
| Aktueller Zyklustag | 20 |
| Abgeschlossene / auswertbare Zyklen | 12 / 12 |
| Geschätzte Zykluslänge | 29 Tage |
| Ø Zyklus in der Home-Karte | ≈ 28 Tage aus 12 Zyklen |
| Ø Periode in der Home-Karte | ≈ 5 Tage aus 13 Perioden |
| Nächster geschätzter Beginn | in 10 Tagen |
| Historische Spanne | heute +7 bis +12 Tage |
| Prognose | persönlich, Zustimmung in den Dummy-Daten gesetzt |

Beispiel beim Start am **03.10.2026**: Tagesdaten ab 04.10.2025, erster
Periodenbeginn 10.10.2025, letzter Beginn 14.09.2026, nächste Schätzung 13.10.2026,
Spanne 10.–15.10.2026. Schmierblutungen zählen nicht als Zyklusbeginn.

Die Durchschnittszeile beschreibt alle vorhandenen auswertbaren Beobachtungen:
Zykluslängen als arithmetisches Mittel der Abstände zwischen Periodenbeginnen
(28,25 Tage), Periodenlängen inklusive Start- und Endtag (64 / 13 Tage).
Markierte Erfassungslücken zählen nicht als Zyklusintervall; Perioden ohne
bekanntes Ende und Schmierblutungen zählen nicht zur durchschnittlichen
Periodenlänge. Die Anzeige rundet auf ganze Tage und zeigt bei fehlenden Daten
einen Strich. Diese Rückschau bleibt auch bei pausierter Prognose sichtbar.
Die Prognose verwendet weiterhin den Median der letzten sechs geeigneten
Zyklen; ihre Berechnungsangaben stehen unter «Details».

## Prüfen

```sh
flutter test test/cycle_demo_test.dart
```

Die Tests prüfen bekannte Sollwerte, JSON-Roundtrip, eine markierte Erfassungslücke,
Schaltjahr-/Zeitumstellungsdaten und den Datenfluss Erfassung → Repository →
Home-/Kalender-ViewModel. Manuell kannst du heute einen neuen Periodenbeginn
eintragen: Der Zyklustag muss auf 1 wechseln und der Kalender ihn markieren.
Pausierst du die Prognose in den Details, verschwinden die Vorhersagen;
erfasste Blutungen bleiben sichtbar.

Der Datensatz prüft die implementierte Rechenregel und den MVVM-Datenfluss.
Er ist keine medizinische Validierung und kein Test der SQLCipher-Persistenz.
