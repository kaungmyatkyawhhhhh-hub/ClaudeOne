-- PosingCompService: the posing competition on the beach stage (Config.PosingComp; owner's feature run, task 1).
-- Every Interval seconds a countdown starts for the whole server; whoever stands on the stage when it ends is in (up to
-- MaxPlayers; NPC bodybuilders fill up when there are fewer than MinPlayers, so a solo player can still compete). Three
-- poses: each one the ring closes over CueTime and the contestant taps (the server times every tap), then holds the pose
-- until the judges score it: size + balance + timing -> a card from 1 to 10 above their head. Players watching vote
-- during the last pose. Top 3 go on the podium; coins for everyone who finished, "Posing Champion" (a posingWins stat
-- title) for a winning player, who also becomes the statue until the next round. Leaving the stage, dying or leaving
-- the game during a round = out, no reward.
-- Studio: Workspace attribute TestPosingComp = true starts a countdown now (TestPosingCountdown = its seconds);
-- TestPosingWatch = true makes that round NPCs only, so a solo tester watches and votes.
-- Remote "PosingComp": server -> clients (kind, info); clients -> server "Tap" | "Vote", index.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local PosingComp = require(Config.PosingComp)
local ShowOff = require(Config.ShowOff)
local Muscles = require(Config.Muscles)
local Town = require(Config.Town)
local Body = require(Config.Body)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)
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
local pieces = nil   -- { marks = { BasePart }, podium = { BasePart }, board = { title, status, rows } }
local round: any = nil -- the running round (nil between rounds)
local countdownEndsAt = nil -- server time the current countdown ends (nil = no countdown)
local nextCountdownAt = 0   -- server time the next countdown starts
local lastResults = nil     -- { { name, total } } of the last round, for the scoreboard

local function now() return Workspace:GetServerTimeNow() end

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

