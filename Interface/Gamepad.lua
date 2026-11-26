local _, private = ...
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

local activeInput, listInput, guideInput
local refreshProfessionShortcut
local professionTab, focusWatcher
local disconnected
local BACK_BUTTON = _G.GAMEPAD_FACE_RIGHT or "PAD2"
local function IgnoreButton() end

local function CanNavigate()
    return private.addonEnabled ~= false and not disconnected and _G.InputUtil.IsGamepadUIEnabled()
        and _G.C_GamePad.IsEnabled() and not _G.InCombatLockdown()
end

local function NativeFocusedFrame()
    local manager = _G.GamepadMode and _G.GamepadMode.FrameControlsManager
    return manager and manager.GetActiveFrame and manager:GetActiveFrame()
end

local function OtherPanelHasFocus()
    local frame = NativeFocusedFrame()
    return frame and frame ~= _G.ProfessionsFrame
end

local function HasBlockingDialog()
    if _G.GameMenuFrame and _G.GameMenuFrame:IsVisible() then return true end
    for index = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
        local dialog = _G["StaticPopup" .. index]
        if dialog and dialog:IsVisible() then return true end
    end
    return false
end

local function InputIsBlocked()
    if not CanNavigate() or OtherPanelHasFocus() or HasBlockingDialog() then return true end
    local manager = _G.Menu and _G.Menu.GetManager and _G.Menu.GetManager()
    return manager and manager:GetOpenMenu() ~= nil
end

local function KeyboardFocus()
    return _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()
end

local function RefreshActiveInput()
    if refreshProfessionShortcut then refreshProfessionShortcut() end
    local guideVisible = guideInput and guideInput:GetParent():IsVisible()
    local listVisible = listInput and listInput:GetParent():IsVisible()
    local tabVisible = professionTab and professionTab:IsVisible()
    if focusWatcher then
        focusWatcher:SetShown(not not ((guideVisible or listVisible or tabVisible) and CanNavigate()))
    end
    local input
    if (guideVisible or listVisible) and not InputIsBlocked() then
        input = guideVisible and guideInput or listInput
    end
    if activeInput == input then return end
    local oldInput = activeInput
    activeInput = input
    if oldInput then oldInput:Hide() end
    if input then
        input:EnableGamePadButton(true)
        if input.hasStick then input:EnableGamePadStick(true) end
        input:Show()
    end
end

local function TrackNativeFocus()
    if focusWatcher then return end
    -- Observe focus outside Blizzard's callbacks, only while one of our controls is visible.
    focusWatcher = _G.CreateFrame("Frame")
    focusWatcher:Hide()
    local elapsed = 0
    focusWatcher:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.08 then return end
        elapsed = 0
        RefreshActiveInput()
    end)
end

local function RegisterGamepadEvents(frame)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
    frame:RegisterEvent("GAME_PAD_CONNECTED")
    frame:RegisterEvent("GAME_PAD_DISCONNECTED")
    frame:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
    frame:SetScript("OnEvent", function(_, event, isActive)
        if event == "GAME_PAD_DISCONNECTED" then
            disconnected = _G.C_GamePad.GetAllDeviceIDs == nil or #_G.C_GamePad.GetAllDeviceIDs() == 0
        elseif event == "GAME_PAD_CONNECTED" or (event == "GAME_PAD_ACTIVE_CHANGED" and isActive) then
            disconnected = false
        end
        RefreshActiveInput()
    end)
end

