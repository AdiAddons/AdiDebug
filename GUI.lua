--[[
AdiDebug - Adirelle's debug frame.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local db

local currentKey

local frame, messageArea, selector, scrollBar, currentNow

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
	if not db.profile.names[currentKey][name] then
		return
	end
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

local function SelectKey(key)
	if currentKey ~= key then
		currentKey = key
		db.profile.key = currentKey
		selector.text:SetText(currentKey or "")
		RefreshMessages()
	end
end

local function KeyEntry_IsChecked(button)
	return currentKey and button.value == currentKey
end

local function KeyEntry_OnClick(button)
	SelectKey(button.value)
end

local function NameEntry_IsChecked(button)
	return db.profile.names[button.arg1][button.value]
end

local function NameEntry_OnClick(button, key, _, checked)
	db.profile.names[button.arg1][button.value] = checked
	if key == currentKey then
		RefreshMessages()
	end
end

local list = {}
local function Selector_Initialize(frame, level, menuList)
	wipe(list)
	if level == 1 then
		for key in pairs(AdiDebug.messages) do
			tinsert(list, key)
		end
		table.sort(list)
		for i, key in ipairs(list) do
			local opt = UIDropDownMenu_CreateInfo()
			opt.text = key
			opt.value = key
			opt.func = KeyEntry_OnClick
			opt.checked = KeyEntry_IsChecked
			if next(AdiDebug.names[key]) then
				opt.hasArrow = true
			end

			UIDropDownMenu_AddButton(opt, level)
		end
	elseif level == 2 then
		local key = UIDROPDOWNMENU_MENU_VALUE

		for name in pairs(AdiDebug.names[key]) do
			tinsert(list, name)
		end
		table.sort(list)
		tinsert(list, 1, key)
		
		for i, name in ipairs(list) do
			local opt = UIDropDownMenu_CreateInfo()
			opt.text = name
			opt.value = name
			opt.isNotRadio = true
			opt.func = NameEntry_OnClick
			opt.arg1 = key
			opt.checked = NameEntry_IsChecked
			opt.keepShownOnClick = true
			UIDropDownMenu_AddButton(opt, level)
		end
	end

	local opt = UIDropDownMenu_CreateInfo()
	opt.text = "Close menu"
	opt.notCheckable = true
	UIDropDownMenu_AddButton(opt, level)
end

local function CreateOurFrame()
	db = AdiDebug.db:RegisterNamespace("GUI", {
		profile = {
			point = "TOPLEFT",
			xOffset = 16,
			yOffset = -200,
			width = 640,
			height = 400,
			names = { ['*'] = { ['*'] = true } }
		}
	}, true)

	frame = CreateFrame("Frame", "AdiDebug", UIParent)
	frame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0,0,0,1)
	frame:SetBackdropBorderColor(1,1,1,1)
	frame:SetSize(db.profile.width, db.profile.height)
	frame:SetPoint(db.profile.point, db.profile.xOffset, db.profile.yOffset)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)

	frame:EnableMouse(true)
	frame:SetScript('OnMouseDown', function(self)
		if not self.movingOrSizing and IsShiftKeyDown() then
			local x, y = GetCursorPosition()
			local scale = self:GetEffectiveScale()
			local left, bottom, width, height = self:GetRect()
			x, y = (x / scale) - left, (y / scale) - bottom
			local horiz = (x < 16) and "LEFT" or (x > width - 16) and "RIGHT"
			local vert = (y < 16) and "BOTTOM" or (y > height - 16) and "TOP"
			if horiz or vert then
				self:StartSizing(strjoin("", vert or "", horiz or ""))
			else
				self:StartMoving()
			end
			self.movingOrSizing = true
		end
	end)
	frame:SetScript('OnMouseUp', function(self)
		if self.movingOrSizing then
			self.movingOrSizing = nil
			frame:StopMovingOrSizing()
			db.profile.width, db.profile.height = frame:GetSize()
			local _
			_, _, db.profile.point, db.profile.xOffset, db.profile.yOffset = frame:GetPoint()
		end
	end)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript('OnClick', function() frame:Hide() end)

	selector = CreateFrame("Button", "AdiDebugDropdown", frame, "UIDropDownMenuTemplate")
	selector:SetPoint("TOPLEFT", -12, -4)
	selector:SetWidth(145)
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
	messageArea:SetIndentedWordWrap(true)

	messageArea:EnableMouseWheel(true)
	messageArea:SetScript('OnMouseWheel', function(self, delta)
		if delta > 0 then
			if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
		else
			if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
		end
		UpdateScrollBar()
	end)

	scrollBar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
	scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -44)
	scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 24)
	scrollBar.scrollStep = 3
	frame.SetVerticalScroll = function(_, value)
		local _, maxVal = scrollBar:GetMinMaxValues()
		local offset = maxVal - floor(value + 0.5)
		if messageArea:GetCurrentScroll() ~= offset then
			--messageArea:SetScrollOffset(offset)
		end
	end
	scrollBar:Hide()

	frame:SetScript('OnShow', UpdateScrollBar)
end

function AdiDebug:Callback(key, ...)
	if key == currentKey then
		AddMessage(...)
		UpdateScrollBar()
	end
end

function AdiDebug:Open(arg)
	if not frame then
		CreateOurFrame()
	end
	if not arg and frame:IsShown() then
		frame:Hide()
		return
	end
	if arg and arg ~= "" then
		arg = strlower(arg)
		for key in pairs(AdiDebug.messages) do
			if strolower(key) == arg then
				SelectKey(key)
			end
		end
	elseif db.profile.key and AdiDebug.messages[db.profile.key] then
		SelectKey(db.profile.key)
	end
	frame:Show()
end

AdiDebug.LoadAndOpen = AdiDebug.Open

