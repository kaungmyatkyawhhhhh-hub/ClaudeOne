--[[
	UI (client) - dark themed interface
	  * loading screen, fades, cinematic letterbox, title card
	  * main menu
	  * garage with live 3D car preview, class tabs, stats and buy/drive
	  * HUD: level + XP bar, analog rev-counter speedometer with gear, cash tab,
	    settings / shop / gifts buttons, daily gift card, controls tab, combo
	    meter, cut-up popups, level-up banner
	  * touch controls for mobile
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local CarSkin = require(script.Parent:WaitForChild("CarSkin"))
local Audio = require(script.Parent:WaitForChild("Audio"))

local Theme = Config.Theme
local player = Players.LocalPlayer

local UI = {}
UI.touch = { throttle = 0, brake = 0, steer = 0, handbrake = false }
UI.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Callbacks assigned by Main
UI.onGarageButton = nil :: (() -> ())?
UI.onCameraButton = nil :: (() -> ())?
UI.onDailyClaim = nil :: (() -> ())? -- asks the server to pay the daily gift

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(r: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.Text,
		TextSize = 16,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base)
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function formatCash(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end
UI.formatCash = formatCash

local function button(text: string, color: Color3, props: { [string]: any }?): TextButton
	local base = {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelLight,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 18,
	}
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	local b: TextButton = new("TextButton", base, { corner(8), stroke(color, 1.5, 0.2) })
	b.Activated:Connect(Audio.click)
	b.MouseEnter:Connect(function()
		tween(b, 0.12, { BackgroundColor3 = color:Lerp(Theme.PanelLight, 0.55) })
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.12, { BackgroundColor3 = Theme.PanelLight })
	end)
	return b
end

---------------------------------------------------------------------
-- Root
---------------------------------------------------------------------
local gui: ScreenGui
local hud: Frame
local overlay: Frame
local cashLabel: TextLabel
local speedLabel: TextLabel
local gearLabel: TextLabel
local gearTag: TextLabel
local needleHolder: Frame
local rpmTrack: { Frame } = {}
local comboFrame: Frame
local comboLabel: TextLabel
local comboBar: Frame
local popupHolder: Frame
local toast: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel
local xpGain: TextLabel
local camToggle: TextButton
local musicToggle: TextButton
local settingsPanel: Frame
local dailyPanel: Frame
local controlsPanel: Frame? = nil
local controlsArrow: TextLabel? = nil
local giftDot: Frame
local dailyCardTime: TextLabel
local dailyCardSub: TextLabel
local dailyCardStroke: UIStroke
local dailyPanelAmount: TextLabel
local dailyClaimBtn: TextButton
local displayedCash = 0
local targetCash = 0

local WHITE = Color3.new(1, 1, 1)
local RPM_MAX = 7 -- the gauge reads 0..7 (x1000 rpm)
local REDLINE = 6

local progress = { level = 1, xp = 0, need = Config.xpForLevel(1) }
local daily = { known = false, readyAt = 0, claiming = false, shown = -1 }

-- 0..RPM_MAX -> gauge angle in degrees (maths convention, 0 = right, CCW);
-- the dial sweeps 270 degrees clockwise from bottom-left to bottom-right
local function rpmAngle(v: number): number
	return 225 - (v / RPM_MAX) * 270
end

-- position on a circle around the centre of the parent
local function polar(r: number, deg: number): UDim2
	local a = math.rad(deg)
	return UDim2.new(0.5, math.cos(a) * r, 0.5, -math.sin(a) * r)
end

local function formatClock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%02d:%02d", m, s % 60)
end

local function musicOn(): boolean
	local m = game:GetService("SoundService"):FindFirstChild("Music")
	return not (m and m:IsA("Sound") and m.Volume <= 0)
end

---------------------------------------------------------------------
-- Flash / toast
---------------------------------------------------------------------
local flashFrame: Frame? = nil
function UI.flash(color: Color3)
	if not flashFrame then
		flashFrame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 15, Parent = gui })
	end
	local f = flashFrame :: Frame
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0.6
	tween(f, 0.5, { BackgroundTransparency = 1 })
end

local toastToken = 0
function UI.toast(text: string, color: Color3?)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.TextColor3 = color or Theme.Text
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.1
	task.delay(2.2, function()
		if my == toastToken then
			tween(toast, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
		end
	end)
end

---------------------------------------------------------------------
-- Touch controls
---------------------------------------------------------------------
function UI.buildTouchControls()
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = hud })
	local function touchButton(text: string, pos: UDim2, size: UDim2, color: Color3, onDown: () -> (), onUp: () -> ())
		local b: TextButton = new("TextButton", {
			AutoButtonColor = false,
			Text = text,
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.25,
			Position = pos,
			Size = size,
			Parent = holder,
		}, { corner(14), stroke(color, 2, 0.2) })
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				b.BackgroundTransparency = 0
				onDown()
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				b.BackgroundTransparency = 0.25
				onUp()
			end
		end)
	end
	local left, right = false, false
	local function updSteer()
		UI.touch.steer = (if right then 1 else 0) - (if left then 1 else 0)
	end
	touchButton("◀", UDim2.new(0, 24, 1, -130), UDim2.fromOffset(90, 90), Theme.Accent, function()
		left = true
		updSteer()
	end, function()
		left = false
		updSteer()
	end)
	touchButton("▶", UDim2.new(0, 124, 1, -130), UDim2.fromOffset(90, 90), Theme.Accent, function()
		right = true
		updSteer()
	end, function()
		right = false
		updSteer()
	end)
	touchButton("GAS", UDim2.new(1, -114, 1, -160), UDim2.fromOffset(90, 120), Theme.Money, function()
		UI.touch.throttle = 1
	end, function()
		UI.touch.throttle = 0
	end)
	touchButton("BRAKE", UDim2.new(1, -214, 1, -130), UDim2.fromOffset(90, 90), Theme.Danger, function()
		UI.touch.brake = 1
	end, function()
		UI.touch.brake = 0
	end)
	touchButton("DRIFT", UDim2.new(1, -214, 1, -230), UDim2.fromOffset(90, 80), Theme.Accent2, function()
		UI.touch.handbrake = true
	end, function()
		UI.touch.handbrake = false
	end)
end

---------------------------------------------------------------------
-- Icons: drawn from plain frames (no image assets) on a 32x32 grid
---------------------------------------------------------------------
local function icon(kind: string, parent: Instance, size: number, color: Color3?): Frame
	local k = size / 32
	local col = color or WHITE
	local canvas = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local function box(x: number, y: number, w: number, h: number, radius: number?, rotation: number?): Frame
		local f = new("Frame", {
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x + w / 2) * k, (y + h / 2) * k),
			Size = UDim2.fromOffset(w * k, h * k),
			Rotation = rotation or 0,
			Parent = canvas,
		})
		if radius then
			new("UICorner", { CornerRadius = if radius < 0 then UDim.new(1, 0) else UDim.new(0, radius * k), Parent = f })
		end
		return f
	end
	if kind == "gear" then
		-- eight teeth around a thick ring
		for t = 0, 7 do
			local a = math.rad(t * 45)
			box(16 + math.cos(a) * 11.5 - 3.5, 16 + math.sin(a) * 11.5 - 3.5, 7, 7, 1.5, t * 45 + 90)
		end
		local ring = box(10, 10, 12, 12, -1)
		ring.BackgroundTransparency = 1
		new("UIStroke", { Color = col, Thickness = math.max(2, 5 * k), Parent = ring })
	elseif kind == "cart" then
		box(2, 5, 7, 3, 1.5) -- handle
		box(7.5, 5, 3, 17, 1.5) -- frame post
		box(9, 9, 20, 10, 2) -- basket
		box(9, 20, 17, 3, 1.5) -- bottom rail
		box(10, 24.5, 5.5, 5.5, -1) -- wheels
		box(21, 24.5, 5.5, 5.5, -1)
	elseif kind == "gift" then
		box(4, 11, 11, 6, 1.5) -- lid (split by the ribbon gap)
		box(17, 11, 11, 6, 1.5)
		box(6, 18, 9, 11, 1.5) -- box
		box(17, 18, 9, 11, 1.5)
		box(8.5, 5, 8, 5.5, -1, 30) -- bow loops
		box(15.5, 5, 8, 5.5, -1, -30)
	end
	return canvas
