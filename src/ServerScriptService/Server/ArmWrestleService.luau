-- Arm wrestling (numbers in Config.Social.ArmWrestle). A table on the right side of the gym with two stools.
-- Sit down (prompt), wait for a second player (or a practice opponent after a few seconds), 3-2-1, then both tap
-- as fast as they can: every tap pushes the meter toward your side, harder with stronger Biceps, Forearms and
-- Front Delts. Push it all the way, or be ahead when time runs out. Everything is decided on the server.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local TitleService = require(script.Parent.TitleService)
local NpcService = require(script.Parent.NpcService)

local Remotes = ReplicatedStorage.Remotes
local Config = Social.ArmWrestle

local ArmWrestleService = {}

local remote -- RemoteEvent "ArmWrestle": client -> server "Tap" / "Leave"; server -> client "State", info
local rng = Random.new()

-- seats[1] pushes the meter toward +1, seats[2] toward -1
local seats = {
	{ player = nil, rookie = nil, seat = nil, cframe = nil, prompt = nil },
	{ player = nil, rookie = nil, seat = nil, cframe = nil, prompt = nil },
}
local match = nil -- { state = "waiting" | "countdown" | "live", meter, startedAt, lastTap = {}, strength = {}, rookie }

------------------------------------------------------------------------
-- The table
------------------------------------------------------------------------
local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildTable()
	local model = Instance.new("Model")
	model.Name = "ArmWrestleTable"
	local base = CFrame.new(Config.TableSpot)
	local dark = Color3.fromHex("#1E1E22")
	local steel = Color3.fromHex("#9EA2A8")
	part(model, "Top", Vector3.new(2.6, 0.25, 2.2), base * CFrame.new(0, 3.1, 0), dark)
	part(model, "Post", Vector3.new(0.5, 3, 0.5), base * CFrame.new(0, 1.5, 0), steel, Enum.Material.Metal)
	part(model, "Foot", Vector3.new(2, 0.2, 2), base * CFrame.new(0, 0.1, 0), dark)
	part(model, "PadA", Vector3.new(0.5, 0.08, 0.7), base * CFrame.new(-0.75, 3.26, 0), Color3.fromHex("#D7262E"))
	part(model, "PadB", Vector3.new(0.5, 0.08, 0.7), base * CFrame.new(0.75, 3.26, 0), Color3.fromHex("#1F5FBF"))
	part(model, "Peg", Vector3.new(0.12, 0.6, 0.12), base * CFrame.new(0, 3.5, 0.75), steel, Enum.Material.Metal)

	for index, side in ipairs({ -1, 1 }) do
		-- a real Seat, so players sit with the normal sitting pose; it faces the table
		local seatPosition = Config.TableSpot + Vector3.new(side * 2.2, 0.9, 0)
		local stool = Instance.new("Seat")
		stool.Name = "Stool" .. index
		stool.Size = Vector3.new(1.4, 1.8, 1.4)
		stool.CFrame = CFrame.lookAt(seatPosition, Vector3.new(Config.TableSpot.X, seatPosition.Y, Config.TableSpot.Z))
		stool.Color = dark
		stool.Material = Enum.Material.SmoothPlastic
		stool.Anchored = true
		stool.TopSurface, stool.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		stool.Parent = model
		seats[index].seat = stool
		-- a practice opponent stands just behind the stool
		seats[index].cframe = CFrame.lookAt(Config.TableSpot + Vector3.new(side * 3, 0, 0), Config.TableSpot)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ArmWrestlePrompt"
		prompt.ActionText = "Arm wrestle"
		prompt.ObjectText = "Sit down"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = stool
		seats[index].prompt = prompt
	end
	CollectionService:AddTag(model, "ArmWrestleTable")
	model.Parent = Workspace
end

------------------------------------------------------------------------
-- Seating
------------------------------------------------------------------------
local function send(index, info)
	local seat = seats[index]
	if seat.player and seat.player.Parent then remote:FireClient(seat.player, "State", info) end
end

local function opponentName(index)
	local other = seats[3 - index]
	if other.player then return other.player.DisplayName end
	if other.rookie then return other.rookie.Name end
	return nil
end

local function broadcast(extra)
	for index = 1, 2 do
		local info = {
			state = match and match.state or "idle",
			meter = match and match.meter or 0,
			side = index == 1 and 1 or -1,
			opponent = opponentName(index),
		}
		for key, value in pairs(extra or {}) do info[key] = value end
		send(index, info)
	end
end

