--
-- FGPedal - wie schnell Gas und Bremse ansprechen
--
-- Das Spiel laesst Gas- und Bremspedal nicht springen, sondern fuehrt sie mit
-- festen Raten nach (WheelsUtil.getSmoothedAcceleratorAndBrakePedals: Bremse
-- voll in 0,4 s, Loslassen in 0,66 bis 2 s). Alle diese Raten haengen linear an
-- der Zeitspanne, die die Funktion bekommt - ein Faktor darauf zieht also
-- saemtliche Rampen gleichmaessig in die Laenge, ohne die Formel anzutasten.
--
-- Kleiner als 1,00 heisst: Pedale bauen sich langsamer auf und ab, das Fahrzeug
-- wirkt schwerer. Groesser als 1,00 macht sie schnittiger.
--
-- Laeuft mit der Physik, also auf dem Server; der Faktor kommt vom Fahrer, so
-- dass im Mehrspieler jeder sein eigenes Pedalgefuehl haben kann.
--
-- OGW
--

FGPedal = {}

FGPedal.MIN = 0.40
FGPedal.MAX = 1.50


-- fgPedal legt FahrGefuehl.fahrzeugAnwenden ab, also bei jeder Verstellung und
-- bei jedem Fahrerwechsel. Hier wird nur gelesen: die Funktion haengt in der
-- Physik und laeuft je Fahrzeug und Schritt.
local function getFaktor(vehicle)
    if vehicle == nil then
        return 1.0
    end

    local faktor = tonumber(vehicle.fgPedal)
    if faktor == nil then
        return 1.0
    end

    if faktor < FGPedal.MIN then
        return FGPedal.MIN
    end
    if faktor > FGPedal.MAX then
        return FGPedal.MAX
    end
    return faktor
end

local function init()
    if WheelsUtil == nil or WheelsUtil.getSmoothedAcceleratorAndBrakePedals == nil or Utils == nil then
        Logging.warning(FahrGefuehl.LOG .. "WheelsUtil nicht gefunden - Pedalverlauf unveraendert.")
        return
    end

    WheelsUtil.getSmoothedAcceleratorAndBrakePedals = Utils.overwrittenFunction(
        WheelsUtil.getSmoothedAcceleratorAndBrakePedals,
        function(vehicle, superFunc, acceleratorPedal, brakePedal, dt)
            local faktor = getFaktor(vehicle)
            if math.abs(faktor - 1.0) < 0.001 then
                return superFunc(vehicle, acceleratorPedal, brakePedal, dt)
            end

            return superFunc(vehicle, acceleratorPedal, brakePedal, dt * faktor)
        end)
end

init()