local function CreateInput(panel, actions, onModeChanged, scroll, more)
    if not (_G.InputUtil and _G.InputUtil.IsGamepadUIEnabled and _G.C_GamePad
        and _G.C_GamePad.IsEnabled and panel.EnableGamePadButton) then return end

    local input = _G.CreateFrame("Frame", nil, panel)
    input:Hide()

    local pressed = {}
    local function CanHandle()
        return activeInput == input and not InputIsBlocked()
    end
    local function ExitSearch()
        local searchBox = panel.search_editbox
        local onEscape = searchBox:GetScript("OnEscapePressed")
        if onEscape then onEscape(searchBox) else searchBox:ClearFocus() end
    end
    local function GetButtonAction(key)
        if not CanHandle() then return end
        local focus = KeyboardFocus()
        if focus then
            if focus == panel.search_editbox and key == BACK_BUTTON then return ExitSearch end
            return
        end
        if more and more:IsShown() then return more.actions[key] or (actions[key] and IgnoreButton) end
        return actions[key]
    end

    -- Keep the action from key-down so a focus change cannot turn search Back into window Back.
    input:SetScript("OnGamePadButtonDown", function(_, key)
        pressed[key] = GetButtonAction(key)
        return not pressed[key]
    end)
    input:SetScript("OnGamePadButtonUp", function(_, key)
        local action = pressed[key]
        pressed[key] = nil
        if not action then return true end
        if action == GetButtonAction(key) then action() end
        return false
    end)
    local scrollDirection, scrollElapsed
    if scroll and input.EnableGamePadStick then
        input:SetScript("OnGamePadStick", function(self, stick, _, y)
            if (stick ~= "Right" and stick ~= "Camera") or not CanHandle() or KeyboardFocus() then return true end
            local direction = y > 0.55 and -1 or y < -0.55 and 1 or nil
            if direction ~= scrollDirection then
                scrollDirection = direction
                scrollElapsed = 0.15
                self:SetScript("OnUpdate", direction and function(frame, elapsed)
                    if not CanHandle() or KeyboardFocus() then
                        scrollDirection = nil
                        frame:SetScript("OnUpdate", nil)
                        return
                    end
                    scrollElapsed = scrollElapsed + elapsed
                    if scrollElapsed >= 0.12 then
                        scrollElapsed = 0
                        if more and more:IsShown() then
                            more:MoveSelection(scrollDirection)
                        else
                            scroll(scrollDirection)
                        end
                    end
                end or nil)
            end
            return false
        end)
    end
    input:SetScript("OnShow", function() onModeChanged(true) end)
    input:SetScript("OnHide", function()
        for key in pairs(pressed) do pressed[key] = nil end
        scrollDirection = nil
        input:SetScript("OnUpdate", nil)
        if more then more:Hide() end
        onModeChanged(false)
    end)
    RegisterGamepadEvents(input)
    panel:HookScript("OnShow", RefreshActiveInput)
    panel:HookScript("OnHide", RefreshActiveInput)
    input.hasStick = scroll and input.EnableGamePadStick ~= nil
    TrackNativeFocus()
    return input
end

