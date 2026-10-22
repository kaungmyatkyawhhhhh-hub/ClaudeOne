-- AlterPopup (prompt 22, 21 Oct): the BODY ALTER READY popup, unique for every alter (Config.AlterThemes; mockups in
-- Downloads\gym_arc_alters\ui_tier1\mockups.png). ProgressClient shows it when the next alter is ready.
-- Layout (the same for all): the alter's background art (or its colors), a small "BODY ALTER READY", the NAME big (Luckiest
-- Guy, the theme's gradient, a soft shadow), "Alter N · gains xN.NN" (+ "· TIER 1 COMPLETE" on a tier's 5th), ALTER (accent)
-- and LATER (dark).
-- Entrance (~1.2 s): the screen dims with a vignette, the music ducks and a riser builds; letterbox bars slide in; the panel
-- slams in (1.3 -> 1 with overshoot) with a sub boom + punch, a shockwave ring in the accent color and a small camera shake;
-- a beat later the name stamps in (2 -> 1, white, then the gradient) with sparks; then the theme's own beat (Pumped: two
-- heartbeats, Shredded: slashes, Tanned: the sun rises, Vascular: veins crackle, Peak: the spotlight and gold dust ...).
-- While open: the border glows and pulses, a shine sweeps the title every 2.5 s, themed particles drift, the ALTER button
-- breathes, a soft hum. ALTER: a heavy "clunk", then the transformation (AlterFX.Transform). LATER closes it.
-- AlterPopup.Show(n, info { bonus, tierName }, callbacks { onAlter, onLater }) / AlterPopup.Hide() / AlterPopup.IsOpen()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = script.Parent.Parent
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local AlterThemes = require(Shared.Config.AlterThemes)
local AlterIcon = require(script.Parent.AlterIcon)
local AlterFX = require(Shared.VFX.AlterFX)
local Audio = require(Shared.Audio)

local AlterPopup = {}

