local Performance = {}
local OPTIONHOUSE, L = ...
local frame, scriptProfiling
local TOTAL_ROWS = 15

local gsub, pairs, sort, strfind, strlower, tinsert
    = gsub, pairs, sort, strfind, strlower, tinsert

local CURRENT_SELECTION

local function sortPerformanceList(a, b)
	if not b then
		return false
	elseif frame.sortOrder then
		local sortType = frame.sortType
		if sortType == "name" or a[sortType] == b[sortType] then
			return strlower(a.title) < strlower(b.title)
		end
		return a[sortType] < b[sortType]
	else
		local sortType = frame.sortType
		if sortType == "name" or a[sortType] == b[sortType] then
			return strlower(a.title) > strlower(b.title)
		end
		return a[sortType] > b[sortType]
	end
end

local function updateAddonPerformance()
	UpdateAddOnMemoryUsage()
	UpdateAddOnCPUUsage()

	local totalMemory = 0
	local totalCPU = 0
	local totalMIR = 0
	local totalCIR = 0

	for id, addon in pairs(frame.addons) do
		local memory = GetAddOnMemoryUsage(addon.name)
		local cpu = GetAddOnCPUUsage(addon.name)

		frame.addons[id].mir = memory - addon.memory
		frame.addons[id].cir = cpu - addon.cpu
		frame.addons[id].memory = memory
		frame.addons[id].cpu = cpu

		totalMemory = totalMemory + memory
		totalCPU = totalCPU + cpu
		totalMIR = totalMIR + frame.addons[id].mir
		totalCIR = totalCIR + frame.addons[id].cir
	end

	for id, addon in pairs(frame.addons) do
		frame.addons[id].cpuPerct = frame.addons[id].cpu / totalCPU * 100
		frame.addons[id].memPerct = frame.addons[id].memory / totalMemory * 100
	end

	frame.totalMemory = totalMemory
	frame.totalCPU = totalCPU
	frame.totalMIR = totalMIR
	frame.totalCIR = totalCIR
end

