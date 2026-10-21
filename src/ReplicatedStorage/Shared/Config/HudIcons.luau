-- Every HUD icon and tile color in one place (the left tile grid and the top-bar pills).
--   accent  the tile's border / 3D color
--   icon    the built-in white line icon (Shared.UI.Icons) used until you give an image
--   image   YOUR OWN icon: put an "rbxassetid://<id>" here and that tile/pill uses it instead of the built-in icon
-- Leave `image` empty to keep the built-in icons. The built-in icons are simple white glyphs built from UI shapes, so
-- these are the ones to replace with your own art later: Stats, Muscles, Titles, Genetics, Wardrobe, Poses, Crew,
-- Quests, Store (tiles) and Coins, Quests, Daily, Settings (pills).
local HudIcons = {}

-- The left menu tiles (owner, 13 Oct: keep the old colored tiles): accent = the tile's color (its face is the accent made
-- darker, its border the accent; the open panel's tile lights up in the full accent), icon = the built-in white line icon
-- (Shared.UI.Icons) or uiIcon (Config/UI.Icons), order = top-left to bottom-right, label = the word under the icon.
-- image = YOUR OWN icon ("rbxassetid://<id>") instead of the built-in one.
HudIcons.Tiles = {
	Store = { order = 1, label = "Shop", accent = Color3.fromHex("#F2B51F"), uiIcon = "shopping-cart", image = "" }, -- only while something is for sale
	Stats = { order = 2, label = "Stats", accent = Color3.fromHex("#E2574C"), uiIcon = "dumbbell", image = "" },   -- the stats labels around you (prompt 39b: the dumbbell)
	Muscles = { order = 3, label = "Muscles", accent = Color3.fromHex("#F0922E"), uiIcon = "biceps-flexed", image = "" }, -- (prompt 39b mockup: a flexed arm)
	-- (owner, 14 Oct: the Titles tile became INVENTORY: titles, auras and items; the owner's backpack line icon)
	Inventory = { order = 4, label = "Inventory", accent = Color3.fromHex("#E8C21C"), uiIcon = "backpack", image = "" },
	Genetics = { order = 5, label = "Genetics", accent = Color3.fromHex("#3FB8AF"), icon = "DNA", image = "" },
	Emotes = { order = 6, label = "Poses", accent = Color3.fromHex("#E96BA8"), icon = "Flex", image = "" },        -- poses + emotes panel (prompt 39b: the flexing stick figure, was STATS')
	Crew = { order = 7, label = "Crew", accent = Color3.fromHex("#4C8DE0"), icon = "People", image = "" },
	-- (Quests: no tile, owner 14 Oct: one entry point, the QUESTS icon on the top bar)
	-- (prompt 19) PUMP SHOP: shown once the shop has opened; a tap takes you to its entrance
	PumpShop = { order = 8, label = "Pump Shop", accent = Color3.fromHex("#C98A12"), uiIcon = "dumbbell", image = "" },
	Trainers = { order = 9, label = "Trainers", accent = Color3.fromHex("#D9823B"), icon = "Clipboard", image = "" }, -- personal trainers
	Wardrobe = { order = 10, label = "Wardrobe", accent = Color3.fromHex("#9B6BDF"), icon = "Hanger", image = "" }, -- hidden: Config/Features.Wardrobe
}
HudIcons.DefaultAccent = Color3.fromHex("#8A8F98")

-- Muscle group colors (the machine signs, the EXP popups' icon chips): one color per group, the tiles' palette.
HudIcons.MuscleGroups = {
	Chest = { accent = Color3.fromHex("#E2574C") },
	Shoulders = { accent = Color3.fromHex("#F0922E") },
	Back = { accent = Color3.fromHex("#4C8DE0") },
	Arms = { accent = Color3.fromHex("#9B6BDF") },
	Legs = { accent = Color3.fromHex("#5BBE5B") },
	Core = { accent = Color3.fromHex("#E8C21C") },
}

HudIcons.Pills = {
	Coins = { icon = "Plate", image = "" },
	Quests = { icon = "Quest", image = "" },
	Daily = { icon = "Gift", image = "" },
	Settings = { icon = "Gear", image = "" },
}

return HudIcons
