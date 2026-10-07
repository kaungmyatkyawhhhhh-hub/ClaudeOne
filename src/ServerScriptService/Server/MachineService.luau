-- One reusable machine system. A machine in the world is a Model tagged "Machine"
-- with a MachineId attribute; everything else comes from Config.Machines.
-- Clients only send intent (Lift / Leave / SelectTier / UnlockTier); all checks happen here.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Machines = require(Config.Machines)
local Poses = require(Config.Poses)
local Gains = require(Config.Gains)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local TitleService = require(script.Parent.TitleService)
local QuestService = require(script.Parent.QuestService)
local BoostService = require(script.Parent.BoostService)
local SocialService = require(script.Parent.SocialService)
local LegendService = require(script.Parent.LegendService)
local SeasonService = require(script.Parent.SeasonService)
local Theme = require(ReplicatedStorage.Shared.UI.Theme) -- bumper plate colors

-- Bars sit loaded when nobody is using them (a mix, so the gym shows every plate color).
local DISPLAY_TIERS = { FlatBench = 7, InclineBench = 5, OverheadPress = 4, SquatRack = 9, Deadlift = 8, BarbellRow = 6, PullUpBar = 3, CrunchBench = 3 }
local function displayTier(machine)
	return machine.tiers[math.min(DISPLAY_TIERS[machine.id] or 5, #machine.tiers)]
end

local Remotes = ReplicatedStorage.Remotes


local MachineService = {}

local sessions = {}  -- [player] = { model, machine, lastRep, connections, pump, nextBig }
local occupants = {} -- [model] = player

-- The machine's own "Use" prompt (SocialService adds a separate "SpotPrompt" next to it).
local function getPrompt(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name ~= "SpotPrompt" then return descendant end
	end
	return nil
end

-- Plates are clones of the templates in ReplicatedStorage.GymAssets (GymAssets builder): real plates with a rim, hub
-- and the weight on the face. Barbells also get sleeves + collars (they ride with the plates). Only the outermost
-- plate on each side shows its number (that's the face people see).
local Assets = ReplicatedStorage:WaitForChild("GymAssets", 10)
local SLEEVE_START = 3.0 -- the collar sits at the end of the bar shaft (shaft = 6 studs); a machine model's SleeveStart
-- attribute overrides it (the leg press / hack squat horns sit closer in)

local function plateModel(lb)
	local template = Assets and Assets.Plates:FindFirstChild("Plate" .. lb)
	if template then return template:Clone() end
	-- fallback: a plain disc in the plate's color
	local spec = Machines.Plates[lb]
	local m = Instance.new("Model")
	local disc = Instance.new("Part")
	disc.Name = "Body"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(spec.thickness, spec.diameter, spec.diameter)
	disc.Color = (Theme.Bumper[spec.color] or Theme.Bumper.Black).Fill
	disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch = true, false, false, false
	disc.Parent = m
	m.PrimaryPart = disc
	return m
end

-- Weight stack machines (Stack attribute): the selector pin ("Bar") moves to the block for this tier.
local function updateStack(model, bar, index)
	local blocks = model:GetAttribute("StackBlocks") or 12
	local count = math.clamp(index, 1, blocks)
	local block = model:FindFirstChild("StackBlock" .. count)
	if block then
		local rest = bar:GetAttribute("RestCFrame")
		if typeof(rest) ~= "CFrame" then
			bar:SetAttribute("RestCFrame", bar.CFrame)
			rest = bar.CFrame
		end
		-- same x/z as the pin's rest place, the selected block's height
		bar.CFrame = rest - Vector3.new(0, rest.Position.Y - block.Position.Y, 0)
	end
	model:SetAttribute("StackCount", count)
end

local function updatePlates(model, tier)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	local bar = machine and model:FindFirstChild(machine.load or "Bar")
	if not bar then return end
	local folder = model:FindFirstChild("Plates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Plates"
		folder.Parent = model
	end
	folder:ClearAllChildren()
	local index = table.find(machine.tiers, tier) or 1
	model:SetAttribute("Tier", index)
	if model:GetAttribute("Stack") then
		updateStack(model, bar, index)
		return
	end

	local centered = machine.layout == "Center"
	local sleeveStart = model:GetAttribute("SleeveStart")
	sleeveStart = if type(sleeveStart) == "number" then sleeveStart else SLEEVE_START
	local start = sleeveStart + 0.2
	if centered then
		-- one stack, centered on the load part
		local width = 0
		for _, lb in ipairs(tier.plates) do width += Machines.Plates[lb].thickness + Machines.PlateGap end
		start = -width / 2
	elseif Assets and Assets:FindFirstChild("BarSleeve") then
		for _, side in ipairs({ 1, -1 }) do
			local sleeve = Assets.BarSleeve:Clone()
			sleeve:PivotTo(bar.CFrame * CFrame.new(side * sleeveStart, 0, 0) * (side < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.identity))
			sleeve.Parent = folder
		end
	end
	for _, side in ipairs(centered and { 1 } or { 1, -1 }) do
		local x = start
		for i, lb in ipairs(tier.plates) do
			local spec = Machines.Plates[lb]
			local plate = plateModel(lb)
			plate.Name = "Plate" .. lb
			-- turned around on the left sleeve, so the plate's +X face always looks outward
			plate:PivotTo(bar.CFrame * CFrame.new(side * (x + spec.thickness / 2), 0, 0) * (side < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.identity))
			if i == #tier.plates then
				local face = plate:FindFirstChild("FaceRight")
				local label = face and face:FindFirstChildWhichIsA("SurfaceGui")
				if label then label.Enabled = true end
			end
			plate.Parent = folder
			x += spec.thickness + Machines.PlateGap
		end
		-- a spring collar locks the stack on each sleeve
		if not centered and #tier.plates > 0 then
			local clamp = Instance.new("Part")
			clamp.Name = "ClampCollar"
			clamp.Shape = Enum.PartType.Cylinder
			clamp.Size = Vector3.new(0.1, 0.46, 0.46)
			clamp.Color = Color3.fromHex("#2A2A2E")
			clamp.Material = Enum.Material.Metal
			clamp.Anchored, clamp.CanCollide, clamp.CanQuery, clamp.CanTouch, clamp.CastShadow = true, false, false, false, false
			clamp.CFrame = bar.CFrame * CFrame.new(side * (x + 0.05), 0, 0)
			clamp.Parent = folder
			local handle = clamp:Clone()
			handle.Name = "ClampHandle"
			handle.Shape = Enum.PartType.Block
			handle.Size = Vector3.new(0.06, 0.32, 0.06)
			handle.CFrame = clamp.CFrame * CFrame.new(0, 0.36, 0)
			handle.Parent = folder
		end
	end
end

-- Where the HumanoidRootPart goes for a pose (see Config.Poses).
local function bodyCFrame(character, humanoid, root, model, pose)
	local pivot = model:GetPivot()
	if pose.kind == "Lie" then
		return pivot * pose.body
	end
	local facing = CFrame.Angles(0, math.rad(pose.yaw or 0), 0)
	local height = humanoid.HipHeight + root.Size.Y / 2
	if pose.kind == "Hang" then
		-- straight arms overhead reach the bar
		local torso = character:FindFirstChild("UpperTorso")
		local upper, lower, hand = character:FindFirstChild("RightUpperArm"), character:FindFirstChild("RightLowerArm"), character:FindFirstChild("RightHand")
		local shoulder = upper and upper:FindFirstChild("RightShoulder")
		if torso and shoulder and lower and hand then
			-- R15 joints are Motor6Ds or (newer avatars) AnimationConstraints between rig attachments
			local shoulderPoint = if shoulder:IsA("Motor6D") then (torso.CFrame * shoulder.C0).Position
				elseif shoulder:IsA("AnimationConstraint") and shoulder.Attachment0 then shoulder.Attachment0.WorldPosition
				else torso.Position + Vector3.new(0, torso.Size.Y * 0.4, 0)
			local shoulderHeight = shoulderPoint.Y - root.Position.Y
			local reach = upper.Size.Y + lower.Size.Y + hand.Size.Y * 0.5
			height = pose.barHeight - shoulderHeight - reach
		end
	end
	return pivot * CFrame.new(pose.position + Vector3.new(0, height, 0)) * facing
end

local function leave(player)
	local session = sessions[player]
	if not session then return end
	sessions[player] = nil
	occupants[session.model] = nil
	for _, connection in ipairs(session.connections) do
		connection:Disconnect()
	end

	player:SetAttribute("PumpMeter", nil)
	player:SetAttribute("PumpedUntil", nil)
	local model = session.model
	model:SetAttribute("UserId", nil)
	local modelAlive = model.Parent ~= nil -- (a seasonal machine can be destroyed under the lifter)
	local prompt = getPrompt(model)
	if prompt then prompt.Enabled = true end

	-- free the character first, so nothing after this can leave them anchored
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		root.Anchored = false
		if modelAlive then
			local exit = model:GetPivot() * CFrame.new(Poses[session.machine.pose].exit)
			character:PivotTo(exit + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		end
	end
	if modelAlive then pcall(updatePlates, model, displayTier(session.machine)) end

	if player.Parent then
		Remotes.MachineState:FireClient(player, "Exit")
	end
end

------------------------------------------------------------------------
-- NPC gym-goers (GymGoerService) use machines too. An NPC on a machine is marked with an "Occupant" ObjectValue
-- (clients pose that character); a player who taps Use on it gets the machine and the NPC steps off.
------------------------------------------------------------------------
local npcEvicted = nil -- callback(npc, model) set by GymGoerService

local function isNpc(occupant)
	return occupant ~= nil and not occupant:IsA("Player")
end

-- Gets whoever is lifting on this machine off it (a machine that is about to be destroyed, e.g. a season's Sled Pull).
function MachineService.LeaveModel(model)
	local occupant = occupants[model]
	if occupant and typeof(occupant) == "Instance" and occupant:IsA("Player") then leave(occupant) end
end

function MachineService.IsFree(model)
	return occupants[model] == nil
end

function MachineService.OnNpcEvicted(callback)
	npcEvicted = callback
end

function MachineService.NpcEnter(npc, model, tierIndex)
	if occupants[model] then return false end
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not machine or not humanoid or not root then return false end
	occupants[model] = npc
	local marker = Instance.new("ObjectValue")
	marker.Name = "Occupant"
	marker.Value = npc
	marker.Parent = model
	root.Anchored = true
	npc:PivotTo(bodyCFrame(npc, humanoid, root, model, Poses[machine.pose]))
	updatePlates(model, machine.tiers[math.clamp(tierIndex or 1, 1, #machine.tiers)])
	return true
end

function MachineService.NpcLift(npc, model)
	if occupants[model] ~= npc then return false end
	model:SetAttribute("Reps", (model:GetAttribute("Reps") or 0) + 1)
	return true
end

function MachineService.NpcLeave(npc, model)
	if occupants[model] ~= npc then return end
	occupants[model] = nil
	local marker = model:FindFirstChild("Occupant")
	if marker then marker:Destroy() end
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	updatePlates(model, displayTier(machine))
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if humanoid and root and npc.Parent then
		local exit = model:GetPivot() * CFrame.new(Poses[machine.pose].exit)
		npc:PivotTo(CFrame.new(exit.Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)) * model:GetPivot().Rotation)
	end
end

local function enter(player, model)
	if sessions[player] then return end
	-- an NPC on it steps off for the player
	local occupant = occupants[model]
	if isNpc(occupant) then
		MachineService.NpcLeave(occupant, model)
		if npcEvicted then task.spawn(npcEvicted, occupant, model) end
	end
	if occupants[model] then return end
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not machine or not humanoid or not root or humanoid.Health <= 0 or humanoid.Sit or not PlayerData.Get(player) then return end
	-- gyms open with Growth Spurts (the pro gym at 2)
	if PlayerData.Get(player).growthSpurts < (Machines.GymUnlock[machine.gym] or 0) then
		Remotes.PlayerEvent:FireClient(player, "GymLocked", { gym = machine.gym, spurts = Machines.GymUnlock[machine.gym] })
		return
	end

	-- off the skateboard first (it changes the hip height the pose is placed from)
	local skateOk, SkateService = pcall(require, script.Parent.SkateService)
	if skateOk then SkateService.Stop(player) end
	-- and out of a held pose (it would keep the arms posed on the bar)
	local poseOk, ShowOffService = pcall(require, script.Parent.ShowOffService)
	if poseOk and ShowOffService.ReleasePose then ShowOffService.ReleasePose(player) end

	local session = { model = model, machine = machine, lastRep = 0, connections = {},
		pump = { meter = 0, lastTap = 0, pumpedUntil = 0 }, nextBig = false }
	sessions[player] = session
	occupants[model] = player
	model:SetAttribute("UserId", player.UserId)
	local prompt = getPrompt(model)
	if prompt then prompt.Enabled = false end

	humanoid.PlatformStand = true
	root.Anchored = true
	character:PivotTo(bodyCFrame(character, humanoid, root, model, Poses[machine.pose]))

	table.insert(session.connections, humanoid.Died:Connect(function()
		leave(player)
	end))

	local progress = PlayerData.GetMachine(player, machine.id)
	local level = PlayerData.Get(player).muscles[machine.muscles[1].id].level
	updatePlates(model, machine.tiers[Machines.LiftTier(machine, progress, level)])
	Remotes.MachineState:FireClient(player, "Enter", model)
end

------------------------------------------------------------------------
-- PUMP meter: taps fill it, a full meter = PUMPED for Gains.Pump.Duration (x2 gains), not tapping drains it.
-- The server owns it; the client predicts it for an instant feel and follows these player attributes.
------------------------------------------------------------------------
local Pump = Gains.Pump

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Bring the meter up to date (it drains once the taps stop) and return it.
local function settlePump(session, now)
	local pump = session.pump
	local from = math.max(pump.settled or now, pump.lastTap + Pump.DrainDelay, pump.pumpedUntil)
	if now > from and pump.meter > 0 then
		pump.meter = math.max(0, pump.meter - Pump.DrainPerSecond * (now - from))
	end
	pump.settled = now
	return pump
end

local function tap(player)
	local session = sessions[player]
	if not session then return end
	if not Guard.Allow(player, "tap", Pump.TapsPerSecond, Pump.TapsPerSecond) then return end
	local now = serverNow()
	local pump = settlePump(session, now)
	pump.lastTap = now
	if now < pump.pumpedUntil then return end -- already PUMPED: it runs out on its own
	pump.meter = math.min(1, pump.meter + 1 / Pump.TapsToFill)
	if pump.meter >= 1 then
		pump.meter = 0
		pump.pumpedUntil = now + Pump.Duration
		player:SetAttribute("PumpedUntil", pump.pumpedUntil)
	end
	player:SetAttribute("PumpMeter", math.floor(pump.meter * 100 + 0.5) / 100)
end

local function lift(player)
	local session = sessions[player]
	if not session then return end
	local now = os.clock()
	if now - session.lastRep < Gains.RepCooldown then return end
	if not Guard.Allow(player, "lift", Gains.MaxRepsPerSecond, Gains.RepBurst) then return end
	local data = PlayerData.Get(player)
	if not data then return end

	local machine = session.machine
	if not PlayerData.UseStamina(player, machine.staminaCost) then
		Remotes.RepResult:FireClient(player, { noStamina = true })
		return
	end
	session.lastRep = now

	local progress = PlayerData.GetMachine(player, machine.id)
	local tierIndex = Machines.LiftTier(machine, progress, data.muscles[machine.muscles[1].id].level)
	local tier = machine.tiers[tierIndex]
	-- how the rep was done: PUMPED x2, BIG REP x3 (rolled one rep ahead, so the client can show it at lockout)
	local pumped = serverNow() < session.pump.pumpedUntil
	local big = session.nextBig
	session.nextBig = math.random() < Gains.BigRep.Chance
	local quality = (pumped and Pump.Multiplier or 1) * (big and Gains.BigRep.Multiplier or 1)
	local xp = Gains.PerRep(data, machine, tierIndex, BoostService.Gains(player), quality)

	local levels = {}
	for muscleId, amount in pairs(xp) do
		if PlayerData.AddMuscleXp(player, muscleId, amount) > 0 then
			local level = data.muscles[muscleId].level
			levels[muscleId] = level
		end
	end
	local coins = math.max(1, math.floor(tier.coins * BoostService.Coins(player) + 0.5))
	PlayerData.AddCoins(player, coins)
	TitleService.OnRep(player)
	QuestService.OnRep(player, machine.id)
	SocialService.OnRep(player, machine.id)
	LegendService.OnRep(player, machine.id)
	SeasonService.OnRep(player)

	-- personal record: the heaviest weight ever lifted on this machine
	local pr = nil
	if tierIndex > (progress.best or 1) then
		PlayerData.SetMachine(player, machine.id, progress.unlocked, progress.selected, tierIndex)
		pr = Machines.WeightText(tier)
	end

	session.model:SetAttribute("Reps", (session.model:GetAttribute("Reps") or 0) + 1)
	Remotes.RepResult:FireClient(player, { levels = levels, coins = coins, big = big,
		nextBig = session.nextBig, pumped = pumped, pr = pr })
end

local function isTierIndex(value)
	return type(value) == "number" and value == math.floor(value)
end

local function selectTier(player, index)
	local session = sessions[player]
	if not session or not isTierIndex(index) then return end
	local machine = session.machine
	local progress = PlayerData.GetMachine(player, machine.id)
	if index < 1 or index > progress.unlocked then return end
	-- bought tiers still need the level (again after a Growth Spurt)
	if PlayerData.Get(player).muscles[machine.muscles[1].id].level < machine.tiers[index].unlockLevel then return end
	PlayerData.SetMachine(player, machine.id, progress.unlocked, index)
	updatePlates(session.model, machine.tiers[index])
end

local function unlockTier(player, index)
	local session = sessions[player]
	if not session or not isTierIndex(index) then return end
	local machine = session.machine
	local progress = PlayerData.GetMachine(player, machine.id)
	local tier = machine.tiers[index]
	if not tier or index ~= progress.unlocked + 1 then return end

	local data = PlayerData.Get(player)
	if data.muscles[machine.muscles[1].id].level < tier.unlockLevel then return end
	if not PlayerData.SpendCoins(player, tier.cost) then return end

	PlayerData.SetMachine(player, machine.id, index, index)
	updatePlates(session.model, tier)
end

local actions = {
	Lift = lift,
	Tap = tap,
	Leave = leave,
	SelectTier = selectTier,
	UnlockTier = unlockTier,
}

local function setupMachine(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine then
		warn("[MachineService] Unknown MachineId on", model:GetFullName())
		return
	end
	-- Workspace streaming: the whole machine is always on every client (posing, plates and the bar need all of it)
	if model:IsA("Model") then model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end
	local prompt = getPrompt(model)
	if prompt then
		prompt.ActionText = "Use"
		prompt.ObjectText = machine.name -- each client adds its own next-weight line (MachineClient)
		Guard.OnTriggered(prompt, function(player)
			enter(player, model)
		end)
	end
	updatePlates(model, displayTier(machine))
end

function MachineService.Start()
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		setupMachine(model)
	end
	CollectionService:GetInstanceAddedSignal("Machine"):Connect(setupMachine)

	-- reps, taps, tier buttons and Exit: far more than a real player can send, far less than a spam script
	Guard.Remote(Remotes.MachineAction, "MachineAction", 16, 24, function(player, action, arg)
		local handler = type(action) == "string" and actions[action]
		if handler then
			handler(player, arg)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			leave(player)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterRemoving:Connect(function()
			leave(player)
		end)
	end
	Players.PlayerRemoving:Connect(leave)
end

return MachineService
