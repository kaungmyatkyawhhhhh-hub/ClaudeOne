-- BodyService: everyone's play body.
--  * On spawn the character gets the one smooth base body (Shared.MuscleBody.BaseBody, Roblox-made), keeping the
--    player's head, face, hair, accessories and skin color. In the gym look (default) shirts/pants are swapped for an
--    original tank top + shorts (built as muscle-body parts on the client); with Settings "Keep my avatar clothes" the
--    avatar's own clothes stay.
--  * Height comes from Growth Spurts; the body only gets a little wider (Shared.BodyShape). The muscles themselves are
--    the shapes MuscleClient builds from this character's attributes (MuscleSteps, VeinStages, BodyLook, colors,
--    VeinSeed), which are only rewritten when they change.
--  * When a muscle grows a step, the owner gets a "Grew" event (the "you grew" moment, ProgressClient).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local BodyShape = require(Shared.BodyShape)
local MuscleBody = require(Shared.MuscleBody)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local BodyService = {}

local REFRESH_EVERY = 1     -- seconds between muscle checks
local SETTLE_TIME = 0.35    -- wait for Roblox to finish rescaling after a height/width change

local bodies = {}    -- [player] = BodyShape body record (+ .bulk, .look)
local lastSteps = {} -- [player] = { [muscleId] = step } (for the "you grew" moment)
local rebuilding = {}
local originals = {} -- [player] = { character, desc } the avatar's own description for this character (before our changes)

local function lookOf(data)
	return (data.settings and data.settings.keepClothes) and "Own" or "Gym"
end

-- Parts the avatar's own shirt/pants cover (they thicken more there, since no muscle shapes show under clothes).
local function coveredParts(character)
	local covered = {}
	if character:FindFirstChildOfClass("Shirt") then
		for _, name in ipairs({ "UpperTorso", "RightUpperArm", "LeftUpperArm" }) do covered[name] = true end
	end
	if character:FindFirstChildOfClass("Pants") then
		for _, name in ipairs({ "LowerTorso", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg" }) do covered[name] = true end
	end
	return covered
end

-- The muscle attributes on a model (only written when they change).
local function setAttr(model, name, value)
	if model:GetAttribute(name) ~= value then model:SetAttribute(name, value) end
end
local function writeMuscles(player, character, data)
	local steps = MuscleBody.StepsFrom(data.muscles, GrowthSpurts.GetGoal(data.growthSpurts))
	local veins = MuscleBody.VeinsFrom(data.muscles, GrowthSpurts.GetLevelCap(data.growthSpurts))
	setAttr(character, "MuscleSteps", MuscleBody.Encode(steps))
	setAttr(character, "VeinStages", MuscleBody.Encode(veins))
	return steps
end

-- Spawn / look change: base body + look, scaled to the Growth Spurt height, then the muscle attributes.
local function rebuild(player)
	if rebuilding[player] then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.WaitFor(player)
	if not humanoid or not data then return end
	rebuilding[player] = true
	bodies[player] = nil
	local look = lookOf(data)
	local groupSteps = BodyShape.GroupSteps(data)
	local width, depth = BodyShape.BulkScales(groupSteps)
	local original = originals[player]
	if not original or original.character ~= character then
		local got, applied = pcall(function() return humanoid:GetAppliedDescription() end)
		original = got and applied and { character = character, desc = applied } or nil
		originals[player] = original
	end
	local ok, desc = original ~= nil, original and original.desc:Clone()
	if ok and desc then
		-- the avatar's own scales, remembered once (the mirror rigs use them too)
		if humanoid:GetAttribute("BaseBodyWidthScale") == nil then
			humanoid:SetAttribute("BaseBodyWidthScale", desc.WidthScale)
			humanoid:SetAttribute("BaseBodyDepthScale", desc.DepthScale)
			humanoid:SetAttribute("BaseSkinColor", desc.HeadColor)
		end
		local top, bottom = MuscleBody.GymColors(player.UserId)
		MuscleBody.BaseDescription(desc, look, top)
		desc.HeightScale = GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight
		desc.WidthScale = humanoid:GetAttribute("BaseBodyWidthScale") * width
		desc.DepthScale = humanoid:GetAttribute("BaseBodyDepthScale") * depth
		local applied = pcall(function() humanoid:ApplyDescription(desc, Enum.AssetTypeVerification.Always) end)
		if not applied then pcall(function() humanoid:ApplyDescription(desc) end) end
		desc:Destroy()
		if look == "Gym" then MuscleBody.StripClothes(character) end
		character:SetAttribute("TopColor", look == "Gym" and top or nil)
		character:SetAttribute("BottomColor", look == "Gym" and bottom or nil)
		task.wait(SETTLE_TIME)
	end
	rebuilding[player] = nil
	if player.Character ~= character then return end
	local body = BodyShape.Capture(character)
	for part, size in pairs(body.parts) do part:SetAttribute("OriginalSize", size) end -- before thickening
	body.bulk = { width, depth }
	body.look = look
	body.covered = look == "Own" and coveredParts(character) or nil
	bodies[player] = body
	BodyShape.Apply(body, BodyShape.PartScales(groupSteps, body.covered))
	-- the client pump and the muscle shapes grow from these sizes
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then part:SetAttribute("BaseSize", part.Size) end
	end
	character:SetAttribute("BodyLook", look)
	character:SetAttribute("SkinColor", humanoid:GetAttribute("BaseSkinColor"))
	character:SetAttribute("VeinSeed", player.UserId)
	local steps = writeMuscles(player, character, data)
	lastSteps[player] = lastSteps[player] or steps
	character:SetAttribute("BodyVersion", (character:GetAttribute("BodyVersion") or 0) + 1) -- gear rebuilds on this
	CollectionService:AddTag(character, MuscleBody.Tag)
end

-- Periodic check: new muscle steps / vein stages, a little part thickening; a bulk or look change rebuilds.
local function refresh(player)
	local body = bodies[player]
	local data = PlayerData.Get(player)
	if not body or not data or not body.model.Parent then return end
	if lookOf(data) ~= body.look then
		task.spawn(rebuild, player)
		return
	end
	local steps = writeMuscles(player, body.model, data)

	-- the "you grew" moment: groups with a muscle that went up a step (a Growth Spurt reset only goes down)
	local before = lastSteps[player] or steps
	local grew, seen = {}, {}
	for muscleId, step in pairs(steps) do
		local group = Muscles.ById[muscleId].group
		if step > (before[muscleId] or 0) and not seen[group] then
			seen[group] = true
			table.insert(grew, group)
		end
	end
	lastSteps[player] = steps
	if #grew > 0 then Remotes.PlayerEvent:FireClient(player, "Grew", { groups = grew }) end

	local groupSteps = BodyShape.GroupSteps(data)
	local width, depth = BodyShape.BulkScales(groupSteps)
	if math.abs(width - body.bulk[1]) > 0.001 or math.abs(depth - body.bulk[2]) > 0.001 then
		task.spawn(rebuild, player)
		return
	end
	if BodyShape.Apply(body, BodyShape.PartScales(groupSteps, body.covered)) then
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
		bodies[player], lastSteps[player], rebuilding[player], originals[player] = nil, nil, nil, nil
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
