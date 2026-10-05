-- MirrorClient: the progress mirror's before/after screen (opened from the mirror's Look prompt in the entrance hall).
-- Two 3D views side by side: your day-one body (your character at the day-one height, without muscle growth) and your
-- body now, each with height and level underneath. Clean and centered, so it makes a good screenshot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local gui = Theme.ScreenGui({ Name = "ProgressMirror", Enabled = false, DisplayOrder = 27, Parent = player:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false, Parent = gui })
local root = New("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.86, 0.86),
	BackgroundTransparency = 1,
	Parent = backdrop,
}, { Theme.Limit(Vector2.new(420, 280), Vector2.new(900, 620)), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })

local header = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = root })
local title = Theme.Text({ Font = "SemiBold", TextSize = "Large", Size = UDim2.fromScale(1, 1), Parent = header })
local columns = New("Frame", { LayoutOrder = 2, Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Parent = root },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.List(Horizontal, "L", Enum.HorizontalAlignment.Center) })
local closeButton = Theme.Button("Secondary", { Name = "Close", LayoutOrder = 3, Size = UDim2.fromOffset(140, Theme.MinTouch), Parent = root }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

local function column(order)
	local col = New("Frame", { LayoutOrder = order, Size = UDim2.fromScale(0.46, 1), BackgroundTransparency = 1, Parent = columns },
		{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
	local viewport = New("ViewportFrame", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Ambient = Color3.fromRGB(150, 140, 130),
		LightColor = Color3.fromRGB(255, 236, 214),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = col,
	}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.Round("Panel"), Theme.Stroke(Colors.Border, 1, Theme.Alpha.Border) })
	local name = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = col })
	local info = Theme.Text({ LayoutOrder = 3, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), Parent = col })
	return viewport, name, info
end
local beforeView, beforeName, beforeInfo = column(1)
local afterView, afterName, afterInfo = column(2)

-- A copy of the character for a viewport: no scripts, facing the camera, feet on y = 0. `scale` resizes it,
-- `plain` puts every body part back to its size before muscle growth (BodyService's OriginalSize).
local function copyCharacter(scale, plain)
	local character = player.Character
	if not character then return nil end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = wasArchivable
	if not copy then return nil end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or (d:IsA("Folder") and d.Name == "Skateboard") then
			d:Destroy()
		elseif plain and d:IsA("BasePart") and typeof(d:GetAttribute("OriginalSize")) == "Vector3" then
			d.Size = d:GetAttribute("OriginalSize")
		end
	end
	local board = copy:FindFirstChild("Skateboard")
	if board then board:Destroy() end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	local rootPart = copy:FindFirstChild("HumanoidRootPart")
	if rootPart then copy.PrimaryPart = rootPart end
	if scale and math.abs(scale - 1) > 0.001 then copy:ScaleTo(scale) end
	-- face the camera (+Z), then stand it on y = 0 in the middle
	local pivot = copy:GetPivot()
	local look = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, 1)
	local yaw = math.atan2(look.X, look.Z) -- 0 when already facing +Z
	copy:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, -yaw, 0) * pivot.Rotation)
	local cf, size = copy:GetBoundingBox()
	copy:PivotTo(copy:GetPivot() - Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))
	return copy, size
end

local function show(viewport, copy, tallest)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
	end
	if not copy then return end
	local world = New("WorldModel", { Parent = viewport })
	copy.Parent = world
	local camera = New("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	-- the same camera for both views, framed on the taller body, so the height difference shows
	local distance = (tallest * 0.62) / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.lookAt(Vector3.new(0, tallest * 0.52, distance), Vector3.new(0, tallest * 0.5, 0))
end

local function averageLevel(data)
	local total = 0
	for _, group in ipairs(Muscles.Groups) do total += Muscles.GetGroupLevel(data.muscles, group.id) end
	return math.floor(total / #Muscles.Groups)
end

local isOpen = false
local function open()
	if isOpen or UIBus.MenuOpen then return end
	local data = ClientData.Get()
	local dayOne = data.dayOne or { height = GrowthSpurts.StartHeight, level = 0 }
	local nowHeight = GrowthSpurts.GetHeight(data.growthSpurts)
	-- day one: the character at the day-one height (relative to now) and without muscle growth
	local before, beforeSize = copyCharacter((dayOne.height or GrowthSpurts.StartHeight) / nowHeight, true)
	local after, afterSize = copyCharacter(1, false)
	if not before or not after then return end
	local tallest = math.max(beforeSize.Y, afterSize.Y)
	show(beforeView, before, tallest)
	show(afterView, after, tallest)
	title.Text = player.DisplayName .. " · GYM ARC"
	beforeName.Text = "Day one"
	beforeInfo.Text = GrowthSpurts.FormatHeight(dayOne.height or GrowthSpurts.StartHeight) .. "  ·  Level " .. (dayOne.level or 0)
	afterName.Text = "Now"
	afterInfo.Text = GrowthSpurts.FormatHeight(nowHeight) .. "  ·  Level " .. averageLevel(data)
		.. (data.growthSpurts > 0 and ("  ·  Growth Spurt " .. data.growthSpurts) or "")
	isOpen = true
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(root, true)
end

local function close()
	if not isOpen then return end
	isOpen = false
	local tween = Theme.Fade(root, false)
	if tween then
		tween.Completed:Connect(function()
			if not isOpen then
				gui.Enabled = false
				for _, view in ipairs({ beforeView, afterView }) do
					for _, child in ipairs(view:GetChildren()) do
						if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
					end
				end
			end
		end)
	else
		gui.Enabled = false
	end
end
closeButton.Activated:Connect(close)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind)
	if kind == "OpenMirror" then open() end
end)
