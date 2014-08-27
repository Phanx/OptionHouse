local Performance = {}
local OPTIONHOUSE, L = ...
local frame, scriptProfiling
local TOTAL_ROWS = 14

local gsub, pairs, sort, strfind, strlower, tinsert
    = gsub, pairs, sort, strfind, strlower, tinsert

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
		frame.sortButtons.memory:SetFormattedText(L["Memory (|cffffffff%.1f MiB|r)"], frame.totalMemory / 1024)
	else
		frame.sortButtons.memory:SetFormattedText(L["Memory (|cffffffff%.1f KiB|r)"], frame.totalMemory)
	end

	if frame.totalMIR > 1024 then
		frame.sortButtons.memsec:SetFormattedText(L["Mem/Sec (|cffffffff%.2f MiB/s|r)"], frame.totalMIR / 1024)
	else
		frame.sortButtons.memsec:SetFormattedText(L["Mem/Sec (|cffffffff%.2f KiB/s|r)"], frame.totalMIR)
	end

	frame.sortButtons.memory:SetWidth(frame.sortButtons.memory:GetFontString():GetStringWidth() + 3)
	frame.sortButtons.memsec:SetWidth(frame.sortButtons.memsec:GetFontString():GetStringWidth() + 3)

	if scriptProfiling then
		if frame.totalCPU > 999999 then
			frame.sortButtons.cpu:SetFormattedText(L["CPU (|cffffffff%.2fm|r)"], frame.totalCPU / 1000000)
		elseif frame.totalCPU > 9999 then
			frame.sortButtons.cpu:SetFormattedText(L["CPU (|cffffffff%.2fk|r)"], frame.totalCPU / 1000)
		else
			frame.sortButtons.cpu:SetFormattedText(L["CPU (|cffffffff%d|r)"], frame.totalCPU)
		end

		frame.sortButtons.cpusec:SetFormattedText(L["CPU/Sec (|cffffffff%.2f|r)"], frame.totalCIR)

		frame.sortButtons.cpu:SetWidth(frame.sortButtons.cpu:GetFontString():GetStringWidth() + 3)
		frame.sortButtons.cpusec:SetWidth(frame.sortButtons.cpusec:GetFontString():GetStringWidth() + 3)
	end

	sort(frame.addons, sortPerformanceList)
	OptionHouse:UpdateScroll(frame.scroll, #(frame.addons))

	for id, row in pairs(frame.rows) do
		local addon = frame.addons[frame.scroll.offset + id]
		if addon then
			row.title:SetText(addon.title)

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
		if IsAddOnLoaded(i) and ((searchBy and strfind(strlower(name), searchBy)) or not searchBy ) then
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

	for id = 1, TOTAL_ROWS do
		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(22)
		row:SetWidth(1)

		row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.title:SetHeight(20)
		row.title:SetWidth(175)
		row.title:SetJustifyH("LEFT")
		row.title:SetJustifyV("CENTER")
		row.title:SetPoint("LEFT", row, "LEFT", 3, 0)

		row.memory = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.memory:SetHeight(20)
		row.memory:SetWidth(178)
		row.memory:SetJustifyH("LEFT")
		row.memory:SetJustifyV("CENTER")
		row.memory:SetPoint("LEFT", row.title, "RIGHT", 3, 0)

		row.memsec = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.memsec:SetHeight(20)
		row.memsec:SetWidth(166)
		row.memsec:SetJustifyH("LEFT")
		row.memsec:SetJustifyV("CENTER")
		row.memsec:SetPoint("LEFT", row.memory, "RIGHT", 3, 0)

		row.cpu = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.cpu:SetHeight(20)
		row.cpu:SetWidth(128)
		row.cpu:SetJustifyH("LEFT")
		row.cpu:SetJustifyV("CENTER")
		row.cpu:SetPoint("LEFT", row.memsec, "RIGHT", 3, 0)

		row.cpusec = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.cpusec:SetHeight(20)
		row.cpusec:SetWidth(70)
		row.cpusec:SetJustifyH("LEFT")
		row.cpusec:SetJustifyV("CENTER")
		row.cpusec:SetPoint("LEFT", row.cpu, "RIGHT", 3, 0)

		if id > 1 then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame.rows[id - 1], "BOTTOMLEFT", 0, 0)
			row:SetPoint("TOPRIGHT", frame.rows[id - 1], "BOTTOMRIGHT", 0, 0)
		else
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -96)
			row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, 0)
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
	frame:Hide()

	-- Button right buttons
	local toggleCPU = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	toggleCPU:SetWidth(80)
	toggleCPU:SetHeight(22)
	toggleCPU:SetPoint("BOTTOMRIGHT", OptionHouse.frame, "BOTTOMRIGHT", -8, 14)
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

	local reloadUI = CreateFrame("Button", nil, frame, "UIPanelButtonGrayTemplate")
	reloadUI:SetWidth(80)
	reloadUI:SetHeight(22)
	reloadUI:SetPoint("RIGHT", toggleCPU, "LEFT")
	reloadUI:SetText(L["Reload UI"])
	reloadUI:SetScript("OnClick", ReloadUI)

	local button = CreateFrame("Button", nil, frame)
	button.sortType = "name"
	button:SetScript("OnClick", sortPerfClick)
	button:SetNormalFontObject(GameFontNormal)
	button:SetText(L["Name"])
	button:SetHeight(18)
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -75)
	button:Show()

	frame.sortButtons.title = button

	local button = CreateFrame("Button", nil, frame)
	button.sortType = "memory"
	button:SetScript("OnClick", sortPerfClick)
	button:SetNormalFontObject(GameFontNormal)
	button:SetText(L["Memory"])
	button:SetHeight(18)
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame.sortButtons.title, "TOPLEFT", 180, 0)
	button:Show()

	frame.sortButtons.memory = button

	local button = CreateFrame("Button", nil, frame)
	button.sortType = "mir"
	button:SetScript("OnClick", sortPerfClick)
	button:SetNormalFontObject(GameFontNormal)
	button:SetText(L["Mem/Sec"])
	button:SetHeight(18)
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame.sortButtons.memory, "TOPLEFT", 180, 0)
	button:Show()

	frame.sortButtons.memsec = button

	local button = CreateFrame("Button", nil, frame)
	button.sortType = "cpu"
	button:SetScript("OnClick", sortPerfClick)
	button:SetNormalFontObject(GameFontNormal)
	button:SetText(L["CPU"])
	button:SetHeight(18)
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame.sortButtons.memsec, "TOPLEFT", 170, 0)
	button:Show()

	frame.sortButtons.cpu = button

	local button = CreateFrame("Button", nil, frame)
	button.sortType = "cir"
	button:SetScript("OnClick", sortPerfClick)
	button:SetNormalFontObject(GameFontNormal)
	button:SetText(L["CPU/Sec"])
	button:SetHeight(18)
	button:SetWidth(button:GetFontString():GetStringWidth() + 3)
	button:SetPoint("TOPLEFT", frame.sortButtons.cpu, "TOPLEFT", 130, 0)
	button:Show()

	frame.sortButtons.cpusec = button

	-- Create all of the rows for display
	createRows()

	-- Scrolly
	OptionHouse:CreateScrollFrame(frame, TOTAL_ROWS, updatePerformanceList)

	frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -76)
	frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 72)

	-- Search on bottom left
	OptionHouse:CreateSearchInput(frame, function()
		updateAddonPerfList()
		updateAddonPerformance()
		updatePerformanceList()
	end)
end

-- Load it into OH
OptionHouse:RegisterTab(L["Performance"], createPerfFrame, "Bid")