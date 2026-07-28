-- Manastorm Group Finder 3.0.3
-- UI.lua - window, table, editing, player menu, filters, whisper, minimap button.

MSGF = MSGF or {}

local ROW_H = 18
local MAX_ROWS = 40
local PAD = 14
local SCROLL_W = 20

local COLS = {
	{ key = "time",    label = "Time",    w = 62 },
	{ key = "name",    label = "Name",    w = 104 },
	{ key = "role",    label = "Role",    w = 104, edit = true },
	{ key = "aura",    label = "Aura",    w = 66,  edit = true },
	{ key = "looms",   label = "Looms",   w = 72,  edit = true },
	{ key = "level",   label = "Lvl",     w = 40,  edit = true },
	{ key = "wsp",     label = "W",       w = 26,  whisper = true },
	{ key = "message", label = "Message", w = 260, flex = true },
}

local SKINS = {
	vanilla = {
		backdrop = {
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		},
		titleColor = { 1, 0.82, 0 },
		headerColor = { 1, 0.82, 0 },
		altAlpha = 0.10,
		lines = false,
	},
	dark = {
		backdrop = {
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		},
		bgColor = { 0.06, 0.07, 0.09, 0.94 },
		borderColor = { 0.35, 0.38, 0.45, 1 },
		titleColor = { 1, 1, 1 },
		headerColor = { 0.75, 0.82, 0.95 },
		altAlpha = 0.06,
		lines = false,
	},
	grid = {
		backdrop = {
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		},
		bgColor = { 0.04, 0.05, 0.07, 0.96 },
		borderColor = { 0.45, 0.40, 0.30, 1 },
		titleColor = { 1, 0.9, 0.6 },
		headerColor = { 1, 0.86, 0.5 },
		altAlpha = 0.16,
		lines = true,
	},
}

local frame, headerBar, tableArea, scrollBar, countText, titleText, subText
local filtersButton, alertsButton, clearButton, whisperButton, resizeGrip
local filterPanel, clickCatcher, menuFrame, copyFrame, levelEdit
local headers, rows, tabs, seps = {}, {}, {}, {}
local currentList = {}
local offset = 0
local visibleRows = 15

local YESNO_COLOR = {
	yes = { 0.45, 0.95, 0.5 },
	maybe = { 1, 0.82, 0.2 },
	no = { 0.75, 0.75, 0.75 },
}

local function skin()
	local name = (MSGF_DB and MSGF_DB.style) or "vanilla"
	return SKINS[name] or SKINS.vanilla
end

-- Player menu ---------------------------------------------------------------

local function ensureTarget(name)
	if UnitExists("target") and UnitName("target") == name then
		return true
	end
	TargetByName(name, true)
	if UnitExists("target") and UnitName("target") == name then
		return true
	end
	MSGF.Print(name .. " is not nearby, so that action needs the player in range.")
	return false
end

local function showCopyBox(name)
	if not copyFrame then
		copyFrame = CreateFrame("Frame", "MSGF_CopyFrame", UIParent)
		copyFrame:SetWidth(240)
		copyFrame:SetHeight(70)
		copyFrame:SetPoint("CENTER")
		copyFrame:SetFrameStrata("DIALOG")
		copyFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 26,
			insets = { left = 9, right = 9, top = 9, bottom = 9 },
		})
		local label = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOP", 0, -14)
		label:SetText("Ctrl+C to copy")
		local box = CreateFrame("EditBox", "MSGF_CopyBox", copyFrame, "InputBoxTemplate")
		box:SetWidth(180)
		box:SetHeight(20)
		box:SetPoint("BOTTOM", 0, 16)
		box:SetAutoFocus(true)
		box:SetScript("OnEscapePressed", function(self) copyFrame:Hide() end)
		box:SetScript("OnEnterPressed", function(self) copyFrame:Hide() end)
		copyFrame.box = box
		table.insert(UISpecialFrames, "MSGF_CopyFrame")
	end
	copyFrame:Show()
	copyFrame.box:SetText(name)
	copyFrame.box:HighlightText()
	copyFrame.box:SetFocus()
end

-- The server refuses InviteUnit when you are in a group without rank, so the
-- row offers the client's own suggestion instead. State is read at click time.
local function inviteEntry(name)
	if MSGF.CanInvite and not MSGF.CanInvite() then
		return { text = "Suggest Invite", notCheckable = true, func = function()
			MSGF.SuggestInvite(name)
		end }
	end
	return { text = "Invite", notCheckable = true, func = function()
		InviteUnit(name)
	end }
end

local function openPlayerMenu(bucket, name, anchor)
	if not menuFrame then
		menuFrame = CreateFrame("Frame", "MSGF_MenuFrame", UIParent, "UIDropDownMenuTemplate")
	end
	local menu = {
		{ text = name, isTitle = true, notCheckable = true },
		{ text = "Whisper", notCheckable = true, func = function()
			ChatFrame_OpenChat("/w " .. name .. " ", DEFAULT_CHAT_FRAME)
		end },
		inviteEntry(name),
		{ text = "Target", notCheckable = true, func = function()
			ensureTarget(name)
		end },
		{ text = "Inspect", notCheckable = true, func = function()
			if ensureTarget(name) then
				if CheckInteractDistance("target", 1) then
					InspectUnit("target")
				else
					MSGF.Print("too far away to inspect " .. name)
				end
			end
		end },
		{ text = "Trade", notCheckable = true, func = function()
			if ensureTarget(name) then
				if CheckInteractDistance("target", 2) then
					InitiateTrade("target")
				else
					MSGF.Print("too far away to trade with " .. name)
				end
			end
		end },
		{ text = "Follow", notCheckable = true, func = function()
			if ensureTarget(name) then
				FollowUnit("target")
			end
		end },
		{ text = "Duel", notCheckable = true, func = function()
			if ensureTarget(name) then
				StartDuel("target")
			end
		end },
		{ text = "Who", notCheckable = true, func = function()
			SendWho(name)
		end },
		{ text = "Add friend", notCheckable = true, func = function()
			AddFriend(name)
		end },
		{ text = "Ignore", notCheckable = true, func = function()
			AddIgnore(name)
		end },
		{ text = "Copy name", notCheckable = true, func = function()
			showCopyBox(name)
		end },
		{ text = "Remove row", notCheckable = true, func = function()
			MSGF.RemoveRow(bucket, name)
		end },
		{ text = "Cancel", notCheckable = true, func = function() end },
	}
	-- Wording is sometimes genuinely ambiguous, so allow a manual move.
	local labels = { LFM = "Move to LFM", LFG = "Move to LFG", UNSURE = "Move to Unsure" }
	for i = 1, #MSGF.BUCKETS do
		local target = MSGF.BUCKETS[i]
		if target ~= bucket then
			table.insert(menu, #menu, {
				text = labels[target],
				notCheckable = true,
				func = function()
					MSGF.MoveRow(bucket, name, target)
				end,
			})
		end
	end
	EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
