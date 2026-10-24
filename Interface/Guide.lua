-- Shared profession-guide UI. Guide data belongs to each profession module.

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local _, private = ...
local addon = _G.LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = _G.LibStub("AceLocale-3.0"):GetLocale(private.addon_name)
local HBD = _G.LibStub("HereBeDragons-2.0")

-- ----------------------------------------------------------------------------
-- Guide selection and saved progress.
-- ----------------------------------------------------------------------------
-- Guide occupies the first tab. Shift profiles saved before it was introduced
-- once, preserving the user's previous recipe-tab selection.
function private.MigrateGuideTabProfile(profile)
    if rawget(profile, "guide_tab_version") == 1 then return end
    local saved = rawget(profile, "current_tab")
    profile.current_tab = type(saved) == "number" and saved >= 1 and saved <= 3 and saved + 1 or 4
    profile.guide_tab_version = 1
end

-- Modules expose either one Guide or an ordered collection of Guides. Resolve
-- the character's selection before choosing any faction-specific route.
function private.GetProfessionGuide(profession)
    local module = profession and profession:Module()
    if not module then return end
    local guide = module.Guide
    if not module.Guides then return guide end
    if module.Guides then
        local choices = addon.db.char.guideSelections or {}
        local key = choices[module:GetName()] or module.GuideOrder[1]
        local choice = module.Guides[key] or module.Guides[module.GuideOrder[1]]
        if choice.factions then guide = choice.factions[private.Player.faction] else guide = choice end
    end
    if not guide then return end
    -- Keep faction-restricted recipe choices out of both detail windows and
    -- shopping totals. The original module data remains available unchanged.
    guide._factionViews = guide._factionViews or {}
    local faction = private.Player.faction
    if not guide._factionViews[faction] then
        -- Copy the chapter/step containers before filtering variants. Shared
        -- metadata stays read-only, and each faction gets its own cached view.
        local view = {}
        for k,v in pairs(guide) do view[k] = v end
        view.chapters = {}
        for _,chapter in ipairs(guide.chapters) do
            local copy = {}; for k,v in pairs(chapter) do copy[k] = v end
            copy.steps = {}
            for _,step in ipairs(chapter.steps) do
                local filtered = {}; for k,v in pairs(step) do filtered[k] = v end
                filtered.variants = {}
                for _,variant in ipairs(step.variants) do
                    if not variant.faction or variant.faction == faction then filtered.variants[#filtered.variants+1] = variant end
                end
                if #filtered.variants > 0 then copy.steps[#copy.steps+1] = filtered end
            end
            view.chapters[#view.chapters+1] = copy
        end
        guide._factionViews[faction] = view
    end
    return guide._factionViews[faction]
end

-- Persist completion by character, guide ID and step ID. Separate route IDs
-- prevent one guide's checkbox state from completing another route.
local function CompletedSteps(guide)
    local progress = addon.db.char.guideProgress
    if not progress then progress = {}; addon.db.char.guideProgress = progress end
    if not progress[guide.id] then progress[guide.id] = {} end
    return progress[guide.id]
end

-- Progress counts the active guide's steps, including collapsed chapters;
-- search results and recipe filters do not change the completion percentage.
function private.GuideProgress(profession)
    local guide = private.GetProfessionGuide(profession)
    if not guide then return 0, 0 end
    local completed, total, saved = 0, 0, CompletedSteps(guide)
    for _, chapter in ipairs(guide.chapters) do
        for _, step in ipairs(chapter.steps) do
            total = total + 1
            if saved[step.id] then completed = completed + 1 end
        end
    end
    return completed, total
end

function private.NextGuideStep(profession)
    local guide = private.GetProfessionGuide(profession)
    if not guide then return end
    local saved = CompletedSteps(guide)
    for _, chapter in ipairs(guide.chapters) do
        for _, step in ipairs(chapter.steps) do
            if not saved[step.id] then return step end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Main panel presentation.
-- ----------------------------------------------------------------------------
-- Called for recipe tabs as well as Guide so their original controls are
-- restored when leaving the guide-specific layout.
function private.UpdateGuidePresentation(panel)
    local tab = panel.tabs and panel.tabs[addon.db.profile.current_tab]
    local isGuide = tab and tab.kind == "guide" or false
    -- Reserve the space beside Guide search for its guide-selection menu.
    if panel.search_editbox then panel.search_editbox:SetWidth(isGuide and 130 or 230) end
    if panel.exclude_toggle then panel.exclude_toggle:SetShown(not isGuide) end
    if panel.filter_toggle then panel.filter_toggle:SetShown(not isGuide) end
    for _, control in ipairs(panel.recipe_sort_controls or {}) do control:SetShown(not isGuide) end
    if panel.list_frame and panel.list_frame.SetGuideLayout then panel.list_frame:SetGuideLayout(isGuide) end
    local module = private.CurrentProfession and private.CurrentProfession:Module()
    if module and module.Guides and not panel.guide_selector then
        local selector = _G.CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
        selector:SetSize(162, 22)
        selector:SetPoint("LEFT", panel.search_editbox, "RIGHT", 8, 0)
        -- Center the label within the space before the arrow, with enough
        -- padding on both sides and a small baseline correction for this row.
        selector.Text:ClearAllPoints()
        selector.Text:SetPoint("LEFT", selector, "LEFT", 10, 1)
        selector.Text:SetPoint("RIGHT", selector, "RIGHT", -28, 1)
        selector.Text:SetHeight(16)
        selector.Text:SetJustifyH("CENTER")
        selector.Text:SetJustifyV("MIDDLE")
        selector.Text:SetWordWrap(false)
        selector:SetDefaultText(L["Guide"])
        selector:SetupMenu(function(_, root)
            -- The selector is reused across professions. Resolve its module
            -- when opening the menu instead of retaining the creation-time one.
            local currentModule = private.CurrentProfession and private.CurrentProfession:Module()
            if not currentModule or not currentModule.Guides then return end
            root:CreateTitle(L["Select guide"])
            local function IsSelected(key)
                local choices = addon.db.char.guideSelections or {}
                local selected = choices[currentModule:GetName()] or currentModule.GuideOrder[1]
                if not currentModule.Guides[selected] then selected = currentModule.GuideOrder[1] end
                return key == selected
            end
            local function SelectGuide(key)
                if not private.CurrentProfession or private.CurrentProfession:Module() ~= currentModule or IsSelected(key) then return end
                addon.db.char.guideSelections = addon.db.char.guideSelections or {}
                addon.db.char.guideSelections[currentModule:GetName()] = key
                -- A detail window belongs to its previous guide. Close it
                -- before rebuilding the main list for the new selection.
                if _G.ARL_GuidePanel then _G.ARL_GuidePanel:Hide() end
                panel.list_frame:Update(nil, false)
            end
            for _,key in ipairs(currentModule.GuideOrder) do
                root:CreateRadio(currentModule.Guides[key].menuTitle or currentModule.Guides[key].title or key, IsSelected, SelectGuide, key)
            end
        end)
        panel.guide_selector = selector
    end
    if panel.guide_selector then
        panel.guide_selector:SetShown(isGuide and module and module.Guides ~= nil)
        if module and module.Guides then
            local guide = private.GetProfessionGuide(private.CurrentProfession)
            panel.guide_selector:OverrideText(guide and (guide.label or guide.title) or L["Guide"])
            private.SetTooltipScripts(panel.guide_selector,
                (L["Current guide: %s\nOpen the menu to select a guide."]):format(guide and (guide.menuTitle or guide.title) or L["None"]), 1)
        end
    end
    if not panel.guide_next_hint and panel.sort_button then
        panel.guide_next_hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel.guide_next_hint:SetPoint("LEFT", panel.sort_button, "LEFT", 2, 0)
        panel.guide_next_hint:SetWidth(250)
        panel.guide_next_hint:SetJustifyH("LEFT")
        panel.guide_next_hint:SetWordWrap(false)
    end
    if panel.guide_next_hint then
        local nextStep = isGuide and private.NextGuideStep(private.CurrentProfession)
        local hint = nextStep and (L["Next: "] .. (nextStep.label or nextStep.id)) or L["Guide complete"]
        if module and module.Guides then
            local guide = private.GetProfessionGuide(private.CurrentProfession)
            if guide then hint = (guide.label or guide.title) .. " | " .. hint end
        end
        panel.guide_next_hint:SetText(hint)
        panel.guide_next_hint:SetShown(isGuide)
    end
end

-- ----------------------------------------------------------------------------
-- Guide list and search.
-- ----------------------------------------------------------------------------
local function SpellName(spellID)
    return private.GetSpellName(spellID) or (L["Spell #%d"]):format(spellID)
end

local function SearchText()
    local text = addon.Frame.search_editbox:GetText() or ""
    return text ~= _G.SEARCH and text:lower() or ""
end

local function MatchesStep(chapter, step, search)
    if search == "" then return true end
    local text = ("%s %s %s %s"):format(chapter.title, chapter.id, step.id, step.note or ""):lower()
    if text:find(search, 1, true) then return true end
    -- Search every available variant, using module names when item data has
    -- not reached the client cache yet.
    local guide = private.GetProfessionGuide(private.CurrentProfession)
    for _, variant in ipairs(step.variants) do
        if (variant.title or (variant.spellID and SpellName(variant.spellID)) or step.title or ""):lower():find(search, 1, true) then return true end
        for _, material in ipairs(variant.materials) do
            local name = private.GetItemInfo(material[1]) or guide.materialNames[material[1]] or ""
            if name:lower():find(search, 1, true) then return true end
        end
    end
    return false
end

function private.PopulateGuideTab(tab, expandMode)
    local guide = private.GetProfessionGuide(private.CurrentProfession)
    local list = addon.Frame.list_frame
    local state = tab:GetProfessionExpansionState(private.CurrentProfession)
    local search = SearchText()
    local index, count = 1, 0
    if not guide then
        local entry = private.CreateListEntry("title")
        entry:SetText(L["No guide available for this profession yet."])
        list:InsertEntry(entry, index)
        return 0
    end
    if search == "" or L["Shopping list materials"]:lower():find(search, 1, true) then
        local shopping = private.CreateListEntry("header")
        shopping.guideShopping = true
        shopping:SetText(L["Shopping List (%d-%d)"], guide.minSkill, guide.maxSkill)
        index = list:InsertEntry(shopping, index)
    end
    for _, chapter in ipairs(guide.chapters) do
        local matches, completed = 0, 0
        for _, step in ipairs(chapter.steps) do
            if MatchesStep(chapter, step, search) then matches = matches + 1 end
            if CompletedSteps(guide)[step.id] then completed = completed + 1 end
        end
        if matches > 0 then
            local entry = private.CreateListEntry("header")
            entry.guideChapter = chapter
            entry.guideChapterProgress = ("%d/%d"):format(completed, #chapter.steps)
            entry:SetText("%d-%d: %s", chapter.from, chapter.to, chapter.title)
            -- Prefix guide expansion keys to avoid recipe-category collisions.
            -- Searches reveal matching steps without saving that expansion.
            local expanded = state["guide:" .. chapter.id] or expandMode or search ~= ""
            index = list:InsertEntry(entry, index, expanded, expanded)
            count = count + matches
        end
    end
    if index == 1 then
        local entry = private.CreateListEntry("title")
        entry:SetText(L["No guide steps match your search."])
        list:InsertEntry(entry, index)
    end
    return count
end

function private.ExpandGuideEntry(tab, entry)
    local index = (entry.button and entry.button.entry_index or entry.index) + 1
    if not entry.guideChapter or entry.guideStep then return index end
    tab:SaveListEntryState(entry, true)
    local guide = private.GetProfessionGuide(private.CurrentProfession)
    local nextStep = private.NextGuideStep(private.CurrentProfession)
    for _, step in ipairs(entry.guideChapter.steps) do
        if MatchesStep(entry.guideChapter, step, SearchText()) then
            local child = private.CreateListEntry("entry", entry)
            child.guideChapter, child.guideStep = entry.guideChapter, step
            -- List.lua reads these fields for completion and next-step markers.
            child.guideDone = CompletedSteps(guide)[step.id] == true
            child.guideNext = step == nextStep
            child:SetText("|cffffd100%s|r  |cffffffff%s|r", step.label or step.id,
                step.title or step.variants[1].title or SpellName(step.variants[1].spellID))
            index = addon.Frame.list_frame:InsertEntry(child, index)
        end
    end
    return index
end

function private.ShowGuideEntryTooltip(entry)
    local tip = _G.GameTooltip
    if not entry.button then return end
    tip:SetOwner(entry.button, "ANCHOR_RIGHT")
    tip:SetText(entry.guideShopping and L["Shopping List"] or entry:Text())
    if entry.guideDone then tip:AddLine(L["Completed"], .3, 1, .3)
    elseif entry.guideNext then tip:AddLine(L["Next step"], 1, .82, 0) end
    tip:AddLine(entry.guideStep and L["Click to open this step."] or
        (entry.guideShopping and L["Click to view materials for the selected route."] or L["Click to expand the leveling steps."]), 1, 1, 1, true)
    tip:Show()
end

-- ----------------------------------------------------------------------------
-- NPC locations and acquisition.
-- ----------------------------------------------------------------------------
-- Older location records may need their localized name matched to an HBD map.
local function MapID(location)
    if not location then return nil end
    local mapID = location:MapID()
    if mapID and HBD:GetLocalizedMap(mapID) then return mapID end
    local name = location:LocalizedName()
    for _, candidate in ipairs(HBD:GetAllMapIDs()) do
        if HBD:GetLocalizedMap(candidate) == name then return candidate end
    end
end

-- Select from an explicitly supplied inventory/rank list, never all vendors.
-- Faction accessibility takes priority over the recipe visibility filters.
local function RankEntities(entities)
    local playerMap = HBD:GetPlayerZone()
    local px, py = HBD:GetPlayerZonePosition()
    for _, candidate in ipairs(entities) do
        local map, entity = candidate.mapID, candidate.entity
        local distance
        if playerMap and map and px and py and entity.coord_x and entity.coord_y
            and entity.coord_x > 0 and entity.coord_y > 0 then
            distance = HBD:GetZoneDistance(playerMap, px, py, map, entity.coord_x / 100, entity.coord_y / 100)
        end
        candidate.localZone = playerMap ~= nil and map == playerMap
        -- Keep unknown distances after known ones; names and IDs provide a
        -- stable fallback order when HBD cannot compare the locations.
        candidate.distance = distance or math.huge
    end
    table.sort(entities, function(a, b)
        if a.localZone ~= b.localZone then return a.localZone end
        if a.distance ~= b.distance then return a.distance < b.distance end
        local an, bn = a.entity.name or "", b.entity.name or ""
        if an ~= bn then return an < bn end
        return tostring(a.id) < tostring(b.id)
    end)
    return entities
end

function private.GetGuideEntities(acquireType, ids, guide)
    local entities = {}
    local faction = private.Player.faction
    for _, id in ipairs(ids or {}) do
        local entity = acquireType:GetEntity(id)
        local location = guide and guide.locations and guide.locations[id]
        -- Reviewed guide locations can supplement or override native records
        -- without modifying the module's recipe-tab acquisition registry.
        if location then
            entity = {name=location.name, faction=location.faction, locationName=location.zone, coord_x=location.x, coord_y=location.y}
        end
        if entity and (not entity.faction or entity.faction == "Neutral" or entity.faction == faction) then
            entities[#entities + 1] = { entity = entity, id = id, mapID = location and location.mapID or MapID(entity.Location) }
        end
    end
    return RankEntities(entities)
end

-- Supplier suggestions require an explicit item in the recorded inventory,
-- rather than assuming every vendor of a profession sells that material.
function private.GetGuideSupplyEntities(guide, itemID)
    local entities = {}
    for _, vendor in ipairs(guide.supplies or {}) do
        if vendor.items[itemID] and (vendor.faction == private.Player.faction or vendor.faction == "Neutral") then
            entities[#entities + 1] = { id = vendor.id, mapID = vendor.mapID,
                entity = { name = vendor.name, locationName = vendor.zone, coord_x = vendor.x, coord_y = vendor.y } }
        end
    end
    return RankEntities(entities)
end

local function EntityText(candidate)
    local entity = candidate.entity
    local zone = entity.Location and entity.Location:LocalizedName() or entity.locationName or L["Unknown location"]
    local coordinates = entity.coord_x and entity.coord_y and entity.coord_x > 0 and entity.coord_y > 0
        and (" (%.1f, %.1f)"):format(entity.coord_x, entity.coord_y) or ""
    return ("%s - %s%s%s"):format(entity.name or (L["NPC #%d"]):format(candidate.id), zone, coordinates,
        candidate.localZone and L[" [current zone]"] or "")
end

local function RecipeFor(profession, variant)
    return variant.spellID and profession.Recipes[variant.spellID]
end

local function RecipeSources(profession, variant, acquireType, guide)
    local recipe = RecipeFor(profession, variant)
    local ids = {}
    -- Prefer recorded formula inventories. Guide-only recipes may also supply
    -- trainer IDs when the native recipe catalogue has no entry for the spell.
    if acquireType == private.AcquireTypes.Vendor then
        local itemID = variant.recipeItemID or (recipe and recipe:RecipeItem())
        local suppliers = itemID and private.GetGuideSupplyEntities(guide, itemID) or {}
        if #suppliers > 0 then return suppliers end
    end
    if not recipe and acquireType == private.AcquireTypes.Trainer then
        return private.GetGuideEntities(acquireType, variant.trainers or {}, guide)
    end
    for id in pairs(recipe and recipe:AcquireDataOfType(acquireType) or {}) do ids[#ids + 1] = id end
    return private.GetGuideEntities(acquireType, ids, guide)
end

-- ----------------------------------------------------------------------------
-- Material labels and acquisition tooltips.
-- ----------------------------------------------------------------------------
local function ItemText(guide, itemID)
    local name, _, _, _, _, _, _, _, _, icon = private.GetItemInfo(itemID)
    -- Keep parchment labels readable; clicks still use the real item hyperlink.
    return name or guide.materialNames[itemID] or (L["Item #%d"]):format(itemID), icon
end

local function AddGuideMaterialDivider(tip)
    tip:AddLine(" ")
    local spacer = _G[tip:GetName() .. "TextLeft" .. tip:NumLines()]
    if not spacer then return end
    local line = tip.ackisGuideDivider
    if not line then
        line = tip:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(.75, .6, .35, .65)
        line:SetRoundLayoutToNearestPixel(true)
        tip.ackisGuideDivider = line
        tip:HookScript("OnTooltipCleared", function() line:Hide() end)
    end
    line:ClearAllPoints()
    line:SetPoint("LEFT", tip, "LEFT", 10, 0)
    line:SetPoint("RIGHT", tip, "RIGHT", -10, 0)
    line:SetPoint("TOP", spacer, "TOP", 0, -4)
    line:SetHeight(_G.PixelUtil.GetPixelToUIUnitFactor() / tip:GetEffectiveScale())
    line:Show()
end

local function AddMaterialSources(tip, guide, itemID, required, forStep)
    local source = guide.materialSources[itemID]
    if not source and not required then return end
    AddGuideMaterialDivider(tip)
    if required then
        local owned = _G.C_Item.GetItemCount(itemID) or 0
        local available = owned >= required
        tip:AddDoubleLine(forStep and L["For this step:"] or L["For the selected route:"],
            ("%d / %d"):format(owned, required), 1, .82, 0,
            available and .2 or 1, available and 1 or .3, available and .2 or .3)
        tip:AddLine(available and L["Material available."] or (L["Still needed: %d"]):format(required - owned),
            available and .2 or 1, available and 1 or .3, available and .2 or .3)
        tip:AddLine(" ")
    end
    if not source then return end
    tip:AddLine(L["How to obtain"], 1, .82, 0)
    if source.kind == "supply" then
        tip:AddLine(L["Supplies vendors"], 1, 1, 1)
        local entities = private.GetGuideSupplyEntities(guide, itemID)
        for index = 1, math.min(3, #entities) do tip:AddLine(EntityText(entities[index]), 1, 1, 1, true) end
        tip:AddLine(L["Check stock at the vendor."], .7, .7, .7, true)
    elseif source.kind == "craft" then
        tip:AddLine((L["Craft: %s (step %s)"]):format(private.GetSpellName(source.spellID) or guide.materialNames[itemID] or SpellName(source.spellID), source.stepID), 1, 1, 1, true)
        if source.note then tip:AddLine(source.note, 1, 1, 1, true) end
    -- These sources have acquisition instructions, not guaranteed world nodes.
    elseif source.kind == "disenchant" or source.kind == "auction" then
        tip:AddLine(source.kind == "disenchant" and L["Disenchanting / Auction House"] or L["Other sources / Auction House"], 1, 1, 1)
        if source.note then tip:AddLine(source.note, 1, 1, 1, true) end
    else
        local labels = { mining = L["Mining / smelting"], skinning = L["Skinning"], drop = L["Loot / Auction House"], fish = L["Fishing"] }
        tip:AddLine(source.kind == "herb" and (L["Herbalism %d"]):format(source.skill) or labels[source.kind] or L["Gathering"], 1, 1, 1)
        if source.zones and #source.zones > 0 then
            tip:AddLine(L["Suggested areas"], 1, .82, 0)
            local currentZone = _G.GetRealZoneText()
            for _, zone in ipairs(source.zones) do
                tip:AddLine("  " .. zone .. (zone == currentZone and L[" [current zone]"] or ""), 1, 1, 1)
            end
        end
        if source.kind == "skinning" and itemID == 2318 then
            tip:AddLine(L["Skin beasts, or purchase at the Auction House."], 1, 1, 1, true)
        elseif source.note then
            tip:AddLine(source.note, 1, 1, 1, true)
        end
        if source.zones and #source.zones > 0 then
            tip:AddLine(L["Suggested areas are not yet confirmed in Forever."], .7, .7, .7, true)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Detail frame creation and events.
-- ----------------------------------------------------------------------------
-- One lazily created frame serves all professions. Callbacks below use the
-- forward-declared renderer once the remaining content helpers are defined.
local GuideFrame
local RenderGuide

-- Short labels belong to the route selector; recipe headings keep full names.
local ROUTE_LABELS = {
    ["Double-stitched Woolen Shoulders"] = L["Woolen shoulders"],
    ["Wool: Double-stitched Woolen Shoulders"] = L["Woolen shoulders"],
    ["Silk: bolts, then Woolen shoulders"] = L["Silk bolts + shoulders"],
    ["Heavy Blasting Powder + Whirring Bronze Gizmo"] = L["Powder + Bronze Gizmos"],
    ["Arathi Highlands - Iron and Gold"] = L["Arathi: Iron / Gold"],
    ["Ashenvale - Tin and Silver"] = L["Ashenvale: Tin / Silver"],
    ["Redridge Mountains - Copper"] = L["Redridge: Copper"],
    ["Redridge Mountains - Tin and Silver"] = L["Redridge: Tin / Silver"],
    ["The Barrens - Tin and Silver"] = L["Barrens: Tin / Silver"],
    ["Thousand Needles - Iron and Gold"] = L["Thousand Needles: Iron / Gold"],
    ["Eastern Plaguelands - Thorium"] = L["E. Plaguelands: Thorium"],
    ["The Hinterlands - Mithril"] = L["Hinterlands: Mithril"],
    ["Artisan training and Mithril"] = L["Artisan + Mithril"],
    ["Copper and Journeyman training"] = L["Copper + Journeyman"],
    ["Gather through the smelting gap"] = L["Gather ore"],
    ["Iron with occasional Gold"] = L["Iron / Gold"],
    ["Mithril; Truesilver at 230"] = L["Mithril / Truesilver"],
    ["Small and Rich Thorium Veins"] = L["Thorium veins"],
}
local function RouteLabel(variant, step)
    local title = variant.menuTitle or variant.title or (variant.spellID and SpellName(variant.spellID)) or step.title or L["Route"]
    local label = ROUTE_LABELS[title] or title:gsub("^Enchant 2H Weapon %- ", function() return L["2H: "] end):gsub("^Enchant (.-) %- ", function(slot) return L["%s: "]:format(slot) end):gsub("^Elixir of ", "")
    return label
end

-- ----------------------------------------------------------------------------
-- Follow a guide step or its shopping list in the native Objectives Tracker.
-- ----------------------------------------------------------------------------
-- Save a material snapshot so tracking survives reloads without loading every
-- profession module. The guide window supplies fresh data when routes change.
local FollowTracker
local followEvents = _G.CreateFrame("Frame", "ARL_GuideFollowEvents")
local function FollowedStep()
    return private.addonEnabled ~= false and addon.db and addon.db.char and addon.db.char.guideFollow
end

local function CanRefreshFollowTracker()
    if _G.InCombatLockdown() then return false end
    local secrets = _G.C_Secrets
    if secrets and secrets.ShouldUnitAurasBeSecret and secrets.ShouldUnitAurasBeSecret("player") then return false end
    return true
end

local FOLLOW_EVENTS = { "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }
local function SetFollowEvents(active)
    for _, event in ipairs(FOLLOW_EVENTS) do
        if active then followEvents:RegisterEvent(event)
        else followEvents:UnregisterEvent(event) end
    end
end

-- Keep Blizzard's module/block/line templates, but never return our frames to
-- the manager's shared pools where native quest/scenario modules can reuse them.
local function UsePrivateFollowPools(module)
    local freeFrames = {}
    local function Acquire(parent, template)
        local pool = freeFrames[template]
        local frame = pool and table.remove(pool)
        local isNew = frame == nil
        if isNew then
            local info = _G.C_XMLUtil.GetTemplateInfo(template)
            frame = _G.CreateFrame(info and info.type or "Frame", nil, parent, template)
            frame.template = template
        end
        frame:SetParent(parent)
        return frame, isNew
    end
    local function Release(frame)
        frame:Hide()
        frame:ClearAllPoints()
        local template = frame.template
        freeFrames[template] = freeFrames[template] or {}
        freeFrames[template][#freeFrames[template] + 1] = frame
    end
    local function FreeLine(block, line)
        block.usedLines[line.objectiveKey] = nil
        Release(line)
        if line.OnFree then line:OnFree(block) end
    end
    local function GetLine(block, objectiveKey, optTemplate)
        local template = optTemplate or module.lineTemplate
        local line = block.usedLines[objectiveKey]
        if line and line.template ~= template then FreeLine(block, line); line = nil end
        if not line then line = Acquire(block, template); line:Show() end
        block.usedLines[objectiveKey] = line
        line.objectiveKey, line.parentBlock, line.used = objectiveKey, block, true
        return line
    end
    function module:AcquireFrame(template)
        local frame, isNew = Acquire(self.ContentsFrame, template)
        if template == self.blockTemplate then
            frame.GetLine, frame.FreeLine = GetLine, FreeLine
        end
        return frame, isNew
    end
    function module:FreeBlock(block)
        self:RemoveBlockFromCache(block, true)
        block:Free()
        self.usedBlocks[block.template][block.id] = nil
        Release(block)
        self:OnFreeBlock(block)
    end
end

local function StopFollowTracker()
    if not FollowTracker or FollowTracker.arlStopped then SetFollowEvents(false); return true end
    if not CanRefreshFollowTracker() then
        SetFollowEvents(false)
        followEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        followEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        return
    end
    local manager = _G.ObjectiveTrackerManager
    local container = manager and manager:GetContainerForModule(FollowTracker)
    if container then
        _G.securecallfunction(container.RemoveModule, container, FollowTracker)
        manager.moduleToContainerMap[FollowTracker] = nil
    end
    FollowTracker.parentContainer = nil
    FollowTracker:Hide()
    FollowTracker:MarkBlocksUnused()
    FollowTracker:FreeUnusedBlocks()
    FollowTracker.arlStopped = true
    SetFollowEvents(false)
    return true
end

local function IsFollowed(frame)
    local saved = FollowedStep()
    return saved and saved.profession == frame.profession:Name() and saved.guideID == frame.guide.id
        and (frame.step and not saved.shopping and saved.stepID == frame.step.id
            or not frame.step and saved.shopping == true)
end

-- Native block highlighting expects a quest ID. Our material blocks have none.
local function SetFollowBlockHighlight(block, highlighted)
    block.isHighlighted = highlighted
    local colors = _G.OBJECTIVE_TRACKER_COLOR
    local header = colors[highlighted and "HeaderHighlight" or "Header"]
    block.HeaderText:SetTextColor(header.r, header.g, header.b)
    block.HeaderText.colorStyle = header
    for _, line in pairs(block.usedLines) do
        if line.used then
            local base = colors[line.Icon:IsShown() and "Complete" or "Normal"]
            local color = highlighted and base.reverse or base
            line.Text:SetTextColor(color.r, color.g, color.b)
            line.Text.colorStyle = color
            if line.Dash then
                local dash = colors[highlighted and "NormalHighlight" or "Normal"]
                line.Dash:SetTextColor(dash.r, dash.g, dash.b)
            end
        end
    end
end

local function OpenFollowedStep()
    local saved = FollowedStep()
    if not saved then return end
    local profession = private.Professions and private.Professions[saved.profession]
    if not profession then
        local names = private.MODULE_NAME_TO_LOCALIZED_PROFESSION_NAME_MAPPING
        if not names or not addon:InitializeProfession(names[saved.profession], true) then return end
        profession = private.Professions[saved.profession]
    end
    if saved.guideKey then
        addon.db.char.guideSelections = addon.db.char.guideSelections or {}
        addon.db.char.guideSelections[saved.profession] = saved.guideKey
    end
    local guide = private.GetProfessionGuide(profession)
    if not guide or guide.id ~= saved.guideID then return end
    if saved.shopping then
        private.OpenGuideStep(profession, nil, nil, saved.selections)
        return
    end
    for _, chapter in ipairs(guide.chapters) do
        for _, step in ipairs(chapter.steps) do
            if step.id == saved.stepID then
                private.OpenGuideStep(profession, chapter, step)
                local selected = step.variants[saved.variant] and saved.variant or 1
                GuideFrame.selections[guide.id][step.id] = selected
                local paired = guide.id == "forever-alchemy-1-225" and
                    (step.id == "130-150" and "150-165" or step.id == "150-165" and "130-150")
                if paired then GuideFrame.selections[guide.id][paired] = selected end
                RenderGuide()
                return
            end
        end
    end
end

local function EnsureFollowTracker()
    if not FollowedStep() then StopFollowTracker(); return end
    SetFollowEvents(true)
    if not CanRefreshFollowTracker() then return end
    local manager, container = _G.ObjectiveTrackerManager, _G.ObjectiveTrackerFrame
    if not manager or not container then
        if not FollowedStep() then return end
        _G.C_AddOns.LoadAddOn("Blizzard_ObjectiveTracker")
        manager, container = _G.ObjectiveTrackerManager, _G.ObjectiveTrackerFrame
    end
    if not manager or not container or not manager.containers[container] then return end
    if not FollowTracker then
        FollowTracker = _G.CreateFrame("Frame", "ARL_GuideObjectiveTracker", container, "ObjectiveTrackerModuleTemplate")
        FollowTracker:SetHeader(L["ARLC - Materials"])
        FollowTracker.lineTemplate = "ObjectiveTrackerAnimLineTemplate"
        FollowTracker.fromBlockOffsetY = 0
        UsePrivateFollowPools(FollowTracker)
        function FollowTracker:CanUpdate()
            return FollowedStep() ~= nil and CanRefreshFollowTracker()
        end
        -- Do not call the inherited module MarkDirty: it enters the shared
        -- container directly from addon execution. Dispatch the Blizzard
        -- scheduling method through its secure-call boundary instead.
        function FollowTracker:MarkDirty()
            if not FollowedStep() then StopFollowTracker(); return end
            if not CanRefreshFollowTracker() then return end
            self.isDirty = true
            if self.parentContainer then
                _G.securecallfunction(self.parentContainer.MarkDirty, self.parentContainer)
            end
        end
        -- Give the module its own order without changing Blizzard's module list.
        FollowTracker.uiOrder = 1000
        function FollowTracker:LayoutContents()
            local saved = FollowedStep()
            if not saved or not CanRefreshFollowTracker() then return end
            local block
            -- Small shopping blocks let the native tracker show as much as fits.
            local chunkSize = saved.shopping and 6 or math.max(1, #saved.materials)
            for index, material in ipairs(saved.materials) do
                if (index - 1) % chunkSize == 0 then
                    if block and not self:LayoutBlock(block) then return end
                    block = self:GetBlock(math.floor((index - 1) / chunkSize) + 1)
                    block:SetHeader(index == 1 and saved.title or "")
                    block.HeaderText:SetShown(index == 1)
                    block.HeaderButton:SetShown(index == 1)
                    if index > 1 then
                        -- Continuations have no header or extra gap between materials.
                        block.HeaderText:SetHeight(0)
                        block.height = 0
                    end
                end
                local owned = _G.C_Item.GetItemCount(material.id) or 0
                local complete = owned >= material.required
                local name = private.GetItemInfo(material.id) or material.name
                local text = ("%d/%d %s"):format(owned, material.required, name)
                local line = block:AddObjective(index, text, nil, nil,
                    complete and _G.OBJECTIVE_DASH_STYLE_HIDE or _G.OBJECTIVE_DASH_STYLE_SHOW,
                    _G.OBJECTIVE_TRACKER_COLOR[complete and "Complete" or "Normal"])
                line.Icon:SetShown(complete)
                if complete then line.Icon:SetAtlas("ui-questtracker-tracker-check", false) end
            end
            if block then self:LayoutBlock(block) end
        end
        function FollowTracker:OnBlockHeaderClick(_, button)
            if button == "RightButton" then
                addon.db.char.guideFollow = nil
                self:MarkDirty()
                if GuideFrame and GuideFrame:IsShown() then RenderGuide() end
            else
                OpenFollowedStep()
            end
        end
        function FollowTracker:OnBlockHeaderEnter(block)
            SetFollowBlockHighlight(block, true)
            _G.GameTooltip:SetOwner(block.HeaderButton, "ANCHOR_LEFT")
            _G.GameTooltip:SetText(L["ARLC - Materials"])
            local saved = FollowedStep()
            _G.GameTooltip:AddLine(saved and saved.shopping
                and L["Click to open the shopping list. Right-click to stop following."]
                or L["Click to open this guide step. Right-click to stop following."], 1, 1, 1, true)
            _G.GameTooltip:Show()
        end
        function FollowTracker:OnBlockHeaderLeave(block)
            SetFollowBlockHighlight(block, false)
            _G.GameTooltip:Hide()
        end
    end
    if manager:GetContainerForModule(FollowTracker) ~= container then
        _G.securecallfunction(manager.SetModuleContainer, manager, FollowTracker, container)
    end
    FollowTracker.arlStopped = false
    FollowTracker:MarkDirty()
    return true
end
private.RefreshGuideTracking = EnsureFollowTracker
private.HideGuideTracking = StopFollowTracker

local function SaveFollowedStep(frame, shopping)
    local step, guide = frame.step, frame.guide
    shopping = shopping or step == nil
    local selections = frame.selections[guide.id]
    local selected = step and (selections[step.id] or 1)
    local variant = step and (step.variants[selected] or step.variants[1])
    local inputs = variant and variant.materials or {}
    if shopping then
        inputs = {}
        for id, quantity in pairs(private.GuideShoppingList(frame.profession, selections)) do
            inputs[#inputs + 1] = { id, quantity }
        end
        table.sort(inputs, function(a, b)
            return (guide.materialNames[a[1]] or tostring(a[1])) < (guide.materialNames[b[1]] or tostring(b[1]))
        end)
    end
    local materials, byID = {}, {}
    for _, material in ipairs(inputs) do
        local id, quantity = material[1], material[2]
        if quantity > 0 then
            if byID[id] then byID[id].required = byID[id].required + quantity
            else
                local entry = { id = id, required = quantity, name = guide.materialNames[id] or (L["Item #%d"]):format(id) }
                byID[id] = entry
                materials[#materials + 1] = entry
            end
        end
    end
    local savedSelections = {}
    if shopping then for id, index in pairs(selections) do savedSelections[id] = index end end
    addon.db.char.guideFollow = {
        profession = frame.profession:Name(), guideID = guide.id, stepID = not shopping and step.id or nil,
        shopping = shopping, selections = shopping and savedSelections or nil,
        guideKey = (addon.db.char.guideSelections or {})[frame.profession:Name()]
            or (frame.profession:Module().GuideOrder or {})[1], variant = selected,
        title = shopping and (L["%s: Shopping List"]:format(frame.profession:LocalizedName()))
            or variant.title or step.title or SpellName(variant.spellID), materials = materials,
    }
end

followEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
followEvents:SetScript("OnEvent", function(_, event, name)
    if not FollowedStep() then StopFollowTracker(); return end
    if event == "ADDON_LOADED" and name ~= "Blizzard_ObjectiveTracker" then return end
    if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
        -- The manager attaches its native modules after entering the world.
        _G.C_Timer.After(0, function() if FollowedStep() then EnsureFollowTracker() end end)
    elseif FollowedStep() then
        if event == "PLAYER_REGEN_ENABLED" or event == "ZONE_CHANGED_NEW_AREA" or not FollowTracker then EnsureFollowTracker()
        else FollowTracker:MarkDirty() end
    end
end)

local function NextUncompletedStep(guide, currentStep)
    local completed = CompletedSteps(guide)
    local passedCurrent, firstChapter, firstStep = false
    for _, chapter in ipairs(guide.chapters) do
        for _, step in ipairs(chapter.steps) do
            if step.id == currentStep.id then
                passedCurrent = true
            elseif not completed[step.id] then
                if passedCurrent then return chapter, step end
                if not firstStep then firstChapter, firstStep = chapter, step end
            end
        end
    end
    -- Return to an earlier unfinished step before declaring the guide complete.
    return firstChapter, firstStep
end

local function CreateGuideFrame()
    local frame = private.CreateFrameWithBackdrop("Frame", "ARL_GuidePanel", _G.UIParent, "PortraitFrameTemplate")
    frame:SetSize(540, 580)
    -- The template offsets its title around the portrait; center this guide's
    -- text on the full frame instead of inheriting that asymmetric container.
    local title = frame.TitleContainer.TitleText
    title:ClearAllPoints()
    title:SetPoint("CENTER", frame, "TOP", 0, -10)
    title:SetWidth(400)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 240, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    table.insert(_G.UISpecialFrames, "ARL_GuidePanel")
    local inset = _G.CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 8, -62)
    inset:SetPoint("BOTTOMRIGHT", -10, 10)
    if inset.Bg then inset.Bg:Hide() end
    local parchment = inset:CreateTexture(nil, "BACKGROUND")
    parchment:SetAtlas("QuestBG-Parchment")
    parchment:SetPoint("TOPLEFT", 1, -1)
    parchment:SetPoint("BOTTOMRIGHT", -1, 1)
    local scroll = _G.CreateFrame("ScrollFrame", "ARL_GuideScroll", inset)
    scroll:SetPoint("TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = _G.CreateFrame("Frame", nil, scroll)
    content:SetSize(466, 1)
    scroll:SetScrollChild(content)
    frame.content, frame.scroll, frame.rows = content, scroll, {}
    local scrollbar = _G.CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
    scrollbar:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -12, -12)
    scrollbar:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -12, 12)
    scrollbar:SetWidth(8)
    scrollbar:SetInterpolateScroll(false)
    scrollbar:Init(1, 1)
    -- Keep Track interactive and its child thumb visible; hide only artwork.
    scrollbar.Track.Begin:Hide()
    scrollbar.Track.Middle:Hide()
    scrollbar.Track.End:Hide()
    frame.scrollbar = scrollbar
    local range, syncing = 0, false
    -- Native controls use percentages; the parchment ScrollFrame uses pixels.
    function frame:UpdateScrollbar()
        local viewport = scroll:GetHeight()
        local extent = math.max(1, content:GetHeight())
        range = math.max(0, extent - viewport)
        local offset = math.min(scroll:GetVerticalScroll(), range)
        syncing = true
        -- Match the compact thumb used by the recipe tooltip.
        scrollbar:SetVisibleExtentPercentage(math.min(0.2, viewport / extent))
        scrollbar:SetPanExtentPercentage(range > 0 and math.min(1, 32 / range) or 1)
        scrollbar:SetScrollPercentage(range > 0 and offset / range or 0)
        scrollbar:SetShown(range > 0)
        scroll:SetVerticalScroll(offset)
        syncing = false
    end
    scrollbar:RegisterCallback(_G.ScrollBarMixin.Event.OnScroll, function(_, percentage)
        if not syncing then scroll:SetVerticalScroll(percentage * range) end
    end, frame)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        if syncing then return end
        syncing = true
        scrollbar:SetScrollPercentage(range > 0 and math.max(0, math.min(1, offset / range)) or 0)
        syncing = false
    end)
    local function ScrollWithWheel(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * 32)))
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", ScrollWithWheel)
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetScript("OnMouseWheel", ScrollWithWheel)
    scroll:SetScript("OnSizeChanged", function() frame:UpdateScrollbar() end)
    -- Step alternatives and expanded NPC lists last for this frame's session;
    -- completion and the selected module guide use character saved variables.
    frame.selections = {}
    frame.expandedLocations = {}
    local choice = _G.CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    choice:SetSize(230, 22)
    choice:SetPoint("TOPRIGHT", -28, -33)
    choice.Text:ClearAllPoints()
    choice.Text:SetPoint("LEFT", choice, "LEFT", 10, 1)
    choice.Text:SetPoint("RIGHT", choice, "RIGHT", -28, 1)
    choice.Text:SetHeight(16)
    choice.Text:SetJustifyH("CENTER")
    choice.Text:SetJustifyV("MIDDLE")
    choice.Text:SetWordWrap(false)
    choice:SetDefaultText(L["Select route"])
    choice:SetupMenu(function(_, root)
        local guide, step = frame.guide, frame.step
        if not guide or not step or #step.variants < 2 then return end
        local selections = frame.selections[guide.id]
        local function IsSelected(index)
            return index == (selections[step.id] or 1)
        end
        local function SelectRoute(index)
            -- A menu belongs to the step that opened it, even if the window is reused.
            if not frame:IsShown() or frame.guide ~= guide or frame.step ~= step or IsSelected(index) then return end
            selections[step.id] = index
            -- These two steps form one route: keep the fish/oil and mana alternatives together.
            local paired = guide.id == "forever-alchemy-1-225" and
                (step.id == "130-150" and "150-165" or step.id == "150-165" and "130-150")
            if paired then selections[paired] = index end
            RenderGuide()
            frame.scroll:SetVerticalScroll(0)
        end
        root:CreateTitle(L["Select route"])
        for index, variant in ipairs(step.variants) do
            root:CreateRadio(RouteLabel(variant, step),
                IsSelected, SelectRoute, index)
        end
    end)
    frame.choice = choice
    local complete = _G.CreateFrame("CheckButton", nil, frame, "MinimalCheckboxArtTemplate")
    complete:SetSize(20, 20)
    complete:SetPoint("TOPLEFT", 78, -34)
    if complete.Text then complete.Text:Hide() end
    complete.label = complete:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    complete.label:SetPoint("LEFT", complete, "RIGHT", 4, 0)
    complete.label:SetText(L["Completed"])
    private.SetTooltipScripts(complete, L["Mark this step as completed to update your guide progress. Uncheck it to undo."], 1)
    complete:SetScript("OnClick", function(self)
        if not frame.step then return end
        local completed = self:GetChecked() and true or false
        CompletedSteps(frame.guide)[frame.step.id] = completed and true or nil
        if completed and IsFollowed(frame) then
            addon.db.char.guideFollow = nil
            if FollowTracker then FollowTracker:MarkDirty() end
        end
        RenderGuide()
        local main = addon.Frame
        local tab = main and main.tabs and main.tabs[addon.db.profile.current_tab]
        -- Refresh markers/progress only if the main panel still shows this
        -- profession's Guide tab; the separate detail window can outlive it.
        if tab and tab.kind == "guide" and private.CurrentProfession == frame.profession then
            main.list_frame:Update(nil, false)
        end
        if completed then
            local chapter, step = NextUncompletedStep(frame.guide, frame.step)
            if step then private.OpenGuideStep(frame.profession, chapter, step)
            else frame:Hide() end
        end
    end)
    frame.complete = complete
    local follow = _G.CreateFrame("CheckButton", nil, frame, "MinimalCheckboxArtTemplate")
    follow:SetSize(20, 20)
    follow:SetPoint("TOPLEFT", 180, -34)
    if follow.Text then follow.Text:Hide() end
    follow.label = follow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    follow.label:SetPoint("LEFT", follow, "RIGHT", 4, 0)
    follow.label:SetText(L["Follow"])
    follow:SetScript("OnClick", function()
        if IsFollowed(frame) then addon.db.char.guideFollow = nil
        else SaveFollowedStep(frame) end
        EnsureFollowTracker()
        RenderGuide()
    end)
    frame.follow = follow
    -- Listen for item, bag, zone and skill changes only while the window is open.
    frame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        self.choice:CloseMenu()
        self:UnregisterAllEvents()
        if self.hoveredRow then _G.GameTooltip:Hide(); self.hoveredRow = nil end
    end)
    frame:SetScript("OnShow", function(self)
        for _, event in ipairs({ "ITEM_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED" }) do
            self:RegisterEvent(event)
        end
    end)
    frame:SetScript("OnEvent", function(self, event, itemID)
        if event == "ITEM_DATA_LOAD_RESULT" and not self.pendingItems[itemID] then return end
        -- Coalesce event bursts into one render. Unrelated item loads need no
        -- refresh, and a delayed callback must not reopen a hidden window.
        if self.refreshPending then return end
        self.refreshPending = true
        _G.C_Timer.After(.1, function()
            self.refreshPending = nil
            if self:IsShown() then RenderGuide() end
        end)
    end)
    frame:Hide()
    return frame
end

-- ----------------------------------------------------------------------------
-- Reusable content rows.
-- ----------------------------------------------------------------------------
-- Rows are pooled by position. Reapply their appearance, payload and callbacks
-- on every render so reused rows cannot retain another step's interaction.
local function AddRow(text, options)
    local frame = GuideFrame
    options = options or {}
    local index = frame.rowCount + 1
    local row = frame.rows[index]
    if not row then
        row = _G.CreateFrame("Button", nil, frame.content)
        row.label = row:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("TOP")
        row.label:SetWordWrap(true)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("TOPLEFT")
        row.iconBackground = row:CreateTexture(nil, "BACKGROUND")
        row.iconBackground:SetAtlas("Professions-Slot-bg")
        row.iconBackground:SetAllPoints(row.icon)
        row.iconBorder = row:CreateTexture(nil, "OVERLAY")
        row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
        -- Match Forever's CircularGiantItemButtonTemplate. Attach its mask only
        -- to output rows; pooled reagent rows must retain their square icons.
        row.iconMask = row:CreateMaskTexture(nil, "ARTWORK")
        row.iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        row.iconMask:SetPoint("TOPLEFT", row.icon, "TOPLEFT", 2, -2)
        row.iconMask:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -2, 2)
        row.detail = row:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
        row.detail:SetPoint("TOPRIGHT", 0, -2)
        row.detail:SetJustifyH("RIGHT")
        row.divider = row:CreateTexture(nil, "ARTWORK")
        row.divider:SetColorTexture(.35, .22, .1, .25)
        row.divider:SetSize(466, 1)
        row.divider:SetPoint("TOPLEFT", 0, 6)
        row:RegisterForClicks("LeftButtonUp")
        frame.rows[index] = row
    end
    if options.heading and frame.cursorY > 0 then frame.cursorY = frame.cursorY + 12 end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -frame.cursorY)
    row:SetWidth(466)
    row.label:ClearAllPoints()
    local inset = options.itemID and (options.hero and 76 or 44) or 0
    local textOffset = options.itemID and (options.hero and -18 or -9) or -2
    row.label:SetPoint("TOPLEFT", inset, textOffset)
    row.label:SetWidth(466 - inset - (options.detail and 125 or 0))
    local fontName = (options.heading or options.hero) and "QuestTitleFont" or "QuestFontNormalSmall"
    row.label:SetFontObject(fontName)
    -- Derive the summary from an existing Forever font, resetting pooled rows too.
    local fontPath, fontSize, fontFlags = _G[fontName]:GetFont()
    row.label:SetFont(fontPath, fontSize + (options.summary and 2 or 0), fontFlags)
    if options.action then row.label:SetTextColor(.32, .23, .12)
    elseif options.muted then row.label:SetTextColor(.36, .28, .19)
    else row.label:SetTextColor(.2, .13, .08) end
    row.label:SetText(text)
    row.itemID, row.entity, row.action = options.itemID, options.entity, options.action
    row.requiredQuantity = options.requiredQuantity
    row.divider:SetShown(options.heading and frame.rowCount > 0 or false)
    row.detail:SetText(options.detail or "")
    local color = options.detailColor or { .2, .13, .08 }
    row.detail:SetTextColor(unpack(color))
    row.detail:ClearAllPoints()
    row.detail:SetPoint("TOPRIGHT", 0, textOffset)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("TOPLEFT", options.hero and 7 or 5, options.hero and -7 or -4)
    row.icon:SetSize(options.hero and 54 or 32, options.hero and 54 or 32)
    local circular = options.itemID and options.hero or false
    if circular ~= (row.iconIsCircular or false) then
        if circular then row.icon:AddMaskTexture(row.iconMask)
        else row.icon:RemoveMaskTexture(row.iconMask) end
        row.iconIsCircular = circular
    end
    row.icon:SetTexCoord(.078125, .921875, .078125, .921875)
    row.iconBackground:SetShown(options.itemID and not options.hero or false)
    row.iconBorder:SetShown(options.itemID ~= nil)
    if options.itemID then
        -- Match the native quality/theme mappings for outputs and ordinary
        -- reagents. ChoiceReagent's CropFrame is only for modifying slots.
        local _, _, quality = private.GetItemInfo(options.itemID)
        local manager = _G.ColorManager
        local getBorder = manager and (options.hero and manager.GetAtlasDataForAuctionHouseItemQuality or manager.GetAtlasDataForProfessionsItemQuality)
        local data = getBorder and getBorder(quality or 1)
        local borderAtlas = data and data.atlas or (options.hero and "auctionhouse-itemicon-border-white" or "Professions-Slot-Frame")
        local borderColor = data and data.overrideColor
        row.iconBorder:ClearAllPoints()
        if options.hero then
            row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
        elseif borderAtlas == "Professions-Slot-Frame" then
            -- The decorative common frame has inset artwork; keep its outer
            -- size steady while letting the item art fill more of the slot.
            row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -3, 3)
            row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 3, -3)
        else
            -- Colored quality frames fit directly to the icon bounds.
            row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT")
            row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
        end
        row.iconBorder:SetAtlas(borderAtlas)
        if options.hero then row.iconBorder:SetSize(68, 68) end
        row.iconBorder:SetVertexColor(borderColor and borderColor.r or 1, borderColor and borderColor.g or 1, borderColor and borderColor.b or 1)
        local _, icon = ItemText(frame.guide, options.itemID)
        row.icon:SetTexture(icon or 134400)
        row.icon:Show()
        -- Draw a placeholder immediately, requesting each missing item once
        -- until its load event allows the renderer to update the content.
        if not private.GetItemInfo(options.itemID) then
            if not frame.pendingItems[options.itemID] then
                frame.pendingItems[options.itemID] = true
                _G.C_Item.RequestLoadItemDataByID(options.itemID)
            end
        else
            frame.pendingItems[options.itemID] = nil
        end
    else
        row.icon:Hide()
    end
    local height = math.max(options.hero and 72 or options.itemID and 40 or 18, row.label:GetStringHeight() - textOffset + 6)
    row:SetHeight(height)
    frame.cursorY, frame.rowCount = frame.cursorY + height + (options.heading and 5 or 2), index
    row:SetScript("OnEnter", function(self)
        if not self.itemID and not self.entity then return end
        frame.hoveredRow = self
        local tip = _G.GameTooltip
        tip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then
            if private.GetItemInfo(self.itemID) then
                tip:SetItemByID(self.itemID)
            else
                tip:SetText(frame.guide.materialNames[self.itemID] or (L["Item #%d"]):format(self.itemID))
            end
            AddMaterialSources(tip, frame.guide, self.itemID, self.requiredQuantity, frame.step ~= nil)
        else
            tip:SetText(EntityText(self.entity))
            tip:AddLine(L["Click to mark this location on the map."], 1, 1, 1)
        end
        tip:Show()
    end)
    row:SetScript("OnLeave", function() frame.hoveredRow = nil; _G.GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.action then
            self.action()
        elseif self.itemID then
            local _, link = private.GetItemInfo(self.itemID)
            link = link or ("|Hitem:%d|h[%s]|h"):format(self.itemID, frame.guide.materialNames[self.itemID] or (L["Item #%d"]):format(self.itemID))
            if not _G.HandleModifiedItemClick(link) then _G.SetItemRef("item:" .. self.itemID, link, button) end
        elseif self.entity then
            local entity = self.entity.entity
            if self.entity.mapID and entity.coord_x and entity.coord_y and entity.coord_x > 0 and entity.coord_y > 0 then
                -- Source coordinates are percentages; waypoints use 0-1 units.
                addon:SetWaypoint(self.entity.mapID, entity.coord_x / 100, entity.coord_y / 100, entity.name)
            end
        end
    end)
    row:EnableMouse(options.itemID ~= nil or options.entity ~= nil or options.action ~= nil)
    row:Show()
end

local function AddEntities(heading, entities)
    if #entities == 0 then return end
    local frame = GuideFrame
    -- Expansion belongs to this guide, step and section, keeping a trainer
    -- list independent from suppliers or the same heading in another step.
    local key = frame.guide.id .. ":" .. (frame.step and frame.step.id or "shopping") .. ":" .. heading
    local expanded = frame.expandedLocations[key]
    AddRow(heading, { heading = true })
    AddRow(L["Recommended: "] .. EntityText(entities[1]), { entity = entities[1] })
    for index = 2, expanded and #entities or 1 do
        AddRow(EntityText(entities[index]), { entity = entities[index] })
    end
    if #entities > 1 then
        AddRow(expanded and L["[-] Hide other locations"] or (L["[+] Other locations (%d)"]):format(#entities - 1), {
            action = function()
                frame.expandedLocations[key] = not frame.expandedLocations[key]
                RenderGuide()
            end,
        })
    end
end

local function AddMaterial(guide, itemID, quantity)
    local bags = _G.C_Item.GetItemCount(itemID) or 0
    AddRow(ItemText(guide, itemID), { itemID = itemID, requiredQuantity = quantity, detail = ("%d / %d"):format(bags, quantity),
        detailColor = bags >= quantity and { .12, .35, .12 } or { .55, .12, .08 } })
end

-- ----------------------------------------------------------------------------
-- Shopping list calculation.
-- ----------------------------------------------------------------------------
-- Shopping quantities are calculated from the selected alternatives, with
-- intermediate crafted products deducted rather than counted as purchases.
function private.GuideShoppingList(profession, selections)
    local guide = private.GetProfessionGuide(profession)
    local totals, produced = {}, {}
    for _, chapter in ipairs(guide.chapters) do
        for _, step in ipairs(chapter.steps) do
            local variant = step.variants[selections[step.id] or 1] or step.variants[1]
            for _, material in ipairs(variant.materials) do
                totals[material[1]] = (totals[material[1]] or 0) + material[2]
            end
            -- Route-specific recipe books are purchased once, even when
            -- several actions refer to the same book.
            for _, requirement in ipairs(variant.shoppingRequirements or {}) do
                totals[requirement[1]] = math.max(totals[requirement[1]] or 0, requirement[2])
            end
            if variant.outputItemID then
                produced[variant.outputItemID] = (produced[variant.outputItemID] or 0) + variant.count * (variant.outputCount or 1)
            end
        end
    end
    -- Deduct route outputs before expanding extra preparations. This keeps
    -- saved belts, hides, bolts and oils from becoming duplicate purchases.
    for itemID, quantity in pairs(produced) do
        if totals[itemID] then totals[itemID] = math.max(0, totals[itemID] - quantity) end
    end
    for _, requirement in ipairs(guide.shoppingRequirements or {}) do
        totals[requirement[1]] = (totals[requirement[1]] or 0) + requirement[2]
    end
    -- Expand only preparations outside the leveling route. Route-produced
    -- grinding stones have already been deducted above. Metadata validation
    -- rejects cycles; keep a runtime guard for manually edited module guides.
    local function expand(itemID, quantity, visiting)
        local source = guide.materialSources[itemID]
        if not source or not source.ingredients or visiting[itemID] then
            totals[itemID] = (totals[itemID] or 0) + quantity
            return
        end
        visiting[itemID] = true
        local crafts = math.ceil(quantity / source.outputCount)
        for _, ingredient in ipairs(source.ingredients) do
            expand(ingredient[1], crafts * ingredient[2], visiting)
        end
        visiting[itemID] = nil
    end
    local preparations = {}
    for itemID, quantity in pairs(totals) do
        if quantity > 0 and guide.materialSources[itemID] and guide.materialSources[itemID].ingredients then
            preparations[itemID] = quantity
        end
    end
    for itemID in pairs(preparations) do totals[itemID] = nil end
    for itemID, quantity in pairs(preparations) do expand(itemID, quantity, {}) end
    -- Reusable tools require at least the listed quantity, not one per craft.
    for _, tool in ipairs(guide.tools or {}) do
        totals[tool.itemID] = math.max(totals[tool.itemID] or 0, tool.quantity)
    end
    return totals
end

-- ----------------------------------------------------------------------------
-- Detail rendering.
-- ----------------------------------------------------------------------------
-- A nil step selects the shopping view. Other calls render the active variant
-- with materials, acquisition, rank training and the shared guide notes.
RenderGuide = function()
    local frame = GuideFrame
    local guide, profession, step, chapter = frame.guide, frame.profession, frame.step, frame.chapter
    local selections = frame.selections[guide.id]
    local oldScroll = frame.scroll:GetVerticalScroll()
    frame.rowCount, frame.cursorY = 0, 0
    -- Retain row objects and scroll position while rebuilding their contents.
    for _, row in ipairs(frame.rows) do row:Hide() end
    frame.TitleContainer.TitleText:SetText(("%s - %s"):format(guide.title or L["%s Guide"]:format(profession:LocalizedName()), step and (step.label or step.id) or L["Shopping List"]))
    if frame.SetPortraitToAsset then frame:SetPortraitToAsset(profession:WaypointIconTexture()) end
    frame.choice:SetShown(step ~= nil and #step.variants > 1)
    frame.complete:SetShown(step ~= nil)
    frame.complete:SetChecked(step ~= nil and CompletedSteps(guide)[step.id] == true)
    local followed = IsFollowed(frame)
    local saved = FollowedStep()
    local shoppingFollowed = saved and saved.shopping and saved.profession == profession:Name() and saved.guideID == guide.id
    if followed or shoppingFollowed then
        SaveFollowedStep(frame, shoppingFollowed)
        if FollowTracker then FollowTracker:MarkDirty() end
    end
    frame.follow:Show()
    frame.follow:ClearAllPoints()
    frame.follow:SetPoint("TOPLEFT", step and 180 or 78, -34)
    local variant = step and (step.variants[selections[step.id] or 1] or step.variants[1])
    local shoppingTotals = not step and private.GuideShoppingList(profession, selections)
    local hasMaterials = variant and #variant.materials > 0 or false
    if shoppingTotals then
        for _, quantity in pairs(shoppingTotals) do if quantity > 0 then hasMaterials = true; break end end
    end
    frame.follow:SetEnabled(hasMaterials)
    frame.follow:SetChecked(followed and true or false)
    private.SetTooltipScripts(frame.follow,
        not step and (followed and L["Stop following the shopping list in the Objectives Tracker."]
            or L["Follow the shopping list in the Objectives Tracker."])
            or (followed and L["Stop following this step's materials in the Objectives Tracker."]
            or L["Follow this step's materials in the Objectives Tracker."]), 1)
    if not step then
        AddRow(L["Materials for the selected route"], { heading = true })
        AddRow(guide.shoppingNote or L["Alternatives replace each other. Change a step's route in its detail window; the shopping list updates automatically."])
        local totals = shoppingTotals
        local ids = {}
        for itemID, quantity in pairs(totals) do if quantity > 0 then ids[#ids + 1] = itemID end end
        table.sort(ids, function(a, b) return (guide.materialNames[a] or tostring(a)) < (guide.materialNames[b] or tostring(b)) end)
        AddRow("", { detail = L["Owned / Required"], muted = true })
        for _, itemID in ipairs(ids) do AddMaterial(guide, itemID, totals[itemID]) end
    else
        local selected = selections[step.id] or 1
        local variant = step.variants[selected] or step.variants[1]
        frame.choice:OverrideText(RouteLabel(variant, step))
        local recipe = RecipeFor(profession, variant)
        local learned = recipe and recipe:HasState("KNOWN")
        local recipeItemID = variant.recipeItemID or (recipe and recipe:RecipeItem())
        local learnedColor = { .12, .35, .12 }
        local function RecipeItemOptions(itemID)
            return { itemID = itemID,
                detail = learned and itemID == recipeItemID and "1 / 1" or nil,
                detailColor = learnedColor }
        end
        -- Gathering can show the ore without declaring a counted craft output.
        local craftedID = variant.iconItemID or (recipe and recipe:CraftedItem()) or variant.outputItemID
        AddRow(variant.title or step.title or SpellName(variant.spellID), {
            hero = true, itemID = craftedID,
            detail = learned and not recipeItemID and "1 / 1" or nil,
            detailColor = learnedColor })
        -- Open-ended gathering/smelting steps supply their own target wording.
        if variant.actionText then
            AddRow(variant.actionText, { summary = true })
        elseif variant.spellID then
            AddRow(variant.count and (L["Craft ~%d times  |  Reach skill %d"]):format(variant.count, step.to)
                or (L["Cook until Cooking %d; catch more fish if needed."]):format(step.to), { summary = true })
        end
        if step.note then AddRow(step.note) end
        if variant.note then AddRow(variant.note) end
        for _, instruction in ipairs(variant.instructions or {}) do AddRow(instruction) end
        for _, itemID in ipairs(variant.items or {}) do AddRow(ItemText(guide, itemID), RecipeItemOptions(itemID)) end
        if variant.npcs then
            local entities = {}
            for _, id in ipairs(variant.npcs) do
                local npc = guide.locations[id]
                if npc and (npc.faction == private.Player.faction or npc.faction == "Neutral") then
                    entities[#entities+1] = {id=id,mapID=npc.mapID,entity={name=npc.name,locationName=npc.zone,coord_x=npc.x,coord_y=npc.y}}
                end
            end
            AddEntities(L["Route locations"], RankEntities(entities))
        end
        if variant.materials and #variant.materials > 0 then
            AddRow(L["Required materials"], { heading = true })
            AddRow("", { detail = L["Owned / Required"], muted = true })
            for _, material in ipairs(variant.materials) do AddMaterial(guide, material[1], material[2]) end
        end
        -- Step-specific tool requirements replace the guide-wide display;
        -- they do not add purchases to the shopping calculation above.
        local tools = variant.requiredTools or guide.tools
        if tools and #tools > 0 then
            AddRow(L["Required tools (reusable)"], { heading = true })
            for _, tool in ipairs(tools) do AddMaterial(guide, tool.itemID, tool.quantity) end
        end
        if recipeItemID then
            AddRow(L["Recipe item"], { heading = true })
            AddRow(ItemText(guide, recipeItemID), RecipeItemOptions(recipeItemID))
        end
        AddEntities(L["Recipe vendors - suggested locations"], RecipeSources(profession, variant, private.AcquireTypes.Vendor, guide))
        AddEntities(L["Learn this recipe"], RecipeSources(profession, variant, private.AcquireTypes.Trainer, guide))
        local training = chapter.training
        if training then
            AddRow(training.rank, { heading = true })
            AddRow((L["Required skill: %d | Character level: %d%s"]):format(training.skill, training.level,
                training.cost and (L[" | Training cost: "] .. training.cost) or ""))
            AddEntities(L["Rank trainers"], private.GetGuideEntities(private.AcquireTypes.Trainer, training.locationIDs or training.trainers or {}, guide))
            if training.note then AddRow(training.note) end
            if training.itemID then
                AddRow(ItemText(guide, training.itemID), {itemID=training.itemID})
                AddEntities(L["Rank book suppliers"], private.GetGuideSupplyEntities(guide, training.itemID))
            end
        end
        for _, material in ipairs(variant.materials) do
            local source = guide.materialSources[material[1]]
            if source and source.kind == "supply" then
                local heading = (material[1] == 3371 or material[1] == 3372 or material[1] == 8925)
                    and L["Buy vials - suggested suppliers"] or L["Buy %s - suggested suppliers"]:format(ItemText(guide, material[1]))
                AddEntities(heading, private.GetGuideSupplyEntities(guide, material[1]))
            end
        end
        for _, tool in ipairs(guide.tools or {}) do
            AddEntities(L["Tool suppliers"], private.GetGuideSupplyEntities(guide, tool.itemID))
        end
        AddRow(L["Vendor recommendations use recorded locations; limited recipes may be out of stock."], { muted = true })
    end
    if guide.setupItems and #guide.setupItems > 0 then
        AddRow(L["Optional campfire supplies"], {heading=true})
        AddRow(L["Use an existing cooking fire, or craft and place a Basic Campfire Kit. Buy these supplies when you need to make your own fire."])
        for _,itemID in ipairs(guide.setupItems) do
            AddRow(ItemText(guide,itemID),{itemID=itemID})
            AddEntities(L["Campfire suppliers"], private.GetGuideSupplyEntities(guide,itemID))
        end
    end
    AddRow(L["Guide notes"], { heading = true })
    AddRow(guide.introduction, { muted = true })
    AddRow(L["Source: WoW-Professions"], { muted = true })
    frame.content:SetHeight(math.max(1, frame.cursorY))
    frame.scroll:UpdateScrollChildRect()
    frame:UpdateScrollbar()
    frame.scroll:SetVerticalScroll(math.min(oldScroll, math.max(0, frame.cursorY - frame.scroll:GetHeight())))
end

-- ----------------------------------------------------------------------------
-- Public detail-window entry point.
-- ----------------------------------------------------------------------------
function private.RefreshGuideRecipeStatus(profession)
    if GuideFrame and GuideFrame:IsShown() and GuideFrame.profession == profession then
        RenderGuide()
    end
end

-- Bind the reused frame to the active guide before showing it. Opening a new
-- step/shopping view resets scrolling; event-driven renders preserve it.
function private.OpenGuideStep(profession, chapter, step, selections)
    local guide = private.GetProfessionGuide(profession)
    if not guide then return end
    GuideFrame = GuideFrame or CreateGuideFrame()
    GuideFrame.choice:CloseMenu()
    GuideFrame.profession, GuideFrame.guide, GuideFrame.chapter, GuideFrame.step = profession, guide, chapter, step
    GuideFrame.selections[guide.id] = GuideFrame.selections[guide.id] or {}
    if selections then
        local restored = {}
        for id, index in pairs(selections) do restored[id] = index end
        GuideFrame.selections[guide.id] = restored
    end
    GuideFrame.pendingItems = {}
    GuideFrame:Show()
    RenderGuide()
    GuideFrame.scroll:SetVerticalScroll(0)
    GuideFrame:Raise()
end
