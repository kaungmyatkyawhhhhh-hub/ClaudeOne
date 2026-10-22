-- CoachPortrait (owner, 23 Oct): Coach Dex for the dialog portraits (Shared/UI/CoachDialog: the tutorial and the unlock
-- guides), always with his muscles. The portraits used to copy the live NPC; far away he goes low detail (MuscleClient LOD:
-- his stage meshes hide past 60 studs) or isn't streamed in at all, so a copy made then showed the plain blocky body.
--   * The server keeps a plain copy of Dex in ReplicatedStorage.CoachPortrait (GymGoerService, made when it builds him, at his
--     full size, tags / prompts / labels taken off).
--   * This module (required on join through CoachDialog) dresses ONE copy of it with his muscle stage meshes (Shared/MuscleRig,
--     static, from his MuscleG, his skin and shorts colours: as MuscleClient does for NPCs) in a WorldModel that is never shown,
--     then preloads its meshes and textures (ContentProvider:PreloadAsync). Each portrait gets a clone of that ready model.
--   CoachPortrait.IsReady() -> boolean
--   CoachPortrait.WaitReady(timeout) -> boolean      (true once ready; waits at most `timeout` seconds)
--   CoachPortrait.Clone() -> Model?                  a dressed copy (nil until ready), facing -Z, his pivot at the origin
--   CoachPortrait.Ready                              a BindableEvent: fires each time a (new) dressed copy is ready
-- (owner, 23 Oct: "put clothes on coach dex portrait too") In the portrait he wears his coach tee (Quests.CoachLook.shirt,
-- short sleeves: the torso and upper arms painted, so the muscle stages take the colour, as on a painted NPC) with his black
-- shorts. Only the portrait: Dex in the gym stays shirtless.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local Shared = script.Parent.Parent
local MuscleRig = require(Shared.MuscleRig)
local BodyStages = require(Shared.BodyStages)
local Quests = require(Shared.Config.Quests)

local SHIRT_PARTS = { "UpperTorso", "RightUpperArm", "LeftUpperArm" }

local CoachPortrait = {}
CoachPortrait.Ready = Instance.new("BindableEvent")

local STAGES_WAIT = 30 -- seconds at most for the body stage meshes to download (BodyStages)
local BUILD_WAIT = 10  -- seconds at most for the rig to put them on

local master: Model? = nil -- the dressed copy (kept with its rig, never shown)
local ready = false
local building = 0 -- (a newer copy from the server replaces one still being dressed)

function CoachPortrait.IsReady(): boolean
	return ready and master ~= nil
end

function CoachPortrait.WaitReady(timeout: number): boolean
	local start = os.clock()
	while not CoachPortrait.IsReady() and os.clock() - start < timeout do task.wait() end
	return CoachPortrait.IsReady()
end

function CoachPortrait.Clone(): Model?
	if not CoachPortrait.IsReady() then return nil end
	local copy = (master :: Model):Clone()
	return copy
end

local function stageCount(model: Model): number
	local folder = model:FindFirstChild("MuscleMeshes")
	local n = 0
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then n += 1 end
		end
	end
	return n
end

local function dress(source: Model)
	building += 1
	local mine = building
	ready = false
	local holder = Instance.new("ViewportFrame") -- (never parented to a screen: keeps the copy out of the 3D world)
	holder.Name = "CoachPortraitHolder"
	local world = Instance.new("WorldModel")
	world.Parent = holder
	local model = source:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	-- his coach tee
	local shirt = Quests.CoachLook and Quests.CoachLook.shirt
	if shirt then
		for _, name in ipairs(SHIRT_PARTS) do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then part.Color = Color3.fromHex(shirt) end
		end
		model:SetAttribute("Top", nil)
	end
	model.Parent = world
	BodyStages.WaitReady(STAGES_WAIT)
	if mine ~= building then return end
	-- his muscles as MuscleClient draws an NPC: the stages from his MuscleG, his painted shorts colour kept
	local style = MuscleRig.StyleFrom(model, model)
	local torso, leg = model:FindFirstChild("UpperTorso"), model:FindFirstChild("LeftUpperLeg")
	if torso and torso:IsA("BasePart") and torso.Color ~= style.skin then style.top = torso.Color end
	if leg and leg:IsA("BasePart") then style.shorts = leg.Color end
	local ok, err = pcall(function()
		local rig = MuscleRig.new(model, { static = true, keepBody = true, style = style })
		rig:Snap(MuscleRig.Decode(model:GetAttribute("MuscleG")))
	end)
	if not ok then
		warn("[CoachPortrait] dressing failed:", err)
		return
	end
	-- the rig puts the stages on over the next frames (one region a frame, a short cross-fade): wait until they're all on
	local start, last, steady = os.clock(), -1, 0
	while os.clock() - start < BUILD_WAIT do
		task.wait(0.1)
		local n = stageCount(model)
		if n > 0 and n == last then steady += 0.1 else steady = 0 end
		last = n
		if steady >= 0.6 then break end
	end
	if mine ~= building then return end
	-- his meshes and textures loaded before the first portrait shows
	pcall(function() ContentProvider:PreloadAsync({ model }) end)
	if mine ~= building then return end
	if master and master.Parent then
		local oldHolder = master:FindFirstAncestorWhichIsA("ViewportFrame")
		if oldHolder then oldHolder:Destroy() end
	end
	master = model
	ready = true
	CoachPortrait.Ready:Fire()
end

-- the server's copy (it makes a new one whenever it rebuilds Dex)
task.spawn(function()
	local source = ReplicatedStorage:FindFirstChild("CoachPortrait") or ReplicatedStorage:WaitForChild("CoachPortrait", math.huge)
	if source and source:IsA("Model") then dress(source) end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "CoachPortrait" and child:IsA("Model") then
			task.wait(0.5) -- (all of it replicated)
			dress(child)
		end
	end)
end)

return CoachPortrait
