-- WardrobeClient: the clothing store screen (opened from the store counter's Shop prompt in the town hub) and the
-- Wardrobe side button + panel (wear or take off owned gear). Items come from Config.Cosmetics; the server validates
-- every buy and wear (CosmeticService). Buying takes two taps ("Tap again to buy") so nobody buys by accident.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Body = require(Shared.Config.Body)
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

local CARD = Vector2.new(200, 92)
local CONFIRM_TIME = 3 -- seconds a "Tap again to buy" waits

local function state()
	local data = ClientData.Get()
	local c = data.cosmetics or {}
	return c.owned or {}, c.equipped or {}, data.coins or 0
end

-- a round color swatch (the item's own color)
local function swatch(props, color)
	props.BackgroundColor3 = color
	return New("Frame", props, { Theme.Round("Round"), Theme.Stroke(Colors.Border, 1, 0.6) })
end

------------------------------------------------------------------------
-- Store screen (modal, like the Title Book)
------------------------------------------------------------------------
local storeGui = Theme.ScreenGui({ Name = "ClothingStore", Enabled = false, DisplayOrder = 25, Parent = player:WaitForChild("PlayerGui") })
storeGui.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.45, Parent = storeGui })
New("TextButton", { Name = "Blocker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = backdrop })
local storePanel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.8),
	Parent = Theme.SafeArea(backdrop),
}, {
	Theme.Limit(Vector2.new(440, 280), Vector2.new(720, 560)),
	Theme.Pad("L"),
	Theme.List(Vertical, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local storeHeader = New("Frame", { Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = storePanel })
Theme.Text({ Text = "Gear and fits", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = storeHeader })
local coinsLabel = Theme.Text({ Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.55, 0.5), Size = UDim2.fromOffset(160, 24), Parent = storeHeader })
local storeClose = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(96, Theme.MinTouch), Parent = storeHeader }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local storeGrid = New("ScrollingFrame", {
	Name = "Grid",
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 1, -(Theme.MinTouch + Spacing.M)),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Colors.Muted,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = storePanel,
}, {
	New("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(Spacing.M, Spacing.M),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	New("UIPadding", { PaddingTop = UDim.new(0, Spacing.S), PaddingBottom = UDim.new(0, Spacing.S) }),
})

local storeCards = {}
local confirming = nil -- itemId waiting for its second tap

local function refreshStore()
	local owned, equipped, coins = state()
	coinsLabel.Text = coins .. " coins"
	for id, card in pairs(storeCards) do
		local item = Cosmetics.ById[id]
		if owned[id] then
			local using = Cosmetics.SlotById[item.slot].verb == "Using"
			card.status.Text = equipped[item.slot] == id and (using and "Using · tap to stop" or "Wearing · tap to take off") or (using and "Owned · tap to use" or "Owned · tap to wear")
			card.status.TextColor3 = Colors.Text
		elseif confirming == id then
			card.status.Text = "Tap again to buy"
			card.status.TextColor3 = Colors.Text
		else
			card.status.Text = item.price .. " coins"
			card.status.TextColor3 = coins >= item.price and Colors.Text or Colors.Muted
		end
		card.outline.Transparency = equipped[item.slot] == id and 0.25 or Theme.Alpha.ButtonBorder
	end
end

