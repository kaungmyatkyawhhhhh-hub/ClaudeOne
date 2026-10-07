--[[
	Audio (client)
	All sound in the game. Built entirely from sound files that ship inside
	every Roblox client (rbxasset://sounds/...), so nothing can fail to load
	or be blocked by asset permissions:

	  engine    : Roblox's wind recording pitched way down, run through
	              distortion + EQ + tremolo. Pitch follows RPM, the tremolo gives
	              a lumpy idle that smooths out as revs rise, and a second
	              throttle-driven "growl" layer adds bite under load.
	  wind      : rushing air that grows with speed
	  tyres     : a high, filtered hiss/squeal while sliding
	  cut-ups   : swoosh + rising chime with the combo
	  crashes   : heavy impact + body thud, scaled by severity
	  backfire  : exhaust pops on high-rpm upshifts
	  UI        : button clicks
	  ambience  : low city night hum; reverb switches to "tunnel" inside the tunnel

	Any asset id put in Config.Sounds is checked at startup and replaces the
	built-in layer only if it actually loads.
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local Audio = {}

local BUILTIN = {
	wind = "rbxasset://sounds/action_falling.ogg",
	boom = "rbxasset://sounds/impact_explosion_03.mp3",
	thud = "rbxasset://sounds/action_jump_land.mp3",
	swoosh = "rbxasset://sounds/action_get_up.mp3",
	tick = "rbxasset://sounds/volume_slider.ogg",
}

-- ids from Config.Sounds that passed the load check (each slot may be a list)
local custom: { [string]: { string } } = {}

local function pickCustom(key: string): string?
	local list = custom[key]
	if list and #list > 0 then
		return list[math.random(1, #list)]
	end
	return nil
end
Audio.pickCustom = pickCustom

local function newSound(id: string, parent: Instance, volume: number, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped == true
	s.Parent = parent
	return s
end

local function effect(className: string, parent: Instance, props: { [string]: any }): Instance
	local e = Instance.new(className)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

---------------------------------------------------------------------
-- Startup: verify custom ids, set reverb, ambience
---------------------------------------------------------------------
function Audio.init()
	SoundService.AmbientReverb = Enum.ReverbType.City
	SoundService.DistanceFactor = 3.33 -- 1 stud ~= 0.3 m
	SoundService.RolloffScale = 0.6

	-- test-load every configured id (in parallel, during the loading screen)
	local probes: { [Sound]: string } = {}
	local list = {}
	for key, value in Config.Sounds do
		local ids = if type(value) == "table" then value elseif type(value) == "string" then { value } else {}
		for _, id in ids do
			if type(id) == "string" and id ~= "" then
				local probe = Instance.new("Sound")
				probe.SoundId = id
				probes[probe] = key
				table.insert(list, probe)
			end
		end
	end
	local ok = pcall(function()
		ContentProvider:PreloadAsync(list, function(contentId, status)
			for probe, key in probes do
				if probe.SoundId == contentId then
					if status == Enum.AssetFetchStatus.Success then
						custom[key] = custom[key] or {}
						table.insert(custom[key], contentId)
					else
						warn(`[CityLegends] sound {key} ({contentId}) did not load ({status.Name}); using the built-in sound`)
					end
				end
			end
		end)
	end)
	if not ok then
		warn("[CityLegends] could not preload sounds; using built-in audio")
	end
	for probe in probes do
		probe:Destroy()
	end
	Audio.startMusic()

	-- night city ambience: distant traffic / wind hum
	local amb = newSound(BUILTIN.wind, SoundService, 0.06, true)
	amb.Name = "Ambience"
	amb.PlaybackSpeed = 0.42
	effect("EqualizerSoundEffect", amb, { LowGain = 4, MidGain = -6, HighGain = -30 })
	amb:Play()

	-- tunnel reverb when the camera is inside the tunnel
	local C = Config.City
	local tx0 = CityLayout.HighwayStartX + C.TunnelStart
	local tx1 = tx0 + C.TunnelLength
	local inTunnel = false
	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local p = cam.CFrame.Position
		local now = p.X > tx0 and p.X < tx1 and math.abs(p.Z) < C.HighwayWidth / 2 + 2 and p.Y < 22
		if now ~= inTunnel then
			inTunnel = now
			SoundService.AmbientReverb = if now then Enum.ReverbType.StoneCorridor else Enum.ReverbType.City
		end
	end)
end

---------------------------------------------------------------------
-- One-shots
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Music: shuffled night-drive playlist, M to mute
---------------------------------------------------------------------
local musicSound: Sound? = nil
local musicMuted = false
function Audio.startMusic()
	local tracks = custom.Music
	if not tracks or #tracks == 0 or musicSound then
		return
	end
	local order = table.clone(tracks)
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local index = 1
	local m = newSound(order[1], SoundService, Config.Sounds.MusicVolume or 0.22)
	m.Name = "Music"
	musicSound = m
	m.Ended:Connect(function()
		index = index % #order + 1
		m.SoundId = order[index]
		m.TimePosition = 0
		m:Play()
	end)
	m:Play()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			Audio.toggleMusic()
		end
	end)
end

function Audio.toggleMusic()
	musicMuted = not musicMuted
	if musicSound then
		musicSound.Volume = if musicMuted then 0 else (Config.Sounds.MusicVolume or 0.22)
	end
end

function Audio.play(key: string, volume: number, speed: number?, parent: Instance?): Sound
	local id = pickCustom(key) or BUILTIN[key] or key
	local s = newSound(id, parent or SoundService, volume)
	s.PlaybackSpeed = speed or 1
	s:Play()
	Debris:AddItem(s, 4)
	return s
end

function Audio.click()
	Audio.play("tick", 0.35, 1.6)
end

-- cut-up reward: swoosh + a chime that climbs with the combo
function Audio.cutUp(combo: number, label: string?)
	if custom.CutUp then
		Audio.play("CutUp", 0.55, 0.95 + math.random() * 0.2)
	else
		Audio.play("swoosh", 0.55, 1.35 + math.random() * 0.15)
	end
	local pitch = 1.4 + math.min(combo, 12) * 0.08
	Audio.play("tick", 0.5, pitch)
	task.delay(0.07, function()
		Audio.play("tick", 0.35, pitch * 1.26)
	end)
	if label and string.find(label, "THREAD") then
		task.delay(0.14, function()
			Audio.play("tick", 0.35, pitch * 1.5)
		end)
	end
end

function Audio.crash(severity: number)
	local k = math.clamp(severity / 120, 0.15, 1)
	if custom.Crash then
		Audio.play("Crash", 0.35 + 0.65 * k, 0.95 + math.random() * 0.1)
		Audio.play("thud", 0.4 + 0.4 * k, 0.8)
		return
	end
	local boom = Audio.play("boom", 0.25 + 0.55 * k, 0.75 + math.random() * 0.1)
	effect("EqualizerSoundEffect", boom, { LowGain = 6, MidGain = 0, HighGain = -12 })
	Audio.play("thud", 0.6 + 0.4 * k, 0.8)
end

function Audio.backfire(parent: Instance?)
	local s = Audio.play("boom", 0.18, 2.3 + math.random() * 0.4, parent)
	effect("EqualizerSoundEffect", s, { LowGain = -4, MidGain = 4, HighGain = -6 })
	if parent then
		s.RollOffMaxDistance = 300
	end
end

-- big low "hit" for titles / cuts
function Audio.boom(volume: number?)
	if custom.Impact then
		Audio.play("Impact", volume or 0.55, 1)
		return
	end
	local s = Audio.play("boom", volume or 0.55, 0.55)
	effect("EqualizerSoundEffect", s, { LowGain = 8, MidGain = -4, HighGain = -20 })
	effect("ReverbSoundEffect", s, { DecayTime = 2.5, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -4 })
end

-- a real car screaming past (falls back to a whoosh)
function Audio.passBy(volume: number?)
	if custom.PassBy then
		Audio.play("PassBy", volume or 0.8, 1)
	else
		Audio.whoosh(volume, 1.5)
	end
end

function Audio.engineStart(parent: Instance?)
	if custom.EngineStart then
		Audio.play("EngineStart", 0.6, 1, parent)
	end
end

function Audio.whoosh(volume: number?, speed: number?)
	local s = Audio.play("wind", volume or 0.5, speed or 1.8)
	effect("EqualizerSoundEffect", s, { LowGain = -6, MidGain = 3, HighGain = 0 })
	task.delay(0.6, function()
		if s.Parent then
			s:Stop()
		end
	end)
end

---------------------------------------------------------------------
-- Engine
---------------------------------------------------------------------
export type Engine = {
	update: (self: Engine, rpm: number, throttle: number, speedFrac: number, slip: number, timeScale: number?) -> (),
	shift: (self: Engine, up: boolean) -> (),
	destroy: (self: Engine) -> (),
}

local CLASS_PITCH = { Sedan = 0.9, SUV = 0.82, Coupe = 1.0, Supercar = 1.08, Hypercar = 1.15 }

--[[
	parent: a BasePart for positional (3D) sound, or nil for 2D (the local
	player's own car always plays 2D so it sounds the same in every camera).
]]
function Audio.engine(class: string, parent: Instance?): Engine
	local holder = parent or SoundService
	local base = CLASS_PITCH[class] or 1
	local positional = parent ~= nil and parent:IsA("BasePart")

	local engineId = pickCustom("Engine")
	local squealId = pickCustom("TyreSqueal")
	local rumble = newSound(engineId or BUILTIN.wind, holder, 0, true)
	rumble.Name = "EngineRumble"
	local growl = newSound(BUILTIN.wind, holder, 0, true)
	growl.Name = "EngineGrowl"
	local wind = newSound(BUILTIN.wind, holder, 0, true)
	wind.Name = "SpeedWind"
	local tyres = newSound(squealId or BUILTIN.wind, holder, 0, true)
	tyres.Name = "TyreHiss"

	local usingCustom = engineId ~= nil
	local tremolo: TremoloSoundEffect? = nil
	if not usingCustom then
		effect("DistortionSoundEffect", rumble, { Level = 0.5 })
		effect("EqualizerSoundEffect", rumble, { LowGain = 9, MidGain = -2, HighGain = -28 })
		tremolo = effect("TremoloSoundEffect", rumble, { Depth = 0.45, Duty = 0.55, Frequency = 6 }) :: TremoloSoundEffect
	end
	effect("DistortionSoundEffect", growl, { Level = 0.72 })
	effect("EqualizerSoundEffect", growl, { LowGain = -4, MidGain = 7, HighGain = -18 })
	effect("EqualizerSoundEffect", wind, { LowGain = -2, MidGain = 0, HighGain = -4 })
	if not squealId then
		effect("EqualizerSoundEffect", tyres, { LowGain = -30, MidGain = -6, HighGain = 6 })
	end

	for _, s in { rumble, growl, wind, tyres } do
		if positional then
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 12
			s.RollOffMaxDistance = 420
		end
		s:Play()
	end

	local dip = 0
	local smoothRpm = 0.1
	local self = {} :: any

	function self.update(_, rpm: number, throttle: number, speedFrac: number, slip: number, timeScale: number?)
		local ts = timeScale or 1
		smoothRpm += (rpm - smoothRpm) * 0.25
		local r = math.clamp(smoothRpm - dip, 0.05, 1.1)
		dip = math.max(0, dip - 0.04)
		if usingCustom then
			-- recorded engine loop: pitch follows rpm, per-class character
			rumble.PlaybackSpeed = (0.62 + r * 1.05) * base * ts
			rumble.Volume = 0.5 + 0.3 * throttle
		else
			rumble.PlaybackSpeed = (0.26 + r * 0.6) * base * ts
			rumble.Volume = 0.5 + 0.2 * throttle
			if tremolo then
				-- lumpy idle, smooth at high revs
				tremolo.Frequency = 5 + r * 18
				tremolo.Depth = math.clamp(0.55 - r * 0.45, 0.08, 0.55)
			end
		end
		growl.PlaybackSpeed = (0.5 + r * 0.95) * base * ts
		growl.Volume = (0.08 + 0.42 * throttle) * math.clamp(r * 1.3, 0.2, 1) * (if usingCustom then 0.35 else 1)
		wind.PlaybackSpeed = (0.85 + speedFrac * 0.6) * ts
		wind.Volume = 0.55 * speedFrac ^ 1.8
		local squeal = math.clamp((slip - 8) / 40, 0, 1)
		if squealId then
			tyres.PlaybackSpeed = (0.95 + squeal * 0.1) * ts
			tyres.Volume = 0.55 * squeal
		else
			tyres.PlaybackSpeed = (2.4 + squeal * 0.4) * ts
			tyres.Volume = 0.3 * squeal
		end
	end

	function self.shift(_, up: boolean)
		if up then
			dip = 0.22
			if smoothRpm > 0.8 and math.random() < 0.6 then
				Audio.backfire(if positional then parent else nil)
			end
		end
	end

	function self.destroy(_)
		for _, s in { rumble, growl, wind, tyres } do
			s:Destroy()
		end
	end

	return self :: Engine
end

return Audio
