-- The pro gym (opens at Growth Spurt 2). The room, its 11 machines and both doors are built in Studio
-- (Workspace.ProGymBuild, made with tools/builders/ProGym.luau). This service only runs the doors: the starter gym's
-- "Pro gym" door teleports you in from Growth Spurt 2 (a note before that), the pro gym's door takes you back.
-- MachineService runs the machines (tag "Machine").
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Machines = require(Config.Machines)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local ProGymService = {}

local CENTER = Vector3.new(0, 0.1, -150) -- the room's floor middle (see the builder)
local STARTER_ARRIVE = CFrame.lookAt(Vector3.new(24, 0.1, -16), Vector3.new(0, 0.1, -16))
local PRO_ARRIVE = CFrame.lookAt(CENTER + Vector3.new(-26, 0, 0), CENTER)

local lastUse = {}

local function teleport(player, cframe)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.Sit or root.Anchored then return false end
	character:PivotTo(cframe + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	return true
end

local function wire(prompt, onUse)
	Guard.OnTriggered(prompt, function(player)
		local now = os.clock()
		if now - (lastUse[player] or 0) < 1.5 then return end
		lastUse[player] = now
		onUse(player)
	end)
end

function ProGymService.Start()
	local build = Workspace:WaitForChild("ProGymBuild", 10)
	if not build then
		warn("[ProGymService] Workspace.ProGymBuild is missing: build it in Studio with tools/builders/ProGym.luau")
		return
	end
	local unlock = Machines.GymUnlock.Pro or 2
	local toPro = build:FindFirstChild("ProGymDoorPrompt", true)
	local toStarter = build:FindFirstChild("StarterDoorPrompt", true)
	if toPro then
		wire(toPro, function(player)
			local data = PlayerData.Get(player)
			if not data then return end
			if data.growthSpurts < unlock then
				Remotes.PlayerEvent:FireClient(player, "ProGymLocked", { spurts = unlock })
				return
			end
			if teleport(player, PRO_ARRIVE) then
				Remotes.PlayerEvent:FireClient(player, "ProGymEntered", {})
			end
		end)
	end
	if toStarter then
		wire(toStarter, function(player) teleport(player, STARTER_ARRIVE) end)
	end
	Players.PlayerRemoving:Connect(function(player) lastUse[player] = nil end)
end

return ProGymService
