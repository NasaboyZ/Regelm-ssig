# Entwicklungsplan & Kanban-Board

Ein detaillierter Umsetzungsplan für die App. Zuerst entsteht das UI-Gerüst,
danach folgen die vier Entwicklungsphasen aus dem Projektplan. Jede Aufgabe ist
so formuliert, dass du sie direkt als GitHub-Issue und Kanban-Karte übernehmen
kannst.

> Grundprinzip: erst das sichtbare Gerüst (Screens ohne Logik), dann Schicht für
> Schicht die Logik dahinter. So hast du früh etwas Sichtbares und baust die
> anspruchsvolle Sicherheitslogik auf einem stabilen Fundament auf.

> Architektur: schichtenbasiert nach dem MVVM-Prinzip — View (Oberfläche),
> ViewModel (Steuerungslogik der Screens), Model (Daten, Datenbank,
> Verschlüsselung, Algorithmus).

> Ehrlicher Hinweis: Die App ist in Entwicklung. Der echte Kamera-Scan des
> farbigen Codes ist der anspruchsvollste, offene Teil und bewusst in Phase 3
> als Forschungsschritt markiert.

---

## So richtest du das Board auf GitHub ein

1. Im Repository auf **Projects** → **New project** → Vorlage **Board** wählen.
2. Spalten (Status) anlegen: **Backlog**, **To Do**, **In Progress**, **Review**, **Done**.
3. Für jede Aufgabe unten ein **Issue** erstellen (Titel + Beschreibung + Haken-Liste).
4. Dem Issue die vorgeschlagenen **Labels** geben und es dem Project zuordnen.
5. Neue Issues landen im **Backlog**; ziehe die aktuelle Phase nach **To Do**.

### Labels, die du einmal anlegst
- `sprint-0`, `phase-1`, `phase-2`, `phase-3`, `phase-4` (zeitliche Zuordnung)
- `ui`, `viewmodel`, `model`, `security`, `algorithm`, `test`, `docs` (Art der Arbeit)
- `must`, `should` (Priorität nach MoSCoW)

---

# Sprint 0 — Fundament & UI-Gerüst
`sprint-0`

Ziel: ein lauffähiges App-Gerüst mit allen Screens als statische Ansichten und
funktionierender Navigation, noch ohne echte Logik. Am Ende kann man durch die
ganze App klicken, sieht aber nur Beispiel-Daten.

### S0-1 · Flutter-Projekt aufsetzen und Repository strukturieren
`sprint-0` `docs`
- [ ] Flutter-Projekt anlegen, in Git-Repository überführen
- [ ] Ordnerstruktur nach Funktionsbereichen mit je View/ViewModel/Model
- [ ] README mit Projektbeschreibung und Setup-Anleitung
- [ ] `.gitignore` für Flutter einrichten

### S0-2 · Architektur- und State-Management-Grundgerüst
`sprint-0` `viewmodel`
- [ ] State-Management-Werkzeug auswählen (auf pub.dev auf Aktualität prüfen)
- [ ] Basis-Struktur für ViewModels festlegen
- [ ] Beispielhafter Datenfluss View → ViewModel → Model als Vorlage
- [ ] Entscheidung im Doku-Ordner kurz begründen

### S0-3 · Design-System und wiederverwendbare Komponenten
`sprint-0` `ui`
- [ ] Farben, Typografie und Abstände zentral definieren
- [ ] Button-Komponenten (primär, sekundär)
- [ ] Eingabefelder und Auswahl-Chips (für die Kategorien)
- [ ] Wiederverwendbare Karten- und Listenelemente

### S0-4 · Navigation und Routing
`sprint-0` `ui`
- [ ] Routing zwischen allen Haupt-Screens einrichten
- [ ] Untere Navigationsleiste oder Menü (Home, Kalender, Transfer)
- [ ] Übergänge testen

### S0-5 · Splashscreen (statisch)
`sprint-0` `ui`
- [ ] Startbildschirm mit Logo/Titel gestalten
- [ ] Automatischer Übergang zum Onboarding bzw. Home

### S0-6 · Onboarding-Screens (statisch)
`sprint-0` `ui`
- [ ] Kurze Einführung in die App (1–3 Schritte)
- [ ] Oberfläche für die Passphrase-Eingabe (nur Ansicht, ohne Logik)
- [ ] Hinweistext zur Bedeutung der Passphrase

