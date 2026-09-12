# Entity: `BleedingEntry`

## 3. Blutung – `BleedingEntry`

`BleedingEntry` beschreibt die Blutungsdaten eines Tages. Das Wertobjekt ist
optional und wird über `DayEntry.bleeding` dem jeweiligen lokalen Kalendertag
zugeordnet.

### Felder

| Feld       | Modelltyp                 | Inhalt und Regel                                                   |
| ---------- | ------------------------- | ------------------------------------------------------------------ |
| `strength` | `FlowStrength?`           | Optional; wenn angegeben, genau eine Blutungsstärke                |
| `clots`    | `Menge<ClotSize>`         | Mehrfachauswahl; null bis mehrere Angaben zu Gerinnseln            |
| `products` | `Menge<MenstrualProduct>` | Mehrfachauswahl; null bis mehrere verwendete Menstruationsprodukte |

### Fachliche Regeln

- `strength` darf höchstens einen Wert enthalten.
- `clots` und `products` sind Mengen. Jeder zulässige Wert darf darin
  höchstens einmal vorkommen.
- Eine leere Menge bedeutet, dass für die jeweilige Kategorie keine Auswahl
  dokumentiert wurde.
- Die Werte müssen aus den jeweils definierten Aufzählungen stammen.

### Blutungsstärke: `FlowStrength`

| Wert          | Bedeutung        |
| ------------- | ---------------- |
| `Spotting`    | Schmierblutung   |
| `Light flow`  | Leichte Blutung  |
| `Medium flow` | Mittlere Blutung |
| `Heavy flow`  | Starke Blutung   |

### Gerinnsel: `ClotSize`

| Wert          | Bedeutung        |
| ------------- | ---------------- |
| `Small clots` | Kleine Gerinnsel |
| `Big clots`   | Große Gerinnsel  |

### Menstruationsprodukte: `MenstrualProduct`

| Wert               | Bedeutung               |
| ------------------ | ----------------------- |
| `Reusable pad`     | Wiederverwendbare Binde |
| `Disposable pad`   | Einweg-Binde            |
| `Tampon`           | Tampon                  |
| `Menstrual cup`    | Menstruationstasse      |
| `Menstrual disc`   | Menstruationsscheibe    |
| `Menstrual sponge` | Menstruationsschwamm    |
| `Period underwear` | Periodenunterwäsche     |
| `Liner`            | Slipeinlage             |
