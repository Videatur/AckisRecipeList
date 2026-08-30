-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------

-- Functions
local pairs = _G.pairs
local type = _G.type

-- Functions
local string = _G.string

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

-- ----------------------------------------------------------------------------
-- Imports.
-- ----------------------------------------------------------------------------
local REPUTATION_COLORS = private.REPUTATION_COLORS
local function SafeGetItemQualityColor(q)
	local fn = rawget(_G, "GetItemQualityColor")
	if type(fn) == "function" then
		return fn(q)
	end
	-- fallback colors similar to Blizzard defaults
	local fallback = {
		[0] = {1,1,1,"ffffffff"}, -- poor/common
		[1] = {0.12,1,0, "1fff00"},
		[2] = {0,0.44,0.87, "0070dd"},
		[3] = {0.64,0.21,0.93, "a335ee"},
		[4] = {1,0.5,0, "ff8000"},
	}
	local t = fallback[q] or fallback[0]
	return t[1], t[2], t[3], t[4]
end

-- ----------------------------------------------------------------------------
-- Objects.
-- ----------------------------------------------------------------------------
local AcquireType = {
	EntryPadding = "    ",
	RecipeQualityColors = _G.setmetatable({}, {
		__index = function(t, recipe_quality)
			local r, g, b, hex = SafeGetItemQualityColor(recipe_quality)
			local rgbValues = {
				hex = hex,
				r = r,
				g = g,
				b = b
			}

			t[recipe_quality] = rgbValues
			return rgbValues
		end
	}),
}

local AcquireTypeMetatable = {
	__index = AcquireType,
}

private.ACQUIRE_TYPES_BY_ID = {}
private.ACQUIRE_TYPE_IDS = {}
private.constants.ACQUIRE_TYPE_IDS = private.ACQUIRE_TYPE_IDS

private.AcquireTypes = {}

-- ----------------------------------------------------------------------------
-- AcquireType Methods.
-- ----------------------------------------------------------------------------
function AcquireType:AddEntity(module, entity)
	local identifier = entity.identifier
	local expansionID = entity.expansionID
	local effectiveExpansion = private.GetEffectiveExpansionID()

	if expansionID ~= nil then
		local isValidExpansionID = type(expansionID) == "number"
			and expansionID >= 1
			and expansionID <= #private.GAME_VERSION_NAMES
			and expansionID % 1 == 0

		if not isValidExpansionID then
			expansionID = nil
		end
	end

	entity.expansionID = expansionID

	if expansionID and effectiveExpansion and expansionID > effectiveExpansion then
		if self._entities[identifier] then
			return self._entities[identifier]
		end

		self._filtered_entities[identifier] = expansionID
		return nil
	end

	local existing = self._entities[identifier]

	if existing then
		local newRevision = expansionID or private.GAME_VERSIONS.ORIG
		local existingRevision = existing.expansionID or private.GAME_VERSIONS.ORIG

		if newRevision == existingRevision then
			return existing
		end

		if newRevision < existingRevision then
			return existing
		end

		entity.item_list = existing.item_list
	end

	self._filtered_entities[identifier] = nil

	if entity.locationName then
		entity.Location = private.LocationsByLocalizedName[entity.locationName]
		if not entity.Location and private.EnsureLocationByLocalizedName then
			entity.Location = private.EnsureLocationByLocalizedName(entity.locationName)
		end
		entity.locationName = nil
	end

	self._entities[identifier] = entity
	return entity
end

function AcquireType:AssignRecipe(spell_id, affiliation)
	self._recipes[spell_id] = affiliation or true
end

function AcquireType:ColorData()
	return self._colorData
end

function AcquireType:EntityPairs()
	return pairs(self._entities)
end

function AcquireType:ExpandListEntry(entry_index, entry_type, parent_entry, identifier, info, recipe, hide_location, hide_type)
	return self._func_expand_list_entry(self, entry_index, entry_type, parent_entry, identifier, info, recipe, hide_location, hide_type)
end

function AcquireType:GetEntity(identifier)
	return self._entities[identifier]
end

function AcquireType:IsEntityFiltered(identifier)
	return self._filtered_entities[identifier] ~= nil
end

function AcquireType:GetOrCreateRecipeData(sourceData, ...)
	return self._GetOrCreateRecipeData and self._GetOrCreateRecipeData(sourceData, ...) or sourceData
end

function AcquireType:GetRecipe(spell_id)
	return self._recipes[spell_id]
end

function AcquireType:GetSortedRecipes()
	return private.SortRecipeList(self._recipes)
end

function AcquireType:GetWaypointEntity(id_num, recipe)
	return self._func_waypoint_target and self._func_waypoint_target(self, id_num, recipe) or nil
end

function AcquireType:HasCoordinates()
	return self._hasCoordinates
end

function AcquireType:HasEntities()
	return self._hasEntities
end

function AcquireType:ID()
	return self._id
end

function AcquireType:InsertTooltipText(recipe, identifier, localizedLocationName, acquireInfo, addlineFunc)
	self._func_insert_tooltip_text(self, recipe, identifier, localizedLocationName, acquireInfo, addlineFunc)
end

function AcquireType:Label()
	return self._label
end

function AcquireType:Name()
	return self._name
end

function AcquireType:RecipePairs()
	return pairs(self._recipes)
end

-- ----------------------------------------------------------------------------
-- AcquireType Functions.
-- ----------------------------------------------------------------------------
function AcquireType.GetTipFactionInfo(comp_faction)
	local display_tip = true
	local color_table

	if comp_faction == "Neutral" then
		color_table = REPUTATION_COLORS.neutral
	elseif comp_faction == private.Player.faction then
		color_table = REPUTATION_COLORS.exalted
	else
		color_table = REPUTATION_COLORS.hated
		display_tip = private.db.profile.filters.general.faction
	end
	return display_tip, color_table
end

function AcquireType.CanDisplayFaction(faction)
	if private.db.profile.filters.general.faction then
		return true
	end
	return (not faction or faction == private.Player.faction or faction == "Neutral")
end

function AcquireType.ColorNameByFaction(name, faction)
	if faction == "Neutral" then
		name = private.SetTextColor(REPUTATION_COLORS.neutral.hex, name)
	elseif faction == private.Player.faction then
		name = private.SetTextColor(REPUTATION_COLORS.exalted.hex, name)
	else
		name = private.SetTextColor(REPUTATION_COLORS.hated.hex, name)
	end
	return name
end

-- ----------------------------------------------------------------------------
-- Instantiation.
-- ----------------------------------------------------------------------------
function private.RegisterAcquireType(acquireType)
	local index = #private.ACQUIRE_TYPES_BY_ID + 1
	acquireType._id = index
	acquireType._entities = {}
	acquireType._filtered_entities = {}
	acquireType._recipes = {}

	_G.setmetatable(acquireType, AcquireTypeMetatable)

	private.ACQUIRE_TYPES_BY_ID[index] = acquireType
	private.ACQUIRE_TYPE_IDS[acquireType._label] = index

	-- Make things easier by assigning the AcquireType by title case: WORLD_DROP becomes WorldDrop, for example
	private.AcquireTypes[acquireType._label:lower():gsub("^%l", string.upper):gsub("_%l", string.upper):gsub("_", "")] = acquireType
end

