-- BodyService: everyone's body.
--  * Height comes from Growth Spurts (Humanoid BodyHeightScale).
--  * Muscles are body tiers (Config.MuscleBodies): from total muscle progress the player gets tier 0-4, and a tier
--    with Marketplace body part ids swaps the torso, arms and legs through the HumanoidDescription. Head, face, hair,
--    accessories, skin color and clothes stay the player's own. Tiers without ids change nothing (tier 0 = own body).
--  * When the body moves up a tier, the owner gets a "Grew" event (the "you grew" pulse + sound, ProgressClient).
--  * A Growth Spurt resets the muscles, so the body goes back to tier 0 (the height stays).
--  * Every second it also sets the player attribute Strength (all muscle levels added up) for the overhead label.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local MuscleBodies = require(Shared.Config.MuscleBodies)
local Muscles = require(Shared.Config.Muscles)
local BodyShape = require(Shared.BodyShape)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local BodyService = {}

local REFRESH_EVERY = 1     -- seconds between muscle checks
local SETTLE_TIME = 0.35    -- wait for Roblox to finish rescaling after a height change

-- [player] = { character, original = the avatar's own HumanoidDescription, body = tier shown, busy }
local states = {}

local function targetHeight(data)
	return GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight
end

local function setHeight(humanoid, data)
	local value = humanoid:FindFirstChild("BodyHeightScale")
	local target = targetHeight(data)
	if value and math.abs(value.Value - target) > 0.001 then
		value.Value = target
		return true
	end
	return false
end

-- The tier the player has earned (0-4).
function BodyService.TierOf(data)
	return MuscleBodies.TierFor(data.muscles, GrowthSpurts.GetGoal(data.growthSpurts or 0))
end

-- The tier whose body is shown: the highest tier up to `tier` that has ids (0 = own body).
function BodyService.BodyTier(tier)
	for t = tier, 1, -1 do
		if MuscleBodies.HasIds(t) then return t end
	end
	return 0
end

-- Put a tier's body parts on any rig with a Humanoid (NPCs, statue). Returns true if it changed the rig.
function BodyService.ApplyTier(humanoid, tier, heightScale)
	local bodyTier = BodyService.BodyTier(tier)
	if bodyTier == 0 then return false end
	local ok, desc = pcall(humanoid.GetAppliedDescription, humanoid)
	if not ok or not desc then return false end
	MuscleBodies.ApplyTo(desc, bodyTier, nil)
	if heightScale then desc.HeightScale = heightScale end
	return (pcall(humanoid.ApplyDescription, humanoid, desc))
end

local function showTier(player, state, data, announce)
	local character = state.character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not state.original then return end
	local body = BodyService.BodyTier(BodyService.TierOf(data))
	if body == state.body then return end
	local desc = humanoid:GetAppliedDescription()
	MuscleBodies.ApplyTo(desc, body, state.original)
	desc.HeightScale = targetHeight(data) -- ApplyDescription sets the scales too
	local ok, err = pcall(humanoid.ApplyDescription, humanoid, desc)
	if not ok then
		warn("[BodyService] couldn't apply body tier " .. body .. ": " .. tostring(err))
		return
	end
	if player.Character ~= character then return end
	local grew = body > state.body
	state.body = body
	character:SetAttribute("BodyTier", body)
	character:SetAttribute("BodyVersion", (character:GetAttribute("BodyVersion") or 0) + 1) -- gear rebuilds on this
	if announce and grew then Remotes.PlayerEvent:FireClient(player, "Grew", { tier = body }) end
end

local function setup(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.WaitFor(player)
	if not humanoid or not data then return end
	local state = { character = character, body = 0, busy = true }
	states[player] = state
	local ok, original = pcall(humanoid.GetAppliedDescription, humanoid)
	state.original = ok and original or nil
	if setHeight(humanoid, data) then task.wait(SETTLE_TIME) end
	if player.Character == character then showTier(player, state, data, false) end
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
	if humanoid and setHeight(humanoid, data) then task.wait(SETTLE_TIME) end -- a Growth Spurt: taller
	showTier(player, state, data, true)
	state.busy = false
end

-- A copy of the player's own avatar description (their real body parts, before any tier), or nil.
function BodyService.OriginalDescription(player)
	local state = states[player]
	return state and state.original and state.original:Clone() or nil
end

function BodyService.Rebuild(player)
	task.spawn(refresh, player)
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
			for _, player in ipairs(Players:GetPlayers()) do
				-- total strength for the label over everyone's head (StatsLabelsClient)
				local data = PlayerData.Get(player)
				if data and data.muscles then player:SetAttribute("Strength", Muscles.TotalStrength(data.muscles)) end
			end
			for player in pairs(states) do
				task.spawn(refresh, player)
			end
		end
	end)
end

return BodyService
