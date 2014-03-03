--[[
	OptionHouse, by Shadow - Mal'Ganis (US)

	Thanks Tekkub and Cladhaire for the original idea and some of the code... which I mutilated shortly thereafter!
]]

OptionHouse = {}

local L = OptionHouseLocals
local tabFunctions = {}
local openedByMenu

-- TABS
local function resizeTab(tab)
	local textWidth = tab:GetFontString():GetWidth()

	tab.middleActive:SetWidth(textWidth)
	tab.middleInactive:SetWidth(textWidth)

	tab:SetWidth((2 * tab.leftActive:GetWidth()) + textWidth)
	tab.highlightTexture:SetWidth(textWidth + 20)
end

local function tabSelected(tab)
	tab:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	tab.highlightTexture:Hide()
	tab:Disable()

	tab.leftActive:Show()
	tab.middleActive:Show()
	tab.rightActive:Show()

	tab.leftInactive:Hide()
	tab.middleInactive:Hide()
	tab.rightInactive:Hide()
end

local function tabDeselected(tab)
	tab:GetFontString():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	tab.highlightTexture:Show()
	tab:Enable()

	tab.leftInactive:Show()
	tab.middleInactive:Show()
	tab.rightInactive:Show()

	tab.leftActive:Hide()
	tab.middleActive:Hide()
	tab.rightActive:Hide()
end

