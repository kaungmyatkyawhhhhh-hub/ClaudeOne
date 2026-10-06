-- TownKit: templates for the town builder (tools/builders/Town.luau). NOT part of the game; run once in Studio.
-- Everything is several parts with real detail, and one good template is reused many times (one lamp, used 40 times).
-- Conventions: a cframe sits on the ground; "front" faces local -Z (CFrame.lookAt(position, street) works).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local TownKit = {}

local hex, rad = Kit.hex, math.rad
local M = Enum.Material

TownKit.C = {
	Asphalt = hex("#2A2B2F"), Sidewalk = hex("#B9B2A6"), Curb = hex("#9C978E"), Paving = hex("#C9B79C"),
	PavingDark = hex("#A8957B"), Stripe = hex("#DEDAD0"), Trunk = hex("#6B4F3A"), TrunkDark = hex("#4E3A2B"),
	Leaf1 = hex("#4E7A3E"), Leaf2 = hex("#5E8C45"), Leaf3 = hex("#3F6B36"), Leaf4 = hex("#6E9A4E"),
	Iron = hex("#2B2C2F"), Brass = hex("#B9935A"), Warm = hex("#FFD7A8"), Sand = hex("#E3D3A8"),
	Wood = hex("#8A6A4A"), WoodDark = hex("#5E4632"), Glass = hex("#7F99A6"), Stone = hex("#8E8A82"),
	White = hex("#F2EEE6"), Red = hex("#D7262E"), Chalk = hex("#F2F0EA"),
}
local C = TownKit.C

-- warm, sunny facade palette
TownKit.Palette = {
	{ wall = hex("#E8DCC4"), trim = hex("#F7F2E8"), mat = M.Plaster },
	{ wall = hex("#C8734F"), trim = hex("#EDE3D3"), mat = M.Brick },
	{ wall = hex("#D9B98C"), trim = hex("#F2EADB"), mat = M.Plaster },
	{ wall = hex("#E59A7A"), trim = hex("#F7EFE4"), mat = M.Plaster },
	{ wall = hex("#A9B89A"), trim = hex("#F2EEE6"), mat = M.Plaster },
	{ wall = hex("#E3C07A"), trim = hex("#F7F0DE"), mat = M.Plaster },
	{ wall = hex("#B5654A"), trim = hex("#E8DCC4"), mat = M.Brick },
	{ wall = hex("#9FB6C2"), trim = hex("#F2EEE6"), mat = M.Plaster },
}

local function p(parent, name, size, cframe, color, material, solid, props)
	local part = (solid and Kit.part or Kit.prop)(parent, name, size, cframe, color, material or M.SmoothPlastic, props)
	if solid then part.CastShadow = true end
	return part
end
TownKit.p = p

local function cyl(parent, name, length, diameter, cframe, color, material, solid)
	local part = p(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material, solid)
	part.Shape = Enum.PartType.Cylinder
	return part
end
TownKit.cyl = cyl

local function ball(parent, name, size, cframe, color, material, solid)
	local part = p(parent, name, size, cframe, color, material, solid)
	part.Shape = Enum.PartType.Ball
	return part
end
TownKit.ball = ball

local function wedge(parent, name, size, cframe, color, material)
	local w = Kit.wedge(parent, name, size, cframe, color, material)
	w.CastShadow = false
	return w
end

local function model(parent, name, cframe)
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = cframe
	m.Parent = parent
	return m
end
TownKit.model = model

local up = CFrame.Angles(0, 0, rad(90)) -- turns a cylinder upright

------------------------------------------------------------------------
-- Plants
------------------------------------------------------------------------
-- A tapered trunk of stacked cylinders, slightly bending. Returns the top CFrame.
local function trunk(m, base, height, width, color, lean)
	local segments = 3
	local cf = base
	for i = 1, segments do
		local h = height / segments
		local w = width * (1 - (i - 1) * 0.18)
		cf = cf * CFrame.Angles(rad(lean or 0), 0, rad((lean or 0) * 0.5))
		cyl(m, "Trunk", h + 0.2, w, cf * CFrame.new(0, h / 2, 0) * up, color, M.Wood, i == 1)
		cf = cf * CFrame.new(0, h, 0)
	end
	return cf
end

-- Oak: big, spread canopy of overlapping clumps over a few branches.
function TownKit.oak(parent, position, scale, seed)
	scale = scale or 1
	local rng = Random.new(seed or math.floor(position.X * 7 + position.Z * 13))
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local m = model(parent, "Oak", base)
	p(m, "RootFlare", Vector3.new(1.9, 0.4, 1.9) * scale, base * CFrame.new(0, 0.2 * scale, 0), C.TrunkDark, M.Wood)
	local top = trunk(m, base, 7 * scale, 1.3 * scale, C.Trunk, rng:NextNumber(-3, 3))
	local greens = { C.Leaf1, C.Leaf2, C.Leaf3 }
	for i = 0, 2 do
		local a = i * 120 + rng:NextNumber(-20, 20)
		local branch = top * CFrame.Angles(0, rad(a), 0) * CFrame.Angles(rad(-50), 0, 0)
		cyl(m, "Branch", 3.4 * scale, 0.45 * scale, branch * CFrame.new(0, 1.5 * scale, 0) * up, C.Trunk, M.Wood)
	end
	for i = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = (i == 1 and 0 or rng:NextNumber(2.4, 3.6)) * scale
		local s = rng:NextNumber(5.2, 7.2) * scale
		local y = (i == 1 and 3.4 or rng:NextNumber(1.2, 3)) * scale
		ball(m, "Leaves", Vector3.new(s, s * 0.82, s), top * CFrame.new(math.cos(a) * r, y, math.sin(a) * r), greens[(i % 3) + 1], M.LeafyGrass)
	end
	return m
end

-- Round tree: a smaller lollipop-free crown made of 5 clumps on a visible trunk with a fork.
function TownKit.roundTree(parent, position, scale, seed)
	scale = scale or 1
	local rng = Random.new(seed or math.floor(position.X * 11 + position.Z * 5))
	local base = CFrame.new(position)
	local m = model(parent, "RoundTree", base)
	local top = trunk(m, base, 5 * scale, 0.8 * scale, C.Trunk, rng:NextNumber(-4, 4))
	cyl(m, "Fork", 2.2 * scale, 0.35 * scale, top * CFrame.Angles(rad(35), 0, 0) * CFrame.new(0, 0.9 * scale, 0) * up, C.Trunk, M.Wood)
	cyl(m, "Fork", 2.2 * scale, 0.35 * scale, top * CFrame.Angles(rad(-35), 0, 0) * CFrame.new(0, 0.9 * scale, 0) * up, C.Trunk, M.Wood)
	local greens = { C.Leaf2, C.Leaf4, C.Leaf1 }
	for i = 1, 5 do
		local a = i * 72 + rng:NextNumber(-15, 15)
		local r = (i == 5 and 0 or 1.6) * scale
		local s = rng:NextNumber(3.6, 4.8) * scale
		ball(m, "Leaves", Vector3.new(s, s * 0.9, s), top * CFrame.new(math.cos(rad(a)) * r, (i == 5 and 3 or 1.8) * scale, math.sin(rad(a)) * r), greens[(i % 3) + 1], M.LeafyGrass)
	end
	return m
end

-- Cypress: tall and narrow, stacked tapering clumps.
function TownKit.cypress(parent, position, scale)
	scale = scale or 1
	local base = CFrame.new(position)
	local m = model(parent, "Cypress", base)
	cyl(m, "Trunk", 1.6 * scale, 0.6 * scale, base * CFrame.new(0, 0.8 * scale, 0) * up, C.TrunkDark, M.Wood, true)
	local y = 1.4 * scale
	for i = 1, 5 do
		local w = (3.2 - i * 0.45) * scale
		local h = (3.4 - i * 0.2) * scale
		ball(m, "Leaves", Vector3.new(w, h, w), base * CFrame.new(0, y + h / 2, 0), i % 2 == 0 and C.Leaf3 or C.Leaf1, M.LeafyGrass)
		y += h * 0.62
	end
	return m
end

