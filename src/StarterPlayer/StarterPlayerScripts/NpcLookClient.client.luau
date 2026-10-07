-- NpcLookClient: how the NPCs (Workspace.NPCs) behave on YOUR screen (client only).
--  * Coach Dex and the visiting legends turn to face you, smoothly, every frame (each player sees them looking at
--    themselves). Doing this on the server only updated a few times a second and looked laggy.
--  * NPCs are not solid here: the Roblox camera zooms in front of anything solid, so a gym regular standing behind your
--    bench pushed the camera into your arm. You also walk through them instead of getting stuck at a machine.
--  * An NPC right next to the camera fades out, so the camera never looks into a head.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

------------------------------------------------------------------------
-- Not solid, and faded near the camera
------------------------------------------------------------------------
local FADE_NEAR, FADE_FAR = 2.5, 5 -- studs from the camera: fully faded / not faded
local MAX_FADE = 0.9

local function ghost(item)
	if not item:IsA("BasePart") then return end
	item.CanCollide = false
	-- (the server sets it again when it rebuilds an NPC's body)
	item:GetPropertyChangedSignal("CanCollide"):Connect(function()
		if item.CanCollide then item.CanCollide = false end
	end)
end

local faded = {} -- [model] = the fade it has now
local function setFade(model, amount)
	if (faded[model] or 0) == amount then return end
	faded[model] = amount > 0 and amount or nil
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then part.LocalTransparencyModifier = amount end
	end
end

local npcFolder = Workspace:WaitForChild("NPCs", 30)
if npcFolder then
	for _, item in ipairs(npcFolder:GetDescendants()) do ghost(item) end
	npcFolder.DescendantAdded:Connect(ghost)
end

local function fadeNearCamera()
	local camera = Workspace.CurrentCamera
	if not npcFolder or not camera then return end
	local eye = camera.CFrame.Position
	for _, npc in ipairs(npcFolder:GetChildren()) do
		local root = npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- distance to the body's middle line (head to feet), not just the root
			local offset = eye - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local vertical = math.max(math.abs(offset.Y) - 2.5, 0)
			local distance = math.sqrt(flat * flat + vertical * vertical)
			local amount = math.clamp((FADE_FAR - distance) / (FADE_FAR - FADE_NEAR), 0, 1) * MAX_FADE
			setFade(npc, math.floor(amount * 10 + 0.5) / 10) -- (steps of 0.1, so parts are only touched when it changes)
		elseif faded[npc] then
			faded[npc] = nil
		end
	end
	for model in pairs(faded) do
		if not model.Parent then faded[model] = nil end
	end
end

local function angleDiff(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

RunService.RenderStepped:Connect(function(dt)
	fadeNearCamera()
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
