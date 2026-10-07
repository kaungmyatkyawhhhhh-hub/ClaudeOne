-- Cosmetic gear sold at the clothing store in the town hub and worn from the Wardrobe. Cosmetic only (no stats), except
-- skate wheels, which only make the skateboard faster.
-- Gear is built from simple parts on the character (CosmeticService), so there are no outside models. Gym fits (slot
-- "Fit") are classic Shirts (2D, the 585x559 template): the muscle meshes wear the Shirt image, so they look right on any
-- body (layered 3D clothing would hide the muscles). Their images are drawn by tools/clothing_templates.ps1.
-- slot: one item per slot is worn at a time. style: how CosmeticService builds it. color: the item's main color.
-- Adding an item = adding an entry here.
local Cosmetics = {}

Cosmetics.Slots = {
	{ id = "Fit", name = "Gym fit" },
	{ id = "Waist", name = "Lifting belt" },
	{ id = "Head", name = "Headband" },
	{ id = "Wrists", name = "Wrist wraps" },
	{ id = "Hip", name = "Shaker" },
	{ id = "Board", name = "Skateboard", verb = "Using" },
	{ id = "Wheels", name = "Skate wheels", verb = "Using" },
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
	-- skateboard decks (SkateService builds the board from the one you use; color2 = a stripe on the grip)
	{ id = "DeckMint", name = "Mint deck", slot = "Board", style = "Deck", color = hex("#7CC6A5"), price = 80 },
	{ id = "DeckCoral", name = "Coral deck", slot = "Board", style = "Deck", color = hex("#E86A6A"), price = 80 },
	{ id = "DeckSunny", name = "Sunny deck", slot = "Board", style = "Deck", color = hex("#F2C14E"), price = 100 },
	{ id = "DeckOcean", name = "Ocean deck", slot = "Board", style = "Deck", color = hex("#2E6E8E"), price = 100 },
	{ id = "DeckStripe", name = "Stripe deck", slot = "Board", style = "Deck", color = hex("#1E1E22"), color2 = hex("#F2EEE6"), price = 150 },
	-- skate wheels: the only gear that changes anything, and only how fast you skate (studs per second; normal 30)
	{ id = "WheelsFast", name = "Fast wheels", slot = "Wheels", style = "Wheels", color = hex("#7FD0E8"), speed = 34, price = 150 },
	{ id = "WheelsFaster", name = "Faster wheels", slot = "Wheels", style = "Wheels", color = hex("#F2C14E"), speed = 38, price = 400 },
	{ id = "WheelsFastest", name = "Fastest wheels", slot = "Wheels", style = "Wheels", color = hex("#D7262E"), speed = 42, price = 900 },
}

-- Gym fits: each top in four colors (black, grey, white and its own accent). price in coins.
Cosmetics.Fits = {
	{ id = "GymTee", name = "gym tee", price = 150, accent = { "Sky", "#3A86C8" } },
	{ id = "Stringer", name = "stringer tank", price = 200, accent = { "Red", "#C0392B" } },
	{ id = "PumpCover", name = "pump cover", price = 300, accent = { "Sage", "#6B8E6B" } },
	{ id = "SleevelessHoodie", name = "sleeveless hoodie", price = 300, accent = { "Orange", "#E07B39" } },
	{ id = "Compression", name = "compression shirt", price = 350, accent = { "Navy", "#1F3B73" } },
	{ id = "CroppedHoodie", name = "cropped hoodie", price = 400, accent = { "Teal", "#2E8E8E" } },
}
Cosmetics.FitColors = { { "Black", "#1E1E22" }, { "Grey", "#7D8088" }, { "White", "#EDEDED" } }
-- the uploaded Shirt images (clothing_templates/<Fit>_<Color>.png; "Accent" = the fit's own color)
Cosmetics.FitTemplates = {
	PumpCover_Black = "rbxassetid://132399426355044", PumpCover_Grey = "rbxassetid://137137515832487",
	PumpCover_White = "rbxassetid://133040142752889", PumpCover_Accent = "rbxassetid://119446579401042",
	Stringer_Black = "rbxassetid://87827094772489", Stringer_Grey = "rbxassetid://98384978860041",
	Stringer_White = "rbxassetid://83507585874690", Stringer_Accent = "rbxassetid://73856140117246",
	Compression_Black = "rbxassetid://73544541382239", Compression_Grey = "rbxassetid://84656979660182",
	Compression_White = "rbxassetid://119193210879803", Compression_Accent = "rbxassetid://126392128430544",
	CroppedHoodie_Black = "rbxassetid://131180795129469", CroppedHoodie_Grey = "rbxassetid://83444217761020",
	CroppedHoodie_White = "rbxassetid://115988564389261", CroppedHoodie_Accent = "rbxassetid://130562701880992",
	GymTee_Black = "rbxassetid://73876922918132", GymTee_Grey = "rbxassetid://118501254574725",
	GymTee_White = "rbxassetid://89079587003434", GymTee_Accent = "rbxassetid://106999784089569",
	SleevelessHoodie_Black = "rbxassetid://121907706218279", SleevelessHoodie_Grey = "rbxassetid://93635678168959",
	SleevelessHoodie_White = "rbxassetid://119159659712895", SleevelessHoodie_Accent = "rbxassetid://112969817238945",
}
for _, fit in ipairs(Cosmetics.Fits) do
	local colors = table.clone(Cosmetics.FitColors)
	table.insert(colors, fit.accent)
	for index, entry in ipairs(colors) do
		local key = fit.id .. "_" .. (if index == #colors then "Accent" else entry[1])
		table.insert(Cosmetics.Items, {
			id = fit.id .. entry[1], name = entry[1] .. " " .. fit.name, slot = "Fit", style = "Shirt",
			color = hex(entry[2]), shirt = Cosmetics.FitTemplates[key], price = fit.price,
		})
	end
end

Cosmetics.ById = {}
for index, item in ipairs(Cosmetics.Items) do
	item.order = index
	Cosmetics.ById[item.id] = item
end
Cosmetics.SlotById = {}
for _, slot in ipairs(Cosmetics.Slots) do Cosmetics.SlotById[slot.id] = slot end

return Cosmetics
