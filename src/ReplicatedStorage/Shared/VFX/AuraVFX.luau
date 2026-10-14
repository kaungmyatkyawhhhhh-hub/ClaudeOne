-- AuraVFX  (ModuleScript, put in ReplicatedStorage.Shared.VFX.AuraVFX)
-- Builds the layered aura effect on a character, CLIENT-SIDE ONLY.
-- Every client builds auras locally from the replicated "EquippedAura" attribute.
--
-- API
--   local handle = AuraVFX.Build(character, "inferno")
--   handle:SetPower(p)   -- 0..1  (0.15 = idle, then follow the PUMP bar while lifting)
--   handle:Burst()       -- one-shot PR / max-pump burst
--   handle:SetLOD(l)     -- 0 = full, 1 = mid (glow + ground only), 2 = off
--   handle:Destroy()
--
-- Textures: the owner's PNGs from Downloads\gym_arc_aura_vfx (uploaded from Studio 14 Oct, so they're in the owner's own
-- inventory, not the Myanmar Builders Club group; Studio can only upload there). The flipbooks are 1024x1024 4x4 grids.

local RunService = game:GetService("RunService")

local TEX = {
	flame     = "rbxassetid://91013788221828", -- flame_flipbook_4x4.png (1024, Grid4x4)
	smoke     = "rbxassetid://105468903616816", -- smoke_flipbook_4x4.png (1024, Grid4x4)
	glow      = "rbxassetid://108461610476976", -- glow_soft.png
	spark     = "rbxassetid://82372237523631", -- spark_star.png
	streak    = "rbxassetid://84289295380894", -- energy_streak.png
	ring      = "rbxassetid://131893925782949", -- shockwave_ring.png
	ground    = "rbxassetid://74138882329945", -- ground_circle.png
	lightning = "rbxassetid://138403894498190", -- lightning_beam.png
}

type Preset = {
	core: Color3, main: Color3, tail: Color3, -- flame colour over its life
	accent: Color3?,                          -- sparks / ring / lightning (defaults to core)
	dark: boolean?,                           -- true = smoky, not glowing (LightEmission 0)
	smoke: Color3?,                           -- adds a smoke layer in this colour
	lightning: boolean?,                      -- adds crackling beams at high power
	stars: boolean?,                          -- extra twinkling sparkles
}

local C = Color3.fromRGB
local PRESETS: { [string]: Preset } = {
	ember      = { core = C(255,230,150), main = C(255,140,30),  tail = C(170,40,10) },
	frost      = { core = C(235,250,255), main = C(110,200,255), tail = C(40,90,200),  stars = true },
	storm      = { core = C(255,255,225), main = C(140,170,255), tail = C(60,60,200),  accent = C(255,250,190), lightning = true },
	golden     = { core = C(255,250,215), main = C(255,195,60),  tail = C(190,110,10), stars = true },
	titan      = { core = C(255,230,140), main = C(255,60,20),   tail = C(120,0,0),    accent = C(255,200,60) },
	inferno    = { core = C(255,240,170), main = C(255,90,10),   tail = C(140,10,0),   smoke = C(40,20,15) },
	blood_moon = { core = C(255,90,80),   main = C(190,0,10),    tail = C(40,0,0),     accent = C(255,40,30), dark = true, smoke = C(25,0,0) },
	void       = { core = C(220,160,255), main = C(130,40,255),  tail = C(25,0,50),    dark = true, smoke = C(30,0,60) },
	neon       = { core = C(255,255,255), main = C(255,40,190),  tail = C(40,255,255), accent = C(40,255,255), lightning = true },
	galaxy     = { core = C(220,230,255), main = C(80,110,255),  tail = C(150,70,255), stars = true },
	royal      = { core = C(255,255,255), main = C(255,215,110), tail = C(255,170,40), stars = true },
	toxic      = { core = C(230,255,170), main = C(120,255,40),  tail = C(30,110,10),  smoke = C(40,90,10) },
	-- (14 Oct tuning: shadow was nearly invisible in the dark gym; main / tail / smoke a little lighter)
	shadow     = { core = C(140,140,160), main = C(70,70,84),    tail = C(22,22,28),   accent = C(170,170,190), dark = true, smoke = C(18,18,22) },
}

local function NS(pts: { { number } }): NumberSequence
	local kps = {}
	for _, p in pts do table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(kps)
end

local function CS(a: Color3, b: Color3, c: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.35, b),
		ColorSequenceKeypoint.new(1, c),
	})
end

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.LockedToPart = false
	e.Rate = 0
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

local AuraVFX = {}
AuraVFX.__index = AuraVFX

