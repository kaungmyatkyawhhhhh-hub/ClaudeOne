--[[
	UI (client) - dark themed interface
	  * loading screen, fades, cinematic letterbox, title card
	  * main menu
	  * garage with live 3D car preview, class tabs, stats and buy/drive
	  * HUD: cash, speedometer gauge with gear + rpm, combo meter, cut-up popups
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

local Theme = Config.Theme
local player = Players.LocalPlayer

local UI = {}
UI.touch = { throttle = 0, brake = 0, steer = 0, handbrake = false }
UI.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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
local rpmFill: Frame
local arcSegments: { Frame } = {}
local comboFrame: Frame
local comboLabel: TextLabel
local comboBar: Frame
local popupHolder: Frame
local toast: TextLabel
local camLabel: TextButton
local displayedCash = 0
local targetCash = 0

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

	-- cash
	local cashPanel = new("Frame", {
		Position = UDim2.new(0, 20, 0, 54),
		Size = UDim2.fromOffset(250, 64),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15,
		Parent = hud,
	}, { corner(10), stroke(Theme.Stroke, 1, 0.2) })
	new("Frame", { Size = UDim2.new(0, 4, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.Money, BorderSizePixel = 0, Parent = cashPanel }, { corner(2) })
	label({ Text = "CASH", TextColor3 = Theme.SubText, TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(22, 8), Size = UDim2.new(1, -30, 0, 14), Parent = cashPanel })
	cashLabel = label({ Text = "$0", TextColor3 = Theme.Money, TextSize = 30, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(22, 22), Size = UDim2.new(1, -30, 0, 34), Parent = cashPanel })

	-- speedometer (circular arc of segments)
	local gaugeSize = if UI.isTouch then 190 else 240
	local gauge = new("Frame", {
		Name = "Speedometer",
		AnchorPoint = if UI.isTouch then Vector2.new(0.5, 1) else Vector2.new(1, 1),
		Position = if UI.isTouch then UDim2.new(0.5, 0, 1, -16) else UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(gaugeSize, gaugeSize),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2,
		Parent = hud,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Theme.Stroke, 2, 0.1) })
	local segCount = 34
	local radius = gaugeSize / 2 - 16
	for k = 0, segCount - 1 do
		local a = math.rad(225 - k * (270 / (segCount - 1)))
		local seg = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * radius, 0.5, -math.sin(a) * radius),
			Size = UDim2.fromOffset(4, 13),
			Rotation = 90 - math.deg(a),
			BackgroundColor3 = Theme.Stroke,
			BorderSizePixel = 0,
			Parent = gauge,
		}, { corner(2) })
		table.insert(arcSegments, seg)
	end
	speedLabel = label({ Text = "0", TextSize = if UI.isTouch then 52 else 66, Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.3), Parent = gauge })
	label({ Text = "MPH", TextColor3 = Theme.SubText, TextSize = 14, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.5, 0.1), Parent = gauge })
	local gearBox = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromOffset(44, 32), BackgroundColor3 = Theme.Background, Parent = gauge }, { corner(6), stroke(Theme.Accent, 1.5, 0.2) })
	gearLabel = label({ Text = "N", TextColor3 = Theme.Accent, TextSize = 20, Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(1, 1), Parent = gearBox })
	local rpmBack = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.92), Size = UDim2.new(0.42, 0, 0, 4), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = gauge }, { corner(2) })
	rpmFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent2, BorderSizePixel = 0, Parent = rpmBack }, { corner(2) })

	-- combo
	comboFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(260, 66),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = hud,
	}, { corner(10), stroke(Theme.Accent2, 1.5, 0.1) })
	comboLabel = label({ Text = "x1 COMBO", TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = Theme.Accent2, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), Parent = comboFrame })
	local comboBack = new("Frame", { Position = UDim2.new(0, 16, 1, -14), Size = UDim2.new(1, -32, 0, 5), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = comboFrame }, { corner(3) })
	comboBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Accent2, BorderSizePixel = 0, Parent = comboBack }, { corner(3) })

	popupHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(500, 200), Parent = hud })

	-- top-right buttons
	local topRight = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 54), Size = UDim2.fromOffset(330, 40), BackgroundTransparency = 1, Parent = hud }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8) }),
	})
	local garageBtn = button("GARAGE  [G]", Theme.Accent, { Size = UDim2.fromOffset(150, 40), TextSize = 15, Parent = topRight })
	local camBtn = button("CAMERA  [C]", Theme.Accent, { Size = UDim2.fromOffset(150, 40), TextSize = 15, Parent = topRight })
	camLabel = camBtn
	garageBtn.Activated:Connect(function()
		if UI.onGarageButton then
			UI.onGarageButton()
		end
	end)
	camBtn.Activated:Connect(function()
		if UI.onCameraButton then
			UI.onCameraButton()
		end
	end)

	-- controls hint
	if not UI.isTouch then
		label({
			Text = "W/S  throttle · brake      A/D  steer      SPACE  handbrake      C  camera      R  reset      G  garage",
			TextColor3 = Theme.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 22, 1, -34),
			Size = UDim2.new(0.6, 0, 0, 20),
			Parent = hud,
		})
	end

	toast = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		TextSize = 16,
		TextTransparency = 1,
		Visible = false,
		ZIndex = 50,
		Parent = gui,
	})
	corner(8).Parent = toast

	-- Overlay (fades, letterbox, title) --------------------------------
	overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui })

	if UI.isTouch then
		UI.buildTouchControls()
	end

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
	label({ Text = "CASH  " .. formatCash(cash), TextColor3 = Theme.Money, TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 314), Size = UDim2.new(1, 0, 0, 22), ZIndex = 6, Parent = panel })
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
end

function UI.setCash(amount: number, instant: boolean?)
	targetCash = amount
	if instant then
		displayedCash = amount
		cashLabel.Text = formatCash(amount)
	end
end

local lastSegLit = -1
function UI.setSpeed(mph: number, frac: number, gear: string, rpm: number)
	speedLabel.Text = tostring(math.floor(math.abs(mph) + 0.5))
	gearLabel.Text = gear
	rpmFill.Size = UDim2.fromScale(math.clamp(rpm, 0, 1), 1)
	rpmFill.BackgroundColor3 = if rpm > 0.9 then Theme.Danger else Theme.Accent2
	local lit = math.floor(math.clamp(frac, 0, 1) * #arcSegments + 0.5)
	if lit ~= lastSegLit then
		lastSegLit = lit
		for k, seg in arcSegments do
			if k <= lit then
				local t = k / #arcSegments
				seg.BackgroundColor3 = if t < 0.6 then Theme.Accent:Lerp(Theme.Accent2, t / 0.6) else Theme.Accent2:Lerp(Theme.Danger, (t - 0.6) / 0.4)
			else
				seg.BackgroundColor3 = Theme.Stroke
			end
		end
	end
end

function UI.setCameraLabel(mode: string)
	camLabel.Text = (if mode == "Interior" then "INTERIOR" else "CHASE") .. "  [C]"
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

-- Callbacks assigned by Main
UI.onGarageButton = nil :: (() -> ())?
UI.onCameraButton = nil :: (() -> ())?

return UI
