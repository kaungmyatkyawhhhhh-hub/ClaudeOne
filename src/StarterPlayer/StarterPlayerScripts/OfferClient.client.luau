-- OfferClient (prompt 12, owner 20 Oct: "developer products sold 0 Robux"): the right product at the right moment, as ONE
-- small card at the bottom center (above the stamina bar, its boost icons and its tip line; clear of STOP / REP), never a
-- full-screen popup. Kids' game: honest text, an X to close, it goes away by itself after CardSeconds, no timers, no
-- "last chance", and each moment shows its card at most once per session (stamina: at most once per StaminaEvery).
--   * Stamina runs out (the "StaminaRecovering" attribute; not in the tutorial, not with Endless Stamina running):
--     "Endless Stamina · 15 min".
--   * The last Energy Shake is drunk (data.items.Shake goes to 0; not in the tutorial): "Shake Bundle", and the honest
--     coin price at the shake machine.
--   * After a Growth Spurt (once its celebration is over): "Boost your next spurt" with the Small / Medium / Large coins.
-- (The Growth Spurt card's "Finish faster" link at 75%+ is in ProgressClient.) A Buy button opens Roblox's purchase
-- prompt itself (2 taps: Buy, then Roblox's confirm); the item is given in ProcessReceipt on the server.
-- Analytics (server, Analytics.ShopEvent): "Offer_Shown_<id>" and "Offer_Tapped_<id>".
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Onboarding = require(Shared.Config.Onboarding)
local Stamina = require(Shared.Config.Stamina)
local ClientData = require(Shared.ClientData)
local ShopPrices = require(Shared.ShopPrices)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local UIBus = require(Shared.UI.UIBus)
local HudBottom = require(Shared.UI.HudBottom)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local CARD_W = 400
local CardSeconds = 12        -- a card goes away by itself after this
local StaminaEvery = 10 * 60  -- the stamina card: at most once per 10 minutes
local SpurtDelay = 6          -- after a Growth Spurt: the celebration (StatsClient) first

local Products = Monetization.ProductByKey
local function forSale(key: string): boolean
	local item = Products[key]
	return item ~= nil and Monetization.ForSale(item)
end
if not (forSale("EndlessStamina") or forSale("ShakePack") or forSale("CoinsSmall")) then return end

local function log(event: string, offer: string)
	Remotes.PlayerAction:FireServer("ShopEvent", { event = event, offer = offer })
end

------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "Offer", DisplayOrder = 8, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)
local card = Theme.Panel({ Name = "Card", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(CARD_W, 72), Parent = root },
	{ New("UIStroke", { Color = Colors.Gold, Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
local art = Pieces.ShopIcon("", { Name = "Art", Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(48, 48), Parent = card })
local title = Kit.Text({ Name = "Title", Text = "", Font = "Title", TextSize = 15, Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -66, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
Kit.GoldText(title)
local sub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 11, TextWrapped = true, Position = UDim2.fromOffset(66, 28), Size = UDim2.new(1, -66, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
Kit.Fit(sub, 12, 9, 3) -- (up to 3 lines; a long one gets a little smaller instead of running out of the card)
local buttons = New("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 44), Parent = card }, {
	Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
})
local close = Kit.CloseButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(44, 44), Parent = card })

local current = nil -- the offer id showing
local shownAt = 0

-- right above the stamina bar (HudBottom moves it up over the hotbar); for its few seconds it covers the boost icons and
-- the "Recovering" tip line there (higher up it sat over the character's head on a phone)
local function place()
	card.Position = UDim2.new(0.5, 0, 1, -(HudBottom.BarTop() + 6))
end

local function hide()
	if not current then return end
	current = nil
	local tween = Theme.Fade(card, false, 0.25)
	if tween then
		tween.Completed:Connect(function() if not current then gui.Enabled = false end end)
	else
		gui.Enabled = false
	end
end
close.Activated:Connect(function()
	Audio.PlayUI("Click")
	hide()
end)

local function inTutorial(data): boolean
	return (data.onboarding and data.onboarding.tutorialStep or Onboarding.Done) < Onboarding.Done
end

-- no card over a window, the menu, the genetics screen or another card
local function free(): boolean
	return current == nil and not UIBus.MenuOpen and not UIBus.GeneticsUp and not UIBus.CoverOpen(player.PlayerGui)
end

-- spec: { id, art, title, text, buy = { { key, label? } } } (one buy = a red button on the right; several = a row of
-- quiet buttons under the text)
local function show(spec)
	for _, child in ipairs(buttons:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local single = #spec.buy == 1
	Pieces.Apply(art, spec.art)
	title.Text = spec.title
	sub.Text = spec.text
	-- one product: its red price button left of the X; several: a row under the text
	-- (the text stops before the price button and the X: 66 px of art on the left, 160 / 52 px on the right)
	title.Size = UDim2.new(1, if single then -226 else -118, 0, 20)
	sub.Size = UDim2.new(1, if single then -226 else -118, 0, 34)
	card.Size = UDim2.fromOffset(CARD_W, if single then 72 else 120)
	buttons.AnchorPoint = if single then Vector2.new(1, 0.5) else Vector2.new(0.5, 1)
	buttons.Position = if single then UDim2.new(1, -52, 0.5, 0) else UDim2.new(0.5, 0, 1, -8)
	buttons.Size = if single then UDim2.fromOffset(100, 44) else UDim2.new(1, -20, 0, 44)
	local layout = buttons:FindFirstChildOfClass("UIListLayout")
	if layout then layout.HorizontalAlignment = if single then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Center end
	for order, entry in ipairs(spec.buy) do
		local item = Products[entry.key]
		local price = ShopPrices.Get(item)
		local text = (if entry.label then entry.label .. "  " else "") .. (if price then "R$ " .. Kit.Format(price) else "Buy")
		local button = Kit.Button(if single then "Red" else "Quiet", text, { Name = entry.key, LayoutOrder = order },
			{ height = 44, width = if single then 100 else 108, textSize = if single then 16 else 13, icon = if entry.label then "coin" else nil })
		button.Parent = buttons
		button.Activated:Connect(function()
			log("OfferTapped", spec.id)
			Audio.PlayUI("Click")
			MarketplaceService:PromptProductPurchase(player, item.id)
			hide()
		end)
	end
	current = spec.id
	shownAt = os.clock()
	place()
	gui.Enabled = true
	Theme.Fade(card, true, 0.25)
	Audio.PlayUI("Whoosh")
	log("OfferShown", spec.id)
	local id = spec.id
	task.delay(CardSeconds, function()
		if current == id and os.clock() - shownAt >= CardSeconds - 0.1 then hide() end
	end)
end

-- a window opening hides the card (it comes back only with its next moment)
task.spawn(function()
	while true do
		task.wait(0.5)
		if current and (UIBus.MenuOpen or UIBus.CoverOpen(player.PlayerGui)) then hide() end
	end
end)

------------------------------------------------------------------------
-- The moments
------------------------------------------------------------------------
local lastStamina = -math.huge
local shakeShown = false
local spurtShown = {} -- [growth spurt number] = true

-- Stamina ran out
player:GetAttributeChangedSignal("StaminaRecovering"):Connect(function()
	if player:GetAttribute("StaminaRecovering") ~= true or not forSale("EndlessStamina") then return end
	local data = ClientData.Get()
	if inTutorial(data) or not free() or os.clock() - lastStamina < StaminaEvery then return end
	local untilTime = player:GetAttribute("EndlessStaminaUntil")
	if type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow() then return end
	lastStamina = os.clock()
	local fx = Monetization.Effects
	show({ id = "Stamina", art = Products.EndlessStamina.art, title = "Endless Stamina · " .. fx.EndlessStaminaMinutes .. " min",
		text = "Stamina never runs out for " .. fx.EndlessStaminaMinutes .. " minutes of play.",
		buy = { { key = "EndlessStamina" } } })
end)

-- The last Energy Shake was drunk
local lastShakes = nil
task.spawn(function()
	local data = ClientData.Get()
	lastShakes = tonumber(data.items and data.items.Shake) or 0
	ClientData.Changed:Connect(function(path, value)
		if path[1] ~= "items" then return end
		local now = tonumber(ClientData.Get().items.Shake) or 0
		local before = lastShakes
		lastShakes = now
		if before == nil or before <= 0 or now > 0 or shakeShown or not forSale("ShakePack") then return end
		if inTutorial(ClientData.Get()) or not free() then return end
		shakeShown = true
		local pack = Monetization.Effects.ShakePackSize or 3
		show({ id = "ShakeOut", art = Products.ShakePack.art, title = "Shake Bundle · " .. pack .. " shakes",
			text = "Full stamina + " .. math.floor((Stamina.Shake.GainsBoost - 1) * 100 + 0.5) .. "% gains each. Or " .. Stamina.Shake.Cost .. " coins at the shake machine.",
			buy = { { key = "ShakePack" } } })
	end)
end)

-- After a Growth Spurt (its celebration first)
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind ~= "GrowthSpurt" or type(info) ~= "table" or not forSale("CoinsSmall") then return end
	local spurt = tonumber(info.spurts) or 0
	if spurtShown[spurt] then return end
	spurtShown[spurt] = true
	task.delay(SpurtDelay, function()
		local data = ClientData.Get()
		if inTutorial(data) then return end
		-- (wait a little for a window the spurt opened, e.g. a reward, to close; give up after half a minute)
		local waited = 0
		while not free() and waited < 30 do
			task.wait(1)
			waited += 1
		end
		if not free() then return end
		local buy = {}
		for _, key in ipairs({ "CoinsSmall", "CoinsMedium", "CoinsLarge" }) do
			if forSale(key) then table.insert(buy, { key = key, label = Kit.Short(Products[key].coins) }) end
		end
		if #buy == 0 then return end
		show({ id = "AfterSpurt", art = Products.CoinsMedium.art, title = "Boost your next spurt",
			text = "Coins buy Energy Shakes and boosts that help you train.", buy = buy })
	end)
end)
