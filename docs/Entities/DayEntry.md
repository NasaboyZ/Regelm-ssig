# Tagesdaten und Day-Entities

## 2. Tagesdaten – `DayEntry`

`DayEntry` ist der zentrale Einstiegspunkt für die Tagesdaten. Er repräsentiert
genau einen fachlichen Datensatz pro lokalem Kalendertag. Das Repository stellt
sicher, dass ein Kalendertag nicht doppelt angelegt wird.

### Felder

| Feld             | Typ                     | Inhalt und Regel                                                                         |
| ---------------- | ----------------------- | ---------------------------------------------------------------------------------------- |
| `id`             | `String`                | Pflichtfeld; stabile, eindeutige ID des Datensatzes                                      |
| `date`           | `LocalDate`             | Pflichtfeld; Jahr, Monat und Tag des lokalen Kalendertags                                |
| `createdAtUtc`   | `DateTime`              | Pflichtfeld; Zeitpunkt der Erstellung in UTC                                             |
| `updatedAtUtc`   | `DateTime`              | Pflichtfeld; Zeitpunkt der letzten Änderung in UTC; darf nicht vor `createdAtUtc` liegen |
| `bleeding`       | `BleedingEntry?`        | Optional; Blutungsdaten des Tages                                                        |
| `wellbeing`      | `WellbeingEntry?`       | Optional; Angaben zum Wohlbefinden                                                       |
| `sexualActivity` | `SexualActivityEntry?`  | Optional; Angaben zur sexuellen Aktivität                                                |
| `contraception`  | `ContraceptionEntry?`   | Optional; Angaben zur Verhütung                                                          |
| `tests`          | `List<HealthTestEntry>` | Liste mit null bis beliebig vielen Gesundheitstests                                      |
| `measurements`   | `MeasurementEntry?`     | Optional; Messwerte des Tages                                                            |
| `appointments`   | `List<Appointment>`     | Liste mit null bis beliebig vielen Terminen                                              |
| `note`           | `DayNote?`              | Optional; Notiz, die zu diesem Tag gehört                                                |

### Fachliche Regeln

#### Lokales Datum

`LocalDate` besteht aus den Ganzzahlen:

- `year`
- `month`
- `day`

Das Datum muss ein gültiges Kalenderdatum sein. Ungültige Kombinationen werden
abgelehnt, zum Beispiel der 29. Februar 2025.

Das Datum beschreibt den lokalen Kalendertag des Geräts. Es darf beim Wechsel
des Geräts oder durch eine Änderung der Zeitzone nicht auf einen anderen Tag
verrutschen. Für die fachliche Identität eines Tages ist daher ausschließlich
`date` maßgeblich, nicht ein aus UTC berechneter Zeitstempel.

#### Zeitstempel

`createdAtUtc` und `updatedAtUtc` werden immer in UTC gespeichert.

Es gilt:

```text
createdAtUtc <= updatedAtUtc
```

Beim Erstellen sind beide Zeitstempel konsistent zu setzen. Bei einer Änderung
des Datensatzes wird `updatedAtUtc` aktualisiert, während `createdAtUtc`
unverändert bleibt.

#### Eindeutigkeit

Für jeden lokalen Kalendertag darf höchstens ein `DayEntry` existieren. Die
Eindeutigkeit wird durch das Repository garantiert. Ein erneutes Speichern für
denselben Tag muss daher den vorhandenen Datensatz aktualisieren oder als
Konflikt behandelt werden, darf aber keinen zweiten Tagesdatensatz erzeugen.

### Beziehungen und Kardinalitäten

Ein `DayEntry` kann pro Kategorie höchstens ein Wertobjekt enthalten:

- höchstens ein `BleedingEntry`
- höchstens ein `WellbeingEntry`
- höchstens ein `SexualActivityEntry`
- höchstens ein `ContraceptionEntry`
- höchstens ein `MeasurementEntry`
- höchstens eine `DayNote`

Für Gesundheitstests und Termine gilt dagegen eine Mehrfachbeziehung:

- null bis beliebig viele `HealthTestEntry`
- null bis beliebig viele `Appointment`

Eine `DayNote` gehört immer zu genau dem `DayEntry`, dem sie zugeordnet ist.

### Persistenzhinweis

Die fachlichen Beziehungen und Kardinalitäten sind unabhängig von ihrer
technischen Speicherung. Referenzen in SQL, eingebettete Strukturen oder eine
andere Persistenzform dürfen später geändert werden, ohne das fachliche Modell
von `DayEntry` zu verändern. Entscheidend bleiben die Regeln für das lokale
Datum, die Eindeutigkeit pro Tag und die oben beschriebenen Kardinalitäten.
