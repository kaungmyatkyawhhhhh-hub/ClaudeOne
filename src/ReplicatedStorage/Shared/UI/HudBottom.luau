-- HudBottom (owner's final kit "BLACK + GOLD", mockups 01 / 02; owner's declutter, 14 Oct): the slim STAMINA bar at the
-- very bottom center, 10 px above the edge, at most 280 wide (a small dark panel: a teal lightning icon, "STAMINA",
-- "82 / 100" on the right, a thin teal bar under it; soft red when nearly empty), and the row of active boost icons above
-- it (a colored icon tile with its timer or value under it).
--   HudBottom.Chip(icon, color, order)   -> chip api { frame, SetText(main, sub?), SetVisible(on), OnTap(fn) } (sub = the timer);
--                                        at most MaxChips show, the rest behind a "+2" tile that also folds the row
--   HudBottom.SetTraining(on)            the bar reads "Stamina 60/100" and the row moves above STOP TRAINING
--   HudBottom.SetHidden(reason, on)      hide it while a screen needs the bottom (posing, arm wrestling)
--   HudBottom.BarTop()                   root-relative y (mockup px from the bottom) of the bar's top edge
--   HudBottom.AddSide(frame, order?)     a button left of the bar, shown on and off machines (unused since prompt 28)
--   HudBottom.SetLift(px)                (prompt 28) everything moves up by px: the hotbar (HotbarClient) sits under it
-- Recovering (prompt 20, the player's "StaminaRecovering" attribute, PlayerData): the bar shows (on a machine or not), turns
-- red and reads "RECOVERING 6s", and a line above says what the Growth Spurt needs (the local "SpurtNeeds" attribute set
-- by ProgressClient) or a tip.
-- Hidden on the main menu, the genetics screen and full-width screens. Stamina: ClientData.stamina against the player's
-- MaxStamina attribute (Iron Lungs, treadmill training) or Config/Stamina.Max.
-- Only while exercising (owner, 14 Oct): the bar sits in a CanvasGroup that fades in (GroupTransparency, 0.2 s) while you're
-- on a machine (lifting, the treadmill, Auto Lift) and fades out (0.4 s) 1.5 s after you leave. Off a machine it stays
-- hidden (it refills in the background), except a jump up (a shake, a refill) shows it for 3 s so you see it fill. It
-- never moves, and the boost icons above it keep their own spot whether it shows or not.
-- Endless Stamina (owner, 14 Oct; the player's "EndlessStaminaUntil" attribute, PlayerData): a gold lightning chip with
-- its countdown ("14:32") first in the boosts row, and the bar turns gold with a slow shine sweeping along it and an
-- infinity sign before the number.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local HudBottom = {}

HudBottom.BarSize = Vector2.new(280, 34) -- the stamina panel
HudBottom.Bottom = 10         -- bar's gap to the screen bottom (mockup px)
HudBottom.ChipSize = 28
HudBottom.TrainingRowLift = 0 -- (owner's final kit: STOP sits bottom-left now, nothing above the stamina panel)
HudBottom.LowStamina = 0.15
HudBottom.FadeIn, HudBottom.FadeOut = 0.2, 0.4
HudBottom.HideAfterLeave = 1.5 -- seconds after getting off a machine
HudBottom.ShowOnRefill = 3     -- seconds a refill (shake, product, trainer) shows the bar while not exercising
HudBottom.RefillJump = 0.1     -- a stamina rise of at least this share of the max at once counts as a refill
HudBottom.ShineEvery = 2.6     -- Endless Stamina: seconds per shine sweep along the gold bar
HudBottom.SideHeight = 44      -- the button left of the stamina bar (the shake): a full thumb target

local gui, root, row, setBar, barTrack, fill, staminaNow, staminaMaxText, group, titleText, tipText, side
local training = false
local shownUntil = 0   -- os.clock() until which a refill keeps the bar up
local shown = false
local lastStamina = nil
local hidden = {}
local endlessChip, infinity, shine, shineTween
local endless = false
local lift = 0 -- (prompt 28) the hotbar's room under the bar
local function base(): number return HudBottom.Bottom + lift end

local function endlessLeft(): number
	local untilTime = Players.LocalPlayer:GetAttribute("EndlessStaminaUntil")
	return if type(untilTime) == "number" then math.max(0, untilTime - Workspace:GetServerTimeNow()) else 0
end

local function staminaMax()
	local max = Players.LocalPlayer:GetAttribute("MaxStamina")
	if type(max) == "number" and max > 0 then return max end
	local ok, Stamina = pcall(function() return require(ReplicatedStorage.Shared.Config.Stamina) end)
	return ok and Stamina.Max or 100
end

-- show / hide the bar (a GroupTransparency tween, never a move)
local function setShown(on: boolean)
	if not group or shown == on then return end
	shown = on
	Theme.Tween(group, { GroupTransparency = on and 0 or 1 }, on and HudBottom.FadeIn or HudBottom.FadeOut)
end
local function recovering(): boolean
	return Players.LocalPlayer:GetAttribute("StaminaRecovering") == true
end
local function updateShown()
	setShown(training or recovering() or os.clock() < shownUntil)
end

local function refresh()
	if not setBar then return end
	local ok, ClientData = pcall(function() return require(ReplicatedStorage.Shared.ClientData) end)
	local data = ok and ClientData.Get() or nil
	local stamina = data and data.stamina or 0
	local max = staminaMax()
	local ratio = math.clamp(stamina / max, 0, 1)
	setBar(ratio)
	staminaNow.Text = tostring(math.floor(stamina + 0.5))
	staminaMaxText.Text = "/ " .. math.floor(max + 0.5)
	local gloss = fill:FindFirstChild("Gloss")
	local isRecovering = recovering() and not endless
	local color = if endless then Colors.Gold elseif isRecovering or ratio < HudBottom.LowStamina then Colors.NeedsWork else Colors.Teal
	if gloss then gloss.Color = Kit.Metal(color) end
	-- recovering (Config/Stamina.Pacing): "RECOVERING 6s" in the title, and what to train next above the bar
	if isRecovering then
		local okS, Stamina = pcall(function() return require(ReplicatedStorage.Shared.Config.Stamina) end)
		local seconds = okS and Stamina.PacingFor(data and data.growthSpurts).refillSeconds or 10
		local left = math.max(0, math.ceil((max - stamina) / max * seconds))
		titleText.Text = "RECOVERING " .. left .. "s"
		local needs = Players.LocalPlayer:GetAttribute("SpurtNeeds")
		tipText.Text = if type(needs) == "string" and needs ~= "" then "Growth Spurt needs " .. needs else "Catch your breath. Reps start again when it's full."
		tipText.Visible = true
	else
		titleText.Text = "STAMINA"
		tipText.Visible = false
	end
	-- a jump up while not exercising (a shake, a refill): show it for a few seconds; the slow refill stays hidden
	if lastStamina and not training and stamina - lastStamina >= HudBottom.RefillJump * max then
		shownUntil = os.clock() + HudBottom.ShowOnRefill
		updateShown()
		task.delay(HudBottom.ShowOnRefill + 0.05, updateShown)
	end
	lastStamina = stamina
end

local function placeRow()
	if not row then return end
	local rowLift = training and HudBottom.TrainingRowLift or 0
	row.Position = UDim2.new(0.5, 0, 1, -(base() + HudBottom.BarSize.Y + 8 + rowLift))
end
-- everything at the bottom, from base() up
local function placeAll()
	if not group then return end
	group.Position = UDim2.new(0.5, 0, 1, -base())
	placeRow()
	tipText.Position = UDim2.new(0.5, 0, 1, -(base() + HudBottom.BarSize.Y + 8 + HudBottom.ChipSize + 18))
	side.Position = UDim2.new(0.5, -(HudBottom.BarSize.X / 2 + 8), 1, -base())
end

local function refreshVisible()
	if not gui then return end
	local anyHidden = next(hidden) ~= nil
	gui.Enabled = not anyHidden and not UIBus.MenuOpen and not UIBus.CoverOpen(gui.Parent)
end

local function ensure()
	if gui then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Theme.ScreenGui({ Name = "HudBottom", DisplayOrder = 4, Parent = playerGui })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	-- the panel: header (icon, STAMINA, "82 / 100") over the teal bar, in its CanvasGroup (hidden until you exercise)
	group = New("CanvasGroup", { Name = "StaminaGroup", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -HudBottom.Bottom),
		Size = UDim2.fromOffset(HudBottom.BarSize.X, HudBottom.BarSize.Y), BackgroundTransparency = 1, GroupTransparency = 1, Parent = root })
	barTrack = Theme.Panel({ Name = "Stamina", Piece = "hud_box", Size = UDim2.fromScale(1, 1), Parent = group })
	local zap = require(script.Parent.Pieces).Icon("zap", Colors.Teal, { Name = "Zap", Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(12, 12), Parent = barTrack })
	zap:SetAttribute("KeepColor", true)
	titleText = Kit.Text({ Name = "Title", Text = "STAMINA", Font = "Title", TextSize = 11, Position = UDim2.fromOffset(26, 2), Size = UDim2.fromOffset(140, 16),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = barTrack })
	local numbers = New("Frame", { Name = "Numbers", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 2),
		Size = UDim2.fromOffset(110, 16), Parent = barTrack }, { Theme.List(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	infinity = Kit.Text({ Name = "Infinity", LayoutOrder = 0, Text = "\u{221E}", Font = "Number", TextSize = 15, TextColor3 = Colors.Gold,
		Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = numbers })
	staminaNow = Kit.Text({ Name = "Now", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 12, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Parent = numbers })
	staminaMaxText = Kit.Text({ Name = "Max", LayoutOrder = 2, Text = "/ 100", Font = "Number", TextSize = 12, TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X, Parent = numbers })
	local _
	_, setBar, fill = Kit.Bar(Colors.Teal, { Name = "Bar", Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 8), Parent = barTrack }, { outline = 1 })
	-- Endless Stamina's shine: a soft white band that sweeps along the fill (hidden otherwise)
	shine = New("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1),
		Visible = false, ZIndex = (fill.ZIndex or 1) + 1, Parent = fill }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", { Name = "Sweep", Rotation = 0, Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	row = New("Frame", { Name = "Boosts", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, HudBottom.ChipSize + 16),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root }, {
		Theme.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	placeRow()
	-- while recovering: what to train next (or a tip), above the boost icons
	tipText = Kit.Text({ Name = "RecoverTip", Text = "", Font = "Strong", TextSize = 13, AnchorPoint = Vector2.new(0.5, 1), Visible = false,
		Position = UDim2.new(0.5, 0, 1, -(HudBottom.Bottom + HudBottom.BarSize.Y + 8 + HudBottom.ChipSize + 18)), Size = UDim2.fromOffset(420, 18), Parent = root })
	-- (prompt 20) the left of the stamina bar: buttons in the same spot on and off a machine (was DRINK SHAKE, gone in prompt 28)
	side = New("Frame", { Name = "Side", AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -(HudBottom.BarSize.X / 2 + 8), 1, -HudBottom.Bottom), Size = UDim2.fromOffset(0, HudBottom.SideHeight),
		AutomaticSize = Enum.AutomaticSize.X, Parent = root }, {
		Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom),
	})
	Players.LocalPlayer:GetAttributeChangedSignal("StaminaRecovering"):Connect(function()
		refresh()
		updateShown()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("SpurtNeeds"):Connect(refresh)
	task.spawn(function()
		local ClientData = require(ReplicatedStorage.Shared.ClientData)
		ClientData.Get()
		refresh()
		ClientData.Changed:Connect(function(path)
			if path[1] == "stamina" then refresh() end
		end)
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("MaxStamina"):Connect(refresh)
	UIBus.MenuClosed.Event:Connect(refreshVisible)
	-- Endless Stamina: the chip's countdown and the gold bar
	endlessChip = HudBottom.Chip("zap", Colors.Gold, 0)
	local function setEndless(on: boolean)
		if endless == on then return end
		endless = on
		endlessChip:SetVisible(on)
		infinity.Visible = on
		shine.Visible = on
		local zapIcon = barTrack:FindFirstChild("Zap")
		if zapIcon and zapIcon:IsA("ImageLabel") then zapIcon.ImageColor3 = on and Colors.Gold or Colors.Teal end
		if shineTween then shineTween:Cancel() shineTween = nil end
		if on then
			local sweep = shine:FindFirstChild("Sweep") :: UIGradient
			sweep.Offset = Vector2.new(-1, 0)
			shineTween = game:GetService("TweenService"):Create(sweep, TweenInfo.new(HudBottom.ShineEvery, Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) })
			shineTween:Play()
		end
		refresh()
	end
	task.spawn(function()
		while true do
			local left = endlessLeft()
			setEndless(left > 0)
			if left > 0 then
				local s = math.ceil(left)
				endlessChip:SetText("", string.format("%d:%02d", s // 60, s % 60))
			end
			task.wait(0.25)
		end
	end)
	UIBus.GeneticsVisible.Event:Connect(function(open) HudBottom.SetHidden("genetics", open) end)
	task.spawn(function()
		while true do
			task.wait(0.4)
			refreshVisible()
		end
	end)
	refreshVisible()
end

-- (prompt 14, 21 Oct) At most MaxChips boost icons show at once; with more, a small "+2" tile follows them. Tapping that
-- tile folds the row away (it then shows "+5", all of them) and tapping again brings it back.
HudBottom.MaxChips = 4
local chipList = {} -- { { frame, wanted } } in creation order (LayoutOrder sorts them on screen)
local chipsFolded = false
local moreTile, moreText
local function layoutChips()
	local wanted = {}
	for _, entry in ipairs(chipList) do
		if entry.wanted then table.insert(wanted, entry) end
	end
	table.sort(wanted, function(a, b) return a.frame.LayoutOrder < b.frame.LayoutOrder end)
	local shown = 0
	for _, entry in ipairs(chipList) do entry.frame.Visible = false end
	for _, entry in ipairs(wanted) do
		if not chipsFolded and shown < HudBottom.MaxChips then
			entry.frame.Visible = true
			shown += 1
		end
	end
	local hidden = #wanted - shown
	if moreTile then
		moreTile.Visible = hidden > 0 or (chipsFolded and #wanted > 0)
		moreText.Text = "+" .. hidden
	end
end

-- A boost icon: a 28px colored tile with a white icon, the timer (or the value) under it.
--   api:SetText(main, sub?)  api:SetVisible(on)  api:OnTap(fn) (a tap on the icon, e.g. to say what it is)
function HudBottom.Chip(icon: string, color: Color3, order: number?)
	ensure()
	if not moreTile then
		moreTile = New("TextButton", { Name = "MoreBoosts", Text = "", AutoButtonColor = false, LayoutOrder = 1000, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(40, HudBottom.ChipSize + 16), Visible = false, Parent = row })
		local face = Theme.Panel({ Name = "Face", Piece = "hud_box", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(HudBottom.ChipSize, HudBottom.ChipSize), Parent = moreTile })
		moreText = Kit.Text({ Name = "Count", Text = "+0", Font = "Number", TextSize = 12, Size = UDim2.fromScale(1, 1), Parent = face })
		moreTile.Activated:Connect(function()
			chipsFolded = not chipsFolded
			layoutChips()
		end)
	end
	local chip = New("Frame", { Name = "Boost_" .. icon, LayoutOrder = order or 1, Size = UDim2.fromOffset(40, HudBottom.ChipSize + 16),
		BackgroundTransparency = 1, Visible = false, Parent = row })
	Kit.IconTile(icon, color, HudBottom.ChipSize, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = chip })
	local label = Kit.Text({ Name = "Value", Text = "", Font = "Number", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(2, 0, 0, 16), Parent = chip })
	local entry = { frame = chip, wanted = false }
	table.insert(chipList, entry)
	local api = { frame = chip }
	function api.SetText(_, main, sub)
		-- the timer when there is one ("4:12"), else the value ("+5%")
		label.Text = (sub and sub ~= "") and sub or (main or "")
	end
	function api.SetVisible(_, on)
		if entry.wanted == (on == true) then return end
		entry.wanted = on == true
		layoutChips()
	end
	function api.OnTap(_, fn)
		local hit = New("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = chip })
		hit.Activated:Connect(fn)
	end
	return api
end

-- (prompt 29) A chip showing an image instead of an icon (a trainer's portrait: your equipped trainers that don't follow
-- you in the world). Same API as Chip, plus SetImage.
function HudBottom.ImageChip(image: string, order: number?)
	local api = HudBottom.Chip("users", Theme.Colors.Gold, order)
	local chip = api.frame
	for _, child in ipairs(chip:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Value" then child.Visible = false end
	end
	local picture = New("ImageLabel", { Name = "Portrait", Image = image, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(HudBottom.ChipSize, HudBottom.ChipSize), ScaleType = Enum.ScaleType.Fit,
		Parent = chip })
	function api.SetImage(_, id: string) picture.Image = id end
	-- (owner, 22 Oct: no trainer pictures) a trainer's live 3D rig in the chip
	function api.SetTrainer(_, trainerId: string)
		if picture:GetAttribute("Trainer") == trainerId then return end
		picture:SetAttribute("Trainer", trainerId)
		picture.Image = ""
		picture:ClearAllChildren()
		require(script.Parent.TrainerPortrait).New(trainerId, { Size = UDim2.fromScale(1, 1), Parent = picture, shot = "bust", pose = "Relaxed" })
	end
	return api
end

-- A button left of the stamina bar: always on screen, on a machine or not.
function HudBottom.AddSide(frame: GuiObject, order: number?)
	ensure()
	frame.LayoutOrder = order or 1
	frame.Parent = side
	return frame
end

function HudBottom.SetTraining(on: boolean)
	ensure()
	training = on
	placeRow()
	refresh()
	if on then
		updateShown()
	else
		-- a moment after getting off, then it fades (unless you got back on meanwhile)
		task.delay(HudBottom.HideAfterLeave, updateShown)
	end
end

function HudBottom.SetHidden(reason: string, on: boolean)
	ensure()
	hidden[reason] = on or nil
	refreshVisible()
end

-- mockup px from the screen bottom to the top of the stamina bar
function HudBottom.BarTop(): number
	return base() + HudBottom.BarSize.Y
end

-- (prompt 28) the hotbar sits at the very bottom: the bar, the boost icons and the tip move up by px (0 = back down)
function HudBottom.SetLift(px: number)
	ensure()
	if lift == px then return end
	lift = px
	placeAll()
end

function HudBottom.Refresh()
	ensure()
	refresh()
end

ensure()
return HudBottom
