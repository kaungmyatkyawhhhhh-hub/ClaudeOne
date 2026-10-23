-- Style (prompt 61, owner 23 Oct): coin sinks that are cosmetic only (no stats). Each is bought ONCE and kept forever, at a
-- fixed price (not scaled by stage: real long goals). Sold in the PUMP SHOP's STYLE tab (PumpShopService), worn from there
-- and from the Inventory (StyleService). Saved in data.style = { owned = { [item id] = true }, name, title,
-- aura = { [aura id] = colour }, alter = { [alter id] = tint } }.
--   NAME TAGS    "Name_<colour>": your name over your head in that colour (a gradient: two colours)
--   TITLES       "Title_<colour>": your title's words in that colour
--   AURAS        "Aura_<aura id>_<colour>": an aura you own in another colour (the same effect; every colour of it turned
--                to that hue). OFF SALE (owner, 23 Oct): owners keep theirs (a swatch in its Inventory detail panel).
--   ALTERS       "Alter_<alter id>_<tint>": a Body Alter you reached with its skin tinted. OFF SALE like the aura colours.
-- (owner, 23 Oct) The STYLE tab sells 15: 8 name tag colours and 7 title colours (Style.Colors: sellName / sellTitle = on sale
-- there). Every other colour is off sale: owners keep it and still see it in the tab to wear it.
-- TRAINER SNACKS (consumable, sold at the Trainer Agency, fed from MY TRAINERS): trainer EXP. Their price DOES scale with your
-- stage (minutes of coins, Config/Economy.Minutes); a snack never skips an evolution (levels stop at the max level).
local Style = {}

-- the name tag and title colours (in the tab's order). sellName / sellTitle = on sale as a NAME TAG / TITLE COLOUR (owner, 23 Oct:
-- 5 solid 10,000-20,000 + gradients 60,000-100,000); the rest are off sale (owners keep them). A gradient = 2+ colours.
Style.Colors = {
	{ id = "Violet", name = "Violet", colors = { "#A45BFF" }, price = 10000, sellName = true, sellTitle = true },
	{ id = "Ice", name = "Ice", colors = { "#7FE8FF" }, price = 12500, sellName = true, sellTitle = true },
	{ id = "Fire", name = "Fire", colors = { "#FF4A1F" }, price = 15000, sellName = true, sellTitle = true },
	{ id = "Mint", name = "Mint", colors = { "#5BF0A8" }, price = 17500, sellName = true, sellTitle = true },
	{ id = "Gold", name = "Gold", colors = { "#F6C75A" }, price = 20000, sellName = true, sellTitle = true },
	{ id = "Sunset", name = "Sunset", colors = { "#FF5F6D", "#FFC371" }, price = 60000, sellName = true, sellTitle = true },
	{ id = "Galaxy", name = "Galaxy", colors = { "#5B6CFF", "#C04BFF", "#FF6FD8" }, price = 80000, sellName = true, sellTitle = true },
	{ id = "Rainbow", name = "Rainbow", colors = { "#FF4A4A", "#FFB23F", "#FFF05A", "#5BE36B", "#3F8CFF", "#A45BFF" }, price = 100000, sellName = true },
	-- off sale (prompt 61's first list; owners keep them)
	{ id = "Crimson", name = "Crimson", colors = { "#E8343C" }, price = 5000 },
	{ id = "Ocean", name = "Ocean", colors = { "#3F8CFF" }, price = 5000 },
	{ id = "Lime", name = "Lime", colors = { "#5BE36B" }, price = 7500 },
	{ id = "Tangerine", name = "Tangerine", colors = { "#FF8A2B" }, price = 7500 },
	{ id = "Bubblegum", name = "Bubblegum", colors = { "#FF5FB4" }, price = 10000 },
	{ id = "Aurora", name = "Aurora", colors = { "#3FF2C8", "#7A5BFF" }, price = 80000 },
	{ id = "Candy", name = "Candy", colors = { "#FF5FB4", "#7FE8FF" }, price = 100000 },
	{ id = "Royal", name = "Royal", colors = { "#F6C75A", "#A45BFF" }, price = 120000 },
}
Style.TitlePriceScale = 1 -- a title colour costs this times the name tag colour

-- aura colours: a hue (0..1) every colour of the effect is turned to
Style.AuraHues = {
	Blue = { hue = 0.6, color = "#3F8CFF" }, Purple = { hue = 0.78, color = "#A45BFF" }, Green = { hue = 0.33, color = "#5BE36B" },
	Red = { hue = 0.0, color = "#E8343C" }, Gold = { hue = 0.12, color = "#F6C75A" }, Pink = { hue = 0.9, color = "#FF5FB4" },
	Teal = { hue = 0.5, color = "#3FD8D0" },
}
-- each aura's two colours (far from its own; OFF SALE since 23 Oct, owners keep them); an aura not listed takes the ones
-- of its effect (vfx)
Style.AuraVariants = {
	ember = { "Blue", "Purple" }, frost = { "Gold", "Pink" }, storm = { "Red", "Green" }, golden = { "Teal", "Purple" },
	titan = { "Blue", "Green" }, inferno = { "Blue", "Purple" }, blood_moon = { "Teal", "Purple" }, void = { "Green", "Red" },
	neon = { "Gold", "Green" }, galaxy = { "Red", "Gold" }, royal = { "Teal", "Pink" }, toxic = { "Purple", "Red" }, shadow = { "Blue", "Red" },
}
Style.AuraVariantPrices = { 25000, 50000 }

-- alter tints (OFF SALE since 23 Oct, owners keep them): the skin's colour leans this far toward the tint
-- (Style.AlterTintStrength)
Style.AlterTints = {
	Crimson = "#B3262D", Rose = "#E86FA3", Ocean = "#3F6FD8", Jade = "#2FAE7A", Gold = "#D9A82E", Violet = "#7A3FC8",
}
Style.AlterVariants = {
	Pumped = { "Crimson", "Rose" }, Shredded = { "Ocean", "Jade" }, Tanned = { "Gold", "Crimson" }, Vascular = { "Violet", "Jade" },
	Peak = { "Gold", "Ocean" },
}
Style.AlterVariantPrices = { 40000, 80000 }
Style.AlterTintStrength = 0.35

-- trainer snacks: price = minutes of coins at your stage; xp = trainer EXP for the trainer you feed (Small = about one level
-- at the low levels: Trainers.LevelXp(1, 1) = 120)
Style.Snacks = {
	{ id = "Small", name = "Small Snack", minutes = 3, xp = 120, color = "#5BE36B" },
	{ id = "Medium", name = "Medium Snack", minutes = 10, xp = 400, color = "#3F8CFF" },
	{ id = "Large", name = "Large Snack", minutes = 30, xp = 1200, color = "#A45BFF" },
}

------------------------------------------------------------------------
Style.ColorById = {}
for _, entry in ipairs(Style.Colors) do Style.ColorById[entry.id] = entry end
Style.SnackById = {}
for _, snack in ipairs(Style.Snacks) do Style.SnackById[snack.id] = snack end

function Style.SnackPrice(snack, spurts: number?): number
	return require(script.Parent.Economy).Minutes(spurts, snack.minutes)
end

-- an aura's two colours (its own list, else its effect's)
function Style.AuraColors(aura): { string }
	if not aura then return {} end
	return Style.AuraVariants[aura.id] or Style.AuraVariants[aura.vfx] or { "Blue", "Purple" }
