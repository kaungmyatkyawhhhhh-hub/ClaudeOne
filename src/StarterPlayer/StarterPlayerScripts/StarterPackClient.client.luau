-- StarterPackClient (owner, 26 Oct): the LIMITED Starter Pack and, after buying it, the VIP 30% OFF deal
-- (Config/Monetization StarterPack / VipDeal).
--  * One offer window (Kit.Modal): the art, what's inside, a countdown (the first WindowHours of play), and the price as
--    "250 R$" with a red line drawn through it, then "79 R$" slamming in, with one red BUY button.
--  * The Starter Pack pops up every PopupMinutes of play (after the tutorial; never over a window, the menu or a lift) until
--    Growth Spurt PopupUntilSpurt. At that spurt it shrinks and flies into the SHOP tile ("The Starter Pack is in the SHOP")
--    and only the SHOP's DEAL tag is left (still sold until the window ends).
--  * A small red DEAL tag on the SHOP tile while a deal is on; tapping it opens that deal.
--  * After the Starter Pack is bought: the VIP deal (VIP's perks listed, 299 crossed out, 209) for VipDeal.Hours of play.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Onboarding = require(Shared.Config.Onboarding)
local ClientData = require(Shared.ClientData)
local ShopPrices = require(Shared.ShopPrices)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors
local PACK = Monetization.StarterPack
local STARTER = Monetization.ProductByKey.StarterPack
local VIP_DEAL = Monetization.PassByKey.VIPDeal
if not STARTER or not STARTER.id then return end

------------------------------------------------------------------------
-- Play time: data.playtime.total comes from the server about once a minute; in between, count on locally
------------------------------------------------------------------------
local syncedAt = os.clock()
ClientData.Changed:Connect(function(path)
	if path[1] == "playtime" then syncedAt = os.clock() end
end)
local function since(): number return os.clock() - syncedAt end

------------------------------------------------------------------------
-- The offer window
------------------------------------------------------------------------
local modal = Kit.Modal({ name = "StarterPack", title = "Starter Pack", width = 520, height = 236, displayOrder = 27, icon = "gift" })
local body = modal.body
local art = Pieces.ShopIcon("", { Name = "Art", Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(120, 120), Parent = body })
local limited = Kit.Tag("LIMITED", Colors.Red, { Name = "Limited", Position = UDim2.fromOffset(14, 136), Size = UDim2.fromOffset(0, 20), Parent = body })
local countdown = Kit.Text({ Name = "Countdown", Text = "", Font = "Number", TextSize = 15, Position = UDim2.fromOffset(4, 160), Size = UDim2.fromOffset(120, 20),
	Parent = body })
Kit.GoldText(countdown)
local list = New("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(136, 2), Size = UDim2.new(1, -136, 0, 130), Parent = body }, {
	Theme.List(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
-- the price: the old one crossed out, the new one
local priceRow = New("Frame", { Name = "Price", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 136, 1, -2),
	Size = UDim2.fromOffset(170, 48), Parent = body })
local was = Kit.Text({ Name = "Was", Text = "", Font = "Number", TextSize = 20, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(80, 24),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = priceRow })
local strike = New("Frame", { Name = "Strike", BackgroundColor3 = Colors.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -2, 0.5, 0),
	Size = UDim2.new(0, 0, 0, 3), Rotation = -8, Parent = was })
local now = Kit.Text({ Name = "Now", Text = "", Font = "Number", TextSize = 30, Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(110, 30),
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = priceRow })
Kit.GoldText(now)
local nowScale = New("UIScale", { Parent = now })
local off = Kit.Tag("", Colors.Red, { Name = "Off", Position = UDim2.fromOffset(112, 26), Size = UDim2.fromOffset(0, 20), Visible = false, Parent = priceRow })
local buy = Kit.Button("Red", "Buy", { Name = "Buy", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Parent = body }, { width = 150, height = 46, textSize = 18 })

local showing = nil -- "Starter" | "Vip"
local function line(order: number, text: string, gold: boolean?)
	local label = Kit.Text({ Name = "Line" .. order, LayoutOrder = order, Text = text, Font = if gold then "Title" else "Strong", TextSize = if gold then 14 else 13,
		Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = list })
	if gold then Kit.GoldText(label) end
end
local function offerLines(kind: string)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local data = ClientData.Get()
	if kind == "Starter" then
		line(1, "+" .. Kit.Format(Monetization.StarterCoins(data.growthSpurts)) .. " coins")
		line(2, PACK.Shakes .. " Protein Shakes")
		line(3, "A DNA Token (reroll your genetics)")
		line(4, "30 min of 2x EXP and the STARTER title")
		line(5, "+" .. math.floor((PACK.Rush.gains - 1) * 100 + 0.5) .. "% EXP and coins for " .. PACK.RushHours .. " hours", true)
	else
		for i, perk in ipairs(Monetization.VipDeal.Perks) do line(i, perk) end
		line(#Monetization.VipDeal.Perks + 1, "Yours forever, " .. math.floor(Monetization.VipDeal.Discount * 100 + 0.5) .. "% off", true)
	end
end

local function priceOf(kind: string): (number, number)
	if kind == "Starter" then return PACK.WasPrice, ShopPrices.Get(STARTER) or STARTER.price end
	return Monetization.VipDeal.WasPrice, ShopPrices.Get(VIP_DEAL) or VIP_DEAL.price
end

-- the price moment: the old price, a red line drawn through it, the new price slams in
local function playPrice(kind: string)
	local old, new = priceOf(kind)
	was.Text = Kit.Format(old) .. " R$"
	now.Text = Kit.Format(new) .. " R$"
	off.Text.Text = "-" .. math.floor((1 - new / math.max(old, 1)) * 100 + 0.5) .. "%" -- (a Kit.Tag: its words are its Text child)
	strike.Size = UDim2.new(0, 0, 0, 3)
	now.Visible, off.Visible = false, false
	Kit.SetButton(buy, "Red", "Buy  R$ " .. Kit.Format(new))
	task.delay(0.45, function()
		if not showing then return end
		TweenService:Create(strike, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 4, 0, 3) }):Play()
		task.wait(0.35)
		if not showing then return end
		now.Visible, off.Visible = true, true
		nowScale.Scale = 1.7
		TweenService:Create(nowScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		Audio.PlayUI("Whoosh")
	end)
end

local function timeLeft(kind: string): (boolean, number)
	local data = ClientData.Get()
	if kind == "Starter" then return Monetization.StarterOpen(data, since()) end
	return Monetization.VipDealOpen(data, since())
end

local function log(event: string, offer: string)
	Remotes.PlayerAction:FireServer("ShopEvent", { event = event, offer = offer })
end

local function open(kind: string)
	local isOpen = timeLeft(kind)
	if not isOpen then return end
	showing = kind
	if kind == "Starter" then
		modal.setTitle("Starter Pack")
		Pieces.Apply(art, STARTER.art)
	else
		modal.setTitle("VIP · 30% Off")
		Pieces.Apply(art, Monetization.PassByKey.VIP.art)
	end
	offerLines(kind)
	UIBus.PanelOpened("StarterPack")
	modal.open()
	playPrice(kind)
	log("OfferShown", if kind == "Starter" then "StarterPackLimited" else "VipDeal")
end
UIBus.RegisterPanel("StarterPack", function() modal.close() end)
buy.Activated:Connect(function()
	Audio.PlayUI("Click")
	if showing == "Starter" then
		log("OfferTapped", "StarterPackLimited")
		MarketplaceService:PromptProductPurchase(player, STARTER.id)
	elseif showing == "Vip" and VIP_DEAL and VIP_DEAL.id then
		log("OfferTapped", "VipDeal")
		MarketplaceService:PromptGamePassPurchase(player, VIP_DEAL.id)
	end
	modal.close()
end)

-- the countdown while the window is open
task.spawn(function()
	while true do
		task.wait(0.5)
		if modal.isOpen() and showing then
			local isOpen, left = timeLeft(showing)
			countdown.Text = if isOpen then "ENDS IN " .. Monetization.Clock(left) else "ENDED"
			if not isOpen then modal.close() end
		else
			showing = if modal.isOpen() then showing else nil
		end
	end
end)

------------------------------------------------------------------------
-- The SHOP tile's DEAL tag (a button: opens the deal that's on)
------------------------------------------------------------------------
local dealTag = nil
local function shopTile(): GuiObject?
	-- (the left nav's SHOP tile is named "Store", next to "Crew" / "Trainers")
	local hud = playerGui:FindFirstChild("MainHud")
	local crew = hud and hud:FindFirstChild("Crew", true)
	local tile = crew and crew.Parent and crew.Parent:FindFirstChild("Store")
	return if tile and tile:IsA("GuiObject") and tile.Visible then tile else nil
end
local function currentDeal(): string?
	if timeLeft("Vip") then return "Vip" end
	if timeLeft("Starter") then return "Starter" end
	return nil
end
task.spawn(function()
	while true do
		task.wait(1)
		local tile = shopTile()
		if tile and (not dealTag or dealTag.Parent ~= tile) then
			dealTag = New("TextButton", { Name = "DealTag", Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Red, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(42, 18), ZIndex = (tile.ZIndex or 1) + 5, Visible = false, Parent = tile }, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
				New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			Kit.Text({ Name = "Text", Text = "DEAL", Font = "Chunky", TextSize = 11, Size = UDim2.fromScale(1, 1), ZIndex = (tile.ZIndex or 1) + 6, Parent = dealTag })
			dealTag.Activated:Connect(function()
				local deal = currentDeal()
				if deal then Audio.PlayUI("Click") open(deal) end
			end)
		end
		if dealTag then dealTag.Visible = currentDeal() ~= nil and not UIBus.InTutorial() end
	end
end)

------------------------------------------------------------------------
-- Pop up every PopupMinutes of play until Growth Spurt PopupUntilSpurt
------------------------------------------------------------------------
local function inTutorial(data): boolean
	return (data.onboarding and data.onboarding.tutorialStep or Onboarding.Done) < Onboarding.Done or UIBus.InTutorial()
end
local function free(): boolean
	return not UIBus.MenuOpen and not UIBus.GeneticsUp and not UIBus.CoverOpen(playerGui) and not UIBus.Training and not UIBus.GuideRunning
		and not modal.isOpen()
end
task.spawn(function()
	local played = 0
	while true do
		task.wait(1)
		local data = ClientData.Get()
		if data and not UIBus.MenuOpen and not inTutorial(data) then
			played += 1
			if played >= PACK.PopupMinutes * 60 and (data.growthSpurts or 0) < PACK.PopupUntilSpurt and timeLeft("Starter") and free() then
				played = 0
				open("Starter")
			end
		end
	end
end)

-- Growth Spurt PopupUntilSpurt: the offer flies into the SHOP tile, once
local function flyIntoShop()
	local tile = shopTile()
	if not tile or tile.AbsoluteSize.X <= 0 then return end
	local gui = Theme.ScreenGui({ Name = "StarterFly", DisplayOrder = 28, Parent = playerGui })
	gui.IgnoreGuiInset = true
	local center = gui.AbsoluteSize / 2
	local chip = Theme.Panel({ Name = "Chip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(250, 84), Parent = gui })
	Theme.SetChrome(chip)
	Pieces.ShopIcon(STARTER.art, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(64, 64), Parent = chip })
	local label = Kit.Text({ Text = "STARTER PACK", Font = "Title", TextSize = 18, Position = UDim2.fromOffset(84, 14), Size = UDim2.new(1, -92, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
	Kit.GoldText(label)
	Kit.Text({ Text = "Still in the SHOP", Font = "Strong", TextSize = 13, Position = UDim2.fromOffset(84, 44), Size = UDim2.new(1, -92, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
	local scale = New("UIScale", { Scale = 0.3, Parent = chip })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(1.6)
	local goal = tile.AbsolutePosition + tile.AbsoluteSize / 2 - gui.AbsolutePosition
	TweenService:Create(chip, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(goal.X, goal.Y) }):Play()
	TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.12 }):Play()
	task.wait(0.7)
	gui:Destroy()
	local bounce = tile:FindFirstChild("DealBounce") or New("UIScale", { Name = "DealBounce", Parent = tile })
	bounce.Scale = 1.3
	TweenService:Create(bounce, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Audio.PlayUI("Whoosh")
	Notify.Toast("The Starter Pack is in the SHOP", "On sale for " .. Monetization.Clock(select(2, timeLeft("Starter"))) .. " more of play", "gift", Colors.Gold, "starterfly")
end
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "GrowthSpurt" and type(info) == "table" and info.spurts == PACK.PopupUntilSpurt and timeLeft("Starter") then
		task.delay(8, function()
			local waited = 0
			while not free() and waited < 60 do task.wait(1) waited += 1 end
			flyIntoShop()
		end)
	elseif kind == "StarterPack" and type(info) == "table" and not info.again then
		-- bought: the VIP deal, once the reward moment is over
		task.delay(7, function()
			local waited = 0
			while not free() and waited < 60 do task.wait(1) waited += 1 end
			open("Vip")
		end)
	end
end)

