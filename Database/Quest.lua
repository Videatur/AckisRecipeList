-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

-- ----------------------------------------------------------------------------
-- Imports
-- ----------------------------------------------------------------------------
local Z = private.ZONE_NAMES

-- ----------------------------------------------------------------------------
-- Memoizing table for quest names.
-- ----------------------------------------------------------------------------

local FALLBACK_QUEST_TITLES = {
    [2751] = "Barbaric Battlements", -- BS quest chain (Horde)
    [2752] = "On Iron Pauldrons", -- BS quest chain (Horde)
    [2753] = "Trampled Under Foot", -- BS quest chain (Horde)
    [2755] = "Joys of Omosh", -- BS quest chain (Horde)
    [1618] = "Gearing Redridge", -- BS quest (Alliance)
    [7604] = "A Binding Contract", -- Plans: Sulfuron Hammer
    [33022] = "Catch and Carry", -- Cooking: Noodle Cart progression
    [33024] = "Is That A Real Measurement?", -- Cooking: Noodle Cart progression
    [33027] = "The Secret Ingredient Is...", -- Cooking: Noodle Cart scenario
    [7493]  = "The Journey Has Just Begun", -- Leatherworking Black Dragonflight cloak (H)
    [31539] = "A Thing of Beauty", -- Inscription weekly (Scroll of Wisdom)
    [44952] = "Blackrock Depths: Jewel of the Depths", -- Legion BS quest
    [41160] = "Earth to Earth", -- Legion BS quest
    [44863] = "Clearing the Air", -- Legion BS quest
}

-- Only native, localized titles are memoized. Fallbacks remain provisional.
local pendingQuestNames = {}
local attempts = {}
local pendingCount = 0
local questDataFrame
local refreshQueued = false
local MAX_ATTEMPTS = 3
local RETRY_DELAY = 10

local function RefreshQuestNames()
    if refreshQueued then return end
    refreshQueued = true
    _G.C_Timer.After(0, function()
        refreshQueued = false
        -- Invalidate even while hidden, so reopening uses the new titles.
        if private.InvalidateSearchIndex then private.InvalidateSearchIndex() end
        local frame = addon.Frame
        if frame and frame:IsVisible() and frame.list_frame and private.CurrentProfession then
            local searchBox = frame.search_editbox
            if searchBox then searchBox:RefreshResults() end
            frame.list_frame:Update(nil, false)
        end
    end)
end

local function FinishRequest(id)
    if not pendingQuestNames[id] then return end
    pendingQuestNames[id] = nil
    pendingCount = pendingCount - 1
    if pendingCount == 0 then questDataFrame:UnregisterEvent("QUEST_DATA_LOAD_RESULT") end
end

local function StoreTitle(id, title)
    if not title or title == "" then return false end
    local changed = rawget(private.quest_names, id) ~= title
    rawset(private.quest_names, id, title)
    FinishRequest(id)
    attempts[id] = nil
    if changed then RefreshQuestNames() end
    return true
end

local function RequestQuestName(id)
    if pendingQuestNames[id] then return end
    local state = attempts[id]
    local now = _G.GetTime()
    if state and (state.count >= MAX_ATTEMPTS or now < state.retryAfter) then return end
    state = { count = state and state.count + 1 or 1, retryAfter = now + RETRY_DELAY }
    attempts[id] = state
    if not questDataFrame then
        questDataFrame = _G.CreateFrame("Frame")
        questDataFrame:SetScript("OnEvent", function(_, _, questID, success)
            if not pendingQuestNames[questID] then return end
            FinishRequest(questID)
            if success then StoreTitle(questID, _G.C_QuestLog.GetTitleForQuestID(questID)) end
        end)
    end
    pendingQuestNames[id] = state
    pendingCount = pendingCount + 1
    questDataFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    _G.C_QuestLog.RequestLoadQuestByID(id)
    if pendingQuestNames[id] == state then
        _G.C_Timer.After(RETRY_DELAY, function()
            if pendingQuestNames[id] == state then FinishRequest(id) end
        end)
    end
end

private.quest_names = _G.setmetatable({}, {
    __index = function(names, id)
        if type(id) == "number" and id > 0 and id % 1 == 0 then
            local title = _G.C_QuestLog.GetTitleForQuestID(id)
            if title and title ~= "" then
                if attempts[id] then StoreTitle(id, title)
                else rawset(names, id, title) end
                return title
            end
            RequestQuestName(id)
            -- The native request may complete synchronously.
            return rawget(names, id) or FALLBACK_QUEST_TITLES[id] or
                ("%s %s"):format(L["Quest"] or "Quest", tostring(id))
        end
        return ("%s %s"):format(L["Quest"] or "Quest", tostring(id))
    end,
})

function addon:InitQuest()
    local function AddQuest(questID, zoneName, coordX, coordY, faction)
        private.AcquireTypes.Quest:AddEntity(addon, {
            coord_x = coordX,
            coord_y = coordY,
            faction = faction,
            identifier = questID,
            item_list = {},
            locationName = zoneName,
            name = nil, -- Handled by memoizing table above.
        })
    end

    AddQuest(8323,	Z.SILITHUS,			67.1,	69.7,	"Neutral") -- Blacksmithing, Tailoring
    AddQuest(43943,	Z.SURAMAR,			36.5,	46.8,	"Neutral") -- Jewelcrafting, Leatherworking

    self.InitQuest = nil
end