-- Stand a character on a part's top centre, facing the crowd (-Z).
local function standOn(model: Model, part: BasePart)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local topY = part.Position.Y + part.Size.Y / 2
	local feet = Vector3.new(part.Position.X, topY, part.Position.Z)
	local height = (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2
	model:PivotTo(CFrame.lookAt(feet, feet - Vector3.zAxis) + Vector3.new(0, height, 0))
end

------------------------------------------------------------------------
-- Contestants
------------------------------------------------------------------------
-- A player's size and balance values (0..1) from their saved muscles.
local function bodyValues(data)
	local levels, goal = BodyService.LevelsOf(data)
	local looks = Muscles.LooksFromLevels(levels, goal)
	return PosingComp.SizeAndBalance(looks, Muscles.Groups)
end

local function buildNpc(spec, mark: BasePart)
	local skin = Color3.fromHex(spec.skin)
	local shorts = Body.ShortsColor(spec.shorts)
	local model = NpcService.Build({
		name = spec.name, skin = spec.skin, shirt = spec.skin, pants = shorts:ToHex(), animated = true, tag = "Poser",
	}, CFrame.lookAt(mark.Position, mark.Position - Vector3.zAxis))
	-- shirtless in gym shorts: bare lower legs, dark shoes (the muscles take their colors from the body parts)
	for _, name in ipairs({ "RightLowerLeg", "LeftLowerLeg" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then part.Color = skin end
	end
	for _, name in ipairs({ "RightFoot", "LeftFoot" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then part.Color = Color3.fromHex("#1E1E22") end
	end
	model:SetAttribute("MuscleG", BodyService.EncodeShare(spec.share))
	model:SetAttribute("SkinColor", skin)
	model:SetAttribute("Top", "Shirtless")
	model:SetAttribute("Shorts", spec.shorts)
	model:SetAttribute("PosingNpc", true)
	standOn(model, mark)
	return model
end

local function contestantModel(c)
	if c.player then return c.player.Character end
	return c.model
end

local function contestantList()
	local list = {}
	for i, c in ipairs(round.contestants) do
		list[i] = { name = c.name, userId = c.player and c.player.UserId or 0, npc = c.player == nil, out = c.out, total = c.total }
	end
	return list
end

local function broadcast(kind, info)
	remote:FireAllClients(kind, info)
end

------------------------------------------------------------------------
-- The judges' card above a contestant's head (a world BillboardGui, sized in studs)
------------------------------------------------------------------------
local function showCard(model: Model?, card: number, label: string?)
	local head = model and model:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("PoseCard")
	if old then old:Destroy() end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PoseCard"
	gui.Size = UDim2.new(2.6, 0, 1.7, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0) -- (above the name and the title)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = head
	local panel = Theme.New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.25, Parent = gui,
	}, { Theme.New("UICorner", { CornerRadius = UDim.new(0.12, 0) }), Theme.New("UIStroke", { Color = Theme.Colors.Border, Transparency = 0.6, Thickness = 2 }) })
	Theme.New("TextLabel", {
		Text = string.format(card % 1 == 0 and "%d" or "%.1f", card), FontFace = Theme.Fonts.SemiBold, TextScaled = true, -- (world-space UI)
		TextColor3 = card >= 9 and Theme.Colors.Gold or Theme.Colors.Text, BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.9, 0.62), Position = UDim2.fromScale(0.05, 0.06), Parent = panel,
	})
	Theme.New("TextLabel", {
		Text = string.upper(label or "Judges"), FontFace = Theme.Fonts.Regular, TextScaled = true, TextColor3 = Theme.Colors.Muted,
		BackgroundTransparency = 1, Size = UDim2.fromScale(0.9, 0.24), Position = UDim2.fromScale(0.05, 0.7), Parent = panel,
	})
	task.delay(PosingComp.ScoreShow, function() if gui.Parent then gui:Destroy() end end)
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

local function dropOut(c, reason)
	if c.out then return end
	c.out = true
	release(c)
	if c.player and c.player.Parent then c.player:SetAttribute("PosingComp", nil) end
	broadcast("Out", { name = c.name, reason = reason, contestants = contestantList() })
end

local function checkContestants()
	if not round then return end
	for _, c in ipairs(round.contestants) do
		if not c.out and c.player then
			local root = c.player.Parent and rootOf(c.player)
			if not c.player.Parent then
				dropOut(c, "left")
			elseif not root then
				dropOut(c, "reset")
			elseif not onStage(root.Position) then
				dropOut(c, "stage")
			end
		end
	end
end

------------------------------------------------------------------------
-- One pose
------------------------------------------------------------------------
local function scoreboardRows()
	local rows = {}
	for i, c in ipairs(round.contestants) do
		rows[i] = { c.name, c.out and "OUT" or string.format("%.1f", c.total) }
	end
	return rows
end

local function npcTap(c, pose)
	-- an NPC strikes the pose a little before or after the ring closes, by its skill
	local skill = c.spec.skill
	local quality = rng:NextNumber(skill[1], skill[2])
	local spread = (1 - quality) * PosingComp.Good * 2
	local offset = rng:NextNumber(-spread, spread)
	task.delay(math.max(0, pose.cueAt - now() + offset), function()
		if round and round.pose == pose and not c.out and c.model and c.model.Parent then
			c.model:SetAttribute("Pose", pose.emote.poseData)
		end
	end)
	c.tap = { offset = offset, value = PosingComp.TapValue(offset) }
end

local function runPose(index: number)
	local emote = ShowOff.EmoteById[PosingComp.Poses[index]]
	local pose = { index = index, emote = emote, cueAt = now() + PosingComp.CueTime }
	round.pose = pose
	local last = index == #PosingComp.Poses
	for _, c in ipairs(round.contestants) do
		c.tap = nil
		if not c.out and not c.player then npcTap(c, pose) end
	end
	broadcast("Pose", {
		index = index, count = #PosingComp.Poses, poseId = emote.id, name = emote.name, cueAt = pose.cueAt,
		cueTime = PosingComp.CueTime, holdUntil = pose.cueAt + PosingComp.HoldTime, vote = last, contestants = contestantList(),
	})
	if last then round.voting = true end
	-- players who never tapped strike the pose anyway once the late window closes (no timing bonus)
	task.wait(math.max(0, pose.cueAt + PosingComp.LateLimit - now()))
	for _, c in ipairs(round.contestants) do
		if not c.out and c.player and not c.tap then
			c.tap = { value = PosingComp.Timing.Missed, label = "Missed" }
			ShowOffService.SetPose(c.player, emote)
			remote:FireClient(c.player, "Tapped", { label = "Missed" })
		end
	end
	-- the judges score at the end of the hold
	task.wait(math.max(0, pose.cueAt + PosingComp.HoldTime - now()))
	checkContestants()
	local cards = {}
	for i, c in ipairs(round.contestants) do
		if not c.out then
			local model = contestantModel(c)
			local held = model ~= nil and model:GetAttribute("Pose") == emote.poseData
			local timing = (c.tap and c.tap.value or 0) * (held and 1 or PosingComp.HoldLost)
			local card = PosingComp.Card(PosingComp.PoseScore(c.size, c.balance, timing))
			c.cards[index] = card
			c.total += card
			cards[i] = card
			showCard(model, card, held and "Judges" or "Held too short")
		end
	end
	broadcast("Scores", { index = index, cards = cards, contestants = contestantList() })
	setBoard(string.format("Pose %d of %d: %s", index, #PosingComp.Poses, emote.name), scoreboardRows())
	task.wait(PosingComp.ScoreShow)
	for _, c in ipairs(round.contestants) do
		if not c.out then release(c) end
	end
	round.pose = nil
	if not last then task.wait(PosingComp.Gap) end
end

------------------------------------------------------------------------
-- Taps and votes from clients
------------------------------------------------------------------------
local function onTap(player: Player)
	local pose = round and round.pose
	if not pose then return end
	local c = nil
	for _, entry in ipairs(round.contestants) do
		if entry.player == player and not entry.out then c = entry end
	end
	if not c or c.tap then return end
	-- the server times the tap; the player's own network delay (capped) is forgiven
	local ping = math.clamp(player:GetNetworkPing(), 0, PosingComp.MaxPing)
	local offset = (now() - ping) - pose.cueAt
	if offset < -PosingComp.CueTime then return end -- (a tap from before this pose's ring even started)
	local value, label = PosingComp.TapValue(offset)
	c.tap = { offset = offset, value = value, label = label }
	ShowOffService.SetPose(player, pose.emote)
	remote:FireClient(player, "Tapped", { label = label })
end

local function onVote(player: Player, index: any)
	if not round or not round.voting or round.voted[player] or type(index) ~= "number" then return end
	local c = round.contestants[index]
	if not c or c.out or c.player == player then return end -- never for yourself
	for _, entry in ipairs(round.contestants) do
		if entry.player == player then return end -- contestants don't vote
	end
	local root = rootOf(player)
	if not root or (root.Position - Town.Stage.Center).Magnitude > PosingComp.VoteRange + 20 then return end
	round.voted[player] = true
	c.votes += 1
	remote:FireClient(player, "Voted", { name = c.name })
end

------------------------------------------------------------------------
-- A whole round
------------------------------------------------------------------------
local function cleanupRound()
	if not round then return end
	for _, c in ipairs(round.contestants) do
		if c.player then
			if c.player.Parent then
				ShowOffService.ReleasePose(c.player)
				c.player:SetAttribute("PosingComp", nil)
			end
		elseif c.model then
			c.model:Destroy()
		end
	end
	if round.watcher then round.watcher:Disconnect() end
	round = nil
	broadcast("Ended", {})
	ShowOffService.SetStageJudging(true)
end

local function results()
	local ranked = {}
	for _, c in ipairs(round.contestants) do
		if not c.out then
			c.total += PosingComp.VoteBonus(c.votes)
			table.insert(ranked, c)
		end
	end
	table.sort(ranked, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return a.order < b.order
	end)
	local list = {}
	for place, c in ipairs(ranked) do
		list[place] = { name = c.name, total = math.floor(c.total * 10 + 0.5) / 10, votes = c.votes, npc = c.player == nil }
		local model = contestantModel(c)
		if place <= 3 and model and pieces.podium[place] then standOn(model, pieces.podium[place]) end
		if c.player and c.player.Parent then
			local coins = PosingComp.Coins[place] or PosingComp.EnterCoins
			PlayerData.AddCoins(c.player, coins)
			if place == 1 then
				local data = PlayerData.Get(c.player)
				if data then PlayerData.SetStat(c.player, "posingWins", (data.stats.posingWins or 0) + 1) end
				TitleService.Check(c.player) -- "Posing Champion"
				GameEvents.Fire("PosingWon", c.player, 1)
			end
			remote:FireClient(c.player, "Reward", { place = place, coins = coins })
		end
	end
	-- the winner (a player) becomes the statue until the next round; an NPC win gives it back to the strongest lifter
	local winner = ranked[1]
	ShowOffService.SetChampion(winner and winner.player and winner.player.Parent and winner.player or nil)
	lastResults = list
	broadcast("Results", { ranking = list })
	local rows = {}
	for place, entry in ipairs(list) do rows[place] = { place .. ". " .. entry.name, string.format("%.1f", entry.total) } end
	setBoard(winner and ("Winner: " .. winner.name) or "No winner", rows)
end

local function startRound(entrants: { Player }, npcsOnly: boolean?)
	round = { contestants = {}, voted = {}, pose = nil, voting = false }
	ShowOffService.SetStageJudging(false) -- (the stage's everyday judges stay quiet during a round)
	-- the marks in use: as many as there are contestants, centred on the stage
	local npcCount = 0
	if #entrants < PosingComp.MinPlayers then
		npcCount = math.max(0, math.min(PosingComp.NpcFillTo, #pieces.marks, #entrants + #PosingComp.Npcs) - #entrants)
	end
	local first = (#pieces.marks - (#entrants + npcCount)) // 2
	local function markFor(i) return pieces.marks[first + i] or pieces.marks[i] end
	-- players on the marks, in the order they were found (closest to the stage centre first)
	for i, player in ipairs(entrants) do
		local data = PlayerData.Get(player)
		local size, balance = 0, 0
		if data then size, balance = bodyValues(data) end
		table.insert(round.contestants, { player = player, name = player.DisplayName, size = size, balance = balance,
			cards = {}, total = 0, votes = 0, out = false, order = i })
		local character = player.Character
		if character and markFor(i) then standOn(character, markFor(i)) end
		player:SetAttribute("PosingComp", true) -- (PoseClient hides its everyday pose panel meanwhile)
		local stats = data and data.stats
		if stats then PlayerData.SetStat(player, "posingEntries", (stats.posingEntries or 0) + 1) end
		GameEvents.Fire("PosingEntered", player, 1)
	end
	-- NPC bodybuilders fill the stage when too few players joined
	if npcCount > 0 then
		local pool = table.clone(PosingComp.Npcs)
		for _ = 1, npcCount do
			if #pool == 0 then break end
			local spec = table.remove(pool, rng:NextInteger(1, #pool))
			local i = #round.contestants + 1
			local ok, model = pcall(buildNpc, spec, markFor(i))
			if ok and model then
				table.insert(round.contestants, { model = model, spec = spec, name = spec.name, size = math.clamp(spec.share / PosingComp.SizeFull, 0, 1),
					balance = 1, cards = {}, total = 0, votes = 0, out = false, order = i })
			else
				warn("[PosingCompService] could not build an NPC bodybuilder:", model)
			end
		end
	end
	-- watch for anyone dropping out (left the stage, died, left the game)
	local acc = 0
	round.watcher = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		checkContestants()
	end)
	broadcast("Start", { contestants = contestantList(), intro = PosingComp.Intro })
	setBoard("Contestants, take your marks", scoreboardRows())
	task.wait(PosingComp.Intro)
	for index = 1, #PosingComp.Poses do
		if not round then return end
		local anyIn = false
		for _, c in ipairs(round.contestants) do
			if not c.out and c.player then anyIn = true end
		end
		if not anyIn and not npcsOnly then break end -- every player dropped out: no round left to judge
		runPose(index)
	end
	if not round then return end
	round.voting = false
	results()
	task.wait(PosingComp.PodiumTime)
	cleanupRound()
end

local function runCountdown(seconds: number)
	countdownEndsAt = now() + seconds
	broadcast("Countdown", { endsAt = countdownEndsAt, stage = Town.Stage.Center + Vector3.new(0, stageTop(), 0) })
	while now() < countdownEndsAt do
		setBoard("Starts in " .. clock(countdownEndsAt - now()) .. ". Step on the stage!", nil)
		task.wait(1)
	end
	countdownEndsAt = nil
	-- who's in: alive players standing on the stage, not lifting, closest to the middle first
	local entrants = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root and onStage(root.Position) and not onMachine(player) and player:GetAttribute("Skating") ~= true then
			table.insert(entrants, { player = player, d = (root.Position - Town.Stage.Center).Magnitude })
		end
	end
	table.sort(entrants, function(a, b) return a.d < b.d end)
	local list = {}
	for i = 1, math.min(#entrants, PosingComp.MaxPlayers) do list[i] = entrants[i].player end
	local npcsOnly = RunService:IsStudio() and Workspace:GetAttribute("TestPosingWatch") == true
	if npcsOnly then list = {} end
	if #list == 0 and not npcsOnly then
		broadcast("NoShow", {})
		setBoard("Nobody stepped up. Next round in " .. clock(nextCountdownAt - now()), nil)
		return
	end
	local ok, err = pcall(startRound, list, npcsOnly)
	if not ok then
		warn("[PosingCompService] round failed:", err)
		broadcast("Cancelled", {})
		cleanupRound()
	end
end

function PosingCompService.IsRunning(): boolean
	return round ~= nil or countdownEndsAt ~= nil
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
	Guard.Remote(remote, "PosingComp", 6, 8, function(player, action, arg)
		if action == "Tap" then
			onTap(player)
		elseif action == "Vote" then
			onVote(player, arg)
		elseif action == "State" then
			-- a client that joined mid-way asks what is going on
			if countdownEndsAt then
				remote:FireClient(player, "Countdown", { endsAt = countdownEndsAt, stage = Town.Stage.Center + Vector3.new(0, stageTop(), 0) })
			end
		end
	end)
	nextCountdownAt = now() + PosingComp.FirstDelay
	setBoard("Next round in " .. clock(PosingComp.FirstDelay), nil)
	local testing = RunService:IsStudio()
	task.spawn(function()
		while true do
			local test = testing and Workspace:GetAttribute("TestPosingComp") == true
			if test or now() >= nextCountdownAt then
				if test then Workspace:SetAttribute("TestPosingComp", nil) end
				local seconds = test and (tonumber(Workspace:GetAttribute("TestPosingCountdown")) or 10) or PosingComp.Countdown
				nextCountdownAt = now() + PosingComp.Interval
				local ok, err = pcall(runCountdown, seconds)
				if not ok then warn("[PosingCompService] countdown failed:", err) end
			elseif not round then
				local rows = nil
				if lastResults then
					rows = {}
					for place, entry in ipairs(lastResults) do rows[place] = { place .. ". " .. entry.name, string.format("%.1f", entry.total) } end
				end
				setBoard("Next round in " .. clock(nextCountdownAt - now()), rows)
			end
			task.wait(1)
		end
	end)
end

return PosingCompService
