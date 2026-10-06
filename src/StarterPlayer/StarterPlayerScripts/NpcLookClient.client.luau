-- NpcLookClient: Coach Dex and the visiting legends turn to face YOU, smoothly, every frame (client only: each player
-- sees them looking at themselves). Doing this on the server only updated a few times a second and looked laggy.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LOOK_RANGE = 14   -- studs: they notice you this close
local MAX_TURN = 70     -- degrees away from where they normally face (never turn toward the wall)
local TURN_SPEED = 14   -- higher = snappier (exponential smoothing per second)
local TAGS = { "Coach", "Legend" }

local player = Players.LocalPlayer
local npcs = {} -- [model] = { root, homeYaw, yaw }

local function track(npc)
	if npcs[npc] or not npc:IsA("Model") then return end
	local root = npc:FindFirstChild("HumanoidRootPart") or npc:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then return end
	local _, yaw = root.CFrame:ToEulerAnglesYXZ()
	npcs[npc] = { root = root, homeYaw = yaw, yaw = yaw }
end

for _, tag in ipairs(TAGS) do
	for _, npc in ipairs(CollectionService:GetTagged(tag)) do task.spawn(track, npc) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(npc) task.spawn(track, npc) end)
end

local function angleDiff(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	local alpha = 1 - math.exp(-TURN_SPEED * dt)
	for npc, info in pairs(npcs) do
		if not npc.Parent or not info.root.Parent then
			npcs[npc] = nil
			continue
		end
		local target = info.homeYaw
		if me then
			local offset = me.Position - info.root.Position
			if offset.Magnitude < LOOK_RANGE then
				local want = math.atan2(-offset.X, -offset.Z) -- facing the player
				if math.abs(angleDiff(want, info.homeYaw)) <= math.rad(MAX_TURN) then target = want end
			end
		end
		info.yaw += angleDiff(target, info.yaw) * alpha
		info.root.CFrame = CFrame.new(info.root.Position) * CFrame.Angles(0, info.yaw, 0)
	end
end)
