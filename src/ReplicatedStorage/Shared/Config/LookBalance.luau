--!strict
-- LookBalance: the LOOK BALANCE CAP. It only changes how muscles LOOK; stats, EXP, strength and leaderboards are untouched.
-- A muscle trained far ahead of the muscles that go with it can't grow visually past them: its look is held at a cap
-- (its partners' average + ALLOW) until they catch up, then it grows to where it should be. All EXP still counts.
--
--   raw look      = Muscles.LookG (0 = flat, 1 = the full aesthetic shape, above 1 = mass monster)
--   displayed     = smooth min(raw, cap) (blended over Smooth, so it never snaps)
--   cap           = the LOWEST cap of every rule the muscle is in, each = average of the rule's partners + its allow
-- Caps are computed from the RAW values of the partners (never from already capped ones), so the rule order doesn't
-- matter. They compare PROGRESS, not raw g: 0..1 up to the full aesthetic look, then 1..2 through the mass monster stage
-- (each muscle's monster size differs, e.g. Obliques 2.9 vs Abs 1.3, so a balanced monster is never capped).
-- Tune the rules and allows here.
local Muscles = require(script.Parent.Muscles)

local LookBalance = {}

LookBalance.Allow = 0.20  -- how far a muscle may look ahead of its partners' average (unless a rule says otherwise)
LookBalance.Smooth = 0.05 -- the smooth min's blend width
LookBalance.CappedBy = 0.01 -- a muscle counts as "capped" (lock icon, hint) when it is held back by more than this

local UPPER = { "UpperChest", "MidChest", "FrontDelts", "SideDelts", "RearDelts", "Lats", "Traps", "Rhomboids", "LowerBack",
	"Biceps", "Triceps", "Forearms", "Abs", "Obliques" }
local LOWER = { "Quads", "Hamstrings", "Glutes", "Calves" }

-- { muscles = capped muscles, partners = whose average caps them, allow = (default Allow), name = the partner group named
-- in the hint ("Look capped - train Back to unlock") }
LookBalance.Rules = {
	-- push vs pull
	{ muscles = { "UpperChest", "MidChest" }, partners = { "Lats", "Rhomboids" }, name = "Back" },
	{ muscles = { "Lats", "Rhomboids" }, partners = { "UpperChest", "MidChest" }, name = "Chest" },
	{ muscles = { "UpperChest" }, partners = { "MidChest" }, allow = 0.25, name = "Mid Chest" },
	{ muscles = { "MidChest" }, partners = { "UpperChest" }, allow = 0.25, name = "Upper Chest" },
	-- shoulders
	{ muscles = { "FrontDelts" }, partners = { "RearDelts" }, name = "Rear Delts" },
	{ muscles = { "RearDelts" }, partners = { "FrontDelts" }, name = "Front Delts" },
	{ muscles = { "SideDelts" }, partners = { "FrontDelts", "RearDelts" }, allow = 0.25, name = "Front and Rear Delts" },
	-- arms
	{ muscles = { "Biceps" }, partners = { "Triceps" }, name = "Triceps" },
	{ muscles = { "Triceps" }, partners = { "Biceps" }, name = "Biceps" },
	{ muscles = { "Forearms" }, partners = { "Biceps", "Triceps" }, allow = 0.25, name = "Biceps and Triceps" },
	-- core
	{ muscles = { "Abs" }, partners = { "Obliques", "LowerBack" }, name = "Obliques and Lower Back" },
	{ muscles = { "Obliques" }, partners = { "Abs", "LowerBack" }, name = "Abs and Lower Back" },
	{ muscles = { "LowerBack" }, partners = { "Abs", "Obliques" }, name = "Abs and Obliques" },
	-- legs
	{ muscles = { "Quads" }, partners = { "Hamstrings", "Glutes" }, name = "Hamstrings and Glutes" },
	{ muscles = { "Hamstrings", "Glutes" }, partners = { "Quads" }, name = "Quads" },
	{ muscles = { "Calves" }, partners = { "Quads", "Hamstrings", "Glutes" }, allow = 0.25, name = "Legs" },
	-- traps follow the shoulders and back
	{ muscles = { "Traps" }, partners = { "SideDelts", "Rhomboids", "Lats" }, allow = 0.25, name = "Shoulders and Back" },
	-- whole body: no chicken legs, no tiny upper body
	{ muscles = UPPER, partners = LOWER, allow = 0.30, name = "Legs" },
	{ muscles = LOWER, partners = UPPER, allow = 0.30, name = "Upper body" },
}

-- look g <-> progress (0..1 to the full aesthetic look, 1..2 through the mass monster stage)
local function toProgress(id: string, g: number): number
	if g <= 1 then return g end
	return 1 + (g - 1) / math.max(Muscles.MonsterG(id) - 1, 0.01)
end
local function fromProgress(id: string, p: number): number
	if p <= 1 then return p end
	return 1 + (p - 1) * (Muscles.MonsterG(id) - 1)
end
LookBalance.ToProgress, LookBalance.FromProgress = toProgress, fromProgress

-- smooth min: the smaller of a and b, blended over k where they are close (never above min(a, b))
function LookBalance.SmoothMin(a: number, b: number, k: number): number
	if k <= 0 then return math.min(a, b) end
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end

-- raw = { [muscleId] = raw look g }. Returns displayed = { [muscleId] = look g } and info = { [muscleId] = { cap
-- (progress), raw, shown (progress), capped, rule } } (rule = the rule giving the lowest cap).
function LookBalance.Apply(raw: { [string]: number }): ({ [string]: number }, { [string]: any })
	local progress: { [string]: number } = {}
	for _, muscle in ipairs(Muscles.List) do progress[muscle.id] = toProgress(muscle.id, raw[muscle.id] or 0) end
	-- pass 1: every rule's cap from the RAW progress of its partners; each muscle keeps its lowest
	local caps: { [string]: number } = {}
	local from: { [string]: any } = {}
	for _, rule in ipairs(LookBalance.Rules) do
		local sum = 0
		for _, id in ipairs(rule.partners) do sum += progress[id] or 0 end
		local cap = sum / #rule.partners + (rule.allow or LookBalance.Allow)
		for _, id in ipairs(rule.muscles) do
			if caps[id] == nil or cap < caps[id] then caps[id], from[id] = cap, rule end
		end
	end
	-- pass 2: the smooth min of raw and cap
	local displayed, info = {}, {}
	for _, muscle in ipairs(Muscles.List) do
		local id = muscle.id
		local p = progress[id]
		local cap = caps[id]
		local shown = if cap then math.max(LookBalance.SmoothMin(p, cap, LookBalance.Smooth), 0) else p
		displayed[id] = fromProgress(id, shown)
		info[id] = { raw = p, cap = cap, shown = shown, capped = p - shown > LookBalance.CappedBy, rule = from[id] }
	end
	return displayed, info
end

-- The capped look of every muscle from saved levels (the same numbers BodyService publishes as MuscleG).
function LookBalance.FromLevels(levels: { [string]: number }, goal: number): ({ [string]: number }, { [string]: any })
	local raw = {}
	for _, muscle in ipairs(Muscles.List) do raw[muscle.id] = Muscles.LookG(muscle.id, levels[muscle.id] or 0, goal) end
	return LookBalance.Apply(raw)
end

return LookBalance
