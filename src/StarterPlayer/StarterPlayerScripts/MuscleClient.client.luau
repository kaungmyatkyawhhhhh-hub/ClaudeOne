-- MuscleClient: builds the visible muscles (Shared.MuscleBody) on every body tagged "MuscleBody": player characters,
-- the mirror's preview rigs, the statue, NPC lifters. Work only happens when a body's muscle attributes change (or its
-- body parts are swapped), never per frame. Veins only build on bodies near the camera, and get a little stronger
-- while their owner is PUMPED.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MuscleBody = require(Shared:WaitForChild("MuscleBody"))

local VEIN_RANGE = 90       -- studs from the camera
local WATCHED = { "MuscleSteps", "VeinStages", "BodyLook", "TopColor", "BottomColor", "SkinColor", "BodyVersion" }

local bodies = {} -- [model] = { pending, near, pumped, connections }

local function ownerOf(model)
	return Players:GetPlayerFromCharacter(model)
end

local function pumpedUntil(model)
	local owner = ownerOf(model)
	local t = owner and owner:GetAttribute("PumpedUntil") or model:GetAttribute("PumpedUntil")
	return type(t) == "number" and t or 0
end

local function isNear(model)
	if model:IsDescendantOf(Workspace) == false then return true end -- viewport / statue copies: always full detail
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local camera = Workspace.CurrentCamera
	return not root or not camera or (root.Position - camera.CFrame.Position).Magnitude < VEIN_RANGE
end

local function build(model, instant)
	local state = bodies[model]
	if not state or not model.Parent then return end
	if not model:GetAttribute("MuscleSteps") then return end
	local spec = MuscleBody.SpecFrom(model)
	spec.instant = instant
	spec.pumped = state.pumped
	if not state.near then
		spec.veins = {}
		spec.veinKey = "far"
	end
	MuscleBody.Apply(model, spec)
end

local function schedule(model, instant, delay)
	local state = bodies[model]
	if not state or state.pending then return end
	state.pending = true
	task.delay(delay or 0.1, function()
		if bodies[model] then
			bodies[model].pending = false
			build(model, instant)
		end
	end)
end

local function track(model)
	if bodies[model] or not model:IsA("Model") then return end
	local state = { pending = false, near = isNear(model), pumped = false, connections = {} }
	bodies[model] = state
	for _, name in ipairs(WATCHED) do
		table.insert(state.connections, model:GetAttributeChangedSignal(name):Connect(function()
			if name == "BodyVersion" then
				-- new body parts: the old shapes were welded to the old ones
				local folder = model:FindFirstChild(MuscleBody.Folder)
				if folder then folder:Destroy() end
				schedule(model, true, 0.2)
			else
				schedule(model, false)
			end
		end))
	end
	-- body parts can stream in after the model (StreamingEnabled): build again when one arrives
	table.insert(state.connections, model.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then schedule(model, true, 0.2) end
	end))
	schedule(model, true, 0.05)
end

local function untrack(model)
	local state = bodies[model]
	if not state then return end
	for _, connection in ipairs(state.connections) do connection:Disconnect() end
	bodies[model] = nil
end

for _, model in ipairs(CollectionService:GetTagged(MuscleBody.Tag)) do track(model) end
CollectionService:GetInstanceAddedSignal(MuscleBody.Tag):Connect(track)
CollectionService:GetInstanceRemovedSignal(MuscleBody.Tag):Connect(untrack)

-- Every half second: veins near/far, and the PUMPED state (veins a bit stronger while pumped).
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = Workspace:GetServerTimeNow()
		for model, state in pairs(bodies) do
			if not model.Parent then
				untrack(model)
			else
				local near = isNear(model)
				local pumped = pumpedUntil(model) > now
				if near ~= state.near or pumped ~= state.pumped then
					state.near, state.pumped = near, pumped
					schedule(model, false)
				end
			end
		end
	end
end)
