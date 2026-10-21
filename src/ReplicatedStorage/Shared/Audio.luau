-- Audio (client): plays every sound through Config.Sounds with SoundGroups, random variants and pitch.
--   Audio.PlayUI(name) / Audio.Play2D(name)   2D (interface, genetics reveal, training feedback)
--   Audio.PlayAt(name, partOrAttachmentOrPosition)   3D at a machine, quieter with distance
--   Audio.StartMusic()                                 background music, low, loops the playlist (waits for the menu's track)
--   Audio.AdoptMenuMusic() / Audio.StopMenuMusic(t)    the loading screen / menu track: into the Music volume, faded out
--   Audio.SetVolumes(music, effects)                   player settings, 0-1 each
--   Audio.Duck(factor, fade) / Audio.Muffle(on, fade)   (prompt 22) music + gym sounds quieter / highs cut (Body Alter moments)
--   Audio.Group(name)                                  a SoundGroup ("AlterFX": the Body Alter layers, at the effects volume)
-- opts (optional): { volume = multiplier, pitch = multiplier }
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent:WaitForChild("Config"):WaitForChild("Sounds"))

local Audio = {}

-- Balanced mix: gameplay loudest, UI quieter, music low in the background.
local GROUP_VOLUME = { Gameplay = 0.9, UI = 0.55, Music = 0.22, AlterFX = 0.9 }
local volumes = { music = 1, effects = 1 }
local duck = 1 -- (Audio.Duck) music and gym sounds times this
local function groupVolume(name)
	local d = if name == "Music" or name == "Gameplay" then duck else 1
	return GROUP_VOLUME[name] * (name == "Music" and volumes.music or volumes.effects) * d
end
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
	group.Volume = groupVolume(name)
	groups[name] = group
	return group
end

local function applyVolumes()
	for name in pairs(GROUP_VOLUME) do
		getGroup(name).Volume = groupVolume(name)
	end
end

local function create(name, parent, opts)
	local def = Sounds[name]
	if not def then
		warn("[Audio] unknown sound " .. tostring(name))
		return nil
	end
	if #def.ids == 0 then return nil end -- an empty slot (the owner hasn't picked its id yet): silent
	opts = opts or {}
	local spread = def.pitch or 0
	local sound = Instance.new("Sound")
	sound.Name = name
	-- (opts.avoid: an index not to pick again, so a clip never plays twice in a row; the pick is on the IdIndex attribute)
	local index = rng:NextInteger(1, #def.ids)
	if opts.avoid and #def.ids > 1 and index == opts.avoid then index = index % #def.ids + 1 end
	sound.SoundId = "rbxassetid://" .. def.ids[index]
	sound:SetAttribute("IdIndex", index)
	sound.Volume = def.volume * (opts.volume or 1)
	sound.PlaybackSpeed = (def.basePitch or 1) * (opts.pitch or 1) * (1 + rng:NextNumber(-spread, spread))
	sound.SoundGroup = getGroup(def.group or "Gameplay")
	if def.range then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = def.range[1]
		sound.RollOffMaxDistance = def.range[2]
	end
	sound.Parent = parent
	sound.Looped = opts.loop == true
	sound:Play()
	if opts.loop then
		-- a loop lives until Audio.StopLoop
	elseif def.maxLength then
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

-- Settings "Other Players' Sounds" Off (13 Oct): sounds on another player's character or on a machine someone else is
-- lifting on stay quiet on this client.
Audio.OthersMuted = false
local function othersSound(where): boolean
	local Players = game:GetService("Players")
	local me = Players.LocalPlayer
	if not me then return false end
	local node = where
	while node and node ~= Workspace do
		if node:IsA("Model") then
			local owner = Players:GetPlayerFromCharacter(node)
			if owner then return owner ~= me end
			local userId = node:GetAttribute("UserId")
			if type(userId) == "number" then return userId ~= me.UserId end
		end
		node = node.Parent
	end
	return false
end

-- where: a BasePart, an Attachment or a Vector3
function Audio.PlayAt(name, where, opts)
	if Audio.OthersMuted and typeof(where) == "Instance" and othersSound(where) then return nil end
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

-- A looping sound on `where` (a BasePart or an Attachment) until Audio.StopLoop; nil when its slot is empty.
function Audio.Loop(name, where)
	if not where or not where.Parent then return nil end
	return create(name, where, { loop = true })
end

-- Fades a loop out (seconds, default 0.3) and removes it.
function Audio.StopLoop(sound, fade)
	if not sound or not sound.Parent then return end
	fade = fade or 0.3
	TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 }):Play()
	task.delay(fade, function() sound:Destroy() end)
