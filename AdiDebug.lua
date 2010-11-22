--[[
AdiDebug - Adirelle's debug frame.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, ns = ...

local AdiDebug = CreateFrame("Frame", "AdiDebug")
AdiDebug.version = GetAddOnMetadata(addonName, "version")

callbacks = LibStub('CallbackHandler-1.0'):New(AdiDebug)

local geterrorhandler, pcall = geterrorhandler, pcall
local setmetatable, getmetatable = setmetatable, getmetatable
local type, tostring, format = type, tostring, format
local select, time = select, time
local tinsert, tremove, tconcat = tinsert, tremove, table.concat

-- ----------------------------------------------------------------------------
-- Error catching call
-- ----------------------------------------------------------------------------

local function safecall_inner(ok, ...)
	if ok then
		return ...
	else
		geterrorhandler()(...)
	end
end

local function safecall(func, ...)
	return safecall_inner(pcall(func, ...))
end

-- ----------------------------------------------------------------------------
-- Safely get name for tables
-- ----------------------------------------------------------------------------

local function GuessTableName(value)
	return
		(type(value.GetName) == "function" and value:GetName())
		or (type(value.ToString) == "function" and value:ToString())
		or value.name
end

local tableNameCache = setmetatable({}, {
	__mode = 'k',
	__index = function(self, value)
		local name = safecall(GuessTableName, value)
		if not name then
			local mt = getmetatable(value)
			setmetatable(value, nil)
			name = gsub(tostring(value), 'table: ', '')
			setmetatable(value, mt)
		end
		self[value] = name
		return name
	end
})

function AdiDebug:GetTableName(value)
	return type(value) == "table" and tableNameCache[value] or tostring(value)
end

-- ----------------------------------------------------------------------------
-- Table/frame hyperlink builder
-- ----------------------------------------------------------------------------

local function BuildHyperLink(value)
	local name = AdiDebug:GetTableName(value)
	local color, linkType
	if type(value[0]) == "userdata" then
		color, linkType = "ffaa44", "Frame"
	else
		color, linkType = "44ffaa", "Table"
	end
	return format("|cff%s|HAdiDebug%s:%s|h[%s]|h|r", color, linkType, name, name)
end

local linkRefs = setmetatable({}, {__mode = 'v'})
local linkCache = setmetatable({}, {
	__mode = 'k',
	__index = function(self, value)
		local link = BuildHyperLink(value)
		linkRefs[link] = value
		self[value] = link
		return link
	end
})

function AdiDebug:GetTableHyperlink(value)
	return type(value) == "table" and linkCache[value] or tostring(value)
end

function AdiDebug:GetTableHyperlinkTable(link)
	return link and linkRefs[link]
end

-- ----------------------------------------------------------------------------
-- Pretty formatting
-- ----------------------------------------------------------------------------

function AdiDebug:PrettyFormat(value)
	if value == nil then
		return "|cffaaaaaanil|r"
	elseif value == true or value == false then
		return format("|cff77aaff%s|r", tostring(value))
	elseif type(value) == "number" then
		return format("|cffaa77ff%s|r", tostring(value))
	elseif type(value) == "table" then
		return AdiDebug:GetTableHyperlink(value)
	else
		return tostring(value)
	end
end

-- ----------------------------------------------------------------------------
-- Message stores and iterators
-- ----------------------------------------------------------------------------

local messages = {}
local subKeys = {}

local function keyIterator(_, key)
	key = next(messages, key)
	return key
end

function AdiDebug:IterateKeys() 
	return keyIterator
end

function AdiDebug:HasSubKeys(key)
	return not not next(subKeys[key])
end

function AdiDebug:IterateSubKeys(key) 
	return pairs(subKeys[key])
end

local function messageIterator(keyMessages, index)
	index = index + 1
	local message = keyMessages[index]
	if message then
		return index, unpack(message)
	end
end

function AdiDebug:IterateMessages(key)
	return messageIterator, messages[key], 0
end

-- ----------------------------------------------------------------------------
-- Error catching call
-- ----------------------------------------------------------------------------

local now = time()
local heap = setmetatable({}, {__mode='kv'})

AdiDebug:SetScript('OnUpdate', function(_, elapsed)
	local newTime = time()
	if newTime == floor(now) then
		now = now + elapsed
	else
		now = newTime
	end
end)

local tmp = {}
local function Format(...)
	local n = select('#', ...)
	if n == 0 then
		return
	elseif n == 1 then
		return AdiDebug:PrettyFormat(...)
	end
	for i = 1, n do
		local v = select(i, ...)
		tmp[i] = type(v) == "string" and v or AdiDebug:PrettyFormat(v)
	end
	return tconcat(tmp, " ", 1, n)
end

local function Sink(key, subKey, ...)
	local m = messages[key]
	local t = tremove(heap, 1)
	local text = Format(...)
	if not t then
		t = { subKey, now, text }
	else
		t[1], t[2], t[3] = subKey, now, text
	end
	tinsert(m, t)
	for i = 500, #m do	
		tinsert(heap, tremove(m, 1))
	end
	if subKey ~= key and not subKeys[key][subKey] then
		subKeys[key][subKey] = true
		callbacks:Fire('AdiDebug_NewSubKey', key, subKey)
	end
	callbacks:Fire('AdiDebug_NewMessage', key, subKey, now, text)
end

-- ----------------------------------------------------------------------------
-- Registering new sinks
-- ----------------------------------------------------------------------------

local function RegisterKey(key)
	if not messages[key] then
		messages[key] = {}
		callbacks:Fire('AdiDebug_NewKey', key)
	end
	if not subKeys[key] then
		subKeys[key] = {}
		callbacks:Fire('AdiDebug_NewSubKey', key, key)
	end
end

local sinkFuncs = setmetatable({}, { __index = function(self, key)
	local sink = function(...) return safecall(Sink, key, key, ...) end
	self[key] = sink
	RegisterKey(key)
	return sink
end})

local sinkMethods = setmetatable({}, { __index = function(self, key)
	local sink = function(self, ...) return safecall(Sink, key, AdiDebug:GetTableName(self), self, ...) end
	self[key] = sink
	RegisterKey(key)
	return sink
end})

function AdiDebug:GetSink(key)
	return sinkFuncs[key]
end

function AdiDebug:Embed(target, key)
	target.Debug = sinkMethods[key]
	return target.Debug
end

-- ----------------------------------------------------------------------------
-- Initialization
-- ----------------------------------------------------------------------------

AdiDebug:SetScript('OnEvent', function(self, event, name)
	if name == addonName then
		self:SetScript('OnEvent', nil)
		self:UnregisterEvent('ADDON_LOADED')
		self.db = LibStub('AceDB-3.0'):New('AdiDebugDB', { profile = { shown = false } }, true)
	end
end)
AdiDebug:RegisterEvent('ADDON_LOADED')

-- ----------------------------------------------------------------------------
-- User interface
-- ----------------------------------------------------------------------------

function AdiDebug:LoadAndOpen(arg)
	if not IsAddOnLoaded("AdiDebug_GUI") and not LoadAddOn("AdiDebug_GUI") then
		return
	end
	AdiDebug:Open(arg)
end

SLASH_ADIDEBUG1 = "/ad"
SLASH_ADIDEBUG2 = "/adidebug"
function SlashCmdList.ADIDEBUG(arg)
	if strtrim(arg) == "" then
		arg = nil
	end
	return AdiDebug:LoadAndOpen(arg)
end

-- ----------------------------------------------------------------------------
-- Emulate tekDebug
-- ----------------------------------------------------------------------------

local function Frame_AddMessage(self, text) return self:Sink(text) end

local frames = setmetatable({}, {__index = function(t, name)
	local frame = {
		Sink = AdiDebug:GetSink(name),
		AddMessage = Frame_AddMessage
	}
	t[name] = frame
	return frame
end})

tekDebug = { GetFrame = function(_, name) return frames[name] end }

