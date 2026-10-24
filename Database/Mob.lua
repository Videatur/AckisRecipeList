-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

-- ----------------------------------------------------------------------------
-- Imports.
-- ----------------------------------------------------------------------------
local Z = private.ZONE_NAMES

function addon:InitMob()
	local function AddMob(npcID, npcName, zoneName, coordX, coordY)
		private.AcquireTypes.MobDrop:AddEntity(addon, {
			coord_x = coordX,
			coord_y = coordY,
			faction = nil,
			identifier = npcID,
			item_list = {},
			locationName = zoneName,
			name = npcName,
		})
	end

	AddMob(9264,	L["Firebrand Pyromancer"],	Z.BLACKROCK_SPIRE,				0, 0) -- Alchemy, Tailoring
	AddMob(9736,	L["Quartermaster Zigris"],	Z.BLACKROCK_SPIRE,				0, 0) -- Blacksmithing, Jewelcrafting
	AddMob(10813,	L["Balnazzar"],			Z.STRATHOLME,					0, 0) -- Alchemy, Tailoring

	self.InitMob = nil
end