function AuraVFX.Build(character: Model, auraName: string)
	local preset = PRESETS[auraName]
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not preset or not hrp or not hum then return nil end

	-- character size -> one scale number (a default R15 is ~5 studs tall)
	local ext = character:GetExtentsSize()
	local s = math.max(ext.Y / 5, 0.5)
	local accent = preset.accent or preset.core
	local glowLE = preset.dark and 0.35 or 1
	local flameLE = preset.dark and 0 or 0.9

	local folder = Instance.new("Folder")
	folder.Name = "AuraVFX"

	-- invisible volume around the body that flames/streaks emit from
	local vol = Instance.new("Part")
	vol.Name = "AuraVolume"
	vol.Size = Vector3.new(ext.X * 0.7, ext.Y * 0.75, ext.Z * 0.7)
	vol.Transparency = 1
	vol.CanCollide, vol.CanQuery, vol.CanTouch, vol.Massless = false, false, false, true
	vol.CastShadow = false
	vol.CFrame = hrp.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hrp, vol
	weld.Parent = vol
	vol.Parent = folder

	local feet = Instance.new("Attachment")
	feet.Name = "AuraFeet"
	feet.Position = Vector3.new(0, -(hrp.Size.Y / 2 + hum.HipHeight) + 0.1, 0)
	feet.Parent = hrp
	local core = Instance.new("Attachment")
	core.Name = "AuraCore"
	core.Parent = hrp

	local L: { [string]: any } = {}

	-- LAYER 1: inner glow + ground circle + light (always on while equipped)
	L.glow = emitter(core, {
		Texture = TEX.glow, LightEmission = glowLE, LockedToPart = true,
		Color = ColorSequence.new(preset.main),
		Size = NS({ {0, 2.6 * s}, {1, 3.2 * s} }),
		Transparency = NS({ {0, 1}, {0.3, 0.72}, {1, 1} }),
		Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
		ZOffset = -1,
	})
	L.ground = emitter(feet, {
		Texture = TEX.ground, LightEmission = glowLE, LockedToPart = true,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Color = ColorSequence.new(accent),
		Size = NS({ {0, 1.6 * s}, {1, 2.6 * s} }),
		Transparency = NS({ {0, 1}, {0.25, 0.45}, {1, 1} }),
		Lifetime = NumberRange.new(1.4), RotSpeed = NumberRange.new(35), Rotation = NumberRange.new(0, 360),
	})
	local light = Instance.new("PointLight")
	light.Color = preset.main
	light.Range = 10 * s
	light.Brightness = 0
	light.Shadows = false
	light.Parent = core
	L.light = light

	-- LAYER 2: rising flames + energy streaks (from 40% power)
	L.flame = emitter(vol, {
		Texture = TEX.flame, LightEmission = flameLE, Brightness = preset.dark and 1 or 2,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(18, 26), FlipbookStartRandom = true,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Color = CS(preset.core, preset.main, preset.tail),
		Size = NS({ {0, 0.9 * s}, {0.3, 1.7 * s}, {1, 0.4 * s} }),
		Squash = NS({ {0, -0.15}, {1, -0.35} }), -- taller than wide
		Transparency = NS({ {0, 1}, {0.12, 0.15}, {0.7, 0.45}, {1, 1} }),
		Lifetime = NumberRange.new(0.55, 0.85),
		Speed = NumberRange.new(1.5 * s, 3 * s), EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 7 * s, 0), Drag = 1.5,
		SpreadAngle = Vector2.new(8, 8), Rotation = NumberRange.new(-8, 8),
		ZOffset = 0.5,
	})
	L.streak = emitter(vol, {
		Texture = TEX.streak, LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Color = ColorSequence.new(preset.core, preset.main),
		Size = NS({ {0, 0.35 * s}, {1, 0.15 * s} }),
		Squash = NS({ {0, -1.6}, {1, -2.2} }),
		Transparency = NS({ {0, 1}, {0.2, 0.1}, {1, 1} }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(9 * s, 14 * s), EmissionDirection = Enum.NormalId.Top,
	})
	if preset.smoke then
		L.smoke = emitter(vol, {
			Texture = TEX.smoke, LightEmission = 0, Brightness = 1,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(preset.smoke),
			Size = NS({ {0, 1.4 * s}, {1, 3.2 * s} }),
			Transparency = NS({ {0, 1}, {0.2, 0.35}, {1, 1} }),
			Lifetime = NumberRange.new(1.1, 1.6),
			Speed = NumberRange.new(1 * s, 2 * s), EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
			ZOffset = -0.5,
		})
	end

	-- LAYER 3: sparks / stars / lightning (from 85% power)
	L.spark = emitter(vol, {
		Texture = TEX.spark, LightEmission = 1, Brightness = 3,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(accent),
		Size = NS({ {0, 0.35 * s}, {1, 0} }),
		Transparency = NS({ {0, 0}, {1, 0.3} }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(4 * s, 8 * s), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -6 * s, 0), Drag = 2,
		Rotation = NumberRange.new(0, 90),
	})
	if preset.stars then
		L.stars = emitter(vol, {
			Texture = TEX.spark, LightEmission = 1, Brightness = 2,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(preset.core),
			Size = NS({ {0, 0}, {0.5, 0.45 * s}, {1, 0} }),
			Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(0.3 * s),
			Rotation = NumberRange.new(0, 90), RotSpeed = NumberRange.new(-60, 60),
		})
	end
	-- one-shot burst pieces
	L.ring = emitter(feet, {
		Texture = TEX.ring, LightEmission = 1, LockedToPart = true,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Color = ColorSequence.new(accent),
		Size = NS({ {0, 0.5 * s}, {1, 9 * s} }),
		Transparency = NS({ {0, 0}, {1, 1} }),
		Lifetime = NumberRange.new(0.5),
	})

	-- lightning beams (storm / neon), only animated at high power + full LOD
	local beams: { Beam } = {}
	local beamAtts: { Attachment } = {}
	if preset.lightning then
		for i = 1, 3 do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = hrp, hrp
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = TEX.lightning
			b.TextureMode = Enum.TextureMode.Stretch
			b.LightEmission, b.LightInfluence = 1, 0
			b.FaceCamera = true
			b.Segments = 1
			b.Width0, b.Width1 = 0.6 * s, 0.6 * s
			b.Color = ColorSequence.new(accent)
			b.Enabled = false
			b.Parent = hrp
			table.insert(beams, b)
			table.insert(beamAtts, a0)
			table.insert(beamAtts, a1)
		end
	end

	folder.Parent = character

	local self = setmetatable({
		_L = L, _beams = beams, _atts = { feet, core }, _beamAtts = beamAtts,
		_folder = folder, _power = 0, _lod = 0, _s = s, _ext = ext, _conn = nil :: RBXScriptConnection?,
		_mobile = 1,
	}, AuraVFX)

	-- fewer particles on phones / low graphics
	local ok, q = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	if game:GetService("UserInputService").TouchEnabled then self._mobile = 0.6 end
	if ok and q > 0 and q <= 3 then self._mobile = math.min(self._mobile, 0.45) end

	if #beams > 0 then
		local acc = 0
		self._conn = RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc < 0.07 then return end
			acc = 0
			local on = self._lod == 0 and self._power >= 0.85
			for i, b in beams do
				local flick = on and math.random() < 0.6
				b.Enabled = flick
				if flick then
					local hx, hy = ext.X * 0.6, ext.Y * 0.45
					beamAtts[i * 2 - 1].Position = Vector3.new((math.random() - 0.5) * 2 * hx, (math.random() - 0.5) * 2 * hy, (math.random() - 0.5) * hx)
					beamAtts[i * 2].Position = Vector3.new((math.random() - 0.5) * 2 * hx, (math.random() - 0.5) * 2 * hy, (math.random() - 0.5) * hx)
				end
			end
		end)
	end

	self:SetPower(0.15)
	return self
