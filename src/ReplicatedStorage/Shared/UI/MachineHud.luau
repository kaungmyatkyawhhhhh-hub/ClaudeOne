-- MachineHud: the look of the panel you see while on a machine (owner's UI redesign, mockups 02_machine_hud and
-- 03_machine_hud_auto). MachineClient owns all the logic; this only builds the widgets (in mockup px inside a Kit.Root,
-- so it scales with the screen) and returns them.
--   bottom center: the panel (machine name + muscle group tag + AUTO, the muscle split line, - / barbell + weight +
--                  tier / +, MAX on top of +, the segmented stamina bar), the coach note just above it
--   right:         PUMP (gold, fills with your taps) above the big red REP button (the rep count under REP)
--   top left:      LEAVE; top center under the top bar: the NEW PERSONAL RECORD banner
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local UIConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("UI"))

local New, Colors = Theme.New, Theme.Colors

local MachineHud = {}

MachineHud.PanelSize = Vector2.new(420, 176)
MachineHud.Bottom = 10          -- panel's gap to the screen bottom
MachineHud.HiddenOffset = UDim2.fromOffset(0, 320) -- the panel group waits below the screen edge
MachineHud.Segments = 10
MachineHud.SegmentBack = 0.88   -- empty stamina segments: faint white over the dark panel
MachineHud.PlateWidth = 6
MachineHud.BarHeight = 46       -- the barbell drawing's height (the biggest plate)

local function frame(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New("Frame", props, children)
end

-- A round image button (REP / PUMP): the piece, its soft ring behind, a press shrink.
local function roundButton(name, piece, ring, size, ringSize, parent)
	local holder = frame({ Name = name .. "Slot", Size = UDim2.fromOffset(ringSize, ringSize), Parent = parent })
	local halo = Pieces.Image(ring, { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), Parent = holder })
	local button = New("ImageButton", { Name = name, AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 2, Parent = holder })
	Pieces.Apply(button, piece)
	local scale = New("UIScale", { Parent = button })
	local function press(on)
		Theme.Tween(scale, { Scale = on and 0.94 or 1 }, on and 0.06 or 0.14)
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then press(true) end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then press(false) end
	end)
	button.MouseLeave:Connect(function() press(false) end)
	return holder, button, halo, scale
end

