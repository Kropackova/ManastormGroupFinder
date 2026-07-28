-- Manastorm Group Finder 2.7
-- Core.lua - chat capture, storage, filters, whisper templates, slash commands.

MSGF = MSGF or {}

MSGF.BUCKETS = { "LFM", "LFG", "UNSURE" }
MSGF.stats = { events = 0, gated = 0, stored = 0, errors = 0 }

local DEFAULTS = {
	mode = "LFM",
	style = "vanilla",
	dupWindow = 120,
	expiry = 900,
	stale = 300,
	maxRows = 200,
	showOwn = false,
	debug = false,
	sortKey = "time",
	sortAsc = false,
	minimap = { show = true, angle = 205 },
	window = { shown = false, x = 0, y = 0, w = 780, h = 460, hasPos = false },
	filter = {
		intent = "BOTH",
		roles = { tank = false, heal = false, damage = false },
		needAura = false,
		needLooms = false,
		minLevel = 0,
		maxLevel = 0,
		word = "",
	},
	alert = { enabled = false, sound = true, chat = false, popup = true, mode = "ANY" },
	-- One line per tab, sent only when you click the W cell in a row.
	whisper = {
		lfm = "Hi {name}, lvl {mylevel} dps with looms and aura, room in your MS?",
		lfg = "Hi {name}, i have a MS group going, want an invite?",
	},
	rows = { LFM = {}, LFG = {}, UNSURE = {} },
}

local function copyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			copyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function MSGF.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffManastorm GF|r: " .. tostring(msg))
	end
end

local function debugPrint(msg)
	if MSGF_DB and MSGF_DB.debug then
		MSGF.Print("|cffaaaaaa" .. tostring(msg) .. "|r")
	end
end

local EVENTS = {
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_BATTLEGROUND",
	"CHAT_MSG_BATTLEGROUND_LEADER",
	"CHAT_MSG_EMOTE",
	"CHAT_MSG_TEXT_EMOTE",
}
MSGF.EVENTS = EVENTS

-- Mode and sorting ----------------------------------------------------------

function MSGF.GetMode()
	return (MSGF_DB and MSGF_DB.mode) or "LFM"
end

function MSGF.SetMode(mode)
	for i = 1, #MSGF.BUCKETS do
		if MSGF.BUCKETS[i] == mode then
			MSGF_DB.mode = mode
			if MSGF.Refresh then
				MSGF.Refresh()
			end
			return
		end
	end
end

-- A mention of aura or looms means different things depending on who wrote
-- the line. In an offer the sender is advertising what they bring, so it is a
-- plain yes or no. In a recruit post the mention can be a hard requirement,
-- an optional nice to have, or what the leader already has, so the honest
-- value is maybe.
function MSGF.StateValue(state, bucket)
	if state ~= "pos" then
		return "no"
	end
	if bucket == "LFM" then
		return "maybe"
	end
	return "yes"
end

-- Recomputes the aura and looms cells of a row for the tab it now sits in.
function MSGF.ApplyStates(row, bucket)
	if not row.locked then
		row.locked = {}
	end
	if not row.locked.aura then
		row.aura = MSGF.StateValue(row.auraState, bucket)
	end
	if not row.locked.looms then
		row.looms = MSGF.StateValue(row.loomsState, bucket)
	end
end

-- Which side of the board you are on. Looking for a group means you want to
-- read recruit posts, looking for players means you want to read offers.
function MSGF.SetFilterIntent(intent)
	MSGF_DB.filter.intent = intent
	if intent == "GROUP" then
		MSGF_DB.alert.mode = "LFM"
		MSGF.SetMode("LFM")
	elseif intent == "PLAYERS" then
		MSGF_DB.alert.mode = "LFG"
		MSGF.SetMode("LFG")
	else
		MSGF_DB.alert.mode = "ANY"
	end
	if MSGF.Refresh then
		MSGF.Refresh()
	end
end

-- Storage -------------------------------------------------------------------

local function findRow(bucket, name)
	local list = MSGF_DB.rows[bucket]
	if not list then
		return nil
	end
	for i = 1, #list do
		if list[i].name == name then
			return list[i], i
		end
	end
	return nil
end

