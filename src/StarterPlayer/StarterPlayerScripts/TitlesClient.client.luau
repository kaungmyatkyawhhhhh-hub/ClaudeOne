-- TitlesClient: the INVENTORY tile and window (owner, 14 Oct: was the Titles window), and the unlock toasts.
-- (prompt 28, 21 Oct: 7 tabs -> 3) Tabs ITEMS | GEAR | LOOKS; the last one opened is remembered (settings.inventoryTab).
-- A tab shows once its feature is open for you: GEAR when you own something to wear (or from Growth Spurt 2, the PUMP
-- SHOP's gear), LOOKS when you own a title, an aura or an alter (or from Growth Spurt 1). ITEMS is always there.
-- Trainers are not here: they live in the TRAINERS window (TrainerClient, its MY TRAINERS tab).
--   ITEMS (Shared/UI/BoostsPanel): the boost items you own with USE and EQUIP, DNA Tokens ("Genetics"), and the boosts
--     running now (passes, Endless Stamina, drinks, a Server Boost) with their timers. Empty: "Get boosts at the PUMP SHOP".
--   GEAR (Shared/UI/GearPanel): what you own to wear (PUMP SHOP gear and apparel, the clothing store's gear).
--   LOOKS: filter chips on top (All / Alters / Auras / Titles):
--     ALL     everything you own, one big tile each (art, name, ALTER / AURA / TITLE in its rarity color; the ones you
--             wear say WORN in gold on a gold card); a tap opens its chip.
--     ALTERS  Shared/UI/AltersPanel.
--     AURAS   on the left the picked aura big (its art, name, rarity, how to get it, the action button) and "Aura: Off"; on
--             the right a grid of aura tiles (art, name, rarity, and its state: EQUIP / EQUIPPED / a coin price / AURA PACK
--             or VIP (opens that pass's purchase) / how to earn it). The preview is your own character behind the window
--             wearing the picked aura at full power (Roblox doesn't draw particles inside a ViewportFrame; AURA.preview).
--     TITLES  a grid of cards (it scrolls): the rarity word in its color (COMMON gray, UNCOMMON green, RARE blue, EPIC
--             purple, LEGENDARY gold, SECRET red), the title's name, and owned: EQUIPPED (gold, tap = take it off) or EQUIP
--             (green, tap = wear it above your head); locked: the name faded and a lock (secret titles show "???"); tapping
--             it says how to earn it. Titles are kept forever and never bought.
-- Text fit (owner, 14 Oct): every label stays inside its card with 8 px each side; names and rarity words shrink to fit
-- one line (Kit.Fit), how-to-unlock text is the body font in sentence case, up to 2 lines.
-- UIBus.OpenInventory(tab, auraId?) opens it on a tab; the old tab names still work ("Boosts" -> ITEMS, "Titles" / "Auras"
-- / "Alters" -> LOOKS on that chip, "Trainers" -> the TRAINERS window).
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
local CARD = Vector2.new(152, 84) -- (prompt 28: bigger, 5 a row)
local PAD = 8 -- every label keeps this far from its card's edges
-- (prompt 28) a tab name, old or new -> the tab, and the LOOKS chip
local TAB_OF = { Items = "Items", Boosts = "Items", Gear = "Gear", Looks = "Looks", Alters = "Looks", Auras = "Looks", Titles = "Looks" }
local LOOK_OF = { Alters = "Alters", Auras = "Auras", Titles = "Titles" }
local CHIP_H = Kit.TabHeight

local menuButton = SideMenu.Add("Inventory", "Inventory", nil, 2)

local tab = "Items"
local look = "All" -- the LOOKS chip
local refresh -- (below)
-- (840 x 290: room for 5 big tiles a row, and the LOOKS chips over the Auras preview card; it still fits a 667 x 375 phone)
local modal = Kit.Modal({ name = "Inventory", title = "Inventory", icon = "backpack", width = 840, height = 290, displayOrder = 25,
	tabs = { { id = "Items", text = "Items", icon = "zap" }, { id = "Gear", text = "Gear", icon = "dumbbell" }, { id = "Looks", text = "Looks", icon = "sparkles" } },
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
-- LOOKS tab: the chips, and the place the four views share under them
------------------------------------------------------------------------
local LOOKS = {}
LOOKS.frame = New("Frame", { Name = "Looks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = modal.body })
local _chips, selectChip = Kit.Tabs({ { id = "All", text = "All" }, { id = "Alters", text = "Alters" }, { id = "Auras", text = "Auras" }, { id = "Titles", text = "Titles" } },
	function(id)
		look = id
		Audio.PlayUI("Click")
		refresh()
	end, { Name = "Chips", Size = UDim2.fromOffset(0, CHIP_H), Parent = LOOKS.frame })
LOOKS.body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, CHIP_H + 8), Size = UDim2.new(1, 0, 1, -(CHIP_H + 8)),
	Parent = LOOKS.frame })

------------------------------------------------------------------------
-- LOOKS > TITLES
------------------------------------------------------------------------
local grid = New("ScrollingFrame", { Name = "Titles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = LOOKS.body }, {
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
-- LOOKS > AURAS
------------------------------------------------------------------------
local AURA = { tiles = {}, picked = Auras.List[1].id }
local TILE = Vector2.new(120, 104) -- (prompt 28: bigger, 5 a row)
AURA.frame = New("Frame", { Name = "Auras", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = LOOKS.body })
-- the preview card (left)
AURA.preview = Kit.Card({ Name = "Preview", Piece = "card_gold", Size = UDim2.new(0, 156, 1, 0), Parent = AURA.frame }, {})
-- (prompt 28: a little shorter, the LOOKS chips sit above it)
AURA.bigIcon = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(60, 60), ScaleType = Enum.ScaleType.Fit, Parent = AURA.preview })
AURA.bigName = Kit.Fit(Kit.GoldText(Kit.Text({ Name = "Name", Text = "", Font = "Title", Upper = true, Position = UDim2.fromOffset(PAD, 68),
	Size = UDim2.new(1, -2 * PAD, 0, 20), Parent = AURA.preview })), 17, 10)
AURA.bigRarity = Kit.Fit(Kit.Text({ Name = "Rarity", Text = "", Font = "Title", Position = UDim2.fromOffset(PAD, 88), Size = UDim2.new(1, -2 * PAD, 0, 14),
	Parent = AURA.preview }), 11, 10)
-- how to get it: the body font, sentence case, up to 2 lines
AURA.bigHow = Kit.Fit(Kit.Text({ Name = "How", Text = "", Font = "Body", TextColor3 = Colors.Muted, Position = UDim2.fromOffset(PAD, 102),
	Size = UDim2.new(1, -2 * PAD, 0, 24), TextYAlignment = Enum.TextYAlignment.Top, Parent = AURA.preview }), 12, 9, 2)
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
	local aura = modal.isOpen() and tab == "Looks" and look == "Auras" and Auras.ById[AURA.picked] or nil
	local want = aura and aura.vfx or nil
	if player:GetAttribute("AuraPreview") ~= want then player:SetAttribute("AuraPreview", want) end
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(AURA.preview) end)

------------------------------------------------------------------------
-- ITEMS tab (Shared/UI/BoostsPanel): the boost items, DNA Tokens and the boosts running now
------------------------------------------------------------------------
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
local ITEMS_TAB = require(Shared.UI.BoostsPanel).Build(modal.body, {
	running = BOOSTS,
	dna = {
		count = function() return ClientData.Get().dnaTokens or 0 end,
		onUse = function()
			modal.close()
			menuButton:SetActive(false)
			UIBus.MenuPanelVisible:Fire(false)
			UIBus.OpenGenetics:Fire()
		end,
	},
})
local GearPanel = require(Shared.UI.GearPanel)
local GEAR_TAB = GearPanel.Build(modal.body)
local ALTERS_TAB = require(Shared.UI.AltersPanel).Build(LOOKS.body) -- (prompt 21) the Body Alter skins

------------------------------------------------------------------------
-- LOOKS > ALL: everything you own, one tile each; a tap opens its chip
------------------------------------------------------------------------
local Alters = require(Shared.Config.Alters)
local ALL = {}
local ALL_TILE = Vector2.new(152, 96)
ALL.grid = New("ScrollingFrame", { Name = "All", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = LOOKS.body }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(ALL_TILE.X, ALL_TILE.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})
ALL.empty = Kit.Text({ Name = "Empty", Text = "No looks yet. Earn titles by training, and get auras in the <font color=\"#F6C75A\">SHOP</font>.", RichText = true,
	Font = "Strong", TextSize = 15, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -20, 0, 22), Visible = false, Parent = LOOKS.body })

-- one tile: the art on top, the name, the kind in its color; worn = a gold card with WORN
local function lookTile(order: number, kind: string, kindColor: Color3, label: string, worn: boolean, makeArt: (Instance) -> (), onTap: () -> ())
	local tile = Kit.Card({ Name = kind .. "_" .. label, LayoutOrder = order, Clickable = true, Parent = ALL.grid }, {})
	Theme.SetPiece(tile, if worn then "card_gold" else "card")
	local art = New("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(40, 40), Parent = tile })
	makeArt(art)
	Kit.Fit(Kit.Text({ Name = "LookName", Text = label, Font = "Title", Upper = true, Position = UDim2.fromOffset(PAD, 52), Size = UDim2.new(1, -2 * PAD, 0, 18),
		Parent = tile }), 14, 9)
	Kit.Fit(Kit.Text({ Name = "Kind", Text = if worn then string.upper(kind) .. " · WORN" else string.upper(kind), Font = "Title",
		TextColor3 = if worn then Colors.Gold else kindColor, Position = UDim2.fromOffset(PAD, 72), Size = UDim2.new(1, -2 * PAD, 0, 14), Parent = tile }), 11, 9)
	tile.Activated:Connect(function()
		Audio.PlayUI("Click")
		onTap()
	end)
end
local function openChip(id: string)
	look = id
	selectChip(id)
	refresh()
end

function ALL.refresh()
	for _, child in ipairs(ALL.grid:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local data = ClientData.Get()
	local n = 0
	-- the alters you've reached
	local state = Alters.State(data)
	for _, alter in ipairs(Alters.List) do
		if alter.number <= (state.highest or 0) then
			n += 1
			lookTile(alter.number, "Alter", Colors.Red, alter.name, alter.number == (state.equipped or 0), function(holder)
				-- (its skin: the alter's color map tinted with your skin color, like the Alters view)
				local skin = player:GetAttribute("SkinColor")
				if typeof(skin) ~= "Color3" then skin = Color3.fromHex("#E0A878") end
				New("ImageLabel", { Name = "Swatch", Image = alter.textures and alter.textures.color or "", ImageColor3 = Alters.Tint(alter.id, skin), ScaleType = Enum.ScaleType.Crop,
					BackgroundColor3 = if alter.textures then skin else Color3.fromHex(alter.placeholder or "#C98A12"), Size = UDim2.fromScale(1, 1), Parent = holder },
					{ New("UICorner", { CornerRadius = UDim.new(1, 0) }), New("UIStroke", { Color = Colors.Outline, Thickness = 2 }) })
			end, function() openChip("Alters") end)
		end
	end
	for index, aura in ipairs(Auras.List) do
		if AURA.has(aura) then
			n += 1
			lookTile(1000 + index, "Aura", RARITY_COLOR[aura.rarity] or Colors.Muted, aura.name, AURA.equipped() == aura.id, function(holder)
				New("ImageLabel", { Name = "Icon", Image = aura.Icon, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Parent = holder })
			end, function()
				AURA.picked = aura.id
				openChip("Auras")
			end)
		end
	end
	for index, title in ipairs(ordered) do
		if data.titles.owned[title.id] then
			n += 1
			lookTile(2000 + index, "Title", RARITY_COLOR[title.rarity] or Colors.Muted, title.name, data.titles.equipped == title.id, function(holder)
				local icon = Pieces.Icon("medal", RARITY_COLOR[title.rarity] or Colors.Gold, { Size = UDim2.fromScale(1, 1), Parent = holder })
				icon:SetAttribute("KeepColor", true)
			end, function() openChip("Titles") end)
		end
	end
	ALL.empty.Visible = n == 0
	ALL.grid.Visible = n > 0
	countLabel.Text = if n > 0 then n .. " owned" else ""
end

------------------------------------------------------------------------
-- Which tabs show (prompt 28: hidden until their feature is open for you)
------------------------------------------------------------------------
local function ownsLooks(data): boolean
	if data.titles and data.titles.owned and next(data.titles.owned) ~= nil then return true end
	if data.auras and data.auras.owned and next(data.auras.owned) ~= nil then return true end
	for _, aura in ipairs(Auras.List) do
		if aura.unlock.type == "pass" and AURA.has(aura) then return true end
	end
	return (Alters.State(data).highest or 0) > 0
end
local function tabShown(id: string): boolean
	if not ClientData.IsLoaded() then return id == "Items" end
	local data = ClientData.Get()
	local spurts = data.growthSpurts or 0
	if id == "Gear" then return spurts >= 2 or GearPanel.Count(data) > 0 end
	if id == "Looks" then return spurts >= 1 or ownsLooks(data) end
	return true
end
local tabRow = modal.panel:FindFirstChild("Tabs", true)
local function refreshTabs()
	for _, id in ipairs({ "Items", "Gear", "Looks" }) do
		local button = tabRow and tabRow:FindFirstChild(id)
		if button then button.Visible = tabShown(id) end
	end
end

------------------------------------------------------------------------
function refresh()
	local data = ClientData.Get()
	refreshTabs()
	if not tabShown(tab) then
		tab = "Items"
		modal.selectTab(tab)
	end
	local looks = tab == "Looks"
	LOOKS.frame.Visible = looks
	ITEMS_TAB.frame.Visible = tab == "Items"
	GEAR_TAB.frame.Visible = tab == "Gear"
	ALL.grid.Visible = looks and look == "All"
	ALL.empty.Visible = false
	grid.Visible = looks and look == "Titles"
	AURA.frame.Visible = looks and look == "Auras"
	ALTERS_TAB.frame.Visible = looks and look == "Alters"
	AURA.preview()
	countLabel.Text = ""
	if tab == "Items" then
		ITEMS_TAB.refresh()
		return
	elseif tab == "Gear" then
		GEAR_TAB.refresh()
		return
	elseif look == "All" then
		ALL.refresh()
		return
	elseif look == "Alters" then
		ALTERS_TAB.refresh()
		return
	elseif look == "Auras" then
		AURA.refresh()
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
		if modal.isOpen() and tab == "Items" then ITEMS_TAB.refresh() end
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
		wanted = if TAB_OF[saved] then saved else tab
	end
	-- (old names: "Titles" opens LOOKS on its chip)
	if LOOK_OF[wanted :: string] then
		look = LOOK_OF[wanted :: string]
		selectChip(look)
	end
	tab = TAB_OF[wanted :: string] or "Items"
	if not tabShown(tab) then tab = "Items" end
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
	-- (prompt 28) trainers live in the TRAINERS window now
	if openTab == "Trainers" then
		UIBus.OpenAgency:Fire("My")
		return
	end
	openOn(if TAB_OF[openTab] then openTab else nil)
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if (key == "titles" or key == "auras" or key == "coins" or key == "items" or key == "dnaTokens" or key == "alter" or key == "cosmetics"
		or key == "growthSpurts") and modal.isOpen() then refresh() end
end)
player.AttributeChanged:Connect(function(name)
	if (string.sub(name, 1, 5) == "Pass_" or name == "Aura") and modal.isOpen() then refresh() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "AuraUnlocked" and type(info) == "table" then
		local aura = Auras.ById[info.id]
		if aura then
			Notify.Toast("New aura!", aura.name .. (if info.bought then " is yours. Wearing it now." else ". Wear it in Inventory > Looks."), "sparkles",
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
