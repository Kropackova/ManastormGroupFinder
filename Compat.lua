-- Manastorm Group Finder 2.8
-- Compat.lua - group state, Ascension Suggest Invite, client probe.
--
-- Confirmed on Ascension, 28 July 2026: the global SuggestInvite is a function,
-- it accepts a plain name, and the group leader receives the accept or deny
-- popup. The addon calls it directly. The scans below stay as a safety net in
-- case the client renames it, and /msgf probe still reports what it finds.

MSGF = MSGF or {}

local function env()
	return getfenv(0)
end

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local ok = pcall(fn, ...)
	return ok
end

local function line(text)
	DEFAULT_CHAT_FRAME:AddMessage("  " .. text)
end

-- One frame delay, used when a click inside a dropdown has to open another one.
local deferFrame = CreateFrame("Frame")
local pending
deferFrame:Hide()
deferFrame:SetScript("OnUpdate", function(self)
	self:Hide()
	local fn = pending
	pending = nil
	if fn then
		pcall(fn)
	end
end)

local function nextFrame(fn)
	pending = fn
	deferFrame:Show()
end

-- Group state ---------------------------------------------------------------
-- InviteUnit is refused by the server when you are in a group without rank.
-- Raid assistants can invite, so a plain leader test is not enough.

function MSGF.GroupState()
	local raid = 0
	local party = 0
	if type(GetNumRaidMembers) == "function" then
		raid = GetNumRaidMembers() or 0
	end
	if type(GetNumPartyMembers) == "function" then
		party = GetNumPartyMembers() or 0
	end

	local inRaid = raid > 0
	local inParty = party > 0
	local rank = false

	if inRaid then
		if type(IsRaidLeader) == "function" and IsRaidLeader() then
			rank = true
		elseif type(IsRaidOfficer) == "function" and IsRaidOfficer() then
			rank = true
		end
	elseif inParty then
		if type(IsPartyLeader) == "function" and IsPartyLeader() then
			rank = true
		end
	end

	return {
		raidMembers = raid,
		partyMembers = party,
		inRaid = inRaid,
		inParty = inParty,
		inGroup = inRaid or inParty,
		rank = rank,
		canInvite = (not (inRaid or inParty)) or rank,
	}
end

function MSGF.CanInvite()
	local state = MSGF.GroupState()
	return state.canInvite
end

function MSGF.PrintGroupState()
	local s = MSGF.GroupState()
	MSGF.Print("group state")
	line("party members " .. s.partyMembers .. ", raid members " .. s.raidMembers)
	line("in group " .. tostring(s.inGroup) .. ", leader or assistant " .. tostring(s.rank))
	line("can invite " .. tostring(s.canInvite))
end

-- Discovery -----------------------------------------------------------------
-- Ascension is a custom client. These scans read what it actually exposes.

local discovery

local function scanFunctions()
	local hits = {}
	for k, v in pairs(env()) do
		if type(k) == "string" and type(v) == "function" then
			if k:lower():find("suggest") then
				table.insert(hits, k)
			end
		end
	end
	table.sort(hits)
	return hits
end

local function scanSlash()
	local hits = {}
	for k, v in pairs(env()) do
		if type(k) == "string" and type(v) == "string" and k:find("^SLASH_") then
			if v:lower():find("suggest") then
				table.insert(hits, { global = k, text = v, key = k:match("^SLASH_(.-)%d+$") })
			end
		end
	end
	return hits
end

local function scanPopupButtons()
	local hits = {}
	if type(UnitPopupButtons) == "table" then
		for k in pairs(UnitPopupButtons) do
			if type(k) == "string" and k:upper():find("SUGGEST") then
				table.insert(hits, k)
			end
		end
	end
	table.sort(hits)
	return hits
end

