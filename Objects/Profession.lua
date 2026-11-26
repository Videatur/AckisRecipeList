--[[
    Ackis Recipe List - Profession Object

    Provides profession tracking and identification:
    - Profession spell IDs for all crafting professions
    - Localized name mappings for client language support
    - Expansion-specific spell tracking (Outland, Northrend, etc.)
    - Module registration for profession databases

    Copyright (c) 2009 - 2012 Ackis <John Pasula>
    All rights reserved by the original author Ackis.
]]

-- ============================================================================
-- Upvalued Lua API
-- ============================================================================
local pairs = _G.pairs

-- ============================================================================
-- AddOn Namespace
-- ============================================================================
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)

-- ============================================================================
-- Profession Spell IDs
-- Base spell IDs for each profession (used for identification)
-- ============================================================================
local PROFESSION_SPELL_IDS = {
	ALCHEMY = 2259,
	ARCHAEOLOGY = 78670,
	BLACKSMITHING = 2018,
	COOKING = 2550,
	ENCHANTING = 7411,
	ENGINEERING = 4036,
	FISHING = 7731,
	FIRST_AID = 1240927,
	LEATHERWORKING = 2108,
	MINING = 2575,
	TAILORING = 3908,
}

private.PROFESSION_SPELL_IDS = PROFESSION_SPELL_IDS
private.constants.PROFESSION_SPELL_IDS = PROFESSION_SPELL_IDS

-- Skill line IDs identify professions independently of their translated spells.
local PROFESSION_SKILL_LINE_IDS = {
    ALCHEMY = 171, ARCHAEOLOGY = 794, BLACKSMITHING = 164, COOKING = 185,
    ENCHANTING = 333, ENGINEERING = 202, FISHING = 356, FIRST_AID = 129,
    LEATHERWORKING = 165, MINING = 186, TAILORING = 197,
}
local SKILL_LINE_ID_TO_LABEL = {}
for label, id in pairs(PROFESSION_SKILL_LINE_IDS) do
    SKILL_LINE_ID_TO_LABEL[id] = label
end
private.PROFESSION_SKILL_LINE_IDS = PROFESSION_SKILL_LINE_IDS

-- ============================================================================
-- Localized Name Tables
-- Built from native skill line names, with spell names as a startup fallback
-- ============================================================================
local LOCALIZED_PROFESSION_NAMES = {}
private.LOCALIZED_PROFESSION_NAMES = LOCALIZED_PROFESSION_NAMES

local LOCALIZED_PROFESSION_NAME_TO_LABEL = {}
private.LOCALIZED_PROFESSION_NAME_TO_LABEL = LOCALIZED_PROFESSION_NAME_TO_LABEL

local PROFESSION_ID_TO_LOCALIZED_NAME = {}
private.PROFESSION_ID_TO_LOCALIZED_NAME = PROFESSION_ID_TO_LOCALIZED_NAME

for label, spellID in pairs(PROFESSION_SPELL_IDS) do
    local skillLineID = PROFESSION_SKILL_LINE_IDS[label]
    local info = _G.C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
    local professionName = info and info.professionName
    if not professionName or professionName == "" or professionName == _G.UNKNOWN then
        professionName = private.GetSpellName(spellID)
    end
	if professionName then
		LOCALIZED_PROFESSION_NAME_TO_LABEL[professionName] = label
		LOCALIZED_PROFESSION_NAMES[label] = professionName
		PROFESSION_ID_TO_LOCALIZED_NAME[spellID] = professionName
        PROFESSION_ID_TO_LOCALIZED_NAME[skillLineID] = professionName
	end
end

-- ============================================================================
-- Expansion Spell Mappings
-- Maps expansion-specific spell names to profession names
-- ============================================================================
local LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING = {}

local function MapSpellToProfession(spellID, label)
	local name = private.GetSpellName(spellID)
	local profName = LOCALIZED_PROFESSION_NAMES[label]
	if name and profName then
		LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[name] = profName
	end
end

-- First Aid ranks published by Forever, including its original spell aliases.
for _, spellID in ipairs({3273, 3274, 7924, 10846, 1240927, 1240928, 1240929, 1240930}) do
	MapSpellToProfession(spellID, 'FIRST_AID')
end

private.LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING = LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING

-- Add base profession names to mapping
for name, localized_name in pairs(LOCALIZED_PROFESSION_NAMES) do
	LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[localized_name] = localized_name
end

-- ============================================================================
-- Ordered Profession List
-- Used for UI display order
-- ============================================================================
local ORDERED_LOCALIZED_PROFESSION_NAMES = {
	LOCALIZED_PROFESSION_NAMES.ALCHEMY,
	LOCALIZED_PROFESSION_NAMES.BLACKSMITHING,
	LOCALIZED_PROFESSION_NAMES.COOKING,
	LOCALIZED_PROFESSION_NAMES.ENCHANTING,
	LOCALIZED_PROFESSION_NAMES.ENGINEERING,
	LOCALIZED_PROFESSION_NAMES.FIRST_AID,
	LOCALIZED_PROFESSION_NAMES.LEATHERWORKING,
	LOCALIZED_PROFESSION_NAMES.MINING,
	LOCALIZED_PROFESSION_NAMES.TAILORING,
}

private.ORDERED_LOCALIZED_PROFESSION_NAMES = ORDERED_LOCALIZED_PROFESSION_NAMES

-- ============================================================================
-- Module Name Mappings
-- Links localized names to module names for database loading
-- ============================================================================
local LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING = {}