end

---------------------------------------------------------------------
-- HUD pieces
---------------------------------------------------------------------
local function buildSpeedometer()
	local size = if UI.isTouch then 180 else 240
	local half = size / 2
	local gauge = new("Frame", {
		Name = "Speedometer",
		AnchorPoint = if UI.isTouch then Vector2.new(0.5, 1) else Vector2.new(1, 1),
		-- on touch it sits bottom-centre between the pedals and the steering
		-- buttons, lifted above the cash tab
		Position = if UI.isTouch then UDim2.new(0.5, 0, 1, -48) else UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.22,
		Parent = hud,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Theme.Stroke, 2, 0.15) })
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0) }),
		Parent = gauge,
	})

	-- rpm track: thin arc that lights up to the current rpm, red in the redline
	local segCount = 63
	local rTrack = half - 9
	local step = 270 / segCount
	local segLen = rTrack * math.rad(step) + 1.2
	for i = 1, segCount do
		local mid = (i - 0.5) / segCount * RPM_MAX
		local a = rpmAngle(mid)
		local seg = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = polar(rTrack, a),
			Size = UDim2.fromOffset(segLen, if UI.isTouch then 3 else 4),
			Rotation = 90 - a,
			BackgroundColor3 = if mid >= REDLINE then Theme.Danger else Theme.Stroke,
			BackgroundTransparency = if mid >= REDLINE then 0.45 else 0.1,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = gauge,
		})
		table.insert(rpmTrack, seg)
	end

	-- ticks every 500 rpm, numbers every 1000
	local rTick = half - 15
	local major = size * 0.06
	local minor = size * 0.03
	for t = 0, RPM_MAX * 2 do
		local v = t / 2
		local isMajor = t % 2 == 0
		local len = if isMajor then major else minor
		local a = rpmAngle(v)
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = polar(rTick - len / 2, a),
			Size = UDim2.fromOffset(if isMajor then 3 else 2, len),
			Rotation = 90 - a,
			BackgroundColor3 = if v >= REDLINE then Theme.Danger else Theme.Text,
			BackgroundTransparency = if isMajor then 0 else 0.35,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = gauge,
		})
		if isMajor then
			label({
				Text = tostring(v),
				TextSize = math.floor(size * 0.068),
				Font = Enum.Font.GothamBlack,
				TextColor3 = if v >= REDLINE then Theme.Danger else Theme.Text,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = polar(rTick - major - size * 0.065, a),
				Size = UDim2.fromOffset(24, 18),
				ZIndex = 2,
				Parent = gauge,
			})
		end
	end
	label({
		Text = "x1000rpm",
		TextSize = math.max(8, math.floor(size * 0.037)),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.SubText,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.285),
		Size = UDim2.new(0.4, 0, 0, 12),
		ZIndex = 2,
		Parent = gauge,
	})

	-- centre ring with the gear
	local ringSize = size * 0.34
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ringSize, ringSize),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.35,
		ZIndex = 2,
		Parent = gauge,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Theme.Stroke, 1.5, 0.2) })
	local gearRow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ringSize, ringSize * 0.6),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gauge,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	gearLabel = label({
		Text = "N",
		TextSize = math.floor(size * 0.19),
		Font = Enum.Font.GothamBlack,
		TextColor3 = Theme.Accent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = gearRow,
	})
	gearTag = label({
		Text = "AT",
		TextSize = math.max(9, math.floor(size * 0.05)),
		Font = Enum.Font.GothamBlack,
		TextColor3 = Theme.SubText,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Size = UDim2.new(0, size * 0.08, 0.62, 0),
		LayoutOrder = 2,
		Visible = false,
		ZIndex = 3,
		Parent = gearRow,
	})

	-- speed readout under the ring
	speedLabel = label({
		Text = "0",
		TextSize = math.floor(size * 0.145),
		Font = Enum.Font.GothamBlack,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.785),
		Size = UDim2.new(0.5, 0, 0, size * 0.15),
		ZIndex = 3,
		Parent = gauge,
	})
	label({
		Text = "mph",
		TextSize = math.max(10, math.floor(size * 0.05)),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.SubText,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.885),
		Size = UDim2.new(0.4, 0, 0, 14),
		ZIndex = 3,
		Parent = gauge,
	})

	-- needle: a square the size of the gauge, rotated about its centre; the
	-- red bar starts outside the centre ring so the gear stays readable
	needleHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Rotation = 90 - rpmAngle(0),
		ZIndex = 4,
		Parent = gauge,
	})
	local rIn = ringSize / 2 + 4
	local rOut = half - 12
	local width = if UI.isTouch then 3 else 4
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -rIn),
		Size = UDim2.fromOffset(width + 6, rOut - rIn),
		BackgroundColor3 = Theme.Danger,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = needleHolder,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local needle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -rIn),
		Size = UDim2.fromOffset(width, rOut - rIn),
		BackgroundColor3 = Theme.Danger,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = needleHolder,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 170), WHITE),
		Parent = needle,
	})
end

local function buildLevelBar()
	local barWidth = if UI.isTouch then 240 else 380
	local top = new("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(barWidth, 66),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	levelLabel = label({
		Text = "Level 1",
		TextSize = if UI.isTouch then 28 else 36,
		Font = Enum.Font.GothamBlack,
		TextColor3 = WHITE, -- coloured by the gradient below
		Size = UDim2.new(1, 0, 0, 40),
		Parent = top,
	})
	new("UIStroke", { Color = Color3.fromRGB(20, 4, 12), Thickness = 2.5, Transparency = 0.1, Parent = levelLabel })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 120, 170), Theme.Accent2),
		Parent = levelLabel,
	})
	local back = new("Frame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.25,
		ClipsDescendants = true,
		Parent = top,
	}, { corner(8), stroke(Theme.Stroke, 1.5, 0.1) })
	xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = back }, { corner(8) })
	new("UIGradient", { Color = ColorSequence.new(Theme.Accent2, Color3.fromRGB(255, 92, 92)), Parent = xpFill })
	xpText = label({
		Text = "0 / 40 XP",
		TextSize = 12,
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = back,
	})
	xpGain = label({
		Text = "",
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Position = UDim2.new(1, 10, 0, 44),
		Size = UDim2.fromOffset(90, 16),
		Parent = top,
	})
end

