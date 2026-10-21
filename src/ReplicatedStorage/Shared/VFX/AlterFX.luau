-- AlterFX (prompt 22, 21 Oct): the Body Alter's sounds and effects on the client, themed per alter (Config.AlterThemes).
--   AlterFX.Sound(key, opts)            one layer (a key of AlterThemes.Sounds or { id, volume }); opts: delay, pitch, volume,
--                                       parent (3D on a part), fadeIn, timePosition, maxLength. Group "AlterFX".
--   AlterFX.UIParticles(parent, theme, count, duration, opts)   themed 2D particles (embers rise, dust falls, sparkles drift)
--   AlterFX.ScreenFX(gui, theme, kind, duration)                 a themed full-screen overlay (edge throb, slashes, sun flare,
--                                       veins, spotlight, prism ...) on a ScreenGui
--   AlterFX.Ring(parent, color, from, to, time)                  a UI shockwave ring
--   AlterFX.Burst(character, theme, isLocal)                     the flash on a body: light, a ground shockwave, particles, a
--                                       3D boom (other players nearby see / hear this one too)
--   AlterFX.Transform(theme, info, hooks) -> controller          the local transformation (about 3 s, tap to skip): camera close,
--                                       world darker, music muffled, energy gathers in, 0.2 s of silence, FLASH (hooks.onFlash
--                                       fires the ALTER action, so the new skin appears under the flash), the reveal (chime, sting,
--                                       cheer; the server makes the body flex), the title card, the camera back.
--   AlterFX.Running()                   true while a transformation plays
-- Max ~40 particles at the peak, ~20 idle; half with low graphics. Reduced Motion: no camera shake, fewer moving overlays.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent
local AlterThemes = require(Shared.Config.AlterThemes)
local Audio = require(Shared.Audio)
local Theme = require(Shared.UI.Theme)

local AlterFX = {}

-- the AuraVFX textures (Downloads\gym_arc_aura_vfx)
local TEX = {
	rim = "rbxassetid://138347218007327",       -- rim_glow.png
	ember = "rbxassetid://76009392745145",      -- ember_dot.png
	lightning = "rbxassetid://80590302550492",  -- lightning_flipbook_4x4.png (1024 x 1024, 4 x 4)
	smoke = "rbxassetid://113405238797101",     -- smoke_shaded_4x4.png (1024 x 1024, 4 x 4)
	droplet = "rbxassetid://137490039482038",   -- droplet.png
	spark = "rbxassetid://82372237523631",      -- spark_star.png
	ring = "rbxassetid://131893925782949",      -- shockwave_ring.png
	ground = "rbxassetid://74138882329945",     -- ground_circle.png
}
AlterFX.TEX = TEX
local FLIPBOOK = { lightning = true, smoke = true }
local LUCKIEST = Font.fromEnum(Enum.Font.LuckiestGuy)
AlterFX.TitleFont = LUCKIEST

local function tween(instance, props, time, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function lowGraphics(): boolean
	local ok, level = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel end)
	return ok and level ~= Enum.SavedQualitySetting.Automatic and level.Value <= 3
end
AlterFX.LowGraphics = lowGraphics

local function reduced(): boolean
	return Theme.ReducedMotion()
end

