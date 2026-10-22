-- PumpShopClient (owner, prompt 19, 21 Oct): the shop window and its HUD bits (PumpShopService sells; numbers in
-- Config.PumpShop). Coins only.
-- (prompt 31, 22 Oct) ONE window for the three shops (Config.PumpShop.Shops): Coach Dex (normal supplements, Basic / Pro
-- gear, ALTERS), the PUMP SHOP (specials, Elite / Champion gear, DNA LAB) and the coconut stand (Coconut Water x1 / x5).
-- (prompt 47) The window is a row of Store-style tiles + a detail strip (see "The window" below).
-- The title and tabs follow the shop that opened it; tabs are always SUPPLEMENTS / GEAR (+ ALTERS / DNA LAB). Apparel
-- is off sale (no try-on any more).
--   * The window (a counter's "Shop" prompt opens it on that section; every section has a tab): on the left the picked
--     item big (art, name, what it does, price, buttons), on the right the section's tiles.
--       SUPPLEMENTS  the boosts (Config.Boosts): BUY x1 / x5 / x10 (into the inventory)
--       GEAR         belt, wraps, straps, sleeves: Basic -> Pro -> Elite, what each helps, BUY the next level
--       APPAREL      shorts and tank top colors, headbands, shakers, gym bags: TRY ON (a few seconds) and BUY
--       DNA LAB      a DNA token (this week's price: +10% for each one bought this week) and "Reroll genetics"
--     Gear and Apparel show a lock until Growth Spurt 2.
--   * Going there (10 s cooldown): the Shop window's "Go to PUMP SHOP" link (UIBus.GoPumpShop; prompt 28: it was a tile in
--     the left menu, the menu keeps 8 buttons).
--   * "You can afford: Pro Lifting Belt!": a small gold note once a newly affordable thing appears (at most every 5 min);
--     tapping it goes to the shop.
-- (prompts 57 / 59 / 60, 23 Oct)
--   * Robux items (Config.Monetization products; an item whose product isn't set up yet is hidden): Coach Dex's
--     SUPPLEMENTS end with SHAKE BUNDLE, DNA TOKEN and DNA TOKEN x3; the PUMP SHOP's DNA LAB shows the coin DNA token next to
--     the two Robux ones (the DNA token picture on all). Their price button has the Robux icon; BUY opens Roblox's purchase
--     prompt (ProcessReceipt gives the item on the server). DNA x3 shows "SAVE n%" only when it really is cheaper per token.
--   * The PUMP SHOP's specials (Mass Gainer, Elite Pre-Workout, Whey Isolate, BCAA) cost Robux: x1 and x5 (no coin price);
--     a product not set up yet shows SOON. You can't buy past the carry limit (MAX).
--   * GEAR (prompt 59, Coach Dex only): two rows, LIFTING BELT (lower body) and WRIST WRAPS (upper body), each with its
--     BASIC and PRO tiles side by side (the gear pictures, the boost, the price or OWNED). Only the level right above your
--     best can be bought. The one-time "Gear got simpler!" note after the gear migration (PlayerEvent GearSimpler).
--   * (prompt 61) STYLE (PUMP SHOP): name tag and title colours, colours for the auras you own, tints for the alters you
--     reached (Config/Style; fixed coin prices, bought once). The strip previews it (your name in the colour), TRY shows an
--     aura colour / alter tint on you for a few seconds, then BUY; owned: WEAR / TAKE OFF (StyleService).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PumpShop = require(Shared.Config.PumpShop)
local Boosts = require(Shared.Config.Boosts)
local Body = require(Shared.Config.Body)
local Cosmetics = require(Shared.Config.Cosmetics)
local DNA = require(Shared.Config.DNA)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local Alters = require(Shared.Config.Alters)
local AlterThemes = require(Shared.Config.AlterThemes)
local Muscles = require(Shared.Config.Muscles)
local Machines = require(Shared.Config.Machines)
local Monetization = require(Shared.Config.Monetization)
local Style = require(Shared.Config.Style)
local Auras = require(Shared.Config.Auras)
local UIConfig = require(Shared.Config.UI)
local ShopPrices = require(Shared.ShopPrices)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local AlterFX = require(Shared.VFX.AlterFX)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("PumpShop", 60) :: RemoteEvent
if not remote then return end

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 770, 290 -- (wide enough for the title, the tabs and the coins pill; prompt 47: taller for the tile row + detail strip)
local shopId = "Pump" -- the shop the window shows (PumpShop.Shops)
local function shop() return PumpShop.Shops[shopId] or PumpShop.Shops.Pump end

------------------------------------------------------------------------
-- What's on sale
------------------------------------------------------------------------
local function data() return ClientData.Get() or {} end
local function spurts() return data().growthSpurts or 0 end
local function coins() return data().coins or 0 end
local function owned() return (data().cosmetics or {}).owned or {} end
local function sectionOpen(id: string): boolean
	local open = player:GetAttribute("PumpShop")
	if not open then return false end
	for _, section in ipairs(PumpShop.Sections) do
		if section.id == id then
			if section.atMax then return GrowthSpurts.IsMaxed(spurts()) end
			return spurts() >= (section.fromSpurt or 0)
		end
	end
	return false
end

-- one tile = { key, section, name, sub, icon, color, price(), state() }
local function bodyEntry(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then return entry end
	end
	return nil
end

local entries = { Supplements = {}, Gear = {}, DnaLab = {}, Alters = {}, Style = {} }

-- (prompt 21) ALTERS: the alters of the tier you're in (the next one picked first), each with its state; nothing is sold
local function alterProgress()
	local d = data()
	return Alters.Progress(d, Muscles.Groups, Machines.TrainableMuscles(d.growthSpurts or 0))
end
local function alterEntries()
	local progress = alterProgress()
	local tier = math.max(1, Alters.TierOf(math.min(progress.next, #Alters.List)))
	local list = {}
	for _, alter in ipairs(Alters.List) do
		if alter.tier == tier then
			table.insert(list, { key = alter.id, section = "Alters", alter = alter, name = alter.name, icon = "flame",
				color = AlterThemes.Get(alter.number).accent, price = function() return nil end })
		end
	end
	return list, progress
end
local function alterStatus(entry, progress): (string, Color3)
	local n = entry.alter.number
	if n < progress.next then return "DONE", Colors.Green end
	if not entry.alter.textures or n > Alters.LastAvailable() then return "SOON", Colors.Muted end
	if n == progress.next then
		if progress.ready then return "READY", Colors.Gold end
		local have, need = 0, 0
		for _, group in ipairs(Muscles.Groups) do
			have += Muscles.Shown(math.min(progress.groups[group.id] or 0, progress.required))
			need += Muscles.Shown(progress.required)
		end
		return math.floor(need > 0 and have / need * 100 or 0) .. "%", Colors.Teal
	end
	return "ALTER " .. n, Colors.Muted
end
-- (prompt 57) a shop picture of Config/UI.ShopIcons
local DNA_ART = UIConfig.ShopIcons.product_dna_token
local function productArt(product): string?
	return product and product.art and UIConfig.ShopIcons[product.art] or nil
end
-- the PUMP SHOP's specials: their Robux products by count ({ [1] = product, [5] = product })
local function robuxPacks(id: string)
	if not PumpShop.RobuxSupplements[id] then return nil end
	return { [1] = Monetization.ProductByKey["Supp_" .. id .. "_1"], [5] = Monetization.ProductByKey["Supp_" .. id .. "_5"] }
end
for _, supplement in ipairs(PumpShop.Supplements) do
	local item = Boosts.ById[supplement.id]
	table.insert(entries.Supplements, { key = item.id, section = "Supplements", name = item.name, sub = item.text .. " Lasts " .. item.duration .. ".",
		icon = item.icon, color = Color3.fromHex(item.color), packs = robuxPacks(item.id),
		price = function() return PumpShop.SupplementPrice(item.id, spurts()) end })
end
-- (prompt 59) gear: a tile per piece and level Coach Dex sells (BASIC / PRO)
for _, gear in ipairs(PumpShop.Gear) do
	for _, level in ipairs(PumpShop.GearLevels) do
		if not level.offSale then
			local itemId = PumpShop.GearItemId(gear.id, level.id)
			table.insert(entries.Gear, { key = itemId, section = "Gear", gear = gear, level = level, name = level.name .. " " .. gear.short,
				icon = PumpShop.GearIcons[itemId] or "dumbbell", color = Color3.fromHex(level.color),
				sub = PumpShop.GearBoostText(gear, level) .. " EXP." })
		end
	end
end
-- (prompt 61) STYLE: every item for the auras you have and the alters you reached
local STYLE_KIND = { Name = "NAME TAG", Title = "TITLE", Aura = "AURA", Alter = "ALTER" }
local STYLE_ICON = { Name = "sparkles", Title = "medal", Alter = "biceps-flexed" }
local function styleState()
	local state = data().style
	return type(state) == "table" and state or {}
end
local function styleEntries()
	local d = data()
	local auras = {}
	for _, aura in ipairs(Auras.List) do
		local has = if aura.unlock.type == "pass" then player:GetAttribute("Pass_" .. aura.unlock.pass) == true
			else type(d.auras) == "table" and type(d.auras.owned) == "table" and d.auras.owned[aura.id] ~= nil
		if has then table.insert(auras, aura) end
	end
	local alters = {}
	for n = 1, Alters.State(d).highest or 0 do
		local alter = Alters.Get(n)
		if alter then table.insert(alters, alter) end
	end
	local list = {}
	for _, item in ipairs(Style.Items(auras, alters)) do
		table.insert(list, { key = item.id, id = item.id, section = "Style", style = item, name = item.name, color = Color3.fromHex(item.colors[1]),
			icon = if item.aura then (item.aura.Icon or "sparkles") else STYLE_ICON[item.kind], price = function() return item.price end })
	end
	return list
end
-- is it the one worn (its kind / target)?
local function styleWorn(item): boolean
	local state = styleState()
	if item.kind == "Name" then return state.name == item.variant end
	if item.kind == "Title" then return state.title == item.variant end
	if item.kind == "Aura" then return type(state.aura) == "table" and state.aura[item.aura.id] == item.variant end
	if item.kind == "Alter" then return type(state.alter) == "table" and state.alter[item.alter.id] == item.variant end
	return false
end
local tryToken = 0
local function tryStyle(item)
	tryToken += 1
	local mine = tryToken
	if item.kind == "Aura" then
		player:SetAttribute("AuraPreview", item.aura.vfx .. "@" .. item.variant)
	elseif item.kind == "Alter" then
		player:SetAttribute("AlterTintPreview", Color3.fromHex(Style.AlterTints[item.variant]))
	end
	task.delay(10, function()
		if tryToken ~= mine then return end
		player:SetAttribute("AuraPreview", nil)
		player:SetAttribute("AlterTintPreview", nil)
	end)
end

table.insert(entries.DnaLab, { key = "DnaToken", section = "DnaLab", name = "DNA Token", icon = DNA_ART, color = Colors.Gold,
	sub = DNA.TokenLine or "One genetics reroll.", price = function() return PumpShop.DnaPriceFor(data(), DNA.CoinPrice) end })

-- (prompts 57 / 60) a Robux product as a tile (nil while its product isn't set up: hidden)
local ROBUX_COLORS = { ShakePack = "#2F8FE8", DnaToken = "#36C2C2", DnaTokenPack = "#8E5CF0" }
local robuxEntries = {}
local function robuxEntry(key: string, section: string)
	local product = Monetization.ProductByKey[key]
	if not product or not product.id then return nil end
	robuxEntries[key] = robuxEntries[key] or { key = "R_" .. key, section = section, product = product, name = product.name,
		sub = if key == "DnaToken" or key == "DnaTokenPack" then (DNA.TokenLine or product.text) else product.text,
		icon = productArt(product) or "sparkles", color = Color3.fromHex(ROBUX_COLORS[key] or "#36C2C2") }
	return robuxEntries[key]
end

-- a product's Robux price: Roblox's (fetched once, ShopPrices), else Config's
local refresh -- (the window's, below)
local fetching = {}
local function robuxPrice(product): number?
	if not product then return nil end
	if product.id and not fetching[product.key] then
		fetching[product.key] = true
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.id, Enum.InfoType.Product)
			if ok and info and type(info.PriceInRobux) == "number" then
				ShopPrices.Set(product.key, info.PriceInRobux)
				if refresh then refresh() end
			end
		end)
	end
	return ShopPrices.Get(product)
end

-- gear: the best level of a piece you own (nil = none)
local function gearBest(gear)
	return PumpShop.GearBest(owned(), gear.id)
end

local function isOwned(entry): boolean
	if entry.section == "Style" then
		local owned_ = styleState().owned
		return type(owned_) == "table" and owned_[entry.key] == true
	end
	if entry.section == "Gear" then
		local best = gearBest(entry.gear)
		return best ~= nil and best.index >= entry.level.index
	end
	return false
end

local function priceOf(entry): number?
	if entry.section == "Gear" then return entry.level.price end
	if entry.product or entry.packs then return nil end -- (Robux: robuxPrice)
	return entry.price and entry.price()
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local tab = "Supplements"
local picked = {} -- [section] = entry key
local openOn -- (below)
local tileColor -- (below)
local tabs = {}
for _, section in ipairs(PumpShop.Sections) do table.insert(tabs, { id = section.id, text = section.name, icon = section.icon }) end
local modal = Kit.Modal({ name = "PumpShop", title = "Pump Shop", icon = "dumbbell", width = W, height = H, displayOrder = 25, tabs = tabs, coins = true,
	onTab = function(id)
		tab = id
		refresh()
	end })
-- (prompt 31) only the shop's own tabs show
local tabRow = modal.panel:FindFirstChild("Tabs", true)
local function showShopTabs()
	for _, section in ipairs(PumpShop.Sections) do
		local button = tabRow and tabRow:FindFirstChild(section.id)
		if button then button.Visible = table.find(shop().tabs, section.id) ~= nil end
	end
	modal.setTitle(shop().title)
end

-- (prompt 47, 22 Oct) A row of item tiles and a detail strip at the bottom for the picked one (its buttons: BUY x1 / x5
-- for supplements, the next gear level, DNA: BUY TOKEN / REROLL). Buying: the coins count down, the item flies to the
-- Inventory button.
-- (owner, 23 Oct) Restyled like the Alters / Auras detail panels (premium, not chunky; Coach Dex's shop is this window):
--   * a tile: a soft background in the item's colour filling it, faint rings behind the icon, a dark gradient at the
--     bottom for the words, a thin outline in its colour (picked: gold, with the soft glow, Shared/UI/ReadyGlow); the icon
--     centred on a glow; the name white and stroked (one line, it shrinks to fit); the effect in a slim dark pill outlined
--     in its colour ("+50% EXP · 15 MIN"; long ones shortened, "2x STAMINA REGEN"); the price on a slim graphite button with
--     a coin ("3,950"; can't afford: the price red and "NEED 1,200 MORE" under it; owned gear: a gold OWNED).
--   * the strip: the picked item's background, its icon on a glow, the name white and stroked, one light gray line, and
--     slim graphite buttons with a thin gold outline, a coin and the price ("x1", "x5"; a small BEST tag on x5 only when
--     it's cheaper per item).
local STRIP_H = 64
local TILE_W, TILE_H = 132, 146
local TILE_GLOW = 8 -- (the picked tile's glow reaches this far: the row leaves room for it)
-- (prompt 61: the premium pieces live in Shared/UI/PremiumKit, shared with the Store)
local PremiumKit = require(Shared.UI.PremiumKit)
local PILL_DARK = PremiumKit.PILL_DARK
local ReadyGlow = require(Shared.UI.ReadyGlow)
local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -(STRIP_H + 4)),
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.X, Parent = modal.body }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center }),
	New("UIPadding", { PaddingLeft = UDim.new(0, TILE_GLOW), PaddingRight = UDim.new(0, TILE_GLOW), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
})
local lockNote = Kit.Text({ Name = "Locked", Text = "", Font = "Chunky", TextSize = 18, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(0.8, 0, 0, 60), Visible = false, Parent = modal.body })

local themedBackground = PremiumKit.ThemedBackground
local slimButton = PremiumKit.SlimButton

-- the detail strip: the picked item's background behind it
local strip = New("Frame", { Name = "Detail", BackgroundColor3 = Color3.fromHex("#141317"), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, STRIP_H), Parent = modal.body }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Name = "Edge", Color = Colors.Gold, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local paintStrip = themedBackground(strip, 12, UDim2.fromOffset(34, STRIP_H / 2), { 70, 120 })
local stripGlow = AlterFX.Image(strip, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(34, STRIP_H / 2), Size = UDim2.fromOffset(80, 80),
	ImageTransparency = 0.45, ZIndex = 2 })
local stripIcon = New("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(48, 48), ZIndex = 3, Parent = strip })
local stripName = Kit.Text({ Name = "Name", Text = "", Font = "Chunky", TextSize = 18, Position = UDim2.fromOffset(68, 8), Size = UDim2.new(1, -340, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = strip })
Kit.Fit(stripName, 18, 11)
local stripLine = Kit.Text({ Name = "Line", Text = "", Font = "Strong", TextSize = 12, TextColor3 = Color3.fromHex("#C9C5CF"), TextWrapped = true, Position = UDim2.fromOffset(68, 30),
	Size = UDim2.new(1, -340, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3, Parent = strip })
Kit.Fit(stripLine, 12, 9, 2)
local buttonRow = New("Frame", { Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(330, 48), ZIndex = 3, Parent = strip }, { Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })

local function clearButtons()
	for _, child in ipairs(buttonRow:GetChildren()) do
		if child:IsA("GuiButton") then child:Destroy() end
	end
end
-- style: "Green" (a buy you can afford: gold outline), "Disabled" (can't afford: the price red), "Gold" (gold outline,
-- gold words), "Quiet" (gray outline); price = coins shown with a coin (nil = words only); best = the small BEST tag
-- (prompt 57) currency = "robux": the Robux icon on the price; best = true ("BEST") or the tag's own words ("SAVE 16%")
local function addButton(style, text, width, onTap, order, price, best, currency)
	local look = if style == "Green" then "buy" elseif style == "Disabled" then (if price then "need" else "off") elseif style == "Gold" then "owned" else "plain"
	local button = slimButton(buttonRow, { Name = "Buy" .. (order or 1), LayoutOrder = order or 1, Size = UDim2.fromOffset(width, 40), ZIndex = 4 }, text, price, look, 15, currency)
	if best then
		local words = if type(best) == "string" then best else "BEST"
		local tag = New("Frame", { Name = "Best", BackgroundColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 4, 0, 0),
			Size = UDim2.fromOffset(if #words > 4 then 64 else 38, 14), ZIndex = 8, Parent = button }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Kit.Text({ Name = "Text", Text = words, Font = "Chunky", TextSize = 10, TextColor3 = Colors.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = tag })
	end
	button.Activated:Connect(function()
		if style == "Disabled" then return end
		Audio.PlayUI("Click")
		onTap(button)
	end)
	return button
end

local function iconOf(entry): string
	local item = Boosts.ById[entry.key]
	return if item then item.icon else entry.icon
end
local function setIcon(holder: GuiObject, entry)
	holder:ClearAllChildren()
	local icon = iconOf(entry)
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		New("ImageLabel", { BackgroundTransparency = 1, Image = icon, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Parent = holder })
	else
		Kit.IconTile(icon, tileColor(entry), math.floor(holder.AbsoluteSize.X > 0 and holder.AbsoluteSize.X or 52), { Size = UDim2.fromScale(1, 1), Parent = holder })
	end
end

-- the effect pill text: "+50% EXP · 15 MIN" (owner, 23 Oct: short enough for the tile: "+100%" -> "2x", and a long effect
-- drops the time, which the strip still says)
local function effectText(entry): string
	if entry.section == "Supplements" and not entry.product then
		local item = Boosts.ById[entry.key]
		local short = string.gsub(item.short or item.text, "^%+100%%", "2x")
		local full = short .. (if item.duration then " · " .. string.upper(item.duration) else "")
		return if #full > 20 then short else full
	elseif entry.section == "Style" then
		return STYLE_KIND[entry.style.kind] or ""
	elseif entry.section == "Gear" then
		return PumpShop.GearBoostText(entry.gear, entry.level)
	elseif entry.product then
		local p = entry.product
		if p.key == "ShakePack" then return Monetization.Effects.ShakePackSize .. " SHAKES" end
		if p.dnaTokens then return p.dnaTokens .. " REROLLS" end
		return "1 REROLL"
	elseif entry.section == "DnaLab" then
		return "1 REROLL"
	end
	return ""
end

-- the item flies from its tile to the Inventory button (after a buy)
local function flyToInventory(entry, from: GuiObject?)
	local target = nil
	local hud = player.PlayerGui:FindFirstChild("MainHud")
	target = hud and hud:FindFirstChild("Inventory", true)
	local gui = Theme.ScreenGui({ Name = "BuyFly", DisplayOrder = 60, Parent = player.PlayerGui })
	gui.IgnoreGuiInset = true
	local start = if from then from.AbsolutePosition + from.AbsoluteSize / 2 else Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
	local goal = if target and target.AbsoluteSize.X > 0 then target.AbsolutePosition + target.AbsoluteSize / 2 else Vector2.new(60, workspace.CurrentCamera.ViewportSize.Y / 2)
	local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(start.X, start.Y + 58), Size = UDim2.fromOffset(56, 56),
		Parent = gui })
	setIcon(holder, entry)
	local TweenService = game:GetService("TweenService")
	TweenService:Create(holder, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(goal.X, goal.Y + 58), Size = UDim2.fromOffset(26, 26) }):Play()
	task.delay(0.6, function()
		gui:Destroy()
		if target then
			local scale = target:FindFirstChild("BuyPop") or New("UIScale", { Name = "BuyPop", Parent = target })
			scale.Scale = 1.2
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
end

-- an item's colour (gear: its next level's, or the one you have)
function tileColor(entry): Color3
	local color = entry.color or Colors.Gold
	if entry.section == "Alters" then
		color = AlterThemes.Get(entry.alter.number).accent
	end
	if color == Color3.fromHex("#2B2B30") then color = Color3.fromHex("#8A8790") end -- (Basic black: readable)
	return color
end

local tilesByKey = {}
local lastBuyTile = nil
local function buy(entry, ...)
	lastBuyTile = tilesByKey[entry.key]
	remote:FireServer("Buy", shopId, ...)
end

-- (prompts 57 / 60) a Robux buy: Roblox's purchase prompt; when Roblox says it went through, the item flies to the
-- Inventory (ProcessReceipt gives it on the server)
local pendingRobux = nil -- { entry, tile, id }
local function promptRobux(entry, product)
	if not product or not product.id then return end
	pendingRobux = { entry = entry, tile = tilesByKey[entry.key], id = product.id }
	MarketplaceService:PromptProductPurchase(player, product.id)
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	local pending = pendingRobux
	if userId ~= player.UserId or not pending or pending.id ~= productId then return end
	pendingRobux = nil
	if purchased then
		Audio.PlayUI("ShopBuy")
		pcall(flyToInventory, pending.entry, pending.tile)
	end
end)

local function showStrip(entry)
	if not entry then
		strip.Visible = false
		return
	end
	strip.Visible = true
	stripLine.RichText = false
	setIcon(stripIcon, entry)
	stripName.Text = string.upper(entry.name)
	local color = tileColor(entry)
	paintStrip(color)
	stripGlow.ImageColor3 = color
	strip.Edge.Color = color
	clearButtons()
	local price = priceOf(entry)
	local afford = price ~= nil and coins() >= price
	if entry.section == "Supplements" and not entry.product then
		local item = Boosts.ById[entry.key]
		local have = (data().items or {})[entry.key] or 0
		stripLine.Text = item.text .. " Lasts " .. item.duration .. ". You have " .. have .. "."
		if entry.packs then
			-- (prompt 57) Robux: x1 and x5 (BEST only when x5 is cheaper per item)
			local single = robuxPrice(entry.packs[1])
			for i, count in ipairs({ 1, 5 }) do
				local product = entry.packs[count]
				local cost = robuxPrice(product)
				if not product or not product.id then
					addButton("Disabled", "x" .. count .. " soon", 128, function() end, i)
				elseif have + count > Boosts.MaxCount then
					addButton("Disabled", "x" .. count .. " max", 128, function() end, i)
				else
					local best = count > 1 and cost ~= nil and single ~= nil and cost / count < single
					addButton("Green", "x" .. count, 128, function() promptRobux(entry, product) end, i, cost, best, "robux")
				end
			end
			return
		end
		for i, quantity in ipairs(shop().quantities or { 1, 5 }) do
			if quantity <= 5 then
				local cost = (price or 0) * quantity
				-- (BEST only when the bigger pack is cheaper per item; today it's the same price each)
				local best = quantity > 1 and cost / quantity < (price or 0)
				addButton(if coins() >= cost then "Green" else "Disabled", "x" .. quantity, 128, function()
					buy(entry, "Supplements", entry.key, quantity)
				end, i, cost, best)
			end
		end
	elseif entry.section == "Gear" then
		-- (prompt 59) the level's boost on its half of the body; the best level you own is the one that counts
		local best = gearBest(entry.gear)
		local level = entry.level
		local groups = string.lower(table.concat(entry.gear.groups, ", "))
		local parts = { string.format("+%d%% EXP on the %s (%s).", math.floor(level.bonus * 100 + 0.5), string.lower(entry.gear.half), groups) }
		if best then table.insert(parts, "You have " .. best.name .. ".") elseif level.index > 1 then table.insert(parts, "Replaces Basic.") end
		stripLine.Text = table.concat(parts, " ")
		if isOwned(entry) then
			addButton("Gold", "Owned", 150, function() end, 1)
		elseif not table.find(shop().gear, level.id) then
			addButton("Quiet", "Go to Coach Dex", 200, function()
				modal.close()
				UIBus.GoCoach:Fire()
			end)
		elseif (best and best.index or 0) + 1 ~= level.index then
			addButton("Disabled", "Buy " .. PumpShop.GearLevels[(best and best.index or 0) + 1].name .. " first", 210, function() end, 1)
		else
			addButton(if afford then "Green" else "Disabled", "Buy " .. level.name, 210, function()
				buy(entry, "Gear", entry.key)
			end, 1, level.price)
		end
	elseif entry.section == "Style" then
		-- (prompt 61) the preview in its colour, TRY (aura / alter), BUY; owned: WEAR / TAKE OFF
		local item = entry.style
		local hex = "#" .. Color3.fromHex(item.colors[1]):ToHex()
		local function painted(text) return '<font color="' .. hex .. '">' .. text .. "</font>" end
		stripLine.RichText = true
		if item.kind == "Name" then
			stripLine.Text = "Your name over your head: " .. painted(player.DisplayName) .. (if #item.colors > 1 then " (a two-colour gradient)" else "")
		elseif item.kind == "Title" then
			stripLine.Text = "Your title's words in " .. painted(item.variant) .. (if #item.colors > 1 then " (a two-colour gradient)" else "") .. "."
		elseif item.kind == "Aura" then
			stripLine.Text = "Your " .. item.aura.name .. " aura in " .. painted(item.variant) .. ". Same effect, new colour."
		else
			stripLine.Text = "Your " .. item.alter.name .. " skin tinted " .. painted(item.variant) .. " (while you wear that alter)."
		end
		local function wearIt(variant)
			Remotes.PlayerAction:FireServer("WearStyle", { kind = item.kind, target = item.aura and item.aura.id or item.alter and item.alter.id, variant = variant })
		end
		if isOwned(entry) then
			if styleWorn(item) then
				addButton("Quiet", "Take off", 150, function() wearIt(nil) end, 1)
			else
				addButton("Gold", "Wear", 150, function() wearIt(item.variant) end, 1)
			end
		else
			if item.kind == "Aura" or item.kind == "Alter" then
				addButton("Quiet", "Try", 100, function() tryStyle(item) end, 1)
			end
			addButton(if afford then "Green" else "Disabled", "Buy", 170, function() buy(entry, "Style", entry.key) end, 2, item.price)
		end
	elseif entry.product then
		-- (prompts 57 / 60) a Robux product: BUY opens Roblox's purchase prompt
		local product = entry.product
		local cost = robuxPrice(product)
		local line = entry.sub
		if product.key == "DnaToken" or product.dnaTokens then line ..= " You have " .. (data().dnaTokens or 0) .. "." end
		if product.key == "ShakePack" then line ..= " You have " .. ((data().items or {}).Shake or 0) .. " shakes." end
		stripLine.Text = line
		local save = nil
		if product.dnaTokens then
			local single = robuxPrice(Monetization.ProductByKey.DnaToken)
			if single and cost and cost / product.dnaTokens < single then
				save = math.floor((1 - cost / (single * product.dnaTokens)) * 100)
			end
		end
		addButton("Green", "Buy", 170, function() promptRobux(entry, product) end, 1, cost, save and save > 0 and ("SAVE " .. save .. "%") or nil, "robux")
	elseif entry.section == "Alters" then
		local progress = alterProgress()
		local status = alterStatus(entry, progress)
		local n = entry.alter.number
		stripName.Text = "ALTER " .. n .. ": " .. string.upper(entry.alter.name)
		if n < progress.next then
			stripLine.Text = "Done. Wear this skin from Inventory > Looks."
		elseif status == "SOON" then
			stripLine.Text = "Coming soon in an update."
		else
			stripLine.Text = string.format("Goal: %s exp in every group. Gains x%.2f after.", Muscles.FormatExpShort(Muscles.Shown(Alters.Goal(n))), Alters.Bonus(n))
		end
		addButton("Quiet", "My skins", 130, function()
			modal.close()
			UIBus.OpenInventory:Fire("Alters")
		end, 1)
		if n == progress.next and progress.ready then
			addButton("Gold", "Alter now", 150, function()
				modal.close()
				UIBus.StartAlter:Fire()
			end, 2)
		end
	elseif entry.section == "DnaLab" then
		local state = data().dnaWeek
		local bought = if type(state) == "table" and state.week == PumpShop.Week() then state.bought or 0 else 0
		stripLine.Text = string.format("One genetics reroll. You have %d. This week: %d bought (+10%% each, resets Monday).", data().dnaTokens or 0, bought)
		addButton("Quiet", "Reroll", 110, function()
			modal.close()
			UIBus.OpenGenetics:Fire()
		end, 1)
		addButton(if afford then "Green" else "Disabled", "Buy", 150, function()
			lastBuyTile = tilesByKey[entry.key]
			Remotes.PlayerAction:FireServer("BuyDnaToken")
		end, 2, price or 0)
	end
end

-- the Champion gear's border: a gold highlight runs round it
local spinning = {}
task.spawn(function()
	while true do
		task.wait(1 / 30)
		if modal.isOpen() then
			for gradient in pairs(spinning) do
				if gradient.Parent then gradient.Rotation = (os.clock() * 90) % 360 else spinning[gradient] = nil end
			end
		end
	end
end)

-- (prompt 54, 23 Oct) the ALTERS tab works like the Inventory's Looks > Alters (Shared/UI/AltersPanel, shop mode): the
-- tiles on the left (the path, bicep icons, ??? undiscovered), the picked one in a detail panel on the right with ALTER
-- NOW / WHAT TO TRAIN / OWNED + MY SKINS. It opens on the next alter.
local AltersPanel = require(Shared.UI.AltersPanel)
local altersPanel = AltersPanel.Build(modal.body, { mode = "shop", columns = 3, onClose = function() modal.close() end })
local altersWasShown = false

-- (prompt 59) GEAR: two rows, LIFTING BELT and WRIST WRAPS: the piece's name and its half of the body on the left, then its
-- BASIC and PRO tiles side by side (picture, name, the boost in a slim pill, the price or OWNED; picked = the gold glow)
local GEAR_LABEL_W, GEAR_TILE_W = 128, 212
local gearRows = New("Frame", { Name = "GearRows", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -(STRIP_H + 4)), Visible = false, Parent = modal.body }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingLeft = UDim.new(0, TILE_GLOW), PaddingRight = UDim.new(0, TILE_GLOW), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
})
local function gearTile(row: Instance, entry, order: number)
	local color = tileColor(entry)
	local isPicked = picked.Gear == entry.key
	local cell = New("Frame", { Name = entry.key, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(0, GEAR_TILE_W, 1, 0), Parent = row })
	local tile = New("TextButton", { Name = "Tile", Text = "", AutoButtonColor = false, BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.85), Size = UDim2.fromScale(1, 1),
		ZIndex = 2, Parent = cell }, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	local border = New("UIStroke", { Name = "Border", Color = if isPicked then Colors.Gold else color, Thickness = if isPicked then 2 else 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tile })
	tilesByKey[entry.key] = tile
	themedBackground(tile, 12, UDim2.new(0, 34, 0.5, 0), { 52, 84 })(color)
	AlterFX.Image(tile, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, 0), Size = UDim2.fromOffset(78, 78),
		ImageColor3 = color, ImageTransparency = 0.45, ZIndex = 2 })
	New("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = entry.icon, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 34, 0.5, 0), Size = UDim2.fromOffset(52, 52), ZIndex = 3, Parent = tile })
	local name = Kit.Text({ Name = "Name", Text = string.upper(entry.name), Font = "Chunky", TextSize = 15, Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -78, 0, 17),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = tile })
	name.TextWrapped = false
	Kit.Fit(name, 15, 9)
	local pill = New("Frame", { Name = "Effect", BackgroundColor3 = PILL_DARK, Position = UDim2.fromOffset(70, 25), Size = UDim2.new(1, -78, 0, 16), ZIndex = 4, Parent = tile }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local effect = Kit.Text({ Name = "Text", Text = effectText(entry), Font = "Chunky", TextSize = 11, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, 0), ZIndex = 5, Parent = pill })
	effect.TextWrapped = false
	Kit.Fit(effect, 11, 7)
	local props = { Name = "Price", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 70, 1, -6), Size = UDim2.new(1, -78, 0, 20), ZIndex = 4 }
	local priceButton
	if isOwned(entry) then
		priceButton = slimButton(tile, props, "Owned", nil, "owned", 12)
	else
		local price = entry.level.price
		priceButton = slimButton(tile, props, nil, price, if coins() >= price then "plain" else "need", 12)
	end
	priceButton.Activated:Connect(function() tile:SetAttribute("Tap", (tile:GetAttribute("Tap") or 0) + 1) end)
	if isPicked then ReadyGlow.New(tile, { stroke = border, pad = TILE_GLOW }):Set(true, Colors.Gold) end
	local scale = New("UIScale", { Name = "PickScale", Scale = if isPicked then 1 else 0.97, Parent = tile })
	local _ = scale
	local function pick()
		picked.Gear = entry.key
		refresh()
		local now = tilesByKey[entry.key]
		if now then Kit.SelectFeedback(now, strip) end
	end
	tile.Activated:Connect(pick)
	tile:GetAttributeChangedSignal("Tap"):Connect(pick)
end
local function renderGear()
	for _, child in ipairs(gearRows:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for order, gear in ipairs(PumpShop.Gear) do
		local row = New("Frame", { Name = gear.id, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.5, -3), Parent = gearRows }, {
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center }),
		})
		local label = New("Frame", { Name = "Label", LayoutOrder = 0, BackgroundTransparency = 1, Size = UDim2.new(0, GEAR_LABEL_W, 1, 0), Parent = row })
		local title = Kit.Text({ Name = "Title", Text = string.upper(gear.name), Font = "Title", KeepItalic = true, TextSize = 16, AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = label })
		Kit.Fit(title, 16, 10)
		Kit.Text({ Name = "Half", Text = string.upper(gear.half), Font = "Chunky", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.new(0, 0, 0.5, 2),
			Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = label })
		local n = 0
		for _, entry in ipairs(entries.Gear) do
			if entry.gear == gear then
				n += 1
				gearTile(row, entry, n)
			end
		end
	end
end

function refresh()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(tilesByKey)
	table.clear(spinning)
	gearRows.Visible = false
	local open = sectionOpen(tab)
	lockNote.Visible = not open
	local altersShown = open and tab == "Alters"
	altersPanel.frame.Visible = altersShown
	if altersShown then
		grid.Visible = false
		strip.Visible = false
		if not altersWasShown then altersPanel.selectNext() else altersPanel.refresh() end
		altersWasShown = true
		return
	end
	altersWasShown = false
	grid.Visible = open
	if not open then
		lockNote.Text = if tab == "Alters" then "BODY ALTERS OPEN AT 7'0\". KEEP GROWING!" else "GEAR OPENS AT GROWTH SPURT 2. KEEP TRAINING!"
		strip.Visible = false
		return
	end
	local list = entries[tab]
	if tab == "Supplements" then
		local mine = {}
		for _, id in ipairs(shop().supplements) do
			for _, entry in ipairs(entries.Supplements) do
				if entry.key == id then table.insert(mine, entry) end
			end
		end
		-- (prompts 57 / 60) the shop's Robux products after its supplements (Coach Dex: Shake Bundle, DNA tokens)
		for _, key in ipairs(shop().robux or {}) do
			local entry = robuxEntry(key, "Supplements")
			if entry then table.insert(mine, entry) end
		end
		list = mine
		if picked.Supplements and not bodyEntry(list, picked.Supplements) then picked.Supplements = nil end
		for _, entry in ipairs(list) do entry.id = entry.key end
	elseif tab == "Style" then
		-- (prompt 61) STYLE: built fresh (your auras and alters can change)
		list = styleEntries()
		entries.Style = list
		if picked.Style and not bodyEntry(list, picked.Style) then picked.Style = nil end
	elseif tab == "DnaLab" then
		-- the coin token and the Robux x1 / x3 side by side (prompt 60)
		list = table.clone(entries.DnaLab)
		for _, key in ipairs(shop().robuxDna or {}) do
			local entry = robuxEntry(key, "DnaLab")
			if entry then table.insert(list, entry) end
		end
		for _, entry in ipairs(list) do entry.id = entry.key end
		if picked.DnaLab and not bodyEntry(list, picked.DnaLab) then picked.DnaLab = nil end
	elseif tab == "Gear" then
		-- (prompt 59) two rows instead of the tile row
		grid.Visible = false
		gearRows.Visible = true
		for _, entry in ipairs(entries.Gear) do entry.id = entry.key end
		if not picked.Gear or not bodyEntry(entries.Gear, picked.Gear) then
			-- the first level you can buy next, else the first tile
			picked.Gear = entries.Gear[1] and entries.Gear[1].key
			for _, entry in ipairs(entries.Gear) do
				if not isOwned(entry) then
					picked.Gear = entry.key
					break
				end
			end
		end
		renderGear()
		showStrip(bodyEntry(entries.Gear, picked.Gear))
		return
	end
	local altersNow = nil
	if tab == "Alters" then
		list, altersNow = alterEntries()
		local nextAlter = Alters.Get(altersNow.next)
		if not picked.Alters or not bodyEntry(list, picked.Alters) then picked.Alters = nextAlter and nextAlter.id or (list[1] and list[1].key) end
		for _, entry in ipairs(list) do entry.id = entry.key end
	end
	if not picked[tab] and list[1] then picked[tab] = list[1].key end
	for order, entry in ipairs(list) do
		local color = tileColor(entry)
		local champion = false -- (prompt 59: no Champion gear on sale; its running gold border is kept for later)
		local isPicked = picked[tab] == entry.key
		-- (a cell per tile: the picked tile's glow sits beside it, outside the list layout)
		local cell = New("Frame", { Name = entry.key, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE_W, TILE_H), Parent = grid })
		local tile = New("TextButton", { Name = "Tile", Text = "", AutoButtonColor = false, BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.85), Size = UDim2.fromScale(1, 1),
			ZIndex = 2, Parent = cell }, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
		local border = New("UIStroke", { Name = "Border", Color = if isPicked then Colors.Gold else color, Thickness = if isPicked then 2 else 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tile })
		tilesByKey[entry.key] = tile
		-- the soft background in its colour, faint rings behind the icon, a dark gradient at the bottom for the words
		themedBackground(tile, 12, UDim2.new(0.5, 0, 0, 36), { 64, 104 })(color)
		New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.58),
			ZIndex = 1, Parent = tile }, {
			New("UICorner", { CornerRadius = UDim.new(0, 12) }),
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.25) }),
		})
		-- the icon, centred on a glow in its colour
		AlterFX.Image(tile, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(96, 96),
			ImageColor3 = color, ImageTransparency = 0.4, ZIndex = 2 })
		local holder = New("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(52, 52),
			ZIndex = 3, Parent = tile })
		local icon = iconOf(entry)
		if string.sub(icon, 1, 13) == "rbxassetid://" then
			New("ImageLabel", { BackgroundTransparency = 1, Image = icon, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder })
		else
			Kit.IconTile(icon, color, 52, { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder })
		end
		-- the name: white, stroked, one line (it shrinks to fit)
		local name = Kit.Text({ Name = "Name", Text = string.upper(entry.name), Font = "Chunky", TextSize = 16, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
			Size = UDim2.new(1, -12, 0, 18), ZIndex = 4, Parent = tile })
		name.TextWrapped = false
		Kit.Fit(name, 16, 9)
		-- the effect: a slim dark pill outlined in its colour
		local effect = effectText(entry)
		if effect ~= "" then
			local pill = New("Frame", { Name = "Effect", BackgroundColor3 = PILL_DARK, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 85), Size = UDim2.new(1, -14, 0, 17),
				ZIndex = 4, Parent = tile }, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
				New("UIStroke", { Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			local text = Kit.Text({ Name = "Text", Text = effect, Font = "Chunky", TextSize = 11, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, 0), ZIndex = 5, Parent = pill })
			text.TextWrapped = false
			Kit.Fit(text, 11, 7)
		end
		-- the price: a slim graphite button with a coin (can't afford: red + NEED x MORE; owned gear: gold OWNED)
		local price = priceOf(entry)
		local priceProps = { Name = "Price", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 107), Size = UDim2.new(1, -16, 0, 22), ZIndex = 4 }
		local priceButton = nil
		if entry.section == "Alters" then
			local status = alterStatus(entry, altersNow)
			priceButton = slimButton(tile, priceProps, status, nil, if entry.alter.number < altersNow.next then "owned" else "plain", 12)
		elseif isOwned(entry) then
			local worn = entry.section == "Style" and styleWorn(entry.style)
			priceButton = slimButton(tile, priceProps, if worn then "Worn" else "Owned", nil, "owned", 13)
		elseif entry.product or entry.packs then
			-- (prompts 57 / 60) Robux: the Robux icon and the price (a special: its x1 price; not set up yet: SOON)
			local product = entry.product or entry.packs[1]
			if product and product.id then
				priceButton = slimButton(tile, priceProps, nil, robuxPrice(product), "plain", 13, "robux")
			else
				priceButton = slimButton(tile, priceProps, "Soon", nil, "off", 12)
			end
		elseif price then
			local afford = coins() >= price
			priceButton = slimButton(tile, priceProps, nil, price, if afford then "plain" else "need", 13)
			if not afford then
				local need = Kit.Text({ Name = "Need", Text = "NEED " .. Kit.Format(price - coins()) .. " MORE", Font = "Chunky", TextSize = 9, TextColor3 = Color3.fromHex("#BDB8C2"),
					AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.new(1, -12, 0, 11), ZIndex = 4, Parent = tile })
				Kit.Fit(need, 9, 7)
			end
		end
		-- (the price button picks the tile too: buying is in the strip)
		if priceButton then priceButton.Activated:Connect(function() tile:SetAttribute("Tap", (tile:GetAttribute("Tap") or 0) + 1) end) end
		if champion then
			-- the Champion gear's border: a gold highlight runs round it
			border.Color = Color3.new(1, 1, 1)
			local gradient = New("UIGradient", { Name = "Spin", Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#C98A12")),
				ColorSequenceKeypoint.new(0.45, Color3.fromHex("#F6C75A")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FFF3C4")),
				ColorSequenceKeypoint.new(0.55, Color3.fromHex("#F6C75A")), ColorSequenceKeypoint.new(1, Color3.fromHex("#C98A12")) }), Parent = border })
			spinning[gradient] = true
		end
		-- picked: the gold outline with the soft glow (the champion keeps its own running highlight)
		if isPicked then
			ReadyGlow.New(tile, { stroke = if champion then nil else border, pad = TILE_GLOW }):Set(true, Colors.Gold)
		end
		local scale = tile:FindFirstChild("PickScale") or New("UIScale", { Name = "PickScale", Parent = tile })
		scale.Scale = if isPicked then 1 else 0.96
		tile:SetAttribute("Picked", isPicked)
		local function pick()
			-- (prompt 54) the grid is rebuilt: the new tile does the bounce and the select sound
			picked[tab] = entry.key
			refresh()
			local now = tilesByKey[entry.key]
			if now then Kit.SelectFeedback(now, strip) end
		end
		tile.Activated:Connect(pick)
		tile:GetAttributeChangedSignal("Tap"):Connect(pick)
	end
	local current = nil
	for _, entry in ipairs(list) do
		if entry.key == picked[tab] then current = entry end
	end
	showStrip(current)