local function buildCashTab()
	local width = if UI.isTouch then 190 else 240
	local height = if UI.isTouch then 38 else 46
	-- the pill extends below the screen edge so only its top corners round
	local tab = new("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 14),
		Size = UDim2.fromOffset(width, height + 14),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.12,
		Parent = hud,
	}, { corner(14), stroke(Theme.Stroke, 1.5, 0.15) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 2), BackgroundColor3 = Theme.Money, BorderSizePixel = 0, Parent = tab }, { corner(1) })
	cashLabel = label({
		Text = "$0",
		TextSize = if UI.isTouch then 24 else 30,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Theme.Money,
		Size = UDim2.new(1, -16, 0, height),
		Position = UDim2.fromOffset(8, 0),
		Parent = tab,
	})
	new("UIStroke", { Color = Color3.fromRGB(0, 30, 14), Thickness = 1.5, Transparency = 0.3, Parent = cashLabel })

	-- controls hint tab next to the cash (keyboard players only)
	if UI.isTouch then
		return
	end
	local ctab: TextButton = new("TextButton", {
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, width / 2 + 8, 1, 14),
		Size = UDim2.fromOffset(124, 30 + 14),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.12,
		Parent = hud,
	}, { corner(10), stroke(Theme.Stroke, 1.5, 0.15) })
	label({
		Text = "CONTROLS",
		TextSize = 12,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 0, 30),
		Parent = ctab,
	})
	controlsArrow = label({
		Text = "▲",
		TextSize = 10,
		TextColor3 = Theme.SubText,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.fromOffset(14, 30),
		Parent = ctab,
	})

	local rows = {
		{ "W / S", "Throttle  ·  brake / reverse" },
		{ "A / D", "Steer" },
		{ "SPACE", "Handbrake (drift)" },
		{ "C", "Camera  (hold RMB to look)" },
		{ "R", "Reset car to road" },
		{ "G", "Garage / shop" },
		{ "M", "Music on / off" },
	}
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -56),
		Size = UDim2.fromOffset(340, 44 + #rows * 28),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 5,
		Parent = hud,
	}, {
		corner(12),
		stroke(Theme.Stroke, 1.5, 0.1),
		new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Text = "CONTROLS", TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, ZIndex = 5, Parent = panel })
	for i, row in rows do
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, ZIndex = 5, Parent = panel })
		local chip = new("Frame", { Size = UDim2.fromOffset(70, 22), BackgroundColor3 = Theme.PanelLight, ZIndex = 5, Parent = r }, { corner(6), stroke(Theme.Stroke, 1, 0.2) })
		label({ Text = row[1], TextSize = 12, Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = chip })
		label({ Text = row[2], TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(84, 0), Size = UDim2.new(1, -84, 1, 0), ZIndex = 5, Parent = r })
	end
	controlsPanel = panel

	ctab.Activated:Connect(function()
		Audio.click()
		UI.toggleControls()
	end)
	ctab.MouseEnter:Connect(function()
		tween(ctab, 0.12, { BackgroundColor3 = Theme.PanelLight })
	end)
	ctab.MouseLeave:Connect(function()
		tween(ctab, 0.12, { BackgroundColor3 = Theme.Panel })
	end)
end

-- small dark panel with a title and a close button, used by settings + gift
local function sidePanel(title: string, height: number, anchorY: number): Frame
	local p = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, if UI.isTouch then 76 else 96, anchorY, 0),
		Size = UDim2.fromOffset(270, height),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.06,
		Visible = false,
		ZIndex = 5,
		Parent = hud,
	}, { corner(12), stroke(Theme.Stroke, 1.5, 0.1) })
	label({ Text = title, TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -60, 0, 22), ZIndex = 5, Parent = p })
	local close = button("✕", Theme.Danger, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(28, 28), TextSize = 13, ZIndex = 6, Parent = p })
	close.Activated:Connect(function()
		p.Visible = false
	end)
	return p
end

local function closePanels()
	settingsPanel.Visible = false
	dailyPanel.Visible = false
end

local function togglePanel(p: Frame)
	local show = not p.Visible
	closePanels()
	p.Visible = show
	if show then
		local final = p.Position
		p.Position = final - UDim2.fromOffset(14, 0)
		tween(p, 0.2, { Position = final }, Enum.EasingStyle.Quint)
	end
end

local function dailyLeft(): number
	return if daily.known then daily.readyAt - os.clock() else math.huge
end

local claimDaily: () -> ()

local function buildSideButtons()
	local size = if UI.isTouch then 48 else 64
	local column = new("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		-- on touch, lift it clear of the steering buttons
		Position = if UI.isTouch then UDim2.new(0, 14, 0.4, 0) else UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(size, size * 3 + 20),
		BackgroundTransparency = 1,
		Parent = hud,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function sideButton(kind: string, caption: string, order: number): TextButton
		local b: TextButton = new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = order,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.12,
			Parent = column,
		}, { corner(if UI.isTouch then 10 else 14) })
		local st = stroke(Theme.Stroke, 1.5, 0.1)
		st.Parent = b
		local iconArea = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, if UI.isTouch then 0 else -12), Parent = b })
		icon(kind, iconArea, size * (if UI.isTouch then 0.55 else 0.48))
		if not UI.isTouch then
			label({ Text = caption, TextSize = 9, Font = Enum.Font.GothamBlack, TextColor3 = Theme.SubText, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, 0, 0, 10), Parent = b })
		end
		b.Activated:Connect(Audio.click)
		b.MouseEnter:Connect(function()
			tween(b, 0.12, { BackgroundColor3 = Theme.PanelLight })
			tween(st, 0.12, { Color = Theme.Accent })
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.12, { BackgroundColor3 = Theme.Panel })
			tween(st, 0.12, { Color = Theme.Stroke })
		end)
		return b
	end

	local settingsBtn = sideButton("gear", "SETTINGS", 1)
	local shopBtn = sideButton("cart", "SHOP", 2)
	local giftBtn = sideButton("gift", "GIFTS", 3)
	giftDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Theme.Danger,
		Visible = false,
		ZIndex = 3,
		Parent = giftBtn,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Theme.Background, 2, 0) })

	-- settings: camera + music toggles (same actions as C and M)
	settingsPanel = sidePanel("SETTINGS", 148, if UI.isTouch then 0.4 else 0.5)
	local function settingRow(name: string, key: string, y: number): TextButton
		label({ Text = name, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(110, 32), ZIndex = 5, Parent = settingsPanel })
		if not UI.isTouch then
			label({ Text = "[" .. key .. "]", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(84, y), Size = UDim2.fromOffset(40, 32), ZIndex = 5, Parent = settingsPanel })
		end
		return button("", Theme.Accent, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, y), Size = UDim2.fromOffset(120, 32), TextSize = 13, TextColor3 = Theme.Accent, ZIndex = 6, Parent = settingsPanel })
	end
	camToggle = settingRow("Camera", "C", 52)
	camToggle.Text = "CHASE"
	musicToggle = settingRow("Music", "M", 96)
	local function refreshMusic()
		local on = musicOn()
		musicToggle.Text = if on then "ON" else "OFF"
		musicToggle.TextColor3 = if on then Theme.Accent else Theme.SubText
	end
	refreshMusic()
	camToggle.Activated:Connect(function()
		if UI.onCameraButton then
			UI.onCameraButton()
		end
	end)
	musicToggle.Activated:Connect(function()
		Audio.toggleMusic()
		refreshMusic()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			task.defer(refreshMusic) -- Audio handles the key itself
		end
	end)

	-- daily gift panel
	dailyPanel = sidePanel("DAILY GIFT", 196, if UI.isTouch then 0.4 else 0.5)
	local giftArea = new("Frame", { Position = UDim2.fromOffset(16, 48), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Theme.Warning:Lerp(Theme.Panel, 0.75), ZIndex = 5, Parent = dailyPanel }, { corner(12), stroke(Theme.Warning, 1.5, 0.4) })
	icon("gift", giftArea, 38, Theme.Warning)
	dailyPanelAmount = label({ Text = "$0", TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Money, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(94, 52), Size = UDim2.new(1, -104, 0, 30), ZIndex = 5, Parent = dailyPanel })
	label({ Text = "Free cash every 24 hours.\nGrows with your level.", TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(94, 84), Size = UDim2.new(1, -104, 0, 30), ZIndex = 5, Parent = dailyPanel })
	dailyClaimBtn = button("CLAIM", Theme.Money, { Position = UDim2.new(0, 16, 1, -62), Size = UDim2.new(1, -32, 0, 46), TextSize = 18, ZIndex = 6, Parent = dailyPanel })
	dailyClaimBtn.Activated:Connect(function()
		claimDaily()
	end)

	settingsBtn.Activated:Connect(function()
		togglePanel(settingsPanel)
	end)
	shopBtn.Activated:Connect(function()
		closePanels()
		if UI.onGarageButton then
			UI.onGarageButton()
		end
	end)
	giftBtn.Activated:Connect(function()
		togglePanel(dailyPanel)
	end)