------------------------------------------------------------------------
-- Sound
------------------------------------------------------------------------
function AlterFX.Sound(key, opts)
	opts = opts or {}
	local spec = if type(key) == "table" then key else AlterThemes.Sounds[key]
	if not spec or not spec.id then return nil end
	local function play()
		local sound = Instance.new("Sound")
		sound.Name = if type(key) == "string" then key else "AlterSound"
		sound.SoundId = "rbxassetid://" .. tostring(spec.id)
		local volume = (spec.volume or 0.5) * (opts.volume or 1)
		sound.Volume = if opts.fadeIn then 0 else volume
		sound.PlaybackSpeed = (spec.pitch or 1) * (opts.pitch or 1)
		sound.SoundGroup = Audio.Group("AlterFX")
		if opts.timePosition then sound.TimePosition = opts.timePosition end
		if opts.parent then
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance, sound.RollOffMaxDistance = 12, 140
			sound.Parent = opts.parent
		else
			sound.Parent = SoundService
		end
		sound.Looped = opts.loop == true
		sound:Play()
		if opts.fadeIn then tween(sound, { Volume = volume }, opts.fadeIn) end
		local maxLength = opts.maxLength or (type(key) == "string" and AlterThemes.MaxLength[key])
		if not opts.loop then
			if maxLength then
				task.delay(math.max(0, maxLength - 0.3), function()
					if sound.Parent then tween(sound, { Volume = 0 }, 0.3) end
				end)
				Debris:AddItem(sound, maxLength + 0.1)
			else
				Debris:AddItem(sound, 8)
			end
		end
		return sound
	end
	if opts.delay and opts.delay > 0 then
		task.delay(opts.delay, play)
		return nil
	end
	return play()
end

local function fadeOut(sound, time)
	if sound and sound.Parent then
		tween(sound, { Volume = 0 }, time or 0.2)
		Debris:AddItem(sound, (time or 0.2) + 0.05)
	end
end
AlterFX.FadeOut = fadeOut

-- the theme's own sting (its layers with their delays)
function AlterFX.Sting(theme, opts)
	for _, layer in ipairs(theme.sting or {}) do
		AlterFX.Sound(layer[1], { delay = (layer[2] or 0) + ((opts and opts.delay) or 0), parent = opts and opts.parent,
			volume = opts and opts.volume, pitch = if layer[1] == "IceCrack" then 1.6 elseif layer[1] == "WarmWhoosh" and theme.intro == "lava" then 0.7 else nil })
	end
end

------------------------------------------------------------------------
-- 2D effects
------------------------------------------------------------------------
local function image(parent, texture, props)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = TEX[texture] or texture
	if FLIPBOOK[texture] then
		i.ImageRectSize = Vector2.new(256, 256)
		i.ImageRectOffset = Vector2.new(0, 0)
	end
	for k, v in pairs(props or {}) do i[k] = v end
	i.Parent = parent
	return i
end
AlterFX.Image = image

-- a flipbook ImageLabel cycles its 16 frames (until it is destroyed)
local function animateFlipbook(label: ImageLabel, fps: number)
	task.spawn(function()
		local frame = math.random(0, 15)
		while label.Parent do
			label.ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256)
			frame = (frame + 1) % 16
			task.wait(1 / fps)
		end
	end)
end
AlterFX.AnimateFlipbook = animateFlipbook