local function removeFromOtherBuckets(bucket, name)
	for i = 1, #MSGF.BUCKETS do
		local b = MSGF.BUCKETS[i]
		if b ~= bucket then
			local list = MSGF_DB.rows[b]
			for j = #list, 1, -1 do
				if list[j].name == name then
					table.remove(list, j)
				end
			end
		end
	end
end

function MSGF.RemoveRow(bucket, name)
	local list = MSGF_DB.rows[bucket]
	for i = #list, 1, -1 do
		if list[i].name == name then
			table.remove(list, i)
		end
	end
	if MSGF.Refresh then
		MSGF.Refresh()
	end
end

-- Moves every row of a player from one tab to another, for the cases where
-- the wording is genuinely ambiguous.
function MSGF.MoveRow(bucket, name, target)
	if bucket == target then
		return
	end
	local from = MSGF_DB.rows[bucket]
	local to = MSGF_DB.rows[target]
	if not from or not to then
		return
	end
	local moved = 0
	for i = #from, 1, -1 do
		if from[i].name == name then
			local row = table.remove(from, i)
			for j = #to, 1, -1 do
				if to[j].name == name then
					table.remove(to, j)
				end
			end
			MSGF.ApplyStates(row, target)
			table.insert(to, row)
			moved = moved + 1
		end
	end
	if moved > 0 then
		MSGF.Print(name .. " moved to " .. target)
		if MSGF.Refresh then
			MSGF.Refresh()
		end
	end
end

function MSGF.ClearBucket(bucket)
	MSGF_DB.rows[bucket] = {}
	if MSGF.Refresh then
		MSGF.Refresh()
	end
end

function MSGF.CountAll()
	local n = 0
	for i = 1, #MSGF.BUCKETS do
		n = n + #MSGF_DB.rows[MSGF.BUCKETS[i]]
	end
	return n
end

function MSGF.PurgeOld()
	if not MSGF_DB then
		return
	end
	local now = time()
	local removed = 0
	for i = 1, #MSGF.BUCKETS do
		local list = MSGF_DB.rows[MSGF.BUCKETS[i]]
		for j = #list, 1, -1 do
			if now - (list[j].time or 0) > (MSGF_DB.expiry or 900) then
				table.remove(list, j)
				removed = removed + 1
			end
		end
		while #list > (MSGF_DB.maxRows or 200) do
			local oldest, index = nil, nil
			for j = 1, #list do
				if not oldest or (list[j].time or 0) < oldest then
					oldest, index = list[j].time or 0, j
				end
			end
			if not index then
				break
			end
			table.remove(list, index)
			removed = removed + 1
		end
	end
	return removed
end

-- Filters -------------------------------------------------------------------

function MSGF.AnyRoleFilter()
	local f = MSGF_DB.filter
	return f.roles.tank or f.roles.heal or f.roles.damage
end

function MSGF.PassesFilter(row)
	local f = MSGF_DB.filter
	if MSGF.AnyRoleFilter() then
		local ok = false
		for i = 1, #MSGF.ROLE_ORDER do
			local role = MSGF.ROLE_ORDER[i]
			if f.roles[role] and row.roleSet and row.roleSet[role] then
				ok = true
			end
		end
		if not ok then
			return false
		end
	end
	-- A maybe still counts as a mention, so it passes an aura or looms filter.
	if f.needAura and row.aura ~= "yes" and row.aura ~= "maybe" then
		return false
	end
	if f.needLooms and row.looms ~= "yes" and row.looms ~= "maybe" then
		return false
	end
	if (f.minLevel or 0) > 0 then
		if not row.level or row.level < f.minLevel then
			return false
		end
	end
	if (f.maxLevel or 0) > 0 then
		if not row.level or row.level > f.maxLevel then
			return false
		end
	end
	if f.word and f.word ~= "" then
		local needle = f.word:lower()
		if not (row.message or ""):lower():find(needle, 1, true) then
			return false
		end
	end
	return true
end

