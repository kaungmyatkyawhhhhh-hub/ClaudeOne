-- LoadingScreen: replaces Roblox's default loading screen from the very first frame (owner's UI v2, mockup 00_loading).
-- Black, with the menu art (UI.MenuArt) on the right fading into the dark on its left and a dim, soft copy of it behind
-- everything; the GYM ARC logo (GYM white, ARC red, FredokaOne with a thick black outline), "Everyone starts tiny.", a
-- rotating tip ("TIP:" in gold, Config/UI.LoadingTips), and at the bottom a red progress bar with the step in it
-- ("Loading muscles... 64%"). SKIP shows top right after 5 seconds (straight to the menu). It fades into the menu.
-- Steps (the bar): the game itself (to 30%), "Loading muscles" = ContentProvider:PreloadAsync of the UI images (icons,
-- art, trainer portraits; to 55%), "Loading the gym" = your save data and the world around you (MenuClient's MenuLoad
-- attribute 0..1, to 90%), "Loading players" = the other players' body stage meshes (Shared.BodyStages, to 100%, at most
-- TIMING.Stages seconds). Between steps the bar creeps a little so it never looks stuck.
-- This starts before ReplicatedStorage has replicated, so the colors, fonts, the art id and a few tips are repeated here
-- (Theme: background #0C0A0C, red #EE3A42, gold #FFC93C; FredokaOne; UI.MenuArt); the full tip list is read once it's in.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LOOK = {
	Background = Color3.fromHex("#0C0A0C"),
	Text = Color3.fromHex("#FFFFFF"),
	Red = Color3.fromHex("#EE3A42"),
	Gold = Color3.fromHex("#FFC93C"),
	Outline = Color3.fromHex("#0D0D12"),
	Track = Color3.fromHex("#1B171A"),
	Display = Font.fromEnum(Enum.Font.FredokaOne),
	Art = "rbxassetid://99238211044120", -- Config/UI.MenuArt
}
local TIMING = { Skip = 5, Tip = 4.5, Fade = 0.5, Stages = 8, GiveUp = 25, Creep = 0.08, CreepTime = 6, Follow = 4 }
local TIPS = {
	"Spot other players on their lifts to earn coins!",
	"Tap fast while lifting to fill PUMP: pumped reps grow twice as much.",
	"Weak muscles grow fastest. Train the group that needs work.",
}
local BASE = Vector2.new(844, 390) -- the mockups' phone screen (Kit.Base)

local function new(class, props, children)
	local instance = Instance.new(class)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then (instance :: any)[key] = value end
	end
	for _, child in ipairs(children or {}) do child.Parent = instance end
	if props and props.Parent then instance.Parent = props.Parent end
	return instance
end
local function outlined(props)
	local thickness = props.Stroke or 2
	props.Stroke = nil
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or LOOK.Display
	props.TextColor3 = props.TextColor3 or LOOK.Text
	local label = new("TextLabel", props)
	new("UIStroke", { Color = LOOK.Outline, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	return label
end

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
local back = new("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = LOOK.Background, BorderSizePixel = 0, Parent = gui })
-- the soft copy of the art behind everything (dim, big)
new("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = LOOK.Art, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.9, ImageColor3 = Color3.fromRGB(110, 90, 90),
	Size = UDim2.fromScale(1, 1), Parent = back })
-- the art on the right, fading into the dark on its left
local art = new("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = LOOK.Art, ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.62, 1), Parent = back }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 0.2),
		NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0) }) }),
})

-- everything else in mockup px (scaled like Kit.Root: the shorter side / 390, never wider than the 844px layout)
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
local scale = new("UIScale", { Parent = root })
local function rescale()
	local size = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local s = math.max(0.5, math.min(size.Y / BASE.Y, size.X / BASE.X))
	scale.Scale = s
	root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
end
rescale()
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

