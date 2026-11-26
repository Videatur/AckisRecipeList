--[[
    Ackis Recipe List - Configuration
    
    Provides native Blizzard Settings controls with AceConfig compatibility:
    - Main options (filters, exclusion list)
    - Waypoint settings (TomTom/HereBeDragons)
    - Display options (UI scale, tooltips)
    - Documentation tabs
    
    Copyright (c) 2009 - 2012 Ackis <John Pasula>
    All rights reserved by the original author Ackis.
]]

-- ============================================================================
-- Upvalued Lua API
-- ============================================================================
local pairs = _G.pairs
local type = _G.type

local table = _G.table

-- ============================================================================
-- AddOn Namespace
-- ============================================================================
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub

local addon = LibStub("AceAddon-3.0"):GetAddon(private.addon_name)
local L = LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

local AceConfigReg = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- ============================================================================
-- Local Variables
-- ============================================================================
local modularOptions = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function RegisterProfileDropdown()
    local gui = LibStub("AceGUI-3.0")
    local widgetType = "AckisProfileDropdown"
    if gui:GetWidgetVersion(widgetType) then return widgetType end
    gui:RegisterWidgetType(widgetType, function()
        local frame = _G.CreateFrame("Frame", nil, _G.UIParent)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT")
        label:SetPoint("TOPRIGHT")
        label:SetJustifyH("LEFT")
        local dropdown = _G.CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
        dropdown:SetHeight(26)
        local widget = { type = widgetType, frame = frame, label = label, dropdown = dropdown, list = {}, order = {} }
        function widget:SetText(text) self.dropdown:SetDefaultText(text or "") end
        function widget:SetLabel(text)
            self.label:SetText(text or "")
            self.label:SetShown(text ~= nil and text ~= "")
            local offset = text and text ~= "" and -18 or 0
            self.dropdown:ClearAllPoints()
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, offset)
            self.dropdown:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, offset)
            self:SetHeight(text and text ~= "" and 46 or 28)
            self.alignoffset = text and text ~= "" and 31 or 13
        end
        function widget:SetValue(value)
            self.value = value
            self:SetText(self.list[value])
            self.dropdown:GenerateMenu()
        end
        function widget:GetValue() return self.value end
        function widget:SetList(list, order)
            self.list, self.order = list or {}, {}
            if type(order) == "table" then
                for _, key in ipairs(order) do self.order[#self.order + 1] = key end
            else
                for key in pairs(self.list) do self.order[#self.order + 1] = key end
                table.sort(self.order, function(a, b) return tostring(self.list[a]) < tostring(self.list[b]) end)
            end
            self.dropdown:GenerateMenu()
        end
        function widget:SetDisabled(disabled)
            self.disabled = disabled
            self.dropdown:SetEnabled(not disabled)
            if disabled then self.dropdown:CloseMenu() end
            self.label:SetTextColor(disabled and .5 or 1, disabled and .5 or .82, disabled and .5 or 0)
        end
        function widget:ClearFocus() self.dropdown:CloseMenu() end
        function widget:OnAcquire()
            self.list, self.order, self.value = {}, {}, nil
            self:SetWidth(200)
            self:SetLabel(nil)
            self:SetDisabled(false)
            self:SetText("")
            self.dropdown:GenerateMenu()
        end
        function widget:OnRelease()
            self:ClearFocus()
            self.list, self.order, self.value = {}, {}, nil
            self.dropdown:GenerateMenu()
        end
        dropdown:SetupMenu(function(_, root)
            for _, key in ipairs(widget.order) do
                root:CreateRadio(widget.list[key], function(value) return widget.value == value end,
                    function(value)
                        if widget.disabled then return end
                        widget:SetValue(value)
                        -- AceConfig still handles validation, confirmation and the DB operation.
                        widget:Fire("OnValueChanged", value)
                    end, key)
            end
        end)
        dropdown:HookScript("OnEnter", function() widget:Fire("OnEnter") end)
        dropdown:HookScript("OnLeave", function() widget:Fire("OnLeave") end)
        frame:SetScript("OnHide", function() widget:ClearFocus() end)
        return gui:RegisterAsWidget(widget)
    end, 1)
    return widgetType
end

local function giveProfiles()
    local original = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)
    local control = RegisterProfileDropdown()
    -- AceDBOptions shares its argument definitions between addons. Copy them
    -- before changing our layout or widget so other addons remain independent.
    local result = {}
    for key, value in pairs(original) do result[key] = value end
    result.args = {}
    for key, option in pairs(original.args) do
        local copy = {}
        for field, value in pairs(option) do copy[field] = value end
        if copy.type == "select" and control then copy.dialogControl = control end
        if copy.type == "description" then copy.fontSize = "medium" end
        result.args[key] = copy
    end
    local args = result.args
    -- Give the full character name its own row instead of the narrow space
    -- beside Reset. Keep inputs and menus compact, matching the other controls.
    if args.current then args.current.width = "full" end
    for _, key in ipairs({ "new", "choose", "copyfrom", "delete" }) do
        if args[key] then args[key].width = 2 end
    end
    if args.current then
        local currentName = args.current.name
        args.currentCaption = {
            type = "description", order = 2, width = "full", fontSize = "medium",
            name = function(info)
                local text = type(currentName) == "function" and currentName(info) or currentName
                -- Keep AceDB's translated caption; the colored profile name is
                -- displayed separately below it in the larger native font.
                local caption = text:match("^(.-)%s*|c%x%x%x%x%x%x%x%x") or text:match("^(.-):") or text
                return "\n|cffb3b3b3" .. caption .. "|r"
            end,
        }
        args.current.order = 3
        args.current.fontSize = "large"
        args.current.name = function(info)
            return "|cffffd100" .. info.handler:GetCurrentProfile() .. "|r\n"
        end
    end
    if args.descreset then args.descreset.order = 90 end
    if args.reset then args.reset.order = 100 end
    return result
