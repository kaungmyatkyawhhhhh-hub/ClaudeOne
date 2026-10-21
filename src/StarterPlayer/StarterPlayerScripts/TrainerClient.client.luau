-- TrainerClient (prompt 24, 21 Oct; was the COACHES hire window): the TRAINER AGENCY. Trainers come from coin rolls, like
-- eggs in pet games (Config/Trainers; every roll is made on the server, TrainerService). Coins only, the odds always shown.
--   * The window (the Trainers tile in the side menu, or the Agency desk's "Roll trainers" prompt): on the left the odds
--     list (all 8 trainers: rarity color, 3D portrait, name, boost, chance; Secret is a black "???" until you own him); on
--     the right the pity counter ("Epic guaranteed in 37 rolls"), ROLL x1 and ROLL x3 (x3 from Growth Spurt 2) with the
--     price, AUTO ROLL (keeps rolling while you have coins, stops on Epic or better or when you tap Stop), auto-delete
--     toggles (Common, Uncommon duplicates become coins), MY TRAINERS (the Inventory's Trainers tab) and the +1 slot pass.
--   * The roll (~1.5 s, tap to skip): a capsule card drops in, shakes and glows in the rarity color, cracks open, the trainer
--     appears in 3D in a pose with his name and rarity banner. Rarer = bigger: Epic a purple burst, Legendary a gold
--     explosion and a slower build, Mythic a screen shake and red-purple lightning, Secret goes dark first, Eternal a white
--     flash, stars and a swell. Layered sounds (Config.AlterThemes.Sounds).
--   * Legendary and better: the whole server is told (a chat line + a toast); Secret and Eternal: a big banner too.
--   * The odds boards over the Agency desks (tag AgencyBoard, tools/builders/TrainerAgency) are filled here from the config.
-- The trainers themselves are drawn by TrainerFollowClient; owning / equipping / Golden: Inventory > Trainers
-- (Shared/UI/TrainersPanel).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trainers = require(Shared.Config.Trainers)
local PumpShop = require(Shared.Config.PumpShop)
local Monetization = require(Shared.Config.Monetization)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local TrainerPortrait = require(Shared.UI.TrainerPortrait)
local AlterFX = require(Shared.VFX.AlterFX)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Trainers", 60) :: RemoteEvent
if not remote then return end -- the trainer service didn't start

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 780, 306 -- (fits 667 x 375: 702 x 284 px)
local LEFT_W = 372
local PASS = Monetization.PassByKey[Trainers.ExtraSlotPass]
local LUCKIEST = AlterFX.TitleFont

local function tween(instance, props, time, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function hex(c) return Color3.fromHex(c) end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local function data() return ClientData.Get() or {} end
local function state() return Trainers.Migrate(data().trainers) end
local function spurts() return data().growthSpurts or 0 end
local function price(): number return Trainers.RollPrice(PumpShop.Rate(spurts())) end
local function multiOpen(): boolean return spurts() >= Trainers.MultiRollFromSpurt end
local function ownsAny(id: string): boolean
	local s = state()
	return (s.owned[id] or 0) > 0 or (s.golden[id] or 0) > 0
end
local function chanceText(chance: number): string
	if chance >= 1 then return string.format("%g%%", chance) end
	return string.format("%g%% · 1 in %s", chance, Kit.Format(math.floor(100 / chance + 0.5)))
end
local function rarityOf(trainer) return Trainers.RarityById[trainer.rarity] end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local menuButton = SideMenu.Add("Trainers", "Trainers", Icons.Clipboard, 7.5)
local modal = Kit.Modal({ name = "Trainers", title = "Trainer Agency", width = W, height = H, displayOrder = 25, coins = true })

-- the odds list
local odds = New("ScrollingFrame", { Name = "Odds", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0, LEFT_W, 1, 0),
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
	Theme.List(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local rows = {}
for order, trainer in ipairs(Trainers.List) do
	local rarity = rarityOf(trainer)
	local row = New("Frame", { Name = trainer.id, LayoutOrder = order, BackgroundColor3 = Color3.fromHex("#1C1C21"), Size = UDim2.new(1, -8, 0, 28),
		Parent = odds }, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	New("Frame", { Name = "Chip", BackgroundColor3 = hex(rarity.color), Size = UDim2.new(0, 5, 1, -8), Position = UDim2.fromOffset(4, 4), Parent = row },
		{ New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local portraitHolder = New("Frame", { Name = "PortraitHolder", BackgroundColor3 = Color3.fromHex("#141417"), Position = UDim2.fromOffset(13, 2),
		Size = UDim2.fromOffset(24, 24), ClipsDescendants = true, Parent = row }, { New("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	local rarityLabel = Kit.Text({ Name = "Rarity", Text = string.upper(rarity.name), Font = "Title", TextSize = 10, TextColor3 = hex(rarity.color),
		Position = UDim2.fromOffset(44, 1), Size = UDim2.fromOffset(84, 13), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	if rarity.id == "Secret" then rarityLabel.TextColor3 = hex(rarity.color2) end
	local nameLabel = Kit.Text({ Name = "Name", Text = trainer.name, Font = "Strong", TextSize = 12, Position = UDim2.fromOffset(44, 13),
		Size = UDim2.fromOffset(110, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local perkLabel = Kit.Text({ Name = "Perk", Text = trainer.perkText, Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(150, 0),
		Size = UDim2.new(1, -258, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = row })
	local chanceLabel = Kit.Text({ Name = "Chance", Text = chanceText(rarity.chance), Font = "Number", TextSize = 11, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 16), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	rows[trainer.id] = { row = row, holder = portraitHolder, name = nameLabel, perk = perkLabel, chance = chanceLabel, trainer = trainer, shownAs = nil }
end
local function refreshRows()
	for id, r in pairs(rows) do
		local hidden = rarityOf(r.trainer).hidden == true and not ownsAny(id)
		r.name.Text = if hidden then "???" else r.trainer.name
		r.perk.Text = if hidden then "???" else r.trainer.perkText
		local s = state()
		local count = (s.owned[id] or 0) + (s.golden[id] or 0)
		if count > 0 then r.name.Text ..= "  x" .. count end
		local want = if hidden then "silhouette" else "full"
		if r.shownAs ~= want then
			r.shownAs = want
			for _, child in ipairs(r.holder:GetChildren()) do
				if child:IsA("ViewportFrame") then child:Destroy() end
			end
			TrainerPortrait.New(id, { Size = UDim2.fromScale(1, 1), shot = "bust", pose = "Relaxed", silhouette = hidden, Parent = r.holder })
		end
	end
end

-- the right side
local right = New("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromOffset(LEFT_W + 10, 0), Size = UDim2.new(1, -(LEFT_W + 10), 1, 0),
	Parent = modal.body })
local pity = Kit.Text({ Name = "Pity", Text = "", Font = "Title", TextSize = 14, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
	Parent = right })
Kit.GoldText(pity)
local _pityBar, setPity = Kit.Bar(hex(Trainers.RarityById.Epic.color), { Name = "PityBar", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -4, 0, 10), Parent = right })
local rollOne = Kit.Button("Gold", "Roll x1", { Name = "RollOne", Position = UDim2.fromOffset(0, 42), Parent = right }, { width = 180, height = 52, textSize = 18, icon = "coin" })
local rollThree = Kit.Button("Gold", "Roll x3", { Name = "RollThree", Position = UDim2.fromOffset(190, 42), Parent = right }, { width = 180, height = 52, textSize = 18, icon = "coin" })
local priceLine = Kit.Text({ Name = "PriceLine", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(0, 96),
	Size = UDim2.new(1, -4, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = right })
-- auto roll
Kit.Text({ Name = "AutoLabel", Text = "AUTO ROLL", Font = "Title", TextSize = 13, Position = UDim2.fromOffset(0, 116), Size = UDim2.fromOffset(110, 30),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = right })
local autoOn = false
local autoLoop -- (below)
local _autoToggle, setAutoToggle = Kit.Toggle(false, function(on)
	autoOn = on
	if on then task.spawn(autoLoop) end
end, { Name = "AutoToggle", Position = UDim2.fromOffset(104, 116), Size = UDim2.fromOffset(66, 30), Parent = right })
local autoHint = Kit.Text({ Name = "AutoHint", Text = "Stops on Epic or better", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted,
	Position = UDim2.fromOffset(180, 116), Size = UDim2.new(1, -184, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = right })
-- auto-delete toggles
Kit.Text({ Name = "DeleteLabel", Text = "AUTO-DELETE DUPLICATES", Font = "Title", TextSize = 11, Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 14),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = right })
local deleteToggles = {}
for i, rarityId in ipairs(Trainers.AutoDeleteRarities) do
	local x = (i - 1) * 150
	Kit.Text({ Text = Trainers.RarityById[rarityId].name, Font = "Strong", TextSize = 12, TextColor3 = hex(Trainers.RarityById[rarityId].color),
		Position = UDim2.fromOffset(x, 166), Size = UDim2.fromOffset(78, 30), TextXAlignment = Enum.TextXAlignment.Left, Parent = right })
	local toggle, set = Kit.Toggle(false, function(on)
		Audio.PlayUI("Click")
		remote:FireServer("AutoDelete", rarityId, on)
	end, { Name = "Delete" .. rarityId, Position = UDim2.fromOffset(x + 78, 166), Size = UDim2.fromOffset(60, 30), Parent = right })
	deleteToggles[rarityId] = { button = toggle, set = set }
end
-- bottom: my trainers, slots, the +1 slot pass
local myTrainers = Kit.Button("Quiet", "My trainers", { Name = "MyTrainers", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Parent = right },
	{ width = 150, height = 44, textSize = 14 })
local slotButton = Kit.Button("Quiet", "+1 slot", { Name = "ExtraSlot", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, 0), Parent = right },
	{ width = 120, height = 44, textSize = 14 })
local slotsLine = Kit.Text({ Name = "Slots", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 158, 1, -14), Size = UDim2.fromOffset(110, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = right })
slotButton.Visible = PASS ~= nil and PASS.id ~= nil
if PASS and PASS.id then
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(PASS.id, Enum.InfoType.GamePass) end)
		if ok and info and info.PriceInRobux then Kit.SetButton(slotButton, nil, "R$ " .. Kit.Format(info.PriceInRobux) .. " · +1 slot") end
	end)
end
slotButton.Activated:Connect(function()
	if PASS and PASS.id and not player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) then MarketplaceService:PromptGamePassPurchase(player, PASS.id) end
end)
myTrainers.Activated:Connect(function()
	Audio.PlayUI("Click")
	modal.close()
	UIBus.OpenInventory:Fire("Trainers")
end)

local function refresh()
	local s = state()
	local p = price()
	local left = Trainers.Pity - (s.pity or 0)
	pity.Text = string.upper(Trainers.PityRarity) .. " GUARANTEED IN " .. left .. " ROLL" .. (if left == 1 then "" else "S")
	setPity((s.pity or 0) / Trainers.Pity)
	local coins = data().coins or 0
	Kit.SetButton(rollOne, if coins >= p then "Gold" else "Disabled", "Roll x1 · " .. Kit.Short(p))
	if multiOpen() then
		Kit.SetButton(rollThree, if coins >= p * Trainers.MultiRoll then "Gold" else "Disabled", "Roll x3 · " .. Kit.Short(p * Trainers.MultiRoll))
	else
		Kit.SetButton(rollThree, "Disabled", "x3 at Spurt " .. Trainers.MultiRollFromSpurt)
	end
	priceLine.Text = "One roll = " .. Kit.Format(p) .. " coins (about " .. Trainers.RollMinutes .. " min of training). Coins only."
	for rarityId, t in pairs(deleteToggles) do t.set(s.autoDelete[rarityId] == true) end
	local slots = player:GetAttribute("TrainerSlots") or 1
	local following = player:GetAttribute("Trainers")
	local n = 0
	if type(following) == "string" then for _ in string.gmatch(following, "[^,]+") do n += 1 end end
	slotsLine.Text = "Following " .. n .. " / " .. slots
	slotButton.Visible = PASS ~= nil and PASS.id ~= nil and player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) ~= true
	refreshRows()
end

------------------------------------------------------------------------
-- The roll animation
------------------------------------------------------------------------
local overlay = Theme.ScreenGui({ Name = "TrainerRoll", DisplayOrder = 47, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
overlay.ScreenInsets = Enum.ScreenInsets.None
overlay.IgnoreGuiInset = true
local dim = New("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = overlay })
local fxLayer = New("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Parent = overlay })
local whiteFlash = New("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20,
	Parent = overlay })
local tapCatcher = New("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30,
	Parent = overlay })
local rollRoot = Kit.Root(overlay)
rollRoot.ZIndex = 5
local continueText = Kit.Text({ Name = "Continue", Text = "Tap to continue", Font = "Strong", TextSize = 14, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(300, 20), Visible = false, Parent = rollRoot })

local CARD = Vector2.new(170, 236)
local busy = false
local skip = false
local closeWanted = false
local cards = {}

local function shakeCamera(strength, time)
	if Theme.ReducedMotion() then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			local k = strength * (1 - (os.clock() - t0) / time)
			humanoid.CameraOffset = Vector3.new(math.random(-10, 10) / 10 * k, math.random(-10, 10) / 10 * k, 0)
			task.wait(0.025)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- a theme-like table for AlterFX helpers (particles, rings)
local function fxTheme(rarity)
	local accent = hex(rarity.color)
	local texture = if rarity.reveal == "cosmic" or rarity.reveal == "explosion" then "spark" elseif rarity.reveal == "lightning" then "lightning"
		elseif rarity.reveal == "dark" then "smoke" else "spark"
	return { accent = accent, particle = { texture = texture, color = accent, motion = if rarity.reveal == "cosmic" then "drift" else "rise" } }
end

local function makeCard(result, index: number, total: number)
	local trainer = Trainers.ById[result.id]
	local rarity = rarityOf(trainer)
	local x = (index - (total + 1) / 2) * (CARD.X + 16)
	local holder = New("Frame", { Name = "Card" .. index, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, -0.6, 0),
		Size = UDim2.fromOffset(CARD.X, CARD.Y), ZIndex = 5, Parent = rollRoot })
	local scale = New("UIScale", { Parent = holder })
	local body = New("Frame", { Name = "Body", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 5, ClipsDescendants = true,
		Parent = holder }, { New("UICorner", { CornerRadius = UDim.new(0, 16) }) })
	local stroke = New("UIStroke", { Color = Color3.fromHex("#55555E"), Thickness = 2, Parent = body })
	local glow = AlterFX.Image(holder, "rim", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 90, 1, 90),
		ImageColor3 = Color3.fromHex("#55555E"), ImageTransparency = 0.6, ZIndex = 4 })
	-- the content (hidden until the card cracks open)
	local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 6, Parent = body })
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex(rarity.color):Lerp(Color3.fromHex("#1C1C21"), 0.55), Color3.fromHex("#141417")), Parent = body })
	TrainerPortrait.New(trainer.id, { Size = UDim2.new(1, 0, 0, 150), ZIndex = 6, pose = "FrontDoubleBiceps", Parent = content })
	local banner = New("Frame", { Name = "Banner", BackgroundColor3 = hex(rarity.color), Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 22), ZIndex = 7,
		Parent = content })
	if rarity.color2 then New("UIGradient", { Color = ColorSequence.new(hex(rarity.color), hex(rarity.color2)), Parent = banner }) end
	local bannerText = Kit.Text({ Text = string.upper(rarity.name), Font = "Title", TextSize = 14, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = banner })
	bannerText.TextColor3 = if rarity.id == "Common" or rarity.id == "Eternal" or rarity.id == "Legendary" then Color3.fromHex("#141417") else Color3.new(1, 1, 1)
	local nameLabel = New("TextLabel", { BackgroundTransparency = 1, Text = string.upper(trainer.name), FontFace = LUCKIEST, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(6, 174), Size = UDim2.new(1, -12, 0, 26), ZIndex = 7, Parent = content })
	New("UIStroke", { Thickness = 2, Parent = nameLabel })
	local tag = if result.deleted then "Duplicate: +" .. Kit.Format(math.floor(price() * Trainers.AutoDeleteRefund)) .. " coins"
		elseif result.count == 1 then "NEW! " .. trainer.perkText
		else "x" .. result.count .. " · " .. math.min(result.count, Trainers.GoldenCount) .. "/" .. Trainers.GoldenCount .. " to Golden"
	Kit.Text({ Text = tag, Font = "Strong", TextSize = 11, TextColor3 = if result.deleted then Colors.Muted else Colors.Gold, Position = UDim2.fromOffset(6, 202),
		Size = UDim2.new(1, -12, 0, 28), TextWrapped = true, ZIndex = 7, Parent = content })
	-- the cover: a capsule with a big "?" and two halves that fly apart
	local cover = New("Frame", { Name = "Cover", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = body })
	local halves = {}
	for i, y in ipairs({ 0, 0.5 }) do
		local half = New("Frame", { Name = "Half" .. i, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0.5),
			ZIndex = 9, Parent = cover }, { New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#4A4A54"), Color3.fromHex("#25252B")) }) })
		halves[i] = half
	end
	New("Frame", { Name = "Seam", BackgroundColor3 = Color3.fromHex("#F6C75A"), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 3), ZIndex = 10, Parent = cover })
	local question = New("TextLabel", { BackgroundTransparency = 1, Text = "?", FontFace = LUCKIEST, TextScaled = true, TextColor3 = Color3.fromHex("#F6C75A"),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(90, 110), ZIndex = 11, Parent = cover })
	New("UIStroke", { Thickness = 3, Parent = question })
	return { holder = holder, scale = scale, body = body, stroke = stroke, glow = glow, content = content, cover = cover, halves = halves, question = question,
		rarity = rarity, trainer = trainer, result = result, x = x, revealed = false }
end

-- the crack: the cover splits, the content shows, the rarity's extras play
local function reveal(card, instant: boolean)
	if card.revealed then return end
	card.revealed = true
	local rarity = card.rarity
	local accent = hex(rarity.color)
	card.content.Visible = true
	card.stroke.Color = accent
	card.stroke.Thickness = 3
	card.glow.ImageColor3 = accent
	card.glow.ImageTransparency = 0.2
	if instant then
		card.cover.Visible = false
		return
	end
	-- the halves fly apart, a flash on the card, a ring
	tween(card.halves[1], { Position = UDim2.fromScale(0, -0.6), Rotation = -8 }, 0.35, Enum.EasingStyle.Quart)
	tween(card.halves[2], { Position = UDim2.fromScale(0, 1.1), Rotation = 8 }, 0.35, Enum.EasingStyle.Quart)
	tween(card.question, { TextTransparency = 1 }, 0.15)
	task.delay(0.36, function() card.cover.Visible = false end)
	card.scale.Scale = 0.85
	tween(card.scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
	AlterFX.Ring(fxLayer, accent, 120, 700, 0.6, UDim2.new(0.5, card.x * rollRoot:FindFirstChildOfClass("UIScale").Scale, 0.5, 0))
	AlterFX.Sound("ImpactPunch", { volume = 0.7 })
	AlterFX.Sound("Chime", { pitch = 0.85 + rarity.index * 0.06 })
	local theme = fxTheme(rarity)
	local reveal_ = rarity.reveal
	if reveal_ == "burst" or reveal_ == "explosion" or reveal_ == "lightning" or reveal_ == "dark" or reveal_ == "cosmic" then
		AlterFX.Sound("Shimmer")
		AlterFX.UIParticles(fxLayer, theme, if reveal_ == "burst" then 12 else 20, 0.1, { burst = true, peak = true, scale = 1.3 })
	end
	if reveal_ == "explosion" then
		AlterFX.Sound("Brass")
		AlterFX.Sound("ImpactSub")
		for i = 1, 3 do task.delay(i * 0.12, function() AlterFX.Ring(fxLayer, accent, 100, 900 + i * 200, 0.7) end) end
		AlterFX.ScreenFX(fxLayer, { accent = accent, particle = theme.particle }, "rise", 1.5)
	elseif reveal_ == "lightning" then
		AlterFX.Sound("Thunder")
		AlterFX.Sound("Crackle", { delay = 0.05 })
		AlterFX.Sound("ImpactSub")
		shakeCamera(0.6, 0.45)
		AlterFX.ScreenFX(fxLayer, { accent = hex(rarity.color2 or rarity.color), particle = theme.particle }, "storm", 1.4)
	elseif reveal_ == "dark" then
		AlterFX.Sound("FlashBoom")
		AlterFX.Sound("ImpactSub")
		tween(dim, { BackgroundTransparency = 0.45 }, 0.6)
	elseif reveal_ == "cosmic" then
		whiteFlash.BackgroundTransparency = 0
		tween(whiteFlash, { BackgroundTransparency = 1 }, 0.8)
		AlterFX.Sound("FlashBoom")
		AlterFX.Sound("CosmicSwell", { delay = 0.1 })
		AlterFX.Sound("CheerBig", { delay = 0.4 })
		AlterFX.ScreenFX(fxLayer, { accent = accent, particle = { texture = "spark", color = Color3.new(1, 1, 1), motion = "drift" } }, "legend", 2)
		AlterFX.UIParticles(fxLayer, { accent = accent, particle = { texture = "spark", color = Color3.fromHex("#FFF3C4"), motion = "fall" } }, 18, 2)
	end
end

-- results = the server's list; quick = auto roll (shorter, closes by itself unless something big came)
local function play(results, quick: boolean)
	busy = true
	skip = false
	closeWanted = false
	for _, c in ipairs(cards) do c.holder:Destroy() end
	cards = {}
	for _, child in ipairs(fxLayer:GetChildren()) do child:Destroy() end
	overlay.Enabled = true
	continueText.Visible = false
	dim.BackgroundTransparency = 1
	tween(dim, { BackgroundTransparency = 0.35 }, 0.25)
	local best = 0
	for i, result in ipairs(results) do
		local card = makeCard(result, i, #results)
		table.insert(cards, card)
		best = math.max(best, card.rarity.index)
	end
	local bigFrom = Trainers.RarityById[Trainers.AutoStopRarity].index
	local speed = if quick then 0.55 else 1
	AlterFX.Sound("Riser", { fadeIn = 0.2 })
	-- the build-up: longer for the rare ones (Legendary+ "slow-mo")
	local build = (if best >= Trainers.RarityById.Legendary.index then 1.05 else 0.45) * speed
	local function wait_(t)
		local t0 = os.clock()
		while os.clock() - t0 < t and not skip do task.wait() end
	end
	-- drop in
	for i, card in ipairs(cards) do
		task.delay((i - 1) * 0.08 * speed, function()
			tween(card.holder, { Position = UDim2.new(0.5, card.x, 0.5, 8) }, 0.35 * speed, Enum.EasingStyle.Back)
		end)
	end
	wait_((0.38 + 0.08 * (#cards - 1)) * speed)
	-- Secret: the screen goes dark first
	if best == Trainers.RarityById.Secret.index and not skip then tween(dim, { BackgroundTransparency = 0.03 }, 0.3 * speed) end
	-- shake + glow toward the rarity color (Secret keeps its mystery: gray)
	local t0 = os.clock()
	while os.clock() - t0 < build and not skip do
		local k = (os.clock() - t0) / build
		for _, card in ipairs(cards) do
			local target = if card.rarity.hidden then Color3.fromHex("#55555E") else hex(card.rarity.color)
			card.holder.Rotation = math.sin(os.clock() * 55) * (2 + k * 5)
			card.stroke.Color = Color3.fromHex("#55555E"):Lerp(target, k)
			card.stroke.Thickness = 2 + k * 3
			card.glow.ImageColor3 = card.stroke.Color
			card.glow.ImageTransparency = 0.6 - k * 0.4
		end
		AlterFX.Sound("Stamp", { volume = 0.15 + k * 0.2, pitch = 1 + k * 0.4 })
		task.wait(0.12)
	end
	for _, card in ipairs(cards) do card.holder.Rotation = 0 end
	-- crack open, one after another
	for i, card in ipairs(cards) do
		if skip then
			reveal(card, true)
		else
			reveal(card, false)
			if i < #cards then wait_(0.22 * speed) end
		end
	end
	if skip then
		for _, card in ipairs(cards) do
			card.holder.Position = UDim2.new(0.5, card.x, 0.5, 8)
			reveal(card, true)
		end
	end
	-- done: wait for a tap (auto roll: closes by itself unless something big came)
	busy = false
	continueText.Visible = true
	skip = false
	if quick and best < bigFrom then
		local t1 = os.clock()
		while os.clock() - t1 < 0.7 and not closeWanted do task.wait() end
		closeWanted = true
	end
	while not closeWanted do task.wait() end
	tween(dim, { BackgroundTransparency = 1 }, 0.2)
	for _, card in ipairs(cards) do tween(card.scale, { Scale = 0.85 }, 0.15) end
	task.wait(0.2)
	overlay.Enabled = false
	for _, c in ipairs(cards) do c.holder:Destroy() end
	cards = {}
	return best
end
tapCatcher.Activated:Connect(function()
	if busy then skip = true else closeWanted = true end
end)

------------------------------------------------------------------------
-- Rolling and Auto Roll
------------------------------------------------------------------------
local waiting = false
local lastBest = 0
local resultSignal = Instance.new("BindableEvent")
local function requestRoll(count: number, auto: boolean): boolean
	if waiting or busy or overlay.Enabled then return false end
	local cost = price() * count
	if (data().coins or 0) < cost then
		Notify.Toast("Not enough coins", "A roll costs " .. Kit.Format(cost) .. " coins", "coin", Colors.Red, "trainercoins")
		return false
	end
	waiting = true
	remote:FireServer("Roll", count, auto)
	local done = false
	local connection = resultSignal.Event:Connect(function() done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 6 do task.wait() end
	connection:Disconnect()
	waiting = false
	return done
end

function autoLoop()
	autoHint.Text = "Rolling... tap Off to stop"
	while autoOn do
		if (data().coins or 0) < price() then
			Notify.Toast("Auto Roll stopped", "Out of coins", "coin", Colors.Red, "trainerauto")
			break
		end
		if not requestRoll(1, true) then break end
		while overlay.Enabled do task.wait() end
		if lastBest >= Trainers.RarityById[Trainers.AutoStopRarity].index then
			Notify.Toast("Auto Roll stopped", "You pulled a " .. Trainers.Rarities[lastBest].name .. "!", "star", hex(Trainers.Rarities[lastBest].color), "trainerauto")
			break
		end
		task.wait(0.15)
	end
	autoOn = false
	setAutoToggle(false)
	autoHint.Text = "Stops on Epic or better"
end

rollOne.Activated:Connect(function()
	Audio.PlayUI("Click")
	task.spawn(requestRoll, 1, false)
end)
rollThree.Activated:Connect(function()
	if not multiOpen() then
		Notify.Toast("Roll x3", "Opens at Growth Spurt " .. Trainers.MultiRollFromSpurt, "lock", Colors.Muted, "trainerx3")
		return
	end
	Audio.PlayUI("Click")
	task.spawn(requestRoll, Trainers.MultiRoll, false)
end)

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function open()
	refresh()
	if modal.isOpen() then return end
	menuButton:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	modal.open()
	Theme.Pulse(rollOne, function() return modal.isOpen() end)
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
UIBus.OpenAgency.Event:Connect(function()
	if not modal.isOpen() then UIBus.PanelOpened("Trainers") end
	open()
end)
ClientData.Changed:Connect(function(path)
	if modal.isOpen() and (path[1] == "coins" or path[1] == "trainers" or path[1] == "growthSpurts") then refresh() end
end)
player:GetAttributeChangedSignal("TrainerSlots"):Connect(function() if modal.isOpen() then refresh() end end)

------------------------------------------------------------------------
-- Server events
------------------------------------------------------------------------
local function announce(info)
	local rarity = Trainers.RarityById[info.rarity]
	local trainer = Trainers.ById[info.trainer]
	if not rarity or not trainer then return end
	local who = if info.userId == player.UserId then "You" else tostring(info.name)
	local text = who .. " pulled " .. (if rarity.id == "Eternal" or rarity.id == "Epic" then "an " else "a ") .. string.upper(rarity.name) .. " trainer: " .. trainer.name .. "!"
	-- a chat-style line for everyone
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(string.format('<font color="#%s"><b>%s</b></font>', hex(rarity.color2 or rarity.color):ToHex(), text))
		end
	end)
	-- (your own pull: the reveal is the celebration; only the chat line)
	if info.userId == player.UserId then return end
	if rarity.announce == "banner" then
		Notify.Reward(string.upper(rarity.name) .. " PULL!", text, "star", hex(rarity.color2 or rarity.color), "TitleUnlocked", "trainerpull")
	else
		Notify.Toast(string.upper(rarity.name) .. " pull", text, "star", hex(rarity.color), "trainerpull")
	end
end

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" then
		if not modal.isOpen() then UIBus.PanelOpened("Trainers") end
		open()
	elseif kind == "Rolled" then
		resultSignal:Fire()
		local results = type(info.results) == "table" and info.results or {}
		task.spawn(function()
			lastBest = play(results, info.auto == true) or 0
			if modal.isOpen() then refresh() end
		end)
	elseif kind == "Failed" then
		resultSignal:Fire()
		Notify.Toast(tostring(info.text), nil, "coin", Colors.Red, "trainerfail")
		if info.auto then autoOn = false end
	elseif kind == "Golden" then
		local trainer = Trainers.ById[info.id]
		if trainer then
			Notify.Reward("GOLDEN TRAINER", "Golden " .. trainer.name .. " · " .. Trainers.PerkText(trainer, true), "star", Colors.Gold, "TitleUnlocked")
		end
	elseif kind == "Pulled" then
		announce(info)
	end
end)

------------------------------------------------------------------------
-- The odds boards over the Agency desks (tag AgencyBoard): filled from the config, Secret "???" until you own him
------------------------------------------------------------------------
local boards = {}
local function fillBoard(part: BasePart)
	local gui = part:FindFirstChild("AgencyGui") or Instance.new("SurfaceGui")
	gui.Name = "AgencyGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui:ClearAllChildren()
	gui.Parent = part
	local root = New("Frame", { BackgroundColor3 = Color3.fromHex("#141417"), Size = UDim2.fromScale(1, 1), Parent = gui }, {
		New("UIPadding", { PaddingTop = UDim.new(0.03, 0), PaddingBottom = UDim.new(0.03, 0), PaddingLeft = UDim.new(0.03, 0), PaddingRight = UDim.new(0.03, 0) }),
	})
	local title = New("TextLabel", { BackgroundTransparency = 1, Text = "TRAINER AGENCY", FontFace = LUCKIEST, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 0.13), Parent = root })
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#FFF3C4"), Color3.fromHex("#C98A12")), Parent = title })
	New("TextLabel", { BackgroundTransparency = 1, Text = "Roll for a coach with coins · odds always shown · Epic guaranteed every " .. Trainers.Pity .. " rolls",
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium), TextScaled = true, TextColor3 = Color3.fromHex("#B8B8BE"),
		Position = UDim2.fromScale(0, 0.13), Size = UDim2.fromScale(1, 0.05), Parent = root })
	local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.2), Size = UDim2.fromScale(1, 0.8), Parent = root }, {
		New("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local rowH = 1 / #Trainers.List - 0.013
	for order, trainer in ipairs(Trainers.List) do
		local rarity = rarityOf(trainer)
		local hidden = rarity.hidden and not ownsAny(trainer.id)
		local row = New("Frame", { LayoutOrder = order, BackgroundColor3 = Color3.fromHex("#1F1F25"), Size = UDim2.fromScale(1, rowH), Parent = list }, {
			New("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
		})
		New("Frame", { BackgroundColor3 = hex(rarity.color), Size = UDim2.fromScale(0.015, 0.8), Position = UDim2.fromScale(0.01, 0.1), Parent = row })
		local function cell(text, x, w, color, align)
			return New("TextLabel", { BackgroundTransparency = 1, Text = text, FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				TextScaled = true, TextColor3 = color, TextXAlignment = align or Enum.TextXAlignment.Left, Position = UDim2.fromScale(x, 0.12),
				Size = UDim2.fromScale(w, 0.76), Parent = row })
		end
		cell(string.upper(rarity.name), 0.04, 0.2, if rarity.hidden then hex(rarity.color2) else hex(rarity.color))
		cell(if hidden then "???" else trainer.name, 0.25, 0.23, Color3.new(1, 1, 1))
		cell(if hidden then "???" else trainer.perkText, 0.49, 0.33, Color3.fromHex("#B8B8BE"))
		cell(chanceText(rarity.chance), 0.8, 0.18, Color3.fromHex("#F6C75A"), Enum.TextXAlignment.Right)
	end
end
local function addBoard(part)
	if not part:IsA("BasePart") or boards[part] then return end
	boards[part] = true
	fillBoard(part)
end
task.spawn(function()
	ClientData.Get()
	for _, part in ipairs(CollectionService:GetTagged("AgencyBoard")) do addBoard(part) end
	CollectionService:GetInstanceAddedSignal("AgencyBoard"):Connect(addBoard)
	-- (owning the Secret one reveals him on the boards)
	local secretShown = nil
	ClientData.Changed:Connect(function(path)
		if path[1] ~= "trainers" then return end
		local now = ownsAny(Trainers.ByRarity.Secret.id)
		if now ~= secretShown then
			secretShown = now
			for part in pairs(boards) do if part.Parent then fillBoard(part) end end
		end
	end)
end)
