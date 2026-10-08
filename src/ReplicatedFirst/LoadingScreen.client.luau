-- LoadingScreen: replaces Roblox's default loading screen from the very first frame with the game's own (owner, 9 Oct:
-- "make it as good as the genetics screen"): a dark room with one soft overhead light and faint chalk dust drifting
-- up through it, the GYM ARC title, and a BARBELL that loads as the game loads: bumper plates (the grade colors, the
-- heaviest inside) slide onto both sleeves pair by pair with a clank, a collar closes each sleeve, and when it is full the
-- bar is lifted with a little bounce before everything fades. Under it the step ("Loading the gym") and a short tip
-- that changes every few seconds.
-- It stays until MenuClient says the menu scene is ready (the LocalPlayer attribute "MenuReady"), then "Loading
-- players": the other players' body stage meshes (Shared.BodyStages) finish downloading, at most TIMING.Stages more.
-- Progress: game loaded, then MenuClient's "MenuLoad" attribute (0..1) while it streams the menu scene; between those
-- steps the bar creeps slowly so it never looks stuck.
-- This runs before ReplicatedStorage has replicated, so it can't read Shared.UI.Theme / UIFonts / Audio: the colors,
-- fonts and the clank below repeat their values (panel #0E0E10, text #FFFFFF, muted #B8B8BE, Oswald / Nunito, the
-- bumper plate colors, Config.Sounds.Clank's id).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LOOK = {
	Background = Color3.fromHex("#0E0E10"),
	Text = Color3.fromHex("#FFFFFF"),
	Muted = Color3.fromHex("#B8B8BE"),
	Steel = Color3.fromHex("#C9CCD2"),
	SteelDark = Color3.fromHex("#7E828A"),
	Heading = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Regular),
}
-- bumper plates, heaviest (inside, biggest) first: red, blue, yellow, green, white (Theme.Plates)
local PLATES = {
	{ color = "#D7262E", rim = "#8E1A1F", height = 1.0 },
	{ color = "#1F5FBF", rim = "#143E7C", height = 0.9 },
	{ color = "#E8C21C", rim = "#9A8113", height = 0.8 },
	{ color = "#2E9E4F", rim = "#1E6834", height = 0.7 },
	{ color = "#F4F1EA", rim = "#A9A59C", height = 0.6 },
}
local TIMING = {
	Follow = 5,       -- how fast the shown progress catches up with its target (per second)
	Creep = 0.14,     -- how far past the last step the bar may creep while waiting
	CreepTime = 4,    -- seconds to creep most of that way
	Lift = 0.45,      -- the bar is lifted when full
	Hold = 0.35,      -- then held this long before fading
	Fade = 0.45,
	GiveUp = 30,      -- after the game has loaded, never wait longer than this for the menu
	Stages = 8,       -- after the menu is ready, wait at most this long for the other players' body stage meshes
	Tip = 3.6,        -- seconds per tip
}
local CLANK_ID = "rbxassetid://9116750726" -- Config.Sounds.Clank (Metal Plate Impact)
local TIPS = {
	"Weak muscles grow the fastest.",
	"Pet Plates the gym cat for a little stamina.",
	"Every Growth Spurt makes you taller.",
	"Tap fast while lifting to get PUMPED.",
	"Click a friend while they lift to spot them.",
	"A shake refills your stamina in one go.",
	"The beach gym opens after your first Growth Spurt.",
	"Heavier plates, bigger gains.",
	"Balanced muscles grow a little faster.",
}

local function new(class, props, children)
	local instance = Instance.new(class)
	for key, value in pairs(props) do instance[key] = value end
	for _, child in ipairs(children or {}) do child.Parent = instance end
	return instance
end
local function round(radius) return new("UICorner", { CornerRadius = radius or UDim.new(0, 3) }) end

local camera = workspace.CurrentCamera
local compact = camera and camera.ViewportSize.Y > 1 and camera.ViewportSize.Y < 520
local S = if compact then 0.72 else 1 -- the barbell's size on short screens

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local backdrop = new("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = LOOK.Background, BorderSizePixel = 0, Parent = gui })

-- one soft overhead light: faint white ovals stacked inside each other (a smooth glow without an edge; never colored)
local light = new("Frame", { Name = "Light", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1, Parent = backdrop })
for i = 1, 22 do
	local k = i / 22
	new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95 * (1.08 - k), 1.15 * (1.08 - k)),
		BackgroundColor3 = LOOK.Text, BackgroundTransparency = 0.9945, BorderSizePixel = 0, Parent = light }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

-- chalk dust: a few faint specks drifting up through the light
local dust = {}
local rng = Random.new()
for i = 1, 26 do
	local size = rng:NextInteger(2, 4)
	local speck = new("Frame", { Name = "Dust", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = LOOK.Text,
		BackgroundTransparency = rng:NextNumber(0.7, 0.9), BorderSizePixel = 0, Parent = backdrop }, { round(UDim.new(1, 0)) })
	dust[i] = { frame = speck, x = rng:NextNumber(0.2, 0.8), y = rng:NextNumber(0, 1), speed = rng:NextNumber(0.012, 0.03),
		sway = rng:NextNumber(0.004, 0.012), phase = rng:NextNumber(0, math.pi * 2) }
