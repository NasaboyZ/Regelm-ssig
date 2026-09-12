# Entity: `Appointment`

## 9. Termine – `Appointment`

`Appointment` beschreibt einen Termin, der im Startermodell einem
`DayEntry` zugeordnet ist. Mehrere Termine können demselben Tageseintrag
zugeordnet werden.

### Felder

| Feld          | Modelltyp  | Inhalt und Regel                       |
| ------------- | ---------- | -------------------------------------- |
| `id`          | `String`   | Pflichtfeld; stabile ID des Termins    |
| `title`       | `String`   | Pflichtfeld; darf nicht leer sein      |
| `location`    | `String?`  | Optional; Ort des Termins              |
| `startsAtUtc` | `DateTime` | Pflichtfeld; Startzeitpunkt in UTC     |
| `note`        | `String?`  | Optional; zusätzliche Notiz zum Termin |

### Fachliche Regeln

- `id`, `title` und `startsAtUtc` sind Pflichtfelder.
- `title` muss mindestens ein Zeichen enthalten und darf nicht leer sein.
- `startsAtUtc` wird intern in UTC gespeichert.
- Termine werden in der Oberfläche in der lokalen Zeitzone angezeigt.
- Im Startermodell gehört jeder Termin zu einem `DayEntry`.

### Tageszuordnung

Die Tageszuordnung richtet sich nach dem lokalen Kalendertag, auf den der
Termin in der Oberfläche fällt. Wird `startsAtUtc` geändert und verschiebt
sich der Termin dadurch lokal über Mitternacht, muss die Zuordnung zum
`DayEntry` aktualisiert werden.

Das Repository kann Termine für spätere übergreifende Terminlisten unabhängig
von ihrer Tageszuordnung abfragen. Diese Möglichkeit ändert nichts an der
fachlichen Zuordnung im Startermodell.

### MVP-Grenze

`Appointment` enthält im MVP kein Alarm- oder Benachrichtigungsfeld.
Erinnerungen und Benachrichtigungen liegen ausdrücklich außerhalb des
aktuellen Projekts. Bei späterem Bedarf werden sie als eigenständige
Erweiterung geplant.
