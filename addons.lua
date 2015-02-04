local OPTIONHOUSE, L = ...

local TOTAL_ROWS = 15
local CHARACTER = UnitName("player")

local Manage = {}
local dependencies, addons, addonStatus = {}, {}, {}
local toggleForAll, showBlizzard, frame = false

OptionHouseProfiles = {}

local blizzardAddons = {
	["Blizzard_AchievementUI"] = true,
	["Blizzard_ArchaeologyUI"] = true,
	["Blizzard_ArenaUI"] = true,
	["Blizzard_AuctionUI"] = true,
	["Blizzard_AuthChallengeUI"] = true,
	["Blizzard_BarbershopUI"] = true,
	["Blizzard_BattlefieldMinimap"] = true,
	["Blizzard_BindingUI"] = true,
	["Blizzard_BlackMarketUI"] = true,
	["Blizzard_Calendar"] = true,
	["Blizzard_ChallengesUI"] = true,
	["Blizzard_ClientSavedVariables"] = true,
	["Blizzard_CombatLog"] = true,
	["Blizzard_CombatText"] = true,
	["Blizzard_CompactRaidFrames"] = true,
	["Blizzard_CUFProfiles"] = true,
	["Blizzard_DebugTools"] = true,
	["Blizzard_EncounterJournal"] = true,
	["Blizzard_GarrisonUI"] = true,
	["Blizzard_GlyphUI"] = true,
	["Blizzard_GMChatUI"] = true,
	["Blizzard_GMSurveyUI"] = true,
	["Blizzard_GuildBankUI"] = true,
	["Blizzard_GuildControlUI"] = true,
	["Blizzard_GuildUI"] = true,
	["Blizzard_InspectUI"] = true,
	["Blizzard_ItemAlterationUI"] = true,
	["Blizzard_ItemSocketingUI"] = true,
	["Blizzard_ItemUpgradeUI"] = true,
	["Blizzard_LookingForGuildUI"] = true,
	["Blizzard_MacroUI"] = true,
	["Blizzard_MovePad"] = true,
	["Blizzard_ObjectiveTracker"] = true,
	["Blizzard_PetBattleUI"] = true,
	["Blizzard_PetJournal"] = true,
	["Blizzard_PVPUI"] = true,
	["Blizzard_QuestChoice"] = true,
	["Blizzard_RaidUI"] = true,
	["Blizzard_StoreUI"] = true,
	["Blizzard_TalentUI"] = true,
	["Blizzard_TimeManager"] = true,
	["Blizzard_TokenUI"] = true,
	["Blizzard_TradeSkillUI"] = true,
	["Blizzard_TrainerUI"] = true,
	["Blizzard_Tutorial"] = true,
	["Blizzard_VoidStorageUI"] = true,
}
for name in pairs(blizzardAddons) do
	if select(6, GetAddOnInfo(name)) == "MISSING" then
		blizzardAddons[name] = nil
	end
end

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
		if addon.isBlizzard and not showBlizzard then
			addons[id].hide = true
		elseif searchBy and not strfind(strlower(addon.title), searchBy) then
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

				row.title:SetFormattedText("%s%s|r", addon.isEnabled and (addon.isBlizzard and BATTLENET_FONT_COLOR_CODE or addon.isLibrary and NORMAL_FONT_COLOR_CODE) or addon.color or "", addon.title)
				row.reason:SetFormattedText("%s%s|r", addon.color or "", addon.reason)

				row.enabled.tooltip = addon.tooltip
				row.enabled.title = addon.title
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

				for _, parent in pairs(row.parents) do
					parent:Hide()
				end
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

	for i = usedRows + 1, #frame.rows do
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
	local name, title, notes, loadable, reason, security = GetAddOnInfo(id)
	local enabled = GetAddOnEnableState(CHARACTER, id) > 0

	local isLoaded = IsAddOnLoaded(id)
	local isLoD = IsAddOnLoadOnDemand(id)
	local isBlizzard = not not blizzardAddons[id]

	local isLibrary
	if isBlizzard then
		title = name:gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
	elseif strmatch(name, "^Lib[%u%W]") or strmatch(title, "^Lib[%u%W]") then
		isLibrary = true
	end

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
		reason = ADDON_DISABLED
		color = STATUS_COLORS["DISABLED"]

	else
		reason = L["Loaded"]
	end

	local author = GetAddOnMetadata(id, "Author")
	if author then
		author = strtrim(author)
	end

	-- Strip out common version strings that are used sometimes
	local version = GetAddOnMetadata(id, "Version") or GetAddOnMetadata(id, "X-Curse-Packaged-Version")
	if version then
		version = gsub(version, "^v(%d.+)", "%1")
		version = gsub(version, "@project-r?e?v[ei]r?sion@", "Development")
		version = gsub(version, "%$Revision: (%d+) %$", "r%1")
		version = gsub(version, "%$Rev: (%d+) %$", "r%1")
		version = gsub(version, "%$LastChangedRevision: (%d+) %$", "r%1")
		version = strtrim(version)
	end

	-- Strip out colors and tags like -Ace2- as it just wastes space
	if not title then
		title = name
	else
		title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(" %-(.+)%-", "")
	end

	-- Create the tooltip
	local tooltip = notes
	if version then
		tooltip = tooltip and format(L["|cffffffffVersion:|r %s\n%s"], version, tooltip) or format(L["|cffffffffVersion:|r %s"], version)
	end
	if author then
		tooltip = tooltip and format(L["|cffffffffAuthor:|r %s\n%s"], author, tooltip) or format(L["|cffffffffAuthor:|r %s"], author)
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

	addon.isBlizzard = isBlizzard
	addon.isLibrary = isLibrary

	if newEntry then
		tinsert(addons, addon)
	end
