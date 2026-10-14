-- AuraClient (owner, 14 Oct): draws every player's aura on this client from their "Aura" attribute (Config.Auras;
-- AuraService decides who may wear what). Three layers of particles (Roblox's own particle textures), one soft light
-- and a thin column of light (a Beam), all sized from the character (its HumanoidRootPart), so a tiny new player and a
-- 7'0" mass monster both look right:
--   1 inner glow   on the upper torso: soft particles + the light      walking: half strength; lifting: full
--   2 outer energy  rising from the body (flames / smoke / mist / ...)   from 50% PUMP (the PumpMeter attribute)
--   3 sparks       bursting out + the column of light                   at 100% PUMP or while PUMPED (PumpedUntil)
-- A new personal record (the "AuraBurst" attribute, MachineService) bursts every layer once with a sound. Equipping an
-- aura shows it at full power for 3 s.
-- Other players: no aura beyond Auras.FarOff studs, only the inner glow from Auras.MidFrom, at most Auras.MaxShown at
-- once (the nearest), none with the Settings "Other players' auras" Off or Low graphics On. Half the particles on phones.
-- No Highlight instances.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Config.Auras)
local ClientData = require(Shared.ClientData)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local TEX = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
}
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local STEP = 0.15         -- seconds between updates
local FULL_AFTER_EQUIP = 3 -- seconds at full power after equipping

local rigs = {} -- [Player] = { character, id, scale, root, layers = { {emitter, base} ... }, light, beam, ... }

local function seq(points)
	local keys = {}
	for _, p in ipairs(points) do table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(keys)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.Rate = 0
	e.Enabled = false
	for k, v in pairs(props) do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

