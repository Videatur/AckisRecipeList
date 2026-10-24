-- ----------------------------------------------------------------------------
-- Upvalued Lua API.
-- ----------------------------------------------------------------------------
local pairs = _G.pairs

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...
local addon = _G.LibStub("AceAddon-3.0"):GetAddon(private.addon_name)

function addon:InitReputation()
	for reputationID in pairs(private.FACTION_LABELS_FROM_ID) do
		local label = private.FACTION_LABELS_FROM_ID[reputationID]
		local localizedName = label and private.LOCALIZED_FACTION_STRINGS_FROM_LABEL[label]
		local factionData = _G.C_Reputation.GetFactionDataByID(reputationID)
		private.AcquireTypes.Reputation:AddEntity(addon, {
			identifier = reputationID,
			faction = private.REPUTATION_FACTIONS[reputationID] or "Neutral",
			item_list = {},
			-- Prefer our centralized mapping, which already applies fallbacks for legacy factions
			name = localizedName or (factionData and factionData.name) or ("%s_%d"):format(_G.UNKNOWN, reputationID),
		})
	end

	self.InitReputation = nil
end
