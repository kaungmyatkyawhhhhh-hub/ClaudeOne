--[[
	PlayerData
	Cash + owned cars, saved with DataStoreService when available
	(publish the place and enable "Studio Access to API Services" to save in Studio).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))

export type Profile = {
	Cash: number,
	Owned: { [string]: boolean },
	Selected: string,
	Loaded: boolean,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("CityLegends_v1")
	end)
	if ok then
		store = result
	else
		warn("[CityLegends] DataStore unavailable, progress will not be saved:", result)
	end
end

local function defaultProfile(): Profile
	return {
		Cash = Config.Economy.StartingCash,
		Owned = { [Cars.StarterId] = true },
		Selected = Cars.StarterId,
		Loaded = false,
	}
end

local function makeLeaderstats(player: Player, cash: number)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Cash"
	value.Value = cash
	value.Parent = stats
	stats.Parent = player
end

function PlayerData.load(player: Player): Profile
	local profile = defaultProfile()
	if store then
		local ok, saved = pcall(function()
			return (store :: DataStore):GetAsync("p_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			if type(saved.Cash) == "number" then
				profile.Cash = math.max(0, math.floor(saved.Cash))
			end
			if type(saved.Owned) == "table" then
				for _, id in saved.Owned do
					if type(id) == "string" and Cars.ById[id] then
						profile.Owned[id] = true
					end
				end
			end
			if type(saved.Selected) == "string" and profile.Owned[saved.Selected] then
				profile.Selected = saved.Selected
			end
		elseif not ok then
			warn("[CityLegends] load failed for", player.Name, saved)
		end
	end
	profile.Loaded = true
	profiles[player] = profile
	makeLeaderstats(player, profile.Cash)
	return profile
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.Loaded or not store then
		return
	end
	local owned = {}
	for id in profile.Owned do
		table.insert(owned, id)
	end
	local payload = { Cash = profile.Cash, Owned = owned, Selected = profile.Selected }
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync("p_" .. player.UserId, payload)
	end)
	if not ok then
		warn("[CityLegends] save failed for", player.Name, err)
	end
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.addCash(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Cash = math.max(0, math.floor(profile.Cash + amount))
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Cash")
	if value and value:IsA("IntValue") then
		value.Value = profile.Cash
	end
end

function PlayerData.snapshot(player: Player): { Cash: number, Owned: { string }, Selected: string }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local owned = {}
	for id in profile.Owned do
		table.insert(owned, id)
	end
	return { Cash = profile.Cash, Owned = owned, Selected = profile.Selected }
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.saveAll()
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerData.save, player)
	end
end

return PlayerData
