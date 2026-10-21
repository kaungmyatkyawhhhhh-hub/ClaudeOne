-- Auras (owner, 14 Oct): a cosmetic effect around the character, built on every client from the equipped aura's id
-- (AuraClient; the server only replicates the id as the player's "Aura" attribute). Three layers:
--   1 inner glow   soft particles close to the body + one soft light       idle: subtle; lifting: full
--   2 outer energy  flames / smoke / energy rising up around the body      at 50% PUMP and up
--   3 sparks       sparks bursting out + a thin column of light             at 100% PUMP / while PUMPED
-- A new personal record bursts every layer once. Everything scales with the character's size.
-- Unlock (AuraService checks it on the server; earned auras are kept forever, pass auras while the pass is owned):
--   { type = "level", level = n }    the average muscle level (the top bar's LVL) reached n
--   { type = "height" }              reached 7'0"
--   { type = "achievements" }        finished the Coach's whole quest chain
--   { type = "pass", pass = key }    owns that game pass (Config/Monetization key)
--   { type = "coins", price = n }    bought once with coins
-- short = the few words on a Store tile ("LVL 10", "Aura Pack", "50,000").
-- Icon = the owner's aura orbs (prompt 45, 22 Oct: Downloads\gym_arc_transparent_icons\auras, transparent; the alter auras
-- reuse an earned one's orb).
-- style: "flame" (fire rising), "smoke" (dark smoke rising), "frost" (cold mist + flakes), "electric" (crackling
-- sparks), "stars" (twinkling stars), "toxic" (bubbling glow).
local Auras = {}

local function c(hex) return Color3.fromHex(hex) end

Auras.List = {
	-- earned
	{ id = "Ember", vfx = "ember", name = "Ember", rarity = "Common", style = "flame", colors = { c("#FF8A2B"), c("#FFD27A") },
		unlock = { type = "level", level = 10 }, how = "Reach LVL 10", short = "LVL 10", Icon = "rbxassetid://138073278679148" },
	{ id = "Frost", vfx = "frost", name = "Frost", rarity = "Uncommon", style = "frost", colors = { c("#8FD8FF"), c("#E8F8FF") },
		unlock = { type = "level", level = 25 }, how = "Reach LVL 25", short = "LVL 25", Icon = "rbxassetid://74261206142711" },
	{ id = "Storm", vfx = "storm", name = "Storm", rarity = "Rare", style = "electric", colors = { c("#9CC8FF"), c("#FFFFFF") },
		unlock = { type = "level", level = 50 }, how = "Reach LVL 50", short = "LVL 50", Icon = "rbxassetid://134283670005654" },
	{ id = "Golden", vfx = "golden", name = "Golden", rarity = "Legendary", style = "flame", colors = { c("#FFC93C"), c("#FFF1B8") },
		unlock = { type = "height" }, how = "Reach 7'0\"", short = "7'0\"", Icon = "rbxassetid://72969190443545" },
	{ id = "Titan", vfx = "titan", name = "Titan", rarity = "Legendary", style = "flame", colors = { c("#E8343C"), c("#FFC93C") },
		unlock = { type = "achievements" }, how = "Finish every Coach Quest", short = "All quests", Icon = "rbxassetid://73997537236580" },
	-- Body Alters (prompt 21): a tier's aura at its 5th alter (placeholder looks: the earned auras' effects)
	{ id = "AlterHuman", vfx = "ember", name = "Peak Human", rarity = "Epic", style = "flame", colors = { c("#FFB36B"), c("#FFF1D6") },
		unlock = { type = "alter", alter = 5 }, how = "Reach Alter 5", short = "Alter 5", Icon = "rbxassetid://138073278679148" },
	{ id = "AlterStone", vfx = "frost", name = "Stone Skin", rarity = "Epic", style = "frost", colors = { c("#A39A8E"), c("#E6E2DA") },
		unlock = { type = "alter", alter = 10 }, how = "Reach Alter 10", short = "Alter 10", Icon = "rbxassetid://74261206142711" },
	{ id = "AlterMetal", vfx = "storm", name = "Forged", rarity = "Legendary", style = "electric", colors = { c("#9AA3AD"), c("#FFFFFF") },
		unlock = { type = "alter", alter = 15 }, how = "Reach Alter 15", short = "Alter 15", Icon = "rbxassetid://134283670005654" },
	{ id = "AlterGem", vfx = "golden", name = "Gemstone", rarity = "Legendary", style = "flame", colors = { c("#8A4FD8"), c("#CFF3FF") },
		unlock = { type = "alter", alter = 20 }, how = "Reach Alter 20", short = "Alter 20", Icon = "rbxassetid://72969190443545" },
	{ id = "AlterElements", vfx = "titan", name = "Elemental", rarity = "Legendary", style = "flame", colors = { c("#E5501E"), c("#9AD9FF") },
		unlock = { type = "alter", alter = 25 }, how = "Reach Alter 25", short = "Alter 25", Icon = "rbxassetid://73997537236580" },
	{ id = "AlterLegend", vfx = "golden", name = "Living Legend", rarity = "Legendary", style = "flame", colors = { c("#FFD36B"), c("#F2F6FF") },
		unlock = { type = "alter", alter = 30 }, how = "Reach Alter 30", short = "Alter 30", Icon = "rbxassetid://72969190443545" },
	-- Aura Pack pass
	{ id = "Inferno", vfx = "inferno", name = "Inferno", rarity = "Epic", style = "flame", colors = { c("#FF3B1F"), c("#FF9A2E") },
		unlock = { type = "pass", pass = "AuraPack" }, how = "Aura Pack", short = "Aura Pack", Icon = "rbxassetid://125663321482602" },
	{ id = "BloodMoon", vfx = "blood_moon", name = "Blood Moon", rarity = "Epic", style = "smoke", colors = { c("#B3121C"), c("#1A0A0C") },
		unlock = { type = "pass", pass = "AuraPack" }, how = "Aura Pack", short = "Aura Pack", Icon = "rbxassetid://134602853072749" },
	{ id = "Void", vfx = "void", name = "Void", rarity = "Epic", style = "smoke", colors = { c("#8A3CFF"), c("#120A1E") },
		unlock = { type = "pass", pass = "AuraPack" }, how = "Aura Pack", short = "Aura Pack", Icon = "rbxassetid://72815742565724" },
	{ id = "Neon", vfx = "neon", name = "Neon", rarity = "Epic", style = "electric", colors = { c("#FF3FD2"), c("#3FF2FF") },
		unlock = { type = "pass", pass = "AuraPack" }, how = "Aura Pack", short = "Aura Pack", Icon = "rbxassetid://135059066043320" },
	{ id = "Galaxy", vfx = "galaxy", name = "Galaxy", rarity = "Epic", style = "stars", colors = { c("#2B3FA8"), c("#E6E9FF") },
		unlock = { type = "pass", pass = "AuraPack" }, how = "Aura Pack", short = "Aura Pack", Icon = "rbxassetid://99887350441472" },
	-- VIP pass
	{ id = "Royal", vfx = "royal", name = "Royal", rarity = "Legendary", style = "stars", colors = { c("#FFD36B"), c("#FFFFFF") },
		unlock = { type = "pass", pass = "VIP" }, how = "VIP", short = "VIP", Icon = "rbxassetid://85878618078587" },
	-- coins
	{ id = "Toxic", vfx = "toxic", name = "Toxic", rarity = "Rare", style = "toxic", colors = { c("#5FE83A"), c("#C8FF8A") },
		unlock = { type = "coins", price = 50000 }, how = "50,000 coins", short = "50,000", Icon = "rbxassetid://115598555521730" },
	{ id = "Shadow", vfx = "shadow", name = "Shadow", rarity = "Epic", style = "smoke", colors = { c("#6A6A78"), c("#1A1A20") },
		unlock = { type = "coins", price = 150000 }, how = "150,000 coins", short = "150,000", Icon = "rbxassetid://131376115105796" },
}

Auras.ById = {}
for index, aura in ipairs(Auras.List) do
	aura.order = index
	Auras.ById[aura.id] = aura
end

-- how auras show (AuraClient; the effect itself is Shared/VFX/AuraVFX, the owner's module, its preset = `vfx` above)
Auras.FullLOD = 40   -- studs: other players' auras at full detail within this
Auras.MidLOD = 90    -- studs: from FullLOD to here, glow + ground only; further away (or the setting off): none
Auras.IdlePower = 0.15 -- not lifting
-- the effect's textures, preloaded on join (AuraClient) so the first aura never shows blank cards; the SAME ids as the
-- TEX table in Shared/VFX/AuraVFX (the owner's file, left as it is): change both together
Auras.VFXTextures = {
	"rbxassetid://138347218007327", "rbxassetid://136758735885193", "rbxassetid://90041400001838", "rbxassetid://76009392745145", "rbxassetid://80590302550492", "rbxassetid://113405238797101", "rbxassetid://137490039482038", "rbxassetid://82372237523631", "rbxassetid://131893925782949", "rbxassetid://74138882329945",
}

return Auras
