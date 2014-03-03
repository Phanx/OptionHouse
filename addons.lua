local Manage = {}
local L = OptionHouseLocals
local TOTAL_ROWS = 14
local dependencies, addons, addonStatus, frame = {}, {}, {}

OptionHouseProfiles = {}

local blizzardAddons = {
--	"Blizzard_AchievementUI", "Blizzard_ArenaUI", "Blizzard_AuctionUI", "Blizzard_BarbershopUI", "Blizzard_BattlefieldMinimap",
--	"Blizzard_BindingUI", "Blizzard_Calendar", "Blizzard_CombatLog", "Blizzard_CombatText", "Blizzard_GlyphUI", "Blizzard_GMChatUI",
--	"Blizzard_GMSurveyUI", "Blizzard_GuildBankUI", "Blizzard_InspectUI", "Blizzard_ItemSocketingUI", "Blizzard_MacroUI",
--	"Blizzard_RaidUI", "Blizzard_TalentUI", "Blizzard_TimeManager", "Blizzard_TokenUI", "Blizzard_TradeSkillUI", "Blizzard_TrainerUI"
}

local STATUS_COLORS = {
	["DISABLED"] = "|cff9d9d9d",
	["NOT_DEMAND_LOADED"] = "|cffff8000",
	["DEP_NOT_DEMAND_LOADED"] = "|cffff8000",
	["LOAD_ON_DEMAND"] = "|cff1eff00",
	["DISABLED_AT_RELOAD"] = "|cffa335ee",
	["INCOMPATIBLE"] = "|cffff2020",
}

local function sortManagementAddons(a, b)
	if not b then
		return false
	elseif frame.sortOrder then
		if frame.sortType == "name" or a[frame.sortType] == b[frame.sortType] then
			return strlower(a.title) < strlower(b.title)
		end
		return strlower(a[frame.sortType]) < strlower(b[frame.sortType])
	else
		if frame.sortType == "name" or a[frame.sortType] == b[frame.sortType] then
			return ( strlower(a.title) > strlower(b.title) )
		end
		return strlower(a[frame.sortType]) > strlower(b[frame.sortType])
	end
end

-- Turns a vararg into a table
local function createDependencies(...)
	if select("#", ...) == 0 then
		return nil
	end

	local deps = {}
	for i = 1, select("#", ...) do
		deps[select(i, ...)] = true
	end
	return deps
end

-- Searches the passed dependencies to see if parent is mentioned
local function isAddonChildOf(parent, ...)
	if select("#", ...) == 0 then
		return nil
	end

	if type(parent) == "number" then
		parent = strlower((GetAddOnInfo(parent)))
	end

	for i = 1, select("#", ...) do
		if strlower(select(i, ...)) == parent then
			return true
		end
	end

	return nil
end

local updateManageList
local function filterParent(self)
	if frame.parentFilter and frame.parentFilter == self.parentAddon then
		frame.parentFilter = nil
	else
		frame.parentFilter = self.parentAddon
	end

	updateManageList()
end