end

--- Reset GUI position without changing display preferences or visibility
local function ResetGUI()
	local options = addon.db.profile.frameopts
	local MainPanel = addon.Frame

	options.offsetx = 0
	options.offsety = 0
	options.anchorTo = ""
	options.anchorFrom = ""
	if MainPanel then
		MainPanel:ClearAllPoints()
		MainPanel:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
	end
end

local function RefreshRecipeList()
    local panel = addon.Frame
    if private.addonEnabled == false or not panel or not panel:IsVisible() or not private.CurrentProfession then return end
    if panel.list_frame then panel.list_frame:Update(nil, false) end
    panel:UpdateTitle()
end

-- ============================================================================
-- Main Options Builder
-- ============================================================================

local options

local function fullOptions()
	if not options then
		options = {
			type = "group",
			name = private.addon_display_name or private.addon_name,
			args = {
				general = {
					order = 1,
					type = "group",
					name = L["Main Options"],
					desc = L["MAIN_OPTIONS_DESC"],
					args = {
						version = {
							order = 11,
							type = "description",
							name = _G.GAME_VERSION_LABEL .. ": " .. addon.version .. "\n",
						},
						show_minimap_button = {
							order = 13,
							type = "toggle",
							name = L["Minimap Button"],
							desc = L["Toggle the ARL minimap button"],
							get = function()
								return not (addon.db.profile.minimapIcon and addon.db.profile.minimapIcon.hide)
							end,
							set = function(_, value)
								addon.db.profile.minimapIcon = addon.db.profile.minimapIcon or { hide = false }
								addon.db.profile.minimapIcon.hide = not value
								if addon.UpdateMinimapIcon then addon:UpdateMinimapIcon() end
							end,
						},
						versionspacer = {
							order = 12,
							type = "description",
							name = "\n",
						},
						header1 = {
							order = 15,
							type = "header",
							name = L["Main Filter Options"],
						},
						mainfilter_desc = {
							order = 20,
							type = "description",
							name = L["MAINFILTER_OPTIONS_DESC"] .. "\n",
						},
						includefiltered = {
							order = 25,
							type = "toggle",
							name = L["Include Filtered"],
							desc = L["FILTERCOUNT_DESC"],
							get = function()
								return addon.db.profile.includefiltered
							end,
							set = function(_, value)
								addon.db.profile.includefiltered = value
								RefreshRecipeList()
							end,
						},
						includeexcluded = {
							order = 30,
							type = "toggle",
							name = L["Include Excluded"],
							desc = L["EXCLUDECOUNT_DESC"],
							get = function()
								return addon.db.profile.includeexcluded
							end,
							set = function(_, value)
								addon.db.profile.includeexcluded = value
								RefreshRecipeList()
							end,
						},
						exclusionlist = {
							order = 35,
							type = "execute",
							name = L["View Exclusion List"],
							desc = L["VIEW_EXCLUSION_LIST_DESC"],
							func = function(info)
								local exclusion_list = addon.db.profile.exclusionlist

								for spell_id in pairs(exclusion_list) do
									local spell_name = private.GetSpellName(spell_id)

									if spell_name then
										addon:Printf("%d: %s", spell_id, spell_name)
									else
										addon:Printf("%d: %s", spell_id, _G.UNKNOWN)
									end
								end
							end,
							disabled = function(info)
								for spell_id in pairs(addon.db.profile.exclusionlist) do
									return false
								end
								return true
							end,
						},
						clearexclusionlist = {
							order = 40,
							type = "execute",
							name = L["Clear Exclusion List"],
							desc = L["CLEAR_EXCLUSION_LIST_DESC"],
							func = function(info)
								local exclusion_list = addon.db.profile.exclusionlist

								table.wipe(exclusion_list)
                                private.IncrementFilterVersion()

								RefreshRecipeList()
							end,
							disabled = function(info)
								for spell_id in pairs(addon.db.profile.exclusionlist) do
									return false
								end
								return true
							end,
						},
						spacer1 = {
							order = 45,
							type = "description",
							name = "\n",
						},
					},
				},
			},
		}

		for k, v in pairs(modularOptions) do
			options.args[k] = (type(v) == "function") and v() or v
		end
	end
	return options