end

-- Layout --------------------------------------------------------------------

local function layout()
	if not frame then
		return
	end
	local avail = frame:GetWidth() - PAD * 2 - SCROLL_W
	local fixed = 0
	for i = 1, #COLS do
		if not COLS[i].flex then
			fixed = fixed + COLS[i].w + 6
		end
	end
	local flexW = avail - fixed - 6
	if flexW < 120 then
		flexW = 120
	end
	local x = 0
	for i = 1, #COLS do
		local c = COLS[i]
		c.cw = c.flex and flexW or c.w
		c.x = x
		x = x + c.cw + 6
	end

	for i = 1, #COLS do
		local h = headers[i]
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", headerBar, "TOPLEFT", COLS[i].x, 0)
		h:SetWidth(COLS[i].cw)
		h:SetHeight(18)
	end

	local areaH = tableArea:GetHeight()
	visibleRows = math.floor(areaH / ROW_H)
	if visibleRows < 1 then visibleRows = 1 end
	if visibleRows > MAX_ROWS then visibleRows = MAX_ROWS end

	for i = 1, MAX_ROWS do
		local row = rows[i]
		row:SetWidth(avail)
		for j = 1, #COLS do
			local cell = row.cells[COLS[j].key]
			cell:ClearAllPoints()
			cell:SetPoint("LEFT", row, "LEFT", COLS[j].x, 0)
			cell:SetWidth(COLS[j].cw)
		end
		if i <= visibleRows then
			row:Show()
		else
			row:Hide()
		end
	end

	local useLines = skin().lines
	for i = 1, #COLS do
		local sep = seps[i]
		sep:ClearAllPoints()
		sep:SetPoint("TOPLEFT", tableArea, "TOPLEFT", COLS[i].x + COLS[i].cw + 2, 0)
		sep:SetPoint("BOTTOMLEFT", tableArea, "BOTTOMLEFT", COLS[i].x + COLS[i].cw + 2, 0)
		sep:SetWidth(1)
		if useLines and i < #COLS then
			sep:Show()
		else
			sep:Hide()
		end
	end
end

-- Rendering -----------------------------------------------------------------

local function levelText(data)
	if not data.level then
		return "?"
	end
	if data.bracket then
		return tostring(data.level) .. "+"
	end
	return tostring(data.level)
end

local function paintRow(row, data, index)
	row.data = data
	row.bucket = MSGF.GetMode()
	local cells = row.cells
	local now = time()
	local age = now - (data.time or now)
	local stale = age > (MSGF_DB.stale or 300)

	cells.time:SetText(date("%H:%M:%S", data.time or now))
	if stale then
		cells.time:SetTextColor(0.55, 0.55, 0.55)
	else
		cells.time:SetTextColor(0.85, 0.85, 0.85)
	end

	cells.name:SetText(data.name or "?")
	cells.name:SetTextColor(1, 1, 1)

	cells.role:SetText(data.roleText or "?")
	if data.locked and data.locked.role then
		cells.role:SetTextColor(0.4, 0.75, 1)
	else
		cells.role:SetTextColor(0.95, 0.9, 0.7)
	end

	local function paintYesNo(cell, value, locked)
		cell:SetText(value or "no")
		if locked then
			cell:SetTextColor(0.4, 0.75, 1)
		else
			local c = YESNO_COLOR[value or "no"] or YESNO_COLOR.no
			cell:SetTextColor(c[1], c[2], c[3])
		end
	end
	paintYesNo(cells.aura, data.aura, data.locked and data.locked.aura)
	paintYesNo(cells.looms, data.looms, data.locked and data.locked.looms)

	cells.level:SetText(levelText(data))
	if data.locked and data.locked.level then
		cells.level:SetTextColor(0.4, 0.75, 1)
	else
		cells.level:SetTextColor(0.85, 0.85, 0.85)
	end

	-- The whisper cell is a one click send, so show plainly when it was used.
	if data.whispered then
		cells.wsp:SetText("|cff40ff90sent|r")
	else
		cells.wsp:SetText("|cffffd200>>|r")
	end

	cells.message:SetText(data.message or "")
	cells.message:SetTextColor(0.8, 0.82, 0.88)

	local alt = skin().altAlpha
	if index % 2 == 0 then
		row.bg:SetTexture(1, 1, 1, alt)
	else
		row.bg:SetTexture(1, 1, 1, alt * 0.35)
	end
	row.bg:Show()
	row:Show()
end

