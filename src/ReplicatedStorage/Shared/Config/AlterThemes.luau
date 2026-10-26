-- AlterThemes (prompt 22, 21 Oct): how each Body Alter's BODY ALTER READY popup and its transformation look and sound.
-- One theme per alter (by number, 1-30). Shared/UI/AlterPopup and Shared/VFX/AlterFX read it; Config.Alters stays the
-- game rules.
--   bg          the popup background image (1200 x 480, no text; Tier 1 has art, later tiers use their colors only)
--   base        the panel's dark base color (behind the art, or the whole background without art)
--   accent      the border, the ALTER button, shockwaves, rim glow on the body
--   buttonText  the ALTER button's text color
--   title       the name's gradient (top -> bottom)
--   intro       the popup's own entrance beat: heartbeat / slice / rise / veins / spotlight (Tier 1), stone / metal / gem /
--               frost / storm / lava / toxic / plasma / legend (later tiers)
--   particle    what drifts behind the popup and bursts off the body: { texture (AuraVFX texture key), color, motion }
--               motion: "rise" (embers up), "fall" (dust / rain down), "drift" (sparkles in place)
--   sting       this alter's own sound layers: { sound key (AlterThemes.Sounds) or { id, volume, pitch }, delay }
-- Sounds: only Roblox licensed library audio (Pro Sound Effects / APM, free to use in games). Every id is here so the
-- owner can swap any of them.
local AlterThemes = {}

