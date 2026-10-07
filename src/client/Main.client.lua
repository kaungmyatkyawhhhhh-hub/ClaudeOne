--[[
	CITY LEGENDS - client entry point
	loading -> intro cutscene -> main menu (orbiting city camera) -> garage -> drive
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))

local UI = require(script.Parent:WaitForChild("UI"))
local Traffic = require(script.Parent:WaitForChild("Traffic"))
local Driving = require(script.Parent:WaitForChild("Driving"))
local Cutscene = require(script.Parent:WaitForChild("Cutscene"))
local WorldFx = require(script.Parent:WaitForChild("WorldFx"))
local CarSkin = require(script.Parent:WaitForChild("CarSkin"))
local BuildingSkin = require(script.Parent:WaitForChild("BuildingSkin"))
local Audio = require(script.Parent:WaitForChild("Audio"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

UI.init()
UI.showLoading("Loading sounds...")
Audio.init() -- test-loads the Creator Store sounds (falls back to built-in ones)
UI.showLoading("Building the city...")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetData = remotes:WaitForChild("GetData") :: RemoteFunction
local BuyCar = remotes:WaitForChild("BuyCar") :: RemoteFunction
local SpawnCar = remotes:WaitForChild("SpawnCar") :: RemoteEvent

Driving.init()

-- wait for the server to finish building the city
local city = workspace:WaitForChild("City", 120)
while city and not city:GetAttribute("Ready") do
	task.wait(0.2)
end
UI.showLoading("Shaping the cars...")
CarSkin.preload({ Cars.CutsceneId })
UI.showLoading("Starting engines...")
task.wait(1) -- let the world finish replicating

---------------------------------------------------------------------
-- World effects: lights, searchlights, billboards, monorail
---------------------------------------------------------------------
if city then
	UI.showLoading("Painting the skyline...")
	BuildingSkin.apply(city)
end
WorldFx.start()

---------------------------------------------------------------------
-- Data
---------------------------------------------------------------------
local data = GetData:InvokeServer()
if not data then
	data = { Cash = Config.Economy.StartingCash, Owned = { "aurelia_s4" }, Selected = "aurelia_s4" }
end
UI.setCash(data.Cash, true)

local function bindCash()
	local stats = player:WaitForChild("leaderstats", 30)
	local cash = stats and stats:WaitForChild("Cash", 10)
	if cash and cash:IsA("IntValue") then
		UI.setCash(cash.Value)
		cash.Changed:Connect(function(v)
			UI.setCash(v)
			data.Cash = v
		end)
	end
end
task.spawn(bindCash)

---------------------------------------------------------------------
-- Intro cutscene
---------------------------------------------------------------------
Cutscene.play()

---------------------------------------------------------------------
-- Traffic (runs for the rest of the session)
---------------------------------------------------------------------
local function focusPoint(): Vector3?
	local root = Driving.getRoot()
	if root then
		return root.Position
	end
	return camera.CFrame.Position
end

RunService.Heartbeat:Connect(function(dt)
	Traffic.update(dt)
end)

---------------------------------------------------------------------
-- Menu camera: slow fly-through down the main avenue over the traffic
-- (the avenue is an open corridor, so the camera never clips a tower)
---------------------------------------------------------------------
local orbitConn: RBXScriptConnection? = nil
local function startOrbit()
	if orbitConn then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local travel = 0
	local span = Config.City.HalfExtent * 1.7
	orbitConn = RunService.RenderStepped:Connect(function(dt: number)
		travel = (travel + dt * 22) % span
		local x = -span / 2 + travel
		local sway = math.sin(travel / 90) * 6
		local pos = Vector3.new(x, 46 + math.sin(travel / 140) * 8, sway)
		camera.CFrame = CFrame.lookAt(pos, Vector3.new(x + 140, 12, sway * 0.3))
		camera.FieldOfView = 62
	end)
end
local function stopOrbit()
	if orbitConn then
		orbitConn:Disconnect()
		orbitConn = nil
	end
end

startOrbit()
UI.showLoading("Filling the streets with traffic...")
UI.fade(false, 0.01)
Traffic.start(math.floor(Config.Traffic.CarCount * math.clamp(WorldFx.qualityScale(), 0.6, 1)), focusPoint)
UI.hideLoading()

---------------------------------------------------------------------
-- Spawning / garage
---------------------------------------------------------------------
local pendingAttach = false
local playerCars = workspace:WaitForChild("PlayerCars")

-- every player's car gets the smooth body locally
local function skinPlayerCar(model: Instance)
	if model:IsA("Model") then
		model:WaitForChild("Chassis", 5)
		task.wait() -- let the whole car replicate
		CarSkin.apply(model, false)
	end
end
for _, existing in playerCars:GetChildren() do
	task.spawn(skinPlayerCar, existing)
end
playerCars.ChildAdded:Connect(function(model)
	if not (model:GetAttribute("Owner") == player.UserId and pendingAttach) then
		skinPlayerCar(model)
	end
end)

local function tryAttach(model: Instance)
	if model:IsA("Model") and model:GetAttribute("Owner") == player.UserId and pendingAttach then
		pendingAttach = false
		model:WaitForChild("Chassis", 5)
		task.wait() -- let the car + its constraints replicate
		CarSkin.apply(model, false)
		stopOrbit()
		Traffic.clearAround(model:GetPivot().Position, 35)
		Driving.attach(model)
		UI.showHud(true)
		UI.setCameraLabel(Driving.cameraMode)
		UI.fade(false, 0.5)
	end
end
playerCars.ChildAdded:Connect(tryAttach)

local function requestDrive(id: string)
	pendingAttach = true
	data.Selected = id
	UI.fade(true, 0.3)
	SpawnCar:FireServer(id)
	-- safety: if the car is already there (rare race) attach to it
	task.delay(0.5, function()
		if pendingAttach then
			local existing = playerCars:FindFirstChild(player.Name)
			if existing then
				tryAttach(existing)
			end
		end
	end)
	task.delay(6, function()
		if pendingAttach then
			pendingAttach = false
			UI.fade(false, 0.3)
			UI.toast("Could not spawn the car, try again", Config.Theme.Danger)
		end
	end)
end

local showMenu: () -> ()

local function openGarage(fromMenu: boolean)
	local fresh = GetData:InvokeServer()
	if fresh then
		data = fresh
	end
	UI.openGarage(data, {
		buy = function(id: string)
			local result = BuyCar:InvokeServer(id)
			if result and result.data then
				data = result.data
			end
			return result or { ok = false, message = "Server did not respond" }
		end,
		drive = function(id: string)
			UI.hideMainMenu()
			requestDrive(id)
		end,
		close = function()
			if fromMenu and not Driving.isDriving() then
				showMenu()
			end
		end,
	})
end

showMenu = function()
	UI.showHud(false)
	startOrbit()
	UI.showMainMenu(data.Cash, function()
		UI.hideMainMenu()
		openGarage(true)
	end)
end

local function toggleGarage()
	if UI.isGarageOpen() then
		UI.closeGarage()
	else
		openGarage(false)
	end
end
UI.onGarageButton = toggleGarage
UI.onCameraButton = function()
	Driving.toggleCamera()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G and Driving.isDriving() then
		toggleGarage()
	end
end)

showMenu()
