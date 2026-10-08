--[[
	Dumps every car as dense meshes for tools/make_glb.py (run from the repo root):
	  lune run tools/export_models.luau
	Writes build/models/cars.json: per car the body layers, one front wheel and
	marker points (origin / axes / wheel hub / plate / exhaust tips).
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local root = "src/shared/"
local cache = {}
local env
local function loadModule(name)
	if cache[name] then
		return cache[name]
	end
	local src = fs.readFile(root .. name .. ".lua")
	src = src:gsub("require%(script%.Parent%.(%w+)%)", 'REQ("%1")')
	local fn = luau.load(src, { debugName = name, environment = env })
	cache[name] = fn()
	return cache[name]
end
-- Lune's CFrame.lookAt differs from Roblox's; use the Roblox convention
local function lookAt(at, target, up)
	up = up or roblox.Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-5 then
		right = look:Cross(roblox.Vector3.new(0, 0, 1))
	end
	right = right.Unit
	return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
end
local CF = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })
env = setmetatable({
	REQ = loadModule, CFrame = CF, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum,
	Instance = roblox.Instance, PhysicalProperties = roblox.PhysicalProperties, UDim = roblox.UDim,
	UDim2 = roblox.UDim2, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2,
}, { __index = _G })

local CarMesh = loadModule("CarMesh")
local CarBuilder = loadModule("CarBuilder")
local Cars = loadModule("Cars")
CarMesh.hq = true

local function r4(x)
	return math.floor(x * 10000 + 0.5) / 10000
end
local function pack(layers)
	local out = {}
	for name, L in layers do
		local v, n = {}, {}
		for i, p in L.verts do
			local q = L.normals[i]
			table.insert(v, r4(p.X)); table.insert(v, r4(p.Y)); table.insert(v, r4(p.Z))
			table.insert(n, r4(q.X)); table.insert(n, r4(q.Y)); table.insert(n, r4(q.Z))
		end
		out[name] = { v = v, n = n, t = L.tris }
	end
	return out
end
local function vec(p)
	return { r4(p.X), r4(p.Y), r4(p.Z) }
end

local result = {}
for _, spec in Cars.List do
	local D = CarBuilder.getDims(spec.Class, spec.Id)
	local layers, meta = CarMesh.build(spec.Id, spec.Class, D, false)
	local ds = CarMesh.design(spec.Id, spec.Class, D)
	local hub = { D.W / 2 - D.wheelW / 2 - 0.06, D.wheelR, -D.wb / 2 } -- front right
	local exhausts = {}
	for _, p in meta.exhausts or {} do
		table.insert(exhausts, vec(p))
	end
	local c, a = spec.Color, spec.Accent or roblox.Color3.fromRGB(18, 18, 20)
	result[spec.Id] = {
		name = spec.Name,
		body = pack(layers),
		wheel = pack(CarMesh.wheel(ds.wheel, D.wheelR, D.wheelW, ds.rimFrac, false)),
		hub = hub,
		plate = if meta.plate then vec(meta.plate.Position) else nil,
		exhausts = exhausts,
		color = { c.R, c.G, c.B },
		accent = { a.R, a.G, a.B },
		rim = ds.rim,
		caliper = ds.caliper,
		drl = ds.drl or { 255, 255, 255 },
	}
	print(spec.Id)
end
fs.writeDir("build/models")
fs.writeFile("build/models/cars.json", serde.encode("json", result))
