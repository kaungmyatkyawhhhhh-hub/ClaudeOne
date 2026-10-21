-- ItemService (owner, prompt 14, 21 Oct; numbers in Config.Boosts): the boosts in the inventory. All checks are here.
--   UseItem(id)    uses one: the Protein Shake runs the old shake (StaminaService.DrinkShake: full stamina, the shake
--                  boost, the chug, "ShakeDrunk"); the others add their time to a BoostService source "Item_<id>" (capped at
--                  Boosts.MaxSeconds), Coconut Water also refills part of the stamina. The player attribute "Item_<id>" =
--                  the boost's end (server time) for the HUD timers. Everyone sees the chug.
--   EquipItem(id)  puts the item in the player's backpack as a Tool (the Roblox hotbar); activating it uses one, and the
--                  Tool goes away when the last one is used. EquipItem again (UNEQUIP) takes it out. The player attribute
--                  "Equipped_<id>" says it's there.
--                  (prompt 28b) Which items sit in the hotbar is saved (data.itemsEquipped): taken out stays out, also after
--                  a rejoin; one that ran out comes back when you get more. A new item type goes in by itself the first
--                  time you get it (while a slot is free); the Protein Shake for players from before this.
--   The held Tool (prompt 28b): activate = a drink (Boosts.DrinkSeconds, the chug for everyone); the item is used and
--                  its effect starts at the END. Put away, dead or another tool in hand meanwhile: nothing is used. One
--                  drink at a time, checked here (taps during a drink do nothing). The player attributes DrinkItem /
--                  DrinkUntil (server time) draw the radial sweep on the hotbar slot.
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

local function use(player, id, quiet: boolean?): boolean
	local item = Boosts.ById[id]
	if not item or not PlayerData.Get(player) then return false end
	local clock = os.clock()
	if clock - (lastUse[player] or 0) < Boosts.UseCooldown then return false end
	if count(player, id) <= 0 then return false end
	lastUse[player] = clock
	if item.shake then
		-- the old Energy Shake, exactly (StaminaService takes the shake from the inventory)
		local ok, StaminaService = pcall(require, script.Parent.StaminaService)
		if not ok or not StaminaService.DrinkShake(player, quiet) then return false end
	else
		if not PlayerData.AddItem(player, id, -1) then return false end
		if item.refill then
			local data = PlayerData.Get(player)
			PlayerData.SetStamina(player, data.stamina + PlayerData.GetMaxStamina(player) * item.refill)
		end
		if item.seconds then apply(player, item, Boosts.Extend(item, secondsLeft(player, id))) end
		saveTimes(player)
		if not quiet then ShowOffService.PlayEmote(player, "Chug") end
		event(player, "ItemUsed", { id = id })
	end
	refreshTool(player, id)
	return true
end

------------------------------------------------------------------------
-- The held drink (prompt 28b): activate -> a 1 s drink -> used at the end, unless it was put away
------------------------------------------------------------------------
local drinking = {}   -- [player] = { token, tool } while a drink runs
local drinkStart = {} -- [player] = os.clock() of the last drink's start (the server-side cooldown)

local function endDrink(player, cancelled: boolean)
	if not drinking[player] then return end
	drinking[player] = nil
	player:SetAttribute("DrinkItem", nil)
	player:SetAttribute("DrinkUntil", nil)
	if cancelled then ShowOffService.PlayEmote(player, "Chug", 0) end -- (stop the chug)
end

