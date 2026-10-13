-- PhotoModeClient (owner's feature run, task 7D): photo mode at the mirrors and the posing stage (Config/PhotoMode).
--   * Near a photo spot a PHOTO button (camera icon) shows in the right column.
--   * Photo mode: every other screen hides (and Roblox's own buttons), your character stands still, the camera turns
--     around you (drag with mouse or finger) and zooms (mouse wheel or pinch). A row of poses at the bottom (the same
--     poses as the Poses panel, everyone sees them). HIDE UI clears the screen for a screenshot; after that a tap or
--     click anywhere ends photo mode. EXIT (X) ends it too, and so does dying.
--   * Client only: nothing is saved, the poses go through the normal Emote remote.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhotoMode = require(Shared.Config.PhotoMode)
local ShowOff = require(Shared.Config.ShowOff)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local RightColumn = require(Shared.UI.RightColumn)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Horizontal = Enum.FillDirection.Horizontal
local emoteRemote = Remotes:WaitForChild("Emote", 30) :: RemoteEvent?

------------------------------------------------------------------------
-- The PHOTO button (right column, only near a photo spot)
------------------------------------------------------------------------
local photoButton = Theme.Button("Secondary", { Name = "Photo", Size = UDim2.new(1, 0, 0, Theme.MinTouch), Visible = false }, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local photoIconSlot = New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = photoButton })
Icons.Camera(Colors.Text).Parent = photoIconSlot
Theme.Text({ LayoutOrder = 2, Text = "Photo", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Parent = photoButton })
RightColumn.Add(photoButton, 0, true)

------------------------------------------------------------------------
-- Photo mode screen
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "PhotoMode", Enabled = false, DisplayOrder = 60, Parent = playerGui })
local safe = Theme.SafeArea(gui)

