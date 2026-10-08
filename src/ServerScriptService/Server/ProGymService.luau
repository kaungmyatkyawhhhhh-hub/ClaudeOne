-- The pro gym (opens at Growth Spurt 2) is built in Studio right next to the starter gym (Workspace.ProGym, made with
-- tools/builders/Gyms.luau): they share a wall with a big glass window, so everyone can watch the pro gym, and a glass
-- door. You walk in (no teleport): ProGymClient slides the door open for players who have unlocked it and keeps the
-- door's invisible Blocker solid for everyone else. The server double-checks: a player who gets into the pro gym
-- before Growth Spurt 2 is put back outside the door. MachineService checks the gym on every machine too.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Machines = require(Config.Machines)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local ProGymService = {}

-- inside of the pro gym (see the builder) and the spot just outside its door, in the starter gym
ProGymService.Bounds = { MinX = 37, MaxX = 93, MinZ = -73.5, MaxZ = -4 }
local OUTSIDE = CFrame.lookAt(Vector3.new(39.7, 0.15, -12.56), Vector3.new(0, 0.15, -12.56)) -- (by the glass door, bigger gyms 8 Oct night)

local welcomed = {}

function ProGymService.IsInside(position)
	local b = ProGymService.Bounds
	return position.X > b.MinX and position.X < b.MaxX and position.Z > b.MinZ and position.Z < b.MaxZ and position.Y < 20
end

local function check(player, unlock)
	local data = PlayerData.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not root or not humanoid or root.Anchored then return end
	if not ProGymService.IsInside(root.Position) then return end
	if data.growthSpurts < unlock then
		character:PivotTo(OUTSIDE + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		Remotes.PlayerEvent:FireClient(player, "ProGymLocked", { spurts = unlock })
	elseif not welcomed[player] then
		welcomed[player] = true
		Remotes.PlayerEvent:FireClient(player, "ProGymEntered", {})
	end
end

function ProGymService.Start()
	if not Workspace:WaitForChild("ProGym", 10) then
		warn("[ProGymService] Workspace.ProGym is missing: build it in Studio with tools/builders/Gyms.luau")
		return
	end
	local unlock = Machines.GymUnlock.Pro or 2
	Players.PlayerRemoving:Connect(function(player) welcomed[player] = nil end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do check(player, unlock) end
		end
	end)
end

return ProGymService
