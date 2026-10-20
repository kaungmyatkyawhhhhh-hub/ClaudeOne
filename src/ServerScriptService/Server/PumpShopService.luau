-- PumpShopService (owner, prompt 19, 21 Oct; every number in Config.PumpShop): the PUMP SHOP in the town hub. Coins only.
--   * Counters: parts tagged "PumpShopCounter" (attribute Section) inside Workspace.Town.PumpShop (tools/builders/
--     PumpShop) get a "Shop" prompt; it opens that section's panel (every section can be browsed from any counter).
--     The old smoothie bar and carts (MealService) open the Supplements section now.
--   * Buying (remote "PumpShop", action "Buy", section, id, quantity): only near a counter (or a smoothie stall for
--     Supplements), only unlocked sections, coins checked here.
--       Supplements  boost items into the inventory (Config.Boosts), price = minutes of coins at your stage, x1/x5/x10
--       Gear         Basic -> Pro -> Elite (each needs the one before), worn right away (CosmeticService), perk while worn
--       Apparel      shorts / tank top colors (settings) and headbands, shakers, gym bags (CosmeticService)
--       DNA Lab      the usual "BuyDnaToken" action (+10% per token each week, ActionService)
--   * "TryOn" (apparel): shows it on your character for a few seconds; "TryOff" ends it.
--   * "Teleport": to the entrance (the HUD's PUMP SHOP button), every TeleportCooldown seconds.
--   * Unlocks: open after OpenAfterMinutes of play or the first Growth Spurt (Supplements); Gear and Apparel at
--     GearAtSpurt. Coach Dex says one line at each (once per player, onboarding flags).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local PumpShop = require(Config.PumpShop)
local Boosts = require(Config.Boosts)
local Body = require(Config.Body)
local Cosmetics = require(Config.Cosmetics)
local PlayerData = require(script.Parent.PlayerData)
local CosmeticService = require(script.Parent.CosmeticService)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local PumpShopService = {}

local REACH = 14 -- studs from a counter where buying is allowed
-- the clerks behind the counters (original characters, in the shop's graphite and gold)
local CLERKS = {
	Supplements = { name = "Mo", skin = "#C68642" },
	Gear = { name = "Rita", skin = "#F1C27D" },
	Apparel = { name = "Jay", skin = "#8D5524" },
	DnaLab = { name = "Dr. Vale", skin = "#E0AC69" },
}
local remote: RemoteEvent
local counters = {} -- [part] = section id
local lastTeleport = {} -- [player] = os.clock()
local tried = {} -- [player] = { kind, id, token }

local function send(player, kind, info)
	if player.Parent then remote:FireClient(player, kind, info or {}) end
end

local function coach(player, flag, text)
	local data = PlayerData.Get(player)
	if not data or data.onboarding[flag] then return end
	PlayerData.SetFlag(player, flag, true)
	Remotes.PlayerEvent:FireClient(player, "CoachSays", { text = text })
end

------------------------------------------------------------------------
-- Unlocks
------------------------------------------------------------------------
local function minutesPlayed(data): number
	local first = data.meta and data.meta.firstJoin or 0
	if first <= 0 then return 0 end
	return (os.time() - first) / 60
end

function PumpShopService.IsOpen(data): boolean
	return data ~= nil and ((data.growthSpurts or 0) >= 1 or minutesPlayed(data) >= PumpShop.OpenAfterMinutes)
end

local function sectionOpen(data, sectionId): boolean
	if not PumpShopService.IsOpen(data) then return false end
	for _, section in ipairs(PumpShop.Sections) do
		if section.id == sectionId then return (data.growthSpurts or 0) >= (section.fromSpurt or 0) end
	end
	return false
end

------------------------------------------------------------------------
-- Where buying is allowed
------------------------------------------------------------------------
local function nearCounter(player, sectionId): boolean
	for part in pairs(counters) do
		if part.Parent and Guard.Near(player, part, REACH + Guard.DistanceSlack) then return true end
	end
	if sectionId == "Supplements" then
		-- (the smoothie bar and carts sell supplements too)
		for _, part in ipairs(CollectionService:GetTagged("MealShop")) do
			if part:IsA("BasePart") and Guard.Near(player, part, 12 + Guard.DistanceSlack) then return true end
		end
	end
	return false
end

------------------------------------------------------------------------
-- Buying
------------------------------------------------------------------------
local function cosmeticsState(data)
	local state = type(data.cosmetics) == "table" and data.cosmetics or {}
	state.owned = type(state.owned) == "table" and state.owned or {}
	state.equipped = type(state.equipped) == "table" and state.equipped or {}
	return state
end

local function buySupplement(player, data, id, quantity)
	local item = Boosts.ById[id]
	local price = PumpShop.SupplementPrice(id, data.growthSpurts)
	if not item or not price or not table.find(PumpShop.Quantities, quantity) then return end
	local have = tonumber(data.items[id]) or 0
	if have + quantity > Boosts.MaxCount then
		send(player, "Failed", { text = "You can carry " .. Boosts.MaxCount .. " " .. item.name .. " at most." })
		return
	end
	if not PlayerData.SpendCoins(player, price * quantity) then
		send(player, "Failed", { text = "Not enough coins: " .. quantity .. " x " .. item.name .. " costs " .. price * quantity .. "." })
		return
	end
	PlayerData.AddItem(player, id, quantity)
	Remotes.PlayerEvent:FireClient(player, "ItemsAdded", { id = id, count = quantity })
	send(player, "Bought", { section = "Supplements", id = id, quantity = quantity })
end

local function buyGear(player, data, gearId)
	local state = cosmeticsState(data)
	for index, level in ipairs(PumpShop.GearLevels) do
		local itemId = PumpShop.GearItemId(gearId, level.id)
		if not state.owned[itemId] then
			-- the next level up (each needs the one before)
			if not Cosmetics.ById[itemId] then return end
			if index > 1 and not state.owned[PumpShop.GearItemId(gearId, PumpShop.GearLevels[index - 1].id)] then return end
			if not PlayerData.SpendCoins(player, level.price) then
				send(player, "Failed", { text = "Not enough coins: " .. Cosmetics.ById[itemId].name .. " costs " .. level.price .. "." })
				return
			end
			CosmeticService.Grant(player, itemId, true)
			send(player, "Bought", { section = "Gear", id = itemId })
			return
		end
	end
end

local function apparelEntry(kind, id)
	for _, entry in ipairs(PumpShop.Apparel) do
		if entry.kind == kind and entry.id == id then return entry end
	end
	return nil
end

local function buyApparel(player, data, kind, id)
	local entry = apparelEntry(kind, id)
	if not entry then return end
	local state = cosmeticsState(data)
	if kind == "Cosmetic" then
		if state.owned[id] or not Cosmetics.ById[id] then return end
		if not PlayerData.SpendCoins(player, entry.price) then
			send(player, "Failed", { text = "Not enough coins: it costs " .. entry.price .. "." })
			return
		end
		CosmeticService.Grant(player, id, true)
	else
		local key = kind .. "_" .. id
		if state.owned[key] then return end
		if not PlayerData.SpendCoins(player, entry.price) then
			send(player, "Failed", { text = "Not enough coins: it costs " .. entry.price .. "." })
			return
		end
		state.owned[key] = true
		PlayerData.SetTable(player, "cosmetics", state)
		-- worn right away
		PlayerData.SetSettings(player, if kind == "Shorts" then { shorts = id } else { top = id })
	end
	send(player, "Bought", { section = "Apparel", kind = kind, id = id })
end

local function buy(player, section, id, quantity)
	local data = PlayerData.Get(player)
	if not data or type(section) ~= "string" or type(id) ~= "string" then return end
	if not sectionOpen(data, section) or not nearCounter(player, section) then return end
	if section == "Supplements" then
		buySupplement(player, data, id, tonumber(quantity) or 1)
	elseif section == "Gear" then
		buyGear(player, data, id)
	elseif section == "Apparel" then
		buyApparel(player, data, quantity, id) -- (quantity = the apparel kind here)
	end
end

------------------------------------------------------------------------
-- Try on (apparel)
------------------------------------------------------------------------
local function tryOff(player)
	local state = tried[player]
	tried[player] = nil
	if not state then return end
	if state.kind == "Cosmetic" then
		CosmeticService.TryOn(player, nil)
	else
		-- back to what they wear (BodyService publishes the saved settings as the player's attributes)
		local data = PlayerData.Get(player)
		if player.Parent then
			player:SetAttribute("TryOnShorts", nil)
			player:SetAttribute("TryOnTop", nil)
			if data then
				player:SetAttribute("Shorts", data.settings.shorts or Body.DefaultShorts)
				player:SetAttribute("Top", data.settings.top or Body.DefaultTop)
			end
		end
	end
end

local function tryOn(player, kind, id)
	if type(kind) ~= "string" or type(id) ~= "string" or not apparelEntry(kind, id) then return end
	local data = PlayerData.Get(player)
	if not data or not sectionOpen(data, "Apparel") or not nearCounter(player, "Apparel") then return end
	tryOff(player)
	local mine = { kind = kind, id = id }
	tried[player] = mine
	if kind == "Cosmetic" then
		CosmeticService.TryOn(player, id, PumpShop.TryOnSeconds)
	else
		-- (every client draws the body from Shorts / Top; BodyService keeps the TryOn one while it's set)
		player:SetAttribute(if kind == "Shorts" then "TryOnShorts" else "TryOnTop", id)
		player:SetAttribute(if kind == "Shorts" then "Shorts" else "Top", id)
	end
	task.delay(PumpShop.TryOnSeconds, function()
		if tried[player] == mine then tryOff(player) end
	end)
end

------------------------------------------------------------------------
-- Teleport (the HUD's PUMP SHOP button)
------------------------------------------------------------------------
local function teleport(player)
	local data = PlayerData.Get(player)
	if not PumpShopService.IsOpen(data) then return end
	local clock = os.clock()
	if clock - (lastTeleport[player] or -math.huge) < PumpShop.TeleportCooldown then return end
	local shop = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("PumpShop")
	local entrance = shop and shop:FindFirstChild("Entrance", true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not entrance or not entrance:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return end
	if player:GetAttribute("PosingComp") then return end -- (not off a posing show stage)
	lastTeleport[player] = clock
	local height = humanoid.HipHeight + (character.PrimaryPart and character.PrimaryPart.Size.Y / 2 or 1)
	character:PivotTo(entrance.CFrame + Vector3.new(0, entrance.Size.Y / 2 + height, 0))
	send(player, "Teleported", {})
end

------------------------------------------------------------------------
-- The counters
------------------------------------------------------------------------
function PumpShopService.OpenFor(player, section)
	local data = PlayerData.Get(player)
	if not data then return end
	if not PumpShopService.IsOpen(data) then
		send(player, "Failed", { text = "The PUMP SHOP opens after a few minutes of training." })
		return
	end
	send(player, "Open", { section = if sectionOpen(data, section) then section else "Supplements" })
end

local function addCounter(part: Instance)
	if not part:IsA("BasePart") or counters[part] then return end
	local section = part:GetAttribute("Section")
	if type(section) ~= "string" then return end
	counters[part] = section
	local prompt = part:FindFirstChild("ShopPrompt")
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = "ShopPrompt"
		created.ActionText = "Shop"
		created.ObjectText = "PUMP SHOP"
		created.MaxActivationDistance = 9
		created.RequiresLineOfSight = false
		created.Parent = part
		prompt = created
	end
	Guard.OnTriggered(prompt, function(player) PumpShopService.OpenFor(player, section) end)
end

function PumpShopService.Start()
	local existing = Remotes:FindFirstChild("PumpShop")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "PumpShop"
		created.Parent = Remotes
		remote = created
	end
	Guard.Remote(remote, "PumpShop", 6, 10, function(player, action, a, b, c)
		if action == "Buy" then
			buy(player, a, b, c)
		elseif action == "TryOn" then
			tryOn(player, a, b)
		elseif action == "TryOff" then
			tryOff(player)
		elseif action == "Teleport" then
			teleport(player)
		end
	end)
	for _, part in ipairs(CollectionService:GetTagged("PumpShopCounter")) do addCounter(part) end
	-- the clerks (one per section, on its ClerkSpot)
	local shop = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("PumpShop")
	if shop then
		local NpcService = require(script.Parent.NpcService)
		for _, spot in ipairs(shop:GetDescendants()) do
			local spec = spot.Name == "ClerkSpot" and CLERKS[spot:GetAttribute("Section")]
			if spec and spot:IsA("BasePart") then
				local ok, err = pcall(function()
					local feet = spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
					local model = NpcService.Build({ name = spec.name, skin = spec.skin, shirt = "#1E1E22", pants = "#2B2B30", animated = true, tag = "PumpShopClerk" },
						CFrame.lookAt(feet, feet + spot.CFrame.LookVector))
					model.Parent = shop
				end)
				if not ok then warn("[PumpShopService] clerk:", err) end
			end
		end
	end
	CollectionService:GetInstanceAddedSignal("PumpShopCounter"):Connect(addCounter)
	if #CollectionService:GetTagged("PumpShopCounter") == 0 then
		warn("[PumpShopService] no PUMP SHOP counters (tag PumpShopCounter): build the store with tools/builders/PumpShop.luau")
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player], tried[player] = nil, nil
	end)
	-- the unlock lines (Coach Dex, once each) and the shop's open state for the HUD (player attribute "PumpShop":
	-- nil = closed, "Supplements" = open, "All" = every section)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data then
					local open = PumpShopService.IsOpen(data)
					local all = open and (data.growthSpurts or 0) >= PumpShop.GearAtSpurt
					player:SetAttribute("PumpShop", if all then "All" elseif open then "Supplements" else nil)
					if open then coach(player, "pumpShopIntro", "The PUMP SHOP in town is open! Spend your coins on shakes and boosts. Tap PUMP SHOP to go there.") end
					if all then coach(player, "pumpShopGearIntro", "You can buy gear and apparel at the PUMP SHOP now. A good belt helps your squats!") end
				end
			end
			task.wait(10)
		end
	end)
end

return PumpShopService
