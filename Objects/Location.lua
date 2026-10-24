-- Ackis Forever location registry. Snapshot: 2026-09-30; instance geography corrected 2026-10-04.
-- Source: https://www.wowhead.com/forever/zones

local FOLDER_NAME, private = ...
local HBD = _G.LibStub("HereBeDragons-2.0")
local UNKNOWN = _G.UNKNOWN or "Unknown"
local ZONE_REGISTRY = {
	AHNQIRAJ = {name = "Ahn'Qiraj", areaIDs = {3428}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	ALTERAC_MOUNTAINS = {name = "Alterac Mountains", areaIDs = {36}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	ALTERAC_VALLEY = {name = "Alterac Valley", areaIDs = {2597}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	ARATHI_BASIN = {name = "Arathi Basin", areaIDs = {3358}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	ARATHI_HIGHLANDS = {name = "Arathi Highlands", areaIDs = {45}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	ASHENVALE = {name = "Ashenvale", areaIDs = {331, 16169}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	AZSHARA = {name = "Azshara", areaIDs = {16, 16003}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	BADLANDS = {name = "Badlands", areaIDs = {3}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	BATTLE_FOR_GILNEAS = {name = "Battle for Gilneas", areaIDs = {16653}, continent = 0, kind = "zone"},
	BLACKFATHOM_DEEPS = {name = "Blackfathom Deeps", areaIDs = {719}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	BLACKROCK_DEPTHS = {name = "Blackrock Depths", areaIDs = {1584, 17803}, continent = 2, kind = "instance", parent = "BURNING_STEPPES", entrance = "20.72:36.94"},
	BLACKROCK_MOUNTAIN = {name = "Blackrock Mountain", areaIDs = {25}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	BLACKROCK_SPIRE = {name = "Blackrock Spire", areaIDs = {1583, 17804}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	BLACKWING_LAIR = {name = "Blackwing Lair", areaIDs = {2677}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	BLASTED_LANDS = {name = "Blasted Lands", areaIDs = {4, 16115}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	BURNING_STEPPES = {name = "Burning Steppes", areaIDs = {46, 16508}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	CAVERNS_OF_TIME = {name = "Caverns of Time", areaIDs = {1941}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	CITY_OF_DALARAN = {name = "City of Dalaran", areaIDs = {16544, 16560}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	CRAFTING = {name = "Crafting", areaIDs = {16941}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS", internal = true},
	DARKSHORE = {name = "Darkshore", areaIDs = {148}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	DARKSPEAR_ISLANDS = {name = "Darkspear Islands", areaIDs = {16606}, continent = 0, kind = "zone"},
	DARNASSUS = {name = "Darnassus", areaIDs = {1657}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	DEADWIND_PASS = {name = "Deadwind Pass", areaIDs = {41, 16114}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	DEEPRUN_TRAM = {name = "Deeprun Tram", areaIDs = {2257}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	DEMON_FALL_CANYON = {name = "Demon Fall Canyon", areaIDs = {15475}, continent = 0, kind = "instance"},
	DESOLACE = {name = "Desolace", areaIDs = {405, 16017}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	DIRE_MAUL = {name = "Dire Maul", areaIDs = {2557}, continent = 1, kind = "instance", parent = "FERALAS", entrance = "61.36:31.78"},
	DUN_MOROGH = {name = "Dun Morogh", areaIDs = {1}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	DUROTAR = {name = "Durotar", areaIDs = {14}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	DUSKWOOD = {name = "Duskwood", areaIDs = {10, 16119, 16148}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	DUSTWALLOW_MARSH = {name = "Dustwallow Marsh", areaIDs = {15}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	EASTERN_KINGDOMS = {name = "Eastern Kingdoms", areaIDs = {}, continent = 2, kind = "continent"},
	EASTERN_PLAGUELANDS = {name = "Eastern Plaguelands", areaIDs = {139, 16028}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	ELSEWHEN = {name = "Elsewhen", areaIDs = {15793}, continent = 0, kind = "instance"},
	ELWYNN_FOREST = {name = "Elwynn Forest", areaIDs = {12, 16118, 16147, 16510}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	ELWYNN_FOREST_BLUE_WHELPLING_INN_PROTOTYPE = {name = "Elwynn Forest (Blue Whelpling Inn Prototype)", areaIDs = {16144}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS", internal = true},
	EMERALD_FOREST = {name = "Emerald Forest", areaIDs = {1397}, continent = 0, kind = "instance"},
	EXCAVATION_SITE_WETLANDS = {name = "Excavation Site: Wetlands", areaIDs = {16732}, continent = 2, kind = "instance", parent = "WETLANDS"},
	FELWOOD = {name = "Felwood", areaIDs = {361, 15809}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	FERALAS = {name = "Feralas", areaIDs = {357, 16018}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	GILNEAS = {name = "Gilneas", areaIDs = {17065}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	GNOMEREGAN = {name = "Gnomeregan", areaIDs = {721}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	HALF_PINT_TAVERN = {name = "Half-Pint Tavern", areaIDs = {16632}, continent = 0, kind = "instance"},
	HILLSBRAD_FOOTHILLS = {name = "Hillsbrad Foothills", areaIDs = {267, 16562}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	IRONFORGE = {name = "Ironforge", areaIDs = {1537}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	KALIMDOR = {name = "Kalimdor", areaIDs = {}, continent = 1, kind = "continent"},
	KARAZHAN_CRYPTS = {name = "Karazhan Crypts", areaIDs = {16074}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	LOCH_MODAN = {name = "Loch Modan", areaIDs = {38}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	MANOR_MISTMANTLE = {name = "Manor Mistmantle", areaIDs = {17191}, continent = 0, kind = "instance"},
	MARAUDON = {name = "Maraudon", areaIDs = {2100}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	MOLTEN_CORE = {name = "Molten Core", areaIDs = {2717}, continent = 2, kind = "instance", parent = "BURNING_STEPPES"},
	MOONGLADE = {name = "Moonglade", areaIDs = {493}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	MOUNT_HYJAL = {name = "Mount Hyjal", areaIDs = {616, 16004}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	MULGORE = {name = "Mulgore", areaIDs = {215}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	NAXXRAMAS = {name = "Naxxramas", areaIDs = {3456, 16394}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	ONYXIAS_LAIR = {name = "Onyxia's Lair", areaIDs = {2159}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	ORGRIMMAR = {name = "Orgrimmar", areaIDs = {1637}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	RAGEFIRE_CHASM = {name = "Ragefire Chasm", areaIDs = {2437}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	RAZORFEN_DOWNS = {name = "Razorfen Downs", areaIDs = {722}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	RAZORFEN_KRAUL = {name = "Razorfen Kraul", areaIDs = {491}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	REDRIDGE_MOUNTAINS = {name = "Redridge Mountains", areaIDs = {44, 16113}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	RIVERGLADES = {name = "Riverglades", areaIDs = {16591}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	RUINS_OF_AHNQIRAJ = {name = "Ruins of Ahn'Qiraj", areaIDs = {3429}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	RUINS_OF_GILNEAS = {name = "Ruins of Gilneas", areaIDs = {16756}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	RUINS_OF_LORDAERON = {name = "Ruins of Lordaeron", areaIDs = {16611}, continent = 2, kind = "instance", parent = "TIRISFAL_GLADES"},
	SCARLET_ENCLAVE = {name = "Scarlet Enclave", areaIDs = {16236}, continent = 0, kind = "instance"},
	SCARLET_MONASTERY = {name = "Scarlet Monastery", areaIDs = {796}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	SCHOLOMANCE = {name = "Scholomance", areaIDs = {2057}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	SEARING_GORGE = {name = "Searing Gorge", areaIDs = {51}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	SHADOWFANG_KEEP = {name = "Shadowfang Keep", areaIDs = {209}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	SHADOW_HOLD = {name = "Shadow Hold", areaIDs = {16362}, continent = 0, kind = "instance"},
	SHARK_INFESTED_WATERS = {name = "Shark-Infested Waters", areaIDs = {17066}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	SHENDRALAS = {name = "Shen'dralas", areaIDs = {16651}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	SILITHUS = {name = "Silithus", areaIDs = {1377}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	SILVERPINE_FOREST = {name = "Silverpine Forest", areaIDs = {130}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	STARFALL_VILLAGE = {name = "Starfall Village", areaIDs = {15938}, continent = 0, kind = "instance"},
	STONETALON_MOUNTAINS = {name = "Stonetalon Mountains", areaIDs = {406}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	STORMRS_TEST_MAP = {name = "Stormr's Test Map", areaIDs = {16662}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS", internal = true},
	STORMWIND_CITY = {name = "Stormwind City", areaIDs = {1519, 16509}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	STORM_CLIFFS = {name = "Storm Cliffs", areaIDs = {15532}, continent = 1, kind = "instance", parent = "AZSHARA"},
	STRANGLETHORN_VALE = {name = "Stranglethorn Vale", areaIDs = {33, 16117}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	STRATHOLME = {name = "Stratholme", areaIDs = {2017}, continent = 2, kind = "instance", parent = "EASTERN_PLAGUELANDS", entrance = "26.75:11.60"},
	SUNKEN_TEMPLE = {name = "Sunken Temple", areaIDs = {1417}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	SWAMP_OF_SORROWS = {name = "Swamp of Sorrows", areaIDs = {8, 16116}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	TANARIS = {name = "Tanaris", areaIDs = {440}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	TELDRASSIL = {name = "Teldrassil", areaIDs = {141}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	TEMPLE_OF_AHNQIRAJ = {name = "Temple of Ahn'Qiraj", areaIDs = {16076}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	TEST_DUNGEON = {name = "Test Dungeon", areaIDs = {13649}, continent = 0, kind = "instance", internal = true},
	THE_BARRENS = {name = "The Barrens", areaIDs = {17}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	THE_BURNING_OF_ANDORHAL = {name = "The Burning of Andorhal", areaIDs = {15828}, continent = 0, kind = "instance"},
	THE_CRYSTAL_VALE = {name = "The Crystal Vale", areaIDs = {15825}, continent = 0, kind = "instance"},
	THE_DEADMINES = {name = "The Deadmines", areaIDs = {1581}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	THE_GREAT_SEA = {name = "The Great Sea", areaIDs = {207}, continent = 0, kind = "instance"},
	THE_HALL_OF_THANES = {name = "The Hall of Thanes", areaIDs = {16919}, continent = 2, kind = "instance", parent = "IRONFORGE"},
	THE_HINTERLANDS = {name = "The Hinterlands", areaIDs = {47, 16029}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	THE_SCARAB_DAIS = {name = "The Scarab Dais", areaIDs = {16295}, continent = 0, kind = "instance"},
	THE_STOCKADE = {name = "The Stockade", areaIDs = {717}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	THE_TAINTED_SCAR = {name = "The Tainted Scar", areaIDs = {15531}, continent = 2, kind = "instance", parent = "BLASTED_LANDS"},
	THE_TEMPLE_OF_ATALHAKKAR = {name = "The Temple of Atal'Hakkar", areaIDs = {1477}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	THE_VEILED_SEA = {name = "The Veiled Sea", areaIDs = {457}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	THOUSAND_NEEDLES = {name = "Thousand Needles", areaIDs = {400}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	THUNDER_BLUFF = {name = "Thunder Bluff", areaIDs = {1638}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	TIRISFAL_GLADES = {name = "Tirisfal Glades", areaIDs = {85}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	TYLERS_TEST_MAP_DESOLACE = {name = "Tyler's Test Map (Desolace)", areaIDs = {16532}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS", internal = true},
	ULDAMAN = {name = "Uldaman", areaIDs = {1337}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
	UNDERCITY = {name = "Undercity", areaIDs = {1497}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	UNGORO_CRATER = {name = "Un'Goro Crater", areaIDs = {490}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	UNUSED = {name = "Unused", areaIDs = {16772}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS", internal = true},
	WAILING_CAVERNS = {name = "Wailing Caverns", areaIDs = {718}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	WARSONG_GULCH = {name = "Warsong Gulch", areaIDs = {3277, 16603}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	WESTERN_PLAGUELANDS = {name = "Western Plaguelands", areaIDs = {28}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	WESTFALL = {name = "Westfall", areaIDs = {40, 16149}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	WETLANDS = {name = "Wetlands", areaIDs = {11}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	WHELGARS_EXCAVATION_SITE = {name = "Whelgar's Excavation Site", areaIDs = {16876}, continent = 2, kind = "zone", parent = "EASTERN_KINGDOMS"},
	WINTERSPRING = {name = "Winterspring", areaIDs = {618}, continent = 1, kind = "zone", parent = "KALIMDOR"},
	ZEPHRAS_ISLE = {name = "Zephras Isle", areaIDs = {16593}, continent = 0, kind = "zone"},
	ZULFARRAK = {name = "Zul'Farrak", areaIDs = {1176}, continent = 1, kind = "instance", parent = "KALIMDOR"},
	ZULGURUB = {name = "Zul'Gurub", areaIDs = {1977}, continent = 2, kind = "instance", parent = "EASTERN_KINGDOMS"},
}
private.ZONE_REGISTRY = ZONE_REGISTRY

local function Normalize(name)
	return name and name:lower():gsub("[^%w]", "")
end

-- Build one English-name index. Lookup and localization are cached afterwards.
local mapData = HBD.mapData or {}
local mapsByName, mapsByLocalizedName, localizedNames = {}, {}, {}
for mapID, data in pairs(mapData) do
	local key = Normalize(data.name)
	if key then
		mapsByName[key] = mapsByName[key] or {}
		mapsByName[key][#mapsByName[key] + 1] = mapID
	end
end
local function MapName(mapID)
	if localizedNames[mapID] == nil then
		localizedNames[mapID] = HBD:GetLocalizedMap(mapID) or false
	end
	return localizedNames[mapID] or nil
end
for mapID in pairs(mapData) do
	local key = Normalize(MapName(mapID))
	if key then
		mapsByLocalizedName[key] = mapsByLocalizedName[key] or {}
		mapsByLocalizedName[key][#mapsByLocalizedName[key] + 1] = mapID
	end
end

local uiMapType = (_G.Enum and _G.Enum.UIMapType) or {}
local continentType, zoneType, dungeonType = uiMapType.Continent or 2, uiMapType.Zone or 3, uiMapType.Dungeon or 4
local ZONE_MAP_IDS, ZONE_NAMES, ZONE_LABELS_FROM_NAME = {}, {}, {}
local ZONE_LABELS_FROM_MAP_ID, continentCache = {}, {}
local continentLabels = {[1] = "KALIMDOR", [2] = "EASTERN_KINGDOMS"}

local function ContinentForMap(mapID)
	if not mapID then return 0 end
	if continentCache[mapID] ~= nil then return continentCache[mapID] end
	local seen, current, result = {}, mapID, 0
	while current and not seen[current] do
		seen[current] = true
		if current == ZONE_MAP_IDS.KALIMDOR then result = 1; break end
		if current == ZONE_MAP_IDS.EASTERN_KINGDOMS then result = 2; break end
		if continentCache[current] ~= nil then result = continentCache[current]; break end
		current = mapData[current] and mapData[current].parent
	end
	for id in pairs(seen) do continentCache[id] = result end
	return result
end

local function ResolveMap(entry)
	local candidates = mapsByName[Normalize(entry.name)] or {}
	if #candidates == 0 and _G.C_Map and _G.C_Map.GetAreaInfo then
		-- The registry stores English names, while HereBeDragons may expose
		-- localized map names. Resolve through the localized area names only
		-- when the stable English lookup did not find a map.
		for _, areaID in ipairs(entry.areaIDs or {}) do
			local areaName = _G.C_Map.GetAreaInfo(areaID)
			local localizedCandidates = areaName and mapsByLocalizedName[Normalize(areaName)]
			if localizedCandidates then
				candidates = localizedCandidates
				break
			end
		end
	end
	local bestID, bestScore
	for _, mapID in ipairs(candidates) do
		local data = mapData[mapID]
		local allowed = entry.kind == "continent" and data.mapType == continentType
			or entry.kind ~= "continent" and type(data.mapType) == "number" and data.mapType >= zoneType
		if allowed then
			local continent = entry.kind ~= "continent" and ContinentForMap(mapID) or 0
			if not entry.continent or entry.continent == 0 or continent == 0 or continent == entry.continent then
				local expectedType = entry.kind == "instance" and dungeonType or zoneType
				local score = (data.mapType == expectedType and 8 or 0) + (continent > 0 and 4 or 0)
				if not bestScore or score > bestScore or score == bestScore and mapID < bestID then
					bestID, bestScore = mapID, score
				end
			end
		end
	end
	return bestID
end

-- Resolve continents first so all remaining geography checks share their cache.
for _, label in ipairs(continentLabels) do
	ZONE_MAP_IDS[label] = ResolveMap(ZONE_REGISTRY[label])
end
for label, entry in pairs(ZONE_REGISTRY) do
	if not entry.internal then
		local mapID = ZONE_MAP_IDS[label] or ResolveMap(entry)
		ZONE_MAP_IDS[label] = mapID
		local name = mapID and MapName(mapID) or entry.name
		ZONE_NAMES[label] = name
		ZONE_LABELS_FROM_NAME[name] = label
		if mapID then ZONE_LABELS_FROM_MAP_ID[mapID] = label end
	end
end

private.ZONE_NAMES = ZONE_NAMES
private.constants.ZONE_NAMES = ZONE_NAMES
private.ZONE_MAP_IDS = ZONE_MAP_IDS
private.ZONE_LABELS_FROM_NAME = ZONE_LABELS_FROM_NAME
private.WOWHEAD_ZONE_LABELS_FROM_ID = {}
private.WOWHEAD_ZONE_NAMES_FROM_ID = {}
for label, entry in pairs(ZONE_REGISTRY) do
	for _, areaID in ipairs(entry.areaIDs) do
		private.WOWHEAD_ZONE_LABELS_FROM_ID[areaID] = label
		private.WOWHEAD_ZONE_NAMES_FROM_ID[areaID] = ZONE_NAMES[label] or entry.name
	end
end

local Location = {}
local LocationMetatable = {__index = Location}
local Locations, LocationsByLocalizedName, LocationsByMapID = {}, {}, {}
local locationsByLabel, ContinentLocationByID = {}, {}
private.Locations = Locations
private.LocationsByLocalizedName = LocationsByLocalizedName
private.LocationsByMapID = LocationsByMapID
private.ContinentLocationByID = ContinentLocationByID

function Location:AssignRecipe(recipe, affiliation) self._recipes[recipe] = affiliation end
function Location:ContinentID() return self._continentID end
function Location:EntranceCoordinates()
	if self._entranceCoordinates then
		local x, y = self._entranceCoordinates:match("^([%d.]+):([%d.]+)$")
		return tonumber(x) or 0, tonumber(y) or 0
	end
	return 0, 0
end
function Location:GetRecipeAffiliation(recipe) return self._recipes[recipe] end
function Location:GetSortedRecipes() return private.SortRecipePairs(self._recipes) end
function Location:HasRecipe(recipe) return self._recipes[recipe] end
function Location:Label() return self._label end
function Location:LocalizedName() return self._localizedName end
function Location:MapID() return self._mapID end
function Location:Name() return self._name end
function Location:Parent() return self._parent end
function Location:RecipePairs() return pairs(self._recipes) end
function Location:GetValidMapID()
	if self._mapID and self._mapID > 0 then return self._mapID end
	if self._entranceCoordinates and self._parent then return self._parent:GetValidMapID() end
	return nil
end

local function KeyFromLocalized(name)
	local words = {}
	for word in name:gsub("[^%w]+", " "):gmatch("%S+") do
		words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2):lower()
	end
	return table.concat(words, "")
end

local function CreateLocation(label, name, mapID, continent)
	local key = label and label:lower():gsub("^%l", string.upper):gsub("_%l", string.upper):gsub("_", "") or KeyFromLocalized(name)
	if Locations[key] and Locations[key]._localizedName ~= name then key = key .. tostring(mapID or -1) end
	local location = setmetatable({
		_label = label, _localizedName = name, _name = key, _mapID = mapID or -1,
		_continentID = continent or 0, _recipes = {},
	}, LocationMetatable)
	Locations[key] = location
	LocationsByLocalizedName[name] = location
	if label then locationsByLabel[label] = location end
	if mapID then LocationsByMapID[mapID] = location end
	return location
end

local function AttachParent(location, parent)
	if not parent or parent == location then return end
	local seen, current = {}, parent
	while current do
		if current == location or seen[current] then return end
		seen[current] = true
		current = current._parent
	end
	location._parent = parent
	parent._childLocations = parent._childLocations or {}
	parent._childLocations[location._name] = location
	parent._childLocationsByLocalizedName = parent._childLocationsByLocalizedName or {}
	parent._childLocationsByLocalizedName[location._localizedName] = location
end

local function RegisteredMapParent(mapID)
	local seen = {}
	local current = mapData[mapID] and mapData[mapID].parent
	while current and not seen[current] do
		seen[current] = true
		if LocationsByMapID[current] then return LocationsByMapID[current] end
		current = mapData[current] and mapData[current].parent
	end
end

-- Names and sources remain usable even when a Forever zone has no client map.
for label, entry in pairs(ZONE_REGISTRY) do
	if not entry.internal then
		local mapID = ZONE_MAP_IDS[label]
		local nativeContinent = mapID and ContinentForMap(mapID) or 0
		local continent = nativeContinent > 0 and nativeContinent or entry.continent
		local location = CreateLocation(label, ZONE_NAMES[label], mapID, continent)
		if entry.kind == "continent" then ContinentLocationByID[entry.continent] = location end
	end
end
for label, location in pairs(locationsByLabel) do
	local entry = ZONE_REGISTRY[label]
	local explicitParent = entry.parent and locationsByLabel[entry.parent]
	if entry.entrance and explicitParent and explicitParent._mapID > 0 then
		AttachParent(location, explicitParent)
		location._entranceCoordinates = entry.entrance
	elseif entry.kind ~= "continent" then
		-- New Forever instances can have an area ID without a native UI map.
		-- Their declared geography must still participate in location grouping.
		local nativeParent = location._mapID > 0 and RegisteredMapParent(location._mapID) or nil
		AttachParent(location, nativeParent or explicitParent or ContinentLocationByID[location._continentID])
	end
end

-- Unknown localized names from NPC databases share one lazily built name index.
local localizedMapIndex
local function FindLocalizedMap(name)
	if not localizedMapIndex then
		localizedMapIndex = {}
		for mapID in pairs(mapData) do
			local localized = MapName(mapID)
			if localized then
				local key = Normalize(localized)
				local previous = localizedMapIndex[key]
				if not previous or mapID < previous then localizedMapIndex[key] = mapID end
			end
		end
	end
	return localizedMapIndex[Normalize(name)]
end

function private.EnsureLocationByLocalizedName(localizedName)
	if type(localizedName) ~= "string" or localizedName == "" then localizedName = UNKNOWN end
	if LocationsByLocalizedName[localizedName] then return LocationsByLocalizedName[localizedName] end
	local mapID = FindLocalizedMap(localizedName)
	if mapID and LocationsByMapID[mapID] then
		LocationsByLocalizedName[localizedName] = LocationsByMapID[mapID]
		return LocationsByMapID[mapID]
	end
	local location = CreateLocation(nil, localizedName, mapID, ContinentForMap(mapID))
	if mapID then AttachParent(location, RegisteredMapParent(mapID)) end
	return location
end

-- Both old-world continents share one acquisition grouping, not a waypoint map.
local worldDropLocation = setmetatable({
	_continentID = 0, _localizedName = "Azeroth", _mapID = -1,
	_name = "AzerothWorldDrops", _recipes = {}, _worldDropAggregate = true,
}, LocationMetatable)
Locations.AzerothWorldDrops = worldDropLocation
private.WorldDropLocation = worldDropLocation
