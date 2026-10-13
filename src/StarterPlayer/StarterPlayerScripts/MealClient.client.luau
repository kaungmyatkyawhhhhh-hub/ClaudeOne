-- MealClient: the Smoothie Bar window (owner's UI v2, mockup 09_smoothie_bar) and the boost timers. MealService opens the
-- window when you press a stall's prompt and checks every purchase; this only shows them.
--   * Window: a "Drinks" tab, the stall's name as the title, and one tile per drink: a big colored icon tile, the name, what
--     it does and for how long ("+20% EXP · 5 min") and a green coin-price button (gray "Full" when the boost is already as
--     long as it gets). Drinks this stall doesn't sell stay gray with where to get them ("Beach only"). Not enough coins:
--     the tile shakes + "Not enough coins". Closes with X, Esc, a tap outside or when you walk away from the stall.
--   * Timers: one small chip per running boost in the right column ("+20%  4:32"), from the player attributes Meal_<id>
--     (server time the boost ends).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meals = require(Shared.Config.Meals)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local RightColumn = require(Shared.UI.RightColumn)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Meals", 60) :: RemoteEvent
if not remote then return end -- the meal service didn't start

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 560, 262 -- the window (mockup px)
local TILE = Vector2.new(124, 196)

local function now() return Workspace:GetServerTimeNow() end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local modal = Kit.Modal({ name = "MealShop", title = "Smoothie Bar", icon = "cup-soda", width = W, height = H, displayOrder = 25,
	tabs = { { id = "Drinks", text = "Drinks", icon = "cup-soda" } } })
local row = New("Frame", { Name = "Tiles", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TILE.Y), Parent = modal.body }, {
	Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})

-- where a drink is sold, for the tiles of the drinks this stall doesn't have
local function soldAt(id: string): string
	local where = {}
	for shopId, shop in pairs(Meals.Shops) do
		if table.find(shop.items, id) then table.insert(where, shopId) end
	end
	if #where == 1 and where[1] == "CoconutCart" then return "Beach only" end
	return "Not sold here"
end

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

local openShop = nil -- shop id while open
local openPart = nil -- the stall part (closes when you walk away)
local tiles = {}
for order, item in ipairs(Meals.Items) do
	local holder = New("Frame", { Name = item.id, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE.X, TILE.Y), Parent = row })
	local card = Kit.Card({ Name = "Card", Size = UDim2.fromScale(1, 1), Parent = holder }, {})
	local color = Color3.fromHex(item.uiColor or item.color)
	local tile = Kit.IconTile(item.uiIcon or "cup-soda", color, 72, { Name = "Tile", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7), Parent = card })
	tile.Size = UDim2.new(1, -14, 0, 74)
	local name = Kit.Text({ Name = "Name", Text = item.name, Font = "Title", TextSize = 15, TextWrapped = true, Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, -8, 0, 36),
		TextYAlignment = Enum.TextYAlignment.Center, Parent = card })
	local sub = Kit.Text({ Name = "Sub", Text = item.sub or item.short or "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, TextWrapped = true,
		Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 28), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	local buy = Kit.Button("Green", Kit.Format(item.price), { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Parent = card },
		{ width = TILE.X - 16, height = 30, textSize = 15, icon = "coin" })
	tiles[item.id] = { card = card, tile = tile, name = name, sub = sub, buy = buy, item = item }
	buy.Activated:Connect(function()
		local entry = tiles[item.id]
		if not openShop or not entry.sold then return end
		if entry.full then return end
		if (ClientData.Get().coins or 0) < item.price then
			shake(card)
			Notify.Toast("Not enough coins", item.name .. " costs " .. Kit.Format(item.price) .. " coins", "coin", Colors.Red, "mealcoins")
			return
		end
		remote:FireServer("Buy", openShop, item.id)
	end)
end

local function refreshTiles()
	local shop = openShop and Meals.Shops[openShop]
	local t = now()
	for id, entry in pairs(tiles) do
		local sold = shop ~= nil and table.find(shop.items, id) ~= nil
		entry.sold = sold
		-- a boost already as long as it gets (MaxStack purchases) can't be bought again for now
		local ends = player:GetAttribute("Meal_" .. id)
		local left = type(ends) == "number" and ends - t or 0
		entry.full = sold and not Meals.CanBuy(entry.item, left)
		entry.sub.Text = sold and (entry.item.sub or entry.item.short or "") or soldAt(id)
		Kit.SetTileColor(entry.tile, sold and Color3.fromHex(entry.item.uiColor or entry.item.color) or Color3.fromHex("#4A4A55"))
		local icon = entry.buy:FindFirstChild("Icon", true)
		if icon then icon.Visible = not entry.full end
		Kit.SetButton(entry.buy, (sold and not entry.full) and "Green" or "Dark", entry.full and "Full" or Kit.Format(entry.item.price))
	end
end

local function setOpen(shopId: string?)
	if shopId then
		openShop = shopId
		-- the stall's name in title case ("Smoothie cart" -> "Smoothie Cart")
		modal.setTitle((string.gsub(Meals.Shops[shopId].name, "(%a)([%w']*)", function(first, rest) return string.upper(first) .. rest end)))
		refreshTiles()
		if not modal.isOpen() then
			modal.open()
			Audio.PlayUI("Whoosh")
		end
	else
		openShop = nil
		modal.close()
	end
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then openShop = nil end
end)
UIBus.RegisterPanel("MealShop", function() setOpen(nil) end)

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
		UIBus.PanelOpened("MealShop")
		setOpen(info.shop)
	elseif kind == "Bought" then
		local item = Meals.ById[info.id]
		if item then
			Notify.Toast(item.name, (item.sub or item.short or "") .. "  (" .. Meals.Clock(tonumber(info.seconds) or 0) .. " left)", item.uiIcon or "cup-soda",
				Color3.fromHex(item.uiColor or item.color))
			Audio.PlayUI("ShopBuy")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then task.delay(0.3, function() Audio.PlayAt("DrinkShake", root) end) end
		end
	elseif kind == "Failed" then
		Notify.Toast(tostring(info.text), nil, "cup-soda", Colors.Red, "mealfail")
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
	if openShop then refreshTiles() end
	-- walked away from the stall: close the shop
	if openShop and openPart then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - openPart.Position).Magnitude > Meals.PromptDistance + 6 then setOpen(nil) end
	end
end)
