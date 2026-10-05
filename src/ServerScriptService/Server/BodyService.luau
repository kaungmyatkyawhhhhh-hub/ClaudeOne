-- Body scaling everyone can see: height comes from Growth Spurts (Roblox's height scale),
-- and each muscle group thickens its body parts as it levels up. Joints and attachments are
-- moved along with the parts so limbs and accessories stay connected.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Muscles = require(Config.Muscles)
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)

local BodyService = {}

local MAX_GROWTH = 0.35      -- a group at its level cap makes its parts up to 35% thicker
local BASE_HEIGHT = 60       -- inches that equal a height scale of 1
local REFRESH_EVERY = 1.5    -- seconds between muscle-size checks
local SETTLE_TIME = 0.35     -- wait for Roblox to finish rescaling after a height change

-- Which parts each group thickens, as (width X, depth Z) weights.
local GROUP_PARTS = {
	Chest = { UpperTorso = Vector2.new(0.4, 1) },
	Back = { UpperTorso = Vector2.new(1, 0.4) },
	Shoulders = { UpperTorso = Vector2.new(0.35, 0), RightUpperArm = Vector2.new(0.6, 0.6), LeftUpperArm = Vector2.new(0.6, 0.6) },
	Arms = {
		RightUpperArm = Vector2.new(1, 1), LeftUpperArm = Vector2.new(1, 1),
		RightLowerArm = Vector2.new(0.8, 0.8), LeftLowerArm = Vector2.new(0.8, 0.8),
	},
	Legs = {
		RightUpperLeg = Vector2.new(1, 1), LeftUpperLeg = Vector2.new(1, 1),
		RightLowerLeg = Vector2.new(0.8, 0.8), LeftLowerLeg = Vector2.new(0.8, 0.8),
	},
	Core = { LowerTorso = Vector2.new(1, 0.8) },
}

local bodies = {} -- [player] = { character, parts = { [part] = original }, joints, attachments, applied }

local function heightScale(data)
	return GrowthSpurts.GetHeight(data.growthSpurts) / BASE_HEIGHT
end

-- Per-part (X, Z) thickness multipliers from the current group levels.
local function partScales(data)
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	local scales = {}
	for groupId, parts in pairs(GROUP_PARTS) do
		local growth = MAX_GROWTH * math.clamp(Muscles.GetGroupLevel(data.muscles, groupId) / cap, 0, 1)
		for partName, weight in pairs(parts) do
			local s = scales[partName] or Vector2.new(1, 1)
			scales[partName] = s + weight * growth
		end
	end
	return scales
end

local function scaleOffset(cframe, sx, sz)
	local p = cframe.Position
	return CFrame.new(p.X * sx, p.Y, p.Z * sz) * cframe.Rotation
end

-- Remember the unscaled sizes, joint offsets and attachment positions.
local function capture(player, character)
	local body = { character = character, parts = {}, joints = {}, attachments = {}, applied = {} }
	for partName in pairs((function()
		local names = {}
		for _, parts in pairs(GROUP_PARTS) do for name in pairs(parts) do names[name] = true end end
		return names
	end)()) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			body.parts[part] = part.Size
			part:SetAttribute("OriginalSize", part.Size) -- before muscle thickening (the progress mirror's day-one body)
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Attachment") then body.attachments[child] = child.CFrame end
			end
		end
	end
	for _, motor in ipairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") then body.joints[motor] = { C0 = motor.C0, C1 = motor.C1 } end
	end
	bodies[player] = body
	return body
end

local function apply(player)
	local body = bodies[player]
	local data = PlayerData.Get(player)
	if not body or not data or not body.character.Parent then return end
	local scales = partScales(data)

	local changed = false
	for part, original in pairs(body.parts) do
		local s = scales[part.Name] or Vector2.new(1, 1)
		local last = body.applied[part]
		if not last or (last - s).Magnitude > 0.004 then
			body.applied[part] = s
			changed = true
			part.Size = Vector3.new(original.X * s.X, original.Y, original.Z * s.Y)
			part:SetAttribute("BaseSize", part.Size) -- the client pump grows from this
			for attachment, cframe in pairs(body.attachments) do
				if attachment.Parent == part then attachment.CFrame = scaleOffset(cframe, s.X, s.Y) end
			end
		end
	end
	if changed then
		-- move joint offsets out with the thicker parts (e.g. shoulders on a wider torso)
		for motor, original in pairs(body.joints) do
			if motor.Parent then
				local s0 = body.applied[motor.Part0] or Vector2.new(1, 1)
				local s1 = body.applied[motor.Part1] or Vector2.new(1, 1)
				motor.C0 = scaleOffset(original.C0, s0.X, s0.Y)
				motor.C1 = scaleOffset(original.C1, s1.X, s1.Y)
			end
		end
	end
end

-- Height scale -> let Roblox rescale -> capture the new base -> thicken by muscle levels.
local function rebuild(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.WaitFor(player)
	if not humanoid or not data then return end
	bodies[player] = nil
	local height = humanoid:FindFirstChild("BodyHeightScale")
	local target = heightScale(data)
	if height and math.abs(height.Value - target) > 0.001 then
		height.Value = target
		task.wait(SETTLE_TIME)
	end
	if player.Character ~= character then return end
	capture(player, character)
	apply(player)
end

function BodyService.Rebuild(player)
	task.spawn(rebuild, player)
end

local function onCharacter(player, character)
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	task.wait(0.1)
	if player.Character == character then rebuild(player) end
end

function BodyService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
		if player.Character then task.spawn(onCharacter, player, player.Character) end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
	Players.PlayerRemoving:Connect(function(player) bodies[player] = nil end)

	task.spawn(function()
		while true do
			task.wait(REFRESH_EVERY)
			for player in pairs(bodies) do
				apply(player)
			end
		end
	end)
end

return BodyService
