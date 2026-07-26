-- Manastorm Group Finder 2.3
-- Alerts.lua - on screen notification. The frame is sized to the text, it
-- appears in place with a very short fade, holds, then fades out. Recruit
-- posts are rare, so those alerts hold two and a half times longer.

MSGF = MSGF or {}

local QUEUE_MAX = 5
local IN_TIME = 0.10
local HOLD_TIME = 2.0
local RARE_MULT = 2.5
local FADE_TIME = 0.6

-- Frame sizing bounds.
local PAD_X = 30
local PAD_TOP = 11
local PAD_BOTTOM = 11
local GAP = 4
local MIN_W = 220
local MAX_W = 520

local queue = {}
local popup, driver
local phase, timer, holdFor = nil, 0, HOLD_TIME

local BUCKET_COLOR = {
	LFM = "|cff40ff90",
	LFG = "|cff40c0ff",
	UNSURE = "|cffaaaaaa",
}

local function createPopup()
	popup = CreateFrame("Frame", "MSGF_Alert", UIParent)
	popup:SetWidth(MIN_W)
	popup:SetHeight(60)
	popup:SetFrameStrata("HIGH")
	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 20,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	popup:EnableMouse(false)

	popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	popup.title:SetPoint("TOP", popup, "TOP", 0, -PAD_TOP)
	popup.title:SetJustifyH("CENTER")

	popup.body = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	popup.body:SetPoint("TOP", popup.title, "BOTTOM", 0, -GAP)
	popup.body:SetJustifyH("CENTER")

	popup:Hide()
end

-- Fixed spot: middle of the screen vertically, two thirds across. The frame
-- grows around that point, it never moves once it is shown.
local function placePopup()
	local w = UIParent:GetWidth() or 1024
	local h = UIParent:GetHeight() or 768
	popup:ClearAllPoints()
	popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT", w * 0.66, h * 0.5)
end

-- Measure both lines and shrink the frame to fit them.
local function fitPopup()
	-- Unwrapped measurement first.
	popup.title:SetWidth(0)
	popup.body:SetWidth(0)
	local natural = math.max(popup.title:GetStringWidth() or 0, popup.body:GetStringWidth() or 0)
	local width = natural + PAD_X * 2
	if width < MIN_W then
		width = MIN_W
	end
	if width > MAX_W then
		width = MAX_W
	end
	local inner = width - PAD_X * 2
	popup.title:SetWidth(inner)
	popup.body:SetWidth(inner)

	local titleH = popup.title:GetStringHeight() or 14
	local bodyH = popup.body:GetStringHeight() or 12
	local height = PAD_TOP + titleH + GAP + bodyH + PAD_BOTTOM
	if height < 52 then
		height = 52
	end
	popup:SetWidth(width)
	popup:SetHeight(height)
end

local function startNext()
	local item = table.remove(queue, 1)
	if not item then
		phase = nil
		popup:Hide()
		return
	end
	local color = BUCKET_COLOR[item.bucket] or "|cffffffff"
	local role = item.roleText or "?"
	popup.title:SetText(color .. item.bucket .. "|r  " .. (item.name or "?")
		.. "  |cffaaaaaa" .. role .. "|r")
	popup.body:SetText(item.message or "")
	fitPopup()
	placePopup()
	-- No scaling, no sliding. It simply appears where it belongs.
	popup:SetScale(1)
	popup:SetAlpha(0)
	popup:Show()
	-- Recruit posts are the scarce side of the board, so hold them longer.
	if item.bucket == "LFM" then
		holdFor = HOLD_TIME * RARE_MULT
	else
		holdFor = HOLD_TIME
	end
	phase = "in"
	timer = 0
end

function MSGF.ShowAlert(row, bucket)
	if not popup then
		createPopup()
	end
	if #queue >= QUEUE_MAX then
		table.remove(queue, 1)
	end
	queue[#queue + 1] = {
		bucket = bucket or "LFM",
		name = row and row.name,
		message = row and row.message,
		roleText = row and row.roleText,
	}
	if not phase then
		startNext()
	end
end

driver = CreateFrame("Frame", "MSGF_AlertDriver", UIParent)
driver:SetScript("OnUpdate", function(self, elapsed)
	if not phase then
		return
	end
	timer = timer + (elapsed or 0)
	if phase == "in" then
		local p = timer / IN_TIME
		if p >= 1 then
			popup:SetAlpha(1)
			phase = "hold"
			timer = 0
		else
			popup:SetAlpha(p)
		end
	elseif phase == "hold" then
		if timer >= holdFor then
			phase = "fade"
			timer = 0
		end
	elseif phase == "fade" then
		local p = timer / FADE_TIME
		if p >= 1 then
			popup:SetAlpha(0)
			popup:Hide()
			phase = nil
			timer = 0
			if #queue > 0 then
				startNext()
			end
		else
			popup:SetAlpha(1 - p)
		end
	end
end)
