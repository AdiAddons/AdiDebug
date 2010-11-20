--[[
AdiDebug - Adirelle's debug helper.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, ns = ...

local AdiDebug = CreateFrame("Frame", "AdiDebug")
AdiDebug.version = GetAddOnMetadata(addonName, "version")

local now = time()
local messages = {}
local heap = setmetatable({}, {__mode='kv'})
AdiDebug.messages = messages

local function PrettyFormat(value)
	if value == nil then
		return "|cffaaaaaanil|r"
	elseif value == true or value == false then
		return format("|cff44aaff%s|r", tostring(value))
	elseif type(value) == "number" then
		return format("|cffaaaaff%s|r", tostring(value))
	elseif type(value) == "table" then
		local name = tostring(
			(type(value.GetName) == "function" and value:GetName())
			or (type(value.ToString) == "function" and value:ToString())
			or value.name
			or gsub(tostring(value), '^table: ', '')
		)
		if type(value[0]) == "userdata" then
			return format("|cffffaa44[%s]|r", name)
		else
			return format("|cff44aa77[%s]|r", name)
		end
	else
		return tostring(value)
	end
end

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
		return table.concat(t, " ", 1, n)
	end
end

local function Record(key, name, ...)
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
	if AdiDebug.Callback then
		AdiDebug:Callback(key, name, now, text)
	end
end

local sinks = setmetatable({}, {__index = function(t, name)
	local key = strsplit('_', name)
	local sink = function(...) return Record(key, name, ...) end
	messages[key] = {}
	t[key] = sink
	return sink
end})

function AdiDebug:GetSink(name)
	return sinks[name]
end

AdiDebug:SetScript('OnUpdate', function() now = time() end)

SLASH_ADIDEBUG1 = "/ad"
SLASH_ADIDEBUG2 = "/adidebug"
function SlashCmdList.ADIDEBUG()
	if not IsAddOnLoaded("AdiDebug_GUI") and not LoadAddOn("AdiDebug_GUI") then
		return
	end
	AdiDebug:Open()
end

