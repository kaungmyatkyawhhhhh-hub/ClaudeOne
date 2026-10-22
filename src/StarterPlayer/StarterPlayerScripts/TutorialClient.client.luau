-- TutorialClient: the first 5 minutes, after the menu and the genetics reveal. Steps come from Config.Onboarding.
-- Owner's UI v2 (mockup 11): each step's short line goes to the top band (Notify.SetBand), a green SKIP TUTORIAL sits
-- under it (tap twice: the first tap asks "Tap again to skip"), and the step's coach pages show in a dialog at the bottom
-- (a live portrait of the Coach NPC, "Coach Dex · Reward (coin) 50", the words, "Tap to continue (1/3)"). On a machine
-- there is no dialog, so it never covers the machine HUD (the band has the step's line). Steps that lead to a machine
-- draw a glowing path of dots on the floor (Shared/UI/GuidePath: Roblox pathfinding, so it walks around equipment) and
-- outline the machine.
-- Progress is saved through the server, so a player who leaves mid-tutorial picks up where they were.
-- Prompt 53a (23 Oct): the new UI. The dialog (Shared/UI/CoachDialog), the gold marker with the target's name over it
-- (GuidePath.Mark), the band (a dark pill, Notify), SKIP (dark pill; "TAP AGAIN TO SKIP" in gold) and, for a button on
-- screen (the shake slot, STOP, Stats, Muscles), the Spotlight (Shared/UI/Spotlight: the rest dims, a gold glow and a
-- bouncing gold arrow). The steps and rewards are unchanged.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Onboarding = require(Shared.Config.Onboarding)
local Quests = require(Shared.Config.Quests)
local Stamina = require(Shared.Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing


------------------------------------------------------------------------
-- Wait for the menu, the data, and the genetics reveal
------------------------------------------------------------------------
local data = ClientData.Get()
local savedStep = data.onboarding.tutorialStep or Onboarding.Done
if savedStep >= Onboarding.Done or savedStep > #Onboarding.Steps then return end
UIBus.WaitForMenu()

local geneticsVisible = false
UIBus.GeneticsVisible.Event:Connect(function(visible) geneticsVisible = visible end)
while not data.onboarding.geneticsRevealed or geneticsVisible do
	task.wait(0.25)
end
task.wait(0.8)

------------------------------------------------------------------------
-- Coach line
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "Tutorial", DisplayOrder = 23, Parent = playerGui }) -- above the stats screen (22), under open panels (24+)
local line = Theme.Panel({
	Name = "CoachLine",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	Parent = gui,
}, {
	New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.L), PaddingRight = UDim.new(0, Spacing.L) }),
	Theme.List(Enum.FillDirection.Horizontal, "S"),
})
New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(Spacing.S, Spacing.S), BackgroundColor3 = Colors.Text, Parent = line }, { Theme.Round("Round") })
local lineText = Theme.Text({ LayoutOrder = 2, Font = "Regular", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Parent = line })

local statsOpen = false
local onMachine = nil -- MachineId of the machine the player is on
local function placeLine()
	-- the top row (TopBar: coins / level / height) owns the top center: sit just under it. While the stats screen is
	-- open the row hides, so the line moves up to the top (it draws above the stats screen).
	local spurtGui = playerGui:FindFirstChild("TopBar")
	local bar = spurtGui and spurtGui:FindFirstChild("Row", true)
	line.AnchorPoint = Vector2.new(0.5, 0)
	if not statsOpen and spurtGui and spurtGui.Enabled and bar and bar:IsA("GuiObject") and bar.AbsoluteSize.Y > 0 then
		-- both are Theme.ScreenGuis (same inset), so the bar's AbsolutePosition is in this gui's space
		line.Position = UDim2.new(0.5, 0, 0, bar.AbsolutePosition.Y - gui.AbsolutePosition.Y + bar.AbsoluteSize.Y + Spacing.S)
	else
		line.Position = UDim2.new(0.5, 0, 0, Spacing.S)
	end
