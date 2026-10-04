-- MenuClient: the menu screen shown on join. It covers data loading, frames the player's character with a slow
-- camera drift (the character faces the camera, the gym shows through the doorway behind them), and holds Play
-- (+ Titles, Settings and a few info lines for returning players: streak, offline coins, Muscle of the Day; new
-- players get a simplified menu with Play only). Movement is frozen and the side menu is hidden until Play.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIBus = require(Shared:WaitForChild("UI"):WaitForChild("UIBus"))
UIBus.MenuOpen = true -- set first, before anything else loads, so other scripts wait for Play

local Onboarding = require(Shared.Config.Onboarding)
local Muscles = require(Shared.Config.Muscles)
local MuscleOfTheDay = require(Shared.Config.MuscleOfTheDay)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ShowOff = require(Shared.Config.ShowOff)
local Legends = require(Shared.Config.Legends)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical = Enum.FillDirection.Vertical

-- Camera framing (studs / degrees). The character sits left of center; the menu panel is on the right.
local CAMERA = {
	Distance = 8.5,     -- from the character's chest
	Height = 1.4,       -- above the chest
	AimOffset = 1.8,    -- aim this far to the camera's right of the character, so they sit left of center
	Sway = 18,          -- slow left/right drift
	SwaySpeed = 0.12,   -- radians per second
	Fov = 55,
	ExitTime = 0.7,     -- camera glides behind the character on Play
	WallGap = 0.6,      -- keep the camera this far in front of walls
}
local PANEL_WIDTH = 300

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, Parent = playerGui })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -Spacing.XL * 2, 0.5, 0),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
}, {
	Theme.Pad("XL"),
	Theme.List(Vertical, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})

Theme.Text({ LayoutOrder = 1, Text = "GYM ARC", Font = "SemiBold", TextSize = "Huge", Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
Theme.Text({ LayoutOrder = 2, Text = "Everyone starts tiny.", Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, Spacing.S), BackgroundTransparency = 1, Parent = panel })

local function menuButton(order, style, text)
	local button = Theme.Button(style, { Name = text, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 52), Parent = panel })
	local label = Theme.Text({ Text = text, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = button })
	return button, label
end
local playButton, playLabel = menuButton(4, "Primary", "Play")
local titlesButton = menuButton(5, "Secondary", "Titles")
local settingsButton = menuButton(6, "Secondary", "Settings")
titlesButton.Visible, settingsButton.Visible = false, false -- shown for returning players once data loads

-- info lines (returning players): streak, offline coins, Muscle of the Day
local info = New("Frame", { LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = panel },
	{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top), New("UIPadding", { PaddingTop = UDim.new(0, Spacing.S) }) })
local function infoLine(order, text)
	return Theme.Text({ LayoutOrder = order, Text = text, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = info })
end

playLabel.Text = "Loading..."
playLabel.TextColor3 = Colors.Muted
playButton.Active = false

