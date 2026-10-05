-- MirrorService: the progress mirror on the entrance hall's right wall (built in Studio: Workspace.ProgressMirror, made
-- with tools/builders/Mirror.luau). "Look" opens the before/after screen (MirrorClient): your day-one body next to
-- your body now, with height and level under each, made for screenshots. (The glass itself shows a live reflection,
-- also MirrorClient.)
-- Both bodies are real R15 rigs built from your avatar's HumanoidDescription (Players:CreateHumanoidModelFromDescription)
-- and scaled with the description's scales, then shaped with Shared.BodyShape, so nothing floats or detaches. The rigs
-- go to the player's own PlayerGui (only they receive them); the client copies them into its ViewportFrames.
-- Day one is saved once per player (data.dayOne): the height and body scales from their first join. Saves from before
-- the mirror existed get the starting height (4'0") and plain scales, which is what every player started with.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local BodyShape = require(ReplicatedStorage.Shared.BodyShape)
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
		muscleScale = 1,                 -- no muscle growth on day one
		level = 0,
		at = os.time(),
		estimated = not fresh,           -- saved later than the real first join
	})
end

-- The player's avatar description (clothes, hair, colors), or a plain default one.
local function avatarDescription(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ok, desc = false, nil
	if humanoid then ok, desc = pcall(function() return humanoid:GetAppliedDescription() end) end
	if not ok or not desc then desc = Instance.new("HumanoidDescription") end
	return desc:Clone(), humanoid
end

-- One preview rig: heightScale = absolute height scale, steps = muscle steps (nil = no muscle growth).
local function buildRig(player, name, heightScale, steps)
	local desc, humanoid = avatarDescription(player)
	-- the avatar's own width/depth (BodyService remembers them before muscle growth changes them)
	local baseWidth = humanoid and humanoid:GetAttribute("BaseBodyWidthScale") or desc.WidthScale
	local baseDepth = humanoid and humanoid:GetAttribute("BaseBodyDepthScale") or desc.DepthScale
	local width, depth = 1, 1
	if steps then width, depth = BodyShape.BulkScales(steps) end
	desc.HeightScale = heightScale
	desc.WidthScale = baseWidth * width
	desc.DepthScale = baseDepth * depth
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
	if steps then BodyShape.Apply(BodyShape.Capture(rig), BodyShape.PartScales(steps)) end
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
	local before = buildRig(player, "DayOne", dayOne.heightScale or GrowthSpurts.StartHeight / BodyShape.BaseHeight, nil)
	local after = buildRig(player, "Now", GrowthSpurts.GetHeight(data.growthSpurts) / BodyShape.BaseHeight, BodyShape.GroupSteps(data))
	if not before or not after then return end
	local folder = Instance.new("Folder")
	folder.Name = "MirrorRigs"
	before.Parent = folder
	after.Parent = folder
	folder.Parent = playerGui
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
end

function MirrorService.Start()
	wireMirror()
	PlayerData.Loaded:Connect(saveDayOne)
end

return MirrorService
