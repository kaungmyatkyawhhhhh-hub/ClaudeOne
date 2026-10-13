-- ProgressClient: the GROW tile in the right column (owner's UI v2, mockup 01_main_hud) and the short "you grew" moment
-- when the body moves up a muscle tier (BodyService fires "Grew").
--  * The tile: a gold square with a big up arrow and "Growth Spurt N" under it. While you work toward it, it shows how far
--    you are (the EXP so far / the goal, each group counted up to its goal) as "62%"; when every group is there it says
--    GROW! with a red READY tag, and a tap does the Growth Spurt (same action as the Stats screen's button). Before that a
--    tap opens Stats. At 7'0" it reads MAX (gray).
--  * The next small goal (a new weight a few reps away, coins for the next weight, which group to train) is a hint in the
--    top band now and then (Notify.Hint), not text on the HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local Gains = require(Config.Gains)
local GrowthSpurts = require(Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local RightColumn = require(Shared.UI.RightColumn)
local Notify = require(Shared.UI.Notify)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------
local Pieces = require(Shared.UI.Pieces)
local UIBus = require(Shared.UI.UIBus)
local TILE = 76
local holder = New("Frame", { Name = "GrowthSpurt", Size = UDim2.fromOffset(RightColumn.Width, TILE + 22), BackgroundTransparency = 1, Visible = false })
local tile = Theme.Button("Gold", { Name = "Tile", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(TILE, TILE), Parent = holder }, {})
Pieces.Icon("arrow-big-up", Colors.Text, { Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7),
	Size = UDim2.fromOffset(38, 38), Parent = tile }):SetAttribute("KeepColor", true)
local tileText = Kit.Text({ Name = "Grow", Text = "GROW!", Font = "Title", TextSize = 16, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, 0, 0, 20), Parent = tile })
local readyTag = New("Frame", { Name = "Ready", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -16, 0, 2), Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Colors.Red, Visible = false, ZIndex = 4, Parent = tile }, {
	New("UICorner", { CornerRadius = UDim.new(0, 6) }),
	New("UIStroke", { Color = Colors.Text, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
})
Kit.Text({ Name = "Text", Text = "READY", Font = "Title", TextSize = 13, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4, Parent = readyTag })
local tileLabel = Kit.Text({ Name = "Label", Text = "Growth Spurt 1", Font = "Title", TextSize = 13, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(1, -TILE / 2, 0, TILE + 3), Size = UDim2.fromOffset(150, 18), Parent = holder })
RightColumn.Add(holder, 9, "bottom")

------------------------------------------------------------------------
-- Progress + goals
------------------------------------------------------------------------
local currentMachine = nil -- the machine the player is on (MachineState)
local ready = false

local function spurtProgress(data)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	local have, need = 0, 0
	for _, group in ipairs(Muscles.Groups) do
		local level = progress.groups[group.id] or 0
		have += Muscles.Shown(math.min(level, progress.required))
		need += Muscles.Shown(progress.required)
	end
	return progress, have, need
end

-- Reps of `machine` (at the tier the player lifts now) until its main muscle reaches `level`.
local function repsToLevel(data, machine, level)
	local main = data.muscles[machine.muscles[1].id]
	local need = -main.xp
	for l = main.level, level - 1 do need += Muscles.XpToNext(l) end
	local tierIndex = Machines.LiftTier(machine, data.machines[machine.id], main.level)
	local perRep = Gains.PerRep(data, machine, tierIndex, player:GetAttribute("GainsBoost"))[machine.muscles[1].id] or 1
	return math.max(1, math.ceil(need / math.max(perRep, 0.01)))
end

-- The next small goal for a machine: a heavier weight.
local function machineGoal(data, machine)
	local progress = data.machines[machine.id]
	local level = data.muscles[machine.muscles[1].id].level
	local usable = Machines.UsableTier(machine, progress, level)
	local nextTier = machine.tiers[usable + 1]
	if not nextTier then return nil end
	local weight = Machines.WeightText(nextTier)
	if level < nextTier.unlockLevel then
		if machine.trains == "Stamina" then -- (running trains stamina: the faster speeds unlock with leg training)
			return "Train " .. Muscles.ById[machine.muscles[1].id].name .. " to unlock " .. weight
		end
		local reps = repsToLevel(data, machine, nextTier.unlockLevel)
		return reps .. (reps == 1 and " rep" or " reps") .. " to unlock " .. weight
	end
	local bought = (progress and progress.unlocked or 1) >= usable + 1
	if bought then return weight .. " is ready: press + on the panel" end
	if data.coins >= nextTier.cost then return "Unlock " .. weight .. " for " .. nextTier.cost .. " coins" end
	return (nextTier.cost - data.coins) .. " more coins to unlock " .. weight
end

local function goalText(data, progress)
	if progress.maxed or progress.ready then return "" end
	if currentMachine then
		local goal = machineGoal(data, currentMachine)
		if goal then return goal end
	end
	-- the group furthest from the goal, and a machine that trains it
	local lowest, lowestLevel = nil, math.huge
	for _, group in ipairs(Muscles.Groups) do
		local level = progress.groups[group.id]
		if level < progress.required and level < lowestLevel then lowest, lowestLevel = group, level end
	end
	if not lowest then return "" end
	for _, machine in ipairs(Machines.List) do
		local open = data.growthSpurts >= (Machines.GymUnlock[machine.gym] or 0) and machine.gym ~= "Seasonal"
		if open and machine.trains ~= "Stamina" and Muscles.ById[machine.muscles[1].id].group == lowest.id then
			return "Next: " .. lowest.name .. " on the " .. machine.name
		end
	end
	return "Next: train " .. lowest.name
end

local lastGoal, lastGoalAt = "", 0
local function refresh()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local progress, have, need = spurtProgress(data)
	ready = progress.ready and not progress.maxed
	readyTag.Visible = ready
	if progress.maxed then
		tileText.Text = "MAX"
		tileLabel.Text = GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts), true)
		Theme.SetButtonStyle(tile, "Gray")
	else
		tileText.Text = ready and "GROW!" or (math.floor((need > 0 and have / need or 0) * 100) .. "%")
		tileLabel.Text = "Growth Spurt " .. (data.growthSpurts + 1)
		Theme.SetButtonStyle(tile, "Gold")
	end
	-- the next small goal: a hint now and then (never more than one a minute, and only a new one)
	local goal = goalText(data, progress)
	if goal ~= "" and goal ~= lastGoal and os.clock() - lastGoalAt > 60 then
		lastGoal, lastGoalAt = goal, os.clock()
		Notify.Hint(goal)
	end
