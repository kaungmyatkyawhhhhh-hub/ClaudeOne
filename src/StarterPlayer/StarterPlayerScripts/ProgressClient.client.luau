-- ProgressClient: the Growth Spurt card at the bottom of the right column (owner's UI redesign, mockup 01_main_hud), the
-- small "next goal" line in it, and the short "you grew" moment when the body moves up a muscle tier (BodyService fires
-- "Grew").
--  * The card: an up arrow, GROWTH SPURT, the EXP so far / the goal (each group counted up to its goal) and a gold bar.
--    When every group is there it says "READY! TAP TO GROW" and a tap does the Growth Spurt (same action as the Muscles
--    screen's button). At 7'0" it reads MAX GROWTH SPURT REACHED (greyed, not tappable).
--  * The goal line always shows the next small thing (a new weight a few reps away, coins for the next weight, which
--    group to train), so there's a new goal every 30-60 seconds.
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
-- (the whole card is the button; it only does something when the Growth Spurt is ready)
local card = RightColumn.Tracker({ name = "GrowthSpurt", title = "Growth Spurt", color = Colors.Gold, icon = "arrow-big-up", iconColor = Colors.Gold, order = 9, idleOnly = "bottom", clickable = true })
card.frame.Visible = false

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

local function refresh()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local progress, have, need = spurtProgress(data)
	if progress.maxed then
		card:SetTitle("Max Growth Spurt reached")
		card:SetCount("")
		card:SetProgress(1, GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts), true))
		card:SetColor(Colors.Faint)
	else
		card:SetTitle(progress.ready and "Ready! Tap to grow" or ("Growth Spurt " .. (data.growthSpurts + 1)))
		card:SetCount("")
		card:SetProgress(need > 0 and have / need or 0, Kit.Format(have) .. " / " .. Kit.Format(need))
		card:SetColor(Colors.Gold)
	end
	card:SetText("")
	card:SetFooter(goalText(data, progress))
	ready = progress.ready
	card.title.TextColor3 = ready and Colors.Gold or Colors.Text
end

card.Activated:Connect(function()
	if ready then Remotes.PlayerAction:FireServer("GrowthSpurt") end
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
	card.frame.Visible = true
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