-- the layers for one aura on one character (scale s = the character's size, 1 = a normal Robloxian)
local function build(character, aura)
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso") or root
	if not root or not torso then return nil end
	local s = math.max(0.6, root.Size.Y / 2)
	local a, b = aura.colors[1], aura.colors[2]
	local style = aura.style
	local folder = Instance.new("Folder")
	folder.Name = "AuraFx"
	local made = { root = root, scale = s, parts = {}, layers = { {}, {}, {} } }
	local function add(layer, e, base)
		-- every emitter starts on the SURFACE of the upper torso and moves out (inside the body it would be hidden by the
		-- muscle meshes, on a mass monster too)
		e.Parent = torso
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		table.insert(made.layers[layer], { emitter = e, base = base })
		table.insert(made.parts, e)
	end

	-- 1: inner glow (soft, close to the body) + the light
	local glowColor = if style == "smoke" then ColorSequence.new(a, a:Lerp(Color3.new(0, 0, 0), 0.4)) else ColorSequence.new(a, b)
	add(1, emitter(torso, { Name = "AuraGlow", Texture = TEX.smoke, Color = glowColor, LightEmission = if style == "smoke" then 0.4 else 1,
		Size = seq({ { 0, 2.4 * s }, { 1, 4 * s } }), Transparency = seq({ { 0, 0.6 }, { 0.5, 0.72 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(0.2, 0.7), SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), ZOffset = -0.5,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume }), 9)
	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = a
	light.Range = 7 * s
	light.Brightness = 0
	light.Shadows = false
	light.Parent = torso
	made.light = light
	table.insert(made.parts, light)

	-- 2: the outer energy rising from the body
	local rise = { Name = "AuraRise", Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60) }
	if style == "flame" then
		rise.Texture, rise.Color, rise.LightEmission = TEX.fire, ColorSequence.new(b, a), 0.9
		rise.Size = seq({ { 0, 2.2 * s }, { 0.6, 1.6 * s }, { 1, 0 } })
		rise.Transparency = seq({ { 0, 0.15 }, { 0.7, 0.45 }, { 1, 1 } })
		rise.Lifetime, rise.Speed = NumberRange.new(0.6, 1), NumberRange.new(2.5 * s, 4.5 * s)
		rise.Acceleration, rise.SpreadAngle = Vector3.new(0, 9 * s, 0), Vector2.new(15, 15)
		add(2, emitter(root, rise), 48)
	elseif style == "smoke" then
		rise.Texture, rise.Color, rise.LightEmission = TEX.smoke, ColorSequence.new(b, a), 0.1
		rise.Size = seq({ { 0, 2 * s }, { 1, 4.2 * s } })
		rise.Transparency = seq({ { 0, 0.12 }, { 0.6, 0.5 }, { 1, 1 } })
		rise.LightInfluence = 0.7 -- (real smoke: lit by the room, so dark smoke still reads in a dark gym)
		rise.Lifetime, rise.Speed = NumberRange.new(1, 1.6), NumberRange.new(2 * s, 3.5 * s)
		rise.Acceleration, rise.SpreadAngle = Vector3.new(0, 4 * s, 0), Vector2.new(20, 20)
		add(2, emitter(root, rise), 26)
		-- a glowing core inside the smoke (the aura's color)
		add(2, emitter(root, { Name = "AuraEmbers", Texture = TEX.spark, Color = ColorSequence.new(a), LightEmission = 1,
			Size = seq({ { 0, 0.3 * s }, { 1, 0 } }), Transparency = seq({ { 0, 0.1 }, { 1, 1 } }), Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(2 * s, 4 * s), Acceleration = Vector3.new(0, 3 * s, 0), SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box }), 12)
	elseif style == "frost" then
		rise.Texture, rise.Color, rise.LightEmission = TEX.smoke, ColorSequence.new(b, a), 0.6
		rise.Size = seq({ { 0, 1.8 * s }, { 1, 3.6 * s } })
		rise.Transparency = seq({ { 0, 0.4 }, { 1, 1 } })
		rise.Lifetime, rise.Speed = NumberRange.new(1, 1.5), NumberRange.new(0.8 * s, 1.8 * s)
		rise.Acceleration, rise.SpreadAngle = Vector3.new(0, 1.5 * s, 0), Vector2.new(25, 25)
		add(2, emitter(root, rise), 22)
		add(2, emitter(root, { Name = "AuraFlakes", Texture = TEX.spark, Color = ColorSequence.new(b), LightEmission = 1,
			Size = seq({ { 0, 0.22 * s }, { 1, 0.1 * s } }), Transparency = seq({ { 0, 0.1 }, { 1, 1 } }), Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(0.5 * s, 1.5 * s), Acceleration = Vector3.new(0, -1 * s, 0), SpreadAngle = Vector2.new(180, 180),
			Shape = Enum.ParticleEmitterShape.Box }), 12)
	elseif style == "electric" then
		rise.Texture, rise.Color, rise.LightEmission = TEX.spark, ColorSequence.new(b, a), 1
		rise.Size = seq({ { 0, 0.9 * s }, { 1, 0 } })
		rise.Transparency = seq({ { 0, 0 }, { 1, 0.6 } })
		rise.Lifetime, rise.Speed = NumberRange.new(0.15, 0.32), NumberRange.new(6 * s, 11 * s)
		rise.SpreadAngle = Vector2.new(180, 180)
		add(2, emitter(root, rise), 50)
		add(2, emitter(torso, { Name = "AuraCharge", Texture = TEX.smoke, Color = ColorSequence.new(a), LightEmission = 1,
			Size = seq({ { 0, 1.6 * s }, { 1, 2.4 * s } }), Transparency = seq({ { 0, 0.75 }, { 1, 1 } }), Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(0, 0.5), Shape = Enum.ParticleEmitterShape.Box }), 10)
	elseif style == "stars" then
		rise.Texture, rise.Color, rise.LightEmission = TEX.spark, ColorSequence.new(b, a), 1
		rise.Size = seq({ { 0, 0 }, { 0.3, 0.55 * s }, { 0.7, 0.4 * s }, { 1, 0 } })
		rise.Transparency = seq({ { 0, 0.1 }, { 1, 0.3 } })
		rise.Lifetime, rise.Speed = NumberRange.new(1.2, 2), NumberRange.new(0.6 * s, 1.6 * s)
		rise.Acceleration, rise.SpreadAngle = Vector3.new(0, 0.8 * s, 0), Vector2.new(60, 60)
		add(2, emitter(root, rise), 30)
		add(2, emitter(root, { Name = "AuraNebula", Texture = TEX.smoke, Color = ColorSequence.new(a), LightEmission = 0.7,
			Size = seq({ { 0, 1.5 * s }, { 1, 3 * s } }), Transparency = seq({ { 0, 0.7 }, { 1, 1 } }), Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(0.5 * s, 1.2 * s), Acceleration = Vector3.new(0, 1 * s, 0), SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box }), 8)
	else -- toxic: a glowing green ooze bubbling up
		rise.Texture, rise.Color, rise.LightEmission = TEX.smoke, ColorSequence.new(a, b), 0.8
		rise.Size = seq({ { 0, 1 * s }, { 0.5, 2.2 * s }, { 1, 0.6 * s } })
		rise.Transparency = seq({ { 0, 0.25 }, { 1, 1 } })
		rise.Lifetime, rise.Speed = NumberRange.new(0.8, 1.3), NumberRange.new(1.5 * s, 3 * s)
		rise.Acceleration, rise.SpreadAngle = Vector3.new(0, 2 * s, 0), Vector2.new(20, 20)
		add(2, emitter(root, rise), 18)
		add(2, emitter(root, { Name = "AuraBubbles", Texture = TEX.spark, Color = ColorSequence.new(b), LightEmission = 1,
			Size = seq({ { 0, 0.25 * s }, { 1, 0.35 * s } }), Transparency = seq({ { 0, 0.2 }, { 1, 1 } }), Lifetime = NumberRange.new(0.8, 1.2),
			Speed = NumberRange.new(1.5 * s, 3 * s), Acceleration = Vector3.new(0, 2 * s, 0), SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box }), 10)
	end

	-- 3: sparks bursting out + a thin column of light through the body
	add(3, emitter(torso, { Name = "AuraSparks", Texture = TEX.spark, Color = ColorSequence.new(b, a), LightEmission = 1,
		Size = seq({ { 0, 0.6 * s }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 1, 0.4 } }), Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(8 * s, 14 * s), Drag = 3, SpreadAngle = Vector2.new(180, 180), Shape = Enum.ParticleEmitterShape.Box }), 32)
	local bottom = Instance.new("Attachment")
	bottom.Name = "AuraBeamBottom"
	bottom.Position = Vector3.new(0, -3 * s, 0)
	bottom.Parent = root
	local top = Instance.new("Attachment")
	top.Name = "AuraBeamTop"
	top.Position = Vector3.new(0, 4.5 * s, 0)
	top.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "AuraColumn"
	beam.Attachment0, beam.Attachment1 = bottom, top
	beam.Color = ColorSequence.new(a, b)
	beam.LightEmission, beam.LightInfluence = 1, 0
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 3.2 * s, 1.2 * s
	beam.Transparency = seq({ { 0, 1 }, { 0.15, 0.7 }, { 0.6, 0.78 }, { 1, 1 } })
	beam.Segments = 2
	beam.Enabled = false
	beam.Parent = root
	made.beam = beam
	for _, item in ipairs({ bottom, top, beam }) do table.insert(made.parts, item) end
	folder.Parent = character
	table.insert(made.parts, folder)
	return made
end

local function destroy(rig)
	if not rig then return end
	for _, item in ipairs(rig.parts) do item:Destroy() end
end

-- how strong each layer is (0 = off): l1, l2, l3
local function setLevels(rig, l1, l2, l3)
	local mult = if MOBILE then Auras.MobileRate else 1
	local levels = { l1, l2, l3 }
	for layer, list in ipairs(rig.layers) do
		for _, entry in ipairs(list) do
			local rate = entry.base * levels[layer] * mult
			entry.emitter.Rate = rate
			entry.emitter.Enabled = rate > 0
		end
	end
	rig.light.Brightness = 0.6 * l1 + 0.6 * l3
	rig.light.Enabled = l1 > 0
	rig.beam.Enabled = l3 > 0
end

local function burst(rig)
	for layer, count in ipairs({ 10, 24, 40 }) do
		for _, entry in ipairs(rig.layers[layer]) do entry.emitter:Emit(count) end
	end
end

local equippedAt = 0
local function update()
	local data = ClientData.IsLoaded() and ClientData.Get() or nil
	local settings = data and data.settings or {}
	local othersOn = settings.otherAuras ~= "Off" and settings.lowGraphics ~= "On"
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local now = Workspace:GetServerTimeNow()
	-- who gets an aura: me, plus the nearest others in range
	local wanted = {}
	local others = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local id = other:GetAttribute("Aura")
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if type(id) == "string" and Auras.ById[id] and root then
			if other == player then
				wanted[other] = 0
			elseif othersOn then
				local distance = (root.Position - eye).Magnitude
				if distance <= Auras.FarOff then table.insert(others, { player = other, distance = distance }) end
			end
		end
	end
	table.sort(others, function(x, y) return x.distance < y.distance end)
	for index = 1, math.min(#others, Auras.MaxShown) do wanted[others[index].player] = others[index].distance end
	-- drop the ones that went away
	for other, rig in pairs(rigs) do
		if wanted[other] == nil or rig.character ~= other.Character or rig.id ~= other:GetAttribute("Aura") or not rig.root.Parent then
			destroy(rig)
			rigs[other] = nil
		end
	end
	for other, distance in pairs(wanted) do
		local rig = rigs[other]
		local character = other.Character
		if not rig then
			local aura = Auras.ById[other:GetAttribute("Aura")]
			rig = build(character, aura)
			if rig then
				rig.character, rig.id = character, aura.id
				rigs[other] = rig
				if other == player then equippedAt = os.clock() end
			end
		elseif math.abs(rig.root.Size.Y / 2 - rig.scale) > 0.12 * rig.scale then
			-- the body changed size (a Growth Spurt): rebuild at the new size
			destroy(rig)
			rigs[other] = nil
			rig = nil
		end
		if rig then
			local pump = other:GetAttribute("PumpMeter")
			local pumpedUntil = other:GetAttribute("PumpedUntil")
			local lifting = type(pump) == "number"
			local pumped = type(pumpedUntil) == "number" and pumpedUntil > now
			local l1 = if lifting then 1 else 0.5
			local l2 = if lifting and (pump >= Auras.HalfPump or pumped) then 1 else 0
			local l3 = if lifting and (pump >= 0.999 or pumped) then 1 else 0
			if other == player and os.clock() - equippedAt < FULL_AFTER_EQUIP then l1, l2, l3 = 1, 1, 1 end
			if other ~= player and distance > Auras.MidFrom then l2, l3 = 0, 0 end -- (mid distance: the inner glow only)
			setLevels(rig, l1, l2, l3)
		end
	end
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < STEP then return end
	elapsed = 0
	update()
end)

-- a new personal record: burst once (and a sound, for anyone nearby)
local function watchBurst(other)
	other:GetAttributeChangedSignal("AuraBurst"):Connect(function()
		task.defer(function()
			local rig = rigs[other]
			if not rig then return end
			burst(rig)
			if other == player then
				Audio.Play2D("AuraBurst")
			elseif (rig.root.Position - (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or Vector3.zero)).Magnitude < 50 then
				Audio.PlayAt("AuraBurst", rig.root)
			end
		end)
	end)
	-- equipping a different aura: full power for a moment
	if other == player then
		other:GetAttributeChangedSignal("Aura"):Connect(function() equippedAt = os.clock() end)
	end
end
for _, other in ipairs(Players:GetPlayers()) do watchBurst(other) end
Players.PlayerAdded:Connect(watchBurst)
Players.PlayerRemoving:Connect(function(other)
	destroy(rigs[other])
	rigs[other] = nil
end)

-- Studio check: Workspace attribute TestAuraFull = true keeps my aura at full power (screenshots)
if RunService:IsStudio() then
	task.spawn(function()
		while true do
			task.wait(0.5)
			if Workspace:GetAttribute("TestAuraFull") == true then equippedAt = os.clock() end
		end
	end)
end
