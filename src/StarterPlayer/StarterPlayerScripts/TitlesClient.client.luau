-- TitlesClient: the Titles tile and the Titles window (owner's UI v2, mockup 08_titles), and a toast when a title unlocks.
-- Tabs All / Owned above the window; a 4-column grid of cards (it scrolls when there are more): the rarity word in its
-- color (COMMON gray, UNCOMMON green, RARE blue, EPIC purple, LEGENDARY gold, SECRET red), the title's name, and
--   owned:  EQUIPPED (gold, tap = take it off) or EQUIP (green, tap = wear it above your head)
--   locked: the name faded and a lock (secret titles show "???"); tapping it says how to earn it.
-- Titles are kept forever and never bought.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Titles = require(Shared.Config.Titles)
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
	tabs = { { id = "All", text = "All", icon = "medal" }, { id = "Owned", text = "Owned", icon = "star" } },
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

function refresh()
	local data = ClientData.Get()
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
		if has then Kit.SetButton(c.button, equipped and "Gold" or "Green", equipped and "Equipped" or "Equip") end
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
UIBus.OpenTitles.Event:Connect(function()
	if not modal.isOpen() then UIBus.PanelOpened("Titles") open() end
end)

ClientData.Changed:Connect(function(path)
	if path[1] == "titles" and modal.isOpen() then refresh() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "TitleUnlocked" then
		local title = Titles.ById[info.id]
		if title then
			Notify.Toast("New title!", title.name, "medal", RARITY_COLOR[title.rarity] or Colors.Gold)
			Audio.PlayUI("TitleUnlocked")
			if not modal.isOpen() then menuButton:SetDot(true) end
		end
	end
end)
