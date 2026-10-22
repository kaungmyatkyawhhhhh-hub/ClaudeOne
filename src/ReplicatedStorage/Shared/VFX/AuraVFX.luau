-- AuraVFX v3  (ModuleScript, ReplicatedStorage.Shared.VFX.AuraVFX)
-- "Body-hugging" auras: effects come off EVERY body part's surface (rim glow, wisps, embers,
-- crackling lightning, billowing smoke, blood mist), so the aura follows the silhouette
-- instead of floating as blobs in front of the character. CLIENT-SIDE ONLY.
--
-- API (unchanged from v2)
--   local h = AuraVFX.Build(character, "storm")
--   h:SetPower(p)  -- 0..1 (0.15 idle, then follow the PUMP bar while lifting)
--   h:Burst()      -- PR / max pump burst
--   h:SetLOD(l)    -- 0 full, 1 mid (rim glow + ground only), 2 off
--   h:Destroy()
--
-- Textures: upload every PNG in Downloads\gym_arc_aura_vfx, find each ID with search_asset by
-- exact name, and fill TEX. Flipbooks must stay 1024x1024 (4x4 grids).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TEX = {
	rim       = "rbxassetid://138347218007327", -- rim_glow.png
	wisp      = "rbxassetid://136758735885193", -- wisp_flipbook_4x4.png
	flame     = "rbxassetid://90041400001838", -- flame_flipbook_4x4.png
	ember     = "rbxassetid://76009392745145", -- ember_dot.png
	lightning = "rbxassetid://80590302550492", -- lightning_flipbook_4x4.png
	smoke     = "rbxassetid://113405238797101", -- smoke_shaded_4x4.png
	droplet   = "rbxassetid://137490039482038", -- droplet.png
	spark     = "rbxassetid://82372237523631", -- spark_star.png
	ring      = "rbxassetid://131893925782949", -- shockwave_ring.png
	ground    = "rbxassetid://74138882329945", -- ground_circle.png
}

local C = Color3.fromRGB
-- style: what comes off the body.
--   flame     = flame tongues + wisps + embers
--   lightning = crackling bolts on every limb + sparks
--   smoke     = thick billowing smoke (+ a little glow)
--   glow      = bright rim halo + wisps + twinkles from the head
--   mist      = blood-red mist + falling droplets
local PRESETS = {
	ember      = { style = "flame",     main = C(255,140,30),  hot = C(255,200,110), tail = C(170,40,10) },
	frost      = { style = "glow",      main = C(120,205,255), hot = C(215,245,255), tail = C(50,110,210), smoke = C(190,225,255) },
	storm      = { style = "lightning", main = C(110,150,255), hot = C(210,225,255), tail = C(50,60,200) },
	golden     = { style = "glow",      main = C(255,195,60),  hot = C(255,235,160), tail = C(200,120,15) },
	titan      = { style = "flame",     main = C(255,55,20),   hot = C(255,190,70),  tail = C(110,0,0), accent = C(255,205,70) },
	inferno    = { style = "flame",     main = C(255,80,10),   hot = C(255,200,90),  tail = C(130,10,0), smoke = C(35,22,18) },
	blood_moon = { style = "mist",      main = C(200,0,15),    hot = C(255,60,60),   tail = C(60,0,0) },
	void       = { style = "smoke",     main = C(150,50,255),  hot = C(210,150,255), tail = C(40,0,80), smoke = C(45,10,80) },
	neon       = { style = "lightning", main = C(255,50,200),  hot = C(255,170,240), tail = C(40,230,255) },
	galaxy     = { style = "glow",      main = C(90,110,255),  hot = C(200,190,255), tail = C(140,70,255), smoke = C(25,25,70) },
	royal      = { style = "glow",      main = C(255,215,120), hot = C(255,250,230), tail = C(255,175,50) },
	toxic      = { style = "smoke",     main = C(120,255,40),  hot = C(210,255,150), tail = C(30,110,10), smoke = C(60,140,20) },
	shadow     = { style = "smoke",     main = C(70,70,85),    hot = C(150,150,170), tail = C(10,10,12), smoke = C(14,14,16), dark = true },
}

-- particles/sec for the WHOLE body at idle (power 0.15) and full power (1.0); split across body parts by area
local RATES = {
	rim        = { 14, 36 },
	flame      = { 4, 40 },
	wisp       = { 3, 26 },
	ember      = { 3, 22 },
	lightning  = { 2, 34 },
	smoke      = { 6, 34 },
	smokeLight = { 2, 10 },
	mist       = { 8, 40 },
	droplet    = { 0, 14 },
	twinkle    = { 2, 14 },
}

