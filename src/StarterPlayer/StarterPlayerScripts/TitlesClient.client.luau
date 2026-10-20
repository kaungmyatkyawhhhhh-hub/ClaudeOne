-- TitlesClient: the INVENTORY tile and window (owner, 14 Oct: was the Titles window), and the unlock toasts.
-- Tabs BOOSTS | GEAR | TITLES | AURAS | ITEMS; the last one opened is remembered (settings.inventoryTab).
--   BOOSTS (prompt 14, 21 Oct): the boost items you own (Config.Boosts) with USE and EQUIP (Shared/UI/BoostsPanel).
--   GEAR (prompt 19): what you own to wear (PUMP SHOP gear and apparel, the clothing store's gear) (Shared/UI/GearPanel).
--   TITLES: a 4-column grid of cards (it scrolls): the rarity word in its color (COMMON gray, UNCOMMON green, RARE blue,
--     EPIC purple, LEGENDARY gold, SECRET red), the title's name, and
--       owned:  EQUIPPED (gold, tap = take it off) or EQUIP (green, tap = wear it above your head)
--       locked: the name faded and a lock (secret titles show "???"); tapping it says how to earn it.
--     Titles are kept forever and never bought.
--   AURAS (Config.Auras, AuraService): on the left the picked aura big (its art, name, rarity, how to get it, the action
--     button) and "Aura: Off"; on the right a grid of aura tiles (art, name, rarity, and its state: EQUIP / EQUIPPED /
--     a coin price / AURA PACK or VIP (opens that pass's purchase) / how to earn it). The preview is your own character
--     behind the window wearing the picked aura at full power (Roblox doesn't draw particles inside a ViewportFrame;
--     AURA.preview).
--   ITEMS: DNA Tokens (count + "Use in Genetics", which opens the Genetics screen) and the boosts running now with their
--     timers (2x EXP, 2x Coins, VIP, Endless Stamina, the shake boost, smoothie bar drinks, inventory boosts, a Server
--     Boost). (The shakes moved to BOOSTS.)
-- Text fit (owner, 14 Oct): every label stays inside its card with 8 px each side; names and rarity words shrink to fit
-- one line (Kit.Fit), how-to-unlock text is the body font in sentence case, up to 2 lines.
-- UIBus.OpenInventory(tab, auraId?) opens it on a tab (the Store's Auras tab, toasts).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Titles = require(Shared.Config.Titles)
local Auras = require(Shared.Config.Auras)
local Meals = require(Shared.Config.Meals)
local Boosts = require(Shared.Config.Boosts)
local Monetization = require(Shared.Config.Monetization)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local New, Colors = Theme.New, Theme.Colors
local player = Players.LocalPlayer

-- the window's rarity colors (mockup 08)
local RARITY_COLOR = {
	Common = Color3.fromHex("#B8B8C4"), Uncommon = Colors.Green, Rare = Colors.Blue, Epic = Colors.Purple,
	Legendary = Color3.fromHex("#FFB04A"), Secret = Colors.Red,
}
local CARD = Vector2.new(124, 78)
local PAD = 8 -- every label keeps this far from its card's edges
local TABS = { Boosts = true, Gear = true, Titles = true, Auras = true, Items = true }

local menuButton = SideMenu.Add("Inventory", "Inventory", nil, 2)

local tab = "Boosts"
local refresh -- (below)
local modal = Kit.Modal({ name = "Inventory", title = "Inventory", icon = "backpack", width = 650, height = 248, displayOrder = 25,
	tabs = { { id = "Boosts", text = "Boosts", icon = "zap" }, { id = "Gear", text = "Gear", icon = "dumbbell" }, { id = "Titles", text = "Titles", icon = "medal" }, { id = "Auras", text = "Auras", icon = "sparkles" }, { id = "Items", text = "Items", icon = "gift" } },
	onTab = function(id)
		if tab ~= id then
			tab = id
			-- remembered for next time (saved with the settings; the server only takes the three tab names)
			Remotes.PlayerAction:FireServer("SetSettings", { inventoryTab = id })
		end
		refresh()
	end })
local countLabel = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 14, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -56, 0, 14), Size = UDim2.fromOffset(90, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = modal.panel })

------------------------------------------------------------------------
-- TITLES tab
------------------------------------------------------------------------
local grid = New("ScrollingFrame", { Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(CARD.X, CARD.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})

local cards = {}
local ordered = table.clone(Titles.List)
table.sort(ordered, function(a, b)
	local ra, rb = Titles.Rarities[a.rarity].order, Titles.Rarities[b.rarity].order
	if ra ~= rb then return ra < rb end
	return table.find(Titles.List, a) < table.find(Titles.List, b)
end)

for index, title in ipairs(ordered) do
	local card = Kit.Card({ Name = title.id, LayoutOrder = index, Clickable = true, Parent = grid }, {})
	local rarity = Kit.Fit(Kit.Text({ Name = "Rarity", Text = string.upper(title.rarity), Font = "Title", TextColor3 = RARITY_COLOR[title.rarity] or Colors.Muted,
		Position = UDim2.fromOffset(PAD, 6), Size = UDim2.new(1, -2 * PAD, 0, 14), Parent = card }), 11, 10)
	-- (room for two lines: a long name on a small phone wraps instead of being cut)
	local name = Kit.Fit(Kit.Text({ Name = "TitleName", Text = title.name, Font = "Title", Position = UDim2.fromOffset(PAD, 19),
		Size = UDim2.new(1, -2 * PAD, 0, 30), Parent = card }), 15, 10)
	local button = Kit.Button("Green", "Equip", { Name = "Equip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Parent = card },
		{ width = CARD.X - 2 * PAD - 2, height = 22, textSize = 12 })
	local lock = Pieces.Icon("lock", Colors.Faint, { Name = "Lock", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(18, 18), Parent = card })
	lock:SetAttribute("KeepColor", true)
	cards[title.id] = { card = card, rarity = rarity, name = name, button = button, lock = lock, title = title }
	local function tapped()
		local data = ClientData.Get()
		if not data.titles.owned[title.id] then
			Notify.Toast(title.rarity == "Secret" and "Secret title" or title.name, title.rarity == "Secret" and "Keep playing to find it." or title.description,
				"lock", RARITY_COLOR[title.rarity], "titleinfo")
			return
		end
		Remotes.PlayerAction:FireServer("EquipTitle", data.titles.equipped ~= title.id and title.id or nil)
	end
	card.Activated:Connect(tapped)
	button.Activated:Connect(tapped)
end

------------------------------------------------------------------------
-- AURAS tab
------------------------------------------------------------------------
local AURA = { tiles = {}, picked = Auras.List[1].id }
local TILE = Vector2.new(112, 104)
AURA.frame = New("Frame", { Name = "Auras", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = modal.body })
-- the preview card (left)
AURA.preview = Kit.Card({ Name = "Preview", Piece = "card_gold", Size = UDim2.new(0, 156, 1, 0), Parent = AURA.frame }, {})
AURA.bigIcon = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(72, 72), ScaleType = Enum.ScaleType.Fit, Parent = AURA.preview })
AURA.bigName = Kit.Fit(Kit.GoldText(Kit.Text({ Name = "Name", Text = "", Font = "Title", Upper = true, Position = UDim2.fromOffset(PAD, 82),
	Size = UDim2.new(1, -2 * PAD, 0, 20), Parent = AURA.preview })), 17, 10)
AURA.bigRarity = Kit.Fit(Kit.Text({ Name = "Rarity", Text = "", Font = "Title", Position = UDim2.fromOffset(PAD, 102), Size = UDim2.new(1, -2 * PAD, 0, 14),
	Parent = AURA.preview }), 11, 10)
-- how to get it: the body font, sentence case, up to 2 lines
AURA.bigHow = Kit.Fit(Kit.Text({ Name = "How", Text = "", Font = "Body", TextColor3 = Colors.Muted, Position = UDim2.fromOffset(PAD, 117),
	Size = UDim2.new(1, -2 * PAD, 0, 30), TextYAlignment = Enum.TextYAlignment.Top, Parent = AURA.preview }), 14, 10, 2)
AURA.action = Kit.Button("Green", "Equip", { Name = "Action", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -38), Parent = AURA.preview },
	{ width = 156 - 2 * PAD - 4, height = 28, textSize = 13 })
AURA.off = Kit.Button("Quiet", "Aura: Off", { Name = "Off", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = AURA.preview },
	{ width = 156 - 2 * PAD - 4, height = 26, textSize = 12 })
-- the tiles (right)
AURA.grid = New("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(164, 0), Size = UDim2.new(1, -164, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = AURA.frame }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(TILE.X, TILE.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})

function AURA.has(aura): boolean
	if aura.unlock.type == "pass" then return player:GetAttribute("Pass_" .. aura.unlock.pass) == true end
	local data = ClientData.Get()
	return data.auras ~= nil and data.auras.owned ~= nil and data.auras.owned[aura.id] ~= nil
end
function AURA.equipped(): string?
	local data = ClientData.Get()
	return data.auras and data.auras.equipped or nil
end
-- what the action button does for an aura: "equip", "equipped", "coins", "pass" or "locked" (+ its text and style)
function AURA.state(aura)
	if AURA.has(aura) then
		if AURA.equipped() == aura.id then return "equipped", "Equipped", "Gold" end
		return "equip", "Equip", "Green"
	end
	local unlock = aura.unlock
	if unlock.type == "coins" then return "coins", Kit.Format(unlock.price), "Gold" end
	if unlock.type == "pass" then
		local pass = Monetization.PassByKey[unlock.pass]
		if pass and pass.id then return "pass", if unlock.pass == "VIP" then "VIP" else "Aura Pack", "Red" end
	end
	return "locked", "Locked", "Disabled"
end
function AURA.act(aura, button)
	local kind = AURA.state(aura)
	if kind == "equip" then
		Remotes.PlayerAction:FireServer("AuraEquip", aura.id)
	elseif kind == "equipped" then
		Remotes.PlayerAction:FireServer("AuraEquip", nil)
	elseif kind == "coins" then
		if (ClientData.Get().coins or 0) < aura.unlock.price then
			Notify.Toast("Not enough coins", aura.name .. " costs " .. Kit.Format(aura.unlock.price) .. " coins", "coin", Colors.Red, "auracoins")
			local base = button.Position
			task.spawn(function()
				for _, dx in ipairs({ -6, 6, -5, 5, -3, 3, 0 }) do
					button.Position = base + UDim2.fromOffset(dx, 0)
					task.wait(0.035)
				end
				button.Position = base
			end)
			return
		end
		Remotes.PlayerAction:FireServer("AuraBuy", aura.id)
	elseif kind == "pass" then
		local pass = Monetization.PassByKey[aura.unlock.pass]
		if pass and pass.id then MarketplaceService:PromptGamePassPurchase(player, pass.id) end
	else
		Notify.Toast(aura.name, aura.how .. " to unlock it.", "lock", Colors.Muted, "aurainfo")
	end
end

for index, aura in ipairs(Auras.List) do
	local tile = Kit.Card({ Name = aura.id, LayoutOrder = index, Clickable = true, Parent = AURA.grid }, {})
	local art = New("ImageLabel", { Name = "Art", Image = aura.Icon, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(34, 34), ScaleType = Enum.ScaleType.Fit, Parent = tile })
	Kit.Fit(Kit.Text({ Name = "AuraName", Text = aura.name, Font = "Title", Upper = true, Position = UDim2.fromOffset(PAD, 39), Size = UDim2.new(1, -2 * PAD, 0, 16),
		Parent = tile }), 13, 10)
	Kit.Fit(Kit.Text({ Name = "Rarity", Text = string.upper(aura.rarity), Font = "Title", TextColor3 = RARITY_COLOR[aura.rarity] or Colors.Muted,
		Position = UDim2.fromOffset(PAD, 55), Size = UDim2.new(1, -2 * PAD, 0, 13), Parent = tile }), 11, 10)
	local button = Kit.Button("Green", "Equip", { Name = "State", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = tile },
		{ width = TILE.X - 2 * PAD, height = 22, textSize = 10 })
	-- locked: how to earn it instead of a button (body font, up to 2 lines)
	local how = Kit.Fit(Kit.Text({ Name = "How", Text = aura.how, Font = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, PAD, 1, -4), Size = UDim2.new(1, -2 * PAD, 0, 32), Visible = false, Parent = tile }), 14, 10, 2)
	AURA.tiles[aura.id] = { tile = tile, art = art, button = button, how = how, aura = aura }
	tile.Activated:Connect(function()
		AURA.picked = aura.id
		refresh()
	end)
	button.Activated:Connect(function()
		AURA.picked = aura.id
		AURA.act(aura, button)
		refresh()
	end)
end
AURA.action.Activated:Connect(function()
	local aura = Auras.ById[AURA.picked]
	if aura then AURA.act(aura, AURA.action) end
end)
AURA.off.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("AuraEquip", nil)
end)