-- Palm: curved ringed trunk, drooping fronds, coconuts.
function TownKit.palm(parent, position, scale, seed)
	scale = scale or 1
	local rng = Random.new(seed or math.floor(position.X * 3 + position.Z * 17))
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local m = model(parent, "Palm", base)
	local cf = base
	local bend = rng:NextNumber(4, 7)
	for i = 1, 7 do
		local h = 1.7 * scale
		cf = cf * CFrame.Angles(rad(bend), 0, 0)
		cyl(m, "Trunk", h + 0.15, (0.9 - i * 0.05) * scale, cf * CFrame.new(0, h / 2, 0) * up, i % 2 == 0 and hex("#8C6E4F") or hex("#9B7C5A"), M.Wood, i == 1)
		if i % 2 == 1 then cyl(m, "Ring", 0.15, (1.0 - i * 0.05) * scale, cf * CFrame.new(0, h, 0) * up, hex("#6E553D"), M.Wood) end
		cf = cf * CFrame.new(0, h, 0)
	end
	for i = 0, 7 do
		local frond = cf * CFrame.Angles(0, rad(i * 45 + rng:NextNumber(-10, 10)), 0)
		-- each frond: two leaf blades, the outer one drooping more
		p(m, "Frond", Vector3.new(1.4 * scale, 0.1, 3.6 * scale), frond * CFrame.Angles(rad(-18), 0, 0) * CFrame.new(0, 0.2, -1.7 * scale), i % 2 == 0 and C.Leaf2 or C.Leaf4, M.LeafyGrass)
		p(m, "FrondTip", Vector3.new(1.0 * scale, 0.1, 3.0 * scale), frond * CFrame.Angles(rad(-18), 0, 0) * CFrame.new(0, 0.2, -3.4 * scale) * CFrame.Angles(rad(-35), 0, 0) * CFrame.new(0, 0, -1.3 * scale), C.Leaf1, M.LeafyGrass)
	end
	for i = 0, 2 do ball(m, "Coconut", Vector3.new(0.6, 0.6, 0.6) * scale, cf * CFrame.new(math.cos(i * 2.1) * 0.45 * scale, -0.3 * scale, math.sin(i * 2.1) * 0.45 * scale), hex("#5E4632"), M.Wood) end
	return m
end

function TownKit.bush(parent, position, scale, seed)
	scale = scale or 1
	local rng = Random.new(seed or math.floor(position.X * 5 + position.Z * 3))
	local m = model(parent, "Bush", CFrame.new(position))
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local s = rng:NextNumber(1.8, 2.6) * scale
		ball(m, "Leaves", Vector3.new(s, s * 0.75, s), CFrame.new(position + Vector3.new(math.cos(a) * 0.8 * scale, s * 0.3, math.sin(a) * 0.8 * scale)), i % 2 == 0 and C.Leaf3 or C.Leaf2, M.LeafyGrass)
	end
	return m
end

-- A cluster of flowers (stem + bloom), colors from a small warm set
local FLOWERS = { hex("#E86A6A"), hex("#F2C14E"), hex("#F4F1EA"), hex("#C77DD6"), hex("#F29E6B") }
function TownKit.flowers(parent, center, radius, count, seed)
	local rng = Random.new(seed or math.floor(center.X + center.Z * 3))
	local m = model(parent, "Flowers", CFrame.new(center))
	for _ = 1, count do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:NextNumber(0.5, 0.9)
		p(m, "Stem", Vector3.new(0.08, h, 0.08), CFrame.new(pos + Vector3.new(0, h / 2, 0)), C.Leaf3, M.Grass)
		ball(m, "Bloom", Vector3.new(0.35, 0.3, 0.35), CFrame.new(pos + Vector3.new(0, h, 0)), FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic)
	end
	return m
end

function TownKit.rock(parent, position, scale, seed)
	scale = scale or 1
	local rng = Random.new(seed or math.floor(position.X * 9 + position.Z))
	local m = model(parent, "Rock", CFrame.new(position))
	for i = 1, 3 do
		local s = Vector3.new(rng:NextNumber(1.4, 2.4), rng:NextNumber(0.9, 1.6), rng:NextNumber(1.2, 2.2)) * scale
		local cf = CFrame.new(position + Vector3.new(rng:NextNumber(-0.7, 0.7) * scale, s.Y * 0.35, rng:NextNumber(-0.7, 0.7) * scale))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4))
		p(m, "Stone", s, cf, i == 1 and hex("#8A857C") or hex("#9C968B"), M.Rock, i == 1)
	end
	return m
end

------------------------------------------------------------------------
-- Night lights: a glowing part (lamp glass, bulb) tagged "NightLight". NightLightService turns its lights on and makes
-- it glow (Neon) only at night; by day it's plain frosted glass and its lights are off. Built in the day look.
------------------------------------------------------------------------
local DAY_GLASS = hex("#F1E3C4")
function TownKit.nightLight(part, nightColor)
	part:SetAttribute("NightColor", nightColor or C.Warm)
	part:SetAttribute("DayColor", DAY_GLASS)
	part.Material = M.SmoothPlastic
	part.Color = DAY_GLASS
	part.Transparency = 0
	for _, light in ipairs(part:GetChildren()) do
		if light:IsA("Light") then light.Enabled = false end
	end
	game:GetService("CollectionService"):AddTag(part, "NightLight")
	return part
end

------------------------------------------------------------------------
-- Street furniture
------------------------------------------------------------------------
-- Street lamp: plinth, fluted pole, ring, curved arm, lantern head with a warm light (on at night only).
function TownKit.lamp(parent, position, facing)
	local base = CFrame.lookAt(position, position + (facing or Vector3.new(0, 0, 1)) * Vector3.new(1, 0, 1))
	local m = model(parent, "StreetLamp", base)
	cyl(m, "Plinth", 0.9, 1.2, base * CFrame.new(0, 0.45, 0) * up, C.Iron, M.Metal, true)
	cyl(m, "PlinthCap", 0.15, 1.0, base * CFrame.new(0, 0.97, 0) * up, C.Iron, M.Metal)
	cyl(m, "Pole", 7.6, 0.45, base * CFrame.new(0, 4.8, 0) * up, C.Iron, M.Metal, true)
	cyl(m, "Ring", 0.25, 0.7, base * CFrame.new(0, 2.4, 0) * up, C.Brass, M.Metal)
	cyl(m, "Ring", 0.25, 0.6, base * CFrame.new(0, 8.4, 0) * up, C.Brass, M.Metal)
	p(m, "Arm", Vector3.new(0.18, 0.18, 2.2), base * CFrame.new(0, 8.9, -1.0), C.Iron, M.Metal)
	p(m, "ArmCurl", Vector3.new(0.14, 0.9, 0.14), base * CFrame.new(0, 8.5, -0.3) * CFrame.Angles(rad(30), 0, 0), C.Iron, M.Metal)
	local head = base * CFrame.new(0, 8.35, -2.0)
	p(m, "HeadCap", Vector3.new(1.1, 0.25, 1.1), head * CFrame.new(0, 0.6, 0), C.Iron, M.Metal)
	p(m, "HeadTop", Vector3.new(0.5, 0.3, 0.5), head * CFrame.new(0, 0.85, 0), C.Iron, M.Metal)
	local glass = p(m, "Lantern", Vector3.new(0.8, 1.0, 0.8), head, C.Warm, M.Neon, false, { Transparency = 0.15 })
	p(m, "HeadBottom", Vector3.new(0.9, 0.15, 0.9), head * CFrame.new(0, -0.55, 0), C.Iron, M.Metal)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = hex("#FFD7A8"), 1.1, 20, false
	light.Parent = glass
	TownKit.nightLight(glass)
	return m
end

function TownKit.bench(parent, cframe)
	local m = model(parent, "Bench", cframe)
	for i = 0, 3 do
		p(m, "Slat", Vector3.new(5, 0.15, 0.32), cframe * CFrame.new(0, 1.6, -0.6 + i * 0.4), C.Wood, M.Wood, i == 0)
	end
	for i = 0, 2 do
		p(m, "BackSlat", Vector3.new(5, 0.32, 0.12), cframe * CFrame.new(0, 2.15 + i * 0.4, 0.85) * CFrame.Angles(rad(-12), 0, 0), C.Wood, M.Wood)
	end
	for _, x in ipairs({ -2.1, 2.1 }) do
		p(m, "Leg", Vector3.new(0.18, 1.6, 1.6), cframe * CFrame.new(x, 0.8, 0.1), C.Iron, M.Metal, true)
		p(m, "Armrest", Vector3.new(0.2, 0.15, 1.5), cframe * CFrame.new(x, 2.3, 0), C.Iron, M.Metal)
		p(m, "BackPost", Vector3.new(0.15, 1.6, 0.15), cframe * CFrame.new(x, 2.5, 0.85) * CFrame.Angles(rad(-12), 0, 0), C.Iron, M.Metal)
	end
	return m
end

function TownKit.bin(parent, cframe)
	local m = model(parent, "Bin", cframe)
	cyl(m, "Body", 2.6, 1.3, cframe * CFrame.new(0, 1.4, 0) * up, hex("#3C5A48"), M.Metal, true)
	for _, y in ipairs({ 0.5, 1.4, 2.3 }) do cyl(m, "Band", 0.12, 1.36, cframe * CFrame.new(0, y, 0) * up, C.Iron, M.Metal) end
	cyl(m, "Lid", 0.25, 1.45, cframe * CFrame.new(0, 2.8, 0) * up, C.Iron, M.Metal)
	cyl(m, "Base", 0.15, 1.1, cframe * CFrame.new(0, 0.08, 0) * up, C.Iron, M.Metal)
	return m
