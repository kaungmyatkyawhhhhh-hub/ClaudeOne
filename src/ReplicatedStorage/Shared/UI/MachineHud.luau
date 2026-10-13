-- MachineHud: the look of the HUD while on a machine (owner's UI v2, mockups 02_machine_hud / 03_machine_auto).
-- MachineClient owns all the logic; this only builds the widgets (mockup px inside a Kit.Root) and returns them.
-- Nothing sits in the middle of the screen (owner, 13 Oct: the old panel covered the player):
--   right:         the weight panel: AUTO TRAIN (AUTO ON in green), WEIGHT "315 LB", "Tier 12 / 12" (or what it needs),
--                  - / +, BEST WEIGHT (or UNLOCK with the price when the weight shown isn't bought yet)
--   bottom right:  the big red REP circle (reps "x13") and the gold PUMP circle left of it
--   bottom center: STOP TRAINING, right above the stamina bar (Shared/UI/HudBottom)
--   top center:    NEW PERSONAL RECORD! (gold outlined text) + "315 LB Bench Press"
-- (No floating text while lifting: coach lines and hints go to the top band, Notify.Hint.)
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local HudBottom = require(script.Parent.HudBottom)
local UIConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("UI"))

local New, Colors = Theme.New, Theme.Colors

local MachineHud = {}

MachineHud.PanelSize = Vector2.new(176, 192)
MachineHud.PanelTop = 85
MachineHud.Edge = 11
MachineHud.HiddenOffset = UDim2.fromOffset(0, 260) -- the bottom widgets wait below the screen edge
MachineHud.PanelHidden = UDim2.fromOffset(230, 0)  -- the weight panel waits past the right edge
MachineHud.RepSize = 92
MachineHud.PumpSize = 56
MachineHud.BarHeight = 46
MachineHud.PlateWidth = 6

local function frame(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New("Frame", props, children)
end

-- A round glossy button (REP / PUMP): gradient circle, dark outline, a lighter ring inside, a press bounce.
local function circle(name, gradient, size, parent)
	local button = New("ImageButton", { Name = name, AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Name = "Gloss", Rotation = 90, Color = ColorSequence.new(Theme.Gradients[gradient][1], Theme.Gradients[gradient][2]) }),
	})
	-- the lighter ring just inside the outline
	local ring = frame({ Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6), Parent = button }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.6 }),
	})
	-- a soft dark halo around it
	frame({ Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 1, 10), ZIndex = 0, Parent = button }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Shadow, Thickness = 5, Transparency = 0.6 }),
	})
	Theme.BindPress(button)
	return button, ring
end

local function grayButton(name, glyph, props)
	props.Name = name
	props.Size = UDim2.fromOffset(69, 30)
	local button = Theme.Button("Gray", props, {})
	Kit.Text({ Name = "Label", Text = glyph, Font = "Title", TextSize = 20, Size = UDim2.new(1, 0, 1 - Theme.LipHeight, 0), Parent = button })
	return button
end

