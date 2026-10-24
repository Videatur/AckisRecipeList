--[[
Copyright (c) 2009 - 2012 Ackis <John Pasula>
All rights reserved by the original author Ackis.
]]

-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------
local select = _G.select

local math = _G.math
local table = _G.table

local ipairs, pairs = _G.ipairs, _G.pairs

local tonumber = _G.tonumber
local tostring = _G.tostring

-- Use _G.SOUNDKIT directly when available (guarded where used)

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private	= ...

local LibStub = _G.LibStub
local addon	= LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L		= LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

function private.InitializeFrame()
    -- Tabs use templates from this load-on-demand Blizzard addon.
    if not _G.C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        local loaded, reason = _G.C_AddOns.LoadAddOn("Blizzard_Professions")
        if not loaded then
            addon:Print("Unable to load Blizzard_Professions: " .. tostring(reason))
            return false
        end
    end
	-- ----------------------------------------------------------------------------
	-- Create the MainPanel and set its values
	-- ----------------------------------------------------------------------------
	-- Use Blizzard's real portrait-panel template rather than drawing a
	-- backdrop imitation.  This supplies the native border, title treatment,
	-- close button and circular portrait used by Forever panels.
	local MainPanel = private.CreateFrameWithBackdrop("Frame", "ARL_MainPanel", _G.UIParent, "PortraitFrameTemplate")

	-- The panel width changes when contracting and expanding - store it for later use.
	MainPanel.normal_width = 384
	MainPanel.expanded_width = 780

	MainPanel:SetWidth(MainPanel.normal_width)
	MainPanel:SetHeight(440)
	MainPanel:SetFrameStrata("MEDIUM")
	MainPanel:SetToplevel(true)
	MainPanel:SetClampedToScreen(true)
	MainPanel:SetClampRectInsets(0, 0, 0, -32)

	MainPanel:SetHitRectInsets(0, 0, 0, 0)
	MainPanel:EnableMouse(true)
	MainPanel:EnableKeyboard(true)
	MainPanel:SetMovable(true)

	MainPanel.is_expanded = false

	-- Let the user banish the MainPanel with the ESC key.
	table.insert(_G.UISpecialFrames, "ARL_MainPanel")
	addon.Frame = MainPanel

	do
		local title_bar = MainPanel.TitleContainer.TitleText
		title_bar:SetFontObject("GameFontHighlight")
		title_bar:SetJustifyH("CENTER")
		MainPanel.title_bar = title_bar

		MainPanel:Hide()
	end	-- do block

	-- ----------------------------------------------------------------------------
	-- MainPanel scripts/functions.
	-- ----------------------------------------------------------------------------
	MainPanel:SetScript("OnHide", function(self)
		if self.arlDragging then
			self:StopMovingOrSizing()
			self.arlDragging = nil
		end
		private.DismissDialogs()
		private.CleanupPanel()
		private.UnregisterUIEvents()
	end)

	MainPanel:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or self.arlProfessionDocked or not self:IsMovable() then
			return
		end
		self:StartMoving()
		self.arlDragging = true
	end)

	MainPanel:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" or not self.arlDragging then return end
		self.arlDragging = nil
		self:StopMovingOrSizing()
		-- A docked panel's anchors belong to ProfessionsFrame, not UIParent.
		-- Never persist them as the independent window's saved position.
		if self.arlProfessionDocked or not self:IsMovable() then return end

		local opts = addon.db.profile.frameopts
		local from, _, to, x, y = self:GetPoint()

		opts.anchorFrom = from
		opts.anchorTo = to

		if self.is_expanded then
			if opts.anchorFrom == "TOPLEFT" or opts.anchorFrom == "LEFT" or opts.anchorFrom == "BOTTOMLEFT" then
				opts.offsetx = x
			elseif opts.anchorFrom == "TOP" or opts.anchorFrom == "CENTER" or opts.anchorFrom == "BOTTOM" then
				opts.offsetx = x - 151 / 2
			elseif opts.anchorFrom == "TOPRIGHT" or opts.anchorFrom == "RIGHT" or opts.anchorFrom == "BOTTOMRIGHT" then
				opts.offsetx = x - 151
			end
		else
			opts.offsetx = x
		end
		opts.offsety = y
	end)

	-- ----------------------------------------------------------------------------
	-- Displays the main GUI frame.
	-- ----------------------------------------------------------------------------
	function MainPanel:Display(isTradeSkillLinked)
		self.is_linked = isTradeSkillLinked
        private.UpdateGuideTabAvailability()
		self.prof_button:SetTexture()

		local editbox = self.search_editbox
        if private.CurrentProfession ~= private.PreviousProfession then
			editbox.prev_search = nil
			editbox:SetText("")
		end

		if editbox.prev_search then
			editbox:SetText(editbox.prev_search)
		end

		-- The first time this function is called, everything in the expanded section of the MainPanel must be created.
		if private.InitializeFilterPanel then
			private.InitializeFilterPanel()
        end
        local currentProfession = private.CurrentProfession
		local professionModule = currentProfession:Module()
		local panel

		if professionModule.InitializeItemFilters then
			local panelName = "items_" .. currentProfession:Name():lower()
			panel = self.filter_menu:CreateSubMenu(panelName)

			self.filter_menu.item[panelName] = self.filter_menu[panelName]
			self.filter_menu[panelName] = nil

            professionModule:InitializeItemFilters(panel)
		else
			panel = self.filter_menu.item["items_" .. currentProfession:Name():lower()]
		end
		private.UpdateFilterMarks()

		if panel then
			self.menu_toggle_item.icon_texture:SetVertexColor(1, 1, 1)
			self.menu_toggle_item.bg_texture:SetVertexColor(1, 1, 1)
			self.menu_toggle_item:Enable()

			if self.filter_menu.item:IsVisible() then
				self.filter_menu.item:Hide()
				self.filter_menu.item:Show()
			end
		else
			self.menu_toggle_item.icon_texture:SetVertexColor(0.50, 0.50, 0.50)
			self.menu_toggle_item.bg_texture:SetVertexColor(0.50, 0.50, 0.50)
			self.menu_toggle_item:Disable()

			if self.filter_menu.item:IsVisible() then
				self.filter_menu.item:Hide()
				self.menu_toggle_item:SetChecked(false)

				self.menu_toggle_general:SetChecked(true)
				self.filter_menu.general:Show()
				self.filter_menu:Show()
			end
		end

		-- If there is no current tab, this is the first time the panel has been
		-- shown so things must be initialized. In this case, MainPanel.list_frame:Update()
		-- will be called by the tab's OnClick handler.
		if self.current_tab then
			self.list_frame:Update(nil, false)
		else
			local currentTab = self.tabs[addon.db.profile.current_tab]
			currentTab:GetScript("OnClick")(currentTab)

			self.current_tab = currentTab
		end
		self.sort_button:SetTextures()
		self:SyncFilterToggle()

		self:UpdateTitle()
		-- Refresh portrait texture explicitly to avoid any external interference.
		if self.prof_button and self.prof_button.SetTexture then
			self.prof_button:SetTexture()
		end
		self:Show()
	end

	do
		-- ----------------------------------------------------------------------------
		-- Restore the panel's position on the screen.
		-- ----------------------------------------------------------------------------
		local function Reset_Position(self)
			local opts = addon.db.profile.frameopts
			local FixedOffsetX = opts.offsetx

			self:ClearAllPoints()

			if opts.anchorTo == "" then	-- no values yet, clamp to whatever frame is appropriate
				self:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
			else
				if self.is_expanded then
					if opts.anchorFrom == "TOPLEFT" or opts.anchorFrom == "LEFT" or opts.anchorFrom == "BOTTOMLEFT" then
						FixedOffsetX = opts.offsetx
					elseif opts.anchorFrom == "TOP" or opts.anchorFrom == "CENTER" or opts.anchorFrom == "BOTTOM" then
						FixedOffsetX = opts.offsetx + 151/2
					elseif opts.anchorFrom == "TOPRIGHT" or opts.anchorFrom == "RIGHT" or opts.anchorFrom == "BOTTOMRIGHT" then
						FixedOffsetX = opts.offsetx + 151
					end
				end
				self:SetPoint(opts.anchorFrom, _G.UIParent, opts.anchorTo, FixedOffsetX, opts.offsety)
			end
			self:SetScale(addon.db.profile.frameopts.uiscale)
		end

		MainPanel:SetScript("OnShow", function(self)
			Reset_Position(self)
			private.RegisterUIEvents()
		end)
	end	-- do-block

	do
		local VALID_CATEGORY = {
			["general"]	= true,
			["obtain"]	= true,
			["binding"]	= true,
			["item"]	= true,
			["quality"]	= true,
			["player"]	= true,
			["rep"]		= true,
		}

		function MainPanel:ToggleState()
			local x, y = self:GetLeft(), self:GetBottom()

			if self.is_expanded then
				-- Hide the category buttons
				for category in pairs(self.filter_menu) do
					if VALID_CATEGORY[category] then
						self["menu_toggle_" .. category]:Hide()
					end
				end

				self.filter_reset:Hide()
				self.filter_menu:Hide()

				if _G.SOUNDKIT and _G.PlaySound then
					_G.PlaySound(_G.SOUNDKIT.IG_CHARACTER_INFO_CLOSE, "Master")
				end

				self:SetWidth(self.normal_width)
				self:SetHeight(440)
				self:SetHitRectInsets(0, 0, 0, 0)
				self:SetClampRectInsets(0, 0, 0, -32)


			else
				local found_active = false

				-- Show the category buttons. If one has been selected, show its information in the panel.
				for category in pairs(MainPanel.filter_menu) do
					local toggle = "menu_toggle_" .. category

					if VALID_CATEGORY[category] then
						MainPanel[toggle]:Show()

						if MainPanel[toggle]:GetChecked() then
							found_active = true
							MainPanel.filter_menu[category]:Show()
							MainPanel.filter_menu:Show()
						end
					end
				end

				-- If nothing was checked, default to the general filters.
				if not found_active then
					MainPanel.menu_toggle_general:SetChecked(true)
					MainPanel.filter_menu.general:Show()
					MainPanel.filter_menu:Show()
				end
				-- Ensure the toggle container row is visible when expanded
				if MainPanel.filter_menu and MainPanel.filter_menu.toggle_container then
					MainPanel.filter_menu.toggle_container:Show()
				end
				MainPanel.filter_reset:Show()

				if _G.SOUNDKIT and _G.PlaySound then
					_G.PlaySound(_G.SOUNDKIT.IG_CHARACTER_INFO_OPEN, "Master")
				end

				self:SetWidth(self.expanded_width)
				self:SetHeight(450)
				self:SetHitRectInsets(0, 0, 0, 0)
				self:SetClampRectInsets(0, 0, 0, -32)


			end
			self.is_expanded = not self.is_expanded
			self:SyncFilterToggle()

			self:ClearAllPoints()
			self:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", x, y)
			self:UpdateTitle()
		end
	end	-- do-block

	function MainPanel:UpdateTitle()
		local localizedProfessionName = private.CurrentProfession:LocalizedName()

		if not self.is_expanded then
			self.title_bar:SetFormattedText(private.SetTextColor(private.BASIC_COLORS.normal.hex, "ARLC (%s) - %s"), addon.version, localizedProfessionName)
			return
		end

		local total, active = 0, 0
		for filter, info in pairs(self.filter_menu.value_map) do
			if info.svroot then
				if info.svroot[filter] == true then
					active = active + 1
				end
				total = total + 1
			end
		end

		self.title_bar:SetFormattedText(private.SetTextColor(private.BASIC_COLORS.normal.hex, "ARLC (%s) - %s (%d/%d %s)"), addon.version, localizedProfessionName, active, total, _G.FILTERS)
	end

	-- ----------------------------------------------------------------------------
	-- Create the profession-cycling button and assign its values.
	-- ----------------------------------------------------------------------------
	local profession_cycler = _G.CreateFrame("Button", nil, MainPanel)
	if MainPanel.PortraitContainer then
		profession_cycler:SetAllPoints(MainPanel.PortraitContainer)
	else
		profession_cycler:SetSize(60, 60)
		profession_cycler:SetPoint("TOPLEFT", 7, -6)
	end
	profession_cycler:SetHighlightTexture([[Interface\Cooldown\ping4]])
	profession_cycler:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	profession_cycler:SetFrameLevel(MainPanel:GetFrameLevel() + 5)
	MainPanel.prof_button = profession_cycler

	-- The portrait comes from PortraitFrameTemplate, giving the profession icon
	-- the same native frame and mask as other Blizzard windows.
	local profession_texture = MainPanel.Portrait or MainPanel:CreateTexture(nil, "ARTWORK")
	if profession_texture ~= MainPanel.Portrait then
		profession_texture:SetAllPoints(profession_cycler)
		profession_texture:SetDrawLayer("ARTWORK", 0)
	end
	profession_texture:SetVertexColor(1, 1, 1, 1)
	profession_texture:SetAlpha(1)
	MainPanel.profession_texture = profession_texture

	-- Apply a circular mask if supported.
	if profession_texture ~= MainPanel.Portrait and profession_texture.AddMaskTexture and profession_cycler.CreateMaskTexture then
		local portrait_mask = profession_cycler:CreateMaskTexture(nil, "ARTWORK")
		portrait_mask:SetAllPoints(profession_cycler)
		portrait_mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
		profession_texture:AddMaskTexture(portrait_mask)
		MainPanel.profession_mask = portrait_mask
	end


	-- ----------------------------------------------------------------------------
	-- ProfCycle scripts/functions.
	-- ----------------------------------------------------------------------------
	do
		-- Changes to the TradeSkill handling in Legion necessitate a 0.1 second timer to run this function.
		local function ScanCurrentProfession()
			addon:Scan()
		end

		local availableProfessions = {}

		profession_cycler:SetScript("OnClick", function(self, button_name, down)
			local player = private.Player
			table.wipe(availableProfessions)

			for index = 1, #private.ORDERED_LOCALIZED_PROFESSION_NAMES do
                local localizedProfessionName = private.ORDERED_LOCALIZED_PROFESSION_NAMES[index]

				if player.professions[localizedProfessionName] then
					if not private.Professions[localizedProfessionName] then
						addon:InitializeProfession(localizedProfessionName, true) -- suppress popups while cycling
					end

					availableProfessions[#availableProfessions + 1] = private.Professions[localizedProfessionName]
				end
			end

			local currentProfessionIndex
			for index = 1, #availableProfessions do
				if availableProfessions[index] == private.CurrentProfession then
					currentProfessionIndex = index
					break
				end
			end

            if currentProfessionIndex then
                if button_name == "LeftButton" then
                    currentProfessionIndex = currentProfessionIndex + 1

                    if currentProfessionIndex > #availableProfessions then
                        currentProfessionIndex = 1
                    end
                elseif button_name == "RightButton" then
                    currentProfessionIndex = currentProfessionIndex - 1

                    if currentProfessionIndex < 1 then
                        currentProfessionIndex = #availableProfessions
                    end
                end

				if _G.SOUNDKIT and _G.PlaySound then
					_G.PlaySound(_G.SOUNDKIT.IG_CHARACTER_NPC_SELECT, "Master")
				end

                -- If not shown, save the current sound effects setting then set it to 0.
				local cVarSfx
				local isPanelShown = (addon.scan_button and addon.scan_button.GetParent and addon.scan_button:GetParent():IsVisible()) or false
                if not isPanelShown then
                    cVarSfx = private.GetCVar("Sound_EnableSFX")
                    private.SetCVar("Sound_EnableSFX", "0")
                end

				local activationSpellName = availableProfessions[currentProfessionIndex]:ActivationSpellName()

                -- Forever protects CastSpellByName.  Profession switching must
                -- be initiated by the player; scan the currently open one.
                addon:Print("Open the selected profession from the spellbook before scanning.")
                ScanCurrentProfession()

                if not isPanelShown then
                    _G.CloseTradeSkill()
                    private.SetCVar("Sound_EnableSFX", cVarSfx or "1")
				end
            end
		end)
	end -- do-block

	function profession_cycler:SetTexture()
		-- Use only our profession icon (no reads/writes to Blizzard portrait).
		local texPath
		if private.CurrentProfession and private.CurrentProfession.WaypointIconTexture then
			texPath = private.CurrentProfession:WaypointIconTexture()
		end
		texPath = texPath or [[Interface\Icons\INV_Misc_Book_11]]
		if MainPanel.SetPortraitToAsset then
			MainPanel:SetPortraitToAsset(texPath)
			if MainPanel.profession_texture and MainPanel.profession_texture ~= MainPanel.Portrait then
				MainPanel.profession_texture:Hide()
			end
			return
		end

		local portrait = MainPanel.profession_texture
		if portrait and portrait.SetTexture then
			portrait:SetTexture(texPath)
			portrait:SetVertexColor(1,1,1,1)
			portrait:SetAlpha(1)
			portrait:Show()
		end
	end

	-- ----------------------------------------------------------------------------
	-- The search entry box and associated methods.
	-- ----------------------------------------------------------------------------
	local SearchRecipes
	do
		local searchIndex = {}
		local indexProfession = nil
		local indexValid = false

		local function AddSearchText(parts, value)
			if value then
				parts[#parts + 1] = tostring(value):lower()
			end
		end

		local function AddItemSearchText(parts, itemID)
			if itemID then
				AddSearchText(parts, itemID)
				AddSearchText(parts, private.GetItemInfo(itemID))
			end
		end

		local function BuildSearchIndex()
			local profession = private.CurrentProfession
			if not profession or not profession.Recipes then
				return
			end

			if indexProfession == profession and indexValid then
				return
			end

			table.wipe(searchIndex)
			indexProfession = profession

			for spellID, recipe in pairs(profession.Recipes) do
				local parts = {}
				AddSearchText(parts, recipe:LocalizedName())
				AddSearchText(parts, spellID)
				AddSearchText(parts, recipe.skill_level)
				AddSearchText(parts, recipe.specialty)
				AddSearchText(parts, private.ITEM_QUALITY_NAMES[recipe:QualityID()])
				AddItemSearchText(parts, recipe:RecipeItem())
				AddItemSearchText(parts, recipe:CraftedItem())

				for acquireType, acquireData in recipe:AcquirePairs() do
					AddSearchText(parts, acquireType:Name())
					for identifier, sourceData in pairs(acquireData) do
						if acquireType == private.AcquireTypes.Quest then
							AddSearchText(parts, private.quest_names[identifier])
						end
						local entity = acquireType:GetEntity(identifier)
						if entity then
							AddSearchText(parts, entity.name)
							AddSearchText(parts, entity.Location and entity.Location:LocalizedName())
						elseif type(identifier) == "string" then
							AddSearchText(parts, identifier)
						end

						-- Reputation acquisition data contains vendors one level deeper.
						if acquireType == private.AcquireTypes.Reputation then
							for _, vendors in pairs(sourceData) do
								for vendorID in pairs(vendors) do
									local vendor = private.AcquireTypes.Vendor:GetEntity(vendorID)
									if vendor then
										AddSearchText(parts, vendor.name)
										AddSearchText(parts, vendor.Location and vendor.Location:LocalizedName())
									end
								end
							end
						end
					end
				end
				searchIndex[recipe] = table.concat(parts, " ")
			end
			for _, location in pairs(private.Locations) do
				local name = location:LocalizedName()
				if name then
					local lowerName = name:lower()
					for recipe in location:RecipePairs() do
						if searchIndex[recipe] then
							searchIndex[recipe] = searchIndex[recipe] .. " " .. lowerName
						end
					end
				end
			end
			indexValid = true
		end

		private.InvalidateSearchIndex = function()
			indexValid = false
		end

		-- Every word must match somewhere in the recipe's indexed details.
		function SearchRecipes(searchPattern)
			local profession = private.CurrentProfession
			if not profession or not profession.Recipes then
				return
			end
			local terms = {}
			for term in (searchPattern or ""):lower():gmatch("%S+") do
				terms[#terms + 1] = term
			end
			if #terms > 0 then
				BuildSearchIndex()
			end

			for _, recipe in pairs(profession.Recipes) do
				recipe:RemoveState("RELEVANT")
				if #terms > 0 then
					local text = searchIndex[recipe] or ""
					local matches = true
					for index = 1, #terms do
						if not text:find(terms[index], 1, true) then
							matches = false
							break
						end
					end
					if matches then
						recipe:AddState("RELEVANT")
					end
				end
			end
		end
	end	-- do-block

	-- ----------------------------------------------------------------------------
	-- Search EditBox
	-- ----------------------------------------------------------------------------
	local SearchBox = _G.CreateFrame("EditBox", "ARL_SearchBox", MainPanel, "SearchBoxTemplate")

	SearchBox:EnableMouse(true)
	SearchBox:SetAutoFocus(false)
	SearchBox:SetFontObject("ChatFontSmall")
	SearchBox:SetWidth(230)
	SearchBox:SetHeight(12)
	SearchBox:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 75, -39)
	SearchBox:Show()

	MainPanel.search_editbox = SearchBox

	SearchBox:SetHistoryLines(10)

	-- Allow removal of focus from the SearchBox by clicking on the WorldFrame.
	do
		local old_x, old_y, click_time

		_G.WorldFrame:HookScript("OnMouseDown", function(frame, ...)
			if not SearchBox:HasFocus() then
				return
			end
			old_x, old_y = _G.GetCursorPosition()
			click_time = _G.GetTime()
		end)

		_G.WorldFrame:HookScript("OnMouseUp", function(frame, ...)
			if not SearchBox:HasFocus() then
				return
			end
			local x, y = _G.GetCursorPosition()

			if not old_x or not old_y or not x or not y or not click_time then
				SearchBox:ClearFocus()
				return
			end

			if (math.abs(x - old_x) + math.abs(y - old_y)) <= 5 and _G.GetTime() - click_time < .5 then
				SearchBox:ClearFocus()
			end
		end)
	end

	-- Re-evaluates the current search after asynchronously loaded source names change.
	function SearchBox:RefreshResults()
		local text = self:GetText()
		SearchRecipes(text ~= _G.SEARCH and text or nil)
	end

	function SearchBox:Reset()
		SearchRecipes(nil)
		self.prev_search = nil
		if private.CurrentProfession and MainPanel.list_frame and MainPanel.current_tab then
			MainPanel.list_frame:Update(nil, false)
		end
	end

	-- If there is text in the search box, return the recipe's RELEVANT state.
	function SearchBox:MatchesRecipe(recipe)
		local editbox_text = self:GetText()

		if editbox_text ~= _G.SEARCH and editbox_text:find("%S") then
			return recipe:HasState("RELEVANT")
		end
		return true
	end

	SearchBox:HookScript("OnEnterPressed", function(self)
		local searchtext = self:GetText():trim()

		if searchtext == "" then
			self:Reset()
			return
		end
		self:HighlightText()

		if searchtext == _G.SEARCH then
			return
		end
		self.prev_search = searchtext

		self:AddHistoryLine(searchtext)
		SearchRecipes(searchtext)
		MainPanel.list_frame:Update(nil, false)
	end)

	SearchBox:HookScript("OnEditFocusLost", function(self)
		_G.SearchBoxTemplate_OnEditFocusLost(self)

		local text = self:GetText():trim()
		if text ~= "" and text ~= _G.SEARCH then
			self:AddHistoryLine(text)
		end
	end)


	SearchBox:SetScript("OnTextSet", function(self)
		if not self:HasFocus() and self:GetText() == "" then
			self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
			self.clearButton:Hide()
		else
			self.searchIcon:SetVertexColor(1.0, 1.0, 1.0)
			self.clearButton:Show()
		end

	end)

	do
		local last_update = 0
		local updater = _G.CreateFrame("Frame", nil, _G.UIParent)

		updater:Hide()
		updater:SetScript("OnUpdate", function(self, elapsed)
			last_update = last_update + elapsed

			if last_update < 0.12 then
				return
			end
			local search_text = SearchBox:GetText()
			last_update = 0
			self:Hide()
			if search_text ~= "" and search_text ~= _G.SEARCH and search_text:find("%S") then
				SearchBox.prev_search = search_text
				SearchRecipes(search_text)
				MainPanel.list_frame:Update(nil, false)
			else
				SearchBox:Reset()
			end
		end)

		SearchBox:HookScript("OnTextChanged", function(self)
			local text = self:GetText()

			if text ~= "" and text ~= _G.SEARCH and text:find("%S") then
				updater:Show()
				last_update = 0
			else
				updater:Hide()
				self:Reset()
			end
		end)

		local itemInfoWatcher = _G.CreateFrame("Frame")
		itemInfoWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		itemInfoWatcher:SetScript("OnEvent", function()
			private.InvalidateSearchIndex()
			local text = SearchBox:GetText()
			if MainPanel:IsShown() and text ~= "" and text ~= _G.SEARCH and text:find("%S") then
				updater:Show()
				last_update = 0
			end
		end)
	end	-- do

	-- ----------------------------------------------------------------------------
	-- Create the expand button and set its scripts.
	-- ----------------------------------------------------------------------------
	local expand_button_frame = _G.CreateFrame("Frame", nil, MainPanel)

	expand_button_frame:SetHeight(20)
	expand_button_frame:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 14, -60)

	expand_button_frame.left = expand_button_frame:CreateTexture(nil, "BACKGROUND")
	expand_button_frame.left:SetWidth(8)
	expand_button_frame.left:SetHeight(22)
	expand_button_frame.left:SetPoint("TOPLEFT", expand_button_frame, 0, 4)
	expand_button_frame.left:SetTexture("Interface\\QuestFrame\\UI-QuestLogSortTab-Left")

	expand_button_frame.right = expand_button_frame:CreateTexture(nil, "BACKGROUND")
	expand_button_frame.right:SetWidth(8)
	expand_button_frame.right:SetHeight(22)
	expand_button_frame.right:SetPoint("TOPRIGHT", expand_button_frame, 0, 4)
	expand_button_frame.right:SetTexture("Interface\\QuestFrame\\UI-QuestLogSortTab-Right")

	expand_button_frame.middle = expand_button_frame:CreateTexture(nil, "BACKGROUND")
	expand_button_frame.middle:SetHeight(22)
	expand_button_frame.middle:SetPoint("LEFT", expand_button_frame.left, "RIGHT")
	expand_button_frame.middle:SetPoint("RIGHT", expand_button_frame.right, "LEFT")
	expand_button_frame.middle:SetTexture("Interface\\QuestFrame\\UI-QuestLogSortTab-Middle")

	local expand_button = _G.CreateFrame("Button", nil, MainPanel)
	expand_button:SetSize(16, 17)

	local expand_label = expand_button:CreateFontString(nil, "ARTWORK")
	expand_label:SetFontObject("GameFontNormalSmall")
	expand_label:SetPoint("LEFT", expand_button, "Right", 0, 0)
	expand_label:SetJustifyH("LEFT")
	expand_label:SetText(_G.ALL)

	expand_button:SetFontString(expand_label)
	private.SetTooltipScripts(expand_button, L["EXPANDALL_DESC"])

	-- Make sure the button frame is large enough to hold the localized word for "All"
	expand_button_frame:SetWidth(27 + expand_button:GetFontString():GetStringWidth())

	MainPanel.expand_button = expand_button

	expand_button:SetPoint("LEFT", expand_button_frame.left, "RIGHT", -3, -3)

	expand_button:SetScript("OnClick", function(self, mouse_button, down)
		local currentTab = MainPanel.current_tab
        local currentProfession = private.CurrentProfession
        local localizedProfessionName = currentProfession:LocalizedName()
		local professionExpandButton = currentTab["expand_button_" .. localizedProfessionName]
		local expandMode

		if professionExpandButton and currentTab.ProfessionState and currentTab.ProfessionState[currentProfession] then
			table.wipe(currentTab.ProfessionState[currentProfession])
		else
			if _G.IsShiftKeyDown() then
				expandMode = "deep"
			else
				expandMode = "normal"
			end
		end
		-- MainPanel.list_frame:Update() must be called before the button can be expanded or contracted, since
		-- the button is contracted from there.
		-- If expand_mode is nil, that means expand nothing.
		MainPanel.list_frame:Update(expandMode, false)

		if professionExpandButton then
			self:Contract(currentTab)
		else
			self:Expand(currentTab)
		end
	end)

	-- Same plus/minus artwork as Forever's All Objectives header. Reuse the
	-- native atlases directly so this control does not require loading the tracker.
	function expand_button:SetExpandedArt(expanded)
		local atlas = "ui-questtrackerbutton-" .. (expanded and "collapse-all" or "expand-all")
		self:SetNormalAtlas(atlas)
		self:SetPushedAtlas(atlas .. "-pressed")
		self:SetDisabledAtlas(atlas)
		self:GetDisabledTexture():SetDesaturated(true)
		self:GetDisabledTexture():SetAlpha(0.5)
		self:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
	end
	expand_button:SetExpandedArt(false)

	function expand_button:Expand(currentTab)
		currentTab["expand_button_" .. private.CurrentProfession:LocalizedName()] = true

		self:SetExpandedArt(true)

		private.SetTooltipScripts(self, L["CONTRACTALL_DESC"])
	end

	function expand_button:Contract(currentTab)
		currentTab["expand_button_" .. private.CurrentProfession:LocalizedName()] = nil

		self:SetExpandedArt(false)

		private.SetTooltipScripts(self, L["EXPANDALL_DESC"])
	end

	-- ----------------------------------------------------------------------------
	-- Spellbook-style search options menu.
	-- ----------------------------------------------------------------------------
	local SearchOptions = _G.CreateFrame("DropdownButton", nil, MainPanel, "UIPanelArrowDropdownButtonTemplate")
	SearchOptions:SetSize(18, 18)
	SearchOptions:SetPoint("LEFT", SearchBox, "RIGHT", 5, -2)
	SearchOptions:SetupMenu(function(_, root)
		local option = root:CreateCheckbox(L["Display Exclusions"], function()
			return addon.db.profile.ignoreexclusionlist
		end, function()
			addon.db.profile.ignoreexclusionlist = not addon.db.profile.ignoreexclusionlist
			MainPanel.list_frame:Update(nil, false)
		end)
		option:SetTooltip(function(tooltip)
			tooltip:AddLine(L["DISPLAY_EXCLUSION_DESC"])
		end)
	end)
	-- Keep the existing Guide presentation hook for this recipe-only control.
	MainPanel.exclude_toggle = SearchOptions
	MainPanel.search_options = SearchOptions
	private.SetTooltipScripts(SearchOptions, L["DISPLAY_EXCLUSION_DESC"], 1)

	-- ----------------------------------------------------------------------------
	-- Create the X-close button, and set its scripts.
	-- ----------------------------------------------------------------------------
	MainPanel.xclose_button = MainPanel.CloseButton

	MainPanel.xclose_button:SetScript("OnClick", function(self, button, down)
		MainPanel:Hide()
	end)

	-- ----------------------------------------------------------------------------
	-- Use the same native title-bar control as Forever's Spellbook.
	-- ----------------------------------------------------------------------------
	do
		local filter_toggle = _G.CreateFrame("Frame", nil, MainPanel, "MaximizeMinimizeButtonFrameTemplate")
		filter_toggle:SetPoint("RIGHT", MainPanel.CloseButton, "LEFT", 0, 0)
		filter_toggle:SetFrameLevel(MainPanel.CloseButton:GetFrameLevel())
		filter_toggle:SkipResetOnShow(true)
		filter_toggle:SetOnMaximizedCallback(function()
			if not MainPanel.is_expanded then MainPanel:ToggleState() end
		end)
		filter_toggle:SetOnMinimizedCallback(function()
			if MainPanel.is_expanded then MainPanel:ToggleState() end
		end)

		private.SetTooltipScripts(filter_toggle.MaximizeButton, L["FILTER_OPEN_DESC"])
		private.SetTooltipScripts(filter_toggle.MinimizeButton, L["FILTER_CLOSE_DESC"])

		MainPanel.filter_toggle = filter_toggle
		MainPanel.MaximizeMinimizeButton = filter_toggle
		function MainPanel:SyncFilterToggle()
			-- Skip callbacks while updating the icon to avoid toggling twice.
			if self.is_expanded then
				self.filter_toggle:Maximize(true, true)
			else
				self.filter_toggle:Minimize(true, true)
			end
		end
		MainPanel:SyncFilterToggle()
	end	-- do-block

	-- ----------------------------------------------------------------------------
	-- Sort-mode toggle button.
	-- ----------------------------------------------------------------------------
	local sort_toggle = _G.CreateFrame("Button", nil, MainPanel)
	sort_toggle:SetSize(18, 18)
	sort_toggle:SetPoint("LEFT", expand_button_frame, "RIGHT", 3, 0)

	private.SetTooltipScripts(sort_toggle, L["SORTING_DESC"])

	MainPanel.sort_button = sort_toggle

	sort_toggle:SetScript("OnClick", function(self, button, down)
		local sort_type = addon.db.profile.sorting

		addon.db.profile.sorting = (sort_type == "Ascending" and "Descending" or "Ascending")

		self:SetTextures()
		MainPanel.list_frame:Update(nil, false)
	end)

	-- Native directional button artwork keeps its border upright in both
	-- states. Flipping a dropdown sprite would also flip its asymmetric frame.
	local sort_textures = {}
	for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
		local texture = sort_toggle:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints(sort_toggle)
		if state == "Highlight" then
			texture:SetBlendMode("ADD")
		end
		sort_toggle["Set" .. state .. "Texture"](sort_toggle, texture)
		sort_textures[state] = texture
	end

	function sort_toggle:SetTextures()
		local direction = addon.db.profile.sorting == "Ascending" and "down" or "up"
		sort_textures.Normal:SetAtlas("common-button-collapseexpand-" .. direction)
		sort_textures.Pushed:SetAtlas("common-button-collapseExpand-" .. direction .. "-pressed")
		sort_textures.Disabled:SetAtlas("common-button-collapseExpand-" .. direction .. "-disabled")
		sort_textures.Highlight:SetAtlas("common-button-collapseExpand-hover")
	end
	sort_toggle:SetTextures()

	-- ----------------------------------------------------------------------------
	-- Sort By buttons.
	-- ----------------------------------------------------------------------------
	do
		local name_button, skill_button

		local function ToggleOnClick(self)
			addon.db.profile.skill_view = not addon.db.profile.skill_view

			name_button:GetScript("OnShow")(name_button)
			skill_button:GetScript("OnShow")(skill_button)
			MainPanel.list_frame:Update(nil, false)
		end

	local sort_label = MainPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	sort_label:SetPoint("LEFT", sort_toggle, "RIGHT", 0, 0)
	-- Safe fallback if the global is missing on some clients
	sort_label:SetText("")

		name_button = _G.CreateFrame("Button", nil, MainPanel)
		-- Use FontObject references (with fallbacks) instead of string names for safety
		local Font_NormalGraySmall   = _G.GameFontNormalGraySmall or _G.GameFontNormalSmall or _G.GameFontNormal
		local Font_NormalSmall       = _G.GameFontNormalSmall or _G.GameFontNormal
		local Font_HighlightSmallOut = _G.GameFontHighlightSmallOutline or _G.GameFontHighlightSmall or _G.GameFontHighlight

		name_button:SetNormalFontObject(Font_NormalGraySmall)
		name_button:SetHighlightFontObject(Font_NormalSmall)
		name_button:SetDisabledFontObject(Font_HighlightSmallOut)

		do
			local fs = name_button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			if fs and fs.SetFontObject then
				fs:SetFontObject(Font_NormalSmall)
			end
			name_button:SetFontString(fs)
		end
		name_button:SetText(_G.NAME or "Name")
		name_button:SetSize(name_button:GetFontString():GetStringWidth(), 16)
		name_button:SetPoint("LEFT", sort_label, "RIGHT", 2, 0)

		name_button:SetScript("OnClick", ToggleOnClick)

		name_button:SetScript("OnShow", function(self)
			self[addon.db.profile.skill_view and "Enable" or "Disable"](self)
		end)

		local separator = MainPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		separator:SetPoint("LEFT", name_button, "RIGHT", 0, 0)
		separator:SetText(" / ")

		skill_button = _G.CreateFrame("Button", nil, MainPanel)
		-- Match the same robust FontObjects for safety
		local fs2 = skill_button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		if fs2 and fs2.SetFontObject then
			fs2:SetFontObject(Font_NormalSmall)
		end
		skill_button:SetFontString(fs2)

		skill_button:SetNormalFontObject(Font_NormalGraySmall)
		skill_button:SetHighlightFontObject(Font_NormalSmall)
		skill_button:SetDisabledFontObject(Font_HighlightSmallOut)
		skill_button:SetText(_G.SKILL_LEVEL or "Skill Level")
		skill_button:SetSize(skill_button:GetFontString():GetStringWidth(), 16)
		skill_button:SetPoint("LEFT", separator, "RIGHT", 0, 0)

		skill_button:SetScript("OnClick", ToggleOnClick)

		skill_button:SetScript("OnShow", function(self)
			self[addon.db.profile.skill_view and "Disable" or "Enable"](self)
		end)

		function MainPanel:RefreshSortButtons()
			name_button:GetScript("OnShow")(name_button)
			skill_button:GetScript("OnShow")(skill_button)
		end
        MainPanel.recipe_sort_controls = { sort_toggle, sort_label, name_button, separator, skill_button }
	end -- do-block

	-- ----------------------------------------------------------------------------
	-- Create MainPanel.progress_bar and set its scripts
	-- ----------------------------------------------------------------------------
	do
		-- Only borrow the cast bar artwork: recipe progress is not a spell cast.
		local progress_bar = _G.CreateFrame("Frame", nil, MainPanel)
		progress_bar:SetWidth(300)
		progress_bar:SetHeight(18)
		local background = progress_bar:CreateTexture(nil, "BACKGROUND")
		background:SetAtlas("ui-castingbar-background")
		background:SetPoint("TOPLEFT", -1, 1)
		background:SetPoint("BOTTOMRIGHT", 1, -1)
		progress_bar.Background = background

		-- The outer frame owns the artwork; only this inset area can fill.
		-- Leave room for the bevel and chamfered ends even at 0% and 100%.
		local fill = _G.CreateFrame("StatusBar", nil, progress_bar)
		fill:SetPoint("TOPLEFT", progress_bar, "TOPLEFT", 6, -4)
		fill:SetPoint("BOTTOMRIGHT", progress_bar, "BOTTOMRIGHT", -6, 4)
		fill:SetStatusBarTexture("ui-castingbar-filling-standard")
		fill:SetOrientation("HORIZONTAL")
		fill:SetStatusBarColor(1, 1, 1)
		fill:SetMinMaxValues(0, 1)
		fill:SetValue(0)
		progress_bar.Fill = fill
		function progress_bar:SetMinMaxValues(minimum, maximum)
			self.Fill:SetMinMaxValues(minimum, maximum)
		end
		function progress_bar:SetValue(value)
			self.Fill:SetValue(value)
		end

		-- Child frames render above their parent, so put border and text on
		-- a separate layer above the inset StatusBar, not below its fill.
		local overlay = _G.CreateFrame("Frame", nil, progress_bar)
		overlay:SetAllPoints(progress_bar)
		overlay:SetFrameLevel(fill:GetFrameLevel() + 1)
		progress_bar.Overlay = overlay

		local border = overlay:CreateTexture(nil, "OVERLAY")
		border:SetAtlas("ui-castingbar-frame")
		border:SetPoint("TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", 2, -2)
		progress_bar.Border = border

		local text = overlay:CreateFontString(nil, "OVERLAY")
		text:SetPoint("LEFT", progress_bar, "LEFT", 8, 0)
		text:SetPoint("RIGHT", progress_bar, "RIGHT", -8, 0)
		text:SetHeight(14)
		text:SetFontObject("GameFontHighlightSmall")
		text:SetShadowColor(0, 0, 0, 1)
		text:SetShadowOffset(1, -1)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")

		progress_bar.text = text
		MainPanel.progress_bar = progress_bar
	end	-- do

	-- ----------------------------------------------------------------------------
	-- Initialize components defined in other files.
	-- ----------------------------------------------------------------------------
	private.InitializeListFrame()
	-- Compact progress indicator, aligned with the recipe list rather than
	-- stretched across the filter pane.
	MainPanel.progress_bar:ClearAllPoints()
	MainPanel.progress_bar:SetPoint("TOPLEFT", MainPanel.list_frame, "BOTTOMLEFT", 0, -4)
	MainPanel.progress_bar:SetPoint("RIGHT", MainPanel.list_frame, "RIGHT", 0, 0)
	private.InitializeTabs()
	addon:SyncProfessionTab()

	private.InitializeFrame = nil
end

-- ----------------------------------------------------------------------------
-- Panel cleanup - called when MainPanel is hidden
-- ----------------------------------------------------------------------------
function private.CleanupPanel()
	local searchBox = addon.Frame and addon.Frame.search_editbox
	if searchBox then
		searchBox:ClearFocus()
	end

	_G.GameTooltip:Hide()

	local listFrame = private.list_frame
	if listFrame then
		if listFrame.entries then
			for i = 1, #listFrame.entries do
				local entry = listFrame.entries[i]
				if entry then
					if entry.children then
						private.ReleaseTable(entry.children)
						entry.children = nil
					end
					entry._discard = true
				end
			end
		end
		listFrame.selected_entry = nil
	end
end
