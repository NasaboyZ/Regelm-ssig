# Entity: `SexualActivityEntry`

## 5. Sexuelle Aktivität – `SexualActivityEntry`

`SexualActivityEntry` beschreibt die von der Nutzerin eingetragenen sexuellen
Aktivitäten und die zugehörigen Schutzangaben eines Tages. Das Wertobjekt ist
optional und wird über `DayEntry.sexualActivity` dem jeweiligen lokalen
Kalendertag zugeordnet.

### Felder

| Feld                  | Modelltyp               | Inhalt und Regel                                       |
| --------------------- | ----------------------- | ------------------------------------------------------ |
| `stiProtection`       | `ProtectionStatus?`     | Optional; Schutz vor sexuell übertragbaren Infektionen |
| `pregnancyProtection` | `ProtectionStatus?`     | Optional; Schutz vor einer Schwangerschaft             |
| `activities`          | `Menge<SexualActivity>` | Mehrfachauswahl der eingetragenen Aktivitäten          |

### Fachliche Regeln

- `stiProtection` und `pregnancyProtection` werden getrennt erfasst. Der
  Status für den STI-Schutz ist unabhängig vom Status für den
  Schwangerschaftsschutz.
- Beide Schutzstatus dürfen jeweils höchstens einen Wert enthalten.
- `activities` ist eine Menge. Jede zulässige Aktivität darf darin höchstens
  einmal vorkommen.
- Eine leere Menge bedeutet, dass keine Aktivität dokumentiert wurde.
- Die Angaben sind Selbstauskünfte und stellen keine medizinische
  Sicherheitsgarantie dar.

### Schutzstatus: `ProtectionStatus`

| Wert          | Bedeutung   |
| ------------- | ----------- |
| `Protected`   | Geschützt   |
| `Unprotected` | Ungeschützt |

### Aktivitäten: `SexualActivity`

| Wert           | Bedeutung    |
| -------------- | ------------ |
| `Masturbation` | Masturbation |
| `Oral sex`     | Oralsex      |
| `Orgasm`       | Orgasmus     |
| `Sex toys`     | Sexspielzeug |
| `Anal sex`     | Analsex      |

### Schutzangaben

Der Schutz vor sexuell übertragbaren Infektionen und der Schutz vor einer
Schwangerschaft werden als zwei separate Informationen gespeichert. Ein
`Protected`-Status in einer Kategorie macht keine Aussage über die jeweils
andere Kategorie.
