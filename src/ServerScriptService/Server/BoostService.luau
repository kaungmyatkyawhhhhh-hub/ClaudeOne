-- Every temporary or permanent bonus in one place, so gains/coins/stamina refill always multiply the same way.
-- Sources are per player (shake, gamepasses) or for the whole server (rush hour, server boost).
-- A source: { gains = x, coins = x, regen = x, untilTime = server time or nil (= permanent) }.
-- Players get attributes the client reads: GainsBoost, CoinsBoost (current multipliers) and ShakeEnds (server time).
-- Gains still go through Config.Gains, which caps all stacked multipliers together.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stamina = require(ReplicatedStorage.Shared.Config.Stamina)

local BoostService = {}

local playerSources = {} -- [player] = { [name] = source }
local globalSources = {} -- [name] = source

local function now()
	return Workspace:GetServerTimeNow()
end

local function alive(source, t)
	return source and (source.untilTime == nil or source.untilTime > t)
end

local function product(player, key)
	local t = now()
	local total = 1
	for _, source in pairs(globalSources) do
		if alive(source, t) and source[key] then total *= source[key] end
	end
	for _, source in pairs(playerSources[player] or {}) do
		if alive(source, t) and source[key] then total *= source[key] end
	end
	return total
end

local function publish(player)
	player:SetAttribute("GainsBoost", product(player, "gains"))
	player:SetAttribute("CoinsBoost", product(player, "coins"))
	local shake = playerSources[player] and playerSources[player].Shake
	player:SetAttribute("ShakeEnds", alive(shake, now()) and shake.untilTime or nil)
	player:SetAttribute("Recovery", BoostService.StationOf(player)) -- the station you stand in (a small note, ShakeClient)
end

function BoostService.SetPlayer(player, name, source)
	playerSources[player] = playerSources[player] or {}
	playerSources[player][name] = source
	publish(player)
end

function BoostService.GetPlayer(player, name)
	local source = playerSources[player] and playerSources[player][name]
	return alive(source, now()) and source or nil
end

-- Global sources also mirror their end time on ReplicatedStorage as "<name>Ends" for the client.
function BoostService.SetGlobal(name, source)
	globalSources[name] = source
	ReplicatedStorage:SetAttribute(name .. "Ends", source and source.untilTime or nil)
	for _, player in ipairs(Players:GetPlayers()) do publish(player) end
end

function BoostService.GetGlobal(name)
	local source = globalSources[name]
	return alive(source, now()) and source or nil
end

function BoostService.Gains(player)
	return product(player, "gains")
end

function BoostService.Coins(player)
	return product(player, "coins")
end

-- Drinking a shake: +Duration seconds of boost (stacking up to MaxDuration).
function BoostService.AddShake(player)
	local current = BoostService.GetPlayer(player, "Shake")
	local start = current and current.untilTime or now()
	local untilTime = math.min(start + Stamina.Shake.Duration, now() + Stamina.Shake.MaxDuration)
	BoostService.SetPlayer(player, "Shake", { gains = Stamina.Shake.GainsBoost, untilTime = untilTime })
end

------------------------------------------------------------------------
-- Recovery stations: models with a Recovery attribute (e.g. the stretching area = "StretchMat")
------------------------------------------------------------------------
local stations = {}

local function scan()
	table.clear(stations)
	for _, instance in ipairs(Workspace:GetDescendants()) do
		local kind = instance:GetAttribute("Recovery")
		if kind and Stamina.Recovery[kind] and (instance:IsA("Model") or instance:IsA("BasePart")) then
			table.insert(stations, { instance = instance, kind = kind, multiplier = Stamina.Recovery[kind] })
		end
	end
end

local function inside(instance, position)
	local cframe, size
	if instance:IsA("Model") then
		cframe, size = instance:GetBoundingBox()
	else
		cframe, size = instance.CFrame, instance.Size
	end
	local p = cframe:PointToObjectSpace(position)
	-- generous height: the player stands on the mat
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2 and p.Y > -size.Y / 2 - 1 and p.Y < size.Y / 2 + 7
end

-- The recovery station the player stands in right now, or nil.
local function stationAt(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	for _, station in ipairs(stations) do
		if station.instance.Parent and inside(station.instance, root.Position) then return station end
	end
	return nil
end

-- The kind of station ("Sauna", "StretchMat", "Cardio") the player stands in, or nil.
function BoostService.StationOf(player)
	local station = stationAt(player)
	return station and station.kind or nil
end

-- Stamina refill multiplier right now (stations x regen sources).
function BoostService.Regen(player)
	local station = stationAt(player)
	return product(player, "regen") * (station and station.multiplier or 1)
end

function BoostService.Start()
	scan()
	Players.PlayerRemoving:Connect(function(player) playerSources[player] = nil end)
	-- expire sources and keep the client attributes current
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do publish(player) end
		end
	end)
	task.delay(5, scan) -- in case parts streamed in late
end

return BoostService