function AURA.refresh()
	local owned = 0
	local worn = AURA.equipped()
	for _, aura in ipairs(Auras.List) do
		local t = AURA.tiles[aura.id]
		local kind, text, style = AURA.state(aura)
		if AURA.has(aura) then owned += 1 end
		t.button.Visible = kind ~= "locked"
		t.how.Visible = kind == "locked"
		if kind ~= "locked" then Kit.SetButton(t.button, style, text) end
		t.art.ImageTransparency = if kind == "locked" then 0.55 else 0
		Theme.SetPiece(t.tile, if worn == aura.id then "card_gold" elseif AURA.picked == aura.id then "card_selected" else "card")
	end
	local aura = Auras.ById[AURA.picked] or Auras.List[1]
	local kind, text, style = AURA.state(aura)
	AURA.bigIcon.Image = aura.Icon
	AURA.bigIcon.ImageTransparency = if kind == "locked" then 0.45 else 0
	AURA.bigName.Text = aura.name
	AURA.bigRarity.Text = string.upper(aura.rarity)
	AURA.bigRarity.TextColor3 = RARITY_COLOR[aura.rarity] or Colors.Muted
	AURA.bigHow.Text = if AURA.has(aura) then "Yours" else aura.how
	Kit.SetButton(AURA.action, style, text)
	Kit.SetButton(AURA.off, if worn then "Quiet" else "Tab", "Aura: Off")
	countLabel.Text = owned .. " / " .. #Auras.List
