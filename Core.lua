--[[
    Ackis Recipe List - Core
    Main addon initialization, event handling, and scanning logic

    Provides:
    - AceAddon lifecycle management (OnInitialize, OnEnable, OnDisable)
    - Trade skill scanning and recipe detection
    - Event registration with conditional UI events
    - GameTooltip hooks for NPC recipe information
    - Database and saved variable handling
]]

-- ============================================================================
-- Upvalued Lua API
-- ============================================================================
local pairs, ipairs = _G.pairs, _G.ipairs
local type = _G.type

local string = _G.string
local table = _G.table

-- ============================================================================
-- AddOn Namespace
-- ============================================================================
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local addon = LibStub("AceAddon-3.0"):NewAddon(private.addon_name, "AceConsole-3.0", "AceEvent-3.0")
addon.constants = private.constants
addon.constants.addon_name = private.addon_name
addon.Name = FOLDER_NAME
private.addon_display_name = "Ackis Recipe List Classic"
addon.name = private.addon_display_name or private.addon_name

local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)
local ldb = LibStub("LibDataBroker-1.1")
local ldbi = LibStub("LibDBIcon-1.0")

local dataBroker = ldb:NewDataObject("AckisRecipeList", {
    type = "launcher",
    label = "Ackis Recipe List",
    icon = [[Interface\Icons\INV_Misc_Book_11]],
    tocname = "AckisRecipeList",
})

local function UpdateMinimapIconLayout()
    if not _G.WOW_PROJECT_CAMELOT or _G.WOW_PROJECT_ID ~= _G.WOW_PROJECT_CAMELOT then return end
    local button = ldbi:GetMinimapButton("AckisRecipeList")
    if not button or not button.icon then return end
    -- Match LibDBIcon's Classic background, including its center offset.
    if ldbi.SetButtonIcon then
        ldbi:SetButtonIcon("AckisRecipeList", nil, 20, "TOPLEFT", 7, -5)
    else
        button.icon:SetSize(20, 20)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", 7, -5)
    end
    if not button.arlIconMask then
        local mask = button:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(button.icon)
        button.icon:AddMaskTexture(mask)
        button.arlIconMask = mask
    end
end

function dataBroker.OnClick(_, button)
    if private.addonEnabled == false then return end
    if button == "LeftButton" then
        if addon.Frame and addon.Frame:IsVisible() then
            addon.Frame:Hide()
        else
            if private.InitializeFrame then private.InitializeFrame() end
            if addon.EnsureProfessionOpenAndScan then
                addon:EnsureProfessionOpenAndScan()
            else
                addon:Scan(false, false)
            end
        end
    elseif button == "RightButton" then
        if not addon.settingsCategory then addon:SetupOptions() end
        _G.Settings.OpenToCategory(addon.settingsCategory:GetID())
    end
end

function dataBroker.OnTooltipShow(tt)
    if private.addonEnabled == false then return end
    tt:AddLine(private.addon_display_name or private.addon_name)
    tt:AddLine("Left-click: Toggle GUI", 0.2, 1, 0.2)
    tt:AddLine("Right-click: Options", 0.2, 1, 0.2)
end

-- Helper to open Blizzard options reliably
local function OpenOptions(target)
    -- Ensure options are registered
    if (not addon.optionsFrame) and addon.SetupOptions then
        addon:SetupOptions()
    end

    -- Native categories expose GetID; AceConfig's Profiles canvas stores it in name.
    local categoryID = target and (target.GetID and target:GetID() or target.name) or addon.settingsCategory:GetID()
    _G.Settings.OpenToCategory(categoryID)
end

-- ----------------------------------------------------------------------------
-- Constants.
-- ----------------------------------------------------------------------------
-- Module schema 5: recipes and acquisition entities have no expansion metadata.
local SUPPORTED_MODULE_VERSION = 5

-- Load-on-demand profession addons validate their schema while they initialize.
-- Publish this static compatibility value before the parent's OnInitialize so
-- those modules do not compare their version against nil.
addon.SUPPORTED_MODULE_VERSION = SUPPORTED_MODULE_VERSION

-- ----------------------------------------------------------------------------
-- Adapt Forever profession data to the tuple consumed by ARL.
-- Never replace functions in Blizzard's shared C_TradeSkillUI table.
-- ----------------------------------------------------------------------------
function private.GetTradeSkillLine()
    -- Match Professions.GetProfessionInfo and GetEffectiveSkillLineID: the
    -- selected child is authoritative; base info is the NPC-crafting fallback.
    local info = _G.C_TradeSkillUI.GetChildProfessionInfo()
    if not info or not info.professionID or info.professionID == 0 then
        info = _G.C_TradeSkillUI.GetBaseProfessionInfo()
    end
    local professionID = info and (info.parentProfessionID or info.professionID)
    local name = info and (info.parentProfessionName or info.professionName)
    if professionID and professionID ~= 0 and name and name ~= "" and name ~= _G.UNKNOWN then
        if private.ResolveProfessionName then
            name = private.ResolveProfessionName(professionID, name)
        end
        local rank = info.skillLevel or 0
        local maxRank = info.maxSkillLevel
        return professionID, name, rank, maxRank, nil, professionID, name
    end
    return nil, _G.UNKNOWN, 0, nil, nil, nil, _G.UNKNOWN
end

-- ----------------------------------------------------------------------------
-- Dialogs.
-- ----------------------------------------------------------------------------
_G.StaticPopupDialogs["ARL_DisabledProfessionModuleDialog"] = {
    text = "%s",
    button1 = _G.OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    wideText = true,
    wide = true,
    OnShow = function(self) private.ShowPopupBackground(self) end,
    OnHide = function(self) private.HidePopupBackground(self) end,
}

local function ShowDisabledProfessionModuleDialog(moduleName)
    local text = ("%s - %s\n\nThe profession module \"%s_%s\" is disabled.\n\nEnable it in the AddOns list and reload the interface to view recipes for this profession."):format(
        (private.addon_display_name or private.addon_name), addon.version, FOLDER_NAME, moduleName)
    _G.StaticPopup_Show("ARL_DisabledProfessionModuleDialog", text)
end

_G.StaticPopupDialogs["ARL_ModuleWrongVersionDialog"] = {
    text = "%s",
    button1 = _G.OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    wideText = true,
    wide = true,
    showAlert = true,
    exclusive = true,
    OnShow = function(self) private.ShowPopupBackground(self) end,
    OnHide = function(self) private.HidePopupBackground(self) end,
}

-- Invoked from the module itself.
function addon:SpawnModuleWrongVersionDialog(data)
    local text = ("%s - %s\n\n%s"):format((private.addon_display_name or private.addon_name), addon.version,
        L.MODULE_WRONG_VERSION_FORMAT:format(data.moduleName, data.moduleVersion, SUPPORTED_MODULE_VERSION))
    _G.StaticPopup_Show("ARL_ModuleWrongVersionDialog", text)
end