-- Displays everything
updateManageList = function()
	-- This way we don't have to recreate the entire list on search
	local searchBy = strtrim(strlower(frame.search:GetText()))
	if searchBy == "" or frame.search.searchText then
		searchBy = nil
	end

	-- We could reduce all of this into one or two if statements, but this way is saner
	-- and far easier for people to debug
	for id, addon in pairs(addons) do
		if searchBy and not strfind(strlower(addon.title), searchBy) then
			addons[id].hide = true
		elseif not frame.parentFilter then
			addons[id].hide = nil
		elseif frame.parentFilter == addon.name or ( dependencies[addon.name] and dependencies[addon.name][frame.parentFilter] ) then
			addons[id].hide = nil
		else
			addons[id].hide = true
		end
	end

	sort(addons, sortManagementAddons)

	local usedRows = 0
	local totalAddons = 0
	for id, addon in pairs(addons) do
		if not addon.hide then
			totalAddons = totalAddons + 1
			if totalAddons > frame.scroll.offset and usedRows < TOTAL_ROWS then
				usedRows = usedRows + 1

				local row = frame.rows[usedRows]
				if addon.color then
					row.title:SetFormattedText("%s%s|r", addon.color, addon.title)
					row.reason:SetFormattedText("%s%s|r", addon.color, addon.reason)
				else
					row.title:SetText(addon.title)
					row.reason:SetText(addon.reason)
				end

				row.enabled.text = addon.tooltip
				row.enabled.addon = addon.name
				row.enabled:SetChecked(addon.isEnabled)
				row:Show()

				-- Shift the reason to the right if no button so we don't have ugly blank space
				if not addon.isLoD then
					row.reason:ClearAllPoints()
					row.reason:SetPoint("RIGHT", row, "RIGHT", -5, 0)
					row.button:Hide()
				else
					row.reason:ClearAllPoints()
					row.reason:SetPoint("RIGHT", row.button, "LEFT", -5, 0)
					row.button.addon = addon.name
					row.button:Show()
				end

				for _, parent in pairs(row.parents) do parent:Hide() end
				if dependencies[addon.name] then
					local id = 1
					for dependency in pairs(dependencies[addon.name]) do
						local parent = row.parents[id]
						if not parent then
							parent = CreateFrame("Button", nil, row)
							parent:SetNormalFontObject(GameFontHighlightSmall)
							parent:SetHeight(18)
							parent:SetScript("OnClick", filterParent)

							if id > 1 then
								parent:SetPoint("LEFT", row.parents[id - 1], "RIGHT", 4, 0)
							else
								parent:SetPoint("LEFT", row.title, "RIGHT", 23, 0)
							end

							row.parents[id] = parent
						end

						if addonStatus[dependency] then
							parent:SetText(addonStatus[dependency])
						else
							parent:SetFormattedText("%s%s|r", STATUS_COLORS["INCOMPATIBLE"], dependency)
						end

						parent.parentAddon = dependency
						parent:SetWidth(parent:GetFontString():GetStringWidth() + 3)
						parent:Show()

						id = id + 1
					end

					addon.totalDependencies = id - 1
				else
					addon.totalDependencies = 0
				end
			end
		end
	end

	for i = usedRows+1, #frame.rows do
		frame.rows[i]:Hide()
	end

	OptionHouse:UpdateScroll(frame.scroll, totalAddons)
end

local function sortManageClick(self)
	if self.sortType then
		if self.sortType ~= frame.sortType then
			frame.sortOrder = false
			frame.sortType = self.sortType
		else
			frame.sortOrder = not frame.sortOrder
		end

		updateManageList()
	end
end

local function saveAddonData(id, skipCheck)
	local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(id)
	local isLoaded = IsAddOnLoaded(id)
	local isLoD = IsAddOnLoadOnDemand(id)

	if not dependencies[name] then
		dependencies[name] = createDependencies(GetAddOnDependencies(id))
	end

	-- Addon is loaded, but it's incompatible, dependencies aren't demand loaded or it's disabled so
	-- it can't be lod
	if isLoaded or reason == "INCOMPATIBLE" or reason == "DEP_NOT_DEMAND_LOADED" or reason == "DISABLED" then
		isLoD = nil
	end

	-- Mass if statement to determine both what the status of the addon is and the coloring to use
	local color
	if reason then
		color = STATUS_COLORS[reason]
		reason = _G["ADDON_" .. reason]

	-- Load on Demand
	elseif loadable and isLoD and not isLoaded and enabled then
		reason = L["Loadable on Demand"]
		color = STATUS_COLORS["LOAD_ON_DEMAND"]

	-- Currently loaded, but will be disabled at reload
	elseif isLoaded and not enabled then
		reason = L["Disabled on UI Reload"]
		color = STATUS_COLORS["DISABLED_AT_RELOAD"]

	-- Addon is LoD, but it was already loaded/enabled so dont show the button
	elseif isLoD and isLoaded and enabled then
		reason = L["Is Loadable on Demand but already loaded"]

	-- Addon is enabled, but isn't LoD so enabled on reload
	elseif not isLoaded and enabled then
		reason = L["Enabled on UI Reload"]
		color = STATUS_COLORS["NOT_DEMAND_LOADED"]

	-- Addon is disabled
	elseif not enabled then
		reason = TEXT(ADDON_DISABLED)
		color = STATUS_COLORS["DISABLED"]
	else
		reason = L["Loaded"]
	end

	local author = GetAddOnMetadata(id, "Author")
	if author then
		author = strtrim(author)
	end

	-- Strip out common version strings that are used sometimes
	local version = GetAddOnMetadata(id, "Version") -- @Phanx: Fixed from "Version: %s" so it will actually get the metadata.
	if version then
		version = gsub(version, "%$Revision: (%d+) %$", "r%1")
		version = gsub(version, "%$Rev: (%d+) %$", "r%1")
		version = gsub(version, "%$LastChangedRevision: (%d+) %$", "r%1")
		version = strtrim(version)
	end

	-- Strip out -Ace2- as it just wastes space
	title = gsub(title or id, "%-(.+)%-%|r", "|r")

	-- Create the tooltip
	local tooltip = "|cffffffff" .. title .. "|r"
	if author then
		tooltip = tooltip .. "\n" .. format(L["|cffd8d8d8Author:|r %s"], author)
	end
	if version then
		tooltip = tooltip .. "\n" .. format(L["|cffd8d8d8Version:|r %s"], version)
	end
	if notes then
		tooltip = tooltip .. "\n" .. format(L["|cffd8d8d8Notes:|r %s"], notes)
	end

	-- Figure out the addon status and cache it
	if color then
		addonStatus[name] = color .. title .. "|r"
	else
		addonStatus[name] = title
	end

	-- Try and recycle the table entry if we can
	local newEntry, addon = true
	for _, data in pairs(addons) do
		if data.name == name then
			addon = data
			newEntry = nil
			break
		end
	end

	addon = addon or {}
	addon.name = name
	addon.id = id
	addon.color = color
	addon.title = title
	addon.author = author
	addon.version = version
	addon.tooltip = tooltip
	addon.reason = reason or ""
	addon.isEnabled = enabled
	addon.isLoD = isLoD
	addon.totalDependencies = 0

	if newEntry then
		tinsert(addons, addon)
	end