end

function TownKit.bikeRack(parent, cframe, count)
	local m = model(parent, "BikeRack", cframe)
	for i = 0, (count or 4) - 1 do
		local x = (i - ((count or 4) - 1) / 2) * 1.2
		p(m, "LoopSide", Vector3.new(0.12, 2.2, 0.12), cframe * CFrame.new(x, 1.1, -0.9), C.Iron, M.Metal, true)
		p(m, "LoopSide", Vector3.new(0.12, 2.2, 0.12), cframe * CFrame.new(x, 1.1, 0.9), C.Iron, M.Metal, true)
		p(m, "LoopTop", Vector3.new(0.12, 0.12, 1.92), cframe * CFrame.new(x, 2.2, 0), C.Iron, M.Metal)
	end
	p(m, "Rail", Vector3.new((count or 4) * 1.2, 0.1, 0.12), cframe * CFrame.new(0, 0.1, -0.9), C.Iron, M.Metal)
	p(m, "Rail", Vector3.new((count or 4) * 1.2, 0.1, 0.12), cframe * CFrame.new(0, 0.1, 0.9), C.Iron, M.Metal)
	return m
end

function TownKit.bike(parent, cframe, color)
	local m = model(parent, "Bike", cframe)
	for _, z in ipairs({ -1.2, 1.2 }) do
		cyl(m, "Wheel", 0.12, 2, cframe * CFrame.new(0, 1, z), hex("#1A1A1A"), M.Rubber)
		cyl(m, "Hub", 0.16, 0.25, cframe * CFrame.new(0, 1, z), C.Iron, M.Metal)
	end
	p(m, "Frame", Vector3.new(0.12, 0.12, 2.4), cframe * CFrame.new(0, 1.6, 0), color or hex("#2E6E8E"), M.Metal)
	p(m, "Down", Vector3.new(0.12, 1.3, 0.12), cframe * CFrame.new(0, 1.3, -0.3) * CFrame.Angles(rad(30), 0, 0), color or hex("#2E6E8E"), M.Metal)
	p(m, "Seat", Vector3.new(0.3, 0.12, 0.6), cframe * CFrame.new(0, 2.1, 0.6), hex("#1A1A1A"), M.Leather)
	p(m, "Bars", Vector3.new(1.0, 0.1, 0.1), cframe * CFrame.new(0, 2.2, -1.0), C.Iron, M.Metal)
	return m
end

function TownKit.planter(parent, cframe, w, d, plant)
	local m = model(parent, "Planter", cframe)
	p(m, "Box", Vector3.new(w, 1.4, d), cframe * CFrame.new(0, 0.7, 0), hex("#B5AA98"), M.Concrete, true)
	p(m, "Cap", Vector3.new(w + 0.3, 0.2, d + 0.3), cframe * CFrame.new(0, 1.5, 0), hex("#CFC6B6"), M.Concrete)
	p(m, "Soil", Vector3.new(w - 0.4, 0.1, d - 0.4), cframe * CFrame.new(0, 1.45, 0), hex("#3B2A1E"), M.Ground)
	if plant == "flowers" then
		TownKit.flowers(m, (cframe * CFrame.new(0, 1.45, 0)).Position, math.min(w, d) / 2 - 0.4, math.floor(w * d * 0.8))
	elseif plant == "bush" then
		TownKit.bush(m, (cframe * CFrame.new(0, 1.4, 0)).Position, math.min(w, d) / 3.2)
	end
	return m
end

function TownKit.hydrant(parent, cframe)
	local m = model(parent, "Hydrant", cframe)
	cyl(m, "Body", 1.6, 0.7, cframe * CFrame.new(0, 0.9, 0) * up, C.Red, M.Metal, true)
	cyl(m, "Base", 0.2, 0.95, cframe * CFrame.new(0, 0.1, 0) * up, C.Red, M.Metal)
	ball(m, "Top", Vector3.new(0.75, 0.6, 0.75), cframe * CFrame.new(0, 1.7, 0), C.Red, M.Metal)
	cyl(m, "Nozzle", 0.4, 0.3, cframe * CFrame.new(0.45, 1.1, 0), hex("#C9CCD2"), M.Metal)
	cyl(m, "Nozzle", 0.4, 0.3, cframe * CFrame.new(-0.45, 1.1, 0), hex("#C9CCD2"), M.Metal)
	return m
end

-- Bus stop: roof, glass back, bench, route sign on a pole.
function TownKit.busStop(parent, cframe)
	local m = model(parent, "BusStop", cframe)
	for _, x in ipairs({ -3.2, 3.2 }) do
		p(m, "Post", Vector3.new(0.25, 8, 0.25), cframe * CFrame.new(x, 4, 1.2), C.Iron, M.Metal, true)
	end
	p(m, "Roof", Vector3.new(7.2, 0.3, 3.2), cframe * CFrame.new(0, 8.1, 0.2) * CFrame.Angles(rad(-5), 0, 0), C.Iron, M.Metal)
	p(m, "RoofTrim", Vector3.new(7.3, 0.4, 0.1), cframe * CFrame.new(0, 8.1, -1.4), hex("#3C5A48"), M.Metal)
	p(m, "BackGlass", Vector3.new(6.2, 5.5, 0.1), cframe * CFrame.new(0, 3.5, 1.25), C.Glass, M.Glass, false, { Transparency = 0.55 })
	p(m, "MapPanel", Vector3.new(1.6, 2.6, 0.12), cframe * CFrame.new(-3.2, 3.2, 1.0), hex("#F2EEE6"), M.SmoothPlastic)
	TownKit.bench(m, cframe * CFrame.new(0, 0, 0.5) * CFrame.Angles(0, math.pi, 0)).Parent = m
	local _, label = Kit.sign(m, "StopSign", Vector3.new(1.6, 1.0, 0.1), cframe * CFrame.new(3.8, 7.4, -0.4), "Bus · Beach Rd", C.White, hex("#3C5A48"), 60)
	label.FontFace = Theme.Fonts.SemiBold
	return m
end

-- Signpost with arrows to the areas (each arrow a board with an arrow tip)
function TownKit.signpost(parent, cframe, arrows)
	local m = model(parent, "Signpost", cframe)
	cyl(m, "Pole", 7, 0.3, cframe * CFrame.new(0, 3.5, 0) * up, C.Iron, M.Metal, true)
	ball(m, "Finial", Vector3.new(0.45, 0.45, 0.45), cframe * CFrame.new(0, 7.1, 0), C.Brass, M.Metal)
	for i, arrow in ipairs(arrows) do
		local cf = cframe * CFrame.new(0, 6.5 - i * 0.8, 0) * CFrame.Angles(0, rad(arrow.yaw), 0)
		local board, label = Kit.sign(m, "Arrow", Vector3.new(3.2, 0.6, 0.12), cf * CFrame.new(1.7, 0, 0), arrow.text, C.White, hex("#3C5A48"), 60)
		board.Name = "Arrow"
		label.FontFace = Theme.Fonts.SemiBold
		wedge(m, "ArrowTip", Vector3.new(0.12, 0.6, 0.5), cf * CFrame.new(3.55, 0, 0) * CFrame.Angles(0, rad(90), 0), hex("#3C5A48"), M.SmoothPlastic)
	end
	return m
end

function TownKit.crates(parent, cframe)
	local m = model(parent, "Crates", cframe)
	local function crate(cf, s)
		p(m, "Crate", Vector3.new(s, s, s), cf, C.Wood, M.WoodPlanks, true)
		for _, y in ipairs({ -s / 2 + 0.1, s / 2 - 0.1 }) do
			p(m, "Slat", Vector3.new(s + 0.04, 0.16, s + 0.04), cf * CFrame.new(0, y, 0), C.WoodDark, M.Wood)
		end
	end
	crate(cframe * CFrame.new(0, 0.9, 0), 1.8)
	crate(cframe * CFrame.new(1.9, 0.75, 0.2) * CFrame.Angles(0, rad(12), 0), 1.5)
	crate(cframe * CFrame.new(0.6, 2.5, 0.1) * CFrame.Angles(0, rad(-8), 0), 1.4)
	return m
end

-- String lights between two points, sagging, with warm bulbs.
function TownKit.stringLights(parent, a, b, bulbs)
	local m = model(parent, "StringLights", CFrame.new((a + b) / 2))
	bulbs = bulbs or 10
	local prev = a
	for i = 1, bulbs do
		local t = i / bulbs
		local point = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 1.6, 0)
		local mid = (prev + point) / 2
		p(m, "Wire", Vector3.new(0.05, 0.05, (point - prev).Magnitude), CFrame.lookAt(mid, point), C.Iron, M.SmoothPlastic)
		if i < bulbs then
			local bulb = ball(m, "Bulb", Vector3.new(0.35, 0.45, 0.35), CFrame.new(point - Vector3.new(0, 0.3, 0)), C.Warm, M.Neon)
			if i % 3 == 0 then
				local light = Instance.new("PointLight")
				light.Color, light.Brightness, light.Range, light.Shadows = C.Warm, 0.6, 9, false
				light.Parent = bulb
			end
			TownKit.nightLight(bulb)
		end
		prev = point
	end
	return m
