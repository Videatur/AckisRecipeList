--[[
    Ackis Recipe List - Constants
    Global constants, filters, and Forever API adapters

    Provides:
    - API adapters for C_AddOns, C_CVar and C_Spell
    - Profession constants and localized names
    - Filter definitions and quality colors
    - Reputation and category mappings

    NOTE: This file must be loaded first as other files depend on
    the API adapters defined here.
]]

-- ============================================================================
-- Upvalued Lua API
-- ============================================================================
local pairs = _G.pairs
local pcall = _G.pcall
local string = _G.string
local table = _G.table
local tostring = _G.tostring
local type = _G.type

-- ============================================================================
-- AddOn Namespace
-- ============================================================================
local _, private = ...
private.addon_name = "Ackis Recipe List"
private.addon_display_name = "Ackis Recipe List Classic"

-- ============================================================================
-- FOREVER API ADAPTERS
-- These keep the return values expected by Ackis and its profession modules
-- while using Forever's namespaced APIs.
-- ============================================================================

--- Get addon metadata (version, author, etc.)
--- @param addonName string The addon name
--- @param field string The metadata field to retrieve
--- @return string|nil The metadata value
function private.GetAddOnMetadata(addonName, field)
    return _G.C_AddOns.GetAddOnMetadata(addonName, field)
end

-- Use the namespaced item API on Forever.
function private.GetItemInfo(itemInfo)
    return _G.C_Item.GetItemInfo(itemInfo)
end

-- Preserve all four color return values on Forever.
function private.GetItemQualityColor(qualityID)
    return _G.C_Item.GetItemQualityColor(qualityID)
end

--- Get information about an addon
--- @param addonNameOrIndex string|number The addon name or index
--- @return string name, string title, string notes, boolean loadable, string reason, string security
function private.GetAddOnInfo(addonNameOrIndex)
    return _G.C_AddOns.GetAddOnInfo(addonNameOrIndex)
end

--- Load an addon by name or index
--- @param addonNameOrIndex string|number The addon name or index
--- @return boolean success, string|nil reason
function private.LoadAddOn(addonNameOrIndex)
    return _G.C_AddOns.LoadAddOn(addonNameOrIndex)
end

--- Get a console variable value
--- @param name string The CVar name
--- @return string|nil value
function private.GetCVar(name)
    return _G.C_CVar.GetCVar(name)
end

--- Set a console variable value
--- @param name string The CVar name
--- @param value string|number|boolean|nil The value to set
--- @return boolean success
function private.SetCVar(name, value)
    if type(value) == "boolean" then
        value = value and "1" or "0"
    elseif value ~= nil then
        value = tostring(value)
    end
    local ok, success = pcall(_G.C_CVar.SetCVar, name, value)
    return ok and success == true
end

--- Get the name of a spell by ID
--- @param spellId number The spell ID
--- @return string|nil name
function private.GetSpellName(spellId)
    return _G.C_Spell.GetSpellName(spellId)
end

--- Get a spell hyperlink through C_Spell.
--- @param spellId number|string The spell ID or name
--- @return string|nil link
function private.GetSpellLink(spellId)
    return _G.C_Spell.GetSpellLink(spellId)
end

-- Required so constants can be assigned to the AddOn object in Core.lua in order to be accessible from profession modules
local constants = {}
private.constants = constants

-- ----------------------------------------------------------------------------
-- General constants.
-- ----------------------------------------------------------------------------
private.COORDINATES_FORMAT = "(%.2f, %.2f)"

-- Safe defaults for unavailable UI labels
local BATTLE_PET_SOURCE_3 = rawget(_G, "BATTLE_PET_SOURCE_3") or "Vendor"
local PARENS_TEMPLATE = rawget(_G, "PARENS_TEMPLATE") or "(%s)"
private.VENDOR_TYPE_FORMAT = BATTLE_PET_SOURCE_3 .. " " .. PARENS_TEMPLATE

-- ----------------------------------------------------------------------------
-- Item qualities.
-- ----------------------------------------------------------------------------
private.ITEM_QUALITY_NAMES = {
	"COMMON",
	"UNCOMMON",
	"RARE",
	"EPIC",
	"LEGENDARY",
}

