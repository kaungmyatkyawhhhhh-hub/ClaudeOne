-- PosingCompClient: the posing show on every screen (PosingCompService runs it; Config.PosingComp has the numbers).
-- Reworked for prompt 18 (21 Oct): a show every 5 minutes in height divisions.
--   * Timer (players with a Growth Spurt): a small pill in the right column, "POSING SHOW 2:30". In the last 30 s it glows
--     gold with a JOIN button (a far player is put on the stage, a near one follows a glowing path; the stage top glows).
--     Tapping the pill shows your show stats. Nobody is ever pulled away from training.
--   * Your division: the crowd's view of the stage, "BANTAM DIVISION · LOCAL SHOW", the pose the judges call big in gold
--     with a bar running down its 5 s. You hit it automatically, with everyone.
--   * The judges' panel (contestants, and anyone near the stage): every contestant's breakdown, "Size 52 / Balance 21 /
--     Presence 11 = 84", best first.
--   * Results: confetti and a fanfare at the podium, your place and prize (a reward
--     popup; everyone who finished gets coins and "Good effort!").
-- Light on phones: a few confetti and flash lights, no shadows.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PosingComp = require(Shared.Config.PosingComp)
local Town = require(Shared.Config.Town)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local RightColumn = require(Shared.UI.RightColumn)
local GuidePath = require(Shared.UI.GuidePath)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("PosingComp", 60) :: RemoteEvent
if not remote then return end -- the posing show service didn't start

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors
local New = Theme.New

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
	return root ~= nil and (root.Position - STAGE).Magnitude <= 150
end

local function unlocked(): boolean
	local data = ClientData.Get()
	return data ~= nil and (data.growthSpurts or 0) >= PosingComp.UnlockSpurts
end

local geneticsUp = false
UIBus.GeneticsVisible.Event:Connect(function(visible) geneticsUp = visible == true end)

