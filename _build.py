"""Build FS25_DrivingFeel (Quellordner Codex/FahrGefuehl).

Zeichnet das Mod-Icon auf dem GIANTS-ModIcon-Template (512x512 DXT1 ohne
Mipmaps), prueft modDesc.xml und packt die ZIP. Die ZIP bleibt in diesem
Ordner und wird NICHT in den Mods-Ordner kopiert - das macht der Nutzer selbst.

Der ZIP-Name ist englisch (ModHub-Richtlinie 5.2: ein deutscher Dateiname ist
ein Fail). Quellordner und die deutschen Bezeichner im Lua bleiben davon
unberuehrt.
"""

import os
import struct
import xml.dom.minidom
import zipfile

from PIL import Image, ImageDraw, ImageFilter

os.chdir(os.path.dirname(os.path.abspath(__file__)))

MOD_NAME = "FS25_DrivingFeel"
ICON = "icon_DrivingFeel.dds"
# FS25-ModHub-Hintergrund (dunkel), NICHT das alte FS19-Template - GIANTS-Beanstandung 05.10.2026
TEMPLATE = r"C:\Users\Admin\Downloads\FS25_ModHub_BG512.png"

LUA = [
    "FahrGefuehl.lua",
    "FGSettings.lua",
    "FGSettingsEvent.lua",
    "FGPlayerEvent.lua",
    "FGSlip.lua",
    "FGSlipEvent.lua",
    "FGKabine.lua",
    "FGPedal.lua",
    "FGSettingsPage.lua",
    "FGUIHelper.lua",
    "FGMenuPage.lua",
    "FGMod.lua",
]
DATEIEN = ["modDesc.xml"] + LUA + ["gui/FGMenu.xml", ICON]

# --- Icon: Rad mit Feder ueber der Fahrbahn. Dunkler Grund -> helles Motiv.
SIZE = 512
F = 2  # in doppelter Aufloesung zeichnen, dann glatt verkleinern
HELL = (232, 236, 240, 255)
GELB = (250, 180, 40, 255)


def motiv():
    import math

    ebene = Image.new("RGBA", (SIZE * F, SIZE * F), (0, 0, 0, 0))
    d = ImageDraw.Draw(ebene)

    def p(*w):
        return [v * F for v in w]

    # Aufbau oben, darunter die Feder
    d.rectangle(p(132, 58, 380, 92), fill=HELL)

    federOben, federUnten = 92, 214
    windungen = 4
    hoehe = (federUnten - federOben) / float(windungen)
    links, rechts = 186, 326
    punkte = []
    for i in range(windungen + 1):
        y = federOben + i * hoehe
        punkte.append((links if i % 2 == 0 else rechts, y))
        punkte.append((rechts if i % 2 == 0 else links, y + hoehe * 0.5))
    for i in range(len(punkte) - 1):
        x1, y1 = punkte[i]
        x2, y2 = punkte[i + 1]
        if y2 <= federUnten:
            d.line(p(x1, y1, x2, y2), fill=GELB, width=20 * F)

    # Rad: Reifen, Nabe, vier Speichen
    mx, my, r = 256, 332, 108
    d.ellipse(p(mx - r, my - r, mx + r, my + r), outline=HELL, width=30 * F)
    for i in range(4):
        winkel = math.radians(45 + i * 90)
        d.line(p(mx, my,
                 mx + math.cos(winkel) * (r - 24),
                 my + math.sin(winkel) * (r - 24)), fill=HELL, width=16 * F)
    d.ellipse(p(mx - 34, my - 34, mx + 34, my + 34), fill=HELL)

    # Fahrbahn
    d.rectangle(p(64, 462, 448, 486), fill=HELL)

    return ebene


grund = Image.open(TEMPLATE).convert("RGBA").resize((SIZE * F, SIZE * F), Image.LANCZOS)
m = motiv()
schatten = Image.new("RGBA", m.size, (0, 0, 0, 0))
schatten.putalpha(m.split()[3].point(lambda a: int(a * 0.55)))
schatten = schatten.filter(ImageFilter.GaussianBlur(10 * F))
versatz = Image.new("RGBA", m.size, (0, 0, 0, 0))
versatz.paste(schatten, (6 * F, 8 * F))
bild = Image.alpha_composite(Image.alpha_composite(grund, versatz), m)
bild = bild.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
bild.save("_icon_vorschau.png")  # Kontrollbild und zugleich icon_512.png fuers Formular

tmp = ICON + ".tmp"
bild.save(tmp, format="DDS", pixel_format="DXT1")
with open(tmp, "rb") as f:
    daten = bytearray(f.read())
