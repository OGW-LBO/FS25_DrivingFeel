--
-- FGSettingsPage - welche Regler es gibt und welche Werte sie annehmen
--
-- Gezeichnet werden sie von FGMenuPage in einem eigenen Unter-Tab unter
-- ESC -> Allgemeine Einstellungen. Alle sichtbaren Texte laufen ueber
-- l10n-Schluessel; die Uebersetzungen stehen inline in der modDesc, weil der
-- ModHub-TestRunner separate Sprachdateien als "obsolete" meldet.
--

FGSettingsPage = {}

-- Faellt auf den Schluessel zurueck, damit ein fehlender Eintrag nie eine
-- leere Zeile ergibt.
function FGSettingsPage.getText(key)
    if key == nil then
        return ""
    end
    if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n.getText ~= nil then
        if g_i18n:hasText(key) then
            return g_i18n:getText(key)
        end
    end
    return key
end

local t = FGSettingsPage.getText

-- art:     "bool" = Aus/An, "faktor" = Anzeige als x0.85,
--          "liste" = feste Auswahl (texte = l10n-Schluessel, Werte 0..n-1)
-- bereich: "server" = Server-Vorgabe (nur Admin), "eigen" = eigene Werte
--
-- Die Abschnitte fuer die eigenen Werte entstehen aus genau dieser Liste,
-- damit beide Seiten nie auseinanderlaufen. titelEigen, labelEigen und
-- tippEigen sind die Texte fuer diese Kopie.
FGSettingsPage.SERVER = {
    {
        titel = "fg_sec_allgemein",
        titelEigen = "fg_sec_eigen",
        eintraege = {
            { key = "aktiv", art = "bool",
              label = "fg_ui_aktiv", tipp = "fg_ui_aktiv_t",
              labelEigen = "fg_ui_eigenAktiv", tippEigen = "fg_ui_eigenAktiv_t" },
            -- Reihenfolge wie FahrGefuehl.VOREINSTELLUNGEN:
            -- 0 = Eigene, 1 = Serie, 2 = Sanft, 3 = Deutlich, 4 = Realistisch.
            { key = "voreinstellung", art = "liste",
              texte = { "fg_opt_eigene", "fg_opt_serie", "fg_opt_sanft", "fg_opt_deutlich", "fg_opt_realistisch" },
              label = "fg_ui_voreinstellung", tipp = "fg_ui_voreinstellung_t",
              tippEigen = "fg_ui_voreinstellungEigen_t" },
        },
    },
    {
        titel = "fg_sec_zug",
        titelEigen = "fg_sec_eigen_zug",
        eintraege = {
            { key = "zugSeite",   art = "faktor",
              label = "fg_ui_seite",   tipp = "fg_ui_seite_t" },
            { key = "zugAntrieb", art = "faktor",
              label = "fg_ui_antrieb", tipp = "fg_ui_antrieb_t" },
            { key = "zugReibung", art = "faktor",
              label = "fg_ui_reibung", tipp = "fg_ui_reibung_t" },
            { key = "zugBremse",  art = "faktor",
              label = "fg_ui_bremse",  tipp = "fg_ui_bremse_t" },
        },
    },
    {
        titel = "fg_sec_anhaenger",
        titelEigen = "fg_sec_eigen_anhaenger",
        eintraege = {
            { key = "anhSeite",   art = "faktor",
              label = "fg_ui_seite",   tipp = "fg_ui_seiteA_t" },
            { key = "anhAntrieb", art = "faktor",
              label = "fg_ui_antrieb", tipp = "fg_ui_antriebA_t" },
            { key = "anhReibung", art = "faktor",
              label = "fg_ui_reibung", tipp = "fg_ui_reibungA_t" },
            { key = "anhBremse",  art = "faktor",
              label = "fg_ui_bremse",  tipp = "fg_ui_bremseA_t" },
        },
    },
    {
        titel = "fg_sec_federung",
        titelEigen = "fg_sec_eigen_federung",
        eintraege = {
            { key = "feder",         art = "faktor",
              label = "fg_ui_feder",         tipp = "fg_ui_feder_t" },
            { key = "federVoll",     art = "faktor",
              label = "fg_ui_federVoll",     tipp = "fg_ui_federVoll_t" },
            { key = "daempfung",     art = "faktor",
              label = "fg_ui_daempfung",     tipp = "fg_ui_daempfung_t" },
            { key = "daempfungVoll", art = "faktor",
              label = "fg_ui_daempfungVoll", tipp = "fg_ui_daempfungVoll_t" },
        },
    },
    {
        titel = "fg_sec_kabine",
        titelEigen = "fg_sec_eigen_kabine",
        eintraege = {
            { key = "kabineAktiv",     art = "bool",
              label = "fg_ui_kabineAktiv",     tipp = "fg_ui_kabineAktiv_t" },
            { key = "kabineWeg",       art = "faktor",
              label = "fg_ui_kabineWeg",       tipp = "fg_ui_kabineWeg_t" },
            { key = "kabineFeder",     art = "faktor",
              label = "fg_ui_kabineFeder",     tipp = "fg_ui_kabineFeder_t" },
            { key = "kabineDaempfung", art = "faktor",
              label = "fg_ui_kabineDaempfung", tipp = "fg_ui_kabineDaempfung_t" },
        },
    },
    {
        titel = "fg_sec_pedale",
        titelEigen = "fg_sec_eigen_pedale",
        eintraege = {
            { key = "pedal", art = "faktor",
              label = "fg_ui_pedal", tipp = "fg_ui_pedal_t" },
        },
    },
    {
        titel = "fg_sec_mp",
        nurMehrspieler = true,
        eintraege = {
            { key = "mpSchlupf", art = "bool",
              label = "fg_ui_mpSchlupf", tipp = "fg_ui_mpSchlupf_t" },
        },
    },
    {
        titel = "fg_sec_meldungen",
        eintraege = {
            { key = "debug", art = "bool",
              label = "fg_ui_debug", tipp = "fg_ui_debug_t" },
        },
    },
}