local SORTERS = {
	time = function(a, b) return (a.time or 0) < (b.time or 0) end,
	name = function(a, b) return (a.name or "") < (b.name or "") end,
	role = function(a, b) return (a.roleText or "") < (b.roleText or "") end,
	aura = function(a, b) return (a.aura or "") < (b.aura or "") end,
	looms = function(a, b) return (a.looms or "") < (b.looms or "") end,
	level = function(a, b) return (a.level or 0) < (b.level or 0) end,
	message = function(a, b) return (a.message or "") < (b.message or "") end,
}

function MSGF.GetSortedRows(bucket, key, ascending)
	local source = MSGF_DB.rows[bucket] or {}
	local list = {}
	for i = 1, #source do
		if MSGF.PassesFilter(source[i]) then
			list[#list + 1] = source[i]
		end
	end
	local sorter = SORTERS[key] or SORTERS.time
	table.sort(list, function(a, b)
		if ascending then
			return sorter(a, b)
		end
		return sorter(b, a)
	end)
	return list
end

-- Alerts --------------------------------------------------------------------

local function alertWanted(bucket, row)
	local a = MSGF_DB.alert
	if not a.enabled then
		return false
	end
	if bucket == "UNSURE" then
		return false
	end
	if a.mode ~= "ANY" and a.mode ~= bucket then
		return false
	end
	return MSGF.PassesFilter(row)
end

-- Message handling ----------------------------------------------------------

local function channelLabel(event, arg4, arg9)
	if event == "CHAT_MSG_CHANNEL" then
		return arg9 or arg4 or "channel"
	end
	local short = event:gsub("^CHAT_MSG_", "")
	return short:lower():gsub("_", " ")
end

local lastSeen = {}

function MSGF.HandleMessage(event, message, sender, arg4, arg9, source)
	MSGF.stats.events = MSGF.stats.events + 1
	if not message or message == "" or not sender or sender == "" then
		return
	end

	sender = sender:match("^[^-]+") or sender

	-- Both capture paths can deliver the same line, so drop instant repeats.
	local key = sender .. "\001" .. message
	local now = time()
	if lastSeen[key] and now - lastSeen[key] < 3 then
		return
	end
	lastSeen[key] = now

	if not MSGF_DB.showOwn and sender == UnitName("player") then
		return
	end

	local parsed, norm = MSGF.Parse(message)
	if not parsed then
		debugPrint("skip (no manastorm): " .. sender .. ": " .. message)
		return
	end
	MSGF.stats.gated = MSGF.stats.gated + 1

	local bucket = parsed.intent
	local channel = channelLabel(event, arg4, arg9)
	debugPrint(bucket .. " <- " .. sender .. " [" .. channel .. "] " .. message)

	removeFromOtherBuckets(bucket, sender)
	local row = findRow(bucket, sender)
	local isNew = false

	if not row then
		row = { name = sender, locked = {} }
		table.insert(MSGF_DB.rows[bucket], row)
		isNew = true
		MSGF.stats.stored = MSGF.stats.stored + 1
	end

	row.time = now
	row.message = message
	row.norm = norm
	row.channel = channel
	row.source = source
	if not row.locked then
		row.locked = {}
	end
	if not row.locked.role then
		row.roleSet = parsed.roleSet
		row.roleText = parsed.roleText
	end
	row.auraState = parsed.auraState or (parsed.aura == "yes" and "pos" or "none")
	row.loomsState = parsed.loomsState or (parsed.looms == "yes" and "pos" or "none")
	MSGF.ApplyStates(row, bucket)
	if not row.locked.level then
		row.level = parsed.level
		row.bracket = parsed.bracket
	end
	row.size = parsed.size or row.size
	row.wanted = parsed.wanted or row.wanted

	if isNew and alertWanted(bucket, row) then
		local a = MSGF_DB.alert
		if a.chat then
			MSGF.Print("|cffffd100" .. bucket .. "|r " .. sender .. ": " .. message)
		end
		if a.sound then
			PlaySound("RaidWarning")
		end
		if a.popup and MSGF.ShowAlert then
			MSGF.ShowAlert(row, bucket)
		end
	end

	if MSGF.Refresh then
		MSGF.Refresh()
	end
end

-- Every capture path funnels through here so one error cannot kill the addon.
function MSGF.Ingest(event, message, sender, arg4, arg9, source)
	if not MSGF_DB then
		return
	end
	local ok, err = pcall(MSGF.HandleMessage, event, message, sender, arg4, arg9, source)
	if not ok then
		MSGF.stats.errors = MSGF.stats.errors + 1
		MSGF.lastError = tostring(err)
		if MSGF_DB.debug then
			MSGF.Print("|cffff5555error|r " .. MSGF.lastError)
		end
	end
end

-- Capture path 1: registered chat events.
local driver = CreateFrame("Frame", "MSGF_Driver", UIParent)
driver:RegisterEvent("ADDON_LOADED")

-- Capture path 2: chat display filters. This sees exactly what your chat frame
-- prints, which keeps working even if event registration behaves oddly.
local function chatFilter(chatFrame, event, ...)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = ...
	MSGF.Ingest(event, a1, a2, a4, a9, "filter")
	return false
end

local function installFilters()
	if not ChatFrame_AddMessageEventFilter then
		return 0
	end
	local count = 0
	for i = 1, #EVENTS do
		ChatFrame_AddMessageEventFilter(EVENTS[i], chatFilter)
		count = count + 1
	end
	return count
end

driver:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= "ManastormGroupFinder" then
			return
		end
		MSGF_DB = MSGF_DB or {}
		copyDefaults(DEFAULTS, MSGF_DB)
		for i = 1, #MSGF.BUCKETS do
			MSGF_DB.rows[MSGF.BUCKETS[i]] = MSGF_DB.rows[MSGF.BUCKETS[i]] or {}
			-- Older rows may hold ? values, normalize them to no.
			local list = MSGF_DB.rows[MSGF.BUCKETS[i]]
			for j = 1, #list do
				if list[j].aura ~= "yes" then list[j].aura = "no" end
				if list[j].looms ~= "yes" then list[j].looms = "no" end
			end
		end
		MSGF.PurgeOld()
		for i = 1, #EVENTS do
			self:RegisterEvent(EVENTS[i])
		end
		MSGF.filterCount = installFilters()
		MSGF.Print("version " .. MSGF.VERSION .. " loaded. Type /msgf to open, /msgf help for commands.")
		return
	end

	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = ...
	MSGF.Ingest(event, a1, a2, a4, a9, "event")
end)