end

local center = new("Frame", { Name = "Center", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(560 * S, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = backdrop }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function text(order, value, font, size, color, height, parent)
	return new("TextLabel", { LayoutOrder = order, Text = value, FontFace = font, TextSize = size, TextColor3 = color, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height), Parent = parent or center })
end
text(1, "GYM ARC", LOOK.Heading, if compact then 40 else 56, LOOK.Text, if compact then 48 else 66)
text(2, "Everyone starts tiny.", LOOK.Body, 16, LOOK.Muted, 20)
new("Frame", { LayoutOrder = 3, Size = UDim2.fromOffset(1, math.floor(18 * S)), BackgroundTransparency = 1, Parent = center })

------------------------------------------------------------------------
-- The barbell
------------------------------------------------------------------------
local BAR_W, BAR_H = math.floor(520 * S), math.max(4, math.floor(7 * S))
local PLATE_W, PLATE_H, PLATE_GAP = math.floor(14 * S), math.floor(92 * S), math.max(1, math.floor(2 * S))
local SLEEVE_W = #PLATES * (PLATE_W + PLATE_GAP) + math.floor(16 * S) -- room for every plate and the collar
local holder = new("Frame", { Name = "Barbell", LayoutOrder = 4, Size = UDim2.fromOffset(BAR_W, PLATE_H + 6), BackgroundTransparency = 1, Parent = center })
local barbell = new("Frame", { Name = "Lift", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder })
local mid = PLATE_H / 2 + 3
-- the shaft, with knurled grips
new("Frame", { Name = "Shaft", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(BAR_W / 2, mid), Size = UDim2.fromOffset(BAR_W - 2 * SLEEVE_W + 20, BAR_H),
	BackgroundColor3 = LOOK.Steel, BorderSizePixel = 0, Parent = barbell }, { round() })
for _, x in ipairs({ -0.17, 0.17 }) do
	new("Frame", { Name = "Grip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(BAR_W / 2 + x * BAR_W, mid), Size = UDim2.fromOffset(math.floor(64 * S), BAR_H),
		BackgroundColor3 = LOOK.SteelDark, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = barbell }, { round() })
end
-- the sleeves (thicker) with their inner stop
local sleeves = {}
for side = -1, 1, 2 do
	local x = if side < 0 then SLEEVE_W / 2 else BAR_W - SLEEVE_W / 2
	sleeves[side] = new("Frame", { Name = "Sleeve", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, mid), Size = UDim2.fromOffset(SLEEVE_W, math.floor(BAR_H * 1.8)),
		BackgroundColor3 = LOOK.Steel, BorderSizePixel = 0, Parent = barbell }, { round() })
	new("Frame", { Name = "Stop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(if side < 0 then SLEEVE_W + 2 else BAR_W - SLEEVE_W - 2, mid),
		Size = UDim2.fromOffset(math.floor(8 * S), math.floor(BAR_H * 3.2)), BackgroundColor3 = LOOK.Steel, BorderSizePixel = 0, Parent = barbell }, { round() })
end

-- where plate n (1 = inside) sits on a side, and where it slides in from (past the sleeve's end)
local function plateX(side: number, n: number): number
	local inner = if side < 0 then SLEEVE_W - 4 else BAR_W - SLEEVE_W + 4
	return inner + side * ((n - 0.5) * (PLATE_W + PLATE_GAP))
end
local function plate(side: number, n: number)
	local spec = PLATES[n]
	local h = math.floor(PLATE_H * spec.height)
	local outside = if side < 0 then -PLATE_W * 2 else BAR_W + PLATE_W * 2
	local frame = new("Frame", { Name = "Plate", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(outside, mid), Size = UDim2.fromOffset(PLATE_W, h),
		BackgroundColor3 = Color3.fromHex(spec.color), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = barbell }, {
		round(UDim.new(0, math.max(2, math.floor(4 * S)))),
		new("UIStroke", { Name = "Rim", Color = Color3.fromHex(spec.rim), Thickness = math.max(1, math.floor(2 * S)), Transparency = 1 }),
	})
	local info = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(frame, info, { Position = UDim2.fromOffset(plateX(side, n), mid), BackgroundTransparency = 0 }):Play()
	TweenService:Create(frame.Rim, TweenInfo.new(0.2), { Transparency = 0 }):Play()
end
local function clank(n: number)
	local sound = new("Sound", { SoundId = CLANK_ID, Volume = 0.22, PlaybackSpeed = 1.12 - n * 0.05 + rng:NextNumber(-0.03, 0.03), Parent = SoundService })
	sound:Play()
	task.delay(2, function() sound:Destroy() end)
end
local function collars()
	for side = -1, 1, 2 do
		local x = plateX(side, #PLATES) + side * (PLATE_W / 2 + math.floor(6 * S))
		local collar = new("Frame", { Name = "Collar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + side * 30, mid), Size = UDim2.fromOffset(math.floor(8 * S), math.floor(BAR_H * 3)),
			BackgroundColor3 = LOOK.SteelDark, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = barbell }, { round() })
		TweenService:Create(collar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(x, mid), BackgroundTransparency = 0 }):Play()
	end
end

local status = text(5, "Loading", LOOK.Body, 14, LOOK.Muted, 18)
local tip = text(6, "", LOOK.Body, 14, LOOK.Muted, 18)
tip.TextTransparency = 0.35
gui.Parent = playerGui

------------------------------------------------------------------------
-- Progress
------------------------------------------------------------------------
local shown = 0
local loaded = 0 -- plates on each side
local lastPlate = 0
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
	if type(value) == "number" then setStep(0.55 + 0.35 * math.clamp(value, 0, 1), "Loading the gym") end -- (the last 10%: the body stages)
end
player:GetAttributeChangedSignal("MenuLoad"):Connect(menuProgress)

-- The other players' body stage meshes (Shared.BodyStages) download in small batches behind this screen, so they are in
-- before you see anyone (owner, 8 Oct night: fewer "could not fetch" misses); requiring the module starts the download.
local BodyStages = nil
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	loadedAt = os.clock()
	setStep(0.55, "Loading the gym")
	menuProgress()
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10)
	local module = shared and shared:WaitForChild("BodyStages", 10)
	if module then
		local ok, result = pcall(require, module)
		if ok then BodyStages = result end
	end