end

-- (owner, 13 Oct: one hint at a time, in the top band, gone after 4 s: the step's line goes to Notify's band; the old
-- coach line pill stays hidden)
line.Visible = false
local shownText = nil
local function setLine(text)
	if text == shownText then return end
	shownText = text
	lineText.Text = text
	Notify.SetBand(text)
end

------------------------------------------------------------------------
-- SKIP TUTORIAL and the coach dialog (mockup 11)
------------------------------------------------------------------------
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- the same top as Notify's band and toasts, so they line up
local root = Kit.Root(gui)
-- (22 Oct, owner) a small dark SKIP pill top-right (was a big green SKIP TUTORIAL bar under the band). Prompt 53: always
-- the same spot, just under the top bar on the right (Shared/UI/SkipPill: tap twice, the first tap turns it gold, "TAP AGAIN
-- TO SKIP").
local skipPill = nil -- (made below, once finish exists)
local skipReady = false
local applySkip -- (below)
-- (owner, 21 Oct) SKIP TUTORIAL only after the player has been in the game for SkipAfter seconds: counted from when the
-- menu is gone and the genetics screen has closed, so a new player sees the first step before the way out
local SkipAfter = 5
task.spawn(function()
	UIBus.WaitForMenu()
	task.wait(1.5) -- (the genetics screen opens a moment after Play)
	while UIBus.GeneticsUp do
		UIBus.GeneticsVisible.Event:Wait()
	end
	task.wait(SkipAfter)
	skipReady = true
	if applySkip then applySkip() end
end)

-- (prompt 39) the Coach Dex dialog lives in Shared/UI/CoachDialog now (the unlock guides use the same box)
local CoachDialog = require(Shared.UI.CoachDialog)
local coachDialog = CoachDialog.new(root, Onboarding.FinishCoins or 0)
local dialog = coachDialog.frame
-- (prompt 28) the dialog and the GO TO button above the hotbar while it shows: on a phone the dialog sat on the shake slot
-- the shake step asks you to tap. (Prompt 53) Both at the bottom centre, above the hotbar / stamina bar
-- (CoachDialog.BottomClear), GO TO 12 px above the dialog when it shows, never over the character.
task.spawn(function()
	while gui.Parent do
		local clear = CoachDialog.BottomClear(root)
		dialog.Position = UDim2.new(0.5, 0, 1, -clear)
		local go = root:FindFirstChild("GoTo")
		local above = coachDialog.Height()
		if go then go.Position = UDim2.new(0.5, 0, 1, -(clear + (if above > 0 then above + CoachDialog.Gap else 0))) end
		task.wait(0.2)
	end
end)
-- on a machine the machine HUD owns the screen: no dialog (the band shows the step's line)
local function placeDialog()
	if onMachine and coachDialog.IsShowing() then coachDialog.Hide() end
end
local function showCoach(step)
	if step and not onMachine and step.coach then coachDialog.Show(step.coach) else coachDialog.Hide() end
end

------------------------------------------------------------------------
-- The glowing path + outline to the step's machine (Shared/UI/GuidePath; the Growth Spurt's Go buttons use it too)
------------------------------------------------------------------------
local GuidePath = require(Shared.UI.GuidePath)
local function showPath(machineId) GuidePath.Show(machineId, "Tutorial") end
local function hidePath() GuidePath.Hide("Tutorial") GuidePath.StopWalk() end
local markedTarget = nil -- (22 Oct) the target the gold marker + arrow are on

-- (prompt 11, 21 Oct) "GO TO FLAT BENCH" above the coach dialog, only while a step leads to a machine the player isn't on.
-- (22 Oct, owner) It TELEPORTS: a short fade to black, the server puts the player in front of the target facing it (off a
-- machine first; GoToService), the fade back in (GuidePath.Teleport); the gold marker + arrow are on the target.
-- (prompt 53) the gold ChunkyButton at its normal size (~30% of a phone screen), placed by the loop above
local goButton = Kit.Button("Gold", "Go to bench", { Name = "GoTo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Visible = false,
	Parent = root }, { width = 240, height = 38, textSize = 15 })
Theme.SetChrome(goButton) -- (owner, 23 Oct, chrome reset: clean italic dark words on metallic gold, no shine)
local walking = false -- (a teleport is running)
local arrivedAt = nil -- the target the last teleport put the player at (its GO TO button stays hidden)
goButton.Activated:Connect(function()
	local target = goButton:GetAttribute("Target")
	if walking or not target then return end
	walking = true
	Audio.PlayUI("Click")
	task.spawn(function()
		-- (there: the button steps aside, it sat over the machine and its Occupy prompt)
		if GuidePath.Teleport(target) then arrivedAt = target end
		walking = false
		if goButton.Parent then Kit.SetButton(goButton, "Gold", goButton:GetAttribute("Label") or "Go") end
		if arrivedAt == goButton:GetAttribute("Target") then goButton.Visible = false end
	end)
end)
local function targetName(target): string
	if target == "Coach" then return Quests.CoachName end
	local Machines = require(Shared.Config.Machines)
	local machine = Machines.ById[target]
	return if machine then machine.name else "it"
end
local function goLabel(target): string
	return "Go to " .. targetName(target)
end

------------------------------------------------------------------------
-- What the player is doing
------------------------------------------------------------------------
local statsOpenTime = 0 -- seconds Stats has been open during the current step
local statsSeenThisStep = false
local drankShake = false -- during the current step
local stepIndex = data.onboarding.tutorialStep
local stepReps = 0
local stepStarted = os.clock()

local advance -- forward declaration
local updateSpotlight -- (below)
local autoDrank = false -- the shake step's safety net already drank the shake for the player

local function stepDef()
	return Onboarding.Steps[stepIndex]
end

-- (prompt 53a) the Spotlight on the button the step needs (prompt 20's arrow over the shake, now for every button): on a
-- machine with a "Tap STOP, then..." line, STOP; the shake step, hotbar slot 1 (HotbarClient "Slot_Shake", once the free
-- shake has arrived); Open Stats / Open Muscles, that menu tile until it's open. Re-checked every half second (a button
-- can appear later), never while a window or the genetics screen is up.
local Spotlight = require(Shared.UI.Spotlight)
local SideMenu = require(Shared.UI.SideMenu)
local function spotlightTarget(step): (GuiObject?, string?)
	if not step or player:GetAttribute("WindowOpen") or UIBus.GeneticsUp then return nil, nil end
	if onMachine and step.onMachineText then
		local hud = playerGui:FindFirstChild("MachineHud")
		return hud and hud:FindFirstChild("Exit", true) :: GuiObject?, "Tap Stop"
	end
	if step.done.type == "shake" then
		local hotbar = playerGui:FindFirstChild("Hotbar")
		local slot = hotbar and hotbar:FindFirstChild("Slot_Shake", true)
		return slot and slot:FindFirstChild("Face") :: GuiObject?, "Tap it"
	end
	if step.done.type == "statsOpen" and not statsOpen then return SideMenu.Button("Stats"), "Tap Stats" end
	if step.done.type == "statsOpenFor" and not statsOpen then return SideMenu.Button("Muscles"), "Tap Muscles" end
	return nil, nil
end
function updateSpotlight()
	local object, word = nil, nil
	if stepIndex < Onboarding.Done then object, word = spotlightTarget(stepDef()) end
	if Spotlight.Pointed() ~= object then Spotlight.Point(object, word) end
end

local coachShownFor = nil
local function refreshStep()
	local step = stepDef()
	if not step then return end
	local text = (onMachine and step.onMachineText) or step.text
	setLine(text)
	if coachShownFor ~= stepIndex then
		coachShownFor = stepIndex
		showCoach(step)
	elseif coachDialog.IsShowing() then
		placeDialog()
	end
	if step.target and onMachine ~= step.target then
		if GuidePath.Target() ~= step.target then showPath(step.target) end
		local label = goLabel(step.target)
		goButton:SetAttribute("Target", step.target)
		if goButton:GetAttribute("Label") ~= label then
			goButton:SetAttribute("Label", label)
			if not walking then Kit.SetButton(goButton, "Gold", label) end
		end
		goButton.Visible = arrivedAt ~= step.target
		-- (22 Oct) the glowing gold marker + arrow on the target, the only machine sign shown (MachineSignsClient)
		if markedTarget ~= step.target then
			markedTarget = step.target
			GuidePath.Mark(step.target, nil, targetName(step.target))
		end
		if UIBus.TutorialTarget ~= step.target then
			UIBus.TutorialTarget = step.target
			UIBus.TutorialChanged:Fire()
		end
	else
		hidePath()
		goButton.Visible = false
		if markedTarget then
			markedTarget = nil
			GuidePath.Unmark()
		end
		if UIBus.TutorialTarget ~= nil then
			UIBus.TutorialTarget = nil
			UIBus.TutorialChanged:Fire()
		end
	end
	-- a button the step needs: the Spotlight on it
	updateSpotlight()
end

local function check()
	local step = stepDef()
	if not step then return end
	local done = step.done
	if done.type == "onMachine" then
		if onMachine == step.target then advance() end
	elseif done.type == "reps" then
		if stepReps >= done.count then advance() end
	elseif done.type == "staminaLow" then
		local max = player:GetAttribute("MaxStamina")
		if ClientData.Get().stamina / (type(max) == "number" and max or Stamina.Max) < done.below or stepReps >= done.count then advance() end
	elseif done.type == "statsOpen" then
		if statsOpen then advance() end
	elseif done.type == "statsOpenFor" then
		if statsOpenTime >= done.count then advance() end
	elseif done.type == "shake" then
		if drankShake then advance() end
	elseif done.type == "quest" then
		local quests = ClientData.Get().quests
		if quests and quests.active then advance() end
	elseif done.type == "seconds" then
		if os.clock() - stepStarted >= done.count then advance() end
	end
end

local function finish(skipped: boolean?)
	hidePath()
	markedTarget = nil
	GuidePath.Unmark()
	UIBus.TutorialTarget = nil
	UIBus.TutorialChanged:Fire()
	Spotlight.Point(nil)
	shownText = nil
	coachDialog.Hide()
	Notify.SetBand(nil)
	Notify.Reserve(0)
	if skipPill then skipPill.Destroy() skipPill = nil end
	gui:Destroy()
	if skipped then
		Notify.Toast("Tutorial skipped", "Quests and hints are in the menu", "list-checks", Colors.Blue)
	else
		Notify.Toast(Onboarding.FinishedText, Onboarding.FinishCoins and ("+" .. Onboarding.FinishCoins .. " coins") or nil, "coin", Colors.Gold)
	end
	Audio.PlayUI("Whoosh")
end

skipPill = require(Shared.UI.SkipPill).new("TutorialSkip", function()
	if stepIndex >= Onboarding.Done then return end
	stepIndex = Onboarding.Done
	Remotes.PlayerAction:FireServer("SkipTutorial")
	finish(true)
end)

function advance()
	stepIndex += 1
	if stepIndex > #Onboarding.Steps then stepIndex = Onboarding.Done end
	stepReps = 0
	stepStarted = os.clock()
	statsOpenTime = 0
	statsSeenThisStep = statsOpen
	drankShake = false
	autoDrank = false
	Remotes.PlayerAction:FireServer("TutorialStep", stepIndex)
	hidePath()
	if stepIndex >= Onboarding.Done then
		finish()
		return
	end
	Audio.PlayUI("Click")
	refreshStep()
	task.defer(check) -- e.g. already on the next target machine
end

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		onMachine = model:GetAttribute("MachineId")
	elseif state == "Exit" then
		onMachine = nil
	end
	if stepIndex < Onboarding.Done then
		refreshStep()
		check()
	end
end)

