local Stamina = {}

Stamina.Max = 100

-- Cardio trains stamina: every MetersPerPoint run on a treadmill (saved as stats.cardioMeters) adds 1 to max stamina,
-- up to MaxBonus extra. (Iron Lungs multiplies the result.)
Stamina.Cardio = { MetersPerPoint = 40, MaxBonus = 150 }

-- Max stamina for a player who has run `meters` in total.
function Stamina.MaxFor(meters: number?): number
	return Stamina.Max + math.min(Stamina.Cardio.MaxBonus, math.floor((meters or 0) / Stamina.Cardio.MetersPerPoint))
end
Stamina.RegenPerSecond = 20
Stamina.RegenDelay = 2 -- seconds after a rep before refilling starts (shorter = it refills between casual taps)

-- Pacing by Growth Spurt (owner, prompt 20, 21 Oct: waiting must stay under 15% of play time). Every stamina number for
-- lifting is here:
--   costScale      x each machine's staminaCost (Config/Machines). 0.25 = 66-100 reps from full: 60-90 s of fast tapping
--                  even on the heaviest machines (cost 6; measured in Studio: about 1 rep a second when tapping hard).
--   refillSeconds  empty to full while RECOVERING. A rep with too little stamina starts recovering: no reps (taps or auto
--                  reps) until the bar is full again, and it refills right away on the machine (no RegenDelay), so the
--                  player never has to get off. Waiting stays under ~15 s per minute even when tapping as fast as possible.
-- The first row whose fromSpurt <= the player's Growth Spurts (counted from the bottom) is used.
Stamina.Pacing = {
	{ fromSpurt = 0, costScale = 0.25, refillSeconds = 10 }, -- before Growth Spurt 2: ~66 s tapping, 10 s rest (13% waiting)
	{ fromSpurt = 2, costScale = 0.45, refillSeconds = 10 }, -- ~37 reps, then 10 s (about 13 s waiting per minute)
	{ fromSpurt = 4, costScale = 0.5, refillSeconds = 10 },  -- ~33 reps, then 10 s (about 14 s per minute)
}

function Stamina.PacingFor(spurts: number?)
	local pick = Stamina.Pacing[1]
	for _, row in ipairs(Stamina.Pacing) do
		if (spurts or 0) >= row.fromSpurt then pick = row end
	end
	return pick
end

-- What one rep costs on a machine for a player with `spurts` Growth Spurts.
function Stamina.RepCost(machineCost: number, spurts: number?): number
	return machineCost * Stamina.PacingFor(spurts).costScale
end

-- Recovery stations: standing in a model with this Recovery attribute refills stamina faster.
Stamina.Recovery = {
	StretchMat = 2.5, -- x the normal refill speed
	Cardio = 1.6,     -- treadmills, bikes and rowers: an easy cool-down
	Sauna = 3.5,      -- the beach sauna (Workspace.Town.Sauna, tools/builders/Sauna.luau)
}
-- the small note when you step into one (once per visit)
Stamina.RecoveryNotes = {
	StretchMat = "Stretching area. Stamina refills faster here.",
	Cardio = "Easy cardio. Stamina refills a bit faster here.",
	Sauna = "Sauna. Stamina refills super fast here.",
}

-- Energy Shakes: bought at the shake machine by the door (or earned), drunk from the button left of the stamina bar.
-- Drinking fills stamina and gives bonus gains for a while. Flavors are only for fun.
Stamina.Shake = {
	Cost = 25,          -- coins
	MaxCarry = 20,      -- shakes in the bag at most
	GainsBoost = 1.5,   -- +50% gains
	Duration = 30,      -- seconds (drinking again adds time, up to MaxDuration)
	MaxDuration = 90,
	Flavors = { "Chocolate", "Strawberry", "Vanilla", "Banana", "Cookies and Cream", "Mint" },
}

-- The gym cat by the front desk: petting gives a tiny refill.
Stamina.Cat = {
	Name = "Plates",
	Refill = 10,
	Cooldown = 30, -- seconds per player
}

return Stamina
