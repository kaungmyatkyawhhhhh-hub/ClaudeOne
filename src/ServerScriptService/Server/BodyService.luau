-- BodyService: everyone's body.
--  * Every player wears the Robloxian 2.0 body (Config.Body): the five body parts are replaced through the
--    HumanoidDescription on every spawn/respawn, whatever avatar they joined with (blocky, Rthro, UGC); the body shape
--    scales are reset so everyone has the same proportions. Head, face, hair, accessories, skin color and animations stay
--    the player's own. If anything resets the body (wardrobe, emotes, outfit changes) it is put back.
--  * Height comes from Growth Spurts (Humanoid BodyHeightScale).
--  * Muscles (muscle v7) are drawn on every client (Shared.MuscleRig / MuscleClient): this service only PUBLISHES the numbers as
--    player attributes: MuscleG (18 growth values 0..1 in Config.Muscles order, i.e. level / Growth Spurt goal), Top and
--    Shorts (the wardrobe choices; ids from Config.Body). A Growth Spurt resets the muscles, so they shrink back on their own.
--  * When the muscle progress passes 25/50/75/100%, the owner gets a "Grew" event (the "you grew" pulse + sound).
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Body = require(Shared.Config.Body)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local Muscles = require(Shared.Config.Muscles)
local BodyShape = require(Shared.BodyShape)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local BodyService = {}

local REFRESH_EVERY = 1     -- seconds between checks
local SETTLE_TIME = 0.35    -- wait for Roblox to finish rescaling after a height change
local THRESHOLDS = { 0.25, 0.5, 0.75, 1 }
local FALLBACK_SKIN = Color3.fromHex("#E0A878")

