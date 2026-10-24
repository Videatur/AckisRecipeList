--[[
Copyright (c) 2009 - 2012 Ackis <John Pasula>
All rights reserved by the original author Ackis.
]]

-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------
local table = _G.table

local pairs, ipairs = _G.pairs, _G.ipairs

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

-- ----------------------------------------------------------------------------
-- Constants.
-- ----------------------------------------------------------------------------
local frame_meta = { __index = _G.CreateFrame("Button") }
local tab_prototype = _G.setmetatable({}, frame_meta)
local tab_meta = { __index = tab_prototype }

-- ----------------------------------------------------------------------------
-- Imports.
-- ----------------------------------------------------------------------------
local CreateListEntry = private.CreateListEntry
local SetTextColor = private.SetTextColor
local AcquireTypes = private.AcquireTypes

-- ----------------------------------------------------------------------------
-- Helpers.
-- ----------------------------------------------------------------------------
-- Selection controls the native atlas slices and label offset.
local function ApplyTabTextures(self, isActive)
    self:SetTabSelected(isActive)
end

local function Tab_OnClick(self, button, down)
	-- The handler is also called directly when restoring the saved selection.
	if self:IsForceDisabled() then return end
	local tabID = self:GetID()
	local MainPanel = addon.Frame

	for index in ipairs(MainPanel.tabs) do
		local tab = MainPanel.tabs[index]

		if index == tabID then
			self:ToFront()
		else
			tab:ToBack()
		end
	end

	addon.db.profile.current_tab = tabID
	MainPanel.current_tab = MainPanel.tabs[tabID]
	MainPanel.list_frame:Update(nil, false)

	_G.PlaySound(_G.SOUNDKIT.IG_CHARACTER_INFO_TAB, "Master")
end

local function CreateTab(id_num, text, ...)
    -- InitializeFrame loads Blizzard_Professions before creating these tabs.
    local tab = _G.setmetatable(_G.CreateFrame("Button", nil, addon.Frame, "ProfessionsFrameTabTemplate"), tab_meta)
    tab:SetID(id_num)
    tab.tabID = id_num
    tab.tabText = text
    tab:SetHeight(32)
    tab:SetPoint(...)
    tab:SetFrameLevel(tab:GetFrameLevel() + 4)
    tab.Text:SetText(text)
    -- Four tabs must fit the contracted 384px panel. Keep labels readable
    -- without forcing every tab to the old 100px minimum.
    tab:SetWidth(math.max(62, math.min(116, tab.Text:GetStringWidth() + 24)))
    tab:SetScript("OnClick", Tab_OnClick)
    ApplyTabTextures(tab, id_num == (addon.db.profile.current_tab or 1))
    return tab
end

function tab_prototype:ToFront()
    ApplyTabTextures(self, true)
end

function tab_prototype:ToBack()
    ApplyTabTextures(self, false)
end

function tab_prototype:SaveListEntryState(listEntry, expanded)
    local professionExpansionState = self.ProfessionState[private.CurrentProfession]
	if listEntry.guideChapter then
		professionExpansionState["guide:" .. listEntry.guideChapter.id] = expanded or nil
		return
	end
	if listEntry.category_id then
		professionExpansionState["continentCategory:" .. listEntry.category_id] = expanded
		return
	end

    local listEntryAcquireType = listEntry:AcquireType()
	if listEntryAcquireType then
		professionExpansionState[listEntryAcquireType] = expanded or nil
	end

    local listEntryLocation = listEntry:Location()
	if listEntryLocation then
		professionExpansionState[listEntryLocation] = expanded or nil
	end

	if listEntry.recipe then
		professionExpansionState[listEntry.recipe] = expanded or nil
	end
end

function tab_prototype:GetProfessionExpansionState(profession)
    local professionState = self.ProfessionState
    if not professionState then
        professionState = {
            [profession] = {}
        }

        self.ProfessionState = professionState
    end

    local professionExpansionState = self.ProfessionState[profession]
    if not professionExpansionState then
        professionExpansionState = {}
        self.ProfessionState[profession] = professionExpansionState
    end

    return professionExpansionState
end

function tab_prototype:ScrollValue(profession)
	return self["profession_" .. profession:Name() .. "_scroll_value"]
end

