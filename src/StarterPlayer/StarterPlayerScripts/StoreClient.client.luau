-- StoreClient: the Shop tile and the Store window (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/04_store:
-- the reference frame for every window), the server boost chip and purchase notes. Only items with ids in
-- Config.Monetization are shown; with none the Shop tile never appears. The Shop tile is in the menu from the start
-- (owner, 20 Oct). No purchase prompt ever opens by itself: only the red price button opens one.
-- Window: STORE + tabs Auras / Boosts / Coins / Passes (each item's `tab` in Config.Monetization; only tabs that have something)
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
		Notify.Toast("Server boost!", tostring(info.name) .. ": 2x gains for " .. tostring(info.minutes) .. " minutes", "zap", Colors.Gold)
		Audio.PlayUI("SetComplete")
	elseif kind == "ShakeFridge" then
		Notify.Toast("Shake Fridge", "+1 Energy Shake", "cup-soda", Colors.Blue, "fridge")
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
for _, id in ipairs({ "Auras", "Boosts", "Coins", "Passes" }) do
	if hasTab[id] then table.insert(tabs, { id = id, text = id }) end
end
local currentTab = tabs[1].id

local refresh, select, endlessFull -- (below)
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
						if refresh and modal.isOpen() then refresh() end
						return
					end
					if attempt == 2 then warn("[Store] no Roblox info for " .. tostring(entry.item.key) .. ": " .. tostring(result)) end
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
-- The hero tile (left): the picked item, big
------------------------------------------------------------------------
local hero = Kit.Card({ Name = "Hero", Piece = "card_gold", Size = UDim2.new(0, HERO_W, 1, 0), Parent = modal.body }, {})
hero:FindFirstChild("Border").Thickness = 2.5
-- a warm red glow behind the art (the art's own backdrop in the mockup)
New("Frame", { Name = "ArtGlow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(100, 100),
	BackgroundColor3 = Color3.fromHex("#3A1214"), BackgroundTransparency = 0.2, Parent = hero }, {
	New("UICorner", { CornerRadius = UDim.new(0, 18) }),
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.7) }) }),
})
local heroArt = Pieces.Image("art", { Name = "Art", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(96, 96), Parent = hero })
-- BEST SELLER: a small gold tag in the top-left corner
local bestTag = New("Frame", { Name = "BestSeller", Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Visible = false, Parent = hero }, {
	New("UICorner", { CornerRadius = UDim.new(0, 5) }),
	New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})
Kit.Text({ Name = "Text", Text = "BEST SELLER", Font = "Title", TextSize = 11, TextColor3 = Colors.Ink, Stroke = false, Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = bestTag })
local heroName = Kit.GoldText(Kit.Text({ Name = "Name", Text = "", Font = "Title", TextSize = 22, Upper = true, Position = UDim2.fromOffset(12, 122),
	Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = hero }))
-- (a long name like ENDLESS STAMINA shrinks to fit instead of being cut off)
heroName.TextScaled = true
Theme.New("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 14, Parent = heroName })
local heroText = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, TextWrapped = true, Position = UDim2.fromOffset(12, 148),
	Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = hero })
local buy = Kit.Button("Red", "", { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = hero },
	{ width = HERO_W - 22, height = 40, textSize = 20 })
-- (DNA token only) the coin price beside the Robux button (each half the width)
local HALF_W = (HERO_W - 22 - 6) / 2
local coinBuy = Kit.Button("Gold", Kit.Format(DNA.CoinPrice), { Name = "BuyCoins", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -11, 1, -10),
	Visible = false, Parent = hero }, { width = HALF_W, height = 40, textSize = 14, icon = "coin" })

------------------------------------------------------------------------
-- The grid (right): dark tiles with art, name and a price pill
------------------------------------------------------------------------
local grid = New("ScrollingFrame", { Name = "Grid", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, -(HERO_W + GAP), 1, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
	New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0.5, -4), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 1) }),
})