-- the logo
local logo = new("Frame", { Name = "Logo", BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 62), Size = UDim2.fromOffset(380, 82), Parent = root }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }),
})
outlined({ Name = "Gym", LayoutOrder = 1, Text = "GYM", TextSize = 78, Size = UDim2.fromOffset(0, 82), AutomaticSize = Enum.AutomaticSize.X, Stroke = 4, Parent = logo })
outlined({ Name = "Arc", LayoutOrder = 2, Text = "ARC", TextSize = 78, TextColor3 = LOOK.Red, Size = UDim2.fromOffset(0, 82), AutomaticSize = Enum.AutomaticSize.X, Stroke = 4, Parent = logo })
outlined({ Name = "Tagline", Text = "Everyone starts tiny.", TextSize = 18, Position = UDim2.fromOffset(46, 146), Size = UDim2.fromOffset(330, 24),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
local tip = outlined({ Name = "Tip", Text = "", RichText = true, TextSize = 15, TextWrapped = true, Position = UDim2.fromOffset(46, 228), Size = UDim2.fromOffset(310, 44),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = root })

-- the progress bar
local bar = new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(1, -92, 0, 24),
	BackgroundColor3 = LOOK.Track, Parent = root }, {
	new("UICorner", { CornerRadius = UDim.new(0, 7) }),
	new("UIStroke", { Color = LOOK.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, {
	new("UICorner", { CornerRadius = UDim.new(0, 7) }),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(LOOK.Red:Lerp(Color3.new(1, 1, 1), 0.2), LOOK.Red:Lerp(Color3.new(0, 0, 0), 0.15)) }),
})
local status = outlined({ Name = "Status", Text = "Loading the game... 0%", TextSize = 15, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = bar })

local skip = new("TextButton", { Name = "Skip", Text = "SKIP", FontFace = LOOK.Display, TextSize = 16, TextColor3 = LOOK.Text, AutoButtonColor = true,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(84, 32), BackgroundColor3 = Color3.fromHex("#2E2E36"),
	Visible = false, Parent = root }, {
	new("UICorner", { CornerRadius = UDim.new(0, 8) }),
	new("UIStroke", { Color = Color3.fromHex("#6A6A76"), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
new("UIStroke", { Color = LOOK.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = skip })

------------------------------------------------------------------------
-- Progress
------------------------------------------------------------------------
local step, stepAt, shown = 0, os.clock(), 0
local label = "Loading the game"
local updating = false
local loadedAt = nil
local function setStep(value: number, text: string?)
	if value > step then
		step, stepAt = value, os.clock()
	end
	if text and not updating then label = text end
end

-- Soft shutdown (ShutdownService): the game was updated and this is the short stop on the way to a new server. The game
-- never loads here, so the screen stays and says why until the teleport takes over.
local function checkUpdating()
	if updating or Workspace:GetAttribute("SoftShutdown") ~= true then return end
	updating = true
	label = "Updating the gym"
	tip.Text = "Taking you to the new version. Your progress is saved."
	setStep(0.9)
end
Workspace:GetAttributeChangedSignal("SoftShutdown"):Connect(checkUpdating)
checkUpdating()

local function menuProgress()
	local value = player:GetAttribute("MenuLoad")
	if type(value) == "number" and step >= 0.55 then setStep(0.55 + 0.35 * math.clamp(value, 0, 1), "Loading the gym") end
end
player:GetAttributeChangedSignal("MenuLoad"):Connect(menuProgress)

-- the game, then the UI images, then (MenuClient) the gym; the other players' body stage meshes download behind it all
local BodyStages = nil
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	checkUpdating()
	loadedAt = os.clock()
	setStep(0.3, "Loading muscles")
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10)
	local config = shared and shared:WaitForChild("Config", 10)
	local uiModule = config and config:WaitForChild("UI", 10)
	local ok, UI = pcall(require, uiModule)
	if ok and type(UI) == "table" then
		if type(UI.LoadingTips) == "table" and #UI.LoadingTips > 0 then TIPS = UI.LoadingTips end
		-- preload the UI images (every icon, the art, the trainer portraits): the bar follows them
		local list = {}
		for _, group in ipairs({ UI.Icons or {}, UI.Trainers or {}, UI.ShopIcons or {} }) do
			for _, id in pairs(group) do
				table.insert(list, new("ImageLabel", { Image = id }))
			end
		end
		table.insert(list, new("ImageLabel", { Image = UI.MenuArt or LOOK.Art }))
		local done = 0
		pcall(function()
			ContentProvider:PreloadAsync(list, function()
				done += 1
				setStep(0.3 + 0.25 * done / math.max(#list, 1))
			end)
		end)
	end
	setStep(0.55, "Loading the gym")
	menuProgress()
	local module = shared and shared:WaitForChild("BodyStages", 10)
	if module then
		local okStages, result = pcall(require, module)
		if okStages then BodyStages = result end
	end
end)

-- tips: one at a time, faded in and out
task.spawn(function()
	local rng = Random.new()
	local index = rng:NextInteger(1, #TIPS)
	while gui.Parent do
		index = index % #TIPS + 1
		tip.Text = if updating then "Taking you to the new version. Your progress is saved."
			else ('<font color="#' .. LOOK.Gold:ToHex() .. '">TIP:</font> ' .. TIPS[index])
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.wait(TIMING.Tip)
		if not gui.Parent then break end
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.3)
	end
end)

local done, finishing = false, false
local function fadeOut()
	if done then return end
	done = true
	player:SetAttribute("LoadingDone", true)
	local info = TweenInfo.new(TIMING.Fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, item in ipairs(gui:GetDescendants()) do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			TweenService:Create(item, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, info, { ImageTransparency = 1 }):Play()
		elseif item:IsA("Frame") and item.BackgroundTransparency < 1 then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(TIMING.Fade, function() gui:Destroy() end)
end
local function finish()
	if done or finishing then return end
	finishing = true
	-- the menu is ready: give the body stage meshes a few more seconds
	if BodyStages then
		label = "Loading players"
		local deadline = os.clock() + TIMING.Stages
		while not done and not BodyStages.WaitReady(0.1) and os.clock() < deadline and gui.Parent do
			setStep(0.9 + 0.09 * BodyStages.Progress())
		end
	end
	setStep(1)
	while not done and shown < 0.995 and gui.Parent do RunService.Heartbeat:Wait() end
	if done then return end
	label = "Let's lift"
	task.wait(0.35)
	fadeOut()
end

if player:GetAttribute("MenuReady") then task.spawn(finish) end
player:GetAttributeChangedSignal("MenuReady"):Connect(function()
	if player:GetAttribute("MenuReady") then task.spawn(finish) end
end)

-- SKIP after a few seconds: straight to the menu (it keeps loading behind it)
task.delay(TIMING.Skip, function()
	if gui.Parent and not done and not updating then skip.Visible = true end
end)
skip.Activated:Connect(fadeOut)

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not gui.Parent then
		connection:Disconnect()
		return
	end
	if loadedAt and not finishing and os.clock() - loadedAt > TIMING.GiveUp then task.spawn(finish) end
	-- creep a little past the last step while waiting, then follow the target smoothly
	local creep = if step < 1 then TIMING.Creep * (1 - math.exp(-(os.clock() - stepAt) / TIMING.CreepTime)) else 0
	local target = math.min(step + creep, 1)
	shown += (target - shown) * math.min(1, dt * TIMING.Follow)
	if step >= 1 and target - shown < 0.01 then shown = 1 end
	fill.Size = UDim2.fromScale(math.max(shown, 0.02), 1)
	status.Text = if label == "Let's lift" then label else string.format("%s... %d%%", label, math.floor(shown * 100))
end)
