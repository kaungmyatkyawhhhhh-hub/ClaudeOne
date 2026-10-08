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
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)

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
	elseif key == "IronLungs" then
		PlayerData.RefreshMaxStamina(player) -- (reads the Pass_IronLungs attribute set above)
	elseif key == "FastRecovery" then
		BoostService.SetPlayer(player, "PassFastRecovery", { regen = Effects.FastRecovery })
	elseif key == "VIP" then
		BoostService.SetPlayer(player, "PassVIP", { coins = Effects.VIPCoins })
	end
	-- AutoLift, GeneLock, ShakeFridge are read from the attribute where they're used
end

local function checkPasses(player)
	for _, pass in ipairs(Monetization.Passes) do
		if pass.id then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then applyPass(player, pass.key) end
		end
	end
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
	for _, player in ipairs(Players:GetPlayers()) do
		event(player, "ServerBoost", { name = buyer.DisplayName, minutes = Effects.ServerBoostMinutes })
	end
end

local function grantProduct(player, product)
	if product.key == "DnaToken" then
		return PlayerData.AddDnaTokens(player, 1)
	elseif product.key == "ShakePack" then
		return PlayerData.AddShakes(player, Effects.ShakePackSize)
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
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do onJoin(player) end

	-- Shake Fridge: a free shake every few minutes for owners
	task.spawn(function()
		while true do
			task.wait(Effects.ShakeFridgeMinutes * 60)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data and player:GetAttribute("Pass_ShakeFridge") and data.shakes < Stamina.Shake.MaxCarry then
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
