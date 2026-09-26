# Regelmässig

Eine mobile App, die besonders schützenswerte Gesundheitsdaten sicher von einem
Smartphone auf ein anderes überträgt — direkt von Gerät zu Gerät über einen
farbigen Multi-Layer-QR-Code, ohne Server, ohne Cloud, ohne Konto.

> Status: in Entwicklung. Diese App entsteht im Rahmen einer Bachelorarbeit und
> ist noch nicht fertiggestellt.

## Was die App ist

Eine datenschutzfreundliche App zum Erfassen und Übertragen sensibler
Gesundheitsdaten. Die Daten bleiben lokal auf dem Gerät und verlassen es nur
verschlüsselt. Für den Wechsel auf ein neues Gerät werden sie optisch übertragen,
also von Bildschirm zu Kamera, über einen farbigen Code, der mehrere Datenebenen
in einem einzigen Bild bündelt.

## Warum sie wichtig ist

Gesundheitsdaten gehören zu den sensibelsten Daten überhaupt. Wer sie erfasst,
sollte selbst die Kontrolle darüber behalten und nicht darauf angewiesen sein,
sie einem fremden Server oder einer Cloud anzuvertrauen. Diese App stellt die
Datenhoheit der Nutzenden in den Mittelpunkt.

## Welches Problem sie löst

Bei sensiblen Gesundheitsdaten steht man vor einem Zielkonflikt. Werden die Daten
zentral auf einem Server gespeichert, ist der Wechsel des Geräts einfach, doch
die gebündelten Daten sind ein attraktives Angriffsziel. Werden sie nur lokal
gespeichert, behält man die volle Kontrolle, doch der Umzug auf ein neues Gerät
wird umständlich.

Diese App verbindet beide Vorteile. Die Daten bleiben jederzeit lokal und
verschlüsselt, und trotzdem lassen sie sich einfach auf ein neues Gerät
übertragen, ohne dass sie je einen Server oder eine Cloud berühren.

## Entwicklung: verschlüsselte Tageserfassung

Der separate SQLCipher-Debug-Start speichert Testeinträge in einer verschlüsselten
SQLite-Datenbank. Die reguläre App verwendet vorerst weiterhin Secure Storage.
Startbefehle, Datenbankkontrolle und Tests stehen in der
[Anleitung zur SQLCipher-Speicherung](docs/entwicklung/sqlcipher_speicherung.md).

## Open Source

Der Quellcode dieses Projekts ist offen und einsehbar. Er darf im Rahmen der
angegebenen Lizenz genutzt und weiterentwickelt werden.

Lizenz: MIT
