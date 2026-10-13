-- TrainerClient: the Trainers window (owner's UI v2, mockup 06_trainers). The Trainers tile and a Trainer Desk's prompt
-- open it. Four picture tiles, no names anywhere: the trainer's portrait (Config/UI.Trainers), his perk ("+5% EXP") and
-- one status line:
--   not hired   a coin + his price (Config/Trainers): tap = hire (not enough coins: the tile shakes + "Not enough coins")
--   hired       "TAP TO EQUIP": tap = he follows you (all slots full: he takes the last slot's place)
--   following   green outline + "FOLLOWING": tap again = he stops following
-- Bottom: "Following 1/1" and the gold "R$ 99 · 2ND SLOT" button for the Extra Trainer pass (only while not owned).
-- The trainers themselves are drawn by TrainerFollowClient.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trainers = require(Shared.Config.Trainers)
local Monetization = require(Shared.Config.Monetization)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Trainers", 60) :: RemoteEvent
if not remote then return end -- the trainer service didn't start

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 560, 280 -- the window (mockup px)
local TILE = Vector2.new(124, 176)
local PASS = Monetization.PassByKey[Trainers.ExtraSlotPass]

local menuButton = SideMenu.Add("Trainers", "Trainers", Icons.Clipboard, 7.5)

local modal = Kit.Modal({ name = "Trainers", title = "Personal Trainers", icon = "clipboard-list", width = W, height = H, displayOrder = 25,
	tabs = { { id = "Trainers", text = "Trainers", icon = "clipboard-list" } } })

local row = New("Frame", { Name = "Tiles", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TILE.Y), Parent = modal.body }, {
	Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})

local function state()
	local data = ClientData.Get()
	local t = type(data.trainers) == "table" and data.trainers or {}
	return type(t.owned) == "table" and t.owned or {}, type(t.equipped) == "table" and t.equipped or {}
end
local function slots(): number
	return Trainers.SlotsFor(player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) == true)
end

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

local tiles = {}
for order, trainer in ipairs(Trainers.List) do
	local holder = New("Frame", { Name = trainer.id, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE.X, TILE.Y), Parent = row })
	local card = Kit.Card({ Name = "Card", Clickable = true, Size = UDim2.fromScale(1, 1), Parent = holder }, {})
	local picture = Pieces.Image(trainer.picture, { Name = "Picture", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, TILE.X - 12), Parent = card })
	picture.ScaleType = Enum.ScaleType.Crop
	New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = picture })
	New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = picture })
	Kit.Text({ Name = "Perk", Text = trainer.perkShort, Font = "Title", TextSize = 16, Position = UDim2.fromOffset(2, TILE.X), Size = UDim2.new(1, -4, 0, 22), Parent = card })
	local status = Kit.Text({ Name = "Status", Text = "", Font = "Title", TextSize = 13, Position = UDim2.fromOffset(2, TILE.X + 22), Size = UDim2.new(1, -4, 0, 18), Parent = card })
	local priceLine = New("Frame", { Name = "Price", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TILE.X + 22), Size = UDim2.new(1, 0, 0, 18), Parent = card }, {
		Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	Kit.Coin(15, { LayoutOrder = 1, Parent = priceLine })
	Kit.Text({ LayoutOrder = 2, Text = Kit.Format(trainer.price), Font = "Title", TextSize = 15, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X, Parent = priceLine })
	tiles[trainer.id] = { card = card, status = status, priceLine = priceLine, trainer = trainer }
	card.Activated:Connect(function()
		local owned, equipped = state()
		if table.find(equipped, trainer.id) then
			Audio.PlayUI("Click")
			remote:FireServer("Unequip", trainer.id)
		elseif table.find(owned, trainer.id) then
			Audio.PlayUI("Click")
			remote:FireServer("Equip", trainer.id)
		elseif (ClientData.Get().coins or 0) < trainer.price then
			shake(card)
			Notify.Toast("Not enough coins", trainer.perkShort .. " costs " .. Kit.Format(trainer.price) .. " coins", "coin", Colors.Red, "trainercoins")
		else
			remote:FireServer("Hire", trainer.id)
		end
	end)
end

-- bottom line: how many follow you, and the 2nd slot pass
local bottom = New("Frame", { Name = "Bottom", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34), Parent = modal.body })
local following = Kit.Text({ Name = "Following", Text = "", Font = "Title", TextSize = 16, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0),
	Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left, Parent = bottom })
local hint = Kit.Text({ Name = "Hint", Text = "Tap a trainer to hire or swap", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 120, 0.5, 0), Size = UDim2.fromOffset(200, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = bottom })
local slotButton = Kit.Button("Gold", "2nd slot", { Name = "SecondSlot", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Parent = bottom },
	{ height = 30, textSize = 14, icon = "robux" })
slotButton.Visible = PASS ~= nil and PASS.id ~= nil
local passPrice = nil
if PASS and PASS.id then
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(PASS.id, Enum.InfoType.GamePass) end)
		if ok and info and info.PriceInRobux then
			passPrice = info.PriceInRobux
			Kit.SetButton(slotButton, nil, Kit.Format(passPrice) .. " · 2nd slot")
		end
	end)
end
slotButton.Activated:Connect(function()
	if PASS and PASS.id and not player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) then
		MarketplaceService:PromptGamePassPurchase(player, PASS.id)
	end
end)

local function refresh()
	local owned, equipped = state()
	for id, tile in pairs(tiles) do
		local isFollowing = table.find(equipped, id) ~= nil
		local isOwned = table.find(owned, id) ~= nil
		Theme.SetPiece(tile.card, isFollowing and "card_selected" or "card")
		tile.priceLine.Visible = not isOwned
		tile.status.Visible = isOwned
		tile.status.Text = isFollowing and "FOLLOWING" or "TAP TO EQUIP"
		tile.status.TextColor3 = isFollowing and Colors.Green or Colors.Text
	end
	following.Text = "Following " .. #equipped .. "/" .. slots()
	hint.Position = UDim2.new(0, following.TextBounds.X + 16, 0.5, 0)
	slotButton.Visible = PASS ~= nil and PASS.id ~= nil and player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) ~= true
end

local function open()
	refresh()
	if modal.isOpen() then return end
	menuButton:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	modal.open()
	Audio.PlayUI("Whoosh")
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then
		menuButton:SetActive(false)
		UIBus.MenuPanelVisible:Fire(false)
	end
end)
menuButton.Activated:Connect(function()
	if modal.isOpen() then modal.close() else UIBus.PanelOpened("Trainers") open() end
end)
UIBus.RegisterPanel("Trainers", function() modal.close() end)
ClientData.Changed:Connect(function(path)
	if modal.isOpen() and (path[1] == "coins" or path[1] == "trainers") then refresh() end
end)
player:GetAttributeChangedSignal("Pass_" .. Trainers.ExtraSlotPass):Connect(function() if modal.isOpen() then refresh() end end)

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" then
		if not modal.isOpen() then UIBus.PanelOpened("Trainers") end
		open()
	elseif kind == "Hired" then
		local trainer = Trainers.ById[info.id]
		if trainer then
			Notify.Toast("Trainer hired!", trainer.perkShort, "clipboard-list", Colors.Green)
			Audio.PlayUI("ShopBuy")
		end
		refresh()
	elseif kind == "Failed" then
		local tile = info.id and tiles[info.id]
		if tile then shake(tile.card) end
		Notify.Toast(tostring(info.text), nil, "coin", Colors.Red, "trainerfail")
	end
end)