### S0-7 · Home-Screen UI (statisch, Beispiel-Daten)
`sprint-0` `ui`
- [ ] Begrüssung und persönlicher Bereich
- [ ] Platz für Zyklus-Vorschau (Beispielwert)
- [ ] Tageswerte-Bereich (Temperatur, Gewicht als Platzhalter)
- [ ] Schnellzugriff „Eintrag für heute“ und Sprung zum Kalender

### S0-8 · Eingabe-Screen UI (statisch, alle Kategorien)
`sprint-0` `ui`
- [ ] Kategorien als antippbare Bereiche: Blutung, Stimmung, Symptome
- [ ] Kategorien: sexuelle Aktivität, Verhütung, Tests
- [ ] Kategorien: Termine, Notizen, Temperatur, Gewicht
- [ ] Auswahl-Optionen je Kategorie als Chips darstellen (ohne Speichern)

### S0-9 · Kalender-Screen UI (statisch)
`sprint-0` `ui`
- [ ] Monatsansicht mit Beispiel-Markierungen
- [ ] Antippen eines Tages öffnet die Eingabe-Ansicht

### S0-10 · Transfer-Screen UI (statisch)
`sprint-0` `ui`
- [ ] Ansicht „Senden“ mit Platzhalter für den farbigen Code
- [ ] Ansicht „Empfangen“ mit Platzhalter
- [ ] Passphrase-Abfrage als Oberfläche (ohne Logik)

---

# Phase 1 — Speicherung & Verschlüsselung
`phase-1`

Ziel: Daten werden lokal, verschlüsselt und dauerhaft gespeichert. Am Ende kann
die Nutzerin einen echten Eintrag anlegen, der verschlüsselt in der Datenbank
landet und wieder korrekt geladen wird.

### P1-1 · Datenmodelle definieren
`phase-1` `model` `must`
- [ ] Modell für einen Tageseintrag (Datum + gewählte Kategorien)
- [ ] Modelle für Notiz und Termin
- [ ] Struktur für die Auswahl-Optionen je Kategorie
- [ ] Modelle dokumentieren

### P1-2 · Lokale Datenbank einrichten
`phase-1` `model` `must`
- [ ] Datenbank-Paket auswählen und einbinden (auf pub.dev prüfen)
- [ ] Tabellen/Strukturen für die Modelle anlegen
- [ ] Grundlegende Speicher- und Ladefunktion testen

### P1-3 · Verschlüsselung der Datenbank (AES-256)
`phase-1` `security` `must`
- [ ] Verschlüsselte Datenbank-Variante einbinden (AES-256 bestätigen)
- [ ] Prüfen, dass die Datei ohne Schlüssel nicht lesbar ist
- [ ] Entscheidung und Verfahren dokumentieren

### P1-4 · Schlüsselableitung aus der Passphrase
`phase-1` `security` `must`
- [ ] Kryptografie-Paket einbinden (auf pub.dev prüfen)
- [ ] Schlüssel aus Passphrase ableiten (KDF, z. B. Argon2/PBKDF2)
- [ ] Sicherstellen, dass der Schlüssel nirgends gespeichert wird
- [ ] Verfahren dokumentieren (wichtig für die Arbeit)

### P1-5 · Passphrase-Logik im Onboarding anbinden
`phase-1` `viewmodel` `must`
- [ ] Passphrase beim ersten Start festlegen
- [ ] Passphrase beim App-Start abfragen und Schlüssel ableiten
- [ ] Fehlerfall behandeln (falsche Passphrase)

### P1-6 · CRUD-Logik für Einträge
`phase-1` `model` `must`
- [ ] Eintrag erstellen
- [ ] Einträge lesen (einzeln und als Liste)
- [ ] Eintrag bearbeiten
- [ ] Eintrag löschen

### P1-7 · Eingabe-Screen mit Speicher-Logik verbinden
`phase-1` `viewmodel` `must`
- [ ] ViewModel für die Eingabe erstellen
- [ ] Auswahl der Nutzerin entgegennehmen und speichern
- [ ] Rückmeldung nach dem Speichern anzeigen