local function CreateLegend(panel, yOffset, commands, parentKey)
    local legends, utility = _G.InputPromptLegends, _G.GamepadSharedUtility
    if not (legends and legends.CreateInputLegend and utility and utility.CreateExtensiblePromptedBinding) then return end

    -- Use only Blizzard's graphics. The controls remain scoped to Ackis's input frame.
    local legend = legends.CreateInputLegend(panel, parentKey or "AckisGamepadLegend")
    legend:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, yOffset)
    legend:SetLegendWidth(panel.normal_width or panel:GetWidth())
    local prompts = {}
    for _, command in ipairs(commands) do
        if command[1] then
            local prompt = utility.CreateExtensiblePromptedBinding(command[1], "AckisGamepadPrompt")
            prompt:AddFooterBinding({ label = command[2] })
            prompts[#prompts + 1] = prompt
        end
    end
    legend:RefreshWithPromptedBindings(prompts)
    return legend
end

local function CreateMoreMenu(panel, onVisibilityChanged)
    local menu = _G.CreateFrame("Frame", nil, panel, "TooltipBackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -28)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    local rows, entries = {}, {}
    local selected, first = 1, 1
    local maxRows, rowHeight = 8, 24
    local legend

    local function Select(index)
        local entry = entries[index]
        if not entry then return end
        menu:Hide()
        entry.action(entry.data)
    end

    local function Render()
        local count = math.min(#entries, maxRows)
        menu:SetHeight(count * rowHeight + 14)
        for index = 1, count do
            local row = rows[index]
            if not row then
                row = _G.CreateFrame("Button", nil, menu)
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", 8, -7 - (index - 1) * rowHeight)
                row:SetPoint("RIGHT", menu, "RIGHT", -8, 0)
                row:SetNormalFontObject("GameFontHighlight")
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "ADD")
                local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                label:SetPoint("LEFT", 6, 0)
                label:SetPoint("RIGHT", -6, 0)
                label:SetJustifyH("LEFT")
                label:SetWordWrap(false)
                row:SetFontString(label)
                row:SetScript("OnClick", function(self) Select(self.entryIndex) end)
                rows[index] = row
            end
            row.entryIndex = first + index - 1
            local entry = entries[row.entryIndex]
            local checked = entry.isSelected and entry.isSelected(entry.data)
            row:SetText(checked and "|cffffd200" .. entry.text .. "|r" or entry.text)
            row:SetHighlightLocked(row.entryIndex == selected)
            row:Show()
        end
        for index = count + 1, #rows do rows[index]:Hide() end
    end

    function menu:Open(items, back)
        if #items == 0 then return end
        entries, selected, first = items, 1, 1
        self.back = back
        local width = 160
        self:SetWidth(width)
        Render()
        for slot = 1, math.min(#items, maxRows) do
            width = math.max(width, rows[slot]:GetFontString():GetUnboundedStringWidth() + 30)
        end
        self:SetWidth(math.min(panel:GetWidth() - 24, width))
        if not legend then
            legend = CreateLegend(self, 0, {
                { _G.GAMEPAD_FACE_BOTTOM, _G.ACTION_LABEL_SELECT },
                { _G.GAMEPAD_FACE_RIGHT, _G.FRAME_ACTION_BACK },
            }, "AckisMoreGamepadLegend")
        end
        self:Show()
    end

    function menu:MoveSelection(direction)
        selected = math.max(1, math.min(#entries, selected + direction))
        first = math.max(selected - maxRows + 1, math.min(first, selected))
        Render()
    end

    menu.actions = {
        [_G.GAMEPAD_DPAD_TOP or "PADDUP"] = function() menu:MoveSelection(-1) end,
        [_G.GAMEPAD_DPAD_BOTTOM or "PADDDOWN"] = function() menu:MoveSelection(1) end,
        [_G.GAMEPAD_FACE_BOTTOM or "PAD1"] = function() Select(selected) end,
        [_G.GAMEPAD_FACE_TOP or "PAD4"] = function() menu:Hide() end,
        [BACK_BUTTON] = function()
            if menu.back then menu.back() else menu:Hide() end
        end,
    }
    menu:SetScript("OnShow", function() onVisibilityChanged(true) end)
    menu:SetScript("OnHide", function()
        entries = {}
        menu.back = nil
        onVisibilityChanged(false)
    end)
    return menu
end

local function CreateInputIcon(panel, key, point, relative, relativePoint, offsetX, offsetY)
    if not (_G.InputIconTextureMixin and key) then return end
    local icon = _G.CreateFrame("Frame", nil, panel, "InputIconTextureFrameTemplate")
    icon:SetSize(18, 18)
    icon:SetInputKey(key)
    icon:SetPoint(point, relative, relativePoint, offsetX, offsetY or 0)
    return icon
end

function private.InitializeGamepadProfessionTab(tab, openAckis)
    if not (_G.InputUtil and _G.InputUtil.IsGamepadUIEnabled and _G.C_GamePad
        and _G.C_GamePad.IsEnabled and _G.RegisterStateDriver) then return end

    local key = _G.GAMEPAD_STICK_LEFT_PRESS or "PADLSTICK"
    local buttonName = "AckisRecipeListProfessionGamepadClick"
    local target = _G.CreateFrame("Button", buttonName, _G.UIParent)
    target:RegisterForClicks("LeftButtonUp")
    local function IsAvailable()
        local professions = _G.ProfessionsFrame
        return private.addonEnabled ~= false and tab:IsVisible() and professions and professions:IsVisible()
            and NativeFocusedFrame() == _G.ProfessionsFrame and not InputIsBlocked() and not KeyboardFocus()
            and not (listInput and listInput:GetParent():IsVisible())
            and not (guideInput and guideInput:GetParent():IsVisible())
    end
    target:SetScript("OnClick", function()
        if IsAvailable() then openAckis() end
    end)

    -- Bind only L3. A frame that listens for gamepad buttons can preempt Blizzard's tab navigation.
    local binding = _G.CreateFrame("Frame", nil, _G.UIParent, "SecureHandlerStateTemplate")
    binding:SetAttribute("arl-key", key)
    binding:SetAttribute("arl-target", buttonName)
    binding:SetAttribute("_onstate-arlshortcut", [[
        if newstate == "on" and self:GetAttribute("state-arlcombat") ~= "combat" then
            self:SetBindingClick(true, self:GetAttribute("arl-key"), self:GetAttribute("arl-target"), "LeftButton")
        else
            self:ClearBindings()
        end
    ]])
    binding:SetAttribute("_onstate-arlcombat", [[
        if newstate == "combat" then
            self:ClearBindings()
            self:SetAttribute("state-arlshortcut", "off")
        end
    ]])
    _G.RegisterStateDriver(binding, "arlcombat", "[combat] combat; safe")
    local icon, bindingRefreshPending
    refreshProfessionShortcut = function()
        local enabled = IsAvailable()
        local state = enabled and "on" or "off"
        if not _G.InCombatLockdown() and not bindingRefreshPending and binding:GetAttribute("state-arlshortcut") ~= state then
            bindingRefreshPending = true
            _G.C_Timer.After(0, function()
                bindingRefreshPending = nil
                if not _G.InCombatLockdown() then
                    binding:SetAttribute("state-arlshortcut", IsAvailable() and "on" or "off")
                end
            end)
        end
        if enabled and not icon then
            icon = CreateInputIcon(tab, key, "LEFT", tab, "RIGHT", 4)
            if icon then icon:SetSize(22, 22) end
        end
        if icon then icon:SetShown(enabled) end
    end
    RegisterGamepadEvents(binding)
    professionTab = tab
    TrackNativeFocus()
    tab:HookScript("OnShow", RefreshActiveInput)
    tab:HookScript("OnHide", RefreshActiveInput)
    RefreshActiveInput()
end

local function CreateScrollHint(scrollBar, input)
    if not (input.hasStick and _G.GamepadScrollBarHint) then return end
    local hint = _G.CreateFrame("Frame", nil, scrollBar, "GamepadScrollBarHintTemplate")
    hint:SetOwner(scrollBar.Track.Thumb, "CENTER")
    return hint
end

function private.InitializeGamepadList(panel)
    local list = panel.list_frame
    local focus, legend, filterLegend, focusedWidget, focusedRow, focusedIndex, tab, profession
    local searchIcon, filterIcon, previousTabIcon, nextTabIcon, scrollHint
    local filtersActive, filterControl
    local detailsHidden, productPreview
    local more

    local function InFilters()
        if filtersActive and not panel.filter_menu:IsVisible() then
            filtersActive, filterControl = nil, nil
        end
        return filtersActive
    end

    local function ChangeFilterCategory(direction)
        local categories = panel.filter_menu.gamepadCategories
        local current = 0
        for index, button in ipairs(categories) do
            if button:GetChecked() then
                current = index
                break
            end
        end
        for step = 1, #categories do
            local index = (current - 1 + step * direction) % #categories + 1
            local button = categories[index]
            if button:IsVisible() and button:IsEnabled() and not button:GetChecked() then
                filterControl = nil
                button:GetScript("OnClick")(button, "LeftButton", false)
                list:UpdateGamepadFocus()
                return
            end
        end
    end

    local function MoveFilterControl(direction)
        local controls = panel.filter_menu:GetGamepadControls()
        for index, control in ipairs(controls) do
            if control == filterControl then
                filterControl = controls[math.max(1, math.min(#controls, index + direction))]
                list:UpdateGamepadFocus()
                return
            end
        end
        list:UpdateGamepadFocus()
    end

    local function ActivateFilterControl()
        local control = filterControl
        if not (control and control:IsVisible() and control:IsEnabled()) then return end
        if control:IsObjectType("CheckButton") then control:SetChecked(not control:GetChecked()) end
        control:GetScript("OnClick")(control, "LeftButton", false)
        list:UpdateGamepadFocus()
    end

    local function CloseFilters()
        filtersActive, filterControl = nil, nil
        if panel.is_expanded then panel:ToggleState() end
        list:UpdateGamepadFocus()
    end

    local function MoveRow(direction, page)
        local index = focusedIndex + direction * (page and (list.visibleLines or 15) or 1)
        -- The list recycles buttons, so navigate the entries and resolve the visible button after scrolling.
        index = math.max(1, math.min(#list.entries, index))
        while list.entries[index] and list.entries[index]:IsTitle() do
            index = index + direction
        end
        if not list.entries[index] or index == focusedIndex then return end

        detailsHidden = nil
        focusedIndex = index
        for _, row in ipairs(list.ListEntryButtons) do
            if row.entry_index == index and row:IsVisible() then
                list:UpdateGamepadFocus()
                return
            end
        end
        local _, lastOffset = list.scroll_bar:GetMinMaxValues()
        panel.current_tab:SetScrollValue(private.CurrentProfession, math.min(index - 1, lastOffset))
        list:Update(nil, true)
    end

    local function MoveTab(direction)
        local tabs = panel.tabs
        local index = panel.current_tab:GetID()
        for offset = 1, #tabs - 1 do
            local candidate = tabs[(index - 1 + offset * direction) % #tabs + 1]
            if candidate:IsVisible() and not candidate:IsForceDisabled() then
                detailsHidden, productPreview = nil, nil
                candidate:GetScript("OnClick")(candidate, "LeftButton", false)
                return
            end
        end
    end

    local function ScrollRows(direction)
        if InFilters() then
            MoveFilterControl(direction)
        elseif focusedRow then
            MoveRow(direction)
        end
    end

    local function OpenFilters(back)
        if panel.guide_selector and panel.guide_selector:IsVisible() then
            more:Open(panel.guide_selector.GetAckisChoices(), back)
        elseif panel.filter_menu and panel:IsVisible() then
            if InFilters() then
                CloseFilters()
                return
            end
            if not panel.is_expanded then panel:ToggleState() end
            filtersActive = true
            if not panel.filter_menu:IsVisible() then ChangeFilterCategory(1) end
            list:HideGamepadDetails()
            RefreshActiveInput()
            list:UpdateGamepadFocus()
        end
    end

    local function OpenActions()
        if InFilters() then return end
        local entries = {
            { text = _G.SEARCH, action = function() panel.search_editbox:SetFocus() end },
        }
        if panel.guide_selector and panel.guide_selector:IsVisible() then
            entries[#entries + 1] = {
                text = L["Select guide"],
                action = function() OpenFilters(OpenActions) end,
            }
        elseif panel.filter_menu then
            entries[#entries + 1] = { text = _G.FILTER, action = OpenFilters }
        end
        if panel.expand_button:IsEnabled() then
            entries[#entries + 1] = {
                text = _G.ALL,
                action = function()
                    panel.expand_button:GetScript("OnClick")(panel.expand_button, "LeftButton", false)
                end,
            }
        end
        more:Open(entries)
    end

    local function MoveHorizontal(direction, changeTab)
        if InFilters() then
            ChangeFilterCategory(direction)
        elseif changeTab and panel.current_tab then
            MoveTab(direction)
        elseif not changeTab and focusedRow then
            MoveRow(direction, true)
        end
    end

    local function Highlight(widget)
        focusedWidget = widget
        widget:SetHighlightLocked(true)
        if not focus and _G.SmartNavigation then
            focus = _G.CreateFrame("Frame", nil, panel, "SmartNavigationPointerTemplate")
        end
        if focus then
            focus:ClearAllPoints()
            focus:SetPoint("RIGHT", widget, "LEFT", 10, 0)
            focus:Show()
        end
    end

    more = CreateMoreMenu(panel, function(showing)
        if showing then productPreview = nil end
        list:UpdateGamepadFocus()
    end)
    listInput = CreateInput(panel, {
        [_G.GAMEPAD_DPAD_TOP or "PADDUP"] = function() ScrollRows(-1) end,
        [_G.GAMEPAD_DPAD_BOTTOM or "PADDDOWN"] = function() ScrollRows(1) end,
        [_G.GAMEPAD_DPAD_LEFT or "PADDLEFT"] = function() MoveHorizontal(-1) end,
        [_G.GAMEPAD_DPAD_RIGHT or "PADDRIGHT"] = function() MoveHorizontal(1) end,
        [_G.GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER"] = function() MoveHorizontal(-1, true) end,
        [_G.GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER"] = function() MoveHorizontal(1, true) end,
        [_G.GAMEPAD_FACE_BOTTOM or "PAD1"] = function()
            if InFilters() then ActivateFilterControl()
            elseif focusedRow then list:ActivateGamepadRow(focusedRow) end
        end,
        [BACK_BUTTON] = function()
            if InFilters() then CloseFilters()
            elseif list:HideGamepadProduct() then productPreview = nil
            elseif list:HideGamepadDetails() then detailsHidden, productPreview = true, nil
            else panel:Hide() end
        end,
        [_G.GAMEPAD_FACE_LEFT or "PAD3"] = function()
            if not focusedRow then return end
            detailsHidden = nil
            local _, shown = list:ShowGamepadDetails(focusedRow, true)
            productPreview = shown
        end,
        [_G.GAMEPAD_FACE_TOP or "PAD4"] = OpenActions,
        [_G.GAMEPAD_STICK_RIGHT_PRESS or "PADRSTICK"] = function()
            if focusedRow then list:LinkGamepadRecipe(focusedRow) end
        end,
        [_G.GAMEPAD_MENU_LEFT or "PADBACK"] = function() panel.search_editbox:SetFocus() end,
        [_G.GAMEPAD_MENU_RIGHT or "PADFORWARD"] = OpenFilters,
    }, function(enabled)
        if enabled and not legend then
            legend = CreateLegend(panel, -30, {
                { _G.GAMEPAD_FACE_BOTTOM, _G.ACTION_LABEL_SELECT },
                { _G.GAMEPAD_FACE_LEFT, L["Crafted item"] },
                { _G.GAMEPAD_FACE_TOP, _G.CONTEXT_ACTION_LABEL_MORE_ACTIONS },
                { _G.GAMEPAD_STICK_RIGHT_PRESS or "PADRSTICK", L["Link in chat"] },
                { _G.GAMEPAD_FACE_RIGHT, _G.FRAME_ACTION_BACK },
            })
        end
        if enabled and not searchIcon then
            searchIcon = CreateInputIcon(panel, _G.GAMEPAD_MENU_LEFT, "RIGHT", panel.search_editbox, "LEFT", -4)
            -- Match the search row's centerline, compensating for the dropdown's lower anchor.
            filterIcon = CreateInputIcon(panel, _G.GAMEPAD_MENU_RIGHT, "LEFT", panel.search_options, "RIGHT", 4, 2)
            previousTabIcon = CreateInputIcon(panel, _G.GAMEPAD_SHOULDER_LEFT, "RIGHT", panel.tabs[1], "LEFT", 0)
            nextTabIcon = CreateInputIcon(panel, _G.GAMEPAD_SHOULDER_RIGHT, "LEFT", panel.tabs[#panel.tabs], "RIGHT", 0)
            scrollHint = CreateScrollHint(list.scroll_bar, listInput)
        end
        if searchIcon then searchIcon:SetShown(enabled) end
        list.gamepadFocus = enabled
        if not enabled then detailsHidden, productPreview = nil, nil end
        list:UpdateGamepadFocus()
    end, function(direction)
        if not productPreview or not list:ScrollGamepadDetails(direction) then ScrollRows(direction) end
    end, more)
    if not listInput then return end
    panel:HookScript("OnHide", function() filtersActive, filterControl = nil, nil end)
    panel.search_editbox:HookScript("OnEditFocusGained", function() list:UpdateGamepadFocus() end)
    panel.search_editbox:HookScript("OnEditFocusLost", function() list:UpdateGamepadFocus() end)

    function list:UpdateGamepadFocus()
        if focusedWidget then focusedWidget:SetHighlightLocked(false) end
        focusedWidget = nil
        focusedRow = nil
        if focus then focus:Hide() end
        local enabled = activeInput == listInput
        local showingMore = enabled and more:IsShown()
        local showingFilters = enabled and InFilters()
        if showingFilters and not filterLegend then
            filterLegend = CreateLegend(panel, -30, {
                { _G.GAMEPAD_FACE_BOTTOM, _G.ACTION_LABEL_SELECT },
                { { _G.GAMEPAD_SHOULDER_LEFT, _G.GAMEPAD_SHOULDER_RIGHT }, L["Filter categories"] },
                { _G.GAMEPAD_FACE_RIGHT, _G.FRAME_ACTION_BACK },
            }, "AckisFilterGamepadLegend")
        end
        local currentLegend = showingFilters and filterLegend or legend
        if legend then legend:SetShown(enabled and not showingMore and currentLegend == legend) end
        if filterLegend then filterLegend:SetShown(showingFilters and true or false) end
        panel:SetGamepadFooterHeight(enabled and currentLegend and currentLegend:GetHeight() or 0)
        if filterIcon then filterIcon:SetShown(enabled and panel.search_options:IsVisible()) end
        if previousTabIcon then previousTabIcon:SetShown(enabled and not showingFilters) end
        if nextTabIcon then nextTabIcon:SetShown(enabled and not showingFilters) end
        if scrollHint then scrollHint:SetShown(enabled and not showingFilters) end
        if not enabled or showingMore then
            self:HideGamepadDetails()
            return
        end
        if showingFilters then
            self:HideGamepadDetails()
            productPreview = nil
            local controls = panel.filter_menu:GetGamepadControls()
            local selected
            for _, control in ipairs(controls) do
                if control == filterControl then
                    selected = control
                    break
                end
            end
            filterControl = selected or controls[1]
            if filterControl then Highlight(filterControl) end
            return
        end
        if tab ~= panel.current_tab or profession ~= private.CurrentProfession then
            focusedIndex = nil
            detailsHidden, productPreview = nil, nil
            tab, profession = panel.current_tab, private.CurrentProfession
        end
        for _, row in ipairs(self.ListEntryButtons) do
            if row.entry_index > 0 and row:IsVisible() and row:IsEnabled() then
                focusedRow = focusedRow or row
                if row.entry_index == focusedIndex then
                    focusedRow = row
                    break
                end
            end
        end
        focusedIndex = focusedRow and focusedRow.entry_index
        if focusedRow then Highlight(focusedRow) end
        if detailsHidden or KeyboardFocus() then
            self:HideGamepadDetails()
        else
            self:ShowGamepadDetails(focusedRow, productPreview)
        end
    end
    RefreshActiveInput()
end

function private.InitializeGamepadGuide(panel, scrollBy, cycleRoute)
    local legend, scrollHint
    local more = CreateMoreMenu(panel, function(showing)
        if legend then legend:SetShown(activeInput == guideInput and not showing) end
    end)
    local function OpenActions()
        local entries = {}
        if panel.complete:IsVisible() then
            entries[#entries + 1] = {
                text = L["Completed"],
                isSelected = function() return panel.complete:GetChecked() end,
                action = function() panel:SetStepCompleted(not panel.complete:GetChecked()) end,
            }
        end
        if panel.follow:IsVisible() then
            entries[#entries + 1] = { text = L["Follow"], action = function() panel:ToggleFollow() end }
        end
        if panel.choice:IsVisible() then
            entries[#entries + 1] = {
                text = L["Select route"],
                action = function() more:Open(panel.choice.GetAckisChoices(), OpenActions) end,
            }
        end
        more:Open(entries)
    end
    guideInput = CreateInput(panel, {
        [_G.GAMEPAD_DPAD_TOP or "PADDUP"] = function() scrollBy(1) end,
        [_G.GAMEPAD_DPAD_BOTTOM or "PADDDOWN"] = function() scrollBy(-1) end,
        [_G.GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER"] = function() cycleRoute(-1) end,
        [_G.GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER"] = function() cycleRoute(1) end,
        [BACK_BUTTON] = function() panel:Hide() end,
        [_G.GAMEPAD_FACE_LEFT or "PAD3"] = function() if panel.follow:IsVisible() then panel:ToggleFollow() end end,
        [_G.GAMEPAD_FACE_TOP or "PAD4"] = OpenActions,
    }, function(enabled)
        if enabled and not legend then
            legend = CreateLegend(panel, 0, {
                { _G.GAMEPAD_FACE_LEFT, L["Follow"] },
                { _G.GAMEPAD_FACE_TOP, _G.CONTEXT_ACTION_LABEL_MORE_ACTIONS },
                { _G.GAMEPAD_FACE_RIGHT, _G.FRAME_ACTION_BACK },
            })
            scrollHint = CreateScrollHint(panel.scrollbar, guideInput)
        end
        if scrollHint then scrollHint:SetShown(enabled) end
        if legend then
            legend:SetShown(enabled)
            panel:SetClampRectInsets(0, 0, 0, enabled and -legend:GetHeight() or 0)
        end
    end, function(direction) scrollBy(-direction) end, more)
    if guideInput then RefreshActiveInput() end
end
