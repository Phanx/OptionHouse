--[[
	OptionHouse, by Shadow - Mal'Ganis (US)
	Thanks Tekkub and Cladhaire for the original idea and some of the code... which I mutilated shortly thereafter!
	This version further updated and modified by Phanx <addons@phanx.net>
]]

local OPTIONHOUSE, L = ...
setmetatable(L, { __index = function(t, k)
	local v = tostring(k)
	t[k] = v
	return v
end })

OptionHouse = {}
local tabFunctions = {}
local openedByMenu

-- TABS
local function setTab(id)
	local frame = OptionHouse.frame
	if( not frame.tabs[id] ) then return end

	if( frame.selectedTab ) then
		PanelTemplates_DeselectTab(frame.tabs[frame.selectedTab])
	end

	frame.selectedTab = id
	PanelTemplates_SelectTab(frame.tabs[id])
end

local function tabOnClick(self)
	local id = type(self) == "number" and self or self:GetID()
	setTab(id)

	local frame = OptionHouse.frame
	for tabID, tab in pairs(tabFunctions) do
		if tabID == id then
			if type(tab.func) == "function" then
				tab.func()
			else
				tab.handler[tab.func](tab.handler)
			end
		elseif type(tab.func) == "function" then
			tab.func(true)
		else
			tab.handler[tab.func](tab.handler, true)
		end
	end
end

function OptionHouse:CreateTab(text, id)
	if not self.frame then
		self:CreateUI()
	end

	local tab = self.frame.tabs[id]
	if not tab then
		tab = CreateFrame("Button", "$parentTab"..id, self.frame, "CharacterFrameTabButtonTemplate")
		tab:GetFontString():SetPoint("CENTER", 0, 2)
		tab:UnregisterEvent("DISPLAY_SIZE_CHANGED")
		tab:SetScript("OnEvent", nil)

		tab:SetID(id)
		tab:SetSize(115, 32)
		tab:SetScript("OnClick", tabOnClick)
		tab:SetScript("OnShow", function(tab) PanelTemplates_TabResize(tab, 10) end)

		tinsert(self.frame.tabs, tab)
	end

	tab:SetText(text)
	tab:Show()

	PanelTemplates_DeselectTab(tab)
	PanelTemplates_TabResize(tab, 0)

	if id > 1 then
		tab:SetPoint("TOPLEFT", self.frame.tabs[id - 1], "TOPRIGHT", -8, 0)
	else
		tab:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 15, 0)
	end
end

-- SCROLL FRAME
local function onVerticalScroll(self, offset)
	offset = ceil(offset)

	self.bar:SetValue(offset)
	self.offset = ceil(offset / self.displayNum)

	if self.offset < 0 then
		self.offset = 0
	end

	local min, max = self.bar:GetMinMaxValues()

	if min == offset then
		self.up:Disable()
	else
		self.up:Enable()
	end

	if max == offset then
		self.down:Disable()
	else
		self.down:Enable()
	end

	self.updateFunc(self.updateHandler)
end

local function onMouseWheel(self, offset)
	if self.scroll then self = self.scroll end
	if offset > 0 then
		self.bar:SetValue(self.bar:GetValue() - (self.bar:GetHeight() / 2))
	else
		self.bar:SetValue(self.bar:GetValue() + (self.bar:GetHeight() / 2))
	end
end

local function onParentMouseWheel(self, offset)
	onMouseWheel(self.scroll, offset)
end

function OptionHouse:UpdateScroll(scroll, totalRows)
	local max = (totalRows - scroll.displayNum) * scroll.displayNum

	-- Macs are unhappy if max is less then the min
	if max < 0 then
		max = 0
	end

	scroll.bar:SetMinMaxValues(0, max)

	if( totalRows > scroll.displayNum ) then
		scroll:Show()
		scroll.bar:Show()
		scroll.up:Show()
		scroll.down:Show()
		scroll.bar:GetThumbTexture():Show()
	else
		scroll:Hide()
		scroll.bar:Hide()
		scroll.up:Hide()
		scroll.down:Hide()
		scroll.bar:GetThumbTexture():Hide()
	end
end

local function onValueChanged(self, offset)
	self:GetParent():SetVerticalScroll(offset)
end

local function scrollButtonUp(self)
	local parent = self:GetParent()
	parent:SetValue(parent:GetValue() - (parent:GetHeight() / 2))
	PlaySound("UChatScrollButton")
end

local function scrollButtonDown(self)
	local parent = self:GetParent()
	parent:SetValue(parent:GetValue() + (parent:GetHeight() / 2))
	PlaySound("UChatScrollButton")
end

function OptionHouse:CreateScrollFrame(frame, displayNum, onScroll)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", onParentMouseWheel)

	local scroll = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "UIPanelScrollFrameTemplate2")
	scroll:SetPoint("TOPLEFT", 10, -65)
	scroll:SetPoint("BOTTOMRIGHT", -31, 30)
	
	scroll:EnableMouseWheel(true)
	scroll:SetWidth(16)
	scroll:SetHeight(270)
	scroll:SetScript("OnVerticalScroll", onVerticalScroll)
	scroll:SetScript("OnMouseWheel", onMouseWheel)
	-- TODO: do we really need custom scroll handlers?

	scroll.offset = 0
	scroll.displayNum = displayNum
	scroll.updateHandler = frame
	scroll.updateFunc = onScroll

	scroll.bar = scroll.ScrollBar
	scroll.up = scroll.ScrollBar.ScrollUpButton
	scroll.down = scroll.ScrollBar.ScrollDownButton

	scroll.barUpTexture = _G[scroll:GetName().."Top"]
	scroll.barUpTexture:SetPoint("TOPLEFT", scroll.up, -6, 5)
	scroll.barUpTexture:SetWidth(29)

	scroll.barDownTexture = _G[scroll:GetName().."Bottom"]
	scroll.barDownTexture:SetPoint("BOTTOMLEFT", scroll.down, -6, -2)
	scroll.barDownTexture:SetWidth(29)

	frame.scroll = scroll
	return scroll
