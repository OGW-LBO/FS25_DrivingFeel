# Fahr-Gefühl

Fahrphysik aller Fahrzeuge einstellbar: Reifen, Federung, Pedalverlauf.

Im Landwirtschafts-Simulator fährt jedes Fahrzeug wie auf Schienen. Diese Mod nimmt das ein Stück zurück.

Sie ersetzt keine Fahrzeugwerte, sondern rechnet Faktoren auf die Reifen- und Federungswerte, die jedes Fahrzeug selbst mitbringt. Ein 90-PS-Traktor fühlt sich also weiterhin anders an als ein Großschlepper. Und weil die Mod an den Rädern ansetzt und nicht an den Fahrzeugdateien, erreicht sie auch die Fahrzeuge des Basisspiels, an die man sonst nicht herankommt.

Regler gibt es für Seitenführung (die Reifen schieben in der Kurve und am Hang früher zur Seite), Antrieb (die Räder drehen unter Last früher durch), Reibung (der Grip auf jedem Untergrund), Bremskraft sowie Federhärte und Dämpfung. Zugfahrzeuge und Anhänger sind dabei getrennt, denn zu wenig Seitenführung am Hänger lässt ihn hinter dem Traktor pendeln - ab Werk stehen die Anhänger deshalb auf Serie.

Wer nicht jeden einzelnen Regler anfassen will, nimmt eine der vier Voreinstellungen: Serie, Sanft, Deutlich oder Realistisch. Serie heißt, jedes Fahrzeug fährt genau wie ohne die Mod. Realistisch ist dabei keine Geschmacksfrage, sondern gerechnet: die Fahrzeuge des Spiels federn im Mittel mit 3,15 Hz, eine gefederte Traktor-Vorderachse liegt in Wirklichkeit bei 2,0 bis 2,5 Hz.

Zu finden ist alles unter ESC - Allgemeine Einstellungen - Fahr-Gefühl. Ein Wert wirkt sofort, auch auf Fahrzeuge, die schon draußen stehen. Im Mehrspieler gehören die Werte dem Server und nur ein Admin stellt sie, zusätzlich kann aber jeder Spieler eigene Werte einschalten, die dann nur für die Fahrzeuge gelten, in denen er selbst sitzt.

Seit 1.2.0.0 zählt die Last mit: Federhärte und Dämpfung haben je einen Wert für leer und einen für voll beladen, dazwischen wird nach der Last gemischt, die jedes Rad gerade trägt. Eine Feder ist für ihre Nennlast gebaut und leer deshalb zu hart - genau das lässt sich damit nachstellen. Kabine, Sitz und Fahrerfigur werden ab Werk straffer gehalten, damit das Bild in der Innenansicht ruhiger steht, und Gas und Bremse lassen sich träger stellen, damit eine schwere Maschine sich auch so anfühlt.

Für den Mehrspieler kommt noch eine Sache dazu. Dort rechnet die Radphysik allein der Server, ein Client bekommt die Raddrehzahl nur gedeckelt und geglättet - durchdrehende Räder fallen deshalb kaum auf. Die Mod schickt den Schlupf vom Server nach, damit Staub, Dreck und Radbild wieder so aussehen wie im Einzelspieler. Der Schalter steht unter Mehrspieler und ist im Einzelspieler ausgeblendet.

Konsole: fgStatus, fgSet, fgReload

Skript-Mod, läuft daher nur auf PC und Mac.

## Installation

Die ZIP aus den [Releases](../../releases) herunterladen und in den
Mods-Ordner legen:

    Dokumente\My Games\FarmingSimulator2025\mods

Auf einem Dedicated Server gehoert sie in dessen Mods-Ordner.

## Stand

Version 1.3.0.0, gebaut gegen descVersion 115.

## Lizenz

Alle Rechte vorbehalten, Einzelheiten in LICENSE.txt. Der Quelltext liegt
offen, damit man sieht, was die Mod tut - eine Freigabe zur
Weiterverwendung ist das nicht.
