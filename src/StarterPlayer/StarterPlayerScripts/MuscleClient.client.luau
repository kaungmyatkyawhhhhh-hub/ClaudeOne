-- MuscleClient: draws the muscles (muscle v8, Shared.MuscleRig) on every character this client can see. The muscles wear the
-- character's own Shirt / Pants (re-read every scan, so a wardrobe change or respawn shows at once) and everyone gets the
-- snatched-waist torso.
--  * Players: the growth numbers come from the player attribute MuscleG (BodyService publishes Muscles.LookG for the 18
--    muscles); for YOUR character they come straight from ClientData (the same numbers, Muscles.LooksFromLevels), so a
--    level-up shows at once. PUMPED comes from the PumpedUntil attribute. Top / Shorts / SkinColor attributes give the look.
--  * NPCs (Workspace.NPCs) and the statue carry the same attribute (a preset share), so everyone shows muscles.
--  * Muscles are only built for characters within ~80 studs of the camera and are removed beyond ~100, so a crowded server
--    stays smooth (only your own character keeps live meshes: MuscleRig bakes everyone else's). A muscle is only built once it has growth (level 0 = the plain Robloxian 2.0 body).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MuscleRig = require(Shared.MuscleRig)
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)

local player = Players.LocalPlayer

local RANGE, DROP = 80, 100
local SCAN_EVERY = 0.5
-- the client holds only a few muscle meshes: other characters wait until my own muscles are built (or this long), so NPCs
-- never grab the meshes first and make mine wait for them to be taken back
local OTHERS_WAIT = 12

local tracked = {} -- [model] = { rig, source, mine }

-- the growth numbers of my own muscles, from ClientData
local function myTargets()
	local data = ClientData.Get()
	if not data or not data.muscles then return nil end
	local goal = math.max(GrowthSpurts.GetGoal(data.growthSpurts or 0), 1)
	local levels = {}
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles[muscle.id]
		levels[muscle.id] = entry and entry.level or 0
	end
	return Muscles.LooksFromLevels(levels, goal), data
end

local function isStatic(model: Model): boolean
	local torso = model:FindFirstChild("UpperTorso")
	return torso ~= nil and torso:IsA("BasePart") and torso.Anchored
end

local function targetsFor(source: Instance, mine: boolean)
	if mine then
		local targets = myTargets()
		if targets then return targets end
	end
	return MuscleRig.Decode(source:GetAttribute("MuscleG"))
end

local untrack -- (defined below)

local function track(model: Model, source: Instance, mine: boolean, kind: string)
	if tracked[model] then return end
	local style = MuscleRig.StyleFrom(source, model)
	local keepBody = kind == "npc"
	if keepBody then
		-- NPCs keep their painted clothes: the muscles take the shirt and pants colors
		local torso, leg = model:FindFirstChild("UpperTorso"), model:FindFirstChild("LeftUpperLeg")
		if torso and torso:IsA("BasePart") and torso.Color ~= style.skin then style.top = torso.Color end
		if leg and leg:IsA("BasePart") then style.shorts = leg.Color end
	end
	local rig = MuscleRig.new(model, {
		static = isStatic(model),
		marble = source:GetAttribute("MuscleMarble") == true,
		style = style,
		keepBody = keepBody,
	})
	rig:Snap(targetsFor(source, mine))
	tracked[model] = { rig = rig, source = source, mine = mine, kind = kind, levels = nil, since = os.clock() }
	-- a character that dies has its joints broken (the muscle welds with them): take the muscles off at once so no part falls
	-- through the floor and the hidden real torso is shown again; they come back on the new character
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			untrack(model)
		end)
	end
end

function untrack(model)
	local info = tracked[model]
	if not info then return end
	tracked[model] = nil
	info.rig:Destroy()
end

-- Update one tracked model from its source (called every scan, and on attribute / data changes for responsiveness).
-- how important a rig is when the client can only hold a few muscle meshes: me first, then the nearest players, then the statue
-- and the NPCs
local function priorityFor(info, distance)
	if info.mine then return 100 end
	if info.kind == "player" then return math.max(60 - distance / 4, 31) end
	if info.kind == "statue" then return 30 end
	return math.max(20 - distance / 10, 1)
