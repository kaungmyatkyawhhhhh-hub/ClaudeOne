-- Skin texture stages (owner's brief, 8 Oct): 5 stages x color / normal / roughness, our own 1024x1024 textures
-- (Downloads/skin_textures, uploaded to the group "Myanmar Builders Club", which owns the game). The color maps are near-white:
-- SurfaceAppearance.Color = the player's skin tone tints them. ReplicatedStorage.SkinStages holds one SurfaceAppearance per
-- stage (Stage1..Stage5), built once in Studio by tools/builders/SkinStages (a game script can't set a SurfaceAppearance's
-- maps; cloning a built one is fine). MuscleRig picks the stage from the body's look (SkinStages.Pick).
local SkinStages = {}

SkinStages.List = {
	{
		name = "Stage1", -- level 0: plain skin, faint pores, matte
		color = "rbxassetid://83803342214797",
		normal = "rbxassetid://88443693775128",
		roughness = "rbxassetid://108195373359813",
	},
	{
		name = "Stage2", -- about half way: slightly shinier, faint grain
		color = "rbxassetid://129087999336968",
		normal = "rbxassetid://139711406490179",
		roughness = "rbxassetid://111641706846491",
	},
	{
		name = "Stage3", -- the full aesthetic look: smooth, shiny, fine striation
		color = "rbxassetid://99034682229244",
		normal = "rbxassetid://128958363893964",
		roughness = "rbxassetid://104832376009194",
	},
	{
		name = "Stage4", -- early mass monster: rock starting to show
		color = "rbxassetid://105462181766151",
		normal = "rbxassetid://85365682861871",
		roughness = "rbxassetid://85256387782133",
	},
	{
		name = "Stage5", -- full mass monster: lumpy stone, faint cracks, darker patches
		color = "rbxassetid://93591374798341",
		normal = "rbxassetid://109473935703799",
		roughness = "rbxassetid://71521978552485",
	},
}

-- Where each stage sits on the body's overall look (Muscles look g averaged over all muscles): 0 = level 0, 1 = the full
-- aesthetic look (max), past 1 = the mass monster transformation (1 -> 2 is the way to the monster: Stage3 -> 4 -> 5).
SkinStages.At = { 0, 0.5, 1, 1.5, 2 }

-- The body shows the stage nearest to its look: between two stages it switches at the midpoint, where the two look most
-- alike (the look itself moves slowly: a little per rep, or the 1.5 s mass monster tween), so it never pops.
-- (the look must move this far past a midpoint before the stage switches back: no flicker when a value sits right on it)
SkinStages.Hysteresis = 0.03

-- The stage index (1..5) for an overall look value, and how far it is between that stage and the next (0..1).
function SkinStages.Position(look: number): (number, number)
	local at = SkinStages.At
	if look <= at[1] then return 1, 0 end
	for i = 1, #at - 1 do
		if look < at[i + 1] then return i, (look - at[i]) / (at[i + 1] - at[i]) end
	end
	return #at, 0
end

-- The stage a body at `look` shows: the nearer of the two stages it is between (switching at the midpoint), with a little
-- hysteresis around the midpoint relative to `current`.
function SkinStages.Pick(look: number, current: number?): number
	local i, t = SkinStages.Position(look)
	local pick = if t >= 0.5 then math.min(i + 1, #SkinStages.List) else i
	if current and current ~= pick then
		-- stay on the current stage until the look is clearly past the midpoint
		local at = SkinStages.At
		local lo, hi = math.min(current, pick), math.max(current, pick)
		if hi - lo == 1 then
			local mid = (at[lo] + at[hi]) / 2
			if math.abs(look - mid) < SkinStages.Hysteresis then return current end
		end
	end
	return pick
end

return SkinStages