Remotes.RepResult.OnClientEvent:Connect(function(result)
	if stepIndex >= Onboarding.Done or type(result) ~= "table" or result.noStamina then return end
	local step = stepDef()
	if step and (not step.done.machine or step.done.machine == onMachine) then
		stepReps += 1
		check()
	end
end)

ClientData.Changed:Connect(function(path)
	if (path[1] == "stamina" or path[1] == "quests") and stepIndex < Onboarding.Done then check() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind)
	if kind == "ShakeDrunk" and stepIndex < Onboarding.Done then
		drankShake = true
		check()
	end
end)

-- "stats open" = the stat labels around you (the Stats tile) or the Muscles window
local labelsShown, musclesShown = false, false
local function onStatsVisible()
	local visible = labelsShown or musclesShown
	statsOpen = visible
	if stepIndex >= Onboarding.Done then return end
	placeLine()
	task.delay(0.1, placeLine) -- again once the goal panel has its measured size
	local step = stepDef()
	if visible then statsSeenThisStep = true end
	updateSpotlight()
	-- closing Stats after a look also finishes a "statsOpenFor" step
	if not visible and step and step.done.type == "statsOpenFor" and statsSeenThisStep and statsOpenTime > 1 then
		advance()
	else
		check()
	end
end
UIBus.StatsVisible.Event:Connect(function(visible) labelsShown = visible onStatsVisible() end)
UIBus.MusclesVisible.Event:Connect(function(visible) musclesShown = visible onStatsVisible() end)

