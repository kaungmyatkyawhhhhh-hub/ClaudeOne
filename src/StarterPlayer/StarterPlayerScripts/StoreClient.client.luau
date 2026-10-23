-- StoreClient: the Shop tile and the Store window (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/04_store:
-- the reference frame for every window), the server boost chip and purchase notes. Only items with ids in
-- Config.Monetization are shown; with none the Shop tile never appears. The Shop tile is in the menu from the start
-- (owner, 20 Oct). No purchase prompt ever opens by itself: only the red price button opens one.
-- Window: STORE + tabs Passes / Auras / Boosts / Coins (prompt 40 order; each item's `tab` in Config.Monetization; only tabs
-- that have something). It opens on PASSES (before Growth Spurt 1: BOOSTS). (prompt 40) The grid tiles are Kit.RewardTile
-- in each item's colour (ITEM_COLOR); owned = dimmed with a small green OWNED pill + check (no big stamp). (prompt 61, 23 Oct:
-- the premium tiles below instead, "The premium look": no checkmarks, owned at full brightness with a gold OWNED.)
-- + its own coins pill and X. On the left the
-- HERO tile: the picked item big (thick gold border + soft gold glow, BEST SELLER tag on Monetization.BestSeller, the art,
-- the name in gold, what it does, the red "R$ 249" CTA that pulses). On the right a 3-column grid of dark tiles (art,
-- name, the price in a dark pill); a tap puts that item in the hero tile. OWNED = a rotated gold stamp over the tile's
-- dimmed art and name. Studio only: Workspace attribute TestStoreAll = true previews every item (no ids, can't be bought).
-- Names, prices and icons (owner's bug, 14 Oct: one bad item must never break the shop): every item's Roblox info is
-- fetched ONCE when the game starts (pcall, 3 tries, cached); until it arrives, or if it never does, the item shows
-- Config's fallback name / price / art. Items with id 0 are skipped with a warning. Owned passes keep their OWNED stamp.
-- AURAS tab (owner, 14 Oct): every aura (Config.Auras) with its art and how to get it ("Aura Pack", "50,000 coins",
-- "Reach LVL 10"); the hero's button and a tap on a tile open the Inventory window's Auras tab on that aura.
-- DNA Token (owner, 14 Oct, Config/DNA): its hero tile has two buttons, the Robux price and "25,000" coins (the server
-- checks and takes the coins; not enough = a shake + "Not enough coins").
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Auras = require(Shared.Config.Auras)
local DNA = require(Shared.Config.DNA)
local ClientData = require(Shared.ClientData)
local ShopPrices = require(Shared.ShopPrices)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 660, 290 -- the window (mockup px; Kit shows it at Kit.PanelScale; 660 wide: four tabs + the coins pill)
local HERO_W = 178
local GAP = 10

-- (each item's shop art is its `art` in Config.Monetization, a Config/UI.ShopIcons name; else its Roblox icon)
-- Studio preview only (TestStoreAll): items that have no id yet show too (their Config price, can't be bought)
local preview = game:GetService("RunService"):IsStudio() and Workspace:GetAttribute("TestStoreAll") == true

------------------------------------------------------------------------
-- Server boost chip (anyone in the server sees it)
------------------------------------------------------------------------
local boostChip = RightColumn.Chip("zap", Colors.Gold, 1)
local started = false
task.spawn(function()
	while true do
		task.wait(1)
		local ends = ReplicatedStorage:GetAttribute("ServerBoostEnds")
		local left = type(ends) == "number" and math.max(0, ends - Workspace:GetServerTimeNow()) or 0
		boostChip:SetVisible(started and left > 0)
		if left > 0 then
			boostChip:SetText(Monetization.Effects.ServerBoostGains .. "x", string.format("%d:%02d", left // 60, math.floor(left % 60)))
		end
	end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "Purchased" then
		Notify.Toast("Thank you!", tostring(info.name) .. " is yours.", "star", Colors.Gold)
		Audio.PlayUI("TitleUnlocked")
	elseif kind == "ServerBoost" then
		Notify.Toast("Server boost!", "2x gains for everyone for " .. tostring(info.minutes) .. " minutes. Thank you!", "zap", Colors.Gold)
		Audio.PlayUI("SetComplete")
	elseif kind == "ShakeFridge" then
		Notify.Toast("Shake Fridge", "+1 Energy Shake", "cup-soda", Colors.Blue, "fridge")
	elseif kind == "AdminGift" and type(info.coins) == "number" and info.coins > 0 then
		-- (prompt 64) coins from the owner's console (AdminService)
		Notify.Reward("A GIFT FOR YOU!", "+" .. Kit.Format(info.coins) .. " coins", "coin", Colors.Gold, "TitleUnlocked", "admincoins")
	end
end)

------------------------------------------------------------------------
-- Store (only when something is for sale)
------------------------------------------------------------------------
if not Monetization.AnyConfigured() then
	task.spawn(function()
		ClientData.Get()
		UIBus.WaitForMenu()
		started = true
	end)
	return
end

local items = {} -- { item, isPass, tab }
local function consider(item, isPass)
	if item.id == 0 then
		warn("[Store] " .. tostring(item.key) .. " has the placeholder id 0: not shown")
		return
	end
	if Monetization.ForSale(item) or (preview and item.store ~= false and not item.hidden) then
		table.insert(items, { item = item, isPass = isPass, tab = if isPass then "Passes" else (item.tab or "Boosts") })
	end
end
for _, pass in ipairs(Monetization.Passes) do consider(pass, true) end
for _, product in ipairs(Monetization.Products) do consider(product, false) end
for _, aura in ipairs(Auras.List) do
	table.insert(items, { item = { key = "Aura_" .. aura.id, name = aura.name, text = aura.how, short = aura.short or aura.how, auraId = aura.id, icon = aura.Icon },
		isAura = true, tab = "Auras" })
end
local tabs = {}
local hasTab = {}
for _, entry in ipairs(items) do hasTab[entry.tab] = true end
-- (prompt 20, 21 Oct: the Store opened on the Robux passes. Auras come first now: most of them are earned by playing or
-- bought with coins, so a new player sees things they can get for free first.)
-- (prompt 40, owner: PASSES · AURAS · BOOSTS · COINS; it opens on PASSES, new players before Growth Spurt 1 on BOOSTS)
for _, id in ipairs({ "Passes", "Auras", "Boosts", "Coins" }) do
	if hasTab[id] then table.insert(tabs, { id = id, text = id }) end
end
local currentTab = tabs[1].id
local function startTab(): string
	local data = ClientData.IsLoaded() and ClientData.Get()
	local wanted = if data and (data.growthSpurts or 0) < 1 then "Boosts" else "Passes"
	return if hasTab[wanted] then wanted else tabs[1].id
end
-- (prompt 40) each item's tile colour (mockup 01_store_A); the rest by their tab
local Rarity = Theme.RarityColor
local ITEM_COLOR = {
	DoubleGains = Rarity.Rare, VIP = Rarity.Legendary, DoubleCoins = Rarity.Uncommon, AuraPack = Rarity.Epic, AutoLift = Colors.Red,
	ExtraTrainer = Color3.fromHex("#FF8A2A"), CoinsSmall = Rarity.Legendary, CoinsMedium = Rarity.Legendary, CoinsLarge = Rarity.Legendary,
	ShakePack = Rarity.Rare, EndlessStamina = Colors.Teal, DnaToken = Rarity.Mythic, ServerBoost = Rarity.Legendary,
	DnaTokenPack = Rarity.Mythic, StarterPack = Rarity.Legendary, -- (prompt 60)
}
local function colorOf(entry): Color3
	if entry.isAura then
		local aura = Auras.ById[entry.item.auraId]
		return (aura and Rarity[aura.rarity]) or Rarity.Common
	end
	return ITEM_COLOR[entry.item.key] or Rarity.Common
end

local refresh, select, endlessFull, soldOut, itemText -- (below)
local starterTurn = false -- (prompt 60) the PASSES hero shows the Starter Pack this turn
local heroFrom = nil      -- the tab whose hero was picked by itself
local modal = Kit.Modal({ name = "Store", title = "Store", width = W, height = H, displayOrder = 25, tabs = tabs, coins = true,
	onTab = function(id)
		currentTab = id
		refresh()
	end })

-- Roblox's info for every item, fetched ONCE in the background once the player is playing (prompt 11: not on join), all at once, each in a pcall with
-- at most one retry after 5 s (owner, 15 Oct): the Store never waits for it; Config's name / price / art show meanwhile,
-- and only a changed price is taken from Roblox.
local info = {}
task.spawn(function()
	UIBus.WaitForGameplay() -- (prompt 11: after the tutorial has started, not on join)
	for _, entry in ipairs(items) do
		local id = entry.item.id
		if id then
			task.spawn(function()
				for attempt = 1, 2 do
					local ok, result = pcall(function()
						return MarketplaceService:GetProductInfo(id, if entry.isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
					end)
					if ok and type(result) == "table" then
						info[entry.item.key] = result
						ShopPrices.Set(entry.item.key, result.PriceInRobux) -- (prompt 12: the offer cards show the same price)
						modal.gui:SetAttribute("Price_" .. entry.item.key, result.PriceInRobux) -- (to check it in a test)
						if refresh and modal.isOpen() then refresh() end
						return
					end
					if attempt == 2 then
						warn("[Store] no Roblox info for " .. tostring(entry.item.key) .. ": " .. tostring(result))
						modal.gui:SetAttribute("Price_" .. entry.item.key, "failed")
					end
					task.wait(5)
				end
			end)
		end
	end
end)
-- the shop pictures load in the background once the game is in, so the Store opens with them already there
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	UIBus.WaitForGameplay(6) -- (prompt 11: after the tutorial has started)
	local list = {}
	for _, entry in ipairs(items) do
		local art = entry.item.art and require(Shared.Config.UI).ShopIcons[entry.item.art]
		local image = art or (entry.isAura and entry.item.icon) or nil
		if image then
			local label = Instance.new("ImageLabel")
			label.Image = image
			table.insert(list, label)
		end
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)
local function infoFor(entry)
	return info[entry.item.key] or false
end
local function priceOf(entry): number?
	local data = info[entry.item.key]
	if data and data.PriceInRobux then return data.PriceInRobux end
	return entry.item.price -- (Config's fallback)
end

local function artFor(image: ImageLabel, entry)
	if entry.isAura then
		image.Image = entry.item.icon
		image.ScaleType = Enum.ScaleType.Fit
		return
	end
	local name = entry.item.art
	if name then
		Pieces.Apply(image, name)
	else
		local data = info[entry.item.key]
		image.Image = data and data.IconImageAssetId and data.IconImageAssetId ~= 0 and ("rbxassetid://" .. data.IconImageAssetId) or ""
	end
end

local function owned(entry): boolean
	if entry.isAura then
		local aura = Auras.ById[entry.item.auraId]
		if aura.unlock.type == "pass" then return player:GetAttribute("Pass_" .. aura.unlock.pass) == true end
		local data = ClientData.Get()
		return data.auras ~= nil and data.auras.owned ~= nil and data.auras.owned[aura.id] ~= nil
	end
	return entry.isPass and player:GetAttribute("Pass_" .. entry.item.key) == true
end

------------------------------------------------------------------------
-- (prompt 61, 23 Oct) The premium look of the Alters / Auras panels and the PUMP SHOP (Shared/UI/PremiumKit): every
-- tile and the hero card have a soft background in the item's colour with faint rings behind the icon and a thin outline
-- in that colour; the icon on a glow in the top part, the name UNDER it (white, stroked, one line); the price on a slim
-- graphite button with the Robux icon; owned = a slim dark pill with a thin gold outline and gold OWNED, the tile at full
-- brightness (no checkmarks anywhere). The picked tile: a gold outline.
--   * The hero (left): on PASSES it features a pass you don't own yet (Monetization.PopularPasses order); own them all =
--     "THANK YOU FOR SUPPORTING GYM ARC" on gold with a gold glow. A tap on a tile shows that item there. One title (the
--     icons' baked words are cropped: ART_CROP), the short description, the red buy button (Robux icon + price) or OWNED.
--   * The grid (right): equal tiles, 3 across, 2 rows.
--   * COACH DEX and GO TO PUMP SHOP: two slim graphite buttons in a row under the hero and the grid (full width), once
--     the PUMP SHOP is open for you.
------------------------------------------------------------------------
local PremiumKit = require(Shared.UI.PremiumKit)
local ReadyGlow = require(Shared.UI.ReadyGlow)
local AlterFX = require(Shared.VFX.AlterFX)
local LINK_H = 30
local LINK_GAP = 6
-- (prompt 61) icons with a word baked in under the art (it would repeat the title): only the art's part is shown
-- (the source pictures are 512 x 512; Downloads\gym_arc_transparent_icons\shop)
local ART_CROP = {
	pass_auto_rep = { Vector2.new(0, 0), Vector2.new(512, 404) }, -- ("AUTO" under the dumbbell)
	pass_vip = { Vector2.new(0, 0), Vector2.new(512, 350) }, -- ("VIP" under the crown)
}
local function cropArt(image: ImageLabel, entry)
	local crop = entry.item.art and ART_CROP[entry.item.art]
	image.ImageRectOffset = if crop then crop[1] else Vector2.zero
	image.ImageRectSize = if crop then crop[2] else Vector2.zero
end

------------------------------------------------------------------------
-- The hero card (left): the featured / picked item, big
------------------------------------------------------------------------
local hero = New("Frame", { Name = "Hero", BackgroundColor3 = Color3.fromHex("#141317"), Size = UDim2.new(0, HERO_W, 1, 0), Parent = modal.body }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
})
local heroEdge = New("UIStroke", { Name = "Edge", Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = hero })
local paintHero = PremiumKit.ThemedBackground(hero, 12, UDim2.new(0.5, 0, 0, 50), { 84, 136 })
local heroGlowDot = AlterFX.Image(hero, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(130, 130),
	ImageTransparency = 0.4, ZIndex = 2 })
local heroArt = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(84, 84),
	ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = hero })
-- BEST SELLER: a small gold tag in the top-left corner
local bestTag = New("Frame", { Name = "BestSeller", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Visible = false, Parent = hero }, {
	New("UICorner", { CornerRadius = UDim.new(0, 5) }),
	New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
})
Kit.Text({ Name = "Text", Text = "BEST SELLER", Font = "Chunky", TextSize = 10, TextColor3 = Colors.Ink, Stroke = false, Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5, Parent = bestTag })
-- the one title: white, stroked, one line (it shrinks to fit)
local heroName = Kit.Text({ Name = "Name", Text = "", Font = "Chunky", TextSize = 22, Upper = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 94),
	Size = UDim2.new(1, -16, 0, 24), ZIndex = 4, Parent = hero })
heroName.TextWrapped = false
Kit.Fit(heroName, 22, 12)
local heroText = Kit.Text({ Name = "Text", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Color3.fromHex("#C9C5CF"), TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 119), Size = UDim2.new(1, -16, 0, 28), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4, Parent = hero })
Kit.Fit(heroText, 11, 8, 2) -- (two lines at most: it shrinks instead of being cut)
-- the buy button: the red CTA with the Robux icon and the price; owned: the slim gold OWNED pill
local buy = Kit.Button("Red", "", { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), ZIndex = 4, Parent = hero },
	{ width = HERO_W - 20, height = 36, textSize = 18, icon = "robux", iconColor = Color3.new(1, 1, 1) })
local heroOwned = PremiumKit.SlimButton(hero, { Name = "Owned", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -36, 0, 28),
	Visible = false, ZIndex = 4 }, "Owned", nil, "owned", 14)
