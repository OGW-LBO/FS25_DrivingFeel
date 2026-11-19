--
-- FGSettingsEvent - Server-Vorgabe zwischen Server und Clients abgleichen
--
-- hasData = true  -> Traeger enthaelt alle Werte. Der Server nimmt sie als
--                    Vorschlag, speichert und verteilt; ein Client uebernimmt
--                    sie unbesehen.
-- hasData = false -> ein Client fragt den aktuellen Stand ab.
--
-- Vor jedem Wert steht ein Typ-Bit, damit der Stream ausgerichtet bleibt,
-- falls Server und Client fuer einen Schluessel verschiedene Typen haben.
--

FGSettingsEvent = {}

local FGSettingsEvent_mt = Class(FGSettingsEvent, Event)

InitEventClass(FGSettingsEvent, "FGSettingsEvent")

function FGSettingsEvent.emptyNew()
    return Event.new(FGSettingsEvent_mt)
end

function FGSettingsEvent.new(hasData)
    local self = FGSettingsEvent.emptyNew()
    self.hasData = (hasData == true)
    return self
end

function FGSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.hasData)

    if not self.hasData then
        return
    end

    local keys = FGSettings.sortedKeys()
    streamWriteInt32(streamId, #keys)

    for _, key in ipairs(keys) do
        local v       = FahrGefuehl.CFG[key]
        local istBool = (type(v) == "boolean")

        streamWriteBool(streamId, istBool)

        if istBool then
            streamWriteBool(streamId, v)
        else
            streamWriteFloat32(streamId, tonumber(v) or 1)
        end
    end
end

function FGSettingsEvent.istAdmin(connection)
    if g_currentMission == nil or g_currentMission.userManager == nil then
        return false
    end

    local benutzerVerwaltung = g_currentMission.userManager
    if benutzerVerwaltung.getUserByConnection == nil then
        return false
    end

    local benutzer = benutzerVerwaltung:getUserByConnection(connection)
    if benutzer == nil or benutzer.getIsMasterUser == nil then
        return false
    end

    return benutzer:getIsMasterUser() == true
end

function FGSettingsEvent:readStream(streamId, connection)
    self.hasData   = streamReadBool(streamId)
    self.abgelehnt = false

    -- Auf dem Server nur Aenderungen von Admins uebernehmen. Der Stream wird
    -- in jedem Fall vollstaendig gelesen, auch wenn die Werte verworfen
    -- werden, sonst geraet die Leitung aus dem Tritt.
    local empfaengerIstServer = not connection:getIsServer()
    local uebernehmen = true
    if self.hasData and empfaengerIstServer then
        uebernehmen = FGSettingsEvent.istAdmin(connection)
        self.abgelehnt = not uebernehmen
    end

    if self.hasData then
        local anzahl = streamReadInt32(streamId)
        local keys   = FGSettings.sortedKeys()

        if anzahl ~= #keys then
            Logging.warning(FahrGefuehl.LOG .. "Einstellungs-Sync verworfen: Sender hat %d Werte, " ..
                "Empfaenger erwartet %d. Laeuft auf Server und Client dieselbe Mod-Version?",
                anzahl, #keys)
            return
        end

        for _, key in ipairs(keys) do
            local istBool = streamReadBool(streamId)

            if istBool then
                local b = streamReadBool(streamId)
                if uebernehmen and type(FahrGefuehl.CFG[key]) == "boolean" then
                    FahrGefuehl.CFG[key] = b
                end
            else
                local v = streamReadFloat32(streamId)
                if uebernehmen then
                    FGSettings.applyValue(key, v)
                end
            end
        end

        if uebernehmen then
            FahrGefuehl.anwenden()

            -- Offene Seite auffrischen, damit ein Client die Werte sofort
            -- sieht und nicht erst beim naechsten Oeffnen des Menues.
            if g_FGMenuPage ~= nil and g_FGMenuPage.injiziert and g_FGMenuPage.populate ~= nil then
                g_FGMenuPage:populate()
            end
        else
            Logging.info(FahrGefuehl.LOG .. "Einstellungs-Vorschlag abgelehnt: Absender ist kein Admin.")
        end
    end

    self:run(connection)
end

function FGSettingsEvent:run(connection)
    -- getIsServer() == true -> der Empfaenger ist ein Client.
    local empfaengerIstClient = connection:getIsServer()

    if self.hasData then
        if not empfaengerIstClient then
            if self.abgelehnt then
                -- Dem Absender die gueltigen Werte zurueckschicken, damit
                -- seine Regler wieder auf den Stand des Servers springen.
                connection:sendEvent(FGSettingsEvent.new(true))
            else
                FGSettings.onServerReceivedChange()
            end
        end
    else
        if not empfaengerIstClient and g_server ~= nil then
            connection:sendEvent(FGSettingsEvent.new(true))
        end
    end
end
