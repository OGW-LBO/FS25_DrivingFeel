--
-- FGSettings - Speichern, Verteilen, Konsolenbefehle
--
-- Die Server-Vorgabe gehoert dem Server. Ein Client meldet eine Aenderung
-- dorthin und bekommt sie von dort bestaetigt zurueck. Die persoenlichen Werte
-- liegen dagegen lokal und gelten fuer jeden Spielstand.
--

FGSettings = {}

FGSettings.settingsDir   = g_currentModSettingsDirectory
FGSettings.xmlFilename   = nil
FGSettings.initialisiert = false

FGSettings.META = {
    { key = "aktiv",          bool = true },
    { key = "voreinstellung", min = 0, max = 4, step = 1 },
    { key = "zugSeite",   min = 0.25, max = 2.50, step = 0.05 },
    { key = "zugAntrieb", min = 0.25, max = 2.50, step = 0.05 },
    { key = "zugReibung", min = 0.25, max = 2.50, step = 0.05 },
    { key = "zugBremse",  min = 0.25, max = 2.50, step = 0.05 },
    { key = "anhSeite",   min = 0.25, max = 2.50, step = 0.05 },
    { key = "anhAntrieb", min = 0.25, max = 2.50, step = 0.05 },
    { key = "anhReibung", min = 0.25, max = 2.50, step = 0.05 },
    { key = "anhBremse",  min = 0.25, max = 2.50, step = 0.05 },
    { key = "feder",         min = 0.25, max = 2.50, step = 0.05 },
    { key = "federVoll",     min = 0.25, max = 2.50, step = 0.05 },
    { key = "daempfung",     min = 0.25, max = 2.50, step = 0.05 },
    { key = "daempfungVoll", min = 0.25, max = 2.50, step = 0.05 },
    -- Engere Grenzen: die Kabine haengt in ihren Anschlaegen, zu viel Weg
    -- schiebt sie aus der Geometrie, die der Erbauer vorgesehen hat.
    { key = "kabineAktiv",     bool = true },
    { key = "kabineFeder",     min = 0.50, max = 1.50, step = 0.05 },
    { key = "kabineDaempfung", min = 0.50, max = 1.50, step = 0.05 },
    { key = "kabineWeg",       min = 0.50, max = 1.50, step = 0.05 },
    { key = "pedal",      min = 0.40, max = 1.50, step = 0.05 },
    { key = "mpSchlupf",  bool = true },
    { key = "debug",      bool = true },
}


function FGSettings.istServer()
    if g_currentMission ~= nil and g_currentMission.getIsServer ~= nil then
        return g_currentMission:getIsServer() == true
    end
    return g_server ~= nil
end

function FGSettings.getMeta(key)
    for _, m in ipairs(FGSettings.META) do
        if m.key == key then
            return m
        end
    end
    return nil
end

-- Reihenfolge muss auf Server und Client gleich sein, sonst verschiebt sich
-- der Netzwerk-Stream.
function FGSettings.sortedKeys()
    local keys = {}
    for k, v in pairs(FahrGefuehl.CFG) do
        local art = type(v)
        if art == "number" or art == "boolean" then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    return keys
end

-- Setzt einen Wert auf den Grenzen begrenzt, nur lokal, ohne Sync.
function FGSettings.applyValueAuf(ziel, key, value)
    local cfg = ziel
    if cfg[key] == nil then
        return false
    end

    if type(cfg[key]) == "boolean" then
        cfg[key] = (value == true or value == 1 or value == "true" or value == "1")
        return true
    end

    local num = tonumber(value)
    if num == nil then
        return false
    end

    local meta = FGSettings.getMeta(key)
    if meta ~= nil then
        if meta.min ~= nil then num = math.max(meta.min, num) end
        if meta.max ~= nil then num = math.min(meta.max, num) end

        -- Ganzzahlige Regler runden: ueber XML-Float und streamWriteFloat32
        -- kommt sonst 0.9999... zurueck und ein Vergleich auf 1 geht schief.
        if meta.step == 1 then
            num = math.floor(num + 0.5)
        end
    end

    cfg[key] = num
    return true
end

function FGSettings.applyValue(key, value)
    return FGSettings.applyValueAuf(FahrGefuehl.CFG, key, value)
end

-- Nachbereitung, aber nur fuer Verstellungen durch den Nutzer: eine
-- Voreinstellung setzt alle anderen Regler, und umgekehrt faellt sie auf
-- "Eigene", sobald einer davon abweicht.
--
-- Darf nicht in applyValue stehen. Beim Laden aus der XML und beim Empfangen
-- vom Server laufen die Schluessel alphabetisch durch, "voreinstellung" steckt
-- also mittendrin und wuerde das halb gelesene Ergebnis ueberschreiben.
function FGSettings.nachVerstellung(key, ziel)
    ziel = ziel or FahrGefuehl.CFG

    if key == "voreinstellung" then
        FahrGefuehl.wendeVoreinstellungAn(ziel.voreinstellung, ziel)
    else
        ziel.voreinstellung = FahrGefuehl.erkenneVoreinstellung(ziel)
    end
