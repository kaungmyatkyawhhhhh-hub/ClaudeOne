-- Loads repo ModuleScripts outside Roblox: a fake `script` tree mirrors src/ folders, and `require(node)` runs the
-- file with that `script`. Enough for pure config/logic modules (no Roblox services).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- Roblox's Random, enough for tests
local FakeRandom = {}
FakeRandom.__index = FakeRandom
function FakeRandom.new(seed)
	if seed then math.randomseed(seed) end
	return setmetatable({}, FakeRandom)
end
function FakeRandom:NextInteger(a, b) return math.random(a, b) end
function FakeRandom:NextNumber(a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end
local cache = {}

-- Build the whole fake instance tree up front (fs calls can't run inside metamethods).
local function build(dir, name, parent)
	local node = { __path = dir, Name = name, Parent = parent, WaitForChild = function(me, child) return me[child] end,
		FindFirstChild = function(me, child) return rawget(me, child) end }
	if fs.isDir(dir) then
		for _, entry in fs.readDir(dir) do
			local full = dir .. "/" .. entry
			if fs.isDir(full) then
				node[entry] = build(full, entry, node)
			elseif entry:sub(-5) == ".luau" then
				local childName = entry:sub(1, -6):gsub("%.server$", ""):gsub("%.client$", "")
				node[childName] = node[childName] or { __path = full:sub(1, -6), Name = childName, Parent = node }
			end
		end
	end
	return node
end
local process = require("@lune/process")
local root = build(process.cwd .. "/src", "src", nil) -- run from the repo root

local function load(node)
	local path = rawget(node, "__path") .. ".luau"
	if cache[path] ~= nil then return cache[path] end
	local source = fs.readFile(path)
	local env = setmetatable({
		script = node,
		require = function(target) return load(target) end,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame, UDim = roblox.UDim, UDim2 = roblox.UDim2,
		Font = roblox.Font, Enum = roblox.Enum, Random = FakeRandom,
	}, { __index = _G })
	local fn = luau.load(source, { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

function Harness.module(relative)
	-- relative like "ReplicatedStorage/Shared/Config/Quests"
	local parts = string.split(relative, "/")
	local node = root
	for _, part in parts do node = node[part] end
	assert(node, "no module " .. relative)
	return load(node)
end

local failures = 0
function Harness.check(cond, label)
	if cond then print("  ok   " .. label) else failures += 1; print("  FAIL " .. label) end
end
function Harness.done()
	print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
	if failures > 0 then error("tests failed") end
end
return Harness
