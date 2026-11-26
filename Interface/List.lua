--[[
Copyright (c) 2009 - 2012 Ackis <John Pasula>
All rights reserved by the original author Ackis.
]]



local math = _G.math
local table = _G.table

local pairs = _G.pairs
local select = _G.select
local tostring = _G.tostring

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
---@type any
local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

-- ----------------------------------------------------------------------------
-- Imports.
-- ----------------------------------------------------------------------------
local BASIC_COLORS = private.BASIC_COLORS

-- ----------------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------------
local NUM_RECIPE_LINES	= 15
local SCROLL_DEPTH	= 5
local LISTFRAME_WIDTH	= 368
local LIST_ENTRY_WIDTH	= LISTFRAME_WIDTH - 42

-- ----------------------------------------------------------------------------
-- Upvalues
-- ----------------------------------------------------------------------------
local ListItem_ShowTooltip

local QTip = LibStub("LibQTip-2.0")
local acquire_tip
local ReleaseAcquireTooltip
local separatorTextures = {}

local function ClearTooltipSeparators()
	for index = 1, #separatorTextures do separatorTextures[index]:Hide() end
	table.wipe(separatorTextures)
	if acquire_tip and acquire_tip.ackisSeparatorAligner then acquire_tip.ackisSeparatorAligner:Hide() end
end

local function AlignTooltipSeparators()
	for _, line in ipairs(separatorTextures) do
		local row = line.ackisRow
		local top = row:GetTop()
		local pixel = _G.PixelUtil.GetPixelToUIUnitFactor() / row:GetEffectiveScale()
		if top and (line.ackisAlignedTop ~= top or line.ackisPixelSize ~= pixel) then
			-- Snap the actual screen edge, not an offset from a fractional row.
			local snappedTop = math.floor((top - 4) / pixel + 0.5) * pixel
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", row, "TOPLEFT", 0, snappedTop - top)
			line:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, snappedTop - top)
			line:SetHeight(pixel)
			line.ackisAlignedTop, line.ackisPixelSize = top, pixel
		end
	end
end

-- ----------------------------------------------------------------------------
-- Dialogs.
-- ----------------------------------------------------------------------------
local listDialogs = {
	ARL_AllFiltered = L["ALL_FILTERED"],
	ARL_AllKnown = L["ARL_ALLKNOWN"],
	ARL_AllExcluded = L["ARL_ALLEXCLUDED"],
	ARL_SearchFiltered = L["ARL_SEARCHFILTERED"],
}

-- Let Blizzard manage the popup template, sizing and dismissal behavior.
for name, text in pairs(listDialogs) do
	_G.StaticPopupDialogs[name] = {
		text = text,
		button1 = _G.OKAY,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		wideText = true,
		wide = true,
		OnShow = function(self) private.ShowPopupBackground(self) end,
		OnHide = function(self) private.HidePopupBackground(self) end,
	}
end

function private.DismissDialogs()
	for name in pairs(listDialogs) do
		_G.StaticPopup_Hide(name)
	end
end


-- ----------------------------------------------------------------------------
-- Frame creation and anchoring
-- ----------------------------------------------------------------------------
local SpellTooltip = _G.CreateFrame("GameTooltip", "AckisRecipeList_SpellTooltip", _G.UIParent, "GameTooltipTemplate")

ReleaseAcquireTooltip = function()
	SpellTooltip:Hide()
	ClearTooltipSeparators()
	if acquire_tip then
		-- Detach the native preview before this frame returns to QTip's pool.
		SpellTooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")
		local tooltip = acquire_tip
		acquire_tip = nil
		tooltip:Release()
	end
end

-- The template queues data refreshes but does not inherit an OnUpdate script.
-- Process native item/effect updates without requiring another preview click.
SpellTooltip:SetScript("OnUpdate", _G.GameTooltip_OnUpdate)

-- Resolve the native preview without routing Shift through chat links.
local function CraftedItemTooltipLink(recipe)
    local itemID = recipe:CraftedItem()
    local link
    if itemID then
        local name, itemLink = private.GetItemInfo(itemID)
        link = itemLink or ("item:%d"):format(itemID)
        if not name then
            _G.C_Item.RequestLoadItemDataByID(itemID)
        end
    else
        link = private.GetSpellLink(recipe:SpellID()) or ("spell:%d"):format(recipe:SpellID())
    end
    return link
end

-- Only recipes with an explicit AddMerchantFavor cost receive this line.
function private.AddMerchantFavorTooltipLine(recipe, addline_func)
	local amount = recipe:MerchantFavor()
	if not amount then
		return
	end

	local name = "Merchant's Favor"
	local icon = "Interface\\Icons\\racial_dwarf_findtreasure"
	if _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetCurrencyInfo then
		local info = _G.C_CurrencyInfo.GetCurrencyInfo(3402)
		if info then
			name = info.name and info.name ~= "" and info.name or name
			icon = info.iconFileID and info.iconFileID ~= 0 and info.iconFileID or icon
		end
	elseif _G.GetCurrencyInfo then
		local currencyName, _, currencyIcon = _G.GetCurrencyInfo(3402)
		name = currencyName and currencyName ~= "" and currencyName or name
		icon = currencyIcon and currencyIcon ~= 0 and currencyIcon or icon
	end

	addline_func(0, 0, false, ("|T%s:16:16:0:0|t %s:"):format(icon, name), BASIC_COLORS.normal, amount, BASIC_COLORS.white)
end