heroOwned.Active = false
-- (DNA token only) the coin price beside the Robux button (each half the width)
local HALF_W = (HERO_W - 20 - 6) / 2
local coinBuy = Kit.Button("Gold", Kit.Format(DNA.CoinPrice), { Name = "BuyCoins", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8),
	Visible = false, ZIndex = 4, Parent = hero }, { width = HALF_W, height = 36, textSize = 14, icon = "coin" })
-- every pass owned: THANK YOU on gold with a gold glow
local thanks = New("Frame", { Name = "Thanks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 4, Parent = hero })
local thanksStar = Pieces.Icon("star", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.fromOffset(46, 46), ZIndex = 5, Parent = thanks })
thanksStar:SetAttribute("KeepColor", true)
local thanksText = Kit.GoldText(Kit.Text({ Name = "Text", Text = "THANK YOU FOR SUPPORTING GYM ARC", Font = "Chunky", TextSize = 20, TextWrapped = true,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.new(1, -18, 0, 70), ZIndex = 5, Parent = thanks }))
Kit.Fit(thanksText, 20, 12, 3)
local thanksSub = Kit.Text({ Name = "Sub", Text = "You own every pass.", Font = "Strong", TextSize = 11, TextColor3 = Color3.fromHex("#C9C5CF"), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -16, 0, 14), ZIndex = 5, Parent = thanks })
hero.ZIndex = 2 -- (its glow goes one layer under it: at layer 1 they'd tie and the glow could cover the card)
local heroGlow = ReadyGlow.New(hero, { stroke = heroEdge, pad = 14 })

------------------------------------------------------------------------
-- The grid (right): equal tiles, 3 across, 2 rows
------------------------------------------------------------------------
local grid = New("ScrollingFrame", { Name = "Grid", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, -(HERO_W + GAP), 1, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
	-- (two rows fill the height exactly with the padding: no scrollbar on PASSES)
	New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0.5, -6), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) }),
})