end

-- ============================================================================
-- Waypoint Options
-- ============================================================================

local arlmap

local function GetMapOptions()
	if not arlmap then
		arlmap = {
			order = 1,
			type = "group",
			name = L["Waypoints"],
			args = {
				map_desc = {
					order = 1,
					type = "description",
					name = L["MAP_OPTIONS_DESC"] .. "\n",
				},
				maptrainer = {
					order = 2,
					type = "toggle",
					name = L["Trainer"],
					desc = L["WAYPOINT_TOGGLE_FORMAT"]:format(L["Trainer"]),
					get = function()
						return addon.db.profile.maptrainer
					end,
					set = function(_, value)
						addon.db.profile.maptrainer = value
						addon:RefreshWaypointPreferences()
					end,
				},
				mapvendor = {
					order = 3,
					type = "toggle",
					name = L["Vendor"],
					desc = L["WAYPOINT_TOGGLE_FORMAT"]:format(L["Vendor"]),
					get = function()
						return addon.db.profile.mapvendor
					end,
					set = function(_, value)
						addon.db.profile.mapvendor = value
						addon:RefreshWaypointPreferences()
					end,
				},
				mapmob = {
					order = 4,
					type = "toggle",
					name = L["Mob Drop"],
					desc = L["WAYPOINT_TOGGLE_FORMAT"]:format(L["Mob Drop"]),
					get = function()
						return addon.db.profile.mapmob
					end,
					set = function(_, value)
						addon.db.profile.mapmob = value
						addon:RefreshWaypointPreferences()
					end,
				},
				mapquest = {
					order = 5,
					type = "toggle",
					name = L["Quest"],
					desc = L["WAYPOINT_TOGGLE_FORMAT"]:format(L["Quest"]),
					get = function()
						return addon.db.profile.mapquest
					end,
					set = function(_, value)
						addon.db.profile.mapquest = value
						addon:RefreshWaypointPreferences()
					end,
				},
				map_acquire_header = {
					order = 10,
					type = "header",
					name = "",
				},
				autoscanmap = {
					order = 11,
					type = "toggle",
					width = "full",
					name = L["Auto Scan Map"],
					desc = L["AUTOSCANMAP_DESC"],
					get = function()
						return addon.db.profile.autoscanmap
					end,
					set = function(_, value)
						addon.db.profile.autoscanmap = value
						if addon.db.profile.autoscanmap then
							addon:AutoScanZoneWaypoints()
						else
							addon:ClearAutomaticWaypoints()
						end
					end,
				},
				worldmap = {
					order = 12,
					type = "toggle",
					width = "full",
					name = _G.WORLD_MAP,
					desc = L["WAYPOINT_MAP_FORMAT"]:format(_G.WORLD_MAP),
					get = function()
						return addon.db.profile.worldmap
					end,
					set = function(_, value)
						addon.db.profile.worldmap = value
						addon:RefreshWaypointPreferences()
					end,
				},
				minimap = {
					order = 13,
					type = "toggle",
					width = "full",
					name = _G.MINIMAP_LABEL,
					desc = L["WAYPOINT_MAP_FORMAT"]:format(_G.MINIMAP_LABEL),
					get = function()
						return addon.db.profile.minimap
					end,
					set = function(_, value)
						addon.db.profile.minimap = value
						addon:RefreshWaypointPreferences()
					end,
				},
				clearmap = {
					order = 20,
					type = "execute",
					name = L["Clear Waypoints"],
					desc = L["CLEAR_WAYPOINTS_DESC"],
					func = function()
						addon:ClearWaypoints()
					end,
				},
			},
		}
	end

	return arlmap
