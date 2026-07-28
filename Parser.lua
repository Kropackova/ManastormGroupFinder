-- Manastorm Group Finder 2.8
-- Parser.lua - normalization, token tables, classification. No game API here.

MSGF = MSGF or {}
MSGF.VERSION = "2.8"

local function trim(s)
	s = s:gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	return s
end

-- 1. Normalization ----------------------------------------------------------

function MSGF.Normalize(raw)
	if not raw then
		return " "
	end
	local t = raw
	t = t:gsub("|c%x%x%x%x%x%x%x%x", "")
	t = t:gsub("|r", "")
	t = t:gsub("|H.-|h", "")
	t = t:gsub("|h", "")
	t = t:gsub("|T.-|t", "")
	t = t:lower()
	-- Group progress such as 3/3, 8/10 or 14/15 becomes one token, so those
	-- numbers are never mistaken for a level or a wanted count.
	t = t:gsub("(%d)%s*/%s*(%d)", "%1by%2")
	t = t:gsub(">", " gt ")
	t = t:gsub("<", " lt ")
	t = t:gsub("%+%s*(%d)", " plus%1 ")
	t = t:gsub("%+", " ")
	t = t:gsub("[/\\,%.!%?%(%)%[%]{}:;\"'%*%%=|~#&@`^]", " ")
	t = t:gsub("_", " ")
	t = t:gsub("%s+", " ")
	return " " .. trim(t) .. " "
end

local function has(t, token)
	return t:find(" " .. token .. " ", 1, true) ~= nil
end
MSGF.Has = has

local function hasAny(t, list)
	for i = 1, #list do
		if has(t, list[i]) then
			return true, list[i]
		end
	end
	return false
end

