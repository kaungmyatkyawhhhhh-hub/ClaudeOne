-- The pro gym (opens at Growth Spurt 2) is built in Studio right next to the starter gym (Workspace.ProGym, made with
-- tools/builders/Gyms.luau): they share a wall with a big glass window, so everyone can watch the pro gym, and a glass
-- door. You walk in (no teleport): ProGymClient slides the door open for players who have unlocked it and keeps the
-- door's invisible Blocker solid for everyone else. The server double-checks: a player who gets into the pro gym
-- before Growth Spurt 2 is put back outside the door, once (a per-player debounce), with "Reach Growth Spurt 2 to enter
-- the Pro Gym" (at most every 3 s). MachineService checks the gym on every machine too.
-- (Bug, 13 Oct: the zone still had the old pre-8-Oct size, MinX 37, so the strip by the door in the STARTER gym counted as
-- inside, and the "outside" spot (x 39.7) was in it too: standing there teleported you every 0.5 s. The zone is now
-- read from the pro gym's own Floor part, and the outside spot is checked to be clear of it.)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Machines = require(Config.Machines)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local ProGymService = {}

-- inside of the pro gym (replaced at Start by its Floor part's footprint) and the spot outside its door, in the starter
-- gym, a few studs clear of the zone
ProGymService.Bounds = { MinX = 45, MaxX = 113, MinZ = -89, MaxZ = -4 }
ProGymService.OutsideGap = 6     -- studs between the zone edge and the spot you're put on
ProGymService.Debounce = 1.5     -- seconds between two put-backs of the same player
ProGymService.MessageCooldown = 3
local OUTSIDE = CFrame.lookAt(Vector3.new(45 - 6, 0.15, -12.56), Vector3.new(0, 0.15, -12.56))

local welcomed = {}
local lastPutBack, lastMessage = {}, {}

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
		local now = os.clock()
		if now - (lastPutBack[player] or 0) < ProGymService.Debounce then return end
		lastPutBack[player] = now
		character:PivotTo(OUTSIDE + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		if now - (lastMessage[player] or -math.huge) >= ProGymService.MessageCooldown then
			lastMessage[player] = now
			Remotes.PlayerEvent:FireClient(player, "ProGymLocked", { spurts = unlock })
		end
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
	-- the zone = the pro gym floor's footprint; the outside spot just past the glass door, clear of it
	local floor = Workspace.ProGym:FindFirstChild("Shell") and Workspace.ProGym.Shell:FindFirstChild("Floor")
		or Workspace.ProGym:FindFirstChild("Floor", true)
	if floor and floor:IsA("BasePart") then
		local b = ProGymService.Bounds
		b.MinX, b.MaxX = floor.Position.X - floor.Size.X / 2, floor.Position.X + floor.Size.X / 2
		b.MinZ, b.MaxZ = floor.Position.Z - floor.Size.Z / 2, floor.Position.Z + floor.Size.Z / 2
	end
	local door = Workspace.ProGym:FindFirstChild("GlassWall") and Workspace.ProGym.GlassWall:FindFirstChild("GlassDoor")
	local blocker = door and door:FindFirstChild("Blocker")
	local doorZ = blocker and blocker.Position.Z or -12.56
	local outsideX = ProGymService.Bounds.MinX - ProGymService.OutsideGap
	OUTSIDE = CFrame.lookAt(Vector3.new(outsideX, 0.15, doorZ), Vector3.new(outsideX - 10, 0.15, doorZ))
	assert(not ProGymService.IsInside(OUTSIDE.Position), "[ProGymService] the outside spot is inside the pro gym zone")
	Players.PlayerRemoving:Connect(function(player)
		welcomed[player], lastPutBack[player], lastMessage[player] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do check(player, unlock) end
		end
	end)
end

return ProGymService