end

local function createManageList()
	-- While you can access Blizzard addons with the addon APIs, they aren't actually returned
	-- by any of the count APIs so a manual list is kept
	for name in pairs(blizzardAddons) do
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
		EnableAddOn(child, toggleForAll)
		saveAddonData(child)
	end

	updateManageList()
end

local function activateAddon(addon, useDeps)
	EnableAddOn(addon, toggleForAll)
	saveAddonData(addon)

	if useDeps and dependencies[addon] then
		for dep in pairs(dependencies[addon]) do
			if GetAddOnEnableState(CHARACTER, dep) == 0 then
				EnableAddOn(dep, toggleForAll)
				saveAddonData(dep)
			end
		end
	end

	updateManageList()
end

local function deactivateAddon(addon)
	DisableAddOn(addon, toggleForAll)
	saveAddonData(addon)
	updateManageList()
end

-- Toggle addon on
local function toggleAddonStatus(self)
	-- Addons disabled
	if GetAddOnEnableState(CHARACTER, self.addon) > 0 then
		PlaySound("igMainMenuOptionCheckBoxOff")
		return deactivateAddon(self.addon)
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	activateAddon(self.addon)
end

local function showTooltip(self)
	self:GetParent().highlight:SetDrawLayer("ARTWORK")
	if self.tooltip then
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 230)
		GameTooltip:SetText(self.title, 1, 1, 1)
		GameTooltip:AddLine(self.tooltip, nil, nil, nil, 1)
		GameTooltip:Show()
	end
end