------------------------------------------------------------------------
-- Contestant camera: the crowd's view of the stage while your division is on (front on, so you see your own poses)
------------------------------------------------------------------------
local STAGE_SHOT = { From = Vector3.new(0, 6, -20), At = Vector3.new(0, 4.6, 0), Fov = 55 }
local savedCamera = nil
local function stageCamera(on: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if on and not savedCamera then
		savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
		camera.CameraType = Enum.CameraType.Scriptable
		Theme.Tween(camera, { CFrame = CFrame.lookAt(STAGE + STAGE_SHOT.From, STAGE + STAGE_SHOT.At), FieldOfView = STAGE_SHOT.Fov }, 0.6)
	elseif not on and savedCamera then
		camera.CameraType = savedCamera.type
		camera.FieldOfView = savedCamera.fov
		savedCamera = nil
	end
end

------------------------------------------------------------------------
-- The timer pill (prompt 46, owner 22 Oct: in Roblox's top bar with TopbarPlus, left of DAILY, like the HUD mockup 05):
-- "POSING SHOW 0:27", and in the join window a small gold JOIN icon right after it. Only while a show starts within
-- SOON seconds (or one is on). On a narrow screen it says "SHOW 0:27".
------------------------------------------------------------------------
local TopBar = require(Shared.UI.TopBar)
local UIConfig = require(Shared.Config.UI)
local SOON = 90 -- seconds before a show the pill comes up
local timerIcon = TopBar.Style(TopBar.Icon.new():setName("PosingShow"):align("Right"):setOrder(0):oneClick(true))
timerIcon:setImage(UIConfig.Icons.trophy)
-- (owner, 23 Oct, chrome reset: a quiet pill like the others: a white trophy, the clean italic words)
timerIcon:modifyTheme({ "IconImage", "ImageColor3", Colors.Text })
timerIcon:modifyTheme({ "IconLabel", "FontFace", require(Shared.UI.UIFonts).Display })
timerIcon:setEnabled(false)
local joinIcon = TopBar.Icon.new():setName("PosingJoin"):align("Right"):setOrder(1):oneClick(true):setLabel("JOIN")
joinIcon:modifyTheme({ "IconButton", "BackgroundColor3", Colors.Gold })
joinIcon:modifyTheme({ "IconButton", "BackgroundTransparency", 0 })
joinIcon:modifyTheme({ "IconLabel", "TextColor3", Colors.Ink })
joinIcon:modifyTheme({ "IconLabel", "FontFace", require(Shared.UI.UIFonts).Display })
joinIcon:setEnabled(false)
-- (the old names the code below uses)
local pill = { Visible = false }
local joinButton = { Visible = false }
local pillStroke = { Transparency = 1 }
local function setPillText(text: string)
	-- shortened when the screen is narrow (a phone): "SHOW 0:27"
	local camera = Workspace.CurrentCamera
	local narrow = camera ~= nil and camera.ViewportSize.X < 900
	timerIcon:setLabel(if narrow then (string.gsub(text, "^POSING SHOW", "SHOW")) else text)
end
local function applyPill()
	timerIcon:setEnabled(pill.Visible == true)
	joinIcon:setEnabled(pill.Visible == true and joinButton.Visible == true)
end

local nextAt = nil   -- server time of the next show
local running = false -- a show is on
local inDivision = false -- I'm in the division on stage now
local joining = false
local seenSent = false

timerIcon:bindEvent("selected", function()
	Audio.PlayUI("Click")
	local stats = (ClientData.Get() or {}).stats or {}
	Notify.Toast("Your posing shows", string.format("Entered %d · Wins %d · Trophies %d · Best %d", stats.posingEntries or 0, stats.posingWins or 0,
		stats.posingTrophies or 0, stats.posingBest or 0), "trophy", Colors.Gold, "posingstats")
end)
joinIcon:bindEvent("selected", function()
	Audio.PlayUI("Click")
	joining = true
	remote:FireServer("Join")
end)

-- the stage top glows during the join window (4 thin neon strips around it)
local glow = New("Folder", { Name = "PosingJoinGlow" })
do
	local size, center = Town.Stage.Size, Town.Stage.Center + Vector3.new(0, Town.Stage.Size.Y + 0.08, 0)
	local strips = {
		{ Vector3.new(size.X, 0.12, 0.25), Vector3.new(0, 0, size.Z / 2) }, { Vector3.new(size.X, 0.12, 0.25), Vector3.new(0, 0, -size.Z / 2) },
		{ Vector3.new(0.25, 0.12, size.Z), Vector3.new(size.X / 2, 0, 0) }, { Vector3.new(0.25, 0.12, size.Z), Vector3.new(-size.X / 2, 0, 0) },
	}
	for _, strip in ipairs(strips) do
		New("Part", { Size = strip[1], CFrame = CFrame.new(center + strip[2]), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			CastShadow = false, Material = Enum.Material.Neon, Color = Colors.Gold, Parent = glow })
	end
end

local function refreshPill()
	local soon = nextAt ~= nil and (running or nextAt - now() <= SOON)
	local show = unlocked() and soon and not UIBus.MenuOpen and not geneticsUp
	pill.Visible = show
	if not show then
		glow.Parent = nil
		applyPill()
		return
	end
	if not seenSent then
		seenSent = true
		remote:FireServer("Seen")
	end
	if running then
		setPillText("POSING SHOW · ON NOW")
		joinButton.Visible = false
		pillStroke.Transparency = 0.35
		glow.Parent = nil
		applyPill()
		return
	end
	local left = nextAt - now()
	local window = left <= PosingComp.JoinWindow and left > 0
	local here = onStage()
	-- (the small gold JOIN is in the pill while it can be used: in the join window, not joined yet)
	joinButton.Visible = window and not joining and not here
	setPillText(if window and here then "ON STAGE · " .. clock(left) else "POSING SHOW " .. clock(left))
	glow.Parent = if window then Workspace else nil
	-- the gold glow pulses in the join window
	pillStroke.Transparency = if window then 0.6 * (0.5 + 0.5 * math.sin(os.clock() * 5)) else 0.35
	applyPill()
end

------------------------------------------------------------------------
-- The show screen (your division): header, the called pose big in gold, its bar
------------------------------------------------------------------------
local showGui = Theme.ScreenGui({ Name = "PosingRound", DisplayOrder = 22, Enabled = false, Parent = playerGui })
showGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local showRoot = Kit.Root(showGui)
local header = Kit.Text({ Name = "Header", Text = "", Font = "Title", TextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(460, 22), Parent = showRoot })
local poseName = Kit.Text({ Name = "PoseName", Text = "", Font = "Title", TextSize = 40, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.fromOffset(520, 48), Parent = showRoot })
local _, setPoseBar = Kit.Bar(Colors.Gold, { Name = "PoseBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(240, 8),
	Parent = showRoot }, { outline = 1 })
local poseBar = showRoot:FindFirstChild("PoseBar")
Kit.OnTopbar(function()
	local top = Kit.UnderTopbar(showRoot)
	header.Position = UDim2.new(0.5, 0, 0, top)
	poseName.Position = UDim2.new(0.5, 0, 0, top + 24)
	if poseBar then poseBar.Position = UDim2.new(0.5, 0, 0, top + 74) end
end)
local poseEnds, poseLength = nil, PosingComp.PoseTime

------------------------------------------------------------------------
-- The judges' panel: every contestant's breakdown, best first (fits 667x375)
------------------------------------------------------------------------
local judgesGui = Theme.ScreenGui({ Name = "PosingJudges", DisplayOrder = 23, Enabled = false, Parent = playerGui })
judgesGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local judgesRoot = Kit.Root(judgesGui)
local judges = Theme.Panel({ Name = "Judges", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(420, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Parent = judgesRoot }, {
	New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	Theme.List(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
local judgesTitle = Kit.Text({ Name = "Title", LayoutOrder = 0, Text = "THE JUDGES", Font = "Title", TextSize = 16, TextColor3 = Colors.Gold,
	Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = judges })
local judgeRows = {}
for i = 1, PosingComp.MaxPerDivision do
	local row = New("Frame", { Name = "Row" .. i, LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Visible = false, Parent = judges })
	local name = Kit.Text({ Name = "Name", Text = "", Font = "Strong", TextSize = 13, Size = UDim2.new(0.38, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local parts = Kit.Text({ Name = "Parts", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromScale(0.38, 0),
		Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local total = Kit.Text({ Name = "Total", Text = "", Font = "Title", TextSize = 15, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.12, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	judgeRows[i] = { row = row, name = name, parts = parts, total = total }
end

local function showJudges(division: string, contestants)
	local list = {}
	for _, c in ipairs(contestants or {}) do
		if not c.out and type(c.score) == "table" then table.insert(list, c) end
	end
	table.sort(list, function(a, b) return a.score.total > b.score.total end)
	judgesTitle.Text = "THE JUDGES · " .. string.upper(division) .. "  (size / balance / presence)"
	for i, row in ipairs(judgeRows) do
		local c = list[i]
		row.row.Visible = c ~= nil
		if c then
			local me = c.userId == player.UserId
			row.name.Text = i .. ". " .. (if me then "You" else c.name)
			row.name.TextColor3 = if me then Colors.Gold else Colors.Text
			row.parts.Text = string.format("Size %d / Balance %d / Presence %d", c.score.size, c.score.balance, c.score.presence)
			row.total.Text = "= " .. c.score.total
		end
	end
	judgesGui.Enabled = true
	Theme.Fade(judges, true, 0.2)
end
local function hideJudges() judgesGui.Enabled = false end

------------------------------------------------------------------------
-- Stage effects (light): camera flashes on each pose, confetti at the podium
------------------------------------------------------------------------
local function flashes()
	for _ = 1, 3 do
		task.delay(math.random() * 1.2, function()
			local part = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
				Size = Vector3.one, CFrame = CFrame.new(STAGE + Vector3.new(math.random(-8, 8), math.random(2, 5), -10)), Parent = Workspace })
			New("PointLight", { Brightness = 6, Range = 14, Shadows = false, Color = Color3.new(1, 1, 1), Parent = part })
			task.delay(0.12, function() part:Destroy() end)
		end)
	end
end

local function confetti()
	local part = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(8, 1, 3), CFrame = CFrame.new(STAGE + Vector3.new(0, 9, 0)), Parent = Workspace })
	local emitter = New("ParticleEmitter", { Rate = 0, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, -9, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), Size = NumberSequence.new(0.35),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Colors.Gold), ColorSequenceKeypoint.new(0.5, Colors.Red), ColorSequenceKeypoint.new(1, Colors.Teal) }),
		LightInfluence = 0, Parent = part })
	emitter:Emit(40)
	task.delay(4, function() part:Destroy() end)
end

------------------------------------------------------------------------
-- Messages from the server
------------------------------------------------------------------------
local function amIn(contestants): boolean
	for _, c in ipairs(contestants or {}) do
		if c.userId == player.UserId and not c.out then return true end
	end
	return false
end

local function endMine()
	inDivision = false
	showGui.Enabled = false
	poseEnds = nil
	stageCamera(false)
end

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Schedule" then
		if type(info.nextAt) == "number" then nextAt = info.nextAt end
		if info.running ~= nil then running = info.running == true end
	elseif kind == "Joined" then
		joining = false
		if not info.teleported then
			GuidePath.Show(STAGE, "Posing")
			Notify.Hint("Follow the glowing dots to the posing stage.")
		else
			Notify.Hint("You're on the stage. Stay here!")
		end
	elseif kind == "Start" then
		running = true
		joining = false
		GuidePath.Hide("Posing")
		if nearStage() then Audio.Play2D(PosingComp.Sounds.Start) end
	elseif kind == "Division" then
		hideJudges()
		if amIn(info.contestants) then
			inDivision = true
			stageCamera(true)
			header.Text = string.upper(tostring(info.division)) .. " DIVISION · " .. string.upper(tostring(info.show))
			poseName.Text = "TAKE YOUR MARKS"
			setPoseBar(0)
			showGui.Enabled = true
		else
			endMine()
		end
	elseif kind == "Pose" then
		if inDivision then
			poseName.Text = string.upper(tostring(info.name)) .. "!"
			poseEnds = tonumber(info.endsAt)
			Audio.Play2D(PosingComp.Sounds.Cue)
		end
		if inDivision or nearStage() then
			Audio.PlayAt(PosingComp.Sounds.Crowd, STAGE)
			flashes()
		end
	elseif kind == "Out" then
		if info.userId == player.UserId and inDivision then
			endMine()
			Notify.Show("You left the stage: you're out of this show", Colors.NeedsWork)
		end
	elseif kind == "Scores" then
		if inDivision then
			poseEnds = nil
			poseName.Text = "THE JUDGES"
		end
		if inDivision or nearStage() then
			showJudges(tostring(info.division), info.contestants)
			Audio.Play2D(PosingComp.Sounds.Score)
		end
	elseif kind == "Results" then
		if inDivision or nearStage() then
			Audio.Play2D(PosingComp.Sounds.Win)
			confetti()
		end
		-- (owner, prompt 48: no server-wide winner toast; the placed players get their own reward popup)
		hideJudges()
		if inDivision then poseName.Text = "THE PODIUM" end
	elseif kind == "Reward" then
		local place = tonumber(info.place) or 0
		local names = { "1ST PLACE!", "2ND PLACE!", "3RD PLACE!" }
		local coins = "+" .. Kit.Format(tonumber(info.coins) or 0) .. " coins"
		if place >= 1 and place <= 3 then
			Notify.Reward(names[place], coins .. (if info.trophy then " · +1 trophy" else ""), "trophy", if place == 1 then Colors.Gold else Colors.Blue)
		else
			Notify.Reward("GOOD EFFORT!", "Place " .. place .. " · " .. coins, "star", Colors.Teal)
		end
	elseif kind == "NoShow" or kind == "Cancelled" or kind == "Ended" then
		running = false
		joining = false
		if type(info.nextAt) == "number" then nextAt = info.nextAt end
		GuidePath.Hide("Posing")
		hideJudges()
		endMine()
	end
end)

RunService.RenderStepped:Connect(function()
	refreshPill()
	if poseEnds then
		setPoseBar(math.clamp((poseEnds - now()) / poseLength, 0, 1))
	end
	-- (the menu / genetics screen cover everything)
	local hidden = UIBus.MenuOpen or geneticsUp
	if hidden then showGui.Enabled = false elseif inDivision then showGui.Enabled = true end
end)

-- joined while the server was already running: ask when the next show is
remote:FireServer("State")
