-- ItemService (owner, prompt 14, 21 Oct; numbers in Config.Boosts): the boosts in the inventory. All checks are here.
--   UseItem(id)    uses one: the Protein Shake runs the old shake (StaminaService.DrinkShake: full stamina, the shake
--                  boost, the chug, "ShakeDrunk"); the others add their time to a BoostService source "Item_<id>" (capped at
--                  Boosts.MaxSeconds), Coconut Water also refills part of the stamina. The player attribute "Item_<id>" =
--                  the boost's end (server time) for the HUD timers. Everyone sees the chug.
--   EquipItem(id)  puts the item in the player's backpack as a Tool (the Roblox hotbar); activating it uses one, and the
--                  Tool goes away when the last one is used. EquipItem again (UNEQUIP) takes it out. The player attribute
--                  "Equipped_<id>" says it's there.
--                  (prompt 28) The Protein Shake goes in by itself (on join, respawn and when you get shakes while you have
--                  none): the DRINK SHAKE button is gone, hotbar slot 1 is the shake. UNEQUIP keeps it out until you get more.
-- Boost time pauses while away: data.boostLeft[id] = seconds left, saved every few seconds and picked up on join.
-- Studio test (only the place owner): type "/give creatine 5" in chat.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local ActionService = require(script.Parent.ActionService)
local ShowOffService = require(script.Parent.ShowOffService)

local Remotes = ReplicatedStorage.Remotes

local ItemService = {}

local lastUse = {}  -- [player] = os.clock()
local restored = {} -- [player] = true once the saved time left is back on (only then is it saved again)
local tools = {}    -- [player] = { [id] = Tool }

local function now() return Workspace:GetServerTimeNow() end

local function event(player, kind, info)
	Remotes.PlayerEvent:FireClient(player, kind, info or {})
end

local function count(player, id): number
	local data = PlayerData.Get(player)
	return data and tonumber(data.items[id]) or 0
end

------------------------------------------------------------------------
-- Timed boosts
------------------------------------------------------------------------
local function secondsLeft(player, id): number
	local source = BoostService.GetPlayer(player, "Item_" .. id)
	return source and source.untilTime and math.max(0, source.untilTime - now()) or 0
end

local function apply(player, item, seconds: number)
	local untilTime = now() + seconds
	local source = { untilTime = untilTime }
	for key, value in pairs(item.effects or {}) do source[key] = value end
	BoostService.SetPlayer(player, "Item_" .. item.id, source)
	player:SetAttribute("Item_" .. item.id, untilTime)
end

local function restore(player)
	local data = PlayerData.Get(player)
	if not data then return end
	restored[player] = true
	for id, left in pairs(data.boostLeft or {}) do
		local item = Boosts.ById[id]
		if item and not item.shake and type(left) == "number" and left > 0 then apply(player, item, math.min(left, Boosts.MaxSeconds)) end
	end
end

local function saveTimes(player)
	local data = PlayerData.Get(player)
	if not data or not restored[player] then return end -- (never before the restore: it would save "nothing left")
	local left = {}
	for _, item in ipairs(Boosts.Items) do
		if not item.shake then
			local seconds = secondsLeft(player, item.id)
			if seconds > 0 then left[item.id] = math.floor(seconds) end
		end
	end
	data.boostLeft = left
end

------------------------------------------------------------------------
-- Using one
------------------------------------------------------------------------
local refreshTool -- (below)

local function use(player, id): boolean
	local item = Boosts.ById[id]
	if not item or not PlayerData.Get(player) then return false end
	local clock = os.clock()
	if clock - (lastUse[player] or 0) < Boosts.UseCooldown then return false end
	if count(player, id) <= 0 then return false end
	lastUse[player] = clock
	if item.shake then
		-- the old Energy Shake, exactly (StaminaService takes the shake from the inventory)
		local ok, StaminaService = pcall(require, script.Parent.StaminaService)
		if not ok or not StaminaService.DrinkShake(player) then return false end
	else
		if not PlayerData.AddItem(player, id, -1) then return false end
		if item.refill then
			local data = PlayerData.Get(player)
			PlayerData.SetStamina(player, data.stamina + PlayerData.GetMaxStamina(player) * item.refill)
		end
		if item.seconds then apply(player, item, Boosts.Extend(item, secondsLeft(player, id))) end
		saveTimes(player)
		ShowOffService.PlayEmote(player, "Chug")
		event(player, "ItemUsed", { id = id })
	end
	refreshTool(player, id)
	return true
end

