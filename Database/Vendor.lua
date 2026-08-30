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
local V = private.GAME_VERSIONS

function addon:InitVendor()
	local function AddVendor(identifier, name, location, coord_x, coord_y, faction, expansionID)
		return private.AcquireTypes.Vendor:AddEntity(addon, {
			coord_x = coord_x,
			coord_y = coord_y,
			expansionID = expansionID,
			faction = faction,
			identifier = identifier,
			item_list = {},
			locationName = location,
			name = name,
		})
	end

	-- ----------------------------------------------------------------------------
	-- Vanilla
	-- ----------------------------------------------------------------------------
	AddVendor(66,		L["Tharynn Bouden"],					Z.ELWYNN_FOREST,			41.8,	67.0,	"Alliance",		V.ORIG) -- Cooking, Tailoring
	AddVendor(777,		L["Amy Davenport"],						Z.REDRIDGE_MOUNTAINS,		29.0,	47.6,	"Alliance",		V.ORIG) -- Leatherworking, Tailoring
	AddVendor(843,		L["Gina MacGregor"],					Z.WESTFALL,					57.6,	54.0,	"Alliance",		V.ORIG) -- Leatherworking, Tailoring
	AddVendor(989,		L["Banalash"],							Z.SWAMP_OF_SORROWS,			44.6,	56.8,	"Horde",		V.ORIG) -- Cooking, Enchanting, Jewelcrafting
	AddVendor(1148,		L["Nerrist"],							Z.STRANGLETHORN_VALE,		32.6,	29.2,	"Horde",		V.ORIG) -- Cooking, Jewelcrafting
	AddVendor(1313,		L["Maria Lumere"],						Z.STORMWIND_CITY,			46.6, 	78.8,	"Alliance",		V.ORIG) -- Alchemy, Enchanting, Engineering
	AddVendor(1318,		L["Jessara Cordell"],					Z.STORMWIND_CITY,			43.0,	64.2,	"Alliance",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(2393,		L["Christoph Jeffcoat"],				Z.HILLSBRAD_FOOTHILLS,		62.2, 	19.0,	"Horde",		V.ORIG) -- Alchemy, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(2679,		L["Wenna Silkbeard"],					Z.WETLANDS,					25.6,	25.8,	"Alliance",		V.ORIG) -- Leatherworking, Tailoring
	AddVendor(2810,		L["Hammon Karwn"],						Z.ARATHI_HIGHLANDS,			46.4, 	47.4,	"Alliance",		V.ORIG) -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(2821,		L["Keena"],								Z.ARATHI_HIGHLANDS,			74.0,	32.6,	"Horde",		V.ORIG) -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(3012,		L["Nata Dawnstrider"],					Z.THUNDER_BLUFF,			44.9,	37.7,	"Horde",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(3134,		L["Kzixx"],								Z.DUSKWOOD,					81.8,	19.8,	"Neutral",		V.ORIG) -- Alchemy, Engineering
	AddVendor(3346,		L["Kithas"],							Z.ORGRIMMAR,				53.6,	38.0,	"Horde",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(3499,		L["Ranik"],								Z.THE_BARRENS,				61.8, 	38.6,	"Neutral",		V.ORIG) -- Alchemy, Jewelcrafting, Tailoring
	AddVendor(3537,		L["Zixil"],								Z.HILLSBRAD_FOOTHILLS,		49.8,	60.8,	"Neutral",		V.ORIG) -- Enchanting, Engineering, Leatherworking, Tailoring
	AddVendor(3556,		L["Andrew Hilbert"],					Z.SILVERPINE_FOREST,		43.2,	40.6,	"Horde",		V.ORIG) -- Cooking, Leatherworking, Tailoring
	AddVendor(3954,		L["Dalria"],							Z.ASHENVALE,				35.0,	52.0,	"Alliance",		V.ORIG) -- Enchanting, Jewelcrafting
	AddVendor(4228,		L["Vaean"],								Z.DARNASSUS,				58.6, 	14.6,	"Alliance",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(4229,		L["Mythrin'dir"],						Z.DARNASSUS,				61.4,	18.8,	"Alliance",		V.ORIG) -- Enchanting, Jewelcrafting
	AddVendor(4561,		L["Daniel Bartlett"],					Z.UNDERCITY,				64.1,	37.4,	"Horde",		V.ORIG) -- Enchanting, Jewelcrafting
	AddVendor(4617,		L["Thaddeus Webb"],						Z.UNDERCITY,				62.4,	61.0,	"Horde",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(4897,		L["Helenia Olden"],						Z.DUSTWALLOW_MARSH,			66.4,	51.5,	"Alliance",		V.ORIG) -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(5158,		L["Tilli Thistlefuzz"],					Z.IRONFORGE,				61.0,	44.0,	"Alliance",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(5757,		L["Lilly"],								Z.SILVERPINE_FOREST,		43.0,	50.8,	"Horde",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(5758,		L["Leo Sarn"],							Z.SILVERPINE_FOREST,		54.0,	82.2,	"Horde",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(9499,		L["Plugger Spazzring"],					Z.BLACKROCK_DEPTHS,			0,	0,			"Neutral",		V.ORIG) -- Alchemy, Leatherworking
	AddVendor(9636,		L["Kireena"],							Z.DESOLACE,					51.0,	53.5,	"Horde",		V.ORIG) -- Cooking, Jewelcrafting, Tailoring
	AddVendor(10856,	L["Argent Quartermaster Hasana"],		Z.TIRISFAL_GLADES,			83.2,	68.1,	"Neutral",		V.ORIG) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(10857,	L["Argent Quartermaster Lightspark"],	Z.WESTERN_PLAGUELANDS,		42.8,	83.8,	"Neutral",		V.ORIG) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(11189,	L["Qia"],								Z.WINTERSPRING,				61.2, 	37.2,	"Neutral",		V.ORIG) -- Enchanting, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(11278,	L["Magnus Frostwake"],					Z.WESTERN_PLAGUELANDS,		68.0,	77.6,	"Neutral",		V.ORIG) -- Alchemy, Blacksmithing
	AddVendor(11536,	L["Quartermaster Miranda Breechlock"],	Z.EASTERN_PLAGUELANDS,		81.6,	60.0,	"Neutral",		V.ORIG) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(11557,	L["Meilosh"],							Z.FELWOOD,					65.6,	2.8, 	"Neutral",		V.ORIG) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(12022,	L["Lorelae Wintersong"],				Z.MOONGLADE,				48.6, 	40.2,	"Neutral",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(12944,	L["Lokhtos Darkbargainer"],				Z.BLACKROCK_DEPTHS,			0,	0,			"Neutral",		V.ORIG) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(13420,	L["Penney Copperpinch"],				Z.ORGRIMMAR,				53.0, 	66.0,	"Neutral",		V.ORIG) -- Cooking, Leatherworking, Tailoring
	AddVendor(13433,	L["Wulmort Jinglepocket"],				Z.IRONFORGE,				33.0,	67.6,	"Neutral",		V.ORIG) -- Cooking, Leatherworking, Tailoring
	AddVendor(15179,	L["Mishta"],							Z.SILITHUS,					49.8,	36.6,	"Neutral",		V.ORIG) -- Jewelcrafting, Tailoring
	AddVendor(15419,	L["Kania"],								Z.SILITHUS,					52.0,	39.6,	"Neutral",		V.ORIG) -- Enchanting, Tailoring
	AddVendor(15909,	L["Fariel Starsong"],					Z.MOONGLADE,				53.8,	35.6,	"Neutral",		V.ORIG) -- Engineering, Tailoring

	-- ----------------------------------------------------------------------------
	-- TBC
	-- ----------------------------------------------------------------------------
	AddVendor(16635,	L["Lyna"],								Z.SILVERMOON_CITY,			70.3,	24.9,	"Horde",		V.TBC) -- Enchanting, Tailoring
	AddVendor(16722,	L["Egomis"],							Z.THE_EXODAR,				39.9,	40.2,	"Alliance",		V.TBC) -- Enchanting, Tailoring
	AddVendor(17585,	L["Quartermaster Urgronn"],				Z.HELLFIRE_PENINSULA,		54.9,	37.9,	"Horde",		V.TBC) -- Alchemy, Blacksmithing, Enchanting, Jewelcrafting, Leatherworking
	AddVendor(17657,	L["Logistics Officer Ulrike"],			Z.HELLFIRE_PENINSULA,		56.7,	62.6,	"Alliance",		V.TBC) -- Alchemy, Blacksmithing, Enchanting, Jewelcrafting, Leatherworking
	AddVendor(17904,	L["Fedryen Swiftspear"],				Z.ZANGARMARSH,				79.3,	63.8,	"Neutral",		V.TBC) -- Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking
	AddVendor(18011,	L["Zurai"],								Z.ZANGARMARSH,				85.3,	54.8,	"Horde",		V.TBC) -- Cooking, Tailoring
	AddVendor(18255,	L["Apprentice Darius"],					Z.DEADWIND_PASS,			47.0,	75.3,	"Neutral",		V.TBC) -- Enchanting, Jewelcrafting, Leatherworking
	AddVendor(18382,	L["Mycah"],								Z.ZANGARMARSH,				17.9,	51.2,	"Neutral",		V.TBC) -- Alchemy, Cooking, Tailoring
	AddVendor(18753,	L["Felannia"],							Z.HELLFIRE_PENINSULA,		52.3,	36.1,	"Horde",		V.TBC) -- Enchanting, Tailoring
	AddVendor(18773,	L["Johan Barnes"],						Z.HELLFIRE_PENINSULA,		53.7,	66.1,	"Alliance",		V.TBC) -- Enchanting, Tailoring
	AddVendor(18821,	L["Quartermaster Jaffrey Noreliqe"],	Z.NAGRAND_OUTLAND,			41.2,	44.3,	"Horde",		V.TBC) -- Alchemy, Jewelcrafting
	AddVendor(18822,	L["Quartermaster Davian Vaclav"],		Z.NAGRAND_OUTLAND,			41.2,	44.3,	"Alliance",		V.TBC) -- Alchemy, Jewelcrafting
	AddVendor(18951,	L["Erilia"],							Z.EVERSONG_WOODS,			55.5,	54.0,	"Horde",		V.TBC) -- Enchanting, Tailoring
	AddVendor(19234,	L["Yurial Soulwater"],					Z.SHATTRATH_CITY,			43.5,	96.9,	"Neutral",		V.TBC) -- Enchanting, Tailoring
	AddVendor(19321,	L["Quartermaster Endarin"],				Z.SHATTRATH_CITY,			47.9,	26.1,	"Neutral",		V.TBC) -- Blacksmithing, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(19331,	L["Quartermaster Enuril"],				Z.SHATTRATH_CITY,			60.5,	64.2,	"Neutral",		V.TBC) -- Alchemy, Blacksmithing, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(19537,	L["Dealer Malij"],						Z.NETHERSTORM,				44.2,	34.0,	"Neutral",		V.TBC) -- Enchanting, Tailoring
	AddVendor(19540,	L["Asarnan"],							Z.NETHERSTORM,				44.2,	33.7,	"Neutral",		V.TBC) -- Enchanting, Tailoring
	AddVendor(19663,	L["Madame Ruby"],						Z.SHATTRATH_CITY,			63.1,	69.3,	"Neutral",		V.TBC) -- Enchanting, Tailoring
	AddVendor(20240,	L["Trader Narasu"],						Z.NAGRAND_OUTLAND,			54.6,	75.2,	"Alliance",		V.TBC) -- Alchemy, Leatherworking
	AddVendor(20241,	L["Provisioner Nasela"],				Z.NAGRAND_OUTLAND,			53.5,	36.9,	"Horde",		V.TBC) -- Alchemy, Leatherworking
	AddVendor(20242,	L["Karaaz"],							Z.NETHERSTORM,				43.6,	34.3,	"Neutral",		V.TBC) -- Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(21432,	L["Almaador"],							Z.SHATTRATH_CITY,			51.0,	41.9,	"Neutral",		V.TBC) -- Alchemy, Enchanting, Jewelcrafting, Leatherworking
	AddVendor(21643,	L["Alurmi"],							Z.TANARIS,					63.0,	57.3,	"Neutral",		V.TBC) -- Alchemy, Enchanting, Jewelcrafting, Leatherworking
	AddVendor(21655,	L["Nakodu"],							Z.SHATTRATH_CITY,			62.1,	69.0,	"Neutral",		V.TBC) -- Alchemy, Enchanting, Jewelcrafting, Tailoring
	AddVendor(23007,	L["Paulsta'ats"],						Z.NAGRAND_OUTLAND,			30.6,	57.0,	"Neutral",		V.TBC) -- Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(23159,	L["Okuno"],								Z.BLACK_TEMPLE,				0,	0,			"Neutral",		V.TBC) -- Blacksmithing, Leatherworking, Tailoring
	AddVendor(25032,	L["Eldara Dawnrunner"],					Z.ISLE_OF_QUELDANAS,		47.1,	30.0,	"Neutral",		V.TBC) -- Alchemy, Enchanting, Jewelcrafting

	-- ----------------------------------------------------------------------------
	-- Wrath of The Lich King
	-- ----------------------------------------------------------------------------
	AddVendor(26569,	L["Alys Vol'tyr"],						Z.DRAGONBLIGHT,				36.3,	46.5,	"Horde",		V.WOTLK) -- Enchanting, Tailoring
	AddVendor(27030,	L["Bradley Towns"],						Z.DRAGONBLIGHT,				76.9,	62.2,	"Horde",		V.WOTLK) -- Enchanting, Tailoring
	AddVendor(27054,	L["Modoru"],							Z.DRAGONBLIGHT,				28.9,	55.9,	"Alliance",		V.WOTLK) -- Enchanting, Tailoring
	AddVendor(27147,	L["Librarian Erickson"],				Z.BOREAN_TUNDRA,			46.7,	32.5,	"Neutral",		V.WOTLK) -- Enchanting, Tailoring
	AddVendor(28714,	L["Ildine Sorrowspear"],				Z.DALARAN_NORTHREND,		39.1,	41.5,	"Neutral",		V.WOTLK) -- Enchanting, Tailoring
	AddVendor(30431,	L["Veteran Crusader Aliocha Segard"],	Z.ICECROWN,					87.6,	75.6,	"Neutral",		V.WOTLK) -- Jewelcrafting, Tailoring
	AddVendor(31916,	L["Tanaika"],							Z.HOWLING_FJORD,			25.5,	58.7,	"Neutral",		V.WOTLK) -- Jewelcrafting, Leatherworking, Tailoring
	AddVendor(32287,	L["Archmage Alvareaux"],				Z.DALARAN_NORTHREND,		25.5,	47.4,	"Neutral",		V.WOTLK) -- Jewelcrafting, Tailoring
	AddVendor(32533,	L["Cielstrasza"],						Z.DRAGONBLIGHT,				59.9,	53.1,	"Neutral",		V.WOTLK) -- Jewelcrafting, Tailoring
	AddVendor(32538,	L["Duchess Mynx"],						Z.ICECROWN,					43.5,	20.6,	"Neutral",		V.WOTLK) -- Jewelcrafting, Tailoring
	AddVendor(32540,	L["Lillehoff"],							Z.THE_STORM_PEAKS,			66.2,	61.4,	"Neutral",		V.WOTLK) -- Jewelcrafting, Leatherworking, Tailoring
	AddVendor(32564,	L["Logistics Officer Silverstone"],		Z.BOREAN_TUNDRA,			57.7,	66.5,	"Alliance",		V.WOTLK) -- Blacksmithing, Engineering
	AddVendor(32565,	L["Gara Skullcrush"],					Z.BOREAN_TUNDRA,			41.4,	53.6,	"Horde",		V.WOTLK) -- Blacksmithing, Engineering
	AddVendor(32763,	L["Sairuk"],							Z.DRAGONBLIGHT,				48.5,	75.7,	"Neutral",		V.WOTLK) -- Jewelcrafting, Leatherworking, Tailoring
	AddVendor(32773,	L["Logistics Officer Brighton"],		Z.HOWLING_FJORD,			59.7,	63.9,	"Alliance",		V.WOTLK) -- Blacksmithing, Engineering
	AddVendor(32774,	L["Sebastian Crane"],					Z.HOWLING_FJORD,			79.6,	30.7,	"Horde",		V.WOTLK) -- Blacksmithing, Engineering
	AddVendor(37687,	L["Alchemist Finklestein"],				Z.ICECROWN_CITADEL,			0,	0,			"Neutral",		V.WOTLK) -- Blacksmithing, Leatherworking, Tailoring

	-- ----------------------------------------------------------------------------
	-- Cataclysm
	-- ----------------------------------------------------------------------------
	AddVendor(777,		L["Amy Davenport"],						Z.REDRIDGE_MOUNTAINS,		28.2,	43.4,	"Alliance",		V.CATA) -- Leatherworking, Tailoring
	AddVendor(1148,		L["Nerrist"],							Z.NORTHERN_STRANGLETHORN,	39.2,	51.0,	"Horde",		V.CATA) -- Cooking, Jewelcrafting
	AddVendor(1313,		L["Maria Lumere"],						Z.STORMWIND_CITY,			55.6,	85.6,	"Alliance",		V.CATA) -- Alchemy, Enchanting, Engineering
	AddVendor(1318,		L["Jessara Cordell"],					Z.STORMWIND_CITY,			53.0,	74.2,	"Alliance",		V.CATA) -- Enchanting, Tailoring
	AddVendor(2393,		L["Christoph Jeffcoat"],				Z.HILLSBRAD_FOOTHILLS,		57.4,	47.6,	"Horde",		V.CATA) -- Alchemy, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(2810,		L["Hammon Karwn"],						Z.ARATHI_HIGHLANDS,			40.4,	48.8,	"Alliance",		V.CATA) -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(2821,		L["Keena"],								Z.ARATHI_HIGHLANDS,			69.0,	33.4,	"Horde",		V.CATA) -- Cooking, Jewelcrafting, Leatherworking
	AddVendor(3346,		L["Kithas"],							Z.ORGRIMMAR,				53.2,	49.0,	"Horde",		V.CATA) -- Enchanting, Tailoring
	AddVendor(3499,		L["Ranik"],								Z.NORTHERN_BARRENS,			67.0,	73.4,	"Neutral",		V.CATA) -- Alchemy, Jewelcrafting, Tailoring
	AddVendor(4228,		L["Vaean"],								Z.DARNASSUS,				56.6,	31.8,	"Alliance",		V.CATA) -- Enchanting, Tailoring
	AddVendor(4229,		L["Mythrin'dir"],						Z.DARNASSUS,				58.2,	34.6,	"Alliance",		V.CATA) -- Enchanting, Jewelcrafting
	AddVendor(5757,		L["Lilly"],								Z.SILVERPINE_FOREST,		46.8,   40.6,	"Horde",		V.CATA) -- Enchanting, Tailoring
	AddVendor(11189,	L["Qia"],								Z.WINTERSPRING,				59.6,	49.2,	"Neutral",		V.CATA) -- Enchanting, Jewelcrafting, Leatherworking, Tailoring
	AddVendor(11536,	L["Quartermaster Miranda Breechlock"],	Z.EASTERN_PLAGUELANDS,		75.8,	54.0,	"Neutral",		V.CATA) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(11557,	L["Meilosh"],							Z.FELWOOD,					64.8,	5.2, 	"Neutral",		V.CATA) -- Alchemy, Blacksmithing, Enchanting, Leatherworking, Tailoring
	AddVendor(13420,	L["Penney Copperpinch"],				Z.ORGRIMMAR,				52.6,	77.6,	"Neutral",		V.CATA) -- Cooking, Leatherworking, Tailoring
	AddVendor(15179,	L["Mishta"],							Z.SILITHUS,					53.8,	34.4,	"Neutral",		V.CATA) -- Jewelcrafting, Tailoring
	AddVendor(15419,	L["Kania"],								Z.SILITHUS,					55.6,	37.2,	"Neutral",		V.CATA) -- Enchanting, Tailoring
	AddVendor(46572,	L["Goram"],								Z.ORGRIMMAR,				48.2,	75.6,	"Horde",		V.CATA) -- Alchemy, Cooking
	AddVendor(46602,	L["Shay Pressler"],						Z.STORMWIND_CITY,			64.6,	76.8,	"Alliance",		V.CATA) -- Alchemy, Cooking
	AddVendor(51495,	L["Steeg Haskell"],						Z.IRONFORGE,				36.3,	85.8,	"Alliance",		V.CATA) -- Alchemy, Cooking
	AddVendor(51496,	L["Kim Horn"],							Z.UNDERCITY,				69.6,	43.8,	"Horde",		V.CATA) -- Alchemy, Cooking
	AddVendor(51503,	L["Randah Songhorn"],					Z.THUNDER_BLUFF,			37.6,	62.8,	"Horde",		V.CATA) -- Alchemy, Cooking
	AddVendor(51512,	L["Mirla Silverblaze"],					Z.DALARAN_NORTHREND,		52.6,	56.6,	"Neutral",		V.CATA) -- Alchemy, Cooking
	AddVendor(53214,	L["Damek Bloombeard"],					Z.MOLTEN_FRONT,				47.0,	90.6,	"Neutral",		V.CATA) -- Blacksmithing, Engineering
	AddVendor(53410,	L["Lissah Spellwick"],					Z.DUSTWALLOW_MARSH,			66.0,	49.7,	"Alliance",		V.CATA) -- Enchanting, Tailoring
	AddVendor(53881,	L["Ayla Shadowstorm"],					Z.MOLTEN_FRONT,				44.8,	86.6,	"Neutral",		V.CATA) -- Leatherworking, Tailoring

	-- ----------------------------------------------------------------------------
	-- Mists of Pandaria
	-- ----------------------------------------------------------------------------
	AddVendor(59908,	L["Jaluu the Generous"],				Z.VALE_OF_ETERNAL_BLOSSOMS,	74.2,	42.6,	"Neutral",		V.MOP) -- Leatherworking, Tailoring
	AddVendor(64001,	L["Sage Lotusbloom"],					Z.VALE_OF_ETERNAL_BLOSSOMS,	62.6,	23.2,	"Horde",		V.MOP) -- Needs updating
	AddVendor(64032,	L["Sage Whiteheart"],					Z.VALE_OF_ETERNAL_BLOSSOMS,	0.0,	0.0,	"Alliance",		V.MOP) -- Enchanting, Tailoring  -- Needs updating

	-- ----------------------------------------------------------------------------
	-- Warlords of Dreanor
	-- ----------------------------------------------------------------------------
	AddVendor(90894,	L["Alexi Hackercam"],					Z.LUNARFALL,				34.6,	33.0,	"Alliance",		V.WOD) -- Blacksmithing, Engineering, Jewelcrafting
	AddVendor(91030,	L["Trixxy Volt"],						Z.FROSTWALL,				40.8,	54.8,	"Horde",		V.WOD) -- Blacksmithing, Engineering, Jewelcrafting
	AddVendor(91031,	L["Nicholas Mitrik"],					Z.FROSTWALL,				40.8,	54.8,	"Horde",		V.WOD) -- Alchemy, Inscription
	AddVendor(91404,	L["Samantha Scarlet"],					Z.LUNARFALL,				34.6,	33.0,	"Alliance",		V.WOD) -- Alchemy, Inscription

	-- ----------------------------------------------------------------------------
	-- Legion
	-- ----------------------------------------------------------------------------
	AddVendor(93530,	L["Ildine Sorrowspear"],				Z.DALARAN_BROKENISLES,		38.3,	41.5,	"Neutral",		V.LEGION) -- Enchanting, Tailoring
	AddVendor(93539,	L["Hobart Grapplehammer"],				Z.DALARAN_BROKENISLES,		38.6,	25.2,	"Neutral",		V.LEGION) -- Jewelcrafting, Engineering, Inscription
	AddVendor(97360,	L["Matthew Rabis"],						Z.DALARAN_BROKENISLES,		46.0,	56.4,	"Neutral",		V.LEGION) -- Jewelcrafting, Skinning, Inscription
	AddVendor(97361,	L["Oxana Demonslay"],					Z.DALARAN_BROKENISLES,		67.0,	17.7,	"Neutral",		V.LEGION) -- Jewelcrafting, Inscription
	AddVendor(97362,	L["Dazzik \"Proudmoore\""],				Z.DALARAN_BROKENISLES,		66.2,	74.1,	"Neutral",		V.LEGION) -- Jewelcrafting, Tailoring
	AddVendor(97363,	L["K'huta"],							Z.DALARAN_BROKENISLES,		65.7,	80.3,	"Neutral",		V.LEGION) -- Enchanting, Inscription
	AddVendor(97366,	L["The Widow"],							Z.DALARAN_BROKENISLES,		71.8,	73.8,	"Neutral",		V.LEGION) -- Jewelcrafting, Engineering, Inscription
	AddVendor(97140,	L["First Arcanist Thalyssra"],			Z.SURAMAR,					36.8,	46.6,	"Neutral",		V.LEGION) -- Enchanting, Tailoring, Alchemy
	AddVendor(106901,	L["Sylvia Hartshorn"],					Z.VALSHARAH,				54.7,	73.2,	"Neutral",		V.LEGION) -- Enchanting, Leatherworking
	AddVendor(106902,	L["Ransa Greyfeather"],					Z.THUNDER_TOTEM,			38.8,	45.4,	"Neutral",		V.LEGION) -- Jewelcrafting, Blacksmithing
	AddVendor(106904,	L["Valdemar Stormseeker"],				Z.STORMHEIM,				60.2,	51.2,	"Neutral",		V.LEGION) -- Leatherworking, Blacksmithing
	AddVendor(107109,	L["Xur'ios"],							Z.DALARAN_BROKENISLES,		48.8,	13.5,	"Neutral",		V.LEGION) -- Leatherworking, Engineering, Blacksmithing, Enchanting, Inscription
	AddVendor(107376,	L["Veridis Fallon"],					Z.AZSUNA,					46.9,	41.4,	"Neutral",		V.LEGION) -- Inscriptions, Tailoring
	AddVendor(107379,	L["Marin Bladewing"],					Z.AZSUNA,					48.2,	73.8,	"Neutral",		V.LEGION) -- Inscription, Jewelcrafting, Engineering
	AddVendor(107760,	L["Strap Bucklebolt"],					Z.DALARAN_BROKENISLES,		66.4,	81.4,	"Neutral",		V.LEGION) -- Blacksmithing, Leatherworking, Tailoring
	AddVendor(115736,	L["First Arcanist Thalyssra"],			Z.SURAMAR,					36.8,	46.6,	"Neutral",		V.LEGION) -- Enchanting, Tailoring, Alchemy
	AddVendor(127120,	L["Vindicator Jaelaana"],				Z.ARGUS,					0.0,	0.0,	"Neutral",		V.LEGION) -- Jewelcrafting, Blacksmithing, Tailoring
	AddVendor(127151,	L["Toraan the Revered"],				Z.ANTORAN_WASTES,			0.0,	0.0,	"Neutral",		V.LEGION) -- Inscription, Alchemy, Enchanting

	-- ----------------------------------------------------------------------------
	-- Battle for Azeroth
	-- ----------------------------------------------------------------------------
	AddVendor(131287,	L["Natal'hakata"],						Z.DAZARALOR,				65.2,	71.2,	"Horde",		V.BFA)
	AddVendor(134345,	L["Collector Kojo"],					Z.ZULDAZAR,					71.4,	30.2,	"Neutral",		V.BFA)
	AddVendor(135446,	L["Vindicator Jaelaana"],				Z.BORALUS,					69.0,	24.7,	"Alliance",		V.BFA) -- Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting)
	AddVendor(135447,	L["Ransa Greyfeather"],					Z.ZULDAZAR,					58.0,	62.6,	"Horde",		V.BFA) -- Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting)
	AddVendor(135459,	L["Provisioner Lija"],					Z.NAZMIR,					39.0,	79.4,	"Horde",		V.BFA)
	AddVendor(135793,	L["Collector Kojo"],					Z.STORMSONG_VALLEY,			40.4,	36.4,	"Neutral",		V.BFA)
	AddVendor(135800,	L["Sister Lilyana"],					Z.STORMSONG_VALLEY,			59.2,	69.4,	"Alliance",		V.BFA)
	AddVendor(135804,	L["Hoarder Jena"],						Z.VOLDUN,					56.6,	49.8,	"Horde",		V.BFA)
	AddVendor(135808,	L["Provisioner Fray"],					Z.BORALUS,					67.6,	21.9,	"Alliance",		V.BFA) -- Alchemy,
	AddVendor(135815,	L["Quartermaster Alcorn"],				Z.DRUSTVAR,					37.8,	49.0,	"Alliance",		V.BFA)
	AddVendor(142552,	L["Ozgrom Ragefang"],					Z.ZULDAZAR,					52.6,	58.2,	"Horde",		V.BFA) -- PvP vendor with plans for all professions
	AddVendor(142564,	L["Leedan Gustaf"],						Z.BORALUS,					56.3,	27.2,	"Alliance",		V.BFA) -- PvP vendor with plans for all professions
	AddVendor(153512,	L["Finder Pruc"],						Z.NAZJATAR,					49.0,	62.2,	"Horde",		V.BFA) -- Alchemy, Cooking, Enchanting, Inscription
	AddVendor(153514,	L["Finder Palta"],						Z.NAZJATAR,					49.2,	62.0,	"Horde",		V.BFA)
	AddVendor(154140,	L["Speaker Utia"],						Z.NAZJATAR,					38.0,	55.7,	"Alliance",		V.BFA) -- Alchemy, Cooking, Enchanting, Inscription
	AddVendor(154652,	L["Dazzerian"],							Z.NAZJATAR,					48.6,	60.8,	"Horde",		V.BFA) -- PvP vendor
	AddVendor(154653,	L["Crafticus Mindbender"],				Z.NAZJATAR,					38.1,	55.4,	"Alliance",		V.BFA) -- PvP vendor
	AddVendor(150716,	L["Stolen Royal Vendorbot"],			Z.MECHAGON_ISLAND,			73.7,	36.9,	"Neutral",		V.BFA)

	-- ----------------------------------------------------------------------------
	-- Shadowlands
	-- ----------------------------------------------------------------------------
	AddVendor(156822,	L["Mistress Mihaela"],					Z.REVENDRETH,				61.4,	63.8,	"Neutral",		V.SHA)
	AddVendor(158556,	L["Aithlyn"],							Z.ARDENWEALD,				60.2,	35.2,	"Neutral",		V.SHA) --Wild Hunt Quartermaster
	AddVendor(160470,	L["Adjutant Nikos"],					Z.BASTION,					52.2,	47.1,	"Neutral",		V.SHA) --Ascended Quartermaster
	AddVendor(161565,	L["Bragni"],							Z.BORALUS,					56.4,	27.0,	"Neutral",		V.SHA)
	AddVendor(162804,	L["Ve'nari"],							Z.THE_MAW,					46.8,	41.6,	"Neutral",		V.SHA)
	AddVendor(173003,	L["Nalcorn Talsen"],					Z.MALDRAXXUS,				50.6,	53.4,	"Neutral",		V.SHA) --Undying Army Quartermaster
	AddVendor(173705,	L["Archivist Janeera"],					Z.REVENDRETH,				73.0,	52.0,	"Neutral",		V.SHA) --Avowed Quartermaster
	AddVendor(174914,	L["Elwyn"],								Z.ARDENWEALD,				59.4,	33.0,	"Neutral",		V.SHA) --Renown Quartermaster in Ardenweald
	AddVendor(176064,	L["Adjutant Mikaros"],					Z.ORIBOS,					47.6,	77.6,	"Neutral",		V.SHA) -- Ascended Quartermaster
	AddVendor(176065,	L["Liawyn"],							Z.ORIBOS,					47.0,	76.8,	"Neutral",		V.SHA) -- Wild Hunt Quartermaster
	AddVendor(176066,	L["Darvel the Frugal"],					Z.ORBIOS,					46.6,	77.6,	"Neutral",		V.SHA) -- Court of Harvesters Quartermaster
	AddVendor(176067,	L["Dar Vattish"],						Z.ORBIOS,					47.6,	77.6,	"Neutral",		V.SHA) -- Undying Army Quartermaster
	AddVendor(176368,	L["Archivist Leonara"],					Z.ORBIOS,					46.6,	77.6,	"Neutral",		V.SHA) -- Avowed Quartermaster
	AddVendor(178257,	L["Archivist Roh-Suir"],				Z.KORTHIA,					62.8,	22.6,	"Neutral",		V.SHA)
	AddVendor(179321,	L["Duchess Mynx"],						Z.KORTHIA,					63.4,	23.4,	"Neutral",		V.SHA)  -- Death's Advance Quartermaster
	AddVendor(182257,	L["Vilo"],								Z.ZERETH_MORTIS,			34.8,	64.2,	"Neutral",		V.SHA)  --Enlightened Quartermaster
	AddVendor(183962,	L["Olea Manu"],							Z.ZERETH_MORTIS,			37.0,	44.6,	"Neutral",		V.SHA)

	self.InitVendor = nil
end