-- Housekeeping ticker, no C_Timer on 3.3.5a.
local elapsedSince = 0
driver:SetScript("OnUpdate", function(self, elapsed)
	elapsedSince = elapsedSince + (elapsed or 0)
	if elapsedSince < 5 then
		return
	end
	elapsedSince = 0
	local removed = MSGF.PurgeOld()
	if MSGF.RefreshTimes then
		pcall(MSGF.RefreshTimes)
	end
	if removed and removed > 0 and MSGF.Refresh then
		pcall(MSGF.Refresh)
	end
end)

-- Slash commands ------------------------------------------------------------

local function printHelp()
	MSGF.Print("commands:")
	local lines = {
		"/msgf - show or hide the window",
		"/msgf lfm | lfg | unsure - pick a tab",
		"/msgf style vanilla | dark | grid - change the look",
		"/msgf clear - clear the current tab, clearall - clear everything",
		"/msgf minimap - show or hide the minimap button",
		"/msgf alert on | off | sound | chat | popup | mode lfm|lfg|any",
		"/msgf expiry 900 - seconds a row stays listed",
		"/msgf own - include or exclude your own messages",
		"/msgf debug - log every scanned chat line",
		"/msgf stats - capture counters and last error",
		"/msgf whisper - set the one click whisper line for each tab",
		"/msgf whisper lfm <text> - set the LFM line, lfg <text> for the LFG line",
		"/msgf group - what the client says about your party or raid rank",
		"/msgf probe - list the suggest invite entry points this client exposes",
		"/msgf test <message> - parse a line without sending it",
	}
	for i = 1, #lines do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. lines[i])
	end
end

