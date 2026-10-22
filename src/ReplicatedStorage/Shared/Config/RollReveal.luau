-- RollReveal (prompt 49, 22 Oct): every timing, size and volume of the Trainer Agency's roll reveal (TrainerClient,
-- "The roll reveal"). (prompt 55, 23 Oct: the orb and its pulses and the spinning sunburst are gone: a name roller, a calm
-- dark background over the world, and for Legendary+ a cinematic in the world, Shared/VFX/RollCinematic; their numbers are
-- Roller, Background and Cinematic below.) Times in seconds, sizes in mockup px (Kit.Root units), volumes as multipliers of the sound's own.
-- Sounds are the Body Alter set (Config.AlterThemes.Sounds, Roblox's own library) and the UI set (Config.Sounds), layered
-- and pitched; the ids are listed in the vault's Sounds note.
local RollReveal = {}

-- The card (one layout; batches and rarities only scale it)
RollReveal.Card = {
	width = 220,
	pad = 10,          -- above the art
	art = 165,         -- the art area's height (the full body; prompt 56: 180 -> 165, room for the stat rows on phones)
	artWidth = 1.12,   -- the art box's width as a share of the card (a little wider, clipped)
	pill = 22, name = 38, dupe = 18, dupeBar = 5, -- (prompt 56: the name 30 -> 38)
	stat = 19, statGap = 1, statPad = 3, -- (prompt 56) the boosts: one row per stat (icon + "+35% EXP"), like MY TRAINERS
	bottom = 14,       -- under the last line
	corner = 14, outline = 4,
	hexTile = Vector2.new(18, 10), hexTransparency = 0.85, -- small cells, ~15%
	textSizes = { pill = 13, stat = 15, dupe = 11, sticker = 16 },
}
-- Card size by rarity (the best in a batch is the biggest); lift = moved up (mockup px)
RollReveal.RarityScale = { Common = 0.9, Uncommon = 0.9, Rare = 1, Epic = 1, Legendary = 1.1, Mythic = 1.15, Secret = 1.15 }
RollReveal.RarityLift = { Mythic = 8, Secret = 8 }

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
	gapBetweenCards = 0.2,
	cardIn = 0.35,           -- the card slides up into place after the roller lands
	flash = 0.1, flashReduced = 0.04,
	dress = 0.6, dressStagger = 0.08,
	beforeBar = 0.4,
	floatPeriod = 2, floatPx = 4,
	skipPop = 0.12,
	autoClose = 0.6,         -- the quick auto roll closes by itself
	-- (prompt 56) the dress: pill, name (+ its shimmer), NEW!, then the stat rows one by one (a tick each), then the dupe bar fills
	nameAt = 0.1, stickerAt = 0.3, rowsAt = 0.45, rowStagger = 0.2, dupeFill = 0.5,
}
-- the hold's ambient hum pitch by mood (warm gold, cold blue, airy white ...)
RollReveal.HumPitch = { Common = 1, Uncommon = 1.05, Rare = 1.2, Epic = 0.95, Legendary = 0.85, Mythic = 0.8, Secret = 0.7 }

-- (prompt 55) The roller: trainer names flick past in their rarity colours, fast, then slowing like a slot machine, a tick
-- each; the last few hover on rarer ones; it lands on the real result (a pop 1.2 -> 1 and its sound). Secret: it stops
-- dead on "???" while still fast.
RollReveal.Roller = {
	time = 1.2, fastTime = 0.6,   -- the whole roll (Auto Roll below the stop rarity: fast)
	names = 14, fastNames = 8,    -- names shown before the result
	slowdown = 2.2,               -- how sharply the gaps grow (ease-out)
	tease = 3,                    -- the last few before the result are rarer trainers
	land = 1.2, landTime = 0.18,  -- the result pops from this scale
	holdAfter = 0.35,             -- the result stays this long before the card comes up
	textSize = 40, y = 0.42,      -- (the middle of the screen)
	tick = 0.45,                  -- tick volume
}
-- (prompt 55) The background for every roll: the world stays visible but dark (a vignette, blur, a soft haze in the
-- rarity colour from the bottom, a few slow particles drifting up)
RollReveal.Background = {
	dim = 0.5,            -- the black wash's transparency
	vignette = 0.38,      -- how far the dark edges reach (share of the screen)
	haze = 0.55, hazeHeight = 0.55, -- the haze's strongest transparency, and its height
	particles = 14,       -- small dots drifting up
	blur = 12,
}
-- (prompt 55) The cinematic in the world after a Legendary+ lands (Shared/VFX/RollCinematic): letterbox, the HUD hidden,
-- music to silence, the colours graded to the rarity, the camera orbiting the player low and looking up, particles
-- swirling in, then at the peak a beam of light beside the player, a shockwave ring, a white flash and the trainer in
-- the beam flexing; the camera pushes in and the name, rarity and chance fade in. Legendary is the light version (no
-- colour grade, a smaller beam). Secret: 1 s of black and silence first, a heartbeat, a glitch flicker.
RollReveal.Cinematic = {
	Legendary = { length = 3.5, light = true },
	Mythic = { length = 5 },
	Secret = { length = 6, blackout = 1, color = "#FFF3C4" }, -- (white-gold light)
	letterbox = 0.12, barsTime = 0.35,  -- the bars' height (share of the screen) and slide time
	orbit = 90,                         -- degrees the camera turns round the player over the cutscene
	distance = 15, height = -1, lookUp = 3.5, -- the camera: studs out, height from the player's middle (low), aim this far up
	pushIn = 0.55,                      -- the camera ends this share of its distance away (the push in)
	peakAt = 0.5,                       -- share of the length when the beam hits
	textAt = 0.66,                      -- ...when the name fades in
	beamHeight = 140, beamWidth = 5, lightBeamWidth = 3.2, ringSize = 46, lightRingSize = 30,
	beamSide = 5,                       -- studs to the player's right
	particles = 45,                     -- (alive at once; phones: <= 60)
	grade = { brightness = -0.14, contrast = 0.18, saturation = -0.15, tint = 0.55 }, -- (tint = how much white in the rarity tint)
	unskippable = 2,                    -- a first-ever Mythic / Secret can't be skipped for this long
	observerRange = 150,                -- players this close see the beam and the shockwave
}