------------------------------------------------------------------------
-- Player card (returning players): membership tier, overall genetics grade, height and a few numbers
------------------------------------------------------------------------
local function buildCard(data)
	local tier, nextTier = ShowOff.Tier(data.stats and data.stats.totalReps or 0)
	local card = Theme.Panel({
		Name = "PlayerCard",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Spacing.XL * 2, 1, -Spacing.XL * 2),
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, {
		Theme.Pad("L"),
		Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	-- the tier color is a thin line along the top of the card
	New("Frame", { Name = "TierLine", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = tier.color, LayoutOrder = 0, Parent = card }, { Theme.Round("Segment") })
	local top = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = card })
	Theme.Text({ Text = player.DisplayName, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -48, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	Theme.Text({ Text = tier.id .. " member", Font = "Regular", TextSize = "Small", TextColor3 = tier.color, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -48, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	local overall = data.genetics and data.genetics.overall
	if overall and Theme.Grades[overall] then
		local disc = Theme.PlateDisc(Theme.Grades[overall], { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(38, 38), Parent = top })
		Theme.Text({ Text = overall, Font = "SemiBold", TextSize = "Body", TextColor3 = Theme.Grades[overall].Text, Size = UDim2.fromScale(1, 1), Parent = disc })
	end
	local metCount, titleCount = 0, 0
	for _ in pairs(data.legends and data.legends.met or {}) do metCount += 1 end
	for _ in pairs(data.titles and data.titles.owned or {}) do titleCount += 1 end
	local lines = {
		"Height " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts)) .. "  ·  Growth Spurt " .. data.growthSpurts,
		(data.stats and data.stats.totalReps or 0) .. " reps  ·  " .. titleCount .. " titles  ·  " .. metCount .. "/" .. #Legends.List .. " legends",
		nextTier and (nextTier.id .. " at " .. nextTier.reps .. " reps") or "Top tier",
	}
	for i, text in ipairs(lines) do
		Theme.Text({ LayoutOrder = 1 + i, Text = text, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	end
	Theme.Fade(card, true)
	return card
end

------------------------------------------------------------------------
-- Freeze movement and hide the side menu while the menu is up
------------------------------------------------------------------------
local function sink()
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority("MenuFreeze", sink, false, Enum.ContextActionPriority.High.Value + 200,
	Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)

local mainHud = nil
task.spawn(function()
	mainHud = playerGui:WaitForChild("MainHud", 10)
	if mainHud and UIBus.MenuOpen then mainHud.Enabled = false end
end)

------------------------------------------------------------------------
-- Camera: a slow drift in front of the character, looking at them with the gym behind them
------------------------------------------------------------------------
local camera = Workspace.CurrentCamera
local baseFov = camera.FieldOfView
local facing = nil   -- horizontal direction from the character toward the camera (away from the gym)
local root = nil

-- Horizontal direction from a point toward the gym (the middle of all machines), if there are any.
local function gymDirection(fromPosition)
	local sum, count = Vector3.zero, 0
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") then
			sum += model:GetPivot().Position
			count += 1
		end
	end
	if count == 0 then return nil end
	local flat = (sum / count - fromPosition) * Vector3.new(1, 0, 1)
	return flat.Magnitude > 1 and flat.Unit or nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function cameraCFrame(time)
	local chest = root.Position + Vector3.new(0, 1.2, 0)
	local angle = math.rad(math.sin(time * CAMERA.SwaySpeed) * CAMERA.Sway)
	local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(facing)
	local wanted = chest + dir * CAMERA.Distance + Vector3.new(0, CAMERA.Height, 0)
	-- stay in front of walls and equipment
	local hit = Workspace:Raycast(chest, wanted - chest, rayParams)
	if hit then
		wanted = hit.Position - (wanted - chest).Unit * CAMERA.WallGap
	end
	local look = (chest - wanted).Unit
	local right = look:Cross(Vector3.yAxis)
	right = right.Magnitude > 0 and right.Unit or Vector3.xAxis
	return CFrame.lookAt(wanted, chest + right * CAMERA.AimOffset)
end

local function startCamera(character)
	root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not UIBus.MenuOpen then return end
	rayParams.FilterDescendantsInstances = { character }
	-- the camera stands on the far side of the character from the gym, so the gym is the background
	local toGym = gymDirection(root.Position)
	facing = toGym and -toGym or root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, 1) end
	facing = facing.Unit
	-- turn the character to face the camera
	root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA.Fov
	local start = os.clock()
	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if root.Parent then camera.CFrame = cameraCFrame(os.clock() - start) end
	end)
end

task.spawn(function()
	startCamera(player.Character or player.CharacterAdded:Wait())
end)

------------------------------------------------------------------------
-- Ready: data loaded
------------------------------------------------------------------------
task.spawn(function()
	local data = ClientData.Get()
	local returning = (data.onboarding.tutorialStep or Onboarding.Done) >= Onboarding.Done
	titlesButton.Visible, settingsButton.Visible = returning, returning
	if returning then
		local okCard, err = pcall(buildCard, data)
		if not okCard then warn("[MenuClient] player card: " .. tostring(err)) end
		info.Visible = true
		local streak = data.daily and data.daily.streak or 0
		if streak > 0 then infoLine(1, "Day " .. streak .. " streak") end
		infoLine(3, "Muscle of the Day: " .. Muscles.GroupById[MuscleOfTheDay.GroupId()].name .. " (" .. MuscleOfTheDay.Multiplier .. "x gains)")
		-- the server pays streak/offline coins right after load; show them when they arrive
		local shownOffline = false
		local function offlineLine()
			local coins = data.welcome and data.welcome.offlineCoins or 0
			if coins > 0 and not shownOffline then
				shownOffline = true
				infoLine(2, "While you were away: +" .. coins .. " coins")
			end
		end
		offlineLine()
		ClientData.Changed:Connect(function(path)
			if path[1] == "welcome" and UIBus.MenuOpen then offlineLine() end
			if path[1] == "daily" and UIBus.MenuOpen then
				for _, child in ipairs(info:GetChildren()) do
					if child:IsA("TextLabel") and child.LayoutOrder == 1 then child:Destroy() end
				end
				infoLine(1, "Day " .. data.daily.streak .. " streak")
			end
		end)
	end
	playLabel.Text = "Play"
	playLabel.TextColor3 = Colors.Text
	playButton.Active = true
end)

------------------------------------------------------------------------
-- Play
------------------------------------------------------------------------
local function play()
	if not UIBus.MenuOpen or not playButton.Active then return end
	playButton.Active = false
	Audio.PlayUI("Whoosh")
	RunService:UnbindFromRenderStep("MenuCamera")

	local function finish()
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		ContextActionService:UnbindAction("MenuFreeze")
		if mainHud then mainHud.Enabled = true end
		UIBus.MenuOpen = false
		UIBus.MenuClosed:Fire()
	end

	Theme.Tween(camera, { FieldOfView = baseFov }, CAMERA.ExitTime)
	local tween = Theme.Fade(panel, false)
	local card = gui:FindFirstChild("PlayerCard")
	if card then Theme.Fade(card, false) end
	if tween then
		tween.Completed:Connect(function() gui.Enabled = false end)
	end
	if root and root.Parent then
		-- turn toward the gym, glide to a normal view behind the character, then hand control back
		if facing then root.CFrame = CFrame.lookAt(root.Position, root.Position - facing) end
		local behind = root.CFrame * CFrame.new(0, 3, 11)
		local goal = CFrame.lookAt(behind.Position, root.Position + Vector3.new(0, 1.5, 0))
		Theme.Tween(camera, { CFrame = goal }, CAMERA.ExitTime).Completed:Connect(finish)
	else
		finish()
	end
end

playButton.Activated:Connect(play)
titlesButton.Activated:Connect(function() UIBus.OpenTitles:Fire() end)
settingsButton.Activated:Connect(function() UIBus.OpenSettings:Fire() end)