local function handleAlert(rest)
	local a = MSGF_DB.alert
	local cmd, value = rest:match("^(%S*)%s*(.*)$")
	cmd = (cmd or ""):lower()
	if cmd == "on" then
		a.enabled = true
		MSGF.Print("alerts on")
	elseif cmd == "off" then
		a.enabled = false
		MSGF.Print("alerts off")
	elseif cmd == "sound" then
		a.sound = not a.sound
		MSGF.Print("alert sound " .. (a.sound and "on" or "off"))
	elseif cmd == "chat" then
		a.chat = not a.chat
		MSGF.Print("alert chat line " .. (a.chat and "on" or "off"))
	elseif cmd == "popup" then
		a.popup = not a.popup
		MSGF.Print("alert popup " .. (a.popup and "on" or "off"))
	elseif cmd == "mode" then
		local m = (value or ""):upper()
		if m == "LFM" or m == "LFG" or m == "ANY" then
			a.mode = m
			MSGF.Print("alert mode " .. m)
		else
			MSGF.Print("use /msgf alert mode lfm | lfg | any")
		end
	elseif cmd == "test" then
		if MSGF.ShowAlert then
			MSGF.ShowAlert({ name = UnitName("player"), message = "LF 1 healer 2 dps manastorm aura looms", roleText = "heal, damage" }, "LFM")
		end
	else
		MSGF.Print("alerts " .. (a.enabled and "on" or "off")
			.. ", mode " .. a.mode
			.. ", popup " .. (a.popup and "on" or "off")
			.. ", sound " .. (a.sound and "on" or "off")
			.. ", chat " .. (a.chat and "on" or "off"))
	end
	if MSGF.RefreshFilterPanel then
		MSGF.RefreshFilterPanel()
	end
end

-- Whisper templates ---------------------------------------------------------

function MSGF.WhisperTemplate(bucket)
	if not MSGF_DB or not MSGF_DB.whisper then
		return ""
	end
	if bucket == "LFG" then
		return MSGF_DB.whisper.lfg or ""
	end
	return MSGF_DB.whisper.lfm or ""
end

function MSGF.SetWhisperTemplate(bucket, text)
	if not MSGF_DB then
		return
	end
	MSGF_DB.whisper = MSGF_DB.whisper or {}
	if bucket == "LFG" then
		MSGF_DB.whisper.lfg = text or ""
	else
		MSGF_DB.whisper.lfm = text or ""
	end
end

-- Placeholders are replaced at click time, never before.
function MSGF.BuildWhisper(row, bucket)
	if not row then
		return nil
	end
	local text = MSGF.WhisperTemplate(bucket or MSGF.GetMode())
	if not text or text == "" then
		return nil
	end
	local values = {
		name = row.name or "",
		role = row.roleText or "?",
		level = row.level and tostring(row.level) or "?",
		aura = row.aura or "no",
		looms = row.looms or "no",
		size = row.size and tostring(row.size) or "?",
		myname = UnitName("player") or "",
		mylevel = tostring(UnitLevel("player") or 0),
	}
	text = text:gsub("{(%a+)}", function(key)
		local value = values[key:lower()]
		if value == nil then
			return "{" .. key .. "}"
		end
		return value
	end)
	return text
end

function MSGF.SendWhisper(row, bucket)
	if not row or not row.name or row.name == "" then
		return false
	end
	local text = MSGF.BuildWhisper(row, bucket)
	if not text or text == "" then
		MSGF.Print("no whisper line set for this tab - press the Whisper button in the window, or use /msgf whisper lfm <text>")
		return false
	end
	if text:len() > 250 then
		text = text:sub(1, 250)
	end
	SendChatMessage(text, "WHISPER", nil, row.name)
	row.whispered = time()
	if MSGF.Refresh then
		MSGF.Refresh()
	end
	return true
end

local function handleWhisper(rest)
	local sub, text = rest:match("^(%S*)%s*(.*)$")
	sub = (sub or ""):lower()
	if sub == "" then
		if MSGF.ShowWhisperSetup then
			MSGF.ShowWhisperSetup()
		end
	elseif sub == "lfm" or sub == "lfg" then
		if text == "" then
			MSGF.Print(sub .. " line: " .. (MSGF.WhisperTemplate(sub:upper()) or ""))
		else
			MSGF.SetWhisperTemplate(sub:upper(), text)
			MSGF.Print(sub .. " line saved: " .. text)
		end
	else
		MSGF.Print("use /msgf whisper to open the setup, or /msgf whisper lfm <text>")
	end