-- COACH DEX / GO TO PUMP SHOP: two slim graphite buttons in a row under everything (once the PUMP SHOP is open for you)
local links = New("Frame", { Name = "Links", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, LINK_H),
	Visible = false, Parent = modal.body })
local function linkButton(name: string, label: string, x: number)
	local button = PremiumKit.SlimButton(links, { Name = name, Position = UDim2.new(x, if x > 0 then LINK_GAP / 2 else 0, 0, 0), Size = UDim2.new(0.5, -LINK_GAP / 2, 1, 0) },
		label, nil, "plain", 13)
	Pieces.Icon("shopping-cart", Colors.Text, { Name = "Icon", LayoutOrder = 0, Size = UDim2.fromOffset(15, 15), ZIndex = button.ZIndex + 2, Parent = button.Row })
		:SetAttribute("KeepColor", true)
	return button
end
local coachLink = linkButton("CoachLink", "Coach Dex", 0)
local pumpLink = linkButton("PumpShopLink", "Go to Pump Shop", 0.5)
pumpLink.Activated:Connect(function()
	Audio.PlayUI("Click")
	modal.close()
	UIBus.GoPumpShop:Fire()
end)
-- (prompt 31) "Coach Dex": to his counter in the Starter Gym, the main shop (10 s cooldown)
coachLink.Activated:Connect(function()
	Audio.PlayUI("Click")
	modal.close()
	UIBus.GoCoach:Fire()
end)
local function refreshPumpLink()
	local on = player:GetAttribute("PumpShop") ~= nil
	links.Visible = on
	local room = if on then -(LINK_H + LINK_GAP) else 0
	grid.Size = UDim2.new(1, -(HERO_W + GAP), 1, room)
	hero.Size = UDim2.new(0, HERO_W, 1, room)
