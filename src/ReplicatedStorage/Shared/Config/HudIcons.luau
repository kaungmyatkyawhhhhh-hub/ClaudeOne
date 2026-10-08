-- Every HUD icon and tile color in one place (the left tile grid and the top-bar pills).
--   accent  the tile's border / 3D color
--   icon    the built-in white line icon (Shared.UI.Icons) used until you give an image
--   image   YOUR OWN icon: put an "rbxassetid://<id>" here and that tile/pill uses it instead of the built-in icon
-- Leave `image` empty to keep the built-in icons. The built-in icons are simple white glyphs built from UI shapes, so
-- these are the ones to replace with your own art later: Stats, Muscles, Titles, Genetics, Wardrobe, Poses, Crew,
-- Store (tiles) and Coins, Quests, Daily, Settings (pills).
local HudIcons = {}

HudIcons.Tiles = {
	Stats = { accent = Color3.fromHex("#E2574C"), icon = "Flex", image = "" },
	Muscles = { accent = Color3.fromHex("#F0922E"), icon = "Stats", image = "" },
	Titles = { accent = Color3.fromHex("#E8C21C"), icon = "Trophy", image = "" },
	Genetics = { accent = Color3.fromHex("#3FB8AF"), icon = "DNA", image = "" },
	Wardrobe = { accent = Color3.fromHex("#9B6BDF"), icon = "Hanger", image = "" },
	Emotes = { accent = Color3.fromHex("#E96BA8"), icon = "Pose", image = "" },
	Crew = { accent = Color3.fromHex("#4C8DE0"), icon = "People", image = "" },
	Store = { accent = Color3.fromHex("#5BBE5B"), icon = "Plate", image = "" }, -- hidden while monetization is OFF
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
