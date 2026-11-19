--
-- FGSlipEvent - Radschlupf eines Fahrzeugs vom Server zu den Clients
--
-- Laeuft nur in eine Richtung. Je Rad gehen 13 Bit raus: Schlupf in 16 Stufen,
-- Drehrichtung und Umfangsgeschwindigkeit in halben km/h. Mehr Aufloesung
-- braucht es nicht, die Werte steuern Staub, Dreck und das Radbild.
--

FGSlipEvent = {}

local FGSlipEvent_mt = Class(FGSlipEvent, Event)

InitEventClass(FGSlipEvent, "FGSlipEvent")

function FGSlipEvent.emptyNew()
    return Event.new(FGSlipEvent_mt)
end

function FGSlipEvent.new(vehicle, werte)
    local self = FGSlipEvent.emptyNew()
    self.vehicle = vehicle
    self.werte   = werte or {}
    return self
end

function FGSlipEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)

    local anzahl = #self.werte
    if anzahl > FGSlip.MAX_RAEDER then
        anzahl = FGSlip.MAX_RAEDER
    end
    streamWriteUIntN(streamId, anzahl, 5)

    for i = 1, anzahl do
        local wert    = self.werte[i]
        local schlupf = tonumber(wert.schlupf) or 0
        local tempo   = tonumber(wert.tempo) or 0

        local stufe = math.floor(schlupf * 15 + 0.5)
        if stufe < 0 then
            stufe = 0
        elseif stufe > 15 then
            stufe = 15
        end
        streamWriteUIntN(streamId, stufe, 4)

        streamWriteBool(streamId, tempo >= 0)

        local kmh = math.abs(tempo) * 3600
        if kmh > FGSlip.MAX_KMH then
            kmh = FGSlip.MAX_KMH
        end
        streamWriteUIntN(streamId, math.floor(kmh * 2 + 0.5), 8)
    end
end

function FGSlipEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)

    local anzahl = streamReadUIntN(streamId, 5)
    local werte  = {}

    for i = 1, anzahl do
        local schlupf   = streamReadUIntN(streamId, 4) / 15
        local vorwaerts = streamReadBool(streamId)
        local tempo     = streamReadUIntN(streamId, 8) / 2 / 3600

        if not vorwaerts then
            tempo = -tempo
        end

        werte[i] = { schlupf = schlupf, tempo = tempo }
    end

    self.werte = werte
    self:run(connection)
end

function FGSlipEvent:run(connection)
    -- getIsServer() == true heisst: die Verbindung fuehrt zum Server, dieser
    -- Rechner ist also ein Client. Der Server selbst hat hier nichts zu tun.
    if not connection:getIsServer() then
        return
    end

    FGSlip.empfange(self.vehicle, self.werte)
end
