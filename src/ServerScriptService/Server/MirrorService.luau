-- MirrorService: the progress mirror on the entrance hall's right wall (built in Studio: Workspace.ProgressMirror, made
-- with tools/builders/Mirror.luau). "Look" opens the before/after screen
-- (MirrorClient): your day-one body next to your body now, with height and level under each, made for screenshots.
-- Day one is saved once per player (data.dayOne): the height and body scales from their first join. Saves from before
-- the mirror existed get the starting height (4'0") and plain scales, which is what every player started with.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local MirrorService = {}

local BASE_HEIGHT = 60 -- inches at height scale 1 (same as BodyService)

local function saveDayOne(player, data)
	if type(data.dayOne) == "table" then return end
	local fresh = (data.stats and data.stats.totalReps or 0) == 0 and (data.growthSpurts or 0) == 0
	local height = fresh and GrowthSpurts.GetHeight(data.growthSpurts or 0) or GrowthSpurts.StartHeight
	PlayerData.SetTable(player, "dayOne", {
		height = height,                 -- inches
		heightScale = height / BASE_HEIGHT,
		muscleScale = 1,                 -- no muscle thickening on day one
		level = 0,
		at = os.time(),
		estimated = not fresh,           -- saved later than the real first join
	})
end

local function wireMirror()
	local mirror = workspace:WaitForChild("ProgressMirror", 10)
	local prompt = mirror and mirror:FindFirstChild("MirrorPrompt", true)
	if not prompt then
		warn("[MirrorService] Workspace.ProgressMirror is missing: build it in Studio with tools/builders/Mirror.luau")
		return
	end
	Guard.OnTriggered(prompt, function(player)
		local data = PlayerData.Get(player)
		if not data then return end
		saveDayOne(player, data)
		Remotes.PlayerEvent:FireClient(player, "OpenMirror", {})
	end)
end

function MirrorService.Start()
	wireMirror()
	PlayerData.Loaded:Connect(saveDayOne)
end

return MirrorService
