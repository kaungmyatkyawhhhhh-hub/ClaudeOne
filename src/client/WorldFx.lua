--[[
	WorldFx (client)
	Everything that makes the city feel alive, run locally for smoothness:
	  * traffic-light lamps (synced to server time) + blinking aviation beacons
	  * sweeping searchlight beams over the landmarks
	  * animated billboard gradients and flickering neon signs
	  * the monorail train gliding around the skyline loop
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local WorldFx = {}

local LAMP_ON = {
	R = Color3.fromRGB(255, 35, 35),
	Y = Color3.fromRGB(255, 176, 0),
	G = Color3.fromRGB(40, 255, 120),
}
local LAMP_OFF = Color3.fromRGB(26, 26, 28)

---------------------------------------------------------------------
-- Monorail train
---------------------------------------------------------------------
type TrainPart = { part: BasePart, offset: CFrame }
type TrainCar = { parts: { TrainPart }, back: number }

local function buildTrain(folder: Instance): { TrainCar }
	local M = Config.Monorail
	local cars: { TrainCar } = {}
	local function add(list: { TrainPart }, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, transparency: number?, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.Color = color
		p.Material = material
		p.Transparency = transparency or 0
		p.Reflectance = if material == Enum.Material.SmoothPlastic then 0.2 else 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = false
		p.Parent = folder
		table.insert(list, { part = p, offset = offset })
		return p
	end
	local L = M.CarLength
	for k = 1, M.Cars do
		local list: { TrainPart } = {}
		-- body sits on top of the guideway; model origin = guideway centre line
		add(list, Vector3.new(4.6, 5, L - 1), CFrame.new(0, 4.3, 0), Color3.fromRGB(225, 228, 235), Enum.Material.SmoothPlastic)
		add(list, Vector3.new(4.7, 1.7, L - 4), CFrame.new(0, 4.9, 0), Color3.fromRGB(255, 226, 180), Enum.Material.Neon, 0.25)
		add(list, Vector3.new(4.75, 0.25, L - 2), CFrame.new(0, 3.2, 0), Config.Theme.Accent, Enum.Material.Neon)
		add(list, Vector3.new(4.2, 0.6, L - 2), CFrame.new(0, 7.05, 0), Color3.fromRGB(40, 42, 48), Enum.Material.Metal)
		-- straddle skirt wrapping the beam
		add(list, Vector3.new(5.2, 2.2, L - 3), CFrame.new(0, 1.0, 0), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
		local inside = add(list, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 4.5, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 220, 180)
		glow.Range = 16
		glow.Brightness = 1.2
		glow.Shadows = false
		glow.Parent = inside
		if k == 1 then
			-- aerodynamic nose + headlights
			add(list, Vector3.new(4.3, 4.2, 3), CFrame.new(0, 4, -L / 2 - 1), Color3.fromRGB(225, 228, 235), Enum.Material.SmoothPlastic)
			add(list, Vector3.new(4, 1.4, 0.2), CFrame.new(0, 5.2, -L / 2 - 2.55), Color3.fromRGB(20, 26, 36), Enum.Material.Glass, 0.2)
			local head = add(list, Vector3.new(3.4, 0.6, 0.3), CFrame.new(0, 3.6, -L / 2 - 3), Color3.fromRGB(235, 245, 255), Enum.Material.Neon)
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Range = 60
			spot.Angle = 50
			spot.Brightness = 3
			spot.Shadows = false
			spot.Parent = head
		elseif k == M.Cars then
			add(list, Vector3.new(3.4, 0.6, 0.3), CFrame.new(0, 3.6, L / 2 + 0.2), Color3.fromRGB(255, 20, 20), Enum.Material.Neon)
		end
		table.insert(cars, { parts = list, back = (k - 1) * (L + 1.2) })
	end
	return cars
end

---------------------------------------------------------------------
-- Start
---------------------------------------------------------------------
function WorldFx.start()
	local lampCache: { [Instance]: boolean } = {}

	-- lamps + beacons (5 Hz is plenty)
	task.spawn(function()
		local blinkOn = true
		local blinkTimer = 0
		while true do
			local now = workspace:GetServerTimeNow()
			for _, lamp in CollectionService:GetTagged("TrafficLamp") do
				if lamp:IsA("BasePart") then
					local i = lamp:GetAttribute("I") :: number
					local j = lamp:GetAttribute("J") :: number
					local axis = lamp:GetAttribute("Axis") :: string
					local mine = lamp:GetAttribute("State") :: string
					local on = CityLayout.lightState(i, j, axis, now) == mine
					if lampCache[lamp] ~= on then
						lampCache[lamp] = on
						lamp.Color = if on then LAMP_ON[mine] else LAMP_OFF
					end
				end
			end
			blinkTimer += 1
			if blinkTimer >= 4 then
				blinkTimer = 0
				blinkOn = not blinkOn
				for _, b in CollectionService:GetTagged("Blink") do
					if b:IsA("BasePart") then
						b.Transparency = if blinkOn then 0 else 0.9
					end
				end
			end
			-- random neon flicker
			for _, f in CollectionService:GetTagged("Flicker") do
				if f:IsA("BasePart") then
					f.Transparency = if math.random() < 0.18 then 0.85 else 0
				end
			end
			task.wait(0.2)
		end
	end)

	-- monorail
	local train: { TrainCar } = {}
	if Config.Graphics.Monorail then
		local folder = Instance.new("Folder")
		folder.Name = "MonorailTrain"
		folder.Parent = workspace
		train = buildTrain(folder)
	end
	local trainParts: { BasePart } = {}
	local trainCFrames: { CFrame } = {}
	local loopLen = CityLayout.monorailLength()

	local boardTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()

		-- searchlights sweep in slow figure-eights
		for _, target in CollectionService:GetTagged("SearchTarget") do
			if target:IsA("BasePart") then
				local base = target:GetAttribute("Base") :: Vector3?
				local phase = (target:GetAttribute("Phase") :: number?) or 0
				if base then
					local t = now * 0.22 + phase
					local offset = Vector3.new(math.sin(t) * 520, 1050, math.cos(t * 0.73) * 520)
					target.CFrame = CFrame.new(base + offset)
				end
			end
		end

		-- billboards (10 Hz)
		boardTimer += dt
		if boardTimer > 0.1 then
			boardTimer = 0
			for _, g in CollectionService:GetTagged("AnimatedBoard") do
				if g:IsA("UIGradient") then
					g.Rotation = (g.Rotation + 4) % 360
					g.Offset = Vector2.new(math.sin(now * 0.8 + g.Rotation * 0.01) * 0.25, 0)
				end
			end
		end

		-- monorail (synced to server time so every player sees it in the same place)
		if #train > 0 then
			table.clear(trainParts)
			table.clear(trainCFrames)
			local head = (now * Config.Monorail.Speed) % loopLen
			for _, car in train do
				local s = head - car.back
				local front = CityLayout.monorailSample(s + Config.Monorail.CarLength / 2)
				local rear = CityLayout.monorailSample(s - Config.Monorail.CarLength / 2)
				local center = (front + rear) / 2
				local cf = CFrame.lookAt(center, center + (front - rear))
				for _, tp in car.parts do
					table.insert(trainParts, tp.part)
					table.insert(trainCFrames, cf * tp.offset)
				end
			end
			workspace:BulkMoveTo(trainParts, trainCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return WorldFx