end

-- ============================================================================
-- Documentation Options
-- ============================================================================

local documentation

local function GetDocumentation()
	if not documentation then
		documentation = {
			order = 1,
			type = "group",
			name = L["Documentation"],
			args = {
				header2 = {
					order = 1,
					type = "header",
					name = L["Using Filters"],
				},
				desc2 = {
					order = 2,
					type = "description",
					name = L["USING_FILTERS_DESC"],
				},
				header3 = {
					order = 3,
					type = "header",
					name = L["Common Issues"],
				},
				desc3 = {
					order = 4,
					type = "description",
					name = L["COMMON_ISSUES_DESC"],
				},
				header5 = {
					order = 5,
					type = "header",
					name = L["Exclusion Issues"],
				},
				desc5 = {
					order = 6,
					type = "description",
					name = L["EXCLUSION_ISSUES_DESC"],
				},
				header6 = {
					order = 7,
					type = "header",
					name = L["Map Issues"],
				},
				desc6 = {
					order = 8,
					type = "description",
					name = L["MAP_ISSUES_DESC"],
				},
				header7 = {
					order = 9,
					type = "header",
					name = L["Game Commands"],
				},
				desc7 = {
					order = 10,
					type = "description",
					name = L["GAME_COMMANDS_DESC"],
				},
			},
		}
	end
	return documentation
end

-- ============================================================================
-- Display Options
-- ============================================================================

local displayoptions