function tab_prototype:SetScrollValue(profession, value)
	self["profession_" .. profession:Name() .. "_scroll_value"] = value
end

-- ----------------------------------------------------------------------------
-- Tab initialization and methods.
-- ----------------------------------------------------------------------------
local GuideTab
local AcquisitionTab
local LocationTab
local RecipesTab

function private.UpdateGuideTabAvailability()
    if not GuideTab then return end
    local hasGuide = private.GetProfessionGuide(private.CurrentProfession) ~= nil
    GuideTab:SetTabEnabled(hasGuide)

    local panel = addon.Frame
    if not hasGuide and (addon.db.profile.current_tab == 1 or panel.current_tab == GuideTab) then
        addon.db.profile.current_tab = 4
        panel.current_tab = RecipesTab
        for index, tab in ipairs(panel.tabs) do
            if index == 4 then tab:ToFront() else tab:ToBack() end
        end
    end
end

-- Used for Location and Acquisition sort - since many recipes have multiple locations/acquire types it is
-- necessary to ensure each is counted only once.
local recipe_registry = {}

-- Recipes with these acquire types will never show as headers.
local CHILDLESS_ACQUIRE_TYPES = {
	[private.AcquireTypes.Achievement] = true,
	[private.AcquireTypes.Custom] = true,
	[private.AcquireTypes.Discovery] = true,
	[private.AcquireTypes.Retired] = true,
	[private.AcquireTypes.WorldDrop] = true,
}

local AcquireDataExpandPredicates = {
	[AcquireTypes.Trainer] = function(obtainFilters, shouldHideType)
		return obtainFilters.trainer
	end,
	[AcquireTypes.Vendor] = function(obtainFilters, shouldHideType)
		return obtainFilters.vendor or obtainFilters.pvp
	end,
	[AcquireTypes.Mixed] = function(obtainFilters, shouldHideType)
		return obtainFilters.mixed
	end,
	[AcquireTypes.MobDrop] = function(obtainFilters, shouldHideType)
		return obtainFilters.mobdrop or obtainFilters.instance or obtainFilters.raid
	end,
	[AcquireTypes.Quest] = function(obtainFilters, shouldHideType)
		return obtainFilters.quest
	end,
	[AcquireTypes.WorldEvent] = function(obtainFilters, shouldHideType)
		return obtainFilters.worldevent
	end,
	[AcquireTypes.Reputation] = function(obtainFilters, shouldHideType)
		return true
	end,
	[AcquireTypes.WorldDrop] = function(obtainFilters, shouldHideType)
		return obtainFilters.worlddrop and not shouldHideType
	end,
	[AcquireTypes.Custom] = function(obtainFilters, shouldHideType)
		return not shouldHideType
	end,
	[AcquireTypes.Discovery] = function(obtainFilters, shouldHideType)
		return not shouldHideType
	end,
	[AcquireTypes.Retired] = function(obtainFilters, shouldHideType)
		return not shouldHideType
	end,
	[AcquireTypes.Achievement] = function(obtainFilters, shouldHideType)
		return obtainFilters.achievement
	end,
	[AcquireTypes.TradeSkill] = function(obtainFilters, shouldHideType)
		return obtainFilters.tradeskill
	end,
}

local function ExpandAcquireData(listEntryIndex, listEntryType, parentListEntry, acquireType, acquireTypeData, recipe, shouldHideLocation, shouldHideType)
	local obtainFilters = addon.db.profile.filters.obtain

	for sourceID, sourceData in pairs(acquireTypeData) do
		local predicateFunc = AcquireDataExpandPredicates[acquireType]
		if predicateFunc and predicateFunc(obtainFilters, shouldHideType) then
			listEntryIndex = acquireType:ExpandListEntry(listEntryIndex, listEntryType, parentListEntry, sourceID, sourceData, recipe, shouldHideLocation, shouldHideType)
		end
	end

	return listEntryIndex
end

-- Category visibility must use its own sources, rather than another
-- acquisition route that makes the recipe globally visible.
local function HasVisibleAcquisitionSource(recipe, acquireType)
	if acquireType ~= private.AcquireTypes.Quest then
		return true
	end
	local acquireData = recipe:AcquireDataOfType(acquireType)
	for identifier in pairs(acquireData or {}) do
		local quest = acquireType:GetEntity(identifier)
		-- Preserve unregistered quests: missing data is not an opposing faction.
		if not quest or acquireType.CanDisplayFaction(quest.faction) then
			return true
		end
	end
	return false