end

-- the try-on: while the AURAS tab is open, your character wears the picked aura at full power (AuraClient reads the
-- local "AuraPreview" attribute; nothing is equipped or sent to the server)
function AURA.preview()
	local aura = modal.isOpen() and tab == "Auras" and Auras.ById[AURA.picked] or nil
	local want = aura and aura.vfx or nil
	if player:GetAttribute("AuraPreview") ~= want then player:SetAttribute("AuraPreview", want) end
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(AURA.preview) end)

------------------------------------------------------------------------
-- ITEMS tab
------------------------------------------------------------------------
local ITEMS = {}
local ITEM_H, BOOST = 78, Vector2.new(258, 46)
ITEMS.frame = New("Frame", { Name = "Items", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = modal.body })

-- one owned item: icon on the left; the name and the count (gold, right) on the top row, a short line under them, the
-- button at the bottom right
local COUNT_W = 48
local function itemCard(order: number, name: string, sub: string, buttonText: string, buttonWidth: number, makeIcon: (Instance) -> ())
	local card = Kit.Card({ Name = name, Position = UDim2.new((order - 1) * 0.5, if order == 1 then 0 else 4, 0, 0),
		Size = UDim2.new(0.5, -4, 0, ITEM_H), Parent = ITEMS.frame }, {})
	makeIcon(card)
	Kit.Fit(Kit.Text({ Name = "Name", Text = name, Font = "Title", Position = UDim2.fromOffset(62, PAD),
		Size = UDim2.new(1, -(62 + COUNT_W + PAD + 4), 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }), 15, 10)
	Kit.Fit(Kit.Text({ Name = "Sub", Text = sub, Font = "Body", TextColor3 = Colors.Muted, Position = UDim2.fromOffset(62, 27),
		Size = UDim2.new(1, -(62 + PAD), 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }), 12, 10)
	local count = Kit.Fit(Kit.GoldText(Kit.Text({ Name = "Count", Text = "x0", Font = "Number", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 6), Size = UDim2.fromOffset(COUNT_W, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })), 20, 12)
	local button = Kit.Button("Green", buttonText, { Name = "Use", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -PAD, 1, -PAD), Parent = card },
		{ width = buttonWidth, height = 28, textSize = 12 })
	return { card = card, count = count, button = button }
end

ITEMS.dna = itemCard(1, "DNA Tokens", "Reroll your genetics", "Use in Genetics", 112, function(card)
	Pieces.ShopIcon("product_dna_token", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(48, 48), Parent = card })
end)
ITEMS.dna.button.Activated:Connect(function()
	modal.close()
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
	UIBus.OpenGenetics:Fire()
end)

