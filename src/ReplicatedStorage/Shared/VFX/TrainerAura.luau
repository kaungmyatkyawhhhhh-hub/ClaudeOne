-- TrainerAura (prompt 25, 21 Oct): the auras of the rare personal trainers (Config/Trainers look.aura), drawn by
-- TrainerFollowClient on its local trainer clones. Small on purpose (owner: max ~15 aura particles per trainer, no extra
-- shadows): a light without shadows, one or two emitters and a glow at the feet; the textures are AuraVFX's.
--   local h = TrainerAura.Build(model, "duke")   -- nil if the preset or the rig is missing
--   h:Update(now)        -- every frame (Atlas's orbiting sparkles)
--   h:SetLOD(level)      -- 0 full, 1 far (light + feet glow only), 2 off
--   h:Burst("chalk")     -- Duke's chalk puff from both hands
--   h:Destroy()
-- Presets:
--   duke   (Legendary) a warm gold glow + slow gold embers rising
--   volta  (Mythic)    red-purple energy wisps + small lightning crackles (the lightning flipbook tinted red / purple)
--   shadow (Secret)    dark purple smoke wisps drifting up, a faint purple glow at the feet
--   atlas  (Eternal)   a white-gold glow, small star sparkles slowly orbiting him, soft god rays from above, a shimmer left on
--                      the ground where he walks
local TEX = require(script.Parent.AuraVFX).Textures

local TrainerAura = {}
TrainerAura.__index = TrainerAura

local C = Color3.fromHex
local function NS(points)
	local keys = {}
	for _, p in ipairs(points) do table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(keys)
end
local function CS(a, b) return ColorSequence.new(a, b or a) end

-- particles alive at once = Rate x Lifetime (kept under ~15 per trainer, the bursts included; prompt 29: Build scales the
-- rates down so at most MAX_PARTICLES are alive)
local MAX_PARTICLES = 10
local PRESETS = {
	duke = { light = C("#FFC45A"), range = 10, brightness = 1.2, feet = C("#F6C75A"),
		emit = { { part = "UpperTorso", tex = "ember", color = CS(C("#FFE6A0"), C("#E8A020")), light = 1, rate = 3, life = { 2.6, 3.4 },
			size = NS({ { 0, 0.22 }, { 1, 0.08 } }), speed = { 0.5, 1.1 }, accel = Vector3.new(0, 0.6, 0), spread = 40 } } },
	volta = { light = C("#E8345A"), range = 10, brightness = 1.4, feet = C("#C83A9A"),
		emit = {
			{ part = "UpperTorso", tex = "wisp", flip = "Random", color = CS(C("#FF4A6A"), C("#9A4AD8")), light = 1, rate = 3, life = { 0.9, 1.3 },
				size = NS({ { 0, 1.2 }, { 1, 2 } }), transparency = NS({ { 0, 0.55 }, { 1, 1 } }), speed = { 0.6, 1.2 }, spread = 60 },
			{ part = "UpperTorso", tex = "lightning", flip = "Random", color = CS(C("#FF7AA0"), C("#B070FF")), light = 1, brightness = 3, rate = 2.5,
				life = { 0.15, 0.22 }, size = NS({ { 0, 1.3 }, { 1, 1.6 } }), speed = { 0, 0 }, rotation = true },
			{ part = "LowerTorso", tex = "spark", color = CS(C("#FFB0D0"), C("#B070FF")), light = 1, brightness = 3, rate = 3, life = { 0.4, 0.6 },
				size = NS({ { 0, 0.3 }, { 1, 0 } }), speed = { 2, 4 }, spread = 180 },
		} },
	shadow = { feetLight = C("#7A3FD0"), range = 9, brightness = 0.9, feet = C("#6E3FB0"), dark = true,
		emit = { { part = "UpperTorso", tex = "smoke", flip = "OneShot", color = CS(C("#3A2056"), C("#120A1C")), light = 0, brightness = 1.2, rate = 3.5,
			life = { 2.4, 3 }, size = NS({ { 0, 1.2 }, { 1, 2.8 } }), transparency = NS({ { 0, 1 }, { 0.2, 0.45 }, { 1, 1 } }), speed = { 0.8, 1.4 },
			spread = 35, accel = Vector3.new(0, 0.4, 0) } } },
	atlas = { light = C("#FFF3C4"), range = 14, brightness = 1.6, feet = C("#FFF3C4"), orbit = 5, rays = 3,
		emit = { { feet = true, tex = "spark", color = CS(C("#FFFFFF"), C("#F6C75A")), light = 1, brightness = 2.5, rate = 4, life = { 1, 1.4 },
			size = NS({ { 0, 0.3 }, { 0.5, 0.22 }, { 1, 0 } }), speed = { 0, 0.2 }, spread = 180 } } },
}
TrainerAura.Presets = PRESETS

local function emitter(parent, e, scale)
	local p = Instance.new("ParticleEmitter")
	p.LightInfluence = 0
	p.Texture = TEX[e.tex]
	if e.flip then
		p.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		p.FlipbookMode = Enum.ParticleFlipbookMode[e.flip]
		p.FlipbookStartRandom = e.flip ~= "OneShot"
		if e.flip == "OneShot" then p.FlipbookFramerate = NumberRange.new(16 / e.life[2]) else p.FlipbookFramerate = NumberRange.new(16, 22) end
	end
	p.Color = e.color
	p.LightEmission = e.light or 0
	p.Brightness = e.brightness or 1.5
	p.Rate = e.rate
	p.Lifetime = NumberRange.new(e.life[1], e.life[2])
	local keys = {}
	for _, k in ipairs(e.size.Keypoints) do table.insert(keys, NumberSequenceKeypoint.new(k.Time, k.Value * scale)) end
	p.Size = NumberSequence.new(keys)
	p.Transparency = e.transparency or NS({ { 0, 0.2 }, { 0.7, 0.4 }, { 1, 1 } })
	p.Speed = NumberRange.new(e.speed[1] * scale, e.speed[2] * scale)
	p.SpreadAngle = Vector2.new(e.spread or 0, e.spread or 0)
	p.EmissionDirection = Enum.NormalId.Top
	p.Acceleration = e.accel or Vector3.zero
	if e.rotation then p.Rotation = NumberRange.new(0, 360) end
	p.Parent = parent
	return p
end

function TrainerAura.Build(model: Model, presetName: string)
	local P = PRESETS[presetName]
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not P or not root or not humanoid then return nil end
	local height = humanoid.HipHeight + root.Size.Y / 2 -- (root centre above the feet)
	local scale = math.max(height / 3, 0.6)
	local self = setmetatable({ _owned = {}, _emitters = {}, _lod = 0, _orbit = {}, _root = root, _height = height, _scale = scale, _hands = {} }, TrainerAura)
	local function own(x) table.insert(self._owned, x) return x end

	local feet = own(Instance.new("Attachment"))
	feet.Name = "AuraFeet"
	feet.Position = Vector3.new(0, -height + 0.08, 0)
	feet.Parent = root
	-- the glow at the feet
	self._ground = own(emitter(feet, { tex = "ground", color = CS(P.feet), light = if P.dark then 0.4 else 0.8, rate = 0.7, life = { 2.2, 2.6 },
		size = NS({ { 0, 2.2 }, { 1, 2.8 } }), transparency = NS({ { 0, 1 }, { 0.3, if P.dark then 0.45 else 0.6 }, { 1, 1 } }), speed = { 0, 0 } }, scale))
	self._ground.LockedToPart = true
	self._ground.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	self._ground.Speed = NumberRange.new(0.01)
	self._ground.RotSpeed = NumberRange.new(20)
	-- the light (no shadows)
	local torso = model:FindFirstChild("UpperTorso")
	if P.light and torso then
		local light = own(Instance.new("PointLight"))
		light.Color, light.Range, light.Brightness, light.Shadows = P.light, P.range, P.brightness, false
		light.Parent = torso
		self._light = light
	elseif P.feetLight then
		local light = own(Instance.new("PointLight"))
		light.Color, light.Range, light.Brightness, light.Shadows = P.feetLight, P.range, P.brightness, false
		light.Parent = feet
		self._light = light
	end
	for _, e in ipairs(P.emit) do
		local parent = if e.feet then feet else model:FindFirstChild(e.part or "UpperTorso")
		if parent then table.insert(self._emitters, own(emitter(parent, e, scale))) end
	end
	-- Atlas: star sparkles slowly orbiting him (billboards moved in Update), soft god rays from above
	for i = 1, (P.orbit or 0) do
		local a = own(Instance.new("Attachment"))
		a.Name = "Orbit" .. i
		a.Parent = root
		local bill = Instance.new("BillboardGui")
		bill.Size = UDim2.fromScale(0.7 * scale, 0.7 * scale)
		bill.LightInfluence = 0
		bill.MaxDistance = 80
		bill.Adornee = a
		bill.Parent = a
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = TEX.spark
		img.ImageColor3 = if i % 2 == 0 then C("#F6C75A") else C("#FFFFFF")
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = bill
		table.insert(self._orbit, { attachment = a, image = img, phase = (i - 1) / P.orbit * math.pi * 2, tilt = (i % 3 - 1) * 0.35 })
	end
	if P.rays and torso then
		local head = model:FindFirstChild("Head") or torso
		self._rays = {}
		for i = 1, P.rays do
			local top = own(Instance.new("Attachment"))
			top.Position = Vector3.new((i - (P.rays + 1) / 2) * 1.1 * scale, 7 * scale, 0.4 * scale)
			top.Parent = root
			local bottom = own(Instance.new("Attachment"))
			bottom.Position = Vector3.new((i - (P.rays + 1) / 2) * 1.8 * scale, (head.Position.Y - root.Position.Y) + 0.4 * scale, 0)
			bottom.Parent = root
			local beam = own(Instance.new("Beam"))
			beam.Attachment0, beam.Attachment1 = top, bottom
			beam.Color = CS(C("#FFF3C4"), C("#FFE6A0"))
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Width0, beam.Width1 = 0.6 * scale, 2.4 * scale
			beam.Transparency = NS({ { 0, 1 }, { 0.35, 0.82 }, { 1, 1 } })
			beam.Segments = 2
			beam.Parent = root
			table.insert(self._rays, beam)
		end
	end
	-- (prompt 29: trainer lag) at most MAX_PARTICLES alive at once: the emitters' rates scaled down to fit (the feet glow
	-- counts too; the chalk puff is a short burst)
	local alive = self._ground.Rate * self._ground.Lifetime.Max
	local emitted = 0
	for _, e in ipairs(self._emitters) do emitted += e.Rate * e.Lifetime.Max end
	if emitted > 0 and alive + emitted > MAX_PARTICLES then
		local f = math.max(MAX_PARTICLES - alive, 1) / emitted
		for _, e in ipairs(self._emitters) do e.Rate *= f end
	end
	-- Duke's chalk puff (Burst only)
	if presetName == "duke" then
		for _, side in ipairs({ "LeftHand", "RightHand" }) do
			local hand = model:FindFirstChild(side)
			if hand then
				table.insert(self._hands, own(emitter(hand, { tex = "smoke", flip = "OneShot", color = CS(C("#FFFFFF"), C("#E6E6E0")), light = 0, brightness = 1.4,
					rate = 0, life = { 0.8, 1.1 }, size = NS({ { 0, 0.4 }, { 1, 1.2 } }), transparency = NS({ { 0, 0.35 }, { 1, 1 } }), speed = { 0.6, 1.4 },
					spread = 70 }, scale)))
			end
		end
	end
	return self
