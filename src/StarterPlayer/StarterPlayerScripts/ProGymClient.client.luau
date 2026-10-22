-- ProGymClient: the glass door between the starter gym and the pro gym (Workspace.ProGym.GlassWall.GlassDoor).
-- Unlocked (Growth Spurt 3+ since prompt 58, or kept from when it opened at 2: Machines.GymLevel): the door's invisible Blocker stops colliding for you, and the glass leaves slide open
-- while you're near. Locked: the door stays shut (the lock and "Unlocks at Growth Spurt 3" sign show on it) and walking
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

-- (owner, 14 Oct: instance streaming) The door (GlassDoor, Atomic) is only on this device while you're near it, and it is a
-- NEW instance each time it streams back in: so it is looked up again whenever the one we have is gone, never waited for.
local door, blocker, leaves, locks, center, slide = nil, nil, {}, {}, Vector3.zero, 0
local function findDoor(): Model?
	local proGym = Workspace:FindFirstChild("ProGym")
	local wall = proGym and proGym:FindFirstChild("GlassWall")
	local found = wall and wall:FindFirstChild("GlassDoor")
	return if found and found:FindFirstChild("Blocker") then found else nil
end
local wasUnlocked = nil -- (declared here: a new door must get its collision and locks set again)
local function setup(found: Model)
	door = found
	blocker = found:FindFirstChild("Blocker") :: BasePart
	leaves, locks = {}, {}
	for _, leaf in ipairs(found:GetChildren()) do
		if leaf:IsA("Model") and leaf:GetAttribute("Side") then
			local parts = {}
			for _, part in ipairs(leaf:GetDescendants()) do
				if part:IsA("BasePart") then parts[part] = part.CFrame end
			end
			table.insert(leaves, { side = leaf:GetAttribute("Side"), parts = parts })
		elseif leaf.Name == "Lock" then
			table.insert(locks, leaf)
		end
	end
	center = blocker.Position
	slide = blocker.Size.Z / 2 - 0.2 -- each leaf slides this far into the wall
	wasUnlocked = nil
end

local function unlocked()
	local data = ClientData.Get()
	return data ~= nil and data.growthSpurts ~= nil and Machines.GymLevel(data) >= Machines.GymUnlock.Pro
end

local amount, lastNote = 0, 0
RunService.Heartbeat:Connect(function(dt)
	-- the door streamed out (or never came in yet): look for it again (cheap: three FindFirstChild)
	if not door or not door:IsDescendantOf(Workspace) then
		door = nil
		local found = findDoor()
		if not found then return end
		setup(found)
		amount = 0
	end
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
		Notify.Show("Reach Growth Spurt " .. Machines.GymUnlock.Pro .. " to enter the Pro Gym", nil, "progym")
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
