-- MachineHud: the look of the HUD while on a machine (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/02_lifting;
-- owner's mobile fixes, 14 Oct). MachineClient owns all the logic; this only builds the widgets (mockup px inside a
-- Kit.Root) and returns them. Nothing sits in the middle of the screen:
--   right:         the WEIGHT CARD a bit above the middle of the screen (owner, 14 Oct: centre at 40% of the height,
--                  16 px from the right safe edge): the machine name + its muscle group in a red tag, - / "45 LB" / + (both
--                  steps always there, greyed when they can't go further), then "Tier 1 / 12" on the left and the BEST
--                  WEIGHT button on the right on one line (a real gold button with an up-arrow icon; "AT BEST" with a check,
--                  flat and dark, when you're on it). When the weight needs a higher level, that requirement gets its own
--                  line and the Tier / BEST WEIGHT line moves under it. AUTO TRAIN under the card (only while Auto Lift is on
--                  sale). The card, PUMP and REP never overlap (10 px apart): on short screens the card shrinks to 0.9 and,
--                  only if it still doesn't fit, moves up just enough.
--   right, bottom: the red REP CTA ("REP x9", 150x46) with the PUMP panel right above it (same width; full = it glows and
--                  says "TAP TO PUMP!", a tap or Space starts PUMPED x2 and the bar drains with the seconds left).
--                  ONE fixed spot (owner, 14 Oct: it must never move during play): on touch screens directly above
--                  Roblox's jump button (12 px gap, right edges lined up), worked out once from TouchGui's JumpButton
--                  (its size and place are there even while Roblox hides it on a seat) and again only when the screen
--                  size changes; on a PC / console the bottom right corner.
--                  Phone or PC (owner, 15 Oct: a phone with no jump button got the PC layout): MachineHud.LayoutMode() =
--                  "phone" when the screen's short side is under PhoneShortSide points (whatever the input), else from
--                  UserInputService.PreferredInput (Touch = phone) or, without it, TouchEnabled and not KeyboardEnabled.
--                  Re-checked live (PreferredInput / LastInputType changes). A phone without a visible jump button uses a
--                  fixed bottom-right spot (TouchLift) instead of the PC corner. The F9 console says which layout and why.
--   left, bottom:  a quiet "x STOP" button (on touch screens above the thumbstick)
--   bottom center: the slim STAMINA bar (Shared/UI/HudBottom)
--   top center:    NEW PERSONAL RECORD! (gold) + "315 LB Bench Press"
-- (No floating text while lifting: coach lines aren't shown; first-time tips go to the top band, Notify.Hint.)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local UIConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("UI"))

local New, Colors = Theme.New, Theme.Colors

local MachineHud = {}

MachineHud.PanelSize = Vector2.new(184, 92) -- the weight card (it grows by NeedsLine while a requirement shows)
MachineHud.PanelCenterY = 0.40 -- the card's centre, as a share of the screen height (owner, 14 Oct)
MachineHud.PanelRight = 16     -- px from the right safe edge
MachineHud.Gap = 8             -- between the card, AUTO TRAIN, PUMP and REP (owner, 23 Oct: one ~8 px gap)
MachineHud.StackCorner = 12    -- (owner, 23 Oct) the four in the stack share one corner radius
MachineHud.AutoHeight = 30     -- AUTO TRAIN's height on screen
MachineHud.NeedsLine = 16
MachineHud.PanelTop = 52 -- (set from Kit.UnderTopbar: just under Roblox's top bar)
MachineHud.Edge = 12
MachineHud.HiddenOffset = UDim2.fromOffset(0, 260) -- the bottom widgets wait below the screen edge
MachineHud.PanelHidden = UDim2.fromOffset(240, 0)  -- the weight card waits past the right edge
MachineHud.RepSize = Vector2.new(150, 46)
MachineHud.PumpSize = Vector2.new(150, 40)
MachineHud.Corner = 12   -- gap to the screen edges (PC)
MachineHud.TouchLift = 150 -- touch screen before Roblox has made its jump button / thumbstick: this far up from the bottom
MachineHud.TouchGap = 12   -- REP above the jump button, STOP above the thumbstick
MachineHud.BarHeight = 46
MachineHud.PhoneShortSide = 500 -- points: a screen whose short side is under this is always the phone layout
MachineHud.PlateWidth = 6

local function frame(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New("Frame", props, children)
end

-- a quiet square step button with a line icon (- / +)
local function stepButton(name, icon, props)
	props.Name = name
	props.Size = UDim2.fromOffset(34, 34)
	local button = Theme.Button("Quiet", props, {})
	Pieces.Icon(icon, Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(16, 16), Parent = button })
		:SetAttribute("KeepColor", true)
	return button
end

-- "phone" or "pc", and why (the rule above)
-- (Studio-only test switches on Workspace: TestPhoneSize (Vector2) = that screen size; TestInput = "Touch",
-- "TouchKeyboard" or "KeyboardAndMouse" = that input; TestNoJump = true acts as if Roblox's jump button were hidden)
local IS_STUDIO = game:GetService("RunService"):IsStudio()
local function testSwitch(name)
	return if IS_STUDIO then workspace:GetAttribute(name) else nil
end

function MachineHud.LayoutMode(): (string, string)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local testSize = testSwitch("TestPhoneSize")
	if typeof(testSize) == "Vector2" then viewport = testSize end
	local short = math.min(viewport.X, viewport.Y)
	if short > 1 and short < MachineHud.PhoneShortSide then
		return "phone", string.format("small screen (%dx%d)", viewport.X, viewport.Y)
	end
	local testInput = testSwitch("TestInput")
	if testInput == "Touch" then return "phone", "PreferredInput = Touch (test)" end
	if testInput == "TouchKeyboard" then return "pc", "PreferredInput = KeyboardAndMouse, touch + keyboard (test)" end
	if testInput == "KeyboardAndMouse" then return "pc", "PreferredInput = KeyboardAndMouse (test)" end
	local ok, preferred = pcall(function() return (UserInputService :: any).PreferredInput end)
	if ok and typeof(preferred) == "EnumItem" then
		if preferred.Name == "Touch" then return "phone", "PreferredInput = Touch" end
		return "pc", "PreferredInput = " .. preferred.Name
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "phone", "touch, no keyboard" end
	return "pc", if UserInputService.TouchEnabled then "touch + keyboard" else "no touch"
end

-- Roblox's touch controls (nil on a PC / console): the jump button and the thumbstick's resting place. Their size and
-- place are read even while Roblox hides them (on a seat), so the answer never changes during play.
local function touchControls(playerGui)
	if testSwitch("TestNoJump") == true then return nil, nil end
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local controls = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	if not controls then return nil, nil end
	local jump = controls:FindFirstChild("JumpButton")
	local stick = nil
	for _, name in ipairs({ "ThumbstickStart", "ThumbstickFrame" }) do
		local found = controls:FindFirstChild(name, true)
		if found and found:IsA("GuiObject") and found.AbsoluteSize.X > 0 then
			stick = found
			break
		end
	end
	return (jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0) and jump or nil, stick
end

function MachineHud.Build()
	local hud = {}
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.ScreenGui({ Name = "MachineHud", Enabled = false, DisplayOrder = 5, Parent = playerGui })
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
	-- (owner, 23 Oct) the card is drawn at PanelSize and scaled to REP's width (placePanel), its top-right corner on the
	-- stack's right edge, so the card, AUTO TRAIN, PUMP and REP are one width with the same edges
	local panel = Theme.Panel({ Name = "Panel", Piece = "hud_box", Clickable = true, -- (taps on it don't lift)
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -MachineHud.PanelRight, 0, 60), Size = UDim2.fromOffset(size.X, size.Y),
		Parent = panelSlot })
	local panelScale = New("UIScale", { Name = "Fit", Parent = panel })
	hud.panel = panel
	-- the machine name and its muscle group (a red tag)
	hud.titleLabel = Kit.Text({ Name = "MachineName", Text = "", Font = "Title", TextSize = 14, Upper = true, Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -80, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel })
	hud.groupTag = Kit.Tag("Chest", Colors.Red, { Name = "Group", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 7), Size = UDim2.fromOffset(0, 17),
		Parent = panel })
	-- - / the weight / +
	hud.minusButton = stepButton("Minus", "minus", { Position = UDim2.fromOffset(10, 28), Parent = panel })
	hud.plusButton = stepButton("Plus", "plus", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 28), Parent = panel })
	local weightRow = frame({ Name = "WeightRow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 27), Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X, Parent = panel }, {
		Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	hud.weightNumber = Kit.Text({ Name = "Weight", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 32,
		Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	hud.weightUnit = Kit.Text({ Name = "Unit", LayoutOrder = 2, Text = "LB", Font = "Number", TextSize = 12, TextColor3 = Colors.Muted,
		Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Parent = weightRow })
	-- line 1: "Tier 1 / 12" left, BEST WEIGHT right; while a requirement shows it takes line 1 (full width) and BEST
	-- WEIGHT drops to line 2
	-- the bottom line: "Tier 1 / 12" left and BEST WEIGHT right, both centred on the same line (rowY = the line's centre)
	local rowY = 75
	local needsY = 64
	hud.tierTag = frame({ Name = "Tier", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(10, rowY), Size = UDim2.new(1, -112, 0, 16), Parent = panel })
	Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = hud.tierTag })
	hud.needsLabel = Kit.Text({ Name = "Needs", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(10, needsY), Size = UDim2.new(1, -20, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false, Parent = panel })
	-- BEST WEIGHT (the heaviest weight the level allows): a real gold button (no ring: not the screen's main CTA) with an
	-- up-arrow icon. `hud.maxButton` is its tap area, 44 px tall (bigger than the 26 px button inside it), a sibling of +
	-- (MachineClient finds it as "Max"); the gold button itself doesn't take input, so every tap lands on the tap area.
	hud.maxButton = New("TextButton", { Name = "Max", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0, rowY), Size = UDim2.fromOffset(104, 44), Parent = panel })
	hud.maxVisual = Kit.Button("Green", "Best weight", { Name = "Visual", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Parent = hud.maxButton }, { width = 100, height = 26, textSize = 11, icon = "arrow-big-up", iconColor = Colors.Ink })
	hud.maxVisual.Interactable = false
	Theme.BindPress(hud.maxButton)
	-- AT BEST: flat and dark, muted text, a check; it can't be pressed
	function hud.setAtBest(atBest: boolean)
		local icon = hud.maxVisual:FindFirstChild("Icon")
		Kit.SetButton(hud.maxVisual, atBest and "Disabled" or "Green", atBest and "At best" or "Best weight")
		if icon then
			icon.Image = UIConfig.Icons[atBest and "check" or "arrow-big-up"]
			icon.ImageColor3 = atBest and Colors.Faint or Colors.Ink
		end
		hud.maxButton:SetAttribute("AtBest", atBest) -- (MachineClient ignores the tap; it still takes it, so it never lifts)
	end
	local function fitNeeds()
		local extra = hud.needsLabel.Visible and MachineHud.NeedsLine or 0
		panel.Size = UDim2.fromOffset(size.X, size.Y + extra)
		hud.maxButton.Position = UDim2.new(1, -6, 0, rowY + extra)
		hud.tierTag.Position = UDim2.fromOffset(10, rowY + extra)
	end
	hud.needsLabel:GetPropertyChangedSignal("Visible"):Connect(fitNeeds)
	-- UNLOCK (weights are free now: never shown, kept for MachineClient)
	local unlock = Theme.Button("Gold", { Name = "Unlock", Size = UDim2.fromOffset(150, 26), Visible = false, Parent = panel }, {})
	hud.unlockButton = unlock
	hud.unlockText = Kit.Text({ Name = "Label", Text = "Unlock", Font = "Title", TextSize = 14, Size = UDim2.fromScale(1, 1), Parent = unlock })
	hud.unlockIcon = Kit.Coin(15, { Visible = false, Parent = unlock })
	hud.costLabel = Kit.Text({ Name = "Cost", Text = "", Font = "Number", TextSize = 14, Visible = false, Parent = unlock })
	-- AUTO TRAIN under the card (only while Auto Lift is on sale)
	-- (sizes in the card's own px: placePanel sets its gap and height so that, scaled with the card, they're Gap and
	-- AutoHeight on screen)
	hud.autoButton, hud.autoLabel = Kit.Button("Quiet", "Auto train", { Name = "Auto", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, 8), Visible = false, Parent = panel }, { width = size.X, height = 34, icon = "lock", textSize = 14 })

	-- (kept for MachineClient, not shown: the muscle split is on the machine's sign, the barbell drawing and the stamina
	-- segments are gone, stamina is the bar at the bottom)
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
		Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	Kit.Text({ Name = "Label", LayoutOrder = 1, Text = "REP", Font = "Chunky", TextSize = 30, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Parent = repRow })
	hud.repsLabel = Kit.Text({ Name = "Count", LayoutOrder = 2, Text = "x0", Font = "Chunky", TextSize = 18, Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X, Parent = repRow })
	hud.repsScale = New("UIScale", { Parent = hud.repsLabel })
	hud.repButton = rep

	-- the PUMP panel: a gold flame, PUMP, the % on the right, a metallic gold bar (the whole panel is the button)
	local pump = Theme.Panel({ Name = "Pump", Piece = "hud_box", Clickable = true, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -corner, 1, -(corner + MachineHud.RepSize.Y + MachineHud.Gap)), Size = UDim2.fromOffset(MachineHud.PumpSize.X, MachineHud.PumpSize.Y), Parent = stack })
	Pieces.Icon("flame", Colors.Gold, { Name = "Flame", Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(14, 14), Parent = pump }):SetAttribute("KeepColor", true)
	hud.pumpLabel = Kit.Text({ Name = "Label", Text = "PUMP", Font = "Title", TextSize = 12, Position = UDim2.fromOffset(28, 3), Size = UDim2.new(1, -78, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pump })
	local pumpPct = Kit.Text({ Name = "Pct", Text = "0%", Font = "Number", TextSize = 12, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 3), Size = UDim2.fromOffset(46, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = pump })
	local _, setPumpBar = Kit.Bar(Colors.Gold, { Name = "Bar", Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 9), Parent = pump })
	local pumpScale = New("UIScale", { Parent = pump })
	hud.pumpButton = pump

	hud.exitButton = Kit.Button("Quiet", "Stop", { Name = "Exit", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, corner, 1, -corner), Parent = stack },
		{ width = 92, height = 40, textSize = 15, icon = "x" })
	-- (prompt 16) dumbbells only: EXERCISE reopens the exercise picker (right above STOP: beside it is the shake button)
	hud.changeButton = Kit.Button("Quiet", "Exercise", { Name = "ChangeExercise", AnchorPoint = Vector2.new(0, 1), Visible = false,
		Position = UDim2.new(0, corner, 1, -(corner + 48)), Parent = stack }, { width = 124, height = 40, textSize = 15, icon = "dumbbell" })

	------------------------------------------------------------ NEW PERSONAL RECORD! (top center)
	local banner = frame({ Name = "PersonalRecord", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(420, 52),
		Visible = false, ZIndex = 5, Parent = root })
	hud.prTitle = Kit.Text({ Name = "Title", Text = "NEW PERSONAL RECORD!", Font = "Title", TextSize = 28, TextColor3 = Colors.Gold,
		Size = UDim2.new(1, 0, 0, 32), ZIndex = 6, Parent = banner })
	hud.prInfo = Kit.Text({ Name = "Info", Text = "", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 6, Parent = banner })
	hud.prBanner = banner

	-- the record banner starts just under Roblox's top bar
	local placePanel -- (below)
	local function placeUnderTopbar()
		local top = Kit.UnderTopbar(root)
		MachineHud.PanelTop = top
		banner.Position = UDim2.new(0.5, 0, 0, top)
		if placePanel then placePanel() end
	end
	Kit.OnTopbar(placeUnderTopbar)
	panel:GetPropertyChangedSignal("Size"):Connect(placeUnderTopbar)
	hud.autoButton:GetPropertyChangedSignal("Visible"):Connect(placeUnderTopbar)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(placeUnderTopbar) end)

	-- REP / PUMP directly above Roblox's jump button and STOP above the thumbstick on touch screens; the corners on a PC.
	-- Worked out once and kept (owner, 14 Oct: REP never moves while playing); only a new screen size works it out again.
	local placed = nil -- { repRight, repBottom, stopBottom, final } in mockup px (final: measured from the real controls)
	local function measure()
		local s = Kit.Scale()
		local rootTop, rootH = root.AbsolutePosition.Y, root.AbsoluteSize.Y
		local rootRight = root.AbsolutePosition.X + root.AbsoluteSize.X
		if rootH < 1 then return nil end
		local jump, stick = touchControls(playerGui)
		-- (right after spawning Roblox hasn't placed its controls yet: only a jump button / thumbstick in the lower half of
		-- the screen counts, so a half-made layout is never kept)
		local half = rootTop + rootH / 2
		if jump and jump.AbsolutePosition.Y < half then jump = nil end
		if stick and stick.AbsolutePosition.Y < half then stick = nil end
		local mode = MachineHud.LayoutMode()
		local touch = mode == "phone"
		if not touch then jump, stick = nil, nil end -- (a PC layout never follows touch controls)
		-- (final on a phone once the real controls were read; with none shown, the fixed spot is kept and looked at again
		-- each second in case they appear)
		local result = { repRight = corner, repBottom = corner, stopBottom = corner, mode = mode, final = not touch or (jump ~= nil and stick ~= nil) }
		if jump then
			result.repRight = math.max(corner, (rootRight - (jump.AbsolutePosition.X + jump.AbsoluteSize.X)) / s)
			result.repBottom = (rootTop + rootH - jump.AbsolutePosition.Y) / s + MachineHud.TouchGap
		elseif touch then
			result.repBottom = MachineHud.TouchLift
		end
		if stick then
			result.stopBottom = (rootTop + rootH - stick.AbsolutePosition.Y) / s + MachineHud.TouchGap
		elseif touch then
			result.stopBottom = MachineHud.TouchLift
		end
		return result
	end
	-- (owner, 23 Oct: one even stack) The weight card, AUTO TRAIN, PUMP and REP are REP's width, with the same right and
	-- left edges and Gap between each, built up from REP: the card is scaled to REP's width (its - / + at the two ends,
	-- the weight in the middle, as drawn), its outline and corners kept as thick and round as PUMP's. Only when the stack
	-- wouldn't fit under the top bar does the card shrink further (owner, 15 Oct: nothing cut off), its right edge kept.
	local lookScale = nil
	local function keepLook(scale: number)
		if lookScale == scale then return end
		lookScale = scale
		local radius = MachineHud.StackCorner
		local corner = panel:FindFirstChildOfClass("UICorner")
		if corner then corner.CornerRadius = UDim.new(0, radius / scale) end
		local border = panel:FindFirstChild("Border")
		if border and border:IsA("UIStroke") then border.Thickness = 2 / scale end
		local depth = panel:FindFirstChild("Depth")
		local goldLine = depth and depth:FindFirstChild("GoldLine")
		if goldLine then
			goldLine.Stroke.Thickness = 1.5 / scale
			goldLine.Corner.CornerRadius = UDim.new(0, (radius - 3) / scale)
		end
		local hex = depth and depth:FindFirstChild("Hex")
		if hex then hex.Corner.CornerRadius = UDim.new(0, (radius - 1) / scale) end
		local auto = hud.autoButton
		local autoCorner = auto:FindFirstChildOfClass("UICorner")
		if autoCorner then autoCorner.CornerRadius = UDim.new(0, radius / scale) end
		auto.Size = UDim2.fromOffset(size.X, MachineHud.AutoHeight / scale)
		auto.Position = UDim2.new(1, 0, 1, MachineHud.Gap / scale)
	end
	function placePanel()
		local s = Kit.Scale()
		local rootH = root.AbsoluteSize.Y / math.max(s, 0.01)
		if rootH < 1 then return end
		local right = placed and placed.repRight or corner
		local repBottom = placed and placed.repBottom or corner
		local gap = MachineHud.Gap
		local pumpTop = rootH - (repBottom + MachineHud.RepSize.Y + gap + MachineHud.PumpSize.Y)
		local autoRoom = if hud.autoButton.Visible then MachineHud.AutoHeight + gap else 0
		local scale = MachineHud.RepSize.X / size.X
		local top = pumpTop - gap - autoRoom - panel.Size.Y.Offset * scale
		if top < MachineHud.PanelTop then
			local room = pumpTop - gap - autoRoom - MachineHud.PanelTop
			scale = math.max(0.45, room / math.max(panel.Size.Y.Offset, 1))
			top = pumpTop - gap - autoRoom - panel.Size.Y.Offset * scale
		end
		panelScale.Scale = scale
		keepLook(scale)
		panel.Position = UDim2.new(1, -right, 0, top)
	end
	local function apply()
		if not placed then return end
		rep.Position = UDim2.new(1, -placed.repRight, 1, -placed.repBottom)
		local repCorner = rep:FindFirstChildOfClass("UICorner")
		if repCorner then repCorner.CornerRadius = UDim.new(0, MachineHud.StackCorner) end
		pump.Position = UDim2.new(1, -placed.repRight, 1, -(placed.repBottom + MachineHud.RepSize.Y + MachineHud.Gap))
		hud.exitButton.Position = UDim2.new(0, corner, 1, -placed.stopBottom)
		hud.changeButton.Position = UDim2.new(0, corner, 1, -(placed.stopBottom + 48))
		placePanel()
	end
	-- the first measurement from the real controls (on a PC: the corners) is kept for good
	local lastLogged = nil
	local function placeForInput()
		if placed and placed.final and placed.mode == MachineHud.LayoutMode() then
			apply()
			return
		end
		local result = measure()
		if result then
			placed = result
			apply()
			-- the F9 console line (once per change), so testers can say which layout they got
			local mode, reason = MachineHud.LayoutMode()
			local line = mode .. ", reason = " .. reason .. (if mode == "phone" and not (placed.final) then " (no jump button: fixed spot)" else "")
			if line ~= lastLogged then
				lastLogged = line
				print("[GYM ARC] HUD layout = " .. line)
			end
		end
	end
	hud.placeForInput = placeForInput
	-- (owner, 23 Oct) while the controls show, the card checks its spot every frame (AUTO TRAIN, the needs line and the
	-- controls settle a moment after you sit down; unchanged values cost nothing)
	game:GetService("RunService").Heartbeat:Connect(function()
		if gui.Enabled then placePanel() end
	end)
	local function screenChanged()
		placed = nil -- (a new screen size: work it out again)
		task.defer(placeForInput)
	end
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(screenChanged) end
	Kit.OnScale(screenChanged)
	-- the input changed (a phone player plugs in a keyboard or a controller, or back): lay out again when the mode changes
	local function inputChanged()
		if placed and placed.mode ~= MachineHud.LayoutMode() then screenChanged() end
	end
	pcall(function() UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(inputChanged) end)
	UserInputService.LastInputTypeChanged:Connect(inputChanged)
	if IS_STUDIO then
		for _, name in ipairs({ "TestInput", "TestNoJump", "TestPhoneSize" }) do
			workspace:GetAttributeChangedSignal(name):Connect(function()
				placed = nil
				screenChanged()
			end)
		end
	end
	task.spawn(function() -- (until Roblox has made its touch controls; checks once a second, never while a spot is final)
		while true do
			if not (placed and placed.final) then placeForInput() end
			task.wait(1)
		end
	end)

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

	-- every tap: REP pops a little (the pulse part of its one UIScale, Theme.ButtonScale)
	function hud.tapPop()
		local pop = Theme.ButtonScale(rep).pulse
		pop.Value = 1.06
		Theme.Tween(pop, { Value = 1 }, 0.14)
	end

	-- the weight card slides in from the right (the bottom widgets come up with `stack`)
	function hud.show(on: boolean)
		if on then
			placeForInput()
			placePanel()
		end
		Theme.Tween(panelSlot, { Position = on and UDim2.new() or MachineHud.PanelHidden })
	end

	return hud
end

return MachineHud
