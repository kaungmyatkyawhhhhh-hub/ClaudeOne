--[[
	CITY LEGENDS - server entry point
	  * builds the city
	  * spawns player cars (client-owned physics)
	  * pays passive driving income + validates "cut up" rewards
	  * XP / levels (earned with the same events as cash) + the daily gift
	  * garage purchases + saving
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local CityBuilder = require(script.Parent:WaitForChild("CityBuilder"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

Players.CharacterAutoLoads = false

---------------------------------------------------------------------
-- Remotes (created before the slow city build so clients can connect)
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local GetData: RemoteFunction = remote("RemoteFunction", "GetData")
local BuyCar: RemoteFunction = remote("RemoteFunction", "BuyCar")
local SpawnCar: RemoteEvent = remote("RemoteEvent", "SpawnCar")
local DespawnCar: RemoteEvent = remote("RemoteEvent", "DespawnCar")
local CutUp: RemoteEvent = remote("RemoteEvent", "CutUp")
local Crash: RemoteEvent = remote("RemoteEvent", "Crash")
local Earned: RemoteEvent = remote("RemoteEvent", "Earned")
local Progress: RemoteEvent = remote("RemoteEvent", "Progress") -- server -> client XP / level updates
local ClaimDaily: RemoteFunction = remote("RemoteFunction", "ClaimDaily")
remotes.Parent = ReplicatedStorage

local playerCars = Instance.new("Folder")
playerCars.Name = "PlayerCars"
playerCars.Parent = workspace

local cityStart = os.clock()
CityBuilder.build()
print(string.format("[CityLegends] city built in %.2fs", os.clock() - cityStart))

---------------------------------------------------------------------
-- Per-player runtime state
---------------------------------------------------------------------
type Session = {
	car: Model?,
	combo: number,
	lastCut: number,
	cutTimes: { number },
	incomeCarry: number,
	xpCarry: number,
}
local sessions: { [Player]: Session } = {}

local function getSession(player: Player): Session
	local s = sessions[player]
	if not s then
		s = { car = nil, combo = 0, lastCut = 0, cutTimes = {}, incomeCarry = 0, xpCarry = 0 }
		sessions[player] = s
	end
	return s
end

local function horizontalSpeed(part: BasePart): number
	local v = part.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

---------------------------------------------------------------------
-- XP / levels
---------------------------------------------------------------------
local function grantXp(player: Player, amount: number, source: string)
	local result = PlayerData.addXp(player, amount)
	if not result then
		return
	end
	Progress:FireClient(player, {
		level = result.level,
		xp = result.xp,
		need = result.need,
		gained = math.floor(amount),
		source = source,
		levelUp = result.levels > 0,
		reward = result.reward,
	})
	if result.levels > 0 then
		task.spawn(PlayerData.save, player)
	end
end

---------------------------------------------------------------------
-- Car spawning
---------------------------------------------------------------------
local graph = CityLayout.buildGraph()
local spawnRng = Random.new()

local function findSpawnCFrame(): CFrame
	local candidates = {}
	for _, seg in graph.lanes do
		local mid = (seg.p0 + seg.p2) / 2
		if mid.Magnitude < 520 then
			table.insert(candidates, seg)
		end
	end
	for _ = 1, 30 do
		local seg = candidates[spawnRng:NextInteger(1, #candidates)]
		local s = spawnRng:NextNumber(30, seg.length * 0.6)
		local pos, dir = CityLayout.sample(seg, s)
		local free = true
		for _, car in playerCars:GetChildren() do
			if car:IsA("Model") and (car:GetPivot().Position - pos).Magnitude < 45 then
				free = false
				break
			end
		end
		if free then
			return CFrame.lookAt(pos, pos + dir)
		end
	end
	local seg = candidates[1]
	local pos, dir = CityLayout.sample(seg, 40)
	return CFrame.lookAt(pos, pos + dir)
end

local function despawn(player: Player)
	local s = getSession(player)
	if s.car then
		s.car:Destroy()
		s.car = nil
	end
	s.combo = 0
end

local function spawnFor(player: Player, carId: string)
	local profile = PlayerData.get(player)
	if not profile or not profile.Owned[carId] then
		return
	end
	profile.Selected = carId
	despawn(player)

	local spec = Cars.get(carId)
	local model = CarBuilder.build(spec, { interior = true, lights = true, anchored = false })
	model:SetAttribute("Plate", string.upper(player.Name):gsub("[^%w]", ""):sub(1, 7))
	model.Name = player.Name
	model:SetAttribute("Owner", player.UserId)

	local root = model.PrimaryPart :: BasePart
	local att = Instance.new("Attachment")
	att.Name = "DriveAttachment"
	att.Parent = root

	-- Velocity is controlled in the ground plane only, so gravity still works
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.zero
	lv.MaxForce = 1e6
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Name = "Steer"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e9
	ao.MaxAngularVelocity = 40
	ao.Responsiveness = 60
	ao.Parent = root

	local spawnCF = findSpawnCFrame()
	local h = model:GetAttribute("Height") :: number
	model:PivotTo(spawnCF + Vector3.new(0, h / 2 + 0.3, 0))
	ao.CFrame = spawnCF.Rotation
	model.Parent = playerCars

	lv.MaxForce = root.AssemblyMass * 400
	root:SetNetworkOwner(player)
	player.ReplicationFocus = root
	getSession(player).car = model
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
GetData.OnServerInvoke = function(player: Player)
	local timeout = os.clock() + 10
	while not PlayerData.get(player) and os.clock() < timeout do
		task.wait(0.1)
	end
	return PlayerData.snapshot(player)
end

ClaimDaily.OnServerInvoke = function(player: Player)
	local ok, amount = PlayerData.claimDaily(player)
	local readyIn = PlayerData.dailyReadyIn(player)
	if not ok then
		return { ok = false, message = "Your next gift isn't ready yet", amount = 0, readyIn = readyIn }
	end
	task.spawn(PlayerData.save, player)
	return { ok = true, message = "Daily gift claimed", amount = amount, readyIn = readyIn }
end

BuyCar.OnServerInvoke = function(player: Player, carId: any)
	if type(carId) ~= "string" or not Cars.ById[carId] then
		return { ok = false, message = "Unknown car" }
	end
	local profile = PlayerData.get(player)
	if not profile then
		return { ok = false, message = "Profile not loaded" }
	end
	if profile.Owned[carId] then
		return { ok = true, message = "Already owned", data = PlayerData.snapshot(player) }
	end
	local spec = Cars.ById[carId]
	if profile.Cash < spec.Price then
		return { ok = false, message = "Not enough cash" }
	end
	PlayerData.addCash(player, -spec.Price)
	profile.Owned[carId] = true
	task.spawn(PlayerData.save, player)
	return { ok = true, message = "Purchased " .. spec.Name, data = PlayerData.snapshot(player) }
end

SpawnCar.OnServerEvent:Connect(function(player: Player, carId: any)
	if type(carId) ~= "string" then
		return
	end
	spawnFor(player, carId)
end)

DespawnCar.OnServerEvent:Connect(function(player: Player)
	despawn(player)
end)

Crash.OnServerEvent:Connect(function(player: Player)
	local s = getSession(player)
	if s.combo > 0 then
		s.combo = 0
		Earned:FireClient(player, { amount = 0, combo = 0, kind = "crash" })
	end
end)

local E = Config.Economy
CutUp.OnServerEvent:Connect(function(player: Player, info: any)
	if type(info) ~= "table" then
		return
	end
	local s = getSession(player)
	local car = s.car
	if not car or not car.PrimaryPart then
		return
	end
	local now = os.clock()
	if now - s.lastCut < E.CutCooldown then
		return
	end
	-- no more than 30 cuts in 10 seconds
	local recent = {}
	for _, t in s.cutTimes do
		if now - t < 10 then
			table.insert(recent, t)
		end
	end
	if #recent >= 30 then
		s.cutTimes = recent
		return
	end
	table.insert(recent, now)
	s.cutTimes = recent

	local spec = Cars.get(car:GetAttribute("CarId") :: string)
	local mph = math.min(Config.spsToMph(horizontalSpeed(car.PrimaryPart)), spec.TopSpeed * 1.05)
	-- a little slack for replication lag
	if mph < E.CutMinMph * 0.8 then
		return
	end

	local closeness = math.clamp(tonumber(info.closeness) or 0, 0, 1)
	local oncoming = info.oncoming == true
	local thread = info.thread == true

	if now - s.lastCut <= E.ComboWindow then
		s.combo = math.min(s.combo + 1, E.ComboMax)
	else
		s.combo = 1
	end
	s.lastCut = now

	local speedFactor = math.clamp(mph / 100, 0.6, 2.6)
	local comboFactor = 1 + E.ComboStep * (s.combo - 1)
	local amount = E.CutBase * (0.6 + 0.8 * closeness) * speedFactor * comboFactor
	if oncoming then
		amount *= E.OncomingBonus
	end
	if thread then
		amount *= E.ThreadBonus
	end
	amount = math.floor(amount)
	PlayerData.addCash(player, amount)

	local label = if thread then "THREAD THE NEEDLE" elseif oncoming then "ONCOMING CUT" elseif closeness > 0.75 then "INSANE CUT" elseif closeness > 0.4 then "CLOSE CUT" else "CUT UP"
	Earned:FireClient(player, { amount = amount, combo = s.combo, kind = "cut", label = label })

	local P = Config.Progression
	grantXp(player, math.clamp(math.floor(amount * P.CutXpPerCash + 0.5), 1, P.CutXpMax), "cut")
end)

---------------------------------------------------------------------
-- Passive driving income
---------------------------------------------------------------------
local incomeTimer = 0
RunService.Heartbeat:Connect(function(dt)
	incomeTimer += dt
	if incomeTimer < 0.5 then
		return
	end
	local step = incomeTimer
	incomeTimer = 0
	for player, s in sessions do
		local car = s.car
		if car and car.PrimaryPart then
			local spec = Cars.get(car:GetAttribute("CarId") :: string)
			local mph = math.min(Config.spsToMph(horizontalSpeed(car.PrimaryPart)), spec.TopSpeed * 1.05)
			if mph >= E.DriveMinMph then
				s.incomeCarry += mph * E.DrivePerSecond * step
				local whole = math.floor(s.incomeCarry)
				if whole >= 1 then
					s.incomeCarry -= whole
					PlayerData.addCash(player, whole)
				end
				-- driving XP mirrors the driving income
				s.xpCarry += mph * Config.Progression.DriveXpPerSecond * step
				local xp = math.floor(s.xpCarry)
				if xp >= 1 then
					s.xpCarry -= xp
					grantXp(player, xp, "drive")
				end
			end
			-- drop combos that expired
			if s.combo > 0 and os.clock() - s.lastCut > E.ComboWindow then
				s.combo = 0
			end
		end
	end
end)

---------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------
--[[
	Console money hook (server side only: Studio command bar, or the F9
	Developer Console's server command line in a live game, which only the
	game's owner / editors can use). Players can't trigger it: attributes they
	set on themselves don't replicate to the server.
	  game.Players.NAME:SetAttribute("SetCash", 1000000)  -- set to an amount
	  game.Players.NAME:SetAttribute("AddCash", 50000)    -- add (negative takes)
]]
local function watchConsoleCash(player: Player)
	for _, attr in { "SetCash", "AddCash" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			local v = player:GetAttribute(attr)
			if type(v) ~= "number" then
				return
			end
			player:SetAttribute(attr, nil)
			local profile = PlayerData.get(player)
			if not profile then
				return
			end
			PlayerData.addCash(player, if attr == "SetCash" then v - profile.Cash else v)
			task.spawn(PlayerData.save, player)
			print(("[CityLegends] %s now has $%d"):format(player.Name, profile.Cash))
		end)
	end
end

local function onPlayerAdded(player: Player)
	getSession(player)
	watchConsoleCash(player)
	PlayerData.load(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	despawn(player)
	sessions[player] = nil
	PlayerData.release(player)
end)

task.spawn(function()
	while true do
		task.wait(120)
		PlayerData.saveAll()
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)
