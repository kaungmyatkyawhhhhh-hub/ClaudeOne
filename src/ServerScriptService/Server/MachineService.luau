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
local TitleService = require(script.Parent.TitleService)
local QuestService = require(script.Parent.QuestService)
local BoostService = require(script.Parent.BoostService)
local Theme = require(ReplicatedStorage.Shared.UI.Theme) -- bumper plate colors

-- Bars sit loaded when nobody is using them (a mix, so the gym shows every bumper color).
local DISPLAY_TIERS = { FlatBench = 5, InclineBench = 4, OverheadPress = 3, SquatRack = 6, Deadlift = 5, BarbellRow = 4, PullUpBar = 3, CrunchBench = 3 }
local function displayTier(machine)
	return machine.tiers[math.min(DISPLAY_TIERS[machine.id] or 4, #machine.tiers)]
end

local Remotes = ReplicatedStorage.Remotes


local MachineService = {}

local sessions = {}  -- [player] = { model, machine, lastRep, connections }
local occupants = {} -- [model] = player

local function getPrompt(model)
	return model:FindFirstChildWhichIsA("ProximityPrompt", true)
end

-- Plates go on the machine's load part: both sleeves of a bar, or one centered stack.
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
	model:SetAttribute("Tier", table.find(machine.tiers, tier) or 1)

	local centered = machine.layout == "Center"
	local sleeveStart = bar.Size.X / 2 - 1.3
	if centered then
		-- one stack, centered on the load part
		local width = 0
		for _, lb in ipairs(tier.plates) do width += Machines.Plates[lb].thickness + 0.03 end
		sleeveStart = -width / 2
	end
	for _, side in ipairs(centered and { 1 } or { 1, -1 }) do
		local x = sleeveStart
		for _, lb in ipairs(tier.plates) do
			local spec = Machines.Plates[lb]
			local plate = Instance.new("Part")
			plate.Name = "Plate" .. lb
			plate.Shape = Enum.PartType.Cylinder
			plate.Size = Vector3.new(spec.thickness, spec.diameter, spec.diameter)
			local bumper = Theme.Bumper[tier.color or "Black"]
			plate.Color = bumper.Fill
			plate.Material = Enum.Material.SmoothPlastic
			plate.Anchored = true
			plate.CanCollide = false
			plate.CanQuery = false
			plate.CanTouch = false
			plate.CFrame = bar.CFrame * CFrame.new(side * (x + spec.thickness / 2), 0, 0)
			plate.Parent = folder
			local hub = plate:Clone()
			hub.Name = "Hub"
			hub.Size = Vector3.new(spec.thickness + 0.04, 0.55, 0.55)
			hub.Color = bar.Color
			hub.Material = Enum.Material.Metal
			hub.Reflectance = 0.25
			hub.CastShadow = false
			hub.Parent = folder
			x += spec.thickness + 0.03
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
			local shoulderHeight = (torso.CFrame * shoulder.C0).Position.Y - root.Position.Y
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

	local model = session.model
	model:SetAttribute("UserId", nil)
	local prompt = getPrompt(model)
	if prompt then prompt.Enabled = true end
	updatePlates(model, displayTier(session.machine))

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		root.Anchored = false
		local exit = model:GetPivot() * CFrame.new(Poses[session.machine.pose].exit)
		character:PivotTo(exit + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	end

	if player.Parent then
		Remotes.MachineState:FireClient(player, "Exit")
	end
end

local function enter(player, model)
	if sessions[player] or occupants[model] then return end
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not machine or not humanoid or not root or humanoid.Health <= 0 or not PlayerData.Get(player) then return end

	local session = { model = model, machine = machine, lastRep = 0, connections = {} }
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
	updatePlates(model, machine.tiers[progress.selected])
	Remotes.MachineState:FireClient(player, "Enter", model)
end

local function lift(player)
	local session = sessions[player]
	if not session then return end
	local now = os.clock()
	if now - session.lastRep < Gains.RepCooldown then return end
	local data = PlayerData.Get(player)
	if not data then return end

	local machine = session.machine
	if not PlayerData.UseStamina(player, machine.staminaCost) then
		Remotes.RepResult:FireClient(player, { noStamina = true })
		return
	end
	session.lastRep = now

	local progress = PlayerData.GetMachine(player, machine.id)
	local tier = machine.tiers[progress.selected]
	local cap = PlayerData.GetLevelCap(player)
	local xp = Gains.PerRep(data, machine, progress.selected, BoostService.Gains(player))

	local levels, maxed = {}, {}
	for muscleId, amount in pairs(xp) do
		if PlayerData.AddMuscleXp(player, muscleId, amount) > 0 then
			local level = data.muscles[muscleId].level
			levels[muscleId] = level
			if level >= cap then maxed[muscleId] = true end
		end
	end
	local coins = math.max(1, math.floor(tier.coins * BoostService.Coins(player) + 0.5))
	PlayerData.AddCoins(player, coins)
	TitleService.OnRep(player)
	QuestService.OnRep(player, machine.id)

	session.model:SetAttribute("Reps", (session.model:GetAttribute("Reps") or 0) + 1)
	Remotes.RepResult:FireClient(player, { levels = levels, maxed = maxed, coins = coins })
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
	local prompt = getPrompt(model)
	if prompt then
		prompt.ActionText = "Use"
		prompt.ObjectText = machine.name
		prompt.Triggered:Connect(function(player)
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

	Remotes.MachineAction.OnServerEvent:Connect(function(player, action, arg)
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