-- [player] = { character, original = the avatar's own HumanoidDescription, skin, step, torsoMesh, busy }
local states = {}

local function targetHeight(data)
	return GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight
end

local function heightChanges(humanoid, data)
	local value = humanoid:FindFirstChild("BodyHeightScale")
	return value ~= nil and math.abs(value.Value - targetHeight(data)) > 0.001
end

-- { [muscleId] = level } from the player's data.
local function levelsOf(data)
	local levels = {}
	for id, entry in pairs(data.muscles or {}) do levels[id] = entry.level or 0 end
	return levels
end

local function goalOf(data)
	return GrowthSpurts.GetGoal(data.growthSpurts or 0)
end

-- Total muscle progress 0..1 (the average of all muscles' level toward the goal).
local function progressOf(levels, goal)
	local total, count = 0, 0
	for _, level in pairs(levels) do
		total += math.clamp(level / math.max(goal, 1), 0, 1)
		count += 1
	end
	return count > 0 and total / count or 0
end

-- The growth numbers as text for an attribute: g = level / goal for each muscle in Config.Muscles order, 3 decimals.
function BodyService.EncodeLevels(levels, goal)
	local parts = {}
	for index, muscle in ipairs(Muscles.List) do
		parts[index] = string.format("%.3f", math.clamp((levels[muscle.id] or 0) / math.max(goal, 1), 0, 1.12))
	end
	return table.concat(parts, ",")
end

-- Every muscle at the same share of the maximum (NPC presets, the statue).
function BodyService.EncodeShare(share)
	local parts = {}
	for index = 1, #Muscles.List do parts[index] = string.format("%.3f", share) end
	return table.concat(parts, ",")
end

-- Put the muscle numbers and the look on any model/player that shows muscles (clients read these attributes).
function BodyService.PublishData(target, data)
	local settings = data.settings or {}
	local g = BodyService.EncodeLevels(levelsOf(data), goalOf(data))
	if target:GetAttribute("MuscleG") ~= g then target:SetAttribute("MuscleG", g) end
	local top = settings.top or Body.DefaultTop
	local shorts = settings.shorts or Body.DefaultShorts
	if target:GetAttribute("Top") ~= top then target:SetAttribute("Top", top) end
	if target:GetAttribute("Shorts") ~= shorts then target:SetAttribute("Shorts", shorts) end
end

-- The player's muscle levels and goal (for rigs that show them: the progress mirror).
function BodyService.LevelsOf(data) return levelsOf(data), goalOf(data) end

-- The body for a rig that is built from a HumanoidDescription (mirror rigs, NPCs, the statue).
function BodyService.PrepareDescription(desc, skin, heightScale)
	Body.ApplyTo(desc, skin, heightScale)
	return desc
end

-- Ask Roblox for the body part ids once, and keep the stored ones if that fails.
local function refreshBodyIds()
	local ok, details = pcall(AssetService.GetBundleDetailsAsync, AssetService, Body.BundleId)
	if not ok or type(details) ~= "table" or not details.Items then
		warn("[BodyService] couldn't look up the Robloxian 2.0 bundle; using the stored body ids")
		return
	end
	local found = {}
	for _, item in ipairs(details.Items) do
		if item.Type == "Asset" then
			local name = string.lower(item.Name or "")
			if string.find(name, "left arm", 1, true) then found.LeftArm = item.Id
			elseif string.find(name, "right arm", 1, true) then found.RightArm = item.Id
			elseif string.find(name, "left leg", 1, true) then found.LeftLeg = item.Id
			elseif string.find(name, "right leg", 1, true) then found.RightLeg = item.Id
			elseif string.find(name, "torso", 1, true) then found.Torso = item.Id end
		end
	end
	for part, id in pairs(found) do
		if Body.Parts[part] ~= id then
			warn("[BodyService] bundle " .. Body.BundleId .. " " .. part .. " is " .. id .. " (stored " .. tostring(Body.Parts[part]) .. "); using the lookup")
			Body.Parts[part] = id
		end
	end
end

-- Put the Robloxian body on a player's character (retries; never leaves the original body in place on purpose).
local function applyBody(state, humanoid, data)
	for attempt = 1, 4 do
		local ok, desc = pcall(humanoid.GetAppliedDescription, humanoid)
		if ok and desc then
			Body.ApplyTo(desc, state.skin, targetHeight(data))
			local applied = pcall(humanoid.ApplyDescription, humanoid, desc)
			if applied then
				local torso = state.character:FindFirstChild("UpperTorso")
				state.torsoMesh = torso and torso:IsA("MeshPart") and torso.MeshId or nil
				return true
			end
		end
		task.wait(0.5 * attempt)
	end
	warn("[BodyService] couldn't apply the Robloxian body to " .. state.character.Name)
	return false
end

-- Is the Robloxian body still on? (something may have applied another outfit)
local function bodyIntact(state)
	local torso = state.character:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("MeshPart") then return false end
	-- no remembered body means the swap never succeeded: try again (refresh runs every second)
	if not state.torsoMesh then return false end
	if torso.MeshId ~= state.torsoMesh then return false end
	return true
end

-- Publish the numbers and fire the "you grew" moment when the overall progress passes a step.
local function publish(player, state, data)
	BodyService.PublishData(player, data)
	local levels, goal = levelsOf(data), goalOf(data)
	local progress = progressOf(levels, goal)
	local step = 0
	for index, threshold in ipairs(THRESHOLDS) do
		if progress >= threshold - 1e-6 then step = index end
	end
	if state.step ~= nil and step > state.step then Remotes.PlayerEvent:FireClient(player, "Grew", { tier = step }) end
	state.step = step
	player:SetAttribute("SkinColor", state.skin)
end

local function setup(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.WaitFor(player)
	if not humanoid or not data then return end
	local state = { character = character, busy = true }
	states[player] = state
	local ok, original = pcall(humanoid.GetAppliedDescription, humanoid)
	state.original = ok and original or nil
	state.skin = state.original and state.original.HeadColor or FALLBACK_SKIN
	if player.Character == character then applyBody(state, humanoid, data) end
	task.wait(SETTLE_TIME)
	if player.Character == character then
		publish(player, state, data)
		character:SetAttribute("BodyVersion", (character:GetAttribute("BodyVersion") or 0) + 1) -- gear rebuilds on this
	end
	state.busy = false
end

local function refresh(player)
	local state = states[player]
	local data = PlayerData.Get(player)
	if not state or state.busy or not data then return end
	local character = state.character
	if player.Character ~= character or not character.Parent then return end
	state.busy = true
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local changed = false
		if heightChanges(humanoid, data) then
			-- a Growth Spurt: taller (the muscles are already reset, the clients shrink them)
			local value = humanoid:FindFirstChild("BodyHeightScale")
			if value then value.Value = targetHeight(data) end
			task.wait(SETTLE_TIME)
			changed = true
		end
		if not bodyIntact(state) then
			applyBody(state, humanoid, data)
			task.wait(SETTLE_TIME)
			changed = true
		end
		if changed then character:SetAttribute("BodyVersion", (character:GetAttribute("BodyVersion") or 0) + 1) end
	end
	publish(player, state, data)
	state.busy = false
end

-- A copy of the player's own avatar description (their real head, hair, colors and clothes, before the Robloxian body),
-- or nil.
function BodyService.OriginalDescription(player)
	local state = states[player]
	return state and state.original and state.original:Clone() or nil
end

function BodyService.Rebuild(player)
	task.spawn(refresh, player)
end

-- The player's skin color (the avatar's own head color).
function BodyService.SkinOf(player)
	local state = states[player]
	return state and state.skin or FALLBACK_SKIN
end

local function onCharacter(player, character)
	states[player] = nil
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	task.wait(0.1)
	if player.Character == character then setup(player, character) end
end

function BodyService.Start()
	task.spawn(refreshBodyIds)
	local function hook(player)
		player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
		if player.Character then task.spawn(onCharacter, player, player.Character) end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
	Players.PlayerRemoving:Connect(function(player) states[player] = nil end)

	task.spawn(function()
		while true do
			task.wait(REFRESH_EVERY)
			for player in pairs(states) do
				task.spawn(refresh, player)
			end
		end
	end)
end

return BodyService
