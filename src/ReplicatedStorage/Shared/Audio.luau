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
local musicPlayer = nil
local area = nil
local playlist = nil -- ids for the current area

-- The tracks for an area (Config.Sounds.AreaMusic), or the whole Music list.
local function tracksFor(name)
	local areas = Sounds.AreaMusic
	return (areas and name and areas[name]) or Sounds.Music.ids
end

function Audio.StartMusic()
	if musicStarted then return end
	musicStarted = true
	local def = Sounds.Music
	musicPlayer = Instance.new("Sound")
	musicPlayer.Name = "Music"
	musicPlayer.Volume = def.volume
	musicPlayer.SoundGroup = getGroup("Music")
	musicPlayer.Parent = SoundService
	playlist = tracksFor(area)
	local index = 0
	local function nextTrack()
		index = index % #playlist + 1
		musicPlayer.SoundId = "rbxassetid://" .. playlist[index]
		musicPlayer.TimePosition = 0
		musicPlayer:Play()
	end
	musicPlayer.Ended:Connect(nextTrack)
	nextTrack()
end

-- Area music: switching area fades the music out and starts that area's tracks.
function Audio.SetArea(name)
	if name == area then return end
	area = name
	if not musicPlayer then return end
	local tracks = tracksFor(name)
	if tracks == playlist then return end
	playlist = tracks
	local fade = TweenService:Create(musicPlayer, TweenInfo.new(0.8), { Volume = 0 })
	fade:Play()
	fade.Completed:Connect(function()
		if playlist ~= tracks then return end
		musicPlayer.SoundId = "rbxassetid://" .. tracks[1]
		musicPlayer.TimePosition = 0
		musicPlayer:Play()
		TweenService:Create(musicPlayer, TweenInfo.new(1.2), { Volume = Sounds.Music.volume }):Play()
	end)
end

applyVolumes()
return Audio