end

------------------------------------------------------------------------
-- Buildings: a facade generator. Front faces local -Z.
--   spec: { w, d, floors, palette (TownKit.Palette entry), shop = { name, stripes = { colorA, colorB } } | nil,
--           balconies = true, roof = "tank" | "ac" | "rail", far = true (simpler, for distance) }
------------------------------------------------------------------------
local FLOOR_H = 9

local function window(m, cf, w, h, trim)
	-- 4 parts: a trim plate (shows as the frame around the glass), the glass in front of it, a mullion and a sill
	p(m, "Frame", Vector3.new(w + 0.36, h + 0.36, 0.12), cf * CFrame.new(0, 0, -0.04), trim, M.SmoothPlastic)
	p(m, "Glass", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.1), hex("#5F7480"), M.Glass, false, { Reflectance = 0.15, Transparency = 0.05 })
	p(m, "Mullion", Vector3.new(0.1, h, 0.1), cf * CFrame.new(0, 0, -0.16), trim, M.SmoothPlastic)
	p(m, "Sill", Vector3.new(w + 0.5, 0.2, 0.45), cf * CFrame.new(0, -h / 2 - 0.1, -0.22), trim, M.Concrete)
end

local function awning(m, cf, w, depth, colors)
	local stripes = math.max(3, math.floor(w / 1.2))
	local sw = w / stripes
	for i = 0, stripes - 1 do
		local x = -w / 2 + sw / 2 + i * sw
		wedge(m, "Awning", Vector3.new(sw, 1.1, depth), cf * CFrame.new(x, 0, -depth / 2) * CFrame.Angles(0, math.pi, 0), colors[(i % 2) + 1], M.Fabric)
		p(m, "Valance", Vector3.new(sw, 0.45, 0.06), cf * CFrame.new(x, -0.75, -depth), colors[(i % 2) + 1], M.Fabric)
	end
	p(m, "AwningBar", Vector3.new(w, 0.12, 0.12), cf * CFrame.new(0, -0.5, -depth + 0.05), C.Iron, M.Metal)
end
TownKit.awning = awning

local function shopfront(m, cf, w, palette, shop)
	-- storefront: a big framed window either side of a glazed door, a sign board, an awning and two wall lamps
	local h = 6.4
	local doorW = 2.8
	local winW = (w - doorW - 3) / 2
	for _, side in ipairs({ -1, 1 }) do
		local wcf = cf * CFrame.new(side * (doorW / 2 + 0.75 + winW / 2), 3.8, 0)
		p(m, "Storefront", Vector3.new(winW, 4.6, 0.12), wcf, hex("#6E8794"), M.Glass, false, { Reflectance = 0.2, Transparency = 0.1 })
		p(m, "StoreFrameTop", Vector3.new(winW + 0.4, 0.25, 0.3), wcf * CFrame.new(0, 2.4, -0.1), C.Iron, M.Metal)
		p(m, "StoreFrameL", Vector3.new(0.22, 4.8, 0.3), wcf * CFrame.new(-winW / 2, 0, -0.1), C.Iron, M.Metal)
		p(m, "StoreFrameR", Vector3.new(0.22, 4.8, 0.3), wcf * CFrame.new(winW / 2, 0, -0.1), C.Iron, M.Metal)
		p(m, "Kickplate", Vector3.new(winW + 0.4, 1.1, 0.35), wcf * CFrame.new(0, -2.9, -0.1), palette.trim, M.Concrete)
	end
	local dcf = cf * CFrame.new(0, 3.6, 0)
	p(m, "Door", Vector3.new(doorW, 6.6, 0.1), dcf * CFrame.new(0, -0.3, 0), hex("#6E8794"), M.Glass, false, { Transparency = 0.15 })
	p(m, "DoorFrame", Vector3.new(doorW + 0.4, 0.3, 0.3), dcf * CFrame.new(0, 3.1, -0.1), C.Iron, M.Metal)
	p(m, "DoorFrameL", Vector3.new(0.25, 6.6, 0.3), dcf * CFrame.new(-doorW / 2, -0.3, -0.1), C.Iron, M.Metal)
	p(m, "DoorFrameR", Vector3.new(0.25, 6.6, 0.3), dcf * CFrame.new(doorW / 2, -0.3, -0.1), C.Iron, M.Metal)
	p(m, "DoorHandle", Vector3.new(0.1, 1.2, 0.12), dcf * CFrame.new(0.9, -0.3, -0.15), C.Brass, M.Metal)
	p(m, "Step", Vector3.new(doorW + 1, 0.3, 1), cf * CFrame.new(0, 0.15, -0.5), C.Stone, M.Concrete, true)
	if shop then
		awning(m, cf * CFrame.new(0, h + 0.9, -0.1), w - 1, 2.6, shop.stripes or { C.White, C.Red })
		local board, label = Kit.sign(m, "ShopSign", Vector3.new(math.min(w - 2, 12), 1.5, 0.2), cf * CFrame.new(0, h + 2.6, -0.2), shop.name, C.White, hex("#2B2B2B"), 50)
		label.FontFace = Theme.Fonts.SemiBold
		p(m, "SignFrame", Vector3.new(math.min(w - 2, 12) + 0.3, 1.8, 0.15), cf * CFrame.new(0, h + 2.6, -0.1), palette.trim, M.SmoothPlastic)
	end
	for _, side in ipairs({ -1, 1 }) do
		local lamp = cf * CFrame.new(side * (w / 2 - 0.8), 7.4, -0.3)
		p(m, "WallLampArm", Vector3.new(0.1, 0.1, 0.6), lamp, C.Iron, M.Metal)
		local shade = p(m, "WallLamp", Vector3.new(0.5, 0.6, 0.5), lamp * CFrame.new(0, -0.2, -0.3), C.Warm, M.Neon)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = C.Warm, 0.7, 10, false
		light.Parent = shade
		TownKit.nightLight(shade)
	end
end

local function rooftop(m, cf, w, d, kind, rng)
	if kind == "tank" then
		local t = cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), 0, rng:NextNumber(-d / 6, d / 6))
		for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			p(m, "TankLeg", Vector3.new(0.25, 3, 0.25), t * CFrame.new(o[1] * 1.3, 1.5, o[2] * 1.3), C.Iron, M.Metal)
		end
		cyl(m, "Tank", 4.2, 3.6, t * CFrame.new(0, 5.1, 0) * up, hex("#8C6E4F"), M.WoodPlanks)
		for _, y in ipairs({ 3.6, 5.1, 6.6 }) do cyl(m, "Hoop", 0.15, 3.7, t * CFrame.new(0, y, 0) * up, C.Iron, M.Metal) end
		cyl(m, "TankRoof", 0.6, 3.9, t * CFrame.new(0, 7.5, 0) * up, C.Iron, M.Metal)
	end
	if kind == "ac" or kind == "tank" then
		for i = 1, 2 do
			local a = cf * CFrame.new(-w / 2 + 2.5 + i * 3.2, 0.7, d / 4)
			p(m, "AcUnit", Vector3.new(2.4, 1.4, 1.8), a, hex("#C9C6BF"), M.Metal, true)
			cyl(m, "AcFan", 0.08, 1.2, a * CFrame.new(0, 0.71, 0) * up, hex("#4A4C50"), M.DiamondPlate)
			p(m, "AcVent", Vector3.new(2.2, 0.9, 0.05), a * CFrame.new(0, 0, -0.93), hex("#9E9B94"), M.DiamondPlate)
		end
	end
	if kind == "rail" then
		for x = -w / 2 + 0.6, w / 2 - 0.6, 1.6 do p(m, "RailPost", Vector3.new(0.12, 1.4, 0.12), cf * CFrame.new(x, 0.7, -d / 2 + 0.6), C.Iron, M.Metal) end
		p(m, "Rail", Vector3.new(w - 1, 0.12, 0.12), cf * CFrame.new(0, 1.4, -d / 2 + 0.6), C.Iron, M.Metal)
		p(m, "AccessHut", Vector3.new(4, 3.4, 3.6), cf * CFrame.new(w / 2 - 3, 1.7, d / 4), hex("#C9C6BF"), M.Concrete, true)
		p(m, "HutDoor", Vector3.new(1.4, 2.5, 0.1), cf * CFrame.new(w / 2 - 3, 1.25, d / 4 - 1.82), C.Iron, M.Metal)
		-- a small roof garden
		for i = 0, 2 do TownKit.planter(m, cf * CFrame.new(-w / 2 + 2.2 + i * 3, 0, -d / 2 + 2.2), 2.2, 1.2, "flowers") end
	end