function MachineHud.Build()
	local hud = {}
	local gui = Theme.ScreenGui({ Name = "MachineHud", Enabled = false, DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	hud.gui = gui
	local root = Kit.Root(gui)
	hud.root = root

	-- the bottom widgets slide up when you get on (MachineClient tweens `stack`)
	local stack = frame({ Name = "Group", Size = UDim2.fromScale(1, 1), Position = MachineHud.HiddenOffset, Parent = root })
	hud.stack = stack

	------------------------------------------------------------ the weight panel (right)
	local size = MachineHud.PanelSize
	local panelSlot = frame({ Name = "PanelSlot", Size = UDim2.fromScale(1, 1), Position = MachineHud.PanelHidden, Parent = root })
	hud.panelSlot = panelSlot
	local panel = Theme.Panel({ Name = "Panel", Clickable = true, -- (taps on it don't lift)
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -MachineHud.Edge, 0, MachineHud.PanelTop), Size = UDim2.fromOffset(size.X, size.Y),
		Parent = panelSlot })
	hud.panel = panel

	hud.autoButton, hud.autoLabel = Kit.Button("Red", "Auto train", { Name = "Auto", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 13),
		Visible = false, Parent = panel }, { width = 150, height = 26, icon = "lock", textSize = 14 })
	Kit.Text({ Name = "WeightLabel", Text = "Weight", Font = "Label", TextSize = 11, Upper = true, Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 14), Parent = panel })
	local weightRow = frame({ Name = "WeightRow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 61), Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X, Parent = panel }, {
		Theme.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	hud.weightNumber = Kit.Text({ Name = "Weight", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 28,
		Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	hud.weightUnit = Kit.Text({ Name = "Unit", LayoutOrder = 2, Text = "LB", Font = "Number", TextSize = 28,
		Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	-- "Tier 12 / 12" in gold, or what the weight needs
	local tierSlot = frame({ Name = "TierSlot", Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 18), Parent = panel })
	hud.tierTag = frame({ Name = "Tier", Size = UDim2.fromScale(1, 1), Parent = tierSlot })
	Kit.Text({ Name = "Text", Text = "", Font = "Number", TextSize = 13, TextColor3 = Colors.Gold, Size = UDim2.fromScale(1, 1), Parent = hud.tierTag })
	hud.needsLabel = Kit.Text({ Name = "Needs", Text = "", Font = "Number", TextSize = 11, TextColor3 = Colors.NeedsWork, Size = UDim2.fromScale(1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd, Visible = false, Parent = tierSlot })
	hud.minusButton = grayButton("Minus", "-", { Position = UDim2.fromOffset(14, 114), Parent = panel })
	hud.plusButton = grayButton("Plus", "+", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 114), Parent = panel })
	-- BEST WEIGHT (the owner's MAX: buys every next plate the level and coins allow, then picks the heaviest you can lift)
	hud.maxButton = Kit.Button("Gold", "Best weight", { Name = "Max", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 155), Parent = panel },
		{ width = 150, height = 26, textSize = 14 })
	-- UNLOCK the weight shown (in BEST WEIGHT's place while that weight isn't bought yet)
	local unlock = Theme.Button("Gold", { Name = "Unlock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 155), Size = UDim2.fromOffset(150, 26),
		Visible = false, Parent = panel }, {
		New("UIPadding", { PaddingBottom = UDim.new(0, 3) }),
		Theme.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	hud.unlockButton = unlock
	hud.unlockText = Kit.Text({ Name = "Label", LayoutOrder = 1, Text = "Unlock", Font = "Title", TextSize = 14, Upper = true,
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = unlock })
	hud.unlockIcon = Kit.Coin(15, { LayoutOrder = 2, Parent = unlock })
	hud.costLabel = Kit.Text({ Name = "Cost", LayoutOrder = 3, Text = "", Font = "Number", TextSize = 14,
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = unlock })

	-- (kept for MachineClient, not shown: the name and muscle split are on the machine's sign, the barbell drawing and
	-- the stamina segments are gone, stamina is the big bar at the bottom)
	local hidden = frame({ Name = "Hidden", Visible = false, Parent = root })
	hud.titleLabel = Kit.Text({ Name = "MachineName", Text = "", Font = "Title", Parent = hidden })
	hud.groupTag = Kit.Tag("Chest", Colors.Red, { Name = "Group", Parent = hidden })
	hud.musclesLabel = Kit.Text({ Name = "Muscles", Text = "", Font = "Body", Parent = hidden })
	hud.noteLabel = Kit.Text({ Name = "CoachNote", Text = "", Font = "Body", Parent = hidden })
	hud.staminaPct = Kit.Text({ Name = "Pct", Text = "", Font = "Number", Parent = hidden })
	hud.pumpHint = Kit.Text({ Name = "PumpHint", Text = "", Font = "Body", Parent = hidden })
	hud.flashSlot = frame({ Name = "FlashSlot", Size = UDim2.fromOffset(300, 24), Parent = hidden })
	hud.barbell = frame({ Name = "Barbell", Size = UDim2.fromOffset(220, MachineHud.BarHeight), Parent = hidden })
	hud.barPlates = {}
	hud.segmentBacks, hud.segments = {}, {}

	------------------------------------------------------------ REP + PUMP (bottom right) and STOP TRAINING
	local rep, repRing = circle("Rep", "Red", MachineHud.RepSize, stack)
	rep.Position = UDim2.new(1, -(844 - 596), 1, -(390 - 284))
	Kit.Text({ Name = "Label", Text = "REP", Font = "Title", TextSize = 30, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 32), Parent = rep })
	hud.repsLabel = Kit.Text({ Name = "Count", Text = "x0", Font = "Number", TextSize = 15, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.new(1, 0, 0, 18), Parent = rep })
	hud.repsScale = New("UIScale", { Parent = hud.repsLabel })
	hud.repButton, hud.repRing = rep, repRing

	local pump, pumpRing = circle("Pump", "Gold", MachineHud.PumpSize, stack)
	pump.Position = UDim2.new(1, -(844 - 507), 1, -(390 - 300))
	Pieces.Icon("flame", Colors.Text, { Name = "Flame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(20, 20), Parent = pump }):SetAttribute("KeepColor", true)
	hud.pumpLabel = Kit.Text({ Name = "Label", Text = "PUMP", Font = "Title", TextSize = 13, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.new(1, 0, 0, 16), Parent = pump })
	hud.pumpButton, hud.pumpRing = pump, pumpRing

	hud.exitButton = Kit.Button("Red", "Stop training", { Name = "Exit", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(HudBottom.BarTop() + 11)), Parent = stack }, { width = 146, height = 28, textSize = 15 })

	------------------------------------------------------------ NEW PERSONAL RECORD! (top center)
	local banner = frame({ Name = "PersonalRecord", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(420, 52),
		Visible = false, ZIndex = 5, Parent = root })
	hud.prTitle = Kit.Text({ Name = "Title", Text = "NEW PERSONAL RECORD!", Font = "Title", TextSize = 28, TextColor3 = Colors.Gold,
		Size = UDim2.new(1, 0, 0, 32), ZIndex = 6, Parent = banner })
	hud.prInfo = Kit.Text({ Name = "Info", Text = "", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 6, Parent = banner })
	hud.prBanner = banner

	------------------------------------------------------------ helpers
	function hud.drawBarbell(_plates) end -- (no barbell drawing in this style)

	-- AUTO: hidden (Auto Lift isn't for sale), locked (red AUTO TRAIN with a lock: opens the shop), off (red AUTO TRAIN),
	-- on (green AUTO ON)
	function hud.setAuto(mode: string)
		local button = hud.autoButton
		button.Visible = mode ~= "hidden"
		if mode == "hidden" then return end
		local icon = button:FindFirstChild("Icon")
		if mode == "on" then
			Kit.SetButton(button, "Green", "Auto on")
			if icon then icon.Image = UIConfig.Icons["repeat"] end
		else
			Kit.SetButton(button, "Red", "Auto train")
			if icon then icon.Image = UIConfig.Icons[mode == "locked" and "lock" or "repeat"] end
		end
	end

	-- PUMP: dim while the meter is low, bright as it fills; while PUMPED it shows the seconds left and the ring glows.
	function hud.setPump(fill: number, pumped: boolean, left: number?, now: number)
		local bright = pumped and 1 or (0.62 + 0.38 * math.clamp(fill, 0, 1))
		pump.BackgroundColor3 = Color3.new(bright, bright, bright)
		local ringStroke = pumpRing:FindFirstChildOfClass("UIStroke")
		if pumped then
			hud.pumpLabel.Text = math.ceil(left or 0) .. "s"
			ringStroke.Transparency = 0.1 + 0.3 * (0.5 + 0.5 * math.sin(now * 6))
		else
			hud.pumpLabel.Text = "PUMP"
			ringStroke.Transparency = 0.6 - 0.4 * math.clamp(fill, 0, 1)
		end
	end

	-- every tap: PUMP pops a little (its press scale is a UIScale named PressScale, made by Theme.BindPress)
	function hud.tapPop()
		local scale = pump:FindFirstChild("PressScale") or New("UIScale", { Name = "PressScale", Parent = pump })
		scale.Scale = 1.08
		Theme.Tween(scale, { Scale = 1 }, 0.16)
	end

	-- the weight panel slides in from the right (the bottom widgets come up with `stack`)
	function hud.show(on: boolean)
		Theme.Tween(panelSlot, { Position = on and UDim2.new() or MachineHud.PanelHidden })
	end

	return hud
end

return MachineHud
