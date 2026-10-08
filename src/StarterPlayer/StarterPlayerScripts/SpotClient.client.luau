-- SpotClient: spotting on the client (owner's redo, 8 Oct night; the server side is SpotService, numbers in
-- Config.Spotting).
--  * Tap / click a lifter's body (another player on a spottable machine): a small popup "SPOT" / X next to them.
--  * As the lifter: a small corner card "<name> wants to spot you" with ACCEPT / X and a draining bar; it closes on its
--    own after the timeout. "Spot requests: Off" in Settings stops them reaching you (the server checks it).
--  * As a spotter: a compact bottom panel with the lifter's name, a chunky segmented meter and EXIT; a click or tap ANYWHERE
--    is a push (owner: no push button; F on a keyboard too). The meter shows your pushes a second (white = clicking).
--    Moving or jumping also stops spotting.
--  * As the lifter while spotted: "SPOTTED x1.35" (gold) and the spotters' names, a small label beside you in the world,
--    next to where the EXP popups fly.
--  * Every client poses every spotter (character attributes SpotLifter / SpotType / SpotSlot from the server): "hands"
--    spotters reach for the lifter's bar (their hands under it, following it each rep); "hype" spotters clap, point and
--    fist pump in turns. Joints are written after the Animator, like PoseController.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Spotting = require(Shared.Config.Spotting)
local Machines = require(Shared.Config.Machines)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Remotes:WaitForChild("Spot", 30)
if not remote then return end -- (the spotting service didn't start)

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local gui = Theme.ScreenGui({ Name = "Spotting", DisplayOrder = 8, Parent = player:WaitForChild("PlayerGui") })

local function machineOfUser(userId: number)
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == userId then return model end
	end
	return nil
end
local function amLifting(): boolean
	return machineOfUser(player.UserId) ~= nil
end
local spottingNow = false

------------------------------------------------------------------------
-- 1. Tap a lifter: the SPOT popup
------------------------------------------------------------------------
local popup = Theme.Panel({ Name = "SpotPopup", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY, Visible = false, Parent = gui }, {
	Theme.Pad("S"), Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local popupName = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, Theme.MinTouch), Parent = popup })
