-- Audio (client): plays every sound through Config.Sounds with SoundGroups, random variants and pitch.
--   Audio.PlayUI(name) / Audio.Play2D(name)   2D (interface, genetics reveal, training feedback)
--   Audio.PlayAt(name, partOrAttachmentOrPosition)   3D at a machine, quieter with distance
--   Audio.StartMusic()                                 background music, low, loops the playlist
--   Audio.SetVolumes(music, effects)                   player settings, 0-1 each
-- opts (optional): { volume = multiplier, pitch = multiplier }
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent:WaitForChild("Config"):WaitForChild("Sounds"))

local Audio = {}

-- Balanced mix: gameplay loudest, UI quieter, music low in the background.
local GROUP_VOLUME = { Gameplay = 0.9, UI = 0.55, Music = 0.22 }
local volumes = { music = 1, effects = 1 }
local groups = {}
local rng = Random.new()

local function getGroup(name)
	local group = groups[name]
	if group then return group end
	group = SoundService:FindFirstChild(name)
	if not (group and group:IsA("SoundGroup")) then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	group.Volume = GROUP_VOLUME[name] * (name == "Music" and volumes.music or volumes.effects)
	groups[name] = group
	return group
end

local function applyVolumes()
	for name, base in pairs(GROUP_VOLUME) do
		getGroup(name).Volume = base * (name == "Music" and volumes.music or volumes.effects)
	end
end

local function create(name, parent, opts)
	local def = Sounds[name]
	if not def then
		warn("[Audio] unknown sound " .. tostring(name))
		return nil
	end
	opts = opts or {}
	local spread = def.pitch or 0
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. def.ids[rng:NextInteger(1, #def.ids)]
	sound.Volume = def.volume * (opts.volume or 1)
	sound.PlaybackSpeed = (def.basePitch or 1) * (opts.pitch or 1) * (1 + rng:NextNumber(-spread, spread))
	sound.SoundGroup = getGroup(def.group or "Gameplay")
	if def.range then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = def.range[1]
		sound.RollOffMaxDistance = def.range[2]
	end
	sound.Parent = parent
	sound:Play()
	if def.maxLength then
		local fade = math.min(0.15, def.maxLength / 3)
		task.delay(def.maxLength - fade, function()
			if sound.Parent then TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 }):Play() end
		end)
		Debris:AddItem(sound, def.maxLength + 0.1)
	else
		Debris:AddItem(sound, 6)
	end
	return sound
end

function Audio.Play2D(name, opts)
	return create(name, SoundService, opts)
end
Audio.PlayUI = Audio.Play2D

-- where: a BasePart, an Attachment or a Vector3
function Audio.PlayAt(name, where, opts)
	if typeof(where) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = where
		attachment.Parent = Workspace.Terrain
		Debris:AddItem(attachment, 6)
		where = attachment
	end
	if not where or not where.Parent then return nil end
	return create(name, where, opts)
end

function Audio.SetVolumes(music, effects)
	volumes.music = math.clamp(tonumber(music) or 1, 0, 1)
	volumes.effects = math.clamp(tonumber(effects) or 1, 0, 1)
	applyVolumes()
end

function Audio.GetVolumes()
	return volumes.music, volumes.effects
end

local musicStarted = false
function Audio.StartMusic()
	if musicStarted then return end
	musicStarted = true
	local def = Sounds.Music
	local player = Instance.new("Sound")
	player.Name = "Music"
	player.Volume = def.volume
	player.SoundGroup = getGroup("Music")
	player.Parent = SoundService
	local index = 0
	local function nextTrack()
		index = index % #def.ids + 1
		player.SoundId = "rbxassetid://" .. def.ids[index]
		player.TimePosition = 0
		player:Play()
	end
	player.Ended:Connect(nextTrack)
	nextTrack()
end

applyVolumes()
return Audio
