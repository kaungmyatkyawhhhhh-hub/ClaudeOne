-- Gamepasses and developer products (Config.Monetization). Pass ownership is checked on join and after a
-- purchase; owners get a "Pass_<key>" attribute and the pass effect (through BoostService / PlayerData).
-- Products are granted in ProcessReceipt, once per purchase id (remembered in the player's save).
-- Nothing here ever opens a purchase prompt; the client's Store does that when the player taps Buy.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Monetization = require(Config.Monetization)
local Stamina = require(Config.Stamina)
local PumpShop = require(Config.PumpShop)
local DNA = require(Config.DNA)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local Analytics = require(script.Parent.Analytics)

local Remotes = ReplicatedStorage.Remotes
local Effects = Monetization.Effects

local MonetizationService = {}

local function event(player, kind, info)
	if player.Parent then Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

------------------------------------------------------------------------
-- Passes
------------------------------------------------------------------------
local function applyPass(player, key)
	player:SetAttribute("Pass_" .. key, true)
	if key == "DoubleGains" then
		BoostService.SetPlayer(player, "PassDoubleGains", { gains = Effects.DoubleGains })
	elseif key == "DoubleCoins" then
		BoostService.SetPlayer(player, "PassDoubleCoins", { coins = Effects.DoubleCoins })
	elseif key == "IronLungs" then
		PlayerData.RefreshMaxStamina(player) -- (reads the Pass_IronLungs attribute set above)
	elseif key == "FastRecovery" then
		BoostService.SetPlayer(player, "PassFastRecovery", { regen = Effects.FastRecovery })
	elseif key == "VIP" then
		BoostService.SetPlayer(player, "PassVIP", { coins = Effects.VIPCoins })
	end
	-- (26 Oct) a deal pass gives its pass's perks (VIPDeal = VIP at 30% off)
	local pass = Monetization.PassByKey[key]
	if pass and pass.grants and pass.grants ~= key then applyPass(player, pass.grants) end
	-- AutoLift, GeneLock, ShakeFridge, AuraPack (AuraService) are read from the attribute where they're used
end

-- every pass at once (owner, 15 Oct: one after another took long on slow phones); "PassesChecked" tells the Store the
-- OWNED stamps are known (until then a pass's buy button shows "...")
local function checkPasses(player)
	local pending = 0
	for _, pass in ipairs(Monetization.Passes) do
		if pass.id then
			pending += 1
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				if ok and owns and player.Parent then applyPass(player, pass.key) end
				pending -= 1
				if pending == 0 and player.Parent then player:SetAttribute("PassesChecked", true) end
			end)
		end
	end
	if pending == 0 then player:SetAttribute("PassesChecked", true) end
end

local function passById(id)
	for _, pass in ipairs(Monetization.Passes) do
		if pass.id == id then return pass end
	end
	return nil
end

------------------------------------------------------------------------
-- Products
------------------------------------------------------------------------
local function productById(id)
	for _, product in ipairs(Monetization.Products) do
		if product.id == id then return product end
	end
	return nil
end

local function serverBoost(buyer)
	local current = BoostService.GetGlobal("ServerBoost")
	local now = Workspace:GetServerTimeNow()
	local start = current and current.untilTime or now
	BoostService.SetGlobal("ServerBoost", { gains = Effects.ServerBoostGains, untilTime = start + Effects.ServerBoostMinutes * 60 })
	ReplicatedStorage:SetAttribute("ServerBoostBy", buyer.DisplayName)
	-- (owner, prompt 48: no server-wide messages; the buyer is thanked, everyone sees the boost in their boosts row)
	event(buyer, "ServerBoost", { name = buyer.DisplayName, minutes = Effects.ServerBoostMinutes })
end

-- (prompt 60) once per player: coins, Protein Shakes, a DNA token, the 2x EXP item and the STARTER title (all saved in the
-- same receipt). Bought again somehow: its value in coins (the coins + the shakes and the token at their coin prices),
-- never a second title.
local function grantStarterPack(player)
	local data = PlayerData.Get(player)
	if not data then return false end
	local pack = Monetization.StarterPack
	local coins = Monetization.StarterCoins(data.growthSpurts)
	if type(data.starterPack) == "table" and data.starterPack.bought then
		local value = coins + pack.Shakes * (PumpShop.SupplementPrice("Shake", data.growthSpurts) or 0) + pack.DnaTokens * DNA.CoinPrice
		PlayerData.AddCoins(player, value)
		event(player, "StarterPack", { again = true, coins = value })
		return true
	end
	PlayerData.SetTable(player, "starterPack", { bought = true, at = os.time(), playAt = Monetization.PlaySeconds(data) })
	MonetizationService.ApplyStarterRush(player) -- (26 Oct: +50% EXP and coins for RushHours)
	PlayerData.AddCoins(player, coins)
	PlayerData.AddItem(player, "Shake", pack.Shakes, true)
	PlayerData.AddDnaTokens(player, pack.DnaTokens)
	PlayerData.AddItem(player, pack.BoostItem, 1, true)
	require(script.Parent.TitleService).Check(player) -- (the STARTER title: condition "starterPack")
	event(player, "StarterPack", { coins = coins, shakes = pack.Shakes, dnaTokens = pack.DnaTokens, boost = pack.BoostItem, title = pack.Title })
	return true
end

-- (owner, 26 Oct) the Starter Pack buyer's boost: Monetization.StarterPack.Rush for the first RushHours (real time) after
-- buying; put back on every join inside that time (BoostService source "StarterRush")
function MonetizationService.ApplyStarterRush(player)
	local data = PlayerData.Get(player)
	local pack = data and data.starterPack
	if type(pack) ~= "table" or not pack.bought or not tonumber(pack.at) then return end
	local left = tonumber(pack.at) + Monetization.StarterPack.RushHours * 3600 - os.time()
	if left <= 0 then return end
	local rush = Monetization.StarterPack.Rush
	BoostService.SetPlayer(player, "StarterRush", { gains = rush.gains, coins = rush.coins, untilTime = Workspace:GetServerTimeNow() + left })
	player:SetAttribute("StarterRushEnds", Workspace:GetServerTimeNow() + left)
end

local function grantProduct(player, product)
	if product.supplement then
		-- (prompt 57) a PUMP SHOP special (paid: never cut by the carry limit)
		local ok = PlayerData.AddItem(player, product.supplement, product.count or 1, true)
		if ok then Remotes.PlayerEvent:FireClient(player, "ItemsAdded", { id = product.supplement, count = product.count or 1 }) end
		return ok
	elseif product.dnaTokens then
		-- (prompt 60) DNA tokens x3
		return PlayerData.AddDnaTokens(player, product.dnaTokens)
	elseif product.key == "StarterPack" then
		return grantStarterPack(player)
	elseif product.coins then -- the coin packs (prompt 61: their size at this player's stage, worked out now)
		local data = PlayerData.Get(player)
		PlayerData.AddCoins(player, Monetization.PackCoins(product, data and data.growthSpurts))
		return true
	elseif product.key == "EndlessStamina" then
		-- 15 min of no stamina drain, stacking up to 60 (the time left is saved; it runs only while in the game)
		return PlayerData.AddEndlessStamina(player, Effects.EndlessStaminaMinutes * 60, Effects.EndlessStaminaMaxMinutes * 60)
	elseif product.key == "DnaToken" then
		return PlayerData.AddDnaTokens(player, 1)
	elseif product.key == "QuestReroll" then
		return require(script.Parent.DailyService).PaidReroll(player)
	elseif product.key == "ShakePack" then
		-- (prompt 14: into the inventory, not drunk; the client offers USE NOW)
		local ok = PlayerData.AddShakes(player, Effects.ShakePackSize)
		if ok then Remotes.PlayerEvent:FireClient(player, "ItemsAdded", { id = "Shake", count = Effects.ShakePackSize }) end
		return ok
	elseif product.key == "ServerBoost" then
		serverBoost(player)
		return true
	end
	return false
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerData.Get(player)
	if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
	data.receipts = data.receipts or {}
	if data.receipts[receipt.PurchaseId] then
		-- already given (Roblox retried): only confirm once it's stored
		return PlayerData.SaveNow(player) and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById(receipt.ProductId)
	if not product then
		warn("[MonetizationService] Unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantProduct, player, product)
	if not ok or not granted then return Enum.ProductPurchaseDecision.NotProcessedYet end
	-- remember the purchase (keep the most recent 50 ids)
	data.receipts[receipt.PurchaseId] = os.time()
	local count, oldestId, oldest = 0, nil, math.huge
	for id, at in pairs(data.receipts) do
		count += 1
		if at < oldest then oldestId, oldest = id, at end
	end
	if count > 50 and oldestId then data.receipts[oldestId] = nil end
	-- stored before Roblox is told it's granted: if the server crashed before the next autosave, a "granted" answer
	-- would lose a paid item. If the save fails, Roblox retries later; the receipt id above stops a double grant.
	if not PlayerData.SaveNow(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	event(player, "Purchased", { name = product.name })
	Analytics.ProductBought(player, product.key, receipt.CurrencySpent) -- (prompt 12)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

------------------------------------------------------------------------
function MonetizationService.Start()
	if not Monetization.AnyConfigured() then return end -- nothing to sell yet
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = purchased and passById(passId)
		if not pass then return end
		-- don't take the purchase flag on trust: ask Roblox who owns the pass
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and owns then
			applyPass(player, pass.key)
			event(player, "Purchased", { name = pass.name })
		end
	end)
	local function onJoin(player)
		task.spawn(function()
			PlayerData.WaitFor(player)
			checkPasses(player)
			MonetizationService.ApplyStarterRush(player)
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do onJoin(player) end

	-- Studio only: Workspace attribute TestReceipt = "<productId>:<purchaseId>" runs a fake receipt for the first player
	-- through the real ProcessReceipt (a test purchase without the purchase dialog; the same purchase id twice must not
	-- grant twice). Prints the decision.
	if game:GetService("RunService"):IsStudio() then
		Workspace:GetAttributeChangedSignal("TestReceipt"):Connect(function()
			local value = Workspace:GetAttribute("TestReceipt")
			local productId, purchaseId = string.match(tostring(value), "^(%d+):(.+)$")
			local player = Players:GetPlayers()[1]
			if not productId or not player then return end
			local decision = processReceipt({ PlayerId = player.UserId, ProductId = tonumber(productId), PurchaseId = purchaseId, CurrencySpent = 0 })
			print("[MonetizationService] test receipt " .. purchaseId .. ": " .. tostring(decision))
		end)
	end

	-- Shake Fridge: a free shake every few minutes for owners
	task.spawn(function()
		while true do
			task.wait(Effects.ShakeFridgeMinutes * 60)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data and player:GetAttribute("Pass_ShakeFridge") and PlayerData.ShakeCount(player) < Stamina.Shake.MaxCarry then
					PlayerData.AddShakes(player, 1)
					event(player, "ShakeFridge", {})
				end
			end
		end
	end)
	-- clear the "boost by" name when the server boost ends
	task.spawn(function()
		while true do
			task.wait(5)
			if not BoostService.GetGlobal("ServerBoost") and ReplicatedStorage:GetAttribute("ServerBoostBy") then
				BoostService.SetGlobal("ServerBoost", nil)
				ReplicatedStorage:SetAttribute("ServerBoostBy", nil)
			end
		end
	end)
end

return MonetizationService
