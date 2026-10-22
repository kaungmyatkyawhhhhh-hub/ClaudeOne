-- TownClient: the gym's glass entrance doors slide open while anyone stands near them (tag "SlidingDoor", the slide
-- distance is each panel's SlideX attribute; TownService turned their collisions off). Animated locally on every
-- client, so it costs no network.
-- (prompt 51) The PUMP SHOP's small motion, also local: models tagged "ShopSpin" turn slowly round their pivot (attribute
-- SpinSpeed, degrees a second: the giant tub, the DNA helix), lights and neon parts tagged "ShopPulse" glow up and down.
-- Only while the camera is within MOTION_RANGE studs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local OPEN_RANGE = 9  -- studs from the doors
local SPEED = 3       -- open/close per second (0 → 1)

local closed = {} -- [panel] = closed CFrame
local amount = 0  -- 0 closed, 1 open

local function track(panel)
	if panel:IsA("BasePart") then closed[panel] = panel.CFrame end
end
for _, panel in ipairs(CollectionService:GetTagged("SlidingDoor")) do track(panel) end
CollectionService:GetInstanceAddedSignal("SlidingDoor"):Connect(track)
CollectionService:GetInstanceRemovedSignal("SlidingDoor"):Connect(function(panel) closed[panel] = nil end)

local function someoneNear()
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - Town.EntranceDoor).Magnitude < OPEN_RANGE then return true end
	end
	return false
end

local MOTION_RANGE = 80
local spinning = {} -- [model] = { base = CFrame, speed = degrees a second }
local pulsing = {}  -- [light or neon part] = its normal Brightness / Transparency
local function trackSpin(model)
	if model:IsA("Model") then spinning[model] = { base = model:GetPivot(), speed = model:GetAttribute("SpinSpeed") or 20 } end
end
local function trackPulse(item)
	if item:IsA("Light") then pulsing[item] = item.Brightness elseif item:IsA("BasePart") then pulsing[item] = item.Transparency end
end
for _, model in ipairs(CollectionService:GetTagged("ShopSpin")) do trackSpin(model) end
for _, item in ipairs(CollectionService:GetTagged("ShopPulse")) do trackPulse(item) end
CollectionService:GetInstanceAddedSignal("ShopSpin"):Connect(trackSpin)
CollectionService:GetInstanceAddedSignal("ShopPulse"):Connect(trackPulse)
CollectionService:GetInstanceRemovedSignal("ShopSpin"):Connect(function(model) spinning[model] = nil end)
CollectionService:GetInstanceRemovedSignal("ShopPulse"):Connect(function(item) pulsing[item] = nil end)

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	local camera = workspace.CurrentCamera
	if not camera or (next(spinning) == nil and next(pulsing) == nil) then return end
	local eye = camera.CFrame.Position
	for model, spin in pairs(spinning) do
		local at = spin.base.Position
		if model.Parent and (at - eye).Magnitude < MOTION_RANGE then
			-- round the world's up axis through the pivot (a cylinder part's own axes are turned)
			model:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(clock * spin.speed % 360), 0) * CFrame.new(-at) * spin.base)
		end
	end
	local wave = 0.5 + 0.5 * math.sin(clock * 2.4)
	for item, normal in pairs(pulsing) do
		local holder = if item:IsA("Light") then item.Parent else item
		if holder and holder:IsA("BasePart") and (holder.Position - eye).Magnitude < MOTION_RANGE then
			if item:IsA("Light") then
				item.Brightness = normal * (0.55 + 0.45 * wave)
			else
				item.Transparency = normal + 0.35 * (1 - wave)
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if next(closed) == nil then return end
	local target = someoneNear() and 1 or 0
	if amount == target then return end
	amount = target > amount and math.min(1, amount + dt * SPEED) or math.max(0, amount - dt * SPEED)
	local eased = amount * amount * (3 - 2 * amount)
	for panel, cframe in pairs(closed) do
		if panel.Parent then
			panel.CFrame = cframe + Vector3.new((panel:GetAttribute("SlideX") or 0) * eased, 0, 0)
		end
	end
end)
