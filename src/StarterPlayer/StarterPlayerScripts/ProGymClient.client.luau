-- ProGymClient: the glass door between the starter gym and the pro gym (Workspace.ProGym.GlassWall.GlassDoor).
-- Unlocked (Growth Spurt 2+): the door's invisible Blocker stops colliding for you, and the glass leaves slide open
-- while you're near. Locked: the door stays shut (the lock and "Unlocks at Growth Spurt 2" sign show on it) and walking
-- up to it shows a small corner note. (The sign itself is an AreaSign: AreaSignsClient shows its rule only while locked.) Everything here is local; ProGymService double-checks on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Machines = require(Shared.Config.Machines)
local ClientData = require(Shared.ClientData)
local Notify = require(Shared.UI.Notify)

local player = Players.LocalPlayer
local OPEN_RANGE = 9  -- studs
local NOTE_RANGE = 5
local SPEED = 3       -- open per second (0 -> 1)

local proGym = Workspace:WaitForChild("ProGym", 60)
local door = proGym and proGym:WaitForChild("GlassWall", 30) and proGym.GlassWall:WaitForChild("GlassDoor", 30)
if not door then return end

-- (the door streams in as one piece: GlassDoor.ModelStreamingMode = Atomic; until then wait quietly)
local blocker = door:WaitForChild("Blocker", math.huge)
local leaves = {}
for _, leaf in ipairs(door:GetChildren()) do
	if leaf:IsA("Model") and leaf:GetAttribute("Side") then
		local parts = {}
		for _, part in ipairs(leaf:GetDescendants()) do
			if part:IsA("BasePart") then parts[part] = part.CFrame end
		end
		table.insert(leaves, { side = leaf:GetAttribute("Side"), parts = parts })
	end
end
local locks = {}
for _, lock in ipairs(door:GetChildren()) do
	if lock.Name == "Lock" then table.insert(locks, lock) end
end
local center = blocker.Position
local slide = blocker.Size.Z / 2 - 0.2 -- each leaf slides this far into the wall

local function unlocked()
	local data = ClientData.Get()
	return data and data.growthSpurts ~= nil and data.growthSpurts >= (Machines.GymUnlock.Pro or 2)
end

local amount, wasUnlocked, lastNote = 0, nil, 0
RunService.Heartbeat:Connect(function(dt)
	local open = unlocked()
	if open ~= wasUnlocked then
		wasUnlocked = open
		blocker.CanCollide = not open
		-- the lock and the rule only show while it's locked
		for _, lock in ipairs(locks) do
			for _, part in ipairs(lock:GetDescendants()) do
				if part:IsA("BasePart") then part.LocalTransparencyModifier = open and 1 or 0 end
			end
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local distance = root and (root.Position - center).Magnitude or math.huge
	if not open and distance < NOTE_RANGE and os.clock() - lastNote > 8 then
		lastNote = os.clock()
		Notify.Show("The pro gym unlocks at Growth Spurt 2. Watch through the glass for now.", nil, "progym")
	end
	local target = (open and distance < OPEN_RANGE) and 1 or 0
	if amount == target then return end
	amount = target > amount and math.min(1, amount + dt * SPEED) or math.max(0, amount - dt * SPEED)
	local eased = amount * amount * (3 - 2 * amount)
	for _, leaf in ipairs(leaves) do
		for part, cframe in pairs(leaf.parts) do
			if part.Parent then part.CFrame = cframe + Vector3.new(0, 0, leaf.side * slide * eased) end
		end
	end
end)