local function startDrink(player, tool: Tool, id: string)
	local clock = os.clock()
	if drinking[player] or clock - (drinkStart[player] or -math.huge) < Boosts.DrinkSeconds then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or tool.Parent ~= character or count(player, id) <= 0 then return end
	-- (not on a machine: the lifter's root is anchored there)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root.Anchored then return end
	drinkStart[player] = clock
	local token = {}
	drinking[player] = { token = token, tool = tool }
	player:SetAttribute("DrinkItem", id)
	player:SetAttribute("DrinkUntil", now() + Boosts.DrinkSeconds)
	ShowOffService.PlayEmote(player, "Chug", Boosts.DrinkSeconds)
	task.delay(Boosts.DrinkSeconds, function()
		local state = drinking[player]
		if not state or state.token ~= token then return end
		endDrink(player, false)
		-- still in the hand of the same, living character: now it counts
		if tool.Parent == character and player.Character == character and humanoid.Health > 0 then
			lastUse[player] = nil -- (the drink was the wait)
			use(player, id, true)
		end
	end)
end

------------------------------------------------------------------------
-- EQUIP: the item as a Tool in the backpack (activate = drink one)
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
	tool.Activated:Connect(function() startDrink(player, tool, item.id) end)
	tool.Unequipped:Connect(function()
		local state = drinking[player]
		if state and state.tool == tool then endDrink(player, true) end
	end)
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

-- the Tool in the backpack (nothing saved here)
local function giveTool(player, id)
	local item = Boosts.ById[id]
	if not item or not PlayerData.Get(player) then return end
	tools[player] = tools[player] or {}
	if tools[player][id] or count(player, id) <= 0 then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = makeTool(player, item)
	tool.Parent = backpack
	tools[player][id] = tool
	player:SetAttribute("Equipped_" .. id, true)
end

local function toolCount(player): number
	local n = 0
	for _ in pairs(tools[player] or {}) do n += 1 end
	return n
end

-- EQUIP / UNEQUIP from the Inventory: the player's choice, saved
local function equip(player, id)
	if not Boosts.ById[id] or not PlayerData.Get(player) then return end
	if tools[player] and tools[player][id] then
		removeTool(player, id)
		PlayerData.SetItemEquipped(player, id, false)
		return
	end
	if count(player, id) <= 0 then return end
	PlayerData.SetItemEquipped(player, id, true)
	giveTool(player, id)
end

-- every item the player keeps in the hotbar (join, respawn); players from before prompt 28b get the shake once
local function fillHotbar(player)
	local data = PlayerData.Get(player)
	if not data then return end
	data.itemsEquipped = data.itemsEquipped or {}
	if data.itemsEquipped.Shake == nil and count(player, "Shake") > 0 then PlayerData.SetItemEquipped(player, "Shake", true) end
	for _, item in ipairs(Boosts.Items) do
		if data.itemsEquipped[item.id] == true then giveTool(player, item.id) end
	end
end

-- more of an item: back in the hotbar if the player keeps it there (it ran out), or in by itself the first time
local function onItemChanged(player, id, new, old)
	if new <= old then return end
	local data = PlayerData.Get(player)
	if not data then return end
	local wanted = data.itemsEquipped and data.itemsEquipped[id]
	if wanted == nil and toolCount(player) < Boosts.HotbarSlots then
		PlayerData.SetItemEquipped(player, id, true)
		wanted = true
	end
	if wanted == true then giveTool(player, id) end
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
function ItemService.Start()
	ActionService.Register("UseItem", function(player, id)
		if type(id) == "string" then use(player, id) end
	end)
	ActionService.Register("EquipItem", function(player, id)
		if type(id) == "string" then equip(player, id) end
	end)
	PlayerData.Loaded:Connect(restore)
	PlayerData.Loaded:Connect(function(player) task.delay(1, fillHotbar, player) end)
	PlayerData.ItemChanged:Connect(onItemChanged)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then restore(player) end
		watchChat(player)
	end
	Players.PlayerAdded:Connect(watchChat)
	-- a respawn empties the backpack: equipped items come back
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			endDrink(player, false)
			for id in pairs(tools[player] or {}) do
				tools[player][id] = nil
				player:SetAttribute("Equipped_" .. id, nil)
			end
			fillHotbar(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player], restored[player], tools[player], drinking[player], drinkStart[player] = nil, nil, nil, nil, nil
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