end

local function createManageList()
	-- While you can access Blizzard addons with the addon APIs, they aren't actually returned
	-- by any of the count APIs so a manual list is kept
	for _, name in pairs(blizzardAddons) do
		saveAddonData(name)
	end

	for id = 1, GetNumAddOns() do
		saveAddonData(id)
	end
end

-- ADDDON ENABLING/LOADING
local function loadAddon(self)
	LoadAddOn(self.addon)

	saveAddonData(self.addon)
	updateManageList()
end

local function activateChildren(children)
	for _, child in pairs(children) do
		EnableAddOn(child)
		saveAddonData(child)
	end

	updateManageList()
end

local function activateAddon(addon, useDeps)
	EnableAddOn(addon)
	saveAddonData(addon)

	if useDeps and dependencies[addon] then
		for dep, _ in pairs(dependencies[addon]) do
			local _, _, _, enabled = GetAddOnInfo(dep)
			if not enabled then
				EnableAddOn(dep)
				saveAddonData(dep)
			end
		end
	end

	updateManageList()
end

-- Toggle addon on
local function toggleAddonStatus(self)
	-- Addons disabled
	local _, _, _, enabled = GetAddOnInfo(self.addon)
	if enabled then
		PlaySound("igMainMenuOptionCheckBoxOff")
		DisableAddOn(self.addon)
		saveAddonData(self.addon)
		updateManageList()
		return
	end

	PlaySound("igMainMenuOptionCheckBoxOn")

	-- ENABLING THE DEPENDENCIES OF AN ADDON
	-- Ask before enabling children
	if not StaticPopupDialogs["ENABLE_ADDON_DEPS"] then
		StaticPopupDialogs["ENABLE_ADDON_DEPS"] = {
			button1 = YES,
			button2 = NO,
			OnAccept = function(dialog, id)
				activateAddon(id, true)
			end,
			OnCancel = function(dialog, id)
				activateAddon(id)
			end,
			timeout = 0,
			whileDead = 1,
			hideOnEscape = 1,
			multiple = 1,
		}
	end

	local totalDependencies = 0
	if dependencies[self.addon] then
		for dep, _ in pairs(dependencies[self.addon]) do
			local _, _, _, enabled = GetAddOnInfo(dep)
			if not enabled then
				totalDependencies = totalDependencies + 1
			end
		end
	end

	if totalDependencies > 0 then
		if totalDependencies > 1 then
			StaticPopupDialogs["ENABLE_ADDON_DEPS"].text = L["Would you like to enable the %d dependencies for %s?"]
		else
			StaticPopupDialogs["ENABLE_ADDON_DEPS"].text = L["Would you like to enable the %d dependency for %s?"]
		end

		-- damn you slouken =(
		local dialog = StaticPopup_Show("ENABLE_ADDON_DEPS", totalDependencies, self.addon)
		if dialog then
			dialog.data = self.addon
		end
	else
		activateAddon(self.addon)
	end

	-- ENABLING THE CHILDREN OF AN ADDON
	-- BigWigs, LightHeaded (damn clad), ect
	-- Find all of the addons with us as a dependency
	local children = {}
	for i = 1, GetNumAddOns() do
		local _, _, _, enabled = GetAddOnInfo(i)
		if not enabled and isAddonChildOf(self.addon, GetAddOnDependencies(i)) then
			tinsert(children, i)
		end
	end

	if #children > 0 then
		if not StaticPopupDialogs["ENABLE_ADDON_CHILDREN"] then
			StaticPopupDialogs["ENABLE_ADDON_CHILDREN"] = {
				button1 = YES,
				button2 = NO,
				OnAccept = function(dialog, children)
					activateChildren(children)
				end,
				timeout = 0,
				whileDead = 1,
				hideOnEscape = 1,
				multiple = 1,
			}
		end

		if #children > 1 then
			StaticPopupDialogs["ENABLE_ADDON_CHILDREN"].text = L["Would you like to enable the %s children addons for %s?"]
		else
			StaticPopupDialogs["ENABLE_ADDON_CHILDREN"].text = L["Would you like to enable the %s child addon for %s?"]
		end

		local dialog = StaticPopup_Show("ENABLE_ADDON_CHILDREN", #children, self.addon)
		if dialog then
			dialog.data = children
		end
	end
end

local function showTooltip(self)
	if self.text then
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 230)
		GameTooltip:SetText(self.text, nil, nil, nil, nil, 1)
	end
end

local function hideTooltip()
	GameTooltip:Hide()
end

local function createRows()
	frame.rows = {}
	for id = 1, TOTAL_ROWS do
		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(22)
		row:SetWidth(1)
		row.parents = {}
		frame.rows[id] = row

		-- Enable checkbox
		row.enabled = CreateFrame("CheckButton", "OptionHouseFrameAddonsRowCheck" .. id, row, "OptionsCheckButtonTemplate")
		row.enabled:SetWidth(22)
		row.enabled:SetHeight(22)
		row.enabled:SetHitRectInsets(0, -215, 0, 0)
		row.enabled:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.enabled:SetScript("OnClick", toggleAddonStatus)
		row.enabled:SetScript("OnEnter", showTooltip)
		row.enabled:SetScript("OnLeave", hideTooltip)

		-- Addon status, loaded, need to ldo etc
		row.reason = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.reason:SetHeight(22)
		row.reason:SetJustifyV("CENTER")

		-- Load a LoD addon
		row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.button:SetWidth(50)
		row.button:SetHeight(18)
		row.button:SetPoint("RIGHT", row, "RIGHT", -3, 0)
		row.button:SetText(L["Load"])
		row.button:SetScript("OnClick", loadAddon)

		-- Addon title
		row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.title:SetWidth(190)
		row.title:SetHeight(20)
		row.title:SetJustifyH("LEFT")
		row.title:SetJustifyV("CENTER")
		row.title:SetPoint("LEFT", row.enabled, "RIGHT", 0, 0)
		row.title:SetNonSpaceWrap(false)

		if id > 1 then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame.rows[id - 1], "BOTTOMLEFT", 0, 0)
			row:SetPoint("TOPRIGHT", frame.rows[id - 1], "BOTTOMRIGHT", 0, 0)
		else
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -96)
			row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, 0)
		end
	end
