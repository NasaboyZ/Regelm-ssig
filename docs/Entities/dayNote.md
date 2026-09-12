# Entity: `DayNote`

## 10. Notizen – `DayNote`

`DayNote` enthält einen freien Text zum jeweiligen lokalen Kalendertag. Die
Notiz ist ein optionales Wertobjekt innerhalb von `DayEntry`.

### Feld

| Feld   | Modelltyp | Inhalt und Regel                  |
| ------ | --------- | -------------------------------- |
| `text` | `String`  | Freier Tagestext                  |

### Fachliche Regeln

- `DayNote` besitzt keine eigene ID.
- Die Notiz ist Teil des zugehörigen `DayEntry` und wird über diesen
	identifiziert.
- Der Inhalt von `text` ist ein freier Tagestext.
- Eine leere Notiz kann im Repository als „nicht erfasst“ normalisiert werden.
	Dadurch kann ein leerer Text genauso behandelt werden wie das Fehlen des
	optionalen `DayNote`-Objekts.
