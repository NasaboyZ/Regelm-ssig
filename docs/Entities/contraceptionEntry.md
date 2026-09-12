# Entity: `ContraceptionEntry`

## 6. Verhütung – `ContraceptionEntry`

`ContraceptionEntry` beschreibt die von der Nutzerin eingetragenen Angaben zur
Verhütung eines Tages. Das Wertobjekt ist optional und wird über
`DayEntry.contraception` dem jeweiligen lokalen Kalendertag zugeordnet.

### Felder

| Feld             | Modelltyp                   | Inhalt und Regel                             |
| ---------------- | --------------------------- | -------------------------------------------- |
| `pill`           | `PillIntake?`               | Optional; Einnahmestatus der Pille           |
| `dailyMethods`   | `Menge<DailyContraception>` | Mehrfachauswahl täglicher Verhütungsmethoden |
| `longTermEvents` | `Liste<LongTermEvent>`      | Liste; mehrere Ereignisse sind möglich       |

### Fachliche Regeln

- `dailyMethods` ist eine Menge. Jede zulässige Methode darf darin höchstens
  einmal vorkommen.
- `longTermEvents` ist eine Liste, da mehrere Ereignisse dokumentiert werden
  können. Die Reihenfolge ist jedoch nicht die fachliche Bedeutung eines
  Ereignisses.
- Jede Kombination aus `LongTermEvent.method` und
  `LongTermEvent.action` muss in der Liste der zulässigen Kombinationen
  enthalten sein. Ungültige Kombinationen werden fachlich abgelehnt.

### Pilleneinnahme: `PillIntake`

| Wert     | Bedeutung         |
| -------- | ----------------- |
| `Took`   | Eingenommen       |
| `Missed` | Vergessen         |
| `Double` | Doppelte Einnahme |

### Tägliche Verhütungsmethoden: `DailyContraception`

| Wert                      | Bedeutung          |
| ------------------------- | ------------------ |
| `Condom`                  | Kondom             |
| `Diaphragm`               | Diaphragma         |
| `Cervical cap`            | Portiokappe        |
| `Sponge`                  | Verhütungsschwamm  |
| `Spermicide`              | Spermizid          |
| `Pull out`                | Coitus interruptus |
| `Emergency contraception` | Notfallverhütung   |

### Langzeitereignisse: `LongTermEvent`

Ein `LongTermEvent` enthält die beiden Felder `method` und `action`.
Zulässig sind ausschließlich die folgenden Kombinationen:

| `method`  | Zulässige `action`-Werte    |
| --------- | --------------------------- |
| `IUD`     | `New`, `Checked`, `Removed` |
| `Implant` | `New`, `Removed`            |
| `Patch`   | `New`, `Removed`            |
| `Ring`    | `New`, `Removed`            |
| `Shot`    | `Shot`                      |

Beispiele für fachlich ungültige Kombinationen sind `IUD - Shot`,
`Implant - Checked` oder `Ring - Shot`. Solche Ereignisse dürfen nicht
gespeichert werden.

### Persistenz und Mapping

Benutzeroberflächen dürfen verständliche Anzeigenamen wie `New` verwenden.
Der Mapper übersetzt diese UI-Begriffe jedoch in stabile interne
Ereigniscodes, bevor ein Ereignis gespeichert oder weiterverarbeitet wird.

Die Persistenz darf niemals von der Position eines Enum-Werts abhängen. Ein
Enum darf daher nicht über seinen numerischen Index gespeichert werden, da
eine spätere Änderung der Enum-Reihenfolge bestehende Daten verfälschen
könnte. Stattdessen werden stabile, explizit definierte Ereigniscodes
verwendet.
