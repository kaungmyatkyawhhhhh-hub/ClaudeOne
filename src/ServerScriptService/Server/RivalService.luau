-- RivalService (owner's feature run, task 6): the NPC rivals (Config/Rivals). Each rival is a gym regular in
-- Workspace.NPCs (Benny and Coral from tools/builders/Rivals, Dante the pro gym's giant) with a "Challenge" prompt:
--   * the prompt sends that player the challenge card (his record, your best, the reward)
--   * "Accept" turns the challenge on (data.rivals[id] = "active")
--   * a lift challenge is beaten by a full set (Rivals.SetReps reps in a row at one weight) on his machine heavier than
--     his record, counted from MachineService's "Rep" events; an arm challenge by winning a match against him (he shows
--     up in the opponent list at every arm wrestling table once accepted, ArmWrestleService.SetExtraOpponents)
--   * beaten: coins + his title (stat beat<Id>), data.rivals[id] = "beaten", the win card and his line; a set at or under
--     his record, or a lost match, gets his "come back stronger" line instead.
-- Gyms open by Growth Spurt already, so a rival never opens one: he is an extra goal and points to the next rival.
-- Remote "Rival": client -> server "Accept", rivalId; server -> client "Card" | "Result" | "Say", info.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rivals = require(ReplicatedStorage.Shared.Config.Rivals)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local PlayerData = require(script.Parent.PlayerData)
local TitleService = require(script.Parent.TitleService)
local ArmWrestleService = require(script.Parent.ArmWrestleService)
local GameEvents = require(script.Parent.GameEvents)
local GymGoerService = require(script.Parent.GymGoerService)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local RivalService = {}

local remote: RemoteEvent
local sets = {}     -- [player] = { machineId, weight, reps, last } (the set being lifted right now)
local lastLose = {} -- [player] = { [rival id] = os.clock() of his last "come back stronger" line }
local cardShown = {} -- [player] = { [rival id] = true } (Accept only after his card was shown)

local function send(player, kind, info)
	remote:FireClient(player, kind, info)
end

local function stateOf(player, rival): string?
	local data = PlayerData.Get(player)
	local rivals = data and data.rivals
	return type(rivals) == "table" and rivals[rival.id] or nil
end

local function setState(player, rival, state)
	local data = PlayerData.Get(player)
	if not data then return end
	local rivals = type(data.rivals) == "table" and table.clone(data.rivals) or {}
	rivals[rival.id] = state
	PlayerData.SetTable(player, "rivals", rivals)
end

-- your heaviest weight ever on his machine ("95 lb"), for the card
local function yourBest(player, rival): string?
	local c = rival.challenge
	if c.kind ~= "lift" then return nil end
	local machine = Machines.ById[c.machineId]
	local progress = machine and PlayerData.GetMachine(player, machine.id)
	local best = progress and progress.best
	if not best or best < 1 or not machine.tiers[best] then return nil end
	return Machines.WeightText(machine.tiers[best])
end

local function card(player, rival)
	local c = rival.challenge
	local machine = c.kind == "lift" and Machines.ById[c.machineId] or nil
	cardShown[player] = cardShown[player] or {}
	cardShown[player][rival.id] = true
	send(player, "Card", {
		id = rival.id,
		state = stateOf(player, rival) or "new",
		challenge = Rivals.ChallengeText(rival, machine and machine.name),
		record = c.kind == "lift" and (c.record .. " lb") or nil,
		machine = machine and machine.name or nil,
		best = yourBest(player, rival),
	})
end

local function say(player, rival, line)
	send(player, "Say", { id = rival.id, line = rival.lines[line] or line })
end

local function lose(player, rival)
	lastLose[player] = lastLose[player] or {}
	local last = lastLose[player][rival.id]
	if last and os.clock() - last < Rivals.LoseLineEvery then return end
	lastLose[player][rival.id] = os.clock()
	say(player, rival, "lose")
end

local function beat(player, rival)
	if stateOf(player, rival) ~= "active" then return end
	setState(player, rival, "beaten")
	PlayerData.AddCoins(player, rival.reward.coins)
	local stat = "beat" .. rival.id
	local data = PlayerData.Get(player)
	PlayerData.SetStat(player, stat, ((data and data.stats[stat]) or 0) + 1)
	TitleService.Check(player)
	GameEvents.Fire("RivalBeaten", player, 1, { rival = rival.id })
	send(player, "Result", { id = rival.id, won = true, line = rival.lines.win, coins = rival.reward.coins,
		title = rival.reward.title, next = rival.next })
end

-- a rep on a machine: count the set; at the full set, check every accepted lift challenge on that machine
local function onRep(player, info)
	if type(info) ~= "table" or type(info.machineId) ~= "string" or type(info.weight) ~= "number" then return end
	local now = os.clock()
	local set = sets[player]
	if set and set.machineId == info.machineId and set.weight == info.weight and now - set.last <= Rivals.SetGap then
		set.reps += 1
		set.last = now
	else
		set = { machineId = info.machineId, weight = info.weight, reps = 1, last = now }
		sets[player] = set
	end
	if set.reps ~= Rivals.SetReps then return end
	for _, rival in ipairs(Rivals.List) do
		local c = rival.challenge
		if c.kind == "lift" and c.machineId == set.machineId and stateOf(player, rival) == "active" then
			if Rivals.BeatsLift(rival, set.machineId, set.weight, set.reps) then
				beat(player, rival)
			else
				lose(player, rival)
			end
		end
	end
end

-- the arm wrestling opponents a player can pick: the arm rivals whose challenge is on (rematches after a win too)
local function armOpponents(player)
	local list = {}
	for _, rival in ipairs(Rivals.List) do
		local c = rival.challenge
		local state = stateOf(player, rival)
		if c.kind == "arm" and (state == "active" or state == "beaten") then
			table.insert(list, { id = Rivals.ArmId(rival), name = rival.name, label = "Rival", strength = c.strength,
				taps = c.taps, coins = 15, look = Rivals.BuildSpec(rival) })
		end
	end
	return list
end

local function accept(player, rivalId)
	local rival = type(rivalId) == "string" and Rivals.ById[rivalId]
	if not rival or not (cardShown[player] and cardShown[player][rival.id]) then return end
	if stateOf(player, rival) ~= nil then return end -- already on, or beaten
	setState(player, rival, "active")
	say(player, rival, "intro")
end

-- the rival's NPC in Workspace.NPCs (by name and gym), with its prompt
local function wire(npc, rival)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return end
	npc:SetAttribute("Rival", rival.id)
	local prompt = root:FindFirstChild("RivalPrompt")
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = "RivalPrompt"
		created.ActionText = "Challenge"
		created.ObjectText = rival.name .. " (rival)"
		created.MaxActivationDistance = Rivals.PromptDistance
		created.RequiresLineOfSight = false
		created.Parent = root
		prompt = created
	end
	Guard.OnTriggered(prompt, function(player)
		if not PlayerData.Get(player) then return end
		-- he stops and turns to you while you read his card
		local character = player.Character
		local you = character and character:FindFirstChild("HumanoidRootPart")
		GymGoerService.Hold(npc, Rivals.HoldSeconds, you and you.Position)
		card(player, rival)
	end, { slack = 6 }) -- (he may take a step while you press)
end

function RivalService.Start()
	local existing = Remotes:FindFirstChild("Rival")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "Rival"
		created.Parent = Remotes
		remote = created
	end
	Guard.Remote(remote, "Rival", 2, 3, function(player, action, rivalId)
		if action == "Accept" then accept(player, rivalId) end
	end)

	local npcs = Workspace:WaitForChild("NPCs", 10)
	for _, rival in ipairs(Rivals.List) do
		local npc = nil
		for _, child in ipairs(npcs and npcs:GetChildren() or {}) do
			if child.Name == rival.name and child:GetAttribute("Gym") == rival.gym then npc = child end
		end
		if npc then
			wire(npc, rival)
		else
			warn("[RivalService] rival " .. rival.name .. " is not in Workspace.NPCs: build him with tools/builders/Rivals.luau")
		end
	end

	ArmWrestleService.SetExtraOpponents(armOpponents)
	GameEvents.On("Rep", function(player, _, info) onRep(player, info) end)
	GameEvents.On("ArmWrestleWon", function(player, _, info)
		local rival = Rivals.FromArmId(info and info.npc)
		if not rival then return end
		if stateOf(player, rival) == "active" then beat(player, rival) else say(player, rival, "beaten") end
	end)
	GameEvents.On("ArmWrestleLost", function(player, _, info)
		local rival = Rivals.FromArmId(info and info.npc)
		if rival then lose(player, rival) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sets[player], lastLose[player], cardShown[player] = nil, nil, nil
	end)

	-- Studio: Workspace attribute TestRivalBeat = rival id beats him for every player (his challenge turns on first, also
	-- when he was beaten already)
	if game:GetService("RunService"):IsStudio() then
		Workspace:GetAttributeChangedSignal("TestRivalBeat"):Connect(function()
			local rival = Rivals.ById[Workspace:GetAttribute("TestRivalBeat") or ""]
			Workspace:SetAttribute("TestRivalBeat", nil)
			if not rival then return end
			for _, player in ipairs(Players:GetPlayers()) do
				setState(player, rival, "active") -- (again after a win too, for screenshots)
				beat(player, rival)
			end
		end)
	end
end

return RivalService