-- Which menu lists carry a given button, for example FRIEND or PARTY.
local function scanPopupMenus(button)
	local hits = {}
	if not button or type(UnitPopupMenus) ~= "table" then
		return hits
	end
	for menuName, list in pairs(UnitPopupMenus) do
		if type(list) == "table" then
			for i = 1, #list do
				if list[i] == button then
					table.insert(hits, menuName)
					break
				end
			end
		end
	end
	table.sort(hits)
	return hits
end

local function scanDialogs()
	local hits = {}
	if type(StaticPopupDialogs) == "table" then
		for k in pairs(StaticPopupDialogs) do
			if type(k) == "string" then
				local uk = k:upper()
				if uk:find("SUGGEST") or uk:find("INVITE") then
					table.insert(hits, k)
				end
			end
		end
	end
	table.sort(hits)
	return hits
end

function MSGF.Discover(force)
	if discovery and not force then
		return discovery
	end
	local buttons = scanPopupButtons()
	discovery = {
		functions = scanFunctions(),
		slash = scanSlash(),
		buttons = buttons,
		menus = scanPopupMenus(buttons[1]),
		dialogs = scanDialogs(),
	}
	return discovery
end

-- SuggestInvite is the confirmed entry point. The rest are fallbacks in case a
-- future client build renames it.
local KNOWN_NAMES = {
	"SuggestInvite",
	"SuggestInviteByName",
	"SuggestInviteUnit",
	"SuggestGroupInvite",
	"SuggestPartyInvite",
}

-- Reported by the probe but never called on their own. RequestInvite asks for
-- an invite for you, which is not the same action.
local REPORT_NAMES = {
	"RequestInvite",
	"RequestGroupInvite",
	"SuggestInviteToGroup",
}

local function knownFunction()
	local e = env()
	for i = 1, #KNOWN_NAMES do
		if type(e[KNOWN_NAMES[i]]) == "function" then
			return KNOWN_NAMES[i]
		end
	end
	return nil
end

-- Only a function whose name states both words is called automatically. A bare
-- "suggest" function could be anything, so it is reported and left alone.
local function preferredFunction()
	local known = knownFunction()
	if known then
		return known
	end
	local d = MSGF.Discover()
	for i = 1, #d.functions do
		local lk = d.functions[i]:lower()
		if lk:find("invite") then
			return d.functions[i]
		end
	end
	return nil
end

-- The real player menu ------------------------------------------------------
-- Three routes to the same UnitPopup data, tried in order. Each one is checked
-- by asking whether a dropdown is actually on screen afterwards.

local stockDropdown

local function dropdownVisible()
	return DropDownList1 and DropDownList1:IsShown()
end

local function openStockNow(name)
	if not name or name == "" then
		return false
	end
	CloseDropDownMenus()

	-- 1. the exact call a right click on a chat name makes
	if type(SetItemRef) == "function" then
		safeCall(SetItemRef, "player:" .. name, "[" .. name .. "]", "RightButton", DEFAULT_CHAT_FRAME)
		if dropdownVisible() then
			MSGF.lastMenuPath = "SetItemRef"
			return true
		end
	end

	-- 2. the friends list route, same button data
	if type(FriendsFrame_ShowDropdown) == "function" then
		safeCall(FriendsFrame_ShowDropdown, name, 1)
		if dropdownVisible() then
			MSGF.lastMenuPath = "FriendsFrame_ShowDropdown"
			return true
		end
	end

	-- 3. build the dropdown here and fill it from the same tables
	if type(UnitPopup_ShowMenu) == "function" and type(UIDropDownMenu_Initialize) == "function" then
		if not stockDropdown then
			stockDropdown = CreateFrame("Frame", "MSGF_StockDropdown", UIParent, "UIDropDownMenuTemplate")
		end
		stockDropdown.name = name
		stockDropdown.unit = nil
		stockDropdown.displayMode = "MENU"
		local init = function(self, level)
			UnitPopup_ShowMenu(self, "FRIEND", nil, name)
		end
		safeCall(UIDropDownMenu_Initialize, stockDropdown, init, "MENU")
		safeCall(ToggleDropDownMenu, 1, nil, stockDropdown, "cursor", 0, 0)
		if dropdownVisible() then
			MSGF.lastMenuPath = "UnitPopup_ShowMenu"
			return true
		end
	end

	MSGF.lastMenuPath = "none"
	MSGF.Print("could not open the player menu for " .. name .. ", run /msgf probe")
	return false