_G.StaticPopupDialogs["ARL_NoModulesErrorDialog"] = {
    text = "No profession module AddOns were found.\n\nEach profession is a separate modular AddOn. You can find and install them on CurseForge or via the Ackis Recipe List Classic page, which lists links to all profession modules.",
    button1 = _G.OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    wideText = true,
    wide = true,
    showAlert = true,
    OnShow = function(self) private.ShowPopupBackground(self) end,
    OnHide = function(self) private.HidePopupBackground(self) end,
}

_G.StaticPopupDialogs["ARL_MissingProfessionModuleDialog"] = {
    text = "%s",
    button1 = _G.OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    wideText = true,
    wide = true,
    OnShow = function(self) private.ShowPopupBackground(self) end,
    OnHide = function(self) private.HidePopupBackground(self) end,
}

local function ShowMissingProfessionModuleDialog(data)
    local prof = data and data.localizedProfessionName or "this profession"
    local moduleName = data and data.moduleName or "(unknown)"
    local text = ("%s - %s\n\nThe profession module for %s is not installed.\n\nInstall the AddOn \"%s\" to view recipes for this profession. You can find it on CurseForge or via the Ackis Recipe List Classic page."):format(
        (private.addon_display_name or private.addon_name), addon.version, prof, moduleName)
    _G.StaticPopup_Show("ARL_MissingProfessionModuleDialog", text)
end

-- ----------------------------------------------------------------------------
-- Database tables
-- ----------------------------------------------------------------------------
local SpecialtyTable

-- Global Frame Variables
addon.optionsFrame = {}

