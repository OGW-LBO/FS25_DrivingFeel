--
-- FGKabine - Faktoren auf die Kabinen- und Sitzfederung
--
-- Jedes Fahrzeug bringt seine Federung fuer Kabine, Sitz und Fahrerfigur in der
-- XML mit (vehicle.suspensions.suspension): je Achse eine Federrate und eine
-- Daempfung, dazu die Anschlaege und eine Grenze fuer den Geschwindigkeitssprung,
-- der die Federung anregt. Hier werden diese Werte mit Faktoren gerechnet, nicht
-- ersetzt - ein Grossschlepper bleibt also ruhiger als ein leichter Hoflader.
--
-- Rein oertlich: die Federung rechnet jeder Rechner fuer sich (Suspensions:onLoad
-- legt die Knoten nur mit isClient an), ein Netzwerk-Event braucht es dafuer nicht.
--
-- OGW
--

FGKabine = {}

FGKabine.PRUEF_MS = 500

FGKabine.pruefZeit = 0


local function getKnoten(vehicle)
    if vehicle == nil then
        return nil
    end
    local spec = vehicle.spec_suspensions
    if spec == nil or spec.suspensionNodes == nil or #spec.suspensionNodes == 0 then
        return nil
    end
    return spec.suspensionNodes
end

-- Die Werte gelten nur fuer diesen Rechner, also auch die eigenen ohne Umweg
-- ueber den Server.
function FGKabine.getWerte()
    if not FahrGefuehl.CFG.aktiv or not FahrGefuehl.CFG.kabineAktiv then
        return nil
    end

    if FahrGefuehl.EIGEN.aktiv then
        return FahrGefuehl.EIGEN
    end

    return FahrGefuehl.CFG
end

local function kopiereVektor(quelle)
    if type(quelle) ~= "table" then
        return nil
    end

    local ziel = {}
    for i = 1, #quelle do
        ziel[i] = quelle[i]
    end
    return ziel
end


-- Sichern ----------------------------------------------------------------

local function merkeKnoten(knoten)
    local parameter = {}
    if type(knoten.suspensionParameters) ~= "table" then
        return nil
    end

    for i = 1, 3 do
        local satz = knoten.suspensionParameters[i]
        if type(satz) ~= "table" or satz[1] == nil or satz[2] == nil then
            return nil
        end
        parameter[i] = { satz[1], satz[2] }
    end

    return {
        knoten         = knoten,
        parameter      = parameter,
        minTranslation = kopiereVektor(knoten.minTranslation),
        maxTranslation = kopiereVektor(knoten.maxTranslation),
        minRotation    = kopiereVektor(knoten.minRotation),
        maxRotation    = kopiereVektor(knoten.maxRotation),
        maxVelocityDifference = tonumber(knoten.maxVelocityDifference),
    }
end


-- Anwenden ---------------------------------------------------------------

local function setzeVektor(ziel, original, faktor)
    if ziel == nil or original == nil then
        return
    end
    for i = 1, #original do
        ziel[i] = original[i] * faktor
    end
end

function FGKabine.fahrzeugAnwenden(vehicle)
    local liste = vehicle ~= nil and vehicle.fgKabine or nil
    if type(liste) ~= "table" then
        return 0
    end

    local werte = FGKabine.getWerte()
    local feder, daempfung, weg = 1.0, 1.0, 1.0
    if werte ~= nil then
        feder     = tonumber(werte.kabineFeder) or 1.0
        daempfung = tonumber(werte.kabineDaempfung) or 1.0
        weg       = tonumber(werte.kabineWeg) or 1.0
    end

    for _, eintrag in ipairs(liste) do
        local knoten = eintrag.knoten

        for i = 1, 3 do
            local satz = knoten.suspensionParameters[i]
            if type(satz) == "table" then
                satz[1] = eintrag.parameter[i][1] * feder
                satz[2] = eintrag.parameter[i][2] * daempfung
            end
        end

        setzeVektor(knoten.minTranslation, eintrag.minTranslation, weg)
        setzeVektor(knoten.maxTranslation, eintrag.maxTranslation, weg)
        setzeVektor(knoten.minRotation, eintrag.minRotation, weg)
        setzeVektor(knoten.maxRotation, eintrag.maxRotation, weg)

        -- maxVelocityDifference klemmt den Geschwindigkeitssprung zwischen zwei
        -- Bildern, bevor daraus die Beschleunigung wird (Suspensions.lua:147).
        -- Bei 60 fps macht der Standardwert 0,1 schon 6,25 m/s². Die Grenze ist
        -- also der einzige Deckel gegen einzelne Spitzen - und im Mehrspieler
        -- kommen die reichlich, weil die Lage beim Client zwischen zwei
        -- Netzwerkpaketen nur interpoliert wird und an jeder Paketgrenze einen
        -- Knick hat. Darum wird sie nie angehoben, nur gesenkt.
        if eintrag.maxVelocityDifference ~= nil then
            if weg < 1.0 then
                knoten.maxVelocityDifference = eintrag.maxVelocityDifference * weg
            else
                knoten.maxVelocityDifference = eintrag.maxVelocityDifference
            end
        end
    end

    return #liste
end

-- false heisst: dieses Fahrzeug hat keine eigene Federung, nicht noch einmal
-- nachsehen.
function FGKabine.erfasse(vehicle)
    local knotenListe = getKnoten(vehicle)
    if knotenListe == nil then
        vehicle.fgKabine = false
        return 0
    end

    local gemerkt = {}
    for _, knoten in ipairs(knotenListe) do
        local eintrag = merkeKnoten(knoten)
        if eintrag ~= nil then
            table.insert(gemerkt, eintrag)
        end
    end

    if #gemerkt == 0 then
        vehicle.fgKabine = false
        return 0
    end

    vehicle.fgKabine = gemerkt
    return FGKabine.fahrzeugAnwenden(vehicle)
end

function FGKabine.anwendenAlle()
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then
        return 0
    end

    local fahrzeuge = g_currentMission.vehicleSystem.vehicles
    if fahrzeuge == nil then
        return 0
    end

    local anzahl = 0
    for _, vehicle in pairs(fahrzeuge) do
        anzahl = anzahl + FGKabine.fahrzeugAnwenden(vehicle)
    end

    return anzahl
end


-- Nachfassen -------------------------------------------------------------

-- Gekaufte und nachgeladene Fahrzeuge kommen erst spaeter dazu. Der Durchlauf
-- sieht je Fahrzeug nur ein Feld an, solange es schon erfasst ist.
function FGKabine:update(dt)
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then
        return
    end

    FGKabine.pruefZeit = FGKabine.pruefZeit - (dt or 0)
    if FGKabine.pruefZeit > 0 then
        return
    end
    FGKabine.pruefZeit = FGKabine.PRUEF_MS

    local fahrzeuge = g_currentMission.vehicleSystem.vehicles
    if fahrzeuge == nil then
        return
    end

    local neue, knoten = 0, 0
    for _, vehicle in pairs(fahrzeuge) do
        if vehicle.fgKabine == nil then
            local gesetzt = FGKabine.erfasse(vehicle)
            if gesetzt > 0 then
                neue   = neue + 1
                knoten = knoten + gesetzt
            end
        end
    end

    if neue > 0 and FahrGefuehl.CFG.debug then
        Logging.info(FahrGefuehl.LOG .. "Kabinenfederung an %d Fahrzeugen gesetzt (%d Knoten).",
            neue, knoten)
    end
end

addModEventListener(FGKabine)
