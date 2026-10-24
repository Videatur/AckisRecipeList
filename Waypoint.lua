-- Ackis Forever waypoints: TomTom integration and standalone HBD pins.
local _, private = ...
local LibStub = _G.LibStub
local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
local UNKNOWN = L["Unknown"] or "Unknown"
local PARENS_TEMPLATE = _G.PARENS_TEMPLATE or "(%s)"
local HEX_FORMAT = "|cff%s%s|r"
local activeWaypoints, waypointIndex, pinPool = {}, {}, {}
local localizedMapIndex
local lastAutoScanTime = -math.huge
local AUTO_SCAN_THROTTLE = 2
local QueueAutoScan

local function Finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function ValidCoordinates(x, y)
    return Finite(x) and Finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

-- Coordinates belong to this map only. A parent map is not a safe substitute.
local function ResolveMapID(location)
    if not location then return nil end
    local mapID = location:MapID()
    if Finite(mapID) and mapID > 0 and HBD:GetLocalizedMap(mapID) then return mapID end
    local name = location:LocalizedName()
    if type(name) ~= "string" then return nil end
    if not localizedMapIndex then
        localizedMapIndex = {}
        for _, id in ipairs(HBD:GetAllMapIDs()) do
            local localized = HBD:GetLocalizedMap(id)
            if localized then
                local key = localized:lower()
                local previous = localizedMapIndex[key]
                if not previous or id < previous then localizedMapIndex[key] = id end
            end
        end
    end
    return localizedMapIndex[name:lower()]
end