end

-- Every style item, as { id, kind, name, price, colors?, aura?, alter?, variant, onSale }. owned = { [id] = true }: the off
-- sale ones you own are listed too (to wear them); nil = only what's on sale. Aura / alter colours are only for the auras /
-- alters in the lists given (the ones the player has) and are never on sale (owner, 23 Oct).
function Style.Items(auras: { any }?, alters: { any }?, owned: { [string]: boolean }?): { any }
	local list = {}
	local function keep(id, onSale) return onSale or (owned ~= nil and owned[id] == true) end
	for _, entry in ipairs(Style.Colors) do
		local id = "Name_" .. entry.id
		if keep(id, entry.sellName) then
			table.insert(list, { id = id, kind = "Name", name = entry.name, price = entry.price, colors = entry.colors, variant = entry.id, onSale = entry.sellName == true })
		end
	end
	for _, entry in ipairs(Style.Colors) do
		local id = "Title_" .. entry.id
		if keep(id, entry.sellTitle) then
			table.insert(list, { id = id, kind = "Title", name = entry.name, price = math.floor(entry.price * Style.TitlePriceScale), colors = entry.colors,
				variant = entry.id, onSale = entry.sellTitle == true })
		end
	end
	if not owned then return list end
	for _, aura in ipairs(auras or {}) do
		for i, hue in ipairs(Style.AuraColors(aura)) do
			local info = Style.AuraHues[hue]
			if info then
				local id = "Aura_" .. aura.id .. "_" .. hue
				if owned[id] then table.insert(list, { id = id, kind = "Aura", name = hue .. " " .. aura.name, price = Style.AuraVariantPrices[i],
					colors = { info.color }, aura = aura, variant = hue, onSale = false }) end
			end
		end
	end
	for _, alter in ipairs(alters or {}) do
		for i, tint in ipairs(Style.AlterVariants[alter.id] or {}) do
			local id = "Alter_" .. alter.id .. "_" .. tint
			if owned[id] then table.insert(list, { id = id, kind = "Alter", name = tint .. " " .. alter.name, price = Style.AlterVariantPrices[i],
				colors = { Style.AlterTints[tint] }, alter = alter, variant = tint, onSale = false }) end
		end
	end
	return list
end

-- An item id -> { kind, variant, aura id?, alter id? } (nil = not a style item)
function Style.Parse(id: any)
	if type(id) ~= "string" then return nil end
	local kind, rest = string.match(id, "^(%a+)_(.+)$")
	if kind == "Name" or kind == "Title" then
		return if Style.ColorById[rest] then { kind = kind, variant = rest } else nil
	elseif kind == "Aura" or kind == "Alter" then
		local target, variant = string.match(rest, "^(.+)_(%a+)$")
		if not target then return nil end
		return { kind = kind, variant = variant, target = target }
	end
	return nil
end

-- "#hex" or "#hex1,#hex2": what goes on the NameColor / TitleColor attributes
function Style.ColorValue(colorId: string?): string?
	local entry = colorId and Style.ColorById[colorId]
	return entry and table.concat(entry.colors, ",") or nil
end

-- { Color3, ... } -> a ColorSequence through all of them (a gradient of 2+ colours)
function Style.Sequence(colors: { Color3 }): ColorSequence
	if #colors < 2 then return ColorSequence.new(colors[1] or Color3.new(1, 1, 1)) end
	local points = {}
	for i, color in ipairs(colors) do table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color)) end
	return ColorSequence.new(points)
end

-- (clients) a NameColor / TitleColor value -> { Color3, ... }
function Style.Decode(value: any): { Color3 }?
	if type(value) ~= "string" or value == "" then return nil end
	local out = {}
	for hex in string.gmatch(value, "[^,]+") do
		local ok, color = pcall(Color3.fromHex, hex)
		if ok then table.insert(out, color) end
	end
	return if #out > 0 then out else nil
end

return Style