end

-- "DAILY GIFT" offer card on the right with the countdown to the next gift
local function buildDailyCard()
	local w = if UI.isTouch then 176 else 212
	local h = if UI.isTouch then 70 else 84
	local card: TextButton = new("TextButton", {
		Name = "DailyCard",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = if UI.isTouch then Vector2.new(1, 0) else Vector2.new(1, 0.5),
		-- on touch, top-right so it stays clear of the pedals
		Position = if UI.isTouch then UDim2.new(1, -14, 0, 70) else UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.08,
		Parent = hud,
	}, { corner(14) })
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(Theme.Warning:Lerp(Theme.Panel, 0.72), Theme.Panel),
		Parent = card,
	})
	dailyCardStroke = stroke(Theme.Warning, 1.5, 0.35)
	dailyCardStroke.Parent = card
	local iconBox = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(h - 22, h - 22),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.4,
		Parent = card,
	}, { corner(10) })
	icon("gift", iconBox, (h - 22) * 0.62, Theme.Warning)
	local textX = h - 2
	label({ Text = "DAILY GIFT", TextSize = if UI.isTouch then 11 else 13, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Warning, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, textX, 0, 8), Size = UDim2.new(1, -textX - 8, 0, 16), Parent = card })
	dailyCardTime = label({ Text = "--:--", TextSize = if UI.isTouch then 22 else 28, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, textX, 0.5, -14), Size = UDim2.new(1, -textX - 8, 0, 30), Parent = card })
	dailyCardSub = label({ Text = "", TextSize = if UI.isTouch then 10 else 12, Font = Enum.Font.GothamBold, TextColor3 = Theme.Money, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, textX, 1, -22), Size = UDim2.new(1, -textX - 8, 0, 16), Parent = card })
	card.Activated:Connect(function()
		Audio.click()
		claimDaily()
	end)
	card.MouseEnter:Connect(function()
		tween(card, 0.12, { BackgroundColor3 = Theme.PanelLight })
	end)
	card.MouseLeave:Connect(function()
		tween(card, 0.12, { BackgroundColor3 = Theme.Panel })
	end)
end

-- keeps every daily-gift widget in step with the countdown (cheap: only
-- touches text when the shown second changes)
local function refreshDaily(force: boolean?)
	local left = dailyLeft()
	local ready = daily.known and left <= 0
	local shown = if ready then 0 elseif daily.known then math.ceil(left) else -2
	if not force and shown == daily.shown then
		return
	end
	daily.shown = shown
	local amount = formatCash(Config.dailyReward(progress.level))
	dailyPanelAmount.Text = amount
	giftDot.Visible = ready
	if ready then
		dailyCardTime.Text = "READY!"
		dailyCardTime.TextColor3 = Theme.Money
		dailyCardSub.Text = "CLAIM  +" .. amount
		dailyClaimBtn.Text = if daily.claiming then "..." else "CLAIM"
		dailyClaimBtn.TextColor3 = Theme.Money
	else
		dailyCardTime.Text = if daily.known then formatClock(left) else "--:--"
		dailyCardTime.TextColor3 = Theme.Text
		dailyCardSub.Text = "+" .. amount .. " cash"
		dailyClaimBtn.Text = if daily.known then "READY IN " .. formatClock(left) else "..."
		dailyClaimBtn.TextColor3 = Theme.SubText
	end
end

claimDaily = function()
	if daily.claiming then
		return
	end
	local left = dailyLeft()
	if not daily.known or left > 0 then
		UI.toast(if daily.known then "Next daily gift in " .. formatClock(left) else "Daily gift not available yet", Theme.SubText)
		return
	end
	local cb = UI.onDailyClaim
	if not cb then
		return
	end
	daily.claiming = true
	refreshDaily(true)
	task.spawn(function()
		local ok, err = pcall(cb)
		if not ok then
			warn("[CityLegends] daily claim failed:", err)
		end
		daily.claiming = false
		refreshDaily(true)
	end)
end

function UI.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = new("ScreenGui", {
		Name = "CityLegendsUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = pg,
	})

	-- HUD ------------------------------------------------------------
	hud = new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui })

	buildLevelBar()
	buildSpeedometer()
	buildCashTab()
	buildSideButtons()
	buildDailyCard()

	-- combo (under the level bar)
	comboFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(260, 66),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = hud,
	}, { corner(10), stroke(Theme.Accent2, 1.5, 0.1) })
	comboLabel = label({ Text = "x1 COMBO", TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Accent2, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), Parent = comboFrame })
	local comboBack = new("Frame", { Position = UDim2.new(0, 16, 1, -14), Size = UDim2.new(1, -32, 0, 5), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = comboFrame }, { corner(3) })
	comboBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Accent2, BorderSizePixel = 0, Parent = comboBack }, { corner(3) })

	popupHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(500, 200), Parent = hud })

	toast = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 162),
		Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		TextSize = 16,
		TextTransparency = 1,
		Visible = false,
		ZIndex = 75, -- readable over the garage too
		Parent = gui,
	})
	corner(8).Parent = toast

	-- Overlay (fades, letterbox, title) --------------------------------
	overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui })

	if UI.isTouch then
		UI.buildTouchControls()
	end

	refreshDaily(true)
	local dailyTick = 0
	RunService.RenderStepped:Connect(function(dt)
		if displayedCash ~= targetCash then
			local diff = targetCash - displayedCash
			local step = math.max(1, math.abs(diff) * math.min(1, dt * 8))
			if math.abs(diff) <= step then
				displayedCash = targetCash
			else
				displayedCash += math.sign(diff) * step
			end
			cashLabel.Text = formatCash(displayedCash)
		end
		dailyTick += dt
		if dailyTick >= 0.2 then
			dailyTick = 0
			refreshDaily()
		end
		if hud.Visible then
			-- breathe the card outline while a gift is waiting
			dailyCardStroke.Transparency = if daily.shown == 0 then 0.25 + 0.25 * math.sin(os.clock() * 4) else 0.35
		end
	end)
end