local function GetDisplayOptions()
	if not displayoptions then
		displayoptions = {
			order = 1,
			name = _G.DISPLAY_OPTIONS,
			type = "group",
			childGroups = "tab",
			args = {
				interface_tab = {
					order = 10,
					name = _G.INTERFACE_OPTIONS,
					type = "group",
					args = {
						display_desc = {
							order = 1,
							name = L["DISPLAY_OPTIONS_DESC"] .. "\n",
							type = "description",
						},

						uiscale = {
							order = 3,
							type = "range",
							name = _G.UI_SCALE,
							desc = L["UI_SCALE_DESC"],
							min = .5,
							max = 1.5,
							step = .05,
							bigStep = .05,
							get = function()
								return addon.db.profile.frameopts.uiscale
							end,
							set = function(info, v)
								addon.db.profile.frameopts.uiscale = v
								if private.InitializeFrame then
									private.InitializeFrame()
								end
								if addon.Frame then addon.Frame:SetScale(v) end
							end,
						},
						small_list_font = {
							order = 4,
							width = "full",
							type = "toggle",
							name = L["Small Font"],
							desc = L["SMALL_FONT_DESC"],
							get = function()
								return addon.db.profile.frameopts.small_list_font
							end,
							set = function(info, value)
								addon.db.profile.frameopts.small_list_font = value
								if private.InitializeFrame then
									private.InitializeFrame()
								end
								RefreshRecipeList()
							end,
						},
						closegui = {
							width = "full",
							order = 5,
							type = "toggle",
							name = L["Close GUI"],
							desc = L["CLOSEGUI_DESC"],
							get = function()
								return addon.db.profile.closeguionskillclose
							end,
							set = function(info, value)
								addon.db.profile.closeguionskillclose = value
							end,
						},
						hidepopup = {
							width = "full",
							order = 6,
							type = "toggle",
							name = L["Hide Pop-Up"],
							desc = L["HIDEPOPUP_DESC"],
							get = function()
								return addon.db.profile.hidepopup
							end,
							set = function(info, value)
								addon.db.profile.hidepopup = value
							end,
						},
						resetguiwindow = {
							width = "double",
							order = 7,
							type = "execute",
							name = L["Reset Window Position"],
							desc = L["RESET_WINDOW_DESC"],
							func = ResetGUI,
						},
					},
				},
				tooltip_tab = {
					order = 20,
					name = L["Tooltip Options"],
					type = "group",
					args = {
						tooltip_desc = {
							order = 12,
							type = "description",
							name = L["TOOLTIP_OPTIONS_DESC"] .. "\n",
						},
						tooltip_fontsize = {
							order = 19,
							type = "range",
							name = _G.FONT_SIZE,
							desc = L["FONT_SIZE_DESC"],
							min = 6,
							max = 20,
							step = 1,
							bigStep = 1,
							get = function()
								return addon.db.profile.tooltip.acquire_fontsize
							end,
							set = function(info, v)
								addon.db.profile.tooltip.acquire_fontsize = v
							end,
						},
						tooltipscale = {
							order = 20,
							type = "range",
							name = L["Tooltip Scale"],
							desc = L["TOOLTIP_SCALE_DESC"],
							min = .5,
							max = 1.5,
							step = .05,
							bigStep = .05,
							get = function()
								return addon.db.profile.tooltip.scale
							end,
							set = function(info, v)
								addon.db.profile.tooltip.scale = v
							end,
						},
						acquiretooltiplocation = {
							order = 21,
							type = "select",
							name = L["Tooltip (Acquire) Position"],
							desc = L["ACQUIRETOOLTIPPOSITION_DESC"],
							get = function()
								return addon.db.profile.acquiretooltiplocation
							end,
							set = function(info, name)
								addon.db.profile.acquiretooltiplocation = name
							end,
							values = function()
								return {
									Right = L["Right"],
									Left = L["Left"],
									Top = L["Top"],
									Bottom = L["Bottom"],
									Off = _G.OFF,
									Mouse = _G.MOUSE_LABEL
								}
							end,
						},
						spelltooltiplocation = {
							order = 22,
							type = "select",
							name = L["Tooltip (Recipe) Position"],
							desc = L["SPELLTOOLTIPPOSITION_DESC"],
							get = function()
								return addon.db.profile.spelltooltiplocation
							end,
							set = function(info, name)
								addon.db.profile.spelltooltiplocation = name
							end,
							values = function()
								return {
									Right = L["Right"],
									Left = L["Left"],
									Top = L["Top"],
									Bottom = L["Bottom"],
									Off = _G.OFF
								}
							end,
						},
						spacer1 = {
							order = 23,
							type = "description",
							name = "\n",
						},
						unit_tooltip = {
							order = 24,
							type = "toggle",
							name = L["Recipes In Tooltips"],
							desc = L["UNIT_TOOLTIPS_DESC"],
							get = function()
								return addon.db.profile.recipes_in_tooltips
							end,
							set = function(info, value)
								addon.db.profile.recipes_in_tooltips = value
								private.RefreshNPCTooltipProfessions()
							end,
						},
						unit_all_profession_drops = {
							order = 25,
							type = "toggle",
							name = L["Recipe Drops Before Scanning"],
							desc = L["UNIT_UNSCANNED_PROFESSION_DROPS_DESC"],
							disabled = function()
								return not addon.db.profile.recipes_in_tooltips
							end,
							get = function()
								return addon.db.profile.all_profession_drops_in_tooltips
							end,
							set = function(info, value)
								addon.db.profile.all_profession_drops_in_tooltips = value
								private.RefreshNPCTooltipProfessions()
							end,
						},
						unit_max_tooltip = {
							order = 26,
							type = "range",
							name = _G.MAXIMUM,
							desc = L["UNIT_MAX_TOOLTIPS_DESC"],
							min = 1,
							max = 50,
							step = 1,
							bigStep = 5,
							disabled = function()
								return not addon.db.profile.recipes_in_tooltips
							end,
							get = function()
								return addon.db.profile.max_recipes_in_tooltips
							end,
							set = function(info, v)
								addon.db.profile.max_recipes_in_tooltips = v
							end,
						},
						tooltip_hint = {
							order = 27,
							type = "toggle",
							name = L["TOOLTIP_HINT"],
							desc = L["TOOLTIP_HINT_DESC"],
							get = function()
								return addon.db.profile.hide_tooltip_hint
							end,
							set = function(info, value)
								addon.db.profile.hide_tooltip_hint = value
							end,
						},
					},
				},
			},
		}
	end
	return displayoptions
