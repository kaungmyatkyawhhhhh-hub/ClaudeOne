-- PosingCompService: the posing show on the beach stage (Config.PosingComp; owner's feature run, task 1, reworked for
-- prompt 18, 21 Oct: a show every 5 minutes with height divisions).
-- Every Interval seconds a show starts. Whoever (Growth Spurt 1+) stands on the stage at the start is in; the last
-- JoinWindow seconds the clients show JOIN (action "Join": a far player is put on the stage, a near one gets a path).
-- Contestants are split into divisions by height (Config.PosingComp.Divisions) and each division runs on its own, smallest
-- first, with NPC competitors filling up a small division: line up on the marks, the judges call 4 poses (everyone hits
-- each one together), then the judges score each contestant out of 100 (size against the division's best + balance +
-- stage presence) and every breakdown is shown ("Size 52 / Balance 21 / Presence 11 = 84"). The top 3 go on the podium.
-- Rewards by the player's own show level (Config.PosingComp.Shows): coins for every place, a trophy for 1st. Stats:
-- posingEntries, posingWins, posingTrophies, posingBest. The winner of the last division (a player) becomes the statue.
-- Leaving the stage, dying or leaving the game during your division = out, no reward. Nobody else is interrupted.
-- Studio: Workspace attribute TestPosingComp = true starts a show in TestPosingCountdown seconds (default 10);
-- TestPosingWatch = true runs an NPC-only Middle division (to watch).
-- Remote "PosingComp": server -> clients (kind, info); clients -> server "Join" | "Seen" | "State".
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")