end

-- A plain facade (back or side of a building): framed windows on every floor, floor bands, an optional door with a
-- canopy and a wall lamp. faceCF sits on the ground at the middle of the wall, facing out along its local -Z.
local function plainFacade(m, faceCF, w, floors, pal, door)
	local cols = math.max(1, math.floor(w / 6))
	for f = 1, floors do
		local y = (f - 1) * FLOOR_H + 4.4
		if f > 1 then p(m, "FloorBand", Vector3.new(w, 0.4, 0.3), faceCF * CFrame.new(0, (f - 1) * FLOOR_H + 0.6, -0.12), pal.trim, M.Concrete) end
		for c = 1, cols do
			local x = -w / 2 + (c - 0.5) * (w / cols)
			if f == 1 and door and c == cols then
				p(m, "BackDoor", Vector3.new(2.4, 5.6, 0.12), faceCF * CFrame.new(x, 3, -0.05), hex("#4A4C50"), M.Metal)
				p(m, "BackDoorFrame", Vector3.new(2.8, 0.25, 0.25), faceCF * CFrame.new(x, 5.9, -0.1), pal.trim, M.Concrete)
				p(m, "BackCanopy", Vector3.new(3.4, 0.2, 1.2), faceCF * CFrame.new(x, 6.5, -0.6), C.Iron, M.Metal)
				p(m, "BackStep", Vector3.new(3, 0.3, 1), faceCF * CFrame.new(x, 0.15, -0.5), C.Stone, M.Concrete, true)
			else
				window(m, faceCF * CFrame.new(x, y, -0.05), 2.4, 3.4, pal.trim)
			end
		end
	end
end
TownKit.plainFacade = plainFacade

function TownKit.building(parent, name, cf, spec)
	local rng = Random.new(spec.seed or math.floor(cf.X * 3 + cf.Z))
	local w, d, floors = spec.w, spec.d, spec.floors
	local pal = spec.palette or TownKit.Palette[1]
	local h = floors * FLOOR_H + 1.5
	local m = model(parent, name, cf)
	-- body (its back half is hidden from the street; the front gets all the detail)
	p(m, "Body", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, d / 2), pal.wall, pal.mat, true)
	p(m, "Plinth", Vector3.new(w + 0.3, 2.2, d + 0.3), cf * CFrame.new(0, 0.1, d / 2), C.Stone, M.Concrete) -- reaches into the ground
	p(m, "Cornice", Vector3.new(w + 0.8, 0.7, d + 0.8), cf * CFrame.new(0, h - 0.35, d / 2), pal.trim, M.Concrete)
	p(m, "Parapet", Vector3.new(w + 0.4, 1.2, 0.5), cf * CFrame.new(0, h + 0.6, 0.05), pal.trim, M.Concrete)
	p(m, "Roof", Vector3.new(w - 0.4, 0.2, d - 0.4), cf * CFrame.new(0, h + 0.05, d / 2), hex("#5E5A54"), M.Concrete)
	if spec.far then
		-- distance version: lit window bands instead of individual windows
		for f = 1, floors do
			p(m, "WindowBand", Vector3.new(w - 1.6, 3.6, 0.12), cf * CFrame.new(0, (f - 1) * FLOOR_H + 5, -0.06), hex("#5F7480"), M.Glass, false, { Reflectance = 0.15 })
			p(m, "FloorBand", Vector3.new(w + 0.2, 0.4, 0.2), cf * CFrame.new(0, f * FLOOR_H + 0.6, -0.1), pal.trim, M.Concrete)
		end
		return m
	end
	-- ground floor: a shopfront, or windows and a door
	if spec.shop then
		shopfront(m, cf, w, pal, spec.shop)
	else
		local cols = math.max(1, math.floor(w / 6))
		for c = 1, cols do
			local x = -w / 2 + (c - 0.5) * (w / cols)
			if c == math.ceil(cols / 2) then
				p(m, "Door", Vector3.new(2.6, 6, 0.12), cf * CFrame.new(x, 3.2, -0.05), hex("#5E4632"), M.Wood)
				p(m, "DoorCanopy", Vector3.new(3.6, 0.25, 1.4), cf * CFrame.new(x, 6.6, -0.7), pal.trim, M.Concrete)
				p(m, "Step", Vector3.new(3.4, 0.3, 1), cf * CFrame.new(x, 0.15, -0.5), C.Stone, M.Concrete, true)
			else
				window(m, cf * CFrame.new(x, 4, -0.05), 2.8, 3.6, pal.trim)
			end
		end
	end
	-- upper floors: windows (some with balconies and shutters), floor bands
	local cols = math.max(1, math.floor(w / 5.5))
	for f = 2, floors do
		local y = (f - 1) * FLOOR_H + 4.6
		p(m, "FloorBand", Vector3.new(w + 0.2, 0.4, 0.3), cf * CFrame.new(0, (f - 1) * FLOOR_H + 0.6, -0.12), pal.trim, M.Concrete)
		for c = 1, cols do
			local x = -w / 2 + (c - 0.5) * (w / cols)
			window(m, cf * CFrame.new(x, y, -0.05), 2.6, 4, pal.trim)
			if spec.balconies and (c + f) % 3 == 0 then
				local b = cf * CFrame.new(x, y - 2.3, -0.9)
				p(m, "Balcony", Vector3.new(4, 0.3, 1.8), b, pal.trim, M.Concrete, true)
				for bx = -1.8, 1.8, 0.6 do p(m, "Baluster", Vector3.new(0.08, 1.2, 0.08), b * CFrame.new(bx, 0.75, -0.8), C.Iron, M.Metal) end
				p(m, "BalconyRail", Vector3.new(4, 0.1, 0.1), b * CFrame.new(0, 1.35, -0.8), C.Iron, M.Metal)
				if rng:NextNumber() < 0.5 then cyl(m, "Pot", 0.6, 0.6, b * CFrame.new(1.4, 0.45, -0.3) * up, hex("#B5654A"), M.Concrete) end
			elseif (c + f) % 4 == 1 then
				p(m, "Shutter", Vector3.new(1.1, 4, 0.12), cf * CFrame.new(x - 2.0, y, -0.12), spec.shutter or hex("#3C5A48"), M.Wood)
				p(m, "Shutter", Vector3.new(1.1, 4, 0.12), cf * CFrame.new(x + 2.0, y, -0.12), spec.shutter or hex("#3C5A48"), M.Wood)
			end
		end
	end
	-- a corner pilaster each side, for depth
	for _, side in ipairs({ -1, 1 }) do
		p(m, "Pilaster", Vector3.new(0.7, h - 1.2, 0.5), cf * CFrame.new(side * (w / 2 - 0.35), h / 2 + 0.6, -0.15), pal.trim, M.Concrete)
	end
	-- back and end walls that can be seen get windows too (no blank walls)
	if spec.back then plainFacade(m, cf * CFrame.new(0, 0, d) * CFrame.Angles(0, math.pi, 0), w - 1.4, floors, pal, true) end
	if spec.left then plainFacade(m, cf * CFrame.new(-w / 2, 0, d / 2) * CFrame.Angles(0, math.pi / 2, 0), d - 2, floors, pal, false) end
	if spec.right then plainFacade(m, cf * CFrame.new(w / 2, 0, d / 2) * CFrame.Angles(0, -math.pi / 2, 0), d - 2, floors, pal, false) end
	rooftop(m, cf * CFrame.new(0, h + 0.15, d / 2), w, d, spec.roof or "ac", rng)
	-- a drainpipe on one side
	cyl(m, "Drainpipe", h, 0.3, cf * CFrame.new(w / 2 - 0.9, h / 2, -0.25) * up, C.Iron, M.Metal)
	return m
end

------------------------------------------------------------------------
-- Beach
------------------------------------------------------------------------
-- A flat triangle a-b-c, `thickness` thick, from two wedges (no overlapping faces, so nothing flickers).
function TownKit.triangle(parent, name, a, b, c, thickness, color, material)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local upward = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(upward))
	local w1 = wedge(parent, name, Vector3.new(thickness, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, upward, back), color, material)
	local w2 = wedge(parent, name, Vector3.new(thickness, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, upward, -back), color, material)
	w1.CanCollide, w2.CanCollide = false, false
	return w1, w2
end