end

function AuraVFX:_apply()
	local L, p, m = self._L, self._power, self._mobile
	local lod = self._lod
	local function rate(e: ParticleEmitter?, r: number)
		if e then e.Rate = r * m end
	end
	if lod >= 2 then
		for _, e in L do if typeof(e) == "Instance" and e:IsA("ParticleEmitter") then e.Rate = 0 end end
		L.light.Brightness = 0
		return
	end
	-- layer 1
	rate(L.glow, 3 + 5 * p)
	rate(L.ground, 0.8 + 0.8 * p)
	L.light.Brightness = 0.6 + 1.6 * p
	if lod >= 1 then
		rate(L.flame, 0); rate(L.streak, 0); rate(L.smoke, 0); rate(L.spark, 0); rate(L.stars, 0)
		return
	end
	-- layer 2 (fades in from 40% to 70% power)
	local l2 = smooth(0.4, 0.7, p)
	rate(L.flame, 4 + 36 * l2)          -- a few tiny flames even at idle
	rate(L.streak, 14 * l2)
	rate(L.smoke, 2 + 8 * l2)
	-- layer 3 (85% -> 100%)
	local l3 = smooth(0.85, 1, p)
	rate(L.spark, 30 * l3)
	rate(L.stars, 3 + 10 * l3)
end

function AuraVFX:SetPower(p: number)
	self._power = math.clamp(p, 0, 1)
	self:_apply()
end

function AuraVFX:SetLOD(level: number)
	if level == self._lod then return end
	self._lod = level
	self:_apply()
end

function AuraVFX:Burst()
	if self._lod >= 2 then return end
	local L = self._L
	L.ring:Emit(1)
	L.glow:Emit(3)
	if self._lod == 0 then
		L.flame:Emit(math.floor(24 * self._mobile))
		L.spark:Emit(math.floor(40 * self._mobile))
		L.streak:Emit(math.floor(16 * self._mobile))
	end
end

function AuraVFX:Destroy()
	if self._conn then self._conn:Disconnect() end
	for _, b in self._beams do b:Destroy() end
	for _, a in self._beamAtts do a:Destroy() end
	for _, a in self._atts do a:Destroy() end
	self._folder:Destroy()
end

AuraVFX.Presets = PRESETS
AuraVFX.Textures = TEX
return AuraVFX