end

SLASH_MANASTORMGF1 = "/msgf"
SLASH_MANASTORMGF2 = "/manastorm"
SlashCmdList["MANASTORMGF"] = function(msg)
	msg = msg or ""
	local cmd, rest = msg:match("^(%S*)%s*(.*)$")
	cmd = (cmd or ""):lower()
	rest = rest or ""

	if cmd == "" then
		if MSGF.Toggle then MSGF.Toggle() end
	elseif cmd == "lfm" or cmd == "lfg" or cmd == "unsure" then
		MSGF.SetMode(cmd:upper())
		if MSGF.Show then MSGF.Show() end
	elseif cmd == "style" then
		local style = rest:lower()
		if style == "vanilla" or style == "dark" or style == "grid" then
			MSGF_DB.style = style
			if MSGF.ApplyStyle then MSGF.ApplyStyle() end
			MSGF.Print("style " .. style)
		else
			MSGF.Print("use /msgf style vanilla | dark | grid")
		end
	elseif cmd == "clear" then
		MSGF.ClearBucket(MSGF.GetMode())
		MSGF.Print("cleared " .. MSGF.GetMode())
	elseif cmd == "clearall" then
		for i = 1, #MSGF.BUCKETS do
			MSGF_DB.rows[MSGF.BUCKETS[i]] = {}
		end
		if MSGF.Refresh then MSGF.Refresh() end
		MSGF.Print("cleared every tab")
	elseif cmd == "minimap" then
		MSGF_DB.minimap.show = not MSGF_DB.minimap.show
		if MSGF.UpdateMinimapButton then MSGF.UpdateMinimapButton() end
		MSGF.Print("minimap button " .. (MSGF_DB.minimap.show and "shown" or "hidden"))
	elseif cmd == "alert" then
		handleAlert(rest)
	elseif cmd == "whisper" then
		handleWhisper(rest)
	elseif cmd == "probe" then
		if MSGF.Probe then
			MSGF.Probe()
		else
			MSGF.Print("probe is not loaded")
		end
	elseif cmd == "group" then
		if MSGF.PrintGroupState then
			MSGF.PrintGroupState()
		else
			MSGF.Print("group state is not loaded")
		end
	elseif cmd == "expiry" then
		local v = tonumber(rest)
		if v and v >= 60 then
			MSGF_DB.expiry = v
			MSGF.Print("rows expire after " .. v .. " seconds")
		else
			MSGF.Print("current expiry " .. MSGF_DB.expiry .. " seconds, minimum 60")
		end
	elseif cmd == "own" then
		MSGF_DB.showOwn = not MSGF_DB.showOwn
		MSGF.Print("own messages " .. (MSGF_DB.showOwn and "included" or "ignored"))
	elseif cmd == "debug" then
		MSGF_DB.debug = not MSGF_DB.debug
		MSGF.Print("debug " .. (MSGF_DB.debug and "on" or "off"))
	elseif cmd == "stats" then
		MSGF.Print("chat lines seen " .. MSGF.stats.events
			.. ", manastorm matches " .. MSGF.stats.gated
			.. ", rows created " .. MSGF.stats.stored
			.. ", listed now " .. MSGF.CountAll()
			.. ", errors " .. MSGF.stats.errors)
		MSGF.Print("chat filters installed " .. tostring(MSGF.filterCount)
			.. ", channel event registered " .. tostring(driver:IsEventRegistered("CHAT_MSG_CHANNEL")))
		if MSGF.lastError then
			MSGF.Print("last error: " .. MSGF.lastError)
		end
	elseif cmd == "test" then
		if rest == "" then
			MSGF.Print("use /msgf test lf3m manastorm 1h 2d aura looms lvl 24")
		else
			local parsed = MSGF.Parse(rest)
			if not parsed then
				MSGF.Print("no manastorm reference, line ignored")
			else
				MSGF.Print(parsed.intent .. " | role " .. parsed.roleText
					.. " | aura " .. parsed.aura
					.. " | looms " .. parsed.looms
					.. " | level " .. tostring(parsed.level or "?"))
			end
		end
	elseif cmd == "help" then
		printHelp()
	else
		printHelp()
	end
end
