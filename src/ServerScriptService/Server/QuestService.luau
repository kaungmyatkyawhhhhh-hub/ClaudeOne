-- Coach quests (Config.Quests) and the Coach NPC at the front desk. Talking to the Coach (ProximityPrompt,
-- handled here on the server) gives a quest, or pays out a finished one and gives the next. Progress is tracked
-- on the server only: rep counters from MachineService, everything else checked against the player's data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Quests = require(Config.Quests)
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage.Remotes

local QuestService = {}

-- The Coach stands at the gym end of the front desk, facing the door aisle.
local TALK_COOLDOWN = 1.5

local rng = Random.new()
local lastTalk = {} -- [player] = os.clock()

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function say(player, text)
	Remotes.PlayerEvent:FireClient(player, "CoachSays", { text = text })
end

local function countTitles(data)
	local n = 0
	for _ in pairs(data.titles.owned) do n += 1 end
	return n
end

-- Current value and goal for a state quest (or nil for counter quests).
local function measure(data, quest)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	if quest.type == "groupLevel" then
		local group = Muscles.GroupById[quest.group]
		return Muscles.Shown(GrowthSpurts.GoalLevel(data.muscles, group, trainable)), Muscles.Shown(quest.level) -- in EXP, like the screen
	elseif quest.type == "allGroups" then
		local lowest = math.huge
		for _, group in ipairs(Muscles.Groups) do
			lowest = math.min(lowest, GrowthSpurts.GoalLevel(data.muscles, group, trainable))
		end
		return Muscles.Shown(lowest), Muscles.Shown(quest.level)
	elseif quest.type == "anyTier" then
		local best = 1
		for _, progress in pairs(data.machines) do best = math.max(best, progress.unlocked or 1) end
		return best, quest.tier
	elseif quest.type == "titles" then
		return countTitles(data), quest.count
	elseif quest.type == "spurts" then
		return data.growthSpurts, quest.count
	end
	return nil
end

local function newActive(data, quest)
	local value, goal = measure(data, quest)
	return { id = quest.id, progress = value and math.min(value, goal) or 0, goal = goal or quest.count, ready = false }
end

-- Recompute a state quest and flag it ready; replicate only when something changed.
local function refresh(player, data, forceReplicate)
	local active = data.quests.active
	local quest = active and Quests.ById[active.id]
	if not quest then return end
	local changed = forceReplicate
	local value, goal = measure(data, quest)
	if value then
		local clamped = math.min(value, goal)
		if clamped ~= active.progress then active.progress, changed = clamped, true end
	end
	if not active.ready and active.progress >= active.goal then
		active.ready, changed = true, true
		Remotes.PlayerEvent:FireClient(player, "QuestReady", { id = quest.id })
	end
	if changed then PlayerData.SetQuests(player, data.quests) end
end

local function grant(player, reward)
	if reward.coins then PlayerData.AddCoins(player, reward.coins) end
	if reward.dnaTokens then PlayerData.AddDnaTokens(player, reward.dnaTokens) end
	if reward.shakes then PlayerData.AddShakes(player, reward.shakes) end
end

local function giveNext(player, data, prefix)
	local quest = Quests.ForIndex(data.quests.index)
	data.quests.active = newActive(data, quest)
	refresh(player, data, true)
	say(player, (prefix and prefix .. " " or "") .. pick(Quests.Lines.give) .. " " .. quest.text .. ".")
end

local function talk(player)
	local now = os.clock()
	if now - (lastTalk[player] or 0) < TALK_COOLDOWN then return end
	lastTalk[player] = now
	local data = PlayerData.Get(player)
	if not data then return end
	local active = data.quests.active
	local quest = active and Quests.ById[active.id]
	if not quest then
		giveNext(player, data)
		return
	end
	refresh(player, data, false)
	if active.ready then
		grant(player, quest.reward)
		Remotes.PlayerEvent:FireClient(player, "QuestDone", { id = quest.id, reward = Quests.RewardText(quest.reward) })
		data.quests.index += 1
		giveNext(player, data, pick(Quests.Lines.done))
	else
		say(player, pick(Quests.Lines.notDone) .. " " .. quest.text .. " (" .. active.progress .. "/" .. active.goal .. ").")
	end
end

-- Called by MachineService for every validated rep.
function QuestService.OnRep(player, machineId)
	local data = PlayerData.Get(player)
	local active = data and data.quests.active
	local quest = active and Quests.ById[active.id]
	if not quest or active.ready then return end
	local counts = quest.type == "reps" or (quest.type == "machineReps" and table.find(quest.machines, machineId) ~= nil)
	if counts then
		active.progress = math.min(active.progress + 1, active.goal)
		refresh(player, data, true)
	else
		refresh(player, data, false)
	end
end

function QuestService.Start()
	-- Coach Dex is built in Studio (Workspace.NPCs, tag "Coach", made with tools/builders/NPCs.luau)
	task.spawn(function()
		local npcs = Workspace:WaitForChild("NPCs", 10)
		local coach = npcs and npcs:WaitForChild(Quests.CoachName, 10)
		local prompt = coach and coach:FindFirstChild("TalkPrompt", true)
		if prompt then
			Guard.OnTriggered(prompt, talk)
		else
			warn("[QuestService] Coach Dex is missing: build him in Studio with tools/builders/NPCs.luau")
		end
	end)

	-- state quests (levels, tiers, titles, Growth Spurts) can finish outside of reps too
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data and data.quests.active and not data.quests.active.ready then
					refresh(player, data, false)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player) lastTalk[player] = nil end)
end

return QuestService