local function setTab(id)
	local frame = OptionHouse.frame
	if( not frame.tabs[id] ) then return end

	if( frame.selectedTab ) then
		tabDeselected(frame.tabs[frame.selectedTab])
	end

	frame.selectedTab = id
	tabSelected(frame.tabs[id])
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

			frame.topLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. tab.type .. "-TopLeft")
			frame.top:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. tab.type .. "-Top")
			frame.topRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. tab.type .. "-TopRight")

			frame.bottomLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. tab.type .. "-BotLeft")
			frame.bottom:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. tab.type .. "-Bot")
			frame.bottomRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. tab.type .. "-BotRight")
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
		tab = CreateFrame("Button", nil, self.frame)
		tab:SetHighlightFontObject(GameFontHighlightSmall)
		tab:SetNormalFontObject(GameFontNormalSmall)
		tab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
		tab:SetText(text)
		tab:SetWidth(115)
		tab:SetHeight(32)
		tab:SetID(id)
		tab:SetScript("OnClick", tabOnClick)
		tab:GetFontString():SetPoint("CENTER", 0, 2)

		tab.highlightTexture = tab:GetHighlightTexture()
		tab.highlightTexture:ClearAllPoints()
		tab.highlightTexture:SetPoint("CENTER", tab:GetFontString(), 0, 0)
		tab.highlightTexture:SetBlendMode("ADD")

		-- TAB SELECTED TEXTURES
		tab.leftActive = tab:CreateTexture(nil, "ARTWORK")
		tab.leftActive:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
		tab.leftActive:SetHeight(32)
		tab.leftActive:SetWidth(20)
		tab.leftActive:SetPoint("TOPLEFT", tab, "TOPLEFT")
		tab.leftActive:SetTexCoord(0, 0.15625, 0, 1.0)

		tab.middleActive = tab:CreateTexture(nil, "ARTWORK")
		tab.middleActive:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
		tab.middleActive:SetHeight(32)
		tab.middleActive:SetWidth(20)
		tab.middleActive:SetPoint("LEFT", tab.leftActive, "RIGHT")
		tab.middleActive:SetTexCoord(0.15625, 0.84375, 0, 1.0)

		tab.rightActive = tab:CreateTexture(nil, "ARTWORK")
		tab.rightActive:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
		tab.rightActive:SetHeight(32)
		tab.rightActive:SetWidth(20)
		tab.rightActive:SetPoint("LEFT", tab.middleActive, "RIGHT")
		tab.rightActive:SetTexCoord(0.84375, 1.0, 0, 1.0)

		-- TAB DESELECTED TEXTURES
		tab.leftInactive = tab:CreateTexture(nil, "ARTWORK")
		tab.leftInactive:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
		tab.leftInactive:SetHeight(32)
		tab.leftInactive:SetWidth(20)
		tab.leftInactive:SetPoint("TOPLEFT", tab, "TOPLEFT")
		tab.leftInactive:SetTexCoord(0, 0.15625, 0, 1.0)

		tab.middleInactive = tab:CreateTexture(nil, "ARTWORK")
		tab.middleInactive:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
		tab.middleInactive:SetHeight(32)
		tab.middleInactive:SetWidth(20)
		tab.middleInactive:SetPoint("LEFT", tab.leftInactive, "RIGHT")
		tab.middleInactive:SetTexCoord(0.15625, 0.84375, 0, 1.0)

		tab.rightInactive = tab:CreateTexture(nil, "ARTWORK")
		tab.rightInactive:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
		tab.rightInactive:SetHeight(32)
		tab.rightInactive:SetWidth(20)
		tab.rightInactive:SetPoint("LEFT", tab.middleInactive, "RIGHT")
		tab.rightInactive:SetTexCoord(0.84375, 1.0, 0, 1.0)

		tinsert(self.frame.tabs, tab)
	end

	tab:SetText(text)
	tab:Show()

	tabDeselected(tab)
	resizeTab(tab)

	if id > 1 then
		tab:SetPoint("TOPLEFT", self.frame.tabs[id - 1], "TOPRIGHT", -8, 0)
	else
		tab:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 15, 11)
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

	frame.scroll = CreateFrame("ScrollFrame", nil, frame)
	frame.scroll:EnableMouseWheel(true)
	frame.scroll:SetWidth(16)
	frame.scroll:SetHeight(270)
	frame.scroll:SetScript("OnVerticalScroll", onVerticalScroll)
	frame.scroll:SetScript("OnMouseWheel", onMouseWheel)

	frame.scroll.offset = 0
	frame.scroll.displayNum = displayNum
	frame.scroll.updateHandler = frame
	frame.scroll.updateFunc = onScroll

	-- Actual bar for scrolling
	frame.scroll.bar = CreateFrame("Slider", nil, frame.scroll)
	frame.scroll.bar:SetValueStep(frame.scroll.displayNum)
	frame.scroll.bar:SetMinMaxValues(0, 0)
	frame.scroll.bar:SetValue(0)
	frame.scroll.bar:SetWidth(16)
	frame.scroll.bar:SetScript("OnValueChanged", onValueChanged)
	frame.scroll.bar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 6, -16)
	frame.scroll.bar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 6, -16)

	-- Up/Down buttons
	frame.scroll.up = CreateFrame("Button", nil, frame.scroll.bar, "UIPanelScrollUpButtonTemplate")
	frame.scroll.up:ClearAllPoints()
	frame.scroll.up:SetPoint( "BOTTOM", frame.scroll.bar, "TOP" )
	frame.scroll.up:SetScript("OnClick", scrollButtonUp)

	frame.scroll.down = CreateFrame("Button", nil, frame.scroll.bar, "UIPanelScrollDownButtonTemplate")
	frame.scroll.down:ClearAllPoints()
	frame.scroll.down:SetPoint( "TOP", frame.scroll.bar, "BOTTOM" )
	frame.scroll.down:SetScript("OnClick", scrollButtonDown)

	-- That square thingy that shows where the bar is
	frame.scroll.bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")

	local thumb = frame.scroll.bar:GetThumbTexture()
	thumb:SetHeight(16)
	thumb:SetWidth(16)
	thumb:SetTexCoord(0.25, 0.75, 0.25, 0.75)

	-- Border graphic
	frame.scroll.barUpTexture = frame.scroll:CreateTexture(nil, "BACKGROUND")
	frame.scroll.barUpTexture:SetWidth(31)
	frame.scroll.barUpTexture:SetHeight(256)
	frame.scroll.barUpTexture:SetPoint("TOPLEFT", frame.scroll.up, "TOPLEFT", -7, 5)
	frame.scroll.barUpTexture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
	frame.scroll.barUpTexture:SetTexCoord(0, 0.484375, 0, 1.0)

	frame.scroll.barDownTexture = frame.scroll:CreateTexture(nil, "BACKGROUND")
	frame.scroll.barDownTexture:SetWidth(31)
	frame.scroll.barDownTexture:SetHeight(106)
	frame.scroll.barDownTexture:SetPoint("BOTTOMLEFT", frame.scroll.down, "BOTTOMLEFT", -7, -3)
	frame.scroll.barDownTexture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
	frame.scroll.barDownTexture:SetTexCoord(0.515625, 1.0, 0, 0.4140625)
