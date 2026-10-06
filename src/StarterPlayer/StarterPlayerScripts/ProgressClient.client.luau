-- ProgressClient: the always-visible Growth Spurt bar (top center), the small "next goal" line under it, and the
-- short "you grew" moment when the body moves up a muscle tier (BodyService fires "Grew").
--  * The bar fills smoothly with the average progress of the 6 groups toward the next Growth Spurt goal. When every
--    group is there it says so and a tap does the Growth Spurt (same action as the Stats screen's button).
--  * The goal line always shows the next small thing (a new weight a few reps away, coins for the next weight, which
--    group to train), so there's a new goal every 30-60 seconds.
--  * Hidden while the menu, the genetics screen or the Stats overlay (which has its own goal panel) is up.
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
local UIBus = require(Shared.UI.UIBus)
local Notify = require(Shared.UI.Notify)
local Icons = require(Shared.UI.Icons)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local SEGMENTS = 20
local compact = Theme.IsCompact()

local gui = Theme.ScreenGui({ Name = "SpurtBar", DisplayOrder = 4, Enabled = false, Parent = player:WaitForChild("PlayerGui") })

local panel = Theme.Button("Secondary", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, Theme.Spacing.S),
	Size = UDim2.fromOffset(compact and 260 or 320, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
}, { Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top), Theme.Pad("S") })
panel.Active = false -- only tappable when the Growth Spurt is ready

local titleRow = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = panel })
local title = Theme.Text({ Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(0.7, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = titleRow })
local heightLabel = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = titleRow })

-- the arrow: collapses the panel to its title row and expands it again
local arrow = New("TextButton", { Name = "Arrow", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = titleRow })
local arrowIcon = Icons.Chevron(1, Colors.Text)
arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
arrowIcon.Position = UDim2.fromScale(0.5, 0.5)
arrowIcon.Size = UDim2.fromScale(1, 1)
arrowIcon.Rotation = -90
arrowIcon.Parent = arrow

local barRow = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, Parent = panel }, { Theme.List(Horizontal, "XS") })
local fills = {}
for i = 1, SEGMENTS do
	local back = New("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = barRow },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	fills[i] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end

-- the next goal: white (readable over any background) and wrapped onto a second line instead of being cut off
local goalLabel = Theme.Text({ LayoutOrder = 3, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Text, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Parent = panel })
Theme.TextShadow(goalLabel)

local collapsed = false
local function setCollapsed(value)
	collapsed = value
	barRow.Visible = not collapsed
	goalLabel.Visible = not collapsed
	Theme.Tween(arrowIcon, { Rotation = collapsed and 90 or -90 }, 0.2)
end
arrow.Activated:Connect(function()
	Audio.PlayUI("Click")
	setCollapsed(not collapsed)
end)

------------------------------------------------------------------------
-- Progress + goals
------------------------------------------------------------------------
local currentMachine = nil -- the machine the player is on (MachineState)
local shownFill = -1
local ready = false

local function spurtProgress(data)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	local total = 0
	for _, level in pairs(progress.groups) do total += math.min(level / progress.required, 1) end
	return progress, total / #Muscles.Groups
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
		local reps = repsToLevel(data, machine, nextTier.unlockLevel)
		return reps .. (reps == 1 and " rep" or " reps") .. " to unlock " .. weight
	end
	local bought = (progress and progress.unlocked or 1) >= usable + 1
	if bought then return weight .. " is ready: press + on the panel" end
	if data.coins >= nextTier.cost then return "Unlock " .. weight .. " for " .. nextTier.cost .. " coins" end
	return (nextTier.cost - data.coins) .. " more coins to unlock " .. weight
end

local function goalText(data, progress)
	if progress.ready then return "Ready! Tap here to grow" end
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
		if open and Muscles.ById[machine.muscles[1].id].group == lowest.id then
			return "Next: " .. lowest.name .. " on the " .. machine.name
		end
	end
	return "Next: train " .. lowest.name
end

local lastGoal = nil
local function setGoal(text)
	if text == lastGoal then return end
	lastGoal = text
	goalLabel.Text = text
	goalLabel.TextTransparency = 0 -- always solid (a fade-in here could get stuck half-transparent)
end

local function refresh()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local progress, fill = spurtProgress(data)
	local nextSpurt = data.growthSpurts + 1
	title.Text = "Growth Spurt " .. nextSpurt
	heightLabel.Text = GrowthSpurts.FormatHeight(GrowthSpurts.Get(nextSpurt).height)
	if math.abs(fill - shownFill) > 0.0005 then
		shownFill = fill
		for i, segment in ipairs(fills) do
			Theme.Tween(segment, { Size = UDim2.fromScale(math.clamp(fill * SEGMENTS - (i - 1), 0, 1), 1) }, 0.4)
		end
	end
	ready = progress.ready
	panel.Active = ready
	goalLabel.FontFace = ready and Theme.Fonts.SemiBold or Theme.Fonts.Regular
	setGoal(goalText(data, progress))
end

panel.Activated:Connect(function()
	if ready then Remotes.PlayerAction:FireServer("GrowthSpurt") end
end)

------------------------------------------------------------------------
-- Visibility
------------------------------------------------------------------------
local hidden = { menu = true, genetics = false, stats = false }
local shown = false
local function updateVisible()
	local want = not (hidden.menu or hidden.genetics or hidden.stats)
	if want == shown then return end
	shown = want
	if want then
		gui.Enabled = true
		Theme.Fade(panel, true)
	else
		local tween = Theme.Fade(panel, false)
		if tween then
			tween.Completed:Connect(function()
				if not shown then gui.Enabled = false end
			end)
		else
			gui.Enabled = false
		end
	end
end

UIBus.GeneticsVisible.Event:Connect(function(visible) hidden.genetics = visible; updateVisible() end)
UIBus.MusclesVisible.Event:Connect(function(visible) hidden.stats = visible; updateVisible() end)

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		currentMachine = Machines.ById[model:GetAttribute("MachineId")]
	elseif state == "Exit" then
		currentMachine = nil
	end
	refresh()
end)

------------------------------------------------------------------------
-- "You grew": a quick pulse on the body, a sound and a small corner note
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
	ClientData.Get() -- waits for the data snapshot (by then the menu screen has started)
	UIBus.WaitForMenu()
	hidden.menu = false
	refresh()
	updateVisible()
end)
ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" or key == "machines" or key == "coins" then refresh() end
end)
task.spawn(function()
	while true do
		task.wait(2)
		if shown then refresh() end
	end
end)

-- phones get a narrower bar (switches live with the screen size)
Theme.OnCompactChanged(function(isCompact)
	panel.Size = UDim2.fromOffset(isCompact and 260 or 320, 0)
end)