-- the boosts running now
Kit.Text({ Name = "BoostsTitle", Text = "Active boosts", Font = "Title", Upper = true, TextSize = 13, TextColor3 = Colors.Muted,
	Position = UDim2.fromOffset(2, ITEM_H + 8), Size = UDim2.new(1, -4, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = ITEMS.frame })
ITEMS.boostGrid = New("ScrollingFrame", { Name = "Boosts", Position = UDim2.fromOffset(0, ITEM_H + 28), Size = UDim2.new(1, 0, 1, -(ITEM_H + 28)),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = ITEMS.frame }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(BOOST.X, BOOST.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})
ITEMS.none = Kit.Text({ Name = "NoBoosts", Text = "No boosts running. Drink a shake or visit the smoothie bar.", Font = "Body", TextSize = 12,
	TextColor3 = Colors.Faint, Position = UDim2.fromOffset(2, ITEM_H + 30), Size = UDim2.new(1, -4, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false, Parent = ITEMS.frame })

-- every boost the client can see: name, icon, color, what it does, and when it ends (nil = not running, math.huge = always)
local function serverNow() return Workspace:GetServerTimeNow() end
local function untilAttr(holder: Instance, name: string): number?
	local value = holder:GetAttribute(name)
	return if type(value) == "number" and value > serverNow() then value else nil
end
local function passOn(key: string): number?
	return if player:GetAttribute("Pass_" .. key) == true then math.huge else nil
end
local BOOSTS = {
	{ id = "DoubleGains", name = "2x EXP", icon = "zap", color = Colors.Gold, sub = "Pass", ends = function() return passOn("DoubleGains") end },
	{ id = "DoubleCoins", name = "2x Coins", icon = "coin", color = Colors.Gold, sub = "Pass", ends = function() return passOn("DoubleCoins") end },
	{ id = "VIP", name = "VIP", icon = "star", color = Colors.Purple, sub = "+10% coins", ends = function() return passOn("VIP") end },
	{ id = "EndlessStamina", name = "Endless Stamina", icon = "zap", color = Colors.Gold, sub = "No stamina drain",
		ends = function() return untilAttr(player, "EndlessStaminaUntil") end },
	{ id = "Shake", name = "Protein Shake", icon = "cup-soda", color = Colors.Teal, sub = "+50% gains", ends = function() return untilAttr(player, "ShakeEnds") end },
	{ id = "ServerBoost", name = "Server Boost", icon = "users", color = Colors.Red, sub = "2x gains for all",
		ends = function() return untilAttr(ReplicatedStorage, "ServerBoostEnds") end },
}
for _, item in ipairs(Boosts.Items) do
	if not item.shake then
		table.insert(BOOSTS, { id = "Item_" .. item.id, name = item.name, icon = item.icon, color = Color3.fromHex(item.color), sub = item.text,
			ends = function() return untilAttr(player, "Item_" .. item.id) end })
	end
end
for _, item in ipairs(Meals.Items) do
	table.insert(BOOSTS, { id = "Meal_" .. item.id, name = item.name, icon = item.uiIcon or "cup-soda", color = Color3.fromHex(item.uiColor or item.color),
		sub = string.gsub(item.sub or item.short or "", " · %d+ min$", ""), ends = function() return untilAttr(player, "Meal_" .. item.id) end })
end
ITEMS.boostCards = {}
for order, boost in ipairs(BOOSTS) do
	local card = Kit.Card({ Name = boost.id, LayoutOrder = order, Visible = false, Parent = ITEMS.boostGrid }, {})
	-- icon | name over what it does | the timer (gold) on the right
	local TIMER_W = 64
	Kit.IconTile(boost.icon, boost.color, 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, PAD, 0.5, 0), Parent = card })
	Kit.Fit(Kit.Text({ Name = "Name", Text = boost.name, Font = "Title", Position = UDim2.fromOffset(PAD + 38, 6), Size = UDim2.new(1, -(2 * PAD + 38 + TIMER_W), 0, 17),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card }), 14, 10)
	Kit.Fit(Kit.Text({ Name = "Sub", Text = boost.sub, Font = "Body", TextColor3 = Colors.Muted, Position = UDim2.fromOffset(PAD + 38, 24),
		Size = UDim2.new(1, -(2 * PAD + 38 + TIMER_W), 0, 15), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }), 12, 10)
	local timer = Kit.Fit(Kit.GoldText(Kit.Text({ Name = "Timer", Text = "", Font = "Number", AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PAD, 0.5, 0), Size = UDim2.fromOffset(TIMER_W, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })), 16, 10)
	ITEMS.boostCards[boost.id] = { card = card, timer = timer, boost = boost }
