-- MachineHud: the look of the HUD while on a machine (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/02_lifting).
-- MachineClient owns all the logic; this only builds the widgets (mockup px inside a Kit.Root) and returns them.
-- Nothing sits in the middle of the screen:
--   right, top:    the WEIGHT CARD: the machine name + its muscle group in a red tag, - / "45 LB" / +, "Tier 1 / 12" (or
--                  what the weight needs) and BEST WEIGHT in gold; AUTO TRAIN under it (only while Auto Lift is on sale)
--   right, lower:  the PUMP panel (a gold flame, PUMP, the % on the right, a metallic gold bar; full = it glows and says
--                  "TAP TO PUMP!", a tap or Space starts PUMPED x2 and the bar drains with the seconds left)
--   bottom right:  the big red REP CTA ("REP x9")
--   bottom left:   a quiet "x STOP" button; bottom center: the STAMINA panel (Shared/UI/HudBottom)
--   top center:    NEW PERSONAL RECORD! (gold) + "315 LB Bench Press"
-- (No floating text while lifting: coach lines and hints go to the top band, Notify.Hint.)
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local UIConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("UI"))

local New, Colors = Theme.New, Theme.Colors

local MachineHud = {}

MachineHud.PanelSize = Vector2.new(204, 110) -- the weight card
MachineHud.PanelTop = 52 -- (set from Kit.UnderTopbar: just under Roblox's top bar)
MachineHud.Edge = 12
MachineHud.HiddenOffset = UDim2.fromOffset(0, 260) -- the bottom widgets wait below the screen edge
MachineHud.PanelHidden = UDim2.fromOffset(240, 0)  -- the weight card waits past the right edge
MachineHud.RepSize = Vector2.new(204, 70)
MachineHud.PumpSize = Vector2.new(204, 52)
MachineHud.Corner = 12 -- the REP / PUMP gap to the screen's bottom right edge
MachineHud.BarHeight = 46
MachineHud.PlateWidth = 6

local function frame(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New("Frame", props, children)
end

-- a quiet square step button with a line icon (- / +)
local function stepButton(name, icon, props)
	props.Name = name
	props.Size = UDim2.fromOffset(38, 38)
	local button = Theme.Button("Quiet", props, {})
	Pieces.Icon(icon, Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(18, 18), Parent = button })
		:SetAttribute("KeepColor", true)
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

	------------------------------------------------------------ the weight card (right, top)
	local size = MachineHud.PanelSize
	local edge = MachineHud.Edge
	local panelSlot = frame({ Name = "PanelSlot", Size = UDim2.fromScale(1, 1), Position = MachineHud.PanelHidden, Parent = root })
	hud.panelSlot = panelSlot
	local panel = Theme.Panel({ Name = "Panel", Piece = "hud_box", Clickable = true, -- (taps on it don't lift)
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -edge, 0, MachineHud.PanelTop), Size = UDim2.fromOffset(size.X, size.Y),
		Parent = panelSlot })
	hud.panel = panel
	-- the machine name and its muscle group (a red tag)
	hud.titleLabel = Kit.Text({ Name = "MachineName", Text = "", Font = "Title", TextSize = 16, Upper = true, Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -90, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel })
	hud.groupTag = Kit.Tag("Chest", Colors.Red, { Name = "Group", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(0, 18),
		Parent = panel })
	-- - / the weight / +
	hud.minusButton = stepButton("Minus", "minus", { Position = UDim2.fromOffset(12, 36), Parent = panel })
	hud.plusButton = stepButton("Plus", "plus", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 36), Parent = panel })
	local weightRow = frame({ Name = "WeightRow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X, Parent = panel }, {
		Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	hud.weightNumber = Kit.Text({ Name = "Weight", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 38,
		Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	hud.weightUnit = Kit.Text({ Name = "Unit", LayoutOrder = 2, Text = "LB", Font = "Number", TextSize = 13, TextColor3 = Colors.Muted,
		Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	-- "Tier 1 / 12" (or what the weight needs) on the left, BEST WEIGHT in gold on the right
	local tierSlot = frame({ Name = "TierSlot", Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -120, 0, 18), Parent = panel })
	hud.tierTag = frame({ Name = "Tier", Size = UDim2.fromScale(1, 1), Parent = tierSlot })
	Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = hud.tierTag })
	hud.needsLabel = Kit.Text({ Name = "Needs", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.NeedsWork, Size = UDim2.new(1, 100, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Visible = false, Parent = tierSlot })
	-- BEST WEIGHT (the owner's MAX: the heaviest weight the level allows) as gold text, a sibling of + (MachineClient finds it)
	hud.maxButton = New("TextButton", { Name = "Max", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 78), Size = UDim2.fromOffset(104, 26), Parent = panel })
	Kit.GoldText(Kit.Text({ Name = "Label", Text = "BEST WEIGHT", Font = "Title", TextSize = 14, Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = hud.maxButton }))
	Theme.BindPress(hud.maxButton)
	-- UNLOCK (weights are free now: never shown, kept for MachineClient)
	local unlock = Theme.Button("Gold", { Name = "Unlock", Size = UDim2.fromOffset(150, 26), Visible = false, Parent = panel }, {})
	hud.unlockButton = unlock
	hud.unlockText = Kit.Text({ Name = "Label", Text = "Unlock", Font = "Title", TextSize = 14, Size = UDim2.fromScale(1, 1), Parent = unlock })
	hud.unlockIcon = Kit.Coin(15, { Visible = false, Parent = unlock })
	hud.costLabel = Kit.Text({ Name = "Cost", Text = "", Font = "Number", TextSize = 14, Visible = false, Parent = unlock })
	-- AUTO TRAIN under the card (only while Auto Lift is on sale)
	hud.autoButton, hud.autoLabel = Kit.Button("Quiet", "Auto train", { Name = "Auto", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -edge, 0, MachineHud.PanelTop + size.Y + 8), Visible = false, Parent = panelSlot }, { width = size.X, height = 30, icon = "lock", textSize = 14 })

	-- (kept for MachineClient, not shown: the muscle split is on the machine's sign, the barbell drawing and the stamina
	-- segments are gone, stamina is the panel at the bottom)
	local hidden = frame({ Name = "Hidden", Visible = false, Parent = root })
	hud.musclesLabel = Kit.Text({ Name = "Muscles", Text = "", Font = "Body", Parent = hidden })
	hud.noteLabel = Kit.Text({ Name = "CoachNote", Text = "", Font = "Body", Parent = hidden })
	hud.staminaPct = Kit.Text({ Name = "Pct", Text = "", Font = "Number", Parent = hidden })
	hud.pumpHint = Kit.Text({ Name = "PumpHint", Text = "", Font = "Body", Parent = hidden })
	hud.flashSlot = frame({ Name = "FlashSlot", Size = UDim2.fromOffset(300, 24), Parent = hidden })
	hud.barbell = frame({ Name = "Barbell", Size = UDim2.fromOffset(220, MachineHud.BarHeight), Parent = hidden })
	hud.barPlates = {}
	hud.segmentBacks, hud.segments = {}, {}

	------------------------------------------------------------ REP (bottom right), the PUMP panel above it, STOP (bottom left)
	local corner = MachineHud.Corner
	local rep = Theme.Button("Red", { Name = "Rep", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -corner, 1, -corner),
		Size = UDim2.fromOffset(MachineHud.RepSize.X, MachineHud.RepSize.Y), Parent = stack }, {})
	local repRow = frame({ Name = "Content", Size = UDim2.new(1, 0, 1 - Theme.LipHeight, 0), Parent = rep }, {
		Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	Kit.Text({ Name = "Label", LayoutOrder = 1, Text = "REP", Font = "Title", TextSize = 38, Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, Parent = repRow })
	hud.repsLabel = Kit.Text({ Name = "Count", LayoutOrder = 2, Text = "x0", Font = "Number", TextSize = 22, Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X, Parent = repRow })
	hud.repsScale = New("UIScale", { Parent = hud.repsLabel })
	hud.repButton = rep

	-- the PUMP panel: a gold flame, PUMP, the % on the right, a metallic gold bar (the whole panel is the button)
	local pump = Theme.Panel({ Name = "Pump", Piece = "hud_box", Clickable = true, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -corner, 1, -(corner + MachineHud.RepSize.Y + 10)), Size = UDim2.fromOffset(MachineHud.PumpSize.X, MachineHud.PumpSize.Y), Parent = stack })
	Pieces.Icon("flame", Colors.Gold, { Name = "Flame", Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(16, 16), Parent = pump }):SetAttribute("KeepColor", true)
	hud.pumpLabel = Kit.Text({ Name = "Label", Text = "PUMP", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(32, 5), Size = UDim2.new(1, -96, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = pump })
	local pumpPct = Kit.Text({ Name = "Pct", Text = "0%", Font = "Number", TextSize = 13, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 5), Size = UDim2.fromOffset(60, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = pump })
	local _, setPumpBar = Kit.Bar(Colors.Gold, { Name = "Bar", Position = UDim2.fromOffset(12, 29), Size = UDim2.new(1, -24, 0, 14), Parent = pump })
	local pumpScale = New("UIScale", { Parent = pump })
	hud.pumpButton = pump

	hud.exitButton = Kit.Button("Quiet", "Stop", { Name = "Exit", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, corner, 1, -corner), Parent = stack },
		{ width = 98, height = 40, textSize = 16, icon = "x" })

	------------------------------------------------------------ NEW PERSONAL RECORD! (top center)
	local banner = frame({ Name = "PersonalRecord", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(420, 52),
		Visible = false, ZIndex = 5, Parent = root })
	hud.prTitle = Kit.Text({ Name = "Title", Text = "NEW PERSONAL RECORD!", Font = "Title", TextSize = 28, TextColor3 = Colors.Gold,
		Size = UDim2.new(1, 0, 0, 32), ZIndex = 6, Parent = banner })
	hud.prInfo = Kit.Text({ Name = "Info", Text = "", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 6, Parent = banner })
	hud.prBanner = banner

	-- the weight card and the record banner start just under Roblox's top bar
	local function placeUnderTopbar()
		local top = Kit.UnderTopbar(root)
		MachineHud.PanelTop = top
		panel.Position = UDim2.new(1, -edge, 0, top)
		hud.autoButton.Position = UDim2.new(1, -edge, 0, top + size.Y + 8)
		banner.Position = UDim2.new(0.5, 0, 0, top)
	end
	Kit.OnTopbar(placeUnderTopbar)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(placeUnderTopbar) end)

	------------------------------------------------------------ helpers
	function hud.drawBarbell(_plates) end -- (no barbell drawing in this style)

	-- AUTO: hidden (Auto Lift isn't for sale), locked (quiet AUTO TRAIN with a lock: opens the shop), off (quiet AUTO
	-- TRAIN), on (gold AUTO ON)
	function hud.setAuto(mode: string)
		local button = hud.autoButton
		button.Visible = mode ~= "hidden"
		if mode == "hidden" then return end
		local icon = button:FindFirstChild("Icon")
		if mode == "on" then
			Kit.SetButton(button, "Gold", "Auto on")
			if icon then icon.Image = UIConfig.Icons["repeat"] end
		else
			Kit.SetButton(button, "Quiet", "Auto train")
			if icon then icon.Image = UIConfig.Icons[mode == "locked" and "lock" or "repeat"] end
		end
	end

	-- PUMP: the gold bar follows the meter with the % on the right; full = the panel glows and pulses "TAP TO PUMP!"; while
	-- PUMPED it drains with the seconds left ("PUMPED x2", "6s") and glows.
	function hud.setPump(fill01: number, pumped: boolean, left: number?, now: number)
		local amount = math.clamp(fill01, 0, 1)
		setPumpBar(amount)
		local wave = 0.5 + 0.5 * math.sin(now * 7)
		if pumped then
			hud.pumpLabel.Text = "PUMPED x2"
			pumpPct.Text = math.ceil(left or 0) .. "s"
			Theme.SetGlow(pump, Colors.Gold, 0.2 + 0.35 * wave, 12)
			pumpScale.Scale = 1
		elseif amount >= 0.999 then
			hud.pumpLabel.Text = "TAP TO PUMP!"
			pumpPct.Text = "100%"
			Theme.SetGlow(pump, Colors.Gold, 0.15 + 0.5 * wave, 12)
			pumpScale.Scale = 1 + 0.03 * wave
		else
			hud.pumpLabel.Text = "PUMP"
			pumpPct.Text = math.floor(amount * 100 + 0.5) .. "%"
			Theme.SetGlow(pump, nil, nil, 12)
			pumpScale.Scale = 1
		end
	end

	-- every tap: REP pops a little (its press scale is a UIScale named PressScale, made by Theme.Button)
	function hud.tapPop()
		local scale = rep:FindFirstChild("PressScale") or New("UIScale", { Name = "PressScale", Parent = rep })
		scale.Scale = 1.06
		Theme.Tween(scale, { Scale = 1 }, 0.14)
	end

	-- the weight card slides in from the right (the bottom widgets come up with `stack`)
	function hud.show(on: boolean)
		Theme.Tween(panelSlot, { Position = on and UDim2.new() or MachineHud.PanelHidden })
	end

	return hud
end

return MachineHud
