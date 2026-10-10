# iPhone-Erkenntnisse: Bedienbarkeit und Design

## Datum

10.10.2026

## Beobachtung

Beim Ausprobieren der App auf dem eigenen iPhone sind zu kleine Schriften und
Bedienflächen, zu geringe Abstände und gestalterische Brüche aufgefallen.
Besonders die geöffneten Erfassungskategorien wirken teilweise unübersichtlich.
Bei der Notizeingabe wurde zudem fehlerhaftes Verhalten gemeldet.

Quelle ist der persönliche Gerätetest des Projektverantwortlichen. iPhone-Modell,
iOS-Version und App-Build wurden nicht festgehalten. Die Beobachtungen sind noch
nicht unabhängig reproduziert; technische Ursachen sind nicht bestätigt.

## Erkenntnis

Die geschlossenen Kategorien sind übersichtlich und sollen diese Qualität
behalten. Innerhalb geöffneter Kategorien braucht es mehr Platz, bessere
Lesbarkeit und eine klare visuelle Hierarchie. Die Untertitel „Stärke“ und
„Gerinnsel“ in „Blutung“ sind dafür ein positives Beispiel.

Dialoge, Eingaben, Buttons und Rückmeldungen sollen dieselbe visuelle Identität
der App (CI/CD) vermitteln und sich auf dem iPhone sorgfältig gestaltet anfühlen.
Das gemeldete Notizproblem erfordert zusätzlich eine technische Untersuchung.

## Auswirkung auf das Projekt: offene Todos

### Erfassungsbildschirm

- [ ] **E1 – Auswahlflächen und Schriften vergrössern**
  - **Beobachtung:** Die Auswahlbuttons für Blutung und andere Tagesangaben sind
    zu klein und stehen zu dicht nebeneinander.
  - **Verbesserung:** Schrift und antippbare Flächen vergrössern; mehr Abstand
    zwischen Optionen und Zeilen schaffen.
  - **Prüfkriterium:** Auf dem iPhone sind Beschriftungen gut lesbar und einzelne
    Optionen gezielt antippbar, ohne versehentlich Nachbaroptionen zu treffen.

- [ ] **E2 – „Für heute nichts eintragen“ besser lesbar machen**
  - **Beobachtung:** Der Text unter „Eintrag speichern“ ist deutlich zu klein.
  - **Verbesserung:** Die sekundäre Abschlussaktion mit grösserer Schrift und
    ausreichend grosser Bedienfläche gestalten; entsprechende Texte für andere
    Tage ebenfalls berücksichtigen.
  - **Prüfkriterium:** Die Aktion ist ohne Anstrengung lesbar, gut antippbar und
    als eigene Handlung unter dem Speichern-Button erkennbar.

- [ ] **E3 – Geöffnete Kategorien übersichtlich gliedern**
  - **Beobachtung:** Besonders „Körperliche Symptome“ wirkt durch dicht gedrängte
    Optionen chaotisch. Bei „Blutung“ schaffen Untertitel eine hilfreiche Hierarchie.
  - **Verbesserung:** Geöffnete Kategorien auf sinnvolle Gruppierung prüfen und
    mit Zwischenüberschriften sowie klaren Abständen ordnen. Die Übersichtlichkeit
    geschlossener Kategorien beibehalten.
  - **Prüfkriterium:** Zusammengehörige Optionen und Gruppen sind auf den ersten
    Blick unterscheidbar. „Körperliche Symptome“ lässt sich gezielt durchsuchen,
    ohne als ungegliederte Ansammlung von Buttons zu wirken.

- [ ] **E4 – Terminerfassung neu gestalten**
  - **Beobachtung:** Das Termin-Modal hat zu kleine Schriften, wirkt unpassend und
    fühlt sich gestalterisch wenig ausgearbeitet an.
  - **Verbesserung:** Aufbau, Typografie, Abstände und Bedienung des Dialogs
    überarbeiten und an die visuelle Identität der App anpassen.
  - **Prüfkriterium:** Felder und Aktionen sind gut lesbar und erreichbar, auch
    mit geöffneter Tastatur. Der Dialog wirkt wie ein zusammengehöriger Teil der App.

- [ ] **E5 – Gemeldeten Funktionsfehler bei Notizen untersuchen und beheben**
  - **Beobachtung:** Beim Schreiben verschwinden nach Nutzerbericht Inhalte;
    unerwartet erscheint ein Menü mit „Undo“, „Cut“, „Copy“, „Paste“ und „Redo“.
    Die gesamte Ansicht wirkt dabei instabil. Ursache und genaue Auslöser sind offen.
  - **Verbesserung:** Den Ablauf auf dem iPhone reproduzieren und die Auslöser
    dokumentieren. Texteingabe, Cursor, Auswahl und Fokus stabilisieren; den
    Notizbereich zugleich gestalterisch verbessern. Reguläre Bearbeitungsfunktionen
    sollen gezielt nutzbar bleiben.
  - **Prüfkriterium:** Beim Tippen, Korrigieren und Auswählen geht kein Text
    unbeabsichtigt verloren. Cursor und Fokus bleiben nachvollziehbar; das
    Bearbeitungsmenü erscheint nur bei einer entsprechenden Bedienhandlung.

