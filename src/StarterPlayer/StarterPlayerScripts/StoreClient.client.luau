-- StoreClient: the Shop tile and the Gym Store window (owner's UI v2, mockup 04_shop), the server boost chip and
-- purchase notes. Only items with ids in Config.Monetization are shown; with none the Shop tile never appears, and it
-- only appears after the tutorial plus a few minutes of play (Workspace attribute TestStore = true skips the wait in
-- Studio). No purchase prompt ever opens by itself: only the green price button opens one.
-- Window: tabs Passes / Items (only the tabs that have something), a 3-column grid of cards (name, art, price "R$ 99"
-- or OWNED in gold) and on the right the picked item big: its art, name, what it does and the green price button.
-- (The mockup's Coins / Boosts / Auras tabs: the game sells no coins and has no auras; products go under Items.)
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Onboarding = require(Shared.Config.Onboarding)
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

local W, H = 566, 290 -- the window (mockup px)
local DETAIL_W = 170
local CARD_H = 112

-- the shop art for each item (Config/UI.ShopIcons); items without art use their Roblox icon
local ART = {
	DoubleGains = "pass_2x_exp", AutoLift = "pass_auto_rep", VIP = "pass_vip", ExtraTrainer = "pass_extra_trainer",
	ShakePack = "product_shake_bundle", ShakeFridge = "product_shake_bundle",
}

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
for _, pass in ipairs(Monetization.Passes) do
	if pass.id then table.insert(items, { item = pass, isPass = true, tab = "Passes" }) end
end
for _, product in ipairs(Monetization.Products) do
	if product.id then table.insert(items, { item = product, isPass = false, tab = "Items" }) end
end
local tabs = {}
local hasTab = {}
for _, entry in ipairs(items) do hasTab[entry.tab] = true end
if hasTab.Passes then table.insert(tabs, { id = "Passes", text = "Passes", icon = "star" }) end
if hasTab.Items then table.insert(tabs, { id = "Items", text = "Items", icon = "gift" }) end
local currentTab = tabs[1].id

local refresh, select -- (below)
local modal = Kit.Modal({ name = "Store", title = "Gym Store", icon = "shopping-cart", width = W, height = H, displayOrder = 25, tabs = tabs,
	onTab = function(id)
		currentTab = id
		refresh()
	end })

local grid = New("ScrollingFrame", { Name = "Grid", Size = UDim2.new(1, -(DETAIL_W + 10), 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
	New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, CARD_H), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 2) }),
})

