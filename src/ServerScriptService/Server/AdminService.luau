-- AdminService (prompt 64, 23 Oct): the owner's gifts from the developer console. Only people who can edit the game can
-- type in the console's Server tab (F9 > Server), and ServerStorage never reaches players, so no player can call this.
-- In the console's Server tab (or Studio's command bar while playing, Server view):
--   game.ServerStorage.Admin:Invoke("help")
--   game.ServerStorage.Admin:Invoke("coins", "LuigiRED", 5000)        -- (a negative amount takes coins away, never below 0)
--   game.ServerStorage.Admin:Invoke("trainer", "LuigiRED", "Atlas")    -- (BASE)
--   game.ServerStorage.Admin:Invoke("trainer", "LuigiRED", "Atlas", 5) -- (stage 1 BASE .. 5 LIMITLESS)
--   game.ServerStorage.Admin:Invoke("trainers")                        -- (every trainer's id and name)
-- The player: their name or display name (any case, the start is enough if only one player matches) or "all" (everyone
-- in this server). Only players in the same server. Every gift prints a line in the server output.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Trainers = require(ReplicatedStorage.Shared.Config.Trainers)
local PlayerData = require(script.Parent.PlayerData)

local AdminService = {}

local MAX_COINS = 1e12 -- one gift at most (a typo guard)

local HELP = table.concat({
	"Admin commands (game.ServerStorage.Admin:Invoke(...)):",
	'  ("coins", "<player or all>", amount)',
	'  ("trainer", "<player or all>", "<trainer>", stage 1-5)',
	'  ("trainers")  list the trainers',
}, "\n")

-- players by name / display name (exact first, then the start if only one matches), or everyone for "all"
local function findPlayers(text): ({ Player }?, string?)
	if type(text) ~= "string" or text == "" then return nil, "say which player" end
	local all = Players:GetPlayers()
	if string.lower(text) == "all" then return all, nil end
	local want = string.lower(text)
	for _, player in ipairs(all) do
		if string.lower(player.Name) == want or string.lower(player.DisplayName) == want then return { player }, nil end
	end
	local found = {}
	for _, player in ipairs(all) do
		if string.sub(string.lower(player.Name), 1, #want) == want or string.sub(string.lower(player.DisplayName), 1, #want) == want then
			table.insert(found, player)
		end
	end
	if #found == 1 then return found, nil end
	if #found > 1 then return nil, "more than one player starts with \"" .. text .. "\"" end
	return nil, "no player \"" .. text .. "\" in this server"
end

-- a trainer by id ("AtlasCoach"), name ("Atlas", "Coach Lou") or the name without "Coach" ("Lou"), any case
local function findTrainer(text)
	if type(text) ~= "string" then return nil end
	local want = string.lower((string.gsub(text, "%s", "")))
	for _, trainer in ipairs(Trainers.List) do
		local name = string.lower((string.gsub(trainer.name, "%s", "")))
		if string.lower(trainer.id) == want or name == want or string.gsub(name, "^coach", "") == want then return trainer end
	end
	return nil
end

local function giveCoins(target, amount)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount % 1 ~= 0 or math.abs(amount) > MAX_COINS then
		return "coins: give a whole number (at most " .. MAX_COINS .. ")"
	end
	local players, err = findPlayers(target)
	if not players then return "coins: " .. err end
	local lines = {}
	for _, player in ipairs(players) do
		local data = PlayerData.Get(player)
		if not data then
			table.insert(lines, player.Name .. ": data not loaded")
		else
			local change = if amount < 0 then -math.min(-amount, data.coins) else amount
			PlayerData.AddCoins(player, change)
			ReplicatedStorage.Remotes.PlayerEvent:FireClient(player, "AdminGift", { coins = change })
			table.insert(lines, string.format("%s: %+d coins (now %d)", player.Name, change, data.coins))
		end
	end
	return table.concat(lines, "\n")
end

local function giveTrainer(target, trainerText, stage)
	local trainer = findTrainer(trainerText)
	if not trainer then return "trainer: no trainer \"" .. tostring(trainerText) .. "\" (\"trainers\" lists them)" end
	local players, err = findPlayers(target)
	if not players then return "trainer: " .. err end
	stage = math.clamp(math.floor(tonumber(stage) or 1), 1, #Trainers.Stages)
	local TrainerService = require(script.Parent.TrainerService)
	local lines = {}
	for _, player in ipairs(players) do
		local ok, why = TrainerService.AdminGive(player, trainer.id, stage)
		table.insert(lines, player.Name .. ": " .. (if ok then trainer.name .. " " .. Trainers.Stages[stage].name else "failed (" .. tostring(why) .. ")"))
	end
	return table.concat(lines, "\n")
end

local function listTrainers()
	local lines = {}
	for _, trainer in ipairs(Trainers.List) do
		table.insert(lines, string.format("%s = %s (%s)", trainer.id, trainer.name, tostring(trainer.rarity)))
	end
	local stages = {}
	for i, stage in ipairs(Trainers.Stages) do table.insert(stages, i .. " " .. stage.name) end
	table.insert(lines, "stages: " .. table.concat(stages, ", "))
	return table.concat(lines, "\n")
end

function AdminService.Run(command, ...)
	command = string.lower(tostring(command or "help"))
	local result
	if command == "coins" then
		result = giveCoins(...)
	elseif command == "trainer" then
		result = giveTrainer(...)
	elseif command == "trainers" then
		result = listTrainers()
	else
		result = HELP
	end
	print("[Admin] " .. result)
	return result
end

function AdminService.Start()
	local old = ServerStorage:FindFirstChild("Admin")
	if old then old:Destroy() end
	local fn = Instance.new("BindableFunction")
	fn.Name = "Admin"
	fn.OnInvoke = AdminService.Run
	fn.Parent = ServerStorage
end

return AdminService
