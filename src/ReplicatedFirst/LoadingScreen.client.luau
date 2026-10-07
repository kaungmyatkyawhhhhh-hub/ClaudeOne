-- LoadingScreen: replaces Roblox's default loading screen from the very first frame with the game's own: dark, the
-- GYM ARC title and a small segmented progress bar. It stays until MenuClient says the menu scene is ready (the
-- LocalPlayer attribute "MenuReady", after the area behind the menu has streamed in), then fades out.
-- Progress: game loaded, then MenuClient's "MenuLoad" attribute (0..1) while it streams the menu scene; between those
-- steps the bar creeps slowly so it never looks stuck.
-- This runs before ReplicatedStorage has replicated, so it can't read Shared.UI.Theme / UIFonts: the few colors and
-- fonts below repeat Theme's values (panel #0E0E10, text #FFFFFF, muted #B8B8BE, Oswald / Nunito).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LOOK = {
	Background = Color3.fromHex("#0E0E10"),
	Text = Color3.fromHex("#FFFFFF"),
	Muted = Color3.fromHex("#B8B8BE"),
	Heading = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Regular),
}
local BAR = { Segments = 10, Width = 18, Height = 8, Gap = 4, EmptyAlpha = 0.85 }
local TIMING = {
	Follow = 6,       -- how fast the bar catches up with its target (per second)
	Creep = 0.14,     -- how far past the last step the bar may creep while waiting
	CreepTime = 4,    -- seconds to creep most of that way
	Hold = 0.15,      -- full bar shown this long before fading
	Fade = 0.4,
	GiveUp = 30,      -- after the game has loaded, never wait longer than this for the menu
}

local function new(class, props, children)
	local instance = Instance.new(class)
	for key, value in pairs(props) do instance[key] = value end
	for _, child in ipairs(children or {}) do child.Parent = instance end
	return instance
end

local camera = workspace.CurrentCamera
local compact = camera and camera.ViewportSize.Y > 1 and camera.ViewportSize.Y < 520

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local backdrop = new("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = LOOK.Background, BorderSizePixel = 0, Parent = gui })
local center = new("Frame", { Name = "Center", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = backdrop }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function text(order, value, font, size, color, height)
	return new("TextLabel", { LayoutOrder = order, Text = value, FontFace = font, TextSize = size, TextColor3 = color, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), Parent = center })
end
text(1, "GYM ARC", LOOK.Heading, compact and 40 or 56, LOOK.Text, compact and 48 or 66)
text(2, "Everyone starts tiny.", LOOK.Body, 16, LOOK.Muted, 20)
new("Frame", { LayoutOrder = 3, Size = UDim2.fromOffset(1, 12), BackgroundTransparency = 1, Parent = center })

-- the bar: chunky segments like stacked plates, each filling left to right
local barWidth = BAR.Segments * BAR.Width + (BAR.Segments - 1) * BAR.Gap
local bar = new("Frame", { Name = "Bar", LayoutOrder = 4, Size = UDim2.fromOffset(barWidth, BAR.Height), BackgroundTransparency = 1, Parent = center }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, BAR.Gap), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local fills = {}
for i = 1, BAR.Segments do
	local segment = new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(BAR.Width, BAR.Height), BackgroundColor3 = LOOK.Text, BackgroundTransparency = BAR.EmptyAlpha, BorderSizePixel = 0, ClipsDescendants = true, Parent = bar }, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	})
	fills[i] = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = LOOK.Text, BorderSizePixel = 0, Parent = segment }, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	})
end
local status = text(5, "Loading", LOOK.Body, 14, LOOK.Muted, 18)
gui.Parent = playerGui

------------------------------------------------------------------------
-- Progress
------------------------------------------------------------------------
local shown = 0
local step, stepAt = 0.05, os.clock()
local loadedAt = nil

local function setStep(value: number, label: string?)
	if value > step then
		step, stepAt = value, os.clock()
	end
	if label then status.Text = label end
end

local function menuProgress()
	local value = player:GetAttribute("MenuLoad")
	if type(value) == "number" then setStep(0.55 + 0.45 * math.clamp(value, 0, 1), "Loading the gym") end
end
player:GetAttributeChangedSignal("MenuLoad"):Connect(menuProgress)

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	loadedAt = os.clock()
	setStep(0.55, "Loading the gym")
	menuProgress()
end)

local done = false
local function finish()
	if done then return end
	done = true
	setStep(1)
	task.delay(math.max(0.25, 1 / TIMING.Follow) + TIMING.Hold, function()
		local info = TweenInfo.new(TIMING.Fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local last
		for _, item in ipairs(gui:GetDescendants()) do
			if item:IsA("TextLabel") then
				last = TweenService:Create(item, info, { TextTransparency = 1 })
				last:Play()
			elseif item:IsA("Frame") and item.BackgroundTransparency < 1 then
				last = TweenService:Create(item, info, { BackgroundTransparency = 1 })
				last:Play()
			end
		end
		task.delay(TIMING.Fade, function() gui:Destroy() end)
	end)
end

if player:GetAttribute("MenuReady") then finish() end
player:GetAttributeChangedSignal("MenuReady"):Connect(function()
	if player:GetAttribute("MenuReady") then finish() end
end)

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not gui.Parent then
		connection:Disconnect()
		return
	end
	if loadedAt and not done and os.clock() - loadedAt > TIMING.GiveUp then finish() end
	-- creep a little past the last step while waiting, then follow the target smoothly
	local creep = if step < 1 then TIMING.Creep * (1 - math.exp(-(os.clock() - stepAt) / TIMING.CreepTime)) else 0
	local target = math.min(step + creep, 1)
	shown += (target - shown) * math.min(1, dt * TIMING.Follow)
	if step >= 1 and target - shown < 0.01 then shown = 1 end
	for i, fill in ipairs(fills) do
		fill.Size = UDim2.fromScale(math.clamp(shown * BAR.Segments - (i - 1), 0, 1), 1)
	end
end)
