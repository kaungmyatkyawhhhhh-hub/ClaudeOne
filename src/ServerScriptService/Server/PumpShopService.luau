-- PumpShopService (owner, prompt 19, 21 Oct; prompt 31, 22 Oct: three shops; every number in Config.PumpShop). Coins only.
--   Shops (Config.PumpShop.Shops), each only sells its own things and only to a player standing at it:
--     Coach    Coach Dex in the Starter Gym (QuestService opens it when you talk to him): normal supplements, Basic / Pro
--              gear, ALTERS (nothing is bought there)
--     Pump     the PUMP SHOP in town (its counter, tag "PumpShopCounter"): special supplements, Elite / Champion gear, DNA
--     Coconut  the coconut stand at the beach gym (tag "CoconutStand"): Coconut Water only, x1 / x5
--   * Buying (remote "PumpShop", action "Buy", shop, section, id, quantity): the shop sells it, the section is open for you,
--     you're at that shop, coins checked here.
--       Supplements  boost items into the inventory (Config.Boosts), price = minutes of coins at your stage
--       Gear         (prompt 59) the belt and the wraps: the level right above your best (BASIC / PRO at Coach Dex; ELITE /
--                    CHAMPION off sale), worn right away (CosmeticService); the best level owned counts
--       (prompt 57) the PUMP SHOP's specials are Robux only (MonetizationService); a coin buy of them is refused
--       DNA Lab      the usual "BuyDnaToken" action (+10% per token each week, ActionService)
--   * "Teleport": to the PUMP SHOP entrance; "TeleportCoach": to Coach Dex's counter (both every 10 s at most).
--   * Unlocks: the shops open after OpenAfterMinutes of play or the first Growth Spurt; Gear at GearAtSpurt; Alters at 7'0".
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local PumpShop = require(Config.PumpShop)
local Boosts = require(Config.Boosts)
local Cosmetics = require(Config.Cosmetics)
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local CosmeticService = require(script.Parent.CosmeticService)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local PumpShopService = {}

local REACH = 14 -- studs from a shop's counter where buying is allowed
-- the PUMP SHOP's shopkeeper behind its one counter (prompt 51: an original character, big and friendly, in a black shop
-- shirt with gold trim and a black cap with a gold peak, so he's clearly not Coach Dex; he leans on the counter and looks at
-- you like Dex does: CoachDexClient, tag "PumpShopClerk")
local CLERK = { name = "Mo", skin = "#C68642", shirt = "#1B1B1F", pants = "#2B2B30", scale = { height = 1.4, width = 1.35, depth = 1.25, head = 1.1 } }
local GOLD = Color3.fromHex("#F6C75A")
local remote: RemoteEvent
local lastTeleport = {} -- [player] = os.clock()
local lastCoachTeleport = {} -- [player] = os.clock()

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
	local section = PumpShop.SectionById[sectionId]
	if not section then return false end
	if section.atMax then return GrowthSpurts.IsMaxed(data.growthSpurts or 0) end
	return (data.growthSpurts or 0) >= (section.fromSpurt or 0)
end

------------------------------------------------------------------------
-- Where each shop is
------------------------------------------------------------------------
local function coachPart(): BasePart?
	for _, model in ipairs(CollectionService:GetTagged("Coach")) do
		local root = model:FindFirstChild("HumanoidRootPart") or (model:IsA("Model") and model.PrimaryPart)
		if root and root:IsA("BasePart") then return root end
	end
	return nil
end
local function shopParts(shopId: string): { BasePart }
	local list = {}
	if shopId == "Pump" then
		for _, part in ipairs(CollectionService:GetTagged("PumpShopCounter")) do
			if part:IsA("BasePart") then table.insert(list, part) end
		end
	elseif shopId == "Coconut" then
		for _, part in ipairs(CollectionService:GetTagged("CoconutStand")) do
			if part:IsA("BasePart") then table.insert(list, part) end
		end
	elseif shopId == "Coach" then
		local part = coachPart()
		if part then table.insert(list, part) end
	end
	return list
end
local function atShop(player, shopId: string): boolean
	for _, part in ipairs(shopParts(shopId)) do
		if part.Parent and Guard.Near(player, part, REACH + Guard.DistanceSlack) then return true end
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

local function buySupplement(player, data, shop, id, quantity)
	local item = Boosts.ById[id]
	local price = PumpShop.SupplementPrice(id, data.growthSpurts)
	if not item or not price or not table.find(shop.supplements, id) or not table.find(shop.quantities or PumpShop.Quantities, quantity) then return end
	if PumpShop.RobuxSupplements[id] then return end -- (prompt 57: Robux only, MonetizationService)
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

