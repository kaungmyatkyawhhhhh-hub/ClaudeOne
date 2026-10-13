-- PosingCompClient: the posing competition on every screen (PosingCompService runs it; Config.PosingComp has the numbers).
--   * Countdown: a small banner under the top bar ("Posing competition · starts in 0:42 · go to the stage") and a waypoint:
--     a marker over the stage (with the distance) and an arrow at the screen edge while the stage is off screen.
--   * Contestants (owner's UI v2, mockup 12): the pose's name big in gold, the Judges panel, and a TIMING bar over a big
--     red POSE! button: tap when the marker reaches the green (Space / gamepad A work too), then hold still until the
--     judges' cards go up.
--   * Watchers near the stage: during the last pose a small vote panel (tap a contestant's name; never yourself).
--   * Results: the podium names, your place and coins.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PosingComp = require(Shared.Config.PosingComp)
local Town = require(Shared.Config.Town)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local RightColumn = require(Shared.UI.RightColumn)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("PosingComp", 60) :: RemoteEvent
if not remote then return end -- the posing competition service didn't start

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors
local New = Theme.New
local Vertical = Enum.FillDirection.Vertical

local STAGE = Town.Stage.Center + Vector3.new(0, Town.Stage.Size.Y + 0.2, 0)

local function now() return Workspace:GetServerTimeNow() end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

local function onStage(): boolean
	local root = myRoot()
	if not root then return false end
	local half = Town.Stage.Size / 2 + Vector3.new(PosingComp.StageMargin, 0, PosingComp.StageMargin)
	local offset = root.Position - Town.Stage.Center
	return math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and root.Position.Y > STAGE.Y - 1 and root.Position.Y < STAGE.Y + 9
end

local function nearStage(): boolean
	local root = myRoot()
	return root ~= nil and (root.Position - STAGE).Magnitude <= PosingComp.VoteRange
end

local gui = Theme.ScreenGui({ Name = "PosingComp", DisplayOrder = 22, Parent = playerGui })

-- the genetics screen covers everything: this UI waits behind it
local geneticsUp = false
UIBus.GeneticsVisible.Event:Connect(function(visible) geneticsUp = visible == true end)

------------------------------------------------------------------------
-- Contestant camera: the crowd's view of the stage while you compete (front on, so you see your own poses)
------------------------------------------------------------------------
local STAGE_SHOT = { From = Vector3.new(0, 6, -20), At = Vector3.new(0, 4.6, 0), Fov = 55 }
local savedCamera = nil -- { type, fov } while the stage shot is on
local function stageCamera(on: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if on and not savedCamera then
		savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
		camera.CameraType = Enum.CameraType.Scriptable
		local goal = CFrame.lookAt(STAGE + STAGE_SHOT.From, STAGE + STAGE_SHOT.At)
		Theme.Tween(camera, { CFrame = goal, FieldOfView = STAGE_SHOT.Fov }, 0.6)
	elseif not on and savedCamera then
		camera.CameraType = savedCamera.type
		camera.FieldOfView = savedCamera.fov
		savedCamera = nil
	end
end

------------------------------------------------------------------------
-- Countdown banner (top of the right column, like the rush hour pill: never over the Growth Spurt bar or the tutorial)
------------------------------------------------------------------------
local banner = Theme.Panel({
	Name = "PosingBanner",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
}, {
	Theme.Pad("S"),
	Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
RightColumn.Add(banner, 0)
local bannerTitle = Theme.Text({ LayoutOrder = 1, Text = "Posing competition", Font = "SemiBold", TextSize = "Small", Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = banner })
Theme.Uppercase(bannerTitle)
local bannerLine = Theme.Text({ LayoutOrder = 2, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = banner })

-- (the banner lives in the right column, outside this script's gui: it's hidden by hand on the menu / genetics screen)
local bannerWanted, bannerShown, bannerToken = false, false, 0
local function applyBanner(hidden: boolean)
	local on = bannerWanted and not hidden
	if on == bannerShown then return end
	bannerShown = on
	bannerToken += 1
	local token = bannerToken
	if on then
		banner.Visible = true
		Theme.Fade(banner, true)
	elseif hidden then
		banner.Visible = false
	else
		local tween = Theme.Fade(banner, false)
		if tween then
			tween.Completed:Connect(function() if token == bannerToken then banner.Visible = false end end)
		else
			banner.Visible = false
		end
	end
end
local function showBanner(on: boolean)
	bannerWanted = on
end

------------------------------------------------------------------------
-- Waypoint: a marker over the stage and an arrow at the screen edge
------------------------------------------------------------------------
local marker = New("BillboardGui", {
	Name = "PosingStageMarker",
	Size = UDim2.fromOffset(150, 64),
	StudsOffsetWorldSpace = Vector3.new(0, 15, 0),
	AlwaysOnTop = true,
	LightInfluence = 0,
	Enabled = false,
	ResetOnSpawn = false,
	Parent = playerGui,
})
local markerAnchor = New("Part", {
	Name = "PosingStageMarkerAnchor", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(STAGE),
})
marker.Adornee = markerAnchor
local markerText = Theme.Text({ Text = "Posing stage", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = marker })
Theme.Uppercase(markerText)
Theme.TextShadow(markerText, 0.2)
local markerDistance = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 22), Parent = marker })
Theme.TextShadow(markerDistance, 0.2)
local markerArrow = New("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), BackgroundTransparency = 1, Rotation = 90, Parent = marker })
Icons.Chevron(1, Colors.Text).Parent = markerArrow

local edgeArrow = New("Frame", {
	Name = "EdgeArrow", Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = Theme.Alpha.Panel, Visible = false, Parent = gui,
}, { Theme.Round("Round"), Theme.Stroke() })
local edgeChevron = New("Frame", { Size = UDim2.fromScale(0.6, 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = edgeArrow })
Icons.Chevron(1, Colors.Text).Parent = edgeChevron

local guiding = false
local function setGuide(on: boolean)
	guiding = on
	marker.Enabled = on
	markerAnchor.Parent = on and Workspace or nil
	if not on then edgeArrow.Visible = false end
end

local function updateGuide()
	local camera = Workspace.CurrentCamera
	local root = myRoot()
	if not guiding or not camera or not root then return end
	local here = onStage()
	marker.Enabled = not here
	markerDistance.Text = math.floor((root.Position - STAGE).Magnitude) .. " studs"
	local point, visible = camera:WorldToViewportPoint(STAGE + Vector3.new(0, 15, 0))
	local size = camera.ViewportSize
	if here or (visible and point.X > 0 and point.X < size.X and point.Y > 0 and point.Y < size.Y) then
		edgeArrow.Visible = false
		return
	end
	-- off screen: an arrow on a ring around the middle of the screen, pointing toward it (clear of the side menu and
	-- the right column; behind the camera counts as the other way)
	local center = size / 2
	local dir = Vector2.new(point.X, point.Y) - center
	if point.Z < 0 then dir = -dir end
	if dir.Magnitude < 1 then dir = Vector2.new(0, 1) end
	dir = dir.Unit
	local radius = math.min(size.X, size.Y) * 0.26
	local pos = center + dir * radius
	local inset = game:GetService("GuiService"):GetGuiInset()
	edgeArrow.Position = UDim2.fromOffset(pos.X, pos.Y - inset.Y)
	edgeChevron.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	edgeArrow.Visible = true
end

------------------------------------------------------------------------
-- The round screen (contestants; owner's UI v2, mockup 12_posing): "POSING COMPETITION · Pose 2/3" and a timer at the top,
-- the pose's name big in gold, the Judges panel on the right (each contestant's last card, best first, "You" for you), and
-- at the bottom the TIMING bar (a marker runs to the green zone: perfect in the middle, good in the light green) over a
-- big red POSE! button (Space / gamepad A work too). Its own gui, so the right column steps aside while it's up.
------------------------------------------------------------------------
local roundGui = Theme.ScreenGui({ Name = "PosingRound", DisplayOrder = 22, Enabled = false, Parent = playerGui })
local roundRoot = Kit.Root(roundGui)
local header = Kit.Text({ Name = "Header", Text = "", Font = "Title", TextSize = 20, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(420, 24), Parent = roundRoot })
local timer = Kit.Text({ Name = "Timer", Text = "", Font = "Title", TextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76),
	Size = UDim2.fromOffset(120, 22), Parent = roundRoot })
local poseName = Kit.Text({ Name = "PoseName", Text = "", Font = "Title", TextSize = 42, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(520, 50), Parent = roundRoot })

-- the judges' scores (right)
local judges = Theme.Panel({ Name = "Judges", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 52), Size = UDim2.fromOffset(196, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Parent = roundRoot }, {
	New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	Theme.List(Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
Kit.Text({ Name = "Title", LayoutOrder = 0, Text = "Judges", Font = "Title", TextSize = 17, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = judges })
-- (everything up here starts just under Roblox's top bar, Kit.UnderTopbar)
local function placeUnderTopbar()
	local top = Kit.UnderTopbar(roundRoot)
	header.Position = UDim2.new(0.5, 0, 0, top)
	timer.Position = UDim2.new(0.5, 0, 0, top + 24)
	poseName.Position = UDim2.new(0.5, 0, 0, top + 52)
	judges.Position = UDim2.new(1, -10, 0, top)
end
Kit.OnTopbar(placeUnderTopbar)
roundGui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(placeUnderTopbar) end)
local judgeRows = {}
for i = 1, 3 do
	local row = Kit.Card({ Name = "Row" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 30), Parent = judges }, {})
	local rank = Kit.Text({ Text = tostring(i), Font = "Title", TextSize = 15, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(14, 30), Parent = row })
	local name = Kit.Text({ Text = "", Font = "Strong", TextSize = 13, Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -78, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local score = Kit.Text({ Text = "", Font = "Title", TextSize = 16, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(40, 30), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	judgeRows[i] = { row = row, rank = rank, name = name, score = score }
end
local lastCards = {} -- [contestant index] = the last card
local function showJudges(contestants)
	local list = {}
	for i, c in ipairs(contestants or {}) do
		if not c.out then table.insert(list, { name = c.userId == player.UserId and "You" or c.name, total = c.total or 0, card = lastCards[i] }) end
	end
	table.sort(list, function(x, y) return x.total > y.total end)
	for i, row in ipairs(judgeRows) do
		local entry = list[i]
		row.row.Visible = entry ~= nil
		if entry then
			row.name.Text = entry.name
			row.score.Text = entry.card and string.format("%.1f", entry.card) or "-"
		end
	end
end

-- the timing bar and the POSE! button (bottom)
local CUE_AT = 0.7 -- where on the bar the cue lands
local timing = Theme.Panel({ Name = "Timing", Piece = "hud_box", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.fromOffset(420, 30),
	Parent = roundRoot }, {})
Kit.Text({ Text = "TIMING", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(70, 30), TextXAlignment = Enum.TextXAlignment.Left, Parent = timing })
local track = New("Frame", { Name = "Track", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 90, 0.5, 0), Size = UDim2.new(1, -102, 0, 16),
	BackgroundColor3 = Colors.Well, Parent = timing }, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
local goodZone = New("Frame", { Name = "Good", AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Colors.Green, BackgroundTransparency = 0.55,
	Position = UDim2.fromScale(CUE_AT, 0), Size = UDim2.fromScale(CUE_AT * 2 * PosingComp.Good / PosingComp.CueTime, 1), Parent = track })
local perfectZone = New("Frame", { Name = "Perfect", AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Colors.Green,
	Position = UDim2.fromScale(CUE_AT, 0), Size = UDim2.fromScale(CUE_AT * 2 * PosingComp.Perfect / PosingComp.CueTime, 1), ZIndex = 2, Parent = track })
local markerLine = New("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 4, 1, 8),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = track }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local _ = goodZone and perfectZone
local tapButton = Kit.Button("Red", "Pose!", { Name = "Tap", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = roundRoot },
	{ width = 230, height = 58, textSize = 32 })
local tapResult = Kit.Text({ Name = "TapResult", Text = "", Font = "Title", TextSize = 22, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -116),
	Size = UDim2.fromOffset(240, 26), Parent = roundRoot })

local current = nil -- { cueAt, cueTime, holdUntil, tapped }
local function sendTap()
	if not current or current.tapped then return end
	current.tapped = true
	remote:FireServer("Tap")
	Kit.SetButton(tapButton, "Gray")
end
tapButton.Activated:Connect(sendTap)
local function boundTap(_, state)
	if state == Enum.UserInputState.Begin then sendTap() end
	return Enum.ContextActionResult.Sink
end

local function showPose(info)
	current = { cueAt = info.cueAt, cueTime = info.cueTime, holdUntil = info.holdUntil, tapped = false, cued = false }
	header.Text = string.format("POSING COMPETITION · Pose %d/%d", info.index, info.count)
	poseName.Text = string.upper(info.name) .. "!"
	tapResult.Text = ""
	Kit.SetButton(tapButton, "Red")
	showJudges(info.contestants)
	roundGui.Enabled = true
	ContextActionService:BindActionAtPriority("PosingTap", boundTap, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

local function hidePose()
	current = nil
	roundGui.Enabled = false
	ContextActionService:UnbindAction("PosingTap")
end

local function updatePose()
	if not current then return end
	local t = now()
	local left = current.cueAt - t
	-- the timer: to the cue, then the hold until the judges score
	timer.Text = clock(left > 0 and left or ((current.holdUntil or t) - t))
	if not current.tapped then
		-- the marker runs from the left edge to the cue spot as the cue comes, and on past it
		local f = 1 - left / current.cueTime
		markerLine.Position = UDim2.fromScale(math.clamp(f * CUE_AT, 0, 1), 0.5)
		if left <= 0 and not current.cued then
			current.cued = true
			Audio.Play2D(PosingComp.Sounds.Cue)
		end
	end
end

------------------------------------------------------------------------
-- Vote panel (watchers near the stage, last pose)
------------------------------------------------------------------------
local votePanel = Theme.Panel({
	Name = "Vote", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -Theme.Spacing.L, 0.55, 0),
	Size = UDim2.fromOffset(220, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = gui,
}, { Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
local voteTitle = Theme.Text({ LayoutOrder = 0, Text = "Vote: best poser", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = votePanel })
Theme.Uppercase(voteTitle)
local voteButtons = {}

local function hideVote()
	if votePanel.Visible then
		local tween = Theme.Fade(votePanel, false)
		if tween then tween.Completed:Connect(function() votePanel.Visible = false end) else votePanel.Visible = false end
	end
end

local function showVote(contestants)
	for _, button in ipairs(voteButtons) do button:Destroy() end
	voteButtons = {}
	for index, c in ipairs(contestants) do
		if not c.out and c.userId ~= player.UserId then
			local button = Kit.Button("Blue", c.name, { Name = "Vote" .. index, LayoutOrder = index, Parent = votePanel },
				{ width = 196, height = 36, textSize = 15, upper = false })
			-- the contestant's headshot left of the name (the shared plain circle; an NPC shows its letter)
			Kit.Headshot(not c.npc and c.userId or nil, c.name, 24, { LayoutOrder = 0, Parent = button })
			button.Activated:Connect(function()
				remote:FireServer("Vote", index)
				hideVote()
			end)
			table.insert(voteButtons, button)
		end
	end
	if #voteButtons == 0 then return end
	votePanel.Visible = true
	Theme.Fade(votePanel, true)
end

------------------------------------------------------------------------
-- Messages from the server
------------------------------------------------------------------------
local countdownEnds = nil
local inRound = false -- I'm a contestant in the running round

local function amContestant(contestants)
	for _, c in ipairs(contestants or {}) do
		if c.userId == player.UserId and not c.out then return true end
	end
	return false
end

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Countdown" and type(info.endsAt) == "number" then
		if not countdownEnds then Audio.Play2D(PosingComp.Sounds.Start) end
		countdownEnds = info.endsAt
		showBanner(true)
		setGuide(true)
	elseif kind == "Start" then
		countdownEnds = nil
		lastCards = {}
		setGuide(false)
		inRound = amContestant(info.contestants)
		if inRound then
			stageCamera(true)
			bannerTitle.Text = "You're in!"
			bannerLine.Text = "Tap POSE! when the marker reaches the green"
			showBanner(true)
			task.delay(info.intro or 4, function() if inRound then showBanner(false) end end)
		else
			showBanner(false)
		end
	elseif kind == "NoShow" or kind == "Cancelled" or kind == "Ended" then
		countdownEnds = nil
		inRound = false
		stageCamera(false)
		setGuide(false)
		showBanner(false)
		hidePose()
		hideVote()
	elseif kind == "Pose" then
		inRound = amContestant(info.contestants)
		if inRound then showPose(info) else hidePose() end
		if info.vote and not inRound and nearStage() then showVote(info.contestants) end
	elseif kind == "Tapped" then
		if current then current.tapped = true end
		tapResult.Text = string.upper(tostring(info.label or "")) .. (info.label == "Perfect" and "!" or "")
		tapResult.TextColor3 = info.label == "Perfect" and Colors.Gold or (info.label == "Good" and Colors.Green or Colors.Text)
		Kit.SetButton(tapButton, "Gray")
	elseif kind == "Scores" then
		for i, card in pairs(type(info.cards) == "table" and info.cards or {}) do lastCards[i] = card end
		showJudges(info.contestants)
		if current then current = nil end -- (the round screen stays up between poses; the next Pose refreshes it)
		if inRound or nearStage() then Audio.Play2D(PosingComp.Sounds.Score) end
	elseif kind == "Out" then
		if not amContestant(info.contestants) and inRound then
			inRound = false
			hidePose()
			stageCamera(false)
			Notify.Show("You left the stage: you're out of this round", Colors.NeedsWork)
		end
	elseif kind == "Voted" then
		Notify.Toast("Vote sent", "You voted for " .. tostring(info.name), "star", Colors.Blue)
	elseif kind == "Results" then
		hidePose()
		hideVote()
		local ranking = info.ranking or {}
		local winner = ranking[1]
		if winner and (inRound or nearStage()) then Audio.Play2D(PosingComp.Sounds.Win) end
		if winner then
			Notify.Show(winner.name .. " won the posing competition!", Colors.Gold, "PosingWinner")
		end
		inRound = false
	elseif kind == "Reward" then
		local place = tonumber(info.place) or 0
		local names = { "1st", "2nd", "3rd" }
		Notify.Toast(string.format("%s place!", names[place] or (place .. "th")), string.format("+%d coins", tonumber(info.coins) or 0), "trophy",
			place == 1 and Colors.Gold or Colors.Blue)
	end
end)

RunService.RenderStepped:Connect(function()
	-- nothing of this shows on the menu screen (or behind the genetics screen)
	local hidden = UIBus.MenuOpen or geneticsUp
	if gui.Enabled == hidden then gui.Enabled = not hidden end
	applyBanner(hidden)
	if guiding and marker.Enabled and hidden then marker.Enabled = false end
	if hidden then return end
	if countdownEnds then
		local left = countdownEnds - now()
		bannerTitle.Text = "Posing competition"
		if onStage() then
			bannerLine.Text = "Starts in " .. clock(left) .. ". You're on the stage: stay here!"
		else
			bannerLine.Text = "Starts in " .. clock(left) .. ". Go to the stage on the beach!"
		end
	end
	updateGuide()
	updatePose()
end)

-- joined while a countdown was running: ask for it
remote:FireServer("State")