-- Patio/beach umbrella: a solid 8-panel canopy (triangles meeting at the top, alternating colors) with a short
-- valance around the rim, 8 thin ribs under it, a pole and a tip. `cframe` is the foot of the pole.
function TownKit.umbrella(parent, cframe, colorA, colorB)
	local m = model(parent, "Umbrella", cframe)
	cyl(m, "Pole", 6.2, 0.18, cframe * CFrame.new(0, 3.1, 0) * up, C.White, M.Metal, true)
	local top = cframe * CFrame.new(0, 6, 0)
	local apex = (top * CFrame.new(0, 0.3, 0)).Position
	local hub = (top * CFrame.new(0, -0.75, 0)).Position
	local rim = {}
	for i = 0, 7 do
		local a = rad(i * 45 + 22.5)
		rim[i] = (top * CFrame.new(math.cos(a) * 3.3, -1, math.sin(a) * 3.3)).Position
	end
	for i = 0, 7 do
		local a, b = rim[i], rim[(i + 1) % 8]
		local color = i % 2 == 0 and colorA or colorB
		TownKit.triangle(m, "Canopy", apex, a, b, 0.08, color, M.Fabric)
		local mid = (a + b) / 2
		local along = (b - a).Unit
		local outward = along:Cross(Vector3.yAxis).Unit
		if outward:Dot(mid - apex) < 0 then outward = -outward end
		p(m, "Valance", Vector3.new((b - a).Magnitude, 0.32, 0.05), CFrame.fromMatrix(mid - Vector3.yAxis * 0.18 + outward * 0.02, along, Vector3.yAxis), color, M.Fabric)
		-- rib: from the hub on the pole to just under the rim corner
		local tip = a - Vector3.yAxis * 0.1
		p(m, "Rib", Vector3.new(0.06, 0.06, (tip - hub).Magnitude), CFrame.lookAt((hub + tip) / 2, tip), C.White, M.Metal)
	end
	ball(m, "Tip", Vector3.new(0.32, 0.32, 0.32), CFrame.new(apex + Vector3.yAxis * 0.1), C.White, M.Metal)
	return m
end

function TownKit.beachChair(parent, cframe, color)
	local m = model(parent, "BeachChair", cframe)
	for _, x in ipairs({ -0.9, 0.9 }) do
		p(m, "Frame", Vector3.new(0.12, 0.12, 4.2), cframe * CFrame.new(x, 0.6, 0), C.White, M.Metal)
		p(m, "Leg", Vector3.new(0.12, 0.6, 0.12), cframe * CFrame.new(x, 0.3, -1.8), C.White, M.Metal)
		p(m, "Leg", Vector3.new(0.12, 0.6, 0.12), cframe * CFrame.new(x, 0.3, 1.8), C.White, M.Metal)
	end
	p(m, "Seat", Vector3.new(1.8, 0.08, 2.6), cframe * CFrame.new(0, 0.65, -0.6), color, M.Fabric)
	p(m, "Back", Vector3.new(1.8, 0.08, 1.8), cframe * CFrame.new(0, 1.2, 1.4) * CFrame.Angles(rad(40), 0, 0), color, M.Fabric)
	return m
end

function TownKit.towel(parent, cframe, colorA, colorB)
	local m = model(parent, "Towel", cframe)
	for i = 0, 4 do p(m, "Stripe", Vector3.new(2.4, 0.04, 0.9), cframe * CFrame.new(0, 0.05, -1.8 + i * 0.9), i % 2 == 0 and colorA or colorB, M.Fabric) end
	return m
end

function TownKit.surfboard(parent, cframe, color)
	local m = model(parent, "Surfboard", cframe)
	local board = p(m, "Board", Vector3.new(1.4, 6, 0.2), cframe * CFrame.new(0, 3, 0), color, M.SmoothPlastic, true)
	p(m, "Stripe", Vector3.new(0.25, 5.6, 0.21), cframe * CFrame.new(0, 3, 0), C.White, M.SmoothPlastic)
	ball(m, "Nose", Vector3.new(1.4, 1.4, 0.2), cframe * CFrame.new(0, 6, 0), color, M.SmoothPlastic)
	return m, board
end

------------------------------------------------------------------------
-- Park, plaza and parking pieces
------------------------------------------------------------------------
local WATER = hex("#6FB4C8")
local STONE_LIGHT = hex("#CFC6B6")