-- the price line: a robux icon and the number in green (or OWNED in gold)
local function priceLine(props, size: number)
	local frame = New("Frame", props, { Theme.List(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	frame.BackgroundTransparency = 1
	local icon = Pieces.Icon("robux", Colors.Green, { LayoutOrder = 1, Size = UDim2.fromOffset(size, size), Parent = frame })
	icon:SetAttribute("KeepColor", true)
	local text = Kit.Text({ Name = "Price", LayoutOrder = 2, Text = "", Font = "Title", TextSize = size + 2, TextColor3 = Colors.Green,
		Size = UDim2.fromOffset(0, size + 4), AutomaticSize = Enum.AutomaticSize.X, Parent = frame })
	return frame, icon, text
end

-- prices and icons from Roblox (once per item)
local info = {}
local function infoFor(entry)
	local key = entry.item.key
	if info[key] ~= nil then return info[key] end
	info[key] = false
	task.spawn(function()
		local ok, result = pcall(function()
			return MarketplaceService:GetProductInfo(entry.item.id, entry.isPass and Enum.InfoType.GamePass or Enum.InfoType.Product)
		end)
		if ok and result then
			info[key] = result
			if refresh then refresh() end
		end
	end)
	return false
end

local function artFor(image: ImageLabel, entry)
	local name = ART[entry.item.key]
	if name then
		Pieces.Apply(image, name)
	else
		local data = info[entry.item.key]
		image.Image = data and data.IconImageAssetId and data.IconImageAssetId ~= 0 and ("rbxassetid://" .. data.IconImageAssetId) or ""
	end
end

local function owned(entry): boolean
	return entry.isPass and player:GetAttribute("Pass_" .. entry.item.key) == true
end

local cards = {}
for index, entry in ipairs(items) do
	local card = Kit.Card({ Name = entry.item.key, LayoutOrder = index, Clickable = true, Parent = grid }, {})
	Kit.Text({ Name = "Name", Text = entry.item.name, Font = "Title", TextSize = 14, Position = UDim2.fromOffset(4, 5), Size = UDim2.new(1, -8, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local art = Pieces.Image("art", { Name = "Art", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 25), Size = UDim2.fromOffset(62, 62), Parent = card })
	local priceFrame, _, price = priceLine({ Name = "PriceLine", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 18), Parent = card }, 13)
	local ownedLabel = Kit.Text({ Name = "Owned", Text = "OWNED", Font = "Title", TextSize = 14, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 18), Visible = false, Parent = card })
	cards[entry.item.key] = { card = card, art = art, priceFrame = priceFrame, price = price, owned = ownedLabel, entry = entry }
	card.Activated:Connect(function()
		Audio.PlayUI("Click")
		select(entry)
	end)
end

-- the picked item, big, on the right
local detail = Kit.Card({ Name = "Detail", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, DETAIL_W, 1, 0), Parent = modal.body }, {})
local detailArt = Pieces.Image("art", { Name = "Art", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(86, 86), Parent = detail })
local detailName = Kit.Text({ Name = "Name", Text = "", Font = "Title", TextSize = 18, Position = UDim2.fromOffset(6, 98), Size = UDim2.new(1, -12, 0, 22),
	TextTruncate = Enum.TextTruncate.AtEnd, Parent = detail })
local detailText = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, TextWrapped = true, Position = UDim2.fromOffset(8, 122),
	Size = UDim2.new(1, -16, 1, -170), TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
local buy = Kit.Button("Green", "", { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = detail },
	{ width = DETAIL_W - 16, height = 36, textSize = 17, icon = "robux" })
local picked = nil

function select(entry)
	picked = entry
	for key, c in pairs(cards) do
		Theme.SetPiece(c.card, key == entry.item.key and "card_gold" or "card")
	end
	artFor(detailArt, entry)
	detailName.Text = entry.item.name
	detailText.Text = entry.item.text
	refresh()
end

function refresh()
	local first = nil
	for _, c in pairs(cards) do
		local entry = c.entry
		c.card.Visible = entry.tab == currentTab
		if c.card.Visible and (not first or c.card.LayoutOrder < first.card.LayoutOrder) then first = c end
		local data = infoFor(entry)
		artFor(c.art, entry)
		local isOwned = owned(entry)
		c.owned.Visible = isOwned
		c.priceFrame.Visible = not isOwned
		c.price.Text = data and data.PriceInRobux and Kit.Format(data.PriceInRobux) or "..."
	end
	if (not picked or picked.tab ~= currentTab) and first then
		select(first.entry)
		return
	end
	if picked then
		local data = info[picked.item.key]
		local isOwned = owned(picked)
		Kit.SetButton(buy, isOwned and "Gray" or "Green", isOwned and "Owned" or (data and data.PriceInRobux and Kit.Format(data.PriceInRobux) or "Buy"))
		local icon = buy:FindFirstChild("Icon", true)
		if icon then icon.Visible = not isOwned end
	end
end

buy.Activated:Connect(function()
	if not picked then return end
	if picked.isPass then
		if owned(picked) then return end
		MarketplaceService:PromptGamePassPurchase(player, picked.item.id)
	else
		MarketplaceService:PromptProductPurchase(player, picked.item.id)
	end
end)
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) == "Pass_" and modal.isOpen() then refresh() end
end)

local menuButton = nil
local function open()
	if menuButton then menuButton:SetActive(true) end
	UIBus.MenuPanelVisible:Fire(true)
	refresh()
	modal.open()
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

-- The Shop tile: after the tutorial and a few minutes of play, never before.
task.spawn(function()
	local data = ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	local playStart = os.clock()
	while not Workspace:GetAttribute("TestStore") and ((data.onboarding.tutorialStep or Onboarding.Done) < Onboarding.Done
		or os.clock() - playStart < Monetization.StoreAfterMinutes * 60) do
		task.wait(5)
	end
	menuButton = SideMenu.Add("Store", "Shop", Icons.Plate, 8)
	menuButton.Activated:Connect(function()
		if modal.isOpen() then modal.close() else UIBus.PanelOpened("Store") open() end
	end)
end)