function private.InitializeListFrame()
	local MainPanel	= addon.Frame
	local ListFrame = _G.CreateFrame("Frame", nil, MainPanel, "InsetFrameTemplate")
	ListFrame:SetSize(LISTFRAME_WIDTH, 335)
	ListFrame:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 8, -75)
	-- Use the same background atlas as ProfessionsRecipeListTemplate.
	if ListFrame.Bg then ListFrame.Bg:Hide() end
	local background = ListFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetAtlas("Professions-background-summarylist")
	ListFrame.Background = background
	ListFrame:EnableMouse(true)
	ListFrame:EnableMouseWheel(true)
	ListFrame:SetScript("OnHide", function(self)
		self:HideGamepadDetails()
		ReleaseAcquireTooltip()
		SpellTooltip:Hide()
		_G.GameTooltip:Hide()
		self.selected_entry = nil

		if self.entries then
			for i = 1, #self.entries do
				local entry = self.entries[i]
				if entry and entry.children then
					private.ReleaseTable(entry.children)
					entry.children = nil
				end
			end
		end
	end)
	MainPanel.list_frame = ListFrame
    local visibleLines = NUM_RECIPE_LINES
	private.list_frame = ListFrame

	-- ----------------------------------------------------------------------------
	-- Scroll bar.
	-- ----------------------------------------------------------------------------
	local ScrollBar = _G.CreateFrame("EventFrame", nil, ListFrame, "MinimalScrollBar")
	ScrollBar:SetPoint("TOPRIGHT", ListFrame, "TOPRIGHT", -10, -5)
	ScrollBar:SetPoint("BOTTOMRIGHT", ListFrame, "BOTTOMRIGHT", -10, 5)
	ScrollBar:SetWidth(8)
	ScrollBar:SetInterpolateScroll(false)
	ScrollBar:Init(1, 1)
	-- Hide only the track artwork. The thumb is a child of Track, which must
	-- remain visible and interactive for dragging and clicking to scroll.
	ScrollBar.Track.Begin:Hide()
	ScrollBar.Track.Middle:Hide()
	ScrollBar.Track.End:Hide()
	ListFrame.scroll_bar = ScrollBar

	-- Adapt Ackis' saved row offsets to the native percentage-based controller.
	-- Programmatic restores must not trigger another list rebuild.
	local minimum, maximum, offset = 0, 0, 0
	local syncing = false
	function ScrollBar:GetMinMaxValues()
		return minimum, maximum
	end
	function ScrollBar:GetValue()
		return offset
	end
	function ScrollBar:SetMinMaxValues(low, high)
		minimum, maximum = low, math.max(low, high)
		local range = maximum - minimum
		self:SetVisibleExtentPercentage(visibleLines / (visibleLines + range))
		self:SetPanExtentPercentage(range > 0 and 1 / range or 1)
	end
	function ScrollBar:SetValue(value)
		offset = math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
		local range = maximum - minimum
		syncing = true
		self:SetScrollPercentage(range > 0 and (offset - minimum) / range or 0, true)
		syncing = false
	end
	ScrollBar:RegisterCallback(_G.ScrollBarMixin.Event.OnScroll, function(_, percentage)
		if syncing or not MainPanel.current_tab or not private.CurrentProfession then return end
		local value = math.floor(minimum + percentage * (maximum - minimum) + 0.5)
		if value == offset then return end
		offset = value
		MainPanel.current_tab:SetScrollValue(private.CurrentProfession, value)
		ListFrame:Update(nil, true)
	end, ListFrame)

	local function ScrollBar_Scroll(delta)
		if not ScrollBar:IsShown() or maximum <= minimum or not MainPanel.current_tab or not private.CurrentProfession then return end
		local value = math.max(minimum, math.min(maximum, offset - delta * SCROLL_DEPTH))
		if value == offset then return end
		ScrollBar:SetValue(value)
		MainPanel.current_tab:SetScrollValue(private.CurrentProfession, value)
		ListFrame:Update(nil, true)
	end
	ScrollBar:EnableMouseWheel(true)
	ScrollBar:SetScript("OnMouseWheel", function(_, delta) ScrollBar_Scroll(delta) end)
	ListFrame:SetScript("OnMouseWheel", function(_, delta) ScrollBar_Scroll(delta) end)

	local function Bar_OnEnter(self)
		if self and self.categoryHeader and self.categoryHeader:IsShown() then
			self.categoryHeader:CheckHighlightTitle(true)
		end
		if ListFrame.selected_entry or ListFrame.gamepadDetails then
			return
		end
		if not self or not self.entry_index or self.entry_index == 0 then
			return
		end
		ListItem_ShowTooltip(ListFrame.entries[self.entry_index])
	end

	local function Bar_OnLeave(self)
		if self and self.categoryHeader and self.categoryHeader:IsShown() then
			self.categoryHeader:CheckHighlightTitle(false)
		end
		if ListFrame.selected_entry or ListFrame.gamepadDetails then
			return
		end
		ReleaseAcquireTooltip()
		SpellTooltip:Hide()
        _G.GameTooltip:Hide()
	end

	local pendingChatLink, pendingChatTicker, pendingChatDeadline
	local function InsertGamepadChatLink(link)
		local chat = _G.ChatFrameUtil
		local findActiveBox = chat and chat.GetActiveWindow or _G.ChatEdit_GetActiveWindow
		if not findActiveBox then return end
		local editBox = findActiveBox()
		if editBox and editBox:HasFocus() then
			if pendingChatTicker then pendingChatTicker:Cancel() end
			pendingChatLink, pendingChatTicker = nil, nil
			editBox:Insert(link)
			return
		end

		-- Opening chat from addon code can carry addon taint into the native binding stack.
		pendingChatLink = link
		pendingChatDeadline = _G.GetTime() + 30
		if pendingChatTicker then return end
		addon:Print(L["Open chat to insert the recipe link."])
		pendingChatTicker = _G.C_Timer.NewTicker(0.1, function(ticker)
			local activeBox = findActiveBox()
			if private.addonEnabled == false or _G.GetTime() >= pendingChatDeadline then
				pendingChatLink = nil
			elseif activeBox and activeBox:HasFocus() then
				activeBox:Insert(pendingChatLink)
				pendingChatLink = nil
			end
			if not pendingChatLink then
				ticker:Cancel()
				pendingChatTicker = nil
			end
		end)
	end

	local function InsertChatLink(link)
		if not link then return end
		if _G.InputUtil and _G.InputUtil.IsGamepadUIEnabled and _G.InputUtil.IsGamepadUIEnabled() then
			InsertGamepadChatLink(link)
			return
		end
		local chat = _G.ChatFrameUtil
		local insert = chat and chat.InsertLink or _G.ChatEdit_InsertLink
		if insert(link) then return end
		local chooseBox = chat and chat.ChooseBoxForSend or _G.ChatEdit_ChooseBoxForSend
		local activate = chat and chat.ActivateChat or _G.ChatEdit_ActivateChat
		local editBox = chooseBox()
		if not editBox then return end
		activate(editBox)
		editBox:Insert(link)
	end

	local function ActivateListItem(self, button, fromGamepad)
		local clickedIndex = self.entry_index

		if not clickedIndex or clickedIndex == 0 then
			return
		end
		local listEntry = ListFrame.entries[clickedIndex]
		local recipe = listEntry.recipe

        if listEntry.guideStep or listEntry.guideShopping then
            private.OpenGuideStep(private.CurrentProfession, listEntry.guideChapter, listEntry.guideStep)
            return
        end

        if button == "LeftButton" and (fromGamepad or not _G.IsModifierKeyDown()) and listEntry.acquisitionSourceRow then
            if listEntry.waypointTarget then
                addon:AddWaypoint(recipe, listEntry:AcquireType(), listEntry:Location(), listEntry:NPCID())
            end
            return
        end

        if recipe and button == "RightButton" and _G.IsShiftKeyDown()
            and not _G.IsControlKeyDown() and not _G.IsAltKeyDown() then
            ListItem_ShowTooltip(listEntry, true)
            return
        end

		if button == "RightButton" and recipe and (not listEntry.parent or listEntry.parent.recipe ~= listEntry.recipe) then
			local old_selected = ListFrame.selected_entry
			local entry_button = listEntry.button

			ListFrame.selected_entry = nil

			if old_selected and old_selected.button then
				old_selected.button.selected_texture:Hide()
				Bar_OnLeave()
			end
			if entry_button then
				Bar_OnEnter(entry_button)
			end

			if old_selected ~= listEntry then
				entry_button.selected_texture:Show()
				ListFrame.selected_entry = listEntry
			end
        elseif recipe and not fromGamepad and _G.IsModifierKeyDown() then
            local hyperLink

            if _G.IsControlKeyDown() then
				if _G.IsShiftKeyDown() and recipe:HasCoordinates() then
					addon:AddWaypoint(recipe, listEntry:AcquireType(), listEntry:Location(), listEntry:NPCID())
                else
                    hyperLink = private.GetSpellLink(recipe:SpellID())
				end
			elseif _G.IsShiftKeyDown() then
				local craftedItemID = recipe:CraftedItem()
				if craftedItemID then
					local _, itemLink = private.GetItemInfo(craftedItemID)
					if itemLink then
                        hyperLink = itemLink
					else
						addon:Print(L["NoItemLink"])
					end
				else
					addon:Print(L["NoItemLink"])
				end
			elseif _G.IsAltKeyDown() then
				local exclusion_list = addon.db.profile.exclusionlist
				local recipeSpellID = recipe:SpellID()

				exclusion_list[recipeSpellID] = (not exclusion_list[recipeSpellID] and true or nil)
                private.IncrementFilterVersion()
				ListFrame:Update(nil, false)
            end

            InsertChatLink(hyperLink)
        else
            local currentTab = MainPanel.current_tab
            if listEntry.is_expanded then
                listEntry:CollapseChildren()
                currentTab:SaveListEntryState(listEntry, false)
                listEntry.is_expanded = false
            else
                currentTab:ExpandListEntry(listEntry)
                listEntry.is_expanded = true
            end
		end

		ListFrame:Update(nil, true)
	end

	local function ListItem_OnClick(self, button)
		ListFrame:HideGamepadDetails()
		ActivateListItem(self, button, false)
	end

	function ListFrame:ActivateGamepadRow(row)
		ActivateListItem(row, "LeftButton", true)
	end

	function ListFrame:LinkGamepadRecipe(row)
		local entry = row and self.entries[row.entry_index]
		local recipe = entry and entry.recipe
		if recipe then InsertChatLink(private.GetSpellLink(recipe:SpellID())) end
	end

	local gamepadTooltip, gamepadProduct
	function ListFrame:ShowGamepadDetails(row, showProduct)
		local entry = row and self.entries[row.entry_index]
		showProduct = showProduct and entry and entry.recipe ~= nil and not (entry.guideChapter or entry.guideShopping) or false
		local productShown = gamepadProduct and gamepadProduct:IsShown() or false
		if entry and gamepadTooltip and self.gamepadDetails == entry
			and gamepadTooltip:IsShown() and productShown == showProduct then
			return true, productShown
		end
		self:HideGamepadDetails()
		if not entry or not (entry.recipe or entry.guideChapter or entry.guideShopping) then return false end
		if self.selected_entry then
			local selectedButton = self.selected_entry.button
			if selectedButton then selectedButton.selected_texture:Hide() end
			self.selected_entry = nil
		end
		gamepadTooltip, gamepadProduct = ListItem_ShowTooltip(entry, showProduct, true)
		self.gamepadDetails = gamepadTooltip and entry
		return gamepadTooltip ~= nil, gamepadProduct ~= nil
	end

	function ListFrame:HideGamepadProduct()
		if not gamepadProduct then return false end
		local wasShown = gamepadProduct:IsShown()
		gamepadProduct:Hide()
		if gamepadTooltip == gamepadProduct then
			gamepadTooltip = nil
			self.gamepadDetails = nil
		end
		gamepadProduct = nil
		return wasShown
	end

	function ListFrame:HideGamepadDetails()
		if not gamepadTooltip then return false end
		local wasShown = self:HideGamepadProduct()
		if not gamepadTooltip then return wasShown end
		if gamepadTooltip == acquire_tip then
			wasShown = gamepadTooltip:IsShown() or wasShown
			ReleaseAcquireTooltip()
		elseif gamepadTooltip == _G.GameTooltip then
			local owner = self.gamepadDetails.button
			if owner and gamepadTooltip:IsOwned(owner) then
				wasShown = gamepadTooltip:IsShown()
				gamepadTooltip:Hide()
			end
		end
		gamepadTooltip = nil
		self.gamepadDetails = nil
		return wasShown
	end

	function ListFrame:ScrollGamepadDetails(direction)
		local bar = gamepadTooltip and gamepadTooltip == acquire_tip and acquire_tip.Slider
		if not (bar and acquire_tip:IsShown() and bar:IsShown()) then return false end
		bar:SetValue(bar:GetValue() + direction * acquire_tip.ScrollStep)
		return true
	end

	-- ----------------------------------------------------------------------------
	-- The state and entry buttons and the container frames which hold them.
	-- ----------------------------------------------------------------------------
    local ListEntryButtonContainers = {}
    ListFrame.entries = {}
	ListFrame.ListEntryButtons = {}

	for index = 1, NUM_RECIPE_LINES do
		local buttonContainer = _G.CreateFrame("Frame", nil, ListFrame)
		buttonContainer:SetSize(LIST_ENTRY_WIDTH, 20)

        if index == 1 then
            buttonContainer:SetPoint("TOPLEFT", ListFrame, "TOPLEFT", 6, -4)
        else
            buttonContainer:SetPoint("TOPLEFT", ListEntryButtonContainers[index - 1], "BOTTOMLEFT", 0, -2)
        end

		local stateButton = _G.CreateFrame("Button", nil, ListFrame)
		stateButton:SetSize(16, 20)
        stateButton:SetPoint("LEFT", buttonContainer, "LEFT", 0, 0)
        stateButton:SetScript("OnClick", ListItem_OnClick)

        stateButton.container = buttonContainer

        local listEntry = _G.CreateFrame("Button", ("%s_ListEntryButton%d"):format(FOLDER_NAME, index), buttonContainer)
		listEntry:SetSize(LIST_ENTRY_WIDTH, 20)
        listEntry:SetPoint("LEFT", stateButton, "RIGHT", -3, 0)
        listEntry:RegisterForClicks("AnyUp")

        listEntry.stateButton = stateButton
        stateButton.listEntry = listEntry

		local highlightTexture = listEntry:CreateTexture(nil, "BORDER")
		highlightTexture:SetAtlas("Professions_Recipe_Hover")
		highlightTexture:SetBlendMode("ADD")
		highlightTexture:SetPoint("TOPLEFT", 2, 0)
		highlightTexture:SetPoint("BOTTOMRIGHT", -2, 1)
		listEntry:SetHighlightTexture(highlightTexture)
		listEntry.highlight_texture = highlightTexture

		local selectedTexture = listEntry:CreateTexture(nil, "BORDER")
		selectedTexture:SetAtlas("Professions_Recipe_Active")
		selectedTexture:SetBlendMode("ADD")
		selectedTexture:SetPoint("TOPLEFT", 2, 0)
		selectedTexture:SetPoint("BOTTOMRIGHT", -2, 1)
		listEntry.selected_texture = selectedTexture

		local emphasisTexture = listEntry:CreateTexture(nil, "BORDER")
		emphasisTexture:SetTexture([[Interface\QUESTFRAME\Ui-QuestLogTitleHighlight]])
		emphasisTexture:SetVertexColor(1, 0.61, 0)
		emphasisTexture:SetBlendMode("ADD")
		emphasisTexture:SetPoint("TOPLEFT", 2, 0)
		emphasisTexture:SetPoint("BOTTOMRIGHT", -2, 1)
		listEntry.emphasis_texture = emphasisTexture

        local titleBackgroundTexture = _G.CreateFrame("Frame", nil, listEntry)
        titleBackgroundTexture:SetAllPoints(listEntry)
        titleBackgroundTexture:SetFrameLevel(listEntry:GetFrameLevel() - 1)
        local left = titleBackgroundTexture:CreateTexture(nil, "BACKGROUND")
        left:SetAtlas("Professions-recipe-header-left", true)
        left:SetPoint("LEFT")
        local right = titleBackgroundTexture:CreateTexture(nil, "BACKGROUND")
        right:SetAtlas("Professions-recipe-header-right", true)
        right:SetPoint("RIGHT")
        local middle = titleBackgroundTexture:CreateTexture(nil, "BACKGROUND")
        middle:SetAtlas("Professions-recipe-header-middle")
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        listEntry.titleBackgroundTexture = titleBackgroundTexture
		listEntry.titleBackgroundSlices = { left, middle, right }

		local label = listEntry:CreateFontString(nil, "ARTWORK")
		label:SetPoint("LEFT", listEntry, "LEFT", 7, 0)
		label:SetPoint("RIGHT", listEntry, "RIGHT", -7, 0)
		label:SetFontObject("GameFontHighlight_NoShadow")
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		label:SetWordWrap(false)

		listEntry:SetFontString(label)
		listEntry.text = label
        listEntry.guide_status_icon = listEntry:CreateTexture(nil, "ARTWORK")
        listEntry.guide_status_icon:SetSize(16, 16)
        listEntry.guide_status_icon:SetPoint("LEFT", 7, 0)
        listEntry.guide_progress = listEntry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        listEntry.guide_progress:SetPoint("RIGHT", -7, 0)
        listEntry.guide_progress:SetWidth(40)
        listEntry.guide_progress:SetJustifyH("RIGHT")
        listEntry.guide_progress:SetTextColor(.8, .75, .6)


		ListEntryButtonContainers[index] = buttonContainer
		ListFrame.ListEntryButtons[index] = listEntry
	end

    function ListFrame:SetGuideLayout(isGuide)
        local rowGap = 2
        local rowHeight = isGuide and 24 or 20
        visibleLines = isGuide and 12 or NUM_RECIPE_LINES
        self.visibleLines = visibleLines
        for index, container in ipairs(ListEntryButtonContainers) do
            container:ClearAllPoints()
            if index == 1 then
                container:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -4)
            else
                container:SetPoint("TOPLEFT", ListEntryButtonContainers[index - 1], "BOTTOMLEFT", 0, -rowGap)
            end
            container:SetHeight(rowHeight)
            container:SetShown(index <= visibleLines)
            self.ListEntryButtons[index]:SetHeight(rowHeight)
            self.ListEntryButtons[index].stateButton:SetHeight(rowHeight)
        end
    end

	function ListFrame:InsertEntry(entry, entry_index, entry_expanded, expand_mode)
		local insert_index = entry_index
		entry.index = entry_index

		-- If we have acquire information for this entry, push the data table into the list
		-- and start processing the acquires.
		if expand_mode then
			entry.is_expanded = true
			table.insert(self.entries, insert_index, entry)

			if entry:IsCategory() or entry:IsHeader() or entry:IsSubHeader() then
				insert_index = MainPanel.current_tab:ExpandListEntry(entry, expand_mode)
			else
				MainPanel.current_tab:SaveListEntryState(entry, entry_expanded)
				insert_index = insert_index + 1
			end
		else
			entry.is_expanded = entry_expanded
			table.insert(self.entries, insert_index, entry)

			insert_index = insert_index + 1
		end
		return insert_index
	end

	-- ----------------------------------------------------------------------------
	-- Filter flag data and functions for ListFrame:Initialize()
	-- ----------------------------------------------------------------------------
		function ListFrame:Initialize(expand_mode)
            ReleaseAcquireTooltip()
            private.UpdateGuideTabAvailability()
            private.UpdateGuidePresentation(MainPanel)
			for i = 1, #self.entries do
				private.ReleaseTable(self.entries[i])
			end
			table.wipe(self.entries)

            local selectedTab = MainPanel.tabs[addon.db.profile.current_tab]
            if selectedTab and selectedTab.kind == "guide" then
                MainPanel.current_tab = selectedTab
                selectedTab:GetProfessionExpansionState(private.CurrentProfession)
                selectedTab:Initialize(expand_mode)
                if selectedTab["expand_button_" .. private.CurrentProfession:LocalizedName()] then
                    MainPanel.expand_button:Expand(selectedTab)
                else
                    MainPanel.expand_button:Contract(selectedTab)
                end
                SpellTooltip:Hide()
                self.selected_entry = nil
                local completed, total = private.GuideProgress(private.CurrentProfession)
                MainPanel.progress_bar:SetMinMaxValues(0, math.max(1, total))
                MainPanel.progress_bar:SetValue(completed)
                MainPanel.progress_bar.text:SetFormattedText("Guide - %d/%d steps - %.0f%%", completed, total,
                    total > 0 and completed / total * 100 or 0)
                return
            end

			-- ----------------------------------------------------------------------------
			-- Update recipe filters.
			-- ----------------------------------------------------------------------------
			local general_filters = addon.db.profile.filters.general
			local professionRecipes = private.CurrentProfession.Recipes
			local recipes_known, recipes_known_filtered = 0, 0
			local recipes_total, recipes_total_filtered = 0, 0

			for _, recipe in pairs(professionRecipes) do
				local can_display = false
				recipe:RemoveState("VISIBLE")

				if not recipe:HasState(MainPanel.is_linked and "LINKED_IGNORED" or "IGNORED") then
					recipes_total = recipes_total + 1

					local is_known

					if MainPanel.is_linked then
						is_known = recipe:HasState("LINKED")
					else
						is_known = recipe:HasState("KNOWN")
					end
					recipes_known = recipes_known + (is_known and 1 or 0)

					can_display = recipe:CanDisplay()

					if can_display then
						recipes_total_filtered = recipes_total_filtered + 1
						recipes_known_filtered = recipes_known_filtered + (is_known and 1 or 0)

						if not general_filters.known and is_known then
							can_display = false
						end

						if not general_filters.unknown and not is_known then
							can_display = false
						end
					end
				end

				if can_display then
					recipe:AddState("VISIBLE")
				end
			end
			local player = private.Player
			player.recipes_total = recipes_total
			player.recipes_known = recipes_known
			player.recipes_total_filtered = recipes_total_filtered
			player.recipes_known_filtered = recipes_known_filtered

			-- ----------------------------------------------------------------------------
			-- Mark all exclusions in the recipe database to not be displayed, and update
			-- the player's known and unknown counts.
			-- ----------------------------------------------------------------------------
			local known_count = 0
			local unknown_count = 0

			for recipeSpellID in pairs(addon.db.profile.exclusionlist) do
				local recipe = professionRecipes[recipeSpellID]
				if recipe then
					if recipe:HasState("KNOWN") then
						known_count = known_count + 1
					else
						unknown_count = unknown_count + 1
					end
				end
			end
			player.excluded_recipes_known = known_count
			player.excluded_recipes_unknown = unknown_count

			-- ----------------------------------------------------------------------------
			-- Initialize the expand button and entries for the current tab.
			-- ----------------------------------------------------------------------------
            local currentTab = MainPanel.tabs[addon.db.profile.current_tab]
            local professionExpandButton = currentTab["expand_button_" .. private.CurrentProfession:LocalizedName()]

			ReleaseAcquireTooltip()
		SpellTooltip:Hide()
			self.selected_entry = nil

			if professionExpandButton then
				MainPanel.expand_button:Expand(currentTab)
			else
				MainPanel.expand_button:Contract(currentTab)
			end
			local recipe_count = currentTab:Initialize(expand_mode)

			-- ----------------------------------------------------------------------------
			-- Update the progress bar display.
			-- ----------------------------------------------------------------------------
			local profile = addon.db.profile
			local max_value = profile.includefiltered and player.recipes_total or (player.recipes_total_filtered + (player.recipes_known - player.recipes_known_filtered))
			local cur_value = player.recipes_known	-- Current value will always be what we know regardless of filters.

			if not profile.includeexcluded and not profile.ignoreexclusionlist then
				max_value = max_value - player.excluded_recipes_known
			end
			local progress_bar = MainPanel.progress_bar

			progress_bar:SetMinMaxValues(0, max_value)
			progress_bar:SetValue(cur_value)

			local percentage = 0
			if max_value > 0 then
				percentage = (cur_value / max_value) * 100
			end

			if (max_value > 0) and (math.floor(percentage) < 101) and (cur_value >= 0) then
				local results = _G.SINGLE_PAGE_RESULTS_TEMPLATE:format(recipe_count)
				progress_bar.text:SetFormattedText("%d/%d - %1.2f%% (%s)", cur_value, max_value, percentage, results)
			else
				progress_bar.text:SetFormattedText("%s", L["NOT_YET_SCANNED"])
			end
		end

	-- Reset the current buttons/lines
	function ListFrame:ClearLines()
		for index = 1, NUM_RECIPE_LINES do
			local entry = self.ListEntryButtons[index]
			entry.text:SetFontObject(addon.db.profile.frameopts.small_list_font and "GameFontHighlightSmall" or "GameFontHighlight_NoShadow")
            entry.text:SetJustifyH("LEFT")
            entry:SetText("")
            entry:SetScript("OnEnter", nil)
            entry:SetScript("OnLeave", nil)
            entry:SetScript("OnClick", nil)
            entry:SetWidth(LIST_ENTRY_WIDTH)
            entry:ClearAllPoints()
            entry:SetPoint("LEFT", entry.stateButton, "RIGHT", -3, 0)
            entry.text:Show()
            if entry.categoryHeader then entry.categoryHeader:Hide() end
            entry.highlight_texture:SetAtlas("Professions_Recipe_Hover")
            entry.highlight_texture:SetAlpha(1)
            entry:Disable()
            entry.emphasis_texture:Hide()
            entry.selected_texture:Hide()
            entry.titleBackgroundTexture:Hide()
            entry.guide_status_icon:Hide()
            entry.guide_status_icon:SetVertexColor(1, 1, 1)
            entry.guide_progress:Hide()
            entry.text:ClearAllPoints()
            entry.text:SetPoint("LEFT", entry, "LEFT", 7, 0)
            entry.text:SetPoint("RIGHT", entry, "RIGHT", -7, 0)
			for _, slice in ipairs(entry.titleBackgroundSlices) do
				slice:SetVertexColor(1, 1, 1)
			end
            entry.button = nil
            entry.entry_index = 0

			local stateButton = entry.stateButton
			stateButton.entry_index = 0
			stateButton:Hide()
			stateButton:Disable()
			stateButton:ClearAllPoints()
		end
	end

	local emptyPopupName, popupSearch, popupProfession

	local function ShowEmptyListPopup(name)
		if emptyPopupName == name then
			return
		end
		private.DismissDialogs()
		emptyPopupName = name
		_G.StaticPopup_Show(name)
	end

	function ListFrame:Update(expand_mode, refresh)
		self:HideGamepadDetails()
		local searchText = MainPanel.search_editbox:GetText()
		if popupSearch ~= searchText or popupProfession ~= private.CurrentProfession then
			private.DismissDialogs()
			emptyPopupName = nil
			popupSearch = searchText
			popupProfession = private.CurrentProfession
		end
        if refresh then
            local writeIndex = 1
            for readIndex = 1, #self.entries do
                local entry = self.entries[readIndex]
                if entry._discard then
                    private.ReleaseTable(entry)
                else
                    if writeIndex ~= readIndex then
                        self.entries[writeIndex] = entry
                    end
                    writeIndex = writeIndex + 1
                end
            end
            for i = writeIndex, #self.entries do
                self.entries[i] = nil
            end
        else
            self:Initialize(expand_mode)
        end

		local listEntryCount = #self.entries

		if listEntryCount == 0 then
			self:ClearLines()

			-- disable expand button, it's useless here and would spam the same error again
			MainPanel.expand_button:SetNormalFontObject("GameFontDisableSmall")
			MainPanel.expand_button:Disable()
			self.scroll_bar:Hide()

			local showpopup = false

			if not addon.db.profile.hidepopup then
				showpopup = true
			end

			-- If we haven't run this before we'll show pop-ups for the first time.
			if addon.db.profile.addonversion ~= addon.version then
				addon.db.profile.addonversion = addon.version
				showpopup = true
			end
			local editbox_text = MainPanel.search_editbox:GetText()
			local player = private.Player

			if player.recipes_total == 0 then
				-- Do not show any popup when nothing has been scanned; scanning starts automatically
			elseif player.recipes_known == player.recipes_total then
				if showpopup then
					ShowEmptyListPopup("ARL_AllKnown")
				end
			elseif (player.recipes_total_filtered - player.recipes_known_filtered) == 0 then
				if showpopup then
					ShowEmptyListPopup("ARL_AllFiltered")
				end
			elseif player.excluded_recipes_unknown ~= 0 then
				if showpopup then
					ShowEmptyListPopup("ARL_AllExcluded")
				end
			elseif editbox_text ~= "" and editbox_text ~= _G.SEARCH then
				if not MainPanel.search_editbox:HasFocus() then
					ShowEmptyListPopup("ARL_SearchFiltered")
				end
			else
				addon:Print(L["NO_DISPLAY"])
			end
			if self.UpdateGamepadFocus then self:UpdateGamepadFocus() end
			return
		end
		local offset = 0

		emptyPopupName = nil
		private.DismissDialogs()

		MainPanel.expand_button:SetNormalFontObject("GameFontNormalSmall")
		MainPanel.expand_button:Enable()

		local currentTab = MainPanel.current_tab
		if currentTab.kind == "acquisition" or currentTab.kind == "location" then
			-- Only source categories get larger rows and extra separation. Count
			-- visible entries by their actual height so compact recipes scroll correctly.
			local availableHeight = self:GetHeight() - 7
			local function RowMetrics(entry, first)
				local category = currentTab.kind == "acquisition" and entry:IsHeader() and entry.acquisitionCount
					or currentTab.kind == "location" and entry:IsCategory()
				return category and 25 or 20, first and 0 or category and currentTab.kind == "acquisition" and 6 or 2
			end
			local function CountRows(start)
				local used, count = 0, 0
				for index = start, math.min(listEntryCount, start + NUM_RECIPE_LINES - 1) do
					local height, gap = RowMetrics(self.entries[index], index == start)
					if used + height + gap > availableHeight then break end
					used, count = used + height + gap, count + 1
				end
				return count
			end
			local lastStart = listEntryCount
			while lastStart > 1 and CountRows(lastStart - 1) == listEntryCount - lastStart + 2 do
				lastStart = lastStart - 1
			end
			local maxScrollValue = lastStart - 1
			offset = maxScrollValue > 0 and math.max(0, math.min(currentTab:ScrollValue(private.CurrentProfession) or 0, maxScrollValue)) or 0
			visibleLines = CountRows(offset + 1)
			self.visibleLines = visibleLines
			self.scroll_bar:SetMinMaxValues(0, maxScrollValue)
			self.scroll_bar:SetValue(offset)
			self.scroll_bar:SetShown(maxScrollValue > 0)
			for index, container in ipairs(ListEntryButtonContainers) do
				local entry = self.entries[offset + index]
				local height, gap = 20, 2
				if entry then height, gap = RowMetrics(entry, index == 1) end
				container:ClearAllPoints()
				if index == 1 then
					container:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -4)
				else
					container:SetPoint("TOPLEFT", ListEntryButtonContainers[index - 1], "BOTTOMLEFT", 0, -gap)
				end
				container:SetHeight(height)
				container:SetShown(index <= visibleLines)
				self.ListEntryButtons[index]:SetHeight(height)
				self.ListEntryButtons[index].stateButton:SetHeight(height)
			end
		elseif listEntryCount <= visibleLines then
			self.scroll_bar:SetMinMaxValues(0, 0)
			self.scroll_bar:SetValue(0)
			self.scroll_bar:Hide()
		else
			local maxScrollValue = listEntryCount - visibleLines
			self.scroll_bar:SetMinMaxValues(0, math.max(0, maxScrollValue))
			local scrollValue = math.max(0, math.min(currentTab:ScrollValue(private.CurrentProfession) or 0, maxScrollValue))
			self.scroll_bar:SetValue(scrollValue)
			offset = scrollValue
			self.scroll_bar:Show()
		end
		self:ClearLines()
		if currentTab.kind == "guide" then
			for index = 2, visibleLines do
				local previousEntry = self.entries[offset + index - 1]
				local gap = previousEntry and previousEntry.guideShopping and 8 or 2
				local container = ListEntryButtonContainers[index]
				container:ClearAllPoints()
				container:SetPoint("TOPLEFT", ListEntryButtonContainers[index - 1], "BOTTOMLEFT", 0, -gap)
			end
		end

		local buttonIndex = 1
		local listEntryIndex = math.floor(buttonIndex + offset)

		-- Populate the buttons with new values
		while buttonIndex <= visibleLines and listEntryIndex <= listEntryCount do
            local listEntryButton = self.ListEntryButtons[buttonIndex]
			local listEntry = self.entries[listEntryIndex]
            local stateButton = listEntryButton.stateButton
            local isEntry = listEntry:IsEntry()
			local isSubentry = not isEntry and listEntry:IsSubEntry()
			local isCategory = listEntry:IsCategory()
			local isHeader = not isSubentry and listEntry:IsHeader()
			local isSubheader = not isHeader and listEntry:IsSubHeader()
            local isTitle = not isSubheader and listEntry:IsTitle()

			if (isCategory or isHeader or isSubheader) and not listEntry.guideShopping then
				stateButton:Show()

				local atlas = listEntry.is_expanded and "Professions-recipe-header-collapse" or "Professions-recipe-header-expand"
				if not stateButton.icon then
					stateButton.icon = stateButton:CreateTexture(nil, "ARTWORK")
					stateButton.icon:SetPoint("CENTER")
				end
				stateButton.icon:SetAtlas(atlas, true)
				stateButton.icon:SetVertexColor(1, 1, 1)
				stateButton.entry_index = listEntryIndex
				stateButton:Enable()
			else
				stateButton:Hide()
				stateButton:Disable()
			end

			if listEntry == ListFrame.selected_entry then
				listEntryButton.selected_texture:Show()
			end

            if isTitle or isCategory or isHeader or isSubheader then
                listEntryButton.titleBackgroundTexture:Show()
                listEntryButton.text:SetJustifyH("LEFT")
                listEntryButton.text:SetFontObject("GameFontNormal_NoShadow")
            elseif listEntry:IsEmphasized() then
                listEntryButton.emphasis_texture:Show()
			end

			if isTitle or isCategory or isHeader or isEntry then
				stateButton:SetPoint("TOPLEFT", stateButton.container, "TOPLEFT", 0, 0)
            elseif isSubheader or isSubentry then
                stateButton:SetPoint("TOPLEFT", stateButton.container, "TOPLEFT", 15, 0)
                listEntryButton:SetWidth(LIST_ENTRY_WIDTH - 15)
			end

			-- Reuse the native profession header art and consistent indentation
			-- across all three views, without changing their entry hierarchies.
			local currentTab = MainPanel.current_tab
			if currentTab.kind == "location" then
				local inset = 0
				local red, green, blue = 1, 1, 1
				if isTitle then
					if listEntry.category_level == "world" then
						red, green, blue = 0.95, 0.73, 0.32
						listEntryButton.text:SetFontObject("GameFontNormalLarge")
					else
						inset = 8
						red, green, blue = 0.60, 0.78, 0.96
						listEntryButton.text:SetFontObject("GameFontNormal")
					end
				elseif isCategory then
					inset = 8
					red, green, blue = 0.60, 0.78, 0.96
					listEntryButton.text:SetFontObject("GameFontNormal")
					stateButton.icon:SetVertexColor(0.83, 0.92, 1)
				elseif isHeader then
					inset = 12
					red, green, blue = 0.64, 0.53, 0.37
					stateButton.icon:SetVertexColor(1, 0.78, 0.35)
				elseif isSubheader or isEntry then
					inset = 28
					listEntryButton.titleBackgroundTexture:Hide()
					if isSubheader then
						stateButton.icon:SetVertexColor(0.88, 0.82, 0.70)
					end
				elseif isSubentry then
					inset = 42
				end
				if isTitle or isCategory or isHeader then
					for _, slice in ipairs(listEntryButton.titleBackgroundSlices) do
						slice:SetVertexColor(red, green, blue)
					end
				end
				stateButton:ClearAllPoints()
				stateButton:SetPoint("TOPLEFT", stateButton.container, "TOPLEFT", inset, 0)
				listEntryButton:SetWidth(LIST_ENTRY_WIDTH - inset)
			elseif currentTab.kind == "acquisition" then
				local inset = 12
				if isHeader then

					for _, slice in ipairs(listEntryButton.titleBackgroundSlices) do
						slice:SetVertexColor(0.64, 0.53, 0.37)
					end
					stateButton.icon:SetVertexColor(1, 0.78, 0.35)
				elseif isSubheader or isEntry then
					inset = 28
					listEntryButton.titleBackgroundTexture:Hide()
					if isSubheader then
						stateButton.icon:SetVertexColor(0.88, 0.82, 0.70)
					end
				elseif isSubentry then
					inset = 42
				end
				stateButton:ClearAllPoints()
				stateButton:SetPoint("TOPLEFT", stateButton.container, "TOPLEFT", inset, 0)
				listEntryButton:SetWidth(LIST_ENTRY_WIDTH - inset)
			elseif currentTab.kind == "recipes" then
				local inset = 10
				if isHeader then
					listEntryButton.titleBackgroundTexture:Hide()
					stateButton.icon:SetVertexColor(0.88, 0.82, 0.70)
				elseif isEntry then
					inset = 28
				end
				stateButton:ClearAllPoints()
				stateButton:SetPoint("TOPLEFT", stateButton.container, "TOPLEFT", inset, 0)
				listEntryButton:SetWidth(LIST_ENTRY_WIDTH - inset)
			end
            if currentTab.kind == "guide" then
                local inset = listEntry.guideStep and 20 or 0
                stateButton:ClearAllPoints()
                stateButton:SetPoint("TOPLEFT", stateButton.container, "TOPLEFT", inset, 0)
                listEntryButton:SetWidth(LIST_ENTRY_WIDTH - inset)
                listEntryButton.text:SetFontObject(listEntry.guideStep and "GameFontHighlight" or "GameFontNormal")
                if listEntry.guideChapter and not listEntry.guideStep then
                    listEntryButton.guide_progress:SetText(listEntry.guideChapterProgress)
                    listEntryButton.guide_progress:Show()
                    listEntryButton.text:ClearAllPoints()
                    listEntryButton.text:SetPoint("LEFT", listEntryButton, "LEFT", 7, 0)
                    listEntryButton.text:SetPoint("RIGHT", listEntryButton, "RIGHT", -52, 0)
                end
                if listEntry.guideShopping or listEntry.guideDone or listEntry.guideNext then
                    local icon = listEntryButton.guide_status_icon
                    icon:SetTexture(listEntry.guideShopping and [[Interface\Icons\INV_Misc_Bag_08]]
                        or listEntry.guideDone and [[Interface\Buttons\UI-CheckBox-Check]]
                        or [[Interface\Buttons\UI-SpellbookIcon-NextPage-Up]])
                    if listEntry.guideDone then icon:SetVertexColor(.3, 1, .3) end
                    icon:Show()
                    listEntryButton.text:ClearAllPoints()
                    listEntryButton.text:SetPoint("LEFT", listEntryButton, "LEFT", 29, 0)
                    listEntryButton.text:SetPoint("RIGHT", listEntryButton, "RIGHT", -7, 0)
                end
                if listEntry.guideNext then listEntryButton.emphasis_texture:Show() end
            end
			local isAcquisitionCategory = currentTab.kind == "acquisition" and isHeader and listEntry.acquisitionCount
			if (currentTab.kind == "location" and isCategory) or isAcquisitionCategory then
				-- The profession list uses ListHeaderVisualTemplate for its categories.
				-- Keep Ackis's row and expansion handler, using the native control as art.
				local header = listEntryButton.categoryHeader
				if not header then
					header = _G.CreateFrame("Button", nil, listEntryButton, "ListHeaderVisualTemplate")
					header:SetAllPoints(listEntryButton)
					header:EnableMouse(false)
					header.CollapseButton:EnableMouse(false)
					header:SetTitleColor(false, _G.NORMAL_FONT_COLOR)
					header:SetTitleColor(true, _G.HIGHLIGHT_FONT_COLOR)
					header.Count = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					header.Count:SetPoint("RIGHT", header, "RIGHT", -8, 0)
					header.Count:SetWidth(40)
					header.Count:SetJustifyH("RIGHT")
					listEntryButton.categoryHeader = header
				end
				listEntryButton:ClearAllPoints()
				listEntryButton:SetPoint("LEFT", stateButton.container, "LEFT", 0, 0)
				listEntryButton:SetWidth(LIST_ENTRY_WIDTH)
				listEntryButton.titleBackgroundTexture:Hide()
				listEntryButton.text:Hide()
				stateButton:Hide()
				header.CollapseButton:ClearAllPoints()
				local label = header:GetTitleRegion()
				label:ClearAllPoints()
				if isAcquisitionCategory then
					local categoryWidth = LIST_ENTRY_WIDTH - 8
					listEntryButton:ClearAllPoints()
					listEntryButton:SetPoint("LEFT", stateButton.container, "LEFT", (LISTFRAME_WIDTH - categoryWidth) / 2 - 6, 0)
					listEntryButton:SetWidth(categoryWidth)
					label:SetFontObject("GameFontNormal")
					header.CollapseButton:SetPoint("LEFT", header, "LEFT", 6, 0)
					label:SetPoint("LEFT", header, "LEFT", 52, 0)
					label:SetPoint("RIGHT", header, "RIGHT", -52, 0)
					label:SetJustifyH("CENTER")
					header.Count:SetText(("(%d)"):format(listEntry.acquisitionCount))
					header.Count:Show()
				else
					label:SetFontObject("Game15Font_Shadow")
					header.CollapseButton:SetPoint("RIGHT", header, "RIGHT", -6, 0)
					label:SetPoint("LEFT", header, "LEFT", 8, 0)
					label:SetPoint("RIGHT", header.CollapseButton, "LEFT", -4, 0)
					label:SetJustifyH("LEFT")
					header.Count:Hide()
				end
				header:SetHeaderText(listEntry:Text())
				header.CollapseButton:UpdateCollapsedState(not listEntry.is_expanded)
				header:Show()
				listEntryButton.highlight_texture:SetAtlas("common-button-list-collapseExpand")
				listEntryButton.highlight_texture:SetAlpha(0.4)
			end
			listEntry.button = listEntryButton
			listEntryButton.entry_index = listEntryIndex

			listEntryButton:SetText(listEntry:Text())
			listEntryButton:SetScript("OnEnter", Bar_OnEnter)
			listEntryButton:SetScript("OnLeave", Bar_OnLeave)

            if not isTitle then
                listEntryButton:SetScript("OnClick", ListItem_OnClick)
                listEntryButton:Enable()
            end

			-- This function could possibly have been called from a mouse click or by scrolling. Since, in those cases, the list entries have
			-- changed, the mouse is likely over a different entry - a tooltip should be generated for it.
			if not self.gamepadFocus and listEntryButton:IsMouseOver() then
				Bar_OnEnter(listEntryButton)
			end
			buttonIndex = buttonIndex + 1
			listEntryIndex = listEntryIndex + 1
		end
		if self.UpdateGamepadFocus then self:UpdateGamepadFocus() end
	end