private.ITEM_QUALITIES = {}
constants.ITEM_QUALITIES = private.ITEM_QUALITIES

for index = 1, #private.ITEM_QUALITY_NAMES do
	private.ITEM_QUALITIES[private.ITEM_QUALITY_NAMES[index]] = index
end

-- ----------------------------------------------------------------------------
-- Common filter bitfield word 1.
-- ----------------------------------------------------------------------------
private.COMMON_FLAGS_WORD1 = {
	ALLIANCE		= 0x00000001,	-- 1
	ACHIEVEMENT		= 0x00000002,	-- 2
	CASTER			= 0x00000004,	-- 3
	DISC			= 0x00000008,	-- 4
	DPS				= 0x00000010,	-- 5
	HEALER			= 0x00000020,	-- 6
	HORDE			= 0x00000040,	-- 7
	INSTANCE		= 0x00000080,	-- 8
	CUSTOM			= 0x00000100,	-- 9
	MOB_DROP		= 0x00000200,	-- 10
	PVP				= 0x00000400,	-- 11
	QUEST			= 0x00000800,	-- 12
	RAID			= 0x00001000,	-- 13
	REPUTATION		= 0x00002000,	-- 14
	RETIRED			= 0x00004000,	-- 15
	TANK			= 0x00008000,	-- 16
	TRAINER			= 0x00010000,	-- 17
	VENDOR			= 0x00020000,	-- 18
	WORLD_DROP		= 0x00040000,	-- 19
	WORLD_EVENT		= 0x00080000,	-- 20
	TRADE_SKILL		= 0x00100000,	-- 21
	MIXED 			= 0x00200000,	-- 22
}

-- ----------------------------------------------------------------------------
-- Class filter bitfield word 1.
-- ----------------------------------------------------------------------------
private.CLASS_FLAGS_WORD1 = {
	DRUID			= 0x00000002,	-- 2
	HUNTER			= 0x00000004,	-- 3
	MAGE			= 0x00000008,	-- 4
	PALADIN			= 0x00000010,	-- 5
	PRIEST			= 0x00000020,	-- 6
	SHAMAN			= 0x00000040,	-- 7
	ROGUE			= 0x00000080,	-- 8
	WARLOCK			= 0x00000100,	-- 9
	WARRIOR			= 0x00000200,	-- 10
}

-- Remove retired class options without changing any Forever class selection.
function private.MigrateClassFilters(profile)
	local classes = profile and profile.filters and profile.filters.classes
	if classes then
		classes.deathknight = nil
		classes.monk = nil
		classes.demonhunter = nil
	end
end

private.FLAG_WORDS = {
	private.COMMON_FLAGS_WORD1,
	private.CLASS_FLAGS_WORD1,
}

-- Member names within a recipe's flags table.
private.FLAG_MEMBERS = {
	"common1",
	"class1",
}

-- ----------------------------------------------------------------------------
-- Item filter types.
-- ----------------------------------------------------------------------------
constants.ITEM_FILTER_TYPES = {} -- Populated via profession modules.

-- ----------------------------------------------------------------------------
-- Reputation levels.
-- ----------------------------------------------------------------------------
private.REP_LEVEL_STRINGS = {
	[1]	= "FRIENDLY",
	[2]	= "HONORED",
	[3]	= "REVERED",
	[4]	= "EXALTED",
}

private.REP_LEVELS = {}
constants.REP_LEVELS = private.REP_LEVELS

for index = 1, #private.REP_LEVEL_STRINGS do
	private.REP_LEVELS[private.REP_LEVEL_STRINGS[index]] = index
end

