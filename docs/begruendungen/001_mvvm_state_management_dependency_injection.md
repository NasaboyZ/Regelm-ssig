# Architekturentscheidung: MVVM, State Management und Dependency Injection

**Datum:** 12. September 2026  
**Status:** Beschlossen; Umsetzung noch ausstehend.

## Kontext

Die Anwendung soll einer schichtenbasierten Architektur nach dem MVVM-Prinzip
folgen. View und ViewModel bilden die Oberfläche ab; Models, Repositories und
Services übernehmen fachliche Daten, Datenzugriff und technische Aufgaben.
Damit ViewModels und Repositories unabhängig von konkreten Implementierungen
wie der Datenbank oder der Verschlüsselung bleiben und isoliert testbar sind,
wird eine Lösung für die Dependency Injection benötigt. Zusätzlich muss der
Zustand der Oberfläche verwaltet und bei Änderungen an die Views gemeldet werden.

## Entscheidung

MVVM trennt die Darstellung in den Views vom Oberflächenzustand und den Aktionen
in den ViewModels. Models bilden die fachlichen Daten und Regeln ab.
Repositories stellen den Zugriff auf diese Daten bereit, während Services
technische Aufgaben wie lokale Speicherung, Verschlüsselung und Übertragung
übernehmen.

Für die Dependency Injection wird `get_it` eingesetzt. Services, Repositories
und die Zusammenstellung ihrer Abhängigkeiten werden zentral registriert.
ViewModels und Repositories erhalten ihre benötigten Abhängigkeiten über ihre
Konstruktoren, statt sie selbst zu erzeugen oder intern aus `get_it` abzurufen.
Wo konkrete Implementierungen austauschbar sein sollen, erfolgt der Zugriff
über entsprechende Schnittstellen.

Für das State Management werden die Flutter-Bordmittel mit `ChangeNotifier`
und expliziten Zuständen als Sealed Classes verwendet. Die Zustände der
ViewModels werden typsicher als `Initial`, `Loading`, `Success` und `Error`
abgebildet. Bei Zustandsänderungen benachrichtigt das ViewModel seine Views.

## Begründung

MVVM trennt Darstellung, Oberflächenzustand und Datenzugriff. Dadurch können
Oberfläche, lokale Speicherung und Verschlüsselung unabhängig weiterentwickelt
werden. Die Logik der ViewModels lässt sich ohne die Darstellung eines
vollständigen Bildschirms isoliert testen.

Die Trennung von Dependency Injection und State Management hält die Aufgaben
überschaubar. Konstruktorübergabe und Schnittstellen halten ViewModels frei von
Wissen über konkrete technische Implementierungen der darunterliegenden
Schichten. `get_it` bündelt deren Zusammenstellung an einer zentralen Stelle.
In Tests können Test doubles direkt an die Konstruktoren übergeben werden;
eine globale Registrierung ist dafür nicht erforderlich.

Die expliziten Zustände reduzieren widersprüchliche Kombinationen einzelner
Statusvariablen. Die Views sollen alle vier Zustände bewusst behandeln,
insbesondere den Fehlerfall. Eine vollständige Fallunterscheidung über die
Sealed Classes unterstützt diese Prüfung durch den Compiler.

## Alternativen

Als Alternativen für das State Management wurden die Pakete `provider` und
`riverpod` erwogen. Sie bieten zusätzliche Unterstützung für die Bereitstellung
und Beobachtung von Zuständen, bringen jedoch weitere Abhängigkeiten und
Konzepte mit. Für den Umfang dieses Projekts wurde die Lösung mit
`ChangeNotifier` und expliziten Zuständen bevorzugt.

## Konsequenz

Die Architektur bleibt schlank und unterstützt isolierte Tests. Die
Registrierung der Abhängigkeiten erfolgt zentral, und die ViewModels geben
ihren Zustand einheitlich über typsichere Zustände nach aussen.

Die Zustandsübergänge und die Lebensdauer der ViewModels müssen bewusst
verwaltet werden. Dazu gehören die Benachrichtigung der Views bei Änderungen
und die Freigabe nicht mehr benötigter `ChangeNotifier`-Instanzen.

`get_it` ist bereits als Abhängigkeit in `pubspec.yaml` eingetragen. Die zentrale
Registrierung, Konstruktorübergabe und die beschriebenen ViewModel-Zustände
sind damit noch nicht implementiert. Dieses Dokument hält die beschlossene
Zielarchitektur fest; es ist kein Nachweis ihrer vollständigen Umsetzung.
