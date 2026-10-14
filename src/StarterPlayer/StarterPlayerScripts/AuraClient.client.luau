-- AuraClient (owner, 14 Oct): draws every player's aura on this client with the owner's AuraVFX module
-- (Shared/VFX/AuraVFX). The server puts the worn aura's preset name on each character as "EquippedAura" (AuraService);
-- when it changes (or the character respawns) the old handle is destroyed and AuraVFX.Build makes the new one.
--   Power: not lifting = Auras.IdlePower (0.15); while lifting = the PUMP meter (the player's PumpMeter attribute, 0-1;
--          1 while PUMPED), set every time it changes.
--   Burst: a new personal record (the "AuraBurst" attribute, MachineService) or the pump reaching 100%, with the
--          AuraBurst sound.
--   LOD:   your own aura is always 0 (full); other players' 0 within Auras.FullLOD studs, 1 up to Auras.MidLOD, 2 beyond or
--          with the Settings "Others' Auras" Off / Low Graphics On.
--   Preview: while the Titles window's AURAS tab is open, your own character wears the picked aura at power 1 (the
--          "AuraPreview" attribute TitlesClient sets on the local player; a try-on, nothing is equipped).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Config.Auras)
local AuraVFX = require(Shared:WaitForChild("VFX"):WaitForChild("AuraVFX"))
local ClientData = require(Shared.ClientData)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer

-- load the effect textures once at start, so the first aura doesn't show blank cards while they download
task.spawn(function()
	local list = {}
	for _, id in ipairs(Auras.VFXTextures) do
		local decal = Instance.new("Decal")
		decal.Texture = id
		table.insert(list, decal)
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)
local LOD_EVERY = 0.25 -- seconds between distance checks
-- AuraVFX sizes the effect from the character once, when it's built; a body that changes size a lot afterwards (the
-- muscle meshes loading after a spawn, a Growth Spurt) gets the aura rebuilt, at most every RESIZE_EVERY seconds
local RESIZE_BY, RESIZE_EVERY = 0.25, 3

local handles = {} -- [Player] = { handle, character, preset, power, maxed }

local function presetFor(other: Player): string?
	if other == player then
		local preview = player:GetAttribute("AuraPreview")
		if type(preview) == "string" and AuraVFX.Presets[preview] then return preview end
	end
	local character = other.Character
	local preset = character and character:GetAttribute("EquippedAura")
	return if type(preset) == "string" and AuraVFX.Presets[preset] then preset else nil
end

-- the power for a player right now (the preview is always full)
local function powerOf(other: Player): number
	if other == player and player:GetAttribute("AuraPreview") then return 1 end
	local pump = other:GetAttribute("PumpMeter")
	if type(pump) ~= "number" then return Auras.IdlePower end -- (not on a machine)
	local pumpedUntil = other:GetAttribute("PumpedUntil")
	if type(pumpedUntil) == "number" and pumpedUntil > Workspace:GetServerTimeNow() then return 1 end
	return math.clamp(pump, 0, 1)
end

local function drop(other: Player)
	local entry = handles[other]
	if entry then
		entry.handle:Destroy()
		handles[other] = nil
	end
end

-- (re)build when the preset or the character changed, then set the power
local function refresh(other: Player)
	local character = other.Character
	local preset = presetFor(other)
	local entry = handles[other]
	if entry and (entry.character ~= character or entry.preset ~= preset or not character or not character.Parent) then
		drop(other)
		entry = nil
	end
	if not entry and preset and character and character:FindFirstChild("HumanoidRootPart") then
		local handle = AuraVFX.Build(character, preset)
		if handle then
			entry = { handle = handle, character = character, preset = preset, power = -1, maxed = false,
				size = character:GetExtentsSize(), builtAt = os.clock() }
			handles[other] = entry
		end
	end
	if not entry then return end
	local power = powerOf(other)
	if power ~= entry.power then
		entry.power = power
		entry.handle:SetPower(power)
	end
	-- the pump reaching 100% bursts once (it bursts again only after dropping below)
	local maxed = power >= 0.999 and other:GetAttribute("PumpMeter") ~= nil
	if maxed and not entry.maxed then entry.handle:Burst() end
	entry.maxed = maxed
end

local function watch(other: Player)
	local function hookCharacter(character)
		character:GetAttributeChangedSignal("EquippedAura"):Connect(function() refresh(other) end)
		task.defer(refresh, other)
	end
	if other.Character then hookCharacter(other.Character) end
	other.CharacterAdded:Connect(hookCharacter)
	other:GetAttributeChangedSignal("PumpMeter"):Connect(function() refresh(other) end)
	other:GetAttributeChangedSignal("PumpedUntil"):Connect(function() refresh(other) end)
	if other == player then
		player:GetAttributeChangedSignal("AuraPreview"):Connect(function() refresh(other) end)
	end
	-- a new personal record: burst + sound
	other:GetAttributeChangedSignal("AuraBurst"):Connect(function()
		local entry = handles[other]
		if not entry then return end
		entry.handle:Burst()
		if other == player then
			Audio.Play2D("AuraBurst")
		else
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root then Audio.PlayAt("AuraBurst", root) end
		end
	end)
end
for _, other in ipairs(Players:GetPlayers()) do watch(other) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(drop)

-- LOD by distance (yours always full), the Settings switch, and a rebuild when the body's size changed
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < LOD_EVERY then return end
	elapsed = 0
	local data = ClientData.IsLoaded() and ClientData.Get() or nil
	local settings = data and data.settings or {}
	local othersOn = settings.otherAuras ~= "Off" and settings.lowGraphics ~= "On"
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for other, entry in pairs(handles) do
		if not entry.character.Parent then
			drop(other)
		elseif os.clock() - entry.builtAt > RESIZE_EVERY and (function()
			local now = entry.character:GetExtentsSize()
			return math.abs(now.X / entry.size.X - 1) > RESIZE_BY or math.abs(now.Y / entry.size.Y - 1) > RESIZE_BY
		end)() then
			drop(other)
			refresh(other)
		elseif other == player then
			entry.handle:SetLOD(0)
		else
			local root = entry.character:FindFirstChild("HumanoidRootPart")
			local distance = root and (root.Position - eye).Magnitude or math.huge
			local lod = if not othersOn or distance > Auras.MidLOD then 2 elseif distance > Auras.FullLOD then 1 else 0
			entry.handle:SetLOD(lod)
		end
	end
end)
