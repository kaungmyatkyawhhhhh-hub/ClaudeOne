-- BodyService: everyone's body.
--  * Every player wears the Robloxian 2.0 body (Config.Body): the five body parts are replaced through the
--    HumanoidDescription on every spawn/respawn, whatever avatar they joined with (blocky, Rthro, UGC); the body shape
--    scales are reset so everyone has the same proportions. Head, face, hair, accessories, skin color and animations stay
--    the player's own. If anything resets the body (wardrobe, emotes, outfit changes) it is put back.
--  * Height comes from Growth Spurts (Humanoid BodyHeightScale).
--  * Muscles are blobs (Shared.MuscleBlobs): ellipsoids welded to the body that grow with each muscle's level. Built once
--    per character, resized only when a level changes (tween 0.4s, a small pump on every 10th level, PUMPED = a bit
--    bigger). A Growth Spurt resets the muscles, so they shrink back while the height goes up.
--  * Default look: shirtless with game-provided shorts; the wardrobe can add a tank or sports top and pick the shorts
--    color (settings.top / settings.shorts).
--  * When the muscle progress passes 25/50/75/100%, the owner gets a "Grew" event (the "you grew" pulse + sound).
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Body = require(Shared.Config.Body)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local BodyShape = require(Shared.BodyShape)
local MuscleBlobs = require(Shared.MuscleBlobs)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local BodyService = {}

local REFRESH_EVERY = 1     -- seconds between checks
local SETTLE_TIME = 0.35    -- wait for Roblox to finish rescaling after a height change
local GROW_TIME = 0.4       -- seconds a level-up takes to show
local MIN_CHANGE = 0.002    -- smaller growth changes aren't worth an update
local THRESHOLDS = { 0.25, 0.5, 0.75, 1 }
local FALLBACK_SKIN = Color3.fromHex("#E0A878")

-- [player] = { character, original = the avatar's own HumanoidDescription, skin, blobs = MuscleBlobs controller,
--              levels = muscle levels last seen, step = progress step reached, torsoMesh, busy }
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

-- The clothes the player chose: skin, top color (nil = shirtless) and shorts color.
function BodyService.StyleOf(data, skin)
	local settings = data and data.settings or {}
	return {
		skin = skin or FALLBACK_SKIN,
		top = Body.TopColor(settings.top),
		topKind = settings.top == "Sports" and "sports" or "tank",
		shorts = Body.ShortsColor(settings.shorts),
	}
end

-- The body for a rig that is built from a HumanoidDescription (mirror rigs, NPCs, the statue).
function BodyService.PrepareDescription(desc, skin, heightScale)
	Body.ApplyTo(desc, skin, heightScale)
	return desc
end

-- Muscle blobs for a rig that is anchored as a whole (mirror rigs, NPCs, the statue). Call after the rig is parented
-- and its joints are solved. opts: share (0..1) or levels + goal; style (BodyService.StyleOf); recolor = { color, material }
-- paints everything one color (marble statue).
function BodyService.BuildStatic(model, opts)
	local blobs = MuscleBlobs.Build(model, { static = opts.static ~= false, castShadow = true })
	if opts.recolor then
		blobs:Dress({ skin = opts.recolor.color, top = nil, shorts = opts.recolor.color })
		local function marble(part) part.Material = opts.recolor.material part.Color = opts.recolor.color end
		for _, entry in ipairs(blobs.entries) do marble(entry.blob) end
		for _, g in ipairs(blobs.garments) do marble(g.blob) end
	else
		blobs:Dress(opts.style)
	end
	if opts.levels then
		blobs:Set(opts.levels, opts.goal or 1, 0)
	else
		blobs:SetShare(opts.share or 0, 0)
	end
	return blobs
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
	if state.torsoMesh and torso.MeshId ~= state.torsoMesh then return false end
	local blobs = state.blobs
	if blobs then
		local first = blobs.entries[1]
		if first and (not first.weld.Part0 or not first.weld.Part0:IsDescendantOf(state.character)) then return false end
	end
	return true
end

local function buildBlobs(state, data)
	if state.blobs then state.blobs:Destroy() end
	state.blobs = MuscleBlobs.Build(state.character, { castShadow = false })
	state.blobs:Dress(BodyService.StyleOf(data, state.skin))
	state.levels = nil
	state.growth = nil
end

local function sameGrowth(a, b)
	if not a or not b then return false end
	for muscle, g in pairs(b) do
		if math.abs((a[muscle] or 0) - g) > MIN_CHANGE then return false end
	end
	return true
end

-- Grow the blobs to the muscle levels. Every 10th level of a muscle pumps it; progress steps fire "Grew".
local function growBody(player, state, data, instant)
	local blobs = state.blobs
	if not blobs then return end
	local levels = levelsOf(data)
	local goal = goalOf(data)
	local growth = {}
	for _, muscle in ipairs(MuscleBlobs.Muscles) do growth[muscle] = MuscleBlobs.Growth(levels[muscle] or 0, goal) end
	if not sameGrowth(state.growth, growth) then
		blobs:Set(levels, goal, instant and 0 or GROW_TIME)
		state.growth = growth
	end
	if state.levels and not instant then
		local pumped = {}
		for muscle, level in pairs(levels) do
			local before = state.levels[muscle] or 0
			if level > before and math.floor(level / 10) > math.floor(before / 10) then table.insert(pumped, muscle) end
		end
		if #pumped > 0 then blobs:Pulse(pumped) end
	end
	state.levels = levels
	-- the "you grew" moment when the overall progress passes a step
	local progress = progressOf(levels, goal)
	local step = 0
	for index, threshold in ipairs(THRESHOLDS) do
		if progress >= threshold - 1e-6 then step = index end
	end
	if state.step ~= nil and step > state.step then Remotes.PlayerEvent:FireClient(player, "Grew", { tier = step }) end
	state.step = step
end

local function updatePumped(player, state)
	if not state.blobs then return end
	local untilTime = player:GetAttribute("PumpedUntil")
	state.blobs:SetPumped(type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow())
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
		buildBlobs(state, data)
		growBody(player, state, data, true)
		updatePumped(player, state)
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
			-- a Growth Spurt: the muscles are already reset, so they shrink while the height goes up
			if state.blobs then
				state.blobs:Set({}, 1, GROW_TIME)
				state.growth = nil
				task.wait(GROW_TIME + 0.1)
			end
			local value = humanoid:FindFirstChild("BodyHeightScale")
			if value then value.Value = targetHeight(data) end
			task.wait(SETTLE_TIME)
			if state.blobs then state.blobs:Refresh() end
		end
		if not bodyIntact(state) then
			applyBody(state, humanoid, data)
			task.wait(SETTLE_TIME)
			buildBlobs(state, data)
			changed = true
		end
		if changed then character:SetAttribute("BodyVersion", (character:GetAttribute("BodyVersion") or 0) + 1) end
	end
	if state.blobs then
		state.blobs:Dress(BodyService.StyleOf(data, state.skin))
		growBody(player, state, data, false)
		updatePumped(player, state)
	end
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

-- The player's muscle levels and goal (for rigs that show them: the progress mirror).
function BodyService.LevelsOf(data) return levelsOf(data), goalOf(data) end

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