end

function ITEMS.refresh()
	local data = ClientData.Get()
	local tokens = data.dnaTokens or 0
	ITEMS.dna.count.Text = "x" .. Kit.Format(tokens)
	local running = 0
	for _, entry in pairs(ITEMS.boostCards) do
		local ends = entry.boost.ends()
		entry.card.Visible = ends ~= nil
		if ends then
			running += 1
			entry.timer.Text = if ends == math.huge then "Always on" else Meals.Clock(ends - serverNow())
		end
	end
	ITEMS.none.Visible = running == 0
	countLabel.Text = ""
end

------------------------------------------------------------------------
-- BOOSTS tab (Shared/UI/BoostsPanel)
------------------------------------------------------------------------
local BOOSTS_TAB = require(Shared.UI.BoostsPanel).Build(modal.body)
local GEAR_TAB = require(Shared.UI.GearPanel).Build(modal.body)

------------------------------------------------------------------------
function refresh()
	local data = ClientData.Get()
	grid.Visible = tab == "Titles"
	AURA.frame.Visible = tab == "Auras"
	ITEMS.frame.Visible = tab == "Items"
	BOOSTS_TAB.frame.Visible = tab == "Boosts"
	GEAR_TAB.frame.Visible = tab == "Gear"
	AURA.preview()
	if tab == "Gear" then
		GEAR_TAB.refresh()
		countLabel.Text = ""
		return
	elseif tab == "Boosts" then
		BOOSTS_TAB.refresh()
		countLabel.Text = ""
		return
	elseif tab == "Auras" then
		AURA.refresh()
		return
	elseif tab == "Items" then
		ITEMS.refresh()
		return
	end
	local owned = 0
	for _, title in ipairs(Titles.List) do
		local c = cards[title.id]
		local has = data.titles.owned[title.id] ~= nil
		local equipped = data.titles.equipped == title.id
		if has then owned += 1 end
		local secret = title.rarity == "Secret"
		c.name.Text = (secret and not has) and "???" or title.name
		c.name.TextTransparency = has and 0 or 0.45
		c.rarity.TextTransparency = has and 0 or 0.35
		c.button.Visible = has
		c.lock.Visible = not has
		if has then Kit.SetButton(c.button, "Green", equipped and "Equipped" or "Equip") end
		Theme.SetPiece(c.card, equipped and "card_gold" or "card")
	end
	countLabel.Text = owned .. " / " .. #Titles.List