-- OWNED: a rotated gold stamp
local function ownedStamp(parent)
	local stamp = New("Frame", { Name = "Owned", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(96, 28),
		Rotation = -12, BackgroundColor3 = Color3.fromHex("#120F08"), BackgroundTransparency = 0.1, ZIndex = 4, Visible = false, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, 7) }),
		New("UIStroke", { Color = Colors.Gold, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Kit.GoldText(Kit.Text({ Name = "Text", Text = "OWNED", Font = "Title", TextSize = 17, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = stamp }))
	return stamp
end

local cards = {}
for index, entry in ipairs(items) do
	local card = Kit.Card({ Name = entry.item.key, LayoutOrder = index, Clickable = true, Parent = grid }, {})
	local art = Pieces.Image("art", { Name = "Art", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(52, 52), Parent = card })
	local name = Kit.Text({ Name = "Name", Text = entry.item.name, Font = "Title", TextSize = 13, Upper = true, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.new(1, -8, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local pill, price = Kit.PricePill("", { Name = "Price", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.fromOffset(0, 24), Parent = card })
	local stamp = ownedStamp(card)
	cards[entry.item.key] = { card = card, art = art, name = name, pill = pill, price = price, stamp = stamp, entry = entry }
	card.Activated:Connect(function()
		Audio.PlayUI("Click")
		select(entry)
	end)
end
local picked = nil

function select(entry)
	picked = entry
	for key, c in pairs(cards) do
		-- the picked tile gets a thin gold edge (the hero tile shows it big)
		local border = c.card:FindFirstChild("Border")
		if border then
			local on = key == entry.item.key
			border.Color = on and Colors.Gold or Colors.Outline
			border.Transparency = on and 0.25 or 0.3
		end
	end
	artFor(heroArt, entry)
	heroName.Text = entry.item.name
	heroText.Text = entry.item.text
	bestTag.Visible = entry.item.key == Monetization.BestSeller
	refresh()
end

function refresh()
	local first = nil
	for _, c in pairs(cards) do
		local entry = c.entry
		c.card.Visible = entry.tab == currentTab
		if c.card.Visible and (not first or c.card.LayoutOrder < first.card.LayoutOrder) then first = c end
		infoFor(entry)
		artFor(c.art, entry)
		local isOwned = owned(entry)
		local price = priceOf(entry)
		c.stamp.Visible = isOwned
		c.pill.Visible = not isOwned
		c.price.Text = if entry.isAura then entry.item.short elseif price then "R$ " .. Kit.Format(price) else "..."
		-- owned: the stamp is the only bright thing on the tile
		c.art.ImageTransparency = isOwned and 0.65 or 0
		c.name.TextColor3 = isOwned and Colors.Faint or Colors.Text
	end
	if (not picked or picked.tab ~= currentTab) and first then
		-- the hero tile starts on the best seller when it's in this tab
		local best = cards[Monetization.BestSeller]
		select((best and best.card.Visible) and best.entry or first.entry)
		return
	end
	if picked then
		local isDna = picked.item.key == "DnaToken"
		coinBuy.Visible = isDna
		if isDna then Kit.SetButton(coinBuy, nil, Kit.Format(require(Shared.Config.PumpShop).DnaPriceFor(ClientData.Get(), DNA.CoinPrice))) end
		buy.Size = UDim2.fromOffset(if isDna then HALF_W else HERO_W - 22, 40)
		buy.AnchorPoint = if isDna then Vector2.new(0, 1) else Vector2.new(0.5, 1)
		buy.Position = if isDna then UDim2.new(0, 11, 1, -10) else UDim2.new(0.5, 0, 1, -10)
		local buyLabel = buy:FindFirstChild("Label")
		if buyLabel then buyLabel.TextSize = if isDna then 15 else 20 end
		local isOwned = owned(picked)
		local price = priceOf(picked)
		if picked.isAura then
			Kit.SetButton(buy, "Gold", "View auras")
		elseif endlessFull(picked) then
			Kit.SetButton(buy, "Quiet", "Full: 60 min")
		elseif picked.isPass and not player:GetAttribute("PassesChecked") then
			Kit.SetButton(buy, "Quiet", "...") -- (ownership not known yet: this pass only)
		else
			Kit.SetButton(buy, isOwned and "Quiet" or "Red", isOwned and "Owned" or (price and ("R$ " .. Kit.Format(price)) or "Buy"))
		end
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
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then
		if menuButton then menuButton:SetActive(false) end
		UIBus.MenuPanelVisible:Fire(false)
	end
end)
UIBus.RegisterPanel("Store", function() modal.close() end)
UIBus.OpenShop.Event:Connect(function(tab)
	if hasTab[tab] then
		currentTab = tab
		modal.selectTab(tab)
	end
	if not modal.isOpen() then UIBus.PanelOpened("Store") open() end
end)

-- The Shop tile: in the menu from the start, for every player (owner, 20 Oct: "make shop appear always, not just after 5
-- mins"; it used to wait for the end of the tutorial plus the player's first 5 minutes).
task.spawn(function()
	UIBus.WaitForMenu()
	started = true
	menuButton = SideMenu.Add("Store", "Shop", Icons.Plate, 8)
	menuButton.Activated:Connect(function()
		if modal.isOpen() then modal.close() else UIBus.PanelOpened("Store") open() end
	end)
end)