local topRow = New("Frame", { Name = "Top", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -Spacing.L, 0, Spacing.L),
	Size = UDim2.fromOffset(0, Theme.MinTouch), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = safe },
	{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
local hideButton = Theme.Button("Secondary", { Name = "HideUI", LayoutOrder = 1, Size = UDim2.fromOffset(120, Theme.MinTouch), Parent = topRow }, {
	Theme.Text({ Text = "Hide UI", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local exitButton = Theme.Button("Secondary", { Name = "Exit", LayoutOrder = 2, Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = topRow }, {})
local exitIcon = New("Frame", { Size = UDim2.fromScale(0.42, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = exitButton })
Icons.Close(Colors.Text).Parent = exitIcon

local title = Theme.Text({ Name = "Title", Text = "Photo mode", Font = "SemiBold", TextSize = "Large", Position = UDim2.fromOffset(Spacing.L, Spacing.L),
	Size = UDim2.fromOffset(240, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = safe })
Theme.TextShadow(title)
local hint = Theme.Text({ Name = "Hint", Text = "Drag to turn the camera. Scroll or pinch to zoom.", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted,
	Position = UDim2.fromOffset(Spacing.L, Spacing.L + 28), Size = UDim2.fromOffset(360, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = safe })
Theme.TextShadow(hint)

-- the poses (a row that scrolls sideways on small screens)
local poseBar = Theme.Panel({ Name = "Poses", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -Spacing.L),
	Size = UDim2.new(1, -Spacing.XL * 2, 0, Theme.MinTouch + Spacing.S * 2), Parent = safe }, {})
New("UISizeConstraint", { MaxSize = Vector2.new(980, 200), Parent = poseBar })
local scroller = New("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.fromScale(0, 0), Parent = poseBar }, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
local function poseChip(order, name, id)
	local chip = Theme.Button("Secondary", { Name = id ~= "" and id or "Relax", LayoutOrder = order, Size = UDim2.fromOffset(0, Theme.MinTouch), AutomaticSize = Enum.AutomaticSize.X, Parent = scroller }, {
		Theme.Pad("M"),
		Theme.Text({ Text = name, Font = "SemiBold", TextSize = "Small", Size = UDim2.fromOffset(0, Theme.MinTouch), AutomaticSize = Enum.AutomaticSize.X }),
	})
	-- (Theme.Pad adds top/bottom padding too: keep the label centered in the 44px chip)
	local pad = chip:FindFirstChildOfClass("UIPadding")
	if pad then pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0) end
	chip.Activated:Connect(function()
		if emoteRemote then emoteRemote:FireServer(id) end
	end)
end
poseChip(0, "Relax", "")
for order, emote in ipairs(ShowOff.Emotes) do poseChip(order, emote.name, emote.id) end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
-- (the camera ray ignores characters, NPCs and trainers, and see-through glass is not a wall)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function refreshRay()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	for _, name in ipairs({ "NPCs", "LocalTrainers" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then table.insert(list, folder) end
	end
	rayParams.FilterDescendantsInstances = list
end
local active = false
local uiHidden = false
local hiddenAt = 0
local yaw, pitch, distance = 0, PhotoMode.Pitch.Start, PhotoMode.Distance.Start
local dragging = nil -- the InputObject turning the camera
local hiddenGuis = {} -- ScreenGuis this hid (shown again on exit)
local coreState = {} -- [CoreGuiType] = was it on

-- you stand still in photo mode (the same freeze as the genetics screen: walking and jumping input is swallowed)
local function freeze()
	return Enum.ContextActionResult.Sink
end

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- the closest point of a part / model's box to `point`
local function distanceTo(inst: Instance, point: Vector3): number
	local cframe, size
	if inst:IsA("Model") then
		cframe, size = inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		cframe, size = inst.CFrame, inst.Size
	else
		return math.huge
	end
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size / 2
	local clamped = Vector3.new(math.clamp(localPoint.X, -half.X, half.X), math.clamp(localPoint.Y, -half.Y, half.Y), math.clamp(localPoint.Z, -half.Z, half.Z))
	return (localPoint - clamped).Magnitude
end

-- every instance at this path (several can share a name: the starter gym has two mirror panels)
local function findAll(path: string): { Instance }
	local nodes: { Instance } = { Workspace }
	for name in string.gmatch(path, "[^%.]+") do
		local nextNodes = {}
		for _, node in ipairs(nodes) do
			for _, child in ipairs(node:GetChildren()) do
				if child.Name == name then table.insert(nextNodes, child) end
			end
		end
		nodes = nextNodes
	end
	return nodes
end

local function nearSpot(): boolean
	local root = rootPart()
	if not root then return false end
	for _, spot in ipairs(PhotoMode.Spots) do
		for _, inst in ipairs(findAll(spot.path)) do
			if distanceTo(inst, root.Position) <= spot.range then return true end
		end
	end
	return false
end

local function setPhotoUi(visible: boolean)
	for _, item in ipairs({ topRow, title, hint, poseBar }) do item.Visible = visible end
end

-- every screen but this one hides (checked every frame: other scripts may switch theirs on meanwhile)
local function hideOtherGuis()
	for _, other in ipairs(playerGui:GetChildren()) do
		if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
			other.Enabled = false
			hiddenGuis[other] = true
		end
	end
end

local function exitPhoto()
	if not active then return end
	active = false
	dragging = nil
	RunService:UnbindFromRenderStep("PhotoModeCamera")
	local camera = Workspace.CurrentCamera
	if camera then camera.CameraType = Enum.CameraType.Custom end
	for other in pairs(hiddenGuis) do
		if other.Parent then other.Enabled = true end
	end
	hiddenGuis = {}
	for coreType, was in pairs(coreState) do pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, was) end
	coreState = {}
	ContextActionService:UnbindAction("PhotoModeFreeze")
	ProximityPromptService.Enabled = true
	player:SetAttribute("PhotoMode", nil)
	if emoteRemote then emoteRemote:FireServer("") end -- let go of the pose
	gui.Enabled = false
	Audio.PlayUI("Whoosh")
end

local function enterPhoto()
	local root = rootPart()
	local camera = Workspace.CurrentCamera
	if active or not root or not camera then return end
	active = true
	uiHidden = false
	UIBus.CloseAllPanels()
	ContextActionService:BindActionAtPriority("PhotoModeFreeze", freeze, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero) end
	-- no prompts or machine signs in the picture (MachineSignsClient reads the attribute; it stays on this client)
	ProximityPromptService.Enabled = false
	player:SetAttribute("PhotoMode", true)
	for _, coreType in ipairs({ Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health }) do
		local ok, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
		if ok then
			coreState[coreType] = was
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
		end
	end
	-- start from where the camera looks now, a little to the side (at a mirror you face the glass: a camera in front of
	-- you would be inside the wall, this one sees you and your reflection)
	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z) + math.rad(25)
	pitch, distance = PhotoMode.Pitch.Start, PhotoMode.Distance.Start
	refreshRay()
	setPhotoUi(true)
	gui.Enabled = true
	hideOtherGuis()
	Audio.PlayUI("Whoosh")
	RunService:BindToRenderStep("PhotoModeCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local r = rootPart()
		if not r then exitPhoto() return end
		hideOtherGuis()
		camera.CameraType = Enum.CameraType.Scriptable
		local focus = r.Position + Vector3.new(0, PhotoMode.FocusHeight, 0)
		local orbit = CFrame.new(focus) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)
		-- never inside a wall or a machine: stop just in front of whatever is between you and the camera
		local wanted = orbit * CFrame.new(0, 0, distance)
		local hit = Workspace:Raycast(focus, wanted.Position - focus, rayParams)
		local reach = hit and math.max(PhotoMode.Distance.Min * 0.5, (hit.Position - focus).Magnitude - 0.6) or distance
		camera.CFrame = orbit * CFrame.new(0, 0, reach)
	end)
end

photoButton.Activated:Connect(enterPhoto)
exitButton.Activated:Connect(exitPhoto)
hideButton.Activated:Connect(function()
	uiHidden = true
	hiddenAt = os.clock()
	setPhotoUi(false)
end)

------------------------------------------------------------------------
-- Input: drag to turn, wheel / pinch to zoom, a tap ends it once the UI is hidden
------------------------------------------------------------------------
local function zoom(by: number)
	distance = math.clamp(distance + by, PhotoMode.Distance.Min, PhotoMode.Distance.Max)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not active then return end
	local isPointer = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.Touch
	if uiHidden then
		-- (not the click that pressed HIDE UI)
		if (isPointer or input.UserInputType == Enum.UserInputType.Keyboard) and os.clock() - hiddenAt > 0.3 then exitPhoto() end
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then exitPhoto() return end
	if processed then return end -- (a button)
	if isPointer and not dragging then dragging = input end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if not active then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not processed then zoom(-input.Position.Z * PhotoMode.ZoomStep) end
		return
	end
	if not dragging then return end
	local mouseDrag = input.UserInputType == Enum.UserInputType.MouseMovement and dragging.UserInputType ~= Enum.UserInputType.Touch
	if mouseDrag or input == dragging then
		yaw -= input.Delta.X * PhotoMode.DragSpeed
		pitch = math.clamp(pitch + input.Delta.Y * PhotoMode.DragSpeed, PhotoMode.Pitch.Min, PhotoMode.Pitch.Max)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == dragging or (dragging and dragging.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == dragging.UserInputType) then dragging = nil end
end)

UserInputService.TouchPinch:Connect(function(_, scale, _, state)
	if not active or uiHidden then return end
	if state == Enum.UserInputState.Change and scale > 0 then
		dragging = nil -- (two fingers: zooming, not turning)
		distance = math.clamp(distance / (1 + (scale - 1) * 0.08), PhotoMode.Distance.Min, PhotoMode.Distance.Max)
	end
end)

player.CharacterAdded:Connect(function() exitPhoto() end)

------------------------------------------------------------------------
-- Show the PHOTO button near a spot
------------------------------------------------------------------------
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.4 then return end
	acc = 0
	local show = not active and not UIBus.MenuOpen and not UIBus.Training and nearSpot()
	if photoButton.Visible ~= show then photoButton.Visible = show end
end)

-- Studio: the Workspace attribute TestPhotoMode (true) opens photo mode wherever you are (for screenshots)
if RunService:IsStudio() then
	Workspace:GetAttributeChangedSignal("TestPhotoMode"):Connect(function()
		if Workspace:GetAttribute("TestPhotoMode") == true then enterPhoto() else exitPhoto() end
	end)
end