local Config = ReplicatedStorage.Shared.Config
local PosingComp = require(Config.PosingComp)
local ShowOff = require(Config.ShowOff)
local Muscles = require(Config.Muscles)
local GrowthSpurts = require(Config.GrowthSpurts)
local Alters = require(Config.Alters) -- (prompt 21: divisions by alter tier at 7'0", c.alterTier = the alter number)
local Town = require(Config.Town)
local Body = require(Config.Body)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Config.Economy) -- (prompt 61: rewards at the player's stage)
local BodyService = require(script.Parent.BodyService)
local NpcService = require(script.Parent.NpcService)
local ShowOffService = require(script.Parent.ShowOffService)
local TitleService = require(script.Parent.TitleService)
local GameEvents = require(script.Parent.GameEvents)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local PosingCompService = {}

local remote: RemoteEvent
local rng = Random.new()
local pieces = nil     -- { marks = { BasePart }, podium = { BasePart }, board = { title, status, rows } }
local show: any = nil  -- the running show (nil between shows)
local nextShowAt = 0   -- server time the next show starts
local lastResults = nil -- { { name, total } } of the last division, for the scoreboard
local seen = {}        -- [player] = true once the timer was logged as seen this session

local function now() return Workspace:GetServerTimeNow() end

-- Analytics (prompt 18): custom events; never breaks the show
local function logEvent(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
	if RunService:IsStudio() then print(string.format("[Analytics] %s %s = %s", player.Name, name, tostring(value or 1))) end
end

------------------------------------------------------------------------
-- Stage pieces (tools/builders/PosingComp)
------------------------------------------------------------------------
local function findPieces()
	local stage = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("PosingStage")
	local folder = stage and stage:WaitForChild("Feature_PosingComp", 10)
	if not folder then return nil end
	local found = { marks = {}, podium = {}, board = nil }
	for i = 1, PosingComp.MaxPlayers do
		local mark = folder:FindFirstChild("Mark" .. i)
		if mark then table.insert(found.marks, mark) end
	end
	local podium = folder:FindFirstChild("Podium")
	for place = 1, 3 do
		local spot = podium and podium:FindFirstChild("Spot" .. place)
		if spot then found.podium[place] = spot end
	end
	local screen = folder:FindFirstChild("Scoreboard") and folder.Scoreboard:FindFirstChild("Screen", true)
	local gui = screen and screen:FindFirstChildOfClass("SurfaceGui")
	if gui then
		local rows = {}
		for i = 1, 6 do
			local row = gui:FindFirstChild("Row" .. i)
			if row then rows[i] = { name = row:FindFirstChild("Name"), score = row:FindFirstChild("Score") } end
		end
		found.board = { title = gui:FindFirstChild("Title"), status = gui:FindFirstChild("Status"), rows = rows }
	end
	if #found.marks == 0 then return nil end
	return found
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function setBoard(status, rows)
	local board = pieces and pieces.board
	if not board then return end
	if board.status then board.status.Text = status end
	for i, row in ipairs(board.rows) do
		local entry = rows and rows[i]
		if row.name then row.name.Text = entry and entry[1] or "" end
		if row.score then row.score.Text = entry and entry[2] or "" end
	end
end

------------------------------------------------------------------------
-- Who is where
------------------------------------------------------------------------
local function stageTop()
	return Town.Stage.Center.Y + Town.Stage.Size.Y + 0.2
end

local function onStage(position: Vector3): boolean
	local stage = Town.Stage
	local half = stage.Size / 2 + Vector3.new(PosingComp.StageMargin, 0, PosingComp.StageMargin)
	local offset = position - stage.Center
	return math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and position.Y > stageTop() - 1 and position.Y < stageTop() + 9
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	return root
end

local function onMachine(player: Player): boolean
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then return true end
	end
	return false
end

local function spurtsOf(player: Player): number
	local data = PlayerData.Get(player)
	return data and data.growthSpurts or 0
end

-- Stand a character at `feet` (a point on a top surface), facing the crowd (-Z).
local function standAt(model: Model, feet: Vector3)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local height = (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2
	model:PivotTo(CFrame.lookAt(feet, feet - Vector3.zAxis) + Vector3.new(0, height, 0))
end
local function topOf(part: BasePart): Vector3
	return Vector3.new(part.Position.X, part.Position.Y + part.Size.Y / 2, part.Position.Z)
end

-- n spots evenly along the line of marks (the builder made MaxPlayers marks; up to MaxPerDivision stand along them)
local function lineSpots(n: number): { Vector3 }
	local first, last = topOf(pieces.marks[1]), topOf(pieces.marks[#pieces.marks])
	local spots = {}
	if n <= 1 then
		spots[1] = first:Lerp(last, 0.5)
		return spots
	end
	-- (a few contestants: a little closer together around the middle; names over heads need the room)
	local spread = math.min(1, 0.4 + 0.15 * n)
	for i = 1, n do
		local t = 0.5 + (((i - 1) / (n - 1)) - 0.5) * spread
		spots[i] = first:Lerp(last, t)
	end
	return spots
end

------------------------------------------------------------------------
-- Contestants
------------------------------------------------------------------------
local function bodyValues(data)
	local levels, goal = BodyService.LevelsOf(data)
	local looks = Muscles.LooksFromLevels(levels, goal)
	return PosingComp.SizeAndBalance(looks, Muscles.Groups)
end

local function buildNpc(spec, share: number, feet: Vector3)
	local skin = Color3.fromHex(spec.skin)
	local shorts = Body.ShortsColor(spec.shorts)
	local model = NpcService.Build({
		name = spec.name, skin = spec.skin, shirt = spec.skin, pants = shorts:ToHex(), animated = true, tag = "Poser",
	}, CFrame.lookAt(feet, feet - Vector3.zAxis))
	-- shirtless in gym shorts: bare lower legs and bare feet (owner, 23 Oct: no shoes; the muscles take their colors from
	-- the body parts)
	for _, name in ipairs({ "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then part.Color = skin end
	end
	model:SetAttribute("MuscleG", BodyService.EncodeShare(share))
	model:SetAttribute("SkinColor", skin)
	model:SetAttribute("Top", "Shirtless")
	model:SetAttribute("Shorts", spec.shorts)
	model:SetAttribute("PosingNpc", true)
	standAt(model, feet)
	return model
end

local function contestantModel(c)
	if c.player then return c.player.Character end
	return c.model
end

local function contestantList(division)
	local list = {}
	for i, c in ipairs(division.contestants) do
		list[i] = { name = c.name, userId = c.player and c.player.UserId or 0, npc = c.player == nil, out = c.out, score = c.score }
	end
	return list
end

local function broadcast(kind, info)
	remote:FireAllClients(kind, info)
end

------------------------------------------------------------------------
-- A contestant drops out (left the stage, died, left the game)
------------------------------------------------------------------------
local function release(c)
	if c.player then
		if c.player.Parent then ShowOffService.ReleasePose(c.player) end
	elseif c.model and c.model.Parent then
		c.model:SetAttribute("Pose", "")
	end
end

local function dropOut(division, c, reason)
	if c.out then return end
	c.out = true
	release(c)
	if c.player and c.player.Parent then c.player:SetAttribute("PosingComp", nil) end
	broadcast("Out", { name = c.name, userId = c.player and c.player.UserId or 0, reason = reason, contestants = contestantList(division) })
end

local function checkContestants(division)
	for _, c in ipairs(division.contestants) do
		if not c.out and c.player then
			local root = c.player.Parent and rootOf(c.player)
			if not c.player.Parent then
				dropOut(division, c, "left")
			elseif not root then
				dropOut(division, c, "reset")
			elseif not onStage(root.Position) then
				dropOut(division, c, "stage")
			end
		end
	end
end

------------------------------------------------------------------------
-- One division
------------------------------------------------------------------------
local function setPose(c, emote)
	if c.out then return end
	if c.player then
		ShowOffService.SetPose(c.player, emote)
	elseif c.model and c.model.Parent then
		c.model:SetAttribute("Pose", emote.poseData)
	end
end

local function results(division)
	-- the judges: size against the division's best (only who's still in), balance, stage presence
	local best = 0
	for _, c in ipairs(division.contestants) do
		if not c.out then best = math.max(best, c.size) end
	end
	local ranked = {}
	for _, c in ipairs(division.contestants) do
		if not c.out then
			c.score = PosingComp.Score(c.size, c.balance, c.height, best, c.alterTier)
			table.insert(ranked, c)
		end
	end
	table.sort(ranked, function(a, b)
		if a.score.total ~= b.score.total then return a.score.total > b.score.total end
		return a.order < b.order
	end)
	broadcast("Scores", { division = division.def.name, contestants = contestantList(division) })
	local rows = {}
	for place, c in ipairs(ranked) do
		if place <= 6 then rows[place] = { place .. ". " .. c.name, tostring(c.score.total) } end
	end
	setBoard(division.def.name .. ": the judges' scores", rows)
	task.wait(PosingComp.ScoreShow)

	local list = {}
	for place, c in ipairs(ranked) do
		list[place] = { name = c.name, total = c.score.total, npc = c.player == nil, userId = c.player and c.player.UserId or 0 }
		local model = contestantModel(c)
		if place <= 3 and model and pieces.podium[place] then standAt(model, topOf(pieces.podium[place])) end
		if c.player and c.player.Parent then
			local data = PlayerData.Get(c.player)
			local level = PosingComp.ShowFor(data and data.growthSpurts or 0) or PosingComp.Shows[1]
			-- (prompt 61) the prize at the player's stage (Config/Economy.Rewards.Posing; the show's own amount is the floor)
			local minutes = Economy.Rewards.Posing[place] or Economy.Rewards.PosingEnter
			local coins = Economy.Reward(data and data.growthSpurts, minutes, level.coins[place] or level.enter)
			-- (prompt 45) the worn aura's show prize perk: the prize only, never the score
			coins = math.floor(coins * (1 + require(game:GetService("ReplicatedStorage").Shared.Config.Auras).Perk(c.player:GetAttribute("Aura"), "showPrize")) + 0.5)
			PlayerData.AddCoins(c.player, coins)
			if data then
				local stats = data.stats
				PlayerData.SetStat(c.player, "posingBest", math.max(stats.posingBest or 0, c.score.total))
				if place == 1 then
					PlayerData.SetStat(c.player, "posingWins", (stats.posingWins or 0) + 1)
					PlayerData.SetStat(c.player, "posingTrophies", (stats.posingTrophies or 0) + 1)
					GameEvents.Fire("PosingWon", c.player, 1)
				end
			end
			TitleService.Check(c.player) -- (first show, first win, 10 wins, 50 wins)
			logEvent(c.player, "PosingPlaced", if place <= 3 then place else 4)
			remote:FireClient(c.player, "Reward", { place = place, coins = coins, trophy = place == 1, show = level.name, division = division.def.name,
				score = c.score })
		end
	end
	lastResults = list
	broadcast("Results", { division = division.def.name, show = division.show and division.show.name or "", ranking = list })
	local board = {}
	for place, entry in ipairs(list) do
		if place <= 6 then board[place] = { place .. ". " .. entry.name, tostring(entry.total) } end
	end
	setBoard(ranked[1] and (division.def.name .. " winner: " .. ranked[1].name) or "No winner", board)
	task.wait(PosingComp.PodiumTime)
	return ranked[1]
end

local function runDivision(division)
	-- line up: players first (in the order they stood closest to the middle), then the NPCs, spread along the marks
	local spots = lineSpots(#division.contestants)
	for i, c in ipairs(division.contestants) do
		local model = contestantModel(c)
		if c.player then
			if model then standAt(model, spots[i]) end
			c.player:SetAttribute("PosingComp", true) -- (PoseClient hides its everyday pose panel meanwhile)
		else
			local ok, built = pcall(buildNpc, c.spec, c.share, spots[i])
			if ok then c.model = built else
				warn("[PosingCompService] could not build an NPC competitor:", built)
				c.out = true
			end
		end
	end
	local watcher = RunService.Heartbeat:Connect(function()
		checkContestants(division)
	end)
	broadcast("Division", { division = division.def.name, show = division.show and division.show.name or "", index = division.index,
		count = division.count, contestants = contestantList(division), intro = PosingComp.Intro })
	setBoard(division.def.name .. " division: take your marks", nil)
	task.wait(PosingComp.Intro)
	local winner = nil
	for index, poseId in ipairs(PosingComp.Poses) do
		local anyPlayer = false
		for _, c in ipairs(division.contestants) do
			if not c.out and c.player then anyPlayer = true end
		end
		if not anyPlayer and not division.npcsOnly then break end -- every player dropped out: nothing left to judge
		local emote = ShowOff.EmoteById[poseId]
		broadcast("Pose", { division = division.def.name, index = index, count = #PosingComp.Poses, poseId = poseId, name = emote.name,
			endsAt = now() + PosingComp.PoseTime, contestants = contestantList(division) })
		setBoard(string.format("%s: %s (%d/%d)", division.def.name, emote.name, index, #PosingComp.Poses), nil)
		for _, c in ipairs(division.contestants) do setPose(c, emote) end
		task.wait(PosingComp.PoseTime)
		checkContestants(division)
	end
	watcher:Disconnect()
	local anyIn = false
	for _, c in ipairs(division.contestants) do
		if not c.out and (c.player or division.npcsOnly) then anyIn = true end
	end
	if anyIn then winner = results(division) end
	-- off the stage: players stay where they are, NPCs go
	for _, c in ipairs(division.contestants) do
		release(c)
		if c.player and c.player.Parent then c.player:SetAttribute("PosingComp", nil) end
		if c.model then c.model:Destroy() end
	end
	return winner
end

------------------------------------------------------------------------
-- A whole show
------------------------------------------------------------------------
local function npcsFor(def, players: number)
	local count = 0
	if players < PosingComp.NpcFillTo then count = math.max(PosingComp.NpcFillTo - players, if players > 0 then PosingComp.NpcMin else 0) end
	count = math.min(count, PosingComp.MaxPerDivision - players, #PosingComp.Npcs)
	local pool = table.clone(PosingComp.Npcs)
	local range = PosingComp.NpcShare[def.id] or (if def.alterTier then PosingComp.NpcShare.Open else { 0.5, 1 })
	local list = {}
	for _ = 1, count do
		local spec = table.remove(pool, rng:NextInteger(1, #pool))
		local share = rng:NextNumber(range[1], range[2])
		table.insert(list, { spec = spec, name = spec.name, share = share, size = share / PosingComp.SizeFull, balance = rng:NextNumber(0.75, 1),
			height = PosingComp.NpcHeight[def.id] or (if def.alterTier then 84 else 66), out = false,
			-- (an NPC in an alter division has an alter in that tier)
			alterTier = if def.alterTier and def.alterTier > 0 then rng:NextInteger(def.alterTier * 5 - 4, def.alterTier * 5) else nil })
	end
	return list
end

local function cleanupShow()
	if not show then return end
	for _, division in ipairs(show.divisions) do
		for _, c in ipairs(division.contestants) do
			if c.player and c.player.Parent then
				ShowOffService.ReleasePose(c.player)
				c.player:SetAttribute("PosingComp", nil)
			elseif c.model then
				c.model:Destroy()
			end
		end
	end
	show = nil
	broadcast("Ended", { nextAt = nextShowAt })
	ShowOffService.SetStageJudging(true)
end

local function runShow(npcsOnly: boolean?)
	-- who's in: alive players (Growth Spurt 1+) standing on the stage, not lifting or skating, closest to the middle first
	local entrants = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root and onStage(root.Position) and spurtsOf(player) >= PosingComp.UnlockSpurts and not onMachine(player)
			and player:GetAttribute("Skating") ~= true then
			table.insert(entrants, { player = player, d = (root.Position - Town.Stage.Center).Magnitude })
		end
	end
	table.sort(entrants, function(a, b) return a.d < b.d end)
	if npcsOnly then entrants = {} end
	-- divisions by height, smallest first
	local byDivision = {}
	for _, entry in ipairs(entrants) do
		local data = PlayerData.Get(entry.player)
		if data then
			local height = GrowthSpurts.PlayerHeight(data)
			local alter = type(data.alter) == "table" and data.alter.highest or 0
			local def = PosingComp.DivisionFor(height, Alters.TierOf(alter))
			byDivision[def.id] = byDivision[def.id] or {}
			if #byDivision[def.id] < PosingComp.MaxPerDivision then
				local size, balance = bodyValues(data)
				table.insert(byDivision[def.id], { player = entry.player, name = entry.player.DisplayName, size = size, balance = balance,
					height = height, out = false, alterTier = alter })
			end
		end
	end
	if npcsOnly then byDivision.Middle = {} end
	show = { divisions = {} }
	for _, def in ipairs(PosingComp.Divisions) do
		local players = byDivision[def.id]
		if players then
			local contestants = table.clone(players)
			for _, npc in ipairs(npcsFor(def, if npcsOnly then 0 else #players)) do table.insert(contestants, npc) end
			if npcsOnly and #contestants == 0 then
				for _, npc in ipairs(npcsFor(def, 1)) do table.insert(contestants, npc) end
			end
			for i, c in ipairs(contestants) do c.order = i end
			-- the show's label: the highest show any player in it has unlocked
			local level = nil
			for _, c in ipairs(players) do
				local s = PosingComp.ShowFor(spurtsOf(c.player))
				if s and (not level or s.fromSpurt > level.fromSpurt) then level = s end
			end
			table.insert(show.divisions, { def = def, contestants = contestants, show = level or PosingComp.Shows[1], npcsOnly = npcsOnly })
		end
	end
	if #show.divisions == 0 then
		show = nil
		broadcast("NoShow", { nextAt = nextShowAt })
		setBoard("Nobody stepped up. Next show in " .. clock(nextShowAt - now()), nil)
		return
	end
	ShowOffService.SetStageJudging(false) -- (the stage's everyday judges stay quiet during a show)
	for index, division in ipairs(show.divisions) do
		division.index, division.count = index, #show.divisions
		for _, c in ipairs(division.contestants) do
			if c.player then
				local data = PlayerData.Get(c.player)
				if data then PlayerData.SetStat(c.player, "posingEntries", (data.stats.posingEntries or 0) + 1) end
				GameEvents.Fire("PosingEntered", c.player, 1)
				logEvent(c.player, "PosingCompeted", 1)
			end
		end
	end
	broadcast("Start", { divisions = (function()
		local names = {}
		for _, division in ipairs(show.divisions) do table.insert(names, division.def.name) end
		return names
	end)() })
	local lastWinner = nil
	for index, division in ipairs(show.divisions) do
		local winner = runDivision(division)
		if winner then lastWinner = winner end
		if index < #show.divisions then task.wait(PosingComp.Between) end
	end
	-- the winner of the biggest division (a player) becomes the statue until the next show; an NPC win gives it back
	ShowOffService.SetChampion(lastWinner and lastWinner.player and lastWinner.player.Parent and lastWinner.player or nil)
	cleanupShow()
end

------------------------------------------------------------------------
-- JOIN (the last JoinWindow seconds): a far player goes straight onto the stage; a near one walks (the client draws a path)
------------------------------------------------------------------------
local function onJoin(player: Player)
	if show or spurtsOf(player) < PosingComp.UnlockSpurts then return end
	local left = nextShowAt - now()
	if left > PosingComp.JoinWindow + 1 or left < 0 then return end
	logEvent(player, "PosingJoinTapped", 1)
	local root = rootOf(player)
	if not root or onMachine(player) then return end
	local far = (root.Position - Town.Stage.Center).Magnitude > PosingComp.JoinTeleport
	if far then
		local spot = Town.Stage.Center + Vector3.new(rng:NextNumber(-3, 3), stageTop() - Town.Stage.Center.Y, rng:NextNumber(-2, 2))
		standAt(player.Character, spot)
	end
	remote:FireClient(player, "Joined", { teleported = far })
end

function PosingCompService.IsRunning(): boolean
	return show ~= nil
end

function PosingCompService.Start()
	local existing = Remotes:FindFirstChild("PosingComp")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "PosingComp"
		created.Parent = Remotes
		remote = created
	end
	pieces = findPieces()
	if not pieces then
		warn("[PosingCompService] Workspace.Town.PosingStage.Feature_PosingComp is missing: build it with tools/builders/PosingComp.luau")
		return
	end
	Guard.Remote(remote, "PosingComp", 6, 8, function(player, action)
		if action == "Join" then
			onJoin(player)
		elseif action == "Seen" then
			if not seen[player] then
				seen[player] = true
				logEvent(player, "PosingTimerSeen", 1)
			end
		elseif action == "State" then
			-- a client that joined mid-way asks when the next show is
			remote:FireClient(player, "Schedule", { nextAt = nextShowAt, running = show ~= nil })
		end
	end)
	Players.PlayerRemoving:Connect(function(player) seen[player] = nil end)
	nextShowAt = now() + PosingComp.FirstDelay
	broadcast("Schedule", { nextAt = nextShowAt })
	local testing = RunService:IsStudio()
	task.spawn(function()
		while true do
			if testing and Workspace:GetAttribute("TestPosingComp") == true and not show then
				Workspace:SetAttribute("TestPosingComp", nil)
				nextShowAt = now() + (tonumber(Workspace:GetAttribute("TestPosingCountdown")) or 10)
				broadcast("Schedule", { nextAt = nextShowAt })
			end
			if not show and now() >= nextShowAt then
				nextShowAt = now() + PosingComp.Interval
				local npcsOnly = testing and Workspace:GetAttribute("TestPosingWatch") == true
				local ok, err = pcall(runShow, npcsOnly)
				if not ok then
					warn("[PosingCompService] show failed:", err)
					broadcast("Cancelled", {})
					cleanupShow()
				end
				broadcast("Schedule", { nextAt = nextShowAt })
			elseif not show then
				local rows = nil
				if lastResults then
					rows = {}
					for place, entry in ipairs(lastResults) do
						if place <= 6 then rows[place] = { place .. ". " .. entry.name, tostring(entry.total) } end
					end
				end
				setBoard("Next show in " .. clock(nextShowAt - now()), rows)
			end
			task.wait(1)
		end
	end)
end

return PosingCompService