local function updatePerformanceList()
	if frame.totalMemory > 1024 then
		frame.sortButtons.memory:SetFormattedText("|cffffffff%.1f MiB|r\n\n%s", frame.totalMemory / 1024, L["Memory"])
	else
		frame.sortButtons.memory:SetFormattedText("|cffffffff%.1f KiB|r\n\n%s", frame.totalMemory, L["Memory"])
	end

	if frame.totalMIR > 1024 then
		frame.sortButtons.memsec:SetFormattedText(L["|cffffffff%.2f MiB/s|r\n\nMem/Sec"], frame.totalMIR / 1024)
	else
		frame.sortButtons.memsec:SetFormattedText(L["|cffffffff%.2f KiB/s|r\n\nMem/Sec"], frame.totalMIR)
	end

	if scriptProfiling then
		if frame.totalCPU > 999999 then
			frame.sortButtons.cpu:SetFormattedText("|cffffffff%.2fm|r\n\n%s", frame.totalCPU / 1000000, L["CPU"])
		elseif frame.totalCPU > 9999 then
			frame.sortButtons.cpu:SetFormattedText("|cffffffff%.2fk|r\n\n%s", frame.totalCPU / 1000, L["CPU"])
		else
			frame.sortButtons.cpu:SetFormattedText("|cffffffff%d|r\n\n%s", frame.totalCPU, L["CPU"])
		end
		frame.sortButtons.cpusec:SetFormattedText("|cffffffff%.2f|r\n\n%s", frame.totalCIR, L["CPU/Sec"])
	end

	sort(frame.addons, sortPerformanceList)
	OptionHouse:UpdateScroll(frame.scroll, #(frame.addons))

	for id, row in pairs(frame.rows) do
		local addon = frame.addons[frame.scroll.offset + id]
		if addon then
			row.title:SetText(addon.title)
			row.highlight:SetDrawLayer(addon.title == CURRENT_SELECTION and "BACKGROUND" or "HIGHLIGHT")

			if addon.memory > 1024 then
				row.memory:SetFormattedText(L["%.3f MiB (%.2f%%)"], addon.memory / 1024, addon.memPerct)
			else
				row.memory:SetFormattedText(L["%.3f KiB (%.2f%%)"], addon.memory, addon.memPerct)
			end

			if addon.mir > 1024 then
				row.memsec:SetFormattedText(L["%.3f MiB/s"], addon.mir / 1024)
			else
				row.memsec:SetFormattedText(L["%.3f KiB/s"], addon.mir)
			end

			if scriptProfiling then
				row.cpu:SetFormattedText("%.3f (%.2f%%)", addon.cpu, addon.cpuPerct)
				row.cpusec:SetFormattedText("%.3f", addon.cir)
			else
				row.cpu:SetText("----")
				row.cpusec:SetText("----")
			end

			row:Show()
		else
			row:Hide()
		end
	end
end

local elapsed = 0
local function performanceOnUpdate(self, time)
	elapsed = elapsed + time
	if elapsed >= 1 then
		elapsed = 0
		updateAddonPerformance()
		updatePerformanceList()
	end
end

local function sortPerfClick(self)
	if self.sortType then
		if self.sortType ~= frame.sortType then
			frame.sortOrder = false
			frame.sortType = self.sortType
		else
			frame.sortOrder = not frame.sortOrder
		end
		updatePerformanceList()
	end
end

-- Create a list now so we aren't creating a new table/list every OnUpdate
local function updateAddonPerfList()
	UpdateAddOnMemoryUsage()
	UpdateAddOnCPUUsage()

	local searchBy = string.trim(strlower(frame.search:GetText()))
	if searchBy == "" or frame.search.searchText then
		searchBy = nil
	end

	frame.addons = {}
	for i = 1, GetNumAddOns() do
		local name, title = GetAddOnInfo(i)
		if IsAddOnLoaded(i) and (not searchBy or strfind(strlower(name), searchBy)) then
			tinsert(frame.addons, {
				name = name,
				title = gsub(title, "%|cff7fff7f %-(.+)%-%|r", ""),
				mir = 0,
				cir = 0,
				cpu = GetAddOnCPUUsage(i),
				memory = GetAddOnMemoryUsage(i)
			})
		end
	end
end

local function createRows()
	frame.rows = {}

	local function rowClick(self)
		CURRENT_SELECTION = self.title:GetText()
		updatePerformanceList()
	end

	for id = 1, TOTAL_ROWS do
		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(22)
		row:SetWidth(1)

		row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.title:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.title:SetSize(225, 20)
		row.title:SetJustifyH("LEFT")

		row.memory = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.memory:SetPoint("LEFT", row.title, "RIGHT", 3, 0)
		row.memory:SetSize(175, 20)
		row.memory:SetJustifyH("RIGHT")

		row.memsec = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.memsec:SetPoint("LEFT", row.memory, "RIGHT", 3, 0)
		row.memsec:SetSize(145, 20)
		row.memsec:SetJustifyH("RIGHT")

		row.cpu = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.cpu:SetPoint("LEFT", row.memsec, "RIGHT", 3, 0)
		row.cpu:SetSize(125, 20)
		row.cpu:SetJustifyH("RIGHT")

		row.cpusec = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.cpusec:SetPoint("LEFT", row.cpu, "RIGHT", 3, 0)
		row.cpusec:SetSize(95, 20)
		row.cpusec:SetJustifyH("RIGHT")

		row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
		row.highlight:SetAllPoints(true)
		row.highlight:SetBlendMode("ADD")
		row.highlight:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-HighlightBar-Blue]])
		row.highlight:SetAlpha(0.5)

		row:EnableMouse(true)
		row:SetScript("OnMouseUp", rowClick)

		if id > 1 then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame.rows[id - 1], "BOTTOMLEFT", 0, 0)
			row:SetPoint("TOPRIGHT", frame.rows[id - 1], "BOTTOMRIGHT", 0, 0)
		else
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -88)
			row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -88)
		end

		frame.rows[id] = row
	end
end