end

local function createManageFrame(hide)
	if frame then
		if hide then
			frame:Hide()
		else
			frame:Show()
		end
		return
	end

	frame = CreateFrame("Frame", nil, OptionHouse.frame)
	frame.sortOrder = true
	frame.sortType = "name"
	frame.sortButtons = {}
	frame:SetAllPoints(OptionHouse.frame)
	frame:Hide()
	frame:SetScript("OnShow", function(self)
		self:RegisterEvent("ADDON_LOADED")
		createManageList()
		updateManageList()
	end)
	frame:SetScript("OnHide", function(self)
		self:UnregisterEvent("ADDON_LOADED")
	end)
	frame:SetScript("OnEvent", function(self, event, addon)
		saveAddonData(addon)
		updateManageList()
	end)

	-- Misc status button things on the bottom right
	local disableAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	disableAll:SetWidth(80)
	disableAll:SetHeight(22)
	disableAll:SetPoint("BOTTOMRIGHT", OptionHouse.frame, "BOTTOMRIGHT", -8, 14)
	disableAll:SetText(L["Disable All"])
	disableAll:SetScript("OnClick", function()
		DisableAllAddOns()
		EnableAddOn("AddonLoader")
		EnableAddOn("OptionHouse")
		createManageList()
		updateManageList()
	end)

	local enableAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	enableAll:SetWidth(80)
	enableAll:SetHeight(22)
	enableAll:SetPoint("RIGHT", disableAll, "LEFT")
	enableAll:SetText(L["Enable All"])
	enableAll:SetScript("OnClick", function()
		EnableAllAddOns()
		createManageList()
		updateManageList()
	end)

	local reloadUI = CreateFrame("Button", nil, frame, "UIPanelButtonGrayTemplate")
	reloadUI:SetWidth(80)
	reloadUI:SetHeight(22)
	reloadUI:SetPoint("RIGHT", enableAll, "LEFT")
	reloadUI:SetText(L["Reload UI"])
	reloadUI:SetScript("OnClick", ReloadUI)

	local info = {}

	local profile = CreateFrame("Frame", "OptionHouseProfileDropdown", frame, "UIDropDownMenuTemplate")
	profile.text = _G[profile:GetName().."Text"]
	profile.text:SetText("Profiles")
	profile:SetPoint("RIGHT", reloadUI, "LEFT", -110, 0)
	profile.initialize = function(self, level)
		wipe(info)

		if level == 1 then
			local profiles = {}
			for name in pairs(OptionHouseProfiles) do
				tinsert(profiles, name)
			end
			sort(profiles)

			info.hasArrow = 1
			info.keepShownOnClick = 1
			info.notCheckable = 1

			for i = 1, #profiles do
				info.text = profiles[i]
				info.value = profiles[i]
				UIDropDownMenu_AddButton(info, level)
			end

			info.value = nil
			info.hasArrow = nil
			info.keepShownOnClick = nil

			info.text = "New profile..." -- L["New profile..."]
			info.func = function()
				if not StaticPopupDialogs["OPTIONHOUSE_NEW_PROFILE"] then
					StaticPopupDialogs["OPTIONHOUSE_NEW_PROFILE"] = {
						text = "Enter a name for the new profile:",
						button1 = ACCEPT,
						button2 = CANCEL,
						exclusive = 1,
						hasEditBox = 1,
						hideOnEscape = 1,
						maxLetters = 24,
						timeout = 0,
						whileDead = 1,
						OnAccept = function(self)
							local profile = strtrim(self.editBox:GetText() or "")
							if strlen(profile) == 0 then
								profile = "New profile"
							end
							if OptionHouseProfiles[profile] then
								local i = 1
								local newtext = profile .. " " .. i
								while OptionHouseProfiles[profile] do
									i = i + 1
									newtext = profile .. " " .. i
								end
								profile = newtext
							end
							local addons = {}
							for i = 1, GetNumAddOns() do
								local name, _, _, enabled = GetAddOnInfo(i)
								if enabled then
									addons[name] = true
								end
							end
							OptionHouseProfiles[profile] = addons
							print("Created new profile:", profile)
						end,
						EditBoxOnEnterPressed = function(self)
							self:GetParent().button1:Click()
						end,
						OnShow = function(self)
							self.editBox:SetFocus()
						end,
						OnHide = function(self)
							ChatEdit_FocusActiveWindow()
							self.editBox:SetText("")
						end,
					}
				end
				CloseDropDownMenus()
				StaticPopup_Show("OPTIONHOUSE_NEW_PROFILE")
			end
			UIDropDownMenu_AddButton(info, level)
		elseif level == 2 then
			local profile = UIDROPDOWNMENU_MENU_VALUE
			if not profile or not OptionHouseProfiles[profile] then return end

			info.text = profile
			info.isTitle = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			info.disabled = nil
			info.isTitle = nil

			info.text = "Load"
			info.func = function()
				local addons = OptionHouseProfiles[profile]
				for i = 1, GetNumAddOns() do
					local name = GetAddOnInfo(i)
					if addons[name] then
						EnableAddOn(i)
					else
						DisableAddOn(i)
					end
					saveAddonData(i)
				end
				updateManageList()
				print("Loaded profile:", profile)
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)

			info.text = "Save"
			info.func = function()
				-- save the currently selected addons to this profile
				local addons = OptionHouseProfiles[profile]
				wipe(addons)
				for i = 1, GetNumAddOns() do
					local name, _, _, enabled = GetAddOnInfo(i)
					if enabled then
						addons[name] = true
					end
				end
				print("Saved profile:", profile)
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)

			info.text = "Rename"
			info.func = function(this)
				-- rename this profile
				if not StaticPopupDialogs["OPTIONHOUSE_RENAME_PROFILE"] then
					StaticPopupDialogs["OPTIONHOUSE_RENAME_PROFILE"] = {
						text = "Enter a new name for this profile:",
						button1 = ACCEPT,
						button2 = CANCEL,
						exclusive = 1,
						hasEditBox = 1,
						hideOnEscape = 1,
						maxLetters = 24,
						timeout = 0,
						whileDead = 1,
						OnAccept = function(self)
							local profile = strtrim(self.editBox:GetText() or "")
							if strlen(profile) == 0 then
								profile = "New profile"
							end
							if OptionHouseProfiles[profile] then
								local i = 1
								local newtext = profile .. " " .. i
								while OptionHouseProfiles[profile] do
									i = i + 1
									newtext = profile .. " " .. i
								end
								profile = newtext
							end
							OptionHouseProfiles[profile] = OptionHouseProfiles[self.data]
							OptionHouseProfiles[self.data] = nil
							print("Renamed profile:", self.data, "->", profile)
						end,
						EditBoxOnEnterPressed = function(self)
							self:GetParent().button1:Click()
						end,
						OnShow = function(self)
							self.editBox:SetText(self.data)
							self.editBox:SetFocus()
							self.editBox:HighlightText(0)
						end,
						OnHide = function(self)
							ChatEdit_FocusActiveWindow()
							self.editBox:SetText("")
							self.data = nil
						end,
					}
				end
				CloseDropDownMenus()
				StaticPopup_Show("OPTIONHOUSE_RENAME_PROFILE", nil, nil, profile)
			end
			UIDropDownMenu_AddButton(info, level)

			info.text = "Delete"
			info.func = function()
				-- remove this profile
				OptionHouseProfiles[profile] = nil
				print("Deleted profile:", profile)
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end

	-- Sorting headers
	local button = CreateFrame("Button", nil, frame)
	button:SetScript("OnClick", sortManageClick)
	button:SetHeight(20)
	button:SetWidth(75)
	button:SetNormalFontObject(GameFontNormal)
	button.sortType = "name"
	button:SetText(L["Name"])
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -73)
	button:Show()

	frame.sortButtons.title = button

	button = CreateFrame("Button", nil, frame)
	button:SetScript("OnClick", sortManageClick)
	button:SetHeight(20)
	button:SetWidth(75)
	button:SetNormalFontObject(GameFontNormal)
	button.sortType = "totalDependencies"
	button:SetText(L["Dependencies"])
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame, "TOPLEFT", 260, -73)
	button:Show()

	frame.sortButtons.dependencies = button

	button = CreateFrame("Button", nil, frame)
	button:SetScript("OnClick", sortManageClick)
	button:SetHeight(20)
	button:SetWidth(75)
	button:SetNormalFontObject(GameFontNormal)
	button.sortType = "reason"
	button:SetText(L["Status"])
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, -73)
	button:Show()

	frame.sortButtons.status = button

	-- Creates the search input in the bottom left of the screen
	OptionHouse:CreateSearchInput(frame, updateManageList)

	-- Create all of the rows for display
	createRows()

	OptionHouse:CreateScrollFrame(frame, TOTAL_ROWS, updateManageList)

	frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -76)
	frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 72)

	frame:Show()
end

-- Load it into OH
OptionHouse:RegisterTab(L["Management"], createManageFrame, "Bid")