end

tile.Activated:Connect(function()
	if ready then
		Remotes.PlayerAction:FireServer("GrowthSpurt")
	else
		UIBus.OpenStats:Fire("Muscles")
	end
end)

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		currentMachine = Machines.ById[model:GetAttribute("MachineId")]
	elseif state == "Exit" then
		currentMachine = nil
	end
	refresh()
end)

------------------------------------------------------------------------
-- "You grew": a quick pulse on the body, a sound and a small note
------------------------------------------------------------------------
local function grewMoment(tier)
	local character = player.Character
	if not character then return end
	Audio.Play2D("Grew")
	local glow = New("Highlight", {
		FillColor = Colors.Text,
		FillTransparency = 0.45,
		OutlineColor = Colors.Text,
		OutlineTransparency = 0.3,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Adornee = character,
		Parent = character,
	})
	Theme.Tween(glow, { FillTransparency = 1, OutlineTransparency = 1 }, 0.8)
	task.delay(0.85, function() glow:Destroy() end)
	local camera = Workspace.CurrentCamera
	local fov = camera.FieldOfView
	camera.FieldOfView = fov + 3
	Theme.Tween(camera, { FieldOfView = fov }, 0.35)
	Notify.Show("You grew! Muscle tier " .. tier)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, payload)
	if kind == "Grew" and type(payload) == "table" and type(payload.tier) == "number" then
		grewMoment(payload.tier)
	end
end)

------------------------------------------------------------------------
task.spawn(function()
	ClientData.Get() -- waits for the data snapshot
	refresh()
	holder.Visible = true
end)
ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" or key == "machines" or key == "coins" then refresh() end
end)
task.spawn(function()
	while true do
		task.wait(2)
		refresh()
	end
end)