local W, H = 520, 208 -- mockup px (2.5 : 1 like the art); fits 667 x 375
local GOTHAM_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local function tween(instance, props, time, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do i[k] = v end
	i.Parent = parent
	return i
end

local built = nil
local open = false
local token = 0 -- (bumps on every show / hide: loops of an older popup stop)
local hum = nil
local callbacks = {}

local function build()
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", { Name = "AlterReady", DisplayOrder = 46, Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.None }, player:WaitForChild("PlayerGui"))
	local dim = new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1) }, gui)
	-- the vignette (dark edges)
	local vignette = new("Frame", { Name = "Vignette", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	for _, spec in ipairs({ { 90, UDim2.fromScale(1, 0.35), UDim2.new() }, { -90, UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65) },
		{ 0, UDim2.fromScale(0.3, 1), UDim2.new() }, { 180, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0) } }) do
		local f = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = spec[2], Position = spec[3] }, vignette)
		new("UIGradient", { Rotation = spec[1], Transparency = NumberSequence.new(0.25, 1) }, f)
	end
	local fx = new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, gui)
	local bars = {}
	for i, y in ipairs({ 0, 1 }) do
		bars[i] = new("Frame", { Name = "Letterbox", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, y),
			Size = UDim2.fromScale(1, 0.08), Position = UDim2.fromScale(0, if i == 1 then -0.08 else 1.08), ZIndex = 5 }, gui)
	end
	local root = Kit.Root(gui)
	root.ZIndex = 3
	local group = new("Frame", { Name = "Group", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), ZIndex = 3 }, root)
	local pop = new("UIScale", {}, group)
	local panel = new("Frame", { Name = "Panel", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true, ZIndex = 3 }, group)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
	local border = new("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
	local glow = new("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = AlterFX.TEX.rim, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 120, 1, 120), ImageTransparency = 0.5, ZIndex = 2 }, group)
	local art = new("ImageLabel", { Name = "Art", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, panel)
	-- (tiers without art yet) a wash of the theme's colors: the accent glowing up from the bottom into the dark base
	local wash = new("Frame", { Name = "Wash", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, panel)
	local washGradient = new("UIGradient", { Rotation = -90 }, wash)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, wash)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, art)
	local overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, ClipsDescendants = true }, panel)
	local kicker = new("TextLabel", { Name = "Kicker", BackgroundTransparency = 1, Text = "BODY ALTER READY", FontFace = GOTHAM_BOLD, TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 18), ZIndex = 6 }, panel)
	new("UIStroke", { Thickness = 1.5, Transparency = 0.4 }, kicker)
	-- the name: a shadow copy, the gradient copy, and a white shine copy swept by a gradient
	local nameBox = new("Frame", { Name = "NameBox", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.new(1, -40, 0, 66), ZIndex = 6 }, panel)
	local nameScale = new("UIScale", {}, nameBox)
	local shadow = new("TextLabel", { Name = "Shadow", BackgroundTransparency = 1, FontFace = AlterFX.TitleFont, TextScaled = true, Text = "",
		TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.45, Position = UDim2.fromOffset(3, 5), Size = UDim2.fromScale(1, 1), ZIndex = 6 }, nameBox)
	local name = new("TextLabel", { Name = "Name", BackgroundTransparency = 1, FontFace = AlterFX.TitleFont, TextScaled = true, Text = "",
		TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 7 }, nameBox)
	local nameGradient = new("UIGradient", { Rotation = 90 }, name)
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.35 }, name)
	local shine = new("TextLabel", { Name = "Shine", BackgroundTransparency = 1, FontFace = AlterFX.TitleFont, TextScaled = true, Text = "",
		TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 8 }, nameBox)
	local shineGradient = new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }, shine)
	-- the wipe (Shredded: the name wipes in left to right)
	local wipe = new("UIGradient", { Name = "Wipe", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.49, 0),
		NumberSequenceKeypoint.new(0.51, 1), NumberSequenceKeypoint.new(1, 1) }), Offset = Vector2.new(0.5, 0), Enabled = false }, nameBox)
	local sub = new("TextLabel", { Name = "Sub", BackgroundTransparency = 1, Text = "", FontFace = GOTHAM_BOLD, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 20), ZIndex = 6 }, panel)
	new("UIStroke", { Thickness = 1.5, Transparency = 0.3 }, sub)
	-- the buttons
	local alterButton = new("TextButton", { Name = "Alter", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, -166, 1, -16), Size = UDim2.fromOffset(222, 50), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8 }, panel)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, alterButton)
	local alterGradient = new("UIGradient", { Rotation = 90 }, alterButton)
	local alterStroke = new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, alterButton)
	local alterScale = new("UIScale", {}, alterButton)
	local gloss = new("Frame", { Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0.38, 0), ZIndex = 9 }, alterButton)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, gloss)
	local alterText = new("TextLabel", { BackgroundTransparency = 1, Text = "ALTER  >", FontFace = AlterFX.TitleFont, TextSize = 26, Size = UDim2.fromScale(1, 1),
		ZIndex = 10 }, alterButton)
	local alterGlow = new("ImageLabel", { Name = "ButtonGlow", BackgroundTransparency = 1, Image = AlterFX.TEX.rim, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 60, 1, 50), ImageTransparency = 0.6, ZIndex = 7 }, alterButton)
	local laterButton = new("TextButton", { Name = "Later", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 70, 1, -16), Size = UDim2.fromOffset(110, 50), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8 }, panel)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, laterButton)
	new("UIStroke", { Thickness = 2, Color = Color3.fromHex("#55555E"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, laterButton)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#5A5A62"), Color3.fromHex("#2A2A30")) }, laterButton)
	new("TextLabel", { BackgroundTransparency = 1, Text = "LATER", FontFace = AlterFX.TitleFont, TextSize = 22, TextColor3 = Color3.fromHex("#E6E6EA"),
		Size = UDim2.fromScale(1, 1), ZIndex = 10 }, laterButton)
	Theme.BindPress(alterButton)
	Theme.BindPress(laterButton)
	-- (prompt 54) the alter's bicep icon (Shared/UI/AlterIcon), top left of the panel
	local icon = AlterIcon.New({ Name = "AlterIcon", Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(62, 62), ZIndex = 7, Parent = panel })

	built = { gui = gui, dim = dim, vignette = vignette, fx = fx, bars = bars, group = group, pop = pop, panel = panel, border = border, glow = glow,
		art = art, wash = wash, washGradient = washGradient, overlay = overlay, nameBox = nameBox, nameScale = nameScale, shadow = shadow, name = name, nameGradient = nameGradient, shine = shine,
		shineGradient = shineGradient, wipe = wipe, sub = sub, alterButton = alterButton, alterGradient = alterGradient, alterStroke = alterStroke,
		alterScale = alterScale, alterText = alterText, alterGlow = alterGlow, laterButton = laterButton, kicker = kicker, icon = icon }

	alterButton.Activated:Connect(function()
		if not open then return end
		AlterFX.Sound("Confirm")
		local onAlter = callbacks.onAlter
		AlterPopup.Hide(true)
		if onAlter then onAlter() end
	end)
	laterButton.Activated:Connect(function()
		if not open then return end
		Audio.PlayUI("Click")
		local onLater = callbacks.onLater
		AlterPopup.Hide()
		if onLater then onLater() end
	end)
	-- under Roblox's top bar on phones: the panel sits a little lower
	Kit.OnTopbar(function()
		group.Position = UDim2.new(0.5, 0, 0.5, math.max(0, Kit.UnderTopbar(root) / 2 - 6))
	end)
	return built
end

-- a small camera shake (Humanoid.CameraOffset; none with Reduced Motion)
local function shake(strength, time)
	if Theme.ReducedMotion() then return end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
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

-- the theme's own entrance beat, on the panel
local function introBeat(b, theme, mine)
	local intro = theme.intro
	if intro == "heartbeat" then
		for i = 0, 1 do
			task.delay(i * 0.42, function()
				if token ~= mine then return end
				tween(b.pop, { Scale = 1.04 }, 0.09)
				task.delay(0.09, function() tween(b.pop, { Scale = 1 }, 0.18) end)
				AlterFX.Ring(b.overlay, theme.accent, 60, 520, 0.6)
			end)
		end
	elseif intro == "slice" then
		for i = 0, 1 do
			task.delay(i * 0.12, function()
				if token ~= mine then return end
				local s = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(-0.2, 0.5), Size = UDim2.new(0, 10, 2, 0), Rotation = 28, ZIndex = 9 }, b.overlay)
				tween(s, { Position = UDim2.fromScale(1.2, 0.5), BackgroundTransparency = 1 }, 0.22)
				task.delay(0.25, function() s:Destroy() end)
			end)
		end
		-- the name wipes in from the left
		b.wipe.Enabled = true
		b.wipe.Offset = Vector2.new(-0.5, 0)
		tween(b.wipe, { Offset = Vector2.new(0.55, 0) }, 0.35)
		task.delay(0.4, function() b.wipe.Enabled = false end)
	elseif intro == "rise" or intro == "legend" then
		b.group.Position += UDim2.fromOffset(0, 40)
		tween(b.group, { Position = b.group.Position - UDim2.fromOffset(0, 40) }, 0.5, Enum.EasingStyle.Back)
	elseif intro == "veins" or intro == "storm" or intro == "plasma" then
		local tints = if intro == "veins" then { Color3.fromHex("#FF4A5A"), Color3.fromHex("#5A6BFF") } else { theme.accent, Color3.new(1, 1, 1) }
		for i, spot in ipairs({ { 0.04, 0.2 }, { 0.96, 0.25 }, { 0.06, 0.85 }, { 0.94, 0.8 } }) do
			task.delay((i - 1) * 0.08, function()
				if token ~= mine then return end
				local bolt = AlterFX.Image(b.overlay, "lightning", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(spot[1], spot[2]),
					Size = UDim2.fromOffset(150, 150), Rotation = (i - 1) * 90, ImageColor3 = tints[(i % 2) + 1], ZIndex = 5 })
				AlterFX.AnimateFlipbook(bolt, 18)
				tween(bolt, { ImageTransparency = 1 }, 0.9)
				task.delay(0.95, function() bolt:Destroy() end)
			end)
		end
	elseif intro == "spotlight" then
		-- (a soft glow texture stretched into a beam, pivoting from above the panel)
		local pivot = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, -0.3),
			Size = UDim2.fromOffset(2, 2), Rotation = -40, ZIndex = 5 }, b.overlay)
		local cone = AlterFX.Image(pivot, "ember", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(240, 420),
			ImageColor3 = theme.accent, ImageTransparency = 0.35, ZIndex = 5 })
		tween(pivot, { Rotation = 0 }, 0.6, Enum.EasingStyle.Back)
		task.delay(1.6, function() if cone.Parent then tween(cone, { ImageTransparency = 0.7 }, 0.6) end end)
	elseif intro == "stone" then
		shake(0.5, 0.35)
	elseif intro == "metal" or intro == "gem" or intro == "frost" then
		-- a sheen across the panel
		local s = new("Frame", { BackgroundColor3 = if intro == "gem" then theme.title[1] else Color3.new(1, 1, 1), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.5), Size = UDim2.new(0, 60, 2, 0), Rotation = 20,
			BackgroundTransparency = 0.5, ZIndex = 5 }, b.overlay)
		tween(s, { Position = UDim2.fromScale(1.2, 0.5) }, 0.5)
		task.delay(0.55, function() s:Destroy() end)
	elseif intro == "lava" or intro == "toxic" then
		AlterFX.UIParticles(b.overlay, theme, 10, 0.6, { zIndex = 5 })
	end