-- count particles over `duration` seconds inside `parent` (a full-size frame); opts.burst = from the centre outward
local live = 0
function AlterFX.UIParticles(parent: GuiObject, theme, count: number, duration: number, opts)
	opts = opts or {}
	local cap = if opts.peak then AlterThemes.MaxParticles.peak else AlterThemes.MaxParticles.idle
	if lowGraphics() then cap = math.floor(cap / 2) end
	local p = theme.particle or { texture = "spark", motion = "drift" }
	local color = p.color or theme.accent
	local rng = Random.new()
	for i = 1, count do
		local delay = if opts.burst then 0 else (i - 1) * duration / count
		task.delay(delay, function()
			if not parent.Parent or live >= cap then return end
			live += 1
			local size = rng:NextNumber(10, 26) * (opts.scale or 1)
			local life = if opts.burst then rng:NextNumber(0.5, 0.9) else rng:NextNumber(1.6, 2.6)
			local start, finish
			if opts.burst then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(0.25, 0.6)
				start = UDim2.fromScale(opts.x or 0.5, opts.y or 0.5)
				finish = UDim2.fromScale((opts.x or 0.5) + math.cos(a) * r, (opts.y or 0.5) + math.sin(a) * r * 0.8)
			elseif p.motion == "rise" then
				local x = rng:NextNumber(0.05, 0.95)
				start, finish = UDim2.fromScale(x, 1.05), UDim2.fromScale(x + rng:NextNumber(-0.08, 0.08), rng:NextNumber(0.1, 0.5))
			elseif p.motion == "fall" then
				local x = rng:NextNumber(0.05, 0.95)
				start, finish = UDim2.fromScale(x, -0.05), UDim2.fromScale(x + rng:NextNumber(-0.05, 0.05), rng:NextNumber(0.6, 1.05))
			else
				local x, y = rng:NextNumber(0.05, 0.95), rng:NextNumber(0.1, 0.9)
				start, finish = UDim2.fromScale(x, y), UDim2.fromScale(x + rng:NextNumber(-0.04, 0.04), y - rng:NextNumber(0.02, 0.1))
			end
			local texture = p.texture or "spark"
			local label = image(parent, texture, { AnchorPoint = Vector2.new(0.5, 0.5), Position = start, Size = UDim2.fromOffset(size, size),
				ImageColor3 = color, ImageTransparency = if opts.burst then 0 else 1, Rotation = rng:NextNumber(0, 360), ZIndex = opts.zIndex or 1 })
			if FLIPBOOK[texture] then animateFlipbook(label, 18) end
			if not opts.burst then tween(label, { ImageTransparency = 0.1 }, life * 0.25) end
			tween(label, { Position = finish, Rotation = label.Rotation + rng:NextNumber(-90, 90) }, life, Enum.EasingStyle.Sine)
			task.delay(life * 0.6, function()
				if label.Parent then tween(label, { ImageTransparency = 1, Size = UDim2.fromOffset(size * 0.4, size * 0.4) }, life * 0.4) end
			end)
			task.delay(life, function()
				live -= 1
				label:Destroy()
			end)
		end)
	end
end

-- a shockwave ring (UI): from `from` px to `to` px over `time`, centred in parent (or at opts position)
function AlterFX.Ring(parent: GuiObject, color: Color3, from: number, to: number, time: number, position: UDim2?)
	local ring = image(parent, "ring", { AnchorPoint = Vector2.new(0.5, 0.5), Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(from, from), ImageColor3 = color, ImageTransparency = 0, ZIndex = 2 })
	tween(ring, { Size = UDim2.fromOffset(to, to), ImageTransparency = 1 }, time, Enum.EasingStyle.Quart)
	Debris:AddItem(ring, time + 0.05)
	return ring
end

-- a frame with a one-sided gradient (an edge glow)
local function edge(parent, color, side, thickness)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(0, 1)
	if side == "top" then
		f.Size = UDim2.new(1, 0, thickness, 0); g.Rotation = 90
	elseif side == "bottom" then
		f.AnchorPoint = Vector2.new(0, 1); f.Position = UDim2.fromScale(0, 1); f.Size = UDim2.new(1, 0, thickness, 0); g.Rotation = -90
	elseif side == "left" then
		f.Size = UDim2.new(thickness * 0.6, 0, 1, 0); g.Rotation = 0
	else
		f.AnchorPoint = Vector2.new(1, 0); f.Position = UDim2.fromScale(1, 0); f.Size = UDim2.new(thickness * 0.6, 0, 1, 0); g.Rotation = 180
	end
	g.Parent = f
	f.Parent = parent
	return f
end