end	-- InitializeListFrame()

-- ----------------------------------------------------------------------------
-- Tooltip functions and data.
-- ----------------------------------------------------------------------------
-- Use the native tooltip font for the same text size as the previous renderer.
do
	local function InitializeTooltipScrollBar(tooltip)
		if tooltip.Slider then return end
		-- Supply QTip's pixel-offset interface through Forever's native controller.
		-- The library retains ownership of sizing, visibility and pool cleanup.
		local padding = QTip.TooltipManager.PixelSize.CellPadding
		local bar = _G.CreateFrame("EventFrame", nil, tooltip, "MinimalScrollBar")
		bar:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -padding, -padding)
		bar:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -padding, padding)
		bar:SetWidth(8)
		bar:SetInterpolateScroll(false)
		bar:Init(1, 1)
		bar.Track.Begin:Hide()
		bar.Track.Middle:Hide()
		bar.Track.End:Hide()

		local minimum, maximum, value = 0, 0, 0
		local syncing = false
		function bar:GetMinMaxValues() return minimum, maximum end
		function bar:GetValue() return value end
		function bar:SetValue(offset)
			value = math.max(minimum, math.min(maximum, offset))
			tooltip.ScrollFrame:SetVerticalScroll(value)
			syncing = true
			self:SetScrollPercentage(maximum > minimum and (value - minimum) / (maximum - minimum) or 0, true)
			syncing = false
		end
		function bar:SetMinMaxValues(low, high)
			minimum, maximum = low, math.max(low, high)
			local visible = math.max(1, tooltip:GetHeight() - 2 * padding)
			local range = maximum - minimum
			-- Keep the thumb compact even when only a few source rows overflow.
			self:SetVisibleExtentPercentage(math.min(0.2, visible / (visible + range)))
			self:SetPanExtentPercentage(range > 0 and math.min(1, tooltip.ScrollStep / range) or 1)
			self:SetValue(value)
		end
		bar:RegisterCallback(_G.ScrollBarMixin.Event.OnScroll, function(_, percentage)
			if syncing then return end
			value = minimum + percentage * (maximum - minimum)
			tooltip.ScrollFrame:SetVerticalScroll(value)
		end, bar)
		bar:EnableMouseWheel(true)
		bar:SetScript("OnMouseWheel", function(_, delta)
			bar:SetValue(value - delta * tooltip.ScrollStep)
		end)
		bar:Hide()
		tooltip.Slider = bar
	end

	local function AddSectionSeparator()
		-- Reserve space around a separate line so fractional scales and reused
		-- rows cannot hide the divider beneath the adjacent text.
		local row = acquire_tip:AddSeparator(8, 0, 0, 0, 0)
		local line = row.ackisSeparator
		if not line then
			line = row:CreateTexture(nil, "OVERLAY")
			-- Absolute edges are snapped after layout; don't round the offsets twice.
			line:SetRoundLayoutToNearestPixel(false)
			line:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
			line:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -4)
			line:SetColorTexture(0.75, 0.6, 0.35, 0.65)
			row.ackisSeparator = line
		end
		line.ackisRow = row
		line.ackisAlignedTop = nil
		-- UI units also depend on physical screen resolution, not just UI scale.
		line:SetHeight(_G.PixelUtil.GetPixelToUIUnitFactor() / acquire_tip:GetEffectiveScale())
		line:Show()
		separatorTextures[#separatorTextures + 1] = line
	end

	-- I want to do a bit more comprehensive tooltip processing. Things like changing font sizes,
	-- adding padding to the left hand side, and using better color handling. So... this function
	-- will do that for me.
	--    leftPad,            -- number of times to pad two spaces on left side
	--    textSize,           -- add to or subtract from addon.db.profile.tooltip.acquire_fontsize to get fontsize
	--    useNarrowFont,      -- retained for acquire-data callback compatibility
	--    leftText,           -- left-hand string
	--    leftColor,          -- color values for left-hand side
	--    rightText,          -- if present, this is the right-hand string
	--    rightColor)         -- if present, color vaues for right-hand side
	local function ttAdd(leftPad, textSize, useNarrowFont, leftText, leftColor, rightText, rightColor)
		local fontSize = (addon.db.profile.tooltip.acquire_fontsize or 11) + textSize
		local fontObject = _G.GameTooltipText
		leftText = ("    "):rep(leftPad or 0) .. (leftText or "")
		local width = math.ceil(fontSize * 37.5)
		local row = acquire_tip:AddRow()
		local left = row:GetCell(1)
		left:SetJustifyH("LEFT")
		left:SetRightPadding(0)
		if rightText then
			width = width / 2
			left:SetLeftPadding(0)
			left:SetMaxWidth(width)
			if fontObject then left:SetFontObject(fontObject) end
			left:SetTextColor(leftColor.r, leftColor.g, leftColor.b)
			left:SetText(leftText)

			local right = row:GetCell(2)
			right:SetJustifyH("RIGHT")
			right:SetLeftPadding(0)
			right:SetRightPadding(0)
			right:SetMaxWidth(width)
			if fontObject then right:SetFontObject(fontObject) end
			right:SetTextColor(rightColor.r, rightColor.g, rightColor.b)
			right:SetText(tostring(rightText))
		else
			left:SetColSpan(2)
			left:SetLeftPadding(2)
			left:SetMaxWidth(width)
			if fontObject then left:SetFontObject(fontObject) end
			left:SetTextColor(leftColor.r, leftColor.g, leftColor.b)
			left:SetText(leftText)
		end
	end

	-- ----------------------------------------------------------------------------
	-- Public API function for displaying a recipe's acquire data.
	-- * The addline_func paramater must be a function which accepts the same
	-- * arguments as ARL's ttAdd function.
	-- ----------------------------------------------------------------------------
	function addon:DisplayAcquireData(recipeSpellID, acquireTypeID, localizedLocationName, addline_func, separator_func)
		local recipe = private.recipe_list[recipeSpellID]
		if not recipe then
			return
		end

		local sources = {}
		for acquireType, acquireData in recipe:AcquirePairs() do
			if not acquireTypeID or acquireType:ID() == acquireTypeID then
				sources[#sources + 1] = {kind = acquireType, data = acquireData}
			end
		end
		table.sort(sources, function(a, b) return a.kind:ID() < b.kind:ID() end)
		local hasDisplayedSource = false
		for _, source in ipairs(sources) do
			local addSourceLine = addline_func
			if separator_func then
				local sourceStarted = false
				addSourceLine = function(...)
					if not sourceStarted then
						if hasDisplayedSource then separator_func() end
						sourceStarted = true
						hasDisplayedSource = true
					end
					return addline_func(...)
				end
			end
			local identifiers = {}
			for identifier in pairs(source.data) do identifiers[#identifiers + 1] = identifier end
			table.sort(identifiers, function(a, b)
				local entityA, entityB = source.kind:GetEntity(a), source.kind:GetEntity(b)
				local nameA, nameB = tostring(entityA and entityA.name or a), tostring(entityB and entityB.name or b)
				if nameA == nameB then return tostring(a) < tostring(b) end
				return nameA < nameB
			end)
			for _, identifier in ipairs(identifiers) do
				source.kind:InsertTooltipText(recipe, identifier, localizedLocationName, source.data[identifier], addSourceLine)
			end
			if #identifiers == 0 then
				source.kind:InsertTooltipText(recipe, nil, localizedLocationName, nil, addSourceLine)
			end
		end
	end

	-- ----------------------------------------------------------------------------
	-- Main tooltip function.
	-- ----------------------------------------------------------------------------
	local function InitializeTooltips(fromGamepad)
		local acquireTooltipAnchor = addon.db.profile.acquiretooltiplocation
		local MainPanel = addon.Frame

		if acquireTooltipAnchor == _G.OFF then
			ReleaseAcquireTooltip()
		else
			acquire_tip = QTip:AcquireTooltip(private.addon_name .. " Tooltip", 2, "LEFT", "LEFT")
			acquire_tip:ClearAllPoints()
			ClearTooltipSeparators()
			acquire_tip:Clear()
			acquire_tip:SetCellMarginV(2)
			InitializeTooltipScrollBar(acquire_tip)
			acquire_tip:SetScale(addon.db.profile.tooltip.scale or 1)
			if not acquire_tip.ackisSeparatorAligner then
				local aligner = _G.CreateFrame("Frame", nil, acquire_tip)
				aligner:SetScript("OnUpdate", AlignTooltipSeparators)
				acquire_tip.ackisSeparatorAligner = aligner
			end
			acquire_tip.ackisSeparatorAligner:Show()
			acquire_tip:SetClampedToScreen(true)
			if acquire_tip.Slider then acquire_tip.Slider:SetValue(0) end
			acquire_tip.ScrollFrame:SetVerticalScroll(0)

			if _G.TipTac and _G.TipTac.AddModifiedTip then
				_G.TipTac:AddModifiedTip(acquire_tip, true)
			end

			if fromGamepad and (acquireTooltipAnchor == "Right" or acquireTooltipAnchor == "Mouse") then
				acquire_tip:SetPoint("TOPLEFT", MainPanel, "TOPRIGHT", 4, 0)
			elseif acquireTooltipAnchor == "Right" then
				acquire_tip:SetPoint("TOPLEFT", MainPanel, "TOPRIGHT", MainPanel.is_expanded and -90 or -35, 0)
			elseif acquireTooltipAnchor == "Left" then
				acquire_tip:SetPoint("TOPRIGHT", MainPanel, "TOPLEFT")
			elseif acquireTooltipAnchor == "Top" then
				acquire_tip:SetPoint("BOTTOMLEFT", MainPanel, "TOPLEFT")
			elseif acquireTooltipAnchor == "Bottom" then
				acquire_tip:SetPoint("TOPLEFT", MainPanel, "BOTTOMLEFT", 0, 55)
			elseif acquireTooltipAnchor == "Mouse" then
				local x, y = _G.GetCursorPosition()
				local uiscale = _G.UIParent:GetEffectiveScale()
				acquire_tip:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", x / uiscale, y / uiscale)
			end

		end
	end

	local function ShowProductTooltip(recipe, showProduct)
		local spellTooltipAnchor = addon.db.profile.spelltooltiplocation
		local spellTooltipOwner = acquire_tip or addon.Frame

		-- The second tooltip is an explicit product preview, never a hover tip.
		if not showProduct then
			SpellTooltip:Hide()
		else
            if not spellTooltipAnchor or spellTooltipAnchor == _G.OFF then
                spellTooltipAnchor = "Right"
            end
            SpellTooltip:SetOwner(spellTooltipOwner, "ANCHOR_NONE")
            SpellTooltip:ClearAllPoints()

            if spellTooltipAnchor == "Top" then
                SpellTooltip:SetPoint("BOTTOMLEFT", spellTooltipOwner, "TOPLEFT")
            elseif spellTooltipAnchor == "Bottom" then
                SpellTooltip:SetPoint("TOPLEFT", spellTooltipOwner, "BOTTOMLEFT")
            elseif spellTooltipAnchor == "Left" then
                SpellTooltip:SetPoint("TOPRIGHT", spellTooltipOwner, "TOPLEFT")
            elseif spellTooltipAnchor == "Right" then
                SpellTooltip:SetPoint("TOPLEFT", spellTooltipOwner, "TOPRIGHT")
            end

            -- Add TipTac Support
            if _G.TipTac and _G.TipTac.AddModifiedTip and not SpellTooltip.tiptac then
                _G.TipTac:AddModifiedTip(SpellTooltip)
                SpellTooltip.tiptac = true
            end

            SpellTooltip:SetScale(addon.db.profile.tooltip.scale or 1)
            SpellTooltip:SetClampedToScreen(true)
            SpellTooltip:SetHyperlink(CraftedItemTooltipLink(recipe))
            SpellTooltip:Show()
			return SpellTooltip
		end
	end

	local ITEM_BINDING_TYPES = {
		BIND_ON_EQUIP = L["BOEFilter"],
		BIND_ON_PICKUP = L["BOPFilter"],
	}

	local RECIPE_BINDING_TYPES = {
		BIND_ON_EQUIP = L["RecipeBOEFilter"],
		BIND_ON_PICKUP = L["RecipeBOPFilter"],
	}

	function ListItem_ShowTooltip(listEntry, showProduct, fromGamepad)
		if not listEntry then
			return
		end

        if listEntry.guideChapter or listEntry.guideShopping then
            ReleaseAcquireTooltip()
            return private.ShowGuideEntryTooltip(listEntry)
        end
		local recipe = listEntry.recipe

		if not recipe then
			return
		end
		InitializeTooltips(fromGamepad)

		if not acquire_tip then
			local product = ShowProductTooltip(recipe, showProduct)
			return product, product
		end
	local name = recipe:LocalizedName()
	--
	local r,g,b = private.GetItemQualityColor(recipe:QualityID())
		local recipe_item_texture = recipe.crafted_item_id and select(10, private.GetItemInfo(recipe.crafted_item_id))
		local header = acquire_tip:AddHeadingRow():GetCell(1)
		header:SetColSpan(2)
		header:SetJustifyH("CENTER")
		header:SetTextColor(r, g, b)
		header:SetText(name)
		if recipe_item_texture then
			local icon = acquire_tip:AddHeadingRow():GetCell(1)
			icon:SetColSpan(2)
			icon:SetJustifyH("CENTER")
			icon:SetTextColor(1, 1, 1)
			icon:SetText(("|T%s:30:30|t"):format(recipe_item_texture))
		end

		if addon.db.profile.exclusionlist[recipe:SpellID()] then
			ttAdd(0, -1, true, L["RECIPE_EXCLUDED"], private.DIFFICULTY_COLORS.impossible)
		end

		-- Add in skill level requirement, colored correctly
		local skill_level = private.current_profession_scanlevel
		local color_type

		if recipe.skill_level > skill_level then
			color_type = "impossible"
		elseif recipe.skill_thresholds_unknown then
			color_type = "unknown"
		elseif skill_level >= recipe.trivial_level then
			color_type = "trivial"
		elseif skill_level >= recipe.easy_level then
			color_type = "easy"
		elseif skill_level >= recipe.medium_level then
			color_type = "medium"
		elseif skill_level >= recipe.optimal_level then
			color_type = "optimal"
		else
			color_type = "trivial"
		end
		ttAdd(0, -1, false, ("%s:"):format(_G.SKILL_LEVEL), BASIC_COLORS.normal, recipe.skill_level, private.DIFFICULTY_COLORS[color_type])

		if recipe.skill_thresholds_unknown then
			ttAdd(0, -1, true, L["SKILL_THRESHOLDS_UNAVAILABLE"], BASIC_COLORS.white)
		end

		local _, recipe_item_binding = recipe:RecipeItem()
		local _, crafted_item_binding = recipe:CraftedItem()
		local bindings = {}
		if recipe_item_binding then bindings[#bindings + 1] = RECIPE_BINDING_TYPES[recipe_item_binding] end
		if crafted_item_binding then bindings[#bindings + 1] = ITEM_BINDING_TYPES[crafted_item_binding] end
		if #bindings > 0 then
			AddSectionSeparator()
			ttAdd(0, -1, true, table.concat(bindings, " · "), BASIC_COLORS.normal)
		end

		local recipe_specialty = recipe.specialty

		if recipe_specialty then
			local color_table = (recipe_specialty == private.current_profession_specialty) and BASIC_COLORS.white or private.DIFFICULTY_COLORS.impossible
			ttAdd(0, -1, false, _G.ITEM_REQ_SKILL:format(private.GetSpellName(recipe_specialty)), color_table)
		end
		AddSectionSeparator()
        ttAdd(0, -1, false, _G.SOURCES .. _G.HEADER_COLON, BASIC_COLORS.normal)

		local listEntryAcquireType = listEntry:AcquireType()
        local listEntryLocation = listEntry:Location()
		local tooltipLocationName = listEntryLocation and listEntryLocation ~= private.WorldDropLocation
			and listEntryLocation:LocalizedName() or nil
		addon:DisplayAcquireData(recipe:SpellID(), listEntryAcquireType and listEntryAcquireType:ID() or nil, tooltipLocationName, ttAdd, AddSectionSeparator)

		if recipe:MerchantFavor() then
			AddSectionSeparator()
			private.AddMerchantFavorTooltipLine(recipe, ttAdd)
		end

		if not addon.db.profile.hide_tooltip_hint then
			local hint_color = private.CATEGORY_COLORS.hint

			AddSectionSeparator()
			ttAdd(0, -1, true, L["CLICK"], hint_color)
			ttAdd(0, -1, true, L["ALT_CLICK"], hint_color)
			ttAdd(0, -1, true, L["CTRL_CLICK"], hint_color)
			ttAdd(0, -1, true, L["SHIFT_CLICK"], hint_color)
            ttAdd(0, -1, true, L["SHIFT_RIGHT_CLICK"], hint_color)

			if recipe:HasCoordinates() then
				ttAdd(0, -1, true, L["CTRL_SHIFT_CLICK"], hint_color)
			end
		end
		acquire_tip:Show()
		-- Measure against the whole screen, then restore the requested anchor.
		-- QTip otherwise shortens tall tips at their initial anchor before the
		-- client can clamp them, even when their full height would fit on screen.
		local points = {}
		for index = 1, acquire_tip:GetNumPoints() do
			points[index] = { acquire_tip:GetPoint(index) }
		end
		local screenHeight = _G.UIParent:GetHeight() * _G.UIParent:GetEffectiveScale() / acquire_tip:GetEffectiveScale()
		acquire_tip:SetMaxHeight(math.max(1, screenHeight - 24))
		acquire_tip:ClearAllPoints()
		acquire_tip:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 12, -12)
		acquire_tip:UpdateLayout()
		acquire_tip:ClearAllPoints()
		for _, point in ipairs(points) do acquire_tip:SetPoint(unpack(point)) end
		acquire_tip:SetClampedToScreen(true)
		AlignTooltipSeparators()
		return acquire_tip, ShowProductTooltip(recipe, showProduct)
	end
end	-- do
