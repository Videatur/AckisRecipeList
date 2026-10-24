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

function addon:InitVendor()
	local function AddVendor(identifier, name, location, coord_x, coord_y, faction)
		return private.AcquireTypes.Vendor:AddEntity(addon, {
			coord_x = coord_x,
			coord_y = coord_y,
			faction = faction,
			identifier = identifier,
			item_list = {},
			locationName = location,
			name = name,
		})
	end

	-- ----------------------------------------------------------------------------
	-- Forever
	-- ----------------------------------------------------------------------------
	AddVendor(32287,  	"Archmage Alvareaux", 					Z.ALTERAC_MOUNTAINS, 		14.0, 63.2, "Alliance")
	AddVendor(264078,  	"Sutara Plainstalker", 					Z.MULGORE, 					34.6, 22.8, "Horde")
	AddVendor(254151,  	"Vayn Moongaze", 						Z.ZEPHRAS_ISLE, 			63.8, 36.0, "Neutral")
	AddVendor(14921,  	"Rin'wosho the Trader", 				Z.STRANGLETHORN_VALE, 		15.0, 16.0, "Neutral")

	-- ----------------------------------------------------------------------------
	-- Classic
	-- ----------------------------------------------------------------------------
	AddVendor(66,		L["Tharynn Bouden"],					Z.ELWYNN_FOREST,			41.8,	67.0,	"Alliance") -- Cooking, Tailoring
	AddVendor(777,		L["Amy Davenport"],						Z.REDRIDGE_MOUNTAINS,		29.0,	47.6,	"Alliance") -- Leatherworking, Tailoring
	AddVendor(843,		L["Gina MacGregor"],					Z.WESTFALL,					57.6,	54.0,	"Alliance") -- Leatherworking, Tailoring
	AddVendor(989,		L["Banalash"],							Z.SWAMP_OF_SORROWS,			44.6,	56.8,	"Horde") -- Cooking, Enchanting, Jewelcrafting
	AddVendor(1148,		L["Nerrist"],							Z.STRANGLETHORN_VALE,		32.6,	29.2,	"Horde") -- Cooking, Jewelcrafting
	AddVendor(1313,		L["Maria Lumere"],						Z.STORMWIND_CITY,			46.6, 	78.8,	"Alliance") -- Alchemy, Enchanting, Engineering
	AddVendor(1318,		L["Jessara Cordell"],					Z.STORMWIND_CITY,			43.0,	64.2,	"Alliance") -- Enchanting, Tailoring
	AddVendor(2393,		L["Christoph Jeffcoat"],				Z.HILLSBRAD_FOOTHILLS,		62.2, 	19.0,	"Horde") -- Alchemy, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(2679,		L["Wenna Silkbeard"],					Z.WETLANDS,					25.6,	25.8,	"Alliance") -- Leatherworking, Tailoring
	AddVendor(2810,		L["Hammon Karwn"],						Z.ARATHI_HIGHLANDS,			46.4, 	47.4,	"Alliance") -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(2821,		L["Keena"],								Z.ARATHI_HIGHLANDS,			74.0,	32.6,	"Horde") -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(3012,		L["Nata Dawnstrider"],					Z.THUNDER_BLUFF,			44.9,	37.7,	"Horde") -- Enchanting, Tailoring
	AddVendor(3134,		L["Kzixx"],								Z.DUSKWOOD,					81.8,	19.8,	"Neutral") -- Alchemy, Engineering
	AddVendor(3346,		L["Kithas"],							Z.ORGRIMMAR,				53.6,	38.0,	"Horde") -- Enchanting, Tailoring
	AddVendor(3499,		L["Ranik"],								Z.THE_BARRENS,				61.8, 	38.6,	"Neutral") -- Alchemy, Jewelcrafting, Tailoring
	AddVendor(3537,		L["Zixil"],								Z.HILLSBRAD_FOOTHILLS,		49.8,	60.8,	"Neutral") -- Enchanting, Engineering, Leatherworking, Tailoring
	AddVendor(3556,		L["Andrew Hilbert"],					Z.SILVERPINE_FOREST,		43.2,	40.6,	"Horde") -- Cooking, Leatherworking, Tailoring
	AddVendor(3954,		L["Dalria"],							Z.ASHENVALE,				35.0,	52.0,	"Alliance") -- Enchanting, Jewelcrafting
	AddVendor(4228,		L["Vaean"],								Z.DARNASSUS,				58.6, 	14.6,	"Alliance") -- Enchanting, Tailoring
	AddVendor(4229,		L["Mythrin'dir"],						Z.DARNASSUS,				61.4,	18.8,	"Alliance") -- Enchanting, Jewelcrafting
	AddVendor(4561,		L["Daniel Bartlett"],					Z.UNDERCITY,				64.1,	37.4,	"Horde") -- Enchanting, Jewelcrafting
	AddVendor(4617,		L["Thaddeus Webb"],						Z.UNDERCITY,				62.4,	61.0,	"Horde") -- Enchanting, Tailoring
	AddVendor(4897,		L["Helenia Olden"],						Z.DUSTWALLOW_MARSH,			66.4,	51.5,	"Alliance") -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(5158,		L["Tilli Thistlefuzz"],					Z.IRONFORGE,				61.0,	44.0,	"Alliance") -- Enchanting, Tailoring
	AddVendor(5757,		L["Lilly"],								Z.SILVERPINE_FOREST,		43.0,	50.8,	"Horde") -- Enchanting, Tailoring
	AddVendor(5758,		L["Leo Sarn"],							Z.SILVERPINE_FOREST,		54.0,	82.2,	"Horde") -- Enchanting, Tailoring
	AddVendor(9499,		L["Plugger Spazzring"],					Z.BLACKROCK_DEPTHS,			0,	0,			"Neutral") -- Alchemy, Leatherworking
	AddVendor(9636,		L["Kireena"],							Z.DESOLACE,					51.0,	53.5,	"Horde") -- Cooking, Jewelcrafting, Tailoring
	AddVendor(10856,	L["Argent Quartermaster Hasana"],		Z.TIRISFAL_GLADES,			83.2,	68.1,	"Neutral") -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(10857,	L["Argent Quartermaster Lightspark"],	Z.WESTERN_PLAGUELANDS,		42.8,	83.8,	"Neutral") -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(11189,	L["Qia"],								Z.WINTERSPRING,				61.2, 	37.2,	"Neutral") -- Enchanting, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(11278,	L["Magnus Frostwake"],					Z.WESTERN_PLAGUELANDS,		68.0,	77.6,	"Neutral") -- Alchemy, Blacksmithing
	AddVendor(11536,	L["Quartermaster Miranda Breechlock"],	Z.EASTERN_PLAGUELANDS,		81.6,	60.0,	"Neutral") -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(11557,	L["Meilosh"],							Z.FELWOOD,					65.6,	2.8, 	"Neutral") -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(12022,	L["Lorelae Wintersong"],				Z.MOONGLADE,				48.6, 	40.2,	"Neutral") -- Enchanting, Tailoring
	AddVendor(12944,	L["Lokhtos Darkbargainer"],				Z.BLACKROCK_DEPTHS,			0,	0,			"Neutral") -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(13420,	L["Penney Copperpinch"],				Z.ORGRIMMAR,				53.0, 	66.0,	"Neutral") -- Cooking, Leatherworking, Tailoring
	AddVendor(13433,	L["Wulmort Jinglepocket"],				Z.IRONFORGE,				33.0,	67.6,	"Neutral") -- Cooking, Leatherworking, Tailoring
	AddVendor(15179,	L["Mishta"],							Z.SILITHUS,					49.8,	36.6,	"Neutral") -- Jewelcrafting, Tailoring
	AddVendor(15419,	L["Kania"],								Z.SILITHUS,					52.0,	39.6,	"Neutral") -- Enchanting, Tailoring
	AddVendor(15909,	L["Fariel Starsong"],					Z.MOONGLADE,				53.8,	35.6,	"Neutral") -- Engineering, Tailoring

	self.InitVendor = nil
end