local function AddProfMap(label, moduleName)
	local name = LOCALIZED_PROFESSION_NAMES[label]
	if name then
		LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[name] = moduleName
	end
end

AddProfMap('ALCHEMY', 'Alchemy')
AddProfMap('BLACKSMITHING', 'Blacksmithing')
AddProfMap('COOKING', 'Cooking')
AddProfMap('ENCHANTING', 'Enchanting')
AddProfMap('ENGINEERING', 'Engineering')
AddProfMap('FIRST_AID', 'FirstAid')
AddProfMap('LEATHERWORKING', 'Leatherworking')
AddProfMap('MINING', 'Mining')
AddProfMap('TAILORING', 'Tailoring')

private.LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING = LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING

local LOCALIZED_PROFESSION_NAME_TO_ID_MAPPING = {}
for index = 1, #ORDERED_LOCALIZED_PROFESSION_NAMES do
	local name = ORDERED_LOCALIZED_PROFESSION_NAMES[index]
	if name then
		LOCALIZED_PROFESSION_NAME_TO_ID_MAPPING[name] = index
	end
end

local MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING = {}
for localizedName, moduleName in pairs(LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING) do
	if localizedName and moduleName then
		MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[moduleName] = localizedName
		MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[moduleName:lower()] = localizedName
	end
end

private.MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING = MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING

-- Keep one canonical name for scans, player ranks and registered modules.
-- An ID takes precedence over text; unknown IDs must not guess a profession.
function private.ResolveProfessionName(skillLineID, name)
    local label = skillLineID and SKILL_LINE_ID_TO_LABEL[skillLineID]
    if skillLineID and not label then return name end
    local canonical = label and LOCALIZED_PROFESSION_NAMES[label]
        or LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[name]
        or MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[name]
    if not canonical then return name end
    if name and name ~= "" and name ~= _G.UNKNOWN then
        LOCALIZED_SPELL_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[name] = canonical
        LOCALIZED_PROFESSION_NAME_TO_LABEL[name] = label or LOCALIZED_PROFESSION_NAME_TO_LABEL[canonical]
        LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[name] = LOCALIZED_PROFESSION_NAME_TO_MODULE_NAME_MAPPING[canonical]
    end
    return canonical
end

-- Activation spell names can differ from the skill line name in any locale.
for label, spellID in pairs(PROFESSION_SPELL_IDS) do
    private.ResolveProfessionName(PROFESSION_SKILL_LINE_IDS[label], private.GetSpellName(spellID))
end

-- ============================================================================
-- Waypoint Icons
-- Icons for minimap/worldmap pins per profession
-- ============================================================================
local ICON_TEXTURE_FORMAT = [[Interface\ICONS\%s]]
local WAYPOINT_ICON_TEXTURES = {
	[[Trade_Alchemy]],
	[[Trade_BlackSmithing]],
	[[INV_Misc_Food_15]],
	[[Trade_Engraving]],
	[[Trade_Engineering]],
	[[Spell_Holy_SealOfSacrifice]],
	[[Trade_LeatherWorking]],
	[[Spell_Fire_FlameBlades]],
	[[Trade_Tailoring]],
}

-- ============================================================================
-- Profession Object
-- Represents a crafting profession with recipes
-- ============================================================================
local Profession = {}
local ProfessionMetatable = {
	__index = Profession,
}

private.Professions = {}

-- ============================================================================
-- Profession Methods
-- ============================================================================

function Profession:ActivationSpellName()
	return self._activationSpellName
end

function Profession:ID()
	return self._id
end

function Profession:LocalizedName()
	return self._localizedName
end

function Profession:Module()
	return self._module
end

function Profession:Name()
	return self._name
end

function Profession:WaypointIconTexture()
	local idx = self._id or 1
	local icon = WAYPOINT_ICON_TEXTURES[idx] or WAYPOINT_ICON_TEXTURES[1]
	return ICON_TEXTURE_FORMAT:format(icon)
end

-- ============================================================================
-- Profession Instantiation
-- ============================================================================

--- Create a Profession object from a module
--- @param module table The profession module
function addon.CreateProfessionFromModule(module)
	local moduleName = module:GetName()

	local localizedProfessionName = MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING[moduleName]
	if not localizedProfessionName then
		return
	end

	local profession = _G.setmetatable({
		_id = LOCALIZED_PROFESSION_NAME_TO_ID_MAPPING[localizedProfessionName],
		_localizedName = localizedProfessionName,
		_name = moduleName,
		_module = module,
		_recipeCount = 0,
		_activationSpellName = module.ActivationSpellID and private.GetSpellName(module.ActivationSpellID) or localizedProfessionName,
		Recipes = module.Recipes,
	}, ProfessionMetatable)

	private.Professions[moduleName] = profession
	private.Professions[localizedProfessionName] = profession
	module.Profession = profession

	-- Register default filter settings
	local defaults = {
		profile = {
			filters = {
				item = {}
			}
		}
	}

	for filter_name in pairs(module.ITEM_FILTER_TYPES) do
		defaults.profile.filters.item[filter_name:lower()] = true
		addon.constants.ITEM_FILTER_TYPES[filter_name] = true
	end

	-- moduleName comes from AceAddon and is available even when a load-on-demand
	-- module's OnInitialize has not populated its legacy ModuleName field yet.
	module.db = addon.db:RegisterNamespace(moduleName, defaults)
end
