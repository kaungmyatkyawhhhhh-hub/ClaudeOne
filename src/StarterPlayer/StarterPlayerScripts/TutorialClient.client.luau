-- TutorialClient: the first 5 minutes, after the menu and the genetics reveal. Steps come from Config.Onboarding.
-- Owner's UI v2 (mockup 11): each step's short line goes to the top band (Notify.SetBand), a green SKIP TUTORIAL sits
-- under it (tap twice: the first tap asks "Tap again to skip"), and the step's coach pages show in a dialog at the bottom
-- (a live portrait of the Coach NPC, "Coach Dex · Reward (coin) 50", the words, "Tap to continue (1/3)"). On a machine
-- there is no dialog, so it never covers the machine HUD (the band has the step's line). Steps that lead to a machine
-- draw a glowing path of dots on the floor (Shared/UI/GuidePath: Roblox pathfinding, so it walks around equipment) and
-- outline the machine.
-- Progress is saved through the server, so a player who leaves mid-tutorial picks up where they were.
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
local Pieces = require(Shared.UI.Pieces)
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
-- (22 Oct, owner) a small dark SKIP pill top-right, under the top bar and left of the right column's cards (was a big green
-- SKIP TUTORIAL bar under the band). Tap twice: the first tap asks "Sure?".
local RightColumn = require(Shared.UI.RightColumn)
local skip = Kit.Button("Quiet", "Skip", { Name = "Skip", AnchorPoint = Vector2.new(1, 0), Parent = root }, { width = 92, height = 40, textSize = 14 })
skip.Position = UDim2.new(1, -(RightColumn.Width + 60), 0, 56) -- (clear of the column's collapse arrow)
Kit.OnTopbar(function() skip.Position = UDim2.new(1, -(RightColumn.Width + 60), 0, Kit.UnderTopbar(root)) end)
local skipArmed = 0
-- (owner, 21 Oct) SKIP TUTORIAL only after the player has been in the game for SkipAfter seconds: counted from when the
-- menu is gone and the genetics screen has closed, so a new player sees the first step before the way out
local SkipAfter = 5
skip.Visible = false
task.spawn(function()
	UIBus.WaitForMenu()
	task.wait(1.5) -- (the genetics screen opens a moment after Play)
	while UIBus.GeneticsUp do
		UIBus.GeneticsVisible.Event:Wait()
	end
	task.wait(SkipAfter)
	if skip.Parent then skip.Visible = true end
end)

local dialog = Theme.Panel({ Name = "CoachDialog", Clickable = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(540, 92), Visible = false, Parent = root }, {})
-- (prompt 28) the dialog and the GO TO button above the hotbar while it shows (HotbarClient: 10 px gap + a 54 px slot): on
-- a phone the dialog sat on the shake slot the shake step asks you to tap
task.spawn(function()
	local lifted = nil
	while true do
		local hotbar = playerGui:FindFirstChild("Hotbar")
		local want = hotbar ~= nil and hotbar.Enabled
		local go = root:FindFirstChild("GoTo")
		if want ~= lifted and go then
			lifted = want
			local lift = if want then 64 else 0
			dialog.Position = UDim2.new(0.5, 0, 1, -(10 + lift))
			go.Position = UDim2.new(0.5, 0, 1, -(112 + lift))
		end
		task.wait(0.3)
	end
end)
local portrait = New("ViewportFrame", { Name = "Portrait", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = Colors.Blue, Ambient = Color3.fromRGB(190, 190, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -0.6, -1),
	Parent = dialog }, {
	New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }),
})
local nameRow = New("Frame", { Name = "NameRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(94, 7), Size = UDim2.new(1, -104, 0, 22), Parent = dialog }, {
	Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
Kit.Text({ LayoutOrder = 1, Text = Quests.CoachName .. " · Reward", Font = "Title", TextSize = 17, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X, Parent = nameRow })
Kit.Coin(17, { LayoutOrder = 2, Parent = nameRow })
Kit.Text({ LayoutOrder = 3, Text = tostring(Onboarding.FinishCoins or 0), Font = "Title", TextSize = 17, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X, Parent = nameRow })
local dialogText = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(94, 30), Size = UDim2.new(1, -106, 0, 38),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = dialog })
local dialogFoot = Kit.Text({ Name = "Continue", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(94, 70), Size = UDim2.new(1, -106, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = dialog })

-- the Coach's face: a copy of the Coach NPC in the portrait (no scripts, prompts or labels)
task.spawn(function()
	local coach = CollectionService:GetTagged("Coach")[1]
	local waited = 0
	while not coach and waited < 15 do
		task.wait(0.5)
		waited += 0.5
		coach = CollectionService:GetTagged("Coach")[1]
	end
	-- (owner, 15 Oct: Dex's body is rebuilt by the server after he loads; copy him once his face head and his muscle
	-- meshes are there, so the portrait shows the new Dex, not the plain body)
	waited = 0
	while coach and (not coach:FindFirstChild("ClassicHead") or not coach:FindFirstChild("MuscleMeshes")) and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	if coach then task.wait(1) end
	local head = coach and coach:FindFirstChild("Head")
	if not head then
		Pieces.Image("trainer_exp", { Size = UDim2.fromScale(1, 1), Parent = portrait })
		return
	end
	local ok = pcall(function()
		coach.Archivable = true
		for _, d in ipairs(coach:GetDescendants()) do d.Archivable = true end
		local copy = coach:Clone()
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") then d:Destroy() end
		end
		local world = New("WorldModel", { Parent = portrait })
		copy.Parent = world
		local copyHead = copy:FindFirstChild("Head") :: BasePart
		local camera = New("Camera", { FieldOfView = 30, Parent = portrait })
		local face = copyHead.CFrame
		-- head and his huge shoulders (owner, 15 Oct: the new Dex is far wider, so the camera sits further back)
		camera.CFrame = CFrame.lookAt(face.Position + face.LookVector * 9 + Vector3.new(0, 0.6, 0), face.Position - Vector3.new(0, 0.9, 0))
		portrait.CurrentCamera = camera
	end)
	if not ok then Pieces.Image("trainer_exp", { Size = UDim2.fromScale(1, 1), Parent = portrait }) end
end)

local pages, pageIndex = nil, 0
local showPage -- (below)
local function placeDialog()
	-- on a machine the machine HUD owns the screen: no dialog (the band shows the step's line)
	if onMachine and pages then
		pages = nil
		showPage()
	end
end
function showPage()
	if not pages or pageIndex > #pages then
		if dialog.Visible then
			local tween = Theme.Fade(dialog, false, 0.2)
			if tween then tween.Completed:Connect(function() if not pages then dialog.Visible = false end end) else dialog.Visible = false end
		end
		pages = nil
		return
	end
	dialogText.Text = pages[pageIndex]
	dialogFoot.Text = string.format("Tap to continue (%d/%d)", pageIndex, #pages)
	if not dialog.Visible then
		dialog.Visible = true
		Theme.Fade(dialog, true, 0.2)
	end
end
local function showCoach(step)
	pages = (step and not onMachine) and step.coach or nil
	pageIndex = 1
	showPage()
end
dialog.Activated:Connect(function()
	if not pages then return end
	Audio.PlayUI("Click")
	pageIndex += 1
	showPage()
end)

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
-- (the owner asked for prompt 37's gold ChunkyButton style: that kit isn't built yet, so it's the kit's gold button)
local goButton = Kit.Button("Gold", "Go to bench", { Name = "GoTo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Visible = false,
	Parent = root }, { width = 220, height = 46, textSize = 16 })
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
local function goLabel(target): string
	if target == "Coach" then return "Go to " .. Quests.CoachName end
	local Machines = require(Shared.Config.Machines)
	local machine = Machines.ById[target]
	return "Go to " .. (if machine then machine.name else "it")
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
local pointAtShake, hideShakeArrow -- (below)
local autoDrank = false -- the shake step's safety net already drank the shake for the player

local function stepDef()
	return Onboarding.Steps[stepIndex]
end

-- (prompt 20, 21 Oct) A gold arrow over the shake, bouncing, pointing down at it. Prompt 28: the shake is hotbar slot 1
-- (HotbarClient "Slot_Shake"; the DRINK SHAKE button is gone). It lives inside the slot, so it shows exactly when the slot
-- does (once the free shake has arrived).
local shakeArrow = nil
function hideShakeArrow()
	if shakeArrow then shakeArrow:Destroy() shakeArrow = nil end
end
function pointAtShake()
	if shakeArrow and shakeArrow.Parent then return end
	local hotbar = playerGui:FindFirstChild("Hotbar")
	local slot = hotbar and hotbar:FindFirstChild("Slot_Shake", true)
	local button = slot and slot:FindFirstChild("Face")
	if not button then
		task.delay(0.5, function()
			local step = stepDef()
			if step and step.done.type == "shake" then pointAtShake() end
		end)
		return
	end
	-- (in a Folder, so the button's list layout leaves it alone: it floats above the button)
	local holder = button:FindFirstChild("TutorialArrowHolder") or New("Folder", { Name = "TutorialArrowHolder", Parent = button })
	shakeArrow = New("Frame", { Name = "TutorialArrow", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1, ZIndex = 20, Parent = holder })
	local icon = Pieces.Icon("arrow-big-up", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		Rotation = 180, ZIndex = 20, Parent = shakeArrow })
	icon:SetAttribute("KeepColor", true)
	local token = shakeArrow
	task.spawn(function()
		while shakeArrow == token and token.Parent do
			Theme.Tween(token, { Position = UDim2.new(0.5, 0, 0, -14) }, 0.35, Enum.EasingStyle.Sine)
			task.wait(0.35)
			if shakeArrow ~= token then break end
			Theme.Tween(token, { Position = UDim2.new(0.5, 0, 0, -4) }, 0.35, Enum.EasingStyle.Sine)
			task.wait(0.35)
		end
	end)
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
	elseif pages then
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
			GuidePath.Mark(step.target)
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
	-- the shake step: a bouncing arrow on hotbar slot 1 (the shake), on a machine or not
	if step.done.type == "shake" then pointAtShake() else hideShakeArrow() end
	-- point at the Stats button (a dot on it until stats is opened)
	if step.done.type == "statsOpen" then
		local hud = playerGui:FindFirstChild("MainHud")
		local button = hud and hud:FindFirstChild("Stats", true)
		local dot = button and button:FindFirstChild("Dot")
		if dot then dot.Visible = true end
	end
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
	hideShakeArrow()
	shownText = nil
	pages = nil
	Notify.SetBand(nil)
	Notify.Reserve(0)
	gui:Destroy()
	if skipped then
		Notify.Toast("Tutorial skipped", "Quests and hints are in the menu", "list-checks", Colors.Blue)
	else
		Notify.Toast(Onboarding.FinishedText, Onboarding.FinishCoins and ("+" .. Onboarding.FinishCoins .. " coins") or nil, "coin", Colors.Gold)
	end
	Audio.PlayUI("Whoosh")
end

skip.Activated:Connect(function()
	if os.clock() - skipArmed > 3 then
		-- the first tap only asks (a stray tap never wipes the tutorial)
		skipArmed = os.clock()
		Kit.SetButton(skip, "Gold", "Sure?")
		task.delay(3, function()
			if skip.Parent and os.clock() - skipArmed >= 3 then Kit.SetButton(skip, "Quiet", "Skip") end
		end)
		return
	end
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
	-- closing Stats after a look also finishes a "statsOpenFor" step
	if not visible and step and step.done.type == "statsOpenFor" and statsSeenThisStep and statsOpenTime > 1 then
		advance()
	else
		check()
	end
end
UIBus.StatsVisible.Event:Connect(function(visible) labelsShown = visible onStatsVisible() end)
UIBus.MusclesVisible.Event:Connect(function(visible) musclesShown = visible onStatsVisible() end)

-- The skip button and the coach dialog step aside while the genetics screen or a menu window is open.
local geneticsShown = false
local function applyHidden()
	if stepIndex < Onboarding.Done and gui.Parent then
		gui.Enabled = not geneticsShown and not player:GetAttribute("WindowOpen")
	end
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
