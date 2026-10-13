-- Every HUD icon and tile color in one place (the left tile grid and the top-bar pills).
--   accent  the tile's border / 3D color
--   icon    the built-in white line icon (Shared.UI.Icons) used until you give an image
--   image   YOUR OWN icon: put an "rbxassetid://<id>" here and that tile/pill uses it instead of the built-in icon
-- Leave `image` empty to keep the built-in icons. The built-in icons are simple white glyphs built from UI shapes, so
-- these are the ones to replace with your own art later: Stats, Muscles, Titles, Genetics, Wardrobe, Poses, Crew,
-- Quests, Store (tiles) and Coins, Quests, Daily, Settings (pills).
local HudIcons = {}

-- The menu tiles (owner's UI redesign, mockup 01): order (mockup first: Shop, Quests, Muscles, Trainers, Titles,
-- Emotes, Crew, Settings; then the extra ones), label, uiIcon (Config/UI.Icons), gold = the highlighted gold tile.
-- image = YOUR OWN icon ("rbxassetid://<id>") instead of uiIcon.
HudIcons.Tiles = {
	Store = { order = 1, label = "Shop", uiIcon = "shopping-cart", gold = true, image = "" }, -- hidden while monetization is OFF
	Quests = { order = 2, label = "Quests", uiIcon = "list-checks", image = "" },          -- daily quests (DailyClient)
	Muscles = { order = 3, label = "Muscles", uiIcon = "biceps-flexed", image = "" },
	Trainers = { order = 4, label = "Trainers", uiIcon = "clipboard-list", image = "" },
	Titles = { order = 5, label = "Titles", uiIcon = "medal", image = "" },
	Emotes = { order = 6, label = "Emotes", uiIcon = "smile", image = "" },
	Crew = { order = 7, label = "Crew", uiIcon = "users", image = "" },
	Settings = { order = 8, label = "Settings", uiIcon = "settings", image = "" },
	Stats = { order = 9, label = "Stats", uiIcon = "eye", image = "" },                   -- the stats labels around you
	Wardrobe = { order = 10, label = "Wardrobe", uiIcon = "sparkles", image = "" },
	Genetics = { order = 11, label = "Genetics", uiIcon = "star", image = "" },
	Coach = { order = 12, label = "Coach", uiIcon = "bell", image = "" },                  -- Coach Dex's quest (QuestClient)
	Daily = { order = 13, label = "Daily", uiIcon = "calendar-days", image = "" },         -- the login streak (DailyClient)
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