-- ----------------------------------------------------------------------------
-- Factions.
-- ----------------------------------------------------------------------------
-- Keep menu order, IDs and faction restrictions in one Forever definition.
local REPUTATIONS = {
	{ id = 529, label = "ARGENT_DAWN" },
	{ id = 609, label = "CENARION_CIRCLE" },
	{ id = 749, label = "HYDRAXIAN_WATERLORDS", fallback = "Hydraxian Waterlords" },
	{ id = 59, label = "THORIUM_BROTHERHOOD" },
	{ id = 270, label = "ZANDALAR_TRIBE" },
	{ id = 576, label = "TIMBERMAW_HOLD" },
	{ id = 2586, label = "AZEROTH_COMMERCE_AUTHORITY", faction = "Alliance" },
	{ id = 2587, label = "DUROTAR_SUPPLY_AND_LOGISTICS", faction = "Horde" },
	{ id = 2740, label = "KIRIN_TOR", faction = "Alliance" },
	{ id = 2758, label = "NIGHTCLAW_DRUIDS" },
	{ id = 2787, label = "EARTHEN_RING", faction = "Horde" },
	{ id = 2765, label = "GUARDIANS_OF_HYJAL", fallback = "Guardians of Hyjal" },
}

-- Player-faction affiliation, separate from reputation IDs and standing levels.
-- Unspecified reputations are treated as Neutral.
private.FACTION_LABELS_FROM_ID = {}
private.REPUTATION_FACTIONS = {}
private.REPUTATION_NAMES = {}

for index = 1, #REPUTATIONS do
	local reputation = REPUTATIONS[index]
	private.FACTION_LABELS_FROM_ID[reputation.id] = reputation.label
	private.REPUTATION_NAMES[index] = reputation.label
	private.REPUTATION_FACTIONS[reputation.id] = reputation.faction
end

function private.IsReputationForFaction(reputationID, playerFaction)
	local faction = private.REPUTATION_FACTIONS[reputationID] or "Neutral"
	return faction == "Neutral" or faction == playerFaction
end

local FACTION_STANDING_LABEL4 = rawget(_G, "FACTION_STANDING_LABEL4") or "Neutral"
local FACTION_STANDING_LABEL5 = rawget(_G, "FACTION_STANDING_LABEL5") or "Friendly"
local FACTION_STANDING_LABEL6 = rawget(_G, "FACTION_STANDING_LABEL6") or "Honored"
local FACTION_STANDING_LABEL7 = rawget(_G, "FACTION_STANDING_LABEL7") or "Revered"
local FACTION_STANDING_LABEL8 = rawget(_G, "FACTION_STANDING_LABEL8") or "Exalted"
local function SafeGetFactionInfoByID(id)
	local data = _G.C_Reputation.GetFactionDataByID(id)
	return data and data.name
end
private.LOCALIZED_FACTION_STRINGS_FROM_LABEL = {
	NEUTRAL	= FACTION_STANDING_LABEL4,
	FRIENDLY = FACTION_STANDING_LABEL5,
	HONORED	= FACTION_STANDING_LABEL6,
	REVERED	= FACTION_STANDING_LABEL7,
	EXALTED	= FACTION_STANDING_LABEL8,
	HORDE = SafeGetFactionInfoByID(67),
	ALLIANCE = SafeGetFactionInfoByID(469),
}

private.FACTION_IDS_FROM_LABEL = {}
constants.FACTION_IDS = private.FACTION_IDS_FROM_LABEL

for index = 1, #REPUTATIONS do
	local reputation = REPUTATIONS[index]
	local id, label = reputation.id, reputation.label
	private.FACTION_IDS_FROM_LABEL[label] = id
	local fname = SafeGetFactionInfoByID(id)
	private.LOCALIZED_FACTION_STRINGS_FROM_LABEL[label] = fname or reputation.fallback or ("Unknown_%d"):format(id)
end