local function hideTooltip(self)
	self:GetParent().highlight:SetDrawLayer("HIGHLIGHT")
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
		row.enabled = CreateFrame("CheckButton", nil, row, "OptionsCheckButtonTemplate")
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
		row.button:SetSize(50, 18)
		row.button:SetPoint("RIGHT", row, "RIGHT", -3, 0)
		row.button:SetText(L["Load"])
		row.button:SetScript("OnClick", loadAddon)

		-- Addon title
		row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.title:SetSize(230, 22)
		row.title:SetJustifyH("LEFT")
		row.title:SetJustifyV("CENTER")
		row.title:SetPoint("LEFT", row.enabled, "RIGHT", 0, 0)
		row.title:SetNonSpaceWrap(false)

		-- Highlight texture
		row:EnableMouse(true)
		row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
		row.highlight:SetAllPoints(true)
		row.highlight:SetBlendMode("ADD")
		row.highlight:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-HighlightBar-Blue]])
		row.highlight:SetAlpha(0.5)

		if id > 1 then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame.rows[id - 1], "BOTTOMLEFT", 0, 0)
			row:SetPoint("TOPRIGHT", frame.rows[id - 1], "BOTTOMRIGHT", 0, 0)
		else
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -88)
			row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -88)
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

	frame = CreateFrame("Frame", "$parentManagement", OptionHouse.frame)
	frame:SetAllPoints(true)
	frame:Hide()

	frame.sortButtons = {}
	frame.sortOrder = true
	frame.sortType = "name"

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

	-- Sorting headers
	local button = CreateFrame("Button", nil, frame)
	button:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -68)
	button:SetSize(275, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMLEFT")
	button:GetFontString():SetJustifyH("LEFT")
	button:SetText(L["Name"])
	button.sortType = "name"
	button:SetScript("OnClick", sortManageClick)
	frame.sortButtons.title = button

	button = CreateFrame("Button", nil, frame)
	button:SetPoint("LEFT", frame.sortButtons.title, "RIGHT", 3, 0)
	button:SetSize(75, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMLEFT")
	button:GetFontString():SetJustifyH("LEFT")
	button:SetText(L["Dependencies"])
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button.sortType = "totalDependencies"
	button:SetScript("OnClick", sortManageClick)
	frame.sortButtons.dependencies = button

	button = CreateFrame("Button", nil, frame)
	button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -68)
	button:SetSize(75, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMRIGHT")
	button:GetFontString():SetJustifyH("RIGHT")
	button:SetText(L["Status"])
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button.sortType = "reason"
	button:SetScript("OnClick", sortManageClick)
	frame.sortButtons.status = button

	createRows()

	OptionHouse:CreateScrollFrame(frame, TOTAL_ROWS, updateManageList)
	OptionHouse:CreateSearchInput(frame, updateManageList)

	-- Misc status button things on the bottom right
	local disableAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	disableAll:SetWidth(120)
	disableAll:SetHeight(22)
	disableAll:SetPoint("BOTTOMRIGHT", OptionHouse.frame, "BOTTOMRIGHT", -8, 4)
	disableAll:SetText(L["Disable All"])
	disableAll:SetScript("OnClick", function()
		DisableAllAddOns()
		EnableAddOn("AddonLoader")
		EnableAddOn("OptionHouse")
		createManageList()
		updateManageList()
	end)

	local enableAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	enableAll:SetWidth(120)
	enableAll:SetHeight(22)
	enableAll:SetPoint("RIGHT", disableAll, "LEFT", -2, 0)
	enableAll:SetText(L["Enable All"])
	enableAll:SetScript("OnClick", function()
		EnableAllAddOns()
		createManageList()
		updateManageList()
	end)

	local reloadUI = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") -- UIPanelButtonGrayTemplate
	reloadUI:SetWidth(120)
	reloadUI:SetHeight(22)
	reloadUI:SetPoint("RIGHT", enableAll, "LEFT", -2, 0)
	reloadUI:SetText(L["Reload UI"])
	reloadUI:SetScript("OnClick", ReloadUI)

	-- Show Blizzard addons
	local showBlizz = CreateFrame("CheckButton", "$parentShowBlizz", frame, "InterfaceOptionsCheckButtonTemplate")
	showBlizz:SetPoint("LEFT", frame.search, "RIGHT", 4, 0)
	showBlizz.Text:SetText(L["Show Blizzard AddOns"])
	showBlizz:SetHitRectInsets(0, -200, 0, 0)
	showBlizz:SetScript("OnClick", function(self)
		showBlizzard = self:GetChecked()
		updateManageList()
	end)

	-- Toggle addons globally or per-character
	local charSelect = CreateFrame("Frame", "$parentCharacterSelect", frame, "UIDropDownMenuTemplate")
	charSelect:SetPoint("TOPLEFT", 90, -30)
	charSelect.Text = _G[charSelect:GetName().."Text"]
	charSelect.Text:SetText(CHARACTER)
	charSelect.func = function(self)
		charSelect.Text:SetText(self:GetText())
		toggleForAll = self.value
		updateManageList()
	end
	charSelect.initialize = function()
		local info = UIDropDownMenu_CreateInfo()
		info.func = charSelect.func

		info.text = ALL
		info.value = true
		info.selected = toggleForAll
		UIDropDownMenu_AddButton(info)

		info.text = UnitName("player")
		info.value = false
		info.selected = not toggleForAll
		UIDropDownMenu_AddButton(info)
	end

	-- Load out of date addons
	local forceLoad = CreateFrame("CheckButton", "$parentForceLoad", frame, "InterfaceOptionsCheckButtonTemplate")
	forceLoad:SetPoint("LEFT", charSelect, "RIGHT", 116, 1)
	forceLoad.Text:SetText(ADDON_FORCE_LOAD)
	forceLoad:SetHitRectInsets(0, -200, 0, 0)
	forceLoad:SetChecked(not IsAddonVersionCheckEnabled())
	forceLoad:SetScript("OnClick", function(self)
		local on = self:GetChecked()
		PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		SetAddonVersionCheck(on)
		updateManageList()
	end)

	-- Profiles
	local profile = CreateFrame("Frame", "$parentProfile", frame, "UIDropDownMenuTemplate")
	profile:SetPoint("TOPRIGHT", -120, -30)
	_G[profile:GetName().."Text"]:SetText(L["Profiles"])

	profile.NewProfile = function()
		if not StaticPopupDialogs["OPTIONHOUSE_NEW_PROFILE"] then
			StaticPopupDialogs["OPTIONHOUSE_NEW_PROFILE"] = {
				text = L["Enter a name for the new profile:"],
				button1 = ACCEPT,
				button2 = CANCEL,
				exclusive = 1,
				hasEditBox = 1,
				hideOnEscape = 1,
				maxLetters = 24,
				timeout = 0,
				whileDead = 1,
				OnAccept = function(self)
					local name = strtrim(self.editBox:GetText() or "")
					if strlen(name) == 0 then
						name = L["New profile"]
					end
					if OptionHouseProfiles[name] then
						local i = 1
						local new = name .. " " .. i
						while OptionHouseProfiles[name] do
							i = i + 1
							new = name .. " " .. i
						end
						name = new
					end
					local saved = {}
					for _, data in pairs(addons) do
						if data.isEnabled and not data.isBlizzard then
							saved[data.name] = true
						end
					end
					OptionHouseProfiles[name] = saved
					print(format(L["Created new profile: %s"], name))
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

	profile.LoadProfile = function()
		local name = UIDROPDOWNMENU_MENU_VALUE
		if name then
			local saved = OptionHouseProfiles[name]
			for name in pairs(blizzardAddons) do
				-- Clean up old profiles
				saved[name] = nil
			end
			for _, data in pairs(addons) do
				if data.isBlizzard then
					-- do nothing
				elseif saved[data.name] and not data.isEnabled then
					activateAddon(data.name, true)
				elseif data.isEnabled and not saved[data.name] then
					deactivateAddon(data.name)
				end
			end
			print(format(L["Loaded profile: %s"], name))
		end
		CloseDropDownMenus()
	end

	profile.SaveProfile = function()
		-- save the currently selected addons to this profile
		local name = UIDROPDOWNMENU_MENU_VALUE
		local saved = OptionHouseProfiles[name]
		wipe(saved)
		for _, data in pairs(addons) do
			if data.isEnabled then
				saved[data.name] = true
			end
		end
		print(format(L["Saved profile: %s"], name))
		CloseDropDownMenus()
	end

	profile.RenameProfile = function()
		-- rename this profile
		if not StaticPopupDialogs["OPTIONHOUSE_RENAME_PROFILE"] then
			StaticPopupDialogs["OPTIONHOUSE_RENAME_PROFILE"] = {
				text = L["Enter a new name for this profile:"],
				button1 = ACCEPT,
				button2 = CANCEL,
				exclusive = 1,
				hasEditBox = 1,
				hideOnEscape = 1,
				maxLetters = 24,
				timeout = 0,
				whileDead = 1,
				OnAccept = function(self)
					local newName = strtrim(self.editBox:GetText() or "")
					if strlen(newName) == 0 then
						newName = L["New profile"]
					end
					if OptionHouseProfiles[newName] then
						local i = 1
						local newtext = newName .. " " .. i
						while OptionHouseProfiles[newName] do
							i = i + 1
							newtext = newName .. " " .. i
						end
						newName = newtext
					end
					OptionHouseProfiles[newName] = OptionHouseProfiles[self.data]
					OptionHouseProfiles[self.data] = nil
					print(format(L["Renamed profile from %s to %s."], self.data, newName))
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
		StaticPopup_Show("OPTIONHOUSE_RENAME_PROFILE", nil, nil, UIDROPDOWNMENU_MENU_VALUE)
	end

	profile.DeleteProfile = function()
		-- remove this profile
		local name = UIDROPDOWNMENU_MENU_VALUE
		OptionHouseProfiles[name] = nil
		print(format(L["Deleted profile: %s"], name))
		CloseDropDownMenus()
	end

	profile.initialize = function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		if level == 1 then
			local list = {}
			for name in pairs(OptionHouseProfiles) do
				tinsert(list, name)
			end
			sort(list)

			info.hasArrow = 1
			info.keepShownOnClick = 1
			info.notCheckable = 1

			for i = 1, #list do
				info.text = list[i]
				info.value = list[i]
				UIDropDownMenu_AddButton(info, level)
			end

			info.value = nil
			info.hasArrow = nil
			info.keepShownOnClick = nil

			info.text = L["New"]
			info.func = profile.NewProfile
			UIDropDownMenu_AddButton(info, level)
		elseif level == 2 then
			local name = UIDROPDOWNMENU_MENU_VALUE
			if not name or not OptionHouseProfiles[name] then return end

			info.text = name
			info.isTitle = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			info.disabled = nil
			info.isTitle = nil

			info.text = L["Load"]
			info.func = profile.LoadProfile
			UIDropDownMenu_AddButton(info, level)

			info.text = L["Save"]
			info.func = profile.SaveProfile
			UIDropDownMenu_AddButton(info, level)

			info.text = L["Rename"]
			info.func = profile.RenameProfile
			UIDropDownMenu_AddButton(info, level)

			info.text = L["Delete"]
			info.func = profile.DeleteProfile
			UIDropDownMenu_AddButton(info, level)
		end
	end

	frame:Show()
end

-- Load it into OH
OptionHouse:RegisterTab(L["Management"], createManageFrame)