end
player:GetAttributeChangedSignal("PumpShop"):Connect(refreshPumpLink)
refreshPumpLink()

-- a tile: the soft background in its colour, rings and a glow behind the icon (top part), the name under it, the price /
-- OWNED / how-to-get at the bottom
local cards = {}
local function makeTile(entry, index: number)
	local color = colorOf(entry)
	local cell = New("Frame", { Name = entry.item.key, LayoutOrder = index, BackgroundTransparency = 1, Parent = grid })
	local tile = New("TextButton", { Name = "Tile", Text = "", AutoButtonColor = false, BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.85), Size = UDim2.fromScale(1, 1),
		ZIndex = 2, Parent = cell }, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	local border = New("UIStroke", { Name = "Border", Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tile })
	-- (the icon's middle: the top part of the tile, above the name and the price)
	local iconCenter = UDim2.new(0.5, 0, 0.5, -22)
	PremiumKit.ThemedBackground(tile, 12, iconCenter, { 56, 92 })(color)
	New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.5),
		ZIndex = 1, Parent = tile }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.3) }),
	})
	AlterFX.Image(tile, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = iconCenter, Size = UDim2.fromOffset(84, 84), ImageColor3 = color,
		ImageTransparency = 0.45, ZIndex = 2 })
	local art = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0.8, 0, 1, -47),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = tile })
	local name = Kit.Text({ Name = "Name", Text = string.upper(entry.item.name), Font = "Chunky", TextSize = 13, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.new(1, -10, 0, 15), ZIndex = 4, Parent = tile })
	name.TextWrapped = false
	Kit.Fit(name, 13, 9)
	local foot = New("Frame", { Name = "Foot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -16, 0, 19),
		ZIndex = 4, Parent = tile })
	local card = { cell = cell, tile = tile, border = border, art = art, foot = foot, entry = entry, color = color }
	cards[entry.item.key] = card
	local function pick()
		select(entry)
		Kit.SelectFeedback(tile)
		Kit.DetailIn(hero)
	end
	tile.Activated:Connect(pick)
	card.pick = pick
	return card
