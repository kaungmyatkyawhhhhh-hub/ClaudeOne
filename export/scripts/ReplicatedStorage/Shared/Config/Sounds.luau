-- Every sound in the game, in one place. All of them come from Roblox's own licensed library in the Creator Store
-- (Pro Sound Effects for effects, APM Music for music), so they're safe to use. Swap an id to change a sound.
--   ids       one is picked at random each time (variety)
--   volume    0-1 before the SoundGroup and the player's volume setting
--   pitch     random pitch spread, 0.05 = +-5% (so repeats never sound robotic)
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
	Breath = { ids = { 9113585730, 9113586280 }, volume = 0.16, pitch = 0.05, group = "Gameplay", range = { 6, 30 }, maxLength = 1.6 }, -- Breath Exhale 11/20: heavy tiers / low stamina only

	-- Training feedback (2D)
	RepTick = { ids = { 9114212934 }, volume = 0.07, pitch = 0.05, group = "UI" },                       -- Button click: soft tick on each rep
	SetComplete = { ids = { 9116163687 }, volume = 0.22, pitch = 0.03, group = "Gameplay" },              -- Key Dings, light metal clinking: every 10 reps
	GrowthSpurt = { ids = { 9113421788 }, volume = 0.25, pitch = 0, group = "Gameplay", maxLength = 2.6 }, -- Bell Rings, resonant: Growth Spurt moment

	-- Interface (2D, quieter than gameplay)
	Click = { ids = { 9114212934 }, volume = 0.1, pitch = 0.05, group = "UI" },                  -- Button click: every button press
	Whoosh = { ids = { 9125715121 }, volume = 0.1, pitch = 0.05, group = "UI", maxLength = 0.6 }, -- Robe Swish, cloth flap: menus and panels opening

	-- Genetics reveal (2D)
	GeneticsClank = { ids = { 9116750726 }, volume = 0.6, pitch = 0.03, group = "Gameplay" },                       -- Metal Plate Impact, Manhole Hit 1: each plate slamming on
	GeneticsThud = { ids = { 9119388384 }, volume = 0.55, pitch = 0, group = "Gameplay", maxLength = 2.2 },          -- Distant Metal Booms, deep soft impact: overall plate
	GeneticsThudLow = { ids = { 9113479635 }, volume = 0.5, pitch = 0, group = "Gameplay", maxLength = 1.0 },        -- Body Falls on Carpet: low layer under the overall plate
	ChalkPuff = { ids = { 9125964822 }, volume = 0.22, pitch = 0.05, group = "Gameplay", maxLength = 0.8 },          -- Snow breaks into powder: S-grade chalk puff

	-- Music (2D, low in the background, plays the tracks in order and loops)
	Music = { ids = { 9043990443, 9043990341 }, volume = 0.5, pitch = 0, group = "Music" }, -- APM "Lovely Sunrise" C (underscore) and A (vinyl chillhop)
}
