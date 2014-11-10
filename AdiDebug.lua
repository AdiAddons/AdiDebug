--[[
AdiDebug - Adirelle's debug frame.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, ns = ...

local AdiDebug = CreateFrame("Frame", "AdiDebug")
AdiDebug.version = GetAddOnMetadata(addonName, "version")

local callbacks = LibStub('CallbackHandler-1.0'):New(AdiDebug)

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
	["number"]   = "ff77ff",
	["table"]    = "44ffaa",
	["UIObject"] = "ffaa44",
	["function"] = "77ffff",
--	["string"]   = "ffffff",
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
	local name = tostring(t)
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
-- Firstly try to use :GetName() and :ToString() methods, if they exist.
-- Then try to get the "name" field.
-- Finally, returns tostring(t).
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
	if t == "table" and type(value[0]) == "userdata" then
		return "UIObject"
	end
	return t
end

-- ----------------------------------------------------------------------------
-- Table/frame hyperlink builder
-- ----------------------------------------------------------------------------

local function BuildHyperLink(t)
	local name, valueType = tostring(AdiDebug:GetTableName(t)), AdiDebug:GetSmartType(t)
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
-- @param maxLength The maximum length of the value ; defaults to no limit.
-- @return An human-readable representation of the value.
function AdiDebug:PrettyFormat(value, noLink, maxLength)
	local valueType = self:GetSmartType(value)
	local stringRepr
	if valueType == "table" or valueType == "UIObject" then
		if not noLink then
			return self:GetTableHyperlink(value)
		else
			stringRepr = self:GetTableName(value)
		end
	elseif valueType == "number" and maxLength then
		stringRepr = strtrim(format('%'..maxLength..'g', value))
	else
		stringRepr = tostring(value)
		if maxLength and strlen(stringRepr) > maxLength then
			stringRepr = strsub(stringRepr, 1, maxLength-3) .. '|cffaaaaaa...|r'
		end
	end
	local color = self.hexColors[valueType]
	return color and strjoin('', '|cff', color, stringRepr, '|r') or stringRepr
end

-- ----------------------------------------------------------------------------
-- Data and iterators
-- ----------------------------------------------------------------------------

local streams = {}
local categories = {}

local function keyIterator(t, k)
	return (next(t, k))
end

--- Tests if a stream exists.
-- @param streamId The identifier of the stream to test.
-- @return True if the stream exists.
function AdiDebug:HasStream(streamId)
	return not not streams[streamId]
end

--- Provides an iterator for the registered streams.
-- @return Suitable values for the "in" part of an "for ... in ... do" statement.
-- @usage
-- for streamId in AdiDebug:IterateStreams() do
--   -- Do something usefull with streamId
-- end
function AdiDebug:IterateStreams()
	return keyIterator, streams
end

--- Tests if any category has been defined for a given stream.
-- @param streamId The identifier of the stream.
-- @return True if any category exists for that stream.
function AdiDebug:HasCategory(streamId)
	return not not next(categories[streamId])
end

--- Provides an iterator for the categories of a given stream.
-- @param streamId The identifier of the stream.
-- @return Suitable values for the "in" part of an "for ... in ... do" statement.
-- @usage
-- for category in AdiDebug:IterateCategories("test") do
--   -- Do something usefull with category
-- end
function AdiDebug:IterateCategories(streamId)
	return keyIterator, categories[streamId]
end

local function messageIterator(stream, index)
	index = index + 1
	local message = stream[index]
	if message then
		return index, unpack(message)
	end
end

--- Provides an iterator for the messages of a given stream.
-- @param streamId The identifier of the stream.
-- @return Suitable values for the "in" part of an "for ... in ... do" statement
-- @usage
--   for index, category, timestamp, message in AdiDebug:IterateMessages("test") do
--     -- Do something meaningful with those value
--   end
function AdiDebug:IterateMessages(streamId)
	return messageIterator, streams[streamId], 0
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

local function Sink(streamId, category, ...)
	assert(streamId)
	assert(category)
	local stream = streams[streamId]
	local message = tremove(heap, 1)
	local text = Format(...)
	if not message then
		message = { category, now, text }
	else
		message[1], message[2], message[3] = category, now, text
	end
	tinsert(stream, message)
	for i = 2000, #stream do
		tinsert(heap, tremove(stream, 1))
	end
	if category ~= streamId and not categories[streamId][category] then
		categories[streamId][category] = true
		callbacks:Fire('AdiDebug_NewCategory', streamId, category)
	end
	callbacks:Fire('AdiDebug_NewMessage', streamId, category, now, text)
end

-- ----------------------------------------------------------------------------
-- Registering new sinks
-- ----------------------------------------------------------------------------

local function RegisterStream(streamId)
	if not streams[streamId] then
		streams[streamId] = {}
		categories[streamId] = {}
		callbacks:Fire('AdiDebug_NewStream', streamId)
	end
end

local sinkFuncs = setmetatable({}, { __index = function(self, streamId)
	local sink = function(...)
		return safecall(Sink, streamId, streamId, ...)
	end
	self[streamId] = sink
	RegisterStream(streamId)
	return sink
end})

local sinkMethods = setmetatable({}, { __index = function(self, streamId)
	local sink = function(obj, ...)
		return safecall(Sink, streamId, AdiDebug:GetTableName(obj), obj, ...)
	end
	self[streamId] = sink
	RegisterStream(streamId)
	return sink
end})

--- Creates a sink function for a given stream.
-- @param streamId The identifier of the stream.
-- @return A sink function that accepts any number of arguments.
-- @usage
-- local Debug = AdiDebug:GetSink("test")
-- Debug("bla")
function AdiDebug:GetSink(streamId)
	return sinkFuncs[streamId]
end

--- Embeds a sink method into an existing object.
-- @parma target The object to embed AdiDebug into.
-- @param streamId The identifier of the stream.
-- @usage
-- AdiDebug:Embed(MyObject, "test")
-- MyObject:Debug("bla")
function AdiDebug:Embed(target, streamId)
	target.Debug = sinkMethods[streamId]
	return target.Debug
end

-- ----------------------------------------------------------------------------
-- Initialization
-- ----------------------------------------------------------------------------

AdiDebug:SetScript('OnEvent', function(self, event, name)
	if name == addonName then
		self:SetScript('OnEvent', nil)
		self:UnregisterEvent('ADDON_LOADED')
		self.db = LibStub('AceDB-3.0'):New('AdiDebugDB', { profile = {} }, true)
	end
end)
AdiDebug:RegisterEvent('ADDON_LOADED')

-- ----------------------------------------------------------------------------
-- Emulate tekDebug
-- ----------------------------------------------------------------------------

local frames = setmetatable({}, {__index = function(t, name)
	local sink = AdiDebug:GetSink(name)
	local frame = { AddMessage = function(_, text) return sink(text) end }
	t[name] = frame
	return frame

end})

tekDebug = { GetFrame = function(_, name) return frames[name] end }

-- ----------------------------------------------------------------------------
-- Display errors caught by BugGrabber
-- ----------------------------------------------------------------------------

if _G.BugGrabber then
	local errorStream

	local function GetErrorCategory(...)
		local category
		for i = 1, select('#', ...) do
			local line = strtrim(select(i, ...) or "")
			if not category and (strmatch(line, 'Interface\\FrameXML') or strmatch(line, 'Interface\\AddOns\\Blizzard_')) then
				category = 'Blizzard'
			else
				local addon = strmatch(line, 'Interface\\AddOns\\([^\\]+)')
				if addon and not strmatch(line, '\\libs\\') and not strmatch(addon, '^Blizzard_') then
					return addon
				end
			end
		end
		return category
	end

	function AdiDebug:BugGrabber_BugGrabbed(_, err)
		if not errorStream then
			errorStream = '|cffff0000ERRORS|r'
			RegisterStream(errorStream)
		end
		local category = GetErrorCategory(err.message, strsplit(err.stack, "\n"))
		if category and streams[category] then
			return Sink(category, errorStream, err.message, err.stack)
		else
			return Sink(errorStream, category or errorStream, err.message, err.stack)
		end
	end

	_G.BugGrabber.RegisterCallback(AdiDebug, 'BugGrabber_BugGrabbed')
end