end
-- (prompt 60) the STARTER PACK is pinned at the top of BOOSTS
for index, entry in ipairs(items) do makeTile(entry, if entry.item.key == "StarterPack" then -1 else index) end
local picked = nil
local showThanks = false
local pickedByTap = false -- (a tapped item stays in the hero; one the hero featured by itself moves on once it's owned)

-- the foot of a tile: OWNED (gold), the price (Robux), or how to get it (an aura)
local function setFoot(card, isOwned: boolean, price: number?)
	for _, child in ipairs(card.foot:GetChildren()) do child:Destroy() end
	local props = { Name = "Button", Size = UDim2.fromScale(1, 1), ZIndex = 5 }
	local button
	if isOwned then
		button = PremiumKit.SlimButton(card.foot, props, "Owned", nil, "owned", 12)
	elseif card.entry.isAura then
		button = PremiumKit.SlimButton(card.foot, props, card.entry.item.short, nil, "plain", 10)
	else
		button = if price then PremiumKit.SlimButton(card.foot, props, nil, price, "plain", 12, "robux") else PremiumKit.SlimButton(card.foot, props, "...", nil, "off", 12)
	end
	local label = button:FindFirstChild("Label", true)
	if label then
		label.TextWrapped = false
		Kit.Fit(label, label.TextSize, 8)
	end
	-- (the button picks the tile too: buying is in the hero)
	button.Activated:Connect(card.pick)
end

local function passesOwned(): boolean
	if not player:GetAttribute("PassesChecked") then return false end
	for _, entry in ipairs(items) do
		if entry.isPass and not owned(entry) then return false end
	end
	return true
end
-- the pass the hero features: the first you don't own in Monetization.PopularPasses order (then the rest)
local function featuredPass()
	local order = Monetization.PopularPasses or {}
	for _, key in ipairs(order) do
		local card = cards[key]
		if card and card.entry.isPass and not owned(card.entry) then return card.entry end
	end
	for _, entry in ipairs(items) do
		if entry.isPass and not owned(entry) then return entry end
	end
	return nil
end

-- (prompt 60) a one-time item that was bought: gone from the Store
function soldOut(entry): boolean
	if not entry.item.once then return false end
	local data = ClientData.Get()
	return type(data.starterPack) == "table" and data.starterPack.bought == true
end

-- (prompts 60 / 61) what an item says: a coin pack its exact coins for you, the DNA x3 its saving, the Starter Pack its
-- contents, "ONE-TIME OFFER" and what it's worth by our own prices (only when that really is more than its price)
function itemText(entry): string
	local item = entry.item
	local data = ClientData.Get()
	local spurts = data.growthSpurts or 0
	if item.coins then
		return "+" .. Kit.Format(Monetization.PackCoins(item, spurts)) .. " COINS. " .. item.text
	end
	if item.dnaTokens then
		local single = cards.DnaToken and priceOf(cards.DnaToken.entry)
		local mine = priceOf(entry)
		local text = DNA.TokenLine .. " x" .. item.dnaTokens .. "."
		if single and mine and mine / item.dnaTokens < single then
			text ..= " SAVE " .. math.floor((1 - mine / (single * item.dnaTokens)) * 100) .. "%."
		end
		return text
	end
	if item.key == "DnaToken" then return DNA.TokenLine end
	if item.key == "StarterPack" then
		local pack = Monetization.StarterPack
		local coins = Monetization.StarterCoins(spurts)
		local text = string.format("ONE-TIME OFFER. +%s coins, %d Protein Shakes, a DNA Token, 30 min 2x EXP and the STARTER title.", Kit.Format(coins), pack.Shakes)
		local medium, shakes, token = cards.CoinsMedium, cards.ShakePack, cards.DnaToken
		if medium and shakes and token then
			local mediumPrice, shakePrice, tokenPrice = priceOf(medium.entry), priceOf(shakes.entry), priceOf(token.entry)
			local mediumCoins = Monetization.PackCoins(medium.entry.item, spurts)
			if mediumPrice and shakePrice and tokenPrice and mediumCoins > 0 then
				local worth = coins * mediumPrice / mediumCoins + shakePrice * pack.Shakes / (Monetization.Effects.ShakePackSize or 3) + tokenPrice * pack.DnaTokens
				worth = math.floor(worth / 5) * 5
				local price = priceOf(entry)
				if price and worth > price then text = "WORTH " .. worth .. " R$! " .. text end
			end
		end
		return text
	end
	return item.text
end

function select(entry)
	picked = entry
	showThanks = false
	pickedByTap = true
	refresh()
end

local function paintHeroFor(entry)
	local color = colorOf(entry)
	paintHero(color)
	heroEdge.Color = color
	heroGlowDot.ImageColor3 = color
	artFor(heroArt, entry)
	cropArt(heroArt, entry)
	heroName.Text = string.upper(entry.item.name)
	heroText.Text = itemText(entry)
	bestTag.Visible = entry.item.key == Monetization.BestSeller
end

function refresh()
	-- (THANK YOU, but a pass isn't owned any more / ownership arrived late: feature one again)
	if showThanks and currentTab == "Passes" and not passesOwned() then picked = nil end
	-- (the pass the hero featured by itself is owned now: the next one, or THANK YOU)
	if picked and not pickedByTap and not showThanks and picked.isPass and owned(picked) then picked = nil end
	local first = nil
	for _, c in pairs(cards) do
		local entry = c.entry
		c.cell.Visible = entry.tab == currentTab and not soldOut(entry)
		if c.cell.Visible and (not first or c.cell.LayoutOrder < first.cell.LayoutOrder) then first = c end
		infoFor(entry)
		artFor(c.art, entry)
		cropArt(c.art, entry)
		setFoot(c, owned(entry), priceOf(entry))
		-- the picked tile: a gold outline (the rest: their own colour)
		local isPicked = picked == entry and not showThanks
		c.border.Color = if isPicked then Colors.Gold else c.color
		c.border.Thickness = if isPicked then 2 else 1.5
	end
	if not picked or (picked.tab ~= currentTab and heroFrom ~= currentTab) or soldOut(picked) then
		-- (prompt 61) PASSES: the hero features a pass you don't own yet; own them all = THANK YOU. Other tabs: the best
		-- seller when it's in this tab, else the first
		pickedByTap = false
		if currentTab == "Passes" then
			local featured = featuredPass()
			local starter = cards.StarterPack
			if starterTurn and starter and not soldOut(starter.entry) then
				-- (prompt 60) the Starter Pack takes turns with the featured pass in the PASSES hero, until bought
				picked, showThanks = starter.entry, false
			elseif featured then
				picked, showThanks = featured, false
			elseif passesOwned() then
				picked, showThanks = first and first.entry, true
			else
				picked, showThanks = first and first.entry, false
			end
		else
			local best = cards[Monetization.BestSeller]
			local starter = cards.StarterPack
			picked = if starter and starter.cell.Visible then starter.entry elseif best and best.cell.Visible then best.entry elseif first then first.entry else nil
			showThanks = false
		end
		if picked then
			heroFrom = currentTab
			return refresh()
		end
	end
	if not picked then return end
	thanks.Visible = showThanks
	for _, part in ipairs({ heroArt, heroGlowDot, heroName, heroText }) do part.Visible = not showThanks end
	if showThanks then
		paintHero(Colors.Gold)
		heroGlow:Set(true, Colors.Gold)
		bestTag.Visible = false
		buy.Visible, coinBuy.Visible, heroOwned.Visible = false, false, false
		return
	end
	heroGlow:Set(false, colorOf(picked))
	paintHeroFor(picked)
	local isDna = picked.item.key == "DnaToken"
	coinBuy.Visible = isDna
	if isDna then Kit.SetButton(coinBuy, nil, Kit.Format(require(Shared.Config.PumpShop).DnaPriceFor(ClientData.Get(), DNA.CoinPrice))) end
	buy.Size = UDim2.fromOffset(if isDna then HALF_W else HERO_W - 20, 36)
	buy.AnchorPoint = if isDna then Vector2.new(0, 1) else Vector2.new(0.5, 1)
	buy.Position = if isDna then UDim2.new(0, 10, 1, -8) else UDim2.new(0.5, 0, 1, -8)
	local buyLabel = buy:FindFirstChild("Label")
	if buyLabel then buyLabel.TextSize = if isDna then 15 else 18 end
	local isOwned = owned(picked)
	local price = priceOf(picked)
	local robux = buy:FindFirstChild("Icon")
	heroOwned.Visible = isOwned and not picked.isAura
	buy.Visible = not heroOwned.Visible
	if robux then robux.Visible = false end
	if picked.isAura then
		Kit.SetButton(buy, "Gold", "View auras")
	elseif endlessFull(picked) then
		Kit.SetButton(buy, "Quiet", "Full: 60 min")
	elseif picked.isPass and not player:GetAttribute("PassesChecked") then
		Kit.SetButton(buy, "Quiet", "...") -- (ownership not known yet: this pass only)
	elseif not isOwned then
		Kit.SetButton(buy, "Red", if price then Kit.Format(price) else "Buy")
		if robux then robux.Visible = price ~= nil end
	end
end

-- Endless Stamina can't be bought while another 15 minutes wouldn't fit under the 60-minute cap (the server caps it too)
function endlessFull(entry): boolean
	if not entry or entry.item.key ~= "EndlessStamina" then return false end
	local untilTime = player:GetAttribute("EndlessStaminaUntil")
	local left = if type(untilTime) == "number" then untilTime - workspace:GetServerTimeNow() else 0
	local fx = Monetization.Effects
	return left > (fx.EndlessStaminaMaxMinutes - fx.EndlessStaminaMinutes) * 60
end

player:GetAttributeChangedSignal("EndlessStaminaUntil"):Connect(function()
	if modal.isOpen() then refresh() end
end)

-- an aura: the Inventory window's Auras tab, on that aura
local function openAura(entry)
	modal.close()
	UIBus.OpenInventory:Fire("Auras", entry.item.auraId)
end
buy.Activated:Connect(function()
	if picked and picked.isAura then
		openAura(picked)
		return
	end
	if not picked or not picked.item.id then return end
	if endlessFull(picked) then return end
	if picked.isPass and not player:GetAttribute("PassesChecked") then return end
	if picked.isPass then
		if owned(picked) then return end
		MarketplaceService:PromptGamePassPurchase(player, picked.item.id)
	else
		MarketplaceService:PromptProductPurchase(player, picked.item.id)
	end
end)
-- a short side-to-side shake (not enough coins)
local function shake(gui: GuiObject)
	local base = gui.Position
	task.spawn(function()
		for _, dx in ipairs({ -6, 6, -5, 5, -3, 3, 0 }) do
			gui.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		gui.Position = base
	end)
end
coinBuy.Activated:Connect(function()
	if not picked or picked.item.key ~= "DnaToken" then return end
	local dnaPrice = require(Shared.Config.PumpShop).DnaPriceFor(ClientData.Get(), DNA.CoinPrice) -- (prompt 19: +10% a token each week)
	if (ClientData.Get().coins or 0) < dnaPrice then
		shake(coinBuy)
		Notify.Toast("Not enough coins", "A DNA token costs " .. Kit.Format(dnaPrice) .. " coins", "coin", Colors.Red, "dnacoins")
		return
	end
	Remotes.PlayerAction:FireServer("BuyDnaToken") -- (the server checks and takes the coins)
end)
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "DnaTokenBought" and type(info) == "table" and info.failed and coinBuy.Visible then shake(coinBuy) end
end)
player.AttributeChanged:Connect(function(name)
	if (name:sub(1, 5) == "Pass_" or name == "PassesChecked") and modal.isOpen() then refresh() end
end)

local menuButton = nil
local function open()
	if menuButton then menuButton:SetActive(true) end
	UIBus.MenuPanelVisible:Fire(true)
	refresh()
	modal.open()
	Theme.Pulse(buy, function() return modal.isOpen() end) -- (the featured CTA pulses while the window is open)
	Audio.PlayUI("Whoosh")
	Remotes.PlayerAction:FireServer("ShopEvent", { event = "ShopOpened" }) -- (prompt 12: analytics)
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then
		if menuButton then menuButton:SetActive(false) end
		UIBus.MenuPanelVisible:Fire(false)
	end
end)
UIBus.RegisterPanel("Store", function() modal.close() end)
-- (tab id, item key?) (prompt 12: an item key opens the Store on that item, e.g. the Growth Spurt card's "Finish faster")
UIBus.OpenShop.Event:Connect(function(tab, itemKey)
	if UIBus.IsLocked and UIBus.IsLocked("Store") then UIBus.ShowLocked("Store") return end -- (prompt 39: still locked, GuideClient)
	if not hasTab[tab] and not modal.isOpen() then tab = startTab() end -- (prompt 40: PASSES, or BOOSTS before Growth Spurt 1)
	if hasTab[tab] then
		currentTab = tab
		modal.selectTab(tab)
	end
	local card = type(itemKey) == "string" and cards[itemKey]
	if card and card.entry.tab == currentTab then select(card.entry) end
	if not modal.isOpen() then UIBus.PanelOpened("Store") open() end
end)

-- (prompt 60) the PASSES hero takes turns: the featured pass, then the Starter Pack (until it's bought; a tapped tile stays)
task.spawn(function()
	while true do
		task.wait(6)
		if modal.isOpen() and currentTab == "Passes" and not pickedByTap and cards.StarterPack and not soldOut(cards.StarterPack.entry) then
			starterTurn = not starterTurn
			picked = nil
			refresh()
		end
	end
end)
ClientData.Changed:Connect(function(path)
	if path[1] == "starterPack" and modal.isOpen() then
		picked = nil
		refresh()
	end
end)

-- The Shop tile: in the menu from the start, for every player (owner, 20 Oct: "make shop appear always, not just after 5
-- mins"; it used to wait for the end of the tutorial plus the player's first 5 minutes).
task.spawn(function()
	UIBus.WaitForMenu()
	started = true
	menuButton = SideMenu.Add("Store", "Shop", Icons.Plate, 8)
	menuButton.Activated:Connect(function()
		if modal.isOpen() then modal.close() return end
		currentTab = startTab() -- (prompt 40: PASSES, or BOOSTS before Growth Spurt 1)
		picked = nil -- (prompt 61: the hero features again what you don't own yet)
		modal.selectTab(currentTab)
		UIBus.PanelOpened("Store")
		open()
	end)
end)
