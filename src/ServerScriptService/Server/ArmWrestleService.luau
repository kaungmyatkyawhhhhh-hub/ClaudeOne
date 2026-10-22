-- Arm wrestling (numbers in Config.Social.ArmWrestle; owner's feature run, task 3). Every model tagged "ArmWrestleTable"
-- (the starter gym's and the pro gym's, tools/builders/ArmWrestleTable) runs its own matches. Sit down with the OCCUPY
-- prompt (Custom style: MachineSignsClient draws it like a machine's). Two players = a match. Alone, you pick an NPC
-- opponent (3 levels) or wait for a player. 3-2-1, then both tap as fast as they can for up to MaxTime: every tap pushes
-- the bar toward your side, a bit harder with bigger biceps and forearms (capped). Push it all the way, or be ahead when
-- time runs out. Coins and a little Biceps / Forearms XP for both; beating the hardest NPC = "Arm Wrestling King".
-- Everything is decided on the server; taps are capped at MaxTapsPerSecond.
-- Remote "ArmWrestle": client -> server "Tap" | "Leave" | "Npc", npcId; server -> client "State", info.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local Muscles = require(ReplicatedStorage.Shared.Config.Muscles)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Config.Economy) -- (prompt 61: rewards at the player's stage)
local BodyService = require(script.Parent.BodyService)
local Guard = require(script.Parent.Guard)
local TitleService = require(script.Parent.TitleService)
local NpcService = require(script.Parent.NpcService)
local GameEvents = require(script.Parent.GameEvents)

local Remotes = ReplicatedStorage.Remotes
local Config = Social.ArmWrestle

local ArmWrestleService = {}

local remote: RemoteEvent
local rng = Random.new()
local tables = {} -- list of tables: { model, center, seats = { { player, npc, seat, prompt } x2 }, match }

------------------------------------------------------------------------
-- What clients see
------------------------------------------------------------------------
-- Every client animates a table from attributes on it (ArmWrestleClient): AwState idle / waiting / countdown / live /
-- result, AwMeter -1..1 (+1 = seat 1 wins), AwWinner 0 (none / draw), 1 or 2.
local function publish(t, state, winner)
	t.model:SetAttribute("AwState", state or (t.match and t.match.state) or "idle")
	t.model:SetAttribute("AwMeter", t.match and t.match.meter and math.floor(t.match.meter * 100 + 0.5) / 100 or 0)
	if winner ~= nil then t.model:SetAttribute("AwWinner", winner) end
end

local function send(t, index, info)
	local seat = t.seats[index]
	if seat.player and seat.player.Parent then remote:FireClient(seat.player, "State", info) end
end

local function opponentName(t, index)
	local other = t.seats[3 - index]
	if other.player then return other.player.DisplayName end
	if other.npc then return other.npc.Name end
	return nil
end

local npcChoices = {}
for _, npc in ipairs(Config.Npcs) do table.insert(npcChoices, { id = npc.id, name = npc.name, label = npc.label, coins = npc.coins }) end

-- Extra opponents only some players can pick (an NPC rival whose challenge they accepted: RivalService sets this).
-- extraOpponents(player) -> { npc config like Config.Npcs (+ look = NpcService.Build spec) }
local extraOpponents = function(_player) return {} end
function ArmWrestleService.SetExtraOpponents(fn) extraOpponents = fn end

local function choicesFor(player)
	local extra = player and extraOpponents(player) or {}
	if #extra == 0 then return npcChoices end
	local list = table.clone(npcChoices)
	for _, npc in ipairs(extra) do table.insert(list, { id = npc.id, name = npc.name, label = npc.label }) end -- (no coins line: a rival's reward is on his card)
	return list
end

local function broadcast(t, extra)
	for index = 1, 2 do
		local alone = t.seats[3 - index].player == nil and t.seats[3 - index].npc == nil
		local info = {
			state = t.match and t.match.state or "idle",
			meter = t.match and t.match.meter or 0,
			side = index == 1 and 1 or -1,
			opponent = opponentName(t, index),
			-- alone and waiting: the NPC opponents you can pick
			npcs = (alone and t.match and t.match.state == "waiting") and choicesFor(t.seats[index].player) or nil,
		}
		for key, value in pairs(extra or {}) do info[key] = value end
		send(t, index, info)
	end
	publish(t)
end

------------------------------------------------------------------------
-- Seats
------------------------------------------------------------------------
local function tableOf(player)
	for _, t in ipairs(tables) do
		for index, seat in ipairs(t.seats) do
			if seat.player == player then return t, index end
		end
	end
	return nil, nil
end

local function standUp(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

-- One body per stool (owner, 14 Oct): an NPC opponent isn't really sitting on the Seat (it's placed there), so while an NPC
-- sits on a stool, or is on its way to it (`reserved`), the stool's Seat is Disabled: nobody can walk into it or take it
-- with the prompt. (A Seat only takes one player by itself.)
local function lockStools(t)
	for _, seat in ipairs(t.seats) do
		local taken = seat.npc ~= nil or seat.reserved == true
		if seat.seat.Disabled ~= taken and not (taken and seat.seat.Occupant) then seat.seat.Disabled = taken end
	end
end

local function clearNpc(t)
	for _, seat in ipairs(t.seats) do
		if seat.npc then
			seat.npc:Destroy()
			seat.npc = nil
		end
	end
	lockStools(t)
end

local function refreshPrompts(t)
	for _, seat in ipairs(t.seats) do
		if seat.prompt then
			seat.prompt.Enabled = seat.player == nil and seat.npc == nil and not seat.reserved and seat.seat.Occupant == nil
				and not (t.match and t.match.state ~= "waiting")
		end
	end
	lockStools(t)
end

local function leave(t, player, silent)
	for _, seat in ipairs(t.seats) do
		if seat.player == player then
			seat.player = nil
			if player.Parent then
				standUp(player)
				if not silent then remote:FireClient(player, "State", { state = "idle" }) end
			end
		end
	end
	-- nobody left: reset; one player left mid-match: they win by default (no coins: the match didn't finish)
	local remaining = t.seats[1].player or t.seats[2].player
	if t.match and t.match.state ~= "waiting" and remaining then
		remote:FireClient(remaining, "State", { state = "result", won = true, reason = "Your opponent left." })
		t.match = { state = "waiting" }
		clearNpc(t)
		publish(t, "waiting", 0)
		broadcast(t)
	elseif not remaining then
		t.match = nil
		clearNpc(t)
		publish(t, "idle", 0)
	end
	refreshPrompts(t)
end

------------------------------------------------------------------------
-- Matches
------------------------------------------------------------------------
local function strengthOf(player)
	local data = PlayerData.Get(player)
	if not data then return 1 end
	local levels, goal = BodyService.LevelsOf(data)
	return Social.Strength(Muscles.LooksFromLevels(levels, goal))
end

local function giveXp(player, amount)
	for _, id in ipairs(Config.Muscles) do PlayerData.AddMuscleXp(player, id, amount) end
	TitleService.Check(player)
end

local function finish(t, winnerIndex, reason)
	local match = t.match
	if not match then return end
	local npc = match.npc -- the NPC opponent's config, if any
	for index = 1, 2 do
		local player = t.seats[index].player
		if player then
			local won = index == winnerIndex
			-- (prompt 61) at the player's stage (the old amounts are the floors)
			local data = PlayerData.Get(player)
			local spurts = data and data.growthSpurts
			local coins = Economy.Reward(spurts, Economy.Rewards.ArmLose, Config.LoseCoins)
			if won then coins = Economy.Reward(spurts, Economy.Rewards.ArmWin, npc and npc.coins or Config.WinCoins) end
			PlayerData.AddCoins(player, coins)
			giveXp(player, won and Config.Xp.Win or Config.Xp.Lose)
			if won then
				local data = PlayerData.Get(player)
				if data then
					PlayerData.SetStat(player, "armWins", (data.stats.armWins or 0) + 1)
					if npc and npc.king then PlayerData.SetStat(player, "armKingWins", (data.stats.armKingWins or 0) + 1) end
					TitleService.Check(player) -- "Iron Grip", "Arm Wrestling King"
					GameEvents.Fire("ArmWrestleWon", player, 1, { npc = npc and npc.id })
				end
			elseif npc and winnerIndex then
				GameEvents.Fire("ArmWrestleLost", player, 1, { npc = npc.id })
			end
			remote:FireClient(player, "State", { state = "result", won = won, draw = winnerIndex == nil, coins = coins, reason = reason,
				king = won and npc ~= nil and npc.king == true, opponent = opponentName(t, index), side = index == 1 and 1 or -1 })
		end
	end
	-- pinned / time: the winner slams the arm down (clients animate it), then everyone stands up
	if winnerIndex and reason == "Pinned!" then match.meter = winnerIndex == 1 and 1 or -1 end
	publish(t, "result", winnerIndex or 0)
	t.match = nil
	-- the NPC stays seated for the slam, then leaves with the player
	-- (its stool stays reserved until it's gone: one body per stool)
	local seated, seatedOn = nil, nil
	for _, seat in ipairs(t.seats) do
		if seat.npc then
			seated, seatedOn = seat.npc, seat
			seat.npc = nil
			seat.reserved = true
		end
	end
	task.delay(2.5, function()
		if seated then
			seated:Destroy()
			seatedOn.reserved = nil
		end
		for _, seat in ipairs(t.seats) do
			if seat.player and not t.match then leave(t, seat.player, false) end
		end
		refreshPrompts(t)
	end)
end

local function startMatch(t)
	-- this match only: if a player leaves, t.match is replaced and this thread must stop
	local started: any = t.match
	if not started then return end
	started.state = "countdown"
	started.meter = 0
	started.lastTap = {}
	started.strength = {}
	refreshPrompts(t)
	for index = 1, 2 do
		local seat = t.seats[index]
		started.strength[index] = seat.player and strengthOf(seat.player) or 1
	end
	if started.npc then
		started.npcIndex = t.seats[1].npc and 1 or 2
		started.strength[started.npcIndex] = started.npc.strength
		started.npcRate = rng:NextNumber(started.npc.taps[1], started.npc.taps[2])
	end
	for count = Config.Countdown, 1, -1 do
		if t.match ~= started then return end
		broadcast(t, { countdown = count })
		task.wait(1)
	end
	if t.match ~= started or started.state ~= "countdown" then return end
	started.state = "live"
	started.startedAt = os.clock()
	broadcast(t, { countdown = 0 })

	while t.match == started and started.state == "live" do
		local dt = task.wait(0.1)
		if t.match ~= started then return end
		if started.npcIndex and math.abs(started.meter) < 1 then
			local dir = started.npcIndex == 1 and 1 or -1
			started.meter += dir * Config.PushPerTap * started.strength[started.npcIndex] * started.npcRate * dt
		end
		started.meter = math.clamp(started.meter, -1, 1)
		broadcast(t)
		if started.meter >= 1 then
			finish(t, 1, "Pinned!")
		elseif started.meter <= -1 then
			finish(t, 2, "Pinned!")
		elseif os.clock() - started.startedAt >= Config.MaxTime then
			if math.abs(started.meter) < 0.02 then
				finish(t, nil, "Draw.")
			else
				finish(t, started.meter > 0 and 1 or 2, "Time! Ahead on points.")
			end
		end
	end
end

local function tap(player)
	local t, index = tableOf(player)
	local match = t and t.match
	if not match or match.state ~= "live" then return end
	local now = os.clock()
	-- the cap: taps closer together than 1 / MaxTapsPerSecond are ignored
	if now - (match.lastTap[index] or 0) < 1 / Config.MaxTapsPerSecond then return end
	match.lastTap[index] = now
	local dir = index == 1 and 1 or -1
	match.meter = math.clamp(match.meter + dir * Config.PushPerTap * match.strength[index], -1, 1)
	-- a pin counts the moment the bar is full (before an NPC's next push can take it back)
	if math.abs(match.meter) >= 1 then finish(t, match.meter > 0 and 1 or 2, "Pinned!") end
end

-- An NPC opponent sits down on the free stool (the player chose it).
local function seatNpc(t, index, npc)
	local seat = t.seats[index]
	-- only onto an empty stool; hold it while the NPC is being built
	if seat.player or seat.npc or seat.reserved or seat.seat.Occupant then return false end
	seat.reserved = true
	refreshPrompts(t)
	local function release()
		seat.reserved = nil
		refreshPrompts(t)
	end
	-- animated: only the root is anchored, so ArmWrestleClient can pose it (seated, arm on the table) like a player
	local stool = seat.seat
	local facing = CFrame.lookAt(stool.Position, Vector3.new(t.center.X, stool.Position.Y, t.center.Z))
	-- (a rival wears his own look: the same spec and size as in his gym, Config.Rivals)
	local spec = npc.look and table.clone(npc.look) or { skin = npc.skin, shirt = npc.shirt, pants = npc.pants }
	spec.name, spec.animated = npc.name, true
	local model = NpcService.Build(spec, facing)
	if not model then
		release()
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		model:PivotTo(facing * CFrame.new(0, Config.SeatedRootY, 0) * root.CFrame:ToObjectSpace(model:GetPivot()))
	end
	model:SetAttribute("ArmWrestleSide", index)
	model:SetAttribute("ArmWrestleTable", t.model.Name)
	CollectionService:AddTag(model, "ArmWrestleRookie")
	-- the player may have left while the NPC was being built (or someone got onto the stool)
	if not t.match or t.match.state ~= "waiting" or not (t.seats[1].player or t.seats[2].player) or seat.player or seat.seat.Occupant then
		model:Destroy()
		release()
		return false
	end
	seat.reserved = nil
	seat.npc = model
	t.match.npc = npc
	refreshPrompts(t)
	task.spawn(startMatch, t)
	return true
end

local function chooseNpc(player, npcId)
	local t, index = tableOf(player)
	local npc = type(npcId) == "string" and Config.NpcById[npcId]
	if not npc and type(npcId) == "string" then
		for _, extra in ipairs(extraOpponents(player)) do
			if extra.id == npcId then npc = extra end
		end
	end
	if not t or not npc or not t.match or t.match.state ~= "waiting" then return end
	local other = t.seats[3 - index]
	if other.player or other.npc or other.reserved or other.seat.Occupant then return end
	seatNpc(t, 3 - index, npc)
end

-- Someone sat on a stool (from the prompt, or by walking into it): they join the table.
local function joined(t, player, index)
	local seat = t.seats[index]
	if seat.player == player then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local busy = false
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then busy = true end
	end
	local elsewhere = tableOf(player)
	if seat.npc or seat.reserved or t.seats[3 - index].player == player or elsewhere or busy or not PlayerData.Get(player) or (t.match and t.match.state ~= "waiting") then
		if humanoid then humanoid.Sit = false end
		return
	end
	seat.player = player
	refreshPrompts(t)
	if t.seats[1].player and t.seats[2].player then
		t.match = t.match or { state = "waiting" }
		task.spawn(startMatch, t)
		return
	end
	t.match = { state = "waiting" }
	broadcast(t)
end

local function setupTable(model)
	local top = model:FindFirstChild("Top")
	local stools = { model:FindFirstChild("Stool1"), model:FindFirstChild("Stool2") }
	if not (top and stools[1] and stools[2]) then
		warn("[ArmWrestleService] " .. model:GetFullName() .. " is missing its Top or stools")
		return
	end
	local t = { model = model, center = top.Position, seats = {}, match = nil }
	for index = 1, 2 do
		local stool = stools[index]
		local prompt = stool:FindFirstChild("ArmWrestlePrompt")
		t.seats[index] = { player = nil, npc = nil, seat = stool, prompt = prompt }
		if prompt then
			-- the machines' prompt (MachineSignsClient draws the key and OCCUPY over the table's sign)
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.ActionText = "Occupy"
			prompt.ObjectText = "Arm wrestling"
			Guard.OnTriggered(prompt, function(player)
				local seat = t.seats[index]
				if seat.player or seat.npc or seat.reserved or stool.Occupant or stool.Disabled then return end
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then stool:Sit(humanoid) end
			end)
		end
		stool:GetPropertyChangedSignal("Occupant"):Connect(function()
			local occupant = stool.Occupant
			local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
			if player then
				joined(t, player, index)
			elseif occupant then
				-- (only players sit on the stools; NPC opponents are placed by seatNpc): break the weld, Sit = false alone
				-- doesn't unseat a body the server doesn't own
				occupant.Sit = false
				local weld = stool:FindFirstChild("SeatWeld")
				if weld then weld:Destroy() end
			elseif t.seats[index].player then
				leave(t, t.seats[index].player, false)
			else
				refreshPrompts(t) -- (a player stood up after the table had already let them go)
			end
		end)
	end
	publish(t, "idle", 0)
	table.insert(tables, t)
end

local function leaveAll(player, silent)
	local t = tableOf(player)
	if t then leave(t, player, silent) end
end

function ArmWrestleService.Start()
	local existing = Remotes:FindFirstChild("ArmWrestle")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "ArmWrestle"
		created.Parent = Remotes
		remote = created
	end
	for _, model in ipairs(CollectionService:GetTagged("ArmWrestleTable")) do setupTable(model) end
	if #tables == 0 then
		warn("[ArmWrestleService] no arm wrestling tables (tag ArmWrestleTable): build them with tools/builders/ArmWrestleTable.luau")
		return
	end
	-- taps are capped again inside tap() (MaxTapsPerSecond); this stops floods of anything else
	Guard.Remote(remote, "ArmWrestle", Config.MaxTapsPerSecond + 6, 30, function(player, action, arg)
		if action == "Tap" then
			tap(player)
		elseif action == "Npc" then
			chooseNpc(player, arg)
		elseif action == "Leave" then
			local t = tableOf(player)
			if t and (not t.match or t.match.state == "waiting") then leave(t, player, false) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) leaveAll(player, true) end)
	local function hook(player)
		player.CharacterRemoving:Connect(function() leaveAll(player, true) end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
end

return ArmWrestleService