end

-- Called from inside our own dropdown, so the open waits one frame.
function MSGF.OpenStockPlayerMenu(name)
	nextFrame(function()
		openStockNow(name)
	end)
	return true
end

-- Suggest an invite ---------------------------------------------------------

local function slashSuggest(name)
	local d = MSGF.Discover()
	for i = 1, #d.slash do
		local entry = d.slash[i]
		if entry.key and type(SlashCmdList) == "table" and type(SlashCmdList[entry.key]) == "function" then
			if safeCall(SlashCmdList[entry.key], name) then
				return entry.text .. " " .. name
			end
		end
	end
	return nil
end

function MSGF.SuggestInvite(name)
	if not name or name == "" then
		return false
	end

	-- 1. a client function that takes a name
	local fname = preferredFunction()
	if fname then
		if safeCall(env()[fname], name) then
			MSGF.lastSuggestPath = fname
			MSGF.Print("suggested an invite for " .. name .. " through " .. fname)
			return true
		end
	end

	-- 2. a server side slash command
	local used = slashSuggest(name)
	if used then
		MSGF.lastSuggestPath = used
		MSGF.Print("suggested an invite for " .. name .. " through " .. used)
		return true
	end

	-- 3. the real menu, so you click the real entry
	MSGF.lastSuggestPath = "player menu"
	MSGF.Print("no direct call found on this client, opening the player menu for "
		.. name .. " - pick Suggest an invite there, then run /msgf probe and send me the output")
	return MSGF.OpenStockPlayerMenu(name)
end

-- Probe ---------------------------------------------------------------------

local function printList(label, list, format)
	if #list == 0 then
		line(label .. ": none")
		return
	end
	line(label .. ": " .. #list)
	for i = 1, #list do
		if i > 12 then
			line("  ... " .. (#list - 12) .. " more")
			break
		end
		line("  " .. format(list[i]))
	end
end

local function plain(v)
	return tostring(v)
end

function MSGF.Probe()
	local d = MSGF.Discover(true)
	local build = "?"
	if type(GetBuildInfo) == "function" then
		build = tostring(GetBuildInfo())
	end
	MSGF.Print("probe, addon " .. tostring(MSGF.VERSION) .. ", client " .. build)
	MSGF.PrintGroupState()
	printList("globals containing suggest", d.functions, plain)
	printList("slash commands containing suggest", d.slash, function(e)
		return e.text .. "  (" .. e.global .. ", key " .. tostring(e.key) .. ")"
	end)
	printList("UnitPopupButtons containing SUGGEST", d.buttons, plain)
	printList("menus carrying that button", d.menus, plain)
	printList("dialogs containing SUGGEST or INVITE", d.dialogs, plain)
	local e = env()
	local names = {}
	for i = 1, #KNOWN_NAMES do
		table.insert(names, KNOWN_NAMES[i] .. " = " .. type(e[KNOWN_NAMES[i]]))
	end
	for i = 1, #REPORT_NAMES do
		table.insert(names, REPORT_NAMES[i] .. " = " .. type(e[REPORT_NAMES[i]]))
	end
	printList("exact name checks", names, plain)
	line("auto call target: " .. tostring(preferredFunction() or "none, the player menu is used instead"))
	line("last suggest path: " .. tostring(MSGF.lastSuggestPath or "not used yet"))
	line("last menu path: " .. tostring(MSGF.lastMenuPath or "not used yet"))
end
