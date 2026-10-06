-- MirrorService: the progress mirror on the entrance hall's right wall (built in Studio: Workspace.ProgressMirror, made
-- with tools/builders/Mirror.luau). "Look" opens the before/after screen (MirrorClient): your day-one body next to
-- your body now, with height and level under each, made for screenshots. (The glass itself shows a live reflection,
-- also MirrorClient.)
-- Both bodies are real R15 rigs built from your avatar's HumanoidDescription (Players:CreateHumanoidModelFromDescription)
-- with the Robloxian 2.0 body and muscle blobs (day one = none, now = your levels), so nothing floats. The rigs
-- go to the player's own PlayerGui (only they receive them); the client copies them into its ViewportFrames.
-- Day one is saved once per player (data.dayOne): the height and body scales from their first join. Saves from before
-- the mirror existed get the starting height (4'0") and plain scales, which is what every player started with.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local BodyShape = require(ReplicatedStorage.Shared.BodyShape)
local BodyService = require(script.Parent.BodyService)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local MirrorService = {}

local function saveDayOne(player, data)
	if type(data.dayOne) == "table" then return end
	local fresh = (data.stats and data.stats.totalReps or 0) == 0 and (data.growthSpurts or 0) == 0
	local height = fresh and GrowthSpurts.GetHeight(data.growthSpurts or 0) or GrowthSpurts.StartHeight
	PlayerData.SetTable(player, "dayOne", {
		height = height,                 -- inches
		heightScale = height / BodyShape.BaseHeight,
		muscleScale = 1,                 -- day one = muscle body tier 0 (your own body)
		level = 0,
		at = os.time(),
		estimated = not fresh,           -- saved later than the real first join
	})
end

-- The player's own avatar description (head, hair, colors), or a plain default one. The body is always the Robloxian 2.0 body.
local function avatarDescription(player)
	local desc = BodyService.OriginalDescription(player)
	if not desc then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local ok, applied = false, nil
		if humanoid then ok, applied = pcall(function() return humanoid:GetAppliedDescription() end) end
		desc = ok and applied and applied:Clone() or Instance.new("HumanoidDescription")
	end
	return desc
end

-- One preview rig: heightScale = absolute height scale. Built from your avatar (head, hair, skin color) with the Robloxian
-- body; the muscles are blobs added after the rig is parented (see openFor).
local function buildRig(player, name, heightScale)
	local desc = avatarDescription(player)
	BodyService.PrepareDescription(desc, nil, heightScale)
	local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	desc:Destroy()
	if not ok or not rig then
		warn("[MirrorService] Could not build a preview rig:", rig)
		return nil
	end
	rig.Name = name
	BodyShape.EnsureJoints(rig)
	for _, item in ipairs(rig:GetDescendants()) do
		if item:IsA("BaseScript") then item:Destroy() end
	end
	BodyShape.SolveJoints(rig)
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
	if rigHumanoid then rigHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return rig
end

local function openFor(player)
	local data = PlayerData.Get(player)
	if not data then return end
	saveDayOne(player, data)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local old = playerGui:FindFirstChild("MirrorRigs")
	if old then old:Destroy() end
	local dayOne = data.dayOne or {}
	local before = buildRig(player, "DayOne", dayOne.heightScale or GrowthSpurts.StartHeight / BodyShape.BaseHeight)
	local after = buildRig(player, "Now", GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight)
	if not before or not after then return end
	local folder = Instance.new("Folder")
	folder.Name = "MirrorRigs"
	before.Parent = folder
	after.Parent = folder
	folder.Parent = playerGui
	-- the muscles are drawn by the client from these numbers (day one = none, now = your levels; MuscleClient / MirrorClient)
	BodyService.PublishData(after, data)
	BodyService.PublishData(before, data)
	before:SetAttribute("MuscleG", BodyService.EncodeShare(0))
	Remotes.PlayerEvent:FireClient(player, "OpenMirror", { before = before, after = after })
end

local function wireMirror()
	local mirror = workspace:WaitForChild("ProgressMirror", 10)
	local prompt = mirror and mirror:FindFirstChild("MirrorPrompt", true)
	if not prompt then
		warn("[MirrorService] Workspace.ProgressMirror is missing: build it in Studio with tools/builders/Mirror.luau")
		return
	end
	Guard.OnTriggered(prompt, openFor)
	-- Studio testing: set the Workspace attribute "TestOpenMirror" (any new value) to open the mirror for everyone
	if game:GetService("RunService"):IsStudio() then
		workspace:GetAttributeChangedSignal("TestOpenMirror"):Connect(function()
			for _, player in ipairs(Players:GetPlayers()) do task.spawn(openFor, player) end
		end)
	end
end

function MirrorService.Start()
	wireMirror()
	PlayerData.Loaded:Connect(saveDayOne)
end

return MirrorService
