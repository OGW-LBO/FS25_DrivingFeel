--
-- FGSlip - Radschlupf im Mehrspieler
--
-- Die Radphysik rechnet nur der Server. Ein Client bekommt die Raddrehzahl
-- gedeckelt und geglaettet ueber die Leitung und rechnet daraus einen Schlupf,
-- der deutlich flacher ausfaellt als der echte - durchdrehende Raeder sieht man
-- im Mehrspieler darum kaum. Hier schickt der Server den Wert, den er selbst
-- ausrechnet, und der Client setzt ihn nach der Spielberechnung wieder ein.
--
-- Im Einzelspieler tut diese Datei nichts, dort stimmen die Werte ohnehin.
--
-- OGW
--

FGSlip = {}

FGSlip.SENDE_MS = 130
FGSlip.HALT_MS  = 400

-- Ab hier gilt ein Rad als durchdrehend. Darunter wird nichts geschickt, denn
-- ein wenig Schlupf hat jedes Rad beim Anfahren.
FGSlip.SCHWELLE = 0.06

FGSlip.MAX_FAHRZEUGE = 24
FGSlip.MAX_RAEDER    = 31
FGSlip.MAX_KMH       = 127.5

-- Je Aufruf ein Stueck in Richtung des gemeldeten Werts, damit zwischen zwei
-- Paketen keine Stufe sichtbar wird.
FGSlip.NACHZIEHEN = 0.3

FGSlip.clientAktiv = false
FGSlip.sendeZeit   = 0


local function istMehrspieler()
    if g_currentMission == nil or g_currentMission.missionDynamicInfo == nil then
        return false
    end
    return g_currentMission.missionDynamicInfo.isMultiplayer == true
end

local function getRaeder(vehicle)
    if vehicle == nil then
        return nil
    end
    local spec = vehicle.spec_wheels
    if spec == nil then
        return nil
    end
    return spec.wheels
end

local function jetzt()
    if g_currentMission ~= nil and type(g_currentMission.time) == "number" then
        return g_currentMission.time
    end
    return 0
end


-- Server ------------------------------------------------------------------

-- Gibt die Werte aller Raeder zurueck, aber nur wenn mindestens eins davon
-- durchdreht. Sonst nil, dann faellt der Client nach HALT_MS von selbst auf
-- die Spielwerte zurueck.
function FGSlip.sammle(vehicle)
    if vehicle == nil or vehicle.isActive ~= true then
        return nil
    end

    local raeder = getRaeder(vehicle)
    if raeder == nil then
        return nil
    end

    local anzahl = #raeder
    if anzahl == 0 or anzahl > FGSlip.MAX_RAEDER then
        return nil
    end

    local werte      = {}
    local hatSchlupf = false

    for i = 1, anzahl do
        local schlupf, tempo = 0, 0

        local physics = raeder[i].physics
        if physics ~= nil and physics.netInfo ~= nil then
            schlupf = tonumber(physics.netInfo.slip) or 0
            tempo   = tonumber(physics.netInfo.lastSpeedSmoothed) or 0
        end

        if schlupf > FGSlip.SCHWELLE then
            hatSchlupf = true
        end

        werte[i] = { schlupf = schlupf, tempo = tempo }
    end

    if not hatSchlupf then
        return nil
    end

    return werte
end

function FGSlip:update(dt)
    if not FGSettings.istServer() or g_server == nil then
        return
    end
    if not FahrGefuehl.CFG.mpSchlupf or not istMehrspieler() then
        return
    end
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then
        return
    end

    FGSlip.sendeZeit = FGSlip.sendeZeit - (dt or 0)
    if FGSlip.sendeZeit > 0 then
        return
    end
    FGSlip.sendeZeit = FGSlip.SENDE_MS

    local fahrzeuge = g_currentMission.vehicleSystem.vehicles
    if fahrzeuge == nil then
        return
    end

    local gesendet = 0
    for _, vehicle in pairs(fahrzeuge) do
        if gesendet >= FGSlip.MAX_FAHRZEUGE then
            break
        end

        local werte = FGSlip.sammle(vehicle)
        if werte ~= nil then
            -- Das Fahrzeug als letztes Argument: dann geht das Paket nur an
            -- Clients, die es ueberhaupt kennen.
            g_server:broadcastEvent(FGSlipEvent.new(vehicle, werte), false, nil, vehicle)
            gesendet = gesendet + 1
        end
    end
end


-- Client ------------------------------------------------------------------

function FGSlip.empfange(vehicle, werte)
    if vehicle == nil or werte == nil then
        return
    end

    local raeder = getRaeder(vehicle)
    if raeder == nil then
        return
    end

    if #raeder ~= #werte then
        if FahrGefuehl.CFG.debug then
            Logging.warning(FahrGefuehl.LOG .. "Schlupf verworfen: Sender hat %d Raeder, " ..
                "hier stehen %d. Laeuft auf Server und Client dieselbe Fahrzeug-Mod?",
                #werte, #raeder)
        end
        return
    end

    local zeit = jetzt()
    for i = 1, #werte do
        local physics = raeder[i].physics
        if physics ~= nil then
            physics.fgSchlupf = werte[i].schlupf
            physics.fgTempo   = werte[i].tempo
            physics.fgZeit    = zeit
        end
    end
end

local function ziehe(ist, ziel)
    if ist == nil then
        return ziel
    end
    return ist + (ziel - ist) * FGSlip.NACHZIEHEN
end

-- Haengt hinter WheelPhysics:updateXDriveSpeed. Laeuft also je Rad und Frame,
-- deshalb steht die Abkuerzung fuer Server und Einzelspieler ganz vorn.
function FGSlip.radAnwenden(physics)
    if not FGSlip.clientAktiv or not FahrGefuehl.CFG.mpSchlupf then
        return
    end

    local zeit = physics.fgZeit
    if zeit == nil then
        return
    end

    if jetzt() - zeit > FGSlip.HALT_MS then
        physics.fgZeit = nil
        return
    end

    local netInfo = physics.netInfo
    if netInfo == nil then
        return
    end

    netInfo.slip              = ziehe(netInfo.slip, physics.fgSchlupf or 0)
    netInfo.lastSpeedSmoothed = ziehe(netInfo.lastSpeedSmoothed, physics.fgTempo or 0)
end


-- Start -------------------------------------------------------------------

function FGSlip:loadMap(name)
    local function merkeSeite()
        FGSlip.clientAktiv = (not FGSettings.istServer()) and istMehrspieler()

        if FGSlip.clientAktiv and FahrGefuehl.CFG.debug then
            Logging.info(FahrGefuehl.LOG .. "Schlupf-Uebertragung: dieser Rechner ist Client.")
        end
    end

    if g_messageCenter ~= nil and MessageType ~= nil and MessageType.CURRENT_MISSION_LOADED ~= nil then
        g_messageCenter:subscribeOneshot(MessageType.CURRENT_MISSION_LOADED, merkeSeite, FGSlip)
    else
        merkeSeite()
    end
end

local function init()
    if WheelPhysics == nil or WheelPhysics.updateXDriveSpeed == nil or Utils == nil then
        Logging.warning(FahrGefuehl.LOG .. "WheelPhysics:updateXDriveSpeed nicht gefunden - " ..
            "Schlupf-Uebertragung inaktiv.")
        return
    end

    WheelPhysics.updateXDriveSpeed = Utils.appendedFunction(WheelPhysics.updateXDriveSpeed,
        function(self)
            FGSlip.radAnwenden(self)
        end)

    addModEventListener(FGSlip)
end

init()