end

function TrainerAura:Update(now: number)
	if self._lod > 0 or #self._orbit == 0 then return end
	local s = self._scale
	for _, o in ipairs(self._orbit) do
		local a = now * 0.55 + o.phase
		local r = 2.6 * s
		o.attachment.Position = Vector3.new(math.cos(a) * r, (0.6 + o.tilt + 0.25 * math.sin(now * 0.9 + o.phase)) * s, math.sin(a) * r)
		o.image.ImageTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(now * 2.3 + o.phase * 3))
	end
end

function TrainerAura:SetLOD(level: number)
	if self._lod == level then return end
	self._lod = level
	for _, e in ipairs(self._emitters) do e.Enabled = level == 0 end
	self._ground.Enabled = level < 2
	if self._light then self._light.Enabled = level < 2 end
	for _, o in ipairs(self._orbit) do o.image.Visible = level == 0 end
	for _, beam in ipairs(self._rays or {}) do beam.Enabled = level == 0 end
end

function TrainerAura:Burst(kind: string)
	if self._lod > 0 then return end
	if kind == "chalk" then
		for _, e in ipairs(self._hands) do e:Emit(3) end
	end
end

function TrainerAura:Destroy()
	for _, x in ipairs(self._owned) do
		if x.Parent then x:Destroy() end
	end
	self._owned = {}
end

return TrainerAura