-- (prompt 59) a gear level: only the one right above the best you own, only where it's sold (BASIC / PRO at Coach Dex,
-- never an off-sale level); worn at once (the best level counts, worn or not)
local function buyGear(player, data, shop, itemId)
	local state = cosmeticsState(data)
	local gear = nil
	for _, g in ipairs(PumpShop.Gear) do
		if type(itemId) == "string" and string.sub(itemId, 1, #g.id + 1) == g.id .. "_" then gear = g end
	end
	local level = gear and PumpShop.GearLevelById[string.sub(itemId, #gear.id + 2)]
	if not gear or not level or level.offSale or not Cosmetics.ById[itemId] or not table.find(shop.gear, level.id) then return end
	local best = PumpShop.GearBest(state.owned, gear.id)
	if (best and best.index or 0) + 1 ~= level.index then return end
	if not PlayerData.SpendCoins(player, level.price) then
		send(player, "Failed", { text = "Not enough coins: " .. Cosmetics.ById[itemId].name .. " costs " .. level.price .. "." })
		return
	end
	CosmeticService.Grant(player, itemId, true)
	send(player, "Bought", { section = "Gear", id = itemId })
end

-- (prompt 59) Once per player (flag cosmetics.gear59): LIFTING STRAPS and KNEE SLEEVES are gone. Straps count toward the
-- WRIST WRAPS, sleeves toward the LIFTING BELT: a higher level than the matching piece you own = that level of it; else
-- the coins paid for the removed piece come back (Config prices; gear was never sold for Robux). The removed pieces leave
-- the save, and the best belt and wraps are worn. A player who owned any gear gets the one-time "Gear got simpler!" note.
local function migrateGear(player)
	local data = PlayerData.WaitFor(player)
	if not data or not player.Parent then return end
	local state = cosmeticsState(data)
	if state.gear59 then return end
	local hadGear, refund = false, 0
	for _, removed in ipairs(PumpShop.RemovedGear) do
		local best, paid = nil, 0
		for _, level in ipairs(PumpShop.GearLevels) do
			local oldId = PumpShop.GearItemId(removed.id, level.id)
			if state.owned[oldId] then
				best = level
				paid += level.price
				state.owned[oldId] = nil
			end
		end
		if state.equipped[removed.slot] and string.sub(tostring(state.equipped[removed.slot]), 1, #removed.id + 1) == removed.id .. "_" then
			state.equipped[removed.slot] = nil
		end
		if best then
			hadGear = true
			local into = PumpShop.GearBest(state.owned, removed.into)
			if not into or best.index > into.index then
				-- the matching piece at that level (and the levels under it, so the ladder stays whole)
				for _, level in ipairs(PumpShop.GearLevels) do
					if level.index <= best.index then state.owned[PumpShop.GearItemId(removed.into, level.id)] = true end
				end
			else
				refund += paid
			end
		end
	end
	for _, gear in ipairs(PumpShop.Gear) do
		local best = PumpShop.GearBest(state.owned, gear.id)
		if best then
			hadGear = true
			state.equipped[gear.slot] = PumpShop.GearItemId(gear.id, best.id)
		end
	end
	state.gear59 = true
	PlayerData.SetTable(player, "cosmetics", state)
	if refund > 0 then PlayerData.AddCoins(player, refund) end
	if hadGear then
		Remotes.PlayerEvent:FireClient(player, "GearSimpler", { refund = refund })
		CosmeticService.Rebuild(player)
	end
end

local function buy(player, shopId, section, id, quantity)
	local data = PlayerData.Get(player)
	local shop = type(shopId) == "string" and PumpShop.Shops[shopId]
	if not data or not shop or type(section) ~= "string" or type(id) ~= "string" then return end
	if not table.find(shop.tabs, section) or not PumpShopService.IsOpen(data) or not sectionOpen(data, section) then return end
	if not atShop(player, shopId) then return end
	if section == "Style" then
		-- (prompt 61) a STYLE item (StyleService checks it and the coins)
		local ok, failText = require(script.Parent.StyleService).Buy(player, id)
		if ok then send(player, "Bought", { section = "Style", id = id }) elseif failText then send(player, "Failed", { text = failText }) end
	elseif section == "Supplements" then
		buySupplement(player, data, shop, id, tonumber(quantity) or 1)
	elseif section == "Gear" then
		buyGear(player, data, shop, id)
	end
end

------------------------------------------------------------------------
-- Teleports (the Shop window's links)
------------------------------------------------------------------------
local function moveTo(player, part: BasePart, ahead: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart or player:GetAttribute("PosingComp") then return false end
	local height = humanoid.HipHeight + (character.PrimaryPart and character.PrimaryPart.Size.Y / 2 or 1)
	local spot = (part.CFrame * CFrame.new(0, 0, -ahead)).Position
	-- stand on the floor there
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, part.Parent }
	local hit = Workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
	local floorY = if hit then hit.Position.Y else part.Position.Y - 3
	local at = Vector3.new(spot.X, floorY + height, spot.Z)
	character:PivotTo(CFrame.lookAt(at, Vector3.new(part.Position.X, at.Y, part.Position.Z)))
	return true
end

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

local function teleportCoach(player)
	local clock = os.clock()
	if clock - (lastCoachTeleport[player] or -math.huge) < PumpShop.CoachTeleportCooldown then return end
	local part = coachPart()
	if not part then return end
	lastCoachTeleport[player] = clock
	-- in front of him (he faces the room), 6 studs out
	if moveTo(player, part, 6) then send(player, "TeleportedCoach", {}) end
end

------------------------------------------------------------------------
-- Opening a shop
------------------------------------------------------------------------
function PumpShopService.OpenFor(player, shopId, section)
	local data = PlayerData.Get(player)
	local shop = PumpShop.Shops[shopId]
	if not data or not shop then return end
	if not PumpShopService.IsOpen(data) then
		send(player, "Failed", { text = "The shops open after a few minutes of training." })
		return
	end
	local wanted = if section and table.find(shop.tabs, section) and sectionOpen(data, section) then section else "Supplements"
	send(player, "Open", { shop = shopId, section = wanted })
end

-- the shop shirt's gold band and name badge, the cap: small parts welded on (they follow the posed joints)
local function dressClerk(model: Model)
	local function add(name, size, cframe, color, holder: BasePart, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.Anchored = false
		p.Massless = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = holder, p
		weld.Parent = p
		p.Parent = model
	end
	local torso = model:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		local s = torso.Size
		add("ShirtBand", Vector3.new(s.X * 1.02, s.Y * 0.08, s.Z * 1.06), torso.CFrame * CFrame.new(0, -s.Y * 0.05, 0), GOLD, torso)
		add("Badge", Vector3.new(s.X * 0.16, s.Y * 0.1, 0.05), torso.CFrame * CFrame.new(-s.X * 0.22, s.Y * 0.25, -s.Z * 0.5), GOLD, torso)
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local s = head.Size
		add("Cap", Vector3.new(s.Y * 0.3, s.X * 1.04, s.X * 1.04), head.CFrame * CFrame.new(0, s.Y * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromHex("#1B1B1F"), head, Enum.PartType.Cylinder)
		add("CapPeak", Vector3.new(s.X * 0.8, 0.08, s.Z * 0.45), head.CFrame * CFrame.new(0, s.Y * 0.3, -s.Z * 0.62), GOLD, head)
	end
end

local function addPrompt(part: Instance, shopId: string, objectText: string)
	if not part:IsA("BasePart") then return end
	local prompt = part:FindFirstChild("ShopPrompt")
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = "ShopPrompt"
		created.ActionText = "Shop"
		created.ObjectText = objectText
		created.MaxActivationDistance = 9
		created.RequiresLineOfSight = false
		created.Parent = part
		prompt = created
	end
	Guard.OnTriggered(prompt, function(player) PumpShopService.OpenFor(player, shopId) end)
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
	Guard.Remote(remote, "PumpShop", 6, 10, function(player, action, a, b, c, d)
		if action == "Buy" then
			buy(player, a, b, c, d)
		elseif action == "Teleport" then
			teleport(player)
		elseif action == "TeleportCoach" then
			teleportCoach(player)
		end
	end)
	local seen = {}
	local function counter(part) if not seen[part] then seen[part] = true; addPrompt(part, "Pump", "PUMP SHOP") end end
	local function stand(part) if not seen[part] then seen[part] = true; addPrompt(part, "Coconut", "COCONUT STAND") end end
	for _, part in ipairs(CollectionService:GetTagged("PumpShopCounter")) do counter(part) end
	for _, part in ipairs(CollectionService:GetTagged("CoconutStand")) do stand(part) end
	CollectionService:GetInstanceAddedSignal("PumpShopCounter"):Connect(counter)
	CollectionService:GetInstanceAddedSignal("CoconutStand"):Connect(stand)
	-- the clerk on the counter's ClerkSpot
	local shop = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("PumpShop")
	if shop then
		local NpcService = require(script.Parent.NpcService)
		for _, spot in ipairs(shop:GetDescendants()) do
			if spot.Name == "ClerkSpot" and spot:IsA("BasePart") then
				local ok, err = pcall(function()
					local feet = spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
					local model = NpcService.Build({ name = CLERK.name, skin = CLERK.skin, shirt = CLERK.shirt, pants = CLERK.pants, scale = CLERK.scale,
						animated = true, tag = "PumpShopClerk" }, CFrame.lookAt(feet, feet + spot.CFrame.LookVector))
					dressClerk(model)
					model.Parent = shop
				end)
				if not ok then warn("[PumpShopService] clerk:", err) end
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player], lastCoachTeleport[player] = nil, nil
	end)
	-- (prompt 59) the gear migration, once per player
	Players.PlayerAdded:Connect(function(player) task.spawn(migrateGear, player) end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(migrateGear, player) end
	-- the unlock lines (Coach Dex, once each) and the shops' open state for the HUD (player attribute "PumpShop":
	-- nil = closed, "Supplements" = open, "All" = gear too)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data then
					local open = PumpShopService.IsOpen(data)
					local all = open and (data.growthSpurts or 0) >= PumpShop.GearAtSpurt
					player:SetAttribute("PumpShop", if all then "All" elseif open then "Supplements" else nil)
					if open then coach(player, "pumpShopIntro", "My shop is open! Talk to me for shakes and boosts. The PUMP SHOP in town has the strong stuff.") end
					if all then coach(player, "pumpShopGearIntro", "You can buy gear from me now. A good belt helps your squats!") end
				end
			end
			task.wait(10)
		end
	end)
end

return PumpShopService