---------------------------------------------------------------------
-- Loading / fades / cinematic
---------------------------------------------------------------------
local loadingFrame: Frame? = nil
function UI.showLoading(text: string)
	if loadingFrame then
		(loadingFrame:FindFirstChild("Status") :: TextLabel).Text = text
		return
	end
	local f = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = gui })
	label({ Text = "CITY LEGENDS", TextSize = 46, Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(600, 60), ZIndex = 101, Parent = f })
	label({ Name = "Status", Text = text, TextSize = 14, TextColor3 = Theme.SubText, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(600, 20), ZIndex = 101, Parent = f })
	local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(220, 3), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, ZIndex = 101, Parent = f })
	local fill = new("Frame", { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 102, Parent = bar })
	task.spawn(function()
		while fill.Parent do
			fill.Position = UDim2.fromScale(-0.3, 0)
			tween(fill, 0.9, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1)
		end
	end)
	loadingFrame = f
end

function UI.hideLoading()
	if loadingFrame then
		loadingFrame:Destroy()
		loadingFrame = nil
	end
end

local fadeFrame: Frame? = nil
function UI.fade(toBlack: boolean, duration: number)
	if not fadeFrame then
		fadeFrame = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 90, Parent = gui })
	end
	local f = fadeFrame :: Frame
	local t = tween(f, duration, { BackgroundTransparency = if toBlack then 0 else 1 }, Enum.EasingStyle.Sine)
	t.Completed:Wait()
end

local barTop: Frame? = nil
local barBottom: Frame? = nil
function UI.letterbox(visible: boolean)
	if not barTop then
		barTop = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), ZIndex = 30, Parent = overlay })
		barBottom = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), ZIndex = 30, Parent = overlay })
	end
	local h = if visible then UDim2.fromScale(1, 0.12) else UDim2.fromScale(1, 0)
	tween(barTop :: Frame, 0.6, { Size = h })
	tween(barBottom :: Frame, 0.6, { Size = h })
end

local titleFrame: Frame? = nil
function UI.showTitle(text: string, subtitle: string)
	if titleFrame then
		titleFrame:Destroy()
	end
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = overlay })
	titleFrame = f
	local title = label({
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = 96,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(1, 0.18),
		TextScaled = true,
		ZIndex = 41,
		Parent = f,
	})
	new("UITextSizeConstraint", { MaxTextSize = 120, Parent = title })
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Accent),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Theme.Accent2),
		}),
		Parent = title,
	})
	local glow = new("UIStroke", { Color = Theme.Accent2, Thickness = 3, Transparency = 1, Parent = title })
	local line = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 41, Parent = f })
	local sub = label({
		Text = subtitle,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Theme.SubText,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(1, 0.05),
		ZIndex = 41,
		Parent = f,
	})
	title.Size = UDim2.fromScale(1.6, 0.24)
	tween(title, 1.2, { TextTransparency = 0, Size = UDim2.fromScale(1, 0.18) }, Enum.EasingStyle.Quint)
	tween(glow, 1.6, { Transparency = 0.55 })
	task.delay(0.5, function()
		tween(line, 0.8, { Size = UDim2.new(0.34, 0, 0, 2) }, Enum.EasingStyle.Quint)
		tween(sub, 0.8, { TextTransparency = 0 })
	end)
end

function UI.hideTitle()
	if titleFrame then
		local f = titleFrame
		titleFrame = nil
		for _, d in f:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.5, { TextTransparency = 1 })
			elseif d:IsA("Frame") then
				tween(d, 0.5, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, 0.5, { Transparency = 1 })
			end
		end
		task.delay(0.6, function()
			f:Destroy()
		end)
	end
end

---------------------------------------------------------------------
-- Cinematic extras (used by the intro)
---------------------------------------------------------------------
local vignetteFrame: Frame? = nil
function UI.vignette(visible: boolean)
	if not vignetteFrame then
		local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = overlay })
		-- four soft edges built from gradients (no image assets needed)
		for _, spec in { { 0, UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 }, { 1, UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 }, { 2, UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 }, { 3, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 } } do
			local edge = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = spec[2], Position = spec[3], ZIndex = 25, Parent = f })
			new("UIGradient", {
				Rotation = spec[4],
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
				Parent = edge,
			})
		end
		vignetteFrame = f
	end
	local vf = vignetteFrame :: Frame
	vf.Visible = visible
end

local whiteFrame: Frame? = nil
function UI.whiteFlash(strength: number, duration: number?)
	if not whiteFrame then
		whiteFrame = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 85, Parent = gui })
	end
	local f = whiteFrame :: Frame
	f.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	tween(f, duration or 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
end

local captionFrame: Frame? = nil
-- Lower-left location card that types itself out
function UI.caption(title: string, sub: string)
	UI.hideCaption()
	local f = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 60, 0.86, -10), Size = UDim2.fromOffset(600, 80), ZIndex = 42, Parent = overlay })
	captionFrame = f
	local bar = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.new(0, 3, 0, 0), ZIndex = 42, Parent = f })
	local t1 = label({ Text = title, Font = Enum.Font.GothamBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -16, 0, 34), MaxVisibleGraphemes = 0, ZIndex = 42, Parent = f })
	local t2 = label({ Text = sub, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -16, 0, 20), MaxVisibleGraphemes = 0, ZIndex = 42, Parent = f })
	tween(bar, 0.35, { Size = UDim2.new(0, 3, 0, 64) }, Enum.EasingStyle.Quint)
	task.spawn(function()
		for i = 1, #title do
			if not t1.Parent then
				return
			end
			t1.MaxVisibleGraphemes = i
			task.wait(0.045)
		end
		for i = 1, #sub do
			if not t2.Parent then
				return
			end
			t2.MaxVisibleGraphemes = i
			task.wait(0.022)
		end
	end)
end

function UI.hideCaption()
	if captionFrame then
		local f = captionFrame
		captionFrame = nil
		for _, d in f:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.35, { TextTransparency = 1 })
			elseif d:IsA("Frame") then
				tween(d, 0.35, { BackgroundTransparency = 1 })
			end
		end
		task.delay(0.4, function()
			f:Destroy()
		end)
	end
end

