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
-- Color scheme
-- ----------------------------------------------------------------------------

--- Colors used in type coloring.
-- Keys are value returned by AdiDebug:GetSmartType().
-- Values are the color in "rrggbb" form.
AdiDebug.hexColors = {
	["nil"]      = "aaaaaa",
	["boolean"]  = "77aaff",
	["number"]   = "aa77ff",
	["table"]    = "44ffaa",
	["UIObject"] = "ffaa44",
	["function"] = "77ffff",
	-- ["userdata"] =
}

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

local function GuessTableName(t)
	return
		(type(t.GetName) == "function" and t:GetName())
		or (type(t.ToString) == "function" and t:ToString())
		or t.name
end

local function GetRawTableName(t)
	local mt = getmetatable(t)
	setmetatable(t, nil)
	local name = gsub(tostring(t), '^table: ', '')
	setmetatable(t, mt)
	return name
end

local tableNameCache = setmetatable({}, {
	__mode = 'k',
	__index = function(self, t)
		local name = safecall(GuessTableName, t) or GetRawTableName(t)
		self[t] = name
		return name
	end
})

--- Get an human-readable name for a table, which could be an object or an UIObject.
-- First try to use :GetName() and :ToString() methods, if they exist.
-- Then try to get the name field.
-- As a last resort, returns the hexadecimal part of tostring(t).
-- @param t The table to examine.
-- @return A table name, hopefully human-readable.
function AdiDebug:GetTableName(t)
	return type(t) == "table" and tableNameCache[t] or tostring(t)
end

-- ----------------------------------------------------------------------------
-- Table/frame hyperlink builder
-- ----------------------------------------------------------------------------

--- Enhanced version of the built-in type() function that detects Blizzard's UIObject.
-- @param value The value to examine.
-- @return Either type(value) or "UIObject"
function AdiDebug:GetSmartType(value)
	local t = type(value)
	if t == "table" and type(t[0]) == "userdata" then
		return "UIObject"
	end
	return t
end

-- ----------------------------------------------------------------------------
-- Table/frame hyperlink builder
-- ----------------------------------------------------------------------------

local function BuildHyperLink(t)
	local name, valueType = AdiDebug:GetTableName(t), AdiDebug:GetSmartType(t)
	return format("|cff%s|HAdiDebug%s:%s|h[%s]|h|r", AdiDebug.hexColors[valueType], valueType, name, name)
end

local linkRefs = setmetatable({}, {__mode = 'v'})
local linkCache = setmetatable({}, {
	__mode = 'k',
	__index = function(self, t)
		local link = BuildHyperLink(t)
		linkRefs[link] = t
		self[t] = link
		return link
	end
})

--- Build an hyperlink for a table.
-- @param t The table.
-- @return An hyperlink, suitable to be used in any FontString.
function AdiDebug:GetTableHyperlink(t)
	return type(t) == "table" and linkCache[t] or tostring(t)
end

--- Returns the table associated to an table hyperlink.
-- @param link The table hyperlink.
-- @return table, linkType: the table or nil if it has been collected, and the subtype of table: "table" or "UIObject".
function AdiDebug:GetTableHyperlinkTable(link)
	local t = link and linkRefs[link]
	if t then
		return t, strmatch(link, 'AdiDebug(%w+):')
	end
end

-- ----------------------------------------------------------------------------
-- Pretty formatting
-- ----------------------------------------------------------------------------

--- Convert an Lua value into a color, human-readable representation.
-- @param value The value to represent.
-- @param noLink Do not return hyperlinks for tables if true ; defaults to false.
-- @param noTableName Do no return human-readable name for table if true ; defaults to false.
-- @return An human-readable representation of the value.
function AdiDebug:PrettyFormat(value, noLink, noTableName)
	local str
	if type(value) == "table" then
		if not noLink then
			return self:GetTableHyperlink(value)
		elseif noTableName then
			str = '['..self:GetTableName(value)..']'
		else
			str = '['..GetRawTableName(value)..']'
		end
	else
		str = tostring(value)
	end
	local color = self.hexColors[self:GetSmartType(value)]
	if color then
		return strjoin('', '|cff', color, str, '|r')
	else
		return str
	end
end

-- ----------------------------------------------------------------------------
-- Message stores and iterators
-- ----------------------------------------------------------------------------

local messages = {}
local subKeys = {}

local function keyIterator(t, key)
	key = next(t, key)
	return key
end

--- Tests if a stream key has been defined.
-- @param key The key to test.
-- @return True if the key exists.
function AdiDebug:HasKey(key)
	return not not messages[key]
end

--- Provides an iterator for the registered stream keys.
-- @return Suitable values for the "in" part of an "for ... in ... do" statement.
-- @usage
-- for key in AdiDebug:IterateKeys() do
--   -- Do something usefull with key
-- end
function AdiDebug:IterateKeys()
	return keyIterator, messages
end

--- Tests is sub-keys have been defined for a given stream key.
-- @param key The stream key to examine.
-- @return True if sub-keys exists for that stream key.
function AdiDebug:HasSubKeys(key)
	return not not next(subKeys[key])
end

--- Provides an iterator for the sub-keys of a given stream key.
-- @param key The stream key.
-- @return Suitable values for the "in" part of an "for ... in ... do" statement.
-- @usage
-- for subKey in AdiDebug:IterateSubKeys("test") do
--   -- Do something usefull with subKey
-- end
function AdiDebug:IterateSubKeys(key)
	return keyIterator, subKeys[key]
end

local function messageIterator(keyMessages, index)
	index = index + 1
	local message = keyMessages[index]
	if message then
		return index, unpack(message)
	end
end

--- Provides an iterator for the messages of a given stream.
-- @param key The stream key.
-- @return Suitable values for the "in" part of an "for ... in ... do" statement
-- @usage
--   for index, subKey, timestamp, message in AdiDebug:IterateMessages("test") do
--     -- Do something meaningful with those value
--   end
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
	assert(key)
	assert(subKey)
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
	local sink = function(...)
		return safecall(Sink, key, key, ...)
	end
	self[key] = sink
	RegisterKey(key)
	return sink
end})

local sinkMethods = setmetatable({}, { __index = function(self, key)
	local sink = function(obj, ...)
		return safecall(Sink, key, AdiDebug:GetTableName(obj), obj, ...)
	end
	self[key] = sink
	RegisterKey(key)
	return sink
end})

--- Creates a sink function for a given stream.
-- @param key The stream key.
-- @return A sink function that accepts any number of arguments.
-- @usage
-- local Debug = AdiDebug:GetSink("test")
-- Debug("bla")
function AdiDebug:GetSink(key)
	return sinkFuncs[key]
end

--- Embeds a sink method into an existing object.
-- @parma target The object to embed AdiDebug into.
-- @param key The stream key.
-- @usage
-- AdiDebug:Embed(MyObject, "test")
-- MyObject:Debug("bla")
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