-- The skip pill and the coach dialog step aside while the genetics screen or a menu window is open.
local geneticsShown = false
function applySkip()
	if skipPill then skipPill.SetShown(skipReady and stepIndex < Onboarding.Done and gui.Parent ~= nil and gui.Enabled) end
end
local function applyHidden()
	if stepIndex < Onboarding.Done and gui.Parent then
		gui.Enabled = not geneticsShown and not player:GetAttribute("WindowOpen")
	end
	applySkip()
end
UIBus.GeneticsVisible.Event:Connect(function(visible)
	geneticsShown = visible == true
	applyHidden()
end)
player:GetAttributeChangedSignal("WindowOpen"):Connect(applyHidden)
applyHidden() -- (a window can already be open when the tutorial starts: the Daily Reward after Play)

-- Timed steps
task.spawn(function()
	while stepIndex < Onboarding.Done do
		local dt = task.wait(0.5)
		local step = stepDef()
		if statsOpen then statsOpenTime += dt end
		updateSpotlight()
		if step and (step.done.type == "seconds" or step.done.type == "statsOpenFor") then check() end
		-- the safety net (prompt 20): a step with a `timeout` never holds the player. The shake step drinks the free shake for
		-- them (the server checks they have one) and moves on when it lands, or a few seconds later anyway.
		step = stepDef()
		if step and step.timeout and stepIndex < Onboarding.Done then
			local waited = os.clock() - stepStarted
			if step.done.type == "shake" then
				if waited >= step.timeout and not autoDrank then
					autoDrank = true
					local items = ClientData.Get().items
					if items and (tonumber(items.Shake) or 0) > 0 then Remotes.PlayerAction:FireServer("DrinkShake") end
				elseif autoDrank and waited >= step.timeout + 3 then
					advance()
				end
			elseif waited >= step.timeout then
				advance()
			end
		end
	end
end)

player.CharacterAdded:Connect(function()
	onMachine = nil
	if stepIndex < Onboarding.Done then
		hidePath()
		task.wait(1)
		refreshStep()
	end
end)

refreshStep()
check()
