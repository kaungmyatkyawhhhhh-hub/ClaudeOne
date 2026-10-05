-- TitlesClient: Titles button, the Title Book (locked titles show as ??? in rarity colors),
-- equip by tapping an owned title, and a corner note when a title unlocks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Titles = require(Shared.Config.Titles)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local Icons = require(Shared.UI.Icons)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local CARD = Vector2.new(200, 74)

------------------------------------------------------------------------
-- Side button under Stats
------------------------------------------------------------------------
local menuButton = SideMenu.Add("Titles", "Titles", Icons.Trophy, 2)
local button = menuButton.button

------------------------------------------------------------------------
-- Title Book
------------------------------------------------------------------------
local book = Theme.ScreenGui({ Name = "TitleBook", Enabled = false, DisplayOrder = 25, Parent = player.PlayerGui })
book.ScreenInsets = Enum.ScreenInsets.None -- the dim backdrop covers the top bar too
local backdrop = New("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Colors.Background,
	BackgroundTransparency = 0.45,
	Parent = book,
})
-- swallows taps on the backdrop so they never count as lifts
New("TextButton", { Name = "Blocker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = backdrop })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.8),
	Parent = Theme.SafeArea(backdrop),
}, {
	Theme.Limit(Vector2.new(440, 300), Vector2.new(720, 560)),
	Theme.Pad("L"),
	Theme.List(Vertical, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local header = New("Frame", { Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = panel })
Theme.Text({ Text = "Title Book", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local countLabel = Theme.Text({ Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(160, 24), Parent = header })
local exitButton = Theme.Button("Secondary", { Name = "Exit", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(96, Theme.MinTouch), Parent = header }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local grid = New("ScrollingFrame", {
	Name = "Grid",
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 1, -(Theme.MinTouch + Spacing.M)),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Colors.Muted,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = panel,
}, {
	New("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(Spacing.M, Spacing.M),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	New("UIPadding", { PaddingTop = UDim.new(0, Spacing.S), PaddingBottom = UDim.new(0, Spacing.S) }),
})

local cards = {}
local ordered = table.clone(Titles.List)
table.sort(ordered, function(a, b)
	local ra, rb = Titles.Rarities[a.rarity].order, Titles.Rarities[b.rarity].order
	if ra ~= rb then return ra < rb end
	return table.find(Titles.List, a) < table.find(Titles.List, b)
end)

for index, title in ipairs(ordered) do
	local outline = Theme.Stroke(Colors.Border, 1, Theme.Alpha.ButtonBorder)
	local card = New("TextButton", {
		Name = title.id,
		LayoutOrder = index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Parent = grid,
	}, {
		Theme.Round("Button"),
		outline,
		Theme.Pad("S"),
		Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	Theme.BindPress(card)
	local row = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = card },
		{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
	local disc = Theme.PlateDisc(Theme.Rarity[title.rarity], { LayoutOrder = 1, Size = UDim2.fromScale(1, 0.6), Parent = row })
	Theme.Aspect(1, Enum.DominantAxis.Height).Parent = disc
	local name = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -24, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local info = Theme.Text({ LayoutOrder = 2, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	cards[title.id] = { card = card, name = name, info = info, outline = outline, rarity = title.rarity }
	card.Activated:Connect(function()
		local data = ClientData.Get()
		if not data.titles.owned[title.id] then return end
		Remotes.PlayerAction:FireServer("EquipTitle", data.titles.equipped ~= title.id and title.id or nil)
	end)
end

local function refresh()
	local data = ClientData.Get()
	local owned = 0
	for _, title in ipairs(Titles.List) do
		local c = cards[title.id]
		local has = data.titles.owned[title.id] ~= nil
		local equipped = data.titles.equipped == title.id
		if has then owned += 1 end
		c.name.Text = has and title.name or "???"
		-- owned names are white; locked ones show ??? in their rarity color
		c.name.TextColor3 = has and Colors.Text or Theme.Rarity[c.rarity].Fill
		local secret = title.rarity == "Secret"
		if has then
			c.info.Text = (equipped and "Equipped · " or "") .. title.description
		else
			c.info.Text = secret and "Secret" or (title.rarity .. " · " .. title.description)
		end
		c.outline.Transparency = equipped and 0.25 or Theme.Alpha.ButtonBorder
		c.card.BackgroundTransparency = equipped and 0.4 or Theme.Alpha.Panel
	end
	countLabel.Text = owned .. " / " .. #Titles.List
end

local isOpen = false
local function open()
	isOpen = true
	menuButton:SetActive(true)
	menuButton:SetDot(false)
	UIBus.MenuPanelVisible:Fire(true)
	refresh()
	book.Enabled = true
	Audio.PlayUI("Whoosh")
	panel.Position = UDim2.new(0.5, 0, 0.5, Spacing.XL)
	Theme.Fade(backdrop, true)
	Theme.Tween(panel, { Position = UDim2.fromScale(0.5, 0.5) })
end
local function close()
	isOpen = false
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
	local tween = Theme.Fade(backdrop, false)
	if tween then
		tween.Completed:Connect(function()
			if not isOpen then book.Enabled = false end
		end)
	end
end
button.Activated:Connect(function()
	if isOpen then close() else open() end
end)
exitButton.Activated:Connect(close)
UIBus.OpenTitles.Event:Connect(function()
	if not isOpen then open() end
end)

ClientData.Changed:Connect(function(path)
	if path[1] == "titles" and isOpen then refresh() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "TitleUnlocked" then
		local title = Titles.ById[info.id]
		if title then
			Notify.Show("New title: " .. title.name, Theme.Rarity[title.rarity].Fill)
			Audio.PlayUI("TitleUnlocked")
			if not isOpen then menuButton:SetDot(true) end
		end
	end
end)