-- Big title: chromatic split layers converge, letters reveal one by one,
-- then a glow pulse and the subtitle slides in.
function UI.cinematicTitle(text: string, subtitle: string)
	if titleFrame then
		titleFrame:Destroy()
	end
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = overlay })
	titleFrame = f
	local function layer(color: Color3, z: number, offset: number): TextLabel
		local l = label({
			Text = text,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = color,
			TextTransparency = if z == 43 then 0 else 0.35,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset, 0.46, 0),
			Size = UDim2.fromScale(0.9, 0.17),
			MaxVisibleGraphemes = 0,
			ZIndex = z,
			Parent = f,
		})
		new("UITextSizeConstraint", { MaxTextSize = 130, Parent = l })
		return l
	end
	local cyan = layer(Theme.Accent, 41, -14)
	local pink = layer(Theme.Accent2, 42, 14)
	local main = layer(Color3.new(1, 1, 1), 43, 0)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 250, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 230)),
		}),
		Parent = main,
	})
	local glow = new("UIStroke", { Color = Theme.Accent2, Thickness = 4, Transparency = 1, Parent = main })
	local line = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.565), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 41, Parent = f })
	new("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = line })
	local sub = label({ Text = subtitle, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(200, 204, 220), TextTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(1, 0.05), ZIndex = 41, Parent = f })

	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n do
			if not f.Parent then
				return
			end
			cyan.MaxVisibleGraphemes = i
			pink.MaxVisibleGraphemes = i
			main.MaxVisibleGraphemes = i
			task.wait(0.055)
		end
		-- converge the colour split into the white title
		tween(cyan, 0.7, { Position = UDim2.fromScale(0.5, 0.46), TextTransparency = 0.75 }, Enum.EasingStyle.Quint)
		tween(pink, 0.7, { Position = UDim2.fromScale(0.5, 0.46), TextTransparency = 0.75 }, Enum.EasingStyle.Quint)
		tween(glow, 0.25, { Transparency = 0.2 })
		task.wait(0.25)
		tween(glow, 1.2, { Transparency = 0.65 })
		tween(line, 0.9, { Size = UDim2.new(0.36, 0, 0, 2) }, Enum.EasingStyle.Quint)
		sub.Position = UDim2.fromScale(0.5, 0.65)
		tween(sub, 0.9, { TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Quint)
	end)
end

local skipBtn: TextButton? = nil
function UI.showSkip(onSkip: () -> ())
	local b = button("SKIP  ▸", Theme.Accent, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(120, 38),
		TextSize = 15,
		ZIndex = 45,
		BackgroundTransparency = 0.2,
		Parent = overlay,
	})
	b.Activated:Connect(onSkip)
	skipBtn = b
end

function UI.hideSkip()
	if skipBtn then
		skipBtn:Destroy()
		skipBtn = nil
	end
end

---------------------------------------------------------------------
-- Main menu
---------------------------------------------------------------------
local menuFrame: Frame? = nil
function UI.showMainMenu(cash: number, onPlay: () -> ())
	UI.hideMainMenu()
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = gui })
	menuFrame = f
	local shade = new("Frame", { BackgroundColor3 = Theme.Background, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 5, Parent = f })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 0,
		Parent = shade,
	})
	local panel = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 70, 0.5, -170), Size = UDim2.fromOffset(520, 360), ZIndex = 6, Parent = f })
	label({ Text = "NIGHT  ·  CITY  ·  TRAFFIC", TextColor3 = Theme.Accent, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), ZIndex = 6, Parent = panel })
	local title = label({ Text = "CITY\nLEGENDS", TextSize = 84, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 170), LineHeight = 0.9, ZIndex = 6, Parent = panel })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Accent2), Rotation = 90, Parent = title })
	label({ Text = "Cut up through traffic. Get paid. Become a legend.", TextColor3 = Theme.SubText, TextSize = 16, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 22), ZIndex = 6, Parent = panel })
	local play = button("PLAY", Theme.Accent, { Position = UDim2.fromOffset(0, 246), Size = UDim2.fromOffset(240, 54), TextSize = 22, ZIndex = 6, Parent = panel })
	play.BackgroundColor3 = Theme.Accent:Lerp(Theme.PanelLight, 0.7)
	label({ Text = "LEVEL " .. progress.level .. "   ·   CASH  " .. formatCash(cash), TextColor3 = Theme.Money, TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 314), Size = UDim2.new(1, 0, 0, 22), ZIndex = 6, Parent = panel })
	play.Activated:Connect(function()
		onPlay()
	end)
	panel.Position = UDim2.new(0, 40, 0.5, -170)
	for _, d in panel:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local tt = d.TextTransparency
			d.TextTransparency = 1
			tween(d, 0.8, { TextTransparency = tt })
		end
	end
	tween(panel, 0.8, { Position = UDim2.new(0, 70, 0.5, -170) }, Enum.EasingStyle.Quint)
end

function UI.hideMainMenu()
	if menuFrame then
		menuFrame:Destroy()
		menuFrame = nil
	end
end

---------------------------------------------------------------------
-- Garage
---------------------------------------------------------------------
export type GarageData = { Cash: number, Owned: { string }, Selected: string }
export type GarageCallbacks = {
	buy: (string) -> { ok: boolean, message: string, data: GarageData? },
	drive: (string) -> (),
	close: (() -> ())?,
}

local garageFrame: Frame? = nil
local previewConn: RBXScriptConnection? = nil

function UI.isGarageOpen(): boolean
	return garageFrame ~= nil
end

function UI.closeGarage()
	if previewConn then
		previewConn:Disconnect()
		previewConn = nil
	end
	if garageFrame then
		garageFrame:Destroy()
		garageFrame = nil
	end
end

