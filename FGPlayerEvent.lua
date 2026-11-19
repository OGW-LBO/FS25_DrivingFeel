--
-- FGPlayerEvent - persoenliche Werte eines Spielers zum Server
--
-- Laeuft nur in eine Richtung: Client -> Server. Der Server legt den Wertesatz
-- unter der Kennung des Absenders ab und benutzt ihn fuer jedes Fahrzeug, in
-- dem dieser Spieler sitzt.
--
-- Die Kennung schickt der Client nicht mit, der Server holt sie aus der
-- Verbindung. Eine Admin-Pruefung gibt es hier nicht: jeder darf sein eigenes
-- Fahrgefuehl festlegen, aber eben nur sein eigenes.
--

FGPlayerEvent = {}

local FGPlayerEvent_mt = Class(FGPlayerEvent, Event)

InitEventClass(FGPlayerEvent, "FGPlayerEvent")

function FGPlayerEvent.emptyNew()
    return Event.new(FGPlayerEvent_mt)
end

function FGPlayerEvent.new()
    return FGPlayerEvent.emptyNew()
end

function FGPlayerEvent:writeStream(streamId, connection)
    local eigen = FahrGefuehl.EIGEN

    streamWriteBool(streamId, eigen.aktiv == true)
    streamWriteInt32(streamId, math.floor(tonumber(eigen.voreinstellung) or 0))

    local keys = FahrGefuehl.FAKTOREN
    streamWriteInt32(streamId, #keys)
    for _, key in ipairs(keys) do
        streamWriteFloat32(streamId, tonumber(eigen[key]) or 1)
    end
end

function FGPlayerEvent:readStream(streamId, connection)
    local werte = { aktiv = streamReadBool(streamId) }
    werte.voreinstellung = streamReadInt32(streamId)

    local anzahl = streamReadInt32(streamId)
    local keys   = FahrGefuehl.FAKTOREN

    if anzahl ~= #keys then
        -- Stream trotzdem leerlesen, sonst geraet die Leitung aus dem Tritt.
        for _ = 1, anzahl do
            streamReadFloat32(streamId)
        end
        Logging.warning(FahrGefuehl.LOG .. "Persoenliche Werte verworfen: Sender hat %d Faktoren, " ..
            "Empfaenger erwartet %d. Laeuft auf Server und Client dieselbe Mod-Version?",
            anzahl, #keys)
        return
    end

    for _, key in ipairs(keys) do
        werte[key] = streamReadFloat32(streamId)
    end

    self:uebernehmen(werte, connection)
end

function FGPlayerEvent:uebernehmen(werte, connection)
    -- Nur der Server fuehrt die Liste, ein Client bekommt dieses Event nie.
    if connection:getIsServer() then
        return
    end

    if g_currentMission == nil or g_currentMission.userManager == nil then
        return
    end

    local verwaltung = g_currentMission.userManager
    if verwaltung.getUserIdByConnection == nil then
        return
    end

    local userId = verwaltung:getUserIdByConnection(connection)
    if userId == nil or userId == 0 then
        return
    end

    FahrGefuehl.spielerWerte[userId] = FahrGefuehl.kopiereWerte(werte)
    FahrGefuehl.anwenden()

    if FahrGefuehl.CFG.debug then
        Logging.info(FahrGefuehl.LOG .. "Eigene Werte von Benutzer %s uebernommen (aktiv=%s).",
            tostring(userId), tostring(werte.aktiv))
    end
end

function FGPlayerEvent.sendeEigene()
    if FahrGefuehl.istEigenerServer() then
        FahrGefuehl.setzeEigeneLokal()
        return
    end

    if g_client == nil or g_client.getServerConnection == nil then
        return
    end

    local conn = g_client:getServerConnection()
    if conn ~= nil then
        conn:sendEvent(FGPlayerEvent.new())
    end
end
