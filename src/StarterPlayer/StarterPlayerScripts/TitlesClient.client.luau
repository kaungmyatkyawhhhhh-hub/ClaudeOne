-- TitlesClient: the Titles tile and the Titles window (owner's UI v2, mockup 08_titles), and a toast when a title unlocks.
-- Tabs All / Owned above the window; a 4-column grid of cards (it scrolls when there are more): the rarity word in its
-- color (COMMON gray, UNCOMMON green, RARE blue, EPIC purple, LEGENDARY gold, SECRET red), the title's name, and
--   owned:  EQUIPPED (gold, tap = take it off) or EQUIP (green, tap = wear it above your head)
--   locked: the name faded and a lock (secret titles show "???"); tapping it says how to earn it.
-- Titles are kept forever and never bought.
-- AURAS tab (owner, 14 Oct; Config.Auras, AuraService): on the left the picked aura big (its art, name, rarity, how to
-- get it, the action button) and "Aura: Off"; on the right a grid of aura tiles (art, name, rarity, and its state:
-- EQUIP / the gold EQUIPPED stamp / a coin price / AURA PACK or VIP (opens that pass's purchase) / locked + how to earn
-- it). (A live 3D preview isn't possible in a window: Roblox doesn't draw particles in a ViewportFrame; equipping shows
-- the aura on your character at full power for a few seconds.) The Store's Auras tab opens this tab (UIBus.OpenTitles).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Titles = require(Shared.Config.Titles)
local Auras = require(Shared.Config.Auras)
local Monetization = require(Shared.Config.Monetization)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local Icons = require(Shared.UI.Icons)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local New, Colors = Theme.New, Theme.Colors

-- the window's rarity colors (mockup 08)
local RARITY_COLOR = {
	Common = Color3.fromHex("#B8B8C4"), Uncommon = Colors.Green, Rare = Colors.Blue, Epic = Colors.Purple,
	Legendary = Color3.fromHex("#FFB04A"), Secret = Colors.Red,
}
local CARD = Vector2.new(124, 78)

local menuButton = SideMenu.Add("Titles", "Titles", Icons.Trophy, 2)

local tab = "All"
local refresh -- (below)
local modal = Kit.Modal({ name = "TitleBook", title = "Titles", icon = "medal", width = 560, height = 248, displayOrder = 25,
	tabs = { { id = "All", text = "All", icon = "medal" }, { id = "Owned", text = "Owned", icon = "star" }, { id = "Auras", text = "Auras", icon = "sparkles" } },
	onTab = function(id)
		tab = id
		refresh()
	end })
local countLabel = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 14, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -56, 0, 14), Size = UDim2.fromOffset(90, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = modal.panel })
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
	local rarity = Kit.Text({ Name = "Rarity", Text = string.upper(title.rarity), Font = "Title", TextSize = 11, TextColor3 = RARITY_COLOR[title.rarity] or Colors.Muted,
		Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 14), Parent = card })
	local name = Kit.Text({ Name = "TitleName", Text = title.name, Font = "Title", TextSize = 15, Position = UDim2.fromOffset(4, 21), Size = UDim2.new(1, -8, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local button = Kit.Button("Green", "Equip", { Name = "Equip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Parent = card },
		{ width = CARD.X - 18, height = 24, textSize = 13 })
	local lock = Pieces.Icon("lock", Colors.Faint, { Name = "Lock", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(20, 20), Parent = card })
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
AURA.frame = New("Frame", { Name = "Auras", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = modal.body })
-- the preview card (left)
AURA.preview = Kit.Card({ Name = "Preview", Piece = "card_gold", Size = UDim2.new(0, 156, 1, 0), Parent = AURA.frame }, {})
AURA.bigIcon = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(78, 78), ScaleType = Enum.ScaleType.Fit, Parent = AURA.preview })
AURA.bigName = Kit.GoldText(Kit.Text({ Name = "Name", Text = "", Font = "Title", TextSize = 17, Upper = true, Position = UDim2.fromOffset(8, 88),
	Size = UDim2.new(1, -16, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = AURA.preview }))
AURA.bigRarity = Kit.Text({ Name = "Rarity", Text = "", Font = "Title", TextSize = 11, Position = UDim2.fromOffset(8, 108), Size = UDim2.new(1, -16, 0, 14), Parent = AURA.preview })
AURA.bigHow = Kit.Text({ Name = "How", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(8, 122),
	Size = UDim2.new(1, -16, 0, 14), Parent = AURA.preview })
AURA.action = Kit.Button("Green", "Equip", { Name = "Action", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -38), Parent = AURA.preview },
	{ width = 136, height = 28, textSize = 13 })
AURA.off = Kit.Button("Quiet", "Aura: Off", { Name = "Off", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = AURA.preview },
	{ width = 136, height = 26, textSize = 12 })
-- the tiles (right)
AURA.grid = New("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(164, 0), Size = UDim2.new(1, -164, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = AURA.frame }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(112, 104), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})

function AURA.has(aura): boolean
	if aura.unlock.type == "pass" then return Players.LocalPlayer:GetAttribute("Pass_" .. aura.unlock.pass) == true end
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
	return "locked", aura.how, "Disabled"
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
		if pass and pass.id then MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.id) end
	else
		Notify.Toast(aura.name, aura.how .. " to unlock it.", "lock", Colors.Muted, "aurainfo")
	end
end

for index, aura in ipairs(Auras.List) do
	local tile = Kit.Card({ Name = aura.id, LayoutOrder = index, Clickable = true, Parent = AURA.grid }, {})
	local art = New("ImageLabel", { Name = "Art", Image = aura.Icon, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(42, 42), ScaleType = Enum.ScaleType.Fit, Parent = tile })
	Kit.Text({ Name = "AuraName", Text = aura.name, Font = "Title", TextSize = 12, Upper = true, Position = UDim2.fromOffset(4, 46), Size = UDim2.new(1, -8, 0, 15),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = tile })
	Kit.Text({ Name = "Rarity", Text = string.upper(aura.rarity), Font = "Title", TextSize = 9, TextColor3 = RARITY_COLOR[aura.rarity] or Colors.Muted,
		Position = UDim2.fromOffset(4, 61), Size = UDim2.new(1, -8, 0, 11), Parent = tile })
	local button = Kit.Button("Green", "Equip", { Name = "State", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = tile },
		{ width = 100, height = 22, textSize = 10 })
	AURA.tiles[aura.id] = { tile = tile, art = art, button = button, aura = aura }
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
		Kit.SetButton(t.button, style, text)
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

function refresh()
	local data = ClientData.Get()
	grid.Visible = tab ~= "Auras"
	AURA.frame.Visible = tab == "Auras"
	if tab == "Auras" then
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
		c.card.Visible = tab == "All" or has
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
UIBus.RegisterPanel("Titles", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else UIBus.PanelOpened("Titles") open() end
end)
modal.closeButton.Activated:Connect(function()
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
end)
UIBus.OpenTitles.Event:Connect(function(openTab, auraId)
	-- (the Store's Auras tab opens the Auras tab, with that aura picked)
	if openTab == "Auras" then
		tab = "Auras"
		if type(auraId) == "string" and Auras.ById[auraId] then AURA.picked = auraId end
		modal.selectTab("Auras")
	end
	if not modal.isOpen() then UIBus.PanelOpened("Titles") open() else refresh() end
end)

ClientData.Changed:Connect(function(path)
	if (path[1] == "titles" or path[1] == "auras" or path[1] == "coins") and modal.isOpen() then refresh() end
end)
Players.LocalPlayer.AttributeChanged:Connect(function(name)
	if (string.sub(name, 1, 5) == "Pass_" or name == "Aura") and modal.isOpen() then refresh() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "AuraUnlocked" and type(info) == "table" then
		local aura = Auras.ById[info.id]
		if aura then
			Notify.Toast("New aura!", aura.name .. (if info.bought then " is yours. Wearing it now." else ". Wear it in Titles > Auras."), "sparkles",
				RARITY_COLOR[aura.rarity] or Colors.Gold, "aura" .. aura.id)
			Audio.PlayUI("TitleUnlocked")
		end
	elseif kind == "AuraBuyFailed" and type(info) == "table" then
		Notify.Toast("Not enough coins", "That aura costs " .. Kit.Format(tonumber(info.price) or 0) .. " coins", "coin", Colors.Red, "auracoins")
	end
	if kind == "TitleUnlocked" then
		local title = Titles.ById[info.id]
		if title then
			Notify.Toast("New title!", title.name, "medal", RARITY_COLOR[title.rarity] or Colors.Gold)
			Audio.PlayUI("TitleUnlocked")
			if not modal.isOpen() then menuButton:SetDot(true) end
		end
	end
end)