- [ ] **E6 – Eingabe von Gewicht und Temperatur überarbeiten**
  - **Beobachtung:** Die aktuelle Eingabe wirkt wenig gestaltet und nicht angenehm
    zu bedienen; für beide Messwerte werden bessere Eingabemöglichkeiten gewünscht.
  - **Verbesserung:** Passende Eingabeformen entwerfen, die Werte, Einheiten und
    Korrekturmöglichkeiten klar darstellen. Die konkrete Eingabeform ist eine
    spätere Designentscheidung.
  - **Prüfkriterium:** Beide Werte lassen sich auf dem iPhone verständlich eingeben,
    ändern und leeren. Einheit und aktueller Wert sind eindeutig erkennbar;
    Tastatur und Fehlermeldungen verdecken keine benötigten Aktionen.

### App-weite Rückmeldungen

- [ ] **A1 – Toast-/Snackbar-Meldungen an die App-Gestaltung anpassen**
  - **Beobachtung:** Die Meldungen wirken ungestaltet, passen nicht zum CI/CD und
    zeigen keinen eigenen Charakter.
  - **Verbesserung:** Farben, Schrift, Form und Abstände zu einer einheitlichen,
    wiedererkennbaren Gestaltung der Rückmeldungen zusammenführen.
  - **Prüfkriterium:** Erfolgs- und Fehlermeldungen sind gut lesbar, verständlich
    unterscheidbar und passen sichtbar zu den übrigen App-Komponenten.

### Home-Screen

- [ ] **H1 – Weissen Balken am oberen Bildschirmrand beseitigen**
  - **Beobachtung:** Beim Scrollen bleibt oben ein weisser Balken sichtbar, der die
    durchgehende Gestaltung unterbricht. Ob die App-Bar die Ursache ist, ist offen.
  - **Verbesserung:** Das verursachende Element ermitteln und den oberen Bereich
    gestalterisch nahtlos in den Screen integrieren. Statusleiste und sichere
    Bedienbereiche berücksichtigen.
  - **Prüfkriterium:** Beim Öffnen und Scrollen entsteht kein abgesetzter weisser
    Streifen. Die Fläche wirkt durchgehend; Statusinformationen bleiben lesbar und
    Bedienelemente werden nicht von Geräteaussparungen verdeckt.

- [ ] **H2 – Kalender auf dem Home-Screen vergrössern**
  - **Beobachtung:** Die Kalenderdarstellung ist trotz verfügbarem Platz zu klein.
  - **Verbesserung:** Mehr Platz für den Kalender nutzen und seine Inhalte
    entsprechend grösser darstellen.
  - **Prüfkriterium:** Tage und Markierungen sind auf dem iPhone besser lesbar und
    antippbar. Die Vergrösserung nutzt den freien Platz, ohne Inhalte abzuschneiden.

### Zyklusverlauf-Screen

- [ ] **Z1 – „Heute“ und „Monat wählen“ vergrössern und vereinheitlichen**
  - **Beobachtung:** Die beiden Buttons sind zu klein, unterscheiden sich von den
    Home-Buttons und passen farblich nicht zum CI/CD.
  - **Verbesserung:** Grösse, Typografie, Form und Farben an die entsprechende
    Button-Gestaltung des Home-Screens angleichen.
  - **Prüfkriterium:** Beide Aktionen sind gut lesbar und antippbar; ihre Gestaltung
    folgt sichtbar derselben Designsprache wie auf dem Home-Screen.

- [ ] **Z2 – Legende grösser und präsenter darstellen**
  - **Beobachtung:** Die Legende ist zu klein und visuell zu zurückhaltend.
  - **Verbesserung:** Schrift, Markierungen und Abstände vergrössern.
  - **Prüfkriterium:** Beschriftungen und zugehörige Markierungen sind auf dem
    iPhone leicht lesbar und eindeutig zuzuordnen, auch bei mehrzeiliger Darstellung.

## Gemeinsame Abnahme

Die Todos bleiben bis zur Umsetzung und Überprüfung offen. Für die spätere
Abnahme gilt:

- Erneut auf einem echten iPhone prüfen und Modell, iOS-Version sowie App-Build
  festhalten.
- Normale und vergrösserte Systemschrift prüfen: keine abgeschnittenen Texte,
  überlappenden Elemente oder unerreichbaren Aktionen.
- Eingabebereiche zusätzlich mit geöffneter Tastatur prüfen.
- Lesbarkeit, Abstände, zuverlässige Eingaben und konsistente Gestaltung über
  Erfassung, Home und Zyklusverlauf hinweg beurteilen.
- Beim Notizfehler die Reproduktionsschritte und das Ergebnis nach der Behebung
  dokumentieren; die Prüfung muss den ursprünglich gemeldeten Ablauf abdecken.

Dieser Eintrag dokumentiert Beobachtungen und Folgeaufgaben. Er bestätigt noch
keine Behebung und legt keine neuen Schnittstellen oder Datenmodelle fest.