local function words(t)
	local out = {}
	for w in t:gmatch("%S+") do
		out[#out + 1] = w
	end
	return out
end

-- 2. Manastorm gate and group size ------------------------------------------
-- MS15 means Manastorm with fifteen players. Those numbers are group sizes,
-- never levels and never wanted counts, so they are tagged before anything
-- else looks at the text.

local MS_WORDS = {
	["ms"] = true, ["mss"] = true, ["msing"] = true, ["manastorm"] = true,
	["manastorms"] = true, ["manastormu"] = true, ["manastormy"] = true,
	["manastrom"] = true, ["manstorm"] = true, ["mstorm"] = true,
	["mana"] = false,
}

local MS_PHRASES = { "mana storm", "mana storms", "m storm", "ms storm" }

-- Contexts where ms means main spec loot, not Manastorm.
local MS_REJECT = {
	"ms gt os", "os gt ms", "ms os", "os ms", "mainspec", "main spec",
	"ms over os", "ms first", "ms only loot",
}

-- Tags ms15, ms 15, manastorm15 and 15 man as a size token and returns it.
function MSGF.MarkSize(t)
	local size
	local function keep(n)
		local v = tonumber(n)
		if v and v >= 2 and v <= 40 then
			size = size or v
		end
	end
	local stems = { "ms", "manastorm", "manastorms", "mstorm", "manastrom" }
	for i = 1, #stems do
		local stem = stems[i]
		t = t:gsub(" " .. stem .. "(%d+) ", function(n)
			keep(n)
			return " " .. stem .. " size" .. n .. " "
		end)
		t = t:gsub(" " .. stem .. " (%d+) ", function(n)
			keep(n)
			return " " .. stem .. " size" .. n .. " "
		end)
	end
	t = t:gsub(" (%d+) ?man ", function(n)
		keep(n)
		return " size" .. n .. " man "
	end)
	-- Spelled out small groups.
	if t:find(" duo ", 1, true) then
		keep(2)
	end
	if t:find(" trio ", 1, true) then
		keep(3)
	end
	return t, size
end

function MSGF.MatchesManastorm(t)
	for i = 1, #MS_PHRASES do
		if has(t, MS_PHRASES[i]) then
			return true
		end
	end
	local list = words(t)
	local plainMs = false
	for i = 1, #list do
		local w = list[i]
		if MS_WORDS[w] then
			if w == "ms" or w == "mss" then
				plainMs = true
			else
				return true
			end
		elseif w:match("^ms%d+s?$") or w:match("^manastorm%d+$") or w:match("^mstorm%d+$") then
			return true
		end
	end
	if plainMs then
		if hasAny(t, MS_REJECT) then
			return false
		end
		return true
	end
	return false
end

-- 3. Roles ------------------------------------------------------------------

local ROLE_WORDS = {
	tank = {
		"tank", "tanks", "tanking", "tanker", "tnk", "mt", "ot", "maintank",
		"offtank", "prot", "protection", "bear", "guardian", "t",
	},
	heal = {
		"heal", "heals", "healz", "healer", "healers", "healor", "healing",
		"healler", "healo", "resto", "rdruid", "rsham", "holy", "hpal",
		"hpala", "hpriest", "disc", "tree", "healadin", "hps", "h",
	},
	damage = {
		"dps", "dd", "damage", "dmg", "rdps", "mdps", "gigadps", "pumper",
		"pumpers", "aoe", "aoes", "ranged", "melee", "caster", "arms",
		"fury", "ret", "feral", "cat", "boomkin", "moonkin", "boomy", "ele",
		"enh", "shadow", "sp", "spriest", "destro", "affli", "affly", "demo",
		"arcane", "fire", "frost", "combat", "sub", "assa", "mm", "bm",
		"surv", "unholy", "mage", "lock", "warlock", "rogue", "hunter",
		"hunt", "d",
	},
}

local ROLE_WORD_MAP = {}
for role, list in pairs(ROLE_WORDS) do
	for i = 1, #list do
		ROLE_WORD_MAP[list[i]] = role
	end
end

local ROLE_PHRASES = {
	{ "off tank", "tank" }, { "main tank", "tank" }, { "prot pala", "tank" },
	{ "prot paladin", "tank" }, { "prot warr", "tank" }, { "blood dk", "tank" },
	{ "resto druid", "heal" }, { "resto sham", "heal" }, { "holy pala", "heal" },
	{ "holy priest", "heal" }, { "disc priest", "heal" },
	{ "frost dk", "damage" }, { "unholy dk", "damage" },
	{ "warr dps", "damage" }, { "dps warr", "damage" },
	{ "ranged dps", "damage" }, { "melee dps", "damage" },
	{ "aoe dps", "damage" }, { "dps aoe", "damage" }, { "big aoe", "damage" },
	{ "huge aoe", "damage" }, { "good aoe", "damage" }, { "big pumper", "damage" },
}

local COMPACT = { t = "tank", h = "heal", d = "damage" }
local ROLE_ORDER = { "tank", "heal", "damage" }
MSGF.ROLE_ORDER = ROLE_ORDER

-- Returns the role a single word stands for, or nil.
local function roleAt(word)
	local role = ROLE_WORD_MAP[word]
	if role then
		return role
	end
	local num, rest = word:match("^(%d+)(%a+)$")
	if num and rest and ROLE_WORD_MAP[rest] then
		return ROLE_WORD_MAP[rest]
	end
	if word:match("^%d[thd]") and word:gsub("%d[thd]", "") == "" then
		return "compact"
	end
	return nil
end

function MSGF.ParseRoles(t)
	local set = {}
	for i = 1, #ROLE_PHRASES do
		if has(t, ROLE_PHRASES[i][1]) then
			set[ROLE_PHRASES[i][2]] = true
		end
	end
	for _, w in ipairs(words(t)) do
		local role = ROLE_WORD_MAP[w]
		if role then
			set[role] = true
		else
			local num, rest = w:match("^(%d+)(%a+)$")
			if num and rest and ROLE_WORD_MAP[rest] then
				set[ROLE_WORD_MAP[rest]] = true
			elseif w:match("^%d[thd]") and w:gsub("%d[thd]", "") == "" then
				for _, letter in w:gmatch("(%d)([thd])") do
					set[COMPACT[letter]] = true
				end
			end
		end
	end
	return set
end

function MSGF.RoleText(set)
	if not set then
		return "?"
	end
	local out = {}
	for i = 1, #ROLE_ORDER do
		if set[ROLE_ORDER[i]] then
			out[#out + 1] = ROLE_ORDER[i]
		end
	end
	if #out == 0 then
		return "?"
	end
	return table.concat(out, ", ")
end

-- 4. Intent -----------------------------------------------------------------
-- Word position carries the meaning. A role named after the looking-for token
-- is a role being recruited. A role named before it is the sender describing
-- themselves. "lf dps" recruits, "dps lf" offers.

local NOISE_WORDS = {
	"what", "whats", "why", "how", "when", "where", "who", "which", "idk",
	"should", "anyone know", "does", "do i", "can i get", "is it", "are",
	"wts", "wtb", "selling", "buying", "price", "gz", "grats", "lol",
	"ty", "thanks", "says", "bugged", "broken", "question",
}

-- Wording only a group leader uses.
local LEADER_SIGNS = {
	"pst", "pst me", "pst for inv", "pst info", "pm info", "pm me",
	"pm for info", "pm for inv", "msg me", "message me", "whisper me",
	"w me", "dm me", "invite bot", "inv bot", "priority", "spots",
	"spot", "spot left", "spots left", "join us", "we need", "forming",
	"making group", "making grp", "who wants", "anyone wants", "need more",
	"include in message", "send info", "apply",
}

-- Wording only a player looking for a group uses.
local LFG_STRONG = {
	"inv me", "invite me", "inv pls", "inv plz", "inv plox", "pls inv",
	"plz inv", "invite pls", "invite plz", "send invite", "send inv",
	"invite please", "inv please", "can i join", "could i join",
	"looking to join", "want to join", "wanna join", "lf inv", "lfinv",
	"lf invite", "need inv", "need invite", "need group", "need grp",
	"need a group", "need party", "want group", "want inv", "inv here",
	"take me", "add me", "count me", "me too", "sign me up", "im free",
	"i am free", "available for", "free for ms", "ready for ms",
}

local LFM_WEAK = {
	"lfm", "lf m", "lfmore", "lf more", "need more", "spot open",
	"spots open", "spot left", "spots left", "forming", "making group",
	"making grp", "who wants", "anyone wants", "join us", "we need",
	"recruiting for ms", "still need", "more needed",
}

local LFG_WEAK = {
	"lfg", "lf g", "lf group", "lf grp", "lf grup", "lf grupe", "lf gruop",
	"looking for group", "lf party", "lf pt", "lf run", "lf raid", "lf ms",
	"lf manastorm", "lg ms", "lg", "lfms", "free dps", "free heal",
	"free tank", "any room", "room for me", "plus1", "plus2", "plus3",
	"lf farm", "lf spam", "lf carry", "lf lvling", "lf leveling",
	"searching for ms", "search for ms", "searching ms", "seeking ms",
	"any ms", "ms pls", "ms plz", "join ms", "wanna ms", "up for ms",
	"down for ms", "in for ms", "anyone doing ms", "who is doing ms",
	"whos doing ms", "looking for ms",
}

local SELF_ADS = {
	"with aura", "w aura", "have aura", "got aura", "has aura", "exp aura",
	"full looms", "full loom", "looms", "loom", "loomed", "heirloom",
	"heirlooms", "prestige", "prestiged", "geared", "i have", "i am",
	"im", "my", "free", "ready", "available", "lvling", "leveling",
	"can go", "want to go", "wanna go",
}

local function lfKindOf(w)
	if w == "lfm" or w == "lfmore" or w:match("^lfm%d+$") or w:match("^lf%d+m$") then
		return "lfm"
	end
	if w == "lfg" or w == "lg" or w == "lgf" or w == "lfms" or w:match("^lfg%d*$") then
		return "lfg"
	end
	if w == "lf" or w:match("^lf%d+$") then
		return "lf"
	end
	if w == "looking" or w == "searching" or w == "seeking" or w == "search" then
		return "lf"
	end
	if w == "need" or w == "needs" or w == "want" or w == "wants" or w == "wanted" then
		return "need"
	end
	return nil
end

-- What the looking-for token points at. "lf ms" and "lf group" mean the
-- sender wants a group and any role named afterwards describes the sender.
-- "lf dps" and "lf 2 tanks" mean the sender is filling a group. This beats
-- the role-position rule, because "lf ms dps" puts the role after the token
-- while still being an offer.
local GROUP_OBJECTS = {
	["group"] = true, ["grp"] = true, ["grup"] = true, ["gruop"] = true,
	["grupe"] = true, ["gruppe"] = true, ["party"] = true, ["pt"] = true,
	["raid"] = true, ["run"] = true, ["team"] = true, ["farm"] = true,
	["farming"] = true, ["spam"] = true, ["spamm"] = true, ["loop"] = true,
	["push"] = true, ["carry"] = true, ["leveling"] = true,
	["levelling"] = true, ["lvling"] = true, ["lvls"] = true,
	["duo"] = true, ["trio"] = true, ["ms"] = true, ["mss"] = true,
	["msing"] = true, ["manastorm"] = true, ["manastorms"] = true,
	["mstorm"] = true, ["manastrom"] = true, ["manstorm"] = true,
}

-- Words that carry no meaning between the token and its object.
local OBJECT_FILLERS = {
	["a"] = true, ["an"] = true, ["the"] = true, ["for"] = true,
	["some"] = true, ["any"] = true, ["to"] = true, ["in"] = true,
	["on"] = true, ["of"] = true, ["fast"] = true, ["quick"] = true,
	["new"] = true, ["good"] = true, ["big"] = true, ["giga"] = true,
	["chill"] = true, ["active"] = true,
}

local function lfObjectIsGroup(list, at)
	for i = at + 1, math.min(at + 4, #list) do
		local w = list[i]
		if w:match("^size%d+$") or OBJECT_FILLERS[w] then
			-- Skip and keep reading.
		elseif roleAt(w) then
			return false
		elseif w:match("^%d+$") then
			return false
		elseif GROUP_OBJECTS[w] or w:match("^ms%d+s?$")
			or w:match("^manastorm%d+$") or w:match("^mstorm%d+$") then
			return true
		else
			return false
		end
	end
	return false
end

-- A wanted headcount, not a level. Only small numbers count as a headcount
-- unless the text spells it out with m, more or a spot.
function MSGF.RecruitCount(t)
	local explicit = t:match(" lf ?(%d+) ?m ") or t:match(" lf ?(%d+) ?m[thd] ")
		or t:match(" lf ?(%d+) ?more ") or t:match(" lfm ?(%d+) ")
		or t:match(" need ?(%d+) ") or t:match(" (%d+) more ")
		or t:match(" (%d+) spot ") or t:match(" (%d+) spots ")
		or t:match(" want (%d+) ") or t:match(" looking for (%d+) ")
	if explicit then
		return tonumber(explicit)
	end
	local loose = t:match(" lf ?(%d+) ")
	if loose then
		local v = tonumber(loose)
		if v and v <= 9 then
			return v
		end
	end
	return nil
end

function MSGF.Classify(t)
	local list = words(t)
	local firstLF, kind
	for i = 1, #list do
		local k = lfKindOf(list[i])
		if k and not firstLF then
			firstLF, kind = i, k
		end
	end

	local before, after = {}, {}
	local countBefore, countAfter = 0, 0
	for i = 1, #list do
		local role = roleAt(list[i])
		if role then
			if firstLF and i > firstLF then
				if not after[role] then
					after[role] = true
					countAfter = countAfter + 1
				end
			else
				if not before[role] then
					before[role] = true
					countBefore = countBefore + 1
				end
			end
		end
	end

	local leader = hasAny(t, LEADER_SIGNS)
	local selfAd = hasAny(t, SELF_ADS)
	local count = MSGF.RecruitCount(t)

	-- 1. Someone asking to be taken along says so plainly.
	if hasAny(t, LFG_STRONG) then
		return "LFG"
	end

	-- 2. Guild adverts and chatter.
	if has(t, "recruiting") or has(t, "guild") then
		return "UNSURE"
	end
	if not firstLF and not leader and not hasAny(t, LFM_WEAK)
		and not hasAny(t, LFG_WEAK) and hasAny(t, NOISE_WORDS) then
		return "UNSURE"
	end

	-- 3. Explicit lfm, or a wanted headcount.
	if kind == "lfm" or count then
		return "LFM"
	end

	-- 4. Explicit lfg always means the sender wants a group.
	if kind == "lfg" then
		return "LFG"
	end

	-- 5. need or want: a role after it is being recruited.
	if kind == "need" then
		if countAfter > 0 then
			return "LFM"
		end
		if countBefore > 0 then
			return "LFG"
		end
		return leader and "LFM" or "LFG"
	end

	-- 6. Bare lf: what the token points at wins, then role position.
	if kind == "lf" then
		-- "lf ms", "lf ms dps", "lf group", "searching for ms": the sender
		-- wants the group, so a role afterwards describes the sender.
		if lfObjectIsGroup(list, firstLF) then
			if count or leader or t:find("%d+by%d+") then
				return "LFM"
			end
			return "LFG"
		end
		if countAfter >= 2 then
			return "LFM"
		end
		if countAfter == 1 then
			if leader then
				return "LFM"
			end
			if selfAd or countBefore > 0 then
				return "LFG"
			end
			return "LFM"
		end
		if countBefore > 0 then
			return "LFG"
		end
		if leader then
			return "LFM"
		end
		return "LFG"
	end

	-- 7. No looking-for token at all.
	if t:find("%d+by%d+") then
		-- Group progress such as 2/2 tanks, 8/10 dps, 14/15.
		return "LFM"
	end
	if hasAny(t, LFM_WEAK) or leader then
		return "LFM"
	end
	if hasAny(t, LFG_WEAK) then
		return "LFG"
	end
	if countBefore > 0 and (selfAd or countBefore >= 1) then
		return "LFG"
	end
	return "UNSURE"
end

-- 5. Aura of Experience and heirlooms ---------------------------------------
-- Deterministic, never unknown. One mention means yes. No mention means no.
-- A negation means no and carries across a list, so "no aura or looms" sets
-- both to no.

local AURA_SET = {
	aura = true, auras = true, aurra = true, aur = true, aurea = true,
	auraexp = true, auraxp = true, expaura = true, xpaura = true,
	aoexp = true, auraofexp = true,
}

local LOOM_SET = {
	loom = true, looms = true, loomed = true, loomz = true, lums = true,
	heirloom = true, heirlooms = true, heriloom = true, herilooms = true,
	hierloom = true, hierlooms = true, heirlomes = true, hairlooms = true,
	hairloom = true, heirlums = true, hl = false,
}
LOOM_SET.hl = nil

local NEGATORS = {
	["no"] = true, ["not"] = true, ["non"] = true, ["none"] = true,
	["without"] = true, ["wo"] = true, ["dont"] = true, ["doesnt"] = true,
	["havent"] = true, ["hasnt"] = true, ["lacking"] = true,
	["missing"] = true, ["zero"] = true, ["never"] = true, ["nope"] = true,
}

-- Filler that keeps a negation open: "no aura or full looms".
local CARRIERS = {
	["or"] = true, ["and"] = true, ["any"] = true, ["the"] = true,
	["my"] = true, ["full"] = true, ["exp"] = true, ["xp"] = true,
	["experience"] = true, ["of"] = true, ["a"] = true, ["yet"] = true,
	["have"] = true, ["has"] = true, ["got"] = true,
}

-- A token right after the keyword that flips it: "aura off", "looms no".
local OFF_WORDS = {
	["off"] = true, ["no"] = true, ["none"] = true, ["0"] = true,
	["missing"] = true, ["gone"] = true,
}

function MSGF.ParseAuraLooms(t)
	local list = words(t)
	local auraPos, auraNeg = false, false
	local loomPos, loomNeg = false, false
	local scope = 0

	for i = 1, #list do
		local word = list[i]

		-- Glued negatives such as noaura, nolooms, unloomed.
		local stripped = word:gsub("^un", "")
		stripped = stripped:gsub("^no", "")
		local gluedNeg = false
		if stripped ~= word and (AURA_SET[stripped] or LOOM_SET[stripped]) then
			gluedNeg = true
		end

		if gluedNeg then
			if AURA_SET[stripped] then
				auraNeg = true
			end
			if LOOM_SET[stripped] then
				loomNeg = true
			end
			scope = 0
		elseif NEGATORS[word] then
			scope = 4
		elseif AURA_SET[word] or LOOM_SET[word] then
			local nextWord = list[i + 1]
			local negated = false
			if scope > 0 then
				negated = true
			elseif nextWord and OFF_WORDS[nextWord] then
				negated = true
			end
			if AURA_SET[word] then
				if negated then
					auraNeg = true
				else
					auraPos = true
				end
			else
				if negated then
					loomNeg = true
				else
					loomPos = true
				end
			end
			if scope > 0 then
				scope = scope - 1
			end
		elseif CARRIERS[word] then
			-- keeps the current negation scope open
		elseif scope > 0 then
			scope = scope - 1
		end
	end

	-- State is what the text literally did: pos = mentioned, neg = denied,
	-- none = never mentioned. The displayed value depends on the tab, because
	-- a mention means different things in a recruit post and in an offer.
	local auraState = "none"
	if auraNeg then
		auraState = "neg"
	elseif auraPos then
		auraState = "pos"
	end
	local loomState = "none"
	if loomNeg then
		loomState = "neg"
	elseif loomPos then
		loomState = "pos"
	end

	local aura = (auraState == "pos") and "yes" or "no"
	local looms = (loomState == "pos") and "yes" or "no"
	return aura, looms, auraState, loomState
end

function MSGF.ParseAura(t)
	local aura = MSGF.ParseAuraLooms(t)
	return aura
end

function MSGF.ParseLooms(t)
	local _, looms = MSGF.ParseAuraLooms(t)
	return looms
end

-- 6. Level ------------------------------------------------------------------

local LEVEL_PATTERNS = {
	" lvl (%d+) ", " lvl(%d+) ", " lv (%d+) ", " lv(%d+) ",
	" level (%d+) ", " level(%d+) ", " (%d+) lvl ", " (%d+)lvl ",
	" (%d+) lv ", " (%d+)lv ", " l(%d+) ",
}

function MSGF.ParseLevel(t, hasCount)
	for i = 1, #LEVEL_PATTERNS do
		local v = tonumber(t:match(LEVEL_PATTERNS[i]) or "")
		if v and v >= 1 and v <= 80 then
			return v, false
		end
	end
	local lo, hi = t:match(" (%d+)%s*%-%s*(%d+) ")
	if lo and hi then
		lo, hi = tonumber(lo), tonumber(hi)
		if lo and hi and lo >= 1 and hi <= 80 and lo <= hi then
			return lo, true
		end
	end
	-- A lone number can be a level, but only when nothing else claims it.
	if not hasCount then
		local found, seen = nil, 0
		for _, w in ipairs(words(t)) do
			if w:match("^%d+$") then
				seen = seen + 1
				found = tonumber(w)
			end
		end
		if seen == 1 and found and found >= 10 and found <= 80 then
			return found, false
		end
	end
	return nil, false
end

-- 7. Entry point ------------------------------------------------------------

function MSGF.Parse(raw)
	local t = MSGF.Normalize(raw)
	local size
	t, size = MSGF.MarkSize(t)
	if not MSGF.MatchesManastorm(t) then
		return nil, t
	end
	local intent = MSGF.Classify(t)
	local count = MSGF.RecruitCount(t)
	local level, bracket = MSGF.ParseLevel(t, count ~= nil)
	local roleSet = MSGF.ParseRoles(t)
	local aura, looms, auraState, loomsState = MSGF.ParseAuraLooms(t)
	return {
		intent = intent,
		roleSet = roleSet,
		roleText = MSGF.RoleText(roleSet),
		aura = aura,
		looms = looms,
		auraState = auraState,
		loomsState = loomsState,
		level = level,
		bracket = bracket,
		size = size,
		wanted = count,
		norm = t,
	}, t
end