function UI.openGarage(data: GarageData, callbacks: GarageCallbacks)
	UI.closeGarage()
	local owned: { [string]: boolean } = {}
	for _, id in data.Owned do
		owned[id] = true
	end
	local cash = data.Cash
	local selectedId = data.Selected
	local classFilter = "ALL"

	local f = new("Frame", { BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.08, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = gui })
	garageFrame = f

	-- header
	local header = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 40), Size = UDim2.new(1, -80, 0, 50), ZIndex = 61, Parent = f })
	label({ Text = "GARAGE", TextSize = 38, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 61, Parent = header })
	local cashText = label({ Text = formatCash(cash), TextColor3 = Theme.Money, TextSize = 26, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), ZIndex = 61, Parent = header })
	if callbacks.close then
		local close = button("✕", Theme.Danger, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(42, 42), TextSize = 18, ZIndex = 61, Parent = header })
		close.Activated:Connect(function()
			UI.closeGarage();
			(callbacks.close :: () -> ())()
		end)
	end

	-- tabs
	local tabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 104), Size = UDim2.new(0.36, 0, 0, 32), ZIndex = 61, Parent = f }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})

	-- list
	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(40, 146),
		Size = UDim2.new(0.36, 0, 1, -186),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 61,
		Parent = f,
	}, {
		corner(10),
		stroke(Theme.Stroke, 1, 0.2),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12) }),
	})

	-- detail panel
	local detail = new("Frame", { Position = UDim2.new(0.36, 64, 0, 104), Size = UDim2.new(0.64, -104, 1, -144), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.1, ZIndex = 61, Parent = f }, { corner(12), stroke(Theme.Stroke, 1, 0.2) })
	local viewport = new("ViewportFrame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0.56, 0),
		BackgroundColor3 = Color3.fromRGB(14, 15, 22),
		Ambient = Color3.fromRGB(120, 120, 150),
		LightColor = Color3.fromRGB(255, 245, 235),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		ZIndex = 62,
		Parent = detail,
	}, { corner(10) })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 70, 110), Color3.fromRGB(30, 30, 40)), Rotation = 90, Parent = viewport })
	local vpCam = new("Camera", { FieldOfView = 34, Parent = viewport })
	viewport.CurrentCamera = vpCam

	local nameText = label({ Text = "", TextSize = 34, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 24, 0.56, 22), Size = UDim2.new(0.6, 0, 0, 38), ZIndex = 62, Parent = detail })
	local classText = label({ Text = "", TextSize = 14, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 24, 0.56, 62), Size = UDim2.new(0.6, 0, 0, 18), ZIndex = 62, Parent = detail })

	local statsHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0.56, 92), Size = UDim2.new(0.55, 0, 0, 110), ZIndex = 62, Parent = detail }, {
		new("UIListLayout", { Padding = UDim.new(0, 10) }),
	})
	local function statRow(name: string): (TextLabel, Frame)
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), ZIndex = 62, Parent = statsHolder })
		label({ Text = name, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0, 14), ZIndex = 62, Parent = row })
		local value = label({ Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 0, 14), ZIndex = 62, Parent = row })
		local back = new("Frame", { Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, ZIndex = 62, Parent = row }, { corner(3) })
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 63, Parent = back }, { corner(3) })
		new("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = fill })
		return value, fill
	end
	local topVal, topFill = statRow("TOP SPEED")
	local accVal, accFill = statRow("0 - 60 MPH")
	local hanVal, hanFill = statRow("HANDLING")

	local priceText = label({ Text = "", TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Money, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0.56, 24), Size = UDim2.new(0.35, 0, 0, 34), ZIndex = 62, Parent = detail })
	local actionBtn = button("DRIVE", Theme.Accent, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(230, 56), TextSize = 22, ZIndex = 62, Parent = detail })
	local msgText = label({ Text = "", TextSize = 14, TextColor3 = Theme.Danger, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -88), Size = UDim2.new(0.4, 0, 0, 18), ZIndex = 62, Parent = detail })

	local previewModel: Model? = nil
	local spin = 0
	local function setPreview(spec: Cars.CarSpec)
		if previewModel then
			previewModel:Destroy()
		end
		local m = CarBuilder.build(spec, { anchored = true, interior = true })
		CarSkin.apply(m, true)
		m:PivotTo(CFrame.new(0, (m:GetAttribute("Height") :: number) / 2, 0))
		local floor = new("Part", { Anchored = true, Size = Vector3.new(60, 0.2, 60), CFrame = CFrame.new(0, -0.1, 0), Color = Color3.fromRGB(26, 26, 34), Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 })
		floor.Parent = m
		m.Parent = viewport
		previewModel = m
		local len = m:GetAttribute("Length") :: number
		vpCam.CFrame = CFrame.lookAt(Vector3.new(len * 1.15, len * 0.42, len * 1.15), Vector3.new(0, 1.6, 0))
	end
	previewConn = RunService.RenderStepped:Connect(function(dt)
		spin += dt * 0.45
		if previewModel then
			previewModel:PivotTo(CFrame.new(0, (previewModel:GetAttribute("Height") :: number) / 2, 0) * CFrame.Angles(0, spin, 0))
		end
	end)

	local rows: { [string]: TextButton } = {}
	local refreshList: () -> ()

	local function showDetail(id: string)
		selectedId = id
		local spec = Cars.get(id)
		setPreview(spec)
		nameText.Text = spec.Name:upper()
		classText.Text = Cars.ClassLabels[spec.Class]
		topVal.Text = spec.TopSpeed .. " MPH"
		topFill.Size = UDim2.fromScale(spec.TopSpeed / 290, 1)
		accVal.Text = string.format("%.1f s", spec.ZeroToSixty)
		accFill.Size = UDim2.fromScale(math.clamp((9 - spec.ZeroToSixty) / 7, 0.05, 1), 1)
		hanVal.Text = math.floor(spec.Handling * 100) .. " / 100"
		hanFill.Size = UDim2.fromScale(spec.Handling, 1)
		msgText.Text = ""
		if owned[id] then
			priceText.Text = "OWNED"
			priceText.TextColor3 = Theme.Accent
			actionBtn.Text = "DRIVE"
		else
			priceText.Text = if spec.Price == 0 then "FREE" else formatCash(spec.Price)
			priceText.TextColor3 = if cash >= spec.Price then Theme.Money else Theme.Danger
			actionBtn.Text = "BUY"
		end
		for rid, row in rows do
			local st = row:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = if rid == id then Theme.Accent else Theme.Stroke
			end
		end
	end

	actionBtn.Activated:Connect(function()
		local id = selectedId
		if owned[id] then
			UI.closeGarage()
			callbacks.drive(id)
			return
		end
		actionBtn.Text = "..."
		local result = callbacks.buy(id)
		if result.ok and result.data then
			cash = result.data.Cash
			for _, oid in result.data.Owned do
				owned[oid] = true
			end
			cashText.Text = formatCash(cash)
			UI.setCash(cash)
			refreshList()
			showDetail(id)
			UI.toast(result.message, Theme.Money)
		else
			showDetail(id)
			msgText.Text = result.message
		end
	end)

	refreshList = function()
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(rows)
		local sorted = table.clone(Cars.List)
		table.sort(sorted, function(a, b)
			return a.Order < b.Order
		end)
		for _, spec in sorted do
			if classFilter == "ALL" or spec.Class == classFilter then
				local row: TextButton = new("TextButton", {
					AutoButtonColor = false,
					Text = "",
					Size = UDim2.new(1, 0, 0, 58),
					BackgroundColor3 = Theme.PanelLight,
					LayoutOrder = spec.Order,
					ZIndex = 62,
					Parent = list,
				}, { corner(8), stroke(Theme.Stroke, 1.5, 0) })
				new("Frame", { Size = UDim2.new(0, 4, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = spec.Color, BorderSizePixel = 0, ZIndex = 63, Parent = row }, { corner(2) })
				label({ Text = spec.Name, TextSize = 17, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(22, 9), Size = UDim2.new(0.6, 0, 0, 20), ZIndex = 63, Parent = row })
				label({ Text = Cars.ClassLabels[spec.Class] .. "  ·  " .. spec.TopSpeed .. " MPH", TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(22, 32), Size = UDim2.new(0.6, 0, 0, 16), ZIndex = 63, Parent = row })
				label({
					Text = if owned[spec.Id] then "OWNED" elseif spec.Price == 0 then "FREE" else formatCash(spec.Price),
					TextSize = 15,
					Font = Enum.Font.GothamBlack,
					TextColor3 = if owned[spec.Id] then Theme.Accent elseif cash >= spec.Price then Theme.Money else Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -14, 0.5, 0),
					Size = UDim2.new(0.4, 0, 0, 20),
					ZIndex = 63,
					Parent = row,
				})
				row.Activated:Connect(function()
					Audio.click()
					showDetail(spec.Id)
				end)
				rows[spec.Id] = row
			end
		end
	end

	local tabButtons: { [string]: TextButton } = {}
	local function setTab(name: string)
		classFilter = name
		for n, b in tabButtons do
			b.TextColor3 = if n == name then Theme.Background else Theme.SubText
			b.BackgroundColor3 = if n == name then Theme.Accent else Theme.PanelLight
		end
		refreshList()
		if rows[selectedId] then
			showDetail(selectedId)
		end
	end
	local tabNames = { "ALL" }
	for _, c in Cars.Classes do
		table.insert(tabNames, c)
	end
	for _, n in tabNames do
		local text = if n == "ALL" then "ALL" else Cars.ClassLabels[n]
		local b: TextButton = new("TextButton", {
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			BackgroundColor3 = Theme.PanelLight,
			Font = Enum.Font.GothamBlack,
			Text = text,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			ZIndex = 62,
			Parent = tabs,
		}, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
		b.Activated:Connect(function()
			Audio.click()
			setTab(n)
		end)
		tabButtons[n] = b
	end

	setTab("ALL")
	showDetail(selectedId)
end

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------
function UI.showHud(visible: boolean)
	hud.Visible = visible
	if not visible then
		closePanels()
	end
end

function UI.setCash(amount: number, instant: boolean?)
	targetCash = amount
	if instant then
		displayedCash = amount
		cashLabel.Text = formatCash(amount)
	end
end

local lastLit = -1
local lastSpeedText = ""
local lastGear = ""
-- mph, speed fraction of top speed (unused by the analog dial), gear ("N",
-- "R", "1".."6") and rpm 0..1 (needle sweeps 0..7 x1000)
function UI.setSpeed(mph: number, _frac: number, gear: string, rpm: number)
	local speedText = tostring(math.floor(math.abs(mph) + 0.5))
	if speedText ~= lastSpeedText then
		lastSpeedText = speedText
		speedLabel.Text = speedText
	end
	if gear ~= lastGear then
		lastGear = gear
		local numeric = tonumber(gear) ~= nil
		gearLabel.Text = gear
		gearTag.Visible = numeric
		gearLabel.TextColor3 = if numeric then Theme.Text elseif gear == "R" then Theme.Warning else Theme.Accent
	end
	local v = math.clamp(rpm, 0, 1) * RPM_MAX
	needleHolder.Rotation = 90 - rpmAngle(v)
	local lit = math.floor(v / RPM_MAX * #rpmTrack + 0.5)
	if lit ~= lastLit then
		lastLit = lit
		for i, seg in rpmTrack do
			local segV = (i - 0.5) / #rpmTrack * RPM_MAX
			local red = segV >= REDLINE
			if i <= lit then
				seg.BackgroundColor3 = if red then Theme.Danger else Theme.Accent:Lerp(Theme.Accent2, segV / REDLINE)
				seg.BackgroundTransparency = 0
			else
				seg.BackgroundColor3 = if red then Theme.Danger else Theme.Stroke
				seg.BackgroundTransparency = if red then 0.45 else 0.1
			end
		end
	end
end

function UI.setCameraLabel(mode: string)
	camToggle.Text = if mode == "Interior" then "INTERIOR" else "CHASE"
end

function UI.toggleControls(show: boolean?)
	local panel = controlsPanel
	if not panel then
		return
	end
	local visible = if show == nil then not panel.Visible else show
	panel.Visible = visible
	if controlsArrow then
		controlsArrow.Text = if visible then "▼" else "▲"
	end
end

-- Level + XP bar. `gained` (optional) flashes "+N XP" next to the bar.
local xpToken = 0
function UI.setProgress(level: number, xp: number, need: number, gained: number?)
	local levelChanged = level ~= progress.level
	progress.level = level
	progress.xp = xp
	progress.need = math.max(1, need)
	levelLabel.Text = "Level " .. level
	xpText.Text = string.format("%d / %d XP", math.floor(xp), math.floor(progress.need))
	local frac = math.clamp(xp / progress.need, 0, 1)
	xpToken += 1
	local my = xpToken
	if levelChanged then
		-- fill up, then restart from empty for the new level
		tween(xpFill, 0.25, { Size = UDim2.fromScale(1, 1) })
		task.delay(0.3, function()
			if my == xpToken then
				xpFill.Size = UDim2.fromScale(0, 1)
				tween(xpFill, 0.4, { Size = UDim2.fromScale(frac, 1) })
			end
		end)
		refreshDaily(true) -- the gift grows with level
	else
		tween(xpFill, 0.3, { Size = UDim2.fromScale(frac, 1) })
	end
	if gained and gained > 0 then
		xpGain.Text = "+" .. gained .. " XP"
		xpGain.TextTransparency = 0
		xpGain.TextStrokeTransparency = 0.5
		xpGain.Position = UDim2.new(1, 10, 0, 50)
		tween(xpGain, 0.25, { Position = UDim2.new(1, 10, 0, 44) }, Enum.EasingStyle.Back)
		task.delay(0.9, function()
			if my == xpToken then
				tween(xpGain, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end
end

function UI.getLevel(): number
	return progress.level
end

-- Big "LEVEL UP" banner (shown over everything, even the garage)
local levelUpFrame: Frame? = nil
function UI.levelUp(level: number, reward: number)
	if levelUpFrame then
		levelUpFrame:Destroy()
	end
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 212),
		Size = UDim2.fromOffset(520, 150),
		BackgroundTransparency = 1,
		ZIndex = 70, -- above the garage too
		Parent = gui,
	})
	levelUpFrame = f
	local scale = new("UIScale", { Scale = 0.4, Parent = f })
	local title = label({ Text = "LEVEL UP!", TextSize = 64, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 70), ZIndex = 71, Parent = f })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 150, 190)),
			ColorSequenceKeypoint.new(1, Theme.Accent2),
		}),
		Parent = title,
	})
	local glow = new("UIStroke", { Color = Color3.fromRGB(40, 0, 20), Thickness = 3, Transparency = 0.1, Parent = title })
	local sub = label({ Text = "Level " .. level, TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Text, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 30), ZIndex = 71, Parent = f })
	local subStroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.4, Parent = sub })
	local cash = label({ Text = if reward > 0 then "+" .. formatCash(reward) else "", TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Money, Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 28), ZIndex = 71, Parent = f })
	local cashStroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.4, Parent = cash })
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.flash(Theme.Accent2)
	Audio.boom(0.5)
	UI.toast("Level " .. level .. " reached!" .. (if reward > 0 then "  +" .. formatCash(reward) else ""), Theme.Accent2)
	task.delay(2.6, function()
		if levelUpFrame ~= f then
			return
		end
		tween(scale, 0.5, { Scale = 1.15 })
		for _, l in { title, sub, cash } do
			tween(l, 0.5, { TextTransparency = 1 })
		end
		for _, st in { glow, subStroke, cashStroke } do
			tween(st, 0.5, { Transparency = 1 })
		end
		task.delay(0.55, function()
			f:Destroy()
			if levelUpFrame == f then
				levelUpFrame = nil
			end
		end)
	end)
