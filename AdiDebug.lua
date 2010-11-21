--[[
AdiDebug - Adirelle's debug frame.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, ns = ...

local AdiDebug = CreateFrame("Frame", "AdiDebug")
AdiDebug.version = GetAddOnMetadata(addonName, "version")

local type, tostring, format = type, tostring, format
local pcall, select, time = pcall, select, time
local tinsert, tremove, tconcat = tinsert, tremove, table.concat

local now = time()
local messages = {}
local names = {}
local heap = setmetatable({}, {__mode='kv'})
AdiDebug.messages = messages
AdiDebug.names = names

local safecall
do
	local function safecall_inner(ok, ...)
		if ok then
			return ...
		else
			geterrorhandler()(...)
		end
	end
	function safecall(func, ...)
		return safecall_inner(pcall(func, ...))
	end
end

local function GetTableName(value)
	return tostring(
		(type(value.GetName) == "function" and value:GetName())
		or (type(value.ToString) == "function" and value:ToString())
		or value.name
		or gsub(tostring(value), '^table: ', '')
	)
end

local function PrettyFormat(value)
	if value == nil then
		return "|cffaaaaaanil|r"
	elseif value == true or value == false then
		return format("|cff77aaff%s|r", tostring(value))
	elseif type(value) == "number" then
		return format("|cffaa77ff%s|r", tostring(value))
	elseif type(value) == "table" then
		if type(value[0]) == "userdata" then
			return format("|cffffaa44[%s]|r", GetTableName(value))
		else
			return format("|cff44ffaa[%s]|r", GetTableName(value))
		end
	else
		return tostring(value)
	end
end
AdiDebug.PrettyFormat = PrettyFormat

local Format
do
	local t = {}
	function Format(...)
		local n = select('#', ...)
		if n == 0 then
			return
		elseif n == 1 then
			return PrettyFormat(...)
		end
		for i = 1, n do
			local v = select(i, ...)
			t[i] = type(v) == "string" and v or PrettyFormat(v)
		end
		return tconcat(t, " ", 1, n)
	end
end

local function Sink(key, name, ...)
	local m = messages[key]
	local t = tremove(heap, 1)
	local text = Format(...)
	if not t then
		t = { name, now, text }
	else
		t[1], t[2], t[3] = name, now, text
	end
	tinsert(m, t)
	for i = 500, #m do
		tinsert(heap, tremove(m, 1))
	end
	if name ~= key then
		names[key][name] = true
	end
	if AdiDebug.Callback then
		AdiDebug:Callback(key, name, now, text)
	end
end

local function AddKey(key)
	if not messages[key] then
		messages[key] = {}
	end
	if not names[key] then
		names[key] = {}
	end
end

local sinkFuncs = {}
local sinkMethods = {}

function AdiDebug:GetSink(key)
	if not sinkFuncs[key] then
		sinkFuncs[key] = function(...) return safecall(Sink, key, key, ...) end
		AddKey(key)
	end
	return sinkFuncs[key]
end

function AdiDebug:Embed(target, key)
	assert(type(target) == "table", "AdiDebug:Embed(target[, key]): target should be a table.")
	assert(type(key) == "string", "AdiDebug:Embed(target[, key]): key should be a string.")
	if not sinkMethods[key] then
		sinkMethods[key] = function(self, ...) return safecall(Sink, key, GetTableName(self), self, ...) end
		AddKey(key)
	end
	target.Debug = sinkMethods[key]
	return target.Debug
end

AdiDebug:SetScript('OnUpdate', function(_, elapsed)
	local newTime = time()
	if newTime == floor(now) then
		now = now + elapsed
	else
		now = newTime
	end
end)

AdiDebug:SetScript('OnEvent', function(self, event, name)
	if name == addonName then
		self:SetScript('OnEvent', nil)
		self:UnregisterEvent('ADDON_LOADED')
		self.db = LibStub('AceDB-3.0'):New('AdiDebugDB', { profile = { shown = false } }, true)
	end
end)
AdiDebug:RegisterEvent('ADDON_LOADED')

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

-- Mimics tekDebug
do
	local function Frame_AddMessage(self, text, r, g, b) return self:Sink(text) end
	local frames = setmetatable({}, {__index = function(t, name)
		local frame = {
			Sink = AdiDebug:GetSink(name),
			AddMessage = Frame_AddMessage
		}
		t[name] = frame
		return frame
	end})
	_G.tekDebug = { GetFrame = function(_, name) return frames[name] end }
end