end

-- SEARCH INPUT
function OptionHouse:CreateSearchInput(frame, onChange)
	local search = CreateFrame("EditBox", "$parentSearchBox", frame, "SearchBoxTemplate")
	search:SetPoint("BOTTOMLEFT", frame, 10, 3)
	search:SetHeight(22)
	search:SetWidth(160)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", onChange)
	--search.Left:SetTexture("")
	--search.Right:SetTexture("")
	--search.Middle:SetTexture("")
	frame.search = search
	return search
end

-- Main container frame
function OptionHouse:CreateUI()
	if self.frame then return end

	local frame = CreateFrame("Frame", "OptionHouseFrame", UIParent, "ButtonFrameTemplate")
	frame:CreateTitleRegion()
	frame:EnableMouse(true) -- @Phanx: don't allow clickthrough
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("HIGH")
	frame:SetWidth(832)
	frame:SetHeight(447)
	frame:SetPoint("TOPLEFT", 0, -104)

	-- If it's not hidden first, the panel layout becomes messed up
	-- because dynamically created frames are created shown
	frame:Hide()
	frame:SetScript("OnHide", function()
		if openedByMenu then
			openedByMenu = nil
			PlaySound("gsTitleOptionExit")
			ShowUIPanel(GameMenuFrame)
		end
	end)

	-- Frame type info
	frame:SetAttribute("UIPanelLayout-defined", true)
	frame:SetAttribute("UIPanelLayout-enabled", true)
 	frame:SetAttribute("UIPanelLayout-area", "doublewide")
	frame:SetAttribute("UIPanelLayout-pushable", 3)
	frame:SetAttribute("UIPanelLayout-whileDead", true)
	tinsert(UISpecialFrames, "OptionHouseFrame")

	frame.TitleText:SetText(L["Option House"])
	frame.portrait:SetTexture("Interface\\AddOns\\OptionHouse\\GnomePortrait")
	frame.portrait:SetPoint("TOPLEFT", -4, 12)
	frame.portrait:SetDrawLayer("OVERLAY")

	local mover = CreateFrame("Button", nil, frame)
	mover:RegisterForClicks("RightButtonUp")
	mover:RegisterForDrag("LeftButton")
	mover:SetPoint("TOPLEFT", OptionHouseFrameTitleBg, 40, 0)
	mover:SetPoint("BOTTOMRIGHT", OptionHouseFrameTitleBg)
	mover:SetScript("OnLeave", GameTooltip_Hide)
	mover:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 10)
		GameTooltip:SetText("Drag to move this frame.\nRight-click to reset its position.")
	end)
	mover:SetScript("OnDragStart", function(self)
		frame:StartMoving()
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	mover:SetScript("OnDragStop", function(self)
		frame:StopMovingOrSizing()
		frame.userPlaced = true
		if self:IsMouseOver() then
			self:GetScript("OnEnter")(self)
		end
	end)
	mover:SetScript("OnHide", function(self)
		frame:StopMovingOrSizing()
	end)
	mover:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			frame.userPlaced = false
			frame:Hide()
			ShowUIPanel(frame)
		end
	end)

	self.frame = frame

	-- Create tabs
	frame.tabs = {}
	for id, tab in pairs(tabFunctions) do
		self:CreateTab(tab.text, id)
	end
end

function OptionHouse:RegisterTab(text, func)
	tinsert(tabFunctions, { func = func, text = text })
	-- Will create all of the tabs when the frame is created if needed
	if not self.frame then return end
	self:CreateTab(text, #(tabFunctions))
end

function OptionHouse:Open(id)
	if self.frame and self.frame:IsShown() then return end
	self:CreateUI()
	tabOnClick(tonumber(tab) or 1)
	if self.frame.userPlaced then
		self.frame:Show()
	else
		ShowUIPanel(self.frame)
	end
end

function OptionHouse:Close()
	if not self.frame or not self.frame:IsShown() then return end
	if self.frame.userPlaced then
		self.frame:Hide()
	else
		HideUIPanel(self.frame)
	end
end

function OptionHouse:Toggle(tab)
	if self.frame and self.frame:IsShown() then
		self:Close()
	else
		self:Open(tab)
	end
end

GameMenuButtonAddons:SetScript("OnClick", function()
	openedByMenu = true
	PlaySound("igMainMenuOption")
	HideUIPanel(GameMenuFrame)
	OptionHouse:Open()
end)

-- Slash commands
SLASH_OPTIONHOUSE1 = "/opthouse"
SLASH_OPTIONHOUSE2 = "/optionhouse"
SLASH_OPTIONHOUSE3 = "/oh"
SlashCmdList["OPTIONHOUSE"] = function(tab)
	OptionHouse:Toggle(tab)
end