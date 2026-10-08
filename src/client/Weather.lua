--[[
	Weather (client)
	Night rain that comes and goes, run locally and cheap enough for phones:
	  * rain     : a few invisible emitter slabs ride above the camera (leading
	               it when you drive fast). Particles use the built-in default
	               texture squashed into thin slivers and aligned to their
	               velocity, so they read as falling streaks without any upload.
	  * splashes : one ground-level emitter under the camera flicks tiny flat
	               droplets up off the road
	  * wet roads: road + sidewalk slabs darken and gain a little gloss (the
	               originals are stored and restored as it dries). Changed in
	               10 steps over the fade, never per frame.
	  * mood     : denser haze, heavier clouds, a slightly darker, cooler grade
	  * sound    : a looping rain bed that fades with the weather
	  * cover    : rain stops in the tunnel / under big overhangs (one upward
	               ray every 0.3 s), and the near curtain is skipped in the
	               cockpit camera so no drops fall through the cabin
	Clear <-> rain alternates every 4-8 minutes; it is raining when you join.

	API: Weather.init(), Weather.setRaining(on, instant?), Weather.isRaining()
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WorldFx = require(script.Parent:WaitForChild("WorldFx"))
local Driving = require(script.Parent:WaitForChild("Driving"))
local Audio = require(script.Parent:WaitForChild("Audio"))

local Weather = {}

local FADE_TIME = 12 -- seconds for the rain to build up / clear away
local SPELL_MIN, SPELL_MAX = 240, 480 -- each clear / rainy spell lasts 4-8 minutes
local RAIN_SPEED = 105 -- studs/s
local NEAR_HALF = 32 -- dense curtain around the camera (half size)
local RING_HALF = 76 -- lighter outer ring (half size), higher quality only
local NEAR_UP = 26 -- spawn height above the camera
local RING_UP = 34
local NEAR_DENSITY = 0.12 -- particles per stud^2 per second at full quality
local RING_DENSITY = 0.026
local SPLASH_HALF = 28
local SPLASH_RATE = 150
local COVER_CHECK = 0.3
local RAIN_VOLUME = 0.32

-- wet look
local WET_TINT = Color3.fromRGB(6, 7, 10)
local ROAD_WET_REFLECTANCE = 0.16
-- rain mood
local RAIN_ATMO_COLOR = Color3.fromRGB(84, 92, 116)
local RAIN_ATMO_DECAY = Color3.fromRGB(40, 44, 64)
local RAIN_CLOUD_COLOR = Color3.fromRGB(34, 34, 48)
local RAIN_TINT = Color3.fromRGB(228, 236, 255)

type Emitter = { part: BasePart, emitter: ParticleEmitter, offset: Vector3, rate: number, on: boolean }
type Surface = { part: BasePart, color: Color3, reflectance: number, material: Enum.Material, road: boolean }

local started = false
local raining = false
local nextToggle = math.huge
local wet: NumberValue? = nil
local tween: Tween? = nil

local function randomSpell(): number
	return SPELL_MIN + math.random() * (SPELL_MAX - SPELL_MIN)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function kp(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end

---------------------------------------------------------------------
-- Emitters
---------------------------------------------------------------------
local function emitterPart(parent: Instance, name: string, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = parent
	return p
end

local function rainEmitter(part: BasePart, size: number): ParticleEmitter
	-- No Texture set: the built-in default particle squashed 3x and turned to
	-- face its velocity becomes a thin vertical sliver = a rain streak.
	local e = Instance.new("ParticleEmitter")
	e.Name = "Rain"
	e.Enabled = false
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Speed = NumberRange.new(RAIN_SPEED * 0.9, RAIN_SPEED * 1.1)
	e.SpreadAngle = Vector2.new(2, 2)
	e.Acceleration = Vector3.new(6, 0, 3) -- light cross wind slants the streaks
	e.Lifetime = NumberRange.new(0.5)
	e.Size = NumberSequence.new(size)
	e.Squash = NumberSequence.new(3)
	e.Rotation = NumberRange.new(0)
	e.Transparency = NumberSequence.new({ kp(0, 1), kp(0.12, 0.45), kp(1, 0.5) })
	e.Color = ColorSequence.new(Color3.fromRGB(196, 208, 232))
	e.LightEmission = 0.15
	e.LightInfluence = 0.35
	e.Brightness = 1.3
	e.Parent = part
	return e
end

local function splashEmitter(part: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Splash"
	e.Enabled = false
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.Lifetime = NumberRange.new(0.12, 0.22)
	e.Size = NumberSequence.new({ kp(0, 0.12), kp(1, 0.5) })
	e.Squash = NumberSequence.new(-1.5) -- wide + flat
	e.Transparency = NumberSequence.new({ kp(0, 0.3), kp(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(205, 214, 235))
	e.LightEmission = 0.2
	e.LightInfluence = 0.5
	e.Parent = part
	return e
end

---------------------------------------------------------------------
-- Wet roads: only the big road / sidewalk slabs the server builds
-- (City/Ground, City/Highway + Plaza, Block sidewalks, Skyline slabs)
---------------------------------------------------------------------
local surfaces: { Surface } = {}
local collected = false
local appliedWet = -1

local function bigSlab(p: BasePart): boolean
	local s = p.Size
	return p.Transparency < 0.5 and math.max(s.X * s.Z, s.X * s.Y, s.Y * s.Z) >= 2000
end

local function isRoad(p: BasePart): boolean
	if p.Material == Enum.Material.Asphalt then
		return true
	end
	local c = p.Color
	return p.Material == Enum.Material.SmoothPlastic and c.R + c.G + c.B < 0.36
end

local function collectSurfaces()
	local city = workspace:FindFirstChild("City")
	if not city then
		return
	end
	collected = true
	table.clear(surfaces)
	local function add(p: Instance, road: boolean)
		if p:IsA("BasePart") then
			table.insert(surfaces, { part = p, color = p.Color, reflectance = p.Reflectance, material = p.Material, road = road })
		end
	end
	local ground = city:FindFirstChild("Ground")
	if ground then
		for _, p in ground:GetChildren() do
			if p:IsA("BasePart") and bigSlab(p) then
				add(p, true)
			end
		end
	end
	local highway = city:FindFirstChild("Highway")
	if highway then
		for _, p in highway:GetChildren() do
			if p:IsA("BasePart") and bigSlab(p) and isRoad(p) then
				add(p, true)
			end
		end
		local plaza = highway:FindFirstChild("Plaza")
		if plaza then
			for _, p in plaza:GetChildren() do
				if p:IsA("BasePart") and bigSlab(p) then
					if p.Name == "Island" then
						add(p, false)
					elseif isRoad(p) then
						add(p, true)
					end
				end
			end
		end
	end
	local blocks = city:FindFirstChild("Blocks")
	if blocks then
		for _, block in blocks:GetChildren() do
			local sidewalk = block:FindFirstChild("Sidewalk")
			if sidewalk then
				add(sidewalk, false)
			end
		end
	end
	local skyline = city:FindFirstChild("Skyline")
	if skyline then
		for _, p in skyline:GetChildren() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Pavement and bigSlab(p) then
				add(p, false)
			end
		end
	end
end

local function applyRoads(level: number)
	local q = math.floor(level * 10 + 0.5) / 10
	if q == appliedWet then
		return
	end
	appliedWet = q
	if not collected then
		collectSurfaces()
	end
	for _, s in surfaces do
		local p = s.part
		if q <= 0 then
			p.Color = s.color
			p.Reflectance = s.reflectance
			p.Material = s.material
		elseif s.road then
			p.Color = s.color:Lerp(WET_TINT, 0.3 * q)
			p.Reflectance = lerp(s.reflectance, math.max(s.reflectance, ROAD_WET_REFLECTANCE), q)
			p.Material = if q >= 0.5 then Enum.Material.SmoothPlastic else s.material
		else
			p.Color = s.color:Lerp(WET_TINT, 0.35 * q)
			p.Reflectance = s.reflectance + 0.06 * q
		end
	end
end

---------------------------------------------------------------------
-- Mood: haze, clouds, exposure, grade (blended from the clear values)
---------------------------------------------------------------------
type Base = {
	atmo: Atmosphere?,
	density: number,
	haze: number,
	atmoColor: Color3,
	decay: Color3,
	clouds: Clouds?,
	cover: number,
	cloudDensity: number,
	cloudColor: Color3,
	exposure: number,
	outdoor: Color3,
	specular: number,
}
local base: Base? = nil
local grade: ColorCorrectionEffect? = nil

local function captureBase(): Base
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	return {
		atmo = atmo,
		density = if atmo then atmo.Density else 0,
		haze = if atmo then atmo.Haze else 0,
		atmoColor = if atmo then atmo.Color else Color3.new(),
		decay = if atmo then atmo.Decay else Color3.new(),
		clouds = clouds,
		cover = if clouds then clouds.Cover else 0,
		cloudDensity = if clouds then clouds.Density else 0,
		cloudColor = if clouds then clouds.Color else Color3.new(),
		exposure = Lighting.ExposureCompensation,
		outdoor = Lighting.OutdoorAmbient,
		specular = Lighting.EnvironmentSpecularScale,
	}
end

local function applyMood(w: number)
	local b = base
	if not b then
		return
	end
	local atmo = b.atmo
	if atmo and atmo.Parent then
		atmo.Density = lerp(b.density, b.density + 0.1, w)
		atmo.Haze = lerp(b.haze, b.haze + 1.2, w)
		atmo.Color = b.atmoColor:Lerp(RAIN_ATMO_COLOR, 0.5 * w)
		atmo.Decay = b.decay:Lerp(RAIN_ATMO_DECAY, 0.4 * w)
	end
	local clouds = b.clouds
	if clouds and clouds.Parent then
		clouds.Cover = lerp(b.cover, math.max(b.cover, 0.85), w)
		clouds.Density = lerp(b.cloudDensity, math.max(b.cloudDensity, 0.7), w)
		clouds.Color = b.cloudColor:Lerp(RAIN_CLOUD_COLOR, 0.5 * w)
	end
	Lighting.ExposureCompensation = b.exposure - 0.12 * w
	Lighting.OutdoorAmbient = b.outdoor:Lerp(Color3.new(0, 0, 0), 0.12 * w)
	Lighting.EnvironmentSpecularScale = lerp(b.specular, math.max(b.specular, 1), w)
	local g = grade
	if g then
		g.Saturation = -0.1 * w
		g.Contrast = 0.04 * w
		g.Brightness = -0.015 * w
		g.TintColor = Color3.new(1, 1, 1):Lerp(RAIN_TINT, w)
	end
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function Weather.isRaining(): boolean
	return raining
end

function Weather.setRaining(on: boolean, instant: boolean?)
	raining = on
	nextToggle = os.clock() + randomSpell()
	local value = wet
	if not value then
		return -- init() picks this up
	end
	if tween then
		tween:Cancel()
		tween = nil
	end
	local target = if on then 1 else 0
	if instant then
		value.Value = target
	else
		local t = TweenService:Create(value, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = target })
		tween = t
		t:Play()
	end
end

function Weather.init()
	if started then
		return
	end
	started = true

	-- density follows the player's graphics level (phones get far fewer drops)
	local quality = math.clamp((WorldFx.qualityScale() - 0.45) / 0.6, 0.3, 1)

	local folder = Instance.new("Folder")
	folder.Name = "WeatherFx"
	folder.Parent = workspace

	local near: Emitter
	do
		local size = Vector3.new(NEAR_HALF * 2, 1, NEAR_HALF * 2)
		local part = emitterPart(folder, "RainNear", size)
		near = { part = part, emitter = rainEmitter(part, 0.34), offset = Vector3.zero, rate = NEAR_DENSITY * size.X * size.Z * quality, on = false }
	end
	local ring: { Emitter } = {}
	if quality >= 0.6 then
		local mid = (NEAR_HALF + RING_HALF) / 2
		local depth = RING_HALF - NEAR_HALF
		local layout = {
			{ Vector3.new(RING_HALF * 2, 1, depth), Vector3.new(0, 0, -mid) },
			{ Vector3.new(RING_HALF * 2, 1, depth), Vector3.new(0, 0, mid) },
			{ Vector3.new(depth, 1, NEAR_HALF * 2), Vector3.new(-mid, 0, 0) },
			{ Vector3.new(depth, 1, NEAR_HALF * 2), Vector3.new(mid, 0, 0) },
		}
		for i, l in layout do
			local part = emitterPart(folder, "RainRing" .. i, l[1])
			table.insert(ring, { part = part, emitter = rainEmitter(part, 0.46), offset = l[2], rate = RING_DENSITY * l[1].X * l[1].Z * quality, on = false })
		end
	end
	local splash: Emitter
	do
		local part = emitterPart(folder, "Splashes", Vector3.new(SPLASH_HALF * 2, 0.2, SPLASH_HALF * 2))
		splash = { part = part, emitter = splashEmitter(part), offset = Vector3.zero, rate = SPLASH_RATE * quality, on = false }
	end
	local all: { Emitter } = { near, splash }
	for _, e in ring do
		table.insert(all, e)
	end

	local g = Instance.new("ColorCorrectionEffect")
	g.Name = "WeatherGrade"
	g.Parent = Lighting
	grade = g
	base = captureBase()

	local rainSound = Audio.rainLoop()
	local volume = 0

	local value = Instance.new("NumberValue")
	value.Name = "Wetness"
	value.Value = 0
	value.Parent = folder
	wet = value

	local function applyLevel()
		local w = value.Value
		for _, e in all do
			e.emitter.Rate = e.rate * w
		end
		applyMood(w)
		applyRoads(w)
	end
	value:GetPropertyChangedSignal("Value"):Connect(applyLevel)

	-- camera probes: overhead cover + ground height (sets the drop lifetime)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local covered = false
	local groundY = 0
	local probeTimer = 0
	local lifeNear, lifeRing = -1, -1
	local function probe(pos: Vector3)
		local ignore: { Instance } = { folder }
		for _, name in { "Traffic", "PlayerCars", "MonorailTrain", "Cutscene" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(ignore, f)
			end
		end
		params.FilterDescendantsInstances = ignore
		local up = workspace:Raycast(pos, Vector3.new(0, 160, 0), params)
		covered = false
		if up and up.Instance:IsA("BasePart") then
			local s = up.Instance.Size
			-- thin things overhead (rails, signs) don't count as a roof
			covered = math.max(s.X * s.Z, s.X * s.Y, s.Y * s.Z) >= 300
		end
		local down = workspace:Raycast(pos, Vector3.new(0, -400, 0), params)
		groundY = if down then down.Position.Y else 0
		local ln = math.clamp((pos.Y + NEAR_UP - groundY) / RAIN_SPEED, 0.2, 1.6)
		if math.abs(ln - lifeNear) > 0.03 then
			lifeNear = ln
			near.emitter.Lifetime = NumberRange.new(ln)
		end
		local lr = math.clamp((pos.Y + RING_UP - groundY) / RAIN_SPEED, 0.2, 1.6)
		if math.abs(lr - lifeRing) > 0.03 then
			lifeRing = lr
			for _, e in ring do
				e.emitter.Lifetime = NumberRange.new(lr)
			end
		end
	end

	local function setOn(e: Emitter, on: boolean)
		if e.on ~= on then
			e.on = on
			e.emitter.Enabled = on
		end
	end

	local lastPos: Vector3? = nil
	local camVel = Vector3.zero
	RunService.RenderStepped:Connect(function(dt: number)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local camCF = cam.CFrame
		local pos = camCF.Position
		if lastPos and dt > 0 then
			local v = (pos - lastPos) / dt
			if v.Magnitude > 600 then
				v = Vector3.zero -- camera cut, not motion
			end
			camVel = camVel:Lerp(Vector3.new(v.X, 0, v.Z), math.min(1, dt * 6))
		end
		lastPos = pos

		local level = value.Value
		local active = level > 0.01
		if active then
			probeTimer -= dt
			if probeTimer <= 0 then
				probeTimer = COVER_CHECK
				probe(pos)
			end
		end
		local open = active and not covered
		local interior = Driving.isDriving() and Driving.cameraMode == "Interior"
		setOn(near, open and not interior)
		setOn(splash, open)
		for _, e in ring do
			setOn(e, open)
		end

		if rainSound then
			local target = RAIN_VOLUME * level * (if covered then 0.3 elseif interior then 0.7 else 1)
			volume += (target - volume) * math.min(1, dt * 3)
			rainSound.Volume = volume
		end
		if not open then
			return
		end

		-- centre slightly ahead of the view and lead the camera when moving fast,
		-- so the world-space drops are already falling where you are going
		local look = camCF.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local ahead = if flat.Magnitude > 0.05 then flat.Unit * 14 else Vector3.zero
		local lead = camVel * math.clamp(lifeNear * 0.5, 0.1, 0.4)
		if lead.Magnitude > 70 then
			lead = lead.Unit * 70
		end
		local c = pos + ahead + lead
		near.part.CFrame = CFrame.new(c.X, pos.Y + NEAR_UP, c.Z)
		for _, e in ring do
			e.part.CFrame = CFrame.new(c.X + e.offset.X, pos.Y + RING_UP, c.Z + e.offset.Z)
		end
		splash.part.CFrame = CFrame.new(c.X, groundY + 0.15, c.Z)
	end)

	-- clear <-> rain cycle
	task.spawn(function()
		while true do
			task.wait(1)
			if os.clock() >= nextToggle then
				Weather.setRaining(not raining)
			end
		end
	end)

	-- the reference night is a rainy one: start wet
	Weather.setRaining(true, true)
	applyLevel()
end

return Weather
