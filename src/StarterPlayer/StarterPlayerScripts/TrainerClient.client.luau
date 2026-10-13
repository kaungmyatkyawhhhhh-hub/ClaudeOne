-- TrainerClient: the COACHES window (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/06_coaches; in code and
-- config they're still "trainers"). The Trainers tile and a Trainer Desk's prompt open it. Four picture tiles, no names:
-- the coach's portrait (Config/UI.Trainers) in a dark box, his perk big ("+5%" + a small "EXP") and one status:
--   locked      the picture gray + a lock icon, a price pill (coin + price, Config/Trainers): tap = hire (not enough
--               coins: the tile shakes + "Not enough coins")
--   owned       a quiet EQUIP button: tap = he follows you (all slots full: he takes the last slot's place)
--   coaching    the tile ~7% bigger with a gold frame + glow, the perk in gold and "COACHING": tap again = he stops
-- Bottom: "Tap a coach to hire or swap · 1 / 1 active" and the gold "R$ 99 · 2ND SLOT" CTA for the Extra Trainer pass
-- (only while not owned; it pulses). The coin pill + X sit in the header.
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
local TILE = Vector2.new(122, 172)
local PASS = Monetization.PassByKey[Trainers.ExtraSlotPass]

local menuButton = SideMenu.Add("Trainers", "Trainers", Icons.Clipboard, 7.5)

local modal = Kit.Modal({ name = "Trainers", title = "Coaches", width = W, height = H, displayOrder = 25, coins = true })

local row = New("Frame", { Name = "Tiles", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, TILE.Y), Parent = modal.body }, {
	Theme.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
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

-- "+5% EXP" -> "+5%", "EXP"
local function splitPerk(text: string): (string, string)
	local number, word = string.match(text, "^(%S+)%s+(.+)$")
	return number or text, word or ""
end

local tiles = {}
for order, trainer in ipairs(Trainers.List) do
	local holder = New("Frame", { Name = trainer.id, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE.X, TILE.Y), Parent = row })
	local card = Kit.Card({ Name = "Card", Clickable = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		Parent = holder }, {})
	local grow = New("UIScale", { Name = "Grow", Parent = card }) -- (the coaching tile is ~7% bigger)
	-- the portrait in a dark box
	local box = New("Frame", { Name = "Box", Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 0, 94), BackgroundColor3 = Color3.fromHex("#141215"),
		ClipsDescendants = true, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local picture = Pieces.Image(trainer.picture, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = box })
	picture.ScaleType = Enum.ScaleType.Crop
	New("UICorner", { CornerRadius = UDim.new(0, 9), Parent = picture })
	-- locked: a gray veil over the picture (a desaturated look) and a lock in the corner
	local veil = New("Frame", { Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#5E5A5C"), BackgroundTransparency = 0.35,
		ZIndex = 2, Visible = false, Parent = box }, { New("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local lock = Pieces.Icon("lock", Colors.Text, { Name = "Lock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 7), Size = UDim2.fromOffset(16, 16),
		ZIndex = 3, Visible = false, Parent = box })
	lock:SetAttribute("KeepColor", true)
	-- the perk: a big number and a small word
	local number, word = splitPerk(trainer.perkShort)
	local perk = New("Frame", { Name = "Perk", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 28), Parent = card }, {
		Theme.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	local perkNumber = Kit.Text({ Name = "Number", LayoutOrder = 1, Text = number, Font = "Number", TextSize = 24, Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X, Parent = perk })
	local perkWord = Kit.Text({ Name = "Word", LayoutOrder = 2, Text = string.upper(word), Font = "Title", TextSize = 11, Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X, Parent = perk })
	-- status: EQUIP (owned), COACHING (following) or the price pill (not hired)
	local equip = Kit.Button("Quiet", "Equip", { Name = "Equip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = card },
		{ width = TILE.X - 22, height = 28, textSize = 14 })
	local coaching = Kit.GoldText(Kit.Text({ Name = "Coaching", Text = "COACHING", Font = "Title", TextSize = 15, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, 0, 0, 20), Visible = false, Parent = card }))
	local price = Kit.PricePill(Kit.Format(trainer.price), { Name = "Price", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(0, 26), Parent = card }, "coin")
	tiles[trainer.id] = { card = card, grow = grow, picture = picture, veil = veil, lock = lock, perkNumber = perkNumber, perkWord = perkWord,
		equip = equip, coaching = coaching, price = price, trainer = trainer }
	local function tap()
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
	end
	card.Activated:Connect(tap)
	equip.Activated:Connect(tap)
end

-- bottom line: how many follow you, and the 2nd slot pass
local bottom = New("Frame", { Name = "Bottom", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34), Parent = modal.body })
local hint = Kit.Text({ Name = "Hint", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(300, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = bottom })
local slotButton = Kit.Button("Gold", "2nd slot", { Name = "SecondSlot", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Parent = bottom },
	{ height = 32, textSize = 15 })
slotButton.Visible = PASS ~= nil and PASS.id ~= nil
local passPrice = nil
if PASS and PASS.id then
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(PASS.id, Enum.InfoType.GamePass) end)
		if ok and info and info.PriceInRobux then
			passPrice = info.PriceInRobux
			Kit.SetButton(slotButton, nil, "R$ " .. Kit.Format(passPrice) .. " · 2nd slot")
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
		Theme.SetPiece(tile.card, isFollowing and "card_gold" or "card")
		Theme.Tween(tile.grow, { Scale = isFollowing and 1.07 or 1 }, 0.18)
		tile.veil.Visible = not isOwned
		tile.lock.Visible = not isOwned
		tile.picture.ImageColor3 = isOwned and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
		tile.price.Visible = not isOwned
		tile.equip.Visible = isOwned and not isFollowing
		tile.coaching.Visible = isFollowing
		-- the perk: gold while he coaches you, faint while locked
		local gold = tile.perkNumber:FindFirstChild("Gold")
		if isFollowing then
			Kit.GoldText(tile.perkNumber)
		elseif gold then
			gold:Destroy()
		end
		tile.perkNumber.TextColor3 = isOwned and Colors.Text or Colors.Faint
		tile.perkWord.TextColor3 = isOwned and Colors.Text or Colors.Faint
		if isFollowing then tile.perkNumber.TextColor3 = Color3.new(1, 1, 1) end
	end
	hint.Text = "Tap a coach to hire or swap · " .. #equipped .. " / " .. slots() .. " active"
	slotButton.Visible = PASS ~= nil and PASS.id ~= nil and player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) ~= true
end

local function open()
	refresh()
	if modal.isOpen() then return end
	menuButton:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	modal.open()
	Theme.Pulse(slotButton, function() return modal.isOpen() end) -- (the featured CTA pulses while the window is open)
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
			Notify.Toast("Coach hired!", trainer.perkShort, "clipboard-list", Colors.Gold)
			Audio.PlayUI("ShopBuy")
		end
		refresh()
	elseif kind == "Failed" then
		local tile = info.id and tiles[info.id]
		if tile then shake(tile.card) end
		Notify.Toast(tostring(info.text), nil, "coin", Colors.Red, "trainerfail")
	end
end)
