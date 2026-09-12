# Umsetzung und Test-Checkliste

Diese Checkliste dokumentiert den aktuellen Starterentwurf für die Umsetzung
der fachlichen Entities und des Transfers.

## 1. Projektstruktur

- [ ] Ordner `domain/common` anlegen
- [ ] Ordner `domain/entry` anlegen
- [ ] Ordner `domain/bleeding` anlegen
- [ ] Ordner `domain/wellbeing` anlegen
- [ ] Ordner `domain/sexual_health` anlegen
- [ ] Ordner `domain/contraception` anlegen
- [ ] Ordner `domain/tests` anlegen
- [ ] Ordner `domain/measurements` anlegen
- [ ] Ordner `domain/appointments` anlegen
- [ ] Ordner `domain/notes` anlegen
- [ ] Ordner `domain/transfer` anlegen
- [ ] Zentrale `entities.dart` erstellen, die alle Domain-Modelle exportiert

## 2. Modellierungsregeln

### Unveränderlichkeit

- [ ] Alle Domain-Modelle immutable halten
- [ ] Listen bei Erstellung und Ausgabe defensiv kopieren
- [ ] Mengen bei Erstellung und Ausgabe defensiv kopieren
- [ ] Byte-Puffer bei Erstellung und Ausgabe defensiv kopieren
- [ ] Bearbeitung eines Modells erzeugt eine neue Instanz
- [ ] IDs aus dem Repository beziehen, nicht aus dem UI erzeugen

### Trennung von Domain und Persistenz

- [ ] Domain-Entities nicht direkt an SQL-Tabellen koppeln
- [ ] Domain-Entities nicht direkt mit Transfer-Bytes vermischen
- [ ] Separate Datenbank-DTOs definieren
- [ ] Separate Transfer-DTOs definieren
- [ ] Explizite Mapper zwischen Domain, Datenbank und Transfer schreiben
- [ ] Mapper so strukturieren, dass Migrationen isoliert testbar bleiben

## 3. Fachliche Validierungs- und Mapping-Tests

| Bereich                | Testfall                              | Erwartung                                                      |
| ---------------------- | ------------------------------------- | -------------------------------------------------------------- |
| Datum und Metadaten    | Ungültiger Tag                        | Ungültige Kalenderdaten werden abgelehnt                       |
| Datum und Metadaten    | Schaltjahr                            | Gültige und ungültige Schalttage werden korrekt unterschieden  |
| Datum und Metadaten    | UTC-Tag beim Transfer                 | Der lokale Kalendertag bleibt beim Transfer erhalten           |
| Freiwillige Kategorien | `null`-Wert                           | Nicht erfasste optionale Kategorie bleibt unterscheidbar       |
| Freiwillige Kategorien | Leere Menge                           | Leere Auswahl bleibt von `null` unterscheidbar                 |
| Freiwillige Kategorien | Mehrfachauswahl                       | Mehrere unterschiedliche Werte werden vollständig erhalten     |
| Unveränderlichkeit     | Eingabe-Liste nach Erstellung ändern  | Die Entity verändert sich nicht                                |
| Unveränderlichkeit     | Eingabe-Menge nach Erstellung ändern  | Die Entity verändert sich nicht                                |
| Unveränderlichkeit     | Eingabe-Puffer nach Erstellung ändern | Die Entity verändert sich nicht                                |
| Unveränderlichkeit     | Ausgegebene Sammlung ändern           | Interner Entity-Zustand bleibt geschützt                       |
| Verhütung              | Ungültige Methode/Aktion              | Fachliche Validierung lehnt die Kombination sauber ab          |
| Messwerte              | `NaN`                                 | Wert wird abgelehnt                                            |
| Messwerte              | Unendlicher Wert                      | Wert wird abgelehnt                                            |
| Messwerte              | Negatives Gewicht                     | Wert wird abgelehnt                                            |
| DTO-Mapping            | Domain speichern und lesen            | Fachliche Daten bleiben identisch                              |
| DTO-Mapping            | Encode und Decode                     | Fachliche Daten bleiben identisch                              |
| Import                 | Doppelte Daten                        | Duplikat wird entsprechend der definierten Strategie behandelt |
| Import                 | Konflikt                              | Konflikt wird entsprechend der definierten Regel behandelt     |
| Import                 | Abbruch während des Imports           | Kein Teilimport bleibt dauerhaft gespeichert                   |

## 4. Mapper- und Transfer-Tests

- [ ] Domain-Entity zu Datenbank-DTO und zurück testen
- [ ] Domain-Entity zu Transfer-DTO und zurück testen
- [ ] Optionale Felder, leere Mengen und Mehrfachauswahlen testen
- [ ] Stabile IDs bei Speicherung und Wiederherstellung testen
- [ ] Versionierte Transfer-Metadaten beim Encode und Decode testen
- [ ] Gemischte `transferId`-Werte ablehnen
- [ ] Fehlende Chunks ablehnen
- [ ] Doppelte Chunk-Indizes ablehnen
- [ ] Inkonsistente `total`-Werte ablehnen
- [ ] Beschädigte oder nicht entschlüsselbare Payloads ablehnen
- [ ] Transaktionalen Import als vollständig oder gar nicht testen

## 5. Nächster vertikaler Schritt

Der nächste umsetzbare End-to-End-Schritt ist:

1. Stimmung auswählen
2. Einen `DayEntry` erstellen
3. Den `DayEntry` über das Repository verschlüsselt speichern
4. Die Anwendung neu starten
5. Den gespeicherten `DayEntry` wieder laden

Dafür sind folgende Tests zu schreiben:

- [ ] Entity-Test für die Erstellung eines `DayEntry` mit Stimmung
- [ ] ViewModel-Test für Auswahl und Speicherung der Stimmung
- [ ] Widget-Test für die Stimmungsauswahl in der Oberfläche
- [ ] Repository-Test für verschlüsseltes Speichern
- [ ] Repository-Test für Laden nach einem Neustart
- [ ] End-to-End-Test für den vollständigen Ablauf

## 6. Abgrenzung

Diese Übersicht dokumentiert den aktuellen Starterentwurf. Sie ist keine
abgeschlossene Sicherheits- oder Transfer-Protokollspezifikation. Offene
Entscheidungen zu Verschlüsselung, KDF, Nonce, Payload-Limits,
Versionskompatibilität und Importkonflikten müssen vor einer produktiven
Implementierung noch verbindlich festgelegt werden.
