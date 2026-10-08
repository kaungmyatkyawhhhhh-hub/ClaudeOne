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

-- Energy Shakes: bought at the shake machine by the door (or earned), drunk from the button on the right.
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