end

-- seconds until the next daily gift (0 = ready now)
function UI.setDaily(readyIn: number)
	daily.known = true
	daily.readyAt = os.clock() + math.max(0, readyIn)
	refreshDaily(true)
end

local comboExpire = 0
function UI.setCombo(combo: number)
	if combo <= 0 then
		comboFrame.Visible = false
		comboExpire = 0
		return
	end
	comboFrame.Visible = true
	comboLabel.Text = "x" .. combo .. " COMBO"
	comboExpire = os.clock() + Config.Economy.ComboWindow
	comboLabel.TextSize = 36
	tween(comboLabel, 0.25, { TextSize = 28 }, Enum.EasingStyle.Back)
end

RunService.RenderStepped:Connect(function()
	if comboFrame and comboFrame.Visible then
		local left = comboExpire - os.clock()
		if left <= 0 then
			comboFrame.Visible = false
		else
			comboBar.Size = UDim2.fromScale(left / Config.Economy.ComboWindow, 1)
		end
	end
end)

function UI.popup(text: string, amount: number, color: Color3)
	local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(500, 70), Parent = popupHolder })
	local main = label({ Text = text, TextSize = 34, Font = Enum.Font.GothamBlack, TextColor3 = color, Size = UDim2.new(1, 0, 0, 40), Parent = holder })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.4, Parent = main })
	local money = label({ Text = "+" .. formatCash(amount), TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Money, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 28), Parent = holder })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.4, Parent = money })
	main.TextSize = 50
	tween(main, 0.25, { TextSize = 34 }, Enum.EasingStyle.Back)
	tween(holder, 1.4, { Position = UDim2.fromScale(0.5, 0.1) }, Enum.EasingStyle.Quad)
	task.delay(0.8, function()
		tween(main, 0.6, { TextTransparency = 1 })
		tween(money, 0.6, { TextTransparency = 1 })
	end)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

return UI