-- a full-screen themed overlay on `gui` for `duration` seconds (cleans itself up)
function AlterFX.ScreenFX(gui: Instance, theme, kind: string, duration: number)
	local layer = Instance.new("Frame")
	layer.Name = "ScreenFX_" .. kind
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 1
	layer.ClipsDescendants = true
	layer.Parent = gui
	local accent = theme.accent
	if kind == "heartbeat" then
		-- the screen edge throbs with the beat (twice), a red shockwave on each beat
		local edges = {}
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do
			local e = edge(layer, accent, side, 0.22)
			e.BackgroundTransparency = 1
			table.insert(edges, e)
		end
		task.spawn(function()
			for _ = 1, math.max(2, math.floor(duration / 0.8)) do
				if not layer.Parent then return end
				for _, e in ipairs(edges) do
					e.BackgroundTransparency = 0.35
					tween(e, { BackgroundTransparency = 1 }, 0.55)
				end
				task.wait(0.8)
			end
		end)
	elseif kind == "slice" then
		-- white-blue slash lines cut across the screen, a quick freeze on the last one
		for i = 0, 2 do
			task.delay(i * 0.12, function()
				if not layer.Parent then return end
				local s = Instance.new("Frame")
				s.BorderSizePixel = 0
				s.BackgroundColor3 = if i == 1 then Color3.new(1, 1, 1) else accent
				s.AnchorPoint = Vector2.new(0.5, 0.5)
				s.Position = UDim2.fromScale(-0.3, 0.35 + i * 0.15)
				s.Size = UDim2.new(1.6, 0, 0, 5 - i)
				s.Rotation = -18 + i * 4
				s.Parent = layer
				tween(s, { Position = UDim2.fromScale(1.3, 0.35 + i * 0.15 - 0.2) }, 0.25, Enum.EasingStyle.Quart)
				tween(s, { BackgroundTransparency = 1 }, 0.35)
				Debris:AddItem(s, 0.4)
			end)
		end
	elseif kind == "rise" or kind == "legend" then
		-- the sun from below: a warm flare and slowly turning god rays
		local flare = image(layer, "ember", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1.02), Size = UDim2.fromScale(1.2, 0.9),
			ImageColor3 = accent, ImageTransparency = 1 })
		tween(flare, { ImageTransparency = 0.25 }, 0.4)
		local rays = Instance.new("Frame")
		rays.BackgroundTransparency = 1
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 1)
		rays.Size = UDim2.fromScale(0, 0)
		rays.Parent = layer
		for i = 0, 11 do
			local r = Instance.new("Frame")
			r.BorderSizePixel = 0
			r.AnchorPoint = Vector2.new(0.5, 1)
			r.BackgroundColor3 = accent
			r.BackgroundTransparency = 0.82
			r.Size = UDim2.fromOffset(40, 900)
			r.Rotation = -75 + i * 13.6
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = NumberSequence.new(1, 0)
			g.Parent = r
			r.Parent = rays
		end
		if not reduced() then
			task.spawn(function()
				local t0 = os.clock()
				while layer.Parent do
					rays.Rotation = math.sin((os.clock() - t0) * 0.6) * 6
					RunService.RenderStepped:Wait()
				end
			end)
		end
	elseif kind == "veins" or kind == "storm" or kind == "plasma" then
		-- lightning crackles racing along the screen edges (red and blue for Vascular)
		local tints = if kind == "veins" then { Color3.fromHex("#FF4A5A"), Color3.fromHex("#5A6BFF") } else { accent, Color3.new(1, 1, 1) }
		local spots = { { 0.08, 0.2, 0 }, { 0.92, 0.25, 180 }, { 0.12, 0.8, 30 }, { 0.88, 0.78, 200 }, { 0.5, 0.06, 90 }, { 0.5, 0.95, -90 } }
		for i, s in ipairs(spots) do
			task.delay((i - 1) * 0.07, function()
				if not layer.Parent then return end
				local bolt = image(layer, "lightning", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(s[1], s[2]),
					Size = UDim2.fromOffset(260, 260), Rotation = s[3], ImageColor3 = tints[(i % 2) + 1], ImageTransparency = 0.1 })
				animateFlipbook(bolt, 20)
				tween(bolt, { ImageTransparency = 1 }, math.max(0.5, duration * 0.6))
			end)
		end
	elseif kind == "spotlight" then
		-- a gold spotlight cone sweeps down onto the middle, gold dust rains
		-- (a soft glow texture stretched into a beam, pivoting from above the screen)
		local pivot = Instance.new("Frame")
		pivot.BackgroundTransparency = 1
		pivot.AnchorPoint = Vector2.new(0.5, 0.5)
		pivot.Position = UDim2.fromScale(0.5, -0.15)
		pivot.Size = UDim2.fromOffset(2, 2)
		pivot.Rotation = -32
		pivot.Parent = layer
		image(pivot, "ember", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 1100),
			ImageColor3 = accent, ImageTransparency = 0.45 })
		tween(pivot, { Rotation = 0 }, 0.7, Enum.EasingStyle.Back)
		AlterFX.UIParticles(layer, { particle = { texture = "spark", color = accent, motion = "fall" }, accent = accent }, 16, duration)
	elseif kind == "frost" or kind == "gem" or kind == "metal" then
		-- prism / frost / chrome flashes: quick tinted sheens across the screen
		for i = 0, 2 do
			task.delay(i * 0.18, function()
				if not layer.Parent then return end
				local s = Instance.new("Frame")
				s.BorderSizePixel = 0
				s.BackgroundColor3 = if kind == "gem" then Color3.fromHSV((i * 0.33 + 0.1) % 1, 0.5, 1) else accent
				s.BackgroundTransparency = 0.6
				s.AnchorPoint = Vector2.new(0.5, 0.5)
				s.Position = UDim2.fromScale(-0.2, 0.5)
				s.Size = UDim2.new(0.18, 0, 2, 0)
				s.Rotation = 20
				s.Parent = layer
				tween(s, { Position = UDim2.fromScale(1.2, 0.5), BackgroundTransparency = 1 }, 0.45, Enum.EasingStyle.Quad)
				Debris:AddItem(s, 0.5)
			end)
		end
	end
	-- the theme's particles drift over the overlay
	if kind ~= "spotlight" then AlterFX.UIParticles(layer, theme, 12, duration) end
	task.delay(duration + 1, function() layer:Destroy() end)
	return layer
