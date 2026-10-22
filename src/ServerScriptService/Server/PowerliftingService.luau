-- PowerliftingService (prompt 58, 23 Oct): the Powerlifting Gym (Workspace.PowerliftingGym, tools/builders/PowerliftingGym;
-- opens at Growth Spurt 5, Machines.GymUnlock; Config/Powerlifting has the numbers).
--   * Door: PowerliftingClient keeps the loading door's Blocker solid for players it's locked for; here the server
--     double-checks like ProGymService: a locked player inside is put back in the alley ("PowerliftingLocked"), the first
--     time an unlocked player walks in once per session says hello ("PowerliftingEntered").
--   * MachineService calls OnLift on every player rep and ExpBonus for its EXP:
--       - a new personal record on a machine here rings the PR BELL for everyone inside ("PLBell": bell, gold flash, the
--         toast "NAME hit a 1,250 LB DEADLIFT PR!" only inside);
--       - a squat / bench / deadlift heavier than the server's record (machine.lift) takes the record: the board updates;
--         beating someone's record: "PLRecord" (the board flashes, judge lights white, GOOD LIFT, the crowd cheers);
--       - the all-time top 3 per lift (one entry per player, their best) are saved in a DataStore (Config Store), merged
--         with other servers' when saved (every SaveEvery s when something changed, and when the server closes);
--       - MEET: every MeetEvery s a MeetSeconds window ("PLMeet" soon / start / end; the gym's MeetEndsAt attribute):
--         reps on the competition platform's machines (attribute Platform) give MeetBonus more EXP and the judge lights
--         answer each one ("PLJudge").
--   * The RECORD BOARD's SurfaceGui (Props.RecordBoard.Board) is filled here, so every player sees the same board.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local Machines = require(Config.Machines)
local Powerlifting = require(Config.Powerlifting)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local PowerliftingService = {}

PowerliftingService.Bounds = { MinX = -174, MaxX = -66, MinZ = -96, MaxZ = -4 } -- (replaced at Start by the floor's footprint)
PowerliftingService.Debounce = 1.5
PowerliftingService.MessageCooldown = 3

local gym: Model? = nil
local outside = CFrame.new(-143, 0.15, 6)
local welcomed, lastPutBack, lastMessage = {}, {}, {}
local serverRecords = {} -- [lift] = { userId, name, weight }
local allTime = {}       -- [lift] = { { userId, name, weight, time }, ... } best first
local dirty = false
local lastBell = 0
local meetEndsAt = 0

function PowerliftingService.IsInside(position: Vector3): boolean
	local b = PowerliftingService.Bounds
	return position.X > b.MinX and position.X < b.MaxX and position.Z > b.MinZ and position.Z < b.MaxZ and position.Y < 40 and position.Y > -10
end

local function playersInside(): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and PowerliftingService.IsInside(root.Position) then table.insert(list, player) end
	end
	return list
end
local function tellInside(kind: string, info)
	for _, player in ipairs(playersInside()) do Remotes.PlayerEvent:FireClient(player, kind, info) end
end

------------------------------------------------------------------------
-- the record board
------------------------------------------------------------------------
local function weightText(weight: number): string
	return Powerlifting.FormatWeight(weight) .. " LB"
end

local function refreshBoard()
	local board = gym and gym:FindFirstChild("Props") and gym.Props:FindFirstChild("RecordBoard")
	local surface = board and board:FindFirstChild("Board")
	if not surface then return end
	for _, lift in ipairs(Powerlifting.Lifts) do
		local column = surface:FindFirstChild(lift)
		if column then
			local record = serverRecords[lift]
			column.Server.Text = if record then record.name .. "  " .. weightText(record.weight) else "-"
			local list = allTime[lift] or {}
			for place = 1, Powerlifting.TopCount do
				local label = column:FindFirstChild("Top" .. place)
				local entry = list[place]
				if label then label.Text = place .. ".  " .. (if entry then entry.name .. "  " .. weightText(entry.weight) else "-") end
			end
		end
	end
end

-- one entry per player (their best), best first, TopCount long
local function mergeTop(list, entry)
	local out = {}
	local seen = {}
	local all = table.clone(list or {})
	if entry then table.insert(all, entry) end
	table.sort(all, function(a, b)
		if a.weight ~= b.weight then return a.weight > b.weight end
		return (a.time or 0) < (b.time or 0)
	end)
	for _, e in ipairs(all) do
		if type(e) == "table" and type(e.weight) == "number" and not seen[e.userId] then
			seen[e.userId] = true
			table.insert(out, { userId = e.userId, name = tostring(e.name), weight = e.weight, time = e.time })
			if #out >= Powerlifting.TopCount then break end
		end
	end
	return out
end

local store = nil
local function load()
	local ok, result = pcall(function()
		store = DataStoreService:GetDataStore(Powerlifting.Store)
		return store:GetAsync("AllTime")
	end)
	if ok and type(result) == "table" then
		for _, lift in ipairs(Powerlifting.Lifts) do allTime[lift] = mergeTop(result[lift], nil) end
	elseif not ok then
		warn("[PowerliftingService] couldn't load the all-time records: " .. tostring(result))
	end
	refreshBoard()
end

local function save()
	if not dirty or not store then return end
	dirty = false
	local ok, err = pcall(function()
		store:UpdateAsync("AllTime", function(old)
			local merged = {}
			for _, lift in ipairs(Powerlifting.Lifts) do
				local list = table.clone(allTime[lift] or {})
				for _, e in ipairs(type(old) == "table" and type(old[lift]) == "table" and old[lift] or {}) do table.insert(list, e) end
				merged[lift] = mergeTop(list, nil)
			end
			allTime = merged
			return merged
		end)
	end)
	if not ok then
		dirty = true
		warn("[PowerliftingService] couldn't save the all-time records: " .. tostring(err))
	end
	refreshBoard()
end

------------------------------------------------------------------------
-- lifts (MachineService)
------------------------------------------------------------------------
local function meetOn(): boolean
	return Workspace:GetServerTimeNow() < meetEndsAt
end

function PowerliftingService.ExpBonus(model: Instance?): number
	if gym and model and model:IsDescendantOf(gym) and model:GetAttribute("Platform") == true and meetOn() then return Powerlifting.MeetBonus end
	return 1
end

function PowerliftingService.OnLift(player: Player, machine, model: Instance, tier, isPR: boolean)
	if not gym or not model:IsDescendantOf(gym) or type(tier) ~= "table" then return end
	local weight = tonumber(tier.weight) or 0
	local liftName = string.upper(machine.lift and Powerlifting.LiftNames[machine.lift] or machine.name)
	local name = player.DisplayName
	-- the PR bell
	if isPR and os.clock() - lastBell >= Powerlifting.BellCooldown then
		lastBell = os.clock()
		tellInside("PLBell", { name = name, userId = player.UserId, weight = weight, lift = liftName })
	elseif isPR then
		-- (a second PR right away: no second bell, still the toast for the lifter)
		Remotes.PlayerEvent:FireClient(player, "PLBell", { name = name, userId = player.UserId, weight = weight, lift = liftName, quiet = true })
	end
	-- the server record and the all-time board (squat, bench, deadlift only)
	local lift = machine.lift
	if lift and Powerlifting.LiftNames[lift] and weight > 0 then
		local record = serverRecords[lift]
		if not record or weight > record.weight then
			local beaten = record ~= nil and record.userId ~= player.UserId
			serverRecords[lift] = { userId = player.UserId, name = name, weight = weight }
			local before = allTime[lift] and allTime[lift][Powerlifting.TopCount]
			local list = mergeTop(allTime[lift], { userId = player.UserId, name = name, weight = weight, time = os.time() })
			allTime[lift] = list
			dirty = dirty or (before == nil or weight > before.weight)
			refreshBoard()
			if beaten then
				tellInside("PLRecord", { lift = lift, liftName = Powerlifting.LiftNames[lift], name = name, weight = weight, from = record.name })
			end
		end
	end
	-- the judges answer every rep on the platform during a meet
	if model:GetAttribute("Platform") == true and meetOn() then
		tellInside("PLJudge", { good = true, pr = isPR })
	end
end

------------------------------------------------------------------------
-- the door
------------------------------------------------------------------------
local function check(player: Player, unlock: number)
	local data = PlayerData.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not root or not humanoid or root.Anchored then return end
	if not PowerliftingService.IsInside(root.Position) then return end
	if Machines.GymLevel(data) < unlock then
		local now = os.clock()
		if now - (lastPutBack[player] or 0) < PowerliftingService.Debounce then return end
		lastPutBack[player] = now
		local target = outside + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
		task.spawn(function()
			pcall(function() player:RequestStreamAroundAsync(target.Position, 1) end)
			if character.Parent then character:PivotTo(target) end
		end)
		if now - (lastMessage[player] or -math.huge) >= PowerliftingService.MessageCooldown then
			lastMessage[player] = now
			Remotes.PlayerEvent:FireClient(player, "PowerliftingLocked", { spurts = unlock })
		end
	elseif not welcomed[player] then
		welcomed[player] = true
		Remotes.PlayerEvent:FireClient(player, "PowerliftingEntered", { meetEndsAt = meetEndsAt })
	end
end

function PowerliftingService.Start()
	gym = Workspace:WaitForChild("PowerliftingGym", 10)
	if not gym then
		warn("[PowerliftingService] Workspace.PowerliftingGym is missing: build it in Studio with tools/builders/PowerliftingGym")
		return
	end
	local floor = gym:FindFirstChild("Shell") and gym.Shell:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		local b = PowerliftingService.Bounds
		b.MinX, b.MaxX = floor.Position.X - floor.Size.X / 2, floor.Position.X + floor.Size.X / 2
		b.MinZ, b.MaxZ = floor.Position.Z - floor.Size.Z / 2, floor.Position.Z + floor.Size.Z / 2
	end
	local blocker = gym:FindFirstChild("LoadingDoor") and gym.LoadingDoor:FindFirstChild("Blocker")
	if blocker then
		outside = CFrame.lookAt(Vector3.new(blocker.Position.X, 0.15, blocker.Position.Z + 9), Vector3.new(blocker.Position.X, 0.15, blocker.Position.Z + 20))
	end
	assert(not PowerliftingService.IsInside(outside.Position), "[PowerliftingService] the outside spot is inside the gym")
	local unlock = Machines.GymUnlock.Powerlifting
	Players.PlayerRemoving:Connect(function(player)
		welcomed[player], lastPutBack[player], lastMessage[player] = nil, nil, nil
	end)
	task.spawn(load)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do check(player, unlock) end
		end
	end)
	-- saving
	task.spawn(function()
		while true do
			task.wait(Powerlifting.SaveEvery)
			save()
		end
	end)
	game:BindToClose(function()
		if not RunService:IsStudio() or dirty then save() end
	end)
	-- the MEET clock (Studio: the Workspace attribute TestMeet = true starts one now)
	task.spawn(function()
		local function runMeet()
			tellInside("PLMeet", { phase = "soon", seconds = Powerlifting.MeetWarn })
			task.wait(Powerlifting.MeetWarn)
			meetEndsAt = Workspace:GetServerTimeNow() + Powerlifting.MeetSeconds
			gym:SetAttribute("MeetEndsAt", meetEndsAt)
			tellInside("PLMeet", { phase = "start", endsAt = meetEndsAt })
			task.wait(Powerlifting.MeetSeconds)
			tellInside("PLMeet", { phase = "end" })
		end
		if RunService:IsStudio() then
			Workspace:GetAttributeChangedSignal("TestMeet"):Connect(function()
				if Workspace:GetAttribute("TestMeet") == true then task.spawn(runMeet) end
			end)
		end
		while true do
			task.wait(Powerlifting.MeetEvery - Powerlifting.MeetWarn)
			runMeet()
		end
	end)
end

return PowerliftingService
