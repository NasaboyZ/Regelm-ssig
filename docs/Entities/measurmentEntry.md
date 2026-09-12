# Entity: `MeasurementEntry`

## 8. Messwerte – `MeasurementEntry`

`MeasurementEntry` enthält optionale Messwerte eines Tages. Temperaturen und
Gewichte werden unabhängig voneinander erfasst.

### Felder

| Feld                       | Modelltyp            | Inhalt und Regel                                           |
| -------------------------- | -------------------- | ---------------------------------------------------------- |
| `temperatureCelsius`       | `double?`            | Optional; endlicher Wert oberhalb des absoluten Nullpunkts |
| `temperatureMethod`        | `TemperatureMethod?` | Nur zusammen mit `temperatureCelsius` zulässig             |
| `temperatureMeasuredAtUtc` | `DateTime?`          | Optional; nur zusammen mit `temperatureCelsius` zulässig   |
| `weightKilograms`          | `double?`            | Optional; endlicher und positiver Wert                     |

### Fachliche Regeln

- `temperatureCelsius` darf nur endlich sein und muss oberhalb des absoluten
  Nullpunkts liegen. In Celsius gilt daher:

  ```text
  temperatureCelsius > -273.15
  ```

- `temperatureMethod` darf nur gesetzt werden, wenn auch
  `temperatureCelsius` vorhanden ist.
- `temperatureMeasuredAtUtc` darf nur gesetzt werden, wenn auch
  `temperatureCelsius` vorhanden ist.
- `weightKilograms` darf nur endlich und größer als `0` sein.
- Alle internen Temperaturwerte werden in Grad Celsius und alle internen
  Gewichtsangaben in Kilogramm gespeichert.
- Andere Anzeigeeinheiten werden ausschließlich in der Oberfläche umgerechnet.

### Messmethoden: `TemperatureMethod`

| Wert       | Bedeutung      |
| ---------- | -------------- |
| `oral`     | Oral           |
| `vaginal`  | Vaginal        |
| `rectal`   | Rektal         |
| `ear`      | Ohr            |
| `forehead` | Stirn          |
| `other`    | Andere Methode |

### Validierung und medizinische Einordnung

Die Prüfung auf endliche Werte, den absoluten Nullpunkt und ein positives
Gewicht ist eine physikalische Grenzprüfung. Sie ist keine medizinische
Bewertung und erlaubt keine Diagnose.

Fachliche Plausibilitätswarnungen für ungewöhnliche Werte werden später
gesondert definiert. Ungewöhnliche, aber zulässige Werte dürfen dabei nicht
stillschweigend verändert oder durch andere Werte ersetzt werden.