-- (prompt 56) The card comes alive (Shared/UI/RollCardFX). Sizes in mockup px, times in seconds.
RollReveal.Alive = {
	breath = 0.02, breathPeriod = 3.2,      -- the art swells this much (share of its height) and back
	flex = 0.035, flexEvery = 6, flexTime = 0.7, -- now and then a short flex on top
	artParallax = 3,                        -- the art moves this far with the tilt (more than the card: depth)
	tiltPx = 5, tiltSpeed = 6,              -- the card leans this far toward the mouse / finger, and how fast it follows
	idleSway = 0.35,                        -- without a pointer (phones) a slow sway, this share of the full tilt
	hexTransparency = 0.8,                  -- Common-Epic: the hex in the rarity colour (~20%)
	hexDots = 5, forgeEmbers = 6, borderSparks = 3,
	strikeEvery = Vector2.new(1.6, 3.4),    -- Volta: seconds between lightning strikes (min, max)
	screenFlash = 0.22,                     -- ...and how bright a strike lights up the screen behind
	escapeRate = 4, escapeMax = 8,          -- Legendary+: particles escaping the card's edges (a second, alive at once; half with low graphics)
	pillGlow = 0.45,                        -- the rarity pill's glow (transparency at its brightest)
}
-- (prompt 56) Each trainer's card theme (the rest: the hex in the rarity colour). bg = the card's gradient top to bottom;
-- color = the glow, the outline's highlight and the screen's haze; particle = what escapes the edges (Legendary+).
RollReveal.Themes = {
	BlazeCoach = { kind = "storm", color = "#4FA8FF", bg = { "#14295A", "#0A1530", "#05080F" }, particle = { texture = "spark", color = "#BFE4FF" } }, -- Volta
	AtlasCoach = { kind = "forge", color = "#FF8A2A", bg = { "#30353D", "#1A1D22", "#0D0E10" }, particle = { texture = "ember", color = "#FF9A3A" } }, -- Duke Ironside
	ShadeCoach = { kind = "smoke", color = "#A35CF0", bg = { "#21102F", "#0E0716", "#050307" }, particle = { texture = "smoke", color = "#7A34B8" } }, -- The Shadow
	AeonCoach = { kind = "clouds", color = "#FFE7A3", bg = { "#806428", "#3A2C12", "#17110A" }, particle = { texture = "droplet", color = "#FFF3C4" } }, -- Atlas
}

-- Volumes. Higher rarity = louder, capped at about +4 dB over Common (x1.585)
RollReveal.LoudestGain = 1.585
RollReveal.MusicDuck = 0.3 -- gameplay music down to ~30% while the reveal is up (the cinematic: silence)
RollReveal.OneShotMax = 1.5 -- every one-shot is cut to this (except the Legendary+ shine)
RollReveal.Volume = {
	swell = 0.6, heartbeat = 0.7, rumble = 0.7, sting = 0.9,
	pop = 1, chime = 0.6, whoosh = 0.8, thump = 0.6, impact = 0.9, sub = 0.8, shine = 0.6, ringBoom = 0.7,
	pillClick = 0.5, nameStamp = 0.8, sticker = 0.8, barTick = 0.4, rowTick = 0.5,
	hum = 0.5, riser = 0.4, fanfare = 0.7, swoosh = 0.6,
}

return RollReveal
