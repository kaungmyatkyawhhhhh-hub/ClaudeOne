-- Lifting voices (owner, 22 Oct; were the hype "lift screams" of 21 Oct, the owner: "disturbing"): a short strained grunt
-- from the lifter's character, 3D so only players nearby hear it, quietly (Config/Sounds LiftGrunt: a random clip, never
-- the same twice in a row, pitch 0.95 - 1.05). The server decides (ScreamService), every client plays it (ScreamClient).
-- Never every rep: only heavy reps (the weight is at least HeavyShare of the heaviest you can lift there), about every
-- EveryHeavy-th one, and a new personal record. No screams, no camera shake. Settings: "Lifting Voices" Off = none at all
-- on this device; "Others' Sounds" Off mutes other players' ones.
return {
	HeavyShare = 0.85, -- a heavy rep: the weight is at least this share of the heaviest weight you can lift on that machine
	EveryHeavy = 5,    -- a grunt on every this-many-th heavy rep (counted per player)
	Cooldown = 3,      -- seconds between two grunts of one player
}
