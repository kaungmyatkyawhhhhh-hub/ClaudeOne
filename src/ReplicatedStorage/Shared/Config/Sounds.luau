-- Every sound in the game, in one place. All of them come from Roblox's own licensed library in the Creator Store
-- (Pro Sound Effects for effects, APM Music for music), so they're safe to use. Swap an id to change a sound.
--   ids       one is picked at random each time (variety)
--   volume    0-1 before the SoundGroup and the player's volume setting
--   pitch     random pitch spread, 0.05 = +-5% (so repeats never sound robotic)
--   basePitch optional fixed pitch (1 = normal), so one clip can make two different sounds
--   group     "Gameplay" | "UI" | "Music" (SoundGroups with balanced volumes; see Shared.Audio)
--   maxLength stop early with a short fade (seconds), for clips with a long tail
--   range     3D sounds only: {full volume within, silent beyond} in studs
return {
	-- Lifting (3D, played at the machine)
	Clank = { ids = { 9116750726, 9116751108 }, volume = 0.5, pitch = 0.05, group = "Gameplay", range = { 10, 70 } },                -- Metal Plate Impact, Manhole Hit 1/2: plates at lockout
	PlateKnock = { ids = { 9116717455, 9116717780 }, volume = 0.22, pitch = 0.05, group = "Gameplay", range = { 8, 50 }, maxLength = 0.6 }, -- Metal Knocks on Metal Plate 1/4: plates jiggling on heavy reps
	BarRattle = { ids = { 9113757391 }, volume = 0.22, pitch = 0.05, group = "Gameplay", range = { 8, 50 }, maxLength = 1.2 },    -- Chain Hit Metal, Light Sliding: bar picked up / set down
	PlateSlide = { ids = { 9117681302 }, volume = 0.25, pitch = 0.05, group = "Gameplay", range = { 8, 50 }, maxLength = 0.55 },  -- Sliding Legs of Metal Tripod: plates on/off when the weight changes
	FloorThud = { ids = { 9113479635 }, volume = 0.45, pitch = 0.05, group = "Gameplay", range = { 10, 60 }, maxLength = 0.9 },   -- Body Falls on Carpet, low thuddy: rubber floor thud
	Breath = { ids = { 9113585730, 9113586280 }, volume = 0.6, pitch = 0.05, group = "Gameplay", range = { 12, 45 }, maxLength = 1.6 }, -- Breath Exhale 11/20: heavy tiers / low stamina only

	-- Training feedback (2D)
	RepTick = { ids = { 9114212934 }, volume = 0.07, pitch = 0.05, group = "UI" },                       -- Button click: soft tick on each rep
	SetComplete = { ids = { 9116163687 }, volume = 0.22, pitch = 0.03, group = "Gameplay" },              -- Key Dings, light metal clinking: every 10 reps
	GrowthSpurt = { ids = { 9113421788 }, volume = 0.25, pitch = 0, group = "Gameplay", maxLength = 2.6 }, -- Bell Rings, resonant: Growth Spurt moment
	LevelUp = { ids = { 9116163687 }, volume = 0.12, pitch = 0.03, basePitch = 1.25, group = "UI", maxLength = 0.8 },     -- Key Dings, higher: a muscle levels up
	Maxed = { ids = { 9113421788 }, volume = 0.13, pitch = 0, basePitch = 1.3, group = "UI", maxLength = 1.2 },             -- Bell Rings, short and high: a muscle hits its level cap
	TitleUnlocked = { ids = { 9113421788 }, volume = 0.16, pitch = 0, basePitch = 1.12, group = "UI", maxLength = 1.6 },    -- Bell Rings: a new title
	TierUnlocked = { ids = { 9116750726, 9116751108 }, volume = 0.3, pitch = 0.03, basePitch = 0.92, group = "Gameplay", maxLength = 1.2 }, -- Metal Plate Impact: heavier plates bought
	OutOfStamina = { ids = { 9113585730, 9113586280 }, volume = 0.55, pitch = 0.05, group = "Gameplay", maxLength = 1.6 },  -- Breath Exhale: tapped with no stamina left
	-- PLACEHOLDERS (owner picks the real ids): these reuse clips from above until then
	PumpFull = { ids = { 9116163687 }, volume = 0.25, pitch = 0.02, basePitch = 1.45, group = "Gameplay", maxLength = 1.0 },       -- PLACEHOLDER (Key Dings, high): the PUMP meter fills, PUMPED starts
	BigRep = { ids = { 9116750726, 9116751108 }, volume = 0.35, pitch = 0.03, basePitch = 0.8, group = "Gameplay", maxLength = 1.0 }, -- PLACEHOLDER (Metal Plate Impact, deep): a BIG REP
	PersonalRecord = { ids = { 9113421788 }, volume = 0.2, pitch = 0, basePitch = 1.2, group = "Gameplay", maxLength = 1.8 },       -- PLACEHOLDER (Bell Rings): NEW PR banner
	Grew = { ids = { 9119388384 }, volume = 0.35, pitch = 0.03, basePitch = 1.15, group = "Gameplay", maxLength = 1.2 },            -- PLACEHOLDER (Distant Metal Booms): "you grew" moment
	CrowdOoh = { ids = { 9119388384 }, volume = 0.3, pitch = 0.04, basePitch = 1.3, group = "Gameplay", range = { 16, 80 }, maxLength = 1.4 }, -- PLACEHOLDER (Distant Metal Booms, higher): the crowd "ooh" when a pose hits; owner picks the real id

	-- Interface (2D, quieter than gameplay)
	Click = { ids = { 9114212934 }, volume = 0.1, pitch = 0.05, group = "UI" },                  -- Button click: every button press
	Whoosh = { ids = { 9125715121 }, volume = 0.1, pitch = 0.05, group = "UI", maxLength = 0.6 }, -- Robe Swish, cloth flap: menus and panels opening

	-- Genetics reveal (2D)
	GeneticsClank = { ids = { 9116750726 }, volume = 0.6, pitch = 0.03, group = "Gameplay" },                       -- Metal Plate Impact, Manhole Hit 1: each plate slamming on
	GeneticsThud = { ids = { 9119388384 }, volume = 0.55, pitch = 0, group = "Gameplay", maxLength = 2.2 },          -- Distant Metal Booms, deep soft impact: overall plate
	GeneticsThudLow = { ids = { 9113479635 }, volume = 0.5, pitch = 0, group = "Gameplay", maxLength = 1.0 },        -- Body Falls on Carpet: low layer under the overall plate
	ChalkPuff = { ids = { 9125964822 }, volume = 0.22, pitch = 0.05, group = "Gameplay", maxLength = 0.8 },          -- Snow breaks into powder: S-grade chalk puff
	-- PLACEHOLDERS for the genetics reveal redesign (owner picks the real ids): these reuse clips from above until then
	GeneticsSpin = { ids = { 9125715121 }, volume = 0.2, pitch = 0.05, basePitch = 0.85, group = "Gameplay", maxLength = 0.7 },     -- PLACEHOLDER (Robe Swish): a plate spins in face-down
	GeneticsFlip = { ids = { 9116717455, 9116717780 }, volume = 0.35, pitch = 0.04, group = "Gameplay", maxLength = 0.6 },          -- PLACEHOLDER (Metal Knocks): the plate flips to show its grade
	GeneticsPop = { ids = { 9114212934 }, volume = 0.3, pitch = 0.04, basePitch = 0.8, group = "Gameplay" },                          -- PLACEHOLDER (Button click, low): C / D small pop
	GeneticsShimmer = { ids = { 9116163687 }, volume = 0.3, pitch = 0.03, basePitch = 1.35, group = "Gameplay", maxLength = 1.2 },  -- PLACEHOLDER (Key Dings, high): B gold shimmer
	GeneticsBurst = { ids = { 9113421788 }, volume = 0.3, pitch = 0.02, basePitch = 1.1, group = "Gameplay", maxLength = 1.6 },     -- PLACEHOLDER (Bell Rings): A blue burst
	GeneticsDrumRoll = { ids = { 9113757391 }, volume = 0.35, pitch = 0, basePitch = 0.7, group = "Gameplay", maxLength = 1.4 },    -- PLACEHOLDER (Chain Hit Metal, slowed): S build-up drum roll
	GeneticsExplode = { ids = { 9119388384 }, volume = 0.6, pitch = 0, basePitch = 0.9, group = "Gameplay", maxLength = 2.2 },     -- PLACEHOLDER (Distant Metal Booms): S explodes
	GeneticsBlessed = { ids = { 9113421788 }, volume = 0.3, pitch = 0, basePitch = 1.25, group = "Gameplay", maxLength = 2 },      -- PLACEHOLDER (Bell Rings, high): the BLESSED banner (2+ S)

	-- Music (2D, low in the background, plays the tracks in order and loops)
	Music = { ids = { 9043990443, 9043990341 }, volume = 0.5, pitch = 0, group = "Music" }, -- APM "Lovely Sunrise" C (underscore) and A (vinyl chillhop)

	-- Area music: which of the music tracks plays where (Audio.SetArea; SettingsClient picks the area).
	AreaMusic = {
		Starter = { 9043990443 }, -- underscore: warm, old-school starter gym
		Pro = { 9043990341 },     -- vinyl chillhop: the darker pro gym
	},
}
