-- TownClient: the gym's glass entrance doors slide open while anyone stands near them (tag "SlidingDoor", the slide
-- distance is each panel's SlideX attribute; TownService turned their collisions off). Animated locally on every
-- client, so it costs no network.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local OPEN_RANGE = 9  -- studs from the doors
local SPEED = 3       -- open/close per second (0 → 1)

local closed = {} -- [panel] = closed CFrame
local amount = 0  -- 0 closed, 1 open

local function track(panel)
	if panel:IsA("BasePart") then closed[panel] = panel.CFrame end
end
for _, panel in ipairs(CollectionService:GetTagged("SlidingDoor")) do track(panel) end
CollectionService:GetInstanceAddedSignal("SlidingDoor"):Connect(track)
CollectionService:GetInstanceRemovedSignal("SlidingDoor"):Connect(function(panel) closed[panel] = nil end)

local function someoneNear()
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - Town.EntranceDoor).Magnitude < OPEN_RANGE then return true end
	end
	return false
end

RunService.Heartbeat:Connect(function(dt)
	if next(closed) == nil then return end
	local target = someoneNear() and 1 or 0
	if amount == target then return end
	amount = target > amount and math.min(1, amount + dt * SPEED) or math.max(0, amount - dt * SPEED)
	local eased = amount * amount * (3 - 2 * amount)
	for panel, cframe in pairs(closed) do
		if panel.Parent then
			panel.CFrame = cframe + Vector3.new((panel:GetAttribute("SlideX") or 0) * eased, 0, 0)
		end
	end
end)
