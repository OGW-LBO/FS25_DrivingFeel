--
-- FGMenuPage - eigener Unter-Tab "Fahr-Gefuehl" unter ESC -> Allgemeine
-- Einstellungen.
--
-- Der Tab wird in settingsFrame.subCategoryPages und .subCategoryBox
-- eingehaengt, die Zeilen aus den Prefabs in gui/FGMenu.xml geklont.
--

FGMenuPage = {}

local FGMenuPage_mt = Class(FGMenuPage, FrameElement)
local modDirectory  = g_currentModDirectory

-- Die GUI-Callbacks brauchen eine globale Referenz.
g_FGMenuPage = nil

function FGMenuPage.new()
    local self = FrameElement.new(nil, FGMenuPage_mt)
    self.controls  = {}
    self.injiziert = false
    return self
end

local function t(key)
    if FGSettingsPage ~= nil and FGSettingsPage.getText ~= nil then
        return FGSettingsPage.getText(key)
    end
    return key or ""
end

-- Eigene Werte darf jeder verstellen, die Server-Vorgabe nur der Host oder ein
-- Admin. Der Server prueft das beim Empfang noch einmal; hier wird nur vorab
-- gesperrt, damit niemand ins Leere klickt und sich wundert, warum der Regler
-- zurueckspringt.
function FGMenuPage.darfAendern(eintrag)
    if eintrag ~= nil and eintrag.bereich == "eigen" then
        return true
    end
    if g_currentMission == nil then
        return true
    end
    if g_currentMission.getIsServer ~= nil and g_currentMission:getIsServer() then
        return true
    end
    return g_currentMission.isMasterUser == true
end

-- paging.state ist der laufende Index in der Auswahlliste, nicht die
-- Seitennummer. Sobald Unter-Kategorien ausgeblendet sind oder weitere Mods
-- eigene Tabs anhaengen, laufen beide auseinander.
function FGMenuPage.istUnserTab(sf)
    if sf == nil or InGameMenuSettingsFrame == nil then
        return false
    end

    local ziel = nil
    if InGameMenuSettingsFrame.SUB_CATEGORY ~= nil then
        ziel = InGameMenuSettingsFrame.SUB_CATEGORY.FAHR_GEFUEHL
    end

    local paging = sf.subCategoryPaging
    if ziel == nil or paging == nil then
        return false
    end

    if paging.texts ~= nil and paging.texts[paging.state] ~= nil then
        return tonumber(paging.texts[paging.state]) == ziel
    end
    return paging.state == ziel
end


-- Aufbau -------------------------------------------------------------------