end

-- SEARCH INPUT
local function focusGained(self)
	if self.searchText then
		self.searchText = nil
		self:SetText("")
		self:SetTextColor(1, 1, 1, 1)
	end
end

local function focusLost(self)
	if not self.searchText and strtrim(self:GetText()) == "" then
		self.searchText = true
		self:SetText(L["Search..."])
		self:SetTextColor(0.90, 0.90, 0.90, 0.80)
	end
end

function OptionHouse:CreateSearchInput(frame, onChange)
	frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.search:SetHeight(19)
	frame.search:SetWidth(150)
	frame.search:SetAutoFocus(false)
	frame.search:ClearAllPoints()
	frame.search:SetPoint("CENTER", frame, "BOTTOMLEFT", 100, 25)

	frame.search.searchText = true
	frame.search:SetText(L["Search..."])
	frame.search:SetTextColor(0.90, 0.90, 0.90, 0.80)
	frame.search:SetScript("OnTextChanged", onChange)
	frame.search:SetScript("OnEditFocusGained", focusGained)
	frame.search:SetScript("OnEditFocusLost", focusLost)
end

-- Main container frame
function OptionHouse:CreateUI()
	if self.frame then return end

	local frame = CreateFrame("Frame", "OptionHouseFrame", UIParent)
	frame:CreateTitleRegion()
	frame:SetClampedToScreen(true)
	frame:SetMovable(false)
	frame:SetFrameStrata("HIGH")
	frame:SetWidth(832)
	frame:SetHeight(447)
	frame:SetPoint("TOPLEFT", 0, -104)
	frame.tabs = {}

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
	frame:SetAttribute("UIPanelLayout-whileDead", true)
	tinsert(UISpecialFrames, frame:GetName())

	-- Title texture
	local title = frame:GetTitleRegion()
	title:SetWidth(757)
	title:SetHeight(20)
	title:SetPoint("TOPLEFT", 75, -15)

	local texture = frame:CreateTexture(nil, "OVERLAY")
	texture:SetWidth(128)
	texture:SetHeight(128)
	texture:SetPoint("TOPLEFT", 9, -2)
	texture:SetTexture("Interface\\AddOns\\OptionHouse\\GnomePortrait")

	frame:EnableMouse(false)
	frame:SetMovable(true)

	-- This goes in the entire bar where "OptionHouse" title text is
	local mover = CreateFrame("Button", nil, frame)
	mover:SetPoint("TOP", 25, -15)
	mover:SetHeight(19)
	mover:SetWidth(730)

	mover:SetScript("OnLeave", hideTooltip)
	mover:SetScript("OnEnter", showTooltip)
	mover:SetScript("OnMouseUp", function(self)
		if self.isMoving then
			self.isMoving = nil
			self:GetParent():StopMovingOrSizing()
		end
	end)

	mover:SetScript("OnMouseDown", function(self, mouse)
		local parent = self:GetParent()

		-- Start moving!
		if mouse == "LeftButton" and parent:IsMovable() then
			self.isMoving = true
			parent:StartMoving()

		-- Reset position
		elseif mouse == "RightButton" then
			parent:ClearAllPoints()
			parent:SetPoint("TOPLEFT", 0, -104)
		end
	end)

	-- Title
	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(GameFontNormal)
	title:SetPoint("TOP", 0, -18)
	title:SetText(L["Option House"])

	-- Container border
	frame.topLeft = frame:CreateTexture(nil, "ARTWORK")
	frame.topLeft:SetWidth(256)
	frame.topLeft:SetHeight(256)
	frame.topLeft:SetPoint("TOPLEFT", 0, 0)

	frame.top = frame:CreateTexture(nil, "ARTWORK")
	frame.top:SetWidth(320)
	frame.top:SetHeight(256)
	frame.top:SetPoint("TOPLEFT", 256, 0)

	frame.topRight = frame:CreateTexture(nil, "ARTWORK")
	frame.topRight:SetWidth(256)
	frame.topRight:SetHeight(256)
	frame.topRight:SetPoint("TOPLEFT", frame.top, "TOPRIGHT", 0, 0)

	frame.bottomLeft = frame:CreateTexture(nil, "ARTWORK")
	frame.bottomLeft:SetWidth(256)
	frame.bottomLeft:SetHeight(256)
	frame.bottomLeft:SetPoint("TOPLEFT", 0, -256)

	frame.bottom = frame:CreateTexture(nil, "ARTWORK")
	frame.bottom:SetWidth(320)
	frame.bottom:SetHeight(256)
	frame.bottom:SetPoint("TOPLEFT", 256, -256)

	frame.bottomRight = frame:CreateTexture(nil, "ARTWORK")
	frame.bottomRight:SetWidth(256)
	frame.bottomRight:SetHeight(256)
	frame.bottomRight:SetPoint("TOPLEFT", frame.bottom, "TOPRIGHT", 0, 0)

	-- Close button
	local button = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	button:SetPoint("TOPRIGHT", 3, -8)
	button:SetScript("OnClick", function()
		HideUIPanel(frame)
	end)

	self.frame = frame

	-- Create tabs
	for id, tab in pairs(tabFunctions) do
		self:CreateTab(tab.text, id)
	end
