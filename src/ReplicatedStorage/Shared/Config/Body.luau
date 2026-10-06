--!strict
-- Body: everyone (players, NPCs, statue, mirrors) wears the Robloxian 2.0 body (Roblox bundle 311). Only the five body
-- parts are replaced; head, face, hair, accessories and animations stay the player's own. The ids come from
-- AssetService:GetBundleDetailsAsync(311) and are stored here so nothing depends on the lookup at runtime (BodyService
-- may refresh them once at startup; if the lookup fails these stay).
local Body = {}

Body.BundleId = 311
Body.Parts = {
	Torso = 27112025,
	RightArm = 27112039,
	LeftArm = 27112052,
	LeftLeg = 27112056,
	RightLeg = 27112068,
}

-- The same shape for everyone: no Rthro/slender proportions, no width/depth tricks. Height comes from Growth Spurts.
-- (The uploaded skin images skin_color / skin_roughness are not used: muscle meshes are colored with vertex colors.)
Body.Scales = { BodyType = 0, Proportion = 0, Width = 1, Depth = 1, Head = 1 }

-- Accessory types that cover the body (removed: the gym look is shirtless with the game's own shorts).
Body.CoveringAccessories = { "TShirt", "Shirt", "Pants", "Jacket", "Sweater", "Shorts", "DressSkirt" }

-- Game-provided shorts (original, plain colors). id = settings.shorts.
Body.ShortsColors = {
	{ id = "Black", name = "Black", color = Color3.fromHex("#1E1E22") },
	{ id = "Navy", name = "Navy", color = Color3.fromHex("#1F3B73") },
	{ id = "Red", name = "Red", color = Color3.fromHex("#B3262D") },
	{ id = "Gray", name = "Gray", color = Color3.fromHex("#6E6E76") },
	{ id = "Teal", name = "Teal", color = Color3.fromHex("#2E8E8E") },
}
Body.DefaultShorts = "Black"

-- Tops (wardrobe "Top"). Shirtless = nothing. A top paints the upper torso (and the chest, back, abs and oblique muscles
-- on it); arms and shoulders stay skin.
Body.Tops = {
	{ id = "Shirtless", name = "Shirtless" },
	{ id = "Tank", name = "Tank top", color = Color3.fromHex("#F4F1EA") },
	{ id = "Sports", name = "Sports top", color = Color3.fromHex("#26262A") },
}
Body.DefaultTop = "Shirtless"

function Body.ShortsColor(id: string?): Color3
	for _, entry in ipairs(Body.ShortsColors) do
		if entry.id == id then return entry.color end
	end
	return Body.ShortsColors[1].color
end

function Body.TopColor(id: string?): Color3?
	for _, entry in ipairs(Body.Tops) do
		if entry.id == id then return entry.color end
	end
	return nil
end

-- Put the body on a HumanoidDescription (before it is applied or turned into a rig). skin = the skin color (default:
-- the description's own head color). heightScale is left alone unless given.
function Body.ApplyTo(desc: HumanoidDescription, skin: Color3?, heightScale: number?)
	desc.Torso = Body.Parts.Torso
	desc.RightArm = Body.Parts.RightArm
	desc.LeftArm = Body.Parts.LeftArm
	desc.LeftLeg = Body.Parts.LeftLeg
	desc.RightLeg = Body.Parts.RightLeg
	local color = skin or desc.HeadColor
	desc.HeadColor, desc.TorsoColor = color, color
	desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = color, color, color, color
	desc.BodyTypeScale = Body.Scales.BodyType
	desc.ProportionScale = Body.Scales.Proportion
	desc.WidthScale, desc.DepthScale, desc.HeadScale = Body.Scales.Width, Body.Scales.Depth, Body.Scales.Head
	if heightScale then desc.HeightScale = heightScale end
	-- shirtless + our own shorts: take the covering clothes off
	desc.Shirt, desc.Pants, desc.GraphicTShirt = 0, 0, 0
	local covering = {}
	for _, name in ipairs(Body.CoveringAccessories) do covering[name] = true end
	local keep = {}
	for _, item in ipairs(desc:GetAccessories(true)) do
		if not covering[item.AccessoryType.Name] then table.insert(keep, item) end
	end
	desc:SetAccessories(keep, true)
end

return Body
