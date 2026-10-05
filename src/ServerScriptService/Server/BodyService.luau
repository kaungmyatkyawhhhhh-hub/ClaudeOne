-- Body scaling everyone can see (rules in Shared.BodyShape): height comes from Growth Spurts, muscle size grows in
-- clear steps as the groups level up (whole body wider/deeper + the trained parts thicker). Joints and attachments
-- move along with the parts so limbs and accessories stay connected. When a group grows a step, the owner gets a
-- "Grew" event for the short "you grew" moment (pulse + sound, ProgressClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local BodyShape = require(ReplicatedStorage.Shared.BodyShape)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local BodyService = {}

local REFRESH_EVERY = 1     -- seconds between muscle-size checks
local SETTLE_TIME = 0.35    -- wait for Roblox to finish rescaling after a height/width change

local bodies = {}    -- [player] = BodyShape body record (+ .bulk = { width, depth } it was built with)
local lastSteps = {} -- [player] = { [groupId] = step } (for the "you grew" moment)
local rebuilding = {}

-- The avatar's own scales (from the player's avatar settings), remembered once per character before we change them.
local function baseScales(humanoid)
	local result = {}
	for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale" }) do
		local value = humanoid:FindFirstChild(name)
		local key = "Base" .. name
		if value and humanoid:GetAttribute(key) == nil then humanoid:SetAttribute(key, value.Value) end
		result[name] = humanoid:GetAttribute(key) or 1
	end
	return result
end

-- Target scale values: height from Growth Spurts, width/depth from the muscle steps.
local function targetScales(humanoid, data, steps)
	local base = baseScales(humanoid)
	local width, depth = BodyShape.BulkScales(steps)
	return {
		BodyHeightScale = GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight,
		BodyWidthScale = base.BodyWidthScale * width,
		BodyDepthScale = base.BodyDepthScale * depth,
	}
end

-- Scale values -> let Roblox rescale -> capture the new base -> thicken the trained parts.
local function rebuild(player)
	if rebuilding[player] then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.WaitFor(player)
	if not humanoid or not data then return end
	rebuilding[player] = true
	bodies[player] = nil
	local steps = BodyShape.GroupSteps(data)
	local changed = false
	for name, target in pairs(targetScales(humanoid, data, steps)) do
		local value = humanoid:FindFirstChild(name)
		if value and math.abs(value.Value - target) > 0.001 then
			value.Value = target
			changed = true
		end
	end
	if changed then task.wait(SETTLE_TIME) end
	rebuilding[player] = nil
	if player.Character ~= character then return end
	local body = BodyShape.Capture(character)
	for part, size in pairs(body.parts) do
		part:SetAttribute("OriginalSize", size) -- before muscle thickening
	end
	body.bulk = { BodyShape.BulkScales(steps) }
	bodies[player] = body
	BodyShape.Apply(body, BodyShape.PartScales(steps))
	for part in pairs(body.parts) do part:SetAttribute("BaseSize", part.Size) end -- the client pump grows from this
	lastSteps[player] = lastSteps[player] or steps
end

-- Periodic check: thicker parts in place; a whole-body bulk change needs a rebuild (Roblox rescales the rig).
local function refresh(player)
	local body = bodies[player]
	local data = PlayerData.Get(player)
	if not body or not data or not body.model.Parent then return end
	local steps = BodyShape.GroupSteps(data)

	-- the "you grew" moment: any group that went up a step (a Growth Spurt reset only goes down, so no moment)
	local before = lastSteps[player] or steps
	local grew = {}
	for groupId, step in pairs(steps) do
		if step > (before[groupId] or 0) then table.insert(grew, groupId) end
	end
	lastSteps[player] = steps
	if #grew > 0 then Remotes.PlayerEvent:FireClient(player, "Grew", { groups = grew }) end

	local width, depth = BodyShape.BulkScales(steps)
	if math.abs(width - body.bulk[1]) > 0.001 or math.abs(depth - body.bulk[2]) > 0.001 then
		task.spawn(rebuild, player)
		return
	end
	if BodyShape.Apply(body, BodyShape.PartScales(steps)) then
		for part in pairs(body.parts) do part:SetAttribute("BaseSize", part.Size) end
	end
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
	Players.PlayerRemoving:Connect(function(player)
		bodies[player], lastSteps[player], rebuilding[player] = nil, nil, nil
	end)

	task.spawn(function()
		while true do
			task.wait(REFRESH_EVERY)
			for player in pairs(bodies) do
				refresh(player)
			end
		end
	end)
end

return BodyService