end

local function InitializeGuideTab()
    GuideTab = CreateTab(1, "Guide", "TOPLEFT", addon.Frame, "BOTTOMLEFT", 22, 2)
    GuideTab.kind = "guide"
    GuideTab.Initialize = private.PopulateGuideTab
    GuideTab.ExpandListEntry = private.ExpandGuideEntry
end

local function InitializeAcquisitionTab()
	local MainPanel = addon.Frame

	-- Used to hold tables for sorting the tab:The tables are only sorted once, upon creation.
	local SortedAcquireTypes

	AcquisitionTab = CreateTab(2, L["Acquisition"], "LEFT", GuideTab, "RIGHT", 0, 0)
    AcquisitionTab.kind = "acquisition"

	function AcquisitionTab:Initialize(expand_mode)
		local recipe_count = 0
		local insert_index = 1

		table.wipe(recipe_registry)

		if not SortedAcquireTypes then
			SortedAcquireTypes = {}

            for name, acquireType in pairs(private.AcquireTypes) do
				SortedAcquireTypes[#SortedAcquireTypes + 1] = acquireType
            end

			table.sort(SortedAcquireTypes, function(acquireTypeA, acquireTypeB)
				local a = (acquireTypeA and acquireTypeA:Name()) or ""
				local b = (acquireTypeB and acquireTypeB:Name()) or ""
				return a < b
			end)
        end
        local currentProfession = private.CurrentProfession
		local localizedProfessionName = currentProfession:LocalizedName()
		local professionRecipes = currentProfession.Recipes
        local professionExpansionState = self:GetProfessionExpansionState(currentProfession)

		for index = 1, #SortedAcquireTypes do
			local acquireType = SortedAcquireTypes[index]
			local count = 0

			-- Check to see if any recipes for this acquire type will be shown - otherwise, don't show the type in the list.
			for spell_id, affiliation in acquireType:RecipePairs() do
				local recipe = professionRecipes[spell_id]

				if recipe and recipe:IsVisible() and HasVisibleAcquisitionSource(recipe, acquireType) then
					count = count + 1

					if not recipe_registry[recipe] then
						recipe_registry[recipe] = true
						recipe_count = recipe_count + 1
					end
                elseif recipe and not recipe:IsVisible() and professionExpansionState[recipe] then
                    professionExpansionState[recipe] = nil
                end
			end

			if count > 0 then
				local isAcquireTypeExpanded = professionExpansionState[acquireType]
				local listEntry = CreateListEntry("header")
				listEntry:SetAcquireType(acquireType)
                listEntry.acquisitionCount = count
                listEntry:SetText(acquireType:Name())

				insert_index = MainPanel.list_frame:InsertEntry(listEntry, insert_index, isAcquireTypeExpanded or expand_mode, isAcquireTypeExpanded or expand_mode)
            elseif professionExpansionState[acquireType] then
                professionExpansionState[acquireType] = nil
            end
        end

		return recipe_count
	end

	function AcquisitionTab:ExpandListEntry(entry, expand_mode)
		local orig_index = entry.button and entry.button.entry_index or entry.index
		local expand_all = expand_mode == "deep"
		local entryAcquireType = entry:AcquireType()

		-- Entry_index is the position in self.entries that we want to expand. Since we are expanding the current entry, the return
		-- value should be the index of the next button after the expansion occurs
		local newListEntryIndex = orig_index + 1

		self:SaveListEntryState(entry, true)

		if entry:IsHeader() then
			local sorted_recipes = entryAcquireType:GetSortedRecipes()
            local currentProfession = private.CurrentProfession
            local localizedProfessionName = currentProfession:LocalizedName()
            local professionExpansionState = self:GetProfessionExpansionState(currentProfession)

            for index = 1, #sorted_recipes do
				local recipe = currentProfession.Recipes[sorted_recipes[index]]
				if recipe and recipe:IsVisible() and HasVisibleAcquisitionSource(recipe, entryAcquireType) then
					local expand = false
					local entry_type = "subheader"

					if CHILDLESS_ACQUIRE_TYPES[entryAcquireType] then
						expand = true
						entry_type = "entry"
					end
					local is_expanded = (professionExpansionState[recipe] and professionExpansionState[entryAcquireType])

					local listEntry = CreateListEntry(entry_type, entry, recipe)
					listEntry:SetAcquireType(entryAcquireType)
					listEntry:SetText(recipe:GetDisplayName())

					newListEntryIndex = MainPanel.list_frame:InsertEntry(listEntry, newListEntryIndex, expand or is_expanded, expand_all or is_expanded)
				end
			end
		elseif entry:IsSubHeader() then
            local recipeAcquireData = entry.recipe:AcquireDataOfType(entryAcquireType)
            if recipeAcquireData then
                newListEntryIndex = ExpandAcquireData(newListEntryIndex, "subentry", entry, entryAcquireType, recipeAcquireData, entry.recipe, false, true)
			end
        end

		return newListEntryIndex
	end
end

local function InitializeLocationTab()
	local MainPanel = addon.Frame

	-- Used to hold tables for sorting the tab: The tables are only sorted once upon creation.
	local SortedLocations

	local function InsertLocationHeader(tab, location, count, parentEntry, insertIndex, expandMode)
		local localizedName = location:LocalizedName()
		local continentID = location:ContinentID()
		local displayName = (location == private.WorldDropLocation or location == private.ContinentLocationByID[continentID])
			and L["World Drop"] or localizedName
		local listEntry = CreateListEntry("header", parentEntry)
		listEntry:SetLocation(location)
		if localizedName == _G.GetRealZoneText() then
			listEntry:Emphasize(true)
			listEntry:SetText("%s (%d)", SetTextColor(private.DIFFICULTY_COLORS.optimal.hex, displayName), count)
		else
			listEntry:Emphasize(false)
			listEntry:SetText("%s (%d)", SetTextColor("f0dfbd", displayName), count)
		end
		local professionExpansionState = tab:GetProfessionExpansionState(private.CurrentProfession)
		local isExpanded = professionExpansionState[location]
		return MainPanel.list_frame:InsertEntry(listEntry, insertIndex, isExpanded or expandMode, isExpanded or expandMode)
	end

	LocationTab = CreateTab(3, L["Location"], "LEFT", AcquisitionTab, "RIGHT", 0, 0)
    LocationTab.kind = "location"

	function LocationTab:Initialize(expand_mode)
		local search_box = MainPanel.search_editbox

		table.wipe(recipe_registry)

		if not SortedLocations then
			SortedLocations = {}

			for name, location in pairs(private.Locations) do
				table.insert(SortedLocations, location)
			end

			table.sort(SortedLocations, function(locationA, locationB)
				local aCont = (locationA and locationA:ContinentID()) or 9999
				local bCont = (locationB and locationB:ContinentID()) or 9999
				if aCont == bCont then
					local continent = private.ContinentLocationByID[aCont]
					if locationA ~= locationB then
						if locationA == continent then return true end
						if locationB == continent then return false end
					end
					local aName = (locationA and locationA:LocalizedName()) or ""
					local bName = (locationB and locationB:LocalizedName()) or ""
					return aName < bName
				end
				return aCont < bCont
			end)
        end
        local currentProfession = private.CurrentProfession
        local localizedProfessionName = currentProfession:LocalizedName()
		local professionRecipes = currentProfession.Recipes
        local professionExpansionState = self:GetProfessionExpansionState(currentProfession)

        local currentContinentID
		local currentCategory

        local recipe_count = 0
        local insert_index = 1

		for index = 1, #SortedLocations do
            local location = SortedLocations[index]
            local localizedLocationName = location:LocalizedName()
			local count = 0

			-- Check to see if any recipes for this location will be shown - otherwise, don't show the location in the list.
            for recipe, affiliation in location:RecipePairs() do
				if professionRecipes[recipe:SpellID()] and recipe:IsVisible() then
					local good_count, bad_count = 0, 0
					local showOpposingFaction = addon.db.profile.filters.general.faction

					if not showOpposingFaction then
                        for name, acquireType in pairs(private.AcquireTypes) do
							local acquireData = recipe:AcquireDataOfType(acquireType)

							if acquireData and acquireType:HasCoordinates() then
                                local alignedCount = 0
                                local opposingCount = 0

                                for identifier in pairs(acquireData) do
                                    local entity = acquireType:GetEntity(identifier)

                                    if entity then
                                        local entityFaction = entity.faction

                                        if not location or entity.Location == location then
                                            if not entityFaction or entityFaction == private.Player.faction or entityFaction == "Neutral" then
                                                alignedCount = alignedCount + 1
                                            else
                                                opposingCount = opposingCount + 1
                                            end
                                        end
                                    end
                                end

                                if alignedCount == 0 and opposingCount > 0 then
									bad_count = bad_count + 1
								else
									good_count = good_count + 1
								end
							end
						end
					end

					if showOpposingFaction or not (good_count == 0 and bad_count > 0) then
						count = count + 1

						if not recipe_registry[recipe] then
							recipe_registry[recipe] = true
							recipe_count = recipe_count + 1
						end
					end
                elseif professionExpansionState[recipe] then
                    professionExpansionState[recipe] = nil
                end
			end

			if count > 0 then
                local locationContinentID = location:ContinentID()
				if locationContinentID ~= currentContinentID then
					currentContinentID = locationContinentID
					currentCategory = nil

					local continentObj = private.ContinentLocationByID and locationContinentID and private.ContinentLocationByID[locationContinentID]
					local continentHeaderName = (continentObj and continentObj:LocalizedName())
						or (private.ZONE_NAMES and (private.ZONE_NAMES.AZEROTH or "Azeroth"))
						or "Azeroth"
					currentCategory = CreateListEntry("category")
					currentCategory.category_id = locationContinentID
					currentCategory.locations = {}
					currentCategory:SetText(continentHeaderName)
					local savedExpansion = professionExpansionState["continentCategory:" .. locationContinentID]
					insert_index = MainPanel.list_frame:InsertEntry(currentCategory, insert_index, expand_mode or savedExpansion ~= false)
				end
				if currentCategory then
					currentCategory.locations[#currentCategory.locations + 1] = { location, count }
				end
				if not currentCategory or currentCategory.is_expanded then
					insert_index = InsertLocationHeader(self, location, count, currentCategory, insert_index, expand_mode)
				end
            elseif professionExpansionState[location] then
                professionExpansionState[location] = nil
            end
        end

		return recipe_count
	end

	function LocationTab:ExpandListEntry(entry, expand_mode)
		local orig_index = entry.button and entry.button.entry_index or entry.index
		local expand_all = expand_mode == "deep"
        local location = entry:Location()

		-- Entry_index is the position in self.entries that we want to expand. Since we are expanding the current entry, the return
		-- value should be the index of the next button after the expansion occurs
		local new_entry_index = orig_index + 1

		self:SaveListEntryState(entry, true)

		if entry:IsCategory() then
			for index = 1, #entry.locations do
				local locationInfo = entry.locations[index]
				new_entry_index = InsertLocationHeader(self, locationInfo[1], locationInfo[2], entry, new_entry_index, expand_mode)
			end
		elseif entry:IsHeader() then
            local currentProfession = private.CurrentProfession
            local professionExpansionState = self:GetProfessionExpansionState(currentProfession)

            local sortedRecipes = location:GetSortedRecipes()
			for index = 1, #sortedRecipes do
				local recipe = currentProfession.Recipes[sortedRecipes[index]]

				if recipe and recipe:IsVisible() then
					local expand = false
					local entry_type = "subheader"

					-- Add World Drop entries as normal entries.
					if location:GetRecipeAffiliation(recipe) == "world_drop" then
						expand = true
						entry_type = "entry"
					end

					local isLocationExpanded = (professionExpansionState[recipe] and professionExpansionState[location])
					local listEntry = CreateListEntry(entry_type, entry, recipe)
					listEntry:SetText(recipe:GetDisplayName())
					listEntry:SetLocation(location)

					new_entry_index = MainPanel.list_frame:InsertEntry(listEntry, new_entry_index, expand or isLocationExpanded, expand_all or isLocationExpanded)
				end
			end
		elseif entry:IsSubHeader() then
			-- World Drops are not handled here because they are of type "entry".
            -- Only expand an acquisition entry if it is from this location.
            for acquireType, acquireData in entry.recipe:AcquirePairs() do
				for sourceID, sourceData in pairs(acquireData) do
					local hideAcquireType
					local shouldExecute
					local sourceEntity = acquireType:GetEntity(sourceID)

					if (acquireType == private.AcquireTypes.Trainer or acquireType == private.AcquireTypes.Vendor or acquireType == private.AcquireTypes.MobDrop or acquireType == private.AcquireTypes.Mixed or acquireType == private.AcquireTypes.Quest)
							and sourceEntity and sourceEntity.Location == location then
						shouldExecute = true
					elseif (acquireType == private.AcquireTypes.WorldEvent or acquireType == private.AcquireTypes.Custom or acquireType == private.AcquireTypes.Discovery)
							and sourceEntity and sourceEntity.Location == location then
						hideAcquireType = true
						shouldExecute = true
					elseif acquireType == private.AcquireTypes.Reputation then
						shouldExecute = true
						break
					end

					if shouldExecute then
						new_entry_index = acquireType:ExpandListEntry(new_entry_index, "subentry", entry, sourceID, sourceData, entry.recipe, true, hideAcquireType)
					end
				end
			end
		end
		return new_entry_index
	end
end

local function InitializeRecipesTab()
	local MainPanel = addon.Frame

	RecipesTab = CreateTab(4, _G.TRADESKILL_SERVICE_LEARN, "LEFT", LocationTab, "RIGHT", 0, 0)
    RecipesTab.kind = "recipes"

	function RecipesTab:Initialize(expand_mode)
        local currentProfession = private.CurrentProfession
        local localizedProfessionName = currentProfession:LocalizedName()
		local professionRecipes = currentProfession.Recipes
        local professionExpansionState = self:GetProfessionExpansionState(currentProfession)

		private.SortRecipeList(professionRecipes)

		local sorted_recipes = addon.sorted_recipes
		local recipe_count = 0
		local insert_index = 1

		for i = 1, #sorted_recipes do
			local recipe = professionRecipes[sorted_recipes[i]]

			if recipe and recipe:IsVisible() then
				local listEntry = CreateListEntry("header", nil, recipe)
				listEntry:SetText(recipe:GetDisplayName())

				recipe_count = recipe_count + 1

				local isRecipeExpanded = professionExpansionState[recipe]
				insert_index = MainPanel.list_frame:InsertEntry(listEntry, insert_index, isRecipeExpanded or expand_mode, isRecipeExpanded or expand_mode)
			elseif professionExpansionState[recipe] then
				professionExpansionState[recipe] = nil
			end
        end

		return recipe_count
	end

	function RecipesTab:ExpandListEntry(entry, expand_mode)
		local orig_index = entry.button and entry.button.entry_index or entry.index

		-- Entry_index is the position in self.entries that we want to expand. Since we are expanding the current entry, the return
		-- value should be the index of the next button after the expansion occurs
		local new_entry_index = orig_index + 1

		self:SaveListEntryState(entry, true)

        for acquireType, acquireData in entry.recipe:AcquirePairs() do
			new_entry_index = ExpandAcquireData(new_entry_index, "entry", entry, acquireType, acquireData, entry.recipe)
		end
		return new_entry_index
	end
end

function private.InitializeTabs()
	local MainPanel = addon.Frame
	MainPanel.tabs = {}

    private.MigrateGuideTabProfile(addon.db.profile)
    InitializeGuideTab()
    MainPanel.tabs[#MainPanel.tabs + 1] = GuideTab

	InitializeAcquisitionTab()
	MainPanel.tabs[#MainPanel.tabs + 1] = AcquisitionTab

	InitializeLocationTab()
	MainPanel.tabs[#MainPanel.tabs + 1] = LocationTab

	InitializeRecipesTab()
	MainPanel.tabs[#MainPanel.tabs + 1] = RecipesTab

    -- Keep these three tabs compact and equally wide, fitting both labels.
    local compactWidth = math.max(LocationTab:GetWidth(), RecipesTab:GetWidth())
    GuideTab:SetWidth(compactWidth)
    LocationTab:SetWidth(compactWidth)
    RecipesTab:SetWidth(compactWidth)

    private.UpdateGuideTabAvailability()

	private.InitializeTabs = nil
end