end

-- the timers tick while the Items tab is open
task.spawn(function()
	while true do
		task.wait(0.5)
		if modal.isOpen() and tab == "Items" then ITEMS.refresh() end
		if modal.isOpen() and tab == "Boosts" then BOOSTS_TAB.refresh() end
	end
end)

local function open()
	menuButton:SetActive(true)
	menuButton:SetDot(false)
	UIBus.MenuPanelVisible:Fire(true)
	refresh()
	modal.open()
	Audio.PlayUI("Whoosh")
end
local function close()
	if not modal.isOpen() then return end
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
	modal.close()
end
-- opens on the last tab used (saved), unless a caller asks for one
local function openOn(wanted: string?)
	if not wanted then
		local saved = ClientData.IsLoaded() and ClientData.Get().settings and ClientData.Get().settings.inventoryTab
		wanted = if TABS[saved] then saved else tab
	end
	tab = wanted :: string
	modal.selectTab(tab)
	if not modal.isOpen() then UIBus.PanelOpened("Inventory") open() else refresh() end
end
UIBus.RegisterPanel("Inventory", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else openOn(nil) end
end)
modal.closeButton.Activated:Connect(function()
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
end)
UIBus.OpenInventory.Event:Connect(function(openTab, auraId)
	-- (the Store's Auras tab opens the Auras tab, with that aura picked)
	if openTab == "Auras" and type(auraId) == "string" and Auras.ById[auraId] then AURA.picked = auraId end
	openOn(if TABS[openTab] then openTab else nil)
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if (key == "titles" or key == "auras" or key == "coins" or key == "items" or key == "dnaTokens") and modal.isOpen() then refresh() end
end)
player.AttributeChanged:Connect(function(name)
	if (string.sub(name, 1, 5) == "Pass_" or name == "Aura") and modal.isOpen() then refresh() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "AuraUnlocked" and type(info) == "table" then
		local aura = Auras.ById[info.id]
		if aura then
			Notify.Toast("New aura!", aura.name .. (if info.bought then " is yours. Wearing it now." else ". Wear it in Inventory > Auras."), "sparkles",
				RARITY_COLOR[aura.rarity] or Colors.Gold, "aura" .. aura.id)
			Audio.PlayUI("TitleUnlocked")
		end
	elseif kind == "AuraBuyFailed" and type(info) == "table" then
		Notify.Toast("Not enough coins", "That aura costs " .. Kit.Format(tonumber(info.price) or 0) .. " coins", "coin", Colors.Red, "auracoins")
	end
	if kind == "TitleUnlocked" then
		local title = Titles.ById[info.id]
		if title then
			-- (prompt 20: a reward popup, queued with the others)
			Notify.Reward("NEW TITLE", title.name, "medal", RARITY_COLOR[title.rarity] or Colors.Gold, "TitleUnlocked")
			if not modal.isOpen() then menuButton:SetDot(true) end
		end
	end
end)