-- The shared sound layers (popup entrance, transformation). volume is before the effects volume setting.
AlterThemes.Sounds = {
	Riser = { id = 9120735973, volume = 0.45 },        -- PSE Whoosh Suction 10 (reversed whoosh: the build before the impact)
	ImpactSub = { id = 9125484526, volume = 0.55 },    -- PSE Deep Hits Big Reverberant Booms 1 (the sub boom when the panel slams in)
	ImpactPunch = { id = 9120730275, volume = 0.5 },   -- PSE Whoosh Impact 1 (thick swish + hard hit: the mid punch phones can play)
	Stamp = { id = 9043367506, volume = 0.5 },         -- APM Percussive Noise 07 Kick 04 (the name stamping in)
	Shimmer = { id = 9116394876, volume = 0.22 },      -- PSE Magic Glows Chiming Hits 2 (the stamp's shimmer tail)
	Hum = { id = 9114353038, volume = 0.08 },          -- PSE Evil Drone Deep Airy Swell 1 (soft low hum while the popup is open)
	Confirm = { id = 9116684733, volume = 0.45 },      -- PSE Metal Impacts 1 (ALTER tapped: a heavy plate locking in)
	ChargeUp = { id = 9043365842, volume = 0.5 },      -- APM Heartbeat 02 96BPM (the slow-mo heartbeat, faster and faster)
	Swell = { id = 9120273504, volume = 0.35 },        -- PSE Tsunami Wind Up Huge Synth Powerup 1 (energy gathering)
	FlashBoom = { id = 9125484367, volume = 0.7 },     -- PSE Deep Hits Big Reverberant Booms 2 (THE flash)
	FlashPunch = { id = 9120730275, volume = 0.55 },   -- PSE Whoosh Impact 1 (the flash's mid punch)
	Sparkle = { id = 9126073302, volume = 0.3 },       -- PSE Synth Sparkle Bell Ding 2 (the glassy sparkle on the flash)
	Chime = { id = 9126073001, volume = 0.35 },        -- PSE Synth Sparkle Bell Ding 4 (the reveal; one small pitch step higher per alter)
	Cheer = { id = 9120973900, volume = 0.18 },        -- PSE Wrestling Crowd 2 (short punchy cheers)
	CheerBig = { id = 9112766176, volume = 0.2 },      -- PSE Crowd Cheer And Applause 1 (tier finale: longer)
	TitleHit = { id = 1837830196, volume = 0.45 },     -- APM BOOM Deep Boom 02 (the title card lands)
	FinaleBoom = { id = 9125484743, volume = 0.6 },    -- PSE Deep Hits Big Reverberant Booms 3 (tier finale: the bigger boom)
	-- themed stings
	Heartbeat = { id = 1840158546, volume = 0.6 },     -- APM Heart Pulse
	Shing = { id = 9119076918, volume = 0.4 },         -- PSE Shing Ringy 4 (large ringy metal blade)
	WarmWhoosh = { id = 9113083076, volume = 0.35 },   -- PSE Airy Whoosh Blast 23
	WarmChime = { id = 9126073011, volume = 0.3 },     -- PSE Synth Sparkle Bell Ding 3
	Crackle = { id = 9114237487, volume = 0.3 },       -- PSE Electric Arcing 4
	Brass = { id = 9040287624, volume = 0.4 },         -- APM Caught Off Guard (full orchestra stab)
	StoneThud = { id = 9125869505, volume = 0.5 },     -- PSE Rock Drops Smashes Impacts Hits 1
	MetalClang = { id = 9116750726, volume = 0.5 },    -- PSE Metal Plate Impact
	CrystalChime = { id = 9116394876, volume = 0.35 }, -- PSE Magic Glows Chiming Hits 2
	IceCrack = { id = 9118587494, volume = 0.45 },     -- PSE Rock Drop On Concrete Breaks 2 (pitched up: ice)
	Thunder = { id = 9113169432, volume = 0.5 },       -- PSE Artillery Distant 2 (deep booms: thunder)
	Bubble = { id = 9120348019, volume = 0.5 },        -- PSE Underwater Movement 801 (bubbles)
	CosmicSwell = { id = 9039636793, volume = 0.35 },  -- APM Stargazing (sting c)
}
-- How long the long files are allowed to play (seconds; they fade out)
AlterThemes.MaxLength = {
	Riser = 0.9, Hum = 30, ChargeUp = 1.6, Swell = 1.7, Heartbeat = 1.4, Cheer = 2.6, CheerBig = 4.5, Thunder = 2.4, Crackle = 1.2,
	CosmicSwell = 2.5, Brass = 2.5, FlashBoom = 3, FinaleBoom = 3.5, ImpactSub = 2, Bubble = 1.4,
}
AlterThemes.ChimeStep = 0.03 -- the reveal chime is this much higher for every alter (1.00, 1.03, 1.06 ...)
AlterThemes.MaxParticles = { idle = 20, peak = 40 } -- on screen at once (Low graphics: half)

local C = Color3.fromHex
local themes = {}

-- Tier 1 (art by the planner: Downloads\gym_arc_alters\ui_tier1, uploaded 21 Oct)
themes[1] = { -- PUMPED: crimson, a heartbeat
	bg = "rbxassetid://116819823138326", base = C("#3A0A0E"), accent = C("#FF3B3B"), buttonText = C("#FFFFFF"),
	title = { C("#FF6A5E"), C("#B3121A") }, intro = "heartbeat",
	particle = { texture = "ember", color = C("#FF4A3A"), motion = "rise" },
	sting = { { "Heartbeat", 0 } },
}
themes[2] = { -- SHREDDED: steel / silver, ice-blue, a blade
	bg = "rbxassetid://80757474213440", base = C("#14181D"), accent = C("#A9D4F2"), buttonText = C("#14181D"),
	title = { C("#EEF3F8"), C("#8C9AAA") }, intro = "slice",
	-- (prompt 57) its art is dark steel with thin blades at the edges: on the HUD's NEXT pill a lighter shade and a wash of
	-- the accent, so it shows as much as PUMPED's (pillShade = the black's transparency left / right; pillWash = the
	-- accent layer's transparency; the defaults: 0.45 / 0.75, none)
	pillShade = { 0.62, 0.9 }, pillWash = 0.8,
	particle = { texture = "spark", color = C("#DDEFFF"), motion = "drift" },
	sting = { { "Shing", 0 } },
}
themes[3] = { -- TANNED: bronze sunset, the sun
	bg = "rbxassetid://87062086356635", base = C("#4A2208"), accent = C("#FFB347"), buttonText = C("#3A1C05"),
	title = { C("#FFD08A"), C("#E0761E") }, intro = "rise",
	particle = { texture = "ember", color = C("#FFC062"), motion = "rise" },
	sting = { { "WarmWhoosh", 0 }, { "WarmChime", 0.25 } },
}
themes[4] = { -- VASCULAR: dark purple, red and blue veins
	bg = "rbxassetid://140546408644128", base = C("#120A1A"), accent = C("#D86BF0"), buttonText = C("#FFFFFF"),
	title = { C("#FF5A6E"), C("#5A6BFF") }, intro = "veins",
	particle = { texture = "spark", color = C("#C86BFF"), motion = "drift" },
	sting = { { "Crackle", 0 } },
}
themes[5] = { -- PEAK: black + gold, the summit (tier finale)
	bg = "rbxassetid://81204181773367", base = C("#100C06"), accent = C("#F6C75A"), buttonText = C("#2A1C04"),
	title = { C("#FFF3C4"), C("#C98A12") }, intro = "spotlight",
	particle = { texture = "spark", color = C("#FFD36B"), motion = "fall" },
	sting = { { "Brass", 0 }, { "CheerBig", 0.3 } },
}

-- Tiers 2-6: colors and gradients only (no art yet). Each alter its own name colors.
local tierStyle = {
	[2] = { intro = "stone", sting = { { "StoneThud", 0 } }, particle = { texture = "smoke", motion = "fall" } },
	[3] = { intro = "metal", sting = { { "MetalClang", 0 } }, particle = { texture = "spark", motion = "drift" } },
	[4] = { intro = "gem", sting = { { "CrystalChime", 0 } }, particle = { texture = "spark", motion = "drift" } },
	[5] = { intro = nil, sting = nil, particle = nil }, -- (per alter below)
	[6] = { intro = "legend", sting = { { "CosmicSwell", 0 } }, particle = { texture = "spark", motion = "drift" } },
}
-- [n] = { base, accent, title top, title bottom, button text, (tier 5: intro, sting, particle texture / motion) }
local colors = {
	[6] = { "#2A1810", "#C9845E", "#E8B08E", "#8A4A2E", "#FFFFFF" },  -- Clay
	[7] = { "#2E2414", "#E3BE7E", "#F4DDA8", "#B0874A", "#2E2414" },  -- Sandstone
	[8] = { "#1C1C1E", "#A8A6A4", "#E2E0DE", "#6E6B69", "#1C1C1E" },  -- Granite
	[9] = { "#24221F", "#F2EEE6", "#FFFFFF", "#B9B3A8", "#24221F" },  -- Marble
	[10] = { "#0A080E", "#8E6BD8", "#B9A3F0", "#3A2A5E", "#FFFFFF" }, -- Obsidian
	[11] = { "#24140A", "#D08A48", "#F2BE86", "#8E5420", "#FFFFFF" }, -- Bronze
	[12] = { "#141416", "#8E9098", "#C6C8CE", "#4A4C52", "#FFFFFF" }, -- Iron
	[13] = { "#12161A", "#B8C6D4", "#EEF3F8", "#7A8696", "#12161A" }, -- Steel
	[14] = { "#101418", "#E6F0FA", "#FFFFFF", "#9FB2C6", "#101418" }, -- Chrome
	[15] = { "#1A1204", "#FFD36B", "#FFF3C4", "#D9A21E", "#2A1C04" }, -- Gold
	[16] = { "#06180F", "#3FD69A", "#9AF2C8", "#1E8A5A", "#06180F" }, -- Jade
	[17] = { "#1A0408", "#FF3A5A", "#FF8AA0", "#B3102E", "#FFFFFF" }, -- Ruby
	[18] = { "#040C1E", "#4A7CFF", "#9AB6FF", "#1E3EB0", "#FFFFFF" }, -- Sapphire
	[19] = { "#12061E", "#B57CFF", "#D8B6FF", "#6A2EC0", "#FFFFFF" }, -- Amethyst
	[20] = { "#0C141A", "#DFF8FF", "#FFFFFF", "#9FE6FF", "#0C141A" }, -- Diamond
	[21] = { "#06121E", "#9AD9FF", "#E6F7FF", "#5AAEE8", "#06121E", "frost", "IceCrack", "spark", "fall" },  -- Frost
	[22] = { "#0A0C1A", "#9A8CFF", "#D2CCFF", "#4A54B8", "#FFFFFF", "storm", "Thunder", "lightning", "drift" }, -- Storm
	[23] = { "#1E0802", "#FF6A1E", "#FFC24A", "#D9300E", "#FFFFFF", "lava", "WarmWhoosh", "ember", "rise" },   -- Lava
	[24] = { "#081A04", "#7CFF3A", "#C8FF8A", "#3AA81E", "#081A04", "toxic", "Bubble", "droplet", "rise" },     -- Toxic
	[25] = { "#1A041E", "#FF4AF0", "#FFA6F8", "#B01EC8", "#FFFFFF", "plasma", "Crackle", "spark", "drift" },    -- Plasma
	[26] = { "#1E0A06", "#E06A3A", "#FFB08A", "#A8321E", "#FFFFFF" }, -- Titan
	[27] = { "#04061A", "#7A8CFF", "#C6D0FF", "#3A2AA8", "#FFFFFF" }, -- Galaxy
	[28] = { "#1A0E1E", "#FFD36B", "#FFF0B0", "#9A4AD8", "#2A1C04" }, -- Royal
	[29] = { "#050307", "#FF8A2A", "#FFC27A", "#2A1A30", "#FFFFFF" }, -- Eclipse
	[30] = { "#0E1018", "#FFF0C0", "#FFFFFF", "#F6C75A", "#2A1C04" }, -- Celestial
}
-- (26 Oct) popup background art for Tiers 2-3 (tools/alter_backgrounds.py, Downloads\gym_arc_alters\for_group_bg, imported
-- to the group by the owner): abstract, no bodies, no text, like Tier 1's
local bgs = {
	[6] = "rbxassetid://86081477005772",   -- Clay: glowing cracks
	[7] = "rbxassetid://136007448586409",  -- Sandstone: dunes under a warm sun
	[8] = "rbxassetid://124884905254975",  -- Granite: shards of light
	[9] = "rbxassetid://130454706656390",  -- Marble: glowing veins
	[10] = "rbxassetid://130654508259652", -- Obsidian: violet glass shards
	[11] = "rbxassetid://102483147646116", -- Bronze: forge sparks
	[12] = "rbxassetid://78384329885876",  -- Iron: a hot seam and rivets
	[13] = "rbxassetid://132353472571060", -- Steel: blades of light
	[14] = "rbxassetid://72824563055626",  -- Chrome: mirror sweeps
	[15] = "rbxassetid://92792053789881",  -- Gold: a gold burst (end of Tier 3)
}
for n, c in pairs(colors) do
	local tier = math.ceil(n / 5)
	local style = tierStyle[tier]
	themes[n] = {
		bg = bgs[n],
		base = C(c[1]), accent = C(c[2]), title = { C(c[3]), C(c[4]) }, buttonText = C(c[5]),
		intro = c[6] or style.intro,
		sting = if c[7] then { { c[7], 0 } } else style.sting,
		particle = { texture = c[8] or style.particle.texture, color = C(c[2]), motion = c[9] or style.particle.motion },
	}
end
AlterThemes.Themes = themes

-- The theme for alter n (the last tier's for anything past 30), plus n, finale (every 5th alter) and the sounds
function AlterThemes.Get(n: number)
	local theme = themes[math.clamp(math.floor(n), 1, 30)]
	return setmetatable({ number = n, finale = n % 5 == 0 }, { __index = theme })
end

-- (prompt 54, 23 Oct) THE alter icon everywhere: a cartoon flexed bicep (Downloads\gym_arc_alter_bicep_icons, uploaded
-- 23 Oct with the owner's OK). Alters without their own picture use the light grey base tinted with their accent. Never
-- body pictures for alters. AlterThemes.Icon(id) -> image, tint (nil = shown as it is).
AlterThemes.Icons = {
	Natural = "rbxassetid://130526825586547",
	Pumped = "rbxassetid://137729197869293",
	Shredded = "rbxassetid://71992766167225",
	Tanned = "rbxassetid://128096768249425",
	Vascular = "rbxassetid://120797137969021",
	Peak = "rbxassetid://123133557518612",
	Gold = "rbxassetid://109478944715600", -- bicep_golden
}
AlterThemes.IconBase = "rbxassetid://82746046688271" -- bicep_base_tint (light grey)
function AlterThemes.Icon(id: string, n: number): (string, Color3?)
	local own = AlterThemes.Icons[id]
	if own then return own, nil end
	return AlterThemes.IconBase, AlterThemes.Get(math.max(n, 1)).accent
end

return AlterThemes