local function istMehrspieler()
    if g_currentMission == nil or g_currentMission.missionDynamicInfo == nil then
        return false
    end
    return g_currentMission.missionDynamicInfo.isMultiplayer == true
end

-- Eintraege ohne Gegenstueck in EIGEN (debug) fallen weg.
local function eigeneAbschnitte()
    local abschnitte = {}

    for _, gruppe in ipairs(FGSettingsPage.SERVER) do
        local eintraege = {}

        for _, eintrag in ipairs(gruppe.eintraege) do
            if FahrGefuehl.EIGEN[eintrag.key] ~= nil then
                local kopie = {}
                for k, v in pairs(eintrag) do
                    kopie[k] = v
                end
                kopie.bereich = "eigen"
                kopie.label   = eintrag.labelEigen or eintrag.label
                kopie.tipp    = eintrag.tippEigen  or eintrag.tipp
                table.insert(eintraege, kopie)
            end
        end

        if #eintraege > 0 then
            table.insert(abschnitte, {
                titel     = gruppe.titelEigen or gruppe.titel,
                eintraege = eintraege,
            })
        end
    end

    return abschnitte
end

-- Im Einzelspieler waeren zwei Wertesaetze nur verwirrend, dort ist die
-- Server-Vorgabe ohnehin die eigene.
function FGSettingsPage.baueAbschnitte()
    local abschnitte = {}

    for _, gruppe in ipairs(FGSettingsPage.SERVER) do
        if not gruppe.nurMehrspieler or istMehrspieler() then
            table.insert(abschnitte, gruppe)
        end
    end

    if istMehrspieler() then
        for _, gruppe in ipairs(eigeneAbschnitte()) do
            table.insert(abschnitte, gruppe)
        end
    end

    return abschnitte
end


-- Wertelisten --------------------------------------------------------------

local function rundeAuf(wert, step)
    if step == nil or step <= 0 then
        return wert
    end
    return math.floor(wert / step + 0.5) * step
end

-- Grenzen kommen aus FGSettings.META, damit Regler und Konsolenbefehl nie
-- auseinanderlaufen.
function FGSettingsPage.baueWerte(eintrag)
    if eintrag.art == "bool" then
        return { false, true }, { t("fg_opt_aus"), t("fg_opt_an") }
    end

    if eintrag.art == "liste" then
        local werte, texte = {}, {}
        for i, schluessel in ipairs(eintrag.texte) do
            werte[i] = i - 1        -- Auswahltexte bilden 0..n-1 ab
            texte[i] = t(schluessel)
        end
        return werte, texte
    end

    local meta = FGSettings.getMeta(eintrag.key)
    local min  = 0.25
    local max  = 2.50
    local step = 0.05
    if meta ~= nil then
        min  = meta.min  or min
        max  = meta.max  or max
        step = meta.step or step
    end

    local werte, texte = {}, {}
    local wert = min

    -- Das #werte < 200 ist nur eine Bremse gegen versehentlich riesige Listen.
    while wert <= max + step * 0.001 and #werte < 200 do
        local w = rundeAuf(wert, step)
        table.insert(werte, w)
        if math.abs(w - 1.0) < 0.001 then
            table.insert(texte, string.format("x%.2f  %s", w, t("fg_opt_serienwert")))
        else
            table.insert(texte, string.format("x%.2f", w))
        end
        wert = wert + step
    end

    return werte, texte
end

function FGSettingsPage.getZiel(eintrag)
    if eintrag.bereich == "eigen" then
        return FahrGefuehl.EIGEN
    end
    return FahrGefuehl.CFG
end

function FGSettingsPage.getWert(eintrag)
    return FGSettingsPage.getZiel(eintrag)[eintrag.key]
end

function FGSettingsPage.findeIndex(werte, aktuell)
    if aktuell == nil then
        return 1
    end

    if type(aktuell) == "boolean" then
        if aktuell then
            return 2
        end
        return 1
    end

    local besterIndex, besteDistanz = 1, nil
    for i, w in ipairs(werte) do
        if type(w) == "number" then
            local d = math.abs(w - aktuell)
            if besteDistanz == nil or d < besteDistanz then
                besteDistanz = d
                besterIndex  = i
            end
        end
    end
    return besterIndex
end

-- Geht ueber FGSettings, damit Regler und Konsolenbefehl denselben Weg nehmen.
-- Danach die ganze Seite auffrischen: eine Voreinstellung aendert alle anderen
-- Zeilen mit, eine einzelne Verstellung die Zeile ganz oben.
function FGSettingsPage.setzeWert(eintrag, neu)
    if eintrag.bereich == "eigen" then
        FGSettings.setzeEigenWert(eintrag.key, neu)
    else
        FGSettings.setzeWert(eintrag.key, neu)
    end

    if g_FGMenuPage ~= nil and g_FGMenuPage.populate ~= nil then
        g_FGMenuPage:populate()
    end
end