local function updateRows()
	if not frame then
		return
	end
	local total = #currentList
	local maxOffset = total - visibleRows
	if maxOffset < 0 then maxOffset = 0 end
	if offset > maxOffset then offset = maxOffset end

	scrollBar:SetMinMaxValues(0, maxOffset)
	scrollBar.updating = true
	scrollBar:SetValue(offset)
	scrollBar.updating = nil
	if maxOffset > 0 then
		scrollBar:Show()
	else
		scrollBar:Hide()
	end

	for i = 1, MAX_ROWS do
		local row = rows[i]
		if i <= visibleRows then
			local data = currentList[i + offset]
			if data then
				paintRow(row, data, i + offset)
			else
				row.data = nil
				for j = 1, #COLS do
					row.cells[COLS[j].key]:SetText("")
				end
				row.bg:Hide()
			end
		else
			row:Hide()
		end
	end
end

function MSGF.Refresh()
	if not frame or not MSGF_DB then
		return
	end
	local mode = MSGF.GetMode()
	currentList = MSGF.GetSortedRows(mode, MSGF_DB.sortKey, MSGF_DB.sortAsc)
	for i = 1, #MSGF.BUCKETS do
		local key = MSGF.BUCKETS[i]
		local tab = tabs[key]
		if tab then
			local count = #(MSGF_DB.rows[key] or {})
			tab:SetText(key == "UNSURE" and ("Unsure " .. count) or (key .. " " .. count))
			if key == mode then
				tab:LockHighlight()
			else
				tab:UnlockHighlight()
			end
		end
	end
	-- On LFM rows aura and looms describe what the leader asks for, on LFG rows
	-- they describe what the player has.
	local leaderView = (mode == "LFM")
	for i = 1, #COLS do
		local key = COLS[i].key
		if key == "aura" then
			headers[i].label:SetText(leaderView and "Aura req" or "Aura")
		elseif key == "looms" then
			headers[i].label:SetText(leaderView and "Looms req" or "Looms")
		end
	end
	countText:SetText(#currentList .. " of " .. #(MSGF_DB.rows[mode] or {}) .. " shown")
	MSGF.UpdateAlertButtons()
	updateRows()
end

-- Alerts button text plus the speaker icon next to it.
function MSGF.UpdateAlertButtons()
	local a = MSGF_DB and MSGF_DB.alert
	if not a then
		return
	end
	if alertsButton then
		alertsButton:SetText("Alerts: " .. (a.enabled and "ON" or "OFF"))
	end
	if soundButton then
		-- Sound on is a bright bell. Muted is the same bell desaturated, with the
		-- stock red cross over it. VOICECHAT-MUTED is only the cross, so it fills
		-- the button cleanly.
		local icon = soundButton:GetNormalTexture()
		if icon and icon.SetDesaturated then
			icon:SetDesaturated(not a.sound)
		end
		if soundButton.cross then
			if a.sound then
				soundButton.cross:Hide()
			else
				soundButton.cross:Show()
			end
		end
		-- Only a slight dim while alerts are off. The bell still has to be legible
		-- against the window frame.
		soundButton:SetAlpha(a.enabled and 1 or 0.85)
	end
end

function MSGF.RefreshTimes()
	if frame and frame:IsShown() then
		updateRows()
	end
end

-- Editing -------------------------------------------------------------------

local function nextInCycle(cycle, current)
	for i = 1, #cycle do
		if cycle[i] == current then
			return cycle[i % #cycle + 1]
		end
	end
	return cycle[1]
end

local ROLE_CYCLE = { "?", "tank", "heal", "damage", "tank, damage", "heal, damage", "tank, heal, damage" }
local YESNO_CYCLE = { "no", "maybe", "yes" }

local function applyRoleText(data, text)
	data.roleText = text
	data.roleSet = {}
	for i = 1, #MSGF.ROLE_ORDER do
		if text:find(MSGF.ROLE_ORDER[i], 1, true) then
			data.roleSet[MSGF.ROLE_ORDER[i]] = true
		end
	end
end

local function openLevelEditor(row, cell)
	if not levelEdit then
		levelEdit = CreateFrame("EditBox", "MSGF_LevelEdit", frame, "InputBoxTemplate")
		levelEdit:SetHeight(18)
		levelEdit:SetWidth(40)
		levelEdit:SetAutoFocus(true)
		levelEdit:SetNumeric(true)
		levelEdit:SetMaxLetters(2)
		levelEdit:Hide()
		local function commit(self)
			local data = self.data
			if data then
				local v = tonumber(self:GetText())
				if v and v >= 1 and v <= 80 then
					data.level = v
					data.bracket = false
				else
					data.level = nil
				end
				data.locked = data.locked or {}
				data.locked.level = true
			end
			self.data = nil
			self:ClearFocus()
			self:Hide()
			MSGF.Refresh()
		end
		levelEdit:SetScript("OnEnterPressed", commit)
		-- Clicking anywhere else drops focus, which saves and closes the editor.
		levelEdit:SetScript("OnEditFocusLost", commit)
		levelEdit:SetScript("OnEscapePressed", function(self)
			self.data = nil
			self:ClearFocus()
			self:Hide()
		end)
	end
	levelEdit.data = row.data
	levelEdit:ClearAllPoints()
	levelEdit:SetPoint("LEFT", cell, "LEFT", -4, 0)
	levelEdit:SetText(row.data.level and tostring(row.data.level) or "")
	levelEdit:Show()
	levelEdit:SetFocus()
	levelEdit:HighlightText()
end

local function columnAt(row)
	local scale = row:GetEffectiveScale()
	local cursorX = GetCursorPosition() / scale
	local rel = cursorX - row:GetLeft()
	for i = 1, #COLS do
		if rel >= COLS[i].x and rel < COLS[i].x + (COLS[i].cw or COLS[i].w) then
			return COLS[i]
		end
	end
	return nil
end

local function onRowClick(row, button)
	local data = row.data
	if not data then
		return
	end
	if button == "RightButton" then
		openPlayerMenu(MSGF.GetMode(), data.name, row)
		return
	end
	local col = columnAt(row)
	if col and col.whisper then
		MSGF.SendWhisper(data, MSGF.GetMode())
		return
	end
	if not col or not col.edit then
		return
	end
	data.locked = data.locked or {}
	if col.key == "role" then
		applyRoleText(data, nextInCycle(ROLE_CYCLE, data.roleText or "?"))
		data.locked.role = true
	elseif col.key == "aura" then
		data.aura = nextInCycle(YESNO_CYCLE, data.aura or "no")
		data.locked.aura = true
	elseif col.key == "looms" then
		data.looms = nextInCycle(YESNO_CYCLE, data.looms or "no")
		data.locked.looms = true
	elseif col.key == "level" then
		openLevelEditor(row, row.cells.level)
		return
	end
	MSGF.Refresh()
end

-- Whisper setup -------------------------------------------------------------

local whisperPanel

-- Built without the stock input box art, which only drew its stretched middle
-- piece on the first box. Own backdrop, so both boxes look the same.
local function makeTemplateBox(parent, y, maxLetters)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
	box:SetWidth(410)
	box:SetHeight(22)
	box:SetAutoFocus(false)
	box:SetMaxLetters(maxLetters or 200)
	box:SetFontObject("ChatFontNormal")
	box:SetTextColor(1, 1, 1)
	box:SetTextInsets(6, 6, 0, 0)
	box:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	box:SetBackdropColor(0, 0, 0, 0.9)
	box:SetBackdropBorderColor(0.45, 0.45, 0.52, 1)
	box:EnableMouse(true)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
end

local function saveWhisperPanel()
	if not whisperPanel then
		return
	end
	MSGF.SetWhisperTemplate("LFM", whisperPanel.lfmBox:GetText() or "")
	MSGF.SetWhisperTemplate("LFG", whisperPanel.lfgBox:GetText() or "")
	MSGF.Print("whisper templates saved")
end

local function createWhisperPanel()
	whisperPanel = CreateFrame("Frame", "MSGF_WhisperPanel", UIParent)
	whisperPanel:SetWidth(470)
	whisperPanel:SetHeight(266)
	whisperPanel:SetPoint("CENTER")
	whisperPanel:SetFrameStrata("FULLSCREEN_DIALOG")
	whisperPanel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})
	whisperPanel:EnableMouse(true)
	whisperPanel:SetMovable(true)
	whisperPanel:RegisterForDrag("LeftButton")
	whisperPanel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	whisperPanel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	-- Solid backing so chat behind the panel cannot be read through it.
	local solid = whisperPanel:CreateTexture(nil, "BORDER")
	solid:SetTexture(0.04, 0.04, 0.05, 1)
	solid:SetPoint("TOPLEFT", 7, -7)
	solid:SetPoint("BOTTOMRIGHT", -7, 7)

	local title = whisperPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 20, -18)
	title:SetText("Whisper templates")

	local lfmLabel = whisperPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lfmLabel:SetPoint("TOPLEFT", 20, -44)
	lfmLabel:SetText("LFM tab - sent to a player leading a group looking for players")
	whisperPanel.lfmBox = makeTemplateBox(whisperPanel, -60)

	local lfgLabel = whisperPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lfgLabel:SetPoint("TOPLEFT", 20, -92)
	lfgLabel:SetText("LFG tab - sent to a player who is looking for a group")
	whisperPanel.lfgBox = makeTemplateBox(whisperPanel, -108)

	local tokens = whisperPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	tokens:SetPoint("TOPLEFT", 22, -138)
	tokens:SetWidth(420)
	tokens:SetJustifyH("LEFT")
	tokens:SetText("Placeholders, filled in when you click: {name} {role} {level} {aura}"
		.. " {looms} {size} for the listed player, {myname} {mylevel} for you.")

	local note = whisperPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", 22, -184)
	note:SetWidth(420)
	note:SetJustifyH("LEFT")
	note:SetText("Nothing is sent automatically. The W column in each row sends the"
		.. " template for the tab you are on, once per click.")

	local save = CreateFrame("Button", nil, whisperPanel, "UIPanelButtonTemplate")
	save:SetWidth(90)
	save:SetHeight(22)
	save:SetPoint("BOTTOMRIGHT", -104, 18)
	save:SetText("Save")
	save:SetScript("OnClick", saveWhisperPanel)

	local close = CreateFrame("Button", nil, whisperPanel, "UIPanelButtonTemplate")
	close:SetWidth(90)
	close:SetHeight(22)
	close:SetPoint("BOTTOMRIGHT", -18, 18)
	close:SetText("Close")
	close:SetScript("OnClick", function()
		saveWhisperPanel()
		whisperPanel:Hide()
	end)

	whisperPanel.lfmBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		saveWhisperPanel()
	end)
	whisperPanel.lfgBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		saveWhisperPanel()
	end)

	table.insert(UISpecialFrames, "MSGF_WhisperPanel")
	whisperPanel:Hide()