-- Square dark step button (- / +) with a line icon.
local function stepButton(name, icon, props)
	props.Name = name
	props.Size = UDim2.fromOffset(40, 36)
	local button = Theme.Button("Secondary", props, {})
	Pieces.Icon(icon, Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18), Parent = button })
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

	-- everything that slides up from the bottom when you get on
	local stack = frame({ Name = "Group", Size = UDim2.fromScale(1, 1), Position = MachineHud.HiddenOffset, Parent = root })
	hud.stack = stack

	------------------------------------------------------------ the panel
	local size = MachineHud.PanelSize
	local panel = Theme.Panel({ Name = "Panel", Piece = "hud_box", Shadow = false, Clickable = true, -- (taps on it don't lift)
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -MachineHud.Bottom), Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 2, Parent = stack })
	hud.panel = panel

	-- header: name, group tag, AUTO
	local header = frame({ Name = "Header", Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 28), Parent = panel }, {
		Theme.List(Enum.FillDirection.Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	hud.titleLabel = Kit.Text({ Name = "MachineName", LayoutOrder = 1, Text = "", Font = "Title", TextSize = 20,
		Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	hud.groupTag = Kit.Tag("Chest", Colors.Red, { Name = "Group", LayoutOrder = 2, Size = UDim2.fromOffset(0, 18), ImageColor3 = Colors.RedTint, Parent = header })

	local auto = frame({ Name = "AutoSlot", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X, Parent = panel })
	hud.autoButton, hud.autoLabel = Kit.Button("Secondary", "Auto", { Name = "Auto", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Visible = false, Parent = auto }, { height = 28, icon = "lock", textSize = 13 })
	hud.autoSlot = auto

	-- the muscle split line
	hud.musclesLabel = Kit.Text({ Name = "Muscles", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted,
		Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel })

	-- - / + and MAX (owner, 9 Oct: MAX sits right on top of +, the same width, a third of its height, a 3px gap)
	hud.minusButton = stepButton("Minus", "minus", { Position = UDim2.fromOffset(12, 81), Parent = panel })
	hud.plusButton = stepButton("Plus", "plus", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 81), Parent = panel })
	local maxButton = Theme.Button("Gold", { Name = "Max", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 0, 81 - 3),
		Size = UDim2.fromOffset(40, 16), Parent = panel }, {})
	Kit.Text({ Name = "Label", Text = "Max", Font = "Title", TextSize = 10, TextColor3 = Colors.Ink, Size = UDim2.new(1, 0, 1, -2), Parent = maxButton })
	hud.maxButton = maxButton

	-- the barbell drawing, then the weight row (number, unit, tier tag / unlock / needs)
	hud.barbell = frame({ Name = "Barbell", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 63),
		Size = UDim2.fromOffset(220, MachineHud.BarHeight), Parent = panel })
	hud.barPlates = {}
	local weightRow = frame({ Name = "WeightRow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Parent = panel }, {
		Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	hud.weightNumber = Kit.Text({ Name = "Weight", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 28,
		Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	hud.weightUnit = Kit.Text({ Name = "Unit", LayoutOrder = 2, Text = "LB", Font = "Number", TextSize = 10, TextColor3 = Colors.Muted,
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	frame({ Name = "Gap", LayoutOrder = 3, Size = UDim2.fromOffset(6, 1), Parent = weightRow })
	local tagSlot = frame({ Name = "TagSlot", LayoutOrder = 4, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow }, {
		Theme.List(Enum.FillDirection.Horizontal, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	hud.tierTag = Kit.Tag("Tier 1 / 1", Colors.Gold, { Name = "Tier", LayoutOrder = 1, Size = UDim2.fromOffset(0, 20), Parent = tagSlot })
	hud.needsLabel = Kit.Text({ Name = "Needs", LayoutOrder = 2, Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.NeedsWork,
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = tagSlot })
	-- unlock the next weight: a gold button with its coin price
	local unlock = Theme.Button("Gold", { Name = "Unlock", LayoutOrder = 3, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		Visible = false, Parent = tagSlot }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 3) }),
		Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	hud.unlockButton = unlock
	hud.unlockText = Kit.Text({ Name = "Label", LayoutOrder = 1, Text = "Unlock", Font = "Title", TextSize = 12, TextColor3 = Colors.Ink,
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = unlock })
	hud.unlockIcon = Kit.Coin(13, { LayoutOrder = 2, Parent = unlock })
	hud.costLabel = Kit.Text({ Name = "Cost", LayoutOrder = 3, Text = "", Font = "Number", TextSize = 12, TextColor3 = Colors.Ink,
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = unlock })

	-- stamina: label, 10 segments, percent
	local staminaRow = frame({ Name = "Stamina", Position = UDim2.fromOffset(12, 146), Size = UDim2.new(1, -24, 0, 18), Parent = panel })
	Kit.Text({ Name = "Label", Text = "Stamina", Font = "Label", TextSize = 10, Size = UDim2.fromOffset(56, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = staminaRow })
	hud.staminaPct = Kit.Text({ Name = "Pct", Text = "100%", Font = "Number", TextSize = 13, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = staminaRow })
	local segmentRow = frame({ Name = "Segments", Position = UDim2.fromOffset(60, 4), Size = UDim2.new(1, -60 - 46, 0, 10), Parent = staminaRow }, {
		Theme.List(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	hud.segmentBacks, hud.segments = {}, {}
	for i = 1, MachineHud.Segments do
		local back = frame({ Name = "Segment" .. i, LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundTransparency = MachineHud.SegmentBack,
			BackgroundColor3 = Colors.Text, Parent = segmentRow }, {
			New("UICorner", { CornerRadius = UDim.new(0, 3) }),
			New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		hud.segmentBacks[i] = back
		hud.segments[i] = frame({ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Colors.Green, Parent = back },
			{ New("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	end

	-- above the panel: the coach note (left) and the level flash (right)
	local above = frame({ Name = "Above", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(MachineHud.Bottom + size.Y + 4)),
		Size = UDim2.fromOffset(size.X, 24), Parent = stack })
	hud.noteLabel = Kit.Text({ Name = "CoachNote", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, 0), Size = UDim2.new(0.62, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = above })
	Theme.TextShadow(hud.noteLabel)
	hud.flashSlot = above

	------------------------------------------------------------ PUMP + REP (right)
	local right = frame({ Name = "Right", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -16), Size = UDim2.fromOffset(116, 200),
		Parent = stack })
	local repSlot, rep, repRing = roundButton("Rep", "rep_button", "rep_button_ring", 104, 116, right)
	repSlot.AnchorPoint, repSlot.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, 0)
	Kit.Text({ Name = "Label", Text = "Rep", Font = "Title", TextSize = 26, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 30), Parent = rep })
	hud.repsLabel = Kit.Text({ Name = "Count", Text = "x0", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 16), Parent = rep })
	hud.repsScale = New("UIScale", { Parent = hud.repsLabel })
	hud.repButton, hud.repRing = rep, repRing

	local pumpSlot, pump, pumpRing, pumpScale = roundButton("Pump", "pump_button", "pump_button_ring", 64, 72, right)
	pumpSlot.AnchorPoint, pumpSlot.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -122)
	Pieces.Icon("flame", Colors.Ink, { Name = "Flame", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(18, 18), Parent = pump }):SetAttribute("KeepColor", true)
	hud.pumpLabel = Kit.Text({ Name = "Label", Text = "Pump", Font = "Title", TextSize = 12, TextColor3 = Colors.Ink,
		Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 16), Parent = pump })
	hud.pumpButton, hud.pumpRing, hud.pumpScale = pump, pumpRing, pumpScale
	-- one-time hint, left of PUMP
	hud.pumpHint = Kit.Text({ Name = "PumpHint", Text = "", Font = "Strong", TextSize = 11, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -8, 0.5, 0), Size = UDim2.fromOffset(150, 16), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = pumpSlot })
	Theme.TextShadow(hud.pumpHint)

	------------------------------------------------------------ LEAVE (top left)
	hud.exitButton = Kit.Button("Secondary", "Leave", { Name = "Exit", Position = UDim2.fromOffset(96, 8), Parent = root },
		{ height = 32, icon = "chevron-left", textSize = 15 })

	------------------------------------------------------------ NEW PERSONAL RECORD banner
	local banner = Pieces.Image("banner_gold", { Name = "PersonalRecord", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 5, Parent = root }, {})
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16), Parent = banner })
	Theme.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = banner
	local trophy = Pieces.Image("rounded_white_r8", { Name = "Tile", LayoutOrder = 1, ImageColor3 = Colors.Gold, Size = UDim2.fromOffset(30, 30), ZIndex = 6, Parent = banner })
	Pieces.Icon("trophy", Colors.Ink, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 6,
		Parent = trophy }):SetAttribute("KeepColor", true)
	local texts = frame({ Name = "Texts", LayoutOrder = 2, Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, Parent = banner }, {
		Theme.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	hud.prTitle = Kit.Text({ Name = "Title", LayoutOrder = 1, Text = "New personal record", Font = "Title", TextSize = 16, TextColor3 = Colors.Gold,
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = texts })
	hud.prInfo = Kit.Text({ Name = "Info", LayoutOrder = 2, Text = "", Font = "Number", TextSize = 11, Upper = false,
		Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = texts })
	hud.prBanner = banner

	------------------------------------------------------------ helpers
	-- Side view of the loaded bar: plates in their tier colors (heaviest inside), sleeves, collars, the shaft.
	-- plates: list of { color = Color3, height = 0..1 } from the inside out.
	function hud.drawBarbell(plates)
		local bar = hud.barbell
		bar:ClearAllChildren()
		table.clear(hud.barPlates)
		local w, h = bar.Size.X.Offset, MachineHud.BarHeight
		local mid = h / 2
		local function rect(x, width, height, color, round)
			return frame({ Position = UDim2.fromOffset(math.floor(x), math.floor(mid - height / 2)), Size = UDim2.fromOffset(width, math.max(2, math.floor(height))),
				BackgroundTransparency = 0, BackgroundColor3 = color, Parent = bar }, round and { New("UICorner", { CornerRadius = UDim.new(0, round) }) } or nil)
		end
		local steel = Color3.fromHex("#B9B4B6")
		local pitch = MachineHud.PlateWidth + 2
		local inner = 64 -- the collars' distance from the centre
		rect(w / 2 - inner, inner * 2, 4, steel) -- the shaft
		for side = -1, 1, 2 do
			local x0 = w / 2 + side * inner
			rect(side < 0 and x0 - 3 or x0, 3, 14, steel, 1) -- collar
			local x = side < 0 and x0 - 3 - 2 or x0 + 3 + 2
			for _, plate in ipairs(plates) do
				local px = side < 0 and x - MachineHud.PlateWidth or x
				table.insert(hud.barPlates, rect(px, MachineHud.PlateWidth, math.max(10, plate.height * h), plate.color, 2))
				x += side * pitch
			end
			rect(side < 0 and x - 12 or x, 12, 6, steel, 2) -- sleeve end
		end
	end

	-- The AUTO button: hidden (no Auto Lift for sale), locked, or ON (green) / OFF (dark).
	function hud.setAuto(mode: string)
		local button = hud.autoButton
		button.Visible = mode ~= "hidden"
		if mode == "hidden" then return end
		local icon = button:FindFirstChild("Icon")
		if mode == "on" then
			Kit.SetButton(button, "Green", "Auto on")
			if icon then icon.Image = UIConfig.Icons["repeat"] end
		else
			Kit.SetButton(button, "Secondary", "Auto")
			if icon then icon.Image = UIConfig.Icons[mode == "locked" and "lock" or "repeat"] end
		end
	end

	-- PUMP: the button darkens while the meter is low and brightens as it fills; PUMPED glows with its seconds left.
	function hud.setPump(fill: number, pumped: boolean, left: number?, now: number)
		local bright = pumped and 1 or (0.7 + 0.3 * math.clamp(fill, 0, 1))
		pump.ImageColor3 = Color3.new(bright, bright, bright)
		if pumped then
			hud.pumpLabel.Text = math.ceil(left or 0) .. "s"
			pumpRing.ImageTransparency = 0.25 * (0.5 + 0.5 * math.sin(now * 6))
		else
			hud.pumpLabel.Text = "PUMP"
			pumpRing.ImageTransparency = 1 - 0.8 * math.clamp(fill, 0, 1)
		end
	end

	function hud.tapPop()
		pumpScale.Scale = 1.08
		Theme.Tween(pumpScale, { Scale = 1 }, 0.16)
	end

	return hud
end

return MachineHud