-- Pack reputation flags into 32-bit words using successive powers of two.
do
	local BITS_PER_WORD = 32
	local flags = {
		{}, -- First word added preemptively.
	}

	local flag_word = 1
	local flag_index = 1

	for index = 1, #private.REPUTATION_NAMES do
		local name = private.REPUTATION_NAMES[index]
		flags[flag_word][name] = 2 ^ (flag_index - 1)

		flag_index = flag_index + 1
		if flag_index > BITS_PER_WORD then
			flags[#flags + 1] = {}
			flag_word = flag_word + 1
			flag_index = 1
		end
	end

	for index = 1, #flags do
		private.FLAG_WORDS[#private.FLAG_WORDS + 1] = flags[index]
		private.FLAG_MEMBERS[#private.FLAG_MEMBERS + 1] = ("reputation%d"):format(index)
	end

	private.REP_FLAGS = flags
end

-- ----------------------------------------------------------------------------
-- This has to be done here, after every other flag definition.
-- ----------------------------------------------------------------------------
private.FILTER_STRINGS = {}
for index = 1, #private.FLAG_WORDS do
	local word = private.FLAG_WORDS[index]
	local names = {}
	for name in pairs(word) do names[#names + 1] = name end
	table.sort(names, function(left, right) return word[left] < word[right] end)
	for nameIndex = 1, #names do
		local flag_name = names[nameIndex]
		private.FILTER_STRINGS[#private.FILTER_STRINGS + 1] = flag_name
	end
end

private.FILTER_IDS = {}
constants.FILTER_IDS = private.FILTER_IDS

for index = 1, #private.FILTER_STRINGS do
	private.FILTER_IDS[private.FILTER_STRINGS[index]] = index
end

-- ----------------------------------------------------------------------------
-- Colors.
-- ----------------------------------------------------------------------------
local function CreateColorTable(dict)
	local r, g, b = dict.r, dict.g, dict.b
	return { hex = ("%02x%02x%02x"):format(r * 255, g * 255, b * 255), r = r, g = g, b = b }
end

local FACTION_BAR_COLORS = rawget(_G, "FACTION_BAR_COLORS") or {
	[1] = { r = 0.8, g = 0.1, b = 0.1 },
	[2] = { r = 1.0, g = 0.0, b = 0.0 },
	[3] = { r = 1.0, g = 0.5, b = 0.0 },
	[4] = { r = 1.0, g = 1.0, b = 0.0 },
	[5] = { r = 0.0, g = 1.0, b = 0.0 },
	[6] = { r = 0.0, g = 0.6, b = 0.1 },
	[7] = { r = 0.0, g = 0.4, b = 0.8 },
	[8] = { r = 0.6, g = 0.2, b = 1.0 },
}
private.REPUTATION_COLORS = {
	exalted		= CreateColorTable(FACTION_BAR_COLORS[8]),
	revered		= CreateColorTable(FACTION_BAR_COLORS[7]),
	honored		= CreateColorTable(FACTION_BAR_COLORS[6]),
	friendly	= CreateColorTable(FACTION_BAR_COLORS[5]),
	neutral		= CreateColorTable(FACTION_BAR_COLORS[4]),
	unfriendly	= CreateColorTable(FACTION_BAR_COLORS[3]),
	hostile		= CreateColorTable(FACTION_BAR_COLORS[2]),
	hated		= CreateColorTable(FACTION_BAR_COLORS[1]),
}

-- Recipe difficulty colors.
private.DIFFICULTY_COLORS = {
	unknown		= { hex = "ffffff",	r = 1,		g = 1,		b = 1 },
	trivial		= { hex = "808080",	r = 0.50,	g = 0.50,	b = 0.50 },
	easy		= { hex = "40bf40",	r = 0.25,	g = 0.75,	b = 0.25 },
	medium		= { hex = "ffff00",	r = 1,		g = 1,		b = 0 },
	optimal		= { hex = "ff8040",	r = 1,		g = 0.50,	b = 0.25 },
	impossible	= { hex = "ff0000",	r = 1,		g = 0,		b = 0 },
}

private.BASIC_COLORS = {
	grey	= { hex = "666666",	r = 0.40,	g = 0.40,	b = 0.40 },
	white	= { hex = "ffffff",	r = 1,		g = 1,		b = 1 },
	yellow	= { hex = "ffff00",	r = 1,		g = 1,		b = 0 },
	normal	= { hex = "ffd100",	r = 1,		g = 0.81,	b = 0 },
}

-- Colors used in tooltips and the recipe list.
private.CATEGORY_COLORS = {
	-- Miscellaneous
	coords		= { hex = "d1ce6f",	r = 0.82,	g = 0.81,	b = 0.44 },
	hint		= { hex = "c9c781",	r = 0.79,	g = 0.78,	b = 0.51 },
	location	= { hex = "ffecc1",	r = 1,		g = 0.93,	b = 0.76 },
	repname		= { hex = "6a9ad9",	r = 0.42,	g = 0.60,	b = 0.85 },
}