end

function OptionHouse:RegisterTab(text, func, type)
	tinsert(tabFunctions, { func = func, text = text, type = type })

	-- Will create all of the tabs when the frame is created if needed
	if not self.frame then
		return
	end

	self:CreateTab(text, #(tabFunctions))
end

function OptionHouse:Open(id)
	self:CreateUI()
	tabOnClick(tonumber(tab) or 1)
	ShowUIPanel(self.frame)
end

-- Make sure it hasn't been created already.
if not GameMenuButtonOptionHouse then
	local menuButton = CreateFrame("Button", "GameMenuButtonOptionHouse", GameMenuFrame, "GameMenuButtonTemplate")
	menuButton:SetText(L["Option House"])
	menuButton:SetScript("OnClick", function()
		openedByMenu = true
		PlaySound("igMainMenuOption")
		HideUIPanel(GameMenuFrame)
		OptionHouse:Open()
	end)

	-- Position below "Interface Options"
	local point, anchorTo, relativePoint, x, y = GameMenuButtonKeybindings:GetPoint()
	menuButton:SetPoint(point, anchorTo, relativePoint, x, y)

	GameMenuButtonKeybindings:SetPoint(point, menuButton, relativePoint, x, y)
	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 25)
end

-- Slash commands
SLASH_OPTHOUSE1 = nil
SlashCmdList["OPTHOUSE"] = nil

SLASH_OH1 = nil
SlashCmdList["OH"] = nil

SLASH_OPTIONHOUSE1 = "/opthouse"
SLASH_OPTIONHOUSE2 = "/optionhouse"
SLASH_OPTIONHOUSE3 = "/oh"
SlashCmdList["OPTIONHOUSE"] = function(tab)
	OptionHouse:Open(tab)
end