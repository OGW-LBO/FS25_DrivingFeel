--
-- FGUIHelper - kleine GUI-Bausteine
--

FGUIHelper = {}

-- Geklonte Elemente behalten sonst die FocusId ihrer Vorlage, und der
-- FocusManager verliert damit die Navigation per Tastatur und Controller.
function FGUIHelper.updateFocusIds(element)
    if element == nil then
        return
    end
    element.focusId = FocusManager:serveAutoFocusId()
    if element.elements then
        for _, child in ipairs(element.elements) do
            FGUIHelper.updateFocusIds(child)
        end
    end
end