end


-- Persoenliche Werte -------------------------------------------------------

function FGSettings.getEigenFilename()
    local dir = FGSettings.settingsDir
    if dir == nil then
        return nil
    end
    if createFolder ~= nil then
        createFolder(dir)
    end
    return dir .. "eigene.xml"
end

function FGSettings.saveEigene()
    local filename = FGSettings.getEigenFilename()
    if filename == nil or XMLFile == nil or XMLFile.create == nil then
        return
    end

    local xmlFile = XMLFile.create("fgEigenXML", filename, "eigene")
    if xmlFile == nil then
        return
    end

    xmlFile:setBool("eigene#aktiv", FahrGefuehl.EIGEN.aktiv == true)
    for _, key in ipairs(FahrGefuehl.FAKTOREN) do
        xmlFile:setFloat("eigene." .. key, FahrGefuehl.EIGEN[key])
    end

    xmlFile:save()
    xmlFile:delete()
end

function FGSettings.loadEigene()
    local filename = FGSettings.getEigenFilename()
    if filename == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        return
    end

    local xmlFile = XMLFile.loadIfExists("fgEigenXML", filename)
    if xmlFile == nil then
        return
    end

    local aktiv = xmlFile:getBool("eigene#aktiv")
    if aktiv ~= nil then
        FahrGefuehl.EIGEN.aktiv = aktiv
    end

    for _, key in ipairs(FahrGefuehl.FAKTOREN) do
        local v = xmlFile:getFloat("eigene." .. key)
        if v ~= nil then
            FGSettings.applyValueAuf(FahrGefuehl.EIGEN, key, v)
        end
    end

    xmlFile:delete()

    FahrGefuehl.EIGEN.voreinstellung = FahrGefuehl.erkenneVoreinstellung(FahrGefuehl.EIGEN)
end

function FGSettings.setzeEigenWert(key, wert)
    if FahrGefuehl.EIGEN[key] == nil then
        return false
    end

    if not FGSettings.applyValueAuf(FahrGefuehl.EIGEN, key, wert) then
        return false
    end

    FGSettings.nachVerstellung(key, FahrGefuehl.EIGEN)
    FGSettings.saveEigene()
    FGPlayerEvent.sendeEigene()
    return true
end

function FGSettings.setzeWert(key, wert)
    if FahrGefuehl.CFG[key] == nil then
        return false, string.format("Unbekannte Einstellung '%s'.", tostring(key))
    end

    if not FGSettings.applyValue(key, wert) then
        return false, string.format("Wert '%s' fuer '%s' nicht gueltig.", tostring(wert), key)
    end

    FGSettings.nachVerstellung(key)
    FGSettings.onLocalChange()
    return true, string.format("%s = %s", key, tostring(FahrGefuehl.CFG[key]))
end


-- settings.xml (schreibt nur Server bzw. Einzelspieler) --------------------

function FGSettings.getXmlFilename()
    if FGSettings.xmlFilename ~= nil then
        return FGSettings.xmlFilename
    end

    local dir = FGSettings.settingsDir
    if dir == nil then
        return nil
    end

    if createFolder ~= nil then
        createFolder(dir)
    end

    FGSettings.xmlFilename = dir .. "settings.xml"
    return FGSettings.xmlFilename
end

function FGSettings.save()
    if not FGSettings.istServer() then
        return
    end

    local filename = FGSettings.getXmlFilename()
    if filename == nil or XMLFile == nil or XMLFile.create == nil then
        return
    end

    local xmlFile = XMLFile.create("fgSettingsXML", filename, "settings")
    if xmlFile == nil then
        Logging.warning(FahrGefuehl.LOG .. "Einstellungen konnten nicht geschrieben werden: %s",
            tostring(filename))
        return
    end

    for _, key in ipairs(FGSettings.sortedKeys()) do
        local pfad = "settings.regler." .. key
        local v    = FahrGefuehl.CFG[key]
        if type(v) == "boolean" then
            xmlFile:setBool(pfad, v)
        else
            xmlFile:setFloat(pfad, v)
        end
    end

    xmlFile:save()
    xmlFile:delete()
end