-- Three-tier fountain: round basin with a rim and water, a column, a middle bowl, a top bowl and a spray.
function TownKit.fountain(parent, cframe, scale)
	scale = scale or 1
	local m = model(parent, "Fountain", cframe)
	local f = cframe
	cyl(m, "Basin", 1.6, 13 * scale, f * CFrame.new(0, 0.8, 0) * up, hex("#B5AA98"), M.Concrete, true)
	cyl(m, "BasinRim", 0.3, 13.6 * scale, f * CFrame.new(0, 1.7, 0) * up, STONE_LIGHT, M.Concrete)
	cyl(m, "Water", 0.1, 12 * scale, f * CFrame.new(0, 1.88, 0) * up, WATER, M.Glass) -- above the rim disc
	cyl(m, "Column", 3.4, 1.6, f * CFrame.new(0, 3, 0) * up, STONE_LIGHT, M.Concrete, true)
	cyl(m, "MidBowl", 0.6, 6, f * CFrame.new(0, 4.6, 0) * up, STONE_LIGHT, M.Concrete)
	cyl(m, "MidWater", 0.1, 5.4, f * CFrame.new(0, 4.92, 0) * up, WATER, M.Glass)
	cyl(m, "TopColumn", 2, 0.8, f * CFrame.new(0, 5.9, 0) * up, STONE_LIGHT, M.Concrete)
	cyl(m, "TopBowl", 0.4, 2.6, f * CFrame.new(0, 7, 0) * up, STONE_LIGHT, M.Concrete)
	local spray = p(m, "Spray", Vector3.new(0.4, 1.2, 0.4), f * CFrame.new(0, 7.8, 0), hex("#BFE3EE"), M.Glass, false, { Transparency = 0.4 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(hex("#DFF3F8"))
	emitter.Size = NumberSequence.new(0.25)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(4, 6)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Rate = 30
	emitter.Parent = spray
	-- four small jets from the basin rim toward the middle
	for i = 0, 3 do
		local a = i * math.pi / 2
		cyl(m, "Jet", 0.5, 0.4, f * CFrame.new(math.cos(a) * 5.4 * scale, 2.1, math.sin(a) * 5.4 * scale) * up, hex("#9EA2A8"), M.Metal)
	end
	return m
end

-- A path made of straight pieces through a list of points (curves = many points). Lies on the ground (top at y + 0.15).
function TownKit.path(parent, points, width, color, edgeColor)
	local m = model(parent, "Path", CFrame.new(points[1]))
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		p(m, "PathStone", Vector3.new(width, 0.3, len + width * 0.35), cf, color or hex("#D8C9AE"), M.Pavement, true)
		if edgeColor then
			for _, side in ipairs({ -1, 1 }) do
				-- a bit taller than the stone (its top would sit almost level with it and flicker)
				p(m, "PathEdge", Vector3.new(0.3, 0.4, len + 0.3), cf * CFrame.new(side * (width / 2 + 0.1), 0.05, 0), edgeColor, M.Concrete)
			end
		end
	end
	return m
end

-- A round path (ring) merged with the straight paths that run into it, as ONE part (CSG): no overlapping slabs, so
-- nothing flickers and the paving texture runs on without seams. `center` is the ring center at the paths' height,
-- `radius` the middle of the ring. `paths` = Path models (TownKit.path) whose stones run into the ring: their stones
-- are merged in, their edge strips are cut back to the ring's outside. Returns the new part (or nil if CSG failed).
function TownKit.pathRing(parent, center, radius, width, color, paths)
	local outerR, innerR = radius + width / 2, radius - width / 2
	local thickness = 0.3
	local function disc(d, h)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(h, d, d)
		part.CFrame = CFrame.new(center) * up
		part.Anchored = true
		part.Material = M.Pavement
		part.Color = color
		part.Parent = workspace
		return part
	end
	local outer, inner = disc(outerR * 2, thickness), disc(innerR * 2, thickness + 0.2)
	local ok, ring = pcall(function() return outer:SubtractAsync({ inner }) end)
	inner:Destroy()
	if not ok or not ring then
		outer:Destroy()
		warn("[TownKit.pathRing] CSG failed: " .. tostring(ring))
		return nil
	end
	outer:Destroy()
	local stones = {}
	for _, path in ipairs(paths or {}) do
		for _, piece in ipairs(path:GetChildren()) do
			if piece.Name == "PathStone" then
				table.insert(stones, piece)
			elseif piece.Name == "PathEdge" and piece:IsA("BasePart") then
				-- cut the edge strip back to where it meets the ring's outside
				local axis = piece.CFrame.LookVector
				local half = piece.Size.Z / 2
				local a, b = piece.Position - axis * half, piece.Position + axis * half
				local function inside(point) return Vector2.new(point.X - center.X, point.Z - center.Z).Magnitude < outerR end
				if inside(a) ~= inside(b) then
					local lo, hi = 0, 1 -- binary search the crossing along a -> b
					for _ = 1, 24 do
						local mid = (lo + hi) / 2
						if inside(a:Lerp(b, mid)) == inside(a) then lo = mid else hi = mid end
					end
					local cross = a:Lerp(b, lo)
					local keepFrom = inside(a) and cross or a
					local keepTo = inside(a) and b or cross
					local length = (keepTo - keepFrom).Magnitude
					piece.Size = Vector3.new(piece.Size.X, piece.Size.Y, length)
					piece.CFrame = CFrame.lookAt((keepFrom + keepTo) / 2, keepTo)
				end
			end
		end
	end
	local merged = ring
	if #stones > 0 then
		local okUnion, union = pcall(function() return ring:UnionAsync(stones) end)
		if okUnion and union then
			ring:Destroy()
			for _, stone in ipairs(stones) do stone:Destroy() end
			merged = union
		else
			warn("[TownKit.pathRing] merging the straight paths failed: " .. tostring(union))
		end
	end
	merged.Name = "PathRing"
	merged.UsePartColor = true
	merged.Color = color
	merged.Material = M.Pavement
	merged.Anchored = true
	merged.CastShadow = false
	merged.Parent = parent
	return merged
end

function TownKit.picnicTable(parent, cframe, color)
	local m = model(parent, "PicnicTable", cframe)
	color = color or C.Wood
	for i = -1, 1 do p(m, "TopPlank", Vector3.new(5, 0.2, 0.75), cframe * CFrame.new(0, 2.6, i * 0.8), color, M.WoodPlanks, i == 0) end
	for _, z in ipairs({ -2.1, 2.1 }) do
		p(m, "SeatPlank", Vector3.new(5, 0.2, 0.8), cframe * CFrame.new(0, 1.5, z), color, M.WoodPlanks, true)
	end
	for _, x in ipairs({ -1.9, 1.9 }) do
		p(m, "LegA", Vector3.new(0.25, 3, 0.3), cframe * CFrame.new(x, 1.3, -0.6) * CFrame.Angles(rad(-25), 0, 0), C.WoodDark, M.Wood)
		p(m, "LegB", Vector3.new(0.25, 3, 0.3), cframe * CFrame.new(x, 1.3, 0.6) * CFrame.Angles(rad(25), 0, 0), C.WoodDark, M.Wood)
		p(m, "SeatBeam", Vector3.new(0.25, 0.25, 5), cframe * CFrame.new(x, 1.3, 0), C.WoodDark, M.Wood)
	end
	return m
end

-- Playground pieces (bright, chunky, kid-friendly)
function TownKit.slide(parent, cframe, color)
	local m = model(parent, "Slide", cframe)
	color = color or hex("#F2C14E")
	local frame = hex("#2E6E8E")
	for _, o in ipairs({ { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } }) do
		cyl(m, "Post", 7, 0.35, cframe * CFrame.new(o[1], 3.5, o[2]) * up, frame, M.Metal, true)
		ball(m, "PostCap", Vector3.new(0.5, 0.5, 0.5), cframe * CFrame.new(o[1], 7.05, o[2]), color, M.SmoothPlastic)
	end
	p(m, "Deck", Vector3.new(3.2, 0.3, 3.2), cframe * CFrame.new(0, 4, 0), hex("#C9B48A"), M.WoodPlanks, true)
	p(m, "Roof", Vector3.new(3.6, 0.3, 3.6), cframe * CFrame.new(0, 7, 0), color, M.SmoothPlastic)
	for _, x in ipairs({ -1.4, 1.4 }) do p(m, "Rail", Vector3.new(0.15, 0.15, 3), cframe * CFrame.new(x, 5.1, 0), frame, M.Metal) end
	-- slide chute down the front (+Z), with side lips
	local chute = cframe * CFrame.new(0, 2.15, 4.2) * CFrame.Angles(rad(-35), 0, 0)
	p(m, "Chute", Vector3.new(1.8, 0.2, 6.2), chute, color, M.SmoothPlastic, true)
	for _, x in ipairs({ -0.95, 0.95 }) do p(m, "ChuteLip", Vector3.new(0.15, 0.6, 6.2), chute * CFrame.new(x, 0.3, 0), color, M.SmoothPlastic) end
	-- ladder at the back
	for _, x in ipairs({ -0.7, 0.7 }) do p(m, "LadderSide", Vector3.new(0.15, 4.4, 0.15), cframe * CFrame.new(x, 2, -2.2) * CFrame.Angles(rad(-12), 0, 0), frame, M.Metal) end
	for i = 0, 4 do p(m, "LadderRung", Vector3.new(1.4, 0.12, 0.12), cframe * CFrame.new(0, 0.5 + i * 0.8, -2.55 + i * 0.17), frame, M.Metal) end
	return m
end

function TownKit.swings(parent, cframe)
	local m = model(parent, "Swings", cframe)
	local frame = hex("#E86A6A")
	for _, x in ipairs({ -4, 4 }) do
		p(m, "LegA", Vector3.new(0.3, 7.4, 0.3), cframe * CFrame.new(x, 3.5, -1.2) * CFrame.Angles(rad(18), 0, 0), frame, M.Metal, true)
		p(m, "LegB", Vector3.new(0.3, 7.4, 0.3), cframe * CFrame.new(x, 3.5, 1.2) * CFrame.Angles(rad(-18), 0, 0), frame, M.Metal, true)
	end
	cyl(m, "TopBar", 8.4, 0.35, cframe * CFrame.new(0, 7, 0), frame, M.Metal)
	for i, x in ipairs({ -2, 2 }) do
		for _, dx in ipairs({ -0.6, 0.6 }) do p(m, "Chain", Vector3.new(0.06, 4.8, 0.06), cframe * CFrame.new(x + dx, 4.6, 0), hex("#9EA2A8"), M.Metal) end
		p(m, "Seat", Vector3.new(1.5, 0.15, 0.6), cframe * CFrame.new(x, 2.2, 0), i == 1 and hex("#F2C14E") or hex("#6FA8DC"), M.Rubber)
	end
	return m
end

function TownKit.climber(parent, cframe)
	local m = model(parent, "Climber", cframe)
	local colors = { hex("#7CC6A5"), hex("#F2C14E"), hex("#6FA8DC"), hex("#E86A6A") }
	-- a dome of arches
	for i = 0, 3 do
		local a = cframe * CFrame.Angles(0, rad(i * 45), 0)
		for s = 0, 7 do
			local t0, t1 = s / 8 * math.pi, (s + 1) / 8 * math.pi
			local p0 = Vector3.new(math.cos(t0) * 3, math.sin(t0) * 3, 0)
			local p1 = Vector3.new(math.cos(t1) * 3, math.sin(t1) * 3, 0)
			local mid = (p0 + p1) / 2
			p(m, "Arch", Vector3.new(0.18, 0.18, (p1 - p0).Magnitude + 0.1), a * CFrame.lookAt(mid, p1), colors[i + 1], M.Metal, s == 0 or s == 7)
		end
	end
	return m
end

-- Original generic car (no brand): lower body, cabin with glass, wheels with rims, lights, bumpers, mirrors.
function TownKit.car(parent, cframe, color)
	local m = model(parent, "Car", cframe)
	local glass = hex("#3E5260")
	p(m, "Body", Vector3.new(5, 1.6, 10), cframe * CFrame.new(0, 1.6, 0), color, M.SmoothPlastic, true)
	p(m, "Hood", Vector3.new(4.8, 0.3, 3), cframe * CFrame.new(0, 2.45, -3.3), color, M.SmoothPlastic)
	p(m, "Trunk", Vector3.new(4.8, 0.3, 2), cframe * CFrame.new(0, 2.45, 3.8), color, M.SmoothPlastic)
	p(m, "Cabin", Vector3.new(4.6, 1.8, 4.6), cframe * CFrame.new(0, 3.3, 0.6), color, M.SmoothPlastic)
	p(m, "Roof", Vector3.new(4.3, 0.2, 4.0), cframe * CFrame.new(0, 4.25, 0.6), color, M.SmoothPlastic)
	p(m, "Windshield", Vector3.new(4.3, 1.5, 0.12), cframe * CFrame.new(0, 3.3, -1.75), glass, M.Glass, false, { Reflectance = 0.2 })
	p(m, "RearGlass", Vector3.new(4.3, 1.4, 0.12), cframe * CFrame.new(0, 3.3, 2.95), glass, M.Glass, false, { Reflectance = 0.2 })
	for _, x in ipairs({ -2.32, 2.32 }) do
		p(m, "SideGlass", Vector3.new(0.12, 1.3, 4.0), cframe * CFrame.new(x, 3.35, 0.6), glass, M.Glass, false, { Reflectance = 0.2 })
		p(m, "Mirror", Vector3.new(0.5, 0.35, 0.3), cframe * CFrame.new(x * 1.12, 2.9, -1.5), color, M.SmoothPlastic)
		p(m, "DoorLine", Vector3.new(0.05, 1.3, 0.06), cframe * CFrame.new(x * 1.08, 1.7, 0.5), hex("#1A1A1A"), M.SmoothPlastic)
		p(m, "Handle", Vector3.new(0.06, 0.12, 0.5), cframe * CFrame.new(x * 1.085, 2.1, 1.1), hex("#C9CCD2"), M.Metal)
		for _, z in ipairs({ -3.2, 3.2 }) do
			cyl(m, "Tire", 0.9, 2.1, cframe * CFrame.new(x * 0.98, 1.05, z), hex("#1A1A1A"), M.Rubber)
			cyl(m, "Rim", 0.92, 1.2, cframe * CFrame.new(x * 0.98, 1.05, z), hex("#C9CCD2"), M.Metal)
			p(m, "Arch", Vector3.new(0.3, 0.3, 2.6), cframe * CFrame.new(x * 1.02, 2.15, z), hex("#1A1A1A"), M.SmoothPlastic)
		end
	end
	p(m, "BumperFront", Vector3.new(5.1, 0.6, 0.5), cframe * CFrame.new(0, 1.1, -5.1), hex("#2B2B2B"), M.SmoothPlastic)
	p(m, "BumperBack", Vector3.new(5.1, 0.6, 0.5), cframe * CFrame.new(0, 1.1, 5.1), hex("#2B2B2B"), M.SmoothPlastic)
	p(m, "Grille", Vector3.new(2.4, 0.6, 0.1), cframe * CFrame.new(0, 1.9, -5.02), hex("#2B2B2B"), M.Metal)
	for _, x in ipairs({ -1.8, 1.8 }) do
		p(m, "Headlight", Vector3.new(0.9, 0.4, 0.1), cframe * CFrame.new(x, 2.0, -5.02), hex("#F2EEE6"), M.Glass)
		p(m, "Taillight", Vector3.new(0.9, 0.4, 0.1), cframe * CFrame.new(x, 2.0, 5.02), hex("#C0392B"), M.Glass)
	end
	p(m, "Plate", Vector3.new(1.3, 0.45, 0.06), cframe * CFrame.new(0, 1.35, 5.38), hex("#F2EEE6"), M.SmoothPlastic)
	return m
end

-- Basketball hoop on a padded pole: backboard with a square, a rim and a net, facing local -Z.
function TownKit.hoop(parent, cframe)
	local m = model(parent, "Hoop", cframe)
	p(m, "Base", Vector3.new(2, 0.6, 2), cframe * CFrame.new(0, 0.3, 0), hex("#2B2B2B"), M.Concrete, true)
	cyl(m, "Pole", 10, 0.5, cframe * CFrame.new(0, 5, 0) * up, hex("#2E6E8E"), M.Metal, true)
	p(m, "PolePad", Vector3.new(0.9, 3, 0.9), cframe * CFrame.new(0, 2, 0), hex("#1F5FBF"), M.Fabric)
	p(m, "Arm", Vector3.new(0.3, 0.3, 2.6), cframe * CFrame.new(0, 9.6, -1.2), hex("#2E6E8E"), M.Metal)
	p(m, "Backboard", Vector3.new(6, 3.6, 0.2), cframe * CFrame.new(0, 10.4, -2.5), hex("#F2EEE6"), M.SmoothPlastic, true)
	p(m, "BoardEdge", Vector3.new(6.2, 3.8, 0.12), cframe * CFrame.new(0, 10.4, -2.4), hex("#D7262E"), M.SmoothPlastic)
	for _, e in ipairs({ { 0, 0.75, 2.4, 0.12 }, { 0, -0.75, 2.4, 0.12 }, { -1.15, 0, 0.12, 1.6 }, { 1.15, 0, 0.12, 1.6 } }) do
		p(m, "Square", Vector3.new(e[3], e[4], 0.05), cframe * CFrame.new(e[1], 9.8 + e[2], -2.62), hex("#D7262E"), M.SmoothPlastic)
	end
	local rimCF = cframe * CFrame.new(0, 9.2, -3.5)
	for i = 0, 11 do
		local a0, a1 = i / 12 * math.pi * 2, (i + 1) / 12 * math.pi * 2
		local p0, p1 = Vector3.new(math.cos(a0) * 0.9, 0, math.sin(a0) * 0.9), Vector3.new(math.cos(a1) * 0.9, 0, math.sin(a1) * 0.9)
		p(m, "Rim", Vector3.new(0.1, 0.1, (p1 - p0).Magnitude + 0.05), rimCF * CFrame.lookAt((p0 + p1) / 2, p1), hex("#E8761C"), M.Metal)
		if i % 2 == 0 then p(m, "Net", Vector3.new(0.05, 1.2, 0.05), rimCF * CFrame.new(math.cos(a0) * 0.75, -0.6, math.sin(a0) * 0.75), hex("#F2EEE6"), M.Fabric) end
	end
	return m
end

-- Clock post: a fluted pole with a four-sided clock head (numbers as tick marks, hands at a sunny afternoon time).
function TownKit.clockPost(parent, position)
	local base = CFrame.new(position)
	local m = model(parent, "ClockPost", base)
	cyl(m, "Plinth", 1.2, 1.6, base * CFrame.new(0, 0.6, 0) * up, C.Iron, M.Metal, true)
	cyl(m, "Pole", 9, 0.5, base * CFrame.new(0, 5.5, 0) * up, C.Iron, M.Metal, true)
	cyl(m, "Ring", 0.3, 0.8, base * CFrame.new(0, 3, 0) * up, C.Brass, M.Metal)
	local head = base * CFrame.new(0, 11, 0)
	p(m, "Head", Vector3.new(2.4, 2.4, 2.4), head, C.Iron, M.Metal)
	p(m, "HeadCap", Vector3.new(2.7, 0.3, 2.7), head * CFrame.new(0, 1.35, 0), C.Iron, M.Metal)
	ball(m, "Finial", Vector3.new(0.5, 0.5, 0.5), head * CFrame.new(0, 1.7, 0), C.Brass, M.Metal)
	for i = 0, 3 do
		local face = head * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -1.21)
		cyl(m, "Dial", 0.06, 2, face * CFrame.Angles(0, rad(90), 0), C.White, M.SmoothPlastic)
		cyl(m, "DialRim", 0.05, 2.2, face * CFrame.new(0, 0, 0.02) * CFrame.Angles(0, rad(90), 0), C.Brass, M.Metal)
		for t = 0, 11 do
			local a = t / 12 * math.pi * 2
			p(m, "Tick", Vector3.new(0.08, t % 3 == 0 and 0.3 or 0.15, 0.03), face * CFrame.new(math.sin(a) * 0.8, math.cos(a) * 0.8, -0.04) * CFrame.Angles(0, 0, -a), C.Iron, M.SmoothPlastic)
		end
		p(m, "HourHand", Vector3.new(0.1, 0.5, 0.03), face * CFrame.Angles(0, 0, rad(-75)) * CFrame.new(0, 0.25, -0.06), C.Iron, M.SmoothPlastic)
		p(m, "MinuteHand", Vector3.new(0.07, 0.75, 0.03), face * CFrame.Angles(0, 0, rad(-180)) * CFrame.new(0, 0.37, -0.07), C.Iron, M.SmoothPlastic)
	end
	return m
end

-- A smoothie/ice-pop cart with a striped umbrella (original, no brand)
function TownKit.cart(parent, cframe, colorA, colorB)
	local m = model(parent, "Cart", cframe)
	p(m, "Box", Vector3.new(4, 2.6, 2.2), cframe * CFrame.new(0, 2.1, 0), colorA, M.SmoothPlastic, true)
	p(m, "Top", Vector3.new(4.2, 0.2, 2.4), cframe * CFrame.new(0, 3.5, 0), C.White, M.SmoothPlastic)
	p(m, "Stripe", Vector3.new(4.02, 0.4, 2.22), cframe * CFrame.new(0, 1.5, 0), colorB, M.SmoothPlastic)
	for _, x in ipairs({ -1.5, 1.5 }) do
		cyl(m, "Wheel", 0.3, 1.3, cframe * CFrame.new(x, 0.65, -1.2), hex("#2B2B2B"), M.Rubber)
		cyl(m, "Wheel", 0.3, 1.3, cframe * CFrame.new(x, 0.65, 1.2), hex("#2B2B2B"), M.Rubber)
	end
	p(m, "PushBar", Vector3.new(0.15, 0.15, 2.4), cframe * CFrame.new(2.6, 3.2, 0), C.Iron, M.Metal)
	for _, z in ipairs({ -1, 1 }) do p(m, "PushArm", Vector3.new(0.7, 0.12, 0.12), cframe * CFrame.new(2.25, 3.2, z), C.Iron, M.Metal) end
	for i = 0, 3 do cyl(m, "Cup", 0.5, 0.45, cframe * CFrame.new(-1.4 + i * 0.6, 3.85, -0.5) * up, FLOWERS[i + 1], M.SmoothPlastic) end
	TownKit.umbrella(m, cframe * CFrame.new(-1.2, 3.6, 0), colorB, C.White):ScaleTo(0.6)
	return m
end

return TownKit
