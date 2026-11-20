--
-- FahrGefuehl - Kern
--
-- Rechnet Faktoren auf die Reifen- und Federungswerte, die ein Fahrzeug selbst
-- mitbringt, statt sie zu ersetzen. Damit bleiben die Unterschiede zwischen den
-- Fahrzeugen erhalten, und es wirkt auch auf die Fahrzeuge des Basisspiels, an
-- deren XML man nicht herankommt.
--
-- OGW
--

FahrGefuehl = {}

FahrGefuehl.LOG = "[FahrGefuehl] "

-- Takt der Fahrerabfrage in ms. Kein Hook auf Enterable.onPlayerEnterVehicle:
-- die Spezialisierungen stecken schon in den Fahrzeugtypen, bevor die Mod
-- geladen wird ("Loaded vehicle types" steht im Log vor "Load mod").
FahrGefuehl.PRUEF_MS = 500

FahrGefuehl.MIN_FAKTOR = 0.25
FahrGefuehl.MAX_FAKTOR = 2.50

-- Ab dieser Radlast gilt ein Fahrzeug als voll beladen: das Doppelte der
-- Nennlast, fuer die der Reifen in der XML ausgelegt ist (physics#restLoad).
-- Dazwischen wird zwischen dem Leer- und dem Vollwert gemischt.
FahrGefuehl.LAST_VOLL = 2.00

-- Die Radlast schwankt im Fahren stark. Erst dieser Anteil des neuen Werts
-- geht je Pruefung ein, sonst pumpt die Federung bei jeder Bodenwelle.
FahrGefuehl.LAST_TRAEGHEIT = 0.3

-- Unterhalb dieser Aenderung wird die Federung nicht neu gesetzt. Jedes Setzen
-- baut die Radform neu auf (setSuspensionMultipliers -> isPositionDirty).
FahrGefuehl.LAST_SCHWELLE = 0.05

-- Server-Vorgabe. 1.00 = unveraendert, Zugfahrzeug = alles mit Motor.
-- voreinstellung 0 = Eigene, sonst Index in VOREINSTELLUNGEN.
FahrGefuehl.CFG = {
    aktiv          = true,
    voreinstellung = 2,

    zugSeite   = 0.75,
    zugAntrieb = 0.85,
    zugReibung = 1.00,
    zugBremse  = 1.00,

    anhSeite   = 1.00,
    anhAntrieb = 1.00,
    anhReibung = 1.00,
    anhBremse  = 1.00,

    feder          = 0.70,
    federVoll      = 0.95,
    daempfung      = 1.00,
    daempfungVoll  = 1.15,

    -- Die Vorgaben beruhigen, sie machen nicht mehr Bewegung: steht die
    -- Kamerafederung des Spiels an, haengt die Innenkamera an der
    -- Kabinenfederung, und im Mehrspieler regen die Knicke der
    -- Positions-Interpolation sie an statt der Fahrbahn.
    kabineAktiv     = true,
    kabineFeder     = 1.10,
    kabineDaempfung = 1.20,
    kabineWeg       = 0.85,

    pedal      = 0.85,

    -- Aus ab Werk: der Test mit mehreren Spielern fehlt noch.
    mpSchlupf  = false,

    debug      = false,
}

-- Werte dieses Spielers. aktiv = "meine Werte verwenden".
FahrGefuehl.EIGEN = {
    aktiv          = false,
    voreinstellung = 2,

    zugSeite   = 0.75,
    zugAntrieb = 0.85,
    zugReibung = 1.00,
    zugBremse  = 1.00,

    anhSeite   = 1.00,
    anhAntrieb = 1.00,
    anhReibung = 1.00,
    anhBremse  = 1.00,

    feder          = 0.70,
    federVoll      = 0.95,
    daempfung      = 1.00,
    daempfungVoll  = 1.15,

    kabineFeder     = 1.10,
    kabineDaempfung = 1.20,
    kabineWeg       = 0.85,

    pedal      = 0.85,
}

-- userId -> Wertesatz. Fuellt nur der Server.
FahrGefuehl.spielerWerte = {}

-- Nur Zahlenwerte. Ein Schalter gehoert hier nicht hinein: FGPlayerEvent
-- schreibt die Liste als Float-Folge in den Stream.
FahrGefuehl.FAKTOREN = {
    "zugSeite", "zugAntrieb", "zugReibung", "zugBremse",
    "anhSeite", "anhAntrieb", "anhReibung", "anhBremse",
    "feder", "federVoll", "daempfung", "daempfungVoll",
    "kabineFeder", "kabineDaempfung", "kabineWeg",
    "pedal",
}

-- Diese Werte werden je Rad gesichert und immer aus dem Original gerechnet.
-- Ohne die Sicherung setzt jede Verstellung auf dem letzten Ergebnis auf.
FahrGefuehl.FELDER = {
    "maxLatStiffness",
    "maxLongStiffness",
    "frictionScale",
    "brakeFactor",
    "autoHoldBrakeFactor",
}

-- Reihenfolge wie die Auswahltexte in FGSettingsPage.SERVER.
FahrGefuehl.VOREINSTELLUNGEN = {
    {   -- Serie
        zugSeite = 1.00, zugAntrieb = 1.00, zugReibung = 1.00, zugBremse = 1.00,
        anhSeite = 1.00, anhAntrieb = 1.00, anhReibung = 1.00, anhBremse = 1.00,
        feder    = 1.00, federVoll = 1.00, daempfung = 1.00, daempfungVoll = 1.00,
        kabineFeder = 1.00, kabineDaempfung = 1.00, kabineWeg = 1.00,
        pedal    = 1.00,
    },
    {   -- Sanft
        zugSeite = 0.75, zugAntrieb = 0.85, zugReibung = 1.00, zugBremse = 1.00,
        anhSeite = 1.00, anhAntrieb = 1.00, anhReibung = 1.00, anhBremse = 1.00,
        feder    = 0.70, federVoll = 0.95, daempfung = 1.00, daempfungVoll = 1.15,
        kabineFeder = 1.10, kabineDaempfung = 1.20, kabineWeg = 0.85,
        pedal    = 0.85,
    },
    {   -- Deutlich
        zugSeite = 0.60, zugAntrieb = 0.75, zugReibung = 0.95, zugBremse = 1.00,
        anhSeite = 0.90, anhAntrieb = 1.00, anhReibung = 0.95, anhBremse = 1.00,
        feder    = 0.55, federVoll = 0.85, daempfung = 0.90, daempfungVoll = 1.10,
        kabineFeder = 1.20, kabineDaempfung = 1.35, kabineWeg = 0.70,
        pedal    = 0.70,
    },
    {   -- Realistisch. Die Federung ist gerechnet, nicht geschaetzt:
        -- Die Fahrzeuge des Basisspiels federn im Mittel mit 3,15 Hz
        -- (Einfederweg 25 mm bei 100 mm Federweg), eine gefederte
        -- Traktor-Vorderachse liegt bei 2,0 bis 2,5 Hz. Die Frequenz waechst
        -- mit der Wurzel der Federrate, 3,15 * sqrt(0,60) sind also 2,44 Hz.
        -- Weiter runter geht nicht: bei 0,50 braucht das haerteste Fahrzeug
        -- seinen ganzen Federweg auf und schlaegt durch.
        -- federVoll = 2 x feder haelt die Frequenz bei doppelter Last,
        -- daempfung = sqrt(feder) und daempfungVoll = sqrt(2 x federVoll)
        -- halten den Daempfungsgrad, den der Fahrzeugautor vorgesehen hat.
        -- Reifen und Pedale sind dagegen Erfahrungswerte, keine Rechnung.
        zugSeite = 0.75, zugAntrieb = 0.85, zugReibung = 1.00, zugBremse = 1.00,
        anhSeite = 1.00, anhAntrieb = 1.00, anhReibung = 1.00, anhBremse = 1.00,
        feder    = 0.60, federVoll = 1.20, daempfung = 0.75, daempfungVoll = 1.55,
        kabineFeder = 1.50, kabineDaempfung = 1.50, kabineWeg = 0.80,
        pedal    = 0.75,
    },
}


local function begrenze(wert)
    local zahl = tonumber(wert)
    if zahl == nil then
        return 1.0
    end
    if zahl < FahrGefuehl.MIN_FAKTOR then
        return FahrGefuehl.MIN_FAKTOR
    end
    if zahl > FahrGefuehl.MAX_FAKTOR then
        return FahrGefuehl.MAX_FAKTOR
    end
    return zahl
end

-- anteil 0 = leer, 1 = voll beladen.
local function mische(leer, voll, anteil)
    local a = tonumber(leer) or 1.0
    local b = tonumber(voll) or a
    return a + (b - a) * (anteil or 0)
end

function FahrGefuehl.getRaeder(vehicle)
    if vehicle == nil then
        return nil
    end
    local spec = vehicle.spec_wheels
    if spec == nil then
        return nil
    end
    return spec.wheels
end

local getRaeder = FahrGefuehl.getRaeder

local function istServer()
    if g_currentMission ~= nil and g_currentMission.getIsServer ~= nil then
        return g_currentMission:getIsServer() == true
    end
    return g_server ~= nil
end

function FahrGefuehl.istEigenerServer()
    return istServer()
end

function FahrGefuehl.getEigeneId()
    if g_localPlayer ~= nil and g_localPlayer.userId ~= nil then
        return g_localPlayer.userId
    end
    return 0
end

function FahrGefuehl.kopiereWerte(quelle)
    local ziel = { aktiv = quelle.aktiv == true, voreinstellung = quelle.voreinstellung or 0 }
    for _, key in ipairs(FahrGefuehl.FAKTOREN) do
        ziel[key] = tonumber(quelle[key]) or 1.0
    end
    return ziel
end

-- Eigene Werte direkt in die Server-Liste legen. Auf dem Host gibt es keine
-- Verbindung zu sich selbst, ueber die ein Event laufen koennte.
function FahrGefuehl.setzeEigeneLokal()
    local userId = FahrGefuehl.getEigeneId()
    if userId == 0 then
        return false
    end

    FahrGefuehl.spielerWerte[userId] = FahrGefuehl.kopiereWerte(FahrGefuehl.EIGEN)
    FahrGefuehl.anwenden()
    return true
end


-- Voreinstellungen ---------------------------------------------------------

function FahrGefuehl.wendeVoreinstellungAn(nummer, ziel)
    ziel = ziel or FahrGefuehl.CFG

    local satz = FahrGefuehl.VOREINSTELLUNGEN[nummer]
    if satz == nil then
        return false
    end

    for key, wert in pairs(satz) do
        ziel[key] = wert
    end
    ziel.voreinstellung = nummer
    return true
end

-- Zu welcher Stufe passen die Faktoren? 0 = zu keiner. Damit springt die
-- Anzeige von selbst auf "Eigene", sobald ein einzelner Regler abweicht.
function FahrGefuehl.erkenneVoreinstellung(ziel)
    ziel = ziel or FahrGefuehl.CFG

    for nummer, satz in ipairs(FahrGefuehl.VOREINSTELLUNGEN) do
        local passt = true
        for key, wert in pairs(satz) do
            local ist = tonumber(ziel[key])
            if ist == nil or math.abs(ist - wert) > 0.001 then
                passt = false
                break
            end
        end
        if passt then
            return nummer
        end
    end
    return 0
end


-- Wessen Werte gelten -----------------------------------------------------

-- Angehaengte Geraete fragen ueber rootVehicle das Zugfahrzeug.
function FahrGefuehl.getFahrerId(vehicle)
    if vehicle == nil then
        return 0
    end

    local root = vehicle.rootVehicle or vehicle
    local spec = root.spec_enterable
    if spec == nil or spec.isControlled ~= true then
        return 0
    end

    return spec.controllerUserId or 0
end

-- Reihenfolge: Server-Vorgabe aus -> gar nichts. Sonst die Werte des Fahrers,
-- wenn er eigene eingeschaltet hat. Sonst die Server-Vorgabe, auch fuer
-- KI-Helfer und abgestellte Fahrzeuge.
function FahrGefuehl.getWerteFuer(vehicle)
    if not FahrGefuehl.CFG.aktiv then
        return nil
    end

    local userId = FahrGefuehl.getFahrerId(vehicle)
    if userId ~= 0 then
        local eigene = FahrGefuehl.spielerWerte[userId]
        if eigene ~= nil and eigene.aktiv then
            return eigene
        end
    end

    return FahrGefuehl.CFG
end

function FahrGefuehl.istZugfahrzeug(vehicle)
    return vehicle ~= nil and vehicle.spec_motorized ~= nil
end

function FahrGefuehl.getFaktoren(vehicle)
    local werte = FahrGefuehl.getWerteFuer(vehicle)

    if werte == nil then
        return 1.0, 1.0, 1.0, 1.0
    end

    if FahrGefuehl.istZugfahrzeug(vehicle) then
        return begrenze(werte.zugSeite), begrenze(werte.zugAntrieb),
               begrenze(werte.zugReibung), begrenze(werte.zugBremse)
    end

    return begrenze(werte.anhSeite), begrenze(werte.anhAntrieb),
           begrenze(werte.anhReibung), begrenze(werte.anhBremse)
end


-- Einzelnes Rad -----------------------------------------------------------

function FahrGefuehl.merkeOriginal(physics)
    if physics == nil or physics.fgOriginal ~= nil then
        return
    end

    local original = {}
    for _, feld in ipairs(FahrGefuehl.FELDER) do
        if type(physics[feld]) == "number" then
            original[feld] = physics[feld]
        end
    end
    physics.fgOriginal = original
end

function FahrGefuehl.radAnwenden(physics)
    if physics == nil or physics.fgOriginal == nil then
        return
    end

    local vehicle = physics.vehicle
    local seite, antrieb, reibung, bremse = FahrGefuehl.getFaktoren(vehicle)
    local original = physics.fgOriginal

    if original.maxLatStiffness ~= nil then
        physics.maxLatStiffness = original.maxLatStiffness * seite
    end
    if original.maxLongStiffness ~= nil then
        physics.maxLongStiffness = original.maxLongStiffness * antrieb
    end
    if original.frictionScale ~= nil then
        physics.frictionScale = original.frictionScale * reibung
    end
    if original.brakeFactor ~= nil then
        physics.brakeFactor = original.brakeFactor * bremse
    end
    if original.autoHoldBrakeFactor ~= nil then
        physics.autoHoldBrakeFactor = original.autoHoldBrakeFactor * bremse
    end

    -- postUpdate uebernimmt die Reifenwerte beim naechsten Durchlauf.
    physics.isFrictionDirty = true

    -- setSuspensionMultipliers SETZT die Multiplikatoren, es multipliziert
    -- nicht - der Aufruf laesst sich also beliebig wiederholen.
    if physics.setSuspensionMultipliers ~= nil then
        local werte = FahrGefuehl.getWerteFuer(vehicle)
        if werte ~= nil then
            local anteil = physics.fgLast or 0
            physics:setSuspensionMultipliers(
                begrenze(mische(werte.feder, werte.federVoll, anteil)),
                begrenze(mische(werte.daempfung, werte.daempfungVoll, anteil)))
            physics.fgLastGesetzt = anteil
        else
            physics:setSuspensionMultipliers(1, 1)
            physics.fgLastGesetzt = nil
        end
    end
end


-- Radlast ----------------------------------------------------------------

-- 0 = das Rad traegt seine Nennlast (physics#restLoad), 1 = das Doppelte.
-- getTireLoad braucht die Radform, die nur der Server anlegt; beim Client
-- bleibt es beim Leerwert, dort ist die Federung ohnehin folgenlos.
function FahrGefuehl.messeLast(physics)
    if physics == nil or physics.getTireLoad == nil then
        return nil
    end

    local nennlast = physics.restLoad
    if type(nennlast) ~= "number" or nennlast <= 0 then
        return nil
    end

    local last = physics:getTireLoad()
    if type(last) ~= "number" or last <= 0 then
        return nil
    end

    local anteil = (last / nennlast - 1) / (FahrGefuehl.LAST_VOLL - 1)
    if anteil < 0 then
        return 0
    end
    if anteil > 1 then
        return 1
    end
    return anteil
end

-- Messen kostet je Rad einen Engine-Aufruf. Wer Leer- und Vollwert gleich
-- stehen laesst, will keine lastabhaengige Federung und bekommt auch keine.
local function lastWirkt(werte)
    if werte == nil then
        return false
    end
    return math.abs((werte.federVoll or 1) - (werte.feder or 1)) > 0.001
        or math.abs((werte.daempfungVoll or 1) - (werte.daempfung or 1)) > 0.001
end

function FahrGefuehl.pruefeLast(vehicle)
    if vehicle == nil or vehicle.isActive ~= true then
        return
    end

    if not lastWirkt(FahrGefuehl.getWerteFuer(vehicle)) then
        return
    end

    local raeder = getRaeder(vehicle)
    if raeder == nil then
        return
    end

    local neuSetzen = false
    for _, rad in pairs(raeder) do
        local physics = rad.physics
        if physics ~= nil and physics.fgOriginal ~= nil then
            local gemessen = FahrGefuehl.messeLast(physics)
            if gemessen ~= nil then
                local alt = physics.fgLast or gemessen
                physics.fgLast = alt + (gemessen - alt) * FahrGefuehl.LAST_TRAEGHEIT

                local gesetzt = physics.fgLastGesetzt
                if gesetzt == nil or math.abs(physics.fgLast - gesetzt) > FahrGefuehl.LAST_SCHWELLE then
                    neuSetzen = true
                end
            end
        end
    end

    if neuSetzen then
        FahrGefuehl.fahrzeugAnwenden(vehicle)
    end
end


-- Alle Fahrzeuge ----------------------------------------------------------

function FahrGefuehl.fahrzeugAnwenden(vehicle)
    local raeder = getRaeder(vehicle)
    if raeder == nil then
        return 0
    end

    local anzahl = 0
    for _, rad in pairs(raeder) do
        local physics = rad.physics
        if physics ~= nil and physics.fgOriginal ~= nil then
            FahrGefuehl.radAnwenden(physics)
            anzahl = anzahl + 1
        end
    end

    vehicle.fgFahrer = FahrGefuehl.getFahrerId(vehicle)

    -- Den Pedalfaktor hier ablegen: FGPedal haengt in der Physik und wird je
    -- Fahrzeug und Schritt aufgerufen, da soll es nur ein Feld lesen.
    local werte = FahrGefuehl.getWerteFuer(vehicle)
    if werte == nil then
        vehicle.fgPedal = nil
    else
        vehicle.fgPedal = tonumber(werte.pedal)
    end

    return anzahl
end

function FahrGefuehl.anwenden()
    if g_currentMission == nil then
        return 0
    end

    local system = g_currentMission.vehicleSystem
    if system == nil or system.vehicles == nil then
        return 0
    end

    local raederGesamt = 0
    for _, vehicle in pairs(system.vehicles) do
        raederGesamt = raederGesamt + FahrGefuehl.fahrzeugAnwenden(vehicle)
    end

    local kabinenKnoten = 0
    if FGKabine ~= nil then
        kabinenKnoten = FGKabine.anwendenAlle()
    end

    if FahrGefuehl.CFG.debug then
        Logging.info(FahrGefuehl.LOG .. "%d Raeder und %d Federungsknoten neu gesetzt (aktiv=%s).",
            raederGesamt, kabinenKnoten, tostring(FahrGefuehl.CFG.aktiv))
    end

    return raederGesamt
end


-- Fahrerwechsel -----------------------------------------------------------

function FahrGefuehl:update(dt)
    if not istServer() or g_currentMission == nil then
        return
    end

    local system = g_currentMission.vehicleSystem
    if system == nil or system.vehicles == nil then
        return
    end

    FahrGefuehl.pruefZeit = (FahrGefuehl.pruefZeit or 0) - (dt or 0)
    if FahrGefuehl.pruefZeit > 0 then
        return
    end
    FahrGefuehl.pruefZeit = FahrGefuehl.PRUEF_MS

    -- g_localPlayer gibt es beim Kartenstart noch nicht; sobald die eigene
    -- Kennung da ist, einmal eintragen.
    local eigeneId = FahrGefuehl.getEigeneId()
    if eigeneId ~= 0 and FahrGefuehl.spielerWerte[eigeneId] == nil then
        FahrGefuehl.setzeEigeneLokal()
    end

    for _, vehicle in pairs(system.vehicles) do
        local jetzt = FahrGefuehl.getFahrerId(vehicle)
        if vehicle.fgFahrer ~= jetzt then
            FahrGefuehl.fahrzeugAnwenden(vehicle)

            if FahrGefuehl.CFG.debug then
                Logging.info(FahrGefuehl.LOG .. "Fahrerwechsel an '%s': %s -> %s",
                    tostring(vehicle.configFileName), tostring(vehicle.fgFahrer), tostring(jetzt))
            end
        else
            FahrGefuehl.pruefeLast(vehicle)
        end
    end
end


-- Uebersicht fuer fgStatus ------------------------------------------------

function FahrGefuehl.baueUebersicht()
    local namen  = { [0] = "Eigene", "Serie", "Sanft", "Deutlich", "Realistisch" }
    local cfg    = FahrGefuehl.CFG
    local zeilen = {
        string.format("aktiv = %s", tostring(cfg.aktiv)),
        string.format("Server-Vorgabe: %s", namen[FahrGefuehl.erkenneVoreinstellung(cfg)] or "Eigene"),
        string.format("  Zugfahrzeuge:  Seite x%.2f  Antrieb x%.2f  Reibung x%.2f  Bremse x%.2f",
            cfg.zugSeite, cfg.zugAntrieb, cfg.zugReibung, cfg.zugBremse),
        string.format("  Anhaenger:     Seite x%.2f  Antrieb x%.2f  Reibung x%.2f  Bremse x%.2f",
            cfg.anhSeite, cfg.anhAntrieb, cfg.anhReibung, cfg.anhBremse),
        string.format("  Federung leer: Feder x%.2f  Daempfung x%.2f", cfg.feder, cfg.daempfung),
        string.format("  Federung voll: Feder x%.2f  Daempfung x%.2f", cfg.federVoll, cfg.daempfungVoll),
        string.format("  Kabine (%s): Feder x%.2f  Daempfung x%.2f  Weg x%.2f",
            cfg.kabineAktiv and "an" or "aus", cfg.kabineFeder, cfg.kabineDaempfung, cfg.kabineWeg),
        string.format("  Pedale:        x%.2f", cfg.pedal),
        string.format("Schlupf uebertragen: %s", cfg.mpSchlupf and "an" or "aus"),
        string.format("Meine Werte: %s (%s)",
            FahrGefuehl.EIGEN.aktiv and "an" or "aus",
            namen[FahrGefuehl.erkenneVoreinstellung(FahrGefuehl.EIGEN)] or "Eigene"),
    }

    local anzahlSpieler = 0
    for _ in pairs(FahrGefuehl.spielerWerte) do
        anzahlSpieler = anzahlSpieler + 1
    end
    table.insert(zeilen, string.format("Spieler mit eigenen Werten auf dem Server: %d", anzahlSpieler))

    local fahrzeuge, raeder = 0, 0
    if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil
            and g_currentMission.vehicleSystem.vehicles ~= nil then
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            local liste = getRaeder(vehicle)
            if liste ~= nil then
                fahrzeuge = fahrzeuge + 1
                for _, rad in pairs(liste) do
                    if rad.physics ~= nil and rad.physics.fgOriginal ~= nil then
                        raeder = raeder + 1
                    end
                end
            end
        end
    end
    table.insert(zeilen, string.format("erfasst: %d Fahrzeuge, %d Raeder", fahrzeuge, raeder))

    return zeilen
end


-- WheelPhysics:finalize ist der richtige Zeitpunkt: vorher sind
-- maxLatStiffness und maxLatStiffnessLoad noch Verhaeltniswerte, finalize
-- multipliziert sie mit restLoad.
local function init()
    if WheelPhysics == nil or WheelPhysics.finalize == nil or Utils == nil then
        Logging.warning(FahrGefuehl.LOG .. "WheelPhysics nicht gefunden - Mod inaktiv.")
        return
    end

    WheelPhysics.finalize = Utils.appendedFunction(WheelPhysics.finalize,
        function(self)
            FahrGefuehl.merkeOriginal(self)
            FahrGefuehl.radAnwenden(self)
        end)

    addModEventListener(FahrGefuehl)
end

init()