end

-- ============================================================================
-- Options Registration
-- ============================================================================

-- Keep the existing option callbacks and profile storage, but let Blizzard
-- build and align the controls with Forever's native Settings system.
local defaultPaths = {
    show_minimap_button = { "minimapIcon", "hide" },
    uiscale = { "frameopts", "uiscale" },
    small_list_font = { "frameopts", "small_list_font" },
    closegui = { "closeguionskillclose" },
    tooltip_fontsize = { "tooltip", "acquire_fontsize" },
    tooltipscale = { "tooltip", "scale" },
    unit_tooltip = { "recipes_in_tooltips" },
    unit_all_profession_drops = { "all_profession_drops_in_tooltips" },
    unit_max_tooltip = { "max_recipes_in_tooltips" },
    tooltip_hint = { "hide_tooltip_hint" },
}

local function NativeDefault(key, option, info)
    local value = addon.db.defaults and addon.db.defaults.profile
    for _, field in ipairs(defaultPaths[key] or { key }) do
        if type(value) == "table" then value = value[field] else value = nil end
    end
    if key == "show_minimap_button" and value ~= nil then value = not value end
    if value == nil then value = option.get(info) end
    return value
end

local function SortedOptions(args)
    local sorted = {}
    for key, option in pairs(args) do sorted[#sorted + 1] = { key = key, option = option } end
    table.sort(sorted, function(a, b)
        local ao, bo = a.option.order or 100, b.option.order or 100
        return ao == bo and a.key < b.key or ao < bo
    end)
    return sorted
end

local function CreateNativeDocumentation(optionsTable)
    local panel = _G.CreateFrame("Frame", nil, _G.UIParent)
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText((private.addon_display_name or private.addon_name) .. " - " .. optionsTable.name)

    local scroll = _G.CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 16, -48)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    scroll:EnableMouseWheel(true)
    local scrollbar = _G.CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollbar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 12, 0)
    scrollbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 12, 0)
    scrollbar:Init(1, 0)
    _G.ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollbar)

    local content = _G.CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local paragraphs = {}
    for _, entry in ipairs(SortedOptions(optionsTable.args)) do
        local option = entry.option
        local heading = option.type == "header"
        local text = content:CreateFontString(nil, "ARTWORK", heading and "GameFontNormal" or "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        text:SetText(option.name)
        paragraphs[#paragraphs + 1] = { text = text, heading = heading }
    end
    local function Layout()
        local width = scroll:GetWidth()
        if width <= 0 then return end
        content:SetWidth(width)
        local offset = 0
        for _, paragraph in ipairs(paragraphs) do
            local text = paragraph.text
            if paragraph.heading and offset > 0 then offset = offset + 12 end
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
            text:SetWidth(width)
            offset = offset + text:GetStringHeight() + 10
        end
        content:SetHeight(offset)
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
        scrollbar:SetShown(scroll:GetVerticalScrollRange() > 0)
    end
    scroll:SetScript("OnSizeChanged", Layout)
    panel:SetScript("OnShow", Layout)
    panel.ScrollFrame, panel.ScrollBar = scroll, scrollbar
    return panel
end

local function AddNativeOptions(category, group, path)
    local Settings = _G.Settings
    local state = addon.nativeOptionGroups[path]
    if not state then
        state = { controls = {}, settings = {}, completed = {}, headers = {} }
        addon.nativeOptionGroups[path] = state
    end
    local controls = state.controls
    local sorted = SortedOptions(group.args)
    for index, entry in ipairs(sorted) do
        local key, option = entry.key, entry.option
        if not state.completed[key] then
            local info = { path, key }
            local initializer = controls[key]
            if not initializer then
                if option.type == "group" then
                    local description
                    for _, child in ipairs(SortedOptions(option.args)) do
                        if child.option.type == "description" then description = child.option.name; break end
                    end
                    if not state.headers[key] then
                        Settings.RegisterInitializer(category, _G.CreateSettingsListSectionHeaderInitializer(option.name, description))
                        state.headers[key] = true
                    end
                    AddNativeOptions(category, option, path .. "_" .. key)
                elseif option.type == "header" or key == "version" then
                    if option.name:find("%S") then
                        local nextOption = sorted[index + 1] and sorted[index + 1].option
                        local description = option.desc or (nextOption and nextOption.type == "description" and nextOption.name)
                        Settings.RegisterInitializer(category, _G.CreateSettingsListSectionHeaderInitializer(option.name, description))
                    end
                elseif option.type == "execute" then
                    -- Keep action buttons out of the shared search index.
                    initializer = _G.CreateSettingsButtonInitializer("", option.name, function()
                        option.func(info)
                        if private.RefreshNativeOptions then private.RefreshNativeOptions() end
                    end, option.desc, false)
                elseif option.type == "toggle" or option.type == "range" or option.type == "select" then
                    local default = NativeDefault(key, option, info)
                    local variableType = option.type == "toggle" and "boolean" or type(default)
                    local variable = FOLDER_NAME .. "_" .. path .. "_" .. key
                    local setting = state.settings[key]
                    if not setting then
                        setting = Settings.RegisterProxySetting(category, variable, variableType, option.name, default,
                            function() return option.get(info) end,
                            function(value)
                                if option.get(info) ~= value then option.set(info, value) end
                            end)
                        state.settings[key] = setting
                        addon.nativeOptionVariables[#addon.nativeOptionVariables + 1] = variable
                    end
                    if option.type == "toggle" then
                        initializer = Settings.CreateCheckboxInitializer(setting, nil, option.desc)
                    elseif option.type == "range" then
                        local sliderOptions = Settings.CreateSliderOptions(option.min, option.max, option.step)
                        sliderOptions:SetLabelFormatter(_G.MinimalSliderWithSteppersMixin.Label.Right, function(value)
                            return option.step < 1 and ("%.2f"):format(value) or tostring(value)
                        end)
                        initializer = Settings.CreateSliderInitializer(setting, sliderOptions, option.desc)
                    else
                        initializer = Settings.CreateDropdownInitializer(setting, function()
                            local values = type(option.values) == "function" and option.values(info) or option.values
                            local keys = {}
                            for value in pairs(values) do keys[#keys + 1] = value end
                            table.sort(keys, function(a, b) return values[a] < values[b] end)
                            local container = Settings.CreateControlTextContainer()
                            for _, value in ipairs(keys) do container:Add(value, values[value]) end
                            return container:GetData()
                        end, option.desc)
                    end
                end
                if initializer then
                    -- The CreateCheckbox/Slider/Dropdown helpers write directly to the
                    -- shared layout. Register through Blizzard's Settings delegate.
                    Settings.RegisterInitializer(category, initializer)
                end
            end
            if initializer then
                controls[key] = initializer
                if key == "unit_max_tooltip" or key == "unit_all_profession_drops" then
                    initializer:AddEvaluateStateCVar(state.settings.unit_tooltip:GetVariable())
                end
                if option.disabled ~= nil then
                    initializer:AddModifyPredicate(function()
                        return not (type(option.disabled) == "function" and option.disabled(info) or option.disabled == true)
                    end)
                end
            end
            state.completed[key] = true
        end
    end
end

function private.RefreshNativeOptions()
    for _, variable in ipairs(addon.nativeOptionVariables or {}) do
        -- NotifyUpdate dispatches to Blizzard's shared settings controls.
        _G.securecallfunction(_G.Settings.NotifyUpdate, variable)
    end
end

local function RegisterOptions(self)
	if not self.optionTableRegistered then
		AceConfigReg:RegisterOptionsTable(private.addon_name, fullOptions)
		self.optionTableRegistered = true
	end
	local Settings = _G.Settings
	self.nativeOptionVariables = self.nativeOptionVariables or {}
	self.nativeOptionGroups = self.nativeOptionGroups or {}
	-- Keep addon bookkeeping off the native category object. Blizzard retains
	-- that object in the shared Settings panel, including its keybinding UI.
	self.optionsFrame = self.optionsFrame or {}
	local category = self.settingsCategory
	if not category then
		category = Settings.RegisterVerticalLayoutCategory(private.addon_display_name or private.addon_name)
		self.settingsCategory = category
	end
	if not self.settingsCategoryRegistered then
		Settings.RegisterAddOnCategory(category)
		self.settingsCategoryRegistered = true
	end
	AddNativeOptions(category, fullOptions().args.general, "general")

	-- Register module options
	self:RegisterModuleOptions("Display", GetDisplayOptions(), _G.DISPLAY_OPTIONS)

	self:RegisterModuleOptions("Waypoint", GetMapOptions(), L["Waypoints"])

	self:RegisterModuleOptions("Documentation", GetDocumentation(), L["Documentation"])
	self:RegisterModuleOptions("Profiles", giveProfiles(), L["Profile Options"])
end

function addon:SetupOptions()
    if self.optionsRegistered or self.optionsRegistering then return end
    self.optionsRegistering = true
    local ok, err = _G.pcall(RegisterOptions, self)
    self.optionsRegistering = nil
    if not ok then _G.error(err, 0) end
    self.optionsRegistered = true
end

--- Register a module options table
--- @param name string The options table key
--- @param optionsTable table The options table or function returning one
--- @param displayName string The display name in config UI
function addon:RegisterModuleOptions(name, optionsTable, displayName)
	modularOptions[name] = optionsTable
	if options then options.args[name] = type(optionsTable) == "function" and optionsTable() or optionsTable end
	if name == "Display" or name == "Waypoint" then
		local category = self.optionsFrame[name]
		if not category then
			category = _G.Settings.RegisterVerticalLayoutSubcategory(self.settingsCategory, displayName)
			self.optionsFrame[name] = category
		end
		AddNativeOptions(category, optionsTable, name)
	elseif name == "Documentation" then
		if not self.optionsFrame[name] then
			self.documentationPanel = self.documentationPanel or CreateNativeDocumentation(optionsTable)
			self.optionsFrame[name] = _G.Settings.RegisterCanvasLayoutSubcategory(self.settingsCategory, self.documentationPanel, displayName)
		end
	else
		local parent = self.settingsCategory:GetID()
		if not self.optionsFrame[name] then
			self.optionsFrame[name] = AceConfigDialog:AddToBlizOptions(private.addon_name, displayName, parent, name)
		end
	end
end
