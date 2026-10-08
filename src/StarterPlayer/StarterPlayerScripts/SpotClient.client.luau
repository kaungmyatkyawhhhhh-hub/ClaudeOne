-- SpotClient: spotting on the client (owner's redo, 8 Oct night; the server side is SpotService, numbers in
-- Config.Spotting).
--  * Tap / click a lifter's body (another player on a spottable machine): a small popup "SPOT" / X next to them.
--  * As the lifter: a small corner card "<name> wants to spot you" with ACCEPT / X and a draining bar; it closes on its
--    own after the timeout. "Spot requests: Off" in Settings stops them reaching you (the server checks it).
--  * As a spotter: a compact bottom panel with the lifter's name, a chunky segmented meter and EXIT; a click or tap ANYWHERE
--    is a push (owner: no push button; F on a keyboard too). The meter shows your pushes a second (white = clicking).
--    Moving or jumping also stops spotting.
--  * As the lifter while spotted: "SPOTTED x1.35" (gold) and the spotters' names, a small label beside you in the world,
--    next to where the EXP popups fly.
--  * Every client poses every spotter (character attributes SpotLifter / SpotType / SpotSlot from the server): "hands"
--    spotters reach for the lifter's bar (their hands under it, following it each rep); "hype" spotters clap, point and
--    fist pump in turns. Joints are written after the Animator, like PoseController.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Spotting = require(Shared.Config.Spotting)
local Machines = require(Shared.Config.Machines)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Remotes:WaitForChild("Spot", 30)
if not remote then return end -- (the spotting service didn't start)

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local gui = Theme.ScreenGui({ Name = "Spotting", DisplayOrder = 8, Parent = player:WaitForChild("PlayerGui") })

local function machineOfUser(userId: number)
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == userId then return model end
	end
	return nil
end
local function amLifting(): boolean
	return machineOfUser(player.UserId) ~= nil
end
local spottingNow = false

------------------------------------------------------------------------
-- 1. Tap a lifter: the SPOT popup
------------------------------------------------------------------------
local popup = Theme.Panel({ Name = "SpotPopup", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY, Visible = false, Parent = gui }, {
	Theme.Pad("S"), Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local popupName = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, Theme.MinTouch), Parent = popup })