end

function openOn(section: string?, newShop: string?)
	if newShop and PumpShop.Shops[newShop] then shopId = newShop end
	showShopTabs()
	if section and not table.find(shop().tabs, section) then section = "Supplements" end
	if section then
		tab = section
		modal.selectTab(section)
	end
	refresh()
	if not modal.isOpen() then
		UIBus.PanelOpened("PumpShop")
		modal.open()
		Audio.PlayUI("Whoosh")
	end
end
UIBus.RegisterPanel("PumpShop", function() modal.close() end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if modal.isOpen() and (key == "coins" or key == "items" or key == "cosmetics" or key == "dnaWeek" or key == "dnaTokens" or key == "growthSpurts"
		or key == "style" or key == "auras" or key == "alter") then refresh() end
end)

-- (prompt 59) once, after the gear migration: what changed, and the coins given back for straps / sleeves
local playerEvent = Remotes:WaitForChild("PlayerEvent") :: RemoteEvent
playerEvent.OnClientEvent:Connect(function(kind, info)
	if kind ~= "GearSimpler" then return end
	local refund = type(info) == "table" and tonumber(info.refund) or 0
	Notify.Reward("GEAR GOT SIMPLER!", "Belt = lower body, Wraps = upper body." .. (if refund > 0 then " +" .. Kit.Format(refund) .. " COINS refunded." else ""),
		"dumbbell", Colors.Gold, "QuestClaim", "gear59")
end)

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" then
		openOn(info.section, info.shop)
	elseif kind == "Failed" then
		Notify.Toast("Can't buy that", tostring(info.text or ""), "coin", Colors.Red, "pumpfail")
	elseif kind == "Bought" then
		Audio.PlayUI("ShopBuy")
		-- (prompt 47) the item flies into the Inventory button
		local entry = nil
		for _, list in pairs(entries) do
			for _, e in ipairs(list) do
				if e.key == info.id or (e.gear and info.id and string.sub(info.id, 1, #e.gear.id + 1) == e.gear.id .. "_") then entry = e end
			end
		end
		if entry then pcall(flyToInventory, entry, lastBuyTile) end
		if info.section == "Style" then
			local found = bodyEntry(entries.Style, info.id)
			Notify.Reward("NEW STYLE", (found and found.name or "Style") .. " · wearing it now", "sparkles", Colors.Gold)
		end
		if info.section == "Gear" then
			local item = Cosmetics.ById[info.id]
			Notify.Reward("NEW GEAR", (item and item.name or "Gear") .. " · wearing it now", "dumbbell", Colors.Gold)
		end
		if modal.isOpen() then refresh() end
	elseif kind == "Teleported" then
		Notify.Hint("Welcome to the PUMP SHOP! Walk up to the counter.")
	elseif kind == "TeleportedCoach" then
		-- the camera behind you, looking at him (it kept its old angle and could end up inside the gym's front wall)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if root and camera then
			local look = root.CFrame.LookVector
			camera.CFrame = CFrame.lookAt(root.Position - look * 10 + Vector3.new(0, 4, 0), root.Position + look * 6)
		end
		Notify.Hint("Talk to Coach Dex to shop.")
	end
end)

------------------------------------------------------------------------
-- Go to the shop (10 s cooldown): the Shop window's link (prompt 28; was a left menu tile)
------------------------------------------------------------------------
local lastGo = -math.huge
local function goToShop()
	if os.clock() - lastGo < PumpShop.TeleportCooldown then
		Notify.Show(string.format("Wait %d s to go to the PUMP SHOP again.", math.ceil(PumpShop.TeleportCooldown - (os.clock() - lastGo))), nil, "pumpwait")
		return
	end
	lastGo = os.clock()
	remote:FireServer("Teleport")
end
UIBus.GoPumpShop.Event:Connect(goToShop)
-- (prompt 31) the Shop window's "Coach Dex" link: to his counter in the Starter Gym (10 s cooldown, checked on the server)
local lastCoach = -math.huge
UIBus.GoCoach.Event:Connect(function()
	if os.clock() - lastCoach < PumpShop.CoachTeleportCooldown then
		Notify.Show(string.format("Wait %d s to go to Coach Dex again.", math.ceil(PumpShop.CoachTeleportCooldown - (os.clock() - lastCoach))), nil, "coachwait")
		return
	end
	lastCoach = os.clock()
	remote:FireServer("TeleportCoach")
end)

------------------------------------------------------------------------
-- "You can afford: ..." (a newly affordable gear level or apparel item; at most every AffordEvery seconds)
------------------------------------------------------------------------
local affordGui = Theme.ScreenGui({ Name = "PumpShopAfford", DisplayOrder = 47, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
affordGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local affordRoot = Kit.Root(affordGui)
local affordButton = Kit.Button("Gold", "", { Name = "Afford", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Parent = affordRoot },
	{ height = 44, textSize = 14, icon = "coin" })
Kit.OnTopbar(function() affordButton.Position = UDim2.new(0.5, 0, 0, Kit.UnderTopbar(affordRoot) + 40) end)
local announced = {} -- [key] = true (this session)
local lastAfford = -math.huge
local affordToken = 0
local affordAtCoach = false -- (prompt 31) the newly affordable level is sold by Coach Dex (Basic / Pro), not the PUMP SHOP
affordButton.Activated:Connect(function()
	affordGui.Enabled = false
	if affordAtCoach then UIBus.GoCoach:Fire() else goToShop() end
end)

local function checkAfford()
	if not player:GetAttribute("PumpShop") or os.clock() - lastAfford < PumpShop.AffordEvery or UIBus.MenuOpen then return end
	local best = nil
	for _, section in ipairs({ "Gear" }) do
		if sectionOpen(section) then
			for _, entry in ipairs(entries[section]) do
				local price = priceOf(entry)
				local key = entry.key .. "@" .. tostring(price)
				local mine = gearBest(entry.gear)
				local nextUp = (mine and mine.index or 0) + 1 == entry.level.index -- (prompt 59: only the next level)
				if price and nextUp and not isOwned(entry) and not announced[key] and coins() >= price and (not best or price > best.price) then
					best = { entry = entry, price = price, key = key }
				end
			end
		end
	end
	if not best then return end
	announced[best.key] = true
	lastAfford = os.clock()
	local name = best.entry.level.name .. " " .. best.entry.gear.name
	affordAtCoach = table.find(PumpShop.Shops.Coach.gear, best.entry.level.id) ~= nil
	Kit.SetButton(affordButton, nil, "You can afford: " .. name .. "!")
	affordGui.Enabled = true
	Audio.PlayUI("QuestClaim")
	affordToken += 1
	local mine = affordToken
	task.delay(6, function() if affordToken == mine then affordGui.Enabled = false end end)
end
task.spawn(function()
	ClientData.Get()
	-- (things already affordable when you join don't all pop up at once: only what becomes affordable later)
	task.wait(20)
	for _, section in ipairs({ "Gear" }) do
		for _, entry in ipairs(entries[section]) do
			local price = priceOf(entry)
			if price and coins() >= price then announced[entry.key .. "@" .. tostring(price)] = true end
		end
	end
	while true do
		task.wait(5)
		pcall(checkAfford)
	end
end)