-- (prompt 61) "<preset>@<colour>": the preset with every colour turned to that colour's hue (Config/Style.AuraHues; a
-- STYLE aura colour). Made once per name.
local variants = {}
local function resolve(name: any)
	if PRESETS[name] then return PRESETS[name] end
	if variants[name] then return variants[name] end
	local presetName, colour = string.match(tostring(name), "^(.-)@(%a+)$")
	local P = presetName and PRESETS[presetName]
	local Style = require(script.Parent.Parent.Config.Style)
	local hue = colour and Style.AuraHues[colour]
	if not P or not hue then return nil end
	local out = {}
	for key, value in pairs(P) do
		if typeof(value) == "Color3" then
			local _, s, v = value:ToHSV()
			out[key] = Color3.fromHSV(hue.hue, s, v)
		else
			out[key] = value
		end
	end
	variants[name] = out
	return out
end

local function NS(pts)
	local k = {}
	for _, p in pts do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
local function CS3(a, b, c)
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.4, b), ColorSequenceKeypoint.new(1, c) })
end
local function smooth(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.Rate = 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

-- visible body parts (muscle meshes included), biggest first, max 10
local function bodyParts(character)
	local list = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9
			and not d:FindFirstAncestorOfClass("Accessory") then
			if d.Size.Magnitude > 0.4 then table.insert(list, d) end
		end
	end
	table.sort(list, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	while #list > 10 do table.remove(list) end
	return list
end

local AuraVFX = {}
AuraVFX.__index = AuraVFX

function AuraVFX.Build(character, auraName)
	local P = resolve(auraName)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not P or not hrp or not hum then return nil end

	local ext = character:GetExtentsSize()
	local s = math.max(ext.Y / 5, 0.5)
	local accent = P.accent or P.hot
	local dark = P.dark == true
	local style = P.style

	local self = setmetatable({ _layers = {}, _power = 0, _lod = 0, _owned = {}, _conns = {}, _mobile = 1 }, AuraVFX)
	local function own(x) table.insert(self._owned, x); return x end
	local function layer(name, e, share) table.insert(self._layers, { name = name, e = e, share = share }); return e end

	-- phones / low graphics get fewer particles
	if UserInputService.TouchEnabled then self._mobile = 0.6 end
	local ok, q = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	if ok and q > 0 and q <= 3 then self._mobile = math.min(self._mobile, 0.45) end

	local parts = bodyParts(character)
	local totalArea = 0
	for _, part in parts do
		local z = part.Size
		totalArea += z.X * z.Y + z.Y * z.Z + z.X * z.Z
	end

	local BOX, VOL, SURF, OUT = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume,
		Enum.ParticleEmitterShapeStyle.Surface, Enum.ParticleEmitterShapeInOut.Outward
	local GRID = Enum.ParticleFlipbookLayout.Grid4x4

	for _, part in parts do
		local z = part.Size
		local share = (z.X * z.Y + z.Y * z.Z + z.X * z.Z) / math.max(totalArea, 1e-3)
		local m = z.Magnitude
		local depth = -(math.max(z.X, z.Z) * 0.5 + 0.25) -- draw just behind this part

		-- RIM GLOW: soft halo hugging the part, behind it (every style)
		layer("rim", own(emitter(part, {
			Texture = TEX.rim, LightEmission = dark and 0.15 or 1, Brightness = dark and 1 or 1.6,
			LockedToPart = true, Shape = BOX, ShapeStyle = VOL,
			Color = ColorSequence.new(dark and P.smoke or P.main),
			Size = NS({ {0, m * 0.55}, {1, m * 0.7} }),
			Transparency = NS({ {0, 1}, {0.3, dark and 0.55 or 0.72}, {1, 1} }),
			Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360), ZOffset = depth,
		})), share)

		if style == "flame" then
			layer("flame", own(emitter(part, {
				Texture = TEX.flame, LightEmission = 0.8, Brightness = 1.4,
				FlipbookLayout = GRID, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
				FlipbookFramerate = NumberRange.new(20, 28), FlipbookStartRandom = true,
				Shape = BOX, ShapeStyle = SURF, ShapeInOut = OUT,
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				Color = CS3(P.hot, P.main, P.tail),
				Size = NS({ {0, 0.35 * s}, {0.35, 0.75 * s}, {1, 0.15 * s} }),
				Squash = NS({ {0, -0.4}, {1, -0.6} }),
				Transparency = NS({ {0, 1}, {0.15, 0.1}, {0.75, 0.4}, {1, 1} }),
				Lifetime = NumberRange.new(0.35, 0.55), Speed = NumberRange.new(0.6 * s, 1.4 * s),
				Acceleration = Vector3.new(0, 8 * s, 0), Drag = 2, ZOffset = depth * 0.6,
			})), share)
		end

		if style == "flame" or style == "glow" then
			layer("wisp", own(emitter(part, {
				Texture = TEX.wisp, LightEmission = 1, Brightness = 1.6,
				FlipbookLayout = GRID, FlipbookMode = Enum.ParticleFlipbookMode.Random,
				Shape = BOX, ShapeStyle = SURF, ShapeInOut = OUT,
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				Color = ColorSequence.new(P.hot, P.main),
				Size = NS({ {0, 0.5 * s}, {1, 0.9 * s} }),
				Transparency = NS({ {0, 1}, {0.2, 0.2}, {1, 1} }),
				Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0.5 * s, 1.2 * s),
				Acceleration = Vector3.new(0, 5 * s, 0), ZOffset = depth * 0.5,
			})), share)
		end

		if not dark then
			layer("ember", own(emitter(part, {
				Texture = TEX.ember, LightEmission = 1, Brightness = 3,
				Shape = BOX, ShapeStyle = SURF, ShapeInOut = OUT,
				Color = ColorSequence.new(accent),
				Size = NS({ {0, 0.14 * s}, {1, 0} }),
				Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(0.8 * s, 2.4 * s),
				Acceleration = Vector3.new(0, 2.5 * s, 0), Drag = 1.2,
				SpreadAngle = Vector2.new(25, 25),
			})), share)
		end

		if style == "lightning" then
			layer("lightning", own(emitter(part, {
				Texture = TEX.lightning, LightEmission = 1, Brightness = 4,
				FlipbookLayout = GRID, FlipbookMode = Enum.ParticleFlipbookMode.Random,
				LockedToPart = true, Shape = BOX, ShapeStyle = VOL,
				Color = ColorSequence.new(P.hot, P.main),
				Size = NS({ {0, m * 0.55}, {1, m * 0.65} }),
				Transparency = NS({ {0, 0}, {1, 0.4} }),
				Lifetime = NumberRange.new(0.07, 0.14), Speed = NumberRange.new(0),
				Rotation = NumberRange.new(0, 360), ZOffset = 0.2,
			})), share)
		end

		if style == "smoke" or P.smoke then
			local main = style == "smoke"
			layer(main and "smoke" or "smokeLight", own(emitter(part, {
				Texture = TEX.smoke, LightEmission = 0, Brightness = main and 1.2 or 0.9,
				FlipbookLayout = GRID, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Shape = BOX, ShapeStyle = SURF, ShapeInOut = OUT,
				Color = ColorSequence.new(P.smoke or P.tail),
				Size = NS({ {0, m * 0.45}, {1, m * 1.0} }),
				Transparency = NS({ {0, 1}, {0.2, main and 0.15 or 0.55}, {1, 1} }),
				Lifetime = NumberRange.new(0.9, 1.5), Speed = NumberRange.new(0.4 * s, 1.1 * s),
				Acceleration = Vector3.new(0, 1.6 * s, 0), Drag = 1,
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
				ZOffset = depth,
			})), share)
		end

		if style == "mist" then
			layer("mist", own(emitter(part, {
				Texture = TEX.smoke, LightEmission = 0.35, Brightness = 1.4,
				FlipbookLayout = GRID, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Shape = BOX, ShapeStyle = SURF, ShapeInOut = OUT,
				Color = CS3(P.hot, P.main, P.tail),
				Size = NS({ {0, m * 0.35}, {1, m * 0.8} }),
				Transparency = NS({ {0, 1}, {0.2, 0.35}, {1, 1} }),
				Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(0.3 * s, 0.9 * s),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), ZOffset = depth * 0.7,
			})), share)
			layer("droplet", own(emitter(part, {
				Texture = TEX.droplet, LightEmission = 0.3, Brightness = 1.5,
				Shape = BOX, ShapeStyle = SURF, ShapeInOut = OUT,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Color = ColorSequence.new(P.main),
				Size = NS({ {0, 0.12 * s}, {1, 0.08 * s} }),
				Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(1 * s, 3 * s),
				SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -30 * s, 0),
			})), share)
		end
	end

	-- twinkles from the head for glow auras
	local head = character:FindFirstChild("Head")
	if style == "glow" and head then
		local att = own(Instance.new("Attachment"))
		att.Parent = head
		layer("twinkle", own(emitter(att, {
			Texture = TEX.spark, LightEmission = 1, Brightness = 3,
			Color = ColorSequence.new(P.hot),
			Size = NS({ {0, 0}, {0.5, 0.35 * s}, {1, 0} }),
			Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(2 * s, 5 * s),
			SpreadAngle = Vector2.new(180, 180), Drag = 3, Rotation = NumberRange.new(0, 90),
		})), 1)
	end

	-- ground ring: world-aligned in Terrain, raycast to the floor (stays flat on benches)
	local feet = own(Instance.new("Attachment"))
	feet.Name = "AuraFeet"
	feet.Parent = workspace.Terrain
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { character }
	local function placeFeet()
		local o = hrp.Position
		local hit = workspace:Raycast(o, Vector3.new(0, -(ext.Y + 6), 0), rp)
		feet.WorldCFrame = CFrame.new(o.X, (hit and hit.Position.Y or o.Y - ext.Y * 0.5) + 0.08, o.Z)
	end
	placeFeet()
	self._ground = emitter(feet, {
		Texture = TEX.ground, LightEmission = dark and 0.3 or 0.8, LockedToPart = true,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Color = ColorSequence.new(dark and P.hot or P.main),
		Size = NS({ {0, 1.6 * s}, {1, 2.4 * s} }),
		Transparency = NS({ {0, 1}, {0.25, 0.6}, {1, 1} }),
		Lifetime = NumberRange.new(1.4), RotSpeed = NumberRange.new(35), Rotation = NumberRange.new(0, 360),
	})
	self._ring = emitter(feet, {
		Texture = TEX.ring, LightEmission = 1, LockedToPart = true,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Color = ColorSequence.new(accent),
		Size = NS({ {0, 0.5 * s}, {1, 9 * s} }), Transparency = NS({ {0, 0}, {1, 1} }),
		Lifetime = NumberRange.new(0.5),
	})
	table.insert(self._conns, RunService.Heartbeat:Connect(function()
		if self._lod < 2 and hrp.Parent then placeFeet() end
	end))

	self:SetPower(0.15)
	return self
