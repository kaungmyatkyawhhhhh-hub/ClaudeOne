-- Lift screams (owner's 13 Oct "Monetization and hype" task 3, built 21 Oct): a hype scream from the lifter's character,
-- 3D so only players nearby hear it. The server decides (ScreamService), every client plays it (ScreamClient). The sounds
-- are Config/Sounds ScreamNormal / ScreamBig (Roblox's licensed library; one picked at random, never the same twice in
-- a row). Settings "Others' Sounds" Off mutes other players' screams for that player only.
return {
	-- a heavy rep: the weight is at least this share of the heaviest weight you can lift on that machine
	HeavyShare = 0.85,
	HeavyChance = 0.35, -- chance per heavy rep
	SetSize = 10, -- the last rep of a set (every this many reps on one machine, like the client's "set complete" beat)
	Cooldown = 2.5, -- seconds between screams per player (never spams)
	BigCooldown = 1.0, -- a big scream (personal record, arm wrestling / posing win) only waits this long
	-- a small camera shake for the screaming player only (never on Low Graphics or Reduce Motion)
	Shake = { Enabled = true, Strength = 0.12, BigStrength = 0.25, Seconds = 0.35 },
}