function FGSettings.load()
    local filename = FGSettings.getXmlFilename()
    if filename == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        return
    end

    local xmlFile = XMLFile.loadIfExists("fgSettingsXML", filename)
    if xmlFile == nil then
        return
    end

    for _, key in ipairs(FGSettings.sortedKeys()) do
        local pfad = "settings.regler." .. key
        if type(FahrGefuehl.CFG[key]) == "boolean" then
            local v = xmlFile:getBool(pfad)
            if v ~= nil then
                FahrGefuehl.CFG[key] = v
            end
        else
            local v = xmlFile:getFloat(pfad)
            if v ~= nil then
                FGSettings.applyValue(key, v)
            end
        end
    end

    xmlFile:delete()

    -- Voreinstellung aus den geladenen Werten ableiten statt sie zu glauben:
    -- eine aeltere settings.xml kennt den Eintrag nicht, eine von Hand
    -- bearbeitete kann ihn falsch stehen haben.
    FahrGefuehl.CFG.voreinstellung = FahrGefuehl.erkenneVoreinstellung()
end


-- Mehrspieler --------------------------------------------------------------

function FGSettings.broadcast()
    if FGSettings.istServer() and g_server ~= nil and FGSettingsEvent ~= nil then
        g_server:broadcastEvent(FGSettingsEvent.new(true), false)
    end
end

function FGSettings.onLocalChange()
    FahrGefuehl.anwenden()

    if FGSettings.istServer() then
        FGSettings.save()
        FGSettings.broadcast()
    elseif g_client ~= nil and g_client.getServerConnection ~= nil and FGSettingsEvent ~= nil then
        local conn = g_client:getServerConnection()
        if conn ~= nil then
            conn:sendEvent(FGSettingsEvent.new(true))
        end
    end
end

-- Der Server hat den Vorschlag eines Clients uebernommen. Kein anwenden()
-- hier, das hat readStream schon direkt nach dem Lesen getan.
function FGSettings.onServerReceivedChange()
    FGSettings.save()
    FGSettings.broadcast()
end

function FGSettings.reload()
    if not FGSettings.istServer() then
        return false, "Nur der Server (bzw. Singleplayer) kann die settings.xml neu laden."
    end
    FGSettings.load()
    FahrGefuehl.anwenden()
    FGSettings.broadcast()
    return true, FGSettings.getXmlFilename()
end


-- Konsolenbefehle ---------------------------------------------------------
--
-- addConsoleCommand ruft target[name](target, ...) auf. Der erste Parameter
-- ist immer das Zielobjekt, nicht das erste Argument des Nutzers - ohne den
-- Platzhalter rutschen alle Argumente eine Stelle weiter.

function FGSettings.cmdStatus(_)
    for _, zeile in ipairs(FahrGefuehl.baueUebersicht()) do
        Logging.info(FahrGefuehl.LOG .. zeile)
    end
    return "Uebersicht steht im Log."
end

function FGSettings.cmdSet(_, key, wert)
    if key == nil or wert == nil then
        local namen = table.concat(FGSettings.sortedKeys(), ", ")
        return "Aufruf: fgSet <name> <wert>   Namen: " .. namen
    end

    local ok, text = FGSettings.setzeWert(key, wert)
    if not ok then
        return text
    end
    return string.format("%s  (%d Raeder neu gesetzt)", text, FahrGefuehl.anwenden())
end

function FGSettings.cmdReload(_)
    local ok, text = FGSettings.reload()
    if not ok then
        return text
    end
    return "Neu geladen aus " .. tostring(text)
end


-- Start --------------------------------------------------------------------

function FGSettings.clientFrageServer()
    if FGSettingsEvent == nil or g_client == nil or g_client.getServerConnection == nil then
        return
    end

    local conn = g_client:getServerConnection()
    if conn ~= nil then
        conn:sendEvent(FGSettingsEvent.new(false))
    end
end

function FGSettings:loadMap(name)
    if FGSettings.initialisiert then
        return
    end
    FGSettings.initialisiert = true

    local istServer = FGSettings.istServer()

    FGSettings.loadEigene()

    if istServer then
        FGSettings.load()
        FGSettings.save()

        if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil then
            FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(
                FSCareerMissionInfo.saveToXMLFile,
                function() FGSettings.save() end)
        end
    else
        local function beimBeitreten()
            FGSettings.clientFrageServer()
            FGPlayerEvent.sendeEigene()
        end

        if g_messageCenter ~= nil and MessageType ~= nil and MessageType.CURRENT_MISSION_LOADED ~= nil then
            g_messageCenter:subscribeOneshot(MessageType.CURRENT_MISSION_LOADED, beimBeitreten, FGSettings)
        else
            beimBeitreten()
        end
    end

    if addConsoleCommand ~= nil then
        addConsoleCommand("fgStatus", "Zeigt die Faktoren und die erfassten Raeder", "cmdStatus", FGSettings)
        addConsoleCommand("fgSet",    "Setzt einen Regler: fgSet <name> <wert>",     "cmdSet",    FGSettings)
        addConsoleCommand("fgReload", "settings.xml neu laden",                      "cmdReload", FGSettings)
    end

    Logging.info(FahrGefuehl.LOG .. "Einstellungen bereit (Server=%s).", tostring(istServer))
end

addModEventListener(FGSettings)