-- ----------------------------------------------------------------------------
-- Initialization functions
-- ----------------------------------------------------------------------------
function addon:OnInitialize()
    -- Register slash commands early so they are always available
    self:RegisterChatCommand("arl", "ChatCommand")
    self:RegisterChatCommand("ackisrecipelist", "ChatCommand")

    -- Set default options, which are to include everything in the scan
    local defaults = {
        char = {
            guideProgress = {},
            professionGuideHelpSeen = {},
        },
        profile = {
            -- ----------------------------------------------------------------------------
            -- Frame options
            -- ----------------------------------------------------------------------------
            frameopts = {
                offsetx = 0,
                offsety = 0,
                anchorTo = "",
                anchorFrom = "",
                uiscale = 1,
                small_list_font = true,
            },

            -- Minimap icon state (LibDBIcon compatible)
            minimapIcon = { hide = false },

            -- ----------------------------------------------------------------------------
            -- Tooltip Options
            -- ----------------------------------------------------------------------------
            tooltip = {
                scale = 1,
                acquire_fontsize = 11,
            },
            -- ----------------------------------------------------------------------------
            -- Sorting Options
            -- ----------------------------------------------------------------------------
            sorting = "Ascending",
            current_tab = 4,    -- Recipes tab, after Guide/Acquisition/Location.
            skill_view = true,  -- Sort the recipes by skill level instead of name?

            -- ----------------------------------------------------------------------------
            -- Display Options
            -- ----------------------------------------------------------------------------
            includefiltered = false,
            includeexcluded = false,
            closeguionskillclose = false,
            ignoreexclusionlist = false,
            spelltooltiplocation = "Right",
            acquiretooltiplocation = "Right",
            recipes_in_tooltips = true,
            max_recipes_in_tooltips = 10,
            hide_tooltip_hint = false,
            hidepopup = false,
            minimap = true,
            worldmap = true,
            autoscanmap = false,
            maptrainer = true,
            mapvendor = true,
            mapmob = false,
            mapquest = false,

            -- ----------------------------------------------------------------------------
            -- Recipe Exclusion
            -- ----------------------------------------------------------------------------
            exclusionlist = {},

            -- ----------------------------------------------------------------------------
            -- Filter Options
            -- ----------------------------------------------------------------------------
            filters = {
                -- ----------------------------------------------------------------------------
                -- General Filters
                -- ----------------------------------------------------------------------------
                general = {
                    faction = false,
                    specialty = false,
                    skill = true,
                    known = false,
                    unknown = true,
                },
                -- ----------------------------------------------------------------------------
                -- Obtain Filters
                -- ----------------------------------------------------------------------------
                obtain = {
                    achievement = true,
                    custom = true,
                    discovery = true,
                    instance = true,
                    mobdrop = true,
                    pvp = true,
                    quest = true,
                    raid = true,
                    reputation = true,
                    retired = false,
                    trainer = true,
                    vendor = true,
                    worlddrop = true,
                    worldevent = true,
                    tradeskill = true,
                    mixed = true,
                },
                -- ----------------------------------------------------------------------------
                -- Profession Item Filters
                -- ----------------------------------------------------------------------------
                item = { -- These are populated from the item flags defined in profession modules.
                },
                -- ----------------------------------------------------------------------------
                -- Quality Filters
                -- ----------------------------------------------------------------------------
                quality = {
                    common = true,
                    uncommon = true,
                    rare = true,
                    epic = true,
                    legendary = true,
                },
                -- ----------------------------------------------------------------------------
                -- Binding Filters
                -- ----------------------------------------------------------------------------
                binding = {
                    item_bind_on_equip = true,
                    item_bind_on_pickup = true,
                    recipe_bind_on_equip = true,
                    recipe_bind_on_pickup = true,
                },
                -- ----------------------------------------------------------------------------
                -- Player Role Filters
                -- ----------------------------------------------------------------------------
                player = {
                    caster = true,
                    healer = true,
                    melee = true,
                    tank = true,
                },
                -- ----------------------------------------------------------------------------
                -- Reputation Filters
                -- ----------------------------------------------------------------------------
                rep = { -- These are populated from the reputations defined in Constants.lua
                },
                -- ----------------------------------------------------------------------------
                -- Class Filters
                -- ----------------------------------------------------------------------------
                classes = {
                    druid = true,
                    hunter = true,
                    mage = true,
                    paladin = true,
                    priest = true,
                    rogue = true,
                    shaman = true,
                    warlock = true,
                    warrior = true,
                },
            }
        }
    }

    self.SUPPORTED_MODULE_VERSION = SUPPORTED_MODULE_VERSION

    for index = 1, #private.REP_FLAGS do
        for reputation_name in pairs(private.REP_FLAGS[index]) do
            defaults.profile.filters.rep[reputation_name:lower()] = true
        end
    end

    for filter_name in pairs(self.constants.ITEM_FILTER_TYPES) do
        defaults.profile.filters.item[filter_name:lower()] = true
    end

    self.db = LibStub("AceDB-3.0"):New("ARLDB2", defaults)
    if not self.db then
        self:Print(
            "Error: Database not loaded correctly.  Please exit out of WoW and delete the ARL database file (AckisRecipeList.lua) found in: \\World of Warcraft\\WTF\\Account\\<Account Name>>\\SavedVariables\\")
        return
    end

    -- Raw profiles distinguish an absent saved tab from AceDB's new default.
    for _, profile in pairs(self.db.sv.profiles or {}) do
        private.MigrateGuideTabProfile(profile)
    end

    -- Migrate obsolete expansion options without changing any other saved filter.
    for _, profile in pairs(self.db.sv.profiles or {}) do
        private.MigrateClassFilters(profile)
        local obtain = profile.filters and profile.filters.obtain
        if obtain then
            for key in pairs(obtain) do
                if type(key) == "string" and key:match("^expansion%d+$") then
                    obtain[key] = nil
                end
            end
        end
    end

    -- LibDBIcon minimap button setup
    ldbi:Register("AckisRecipeList", dataBroker, self.db.profile.minimapIcon)
    UpdateMinimapIconLayout()

    private.db = self.db

    local function RefreshProfilePreferences()
        private.MigrateClassFilters(self.db.profile)
        if private.RefreshNativeOptions then private.RefreshNativeOptions() end
        private.MigrateGuideTabProfile(self.db.profile)
        private.IncrementFilterVersion()
        self:UpdateMinimapIcon()
        self:RefreshWaypointPreferences()
        local panel = self.Frame
        if not panel or not panel.filter_menu or not panel.filter_menu.value_map then return end
        private.UpdateFilterMarks()
        if panel.sort_button then panel.sort_button:SetTextures() end
        if panel.RefreshSortButtons then panel:RefreshSortButtons() end
        private.UpdateGuideTabAvailability()
        local tabID = self.db.profile.current_tab
        if panel.tabs and panel.tabs[tabID] then
            for index, tab in ipairs(panel.tabs) do
                if index == tabID then tab:ToFront() else tab:ToBack() end
            end
            panel.current_tab = panel.tabs[tabID]
        end
        if panel:IsShown() and private.CurrentProfession then
            panel:UpdateTitle()
            panel.list_frame:Update(nil, false)
        end
    end
    self.db.RegisterCallback(self, "OnProfileChanged", RefreshProfilePreferences)
    self.db.RegisterCallback(self, "OnProfileCopied", RefreshProfilePreferences)
    self.db.RegisterCallback(self, "OnProfileReset", RefreshProfilePreferences)

    local version = private.GetAddOnMetadata("AckisRecipeList", "Version")
    self.version = version
    self:SetupOptions()

    -- ----------------------------------------------------------------------------
    -- Hook GameTooltip to show recipe information on mobs that drop/sell/train
    -- ----------------------------------------------------------------------------
    local npcRecipeCache = {}
    local lastCachePrune = 0
    local CACHE_DURATION = 30

    function private.InvalidateNPCRecipeCache()
        table.wipe(npcRecipeCache)
    end

    local function GetNPCRecipeList(npcID)
        local now = _G.GetTime()
        if now - lastCachePrune >= CACHE_DURATION then
            for id, entry in pairs(npcRecipeCache) do
                if now - entry.time >= CACHE_DURATION then npcRecipeCache[id] = nil end
            end
            lastCachePrune = now
        end
        local cached = npcRecipeCache[npcID]
        if cached and (now - cached.time) < CACHE_DURATION then
            return cached.recipes
        end
        return nil
    end

    local function CacheNPCRecipes(npcID)
        local recipes, seen = {}, {}
        for _, acquireType in ipairs({private.AcquireTypes.MobDrop, private.AcquireTypes.Vendor,
            private.AcquireTypes.Trainer, private.AcquireTypes.Mixed}) do
            local entity = acquireType:GetEntity(npcID)
            for spellID in pairs(entity and entity.item_list or {}) do
                local recipe = private.recipe_list[spellID]
                if recipe and not seen[spellID] then
                    seen[spellID] = true
                    recipes[#recipes + 1] = recipe
                end
            end
        end
        table.sort(recipes, function(a, b)
            local ap = a.Profession and a.Profession:LocalizedName() or _G.UNKNOWN
            local bp = b.Profession and b.Profession:LocalizedName() or _G.UNKNOWN
            if ap ~= bp then return ap < bp end
            local an, bn = a:LocalizedName() or _G.UNKNOWN, b:LocalizedName() or _G.UNKNOWN
            if an ~= bn then return an < bn end
            return a:SpellID() < b:SpellID()
        end)
        npcRecipeCache[npcID] = {
            recipes = recipes,
            time = _G.GetTime()
        }
        return recipes
    end

    local function AddRecipeLine(tooltip, recipe)
        local qualityID = recipe:QualityID()
        local hex = "ffffffff"
        if private.GetItemQualityColor then
            local ok, r, g, b, h = pcall(private.GetItemQualityColor, qualityID)
            if ok and h then
                hex = h
            end
        end

        local professionName = recipe.Profession and recipe.Profession:LocalizedName() or _G.UNKNOWN
        local recipeName = recipe:LocalizedName() or _G.UNKNOWN
        local skillLevel = recipe.skill_level or 0

        tooltip:AddLine(("%s: |c%s%s|r (%d)"):format(professionName, hex, recipeName, skillLevel))
    end

    local function AddUnitTooltipRecipes(tooltip, tooltipData)
        if private.addonEnabled == false or not addon.db.profile.recipes_in_tooltips then
            return
        end

        -- Forever's TooltipDataProcessor supplies the GUID when available.
        -- Resolve the tooltip unit if the data does not include it.
        local guid = tooltipData and tooltipData.guid
        if not guid then
            local _, tooltipUnit = tooltip:GetUnit()
            guid = tooltipUnit and _G.UnitGUID(tooltipUnit)
        end
        if not guid then
            return
        end

        local npcID = private.MobGUIDToIDNum(guid)
        if not npcID then
            return
        end

        local recipes = GetNPCRecipeList(npcID)
        if not recipes then
            recipes = CacheNPCRecipes(npcID)
        end

        if #recipes == 0 then
            return
        end

        local player = private.Player
        local maxRecipes = addon.db.profile.max_recipes_in_tooltips or 10
        local showAll = _G.IsShiftKeyDown()
        local addedCount = 0

        for i = 1, #recipes do
            local recipe = recipes[i]
            local professionName = recipe.Profession and recipe.Profession:LocalizedName()

            if professionName and player.scanned_professions[professionName] then
                local skillLevel = player.professions[professionName]
                local hasLevel = skillLevel and skillLevel >= (recipe.skill_level or 0)

                local isKnown = recipe.HasState and recipe:HasState("KNOWN")
                local hasFaction = player.HasRecipeFaction and player:HasRecipeFaction(recipe)

                if (showAll or (not isKnown and hasLevel)) and hasFaction then
                    AddRecipeLine(tooltip, recipe)
                    addedCount = addedCount + 1

                    if addedCount >= maxRecipes then
                        break
                    end
                end
            end
        end
    end

    -- Use Forever's native unit-tooltip data callback.
    _G.TooltipDataProcessor.AddTooltipPostCall(_G.Enum.TooltipDataType.Unit, AddUnitTooltipRecipes)
end

function addon:UpdateMinimapIcon()
    if private.addonEnabled == false then ldbi:Hide("AckisRecipeList"); return end
    ldbi:Refresh("AckisRecipeList", self.db and self.db.profile and self.db.profile.minimapIcon)
    UpdateMinimapIconLayout()
end

-- Function run when the addon is enabled.  Registers events and pre-loads certain variables.
function addon:OnEnable()
    private.addonEnabled = true
    if private.RefreshGuideTracking then private.RefreshGuideTracking() end
    if private.RefreshRecipeTracking then private.RefreshRecipeTracking() end
    self.AcquireTypes = private.AcquireTypes

    -- Base events - always needed
    self:RegisterEvent("TRADE_SKILL_SHOW")
    self:RegisterEvent("TRADE_SKILL_CLOSE")
    self:InitializeProfessionIntegration()

    private.Player:Initialize()
    private.RegisterPlayerEvents(self)
    self:UpdateMinimapIcon()
    if self.profession_scan_tab then self.profession_scan_tab:Show() end

    -- ----------------------------------------------------------------------------
    -- Initialize the profession specialty table.
    -- ----------------------------------------------------------------------------
    do
        local EngineeringSpec = {
            [private.GetSpellName(20219)] = 20219, -- Gnomish
            [private.GetSpellName(20222)] = 20222, -- Goblin
        }

        SpecialtyTable = {
            [private.LOCALIZED_PROFESSION_NAMES.ENGINEERING] = EngineeringSpec,
        }

    end
end

-- ============================================================================
-- CONDITIONAL UI EVENTS
-- Events registered only when the main panel is visible.
-- This reduces event dispatch overhead when the UI is hidden.
-- Called from Panel.lua OnShow/OnHide handlers.
-- ============================================================================

local uiEventsRegistered = false

--- Register UI events when the main panel is shown
--- @return void
function private.RegisterUIEvents()
    if private.addonEnabled == false then return end
    if uiEventsRegistered then return end
    uiEventsRegistered = true

    addon:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    addon:RegisterEvent("NEW_RECIPE_LEARNED")
end

--- Unregister UI events when the main panel is hidden
--- @return void
function private.UnregisterUIEvents()
    if private.CancelUIRefresh then private.CancelUIRefresh() end
    if private.CancelPendingScan then private.CancelPendingScan() end
    if not uiEventsRegistered then return end
    uiEventsRegistered = false

    addon:UnregisterEvent("TRADE_SKILL_LIST_UPDATE")
    addon:UnregisterEvent("NEW_RECIPE_LEARNED")
end

-- ============================================================================
-- ADDON LIFECYCLE
-- ============================================================================

function addon:OnDisable()
    private.addonEnabled = false
    private.UnregisterUIEvents()
    private.UnregisterPlayerEvents(self)
    self:HideProfessionGuideTip()
    if self.professionGuideTipWatcher then self.professionGuideTipWatcher:UnregisterAllEvents() end
    if self.professionLoader then self.professionLoader:UnregisterAllEvents() end
    if self.profession_scan_tab then self.profession_scan_tab:Hide() end
    self:ClearWaypoints()
    if private.HideGuideTracking then private.HideGuideTracking() end
    if private.HideRecipeTracking then private.HideRecipeTracking() end
    ldbi:Hide("AckisRecipeList")
    if addon.Frame then
        addon.Frame:Hide()
    end
end


-- ============================================================================
-- SCAN BUTTON MANAGEMENT
-- The Scan tab attaches to the Forever professions frame.
-- ============================================================================

local function AnchorProfessionSidebar(sidebar, owner)
    sidebar:ClearAllPoints()
    sidebar:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", 0, 0)
end

function addon:CloseProfessionPanel()
    if self.Frame then self.Frame:Hide() end
    self:SyncProfessionTab()
end

function addon:SyncProfessionTab()
    local panel, tab = self.Frame, self.profession_scan_tab
    if not tab then return end
    if panel and not panel.arlLauncherHooks then
        panel.arlLauncherHooks = true
        panel:HookScript("OnHide", function() addon:SyncProfessionTab() end)
        panel:HookScript("OnShow", function() addon:SyncProfessionTab() end)
    end
    tab:SetChecked(panel and panel:IsShown() or false)
    if panel and panel:IsShown() then self:HideProfessionGuideTip() end
end

-- Beginner guide discovery uses Blizzard's HelpTip, independent of the recipe scan.
do
    local tipText, tipProfession
    local unavailableModules = {}

    function addon:HideProfessionGuideTip()
        if tipText and self.profession_scan_tab then
            _G.HelpTip:Hide(self.profession_scan_tab, tipText)
        end
        tipText, tipProfession = nil, nil
    end

    function addon:MaybeShowProfessionGuideTip()
        if private.addonEnabled == false then return end
        local tab = self.profession_scan_tab
        if not tab or not tab:IsVisible() or not _G.ProfessionsFrame:IsVisible() then return end
        local id, name, rank = private.GetTradeSkillLine()
        local linked = _G.C_TradeSkillUI.IsTradeSkillLinked() or _G.C_TradeSkillUI.IsTradeSkillGuild()
        if tipProfession and (tipProfession ~= id or rank ~= 1 or linked) then self:HideProfessionGuideTip() end
        if not id or rank ~= 1 or linked or (self.Frame and self.Frame:IsShown()) then return end
        local moduleName = private.LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[name]
        if not moduleName then return end
        local seen = self.db.char.professionGuideHelpSeen
        if not seen then seen = {}; self.db.char.professionGuideHelpSeen = seen end
        if seen[moduleName] or unavailableModules[moduleName] then return end

        local module = self:GetModule(moduleName, true)
        if not module then
            local exists, _, _, _, reason = private.GetAddOnInfo(FOLDER_NAME .. "_" .. moduleName)
            if not exists or reason == "MISSING" or reason == "DISABLED" then
                unavailableModules[moduleName] = true
                return
            end
            -- Use the normal module initializer so shared acquisition data is
            -- ready before a load-on-demand module enables itself.
            if not self:InitializeProfession(name, true) then
                unavailableModules[moduleName] = true
                return
            end
            module = self:GetModule(moduleName, true)
        end
        if not module or module.IsStub then return end
        -- Resolve the selected faction/route without starting a scan or opening Ackis.
        local guide = private.GetProfessionGuide({ Module = function() return module end })
        if not guide or not guide.chapters or #guide.chapters == 0 then return end
        local text = L["PROFESSION_GUIDE_HELP"]:format(name)
        local shown = _G.HelpTip:Show(tab, {
            text = text,
            buttonStyle = _G.HelpTip.ButtonStyle.Close,
            targetPoint = _G.HelpTip.Point.RightEdgeCenter,
            alignment = _G.HelpTip.Alignment.Center,
            autoEdgeFlipping = true,
            autoHideWhenTargetHides = true,
        }, tab)
        if shown then
            seen[moduleName] = true
            tipText, tipProfession = text, id
        end
    end

    function addon:WatchProfessionGuideTip()
        if private.addonEnabled == false then return end
        if not self.professionGuideTipWatcher then
            local watcher = _G.CreateFrame("Frame")
            watcher:SetScript("OnEvent", function() addon:MaybeShowProfessionGuideTip() end)
            self.professionGuideTipWatcher = watcher
        end
        -- The selected profession may arrive after the frame's OnShow.
        self.professionGuideTipWatcher:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
        self:MaybeShowProfessionGuideTip()
    end
end

function addon:ToggleProfessionPanel(mouseButton)
    if private.addonEnabled == false then return end
    if mouseButton and mouseButton ~= "LeftButton" then return end
    if _G.IsAltKeyDown() and not _G.IsControlKeyDown() then
        self:ClearWaypoints()
        return
    end
    if _G.IsControlKeyDown() then return end
    self:HideProfessionGuideTip()
    local tab = self.profession_scan_tab
    if not tab or not _G.ProfessionsFrame:IsShown() then return end
    if self.Frame and self.Frame:IsShown() then
        self:CloseProfessionPanel()
        return
    end

    if private.InitializeFrame then private.InitializeFrame() end
    local panel = self.Frame
    if not panel then return end
    self:SyncProfessionTab()
    self:EnsureProfessionOpenAndScan()
    self:SyncProfessionTab()
end

function addon:EnsureProfessionTab()
    local professions = _G.ProfessionsFrame
    if not professions then return end
    if self.profession_scan_tab then return self.profession_scan_tab end

    local sidebar = _G.ProfessionsFrameTabSideBar
    if not sidebar then
        sidebar = _G.CreateFrame("Frame", nil, professions)
        sidebar:SetWidth(1)
        sidebar.Tabs = {}
        sidebar.selTab = 0
        _G.ProfessionsFrameTabSideBar = sidebar
        AnchorProfessionSidebar(sidebar, professions)
    end

    if not sidebar.Tabs[1] then
        local reserved = _G.CreateFrame("Frame", nil, sidebar)
        reserved:Hide()
        sidebar.Tabs[1] = reserved
    end
    local index = 2
    while sidebar.Tabs[index] do index = index + 1 end
    -- Keep native dimensions, side-tab artwork and mouse/selection handling intact.
    local tab = _G.CreateFrame("Frame", "AckisRecipeListProfessionTab", professions, "QuestLogTabButtonTemplate")
    tab:SetFrameLevel(professions:GetFrameLevel() + 20)
    tab.displayMode = _G.QuestLogDisplayMode.Quests
    tab.tooltipText = "Ackis Recipe List - " .. L["Scan"] .. "\n" .. L["SCAN_RECIPES_DESC"]
    local function restoreIcon()
        tab.Icon:SetTexture([[Interface\Icons\INV_Misc_Book_11]])
        -- Fill the side-tab interior and crop the icon's inset border.
        tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.Icon:SetSize(40, 40)
    end
    -- SetChecked updates the native icon atlas; restore only Ackis' icon.
    _G.hooksecurefunc(tab, "SetChecked", restoreIcon)
    tab:SetCustomOnMouseUpHandler(function()
        addon:ToggleProfessionPanel("LeftButton")
        addon:SyncProfessionTab()
    end)
    tab:SetChecked(false)
    local function positionTab()
        tab:ClearAllPoints()
        -- Keep the sidebar launcher at the bottom, away from the upper tabs
        tab:SetPoint("BOTTOMLEFT", professions, "BOTTOMRIGHT", -2, 12)
    end
    positionTab()
    tab:HookScript("OnShow", positionTab)
    tab.sidebarIndex = index
    sidebar.Tabs[index] = tab
    self.profession_scan_tab = tab
    if self.scan_button then self.scan_button:Hide() end
    self.scan_button = tab
    professions:HookScript("OnHide", function() addon:TRADE_SKILL_CLOSE() end)
    professions:HookScript("OnShow", function()
        if private.addonEnabled == false then return end
        positionTab(); tab:Show(); addon:WatchProfessionGuideTip()
    end)
    self:SyncProfessionTab()
    return tab
end

function addon:InitializeProfessionIntegration()
    if self:EnsureProfessionTab() then return end
    if self.professionLoader then self.professionLoader:RegisterEvent("ADDON_LOADED"); return end
    local loader = _G.CreateFrame("Frame")
    self.professionLoader = loader
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(frame)
        if private.addonEnabled == false then return end
        if addon:EnsureProfessionTab() then
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

function addon:TRADE_SKILL_SHOW()
    if private.addonEnabled == false then return end
    local tab = self:EnsureProfessionTab()
    if tab then tab:Show() end
    self:SyncProfessionTab()
    self:WatchProfessionGuideTip()
end

function addon:TRADE_SKILL_CLOSE()
    self:HideProfessionGuideTip()
    if self.professionGuideTipWatcher then self.professionGuideTipWatcher:UnregisterAllEvents() end
    if private.CancelPendingScan then private.CancelPendingScan() end
    if private.CancelUIRefresh then private.CancelUIRefresh() end
    if self.Frame and addon.db.profile.closeguionskillclose then
        self.Frame:Hide()
    end
end

do
    local last_update = 0
    local updater = _G.CreateFrame("Frame")
    updater:Hide()

    function private.CancelUIRefresh()
        last_update = 0
        updater:Hide()
    end

    updater:SetScript("OnUpdate", function(self, elapsed)
        if private.addonEnabled == false or not addon.Frame or not addon.Frame:IsVisible() then
            private.CancelUIRefresh()
            return
        end
        last_update = last_update + elapsed

        if last_update >= 0.5 then
            local _, localizedProfessionName = private.GetTradeSkillLine()

            self:Hide()
            if localizedProfessionName and localizedProfessionName ~= "" and localizedProfessionName ~= _G.UNKNOWN then
                addon:Scan(false, true)
            end
        end
    end)

    function addon:TRADE_SKILL_LIST_UPDATE()
        if private.addonEnabled == false or not self.Frame or not self.Frame:IsVisible() then
            return
        end

        if not updater:IsVisible() then
            last_update = 0
            updater:Show()
        end
    end

    -- Debounced refresh when a new spell/recipe is learned or the trade skill system updates
    local function DebouncedScanIfVisible()
        if private.addonEnabled == false or not addon.Frame or not addon.Frame:IsVisible() then
            return
        end
        local _, lp = private.GetTradeSkillLine()
        if not lp or lp == _G.UNKNOWN then
            -- Native data may be changing; wait for its next update without a popup.
            return
        end
        if not updater:IsVisible() then
            last_update = 0
            updater:Show()
        end
    end

    function addon:NEW_RECIPE_LEARNED()
        DebouncedScanIfVisible()
    end

end

-- ----------------------------------------------------------------------------
-- ARL Logic Functions
-- ----------------------------------------------------------------------------
do
    local function InitializeLookups()
        addon:InitCustom()
        addon:InitDiscoveries()
        addon:InitMob()
        addon:InitQuest()
        addon:InitReputation()
        addon:InitTrainer()
        addon:InitWorldEvents()
        addon:InitVendor()
        addon:InitMixed()
        if private.InvalidateNPCRecipeCache then private.InvalidateNPCRecipeCache() end

        InitializeLookups = nil
    end

    local function ReportModuleLoadError(moduleName, diagnostic, suppressDialogs)
        addon.moduleLoadErrors = addon.moduleLoadErrors or {}
        if not suppressDialogs and addon.moduleLoadErrors[moduleName] ~= diagnostic then
            addon.moduleLoadErrors[moduleName] = diagnostic
            addon:Print(("Unable to load %s_%s: %s"):format(FOLDER_NAME, moduleName, diagnostic))
        end
        return false
    end

    local function ValidateProfessionModule(module, moduleName, moduleFolderName, suppressDialogs)
        if not module then
            return ReportModuleLoadError(moduleName, "MODULE_NOT_REGISTERED", suppressDialogs)
        end
        if _G.C_AddOns.DoesAddOnHaveLoadError(moduleFolderName) then
            return ReportModuleLoadError(moduleName, "SCRIPT_ERROR", suppressDialogs)
        end
        if module.Version ~= SUPPORTED_MODULE_VERSION then
            if not suppressDialogs then addon:SpawnModuleWrongVersionDialog({
                moduleName = moduleName, moduleVersion = module.Version or "Unknown",
            }) end
            return false
        end
        return true
    end

    -- Enable only validated modules and verify that OnEnable replaced any stub.
    local function InitializeProfessionModule(module, moduleName, moduleFolderName, suppressDialogs, newlyLoaded)
        if not ValidateProfessionModule(module, moduleName, moduleFolderName, suppressDialogs) then
            return false
        end
        local wasEnabled = module:IsEnabled()
        if not wasEnabled then
            module:Enable()
        end
        if (newlyLoaded or not wasEnabled) and private.InvalidateNPCRecipeCache then
            private.InvalidateNPCRecipeCache()
        end
        local initialized = private.Professions[moduleName]
        if not initialized or initialized:Module() ~= module then
            if not suppressDialogs then addon:Print("Unable to initialize profession module: " .. moduleFolderName) end
            return false
        end
        return true
    end

    -- Returns true if a profession was initialized.
    function addon:InitializeProfession(localizedProfessionName, suppressDialogs)
        if private.ResolveProfessionName then
            localizedProfessionName = private.ResolveProfessionName(nil, localizedProfessionName)
        end
        -- Normalize known spell aliases to the localized profession name.
        local professionModuleName = localizedProfessionName and
            private.LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[localizedProfessionName] or nil
        if not professionModuleName and private.LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING then
            local baseName = private.LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[localizedProfessionName]
            if baseName then
                localizedProfessionName = baseName
                professionModuleName = private.LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[localizedProfessionName]
            end
        end
        if not professionModuleName then
            return false
        end

        if InitializeLookups then
            InitializeLookups()
        end

        local moduleFolderName = FOLDER_NAME .. "_" .. professionModuleName

        local registered = private.Professions[professionModuleName]
        if registered and not registered:Module().IsStub then
            return ValidateProfessionModule(registered:Module(), professionModuleName, moduleFolderName, suppressDialogs)
        end

        local professionModule = self:GetModule(professionModuleName, true)
        if not professionModule then
            local exists, _, _, _, reason = private.GetAddOnInfo(moduleFolderName)
            local loaded, loadReason
            if exists and reason ~= "DISABLED" and reason ~= "MISSING" then
                loaded, loadReason = private.LoadAddOn(moduleFolderName)
                if loaded and _G.C_AddOns.DoesAddOnHaveLoadError(moduleFolderName) then
                    loaded, loadReason = false, "SCRIPT_ERROR"
                end
                if private.InvalidateNPCRecipeCache then private.InvalidateNPCRecipeCache() end
            end

            if reason == "DISABLED" or loadReason == "DISABLED" then
                if not suppressDialogs then
                    ShowDisabledProfessionModuleDialog(professionModuleName)
                end
                return false
            elseif not loaded then
                if exists and reason ~= "MISSING" and loadReason ~= "MISSING" then
                    -- Preserve the native diagnostic instead of pretending the module is absent.
                    local diagnostic = loadReason or (reason ~= "" and reason) or "INITIALIZATION_FAILED"
                    return ReportModuleLoadError(professionModuleName, diagnostic, suppressDialogs)
                end
                -- A missing module may expose empty data, but a load error must not.
                local label = private.LOCALIZED_PROFESSION_NAME_TO_LABEL[localizedProfessionName]
                local activationSpellID = label and addon.constants.PROFESSION_SPELL_IDS[label]
                local stub = {
                    GetName = function() return professionModuleName end,
                    ModuleName = professionModuleName,
                    Version = SUPPORTED_MODULE_VERSION,
                    IsStub = true,
                    ITEM_FILTER_TYPES = {},
                    Recipes = {},
                    ActivationSpellID = activationSpellID,
                }
                if not registered and addon.CreateProfessionFromModule then
                    addon.CreateProfessionFromModule(stub)
                end
                -- Warn the user about this specific missing profession module (once per profession per session)
                addon._missingModuleWarned = addon._missingModuleWarned or {}
                if not suppressDialogs and not addon._missingModuleWarned[professionModuleName] then
                    addon._missingModuleWarned[professionModuleName] = true
                    local displayModuleName = (private.addon_display_name or private.addon_name) ..
                        ": " .. (professionModuleName or localizedProfessionName or "Unknown")
                    ShowMissingProfessionModuleDialog({
                        localizedProfessionName = localizedProfessionName,
                        moduleName = displayModuleName,
                    })
                end

                -- Only warn if truly no profession modules are present at all; avoid false positives when a specific module fails to load.
                if not addon._warnedNoModules then
                    local hasAnyModule = false
                    for modName in pairs(private.MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING or {}) do
                        local name, _, _, _, r = private.GetAddOnInfo(FOLDER_NAME .. "_" .. modName)
                        if name and r ~= "MISSING" then
                            hasAnyModule = true
                            break
                        end
                    end
                    if not hasAnyModule and not suppressDialogs then
                        addon._warnedNoModules = true
                        _G.StaticPopup_Show("ARL_NoModulesErrorDialog")
                    end
                end
                return private.Professions[professionModuleName] ~= nil
            end

            -- LoadOnDemand module was successfully loaded - retrieve and enable it
            professionModule = self:GetModule(professionModuleName, true)
            return InitializeProfessionModule(professionModule, professionModuleName, moduleFolderName, suppressDialogs, true)
        end
        return InitializeProfessionModule(professionModule, professionModuleName, moduleFolderName, suppressDialogs, false)
    end
end -- do-block

local function OpenProfileOptions()
    if not addon.optionsFrame or not addon.optionsFrame.Profiles then addon:SetupOptions() end
    OpenOptions(addon.optionsFrame.Profiles)
end

local SUBCOMMAND_FUNCS = {
    [L["Profile"]:lower()] = OpenProfileOptions,
    [L["Scan"] and L["Scan"]:lower() or "scan"] = function()
        if private.InitializeFrame then private.InitializeFrame() end
        addon:EnsureProfessionOpenAndScan()
    end,
    scan = function()
        if private.InitializeFrame then private.InitializeFrame() end
        addon:EnsureProfessionOpenAndScan()
    end,
    -- alias for profiles
    profiles = OpenProfileOptions,
    -- Open UI for the profession selected by the player
    ui = function()
        if private.InitializeFrame then private.InitializeFrame() end
        addon:EnsureProfessionOpenAndScan()
    end,
    toggle = function()
        if private.InitializeFrame then private.InitializeFrame() end
        addon:EnsureProfessionOpenAndScan()
    end,

}

-- Check whether a trade skill window is open
local function IsTradeSkillOpen()
    if not _G.ProfessionsFrame or not _G.ProfessionsFrame:IsVisible() then
        return false
    end
    local _, name = private.GetTradeSkillLine()
    return name and name ~= "" and name ~= _G.UNKNOWN
end

function addon:ChatCommand(input)
    if private.addonEnabled == false then return end
    local arg1, arg2 = self:GetArgs(input, 2)

    if arg1 then
        arg1 = arg1:trim():lower()
    end

    -- If no args, open the ARL UI (ensure a profession is open, then scan)
    if not arg1 then
        -- Requirement: if no profession window is open, print a chat message and do not auto-open
        if not IsTradeSkillOpen() then
            self:Print("Please open a profession window first to start the scan.")
            return
        end
        if private.InitializeFrame then private.InitializeFrame() end
        self:EnsureProfessionOpenAndScan()
    elseif arg1 == "ui" or arg1 == "toggle" then
        if private.InitializeFrame then private.InitializeFrame() end
        self:EnsureProfessionOpenAndScan()
    else
        local func = SUBCOMMAND_FUNCS[arg1]
        if func then
            func(arg2)
        else
            -- Unknown subcommand: default to opening the UI (no AceConfigCmd fallback)
            if private.InitializeFrame then private.InitializeFrame() end
            addon:EnsureProfessionOpenAndScan()
        end
    end
end

-- Ensure a profession is open;
function addon:EnsureProfessionOpenAndScan()
    if private.addonEnabled == false then return end
    if IsTradeSkillOpen() then
        self:Scan(false, false)
        if not self.scan_button then
            self:TRADE_SKILL_SHOW()
        end
        return
    end
    self:Print("Open a profession window (e.g., via the spellbook) before scanning ARL.")
end

-- ----------------------------------------------------------------------------
-- Recipe Scanning Functions
-- ----------------------------------------------------------------------------
do
    -- Listen only while a requested scan is waiting for complete native data.
    local pendingScan
    local lastScanProfession, lastScanRank, lastScanLinked, lastScanSpecialty, lastScanPlayerRevision
    local pendingFrame
    local lastChainError

    local function GetScanContext()
        local professionID, _, rank, _, _, _, name = private.GetTradeSkillLine()
        local linked, linkedName = _G.C_TradeSkillUI.IsTradeSkillLinked()
        local guild, guildName = _G.C_TradeSkillUI.IsTradeSkillGuild()
        return { professionID = professionID, name = name, rank = rank,
            linked = not not linked, guild = not not guild,
            linkedName = linkedName, guildName = guildName }
    end

    local function SameScanContext(left, right)
        return left.professionID == right.professionID and left.name == right.name and
            left.linked == right.linked and left.guild == right.guild and
            left.linkedName == right.linkedName and left.guildName == right.guildName
    end

    function private.CancelPendingScan()
        pendingScan = nil
        if pendingFrame then pendingFrame:UnregisterAllEvents() end
    end

    local function DeferScan(isRefresh, context)
        if not pendingFrame then
            pendingFrame = _G.CreateFrame("Frame")
            pendingFrame:SetScript("OnEvent", function()
                local request = pendingScan
                if not request or request.queued then return end
                request.queued = true
                _G.C_Timer.After(0.1, function()
                    if pendingScan ~= request then return end
                    request.queued = nil
                    if private.addonEnabled ~= false and IsTradeSkillOpen()
                        and (not request.isRefresh or (addon.Frame and addon.Frame:IsVisible()))
                        and SameScanContext(request.context, GetScanContext()) then
                        addon:Scan(false, request.isRefresh)
                    else
                        private.CancelPendingScan()
                    end
                end)
            end)
        end
        if pendingScan and not SameScanContext(pendingScan.context, context) then
            private.CancelPendingScan()
        end
        if not pendingScan then
            pendingScan = { isRefresh = isRefresh, context = context }
            if not isRefresh then addon:Print("Profession recipes are still loading; ARL will retry when data is ready.") end
        elseif not isRefresh then
            pendingScan.isRefresh = false
        end
        pendingFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    end

    -- Evaluate each directional chain once, including nodes outside the main list.
    -- A cycle rejects the snapshot before any KNOWN/LINKED state is changed.
    local function ChainMatches(id, field, unlearned, cache, snapshot)
        local path, visited = {}, {}
        local current = id
        while current and cache[current] == nil do
            if visited[current] then return nil, current end
            visited[current] = true
            path[#path + 1] = current
            current = snapshot[current][field]
        end
        local matches = current and cache[current] or false
        for index = #path, 1, -1 do
            local node = path[index]
            local learned = snapshot[node].learned
            matches = matches or (unlearned and not learned or not unlearned and learned == true)
            cache[node] = matches
        end
        return matches
    end

    -- Read all related recipes before changing KNOWN/LINKED states.
    local function ReadRecipeSnapshot()
        local recipeIDs = _G.C_TradeSkillUI.GetAllRecipeIDs()
        if _G.C_TradeSkillUI.IsDataSourceChanging() or not recipeIDs or #recipeIDs == 0 then
            return
        end
        local recipeInfoByID, queue, queued = {}, {}, {}
        for _, recipeID in ipairs(recipeIDs) do
            queue[#queue + 1] = recipeID
            queued[recipeID] = true
        end
        local index = 1
        while index <= #queue do
            local recipeID = queue[index]
            local info = _G.C_TradeSkillUI.GetRecipeInfo(recipeID)
            if not info then
                return
            end
            recipeInfoByID[recipeID] = info
            for _, field in ipairs({"nextRecipeID", "previousRecipeID"}) do
                local related = info[field]
                if related and not queued[related] then
                    queued[related] = true
                    queue[#queue + 1] = related
                end
            end
            index = index + 1
        end
        return recipeIDs, recipeInfoByID
    end

    local function ValidateRecipeSnapshot(recipeIDs, recipeInfoByID)
        local descendantCache, ancestorCache, ignoredByID = {}, {}, {}
        for _, recipeID in ipairs(recipeIDs) do
            local info = recipeInfoByID[recipeID]
            local descendant, descendantError = ChainMatches(info.nextRecipeID, "nextRecipeID", false, descendantCache, recipeInfoByID)
            local ancestor, ancestorError = ChainMatches(info.previousRecipeID, "previousRecipeID", true, ancestorCache, recipeInfoByID)
            local chainError = descendantError or ancestorError
            if chainError then
                return nil, chainError
            end
            ignoredByID[recipeID] = descendant or ancestor
        end
        return ignoredByID
    end

    local function PrepareProfessionScan(context)
        local professionRank, localizedProfessionName = context.rank, context.name
        private.current_profession_specialty = nil

        local professionModuleName = private.LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[localizedProfessionName]
        if not professionModuleName or not addon:InitializeProfession(localizedProfessionName) then
            return
        end

        local profession = private.Professions[localizedProfessionName] or private.Professions[professionModuleName]
        if not profession or not profession.Recipes then
            addon:Print("Unable to initialize profession: " .. localizedProfessionName)
            return
        end

        local player = private.Player
        player:UpdateProfessions()

        private.current_profession_scanlevel = professionRank

        -- Make sure we're only updating a profession the character actually knows - this could be a scan from a tradeskill link.
        local isTradesSkillLinked = context.linked or context.guild
        if not isTradesSkillLinked then
            player.scanned_professions[localizedProfessionName] = true
        end

        local professionSpecialties = SpecialtyTable[localizedProfessionName]
        if professionSpecialties then
            for _, spellID in pairs(professionSpecialties) do
                if _G.C_SpellBook.IsSpellKnown(spellID, _G.Enum.SpellBookSpellBank.Player) then
                    private.current_profession_specialty = spellID
                    break
                end
            end
        end

        -- If this profession is backed by a stub (module missing), ensure the user gets a warning once
        if profession.Module and profession:Module().IsStub then
            addon._missingModuleWarned = addon._missingModuleWarned or {}
            local moduleName = private.LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[localizedProfessionName]
            if moduleName and not addon._missingModuleWarned[moduleName] then
                addon._missingModuleWarned[moduleName] = true
                local displayModuleName = (private.addon_display_name or private.addon_name) ..
                    ": " .. (moduleName or localizedProfessionName or "Unknown")
                ShowMissingProfessionModuleDialog({
                    localizedProfessionName = localizedProfessionName,
                    moduleName = displayModuleName
                })
            end
        end
        return profession
    end

    -- Apply only the validated snapshot; never read native recipe data here.
    local function ApplyRecipeSnapshot(profession, recipeIDs, recipeInfoByID, ignoredByID, isTradesSkillLinked)
        local stateChanged = false
        local learnedState = isTradesSkillLinked and "LINKED" or "KNOWN"
        local ignoredState = isTradesSkillLinked and "LINKED_IGNORED" or "IGNORED"
        for recipeIndex = 1, #recipeIDs do
            local recipeID = recipeIDs[recipeIndex]
            local recipe = profession.Recipes[recipeID]
            local recipeInfo = recipeInfoByID[recipeID]

            if recipe then
                local wasLearned = recipe:HasState(learnedState)
                local wasIgnored = recipe:HasState(ignoredState)
                stateChanged = stateChanged or not recipe.isValidated
                recipe.isValidated = true
                recipe:RemoveState(ignoredState)
                if recipeInfo.learned then
                    recipe:AddState(learnedState)
                elseif ignoredByID[recipeID] then
                    recipe:AddState(ignoredState)
                    recipe:RemoveState(learnedState)
                else
                    recipe:RemoveState(learnedState)
                end
                if not isTradesSkillLinked then
                    recipe:RemoveState("LINKED")
                    recipe:RemoveState("LINKED_IGNORED")
                end
                stateChanged = stateChanged or wasLearned ~= recipe:HasState(learnedState) or
                    wasIgnored ~= recipe:HasState(ignoredState)
            end
        end

        if stateChanged and not isTradesSkillLinked and private.RefreshGuideRecipeStatus then
            private.RefreshGuideRecipeStatus(profession)
        end
        return stateChanged
    end

    local function UpdateScanDisplay(profession, context, stateChanged, isRefresh)
        local player = private.Player
        local professionRank = context.rank
        local isTradesSkillLinked = context.linked or context.guild
        player:UpdateReputations()
        local unchanged = not stateChanged and lastScanPlayerRevision == player.revision and lastScanProfession == profession and
            lastScanRank == professionRank and lastScanLinked == isTradesSkillLinked and
            lastScanSpecialty == private.current_profession_specialty
        lastScanProfession, lastScanRank, lastScanLinked, lastScanSpecialty =
            profession, professionRank, isTradesSkillLinked, private.current_profession_specialty
        lastScanPlayerRevision = player.revision
        if isRefresh and unchanged then return end

        -- ----------------------------------------------------------------------------
        -- Everything is ready - display the GUI.
        -- ----------------------------------------------------------------------------
        private.PreviousProfession = private.CurrentProfession
        private.CurrentProfession = profession
        if private.InitializeFrame then private.InitializeFrame() end
        if addon.Frame then addon.Frame:Display(isTradesSkillLinked) end
    end

    --- Causes a scan of the tradeskill to be conducted. Function called when the scan button is clicked.   Parses recipes and displays output
    -- @name AckisRecipeList:Scan
    -- @usage AckisRecipeList:Scan()
    -- The first argument is retained for compatibility with profession modules.
    -- @return The ARL frame
    function addon:Scan(_, isRefresh)
        if private.addonEnabled == false then return end
        if isRefresh and (not self.Frame or not self.Frame:IsVisible()) then return end
        local context = GetScanContext()
        if not context.name or context.name == _G.UNKNOWN then
            private.CancelPendingScan()
            self:Print(L["OpenTradeSkillWindow"])
            return
        end

        local recipeIDs, recipeInfoByID = ReadRecipeSnapshot()
        if not recipeIDs then
            DeferScan(isRefresh, context)
            return
        end
        local ignoredByID, chainError = ValidateRecipeSnapshot(recipeIDs, recipeInfoByID)
        if chainError then
            private.CancelPendingScan()
            local errorKey = context.name .. ":" .. chainError
            if lastChainError ~= errorKey then
                lastChainError = errorKey
                self:Print(("Invalid recipe chain for %s (recipe %d); the previous scan was preserved."):format(context.name, chainError))
            end
            return
        end
        if not SameScanContext(context, GetScanContext()) then
            private.CancelPendingScan()
            return
        end
        if _G.C_TradeSkillUI.IsDataSourceChanging() then DeferScan(isRefresh, context); return end
        lastChainError = nil
        private.CancelPendingScan()

        local profession = PrepareProfessionScan(context)
        if not profession then return end
        local stateChanged = ApplyRecipeSnapshot(profession, recipeIDs, recipeInfoByID, ignoredByID, context.linked or context.guild)
        UpdateScanDisplay(profession, context, stateChanged, isRefresh)
    end
end