end

function MSGF.ShowWhisperSetup()
	if not whisperPanel then
		createWhisperPanel()
	end
	whisperPanel.lfmBox:SetText(MSGF.WhisperTemplate("LFM") or "")
	whisperPanel.lfgBox:SetText(MSGF.WhisperTemplate("LFG") or "")
	whisperPanel:Show()
end

-- The Whisper button is a switch, so a second click closes the panel. Whatever
-- is typed is kept, the same as the Close button does.
function MSGF.ToggleWhisperSetup()
	if whisperPanel and whisperPanel:IsShown() then
		saveWhisperPanel()
		whisperPanel:Hide()
		return
	end
	MSGF.ShowWhisperSetup()
end

-- Filters panel -------------------------------------------------------------

local function closeFilterPanel()
	if filterPanel then filterPanel:Hide() end
	if clickCatcher then clickCatcher:Hide() end
end

local function makeCheck(parent, label, x, y, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetWidth(22)
	check:SetHeight(22)
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", check, "RIGHT", 2, 0)
	text:SetText(label)
	check:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
		MSGF.Refresh()
		MSGF.RefreshFilterPanel()
	end)
	return check
end

local function createFilterPanel()
	clickCatcher = CreateFrame("Frame", "MSGF_ClickCatcher", UIParent)
	clickCatcher:SetAllPoints(UIParent)
	clickCatcher:SetFrameStrata("FULLSCREEN")
	clickCatcher:EnableMouse(true)
	clickCatcher:SetScript("OnMouseDown", closeFilterPanel)
	clickCatcher:Hide()

	filterPanel = CreateFrame("Frame", "MSGF_FilterPanel", UIParent)
	filterPanel:SetWidth(210)
	filterPanel:SetHeight(374)
	filterPanel:SetFrameStrata("FULLSCREEN_DIALOG")
	filterPanel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})
	filterPanel:EnableMouse(true)

	-- Solid backing so nothing underneath shows through the panel.
	local solid = filterPanel:CreateTexture(nil, "BORDER")
	solid:SetTexture(0.04, 0.04, 0.05, 1)
	solid:SetPoint("TOPLEFT", 7, -7)
	solid:SetPoint("BOTTOMRIGHT", -7, 7)

	filterPanel:Hide()

	local title = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Show and alert on")

	local p = filterPanel
	p.roleChecks = {}
	local y = -36
	for i = 1, #MSGF.ROLE_ORDER do
		local role = MSGF.ROLE_ORDER[i]
		p.roleChecks[role] = makeCheck(p, role, 14, y, function(value)
			MSGF_DB.filter.roles[role] = value
		end)
		y = y - 24
	end
	p.auraCheck = makeCheck(p, "aura", 14, y, function(value)
		MSGF_DB.filter.needAura = value
	end)
	y = y - 24
	p.loomsCheck = makeCheck(p, "looms", 14, y, function(value)
		MSGF_DB.filter.needLooms = value
	end)
	y = y - 30

	-- Which side of the board you are on.
	local intentLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	intentLabel:SetPoint("TOPLEFT", 16, y)
	intentLabel:SetText("I am looking for")
	y = y - 20

	p.intentChecks = {}
	local INTENTS = {
		{ "GROUP", "a group to join" },
		{ "PLAYERS", "players to join me" },
		{ "BOTH", "both" },
	}
	for i = 1, #INTENTS do
		local value, text = INTENTS[i][1], INTENTS[i][2]
		p.intentChecks[value] = makeCheck(p, text, 14, y, function()
			MSGF.SetFilterIntent(value)
			MSGF.RefreshFilterPanel()
		end)
		y = y - 22
	end
	y = y - 6

	local levelLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	levelLabel:SetPoint("TOPLEFT", 16, y)
	levelLabel:SetText("level from / to, 0 = any")
	y = y - 20

	p.minLevel = CreateFrame("EditBox", "MSGF_MinLevel", p, "InputBoxTemplate")
	p.minLevel:SetWidth(38)
	p.minLevel:SetHeight(18)
	p.minLevel:SetPoint("TOPLEFT", 20, y)
	p.minLevel:SetAutoFocus(false)
	p.minLevel:SetNumeric(true)
	p.minLevel:SetMaxLetters(2)

	p.maxLevel = CreateFrame("EditBox", "MSGF_MaxLevel", p, "InputBoxTemplate")
	p.maxLevel:SetWidth(38)
	p.maxLevel:SetHeight(18)
	p.maxLevel:SetPoint("LEFT", p.minLevel, "RIGHT", 14, 0)
	p.maxLevel:SetAutoFocus(false)
	p.maxLevel:SetNumeric(true)
	p.maxLevel:SetMaxLetters(2)

	local function commitLevels()
		MSGF_DB.filter.minLevel = tonumber(p.minLevel:GetText()) or 0
		MSGF_DB.filter.maxLevel = tonumber(p.maxLevel:GetText()) or 0
		MSGF.Refresh()
	end
	p.minLevel:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	p.maxLevel:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	p.minLevel:SetScript("OnEditFocusLost", commitLevels)
	p.maxLevel:SetScript("OnEditFocusLost", commitLevels)
	y = y - 30

	local wordLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	wordLabel:SetPoint("TOPLEFT", 16, y)
	wordLabel:SetText("message contains")
	y = y - 20

	p.word = CreateFrame("EditBox", "MSGF_WordFilter", p, "InputBoxTemplate")
	p.word:SetWidth(150)
	p.word:SetHeight(18)
	p.word:SetPoint("TOPLEFT", 20, y)
	p.word:SetAutoFocus(false)
	p.word:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	p.word:SetScript("OnEditFocusLost", function(self)
		MSGF_DB.filter.word = self:GetText() or ""
		MSGF.Refresh()
	end)
	y = y - 30

	local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	reset:SetWidth(80)
	reset:SetHeight(20)
	reset:SetPoint("TOPLEFT", 20, y)
	reset:SetText("Reset")
	reset:SetScript("OnClick", function()
		MSGF_DB.filter.roles = { tank = false, heal = false, damage = false }
		MSGF_DB.filter.needAura = false
		MSGF_DB.filter.needLooms = false
		MSGF_DB.filter.minLevel = 0
		MSGF_DB.filter.maxLevel = 0
		MSGF_DB.filter.word = ""
		MSGF_DB.filter.intent = "BOTH"
		MSGF_DB.alert.mode = "ANY"
		MSGF.RefreshFilterPanel()
		MSGF.Refresh()
	end)

	local close = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	close:SetWidth(80)
	close:SetHeight(20)
	close:SetPoint("LEFT", reset, "RIGHT", 8, 0)
	close:SetText("Close")
	close:SetScript("OnClick", closeFilterPanel)
