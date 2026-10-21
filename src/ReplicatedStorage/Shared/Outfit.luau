-- Outfit (prompt 34): which muscle stage pieces wear a character's clothing image.
-- A player's classic Shirt / Pants (style.shirt / style.pants from MuscleRig.StyleFrom) go on every piece they cover, as
-- before. A trainer's outfit is not a classic Shirt / Pants: it is a clean image made for the stage meshes
-- (tools/trainer_outfits.py: one solid color, so it never tears), from the model's attributes
-- OutfitShirt / OutfitPants, with style.outfit = true and how much it covers:
--   style.sleeves  "none" (the torso only) | "short" (+ the upper arms, to the elbow) | "long" (+ the forearms, to the wrist)
--   style.legs     "shorts" (the waist and the whole thighs, to the knee: the stage's own shorts piece alone is only the
--                  top of the thighs and looked like underwear) | "long" (+ the calves, to the ankle)
-- Marble bodies (the statue, Atlas) wear nothing, except an outfit's shorts (Atlas's white shorts).
local Outfit = {}

-- The image a stage piece wears ("" = none). clothing = "Shirt" / "Pants" (the piece's), part = the body part it stands
-- in for, kind = the BodyStages piece kind ("skin" / "top" / "shorts"; nil on the forearm / calf stages).
function Outfit.Template(style: any, clothing: string?, part: string?, kind: string?, marble: any): string
	if not style then return "" end
	if clothing == "Pants" then
		local image = style.pants
		if type(image) ~= "string" or image == "" then return "" end
		if style.legs == "shorts" then return if kind ~= nil then image else "" end -- (kind is nil on the calf stages)
		return if marble then "" else image
	elseif clothing == "Shirt" then
		local image = style.shirt
		if marble or type(image) ~= "string" or image == "" then return "" end
		local sleeves = style.sleeves
		if sleeves and part then
			if string.find(part, "UpperArm") and sleeves == "none" then return "" end
			if string.find(part, "LowerArm") and sleeves ~= "long" then return "" end
		end
		return image
	end
	return ""
end

return Outfit