end

function AlterPopup.IsOpen(): boolean
	return open
end

function AlterPopup.Show(n: number, info, cbs)
	local b = built or build()
	callbacks = cbs or {}
	token += 1
	local mine = token
	open = true
	local theme = AlterThemes.Get(n)
	info = info or {}
	-- the theme
	b.panel.BackgroundColor3 = theme.base
	b.art.Image = theme.bg or ""
	b.art.Visible = theme.bg ~= nil
	b.wash.Visible = theme.bg == nil
	b.washGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, theme.accent:Lerp(theme.base, 0.45)),
		ColorSequenceKeypoint.new(0.55, theme.base), ColorSequenceKeypoint.new(1, theme.base:Lerp(Color3.new(0, 0, 0), 0.3)) })
	b.border.Color = theme.accent
	b.glow.ImageColor3 = theme.accent
	AlterIcon.Set(b.icon, n)
	b.nameGradient.Color = ColorSequence.new(theme.title[1], theme.title[2])
	local display = string.upper(info.name or "")
	b.name.Text, b.shadow.Text, b.shine.Text = display, display, display
	local subText = "Alter " .. n .. " · gains x" .. string.format("%.2f", info.bonus or 1)
	if theme.finale then subText ..= " · TIER " .. tostring(info.tier or math.ceil(n / 5)) .. " COMPLETE" end
	b.sub.Text = subText
	b.alterGradient.Color = ColorSequence.new(theme.accent:Lerp(Color3.new(1, 1, 1), 0.35), theme.accent:Lerp(Color3.new(0, 0, 0), 0.2))
	b.alterStroke.Color = theme.accent:Lerp(Color3.new(1, 1, 1), 0.5)
	b.alterText.TextColor3 = theme.buttonText
	b.alterGlow.ImageColor3 = theme.accent

	-- the entrance
	b.gui.Enabled = true
	for _, child in ipairs(b.fx:GetChildren()) do child:Destroy() end
	for _, child in ipairs(b.overlay:GetChildren()) do child:Destroy() end
	b.dim.BackgroundTransparency = 1
	tween(b.dim, { BackgroundTransparency = 0.4 }, 0.5)
	b.vignette.Visible = true
	Audio.Duck(0.3, 0.5)
	AlterFX.Sound("Riser", { fadeIn = 0.5 })
	for i, bar in ipairs(b.bars) do
		bar.Position = UDim2.fromScale(0, if i == 1 then -0.08 else 1.08)
		tween(bar, { Position = UDim2.fromScale(0, if i == 1 then 0 else 1) }, 0.45, Enum.EasingStyle.Quart)
	end
	b.group.Visible = false
	b.nameBox.Visible = false
	b.shine.TextTransparency = 1
	task.delay(0.75, function()
		if token ~= mine then return end
		-- the panel slams in: sub boom + punch, a shockwave ring, a small shake
		b.group.Visible = true
		b.pop.Scale = 1.3
		tween(b.pop, { Scale = 1 }, 0.32, Enum.EasingStyle.Back)
		AlterFX.Sound("ImpactSub")
		AlterFX.Sound("ImpactPunch")
		AlterFX.Ring(b.fx, theme.accent, 200, 1400, 0.7)
		shake(0.35, 0.25)
		introBeat(b, theme, mine)
	end)
	task.delay(1.05, function()
		if token ~= mine then return end
		-- the name stamps in: 2 -> 1, white first, then the gradient; sparks behind it
		b.nameBox.Visible = true
		b.nameScale.Scale = 2
		b.nameGradient.Enabled = false
		tween(b.nameScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back)
		task.delay(0.12, function() b.nameGradient.Enabled = true end)
		AlterFX.Sound("Stamp")
		AlterFX.Sound("Shimmer", { delay = 0.05 })
		AlterFX.Sting(theme, { delay = 0.1 })
		AlterFX.UIParticles(b.overlay, theme, 12, 0.1, { burst = true, y = 0.37, zIndex = 5 })
	end)
	-- the loops while open: the border pulses, the shine sweeps, particles drift, the button breathes, a soft hum
	task.delay(1.3, function()
		if token ~= mine then return end
		hum = AlterFX.Sound("Hum", { loop = true, fadeIn = 1 })
		AlterFX.ScreenFX(b.fx, theme, if theme.intro == "spotlight" then "spotlight" else "particles", 1)
		while token == mine and open do
			tween(b.border, { Thickness = 4.5 }, 0.6, Enum.EasingStyle.Sine)
			tween(b.glow, { ImageTransparency = 0.25 }, 0.6, Enum.EasingStyle.Sine)
			tween(b.alterScale, { Scale = 1.04 }, 0.6, Enum.EasingStyle.Sine)
			tween(b.alterGlow, { ImageTransparency = 0.25 }, 0.6, Enum.EasingStyle.Sine)
			task.wait(0.65)
			if token ~= mine then break end
			tween(b.border, { Thickness = 3 }, 0.6, Enum.EasingStyle.Sine)
			tween(b.glow, { ImageTransparency = 0.55 }, 0.6, Enum.EasingStyle.Sine)
			tween(b.alterScale, { Scale = 1 }, 0.6, Enum.EasingStyle.Sine)
			tween(b.alterGlow, { ImageTransparency = 0.6 }, 0.6, Enum.EasingStyle.Sine)
			-- the shine sweep (about every 2.5 s)
			b.shine.TextTransparency = 0
			b.shineGradient.Offset = Vector2.new(-1, 0)
			tween(b.shineGradient, { Offset = Vector2.new(1, 0) }, 0.7)
			AlterFX.UIParticles(b.fx, theme, 6, 1.2)
			task.wait(0.65)
			if token ~= mine then break end
			task.wait(1.2)
		end
	end)
end

-- confirmed = ALTER was tapped (the transformation takes over the music; nothing to fade back here)
function AlterPopup.Hide(confirmed: boolean?)
	if not built or not open then return end
	open = false
	token += 1
	local b = built
	AlterFX.FadeOut(hum, 0.3)
	hum = nil
	if not confirmed then Audio.Duck(1, 0.8) end
	tween(b.pop, { Scale = 0.9 }, 0.15)
	tween(b.dim, { BackgroundTransparency = 1 }, 0.2)
	for i, bar in ipairs(b.bars) do tween(bar, { Position = UDim2.fromScale(0, if i == 1 then -0.08 else 1.08) }, 0.2) end
	local mine = token
	task.delay(0.2, function()
		if token == mine then b.gui.Enabled = false end
	end)
end

return AlterPopup