------------------------------------------------------------------------
-- EQUIP: the item as a Tool in the backpack (activate = use one)
------------------------------------------------------------------------
local function makeTool(player, item)
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.text
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("BoostItem", item.id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(0.9, 0.5, 0.5)
	handle.Color = Color3.fromHex(item.color)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide, handle.CanQuery, handle.CanTouch, handle.Massless = false, false, false, true
	handle.Parent = tool
	tool.Grip = CFrame.Angles(0, 0, math.rad(90)) -- (upright in the hand)
	tool.Activated:Connect(function() use(player, item.id) end)
	return tool
end

local function removeTool(player, id)
	local list = tools[player]
	local tool = list and list[id]
	if tool then tool:Destroy() end
	if list then list[id] = nil end
	player:SetAttribute("Equipped_" .. id, nil)
end

function refreshTool(player, id)
	if tools[player] and tools[player][id] and count(player, id) <= 0 then removeTool(player, id) end
end

local function equip(player, id)
	local item = Boosts.ById[id]
	if not item or not PlayerData.Get(player) then return end
	tools[player] = tools[player] or {}
	if tools[player][id] then
		removeTool(player, id) -- UNEQUIP
		return
	end
	if count(player, id) <= 0 then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = makeTool(player, item)
	tool.Parent = backpack
	tools[player][id] = tool
	player:SetAttribute("Equipped_" .. id, true)
end

------------------------------------------------------------------------
-- Studio: "/give creatine 5" (only the place owner, only in Studio)
------------------------------------------------------------------------
local function findItem(name: string)
	local wanted = string.lower((string.gsub(name, "[%s_]", "")))
	for _, item in ipairs(Boosts.Items) do
		if string.lower(item.id) == wanted or string.lower((string.gsub(item.name, "%s", ""))) == wanted then return item end
	end
	if wanted == "shake" or wanted == "shakes" then return Boosts.ById.Shake end
	return nil
end

local function watchChat(player)
	if not RunService:IsStudio() then return end
	local owner = game.CreatorType == Enum.CreatorType.User and game.CreatorId or 0
	if player.UserId ~= owner and owner ~= 0 then return end
	player.Chatted:Connect(function(message)
		local name, amount = string.match(message, "^/give%s+(%S+)%s*(%d*)")
		if not name then return end
		local item = findItem(name)
		if not item then
			warn("[ItemService] /give: no item called " .. name)
			return
		end
		PlayerData.AddItem(player, item.id, tonumber(amount) or 1)
		print(string.format("[ItemService] gave %s x%d", item.id, tonumber(amount) or 1))
	end)
end

------------------------------------------------------------------------
-- Rewards from other services (daily calendar, quests): one or more items, with the "added" toast
function ItemService.Give(player, id: string, amount: number?)
	if PlayerData.AddItem(player, id, amount or 1) then
		event(player, "ItemsAdded", { id = id, count = amount or 1 })
		return true
	end
	return false
end

-- (prompt 28) the shake in the hotbar unless it's there already
local function autoShake(player)
	if count(player, "Shake") > 0 and not (tools[player] and tools[player].Shake) then equip(player, "Shake") end
end

function ItemService.Start()
	ActionService.Register("UseItem", function(player, id)
		if type(id) == "string" then use(player, id) end
	end)
	ActionService.Register("EquipItem", function(player, id)
		if type(id) == "string" then equip(player, id) end
	end)
	PlayerData.Loaded:Connect(restore)
	PlayerData.Loaded:Connect(function(player) task.delay(1, autoShake, player) end)
	PlayerData.ItemChanged:Connect(function(player, id, new, old)
		if id == "Shake" and old <= 0 and new > 0 then autoShake(player) end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then restore(player) end
		watchChat(player)
	end
	Players.PlayerAdded:Connect(watchChat)
	-- a respawn empties the backpack: equipped items come back
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			local list = tools[player]
			if not list then
				autoShake(player)
				return
			end
			for id in pairs(list) do
				tools[player][id] = nil
				player:SetAttribute("Equipped_" .. id, nil)
				equip(player, id)
			end
			autoShake(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player], restored[player], tools[player] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(Boosts.SaveEvery)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(saveTimes, player)
				if not ok then warn("[ItemService] save:", err) end
				for _, item in ipairs(Boosts.Items) do
					if player:GetAttribute("Item_" .. item.id) and secondsLeft(player, item.id) <= 0 then player:SetAttribute("Item_" .. item.id, nil) end
				end
			end
		end
	end)
end

return ItemService
