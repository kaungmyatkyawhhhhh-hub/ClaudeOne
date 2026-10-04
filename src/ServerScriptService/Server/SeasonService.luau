-- Seasonal events (Config.Seasons): while one runs, the starter gym gets simple decorations built from parts, every
-- rep pays a little extra (a global BoostService source), and reps count toward that season's title.
-- ReplicatedStorage gets a "Season" attribute (the season id) for the client's note.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Seasons = require(ReplicatedStorage.Shared.Config.Seasons)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local TitleService = require(script.Parent.TitleService)

local SeasonService = {}

local active = nil -- the running season
local decor = nil  -- Folder with the decorations

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in pairs(props) do p[key] = value end
	p.Parent = parent
	return p
end

local function glow(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, false
	light.Parent = parent
end

-- Each season: a list of floor spots (x, z, y = surface height) and a function that builds one prop there.
local DECOR = {}

DECOR.Halloween = {
	spots = { { 16, 4.1, -8 }, { -6.5, 0.1, -6 }, { 6.5, 0.1, -6 }, { -21, 0.1, -46.5 }, { 21, 0.1, -46.5 }, { -9, 6, -6 } },
	build = function(parent, base)
		local pumpkin = part(parent, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5),
			Color = Color3.fromHex("#E8761C"), CFrame = CFrame.new(base + Vector3.new(0, 0.7, 0)) })
		pumpkin.Size = Vector3.new(1.6, 1.25, 1.6)
		part(parent, { Name = "Stem", Size = Vector3.new(0.18, 0.35, 0.18), Color = Color3.fromHex("#3E6B2A"),
			CFrame = CFrame.new(base + Vector3.new(0, 1.45, 0)) })
		glow(pumpkin, Color3.fromHex("#FF9A3C"), 0.8, 8) -- a soft jack-o-lantern glow
	end,
}

DECOR.Winter = {
	spots = { { -6.5, 0.1, -6 }, { 6.5, 0.1, -6 }, { -21, 0.1, -46.5 }, { 21, 0.1, -46.5 } },
	build = function(parent, base)
		local green = Color3.fromHex("#2E5B3A")
		for i, size in ipairs({ 2.6, 2, 1.3 }) do
			part(parent, { Name = "Tree", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, size, size), Color = green,
				CFrame = CFrame.new(base + Vector3.new(0, 0.6 + (i - 1) * 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		end
		local star = part(parent, { Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45),
			Color = Color3.fromHex("#E8C21C"), Material = Enum.Material.Neon, CFrame = CFrame.new(base + Vector3.new(0, 3.2, 0)) })
		glow(star, Color3.fromHex("#FFE7A8"), 0.6, 8)
		part(parent, { Name = "Snow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3, 3), Color = Color3.fromHex("#F4F1EA"),
			CFrame = CFrame.new(base + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	end,
}

DECOR.Summer = {
	spots = { { -6.5, 0.1, -6 }, { 6.5, 0.1, -6 }, { -21, 0.1, -46.5 }, { 21, 0.1, -46.5 } },
	build = function(parent, base)
		local colors = { "#D7262E", "#F4F1EA", "#1F5FBF", "#E8C21C" }
		local ball = part(parent, { Name = "BeachBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2),
			Color = Color3.fromHex(colors[1]), CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) })
		for i = 2, #colors do
			part(parent, { Name = "Stripe", Size = Vector3.new(1.22, 0.25, 1.22), Shape = Enum.PartType.Cylinder,
				Color = Color3.fromHex(colors[i]), CFrame = ball.CFrame * CFrame.Angles(0, math.rad(60 * i), math.rad(90)) })
		end
		part(parent, { Name = "Towel", Size = Vector3.new(2.2, 0.05, 1.2), Color = Color3.fromHex("#1F5FBF"),
			CFrame = CFrame.new(base + Vector3.new(1.8, 0.03, 0)) })
	end,
}

local function clearDecor()
	if decor then decor:Destroy() end
	decor = nil
end

local function buildDecor(season)
	clearDecor()
	local spec = DECOR[season.id]
	if not spec then return end
	decor = Instance.new("Folder")
	decor.Name = "SeasonDecor"
	for _, spot in ipairs(spec.spots) do
		local ok, err = pcall(spec.build, decor, Vector3.new(spot[1], spot[2], spot[3]))
		if not ok then warn("[SeasonService] decor: " .. tostring(err)) end
	end
	decor.Parent = Workspace
end

local function setSeason(season)
	if season == active then return end
	active = season
	if season then
		BoostService.SetGlobal("Season", { coins = season.coins })
		ReplicatedStorage:SetAttribute("Season", season.id)
		buildDecor(season)
	else
		BoostService.SetGlobal("Season", nil)
		ReplicatedStorage:SetAttribute("Season", nil)
		clearDecor()
	end
end

local function current()
	local forced = RunService:IsStudio() and Workspace:GetAttribute("ForceSeason")
	if type(forced) == "string" and Seasons.ById[forced] then return Seasons.ById[forced] end
	return Seasons.Active(os.time())
end

-- Called by MachineService for every validated rep.
function SeasonService.OnRep(player)
	if not active then return end
	local data = PlayerData.Get(player)
	if not data then return end
	local seasons = data.seasons or {}
	seasons[active.id] = (seasons[active.id] or 0) + 1
	PlayerData.SetTable(player, "seasons", seasons)
	if seasons[active.id] == active.title.reps then TitleService.Check(player) end
end

function SeasonService.Start()
	setSeason(current())
	task.spawn(function()
		while true do
			task.wait(600)
			setSeason(current())
		end
	end)
end

return SeasonService
