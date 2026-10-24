-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub

local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)
local Z = private.ZONE_NAMES

function addon:InitWorldEvents()
	local function AddWorldEvent(identifier, name, locationName)
		private.AcquireTypes.WorldEvent:AddEntity(addon, {
			identifier = identifier,
			item_list = {},
			name = name,
			locationName = locationName,
		})
	end

	AddWorldEvent("WINTER_VEIL", 		L["Winter Veil"])
	AddWorldEvent("LUNAR_FESTIVAL", 	L["Lunar Festival"], Z.MOONGLADE)
	AddWorldEvent("MIDSUMMER", 			L["Mid Summer"])
	AddWorldEvent("PILGRIMS_BOUNTY", 	L["Pilgrims Bounty"])
	AddWorldEvent("DAY_OF_THE_DEAD", 	L["Day of the Dead"])
	AddWorldEvent("DARKMOON_FAIRE", 	L["Darkmoon Faire"])

	self.InitWorldEvents = nil
end