end

function MSGF.RefreshFilterPanel()
	if not filterPanel then
		return
	end
	local f = MSGF_DB.filter
	for i = 1, #MSGF.ROLE_ORDER do
		local role = MSGF.ROLE_ORDER[i]
		filterPanel.roleChecks[role]:SetChecked(f.roles[role] and true or false)
	end
	filterPanel.auraCheck:SetChecked(f.needAura and true or false)
	filterPanel.loomsCheck:SetChecked(f.needLooms and true or false)
	local intent = f.intent or "BOTH"
	for value, check in pairs(filterPanel.intentChecks) do
		check:SetChecked(value == intent)
	end
	filterPanel.minLevel:SetText((f.minLevel or 0) > 0 and tostring(f.minLevel) or "")
	filterPanel.maxLevel:SetText((f.maxLevel or 0) > 0 and tostring(f.maxLevel) or "")
	filterPanel.word:SetText(f.word or "")
end

local function toggleFilterPanel()
	if not filterPanel then
		createFilterPanel()
	end
	if filterPanel:IsShown() then
		closeFilterPanel()
		return
	end
	-- Always anchored to the button, never to the cursor.
	filterPanel:ClearAllPoints()
	filterPanel:SetPoint("TOPRIGHT", filtersButton, "BOTTOMRIGHT", 0, -4)
	MSGF.RefreshFilterPanel()
	clickCatcher:Show()
	filterPanel:Show()
