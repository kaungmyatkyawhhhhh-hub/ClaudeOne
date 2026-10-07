--!strict
-- LookBalance: the LOOK BALANCE CAP. It only changes how muscles LOOK; stats, EXP, strength and leaderboards are untouched.
-- A muscle is only compared with the other muscles in its OWN group (Config.Muscles groups: Chest, Shoulders, Back, Arms,
-- Legs, Core); nothing across groups, so training only Chest grows Chest fully. Inside a group, a muscle can't stick out far
-- past its smallest groupmate: measured in real bulge size (studs off the skin, Config.MuscleBulge at the full look):
--   cap_studs = max(mate_studs + MaxGap, mate_studs * MaxRatio)   (mate = the smallest other muscle in the group, raw)
--   cap       = the look that gives cap_studs, but never below the mate's own look (muscles differ in natural size: Lats
--               bulge 3x more than Lower Back at the same look, so a balanced body is never held back)
--   displayed = soft cap(raw, cap): raw up to the cap, then easing into it over Smooth (never snaps; never below 0)
-- e.g. only Upper Chest trained: it shows at most 0.15 studs of bulge until Mid Chest grows too.
local Muscles = require(script.Parent.Muscles)
local Bulge = require(script.Parent.MuscleBulge)

local LookBalance = {}

LookBalance.MaxGap = 0.15    -- studs a muscle may stick out past its smallest groupmate
LookBalance.MaxRatio = 1.5   -- ... or this many times its bulge, once both are big (the larger of the two)
LookBalance.Smooth = 0.05    -- the soft cap's blend (look g): how far past the cap a held muscle can still creep
LookBalance.CappedBy = 0.01  -- studs held back before a muscle counts as capped (lock icon, hint)
LookBalance.ToastStuds = 0.05 -- studs held back before the one-time toast shows

-- studs off the skin at look g (the mesh grows linearly with g)
function LookBalance.Studs(id: string, g: number): number
	return g * (Bulge[id] or 0.2)
end

-- soft cap: g itself up to the cap, then easing into it (continuous and smooth, never snapping; at most k above the cap)
function LookBalance.SoftCap(g: number, cap: number, k: number): number
	if g <= cap then return g end
	if k <= 0 then return cap end
	return cap + k * (1 - math.exp(-(g - cap) / k))
end

-- raw = { [muscleId] = raw look g }. Returns displayed = { [muscleId] = look g } and info = { [muscleId] = { raw, shown, cap
-- (look g), held (studs held back), capped, mate (the groupmate holding it), rule = { name, partners } } }.
function LookBalance.Apply(raw: { [string]: number }): ({ [string]: number }, { [string]: any })
	local displayed, info = {}, {}
	for _, group in ipairs(Muscles.Groups) do
		for _, muscle in ipairs(group.muscles) do
			local id = muscle.id
			local g = raw[id] or 0
			-- the smallest other muscle of the group (by its RAW bulge)
			local mate, mateStuds = nil, math.huge
			for _, other in ipairs(group.muscles) do
				if other.id ~= id then
					local studs = LookBalance.Studs(other.id, raw[other.id] or 0)
					if studs < mateStuds then mate, mateStuds = other, studs end
				end
			end
			local shown, cap = g, math.huge
			if mate then
				local capStuds = math.max(mateStuds + LookBalance.MaxGap, mateStuds * LookBalance.MaxRatio)
				cap = math.max(capStuds / (Bulge[id] or 0.2), raw[mate.id] or 0)
				shown = math.max(LookBalance.SoftCap(g, cap, LookBalance.Smooth), 0)
			end
			local held = LookBalance.Studs(id, g - shown)
			displayed[id] = shown
			info[id] = {
				raw = g, shown = shown, cap = cap, held = held, capped = held > LookBalance.CappedBy, mate = mate and mate.id,
				rule = mate and { name = mate.name, partners = { mate.id } } or nil,
			}
		end
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
