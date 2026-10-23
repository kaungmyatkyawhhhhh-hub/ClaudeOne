-- BackdropClient (prompt 58, 23 Oct): far-away scenery that only this device draws, only when you can see it.
--   * The Pro Gym's city (ReplicatedStorage.Backdrops.ProGymCity, tools/builders/ProGymCity): the valley east of the gym
--     (tools/builders/ProGymValley). A copy goes into the Workspace while the camera is in the east part of town or the Pro
--     Gym (ShowWhen below) and comes out again when you walk away, so phones elsewhere never draw it.
--   * (prompt 62b) Everywhere else the cheap far city shows instead (ReplicatedStorage.Backdrops.ProGymFarCity,
--     tools/builders/ProGymFarCity: ~150 parts, ground + road grid, dark blocks, window strips), so the valley is never
--     bare ground. The two never draw at the same time.
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

local folder = ReplicatedStorage:WaitForChild("Backdrops", 30)
local template = folder and folder:WaitForChild("ProGymCity", 30)
if not template then return end
local farTemplate = folder:WaitForChild("ProGymFarCity", 30)

-- a backdrop's copy plus what changes at night: { model, glowing, windows, day, night }
local function build(source: Model)
	local b = { model = source:Clone(), glowing = {}, windows = {}, day = {}, night = nil }
	for _, p in ipairs(b.model:GetDescendants()) do
		if p:IsA("BasePart") then
			if typeof(p:GetAttribute("NightColor")) == "Color3" then
				table.insert(b.glowing, p)
				b.day[p] = { p.Color, p.Material }
			elseif p.Name == "Windows" then
				table.insert(b.windows, p)
				b.day[p] = { p.Color, p.Material }
			end
		end
	end
	return b
end

local function applyNight(b, on: boolean)
	if b.night == on then return end
	b.night = on
	for _, p in ipairs(b.glowing) do
		if on then
			p.Material, p.Color = Enum.Material.Neon, p:GetAttribute("NightColor")
		else
			p.Color, p.Material = b.day[p][1] :: Color3, b.day[p][2] :: Enum.Material
		end
	end
	for _, p in ipairs(b.windows) do
		p.Color = if on then DARK_WINDOW else b.day[p][1] :: Color3
	end
end

local city = nil -- the detailed city (built the first time it's wanted)
local far = if farTemplate then build(farTemplate) else nil

local function show(b, on: boolean)
	if not b then return end
	if on then
		applyNight(b, DayNight.IsNight(DayNight.Now(Workspace:GetServerTimeNow())))
		if b.model.Parent ~= Workspace then b.model.Parent = Workspace end
	elseif b.model.Parent then
		b.model.Parent = nil
	end
end

while true do
	local camera = Workspace.CurrentCamera
	local want = camera ~= nil and showWhen(camera.CFrame.Position)
	if want and not city then city = build(template) end
	-- (hide first, so both are never in at once)
	if want then show(far, false) show(city, true) else show(city, false) show(far, true) end
	task.wait(1)
end
