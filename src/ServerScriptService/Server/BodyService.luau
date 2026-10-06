-- BodyService: everyone's body.
--  * Height comes from Growth Spurts (Humanoid BodyHeightScale).
--  * Muscles are body tiers (Config.MuscleBodies): from total muscle progress the player gets tier 0-4, and a tier
--    with Marketplace body part ids swaps the torso, arms and legs through the HumanoidDescription. Head, face, hair,
--    accessories, skin color and clothes stay the player's own. Tiers without ids change nothing (tier 0 = own body).
--  * When the body moves up a tier, the owner gets a "Grew" event (the "you grew" pulse + sound, ProgressClient).
--  * A Growth Spurt resets the muscles, so the body goes back to tier 0 (the height stays).
--  * Muscle growth (Shared.BodyThickness): every R15 part grows its thickness a little with every level of its own
--    muscles (gradual, per part, no ids needed). Done here on the server so everyone sees it, batched once a second and
--    only when a level changed; every 10th level adds a small pump. A Growth Spurt eases the thickness back to normal
--    while the height goes up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local MuscleBodies = require(Shared.Config.MuscleBodies)
local BodyShape = require(Shared.BodyShape)
local BodyThickness = require(Shared.BodyThickness)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local BodyService = {}

local REFRESH_EVERY = 1     -- seconds between muscle checks
local SETTLE_TIME = 0.35    -- wait for Roblox to finish rescaling after a height change
local GROW_TIME = 0.4       -- seconds a level-up takes to show
local MIN_CHANGE = 0.0005   -- smaller factor changes aren't worth an update

-- [player] = { character, original = the avatar's own HumanoidDescription, body = tier shown, busy }
local states = {}

local function targetHeight(data)
	return GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight
end

local function heightChanges(humanoid, data)
	local value = humanoid:FindFirstChild("BodyHeightScale")
	return value ~= nil and math.abs(value.Value - targetHeight(data)) > 0.001
end

local function setHeight(humanoid, data)
	local value = humanoid:FindFirstChild("BodyHeightScale")
	if value and heightChanges(humanoid, data) then
		value.Value = targetHeight(data)
		return true
	end
	return false
end

-- { [muscleId] = level } from the player's data.
local function levelsOf(data)
	local levels = {}
	for id, entry in pairs(data.muscles or {}) do levels[id] = entry.level or 0 end
	return levels
end

-- Per-part thickness factors for this data (BodyThickness.Targets).
function BodyService.TargetsOf(data)
	return BodyThickness.Targets(levelsOf(data), GrowthSpurts.GetGoal(data.growthSpurts or 0))
end

local function sameTargets(a, b)
	if not a or not b then return false end
	for name, factor in pairs(b) do
		local old = a[name]
		if not old or math.abs(old.x - factor.x) > MIN_CHANGE or math.abs(old.z - factor.z) > MIN_CHANGE then return false end
	end
	return true
end

-- Grow (or shrink) the body to the muscle levels. Every 10th level of a muscle pumps its parts.
local function growBody(state, data, instant)
	local thick = state.thick
	if not thick then return end
	local levels = levelsOf(data)
	local targets = BodyService.TargetsOf(data)
	if not sameTargets(state.targets, targets) then
		thick:Set(targets, instant and 0 or GROW_TIME)
		state.targets = targets
	end
	if state.levels and not instant then
		for id, level in pairs(levels) do
			local before = state.levels[id] or 0
			if level > before and math.floor(level / 10) > math.floor(before / 10) then
				thick:Pulse(BodyThickness.PulseParts(id))
			end
		end
	end
	state.levels = levels
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
	if player.Character == character then
		showTier(player, state, data, false)
		state.thick = BodyThickness.New(character)
		growBody(state, data, true)
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
	if humanoid and heightChanges(humanoid, data) then
		-- a Growth Spurt: ease back to normal thickness, then grow taller (Roblox rescales parts from their own
		-- original sizes), then capture the new normal
		if state.thick then
			state.thick:Set(nil, GROW_TIME)
			task.wait(GROW_TIME + 0.1)
			state.thick:Restore()
		end
		setHeight(humanoid, data)
		task.wait(SETTLE_TIME)
		if state.thick then state.thick:Capture() end
		state.targets = nil
		state.levels = nil
	end
	showTier(player, state, data, true)
	if player.Character == character then growBody(state, data, false) end
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
			for player in pairs(states) do
				task.spawn(refresh, player)
			end
		end
	end)
end

return BodyService