end

function AuraVFX:_apply()
	local p, lod, m = self._power, self._lod, self._mobile
	local k = smooth(0.15, 1, p)
	for _, L in self._layers do
		local r = 0
		local def = RATES[L.name]
		if def and (lod == 0 or (lod == 1 and L.name == "rim")) then
			r = (def[1] + (def[2] - def[1]) * k) * L.share * m
			if lod == 1 then r *= 0.5 end
		end
		L.e.Rate = r
	end
	self._ground.Rate = lod < 2 and (0.8 + 0.8 * p) or 0
end

function AuraVFX:SetPower(p)
	self._power = math.clamp(p, 0, 1)
	self:_apply()
end

function AuraVFX:SetLOD(level)
	if level == self._lod then return end
	self._lod = level
	self:_apply()
end

local BURST = { ember = 10, lightning = 4, flame = 6, wisp = 4, smoke = 3, mist = 4, droplet = 6, twinkle = 10 }
function AuraVFX:Burst()
	if self._lod >= 2 then return end
	self._ring:Emit(1)
	if self._lod > 0 then return end
	for _, L in self._layers do
		local n = BURST[L.name]
		if n then L.e:Emit(math.max(1, math.floor(n * L.share * 4 * self._mobile))) end
	end
end

function AuraVFX:Destroy()
	for _, c in self._conns do c:Disconnect() end
	for _, x in self._owned do if x.Parent then x:Destroy() end end
	if self._ground then self._ground:Destroy() end
	if self._ring then self._ring:Destroy() end
end

AuraVFX.Presets = PRESETS
-- (prompt 61) a preset name the client can build: a preset, or "<preset>@<colour>"
function AuraVFX.Valid(name: any): boolean
	return type(name) == "string" and resolve(name) ~= nil
end
AuraVFX.Textures = TEX -- (prompt 25: the trainers' auras use the same textures, Shared.VFX.TrainerAura)
return AuraVFX