end

------------------------------------------------------------------------
-- 3D effects on a character
------------------------------------------------------------------------
local function emitter(parent, theme, props)
	local p = theme.particle or { texture = "spark" }
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[p.texture] or TEX.spark
	if FLIPBOOK[p.texture] then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(p.color or theme.accent, 0.35), p.color or theme.accent)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Enabled = false
	e.Rate = 0
	for k, v in pairs(props or {}) do e[k] = v end
	e.Parent = parent
	return e
end

-- the flash on a body: a bright light, a ground shockwave and a burst of themed particles (+ a 3D boom for others)
function AlterFX.Burst(character: Model, theme, isLocal: boolean)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local size = character:GetExtentsSize()
	local feet = root.Position - Vector3.new(0, size.Y / 2 - 0.2, 0)
	local holder = Instance.new("Part")
	holder.Name = "AlterBurst"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(4, 0.1, 4)
	holder.CFrame = CFrame.new(feet)
	holder.Parent = Workspace
	-- the light
	local light = Instance.new("PointLight")
	light.Color = theme.accent
	light.Range = 30
	light.Brightness = 8
	light.Shadows = false
	light.Parent = holder
	tween(light, { Brightness = 0 }, 0.9)
	-- the ground shockwave (a decal on a growing flat part) and a fast outer ring
	for i, texture in ipairs({ "ground", "ring" }) do
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = TEX[texture]
		decal.Color3 = theme.accent
		decal.Transparency = 0
		local flat = holder:Clone()
		flat:ClearAllChildren()
		flat.Size = Vector3.new(3, 0.05, 3)
		flat.Parent = holder
		decal.Parent = flat
		local final = if i == 1 then 34 else 48
		tween(flat, { Size = Vector3.new(final, 0.05, final) }, if i == 1 then 0.8 else 0.5, Enum.EasingStyle.Quart)
		tween(decal, { Transparency = 1 }, if i == 1 then 0.9 else 0.55)
	end
	-- particles off the body
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, size.Y / 2, 0)
	attachment.Parent = holder
	local count = if isLocal then 26 else 14
	if lowGraphics() then count = math.floor(count / 2) end
	local burst = emitter(attachment, theme, { Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(18, 34), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }), Drag = 3,
		Acceleration = if (theme.particle and theme.particle.motion) == "fall" then Vector3.new(0, -20, 0) else Vector3.new(0, 6, 0) })
	burst:Emit(count)
	local sparks = emitter(attachment, { particle = { texture = "spark", color = Color3.new(1, 1, 1) }, accent = theme.accent },
		{ Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(30, 50), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }), Drag = 6 })
	sparks:Emit(if isLocal then 12 else 6)
	if not isLocal then
		-- other players hear the flash a little quieter, in 3D
		AlterFX.Sound("FlashBoom", { parent = holder, volume = 0.6 })
		AlterFX.Sound("FlashPunch", { parent = holder, volume = 0.5 })
	end
	Debris:AddItem(holder, 2.5)
