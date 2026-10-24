--[[
Copyright (c) 2009 - 2012 Ackis <John Pasula>
All rights reserved by the original author Ackis.
]]

-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------
-- Functions
local pairs = _G.pairs

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...


-- ----------------------------------------------------------------------------
-- Character data used by recipe scans, filters, tooltips, and profession guides.
-- ----------------------------------------------------------------------------
-- @class table
-- @name Player
-- @field professions Profession skill levels indexed by localized name.
-- @field scanned_professions Professions scanned for this character.
-- @field faction Player's faction
-- @field class Player's class
-- @field reputation_levels Reputation levels indexed by localized name.
-- @field reputation_levels_by_id Reputation levels indexed by faction ID.
-- @field revision Incremented when character data changes.
local Player = {}
private.Player = Player

-- ----------------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- Player methods.
-- ----------------------------------------------------------------------------
local function ReplaceValues(target, values)
	local changed = false
	for key in pairs(target) do
		if values[key] == nil then target[key] = nil; changed = true end
	end
	for key, value in pairs(values) do
		if target[key] ~= value then target[key] = value; changed = true end
	end
	return changed
end

function Player:UpdateIdentity()
	local faction = _G.UnitFactionGroup("player") or self.faction
	local class = _G.select(2, _G.UnitClass("player")) or self.class
	local changed = self.faction ~= faction or self.class ~= class
	self.faction, self.class = faction, class
	if changed then self.revision = (self.revision or 0) + 1 end
	return changed
end

function Player:Initialize()
	self.scanned_professions = self.scanned_professions or {}
	self.professions = self.professions or {}
	self.reputation_levels = self.reputation_levels or {}
	self.reputation_levels_by_id = self.reputation_levels_by_id or {}
	self.revision = self.revision or 0
	self:UpdateIdentity()
	self:UpdateProfessions()
	self:UpdateReputations()
end

function Player:UpdateReputations()
	self.reputation_levels = self.reputation_levels or {}
	self.reputation_levels_by_id = self.reputation_levels_by_id or {}
	local names, levels = {}, {}
	-- Read registered factions directly; collapsed UI headers do not affect IDs.
	for reputationID in pairs(private.FACTION_LABELS_FROM_ID) do
		local data = _G.C_Reputation.GetFactionDataByID(reputationID)
		if data and type(data.reaction) == "number" and data.reaction >= 1 and data.reaction <= 8 then
			-- ARL represents Neutral as 0 and Friendly through Exalted as 1 through 4.
			local level = data.reaction - 4
			levels[reputationID] = level
			if data.name then names[data.name] = level end
			local label = private.FACTION_LABELS_FROM_ID[reputationID]
			local registeredName = private.LOCALIZED_FACTION_STRINGS_FROM_LABEL[label]
			if registeredName then names[registeredName] = level end
		end
	end
	local changed = ReplaceValues(self.reputation_levels, names)
	changed = ReplaceValues(self.reputation_levels_by_id, levels) or changed
	if changed then self.revision = (self.revision or 0) + 1 end
	return changed
end

function Player:HasProperRepLevel(rep_data)
	if not rep_data or not next(rep_data) then
		return true
	end
	local reputation_levels = self.reputation_levels_by_id or {}
	-- A recipe is obtainable when any accessible reputation source qualifies.
	for rep_id, rep_info in pairs(rep_data) do
		local standing = reputation_levels[rep_id]
		if standing ~= nil and private.IsReputationForFaction(rep_id, self.faction) then
			for rep_level in pairs(rep_info) do
				if standing >= rep_level then return true end
			end
		end
	end
	return false
end

function Player:HasRecipeFaction(recipe)
	local flagged_horde = recipe:HasFilter("common1", "HORDE")
	local flagged_alliance = recipe:HasFilter("common1", "ALLIANCE")

	if self.faction == "Alliance" and flagged_horde and not flagged_alliance then
		return false
	elseif self.faction == "Horde" and flagged_alliance and not flagged_horde then
		return false
	end
	return true
end

do
	-- Sets the player's professions. Used when the AddOn initializes and when a profession has been learned or unlearned.
	function Player:UpdateProfessions()
		self.professions = self.professions or {}
		self.scanned_professions = self.scanned_professions or {}
		local tradeSkillUI = _G.C_TradeSkillUI
		local skillLineIDs = tradeSkillUI.GetAllProfessionTradeSkillLines()
		if not skillLineIDs then return false end
		local professions = {}
		for _, skillLineID in pairs(skillLineIDs) do
			local info = tradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
			-- Preserve the previous snapshot until every profession is available.
			if not info or not info.professionName or type(info.skillLevel) ~= "number" then return false end
            local name = private.ResolveProfessionName and private.ResolveProfessionName(info.parentProfessionID or skillLineID, info.parentProfessionName or info.professionName)
                or info.professionName
            professions[name] = math.max(professions[name] or 0, info.skillLevel)
		end
		local changed = ReplaceValues(self.professions, professions)
		for name in pairs(self.scanned_professions) do
			if professions[name] == nil then self.scanned_professions[name] = nil end
		end
		if changed then self.revision = (self.revision or 0) + 1 end
		return changed
	end
end -- do-block

-- ----------------------------------------------------------------------------
-- Character data events.
-- ----------------------------------------------------------------------------
local updateGeneration, updatePending = 0, false
local updateProfessions, updateReputations, updateIdentity = false, false, false

local function QueuePlayerUpdate(addon, professions, reputations, identity)
	updateProfessions = updateProfessions or professions
	updateReputations = updateReputations or reputations
	updateIdentity = updateIdentity or identity
	if updatePending then return end
	updatePending = true
	local generation = updateGeneration
	_G.C_Timer.After(0.1, function()
		if generation ~= updateGeneration then return end
		updatePending = false
		local professionsDirty, reputationsDirty, identityDirty = updateProfessions, updateReputations, updateIdentity
		updateProfessions, updateReputations, updateIdentity = false, false, false
		local changed = identityDirty and Player:UpdateIdentity() or false
		if professionsDirty then changed = Player:UpdateProfessions() or changed end
		if reputationsDirty then changed = Player:UpdateReputations() or changed end
		if not changed then return end
		local panel, profession = addon.Frame, private.CurrentProfession
		if panel and panel:IsVisible() and profession and panel.list_frame then
			-- Linked profession ranks belong to the linked owner, not this character.
			local rank = Player.professions[profession:LocalizedName()]
			if not panel.is_linked and rank then private.current_profession_scanlevel = rank end
			panel:UpdateTitle()
			panel.list_frame:Update(nil, false)
		end
	end)
end

function private.RegisterPlayerEvents(addon)
	addon:RegisterEvent("SKILL_LINES_CHANGED", function() QueuePlayerUpdate(addon, true, false, false) end)
	addon:RegisterEvent("UPDATE_FACTION", function() QueuePlayerUpdate(addon, false, true, false) end)
	addon:RegisterEvent("PLAYER_ENTERING_WORLD", function() QueuePlayerUpdate(addon, true, true, true) end)
end

function private.UnregisterPlayerEvents(addon)
	updateGeneration = updateGeneration + 1
	updatePending = false
	updateProfessions, updateReputations, updateIdentity = false, false, false
	addon:UnregisterEvent("SKILL_LINES_CHANGED")
	addon:UnregisterEvent("UPDATE_FACTION")
	addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
end
