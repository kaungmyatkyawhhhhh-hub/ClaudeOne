-- Legend NPCs (Config.Legends): one visits for a few minutes every 20-30 minutes. Talking gives their one-time
-- challenge; finishing it (any time later) pays the reward, marks them as met and unlocks their title.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Legends = require(Config.Legends)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local NpcService = require(script.Parent.NpcService)
local TitleService = require(script.Parent.TitleService)

local Remotes = ReplicatedStorage.Remotes

local LegendService = {}

local rng = Random.new()
local present = nil -- { legend, model }
local lastTalk = {}

local function event(player, kind, info)
	if player.Parent then Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

local function eventAll(kind, info)
	for _, player in ipairs(Players:GetPlayers()) do event(player, kind, info) end
end

local function say(player, model, text)
	event(player, "NpcSays", { text = text, npc = model })
end

local function save(player, data)
	PlayerData.SetTable(player, "legends", data.legends)
end

local function complete(player, data, legend)
	data.legends.met[legend.id] = true
	data.legends.active = nil
	save(player, data)
	if Legends.Reward.coins then PlayerData.AddCoins(player, Legends.Reward.coins) end
	if Legends.Reward.dnaTokens then PlayerData.AddDnaTokens(player, Legends.Reward.dnaTokens) end
	TitleService.Check(player)
	event(player, "LegendDone", { name = legend.name, title = legend.title, coins = Legends.Reward.coins, dnaTokens = Legends.Reward.dnaTokens })
end

local function talk(player, legend, model)
	local now = os.clock()
	if now - (lastTalk[player] or 0) < 1.5 then return end
	lastTalk[player] = now
	local data = PlayerData.Get(player)
	if not data then return end
	local legends = data.legends
	if legends.met[legend.id] then
		say(player, model, "Good to see you again. Keep stacking those plates.")
		return
	end
	local active = legends.active
	if active and active.id == legend.id then
		say(player, model, legend.quest.text .. ". You're at " .. active.progress .. "/" .. active.goal .. ".")
		return
	end
	if active then
		local other = Legends.ById[active.id]
		say(player, model, "Finish " .. (other and other.name or "that") .. "'s challenge first, then come find me.")
		return
	end
	legends.active = { id = legend.id, progress = 0, goal = legend.quest.count }
	save(player, data)
	say(player, model, legend.line .. " My challenge: " .. legend.quest.text .. ".")
	event(player, "LegendQuest", { name = legend.name })
end

-- Called by MachineService for every validated rep.
function LegendService.OnRep(player, machineId)
	local data = PlayerData.Get(player)
	local active = data and data.legends and data.legends.active
	local legend = active and Legends.ById[active.id]
	if not legend then return end
	local quest = legend.quest
	if quest.type == "reps" or (quest.type == "machineReps" and table.find(quest.machines, machineId)) then
		active.progress = math.min(active.progress + 1, active.goal)
		if active.progress >= active.goal then
			complete(player, data, legend)
		else
			save(player, data)
		end
	end
end

local function visit()
	-- a legend nobody here has met yet if possible, else anyone
	local unmet = {}
	for _, legend in ipairs(Legends.List) do
		local someoneNeeds = false
		for _, player in ipairs(Players:GetPlayers()) do
			local data = PlayerData.Get(player)
			if data and not data.legends.met[legend.id] then someoneNeeds = true end
		end
		if someoneNeeds then table.insert(unmet, legend) end
	end
	local pool = #unmet > 0 and unmet or Legends.List
	local legend = pool[rng:NextInteger(1, #pool)]
	local spot = Legends.Visit.Spot
	local cframe = CFrame.lookAt(spot, spot + Legends.Visit.Facing)
	local spec = {
		name = legend.name, skin = legend.look.skin, shirt = legend.look.shirt, pants = legend.look.pants,
		scale = legend.look.scale, tag = "Legend", animated = true, prompt = { action = "Talk", object = legend.name, distance = 11 },
	}
	local model, prompt = NpcService.Build(spec, cframe)
	if not model then return end -- (couldn't build this visit; the loop tries again next time)
	present = { legend = legend, model = model }
	if prompt then Guard.OnTriggered(prompt, function(player) talk(player, legend, model) end) end
	eventAll("LegendArrived", { name = legend.name, minutes = Legends.Visit.StayMinutes })
	task.wait(Legends.Visit.StayMinutes * 60)
	eventAll("LegendLeft", { name = legend.name })
	model:Destroy()
	present = nil
end

function LegendService.Start()
	Players.PlayerRemoving:Connect(function(player) lastTalk[player] = nil end)
	task.spawn(function()
		task.wait(RunService:IsStudio() and 30 or Legends.Visit.FirstVisitSeconds)
		while true do
			local ok, err = pcall(visit) -- (one failed visit must not end the legends for the whole server)
			if not ok then
				warn("[LegendService] visit failed:", err)
				present = nil
			end
			local gap = rng:NextNumber(Legends.Visit.EveryMinutes[1], Legends.Visit.EveryMinutes[2]) * 60
			task.wait(gap)
		end
	end)
end

-- The legend in the gym right now (or nil).
function LegendService.Present()
	return present and present.legend or nil
end

return LegendService
