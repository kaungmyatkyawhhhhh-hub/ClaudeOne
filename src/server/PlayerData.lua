--[[
	PlayerData
	Cash, owned cars, level/XP and the daily gift timer, saved with DataStoreService
	when available. Old saves without the progression fields load as level 1.
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
	Level: number,
	XP: number, -- progress inside the current level
	LastDaily: number, -- os.time() of the last daily gift claim (0 = never)
	Loaded: boolean,
}

export type Snapshot = {
	Cash: number,
	Owned: { string },
	Selected: string,
	Level: number,
	XP: number,
	XPNeed: number,
	DailyIn: number, -- seconds until the daily gift can be claimed
}

export type XpResult = {
	level: number,
	xp: number,
	need: number,
	levels: number, -- levels gained by this award
	reward: number, -- cash paid for those levels
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
		Level = 1,
		XP = 0,
		LastDaily = 0,
		Loaded = false,
	}
end

local function makeLeaderstats(player: Player, profile: Profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = profile.Level
	level.Parent = stats
	local value = Instance.new("IntValue")
	value.Name = "Cash"
	value.Value = profile.Cash
	value.Parent = stats
	stats.Parent = player
end

local function setStat(player: Player, name: string, v: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		value.Value = v
	end
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
			-- progression (absent in saves from before levels existed)
			if type(saved.Level) == "number" then
				profile.Level = math.clamp(math.floor(saved.Level), 1, Config.Progression.MaxLevel)
			end
			if type(saved.XP) == "number" then
				profile.XP = math.clamp(math.floor(saved.XP), 0, Config.xpForLevel(profile.Level))
			end
			if type(saved.LastDaily) == "number" then
				profile.LastDaily = math.clamp(math.floor(saved.LastDaily), 0, os.time())
			end
		elseif not ok then
			warn("[CityLegends] load failed for", player.Name, saved)
		end
	end
	profile.Loaded = true
	profiles[player] = profile
	makeLeaderstats(player, profile)
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
	local payload = {
		Cash = profile.Cash,
		Owned = owned,
		Selected = profile.Selected,
		Level = profile.Level,
		XP = profile.XP,
		LastDaily = profile.LastDaily,
	}
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
	setStat(player, "Cash", profile.Cash)
end

-- Adds XP, rolls over as many levels as it covers and pays the level-up cash.
function PlayerData.addXp(player: Player, amount: number): XpResult?
	local profile = profiles[player]
	amount = math.floor(amount)
	if not profile or amount <= 0 then
		return nil
	end
	local maxLevel = Config.Progression.MaxLevel
	profile.XP += amount
	local levels, reward = 0, 0
	while profile.Level < maxLevel and profile.XP >= Config.xpForLevel(profile.Level) do
		profile.XP -= Config.xpForLevel(profile.Level)
		profile.Level += 1
		levels += 1
		reward += Config.levelReward(profile.Level)
	end
	local need = Config.xpForLevel(profile.Level)
	if profile.Level >= maxLevel then
		profile.XP = math.min(profile.XP, need)
	end
	if levels > 0 then
		setStat(player, "Level", profile.Level)
		PlayerData.addCash(player, reward)
	end
	return { level = profile.Level, xp = profile.XP, need = need, levels = levels, reward = reward }
end

function PlayerData.dailyReadyIn(player: Player): number
	local profile = profiles[player]
	if not profile then
		return Config.Daily.Cooldown
	end
	return math.max(0, profile.LastDaily + Config.Daily.Cooldown - os.time())
end

-- Returns (claimed, cash paid). Only succeeds once per Config.Daily.Cooldown.
function PlayerData.claimDaily(player: Player): (boolean, number)
	local profile = profiles[player]
	if not profile or not profile.Loaded or PlayerData.dailyReadyIn(player) > 0 then
		return false, 0
	end
	local amount = Config.dailyReward(profile.Level)
	profile.LastDaily = os.time()
	PlayerData.addCash(player, amount)
	return true, amount
end

function PlayerData.snapshot(player: Player): Snapshot?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local owned = {}
	for id in profile.Owned do
		table.insert(owned, id)
	end
	return {
		Cash = profile.Cash,
		Owned = owned,
		Selected = profile.Selected,
		Level = profile.Level,
		XP = profile.XP,
		XPNeed = Config.xpForLevel(profile.Level),
		DailyIn = PlayerData.dailyReadyIn(player),
	}
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
