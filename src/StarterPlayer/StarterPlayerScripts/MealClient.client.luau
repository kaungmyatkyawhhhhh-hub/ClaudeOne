-- MealClient (owner's feature run, task 5): the smoothie bar's shop panel and the boost timers. MealService opens the
-- panel when you press a stall's prompt and checks every purchase; this only shows them.
--   * Shop panel (centre): the stall's items with what they do, the price and BUY (dimmed when you can't afford it).
--     Closes with X, Esc or when you walk away from the stall.
--   * Timers: one small pill per running boost at the top of the right column ("Protein Shake 4:32"), from the player
--     attributes Meal_<id> (server time the boost ends).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meals = require(Shared.Config.Meals)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local RightColumn = require(Shared.UI.RightColumn)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Meals", 60) :: RemoteEvent
if not remote then return end -- the meal service didn't start

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local function now() return Workspace:GetServerTimeNow() end
local iconOf -- (defined with the shop below)

------------------------------------------------------------------------
-- Shop panel
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "MealShop", Enabled = false, DisplayOrder = 25, Parent = playerGui })
local panel = Theme.Panel({
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = true, Parent = gui,
}, { Theme.Pad("L"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local header = New("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = panel })
local title = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -52, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
Theme.Uppercase(title)
local close = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = header }, {})
local closeIcon = New("Frame", { Size = UDim2.fromScale(0.42, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = close })
Icons.Close(Colors.Text).Parent = closeIcon
local coinsLine = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local rows = {} -- the current shop's rows

-- an item's icon (a cup with a straw, or a bowl) in the item's color
iconOf = function(item)
	local factory = Icons[item.icon or "Cup"] or Icons.Cup
	return factory(Color3.fromHex(item.color))
end
local openShop = nil -- shop id while open
local openPart = nil -- the stall part (closes when you walk away)

local function setOpen(shopId: string?)
	if shopId == openShop then return end
	openShop = shopId
	if shopId then
		gui.Enabled = true
		Audio.PlayUI("Whoosh")
		Theme.Fade(panel, true)
	else
		local tween = Theme.Fade(panel, false)
		if tween then
			tween.Completed:Connect(function() if not openShop then gui.Enabled = false end end)
		else
			gui.Enabled = false
		end
	end
end

local function refreshAffordable()
	local coins = ClientData.Get().coins or 0
	coinsLine.Text = "You have " .. coins .. " coins"
	local t = now()
	for _, row in ipairs(rows) do
		-- a boost already as long as it gets (MaxStack purchases) can't be bought again for now
		local ends = player:GetAttribute("Meal_" .. row.item.id)
		local left = type(ends) == "number" and ends - t or 0
		local full = not Meals.CanBuy(row.item, left)
		local can = coins >= row.item.price and not full
		row.buy.BackgroundTransparency = can and Theme.Alpha.Primary or 0.92
		row.label.TextTransparency = can and 0 or 0.5
		row.label.Text = full and "Full" or ("Buy · " .. row.item.price)
	end
end

local function build(shopId: string)
	for _, row in ipairs(rows) do row.frame:Destroy() end
	rows = {}
	local shop = Meals.Shops[shopId]
	title.Text = shop.name
	for order, id in ipairs(shop.items) do
		local item = Meals.ById[id]
		local frame = New("Frame", { Name = id, LayoutOrder = 10 + order, Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Parent = panel })
		-- the item's own icon in its own color (never the bag's white shaker, so the two never look alike)
		local iconSlot = New("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, 2), BackgroundTransparency = 1, Parent = frame })
		iconOf(item).Parent = iconSlot
		Theme.Text({ Text = item.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -164, 0, 22), Position = UDim2.fromOffset(36, 2), TextXAlignment = Enum.TextXAlignment.Left, Upper = false, Parent = frame })
		Theme.Text({ Text = item.text, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, TextWrapped = true, Size = UDim2.new(1, -164, 0, 32), Position = UDim2.fromOffset(36, 24),
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = frame })
		local buy = Theme.Button("Primary", { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(120, Theme.MinTouch), Parent = frame }, {
			Theme.Text({ Name = "Label", Text = "Buy · " .. item.price, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
		})
		buy.Activated:Connect(function()
			if (ClientData.Get().coins or 0) < item.price then
				Notify.Show(item.name .. " costs " .. item.price .. " coins.", Colors.NeedsWork, "mealcoins")
				return
			end
			remote:FireServer("Buy", shopId, id)
		end)
		table.insert(rows, { frame = frame, item = item, buy = buy, label = buy:FindFirstChild("Label") })
	end
	refreshAffordable()
end

close.Activated:Connect(function() setOpen(nil) end)
UIBus.RegisterPanel("MealShop", function() setOpen(nil) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and openShop then setOpen(nil) end
end)
ClientData.Changed:Connect(function(path)
	if path[1] == "coins" and openShop then refreshAffordable() end
end)

------------------------------------------------------------------------
-- Boost timers (right column)
------------------------------------------------------------------------
local pills = {} -- [item id] = chip api (RightColumn.Chip: icon tile, "+20%", "4:12")
for order, item in ipairs(Meals.Items) do
	local chip = RightColumn.Chip(item.uiIcon or "cup-soda", Color3.fromHex(item.uiColor or item.color), order)
	pills[item.id] = { chip = chip, item = item, shown = false }
end

------------------------------------------------------------------------
-- Messages
------------------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" and Meals.Shops[info.shop] then
		openPart = nil
		for _, part in ipairs(CollectionService:GetTagged("MealShop")) do
			if part:GetAttribute("MealShop") == info.shop then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and (not openPart or (part.Position - root.Position).Magnitude < (openPart.Position - root.Position).Magnitude) then openPart = part end
			end
		end
		build(info.shop)
		UIBus.PanelOpened("MealShop")
		setOpen(info.shop)
	elseif kind == "Bought" then
		local item = Meals.ById[info.id]
		if item then
			Notify.Show(item.name .. ": " .. item.text:gsub(" for %d+ min$", "") .. " (" .. Meals.Clock(tonumber(info.seconds) or 0) .. ")")
			Audio.PlayUI("ShopBuy")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then task.delay(0.3, function() Audio.PlayAt("DrinkShake", root) end) end
		end
	elseif kind == "Failed" then
		Notify.Show(tostring(info.text), Colors.NeedsWork, "mealfail")
	end
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	-- the timers
	local t = now()
	for id, pill in pairs(pills) do
		local ends = player:GetAttribute("Meal_" .. id)
		local left = type(ends) == "number" and ends - t or 0
		local show = left > 0
		if pill.shown ~= show then
			pill.shown = show
			pill.chip:SetVisible(show)
		end
		if show then pill.chip:SetText(pill.item.chip or "", Meals.Clock(left)) end
	end
	if openShop then refreshAffordable() end
	-- walked away from the stall: close the shop
	if openShop and openPart then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - openPart.Position).Magnitude > Meals.PromptDistance + 6 then setOpen(nil) end
	end
end)