for _, item in ipairs(Cosmetics.Items) do
	local outline = Theme.Stroke(Colors.Border, 1, Theme.Alpha.ButtonBorder)
	local card = New("TextButton", {
		Name = item.id,
		LayoutOrder = item.order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Parent = storeGrid,
	}, { Theme.Round("Button"), outline, Theme.Pad("S"), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	Theme.BindPress(card)
	local row = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = card }, { Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
	swatch({ LayoutOrder = 1, Size = UDim2.fromOffset(24, 24) }, item.color).Parent = row
	Theme.Text({ LayoutOrder = 2, Text = item.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -32, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	Theme.Text({ LayoutOrder = 2, Text = Cosmetics.SlotById[item.slot].name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local status = Theme.Text({ LayoutOrder = 3, Font = "SemiBold", TextSize = "Small", Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	storeCards[item.id] = { card = card, status = status, outline = outline }
	card.Activated:Connect(function()
		local owned, _, coins = state()
		if owned[item.id] then
			Remotes.PlayerAction:FireServer("EquipCosmetic", item.id)
			Audio.PlayUI("Click")
			return
		end
		if coins < item.price then
			Notify.Show("You need " .. item.price .. " coins for the " .. item.name:lower() .. ".", nil, "store")
			return
		end
		if confirming ~= item.id then
			confirming = item.id
			refreshStore()
			task.delay(CONFIRM_TIME, function()
				if confirming == item.id then confirming = nil refreshStore() end
			end)
			return
		end
		confirming = nil
		Remotes.PlayerAction:FireServer("BuyCosmetic", item.id)
	end)
end

local storeOpen = false
local function openStore()
	if storeOpen then return end
	storeOpen = true
	confirming = nil
	refreshStore()
	storeGui.Enabled = true
	Audio.PlayUI("Whoosh")
	storePanel.Position = UDim2.new(0.5, 0, 0.5, Spacing.XL)
	Theme.Fade(backdrop, true)
	Theme.Tween(storePanel, { Position = UDim2.fromScale(0.5, 0.5) })
end
local function closeStore()
	if not storeOpen then return end
	storeOpen = false
	local tween = Theme.Fade(backdrop, false)
	if tween then
		tween.Completed:Connect(function() if not storeOpen then storeGui.Enabled = false end end)
	else
		storeGui.Enabled = false
	end
end
storeClose.Activated:Connect(closeStore)

------------------------------------------------------------------------
-- Wardrobe: side button + panel beside the side menu
------------------------------------------------------------------------
local menuButton = SideMenu.Add("Wardrobe", "Wardrobe", Icons.Hanger, 6)
local wardrobeGui = Theme.ScreenGui({ Name = "Wardrobe", Enabled = false, DisplayOrder = 24, Parent = player:WaitForChild("PlayerGui") })
local wardrobePanel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 0.5, 0),
	Size = UDim2.new(0, 280, 1, -Spacing.L * 2),
	Active = true, -- taps on the panel never count as lifts
	Parent = wardrobeGui,
}, { Theme.Pad("M"), New("UISizeConstraint", { MaxSize = Vector2.new(280, 440) }) })
local wardrobeList = New("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Colors.Muted,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = wardrobePanel,
}, { Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

local function clearWardrobe()
	for _, child in ipairs(wardrobeList:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function refreshWardrobe()
	clearWardrobe()
	local owned, equipped = state()
	local order = 0
	local function nextOrder() order += 1 return order end
	Theme.Text({ LayoutOrder = nextOrder(), Text = "Wardrobe", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Parent = wardrobeList })
	-- body: top and shorts color (the game's own gym look)
	local settings = (ClientData.Get() or {}).settings or {}
	local function choice(label, id, selected, color, onPick)
		local button = Theme.Button(selected and "Primary" or "Secondary", { Name = label, LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, Theme.MinTouch), Parent = wardrobeList },
			{ Theme.Pad("S"), Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
		if color then swatch({ LayoutOrder = 1, Size = UDim2.fromOffset(22, 22) }, color).Parent = button end
		Theme.Text({ LayoutOrder = 2, Text = label, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -40, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = button })
		button.Activated:Connect(function()
			onPick(id)
			Audio.PlayUI("Click")
		end)
	end
	Theme.Text({ LayoutOrder = nextOrder(), Text = "Top", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = wardrobeList })
	for _, entry in ipairs(Body.Tops) do
		choice(entry.name, entry.id, (settings.top or Body.DefaultTop) == entry.id, entry.color, function(id) Remotes.PlayerAction:FireServer("SetSettings", { top = id }) end)
	end
	Theme.Text({ LayoutOrder = nextOrder(), Text = "Shorts", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = wardrobeList })
	for _, entry in ipairs(Body.ShortsColors) do
		choice(entry.name, entry.id, (settings.shorts or Body.DefaultShorts) == entry.id, entry.color, function(id) Remotes.PlayerAction:FireServer("SetSettings", { shorts = id }) end)
	end
	local any = false
	for _, slot in ipairs(Cosmetics.Slots) do
		local items = {}
		for _, item in ipairs(Cosmetics.Items) do
			if item.slot == slot.id and owned[item.id] then table.insert(items, item) end
		end
		if #items > 0 then
			any = true
			Theme.Text({ LayoutOrder = nextOrder(), Text = slot.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = wardrobeList })
			for _, item in ipairs(items) do
				local wearing = equipped[slot.id] == item.id
				local button = Theme.Button(wearing and "Primary" or "Secondary", { Name = item.id, LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, Theme.MinTouch), Parent = wardrobeList },
					{ Theme.Pad("S"), Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
				swatch({ LayoutOrder = 1, Size = UDim2.fromOffset(22, 22) }, item.color).Parent = button
				Theme.Text({ LayoutOrder = 2, Text = item.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -110, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = button })
				Theme.Text({ LayoutOrder = 3, Text = (slot.verb == "Using") and (wearing and "Stop" or "Use") or (wearing and "Take off" or "Wear"), Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0, 70, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = button })
				button.Activated:Connect(function()
					Remotes.PlayerAction:FireServer("EquipCosmetic", item.id)
					Audio.PlayUI("Click")
				end)
			end
		end
	end
	if not any then
		Theme.Text({ LayoutOrder = nextOrder(), Text = "No gear yet. The clothing store across the street from the gym sells belts, headbands, wraps and shakers.",
			Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = wardrobeList })
	end
end

local wardrobeOpen = false
local function closeWardrobe()
	if not wardrobeOpen then return end
	wardrobeOpen = false
	menuButton:SetActive(false)
	local tween = Theme.Fade(wardrobePanel, false)
	if tween then
		tween.Completed:Connect(function() if not wardrobeOpen then wardrobeGui.Enabled = false end end)
	end
end
local function openWardrobe()
	wardrobeOpen = true
	menuButton:SetActive(true)
	menuButton:SetDot(false)
	wardrobePanel.Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 0.5, 0) -- beside the side menu (one or two columns)
	refreshWardrobe()
	wardrobeGui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(wardrobePanel, true)
end
menuButton.Activated:Connect(function()
	if wardrobeOpen then closeWardrobe() else openWardrobe() end
end)

------------------------------------------------------------------------
-- Data + server events
------------------------------------------------------------------------
ClientData.Changed:Connect(function(path)
	if path[1] == "cosmetics" or path[1] == "coins" then
		if storeOpen then refreshStore() end
		if wardrobeOpen and path[1] == "cosmetics" then refreshWardrobe() end
	end
	if path[1] == "settings" and wardrobeOpen then refreshWardrobe() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "OpenClothingStore" then
		if not UIBus.MenuOpen then openStore() end
	elseif kind == "CosmeticBought" then
		if info.failed then
			Notify.Show("You need " .. tostring(info.price) .. " coins for that.", nil, "store")
		else
			local item = Cosmetics.ById[info.id]
			Notify.Show("Bought: " .. (item and item.name or "gear") .. ". Change it any time in the Wardrobe.", nil, "store")
			Audio.PlayUI("LevelUp")
			menuButton:SetDot(not wardrobeOpen)
		end
	end
end)