local function standUp(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

local function clearRookie()
	for _, seat in ipairs(seats) do
		if seat.rookie then
			seat.rookie:Destroy()
			seat.rookie = nil
		end
	end
end

local function refreshPrompts()
	for _, seat in ipairs(seats) do
		if seat.prompt then seat.prompt.Enabled = seat.player == nil and seat.rookie == nil end
	end
end

local function leave(player, silent)
	for index, seat in ipairs(seats) do
		if seat.player == player then
			seat.player = nil
			if player.Parent then
				standUp(player)
				if not silent then remote:FireClient(player, "State", { state = "idle" }) end
			end
		end
	end
	-- nobody left at the table: reset; one player left mid-match: they win by default
	local remaining = seats[1].player or seats[2].player
	if match and match.state ~= "waiting" and remaining then
		remote:FireClient(remaining, "State", { state = "result", won = true, reason = "Your opponent left." })
		match = { state = "waiting" }
		clearRookie()
	elseif not remaining then
		match = nil
		clearRookie()
	end
	refreshPrompts()
end

------------------------------------------------------------------------
-- Matches
------------------------------------------------------------------------
local function strengthOf(player)
	local data = PlayerData.Get(player)
	return data and Social.Strength(data.muscles) or 1
end

local function finish(winnerIndex, reason)
	if not match then return end
	local practice = match.rookie ~= nil
	for index = 1, 2 do
		local player = seats[index].player
		if player then
			local won = index == winnerIndex
			local coins = won and (practice and Config.PracticeWinCoins or Config.WinCoins) or Config.LoseCoins
			if winnerIndex == nil then coins = Config.LoseCoins end
			PlayerData.AddCoins(player, coins)
			if won then
				local data = PlayerData.Get(player)
				if data then
					PlayerData.SetStat(player, "armWins", (data.stats.armWins or 0) + 1)
					TitleService.Check(player)
				end
			end
			remote:FireClient(player, "State", { state = "result", won = won, draw = winnerIndex == nil, coins = coins, reason = reason })
		end
	end
	match = nil
	clearRookie()
	-- both players stand up after a match, so the next pair can sit
	task.delay(2.5, function()
		for _, seat in ipairs(seats) do
			if seat.player and not match then leave(seat.player, false) end
		end
	end)
end

local function startMatch()
	match.state = "countdown"
	match.meter = 0
	match.lastTap = {}
	match.strength = {}
	for index = 1, 2 do
		local seat = seats[index]
		match.strength[index] = seat.player and strengthOf(seat.player) or 1
	end
	if match.rookie then
		local playerIndex = seats[1].player and 1 or 2
		local rookieIndex = 3 - playerIndex
		local range = Config.RookieStrength
		match.strength[rookieIndex] = match.strength[playerIndex] * rng:NextNumber(range[1], range[2])
		match.rookieIndex = rookieIndex
		match.rookieRate = rng:NextNumber(Config.RookieTapsPerSecond[1], Config.RookieTapsPerSecond[2])
	end
	for count = Config.Countdown, 1, -1 do
		if not match then return end
		broadcast({ countdown = count })
		task.wait(1)
	end
	if not match then return end
	match.state = "live"
	match.startedAt = os.clock()
	broadcast({ countdown = 0 })

	local current = match
	while match == current and match.state == "live" do
		local dt = task.wait(0.1)
		if match ~= current then return end
		if match.rookieIndex then
			local pushes = match.rookieRate * dt
			local dir = match.rookieIndex == 1 and 1 or -1
			match.meter += dir * Config.PushPerTap * match.strength[match.rookieIndex] * pushes
		end
		match.meter = math.clamp(match.meter, -1, 1)
		broadcast()
		if match.meter >= 1 then
			finish(1, "Pinned!")
		elseif match.meter <= -1 then
			finish(2, "Pinned!")
		elseif os.clock() - match.startedAt >= Config.MaxSeconds then
			if math.abs(match.meter) < 0.02 then
				finish(nil, "Draw.")
			else
				finish(match.meter > 0 and 1 or 2, "Time! Ahead on points.")
			end
		end
	end
end

local function tap(player)
	if not match or match.state ~= "live" then return end
	local index = seats[1].player == player and 1 or (seats[2].player == player and 2 or nil)
	if not index then return end
	local now = os.clock()
	if now - (match.lastTap[index] or 0) < 1 / Config.MaxTapsPerSecond then return end
	match.lastTap[index] = now
	local dir = index == 1 and 1 or -1
	match.meter = math.clamp(match.meter + dir * Config.PushPerTap * match.strength[index], -1, 1)
end

local function seatRookie(index)
	local spec = Config.Rookies[rng:NextInteger(1, #Config.Rookies)]
	local rookieSpec = { name = spec.name, skin = spec.skin, shirt = spec.shirt, pants = spec.pants }
	local model = NpcService.Build(rookieSpec, seats[index].cframe)
	seats[index].rookie = model
	match.rookie = model
	refreshPrompts()
	task.spawn(startMatch)
end

-- Someone sat on a stool (from the prompt, or by walking into it): they join the table.
local function joined(player, index)
	local seat = seats[index]
	if seat.player == player then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local onMachine = false
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then onMachine = true end
	end
	if seat.rookie or seats[3 - index].player == player or onMachine or not PlayerData.Get(player) or (match and match.state ~= "waiting") then
		if humanoid then humanoid.Sit = false end
		return
	end
	seat.player = player
	refreshPrompts()
	if seats[1].player and seats[2].player then
		match = match or { state = "waiting" }
		task.spawn(startMatch)
		return
	end
	match = { state = "waiting" }
	broadcast()
	local waitingMatch = match
	task.delay(Config.WaitForOpponent, function()
		if match == waitingMatch and match.state == "waiting" and seat.player == player and not seats[3 - index].player then
			seatRookie(3 - index)
		end
	end)
end

local function prompted(player, index)
	local seat = seats[index]
	if seat.player or seat.rookie then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then seat.seat:Sit(humanoid) end
end

local function watchSeat(index)
	local seat = seats[index]
	seat.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if player then
			joined(player, index)
		elseif seat.player then
			leave(seat.player, false)
		end
	end)
end

function ArmWrestleService.Start()
	remote = Remotes:FindFirstChild("ArmWrestle")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ArmWrestle"
		remote.Parent = Remotes
	end
	buildTable()
	for index, seat in ipairs(seats) do
		Guard.OnTriggered(seat.prompt, function(player) prompted(player, index) end)
		watchSeat(index)
	end
	-- taps are capped again inside tap() (MaxTapsPerSecond); this stops floods of anything else
	Guard.Remote(remote, "ArmWrestle", Config.MaxTapsPerSecond + 6, 30, function(player, action)
		if action == "Tap" then
			tap(player)
		elseif action == "Leave" then
			if not match or match.state == "waiting" then leave(player, false) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) leave(player, true) end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function() leave(player, true) end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterRemoving:Connect(function() leave(player, true) end)
	end
end

return ArmWrestleService
