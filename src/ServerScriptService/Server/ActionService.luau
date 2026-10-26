-- Player intents outside of machines (Growth Spurt, titles, genetics, tutorial). Every action is
-- validated here; the client only asks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Config.Economy) -- (prompt 61: rewards at the player's stage)
local Guard = require(script.Parent.Guard)
local Analytics = require(script.Parent.Analytics)
local BodyService = require(script.Parent.BodyService)
local TitleService = require(script.Parent.TitleService)
local Titles = require(Config.Titles)
local Onboarding = require(Config.Onboarding)

local Remotes = ReplicatedStorage.Remotes

local ActionService = {}
local handlers = {}

handlers.GrowthSpurt = function(player)
	if PlayerData.GrowthSpurt(player) then
		local data = PlayerData.Get(player)
		Analytics.GrowthSpurt(player, data)
		BodyService.Rebuild(player)
		TitleService.Check(player)
		-- (prompt 24) Growth Spurt 2 adds a trainer slot
		local okTrainers, TrainerService = pcall(require, script.Parent.TrainerService)
		if okTrainers and TrainerService.Refresh then TrainerService.Refresh(player) end
		Remotes.PlayerEvent:FireClient(player, "GrowthSpurt", {
			spurts = data.growthSpurts,
			height = GrowthSpurts.PlayerHeight(data),
			bonus = GrowthSpurts.GetBonus(data.growthSpurts),
		})
	end
end

-- (prompt 21) Body Alter: the goal is checked in PlayerData.Alter (saves before and after). A finished tier (every 5th
-- alter) adds its DNA tokens; its title and aura come from TitleService / AuraService.
handlers.Alter = function(player)
	local n = PlayerData.Alter(player)
	if not n then return end
	local Alters = require(Config.Alters)
	local alter = Alters.Get(n)
	local reward = nil
	if n % 5 == 0 then
		reward = Alters.TierRewards[Alters.TierOf(n)]
		if reward and (reward.dnaTokens or 0) > 0 then PlayerData.AddDnaTokens(player, reward.dnaTokens) end
	end
	BodyService.Rebuild(player)
	TitleService.Check(player)
	-- (prompt 24) the first alter adds a trainer slot
	local okTrainers, TrainerService = pcall(require, script.Parent.TrainerService)
	if okTrainers and TrainerService.Refresh then TrainerService.Refresh(player) end
	local okAura, AuraService = pcall(require, script.Parent.AuraService)
	if okAura and AuraService.CheckEarned then AuraService.CheckEarned(player) end
	Analytics.Event(player, "BodyAlter", n)
	Remotes.PlayerEvent:FireClient(player, "Altered", {
		alter = n, name = alter.name, tier = Alters.TierOf(n), bonus = Alters.Bonus(n),
		reward = reward and { title = reward.title, aura = reward.aura, dnaTokens = reward.dnaTokens } or nil,
	})
	-- (prompt 22) the reveal: the new body flexes (front double biceps, everyone sees it) and players nearby see the flash
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root then
		if character:GetAttribute("Pose") == nil then
			character:SetAttribute("Pose", "FrontDoubleBiceps")
			task.delay(2.6, function()
				if character.Parent and character:GetAttribute("Pose") == "FrontDoubleBiceps" then character:SetAttribute("Pose", nil) end
			end)
		end
		for _, other in ipairs(Players:GetPlayers()) do
			local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and (otherRoot.Position - root.Position).Magnitude < 150 then
				Remotes.PlayerEvent:FireClient(other, "AlterBurst", { userId = player.UserId, alter = n })
			end
		end
	end
end

handlers.EquipAlter = function(player, n)
	if PlayerData.EquipAlter(player, n) then BodyService.Rebuild(player) end
end

handlers.EquipTitle = function(player, titleId)
	if titleId == nil or (type(titleId) == "string" and Titles.ById[titleId]) then
		TitleService.Equip(player, titleId)
	end
end

-- Genetics: reroll uses the free reroll first, then a DNA Token (validated in PlayerData).
handlers.Reroll = function(player)
	if PlayerData.RerollGenetics(player) then
		TitleService.Check(player)
		Remotes.PlayerEvent:FireClient(player, "Rerolled", {})
	end
end

-- Buy one DNA token with coins (Config/DNA.CoinPrice); the coins are checked and taken here. (PlayerAction is rate
-- limited by Guard.) (prompt 19) Every token bought in the same week costs 10% more (Config/PumpShop.DnaPrice; saved in
-- data.dnaWeek = { week, bought }), from the Genetics screen, the Store and the PUMP SHOP's DNA Lab alike.
handlers.BuyDnaToken = function(player)
	local data = PlayerData.Get(player)
	if not data then return end
	local PumpShop = require(Config.PumpShop)
	local week = PumpShop.Week()
	local state = type(data.dnaWeek) == "table" and data.dnaWeek.week == week and data.dnaWeek or { week = week, bought = 0 }
	local price = PumpShop.DnaPrice(require(Config.DNA).CoinPrice, state.bought)
	if PlayerData.SpendCoins(player, price) then
		PlayerData.SetTable(player, "dnaWeek", { week = week, bought = (state.bought or 0) + 1 })
		PlayerData.AddDnaTokens(player, 1)
		Remotes.PlayerEvent:FireClient(player, "DnaTokenBought", {})
	else
		Remotes.PlayerEvent:FireClient(player, "DnaTokenBought", { failed = true, price = price })
	end
end

-- (prompt 11, 21 Oct) A new player starts the tutorial inside the starter gym, a short walk from the Flat Bench
-- (Config.Onboarding StartSpot, under 5 s), not at the spawn by the street door.
local function placeAtStart(player)
	local data = PlayerData.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root or data.onboarding.tutorialStep ~= 1 or not Onboarding.StartSpot then return end
	local spot, face = Onboarding.StartSpot, Onboarding.StartFacing or Onboarding.StartSpot + Vector3.new(0, 0, -1)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local lift = humanoid and (humanoid.HipHeight + root.Size.Y / 2) or 3
	character:PivotTo(CFrame.lookAt(spot + Vector3.new(0, lift, 0), Vector3.new(face.X, spot.Y + lift, face.Z)))
end

-- The player has seen their genetics reveal (first join).
handlers.GeneticsSeen = function(player)
	PlayerData.SetFlag(player, "geneticsRevealed", true)
	Analytics.GeneticsKept(player)
	placeAtStart(player)
end

-- Tutorial: the client reports the step it reached (validated in PlayerData).
handlers.TutorialStep = function(player, step)
	local before = PlayerData.Get(player) and PlayerData.Get(player).onboarding.tutorialStep
	if PlayerData.SetTutorialStep(player, step) then
		Analytics.TutorialStep(player, step)
		-- a step's gift (e.g. the free shake) is given once, when the step is reached the normal way (one step after the last):
		-- a client that jumps straight to a gift step does not get it
		local def = Onboarding.Steps[step]
		if def and def.gift and def.gift.shakes and step == before + 1 then
			PlayerData.AddShakes(player, def.gift.shakes)
		end
		-- the whole tutorial done the normal way (from the last step, not skipped): the reward
		if step == Onboarding.Done and before == #Onboarding.Steps and Onboarding.FinishCoins then
			PlayerData.AddCoins(player, Onboarding.FinishCoins)
		end
	end
end

-- SKIP TUTORIAL: straight to the end (no reward, no gifts)
handlers.SkipTutorial = function(player)
	if PlayerData.SetTutorialStep(player, Onboarding.Done) then
		Analytics.TutorialStep(player, Onboarding.Done, true)
	end
end

-- Settings menu: { music = 0-1, effects = 0-1, gainNumbers = "On" | "Minimal" | "Off", repFlash = "On" | "Off",
-- expPopups = "On" | "Off", pumpHintSeen = true } (PlayerData validates)
handlers.SetSettings = function(player, settings)
	if type(settings) == "table" then
		PlayerData.SetSettings(player, settings)
	end
end

-- (prompt 12) shop analytics from the client: { event = "ShopOpened" | "OfferShown" | "OfferTapped", offer = id }
-- (Analytics.ShopEvent checks the names and spacing)
handlers.ShopEvent = function(player, info)
	Analytics.ShopEvent(player, info)
end

-- (prompt 39) the unlock guides. { id = save id ("BeachGym", "SpurtReadyAgain:3", "New:Store"), how = "shown" | "done" |
-- "skip" | "timeout" | "tap" }. Checked: a real guide (Config/Guides) whose condition is met now (or a real locked tile);
-- saved once; a first-time guide DONE pays its reward once (the gold "+25" pill on the client).
handlers.Guide = function(player, info)
	if type(info) ~= "table" or type(info.id) ~= "string" then return end
	local how = info.how
	if how ~= "shown" and how ~= "done" and how ~= "skip" and how ~= "timeout" and how ~= "tap" then return end
	local Guides = require(Config.Guides)
	local data = PlayerData.Get(player)
	if not data then return end
	local tile = string.match(info.id, "^New:(%a+)$")
	if tile then
		local lock = Guides.LockByTile[tile]
		if lock and how == "tap" and Guides.Met(lock.need, data) then PlayerData.SetGuideSeen(player, info.id) end
		return
	end
	local baseId, n = string.match(info.id, "^(%a+):(%d+)$")
	local guide = Guides.ById[baseId or info.id]
	if not guide or (baseId ~= nil) ~= (guide.every ~= nil) then return end
	if Guides.SaveId(guide, data) ~= info.id then return end
	local _ = n
	-- the condition, as the server sees it
	local Alters = require(Config.Alters)
	local Muscles = require(Config.Muscles)
	local Machines = require(Config.Machines)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local spurt = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	local state = {}
	if spurt.maxed then
		local alter = Alters.Progress(data, Muscles.Groups, trainable)
		state.alterReady = alter.ready == true and not alter.locked
		local highest = type(data.alter) == "table" and data.alter.highest or 0
		state.alterTier = state.alterReady and Alters.TierOf(highest + 1) > Alters.TierOf(highest)
	else
		state.spurtReady = spurt.ready == true
	end
	-- (a "ready" guide may finish after the player already grew: then the spurt / alter they did counts)
	local highest = type(data.alter) == "table" and data.alter.highest or 0
	local met = Guides.Met(guide.need, data, state)
		or (guide.need.ready == "spurt" and (data.growthSpurts or 0) >= 1)
		or ((guide.need.ready == "alter" or guide.need.alterTier) and highest >= 1)
	if not met then return end
	Analytics.GuideEvent(player, "Guide_" .. how .. "_" .. guide.id)
	if how == "shown" then return end
	if PlayerData.SetGuideSeen(player, info.id) then
		-- its reminder (`after`) never also plays for the same Growth Spurt / alter
		for _, other in ipairs(Guides.List) do
			if other.after == guide.id then PlayerData.SetGuideSeen(player, Guides.SaveId(other, data)) end
		end
		if how == "done" and guide.reward and not guide.every then
			local coins = Economy.Reward(data.growthSpurts, Economy.Rewards.Guide, guide.reward) -- (prompt 61)
			PlayerData.AddCoins(player, coins)
			Remotes.PlayerEvent:FireClient(player, "GuideReward", { coins = coins })
		end
	end
end

-- (prompt 39) a tap on a locked menu tile (analytics only: what players are curious about)
handlers.LockedTap = function(player, tile)
	local Guides = require(Config.Guides)
	if type(tile) ~= "string" or not Guides.LockOf(tile) then return end
	local data = PlayerData.Get(player)
	Analytics.GuideEvent(player, "Locked_Tap_" .. string.gsub(tile, "/", "_"), data and Guides.Level(data) or 0)
end

-- Other services add handlers.
function ActionService.Register(action, handler)
	handlers[action] = handler
end

function ActionService.Start()
	PlayerData.Loaded:Connect(Analytics.Joined) -- onboarding funnel (new players only)
	-- menus, settings, tutorial steps, shakes: plenty for a real player, not for a spam script
	Guard.Remote(Remotes.PlayerAction, "PlayerAction", 8, 15, function(player, action, arg)
		local handler = type(action) == "string" and handlers[action]
		if handler then handler(player, arg) end
	end)
end

return ActionService
