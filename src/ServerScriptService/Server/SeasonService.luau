-- Seasonal events (Config.Seasons): while one runs, the starter gym gets its decorations (templates built in Studio in
-- ServerStorage.SeasonDecor, made with tools/builders/Seasons.luau), every
-- rep pays a little extra (a global BoostService source), and reps count toward that season's title.
-- ReplicatedStorage gets a "Season" attribute (the season id) for the client's note.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Seasons = require(ReplicatedStorage.Shared.Config.Seasons)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local TitleService = require(script.Parent.TitleService)

local SeasonService = {}

local active = nil -- the running season
local decor = nil  -- Folder with the decorations

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local function clearDecor()
	if decor then decor:Destroy() end
	decor = nil
end

local function buildDecor(season)
	clearDecor()
	local templates = ServerStorage:FindFirstChild("SeasonDecor")
	local template = templates and templates:FindFirstChild(season.id)
	if not template then
		warn("[SeasonService] ServerStorage.SeasonDecor." .. season.id .. " is missing: build it in Studio with tools/builders/Seasons.luau")
		return
	end
	decor = template:Clone()
	decor.Name = "SeasonDecor"
	decor.Parent = Workspace
	-- seasonal machines (Winter's Sled Pull) run through MachineService once they're in the world
	for _, model in ipairs(decor:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("MachineId") then CollectionService:AddTag(model, "Machine") end
	end
end

local function setSeason(season)
	if season == active then return end
	active = season
	if season then
		BoostService.SetGlobal("Season", { coins = season.coins })
		ReplicatedStorage:SetAttribute("Season", season.id)
		buildDecor(season)
	else
		BoostService.SetGlobal("Season", nil)
		ReplicatedStorage:SetAttribute("Season", nil)
		clearDecor()
	end
end

local function current()
	local forced = RunService:IsStudio() and Workspace:GetAttribute("ForceSeason")
	if type(forced) == "string" and Seasons.ById[forced] then return Seasons.ById[forced] end
	return Seasons.Active(os.time())
end

-- Called by MachineService for every validated rep.
function SeasonService.OnRep(player)
	if not active then return end
	local data = PlayerData.Get(player)
	if not data then return end
	local seasons = data.seasons or {}
	seasons[active.id] = (seasons[active.id] or 0) + 1
	PlayerData.SetTable(player, "seasons", seasons)
	if seasons[active.id] == active.title.reps then TitleService.Check(player) end
end

function SeasonService.Start()
	setSeason(current())
	task.spawn(function()
		while true do
			task.wait(600)
			setSeason(current())
		end
	end)
end

return SeasonService