end)

-- tips: one at a time, faded in and out
task.spawn(function()
	local order = {}
	for i = 1, #TIPS do order[i] = i end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local index = 0
	while gui.Parent do
		index = index % #order + 1
		tip.Text = TIPS[order[index]]
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0.35 }):Play()
		task.wait(TIMING.Tip)
		if not gui.Parent then break end
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.3)
	end
end)

local done = false
local finishing = false
local function finish()
	if done or finishing then return end
	finishing = true
	-- the menu is ready: give the body stage meshes a few more seconds (the last plates show their download)
	if BodyStages then
		status.Text = "Loading players"
		local deadline = os.clock() + TIMING.Stages
		while not BodyStages.WaitReady(0.1) and os.clock() < deadline and gui.Parent do
			setStep(0.9 + 0.09 * BodyStages.Progress())
		end
	end
	done = true
	setStep(1)
	-- wait for the last plates, close the collars, lift the bar, then fade everything
	while loaded < #PLATES and gui.Parent do RunService.Heartbeat:Wait() end
	task.wait(0.2)
	collars()
	clank(#PLATES)
	task.wait(0.3)
	TweenService:Create(barbell, TweenInfo.new(TIMING.Lift, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, -math.floor(26 * S)) }):Play()
	status.Text = "Let's lift"
	task.wait(TIMING.Lift + TIMING.Hold)
	local info = TweenInfo.new(TIMING.Fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, item in ipairs(gui:GetDescendants()) do
		if item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1 }):Play()
		elseif item:IsA("Frame") and item.BackgroundTransparency < 1 then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		elseif item:IsA("UIGradient") then
			item.Parent.Visible = false -- (the light: a gradient's frame fades badly, it just goes)
		end
	end
	task.delay(TIMING.Fade, function() gui:Destroy() end)
end

if player:GetAttribute("MenuReady") then task.spawn(finish) end
player:GetAttributeChangedSignal("MenuReady"):Connect(function()
	if player:GetAttribute("MenuReady") then task.spawn(finish) end
end)

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not gui.Parent then
		connection:Disconnect()
		return
	end
	if loadedAt and not done and os.clock() - loadedAt > TIMING.GiveUp then task.spawn(finish) end
	-- creep a little past the last step while waiting, then follow the target smoothly
	local creep = if step < 1 then TIMING.Creep * (1 - math.exp(-(os.clock() - stepAt) / TIMING.CreepTime)) else 0
	local target = math.min(step + creep, 1)
	shown += (target - shown) * math.min(1, dt * TIMING.Follow)
	if step >= 1 and target - shown < 0.01 then shown = 1 end
	-- a pair of plates for every fifth of the way (never more than one pair at a time, so each clank is heard)
	local want = math.clamp(math.floor(shown * #PLATES + 0.02), 0, #PLATES)
	if want > loaded and os.clock() - lastPlate >= 0.22 then
		lastPlate = os.clock()
		loaded += 1
		plate(-1, loaded)
		plate(1, loaded)
		clank(loaded)
	end
	-- chalk dust drifting up
	local t = os.clock()
	for _, speck in ipairs(dust) do
		speck.y -= speck.speed * dt
		if speck.y < -0.02 then speck.y, speck.x = 1.02, rng:NextNumber(0.2, 0.8) end
		speck.frame.Position = UDim2.fromScale(speck.x + math.sin(t * 0.6 + speck.phase) * speck.sway, speck.y)
	end
end)
