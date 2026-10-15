-- ProgressClient: the Growth Spurt button in the right column (owner's final kit "BLACK + GOLD", mockup 01_hud) and the
-- short "you grew" moment when the body moves up a muscle tier (BodyService fires "Grew").
--  * The button (a card in the right column, one card at a time: RightColumn.Priority): when every group is at its goal,
--    the wide gold TAP TO GROW CTA ("GROWTH SPURT 2 READY" under it) with a glow that pulses, the first card to show; a
--    tap does the Growth Spurt (same action as the Physique screen's button). Before that it is a quiet dark card
--    "GROWTH SPURT 2" with how far you are ("62%"), shown only when no other card wants the spot; a tap opens Physique.
--    At 7'0" there is no card (owner, 14 Oct and again 15 Oct: the top bar's height reads "7'0" MAX", Stats has the greyed
--    "Max Growth Spurt reached" button).
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
local UIBus = require(Shared.UI.UIBus)
local TILE_H = 44
local holder = New("Frame", { Name = "GrowthSpurt", Size = UDim2.fromOffset(RightColumn.Width, TILE_H + 6), BackgroundTransparency = 1, Visible = false })
local tile = Theme.Button("Gold", { Name = "Tile", Size = UDim2.new(1, 0, 0, TILE_H), Parent = holder }, {})
local tileText = Kit.Text({ Name = "Grow", Text = "TAP TO GROW", Font = "Title", TextSize = 18, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), Parent = tile })
Kit.Fit(tileText, 18, 11) -- ("MAX GROWTH SPURT" fits the card)
local tileLabel = Kit.Text({ Name = "Label", Text = "", Font = "Title", TextSize = 10, Upper = true, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 12), Parent = tile })
-- (owner, 15 Oct: always shown under the one priority card; it had vanished behind Today's Quest)
RightColumn.Add(holder, 9, "bottom")
local started = false -- (shown after the data is in)

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
	return weight .. " is ready: press + on the panel" -- (weights are free, owner 14 Oct)
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
	holder:SetAttribute("CardPriority", ready and RightColumn.Priority.GrowReady or RightColumn.Priority.Grow)
	-- (owner, 15 Oct, later: at the 7'0" cap NO card on the HUD; the top bar's "7'0" MAX" and the Stats panel's greyed
	-- button show it)
	holder.Visible = started and not progress.maxed
	if progress.maxed then
		tileText.Text = "MAX GROWTH SPURT"
		tileLabel.Text = "Reached · " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts), true)
		Theme.SetButtonStyle(tile, "Disabled")
	elseif ready then
		tileText.Text = "TAP TO GROW"
		tileLabel.Text = "Growth Spurt " .. (data.growthSpurts + 1) .. " ready"
		Theme.SetButtonStyle(tile, "Gold")
		Theme.Pulse(tile, function() return ready end)
	else
		tileText.Text = "GROWTH SPURT " .. (data.growthSpurts + 1)
		tileLabel.Text = math.floor((need > 0 and have / need or 0) * 100) .. "% · tap for your physique"
		Theme.SetButtonStyle(tile, "Quiet")
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
	started = true
	refresh()
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