end

local function refreshInfo(model, info, distance)
	local rig = info.rig
	rig.priority = priorityFor(info, distance or 0)
	rig:SetGrowth(targetsFor(info.source, info.mine))
	local until_ = info.source:GetAttribute("PumpedUntil")
	rig:SetPumped(type(until_) == "number" and until_ > Workspace:GetServerTimeNow())
	if info.kind == "player" then
		local style = MuscleRig.StyleFrom(info.source, model)
		local old = info.style
		if not old or old.skin ~= style.skin or old.shorts ~= style.shorts or old.top ~= style.top or old.shirt ~= style.shirt or old.pants ~= style.pants then
			info.style = style
			rig:SetStyle(style)
		end
	end
end

-- the small pump when one of MY muscles passes a multiple of 10 levels
local lastLevels = nil
local function pulseMine()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local mine = tracked[player.Character]
	local levels = {}
	for _, muscle in ipairs(Muscles.List) do levels[muscle.id] = data.muscles[muscle.id] and data.muscles[muscle.id].level or 0 end
	if lastLevels and mine then
		local list = {}
		for id, level in pairs(levels) do
			local before = lastLevels[id] or 0
			if level > before and math.floor(level / 10) > math.floor(before / 10) then table.insert(list, id) end
		end
		if #list > 0 then mine.rig:Pulse(list) end
	end
	lastLevels = levels
end

local function distanceTo(model: Model, camera: Camera): number
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local position = root and root.Position or model:GetPivot().Position
	return (position - camera.CFrame.Position).Magnitude
end

local function candidates()
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local alive = humanoid == nil or humanoid.Health > 0 -- (no muscles on a dead body)
		if character and alive and character:FindFirstChild("UpperTorso") and character:GetAttribute("BodyVersion") then
			table.insert(list, { model = character, source = other, mine = other == player, kind = "player" })
		end
	end
	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then
		for _, npc in ipairs(npcs:GetChildren()) do
			if npc:IsA("Model") and npc:GetAttribute("MuscleG") and npc:FindFirstChild("UpperTorso") then
				table.insert(list, { model = npc, source = npc, mine = false, kind = "npc" })
			end
		end
	end
	local statue = Workspace:FindFirstChild("Statue")
	if statue and statue:IsA("Model") and statue:GetAttribute("MuscleG") and statue:FindFirstChild("UpperTorso") then
		table.insert(list, { model = statue, source = statue, mine = false, kind = "statue" })
	end
	return list
end

local function scan()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local seen = {}
	local myInfo = player.Character and tracked[player.Character]
	local othersAllowed = myInfo ~= nil and (myInfo.rig:IsReady() or os.clock() - myInfo.since > OTHERS_WAIT)
	for _, item in ipairs(candidates()) do
		seen[item.model] = true
		local info = tracked[item.model]
		local distance = distanceTo(item.model, camera)
		if info then
			if distance > DROP and not item.mine then
				untrack(item.model)
			else
				refreshInfo(item.model, info, distance)
			end
		elseif item.mine or (distance < RANGE and othersAllowed) then
			track(item.model, item.source, item.mine, item.kind)
			refreshInfo(item.model, tracked[item.model], distance)
		end
	end
	for model in pairs(tracked) do
		if not seen[model] or not model.Parent then untrack(model) end
	end
end

task.spawn(function()
	ClientData.Get()
	while true do
		-- (one bad model must not stop the muscles for the rest of the session)
		local ok, err = pcall(scan)
		if not ok then warn("[MuscleClient] scan failed:", err) end
		-- (quick scans until my own character is tracked, so the muscles start the moment the body is ready)
		local mine = player.Character and tracked[player.Character]
		task.wait(if mine then SCAN_EVERY else 0.1)
	end
end)

-- my own muscles react at once to a level-up (no waiting for the next scan)
ClientData.Changed:Connect(function(path)
	if path[1] ~= "muscles" and path[1] ~= "growthSpurts" then return end
	local mine = player.Character and tracked[player.Character]
	if mine then
		mine.rig:SetGrowth(targetsFor(player, true))
	end
	pulseMine()
end)
