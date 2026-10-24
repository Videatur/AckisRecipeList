-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------

local pairs = _G.pairs

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...
local L = _G.LibStub("AceLocale-3.0"):GetLocale(private.addon_name)

-- ----------------------------------------------------------------------------
-- Imports.
-- ----------------------------------------------------------------------------
local CATEGORY_COLORS = private.CATEGORY_COLORS
local COORDINATES_FORMAT = private.COORDINATES_FORMAT
local LFAC = private.LOCALIZED_FACTION_STRINGS_FROM_LABEL

local REPUTATION_VENDOR_LABEL = private.VENDOR_TYPE_FORMAT:format(_G.REPUTATION)

private.RegisterAcquireType({
	-- ----------------------------------------------------------------------------
	-- Data.
	-- ----------------------------------------------------------------------------
	_colorData = { hex = "855a99", r = 0.52, g = 0.35, b = 0.6 },
	_hasCoordinates = false,
	_hasEntities = true,
	_label = "REPUTATION",
	_name = REPUTATION_VENDOR_LABEL,
	-- ----------------------------------------------------------------------------
	-- Methods.
	-- ----------------------------------------------------------------------------
	_func_expand_list_entry = function(self, entry_index, entry_type, parent_entry, identifier, info, recipe, hide_location, hide_type)
		local reputation_entity = self:GetEntity(identifier)

		-- A neutral reputation vendor may sell recipes restricted to one player
		-- faction.  The vendor's faction alone is therefore not enough to decide
		-- visibility; respect the recipe's Alliance/Horde filter as well.
		if not reputation_entity or (not private.db.profile.filters.general.faction and not private.Player:HasRecipeFaction(recipe)) then
			return entry_index
		end

		for reputation_level, reputation_level_info in pairs(info) do
			for vendor_id in pairs(reputation_level_info) do
				local rep_vendor = private.AcquireTypes.Vendor:GetEntity(vendor_id)

				if not rep_vendor or not self.CanDisplayFaction(rep_vendor.faction) then
					return entry_index
				end

				if not self.__faction_labels then
					local rep_color = private.REPUTATION_COLORS

					self.__faction_labels = {
						[0] = private.SetTextColor(rep_color.neutral.hex, LFAC.NEUTRAL .. " : "),
						[1] = private.SetTextColor(rep_color.friendly.hex, LFAC.FRIENDLY .. " : "),
						[2] = private.SetTextColor(rep_color.honored.hex, LFAC.HONORED .. " : "),
						[3] = private.SetTextColor(rep_color.revered.hex, LFAC.REVERED .. " : "),
						[4] = private.SetTextColor(rep_color.exalted.hex, LFAC.EXALTED .. " : ")
					}
				end

				local entry = private.CreateListEntry(entry_type, parent_entry, recipe)
				entry:SetNPCID(vendor_id)
				entry:SetLocation(rep_vendor.Location)
				entry:SetText("%s%s %s",
					self.EntryPadding,
					hide_type and "" or private.SetTextColor(self:ColorData().hex, REPUTATION_VENDOR_LABEL) .. ":",
					private.SetTextColor(CATEGORY_COLORS.repname.hex, reputation_entity.name))

				entry_index = private.list_frame:InsertEntry(entry, entry_index, true)

				entry = private.CreateListEntry(entry_type, parent_entry, recipe)
				entry:SetNPCID(vendor_id)
				entry:SetLocation(rep_vendor.Location)
				local standingLabel = recipe:IsRepVendorStandingUnknown(identifier)
					and private.SetTextColor(CATEGORY_COLORS.repname.hex, L["Special requirements"] .. " : ")
					or self.__faction_labels[reputation_level]
				entry:SetText(self.EntryPadding:rep(2) .. standingLabel .. self.ColorNameByFaction(rep_vendor.name, rep_vendor.faction))

				entry_index = private.list_frame:InsertEntry(entry, entry_index, true)

				local coord_text = ""

				if rep_vendor.coord_x ~= 0 and rep_vendor.coord_y ~= 0 then
					coord_text = private.SetTextColor(CATEGORY_COLORS.coords.hex, COORDINATES_FORMAT:format(rep_vendor.coord_x, rep_vendor.coord_y))
				end

				if coord_text == "" and hide_location then
					return entry_index
				end

				entry = private.CreateListEntry(entry_type, parent_entry, recipe)
				entry:SetNPCID(vendor_id)
				entry:SetLocation(rep_vendor.Location)
				local locName = (rep_vendor.Location and rep_vendor.Location.LocalizedName and rep_vendor.Location:LocalizedName()) or "Unknown"
				entry:SetText("%s%s %s",
					self.EntryPadding:rep(3),
					hide_location and "" or private.SetTextColor(CATEGORY_COLORS.location.hex, locName),
					coord_text)

				return private.list_frame:InsertEntry(entry, entry_index, true)
			end
		end
	end,
	_func_insert_tooltip_text = function(self, recipe, identifier, localizedLocationName, acquire_info, addline_func)
		local reputation_entity = self:GetEntity(identifier)

		-- Keep tooltip output consistent with the list: neutral vendors must not
		-- bypass a faction restriction placed on the recipe.
		if not reputation_entity or (not private.db.profile.filters.general.faction and not private.Player:HasRecipeFaction(recipe)) then
			return
		end

		local levels = {}
		for level in pairs(acquire_info) do levels[#levels + 1] = level end
		table.sort(levels)
		local ranks = {
			[0] = {LFAC.NEUTRAL, private.REPUTATION_COLORS.neutral},
			[1] = {LFAC.FRIENDLY, private.REPUTATION_COLORS.friendly},
			[2] = {LFAC.HONORED, private.REPUTATION_COLORS.honored},
			[3] = {LFAC.REVERED, private.REPUTATION_COLORS.revered},
			[4] = {LFAC.EXALTED, private.REPUTATION_COLORS.exalted}
		}
		for _, reputationLevel in ipairs(levels) do
			local vendors = {}
			for vendorID in pairs(acquire_info[reputationLevel]) do
				local vendor = private.AcquireTypes.Vendor:GetEntity(vendorID)
				local location = vendor and vendor.Location
				local locName = (location and location.LocalizedName and location:LocalizedName()) or "Unknown"
				if vendor and (not localizedLocationName or locName == localizedLocationName) then
					local canDisplay, nameColor = self.GetTipFactionInfo(vendor.faction)
					if canDisplay then
						vendors[#vendors + 1] = {id=vendorID, entity=vendor, location=locName, color=nameColor}
					end
				end
			end
			table.sort(vendors, function(a, b)
				if a.entity.name == b.entity.name then return a.id < b.id end
				return a.entity.name < b.entity.name
			end)
			if #vendors > 0 then
				local rank = ranks[reputationLevel] or ranks[4]
				local standingLabel = recipe:IsRepVendorStandingUnknown(identifier) and L["Special requirements"] or rank[1]
				addline_func(0, 0, false, reputation_entity.name, CATEGORY_COLORS.repname, standingLabel, rank[2])
				for _, entry in ipairs(vendors) do
					local vendor = entry.entity
					addline_func(1, -1, false, vendor.name, entry.color)
					local coords = ""
					if vendor.coord_x and vendor.coord_y and vendor.coord_x ~= 0 and vendor.coord_y ~= 0 then
						coords = COORDINATES_FORMAT:format(vendor.coord_x, vendor.coord_y)
					end
					addline_func(2, -2, true, entry.location, CATEGORY_COLORS.location, coords, CATEGORY_COLORS.coords)
				end
			end
		end
	end,
	_func_waypoint_target = function(self, id_num, recipe)
		if not private.db.profile.mapvendor then
			return
		end

		local vendor = private.AcquireTypes.Vendor:GetEntity(id_num)
		if not vendor or not vendor.reputation_id then
			return
		end

		local reputation = self:GetEntity(vendor.reputation_id)
		local standing = private.Player.reputation_levels_by_id[vendor.reputation_id]
		if reputation and standing and standing > 0 and self.CanDisplayFaction(vendor.faction)
			and private.IsReputationForFaction(vendor.reputation_id, private.Player.faction) then
			return vendor
		end
	end,
	_GetOrCreateRecipeData = function(sourceData, ...)
		local factionID, reputationLevel = ...

		if factionID and reputationLevel then
			if not sourceData[factionID] then
				sourceData[factionID] = {
					[reputationLevel] = {}
				}
			elseif not sourceData[factionID][reputationLevel] then
				sourceData[factionID][reputationLevel] = {}
			end
		end

		return sourceData
	end
})
