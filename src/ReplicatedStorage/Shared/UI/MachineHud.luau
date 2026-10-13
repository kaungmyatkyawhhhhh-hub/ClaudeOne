-- MachineHud: the look of the HUD while on a machine (owner's UI v2, mockups 02_machine_hud / 03_machine_auto).
-- MachineClient owns all the logic; this only builds the widgets (mockup px inside a Kit.Root) and returns them.
-- Nothing sits in the middle of the screen (owner, 13 Oct: the old panel covered the player):
--   right:         the weight panel: AUTO TRAIN (AUTO ON in green), WEIGHT "315 LB", "Tier 12 / 12" (or what it needs),
--                  - / +, BEST WEIGHT (or UNLOCK with the price when the weight shown isn't bought yet)
--   bottom right:  the red REP button (reps "x13") and, right above it, the PUMP bar (owner, 14 Oct: back to a bar as
--                  before the new UI): gold fill with every tapped rep; full = it pulses "TAP TO PUMP!" and a tap on it
--                  (or Space) starts PUMPED (x2, the bar drains with the seconds left)
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
MachineHud.RepSize = Vector2.new(104, 52)
MachineHud.PumpSize = Vector2.new(186, 28)
MachineHud.Corner = 12 -- the REP / PUMP gap to the screen's bottom right edge
MachineHud.BarHeight = 46
MachineHud.PlateWidth = 6

local function frame(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New("Frame", props, children)
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

	------------------------------------------------------------ REP + the PUMP bar (bottom right) and STOP TRAINING
	local edge = MachineHud.Corner
	local rep = Theme.Button("Red", { Name = "Rep", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -edge, 1, -edge),
		Size = UDim2.fromOffset(MachineHud.RepSize.X, MachineHud.RepSize.Y), Parent = stack }, {})
	Kit.Text({ Name = "Label", Text = "REP", Font = "Title", TextSize = 24, Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 26), Parent = rep })
	hud.repsLabel = Kit.Text({ Name = "Count", Text = "x0", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 16), Parent = rep })
	hud.repsScale = New("UIScale", { Parent = hud.repsLabel })
	hud.repButton = rep

	-- the PUMP bar: a dark track with a dark outline, the gold fill, a flame + PUMP on the left, the state on the right
	local pump = New("TextButton", { Name = "Pump", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -edge, 1, -(edge + MachineHud.RepSize.Y + 6)), Size = UDim2.fromOffset(MachineHud.PumpSize.X, MachineHud.PumpSize.Y),
		BackgroundColor3 = Colors.Well, Parent = stack }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local glow = New("UIStroke", { Name = "Glow", Color = Colors.Gold, Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	-- (the glow sits on a frame just outside the outline, so both show)
	frame({ Name = "GlowRing", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 6, 1, 6), Parent = pump }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }), glow,
	})
	local fill = New("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = pump }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Gradients.Gold[1], Theme.Gradients.Gold[2]) }),
	})
	Pieces.Icon("flame", Colors.Text, { Name = "Flame", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(16, 16),
		ZIndex = 3, Parent = pump }):SetAttribute("KeepColor", true)
	hud.pumpLabel = Kit.Text({ Name = "Label", Text = "PUMP", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(27, 0), Size = UDim2.new(1, -34, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = pump })
	local pumpScale = New("UIScale", { Parent = pump })
	hud.pumpButton = pump

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

	-- PUMP: the gold fill follows the meter; full = it pulses "TAP TO PUMP!"; while PUMPED it drains with the seconds left
	-- ("PUMPED x2  6s") and glows.
	function hud.setPump(fill01: number, pumped: boolean, left: number?, now: number)
		local amount = math.clamp(fill01, 0, 1)
		fill.Visible = amount > 0.01
		fill.Size = UDim2.fromScale(amount, 1)
		local wave = 0.5 + 0.5 * math.sin(now * 7)
		if pumped then
			hud.pumpLabel.Text = "PUMPED x2  " .. math.ceil(left or 0) .. "s"
			glow.Transparency = 0.15 + 0.35 * wave
			pumpScale.Scale = 1
		elseif amount >= 0.999 then
			hud.pumpLabel.Text = "TAP TO PUMP!"
			glow.Transparency = 0.6 * wave
			pumpScale.Scale = 1 + 0.04 * wave
		else
			hud.pumpLabel.Text = "PUMP"
			glow.Transparency = 1
			pumpScale.Scale = 1
		end
	end

	-- every tap: REP pops a little (its press scale is a UIScale named PressScale, made by Theme.Button)
	function hud.tapPop()
		local scale = rep:FindFirstChild("PressScale") or New("UIScale", { Name = "PressScale", Parent = rep })
		scale.Scale = 1.06
		Theme.Tween(scale, { Scale = 1 }, 0.14)
	end

	-- the weight panel slides in from the right (the bottom widgets come up with `stack`)
	function hud.show(on: boolean)
		Theme.Tween(panelSlot, { Position = on and UDim2.new() or MachineHud.PanelHidden })
	end

	return hud
end

return MachineHud