### P1-8 · Home-Screen mit echten Daten verbinden
`phase-1` `viewmodel` `should`
- [ ] Heutigen bzw. letzten Eintrag laden und anzeigen
- [ ] Tageswerte aus echten Daten füllen

### P1-9 · Tests für Verschlüsselung und Speicherung
`phase-1` `test` `must`
- [ ] Test: gespeicherte Daten werden korrekt entschlüsselt geladen
- [ ] Test: mit falschem Schlüssel kein Zugriff
- [ ] Test: CRUD funktioniert wie erwartet

---

# Phase 2 — Multi-Layer-QR-Code
`phase-2`

Ziel: aus verschlüsselten Daten entsteht ein farbiger Multi-Layer-QR-Code, und
der eigene Algorithmus kann ihn wieder korrekt in die Ebenen zerlegen.

### P2-1 · Daten für die Übertragung vorbereiten (komprimieren + verschlüsseln)
`phase-2` `security` `must`
- [ ] Eintragsdaten in ein kompaktes Format bringen
- [ ] Daten komprimieren (zuerst mit Bordmitteln prüfen)
- [ ] Daten verschlüsseln, bevor sie in die Layer geschrieben werden
- [ ] Reihenfolge dokumentieren (Verschlüsselung ist der eigentliche Schutz)

### P2-2 · Multi-Layer-Algorithmus: Kodierung
`phase-2` `algorithm` `must`
- [ ] Partition-Berechnung implementieren
- [ ] Layer über die Farbkanäle R, G, B bündeln
- [ ] Farbiges Multi-Layer-Bild erzeugen

### P2-3 · Multi-Layer-Algorithmus: Dekodierung
`phase-2` `algorithm` `must`
- [ ] Farbwerte je Position auslesen
- [ ] Aus der Summe die aktiven Ebenen zurückrechnen
- [ ] Einzelne QR-Ebenen rekonstruieren

### P2-4 · Daten sinnvoll auf die Layer aufteilen
`phase-2` `algorithm` `should`
- [ ] Aufteilungslogik, damit ein einzelner Layer kein vollständiges Bild ergibt
- [ ] Aufteilung dokumentieren

### P2-5 · Anzeige des Multi-Layer-Codes
`phase-2` `ui` `must`
- [ ] Erzeugten Farbcode im Transfer-Screen darstellen
- [ ] Kapazitätsvergleich normaler QR vs. Multi-Layer sichtbar machen (optional)

### P2-6 · Tests: Kodierung und Dekodierung
`phase-2` `test` `must`
- [ ] Test: kodieren und wieder dekodieren ergibt identische Daten (100 %)
- [ ] Test mit verschieden grossen Datenmengen
- [ ] Grenzfälle prüfen (leer, sehr gross)

---

# Phase 3 — Transfer & Empfang
`phase-3`

Ziel: Daten wandern verschlüsselt und serverlos von einem Gerät auf ein anderes
und werden dort korrekt wiederhergestellt.

### P3-1 · Session-Verbindung über Standard-QR
`phase-3` `must`
- [ ] Session-ID erzeugen
- [ ] Standard-Session-QR anzeigen (normal lesbar)
- [ ] Session-QR mit `mobile_scanner` scannen
- [ ] Verbindung zwischen den Geräten herstellen

### P3-2 · Sende-Logik
`phase-3` `model` `must`
- [ ] Nutzdaten für den Versand zusammenstellen
- [ ] Grosse Inhalte in Teile zerlegen und nacheinander senden
- [ ] Abschluss-Signal senden

### P3-3 · Empfangs-Logik auf dem Zweitgerät
`phase-3` `model` `must`
- [ ] Empfangene Teile sammeln und ordnen
- [ ] Vollständigkeit prüfen
- [ ] Daten wieder zusammensetzen

### P3-4 · Wiederherstellung und Entschlüsselung
`phase-3` `security` `must`
- [ ] Passphrase auf dem Zweitgerät abfragen, Schlüssel ableiten
- [ ] Empfangene Daten entschlüsseln
- [ ] Daten in die lokale Datenbank des Zweitgeräts speichern