end

-- energy gathering into the body: particles pulled inward + a rim glow (Highlight) in the accent color. Returns stop().
local function gather(character: Model, theme, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return function() end end
	local size = character:GetExtentsSize()
	local shell = Instance.new("Part")
	shell.Name = "AlterGather"
	shell.Shape = Enum.PartType.Ball
	shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch = true, false, false, false
	shell.Transparency = 1
	shell.Size = Vector3.one * (size.Y * 1.6)
	shell.CFrame = root.CFrame
	shell.Parent = Workspace
	local e = emitter(shell, theme, { Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Lifetime = NumberRange.new(0.45, 0.6), Speed = NumberRange.new(size.Y * 1.1, size.Y * 1.4),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.7, 1.1), NumberSequenceKeypoint.new(1, 0) }),
		Rate = if lowGraphics() then 18 else 36 })
	e.Enabled = true
	local highlight = Instance.new("Highlight")
	highlight.Name = "AlterGlow"
	highlight.FillColor = theme.accent
	highlight.OutlineColor = theme.accent
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	tween(highlight, { FillTransparency = 0.55, OutlineTransparency = 0 }, duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	return function()
		e.Enabled = false
		Debris:AddItem(shell, 0.7)
		tween(highlight, { FillTransparency = 1, OutlineTransparency = 1 }, 0.6)
		Debris:AddItem(highlight, 0.65)
	end
end

------------------------------------------------------------------------
-- The local transformation
------------------------------------------------------------------------
local running = false
function AlterFX.Running() return running end

-- info = { alter, name, bonus, finale, tierName?, instant? (the skin already changed: flash at once) }
-- hooks = { onFlash() (fire the ALTER action), onDone() }. Returns at once: controller.setReward(reward) adds the tier reward
-- (it comes with the server's "Altered" event) to the title card.
function AlterFX.Transform(theme, info, hooks)
	hooks = hooks or {}
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = Workspace.CurrentCamera
	running = true
	local controller = { reward = nil }
	function controller.setReward(reward)
		controller.reward = reward
		if controller.refresh then controller.refresh() end
	end
	task.spawn(function()
		local skipped = false

		local gui = Instance.new("ScreenGui")
		gui.Name = "AlterTransform"
		gui.DisplayOrder = 60
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.Parent = player:WaitForChild("PlayerGui")
		local skip = Instance.new("TextButton")
		skip.Text = ""
		skip.BackgroundTransparency = 1
		skip.Size = UDim2.fromScale(1, 1)
		skip.ZIndex = 20
		skip.Parent = gui
		skip.Activated:Connect(function() skipped = true end)
		local flash = Instance.new("Frame")
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 10
		flash.Parent = gui
		local bars = {}
		for i, y in ipairs({ 0, 1 }) do
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.AnchorPoint = Vector2.new(0, y)
			bar.Size = UDim2.fromScale(1, 0.09)
			bar.Position = UDim2.fromScale(0, if i == 1 then -0.09 else 1.09)
			bar.ZIndex = 9
			bar.Parent = gui
			tween(bar, { Position = UDim2.fromScale(0, y) }, 0.35)
			bars[i] = bar
		end

		-- the world goes dark (the glowing body stays bright), the music ducks and goes muffled
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "AlterFX_CC"
		cc.Parent = Lighting
		Audio.Duck(0.3, 0.4)
		Audio.Muffle(true, 0.4)

		-- waits that end early on a skip
		local function wait_(t)
			local t0 = os.clock()
			while os.clock() - t0 < t and not skipped do task.wait() end
		end

		-- the camera: in front of the body, slowly closer (put back at the end)
		local oldType = camera.CameraType
		local size = if character then character:GetExtentsSize() else Vector3.new(4, 6, 2)
		-- the camera angle: in front of the body if that's clear, else the clearest of a few angles around it; never through a
		-- wall (it stops short of whatever is in the way)
		local focus = if root then root.Position + Vector3.new(0, size.Y * 0.12, 0) else Vector3.zero
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local angle = 0
		if root then
			local best, bestRoom = 0, -1
			for _, a in ipairs({ 0, 30, -30, 60, -60, 100, -100, 180 }) do
				local dir = (root.CFrame * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(size.Y * 0.18, size.Y * 0.08, -size.Y * 1.7)).Position - focus
				local hit = Workspace:Raycast(focus, dir, params)
				local room = if hit then (hit.Position - focus).Magnitude / dir.Magnitude else 1
				if room > bestRoom + 0.05 then best, bestRoom = a, room end
				if room >= 1 then break end
			end
			angle = best
		end
		local function shot(distance, height)
			local want = (root.CFrame * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(size.Y * 0.18, size.Y * height, -size.Y * distance)).Position
			local hit = Workspace:Raycast(focus, want - focus, params)
			if hit then want = focus + (want - focus).Unit * math.max(3, (hit.Position - focus).Magnitude - 1) end
			return CFrame.lookAt(want, focus)
		end
		if root then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = shot(1.7, 0.05)
			tween(camera, { CFrame = shot(1.25, 0.1) }, if info.instant then 0.3 else 1.75, Enum.EasingStyle.Sine)
		end

		local stopGather = function() end
		if not info.instant then
			tween(cc, { Brightness = -0.18, Contrast = 0.15, Saturation = -0.55 }, 0.5)
			-- 1. slow motion: a heartbeat getting faster; 2. energy gathers in with a rising swell
			local beat = AlterFX.Sound("ChargeUp", { fadeIn = 0.2 })
			if beat then tween(beat, { PlaybackSpeed = 1.8 }, 1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
			local swell = AlterFX.Sound("Swell", { fadeIn = 0.6, delay = 0 })
			if swell then tween(swell, { PlaybackSpeed = 1.35 }, 1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
			if character then stopGather = gather(character, theme, 1.5) end
			wait_(1.6)
			-- 0.2 s of silence before the flash
			fadeOut(beat, 0.05)
			fadeOut(swell, 0.05)
			wait_(0.2)
		end

		-- 3. FLASH: the ALTER action goes now, so the new skin appears under the white
		if hooks.onFlash then task.spawn(hooks.onFlash) end
		stopGather()
		flash.BackgroundTransparency = 0
		cc.Brightness, cc.Contrast, cc.Saturation = 0.5, 0.2, 0.2
		AlterFX.Sound("FlashBoom")
		AlterFX.Sound("FlashPunch")
		AlterFX.Sound("Sparkle", { delay = 0.05 })
		if theme.finale then AlterFX.Sound("FinaleBoom", { delay = 0.08 }) end
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 2.5
		reverb.WetLevel = -4
		reverb.DryLevel = 0
		reverb.Parent = Audio.Group("AlterFX")
		Debris:AddItem(reverb, 3.5)
		if character then AlterFX.Burst(character, theme, true) end
		task.delay(0.15, function() tween(flash, { BackgroundTransparency = 1 }, 0.55) end)
		tween(cc, { Brightness = 0, Contrast = 0, Saturation = 0 }, 0.8)
		-- a short camera shake (not with Reduced Motion)
		if root and not reduced() then
			task.spawn(function()
				local base = camera.CFrame
				for i = 1, 8 do
					local a = (1 - i / 8) * 0.35
					camera.CFrame = base * CFrame.new(math.random(-10, 10) / 10 * a, math.random(-10, 10) / 10 * a, 0)
					task.wait(0.03)
				end
			end)
		end

		-- 4. the reveal: chime (a step higher every alter), the theme's sting and screen effect, a cheer
		task.delay(0.25, function()
			AlterFX.Sound("Chime", { pitch = 1 + AlterThemes.ChimeStep * ((info.alter or 1) - 1) })
			AlterFX.Sting(theme)
			AlterFX.Sound(if theme.finale then "CheerBig" else "Cheer", { delay = 0.2 })
			AlterFX.ScreenFX(gui, theme, theme.intro or "rise", 1.8)
		end)

		-- the title card ("ALTER 3: TANNED"), in the theme's style
		local card = Instance.new("Frame")
		card.BackgroundTransparency = 1
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.72)
		card.Size = UDim2.fromScale(0.9, 0.24)
		card.ZIndex = 11
		card.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Parent = card
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.62)
		title.FontFace = LUCKIEST
		title.TextScaled = true
		title.Text = "ALTER " .. tostring(info.alter) .. ": " .. string.upper(info.name or "")
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextTransparency = 1
		title.ZIndex = 12
		title.Parent = card
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(theme.title[1], theme.title[2])
		gradient.Parent = title
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 1
		stroke.Parent = title
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.64)
		sub.Size = UDim2.fromScale(1, 0.3)
		sub.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		sub.TextScaled = true
		sub.TextColor3 = Color3.new(1, 1, 1)
		sub.TextTransparency = 1
		sub.ZIndex = 12
		sub.Parent = card
		local subStroke = Instance.new("UIStroke")
		subStroke.Thickness = 2
		subStroke.Transparency = 1
		subStroke.Parent = sub
		local function subText()
			local text = "Gains x" .. string.format("%.2f", info.bonus or 1)
			local reward = controller.reward
			if theme.finale then
				text ..= " · TIER " .. tostring(info.tier or math.ceil((info.alter or 1) / 5)) .. " COMPLETE"
				if type(reward) == "table" and (reward.dnaTokens or 0) > 0 then text ..= " · +" .. reward.dnaTokens .. " DNA" end
			end
			sub.Text = text
		end
		controller.refresh = subText
		subText()
		task.delay(0.55, function()
			AlterFX.Sound("TitleHit")
			scale.Scale = 2
			tween(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
			title.TextTransparency, stroke.Transparency = 0, 0
			tween(sub, { TextTransparency = 0 }, 0.3)
			tween(subStroke, { Transparency = 0.2 }, 0.3)
			AlterFX.UIParticles(card, theme, 14, 0.1, { burst = true, peak = true, zIndex = 11 })
		end)
		skipped = false -- (a tap during the build-up only shortens it; the title still shows briefly)
		wait_(0.55 + 2.2)

		-- 5. back: title fades, camera returns, music back
		tween(title, { TextTransparency = 1 }, 0.35)
		tween(stroke, { Transparency = 1 }, 0.35)
		tween(sub, { TextTransparency = 1 }, 0.35)
		tween(subStroke, { Transparency = 1 }, 0.35)
		for i, bar in ipairs(bars) do tween(bar, { Position = UDim2.fromScale(0, if i == 1 then -0.09 else 1.09) }, 0.35) end
		camera.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
		Audio.Duck(1, 1)
		Audio.Muffle(false, 0.6)
		task.delay(0.9, function()
			cc:Destroy()
			gui:Destroy()
		end)
		running = false
		if hooks.onDone then task.spawn(hooks.onDone) end
	end)
	return controller
end

return AlterFX