local function createPerfFrame(hide)
	if frame then
		if hide then
			frame:Hide()
		else
			frame:Show()
		end
		return
	end

	frame = CreateFrame("Frame", nil, OptionHouse.frame)
	frame:SetAllPoints(OptionHouse.frame)
	frame:Hide()

	frame.sortOrder = nil
	frame.sortType = "name"
	frame.sortButtons = {}

	frame:SetScript("OnShow", function(self)
		updateAddonPerfList()
		updateAddonPerformance()
		updatePerformanceList()
		self:RegisterEvent("ADDON_LOADED")
	end)
	frame:SetScript("OnHide", function(self)
		self:UnregisterEvent("ADDON_LOADED")
	end)
	frame:SetScript("OnUpdate", performanceOnUpdate)
	frame:SetScript("OnEvent", updatePerformanceList)

	-- Sort headers

	local button = CreateFrame("Button", nil, frame)
	button:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -68)
	button:SetSize(225, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMLEFT")
	button:GetFontString():SetJustifyH("LEFT")
	button:SetText(L["Name"])
	button.sortType = "name"
	button:SetScript("OnClick", sortPerfClick)
	frame.sortButtons.title = button

	local button = CreateFrame("Button", nil, frame)
	button:SetPoint("LEFT", frame.sortButtons.title, "RIGHT", 3, 0)
	button:SetSize(175, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMRIGHT")
	button:GetFontString():SetJustifyH("RIGHT")
	button:SetText(L["Memory"])
	button.sortType = "memory"
	button:SetScript("OnClick", sortPerfClick)
	frame.sortButtons.memory = button

	local button = CreateFrame("Button", nil, frame)
	button:SetPoint("LEFT", frame.sortButtons.memory, "RIGHT", 3, 0)
	button:SetSize(145, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMRIGHT")
	button:GetFontString():SetJustifyH("RIGHT")
	button:SetText(L["Mem/Sec"])
	button.sortType = "mir"
	button:SetScript("OnClick", sortPerfClick)
	frame.sortButtons.memsec = button

	local button = CreateFrame("Button", nil, frame)
	button:SetPoint("LEFT", frame.sortButtons.memsec, "RIGHT", 3, 0)
	button:SetSize(125, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMRIGHT")
	button:GetFontString():SetJustifyH("RIGHT")
	button:SetText(L["CPU"])
	button.sortType = "cpu"
	button:SetScript("OnClick", sortPerfClick)
	frame.sortButtons.cpu = button

	local button = CreateFrame("Button", nil, frame)
	button:SetPoint("LEFT", frame.sortButtons.cpu, "RIGHT", 3, 0)
	button:SetSize(95, 18)
	button:SetFontString(button:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	button:GetFontString():SetPoint("BOTTOMRIGHT")
	button:GetFontString():SetJustifyH("RIGHT")
	button:SetText(L["CPU/Sec"])
	button.sortType = "cir"
	button:SetScript("OnClick", sortPerfClick)
	frame.sortButtons.cpusec = button

	createRows()

	OptionHouse:CreateScrollFrame(frame, TOTAL_ROWS, updatePerformanceList)
	OptionHouse:CreateSearchInput(frame, function()
		updateAddonPerfList()
		updateAddonPerformance()
		updatePerformanceList()
	end)

	-- Buttons on bottom right
	local toggleCPU = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	toggleCPU:SetWidth(120)
	toggleCPU:SetHeight(22)
	toggleCPU:SetPoint("BOTTOMRIGHT", OptionHouse.frame, "BOTTOMRIGHT", -8, 4)
	toggleCPU:SetScript("OnClick", function(self)
		if GetCVar("scriptProfile") == "1" then
			self:SetText(L["Enable CPU"])
			SetCVar("scriptProfile", "0")
		else
			self:SetText(L["Disable CPU"])
			SetCVar("scriptProfile", "1")
		end
	end)

	-- UI Reload required for CPU profiling to be usable, so check on load
	if GetCVar("scriptProfile") == "1" then
		scriptProfiling = true
		toggleCPU:SetText(L["Disable CPU"])
	else
		toggleCPU:SetText(L["Enable CPU"])
	end

	local reloadUI = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") -- UIPanelButtonGrayTemplate
	reloadUI:SetWidth(120)
	reloadUI:SetHeight(22)
	reloadUI:SetPoint("RIGHT", toggleCPU, "LEFT", -2, 0)
	reloadUI:SetText(L["Reload UI"])
	reloadUI:SetScript("OnClick", ReloadUI)
end

-- Load it into OH
OptionHouse:RegisterTab(L["Performance"], createPerfFrame, "Bid")