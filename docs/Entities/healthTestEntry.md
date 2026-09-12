# Entity: `HealthTestEntry`

## 7. Tests – `HealthTestEntry`

`HealthTestEntry` beschreibt das Ergebnis eines einzelnen Gesundheits- oder
Schwangerschaftstests. Mehrere Tests können demselben `DayEntry` zugeordnet
werden.

### Felder

| Feld              | Modelltyp          | Inhalt und Regel                                   |
| ----------------- | ------------------ | -------------------------------------------------- |
| `id`              | `String`           | Pflichtfeld; stabile ID des Tests                  |
| `type`            | `HealthTestType`   | Pflichtfeld; STI-Test oder Schwangerschaftstest    |
| `result`          | `HealthTestResult` | Pflichtfeld; positives oder negatives Testergebnis |
| `testedInfection` | `String?`          | Optional; getestete Infektion bei einem STI-Test   |
| `note`            | `String?`          | Optional; zusätzliche Notiz zum Test               |

### Fachliche Regeln

- `id`, `type` und `result` sind Pflichtfelder.
- `testedInfection` kann bei einem STI-Test die konkret getestete Infektion
  benennen. Die Angabe ist optional.
- Ein STI-Test beschreibt nur das Ergebnis für die konkret getestete
  Infektion. Er ist kein pauschaler Status für alle sexuell übertragbaren
  Infektionen.
- Mehrere `HealthTestEntry`-Objekte können am selben lokalen Kalendertag
  erfasst werden.
- Die Werte für `type` und `result` müssen aus den jeweils definierten
  Aufzählungen stammen.

### Testtyp: `HealthTestType`

| Wert        | Bedeutung                               |
| ----------- | --------------------------------------- |
| `STI`       | Test auf sexuell übertragbare Infektion |
| `Pregnancy` | Schwangerschaftstest                    |

### Testergebnis: `HealthTestResult`

| Wert       | Bedeutung |
| ---------- | --------- |
| `Positive` | Positiv   |
| `Negative` | Negativ   |

### Getestete Infektion

`testedInfection` ist ein optionaler Freitext für STI-Tests. Damit kann die
konkret getestete Infektion dokumentiert werden, ohne die Entity auf eine
starre Liste von Infektionen zu beschränken.

Bei einem STI-Test ohne Angabe von `testedInfection` darf aus dem Ergebnis
keine Aussage über nicht benannte Infektionen abgeleitet werden.
