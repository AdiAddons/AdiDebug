--[[
AdiDebug - Adirelle's debug helper.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local currentKey

local messageArea, selector, scrollBar, currentNow

local function UpdateScrollBar()
	local numMessages, displayed = messageArea:GetNumMessages(), messageArea:GetNumLinesDisplayed()
	local newMax = max(0, numMessages - displayed)
	if newMax > 0 then
		local _, oldMax = scrollBar:GetMinMaxValues()
		if newMax ~= oldMax then
			local offset = oldMax - floor(scrollBar:GetValue() + 0.5)
			scrollBar:SetMinMaxValues(0, newMax)
			scrollBar:SetValue(max(0, newMax - offset))
		end
		if not scrollBar:IsShown() then
			scrollBar:Show()
		end
	elseif scrollBar:IsShown() then
		scrollBar:Hide()
	end
end

local function AddMessage(name, now, text)
	if now ~= currentNow then
		messageArea:AddMessage(strjoin(" ", '-----', date("%X", now)), 0.6, 0.6, 0.6)
		currentNow = now
	end
	messageArea:AddMessage(text)
end

local function RefreshMessages()
	messageArea:Clear()
	currentNow = nil
	if currentKey then
		local m = AdiDebug.messages[currentKey]
		for i = 1, #m do
			AddMessage(unpack(m[i]))
		end
	end
	UpdateScrollBar()
end

local function MenuEntry_IsChecked(button)
	return currentKey and button.value == currentKey
end

local function MenuEntry_OnClick(button)
	if button.value ~= currentKey then
		currentKey = button.value
		selector.text:SetText(currentKey or "")
		RefreshMessages()
	end
end

local list = {}
local function Selector_Initialize(frame, level, menuList)
	wipe(list)
	for key in pairs(AdiDebug.messages) do
		tinsert(list, key)
	end
	table.sort(list)
	for i, key in ipairs(list) do
		local opt = UIDropDownMenu_CreateInfo()
		opt.text = key
		opt.value = key
		opt.func = MenuEntry_OnClick
		opt.checked = MenuEntry_IsChecked

		UIDropDownMenu_AddButton(opt, level)
	end
	
	local opt = UIDropDownMenu_CreateInfo()
	opt.text = "Close menu"
	opt.notCheckable = true
	UIDropDownMenu_AddButton(opt, level)
end

local function PopFrame()
	local frame = CreateFrame("Frame", "AdiDebug", UIParent)
	frame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16, 
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	frame:SetBackdropColor(0,0,0,1)
	frame:SetBackdropBorderColor(1,1,1,1)
	frame:SetSize(640, 400)
	frame:SetPoint("TOPLEFT", 16, -200)
	frame:SetClampedToScreen(true)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript('OnClick', function() frame:Hide() end)

	selector = CreateFrame("Button", "AdiDebugDropdown", frame, "UIDropDownMenuTemplate")
	selector:SetPoint("TOPLEFT", -12, -4)
	selector.initialize = Selector_Initialize
	selector.text = _G["AdiDebugDropdownText"]
	
	messageArea = CreateFrame("ScrollingMessageFrame", nil, frame)
	messageArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
	messageArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 8)
	messageArea:SetFading(false)
	messageArea:SetJustifyH("LEFT")
	messageArea:SetMaxLines(550)
	messageArea:SetFontObject(ChatFontSmall)
	messageArea:SetHyperlinksEnabled(false)
	messageArea:SetScript('OnMessageScrollChanged', UpdateScrollBar)
	messageArea:SetScript('OnSizeChanged', UpdateScrollBar)
		
	scrollBar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
	scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -44)
	scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 24)
	scrollBar.scrollStep = 3
	frame.SetVerticalScroll = function(_, value)
		local _, maxVal = scrollBar:GetMinMaxValues()
		local offset = maxVal - floor(value + 0.5)
		if messageArea:GetCurrentScroll() ~= offset then
			messageArea:SetScrollOffset(offset)
		end
	end
	
	frame:SetScript('OnShow', UpdateScrollBar)
	
	return frame
end

function AdiDebug:Callback(key, ...)
	if key == currentKey then
		AddMessage(...)
		UpdateScrollBar()
	end
end

function AdiDebug:Open()
	if not frame then
		frame = PopFrame()
	end
	frame:Show()
end

