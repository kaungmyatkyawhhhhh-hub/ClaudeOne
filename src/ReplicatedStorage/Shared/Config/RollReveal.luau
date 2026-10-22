-- RollReveal (prompt 49, 22 Oct): every timing, size and volume of the Trainer Agency's roll reveal (TrainerClient,
-- "The roll reveal"). Times in seconds, sizes in mockup px (Kit.Root units), volumes as multipliers of the sound's own.
-- Sounds are the Body Alter set (Config.AlterThemes.Sounds, Roblox's own library) and the UI set (Config.Sounds), layered
-- and pitched; the ids are listed in the vault's Sounds note.
local RollReveal = {}

-- The card (one layout; batches and rarities only scale it)
RollReveal.Card = {
	width = 220,
	pad = 10,          -- above the art
	art = 180,         -- the art area's height (the full body, ~65-70% of the card)
	artWidth = 1.12,   -- the art box's width as a share of the card (a little wider, clipped)
	pill = 22, name = 30, perk = 18, dupe = 18, dupeBar = 5,
	bottom = 20,       -- under the last line
	corner = 14, outline = 4,
	hexTile = Vector2.new(18, 10), hexTransparency = 0.85, -- small cells, ~15%
	rays = 8, raysTransparency = 0.78,
	textSizes = { pill = 13, perk = 14, dupe = 11, sticker = 16 },
}
-- Card size by rarity (the best in a batch is the biggest); lift = moved up (mockup px)
RollReveal.RarityScale = { Common = 0.9, Uncommon = 0.9, Rare = 1, Epic = 1, Legendary = 1.1, Mythic = 1.15, Secret = 1.15, Eternal = 1.15 }
RollReveal.RarityLift = { Mythic = 8, Secret = 8, Eternal = 8 }
-- The orb's glow size (x the orb) by rarity: the first tell
RollReveal.OrbGlow = { Common = 1.6, Uncommon = 2, Rare = 2.3, Epic = 2.7, Legendary = 3.4, Mythic = 3.6, Secret = 3.6, Eternal = 3.8 }
RollReveal.OrbSize = 46

-- The screen
RollReveal.Screen = {
	dim = 0.1,          -- the backdrop's transparency (~90% black)
	top = 40,           -- kept free at the top (at least: Roblox's top bar + 8, measured)
	bottom = 74,        -- kept free at the bottom (the bar, and the cards' float)
	gap = 16,           -- between cards
	bubbleRoom = 36,    -- the speech bubble needs this above the card (left out when there's no room: phones)
	barHeight = 54, barWidth = 560,
}

-- Timings
RollReveal.Time = {
	setup = 0.3,
	orbDrop = 0.3,
	gapBetweenCards = 0.2,
	burst = 0.3,             -- the card snaps in (0 -> 1.15 -> 1.0)
	burstSlow = 2,           -- Legendary+: the burst at 0.5x speed (x2 the time; not with Reduced Motion)
	flash = 0.1, flashReduced = 0.04,
	dress = 0.6, dressStagger = 0.08,
	beforeBar = 0.4,
	floatPeriod = 2, floatPx = 4,
	raysDegPerSecond = 10,
	skipPop = 0.12,
	autoClose = 0.6,         -- the quick auto roll closes by itself
	hold = 0.4,              -- Legendary+: the held beat with the orb almost still
}
-- Pulses per rarity: { durations }, scale = how big each pulse gets
RollReveal.Pulses = {
	Common = { times = { 0.25 }, scale = 1.1 },
	Uncommon = { times = { 0.35, 0.35 }, scale = 1.18 },
	Rare = { times = { 0.35, 0.35 }, scale = 1.22 },
	Epic = { times = { 0.3, 0.4, 0.5 }, scale = 1.3 },
	Legendary = { times = { 0.3, 0.5, 0.7, 1.0 }, scale = 1.38 },
}
RollReveal.Pulses.Mythic, RollReveal.Pulses.Secret, RollReveal.Pulses.Eternal = RollReveal.Pulses.Legendary, RollReveal.Pulses.Legendary, RollReveal.Pulses.Legendary
-- Pulse tones (playback speed of the bell): Uncommon/Rare a minor third apart, Epic three climbing, Legendary+ four
-- climbing a full octave
RollReveal.Tones = {
	Common = { 1 },
	Uncommon = { 1, 1.189 }, Rare = { 1, 1.189 },
	Epic = { 1, 1.189, 1.414 },
	Legendary = { 1, 1.26, 1.5, 2 },
}
-- the hold's ambient hum pitch by mood (warm gold, cold blue, airy white ...)
RollReveal.HumPitch = { Common = 1, Uncommon = 1.05, Rare = 1.2, Epic = 0.95, Legendary = 0.85, Mythic = 0.8, Secret = 0.7, Eternal = 1.35 }

-- Volumes. Higher rarity = louder, capped at about +4 dB over Common (x1.585)
RollReveal.LoudestGain = 1.585
RollReveal.MusicDuck = 0.3 -- gameplay music down to ~30% from the orb's arrival until the reveal closes
RollReveal.OneShotMax = 1.5 -- every one-shot is cut to this (except the Legendary+ shine)
RollReveal.Volume = {
	orbThud = 0.5, orbShimmer = 0.5,
	tick = 0.6, tone = 0.7, swell = 0.6, heartbeat = 0.7,
	pop = 1, chime = 0.6, whoosh = 0.8, thump = 0.6, impact = 0.9, sub = 0.8, shine = 0.6, ringBoom = 0.7,
	pillClick = 0.5, nameStamp = 0.8, sticker = 0.8, barTick = 0.4,
	hum = 0.5, riser = 0.4, fanfare = 0.7, swoosh = 0.6,
}

return RollReveal