local function AcquirePin(title)
    local pin = table.remove(pinPool)
    if not pin then
        pin = _G.CreateFrame("Button", nil, _G.Minimap)
        pin:SetSize(16, 16)
        local texture = pin:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(136815)
        texture:SetAllPoints()
        pin:SetHighlightTexture(136815)
        pin:GetHighlightTexture():SetVertexColor(1, 1, 0, 0.5)
        pin:SetScript("OnEnter", function(self)
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(self.title, 1, 1, 1)
            _G.GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
        pin:RegisterForClicks("RightButtonUp")
        pin:SetScript("OnClick", function(self) addon:RemoveWaypoint(self.waypoint) end)
    end
    pin.title = title or ""
    pin:Hide() -- HBD controls visibility after registration.
    return pin
end

local function ReleasePin(pin)
    HBDPins:RemoveMinimapIcon(addon, pin)
    HBDPins:RemoveWorldMapIcon(addon, pin)
    if _G.GameTooltip:IsOwned(pin) then _G.GameTooltip:Hide() end
    pin:Hide()
    pin:ClearAllPoints()
    pin.title, pin.waypoint = nil, nil
    pinPool[#pinPool + 1] = pin
end

function addon:RemoveWaypoint(waypoint)
    if not waypoint or not activeWaypoints[waypoint] then return end
    if waypoint.tomtom_uid then
        waypoint.backend:RemoveWaypoint(waypoint.tomtom_uid)
    elseif waypoint.pin then
        ReleasePin(waypoint.pin)
    end
    activeWaypoints[waypoint] = nil
    waypointIndex[waypoint.key] = nil
end

-- An automatic refresh releases only automatic ownership. Explicit Clear
-- still removes every Ackis waypoint, including a manually selected source.
local function ClearAutomaticWaypoints()
    for waypoint in pairs(activeWaypoints) do
        waypoint.automatic = nil
        if not waypoint.manual then addon:RemoveWaypoint(waypoint) end
    end
end

function addon:ClearAutomaticWaypoints()
    ClearAutomaticWaypoints()
end

function addon:ClearWaypoints()
    for waypoint in pairs(activeWaypoints) do self:RemoveWaypoint(waypoint) end
end

function addon:SetWaypoint(mapID, x, y, title, automatic)
    if private.addonEnabled == false then return false end
    if not Finite(mapID) or mapID <= 0 or mapID % 1 ~= 0 or not ValidCoordinates(x, y) then return false end
    if not HBD:GetLocalizedMap(mapID) then return false end
    local wx, wy, instance = HBD:GetWorldCoordinatesFromZone(x, y, mapID)
    if not Finite(wx) or not Finite(wy) or not Finite(instance) then return false end
    local profile = self.db and self.db.profile
    if not profile or (not profile.minimap and not profile.worldmap) then return false end
    title = title or ""
    if type(title) ~= "string" then return false end
    local key = string.format("%d:%.17g:%.17g:%s", mapID, x, y, title)
    local existing = waypointIndex[key]
    if existing and existing.backend and not existing.backend:IsValidWaypoint(existing.tomtom_uid) then
        activeWaypoints[existing], waypointIndex[key] = nil, nil
        existing = nil
    end
    if existing then
        if automatic then existing.automatic = true else existing.manual = true end
        return true
    end
    local waypoint = {key = key, mapID = mapID, x = x, y = y, title = title,
        automatic = automatic or nil, manual = not automatic or nil}
    local TomTom = _G.TomTom
    if TomTom then
        local uid = TomTom:AddWaypoint(mapID, x, y, {
            title = title, persistent = false,
            minimap = profile.minimap, world = profile.worldmap,
        })
        if uid then waypoint.tomtom_uid, waypoint.backend = uid, TomTom end
    end
    if not waypoint.tomtom_uid then
        local pin = AcquirePin(title)
        local minimapAdded, worldAdded = false, false
        if profile.minimap then minimapAdded = HBDPins:AddMinimapIconMap(addon, pin, mapID, x, y, true, true) end
        if profile.worldmap then worldAdded = HBDPins:AddWorldMapIconMap(addon, pin, mapID, x, y) end
        if not minimapAdded and not worldAdded then
            ReleasePin(pin)
            return false
        end
        waypoint.pin, pin.waypoint = pin, waypoint
    end
    activeWaypoints[waypoint], waypointIndex[key] = true, waypoint
    return true
end

-- Keep manually selected destinations while applying the new profile's visibility.
function addon:RefreshWaypointPreferences()
    local manual = {}
    for waypoint in pairs(activeWaypoints) do
        if waypoint.manual then manual[#manual + 1] = waypoint end
    end
    self:ClearWaypoints()
    local profile = self.db.profile
    for _, waypoint in ipairs(manual) do
        if private.addonEnabled ~= false and not profile.minimap and not profile.worldmap then
            -- Keep manual destinations dormant while both map displays are off.
            waypoint.tomtom_uid, waypoint.backend, waypoint.pin, waypoint.automatic = nil, nil, nil, nil
            activeWaypoints[waypoint], waypointIndex[waypoint.key] = true, waypoint
        else
            self:SetWaypoint(waypoint.mapID, waypoint.x, waypoint.y, waypoint.title)
        end
    end
    self:AutoScanZoneWaypoints()
end

-- Acquisition metadata belongs to this collection, never the shared NPC.
local function CollectRecipeWaypoints(records, recipe, targetAcquireType, location, npcID)
    if not recipe then return end
    local function AddSource(acquireType, sourceID)
        if npcID and sourceID ~= npcID then return end
        local entity = acquireType:GetWaypointEntity(sourceID, recipe)
        if not entity or (location and entity.Location ~= location) then return end
        if not entity.Location then return end
        local previous = records[entity]
        if not previous or recipe:SpellID() < previous.recipe:SpellID() then
            records[entity] = {entity = entity, recipe = recipe, acquireType = acquireType, sourceID = sourceID}
        end
    end
    for acquireType, acquireData in recipe:AcquirePairs() do
        if not targetAcquireType or acquireType == targetAcquireType then
            for sourceID, sourceData in pairs(acquireData) do
                if acquireType == private.AcquireTypes.Reputation then
                    for _, vendors in pairs(sourceData) do
                        for vendorID in pairs(vendors) do AddSource(acquireType, vendorID) end
                    end
                else
                    AddSource(acquireType, sourceID)
                end
            end
        end
    end
end

local function ColorHex(hex)
    if not hex then return "ffffff" end
    return #hex == 8 and hex:sub(3) or hex
end

local function SourceTitle(record)
    local entity, recipe, acquireType = record.entity, record.recipe, record.acquireType
    local entityName = entity.name
        or (acquireType == private.AcquireTypes.Quest and private.quest_names[record.sourceID]) or UNKNOWN
    local ok, _, _, _, qualityHex = pcall(private.GetItemQualityColor, recipe:QualityID())
    local acquireHex = ColorHex(acquireType:ColorData().hex)
    return string.format("%s: %s %s\n%s",
        HEX_FORMAT:format(acquireHex, acquireType:Name()), HEX_FORMAT:format(acquireHex, entityName),
        PARENS_TEMPLATE:format(HEX_FORMAT:format(ColorHex(ok and qualityHex or nil), recipe:LocalizedName())),
        entity.Location:LocalizedName())
end

local function SourcePosition(entity)
    local location, x, y = entity.Location, entity.coord_x, entity.coord_y
    local entranceX, entranceY = location:EntranceCoordinates()
    if Finite(entranceX) and Finite(entranceY) and entranceX > 0 and entranceY > 0 then
        location, x, y = location:Parent(), entranceX, entranceY
    end
    -- Source databases use 0/0 for an unknown position.
    if not Finite(x) or not Finite(y) or x <= 0 or y <= 0 then return nil end
    return ResolveMapID(location), x / 100, y / 100
end

local function PlaceSources(records, automatic)
    local count = 0
    for _, record in pairs(records) do
        local mapID, x, y = SourcePosition(record.entity)
        local title = SourceTitle(record)
        if addon:SetWaypoint(mapID, x, y, title, automatic) then
            count = count + 1
        elseif not automatic then
            addon:Print(title)
        end
    end
    return count
end

function addon:AddWaypoint(recipe, targetAcquireType, location, npcID)
    local records = {}
    if recipe then
        CollectRecipeWaypoints(records, recipe, targetAcquireType, location, npcID)
    elseif self.db.profile.autoscanmap then
        for _, candidate in pairs(private.recipe_list or {}) do
            if candidate:IsVisible() then CollectRecipeWaypoints(records, candidate) end
        end
    end
    if recipe and private.TrackRecipeSources then private.TrackRecipeSources(records, SourcePosition) end
    if not self.db.profile.minimap and not self.db.profile.worldmap then return end
    PlaceSources(records, false)
end

function addon:AutoScanZoneWaypoints()
    if private.addonEnabled == false then return end
    local profile = self.db and self.db.profile
    if not profile or not profile.autoscanmap or (not profile.minimap and not profile.worldmap) then return end
    if not private.recipe_list or not next(private.recipe_list) then return end
    local now = _G.GetTime()
    if now - lastAutoScanTime < AUTO_SCAN_THROTTLE then
        QueueAutoScan(AUTO_SCAN_THROTTLE - (now - lastAutoScanTime))
        return
    end
    lastAutoScanTime = now
    local mapID = HBD:GetPlayerZone()
    local zoneLocation = mapID and private.LocationsByMapID[mapID]
    local zoneName = mapID and HBD:GetLocalizedMap(mapID)
    zoneLocation = zoneLocation or (zoneName and private.LocationsByLocalizedName[zoneName])
    ClearAutomaticWaypoints()
    if not zoneLocation then return end
    local records = {}
    for _, recipe in pairs(private.recipe_list) do
        if recipe:IsVisible() then CollectRecipeWaypoints(records, recipe, nil, zoneLocation) end
    end
    local count = PlaceSources(records, true)
    if count > 0 then addon:Print(L["Auto-scanned %d waypoints for %s"]:format(count, zoneName or zoneLocation:LocalizedName())) end
end

-- Coalesce events into one pending scan; throttled work is deferred, not lost.
local scanPending, scanDeadline = false, 0
local function RunScheduledScan()
    local remaining = scanDeadline - _G.GetTime()
    if remaining > 0 then
        _G.C_Timer.After(remaining, RunScheduledScan)
        return
    end
    scanPending = false
    addon:AutoScanZoneWaypoints()
end
QueueAutoScan = function(delay)
    if private.addonEnabled == false then return end
    local profile = addon.db and addon.db.profile
    if not profile or not profile.autoscanmap then return end
    scanDeadline = math.max(_G.GetTime() + (delay or 0.2), lastAutoScanTime + AUTO_SCAN_THROTTLE)
    if not scanPending then
        scanPending = true
        _G.C_Timer.After(math.max(0, scanDeadline - _G.GetTime()), RunScheduledScan)
    end
end

-- HBD also reports corrected/delayed map changes and microdungeon transitions.
HBD.RegisterCallback(addon, "PlayerZoneChanged", function() QueueAutoScan() end)
local autoScanFrame = _G.CreateFrame("Frame")
autoScanFrame:RegisterEvent("ZONE_CHANGED")
autoScanFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
autoScanFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
autoScanFrame:SetScript("OnEvent", function(_, event)
    QueueAutoScan(event == "PLAYER_ENTERING_WORLD" and 1 or 0.2)
end)

-- Saved recipe destinations in Forever's Map & Quest Log.
do
    local pins = HBDPins
    local pinOwner = {}
    local pinFrames, rows, zoneLabels = {}, {}, {}
    local section, hooked, collapsed
    local pinsActive, refreshPending, hidePending = false, false, false
    local events = _G.CreateFrame("Frame")
    local Refresh
    local SCROLL_ICON = [[Interface\Buttons\UI-GuildButton-PublicNote-Up]]

    local function CanRefreshTracking()
        if _G.InCombatLockdown() then return false end
        local secrets = _G.C_Secrets
        return not (secrets and secrets.ShouldUnitAurasBeSecret and secrets.ShouldUnitAurasBeSecret("player"))
    end

    local function RefreshNativeQuestLog()
        if hooked and CanRefreshTracking() then
            _G.securecallfunction(_G.QuestLogQuests_Update)
        end
    end

    local function Destinations()
        if not addon.db or not addon.db.char then return nil end
        addon.db.char.recipeDestinations = addon.db.char.recipeDestinations or {}
        return addon.db.char.recipeDestinations
    end

    local function ShowDestination(destination)
        if CanRefreshTracking() then _G.securecallfunction(_G.OpenQuestLog, destination.mapID) end
    end

    local function RemoveDestination(key)
        local destinations = Destinations()
        if destinations then destinations[key] = nil end
        Refresh()
    end

    local function ShowDestinationTooltip(owner, destination)
        local tip = _G.GameTooltip
        tip:SetOwner(owner, "ANCHOR_RIGHT")
        tip:SetText(destination.recipeName, 1, .82, 0)
        tip:AddLine(destination.sourceName, 1, 1, 1)
        tip:AddLine(("%s (%.1f, %.1f)"):format(destination.zoneName, destination.x * 100, destination.y * 100), 1, 1, 1)
        tip:AddLine(_G.CLICK_TO_VIEW or "Click to view", .7, .7, .7)
        tip:AddLine(L["RECIPE_TRACKING_REMOVE"], .7, .7, .7)
        tip:Show()
    end

    local function DestinationClick(self, button)
        if button == "RightButton" then
            _G.GameTooltip:Hide()
            RemoveDestination(self.destination.key)
        else
            ShowDestination(self.destination)
        end
    end

    local function ClearPins()
        if not pinsActive then return end
        pins:RemoveAllWorldMapIcons(pinOwner)
        for _, pin in ipairs(pinFrames) do pin:Hide() end
        pinsActive = false
    end

    local function RefreshPins(destinations)
        ClearPins()
        for index, destination in ipairs(destinations) do
            local pin = pinFrames[index]
            if not pin then
                pin = _G.CreateFrame("Button", nil, _G.UIParent)
                pin:SetSize(22, 22)
                pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                local icon = pin:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexture(SCROLL_ICON)
                pin:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")
                pin:SetScript("OnClick", DestinationClick)
                pin:SetScript("OnEnter", function(self) ShowDestinationTooltip(self, self.destination) end)
                pin:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
                pinFrames[index] = pin
            end
            pin.destination = destination
            pins:AddWorldMapIconMap(pinOwner, pin, destination.mapID, destination.x, destination.y)
            pinsActive = true
        end
    end

    local function EnsureSection()
        local contents = _G.QuestScrollFrame and _G.QuestScrollFrame.Contents
        if not contents then return end
        if not section then
            section = _G.CreateFrame("Frame", "ARL_RecipeQuestLogSection", contents)
            -- Own one layout element; do not consume Blizzard's pooled quest rows.
            section.layoutIndex = 100000
            section.topPadding = 10
            section:SetWidth(contents:GetWidth())
            section.header = _G.CreateFrame("Button", nil, section, "ListHeaderVisualTemplate, ListHeaderCodeTemplate")
            section.header:RegisterForClicks("LeftButtonUp")
            section.header:SetPoint("TOPLEFT", 9, 0)
            -- Match QuestLogHeaderTemplate instead of stretching to the section width.
            section.header:SetSize(289, 22)
            section.header:SetHeaderText("ARLC · " .. L["RECIPE_TRACKING_HEADER"])
            section.header:SetClickHandler(function(_, button)
                if button ~= "LeftButton" then return end
                collapsed = not collapsed
                Refresh()
            end)
            -- The native collapse button propagates its click to this header.
        end
        return contents
    end

    local function Render(destinations)
        -- A post-hook stays installed once used. Empty/disabled/unsafe calls
        -- must return before reading or modifying the native quest layout.
        if #destinations == 0 or private.addonEnabled == false then
            if section and section:IsShown() then section:Hide() end
            return
        end
        if not CanRefreshTracking() then
            refreshPending = true
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        local contents = EnsureSection()
        if not contents then return end
        for _, row in ipairs(rows) do row:Hide() end
        for _, label in ipairs(zoneLabels) do label:Hide() end
        section:SetShown(#destinations > 0 and private.addonEnabled ~= false)
        _G.QuestScrollFrame.EmptyText:Hide()
        _G.QuestScrollFrame.NoSearchResultsText:Hide()
        _G.QuestScrollFrame.Background:SetAtlas("QuestLog-main-background", true)
        _G.securecallfunction(_G.QuestScrollFrame.ResizeBackground, _G.QuestScrollFrame)
        _G.ListHeaderMixin.UpdateCollapsedState(section.header, not not collapsed)
        local offset, zoneIndex, rowIndex, lastMap = 26, 0, 0
        local search = _G.QuestScrollFrame.SearchBox and _G.QuestScrollFrame.SearchBox:GetText() or ""
        search = search:lower()
        if not collapsed then
            for _, destination in ipairs(destinations) do
                local matches = search == "" or (destination.recipeName .. " " .. destination.sourceName .. " " .. destination.zoneName):lower():find(search, 1, true)
                if matches then
                    if destination.mapID ~= lastMap then
                        zoneIndex = zoneIndex + 1
                        local label = zoneLabels[zoneIndex]
                        if not label then
                            label = section:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
                            zoneLabels[zoneIndex] = label
                        end
                        label:ClearAllPoints()
                        label:SetPoint("TOPLEFT", 17, -offset)
                        label:SetText(destination.zoneName)
                        label:Show()
                        offset = offset + label:GetStringHeight() + 8
                        lastMap = destination.mapID
                    end
                    rowIndex = rowIndex + 1
                    local row = rows[rowIndex]
                    if not row then
                        row = _G.CreateFrame("Button", nil, section)
                        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        row.icon = row:CreateTexture(nil, "ARTWORK")
                        row.icon:SetSize(16, 16)
                        row.icon:SetPoint("TOPLEFT", 0, -2)
                        row.icon:SetTexture(SCROLL_ICON)
                        row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
                        row.title:SetPoint("TOPLEFT", 22, 0)
                        row.title:SetPoint("TOPRIGHT", -3, 0)
                        row.title:SetJustifyH("LEFT")
                        row.description = row:CreateFontString(nil, "ARTWORK", "ObjectiveFont")
                        row.description:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
                        row.description:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -3)
                        row.description:SetJustifyH("LEFT")
                        row:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")
                        row:SetScript("OnClick", DestinationClick)
                        row:SetScript("OnEnter", function(self) ShowDestinationTooltip(self, self.destination) end)
                        row:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
                        rows[rowIndex] = row
                    end
                    row.destination = destination
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 17, -offset)
                    row:SetPoint("TOPRIGHT", -6, -offset)
                    row.title:SetText(destination.recipeName)
                    row.description:SetText(destination.sourceName)
                    local height = math.max(34, row.title:GetStringHeight() + row.description:GetStringHeight() + 10)
                    row:SetHeight(height)
                    row:Show()
                    offset = offset + height + 4
                end
            end
        end
        section:SetHeight(offset)
        _G.securecallfunction(contents.Layout, contents)
    end

    Refresh = function()
        local saved = Destinations()
        if not saved then return end
        if not next(saved) and not pinsActive and not (section and section:IsShown()) then return end
        if not CanRefreshTracking() then
            refreshPending = true
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        refreshPending = false
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local destinations = {}
        for key, destination in pairs(saved) do
            local known = _G.C_SpellBook and _G.C_SpellBook.IsSpellKnown(destination.spellID, _G.Enum.SpellBookSpellBank.Player)
            if known then
                saved[key] = nil
            else
                destinations[#destinations + 1] = destination
            end
        end
        table.sort(destinations, function(a, b)
            if a.zoneName ~= b.zoneName then return a.zoneName < b.zoneName end
            if a.mapID ~= b.mapID then return a.mapID < b.mapID end
            if a.recipeName ~= b.recipeName then return a.recipeName < b.recipeName end
            return a.key < b.key
        end)
        if private.addonEnabled == false then ClearPins(); return end
        if #destinations > 0 then RefreshPins(destinations) else ClearPins() end
        if #destinations > 0 and not hooked and _G.QuestLogQuests_Update and _G.QuestScrollFrame then
            _G.hooksecurefunc("QuestLogQuests_Update", function() Render(private.recipeTrackingDestinations or {}) end)
            -- The hook must read the latest saved destinations, not a captured snapshot.
            hooked = true
        end
        private.recipeTrackingDestinations = destinations
        if hooked then RefreshNativeQuestLog() else Render(destinations) end
    end

    function private.TrackRecipeSources(records, position)
        local saved = Destinations()
        if not saved or private.addonEnabled == false then return end
        for _, record in pairs(records) do
            if record.acquireType == private.AcquireTypes.Vendor or record.acquireType == private.AcquireTypes.Trainer then
                local mapID, x, y = position(record.entity)
                if mapID and x and y and x > 0 and y > 0 and x <= 1 and y <= 1 then
                    local key = ("%d:%d:%d"):format(record.recipe:SpellID(), record.acquireType:ID(), record.sourceID)
                    local info = _G.C_Map.GetMapInfo(mapID)
                    saved[key] = {
                        key = key, spellID = record.recipe:SpellID(), mapID = mapID, x = x, y = y,
                        recipeName = record.recipe:LocalizedName(),
                        sourceName = record.acquireType:Name() .. ": " .. record.entity.name,
                        zoneName = info and info.name or record.entity.Location:LocalizedName(),
                    }
                end
            end
        end
        Refresh()
    end

    private.RefreshRecipeTracking = Refresh
    function private.HideRecipeTracking()
        if not CanRefreshTracking() then
            if section then section:Hide() end
            if pinsActive then
                hidePending = true
                events:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
            return
        end
        ClearPins()
        if section and section:IsShown() then
            section:Hide()
            RefreshNativeQuestLog()
        end
    end

    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("NEW_RECIPE_LEARNED")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_ENABLED" and CanRefreshTracking() and hidePending then
            hidePending = false
            ClearPins()
        end
        if private.addonEnabled == false then return end
        if event ~= "ADDON_LOADED" or name == "Blizzard_WorldMap" then Refresh() end
    end)
end