local spotButton = Theme.Button("Primary", { LayoutOrder = 2, Size = UDim2.fromOffset(96, Theme.MinTouch), Parent = popup }, {
	Theme.Text({ Text = "Spot", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local popupClose = Theme.Button("Secondary", { LayoutOrder = 3, Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = popup }, {
	Theme.Text({ Text = "X", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local popupTarget = nil -- { player, shownAt }

local function hidePopup()
	popup.Visible = false
	popupTarget = nil
end
popupClose.Activated:Connect(hidePopup)
spotButton.Activated:Connect(function()
	if popupTarget then remote:FireServer("Request", popupTarget.player.UserId) end
	Audio.PlayUI("Click")
	hidePopup()
end)

-- the player whose character a screen point is on, if they lift on a spottable machine
local function lifterAt(screen: Vector2): (Player?, Vector3?)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 120, params)
	local part = hit and hit.Instance
	local character = part and part:FindFirstAncestorOfClass("Model")
	while character and not character:FindFirstChildOfClass("Humanoid") do
		character = character:FindFirstAncestorOfClass("Model")
	end
	local other = character and Players:GetPlayerFromCharacter(character)
	if not other or other == player then return nil end
	local model = machineOfUser(other.UserId)
	local machine = model and Machines.ById[model:GetAttribute("MachineId")]
	if not (machine and machine.spotType) then return nil end
	return other, hit.Position
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if spottingNow or amLifting() or UIBus.MenuOpen then return end
	local screen = Vector2.new(input.Position.X, input.Position.Y)
	local other, at = lifterAt(screen)
	if not other then return end
	local camera = workspace.CurrentCamera
	local point = camera:WorldToViewportPoint((at :: Vector3) + Vector3.new(0, 1.5, 0))
	local size = camera.ViewportSize
	popupName.Text = other.DisplayName
	popup.Position = UDim2.fromOffset(math.clamp(point.X, 140, size.X - 140), math.clamp(point.Y, 120, size.Y - 20))
	popup.Visible = true
	popupTarget = { player = other, shownAt = os.clock() }
end)

------------------------------------------------------------------------
-- 2. The lifter's request cards (top left: while lifting the top bar is hidden and the right side has the body map)
------------------------------------------------------------------------
local cards = New("Frame", { Name = "Requests", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, Spacing.L, 0, 64),
	Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui },
	{ Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local openCards = {} -- [userId] = card

local function closeCard(userId: number)
	local card = openCards[userId]
	if card then
		openCards[userId] = nil
		card:Destroy()
	end
end

local function requestCard(info)
	local userId, name, timeout = info.userId, tostring(info.name or ""), tonumber(info.timeout) or Spotting.RequestTimeout
	if type(userId) ~= "number" then return end
	closeCard(userId)
	local card = Theme.Panel({ Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cards }, {
		Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	openCards[userId] = card
	Theme.Text({ LayoutOrder = 1, Text = name .. " wants to spot you", Font = "Regular", TextSize = "Body", TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	local row = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = card },
		{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local accept = Theme.Button("Primary", { LayoutOrder = 1, Size = UDim2.new(1, -(Theme.MinTouch + Spacing.S), 1, 0), Parent = row }, {
		Theme.Text({ Text = "Accept", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	local decline = Theme.Button("Secondary", { LayoutOrder = 2, Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = row }, {
		Theme.Text({ Text = "X", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	-- the time left: a thin draining bar
	local track = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Colors.Chalk, BackgroundTransparency = 0.85, Parent = card },
		{ New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Chalk, BackgroundTransparency = 0.2, Parent = track },
		{ New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
	Theme.Tween(fill, { Size = UDim2.fromScale(0, 1) }, timeout, Enum.EasingStyle.Linear)
	accept.Activated:Connect(function()
		remote:FireServer("Respond", userId, true)
		closeCard(userId)
	end)
	decline.Activated:Connect(function()
		remote:FireServer("Respond", userId, false)
		closeCard(userId)
	end)
	task.delay(timeout, function() if openCards[userId] == card then closeCard(userId) end end)
	Audio.PlayUI("Click")
end

------------------------------------------------------------------------
-- 3. The spotter's panel (bottom centre): PUSH, the meter, EXIT
------------------------------------------------------------------------
-- The feel (owner, 9 Oct: "more dopamine for spotters"): every push answers at once (a ring where you clicked, a tick
-- that climbs in pitch with your combo, the combo number hopping); combo milestones (10 / 25 / 50 / 100 / 200) ding and
-- flash the panel gold; counting as clicking turns the border gold with a ding ("BOOSTING x1.35"); each of the lifter's
-- reps fills the coins bar (a plate per rep) and, if you were pushing, pops a gold "ASSIST" over them; a payout flies
-- coins from the bar to your coins pill with "+8 COINS"; the end shows what you did. Small and quick, nothing covers the
-- screen. Sounds: Config.Sounds Spot* (placeholders until the owner picks ids).
local SEGMENTS = 10
local COMBO_RESET = 1.2           -- seconds without a push before the combo starts again
local MILESTONES = { [10] = true, [25] = true, [50] = true, [100] = true, [200] = true }
local panel = Theme.Panel({ Name = "Spotter", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -Spacing.XL),
	Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = gui }, {
	Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
local panelStroke = panel:FindFirstChildOfClass("UIStroke")
local header = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = panel })
local spotTitle = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -90, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local comboHolder = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 90, 1, 0),
	BackgroundTransparency = 1, Parent = header })
local comboLabel = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Title", Upper = false, Size = UDim2.fromScale(1, 1),
	TextXAlignment = Enum.TextXAlignment.Right, Parent = comboHolder })
-- your push rate
local meter = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local segments = {}
for i = 1, SEGMENTS do
	segments[i] = New("Frame", { LayoutOrder = i, Size = UDim2.new(1 / SEGMENTS, -Spacing.XS, 1, 0), BackgroundColor3 = Colors.Chalk,
		BackgroundTransparency = 0.85, Parent = meter }, { New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
end
-- the coins bar: one small plate per lifter rep until the next payout
local payoutRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = panel })
local payoutLabel = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0, 120, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = payoutRow })
local plates = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(1, -128, 0, 8),
	BackgroundTransparency = 1, Parent = payoutRow }, { Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
local payoutPlates = {}
for i = 1, Spotting.RewardEvery do
	payoutPlates[i] = New("Frame", { LayoutOrder = i, Size = UDim2.new(1 / Spotting.RewardEvery, -Spacing.XS, 1, 0), BackgroundColor3 = Colors.Chalk,
		BackgroundTransparency = 0.85, Parent = plates }, { New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
end
local spotStatus = Theme.Text({ LayoutOrder = 4, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted,
	Size = UDim2.new(1, 0, 0, 18), Parent = panel })
local exitButton = Theme.Button("Secondary", { LayoutOrder = 5, Size = UDim2.fromOffset(120, Theme.MinTouch), Parent = panel }, {
	Theme.Text({ Text = "Exit", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

local assisted = {} -- [plate index] = true: that rep landed while you pushed (it stays gold until the payout)
local function setPayout(progress: number)
	if progress == 0 then table.clear(assisted) end
	for i, plate in ipairs(payoutPlates) do
		plate.BackgroundTransparency = if i <= progress then 0.1 else 0.85
		plate.BackgroundColor3 = if i <= progress and assisted[i] then Colors.Gold else Colors.Chalk
	end
	local left = Spotting.RewardEvery - progress
	payoutLabel.Text = if left == 1 then "Coins next rep" else "Coins in " .. left .. " reps"
end

-- a short text that floats up from a screen point and fades (combo milestones, "+8 COINS")
local function floatText(text: string, at: Vector2, color: Color3)
	local label = Theme.Text({ Text = text, Font = "SemiBold", TextSize = "Large", Upper = false, TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(220, 30), Parent = gui })
	Theme.TextShadow(label)
	Theme.Tween(label, { Position = UDim2.fromOffset(at.X, at.Y - 46) }, 0.8, Enum.EasingStyle.Quad)
	task.delay(0.35, function()
		Theme.Tween(label, { TextTransparency = 1 }, 0.45, Enum.EasingStyle.Quad)
		local shadow = label:FindFirstChildOfClass("UIStroke")
		if shadow then Theme.Tween(shadow, { Transparency = 1 }, 0.45, Enum.EasingStyle.Quad) end
	end)
	task.delay(0.85, function() label:Destroy() end)
end

local function panelTop(): Vector2
	return Vector2.new(panel.AbsolutePosition.X + panel.AbsoluteSize.X / 2, panel.AbsolutePosition.Y - 10)
end

-- a ring where you clicked (gold while you're boosting)
local serverClicking, boostShown = false, 1
local function ripple(at: Vector2)
	local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = if serverClicking then Colors.Gold else Colors.Chalk, BackgroundTransparency = 0.55, Parent = gui },
		{ New("UICorner", { CornerRadius = Theme.Corner.Round }) })
	local stroke = Theme.Stroke(if serverClicking then Colors.Gold else Colors.Chalk, 2, 0.2)
	stroke.Parent = ring
	Theme.Tween(ring, { Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1 }, 0.35, Enum.EasingStyle.Quad)
	Theme.Tween(stroke, { Transparency = 1 }, 0.35, Enum.EasingStyle.Quad)
	task.delay(0.4, function() ring:Destroy() end)
end

local function flashBorder(color: Color3)
	if not panelStroke then return end
	panelStroke.Color, panelStroke.Transparency = color, 0
	task.delay(0.15, function()
		if serverClicking then return end -- (gold stays while boosting)
		Theme.Tween(panelStroke, { Color = Colors.Border, Transparency = Theme.Alpha.Border }, 0.4, Enum.EasingStyle.Quad)
	end)
end

-- PUSH = a click / tap ANYWHERE on the screen (owner, 9 Oct: no push button), or F / R2; taps on buttons (EXIT) don't count
local myTaps = {}
local combo, lastPush = 0, 0
local function push(at: Vector2?)
	if not spottingNow then return end
	local now = os.clock()
	table.insert(myTaps, now)
	remote:FireServer("Push")
	combo = if now - lastPush > COMBO_RESET then 1 else combo + 1
	lastPush = now
	comboLabel.Text = "x" .. combo
	comboLabel.TextTransparency = 0
	comboLabel.TextColor3 = if combo >= 10 then Colors.Gold else Colors.Text
	-- the number hops (moved, not scaled: text stays crisp)
	comboLabel.Position = UDim2.fromOffset(0, -5)
	Theme.Tween(comboLabel, { Position = UDim2.fromOffset(0, 0) }, 0.18, Enum.EasingStyle.Back)
	Audio.PlayUI("SpotPush", { pitch = 1 + math.min(combo, 40) * 0.015 })
	if at then ripple(at) end
	if MILESTONES[combo] then
		Audio.PlayUI("SpotCombo")
		flashBorder(Colors.Gold)
		floatText("COMBO " .. combo, panelTop(), Colors.Gold)
	end
end
exitButton.Activated:Connect(function() remote:FireServer("Exit") end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not spottingNow then return end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		push(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		push(nil)
	end
end)
local PUSH_HINT = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap anywhere fast to push" else "Click anywhere fast to push"

local function setSpotting(on: boolean, info)
	spottingNow = on
	panel.Visible = on
	table.clear(myTaps)
	serverClicking = false
	combo, lastPush = 0, 0
	comboLabel.Text = ""
	if panelStroke then panelStroke.Color, panelStroke.Transparency = Colors.Border, Theme.Alpha.Border end
	if on then
		hidePopup()
		spotTitle.Text = string.upper("Spotting " .. tostring(info.lifter or ""))
		spotStatus.Text = PUSH_HINT .. " and boost their gains"
		spotStatus.TextColor3 = Colors.Muted
		setPayout(0)
	end
end

-- the boost turning on / off (from the server's State)
local function setBoosting(on: boolean)
	if on == serverClicking then return end
	serverClicking = on
	if on then
		Audio.PlayUI("SpotBoostOn")
		if panelStroke then
			panelStroke.Color = Colors.Gold
			Theme.Tween(panelStroke, { Transparency = 0.15 }, 0.2, Enum.EasingStyle.Quad)
		end
	elseif panelStroke then
		Theme.Tween(panelStroke, { Color = Colors.Border, Transparency = Theme.Alpha.Border }, 0.4, Enum.EasingStyle.Quad)
	end
end

-- "ASSIST" over the lifter's head when their rep lands while you push
local function assistPop()
	local character = player.Character
	local lifterId = character and character:GetAttribute("SpotLifter")
	local lifter = type(lifterId) == "number" and Players:GetPlayerByUserId(lifterId)
	local head = lifter and lifter.Character and lifter.Character:FindFirstChild("Head")
	if not head then return end
	local board = New("BillboardGui", { Size = UDim2.fromOffset(160, 36), StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0), AlwaysOnTop = true,
		LightInfluence = 0, MaxDistance = 80, Adornee = head, Parent = player:FindFirstChildOfClass("PlayerGui") })
	local label = Theme.Text({ Text = "ASSIST", Font = "SemiBold", TextSize = "Large", Upper = false, TextColor3 = Colors.Gold,
		Size = UDim2.fromScale(1, 1), Parent = board })
	Theme.TextShadow(label)
	label.Position = UDim2.fromOffset(0, 8)
	Theme.Tween(label, { Position = UDim2.fromOffset(0, -6) }, 0.25, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		Theme.Tween(label, { TextTransparency = 1 }, 0.35, Enum.EasingStyle.Quad)
		local shadow = label:FindFirstChildOfClass("UIStroke")
		if shadow then Theme.Tween(shadow, { Transparency = 1 }, 0.35, Enum.EasingStyle.Quad) end
	end)
	task.delay(0.85, function() board:Destroy() end)
	Audio.PlayUI("SpotAssist")
end

-- coins fly from the coins bar to the coins pill
local function coinBurst(coins: number)
	local from = Vector2.new(plates.AbsolutePosition.X + plates.AbsoluteSize.X / 2, plates.AbsolutePosition.Y)
	local topBar = player.PlayerGui:FindFirstChild("TopBar")
	local pill = topBar and topBar:FindFirstChild("Coins", true)
	local to = if pill and pill:IsA("GuiObject") and pill.AbsoluteSize.X > 0
		then Vector2.new(pill.AbsolutePosition.X + 22, pill.AbsolutePosition.Y + pill.AbsoluteSize.Y / 2)
		else Vector2.new(60, 40)
	for i = 1, math.clamp(coins, 4, 8) do
		local coin = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X + (i - 4) * 12, from.Y),
			Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Colors.Gold, Parent = gui }, { New("UICorner", { CornerRadius = Theme.Corner.Round }) })
		Theme.Stroke(Color3.fromHex("#B8862B"), 2, 0).Parent = coin
		task.delay(i * 0.05, function()
			Theme.Tween(coin, { Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(8, 8) }, 0.55, Enum.EasingStyle.Quad)
			task.delay(0.55, function() coin:Destroy() end)
		end)
	end
	floatText("+" .. coins .. " COINS", panelTop(), Colors.Gold)
	Audio.PlayUI("SpotPayout")
	-- the coins bar flashes gold, then starts again
	for _, plate in ipairs(payoutPlates) do
		plate.BackgroundColor3, plate.BackgroundTransparency = Colors.Gold, 0
	end
	task.delay(0.35, function() if spottingNow then setPayout(0) end end)
end

local function onRep(info)
	if not spottingNow then return end
	local progress = tonumber(info.progress) or 0
	if info.paid then
		coinBurst(tonumber(info.paid) or 0)
	else
		assisted[progress] = info.assist == true
		setPayout(progress)
		local plate = payoutPlates[progress]
		if plate then
			plate.Size = UDim2.new(1 / Spotting.RewardEvery, -Spacing.XS, 1.8, 0)
			Theme.Tween(plate, { Size = UDim2.new(1 / Spotting.RewardEvery, -Spacing.XS, 1, 0) }, 0.25, Enum.EasingStyle.Back)
		end
	end
	if info.assist then assistPop() end
end

-- moving or jumping stops spotting (the root is held in place, so only the input shows it)
RunService.Heartbeat:Connect(function()
	if not spottingNow then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and (humanoid.MoveDirection.Magnitude > 0.5 or humanoid.Jump) then
		spottingNow = false
		remote:FireServer("Exit")
	end
	-- the meter: your taps per second over the last second, full at twice the clicking rate
	local now = os.clock()
	while myTaps[1] and now - myTaps[1] > Spotting.ClickWindow do table.remove(myTaps, 1) end
	local lit = math.clamp(math.floor(#myTaps / (Spotting.ClickRate * 2) * SEGMENTS + 0.5), 0, SEGMENTS)
	for i, segment in ipairs(segments) do
		segment.BackgroundTransparency = if i <= lit then (if serverClicking then 0 else 0.45) else 0.85
		segment.BackgroundColor3 = if serverClicking and i <= lit then Colors.Gold else Colors.Chalk
	end
	-- the combo fades out once you stop
	if combo > 0 and now - lastPush > COMBO_RESET then
		combo = 0
		Theme.Tween(comboLabel, { TextTransparency = 1 }, 0.3, Enum.EasingStyle.Quad)
	end
end)

------------------------------------------------------------------------
-- 4. The lifter's SPOTTED label (beside you, by the EXP popups)
------------------------------------------------------------------------
local spottedGui = New("BillboardGui", { Name = "SpottedLabel", Size = UDim2.fromOffset(220, 56), StudsOffset = Vector3.new(-3.6, 2.2, 0), AlwaysOnTop = true,
	LightInfluence = 0, MaxDistance = 80, ResetOnSpawn = false, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local spottedBig = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Large", TextColor3 = Colors.Gold, Upper = false,
	Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Right, Parent = spottedGui })
Theme.TextShadow(spottedBig)
local spottedNames = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = spottedGui })
Theme.TextShadow(spottedNames)

local function showSpotted(info)
	local count = tonumber(info.count) or 0
	if count <= 0 then
		spottedGui.Enabled = false
		return
	end
	local character = player.Character
	spottedGui.Adornee = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
	spottedBig.Text = string.format("SPOTTED x%.2f", math.floor((tonumber(info.boost) or 1) * 100 + 0.5) / 100)
	local list = type(info.names) == "table" and info.names or {}
	spottedNames.Text = table.concat(list, ", ")
	spottedGui.Enabled = spottedGui.Adornee ~= nil
end

------------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------------
local REFUSED = {
	Full = "Spot full",
	Declined = "%s said no",
	NoAnswer = "%s didn't answer",
	RequestsOff = "%s isn't taking spot requests",
	TooFar = "Get closer to spot",
	Busy = "You can't spot right now",
	NotSpottable = "This machine can't be spotted",
	Unavailable = "They're not lifting anymore",
}
local ENDED = {
	LifterLeft = "Set's over: spotting ended",
	Moved = "You moved: spotting ended",
	Exit = "Spotting ended",
}

remote.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "Request" then
		requestCard(info)
	elseif kind == "RequestClosed" then
		if type(info.userId) == "number" then closeCard(info.userId) end
	elseif kind == "Asked" then
		Notify.Show("Asked " .. tostring(info.name) .. " to let you spot", nil, "spot")
	elseif kind == "Refused" then
		local text = REFUSED[info.reason] or "Can't spot right now"
		Notify.Show(string.format(text, tostring(info.name or "")), nil, "spot")
	elseif kind == "Started" then
		setSpotting(true, info)
		Notify.Show("Spotting " .. tostring(info.lifter), nil, "spot")
		Audio.PlayUI("Click")
	elseif kind == "State" then
		boostShown = tonumber(info.boost) or 1
		if spottingNow then
			setBoosting(info.clicking == true)
			spotStatus.Text = if serverClicking then string.format("BOOSTING  x%.2f", boostShown)
				else string.format("Their gains x%.2f. %s for more", boostShown, PUSH_HINT)
			spotStatus.TextColor3 = if serverClicking then Colors.Gold else Colors.Muted
		end
	elseif kind == "Rep" then
		onRep(info)
	elseif kind == "Ended" then
		if spottingNow or panel.Visible then setSpotting(false, info) end
		-- the wrap-up: what you did
		local reps, coins = tonumber(info.reps) or 0, tonumber(info.coins) or 0
		local wrap = if reps > 0 then string.format(" · %d reps spotted%s", reps, if coins > 0 then ", +" .. coins .. " coins" else "") else ""
		Notify.Show((ENDED[info.reason] or "Spotting ended") .. wrap, nil, "spot")
	elseif kind == "Spotted" then
		showSpotted(info)
	end
end)

------------------------------------------------------------------------
-- 5. Spotter poses (every client, every spotter)
------------------------------------------------------------------------
local ARM = {
	R = { shoulder = { "RightUpperArm", "RightShoulder" }, elbow = { "RightLowerArm", "RightElbow" }, side = 1 },
	L = { shoulder = { "LeftUpperArm", "LeftShoulder" }, elbow = { "LeftLowerArm", "LeftElbow" }, side = -1 },
}
local DOWN = Vector3.new(0, -1, 0)
local posed = {} -- [character] = { motors }

local function motor(character, spec)
	local part = character:FindFirstChild(spec[1])
	local joint = part and part:FindFirstChild(spec[2])
	return joint
end

-- the arm (upper arm from the shoulder) pointed along `dir` (UpperTorso space), elbow bent by `bend` degrees
local function aim(character, key: string, dir: Vector3, bend: number)
	local arm = ARM[key]
	local shoulder, elbow = motor(character, arm.shoulder), motor(character, arm.elbow)
	if not (shoulder and elbow) or dir.Magnitude < 1e-3 then return end
	shoulder.Transform = CFrame.fromRotationBetweenVectors(DOWN, dir.Unit)
	elbow.Transform = CFrame.Angles(math.rad(bend), 0, 0)
	posed[character] = posed[character] or {}
	posed[character][shoulder] = true
	posed[character][elbow] = true
end

local function rest(character)
	local list = posed[character]
	if not list then return end
	for joint in pairs(list) do
		if joint.Parent then joint.Transform = CFrame.identity end
	end
	posed[character] = nil
end

-- hands under the lifter's bar (the bar part moves with the rep on every client), closest point along the bar
local function handsPose(character, torso: BasePart, model: Model)
	local bar = model:FindFirstChild("Bar", true)
	local target
	if bar and bar:IsA("BasePart") then
		local axis = bar.CFrame.XVector
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local along = root and math.clamp((root.Position - bar.Position):Dot(axis), -bar.Size.X / 2 + 0.3, bar.Size.X / 2 - 0.3) or 0
		target = bar.Position + axis * along - Vector3.new(0, 0.25, 0)
		-- each hand a little to its own side along the bar
		local toRight = if torso.CFrame.RightVector:Dot(axis) >= 0 then axis else -axis
		for _, key in ipairs({ "R", "L" }) do
			local upper = character:FindFirstChild(ARM[key].shoulder[1])
			if not (upper and upper:IsA("BasePart")) then continue end
			local origin = upper.Position + upper.CFrame.UpVector * (upper.Size.Y / 2) -- (the shoulder end of the upper arm)
			local hand = target + toRight * (if key == "R" then 0.35 else -0.35)
			aim(character, key, torso.CFrame:VectorToObjectSpace(hand - origin), 18)
		end
	else
		-- (no bar: hands up and ready in front)
		aim(character, "R", Vector3.new(0.15, 0.3, -1), 25)
		aim(character, "L", Vector3.new(-0.15, 0.3, -1), 25)
	end
end

-- hype: clap, point, fist pump in turns (each spotter on their own clock)
local function hypePose(character, slot: string)
	local seed = (tonumber(string.match(slot or "", "%d+")) or 1) * 1.7
	local t = os.clock() + seed
	local move = math.floor(t / 2.4) % 3
	if move == 0 then -- clap: hands come together in front, fast
		local open = math.abs(math.sin(t * 7))
		aim(character, "R", Vector3.new(-0.05 + 0.4 * open, 0.15, -1), 35)
		aim(character, "L", Vector3.new(0.05 - 0.4 * open, 0.15, -1), 35)
	elseif move == 1 then -- point at the lifter, the other hand on the hip
		local beat = math.sin(t * 6) * 0.08
		aim(character, "R", Vector3.new(0.12, 0.45 + beat, -1), 0)
		aim(character, "L", Vector3.new(-0.35, -1, 0.1), 70)
	else -- fist pump: the right arm up, pumping
		local pump = (math.sin(t * 9) + 1) / 2
		aim(character, "R", Vector3.new(0.25, 1, -0.15), 30 + pump * 70)
		aim(character, "L", Vector3.new(-0.25, -1, -0.1), 15)
	end
end

RunService.PreSimulation:Connect(function()
	for character in pairs(posed) do
		if not character.Parent or not character:GetAttribute("SpotType") then rest(character) end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local kind = character and character:GetAttribute("SpotType")
		if kind then
			local torso = character:FindFirstChild("UpperTorso")
			local lifter = character:GetAttribute("SpotLifter")
			local model = type(lifter) == "number" and machineOfUser(lifter)
			if torso and torso:IsA("BasePart") then
				if kind == "hands" and model then
					handsPose(character, torso, model)
				else
					hypePose(character, character:GetAttribute("SpotSlot"))
				end
			end
		end
	end
end)
