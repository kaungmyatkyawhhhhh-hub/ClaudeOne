-- Cosmetic gear sold at the clothing store in the town hub and worn from the Wardrobe. Cosmetic only (no stats).
-- Every item is built from simple parts on the character (CosmeticService), so there are no outside models.
-- slot: one item per slot is worn at a time. style: how CosmeticService builds it. color: the item's main color.
-- Adding an item = adding an entry here.
local Cosmetics = {}

Cosmetics.Slots = {
	{ id = "Waist", name = "Lifting belt" },
	{ id = "Head", name = "Headband" },
	{ id = "Wrists", name = "Wrist wraps" },
	{ id = "Hip", name = "Shaker" },
}

local function hex(value) return Color3.fromHex(value) end

Cosmetics.Items = {
	-- lifting belts (a wide band around the waist with a buckle)
	{ id = "BeltBlack", name = "Black belt", slot = "Waist", style = "Belt", color = hex("#1E1E22"), price = 120 },
	{ id = "BeltBrown", name = "Leather belt", slot = "Waist", style = "Belt", color = hex("#6B4428"), price = 150 },
	{ id = "BeltRed", name = "Red belt", slot = "Waist", style = "Belt", color = hex("#B3262D"), price = 200 },
	-- headbands
	{ id = "BandWhite", name = "White headband", slot = "Head", style = "Headband", color = hex("#F4F1EA"), price = 60 },
	{ id = "BandBlue", name = "Blue headband", slot = "Head", style = "Headband", color = hex("#1F5FBF"), price = 80 },
	{ id = "BandGreen", name = "Green headband", slot = "Head", style = "Headband", color = hex("#2E9E4F"), price = 80 },
	-- wrist wraps (both wrists)
	{ id = "WrapsBlack", name = "Black wraps", slot = "Wrists", style = "Wraps", color = hex("#26262A"), price = 70 },
	{ id = "WrapsYellow", name = "Yellow wraps", slot = "Wrists", style = "Wraps", color = hex("#E8C21C"), price = 90 },
	{ id = "WrapsRed", name = "Red wraps", slot = "Wrists", style = "Wraps", color = hex("#D7262E"), price = 90 },
	-- shaker bottles (clipped at the hip)
	{ id = "ShakerWhite", name = "White shaker", slot = "Hip", style = "Shaker", color = hex("#F4F1EA"), price = 100 },
	{ id = "ShakerPink", name = "Pink shaker", slot = "Hip", style = "Shaker", color = hex("#E86FA3"), price = 120 },
	{ id = "ShakerBlack", name = "Black shaker", slot = "Hip", style = "Shaker", color = hex("#1E1E22"), price = 120 },
}

Cosmetics.ById = {}
for index, item in ipairs(Cosmetics.Items) do
	item.order = index
	Cosmetics.ById[item.id] = item
end
Cosmetics.SlotById = {}
for _, slot in ipairs(Cosmetics.Slots) do Cosmetics.SlotById[slot.id] = slot end

return Cosmetics