### P3-5 · Kamera-Auslesung des Multi-Layer-Codes (Forschungsteil)
`phase-3` `algorithm` `should`
- [ ] Rohen Kamerastrom über das `camera`-Paket abgreifen
- [ ] Farbwerte mit dem `image`-Paket auslesen
- [ ] Eigenen Dekodier-Algorithmus auf das Kamerabild anwenden
- [ ] Ehrlich dokumentieren: Farbkalibrierung unter realem Licht ist offen

### P3-6 · Empfangsansicht / Rekonstruktion
`phase-3` `ui` `should`
- [ ] Fortschritt des Empfangs anzeigen
- [ ] Wiederhergestellte Daten übersichtlich darstellen

### P3-7 · Ende-zu-Ende-Test Gerät zu Gerät
`phase-3` `test` `must`
- [ ] Vollständiger Transfer iPhone ↔ Samsung
- [ ] Daten kommen korrekt und vollständig an
- [ ] Fehlerfälle testen (Abbruch, unvollständig)

---

# Phase 4 — Evaluation & Optimierung
`phase-4`

Ziel: die App wird rund, sicher überprüft und mit echten Personen getestet. Hier
kommen die ergänzenden Funktionen dazu.

### P4-1 · Zyklus-Vorschau (einfache Berechnung)
`phase-4` `viewmodel` `should`
- [ ] Durchschnittliche Zykluslänge aus vorhandenen Daten berechnen
- [ ] Nächste Periode als Vorschau anzeigen (ehrlich als „Vorschau“ benannt)
- [ ] Fall behandeln: zu wenige Daten für eine Vorschau

### P4-2 · Symptom- und Verlaufs-Statistiken
`phase-4` `viewmodel` `should`
- [ ] Häufigkeiten anzeigen (wie oft wurde was angegeben)
- [ ] Übersicht über einen Zeitraum
- [ ] Notizen und Termine in der Übersicht berücksichtigen

### P4-3 · Kalender mit echten Daten
`phase-4` `ui` `should`
- [ ] Erfasste Tage und Perioden-Tage markieren
- [ ] Vorschau-Tage kennzeichnen

### P4-4 · Onboarding-Feinschliff
`phase-4` `ui` `should`
- [ ] Texte und Ablauf verbessern
- [ ] Barrierefreiheit prüfen

### P4-5 · Sicherheitsüberprüfung mit Wireshark
`phase-4` `security` `must`
- [ ] Netzwerkverkehr während des Transfers aufzeichnen
- [ ] Nachweisversuch, dass keine Daten an einen Server gehen
- [ ] Ergebnis dokumentieren (wichtig für die Arbeit)

### P4-6 · Nutzertests mit 3–5 Personen
`phase-4` `test` `should`
- [ ] Testpersonen die App bedienen lassen
- [ ] Rückmeldungen sammeln und ordnen
- [ ] Verbesserungen ableiten

### P4-7 · Fehlerbehebung und Optimierung
`phase-4` `must`
- [ ] Gemeldete Fehler beheben
- [ ] Leistung und Bedienung verbessern

### P4-8 · Dokumentation abschliessen
`phase-4` `docs` `must`
- [ ] Technische Dokumentation vervollständigen
- [ ] Fachliche Entscheidungen begründet festhalten
- [ ] Offene Punkte und Ausblick notieren

---

## Ehrliche Hinweise zur Nutzung dieses Plans

**Halte die Reihenfolge ein.** Beginne erst mit einer Phase, wenn die
vorherige steht. Die Verschlüsselung aus Phase 1 ist die Grundlage für alles
Weitere, besonders für den sicheren Multi-Layer-Code in Phase 2.

**Schätze grosszügig.** Einzelne Karten wirken klein, sind es aber oft nicht,
besonders bei Verschlüsselung und Algorithmus. Plane Puffer ein — das war ein
bewusster Lernpunkt aus der Reflexion.

**Priorisiere nach `must` vor `should`.** Wenn die Zeit knapp wird, sind die
`should`-Aufgaben (Vorschau, Statistiken, Feinschliff) die ersten, die warten
dürfen. Der Kern ist Speicherung, Verschlüsselung, Multi-Layer-Code und Transfer.

**Der Kamera-Scan ist der Forschungsteil.** Karte P3-5 ist die technisch
schwierigste und bewusst als offen markiert. Rechne hier mit mehr Zeit und
dokumentiere ehrlich, was funktioniert und was noch nicht.
