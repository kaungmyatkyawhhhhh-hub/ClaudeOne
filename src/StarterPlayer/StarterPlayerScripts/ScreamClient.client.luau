-- ScreamClient (21 Oct): plays the lift screams ScreamService sends, from the screamer's head (3D: Config/Sounds range,
-- so only nearby players hear it). Another player's scream is muted by Settings "Others' Sounds" (Audio.OthersMuted).
-- Never the same clip twice in a row. Your own scream also gives a small camera shake (Config/Screams.Shake), never on Low
-- Graphics or Reduce Motion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Audio)
local ClientData = require(Shared.ClientData)
local Screams = require(Shared.Config.Screams)

local localPlayer = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Scream")

local lastIndex = {} -- [sound name] = the clip played last

local function shake(strength: number)
	local settings = ClientData.IsLoaded() and ClientData.Get().settings or {}
	if not Screams.Shake.Enabled or settings.lowGraphics == "On" or settings.reduceMotion == "On" then return end
	local camera = workspace.CurrentCamera
	local start = os.clock()
	local name = "ScreamShake"
	pcall(function() RunService:UnbindFromRenderStep(name) end)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = (os.clock() - start) / Screams.Shake.Seconds
		if t >= 1 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local s = strength * (1 - t) * 4
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * 2 * s), math.rad((math.random() - 0.5) * 2 * s), 0)
	end)
end

remote.OnClientEvent:Connect(function(player: Player, big: boolean)
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local name = if big then "ScreamBig" else "ScreamNormal"
	local sound = Audio.PlayAt(name, head, { avoid = lastIndex[name] })
	if sound then lastIndex[name] = sound:GetAttribute("IdIndex") end
	if player == localPlayer then shake(if big then Screams.Shake.BigStrength else Screams.Shake.Strength) end
end)