end

function Audio.SetVolumes(music, effects)
	volumes.music = math.clamp(tonumber(music) or 1, 0, 1)
	volumes.effects = math.clamp(tonumber(effects) or 1, 0, 1)
	applyVolumes()
end

function Audio.Group(name)
	return getGroup(name)
end

-- (prompt 22) the music and gym sounds go to `factor` of their volume (1 = back), over `fade` seconds
function Audio.Duck(factor: number, fade: number?)
	duck = math.clamp(factor, 0, 1)
	for _, name in ipairs({ "Music", "Gameplay" }) do
		TweenService:Create(getGroup(name), TweenInfo.new(fade or 0.3), { Volume = groupVolume(name) }):Play()
	end
end

-- (prompt 22) slow motion: the highs of the music and gym sounds cut (an EqualizerSoundEffect on their groups)
function Audio.Muffle(on: boolean, fade: number?)
	for _, name in ipairs({ "Music", "Gameplay" }) do
		local group = getGroup(name)
		local eq = group:FindFirstChild("Muffle")
		if not eq then
			eq = Instance.new("EqualizerSoundEffect")
			eq.Name = "Muffle"
			eq.LowGain, eq.MidGain, eq.HighGain = 0, 0, 0
			eq.Parent = group
		end
		TweenService:Create(eq, TweenInfo.new(fade or 0.3), { HighGain = if on then -40 else 0, MidGain = if on then -12 else 0 }):Play()
	end
end

function Audio.GetVolumes()
	return volumes.music, volumes.effects
end

local musicStarted = false
local musicPlayer = nil
local area = nil
local playlist = nil -- ids for the current area
local trackIndex = 0 -- the playing track in the playlist

-- The tracks for an area (Config.Sounds.AreaMusic), or the whole Music list.
local function tracksFor(name)
	local areas = Sounds.AreaMusic
	return (areas and name and areas[name]) or Sounds.Music.ids
end

-- The loading screen's and main menu's track (Config.Sounds.MenuMusic): ReplicatedFirst.LoadingScreen starts it as
-- SoundService.MenuMusic before this module can load. Adopt puts it in the Music volume group (the player's setting);
-- Stop fades it out when the game starts (renamed at once, so the area music starts under the fade).
function Audio.AdoptMenuMusic()
	local sound = SoundService:FindFirstChild("MenuMusic")
	if sound and sound:IsA("Sound") then sound.SoundGroup = getGroup("Music") end
end
function Audio.StopMenuMusic(fadeTime: number?)
	local sound = SoundService:FindFirstChild("MenuMusic")
	if not (sound and sound:IsA("Sound")) then return end
	sound.Name = "MenuMusicFading"
	local fade = TweenService:Create(sound, TweenInfo.new(fadeTime or 1.2), { Volume = 0 })
	fade.Completed:Connect(function() sound:Destroy() end)
	fade:Play()
end

function Audio.StartMusic()
	if musicStarted then return end
	musicStarted = true
	-- (the menu's track plays until the game starts: the area music waits for it, then begins under its fade)
	if SoundService:FindFirstChild("MenuMusic") then
		task.spawn(function()
			while SoundService:FindFirstChild("MenuMusic") do task.wait(0.2) end
			musicStarted = false
			Audio.StartMusic()
		end)
		return
	end
	local def = Sounds.Music
	musicPlayer = Instance.new("Sound")
	musicPlayer.Name = "Music"
	musicPlayer.Volume = def.volume
	musicPlayer.SoundGroup = getGroup("Music")
	musicPlayer.Parent = SoundService
	playlist = tracksFor(area)
	trackIndex = 0
	-- the next track of the current area's list (in order, then from the first again)
	local function nextTrack()
		if #playlist == 0 then return end
		trackIndex = trackIndex % #playlist + 1
		musicPlayer.SoundId = "rbxassetid://" .. playlist[trackIndex]
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
		if playlist ~= tracks or #tracks == 0 then return end
		trackIndex = 1 -- (a new area starts its list from the first track; Ended then moves through the rest)
		musicPlayer.SoundId = "rbxassetid://" .. tracks[1]
		musicPlayer.TimePosition = 0
		musicPlayer:Play()
		TweenService:Create(musicPlayer, TweenInfo.new(1.2), { Volume = Sounds.Music.volume }):Play()
	end)
end

applyVolumes()
return Audio