os.remove(tmp)

# DDS-Header auf TestRunner-Vorgabe (512x512 DXT1, keine Mipmaps)
daten = daten[: 128 + 131072]
struct.pack_into("<I", daten, 8, 0xA1007)
struct.pack_into("<I", daten, 28, 1)
struct.pack_into("<I", daten, 108, 0x1000)
struct.pack_into("<I", daten, 112, 0)

with open(ICON, "wb") as f:
    f.write(daten)

assert os.path.getsize(ICON) == 131200
print("Icon:", ICON, os.path.getsize(ICON), "Bytes")

# --- modDesc pruefen ---------------------------------------------------------
dom = xml.dom.minidom.parse("modDesc.xml")
assert dom.documentElement.getAttribute("descVersion") == "115"

quellen = [k.getAttribute("filename") for k in dom.getElementsByTagName("sourceFile")]
for q in quellen:
    assert os.path.exists(q), "fehlt: %s" % q
assert quellen == LUA, "Reihenfolge in modDesc und build.py laufen auseinander"

# Doppelte Schluessel faellt sonst niemandem auf: im Spiel gewinnt einer von
# beiden, und welcher, ist nicht zugesichert.
texte = {}
for t in dom.getElementsByTagName("text"):
    name = t.getAttribute("name")
    if name:
        assert name not in texte, "l10n-Schluessel doppelt vergeben: %s" % name
        texte[name] = t

# jeder l10n-Text braucht en, de und fr
for name, t in texte.items():
    sprachen = {k.tagName for k in t.childNodes if k.nodeType == k.ELEMENT_NODE}
    assert {"en", "de", "fr"} <= sprachen, "Sprache fehlt bei %s: %s" % (name, sprachen)

# Titel und Beschreibung ebenfalls dreisprachig
for tag in ("title", "description"):
    knoten = dom.getElementsByTagName(tag)[0]
    sprachen = {k.tagName for k in knoten.childNodes if k.nodeType == k.ELEMENT_NODE}
    assert {"en", "de", "fr"} <= sprachen, "Sprache fehlt bei %s: %s" % (tag, sprachen)

# jeder $l10n_-Verweis in der Hilfe muss existieren
for el in dom.getElementsByTagName("helpLines")[0].getElementsByTagName("*"):
    for attr in ("title", "text"):
        wert = el.getAttribute(attr)
        if wert.startswith("$l10n_"):
            assert wert[6:] in texte, "Hilfe-Text fehlt: %s" % wert

# jeder l10n-Schluessel, den der Lua-Code nennt, muss es geben
quelltext = "".join(open(d, encoding="utf-8").read() for d in LUA)
import re
for schluessel in sorted(set(re.findall(r'"(fg_[A-Za-z0-9_]+)"', quelltext))):
    assert schluessel in texte, "l10n fehlt fuer %s" % schluessel

# GUI-XML: jeder $l10n_-Verweis muss existieren
gui = open("gui/FGMenu.xml", encoding="utf-8").read()
for schluessel in sorted(set(re.findall(r"\$l10n_([A-Za-z0-9_]+)", gui))):
    assert schluessel in texte, "l10n fehlt fuer GUI-Schluessel %s" % schluessel

# PublicLuaCheck: diese Aufrufe lehnt der TestRunner ab. Sein Muster ist
# "\bname\s*\(", erwischt also auch "name (" mit Leerzeichen - und damit sogar
# eine Erwaehnung im Kommentar. Deshalb hier dieselbe Suche und nicht nur
# "name(" als Zeichenkette.
for datei in LUA:
    inhalt = open(datei, encoding="utf-8").read()
    for verboten in ("pcall", "xpcall", "loadstring", "collectgarbage"):
        treffer = re.findall(r"\b%s\s*\(" % verboten, inhalt)
        assert not treffer, "%s nutzt %dx %s()" % (datei, len(treffer), verboten)

print("modDesc.xml ok:", len(quellen), "Skripte,", len(texte), "Texte")

# --- ZIP ---------------------------------------------------------------------
zip_name = MOD_NAME + ".zip"
if os.path.exists(zip_name):
    os.remove(zip_name)

with zipfile.ZipFile(zip_name, "w", zipfile.ZIP_DEFLATED) as z:
    for fn in DATEIEN:
        z.write(fn, fn)

print("ZIP:", zip_name, os.path.getsize(zip_name), "Bytes")
with zipfile.ZipFile(zip_name) as z:
    for i in z.namelist():
        print("  ", i)