local spotButton = Theme.Button("Primary", { LayoutOrder = 2, Size = UDim2.fromOffset(96, Theme.MinTouch), Parent = popup }, {
	Theme.Text({ Text = "Spot", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local popupClose = Theme.Button("Secondary", { LayoutOrder = 3, Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = popup }, {
	Theme.Text({ Text = "X", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local popupTarget = nil -- { player, shownAt }

local function hidePopup()
	popup.Visible = false
	popupTarget = nil
end
popupClose.Activated:Connect(hidePopup)
spotButton.Activated:Connect(function()
	if popupTarget then remote:FireServer("Request", popupTarget.player.UserId) end
	Audio.PlayUI("Click")
	hidePopup()
end)

-- the player whose character a screen point is on, if they lift on a spottable machine
local function lifterAt(screen: Vector2): (Player?, Vector3?)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 120, params)
	local part = hit and hit.Instance
	local character = part and part:FindFirstAncestorOfClass("Model")
	while character and not character:FindFirstChildOfClass("Humanoid") do
		character = character:FindFirstAncestorOfClass("Model")
	end
	local other = character and Players:GetPlayerFromCharacter(character)
	if not other or other == player then return nil end
	local model = machineOfUser(other.UserId)
	local machine = model and Machines.ById[model:GetAttribute("MachineId")]
	if not (machine and machine.spotType) then return nil end
	return other, hit.Position
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if spottingNow or amLifting() or UIBus.MenuOpen then return end
	local screen = Vector2.new(input.Position.X, input.Position.Y)
	local other, at = lifterAt(screen)
	if not other then return end
	local camera = workspace.CurrentCamera
	local point = camera:WorldToViewportPoint((at :: Vector3) + Vector3.new(0, 1.5, 0))
	local size = camera.ViewportSize
	popupName.Text = other.DisplayName
	popup.Position = UDim2.fromOffset(math.clamp(point.X, 140, size.X - 140), math.clamp(point.Y, 120, size.Y - 20))
	popup.Visible = true
	popupTarget = { player = other, shownAt = os.clock() }
end)

------------------------------------------------------------------------
-- 2. The lifter's request cards (top left: while lifting the top bar is hidden and the right side has the body map)
------------------------------------------------------------------------
local cards = New("Frame", { Name = "Requests", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, Spacing.L, 0, 64),
	Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui },
	{ Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local openCards = {} -- [userId] = card

local function closeCard(userId: number)
	local card = openCards[userId]
	if card then
		openCards[userId] = nil
		card:Destroy()
	end
end

local function requestCard(info)
	local userId, name, timeout = info.userId, tostring(info.name or ""), tonumber(info.timeout) or Spotting.RequestTimeout
	if type(userId) ~= "number" then return end
	closeCard(userId)
	local card = Theme.Panel({ Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cards }, {
		Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	openCards[userId] = card
	Theme.Text({ LayoutOrder = 1, Text = name .. " wants to spot you", Font = "Regular", TextSize = "Body", TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	local row = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = card },
		{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local accept = Theme.Button("Primary", { LayoutOrder = 1, Size = UDim2.new(1, -(Theme.MinTouch + Spacing.S), 1, 0), Parent = row }, {
		Theme.Text({ Text = "Accept", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	local decline = Theme.Button("Secondary", { LayoutOrder = 2, Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = row }, {
		Theme.Text({ Text = "X", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	-- the time left: a thin draining bar
	local track = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Colors.Chalk, BackgroundTransparency = 0.85, Parent = card },
		{ New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Chalk, BackgroundTransparency = 0.2, Parent = track },
		{ New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
	Theme.Tween(fill, { Size = UDim2.fromScale(0, 1) }, timeout, Enum.EasingStyle.Linear)
	accept.Activated:Connect(function()
		remote:FireServer("Respond", userId, true)
		closeCard(userId)
	end)
	decline.Activated:Connect(function()
		remote:FireServer("Respond", userId, false)
		closeCard(userId)
	end)
	task.delay(timeout, function() if openCards[userId] == card then closeCard(userId) end end)
	Audio.PlayUI("Click")
end

------------------------------------------------------------------------
-- 3. The spotter's panel (bottom centre): PUSH, the meter, EXIT
------------------------------------------------------------------------
local SEGMENTS = 10
local panel = Theme.Panel({ Name = "Spotter", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -Spacing.XL),
	Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = gui }, {
	Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
local spotTitle = Theme.Text({ LayoutOrder = 1, Text = "", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = panel })
local meter = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local segments = {}
for i = 1, SEGMENTS do
	segments[i] = New("Frame", { LayoutOrder = i, Size = UDim2.new(1 / SEGMENTS, -Spacing.XS, 1, 0), BackgroundColor3 = Colors.Chalk,
		BackgroundTransparency = 0.85, Parent = meter }, { New("UICorner", { CornerRadius = Theme.Corner.Segment }) })
end
local spotStatus = Theme.Text({ LayoutOrder = 3, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted,
	Size = UDim2.new(1, 0, 0, 18), Parent = panel })
local exitButton = Theme.Button("Secondary", { LayoutOrder = 4, Size = UDim2.fromOffset(120, Theme.MinTouch), Parent = panel }, {
	Theme.Text({ Text = "Exit", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

-- PUSH = a click / tap ANYWHERE on the screen (owner, 9 Oct: no push button), or F / R2; taps on buttons (EXIT) don't count
local myTaps = {}
local serverClicking, boostShown = false, 1
local function push()
	if not spottingNow then return end
	table.insert(myTaps, os.clock())
	remote:FireServer("Push")
end
exitButton.Activated:Connect(function() remote:FireServer("Exit") end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not spottingNow then return end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		push()
	end
end)
local PUSH_HINT = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap anywhere fast to push" else "Click anywhere fast to push"

local function setSpotting(on: boolean, info)
	spottingNow = on
	panel.Visible = on
	table.clear(myTaps)
	serverClicking = false
	if on then
		hidePopup()
		spotTitle.Text = string.upper("Spotting " .. tostring(info.lifter or ""))
		spotStatus.Text = PUSH_HINT .. " and boost their gains"
	end
end

-- moving or jumping stops spotting (the root is held in place, so only the input shows it)
RunService.Heartbeat:Connect(function()
	if not spottingNow then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and (humanoid.MoveDirection.Magnitude > 0.5 or humanoid.Jump) then
		spottingNow = false
		remote:FireServer("Exit")
	end
	-- the meter: your taps per second over the last second, full at twice the clicking rate
	local now = os.clock()
	while myTaps[1] and now - myTaps[1] > Spotting.ClickWindow do table.remove(myTaps, 1) end
	local lit = math.clamp(math.floor(#myTaps / (Spotting.ClickRate * 2) * SEGMENTS + 0.5), 0, SEGMENTS)
	for i, segment in ipairs(segments) do
		segment.BackgroundTransparency = if i <= lit then (if serverClicking then 0 else 0.45) else 0.85
	end
end)

------------------------------------------------------------------------
-- 4. The lifter's SPOTTED label (beside you, by the EXP popups)
------------------------------------------------------------------------
local spottedGui = New("BillboardGui", { Name = "SpottedLabel", Size = UDim2.fromOffset(220, 56), StudsOffset = Vector3.new(-3.6, 2.2, 0), AlwaysOnTop = true,
	LightInfluence = 0, MaxDistance = 80, ResetOnSpawn = false, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local spottedBig = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Large", TextColor3 = Colors.Gold, Upper = false,
	Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Right, Parent = spottedGui })
Theme.TextShadow(spottedBig)
local spottedNames = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = spottedGui })
Theme.TextShadow(spottedNames)

local function showSpotted(info)
	local count = tonumber(info.count) or 0
	if count <= 0 then
		spottedGui.Enabled = false
		return
	end
	local character = player.Character
	spottedGui.Adornee = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
	spottedBig.Text = string.format("SPOTTED x%.2f", math.floor((tonumber(info.boost) or 1) * 100 + 0.5) / 100)
	local list = type(info.names) == "table" and info.names or {}
	spottedNames.Text = table.concat(list, ", ")
	spottedGui.Enabled = spottedGui.Adornee ~= nil
end

------------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------------
local REFUSED = {
	Full = "Spot full",
	Declined = "%s said no",
	NoAnswer = "%s didn't answer",
	RequestsOff = "%s isn't taking spot requests",
	TooFar = "Get closer to spot",
	Busy = "You can't spot right now",
	NotSpottable = "This machine can't be spotted",
	Unavailable = "They're not lifting anymore",
}
local ENDED = {
	LifterLeft = "Set's over: spotting ended",
	Moved = "You moved: spotting ended",
	Exit = "Spotting ended",
}

remote.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "Request" then
		requestCard(info)
	elseif kind == "RequestClosed" then
		if type(info.userId) == "number" then closeCard(info.userId) end
	elseif kind == "Asked" then
		Notify.Show("Asked " .. tostring(info.name) .. " to let you spot", nil, "spot")
	elseif kind == "Refused" then
		local text = REFUSED[info.reason] or "Can't spot right now"
		Notify.Show(string.format(text, tostring(info.name or "")), nil, "spot")
	elseif kind == "Started" then
		setSpotting(true, info)
		Notify.Show("Spotting " .. tostring(info.lifter), nil, "spot")
		Audio.PlayUI("Click")
	elseif kind == "State" then
		serverClicking = info.clicking == true
		boostShown = tonumber(info.boost) or 1
		if spottingNow then
			spotStatus.Text = if serverClicking then string.format("Pushing hard: their gains x%.2f", boostShown)
				else string.format("Their gains x%.2f. %s for more", boostShown, PUSH_HINT)
		end
	elseif kind == "Ended" then
		if spottingNow or panel.Visible then setSpotting(false, info) end
		Notify.Show(ENDED[info.reason] or "Spotting ended", nil, "spot")
	elseif kind == "Spotted" then
		showSpotted(info)
	elseif kind == "Reward" then
		Notify.Show("+" .. tostring(info.coins) .. " coins for spotting", nil, "spotreward")
	end
end)

------------------------------------------------------------------------
-- 5. Spotter poses (every client, every spotter)
------------------------------------------------------------------------
local ARM = {
	R = { shoulder = { "RightUpperArm", "RightShoulder" }, elbow = { "RightLowerArm", "RightElbow" }, side = 1 },
	L = { shoulder = { "LeftUpperArm", "LeftShoulder" }, elbow = { "LeftLowerArm", "LeftElbow" }, side = -1 },
}
local DOWN = Vector3.new(0, -1, 0)
local posed = {} -- [character] = { motors }

local function motor(character, spec)
	local part = character:FindFirstChild(spec[1])
	local joint = part and part:FindFirstChild(spec[2])
	return joint
end

-- the arm (upper arm from the shoulder) pointed along `dir` (UpperTorso space), elbow bent by `bend` degrees
local function aim(character, key: string, dir: Vector3, bend: number)
	local arm = ARM[key]
	local shoulder, elbow = motor(character, arm.shoulder), motor(character, arm.elbow)
	if not (shoulder and elbow) or dir.Magnitude < 1e-3 then return end
	shoulder.Transform = CFrame.fromRotationBetweenVectors(DOWN, dir.Unit)
	elbow.Transform = CFrame.Angles(math.rad(bend), 0, 0)
	posed[character] = posed[character] or {}
	posed[character][shoulder] = true
	posed[character][elbow] = true
end

local function rest(character)
	local list = posed[character]
	if not list then return end
	for joint in pairs(list) do
		if joint.Parent then joint.Transform = CFrame.identity end
	end
	posed[character] = nil
end

-- hands under the lifter's bar (the bar part moves with the rep on every client), closest point along the bar
local function handsPose(character, torso: BasePart, model: Model)
	local bar = model:FindFirstChild("Bar", true)
	local target
	if bar and bar:IsA("BasePart") then
		local axis = bar.CFrame.XVector
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local along = root and math.clamp((root.Position - bar.Position):Dot(axis), -bar.Size.X / 2 + 0.3, bar.Size.X / 2 - 0.3) or 0
		target = bar.Position + axis * along - Vector3.new(0, 0.25, 0)
		-- each hand a little to its own side along the bar
		local toRight = if torso.CFrame.RightVector:Dot(axis) >= 0 then axis else -axis
		for _, key in ipairs({ "R", "L" }) do
			local upper = character:FindFirstChild(ARM[key].shoulder[1])
			if not (upper and upper:IsA("BasePart")) then continue end
			local origin = upper.Position + upper.CFrame.UpVector * (upper.Size.Y / 2) -- (the shoulder end of the upper arm)
			local hand = target + toRight * (if key == "R" then 0.35 else -0.35)
			aim(character, key, torso.CFrame:VectorToObjectSpace(hand - origin), 18)
		end
	else
		-- (no bar: hands up and ready in front)
		aim(character, "R", Vector3.new(0.15, 0.3, -1), 25)
		aim(character, "L", Vector3.new(-0.15, 0.3, -1), 25)
	end
end

-- hype: clap, point, fist pump in turns (each spotter on their own clock)
local function hypePose(character, slot: string)
	local seed = (tonumber(string.match(slot or "", "%d+")) or 1) * 1.7
	local t = os.clock() + seed
	local move = math.floor(t / 2.4) % 3
	if move == 0 then -- clap: hands come together in front, fast
		local open = math.abs(math.sin(t * 7))
		aim(character, "R", Vector3.new(-0.05 + 0.4 * open, 0.15, -1), 35)
		aim(character, "L", Vector3.new(0.05 - 0.4 * open, 0.15, -1), 35)
	elseif move == 1 then -- point at the lifter, the other hand on the hip
		local beat = math.sin(t * 6) * 0.08
		aim(character, "R", Vector3.new(0.12, 0.45 + beat, -1), 0)
		aim(character, "L", Vector3.new(-0.35, -1, 0.1), 70)
	else -- fist pump: the right arm up, pumping
		local pump = (math.sin(t * 9) + 1) / 2
		aim(character, "R", Vector3.new(0.25, 1, -0.15), 30 + pump * 70)
		aim(character, "L", Vector3.new(-0.25, -1, -0.1), 15)
	end
end

RunService.PreSimulation:Connect(function()
	for character in pairs(posed) do
		if not character.Parent or not character:GetAttribute("SpotType") then rest(character) end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local kind = character and character:GetAttribute("SpotType")
		if kind then
			local torso = character:FindFirstChild("UpperTorso")
			local lifter = character:GetAttribute("SpotLifter")
			local model = type(lifter) == "number" and machineOfUser(lifter)
			if torso and torso:IsA("BasePart") then
				if kind == "hands" and model then
					handsPose(character, torso, model)
				else
					hypePose(character, character:GetAttribute("SpotSlot"))
				end
			end
		end
	end
end)
