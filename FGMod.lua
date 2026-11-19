--
-- FGMod - Einstiegspunkt
--
-- Geladen werden alle Skripte ueber extraSourceFiles in der modDesc. Hier
-- stehen nur die beiden Anstoesse: den Einstellungs-Tab bauen, sobald das
-- InGameMenu existiert, und die Werte einmal auf alles anwenden, was beim
-- Kartenstart schon in der Welt steht.
--

FGMod = {}

FGMod.versuche     = 0
FGMod.MAX_VERSUCHE = 60      -- rund 60 Frames Nachlauf, falls das Menue spaet kommt

function FGMod.initSeite()
    if FGMenuPage == nil then
        return
    end

    if g_FGMenuPage == nil then
        g_FGMenuPage = FGMenuPage.new()
    end

    g_FGMenuPage:registerAndInject()
end

function FGMod:loadMap(name)
    -- Ein Fahrzeug, das vor dem Laden der settings.xml erzeugt wurde, haette
    -- sonst die Vorgabewerte.
    if g_messageCenter ~= nil and MessageType ~= nil and MessageType.CURRENT_MISSION_LOADED ~= nil then
        g_messageCenter:subscribeOneshot(MessageType.CURRENT_MISSION_LOADED, function()
            FahrGefuehl.anwenden()
        end, nil)
    end

    if g_dedicatedServer ~= nil then
        Logging.info(FahrGefuehl.LOG .. "Dedicated Server erkannt - Einstellungs-Tab wird nicht gebaut.")
        return
    end

    if g_messageCenter ~= nil and MessageType ~= nil and MessageType.OWN_PLAYER_ENTERED ~= nil then
        g_messageCenter:subscribeOneshot(MessageType.OWN_PLAYER_ENTERED, function()
            FGMod.initSeite()
        end, nil)
    else
        FGMod.initSeite()
    end
end

-- Nachfassen, falls das Menue beim ersten Versuch noch nicht stand.
function FGMod:update(dt)
    if g_dedicatedServer ~= nil then
        return
    end
    if g_FGMenuPage ~= nil and g_FGMenuPage.injiziert then
        return
    end
    if FGMod.versuche >= FGMod.MAX_VERSUCHE then
        return
    end

    FGMod.versuche = FGMod.versuche + 1
    FGMod.initSeite()
end

addModEventListener(FGMod)
