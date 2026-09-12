# Entity: `WellbeingEntry`

## 4. Stimmung & Symptome – `WellbeingEntry`

`WellbeingEntry` beschreibt die von der Nutzerin eingetragenen Stimmungen und
körperlichen Symptome eines Tages. Das Wertobjekt ist optional und wird über
`DayEntry.wellbeing` dem jeweiligen lokalen Kalendertag zugeordnet.

### Felder

| Feld       | Modelltyp                | Inhalt und Regel                            |
| ---------- | ------------------------ | ------------------------------------------- |
| `moods`    | `Menge<Mood>`            | Mehrere Stimmungen können ausgewählt werden |
| `symptoms` | `Menge<PhysicalSymptom>` | Mehrere Symptome können ausgewählt werden   |

### Fachliche Regeln

- `moods` und `symptoms` sind Mengen. Jeder zulässige Wert darf darin
  höchstens einmal vorkommen.
- Eine leere Menge bedeutet, dass für die jeweilige Kategorie keine Angabe
  dokumentiert wurde.
- Die Werte müssen aus den jeweils definierten Aufzählungen stammen.
- Die Angaben sind Beobachtungen der Nutzerin und stellen keine medizinische
  Diagnose dar.

### Stimmungen: `Mood`

| Wert          | Bedeutung      |
| ------------- | -------------- |
| `Calm`        | Ruhig          |
| `Stressed`    | Gestresst      |
| `Unmotivated` | Unmotiviert    |
| `Sad`         | Traurig        |
| `Happy`       | Glücklich      |
| `Irritable`   | Gereizt        |
| `Angry`       | Wütend         |
| `Energetic`   | Energiegeladen |
| `Horny`       | Sexuell erregt |

### Symptome: `PhysicalSymptom`

| Wert           | Bedeutung             |
| -------------- | --------------------- |
| `Acne`         | Akne                  |
| `Bloating`     | Blähungen             |
| `Cramps`       | Krämpfe               |
| `Cravings`     | Heißhunger            |
| `Discharge`    | Ausfluss              |
| `Fatigue`      | Müdigkeit             |
| `Fever`        | Fieber                |
| `Headache`     | Kopfschmerzen         |
| `Itchiness`    | Juckreiz              |
| `Nausea`       | Übelkeit              |
| `Severe pain`  | Starke Schmerzen      |
| `Stomachache`  | Bauchschmerzen        |
| `Tender chest` | Empfindliche Brust    |
| `Ovulation`    | Beobachteter Eisprung |

### Abgrenzung von `Ovulation`

`Ovulation` bezeichnet ausschließlich eine von der Nutzerin eingetragene
Beobachtung. Der Wert wird nicht automatisch ermittelt und stellt keine
medizinische Bestätigung oder Diagnose eines Eisprungs dar.
