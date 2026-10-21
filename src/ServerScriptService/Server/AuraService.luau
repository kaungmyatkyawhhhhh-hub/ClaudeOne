-- AuraService (owner, 14 Oct): which auras a player has, which one they wear, coin purchases (Config.Auras). Saved in
-- data.auras = { owned = { [auraId] = unix time }, equipped = auraId | nil }. Earned auras (level, 7'0", every Coach quest)
-- and coin auras are kept in `owned` forever; pass auras (Aura Pack, VIP) count while the pass is owned (the "Pass_<key>"
-- attribute MonetizationService sets on join and right after a purchase). The worn aura is replicated as the player's
-- "Aura" attribute; every client builds the effect itself (AuraClient). All checks here.
-- PlayerAction "AuraEquip" (auraId or nil = off), "AuraBuy" (auraId: a coin aura). Events: "AuraUnlocked" { id }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Auras = require(Config.Auras)
local Muscles = require(Config.Muscles)
local GrowthSpurts = require(Config.GrowthSpurts)
local Quests = require(Config.Quests)
local PlayerData = require(script.Parent.PlayerData)
local ActionService = require(script.Parent.ActionService)

local Remotes = ReplicatedStorage.Remotes

local AuraService = {}
local CHECK_EVERY = 10 -- seconds between "earned a new aura?" checks

local function event(player, kind, info)
	if player.Parent then Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

local function auraData(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	if type(data.auras) ~= "table" then data.auras = { owned = {}, equipped = nil } end
	data.auras.owned = data.auras.owned or {}
	return data.auras, data
end

-- the top bar's LVL: the average exact level of the 18 muscles
local function averageLevel(data): number
	local total, count = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles and data.muscles[muscle.id]
		if entry then
			total += Muscles.ExactLevel(entry)
			count += 1
		end
	end
	return if count > 0 then total / count else 0
end

-- earned right now? (level / height / achievements; the rest never "earns")
local function earnedNow(aura, data): boolean
	local unlock = aura.unlock
	if unlock.type == "level" then return averageLevel(data) >= unlock.level end
	if unlock.type == "height" then return GrowthSpurts.IsMaxed(data.growthSpurts) end
	if unlock.type == "achievements" then return (data.quests and data.quests.index or 1) > #Quests.Chain end
	if unlock.type == "alter" then return type(data.alter) == "table" and (data.alter.highest or 0) >= unlock.alter end
	return false
end

function AuraService.Has(player, auraId): boolean
	local aura = Auras.ById[auraId]
	local auras = auraData(player)
	if not aura or not auras then return false end
	if aura.unlock.type == "pass" then return player:GetAttribute("Pass_" .. aura.unlock.pass) == true end
	return auras.owned[auraId] ~= nil
end

-- the worn aura, replicated (only while the player still has it: a pass that's gone takes its aura with it)
local function replicateWorn(player)
	local auras = auraData(player)
	if not auras then return end
	local worn = auras.equipped
	if worn and not AuraService.Has(player, worn) then worn = nil end
	if player:GetAttribute("Aura") ~= worn then player:SetAttribute("Aura", worn) end
	-- (prompt 45) its perk, only while worn: EXP / coins / rep speed as a boost source, max stamina refreshed
	local BoostService = require(script.Parent.BoostService)
	if worn and Auras.Perks[worn] then
		BoostService.SetPlayer(player, "Aura", { gains = 1 + Auras.Perk(worn, "exp"), coins = 1 + Auras.Perk(worn, "coins"),
			repSpeed = 1 + Auras.Perk(worn, "autoRep") })
	else
		BoostService.SetPlayer(player, "Aura", nil)
	end
	PlayerData.RefreshMaxStamina(player)
	-- the effect's preset name on the character too ("EquippedAura", AuraVFX: every client builds it from this)
	local character = player.Character
	local preset = worn and Auras.ById[worn] and Auras.ById[worn].vfx or nil
	if character and character:GetAttribute("EquippedAura") ~= preset then character:SetAttribute("EquippedAura", preset) end
end

local function save(player)
	local auras = auraData(player)
	if auras then PlayerData.SetTable(player, "auras", auras) end
end

-- newly earned auras go into `owned` (kept forever) with a toast
local function checkEarned(player)
	local auras, data = auraData(player)
	if not auras then return end
	local changed = false
	for _, aura in ipairs(Auras.List) do
		if not auras.owned[aura.id] and earnedNow(aura, data) then
			auras.owned[aura.id] = os.time()
			changed = true
			event(player, "AuraUnlocked", { id = aura.id })
		end
	end
	if changed then save(player) end
	replicateWorn(player)
end
AuraService.CheckEarned = checkEarned

local function equip(player, auraId)
	local auras = auraData(player)
	if not auras then return end
	if auraId == nil or auraId == false then
		auras.equipped = nil
	elseif type(auraId) == "string" and AuraService.Has(player, auraId) then
		auras.equipped = auraId
	else
		return
	end
	save(player)
	replicateWorn(player)
end

local function buy(player, auraId)
	local aura = type(auraId) == "string" and Auras.ById[auraId]
	local auras = auraData(player)
	if not aura or not auras or aura.unlock.type ~= "coins" or auras.owned[aura.id] then return end
	if not PlayerData.SpendCoins(player, aura.unlock.price) then
		event(player, "AuraBuyFailed", { id = aura.id, price = aura.unlock.price })
		return
	end
	auras.owned[aura.id] = os.time()
	auras.equipped = aura.id -- (bought it: wear it)
	save(player)
	replicateWorn(player)
	event(player, "AuraUnlocked", { id = aura.id, bought = true })
end

function AuraService.Start()
	ActionService.Register("AuraEquip", equip)
	ActionService.Register("AuraBuy", buy)
	local function watch(player)
		-- (a new character gets the attribute again: respawn)
		player.CharacterAdded:Connect(function() task.defer(replicateWorn, player) end)
		task.spawn(function()
			PlayerData.WaitFor(player)
			checkEarned(player)
		end)
		-- a pass bought (or found on join) unlocks its auras at once
		player.AttributeChanged:Connect(function(name)
			if string.sub(name, 1, 5) == "Pass_" then
				for _, aura in ipairs(Auras.List) do
					if aura.unlock.type == "pass" and "Pass_" .. aura.unlock.pass == name and player:GetAttribute(name) == true then
						event(player, "AuraUnlocked", { id = aura.id, pass = true })
					end
				end
				replicateWorn(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			for _, player in ipairs(Players:GetPlayers()) do
				if PlayerData.Get(player) then pcall(checkEarned, player) end
			end
		end
	end)
end

return AuraService
