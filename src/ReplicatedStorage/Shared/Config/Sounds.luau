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

	-- Lifting voices (owner, 22 Oct: "the lifting screams are disturbing"; the style: a short, low, held strained grunt, no
	-- screaming). 3D from the lifter's head, quiet for others (a short range); Config/Screams, ScreamService / ScreamClient.
	-- Picked from Roblox's licensed library (Pro Sound Effects) by their description, NOT heard: the owner listens and swaps
	-- any id. Volume = 40% of the old screams' 0.45; pitch 0.95 - 1.05.
	-- (were: ScreamNormal 9120415730, 9120415788, 9120415873, 9120417141, 9120417581 (Video Game Effects 1/2/4/21/23) and
	-- ScreamBig 9125650883, 9125651373, 9125652432 (Male Scream Short Yelling Bursts 1/10/5))
	LiftGrunt = { ids = { 9125572953, 9125573322, 9120416707, 9120417872 }, volume = 0.18, pitch = 0.05, group = "Gameplay",
		range = { 6, 35 }, maxLength = 1.6 }, -- PSE Gasps Male Deep Breaths ... Struggling 10 / 13 (strained efforts, 1.3 / 1.5 s), Video Game Effects 15 / 26 (short grunts)

	-- Treadmill (3D, on the belt; owner, 14 Oct: the treadmill never uses the lifting sounds). EMPTY on purpose: the owner
	-- picks these ids (Roblox's licensed library only); an empty slot is silent.
	TreadmillLoop = { ids = {}, volume = 0.18, pitch = 0, group = "Gameplay", range = { 6, 30 } }, -- looping belt / running hum while someone runs (fades out over 0.3 s)
	TreadmillStep = { ids = {}, volume = 0.08, pitch = 0.08, group = "Gameplay", range = { 5, 22 }, maxLength = 0.4 }, -- soft footstep, every stride

	-- Training feedback (2D)
	RepTick = { ids = { 9114212934 }, volume = 0.07, pitch = 0.05, group = "UI" },                       -- Button click: soft tick on each rep
	SetComplete = { ids = { 9116163687 }, volume = 0.22, pitch = 0.03, group = "Gameplay" },              -- Key Dings, light metal clinking: every 10 reps
	GrowthSpurt = { ids = { 9113421788 }, volume = 0.25, pitch = 0, group = "Gameplay", maxLength = 2.6 }, -- Bell Rings, resonant: Growth Spurt moment
	LevelUp = { ids = { 9126073001 }, volume = 0.12, pitch = 0.03, group = "UI", maxLength = 0.9 }, -- PSE Synth Sparkle Bell Ding 4: a muscle levels up
	Maxed = { ids = { 9126073302 }, volume = 0.13, pitch = 0, group = "UI", basePitch = 1.1, maxLength = 1.2 }, -- PSE Synth Sparkle Bell Ding 2, a bit higher: a muscle hits its level cap
	TitleUnlocked = { ids = { 9116394876 }, volume = 0.18, pitch = 0, group = "UI", maxLength = 2 }, -- PSE Magic Glows Chiming Hits 2: a new title
	TierUnlocked = { ids = { 9116684733 }, volume = 0.3, pitch = 0.03, group = "Gameplay", maxLength = 1.2 }, -- PSE Metal Impacts 1: heavier plates bought
	OutOfStamina = { ids = { 9117018751 }, volume = 0.4, pitch = 0.05, group = "Gameplay", maxLength = 0.9 }, -- PSE Mouth Poof, burst of air: tapped with no stamina left (no voice)
	-- (picked 13 Oct from Roblox's licensed library at the owner's request: PSE = ProSoundEffects, APM = APM Music)
	PumpFull = { ids = { 9126073011 }, volume = 0.22, pitch = 0.02, group = "Gameplay", maxLength = 1.2 }, -- PSE Synth Sparkle Bell Ding 3: the PUMP meter fills, PUMPED starts
	BigRep = { ids = { 1837830196 }, volume = 0.3, pitch = 0.03, group = "Gameplay", maxLength = 1.2 }, -- APM BOOM Deep Boom 02: a BIG REP
	PersonalRecord = { ids = { 9039636793 }, volume = 0.22, pitch = 0, group = "Gameplay", maxLength = 2 }, -- APM Stargazing (sting c): NEW PR banner
	Grew = { ids = { 9125807054 }, volume = 0.3, pitch = 0.03, group = "Gameplay", maxLength = 1.5 }, -- PSE Rising Whoosh Swooshing In 3: the 'you grew' moment
	CrowdOoh = { ids = { 9120974378 }, volume = 0.28, pitch = 0.04, group = "Gameplay", range = { 16, 80 }, maxLength = 2.2 }, -- PSE Wrestling Crowd 3, a crowd surge (there is no licensed 'ooh'): a pose hits
	-- Spotting (SpotClient)
	SpotPush = { ids = { 9113885761 }, volume = 0.06, pitch = 0.04, group = "UI", basePitch = 1.1 }, -- PSE Computer Track Ball 57 click: every push; the pitch climbs with the combo
	SpotBoostOn = { ids = { 9126072698 }, volume = 0.2, pitch = 0.02, group = "Gameplay", basePitch = 1.1, maxLength = 1 }, -- PSE Synth Sparkle Bell Ding 2: you start counting as clicking
	SpotCombo = { ids = { 9126073318 }, volume = 0.16, pitch = 0.02, group = "UI", basePitch = 1.25, maxLength = 0.9 }, -- PSE Synth Sparkle Bell Ding 1, higher: combo 10 / 25 / 50 / 100
	SpotAssist = { ids = { 9113912086 }, volume = 0.14, pitch = 0.05, group = "Gameplay", maxLength = 0.6 }, -- PSE Cooking Pot 29, light metal knock: the lifter's rep landed while you pushed
	SpotPayout = { ids = { 9119217702 }, volume = 0.22, pitch = 0.02, group = "Gameplay", maxLength = 1.6 }, -- PSE Slot Machine 7, coins: spotting coins paid out

	-- Interface (2D, quieter than gameplay)
	Click = { ids = { 9114212934 }, volume = 0.1, pitch = 0.05, group = "UI" },                  -- Button click: every button press
	Whoosh = { ids = { 9125715121 }, volume = 0.1, pitch = 0.05, group = "UI", maxLength = 0.6 }, -- Robe Swish, cloth flap: menus and panels opening

	-- Genetics reveal (2D)
	GeneticsClank = { ids = { 9116750726 }, volume = 0.6, pitch = 0.03, group = "Gameplay" },                       -- Metal Plate Impact, Manhole Hit 1: each plate slamming on
	GeneticsThud = { ids = { 9119388384 }, volume = 0.55, pitch = 0, group = "Gameplay", maxLength = 2.2 },          -- Distant Metal Booms, deep soft impact: overall plate
	GeneticsThudLow = { ids = { 9113479635 }, volume = 0.5, pitch = 0, group = "Gameplay", maxLength = 1.0 },        -- Body Falls on Carpet: low layer under the overall plate
	ChalkPuff = { ids = { 9125964822 }, volume = 0.22, pitch = 0.05, group = "Gameplay", maxLength = 0.8 },          -- Snow breaks into powder: S-grade chalk puff
	GeneticsSpin = { ids = { 9126228629 }, volume = 0.2, pitch = 0.05, group = "Gameplay", maxLength = 0.9 }, -- PSE Whoosh Fast Camera In And Out 1: a plate spins in
	GeneticsFlip = { ids = { 9119239488 }, volume = 0.3, pitch = 0.04, group = "Gameplay", maxLength = 0.7 }, -- PSE Small Pipe Wrench On Metal Pipe 7: the plate flips
	GeneticsPop = { ids = { 9117183955 }, volume = 0.3, pitch = 0.04, group = "Gameplay", maxLength = 0.6 }, -- PSE Comic Pops (Pacifier 3): C / D small pop
	GeneticsShimmer = { ids = { 9116383749 }, volume = 0.28, pitch = 0.03, group = "Gameplay", maxLength = 1.6 }, -- PSE Magical Wing Flutter 5: B gold shimmer
	GeneticsBurst = { ids = { 9116394545 }, volume = 0.3, pitch = 0.02, group = "Gameplay", maxLength = 2 }, -- PSE Magic Glows Chiming Hits 1: A blue burst
	-- (owner, 14 Oct: the aura's personal record burst; a power burst, no voice: the "no grunts" rule. Swap the id for another)
	AuraBurst = { ids = { 9116394545 }, volume = 0.35, pitch = 0.05, group = "Gameplay", maxLength = 2 }, -- PSE Magic Glows Chiming Hits 1
	GeneticsDrumRoll = { ids = { 1840444182 }, volume = 0.35, pitch = 0, group = "Gameplay", maxLength = 1.6 }, -- APM Drum Rolls (A): S build-up
	GeneticsExplode = { ids = { 1837830667 }, volume = 0.5, pitch = 0, group = "Gameplay", maxLength = 2.2 }, -- APM BOOM Mid Boom 07: S explodes
	GeneticsBlessed = { ids = { 9039637427 }, volume = 0.28, pitch = 0, group = "Gameplay", maxLength = 3 }, -- APM Full of Wonder (sting a): the BLESSED banner (2+ S)

	-- Posing Competition (PosingCompClient)
	PosingStart = { ids = { 9042409054 }, volume = 0.3, pitch = 0, group = "Gameplay", maxLength = 4 }, -- APM Day Of The Election Sting 2, fanfare: the round's countdown starts (server-wide)
	PosingCue = { ids = { 9113936601 }, volume = 0.2, pitch = 0.02, group = "UI" }, -- PSE Cordless Phone beep 8: the timing ring closes (tap now)
	PosingScore = { ids = { 9125574158 }, volume = 0.25, pitch = 0.03, group = "Gameplay", maxLength = 0.8 }, -- PSE Gavel Hit Wood 4: the judges raise their cards
	PosingWin = { ids = { 9113137529 }, volume = 0.35, pitch = 0, group = "Gameplay", maxLength = 5 }, -- PSE Applause Nightclub 1: the winner on the podium

	-- Feature run (13 Oct): daily quests, arm wrestling, smoothie bar, rivals, pets, photo mode, world sounds
	QuestComplete = { ids = { 1841173364 }, volume = 0.22, pitch = 0, group = "UI", maxLength = 3 },          -- APM In Toytown (a): a daily quest is done
	QuestClaim = { ids = { 9113849579 }, volume = 0.22, pitch = 0.03, group = "UI", maxLength = 1.6 },        -- PSE Coin Throws 1: quest reward claimed
	StreakClaim = { ids = { 9039566006 }, volume = 0.22, pitch = 0, group = "UI", maxLength = 3 },           -- APM Neon Nights (sting f): daily streak claimed
	ArmCountdown = { ids = { 9113939659 }, volume = 0.18, pitch = 0, group = "Gameplay" },                    -- PSE Cordless Phone beep 45: 3-2-1
	ArmGo = { ids = { 9117264449 }, volume = 0.22, pitch = 0, group = "Gameplay", maxLength = 0.6 },          -- PSE Referee Whistle 3: GO
	ArmTap = { ids = { 9113885617 }, volume = 0.05, pitch = 0.05, group = "UI" },                             -- PSE Computer Track Ball 52 click: each tap
	ArmSlam = { ids = { 9119912410 }, volume = 0.45, pitch = 0.04, group = "Gameplay", range = { 10, 60 }, maxLength = 1.1 }, -- PSE Wood Table Impact 2: the winner slams
	ShopBuy = { ids = { 9113728049 }, volume = 0.22, pitch = 0.02, group = "UI", maxLength = 1.6 },           -- PSE Cash Register 2: bought at the smoothie bar
	DrinkShake = { ids = { 9114889936 }, volume = 0.3, pitch = 0.04, group = "Gameplay", range = { 6, 30 }, maxLength = 1.6 }, -- PSE Juice Box sip 6: drinking a shake
	RivalWin = { ids = { 1846248237 }, volume = 0.25, pitch = 0, group = "Gameplay", maxLength = 4 },         -- APM Five Card Tricks 'Win': you beat a rival
	RivalLose = { ids = { 101507156781402 }, volume = 0.2, pitch = 0, group = "Gameplay", maxLength = 2 },    -- APM Glissando down: lost to a rival
	PetCheer = { ids = { 9125994778 }, volume = 0.18, pitch = 0.08, group = "Gameplay", range = { 6, 40 }, maxLength = 0.6 }, -- PSE Squeaky Toy 12: your pet cheers a set
	CameraShutter = { ids = { 9113678227 }, volume = 0.25, pitch = 0.02, group = "UI", maxLength = 1 },       -- PSE Camera Shutter 1: photo mode
	SkateRoll = { ids = { 9125955674 }, volume = 0.18, pitch = 0, group = "Gameplay" },                       -- PSE Skateboard Constant Rolling 1 (a loop; not wired yet)
	SkateGrind = { ids = { 9125956838 }, volume = 0.3, pitch = 0.05, group = "Gameplay", maxLength = 1.8 },   -- PSE Skateboard Tail Grinds 9 (not wired yet)
	DoorSlide = { ids = { 9114307558 }, volume = 0.18, pitch = 0.03, group = "Gameplay", range = { 6, 40 }, maxLength = 2 }, -- PSE Elevator Door, the closest licensed slide (not wired yet)
	StorePurchase = { ids = { 9126072697 }, volume = 0.2, pitch = 0.02, group = "UI", maxLength = 1.4 },      -- PSE Synth Sparkle Bell Ding 1: store purchase (not wired yet)
	MirrorOpen = { ids = { 9116395179 }, volume = 0.2, pitch = 0, group = "UI", maxLength = 2.2 },            -- PSE Magic Glows Chiming Hits 6: the mirror opens (not wired yet)

	-- The loading screen and the main menu (owner, 14 Oct): one track, looping, from the first frame until Play. The
	-- loading screen starts it before this module can load, so the id is repeated in ReplicatedFirst.LoadingScreen (LOOK.Music):
	-- change both. Then the area music below takes over.
	MenuMusic = { ids = { 118959016267248 }, volume = 0.7, pitch = 0, group = "Music" },

	-- Music (2D, low in the background, plays the tracks in order and loops). The owner's own tracks (14 Oct); this list
	-- plays wherever an area below has no list of its own.
	Music = { ids = { 118959016267248, 99979837873059, 131532099124744, 139266399633943, 86451874359343, 113417603188158, 1840007392 }, volume = 0.7, pitch = 0, group = "Music" },

	-- Area music: which tracks play where (Audio.SetArea; SettingsClient picks the area). Put as many ids in an area's
	-- list as you like, separated by commas: they play one after another in that order, then start again from the first.
	-- e.g. Starter = { 86451874359343, 131532099124744, 139266399633943 },
	AreaMusic = {
		-- (owner, 14 Oct: several songs in every area: each area's own song first, then the owner's other tracks)
		Starter = { 86451874359343, 131532099124744, 135822443550596 }, -- the starter gym
		Pro = { 118959016267248, 113417603188158, 139777823649977 },    -- the pro gym
		Beach = { 1837324500, 95854242246323, 102866809292046 },         -- the beach, beach gym, posing stage, skate park
		-- the streets, plaza and shops (21 Oct: + APM Hit The Street, City Lights (A) from Roblox's licensed library; swap freely)
		Town = { 1840007392, 1840558258, 1840517437 },
	},
}