end

-- Style ---------------------------------------------------------------------

function MSGF.ApplyStyle()
	if not frame then
		return
	end
	local s = skin()
	frame:SetBackdrop(s.backdrop)
	if s.bgColor then
		frame:SetBackdropColor(s.bgColor[1], s.bgColor[2], s.bgColor[3], s.bgColor[4])
	end
	if s.borderColor then
		frame:SetBackdropBorderColor(s.borderColor[1], s.borderColor[2], s.borderColor[3], s.borderColor[4])
	end
	titleText:SetTextColor(s.titleColor[1], s.titleColor[2], s.titleColor[3])
	for i = 1, #headers do
		headers[i].label:SetTextColor(s.headerColor[1], s.headerColor[2], s.headerColor[3])
	end
	layout()
	MSGF.Refresh()
end

-- Window --------------------------------------------------------------------

local function savePosition()
	local x, y = frame:GetLeft(), frame:GetBottom()
	if x and y then
		MSGF_DB.window.x = x
		MSGF_DB.window.y = y
		MSGF_DB.window.hasPos = true
	end
	MSGF_DB.window.w = frame:GetWidth()
	MSGF_DB.window.h = frame:GetHeight()
end

local function createWindow()
	frame = CreateFrame("Frame", "MSGF_Window", UIParent)
	frame:SetWidth(MSGF_DB.window.w or 780)
	frame:SetHeight(MSGF_DB.window.h or 460)
	if MSGF_DB.window.hasPos then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", MSGF_DB.window.x, MSGF_DB.window.y)
	else
		frame:SetPoint("CENTER")
	end
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetMinResize(640, 260)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(self, delta)
		scrollBar:SetValue(offset - (delta or 0) * 3)
	end)
	table.insert(UISpecialFrames, "MSGF_Window")

	titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("TOPLEFT", PAD + 2, -16)
	titleText:SetText("Manastorm Group Finder")

	subText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
	subText:SetText("Chat scanner - /msgf")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -8, -8)

	-- Tabs
	local prev
	for i = 1, #MSGF.BUCKETS do
		local key = MSGF.BUCKETS[i]
		local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		tab:SetWidth(92)
		tab:SetHeight(22)
		if prev then
			tab:SetPoint("LEFT", prev, "RIGHT", 6, 0)
		else
			tab:SetPoint("TOPLEFT", PAD, -46)
		end
		tab:SetText(key)
		tab:SetScript("OnClick", function()
			offset = 0
			MSGF.SetMode(key)
		end)
		tabs[key] = tab
		prev = tab
	end

	alertsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	alertsButton:SetWidth(96)
	alertsButton:SetHeight(22)
	alertsButton:SetPoint("TOPRIGHT", -PAD - 26, -46)
	alertsButton:SetText("Alerts: OFF")
	alertsButton:RegisterForClicks("LeftButtonUp")
	alertsButton:SetScript("OnClick", function(self)
		MSGF_DB.alert.enabled = not MSGF_DB.alert.enabled
		MSGF.Print("alerts " .. (MSGF_DB.alert.enabled and "on" or "off"))
		MSGF.Refresh()
	end)
	alertsButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Alerts")
		GameTooltip:AddLine("Click switches alerts on or off.", 1, 1, 1)
		GameTooltip:AddLine("A new row matching the filters pops up on screen.", 0.7, 0.7, 0.7)
		GameTooltip:AddLine("Right click the minimap button to move the popup.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	alertsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Speaker. The popup is always shown when alerts are on. This only decides
	-- whether the popup is silent or comes with a sound.
	soundButton = CreateFrame("Button", nil, frame)
	soundButton:SetWidth(22)
	soundButton:SetHeight(22)
	soundButton:SetPoint("LEFT", alertsButton, "RIGHT", 4, 0)
	soundButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	soundButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Bell_01")
	local speaker = soundButton:GetNormalTexture()
	if speaker then
		speaker:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		-- 87 percent of the button, centred. 22 x 0.87 is 19.1, so the inset is
		-- 1.4 on every side.
		speaker:ClearAllPoints()
		speaker:SetPoint("TOPLEFT", soundButton, "TOPLEFT", 1.4, -1.4)
		speaker:SetPoint("BOTTOMRIGHT", soundButton, "BOTTOMRIGHT", -1.4, 1.4)
	end
	-- VOICECHAT-ON is dropped. The arcs sit off centre inside their own file and
	-- fill only part of it, so they cannot be lined up with the bell without
	-- guessing at texture coordinates. Sound on is a bright bell instead.
	soundButton.cross = soundButton:CreateTexture(nil, "OVERLAY")
	soundButton.cross:SetTexture("Interface\\COMMON\\VOICECHAT-MUTED")
	soundButton.cross:SetPoint("TOPLEFT", soundButton, "TOPLEFT", 1.4, -1.4)
	soundButton.cross:SetPoint("BOTTOMRIGHT", soundButton, "BOTTOMRIGHT", -1.4, 1.4)
	soundButton.cross:Hide()

	-- One builder, used by OnEnter and again by OnClick, so the text follows the
	-- state without the cursor having to leave the button and come back.
	local function soundTooltip()
		GameTooltip:SetOwner(soundButton, "ANCHOR_LEFT")
		GameTooltip:AddLine("Alert sound")
		GameTooltip:AddLine(MSGF_DB.alert.sound
			and "On. The popup comes with a sound."
			or "Muted. The popup appears silently.", 1, 1, 1)
		GameTooltip:AddLine("Click to " .. (MSGF_DB.alert.sound and "mute." or "unmute."), 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end

	soundButton:SetScript("OnClick", function()
		MSGF_DB.alert.sound = not MSGF_DB.alert.sound
		MSGF.Print("alert sound " .. (MSGF_DB.alert.sound and "on" or "off"))
		if MSGF_DB.alert.sound then
			PlaySound("RaidWarning")
		end
		MSGF.UpdateAlertButtons()
		if GetMouseFocus and GetMouseFocus() == soundButton then
			soundTooltip()
		end
	end)
	soundButton:SetScript("OnEnter", function()
		soundTooltip()
	end)
	soundButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	filtersButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	filtersButton:SetWidth(80)
	filtersButton:SetHeight(22)
	filtersButton:SetPoint("RIGHT", alertsButton, "LEFT", -6, 0)
	-- Room on the right for the speaker button.
	filtersButton:SetText("Filters")
	filtersButton:SetScript("OnClick", toggleFilterPanel)

	-- Header bar
	headerBar = CreateFrame("Frame", nil, frame)
	headerBar:SetPoint("TOPLEFT", PAD, -76)
	headerBar:SetPoint("TOPRIGHT", -(PAD + SCROLL_W), -76)
	headerBar:SetHeight(18)

	for i = 1, #COLS do
		local col = COLS[i]
		local button = CreateFrame("Button", nil, headerBar)
		button:SetHeight(18)
		local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", 2, 0)
		label:SetText(col.label)
		button.label = label
		button:SetScript("OnClick", function()
			if MSGF_DB.sortKey == col.key then
				MSGF_DB.sortAsc = not MSGF_DB.sortAsc
			else
				MSGF_DB.sortKey = col.key
				MSGF_DB.sortAsc = false
			end
			offset = 0
			MSGF.Refresh()
		end)
		headers[i] = button
	end

	local headerLine = frame:CreateTexture(nil, "ARTWORK")
	headerLine:SetTexture(1, 1, 1, 0.25)
	headerLine:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -1)
	headerLine:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -1)
	headerLine:SetHeight(1)

	-- Table area
	tableArea = CreateFrame("Frame", nil, frame)
	tableArea:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -4)
	tableArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + SCROLL_W), PAD + 20)
	tableArea:EnableMouseWheel(true)
	tableArea:SetScript("OnMouseWheel", function(self, delta)
		scrollBar:SetValue(offset - (delta or 0) * 3)
	end)

	for i = 1, #COLS do
		local sep = tableArea:CreateTexture(nil, "BACKGROUND")
		sep:SetTexture(1, 1, 1, 0.12)
		sep:Hide()
		seps[i] = sep
	end

	scrollBar = CreateFrame("Slider", "MSGF_ScrollBar", frame, "UIPanelScrollBarTemplate")
	-- The stock template assumes its parent is a ScrollFrame and calls
	-- parent:SetVerticalScroll() on every value change. Our parent is a plain
	-- frame, so the inherited handler is replaced before any value is set.
	scrollBar:SetScript("OnValueChanged", function(self, value)
		local newOffset = math.floor((value or 0) + 0.5)
		if newOffset ~= offset then
			offset = newOffset
			if not self.updating then
				updateRows()
			end
		end
	end)
	scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD + 2, -100)
	scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD + 2, PAD + 40)
	scrollBar:SetWidth(16)
	scrollBar:SetMinMaxValues(0, 0)
	scrollBar:SetValueStep(1)
	scrollBar:SetValue(0)

	-- Rows
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, tableArea)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", tableArea, "TOPLEFT", 0, -(i - 1) * ROW_H)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints(row)
		row.bg:SetTexture(1, 1, 1, 0.05)
		row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
		row.highlight:SetAllPoints(row)
		row.highlight:SetTexture(1, 1, 1, 0.14)
		row.cells = {}
		for j = 1, #COLS do
			local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			cell:SetHeight(ROW_H)
			cell:SetJustifyH("LEFT")
			cell:SetJustifyV("MIDDLE")
			cell:SetNonSpaceWrap(false)
			row.cells[COLS[j].key] = cell
		end
		row:SetScript("OnClick", onRowClick)
		row:SetScript("OnEnter", function(self)
			if not self.data then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:AddLine(self.data.name or "?", 1, 0.82, 0)
			GameTooltip:AddLine(self.data.message or "", 1, 1, 1, true)
			GameTooltip:AddLine(" ")
			if self.data.size then
				GameTooltip:AddLine("group size: " .. self.data.size .. " players", 0.6, 0.6, 0.6)
			end
			if self.data.wanted then
				GameTooltip:AddLine("asking for: " .. self.data.wanted, 0.6, 0.6, 0.6)
			end
			GameTooltip:AddLine("channel: " .. tostring(self.data.channel or "?"), 0.6, 0.6, 0.6)
			if MSGF.GetMode() == "LFM" then
				GameTooltip:AddLine("maybe means the leader mentioned it, requirement unclear", 0.6, 0.6, 0.6)
			else
				GameTooltip:AddLine("aura and looms on LFG rows are what that player brings", 0.6, 0.6, 0.6)
			end
			local preview = MSGF.BuildWhisper and MSGF.BuildWhisper(self.data, MSGF.GetMode())
			if preview and preview ~= "" then
				GameTooltip:AddLine("W sends: " .. preview, 0.45, 0.85, 1, true)
			else
				GameTooltip:AddLine("no whisper template yet, use the Whisper button", 0.6, 0.6, 0.6)
			end
			if self.data.whispered then
				GameTooltip:AddLine("whispered at " .. date("%H:%M:%S", self.data.whispered), 0.6, 0.6, 0.6)
			end
			GameTooltip:AddLine("left click a value to edit, right click for actions", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[i] = row
	end

	-- Bottom bar
	clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	clearButton:SetWidth(110)
	clearButton:SetHeight(20)
	clearButton:SetPoint("BOTTOMLEFT", PAD, PAD - 4)
	clearButton:SetText("Clear tab")
	clearButton:SetScript("OnClick", function()
		MSGF.ClearBucket(MSGF.GetMode())
	end)

	whisperButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	whisperButton:SetWidth(100)
	whisperButton:SetHeight(20)
	whisperButton:SetPoint("LEFT", clearButton, "RIGHT", 6, 0)
	whisperButton:SetText("Whisper...")
	whisperButton:SetScript("OnClick", function()
		MSGF.ToggleWhisperSetup()
	end)
	whisperButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Whisper templates")
		GameTooltip:AddLine("Write one line for the LFM tab and one for the LFG tab.", 1, 1, 1)
		GameTooltip:AddLine("The W column in a row sends it to that player.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	whisperButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	countText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	countText:SetPoint("BOTTOMLEFT", whisperButton, "BOTTOMRIGHT", 10, 5)
	countText:SetText("")

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMRIGHT", -PAD - 16, PAD)
	hint:SetText("Left click a value to edit - W sends your whisper - right click a row for actions")

	resizeGrip = CreateFrame("Button", nil, frame)
	resizeGrip:SetWidth(16)
	resizeGrip:SetHeight(16)
	resizeGrip:SetPoint("BOTTOMRIGHT", -6, 6)
	resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resizeGrip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	resizeGrip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		savePosition()
		layout()
		MSGF.Refresh()
	end)

	frame:SetScript("OnSizeChanged", function()
		layout()
		updateRows()
	end)
	frame:SetScript("OnShow", function()
		if MSGF_DB then MSGF_DB.window.shown = true end
		layout()
		MSGF.Refresh()
	end)
	frame:SetScript("OnHide", function()
		if MSGF_DB then MSGF_DB.window.shown = false end
		closeFilterPanel()
	end)

	MSGF.ApplyStyle()
	frame:Hide()
end

function MSGF.Show()
	if not frame then
		return
	end
	frame:Show()
	MSGF.Refresh()
end

function MSGF.Toggle()
	if not frame then
		return
	end
	if frame:IsShown() then
		frame:Hide()
	else
		MSGF.Show()
	end
end

-- Minimap button ------------------------------------------------------------

local minimapButton

local function placeMinimapButton()
	local angle = math.rad(MSGF_DB.minimap.angle or 205)
	local x = 80 * math.cos(angle)
	local y = 80 * math.sin(angle)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function createMinimapButton()
	minimapButton = CreateFrame("Button", "MSGF_MinimapButton", Minimap)
	minimapButton:SetWidth(31)
	minimapButton:SetHeight(31)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetMovable(true)

	local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("CENTER", 0, 1)

	local border = minimapButton:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetPoint("TOPLEFT")

	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimapButton:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			-- Unlock the alert popup so it can be dragged. Right click again to lock.
			if MSGF.ToggleAlertLock then
				MSGF.ToggleAlertLock()
			end
		else
			MSGF.Toggle()
		end
	end)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Manastorm Group Finder")
		GameTooltip:AddLine("Left click opens the list.", 1, 1, 1)
		GameTooltip:AddLine("Right click unlocks the alert popup so you can drag it.", 1, 1, 1)
		GameTooltip:AddLine("Drag to move around the minimap.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:SetScript("OnDragStart", function(self)
		self.dragging = true
	end)
	minimapButton:SetScript("OnDragStop", function(self)
		self.dragging = nil
	end)
	minimapButton:SetScript("OnUpdate", function(self)
		if not self.dragging then
			return
		end
		local mx, my = Minimap:GetCenter()
		local scale = UIParent:GetScale()
		local cx, cy = GetCursorPosition()
		cx, cy = cx / scale, cy / scale
		MSGF_DB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
		placeMinimapButton()
	end)
	placeMinimapButton()
end

function MSGF.UpdateMinimapButton()
	if not minimapButton then
		return
	end
	if MSGF_DB.minimap.show then
		placeMinimapButton()
		minimapButton:Show()
	else
		minimapButton:Hide()
	end
end

-- Bootstrap -----------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	-- createWindow hides the frame, which fires OnHide and clears the flag,
	-- so read the saved state first.
	local wasShown = MSGF_DB and MSGF_DB.window.shown
	local ok, err = pcall(createWindow)
	if not ok then
		MSGF.Print("|cffff5555interface error|r " .. tostring(err))
		return
	end
	pcall(createMinimapButton)
	MSGF.UpdateMinimapButton()
	if wasShown then
		MSGF.Show()
	end
end)