function FGMenuPage:registerAndInject()
    if self.injiziert then
        return
    end

    if g_gui == nil or g_gui.loadGui == nil or FrameElement == nil then
        return
    end

    local settingsFrame = nil
    if g_inGameMenu ~= nil then
        settingsFrame = g_inGameMenu.pageSettings
    end
    if settingsFrame == nil or settingsFrame.subCategoryPages == nil
            or settingsFrame.subCategoryBox == nil then
        return
    end

    g_gui:loadGui(Utils.getFilename("gui/FGMenu.xml", modDirectory), "FGMenuPage", self)

    local seite = self.fgPage
    local tab   = self.fgTab
    if seite == nil or tab == nil then
        Logging.warning(FahrGefuehl.LOG .. "fgPage/fgTab nicht gefunden (GUI-XML fehlerhaft?).")
        return
    end

    -- Beschriftung nochmal setzen: das $l10n_ im XML loest je nach
    -- Ladezeitpunkt zu frueh auf.
    if tab.setText ~= nil then
        tab:setText(t("fg_tabTitle"))
    end

    -- Prefabs sind nur Klonvorlagen.
    if self.fgSectionPrefab ~= nil then self.fgSectionPrefab:setVisible(false) end
    if self.fgRowPrefab     ~= nil then self.fgRowPrefab:setVisible(false)     end

    -- Abwechselnde Zeilenhintergruende wie im Basisspiel.
    local function updateAlternating(layout)
        if layout == nil or layout.elements == nil or InGameMenuSettingsFrame == nil then
            return
        end
        local farben = InGameMenuSettingsFrame.COLOR_ALTERNATING
        if farben == nil then
            return
        end
        local wechsel = true
        for _, container in ipairs(layout.elements) do
            if container.name == "sectionHeader" then
                wechsel = true
            elseif container.setImageColor ~= nil
                    and (container.getIsVisibleNonRec == nil or container:getIsVisibleNonRec()) then
                container:setImageColor(nil, unpack(farben[wechsel]))
                wechsel = not wechsel
            end
        end
        if layout.invalidateLayout ~= nil then
            layout:invalidateLayout()
        end
    end
    self._updateAlternating = updateAlternating

    self:baueZeilen()

    -- Den Frame-Namen braucht der FocusManager auf dem Zielobjekt.
    self.name = settingsFrame.name

    -- Prefabs weg, sonst stehen sie als leere Zeilen in der Liste.
    if self.fgRowPrefab ~= nil then
        self.fgRowPrefab:delete()
        self.fgRowPrefab = nil
    end
    if self.fgSectionPrefab ~= nil then
        self.fgSectionPrefab:delete()
        self.fgSectionPrefab = nil
    end

    updateAlternating(self.fgLayout)

    -- Tab hinten an die vorhandenen Unter-Kategorien haengen.
    local position = #settingsFrame.subCategoryPages + 1

    local function einfuegen(element, ziel, pos)
        if element.parent ~= nil then
            element.parent:removeElement(element)
        end
        table.insert(ziel.elements, pos, element)
        element.parent = ziel
    end

    einfuegen(seite, settingsFrame.subCategoryPages[1].parent, position)
    einfuegen(tab,   settingsFrame.subCategoryBox,             position)

    table.insert(settingsFrame.subCategoryPages, position, seite)
    table.insert(settingsFrame.subCategoryTabs,  position, tab)

    InGameMenuSettingsFrame.SUB_CATEGORY.FAHR_GEFUEHL = position

    -- HEADER_SLICES geht an OverlayManager:createOverlay, das den Identifier an
    -- seinem ersten Punkt zerlegt. Ein leerer String ergibt dort die Warnung
    -- "Identifier '' does not contain prefix or slice ID", sobald der Tab
    -- aufgeht - deshalb das Symbol eines vorhandenen Tabs uebernehmen.
    local slices = InGameMenuSettingsFrame.HEADER_SLICES
    local slice  = ""
    for _, vorhanden in ipairs(slices) do
        if type(vorhanden) == "string" and string.find(vorhanden, ".", 1, true) ~= nil then
            slice = vorhanden
            break
        end
    end
    table.insert(slices, position, slice)

    -- HEADER_TITLES loest der Frame ueber g_i18n:getText auf, ohne
    -- Mod-Umgebung, und das in jedem Frame, in dem die Seite offen ist. Ein
    -- eigener Schluessel ergibt dort fortlaufend "DevWarning: Missing ... in
    -- l10n_de.xml". Also der Schluessel eines Basisspiel-Tabs; sichtbar wird er
    -- nie, weil der update-Hook weiter unten die Kopfzeile selbst schreibt.
    local titles = InGameMenuSettingsFrame.HEADER_TITLES
    local titel  = "fg_tabTitle"
    for _, vorhanden in ipairs(titles) do
        if type(vorhanden) == "string" and vorhanden ~= "" then
            titel = vorhanden
            break
        end
    end
    table.insert(titles, position, titel)

    settingsFrame:updateAbsolutePosition()

    -- Tastatur- und Controller-Navigation.
    local aktuelleGui    = FocusManager.currentGui
    local getDescendants = settingsFrame.getDescendants

    settingsFrame.getDescendants = function() return seite:getDescendants() end
    settingsFrame:exposeControlsAsFields(settingsFrame.name)
    settingsFrame.getDescendants = getDescendants

    seite:setTarget(settingsFrame, seite.target)
    tab:setTarget(settingsFrame,   tab.target)

    FocusManager:setGui(settingsFrame.name)
    FocusManager:removeElement(seite)
    FocusManager:removeElement(tab)
    FocusManager:loadElementFromCustomValues(seite)
    FocusManager:loadElementFromCustomValues(tab)
    FocusManager:setGui(aktuelleGui)

    local selbst = self

    -- Beim Oeffnen auffrischen, der Server kann die Werte zwischenzeitlich
    -- geaendert haben.
    settingsFrame.onFrameOpen = Utils.appendedFunction(
        settingsFrame.onFrameOpen,
        function()
            selbst:populate()
            if selbst.fgLayout ~= nil and selbst.fgLayout.invalidateLayout ~= nil then
                selbst.fgLayout:invalidateLayout()
            end
        end)

    -- Der Frame setzt die Kopfzeile jeden Frame neu aus HEADER_TITLES.
    -- Solange unser Tab aktiv ist, schreiben wir sie selbst.
    settingsFrame.update = Utils.appendedFunction(
        settingsFrame.update,
        function(sf)
            if FGMenuPage.istUnserTab(sf) and sf.categoryHeaderText ~= nil
                    and sf.categoryHeaderText.setText ~= nil then
                sf.categoryHeaderText:setText(t("fg_tabTitle"))
            end
        end)

    -- Tabwechsel per Paging: Kopfzeile setzen und Werte auffrischen.
    if settingsFrame.subCategoryPaging ~= nil then
        settingsFrame.subCategoryPaging.onClickCallback = Utils.overwrittenFunction(
            settingsFrame.subCategoryPaging.onClickCallback,
            function(pagingElem, superFunc, state)
                local ret = superFunc(pagingElem, state)
                local wert = nil
                if pagingElem.texts ~= nil then
                    wert = pagingElem.texts[state]
                end
                if wert ~= nil and tonumber(wert) == InGameMenuSettingsFrame.SUB_CATEGORY.FAHR_GEFUEHL then
                    selbst:onTabOpen(settingsFrame)
                end
                return ret
            end)
    end

    self.injiziert = true
    Logging.info(FahrGefuehl.LOG .. "Eigener Einstellungs-Tab eingefuegt (Position %d, %d Regler).",
        position, #self.controls)
end


-- Zeilen erzeugen ----------------------------------------------------------

function FGMenuPage:baueZeilen()
    if FGSettingsPage == nil or self.fgRowPrefab == nil or self.fgLayout == nil then
        Logging.warning(FahrGefuehl.LOG .. "Vorlagen fehlen - keine Regler erstellt.")
        return
    end

    local selbst = self
    local nummer = 0

    local function abschnitt(titelKey)
        local prefab = selbst.fgSectionPrefab
        if prefab == nil then
            return
        end
        local kopf = prefab:clone(selbst.fgLayout)
        if kopf == nil then
            return
        end
        kopf:setVisible(true)
        kopf:setText(t(titelKey))
        kopf.focusId = FocusManager:serveAutoFocusId()
    end

    local function zeile(eintrag)
        if FGSettingsPage.getZiel(eintrag)[eintrag.key] == nil then
            return
        end

        local box = selbst.fgRowPrefab:clone(selbst.fgLayout)
        if box == nil then
            return
        end

        nummer = nummer + 1
        box:setVisible(true)
        FGUIHelper.updateFocusIds(box)

        local id           = string.format("FG_%d", nummer)
        local callbackName = string.format("FG_onChange_%d", nummer)
        box.id = id .. "Box"

        local werte, texte = FGSettingsPage.baueWerte(eintrag)

        local option = box.elements[1]
        if option ~= nil then
            option.id               = id
            option.focusOnHighlight = true
            option.target           = selbst

            -- Callback direkt als Funktion, nicht ueber setCallback mit Namen:
            -- GuiElement:raiseCallback ruft schlicht self[name](self.target,
            -- ...) und erwartet in onClickCallback also eine Funktion. Mit dem
            -- Namens-Umweg bleiben die Regler wirkungslos.
            option.onClickCallback = function(_, newState)
                local ziel = selbst[callbackName]
                if ziel ~= nil then
                    ziel(selbst, newState)
                end
            end

            option:setDisabled(not FGMenuPage.darfAendern(eintrag))

            -- Tipp-Zeile unter der Option.
            if option.elements ~= nil and option.elements[1] ~= nil
                    and option.elements[1].setText ~= nil then
                option.elements[1]:setText(t(eintrag.tipp))
            end

            if option.setTexts ~= nil then
                option:setTexts(texte)
            end
            if option.setState ~= nil then
                option:setState(FGSettingsPage.findeIndex(werte, FGSettingsPage.getWert(eintrag)))
            end
        end

        local beschriftung = box.elements[2]
        if beschriftung ~= nil then
            beschriftung:setVisible(true)
            beschriftung:setText(t(eintrag.label))
        end

        local gemerkterEintrag = eintrag
        local gemerkteWerte    = werte
        selbst[callbackName] = function(_, newState)
            local neu = gemerkteWerte[newState]
            if neu == nil then
                return
            end
            FGSettingsPage.setzeWert(gemerkterEintrag, neu)
        end

        box.fgEintrag = eintrag
        box.fgWerte   = werte
        table.insert(selbst.controls, box)
    end

    for _, gruppe in ipairs(FGSettingsPage.baueAbschnitte()) do
        abschnitt(gruppe.titel)
        for _, eintrag in ipairs(gruppe.eintraege) do
            zeile(eintrag)
        end
    end
end


-- Auffrischen --------------------------------------------------------------

function FGMenuPage:populate()
    -- Der Admin-Status kann sich mitten im Spiel aendern, deshalb wird er hier
    -- jedes Mal neu abgefragt.
    for _, box in ipairs(self.controls) do
        local eintrag = box.fgEintrag
        local option  = nil
        if box.elements ~= nil then
            option = box.elements[1]
        end

        if eintrag ~= nil and option ~= nil then
            if option.setState ~= nil then
                option:setState(
                    FGSettingsPage.findeIndex(box.fgWerte, FGSettingsPage.getWert(eintrag)))
            end
            if option.setDisabled ~= nil then
                option:setDisabled(not FGMenuPage.darfAendern(eintrag))
            end
        end
    end
end

function FGMenuPage:onTabOpen(settingsFrame)
    if settingsFrame ~= nil then
        settingsFrame:updateAbsolutePosition()
        if settingsFrame.categoryHeaderText ~= nil
                and settingsFrame.categoryHeaderText.setText ~= nil then
            settingsFrame.categoryHeaderText:setText(t("fg_tabTitle"))
        end
    end

    self:populate()

    if self.fgLayout ~= nil and self.fgLayout.invalidateLayout ~= nil then
        self.fgLayout:invalidateLayout()
    end
    if self._updateAlternating ~= nil then
        self._updateAlternating(self.fgLayout)
    end
end

function FGMenuPage:onClickFgTab()
    local seite = g_FGMenuPage
    if seite == nil or g_inGameMenu == nil then
        return
    end

    local sf = g_inGameMenu.pageSettings
    if sf == nil or sf.subCategoryPaging == nil or InGameMenuSettingsFrame == nil
            or InGameMenuSettingsFrame.SUB_CATEGORY == nil then
        return
    end

    -- setState will den Paging-State, nicht die Seitennummer.
    local ziel   = InGameMenuSettingsFrame.SUB_CATEGORY.FAHR_GEFUEHL
    local state  = ziel
    local paging = sf.subCategoryPaging
    if paging.texts ~= nil then
        for st, txt in ipairs(paging.texts) do
            if tonumber(txt) == ziel then
                state = st
                break
            end
        end
    end

    paging:setState(state, true)
    seite:onTabOpen(sf)
end
