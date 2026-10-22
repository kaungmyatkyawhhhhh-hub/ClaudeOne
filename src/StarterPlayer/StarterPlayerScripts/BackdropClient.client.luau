-- BackdropClient (prompt 58, 23 Oct): far-away scenery that only this device draws, only when you can see it.
--   * The Pro Gym's city (ReplicatedStorage.Backdrops.ProGymCity, tools/builders/ProGymCity): the valley east of the gym
--     (tools/builders/ProGymValley). A copy goes into the Workspace while the camera is in the east part of town or the Pro
--     Gym (ShowWhen below) and comes out again when you walk away, so phones elsewhere never draw it.
--   * Night: parts with a NightColor attribute (lit windows, street lamps, bridge lights) glow (Neon in that colour) from
--     dusk to dawn (Config.DayNight, the same clock as the town's lamps); unlit windows go dark. By day: their own look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DayNight = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DayNight"))

local DARK_WINDOW = Color3.fromHex("#151A22")
-- where the camera must be for the city to show: the town east of the starter gym and the Pro Gym
local function showWhen(p: Vector3): boolean
	return p.X > 20 and p.Z < 200 and p.Y < 400
end

local template = ReplicatedStorage:WaitForChild("Backdrops", 30)
template = template and template:WaitForChild("ProGymCity", 30)
if not template then return end

local city: Model? = nil
local glowing: { BasePart } = {}
local windows: { BasePart } = {}
local day: { [BasePart]: { Color3 | Enum.Material } } = {}
local night: boolean? = nil

local function applyNight(on: boolean)
	for _, p in ipairs(glowing) do
		if on then
			p.Material, p.Color = Enum.Material.Neon, p:GetAttribute("NightColor")
		else
			p.Color, p.Material = day[p][1] :: Color3, day[p][2] :: Enum.Material
		end
	end
	for _, p in ipairs(windows) do
		p.Color = if on then DARK_WINDOW else day[p][1] :: Color3
	end
end

local function build()
	city = template:Clone()
	for _, p in ipairs((city :: Model):GetDescendants()) do
		if p:IsA("BasePart") then
			if typeof(p:GetAttribute("NightColor")) == "Color3" then
				table.insert(glowing, p)
				day[p] = { p.Color, p.Material }
			elseif p.Name == "Windows" then
				table.insert(windows, p)
				day[p] = { p.Color, p.Material }
			end
		end
	end
	night = nil
end

while true do
	local camera = Workspace.CurrentCamera
	local want = camera ~= nil and showWhen(camera.CFrame.Position)
	if want then
		if not city then build() end
		local isNight = DayNight.IsNight(DayNight.Now(Workspace:GetServerTimeNow()))
		if isNight ~= night then
			night = isNight
			applyNight(isNight)
		end
		if (city :: Model).Parent ~= Workspace then (city :: Model).Parent = Workspace end
	elseif city and city.Parent then
		city.Parent = nil
	end
	task.wait(1)
end
