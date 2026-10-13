-- MealService (owner's feature run, task 5; numbers in Config.Meals): the smoothie bar in the pro gym, the smoothie cart in
-- the starter gym and the coconut cart at the beach gym. Walk up, press the prompt, the shop panel opens (MealClient);
-- buying is checked here (near the stall, the stall sells it, enough coins), then the boost goes through BoostService
-- ("Meal_<id>": EXP / stamina refill / treadmill distance) and the player attribute "Meal_<id>" = its end (server time)
-- for the HUD timers. Buying again adds time (capped). Boosts PAUSE while you're away: the time left is saved
-- (data.meals[id] = seconds left, updated every few seconds) and picked up again when you join.
-- The character holds a shaker for a moment and does the shake chug (everyone sees it).
-- Studio: Workspace attribute TestMealRejoin = seconds away (see Start).
-- Stalls: invisible OrderPoint parts in front of each counter with the attribute MealShop (Config.Meals.Shops).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meals = require(ReplicatedStorage.Shared.Config.Meals)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local ShowOffService = require(script.Parent.ShowOffService)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local MealService = {}

local remote: RemoteEvent
local stalls = {} -- [part] = shop id
local restored = {} -- [player] = true once the saved time left is back on (only then is it saved again)

local function now() return Workspace:GetServerTimeNow() end

local function send(player, kind, info)
	if player.Parent then remote:FireClient(player, kind, info or {}) end
end

------------------------------------------------------------------------
-- Boosts
------------------------------------------------------------------------
local function apply(player: Player, item, secondsLeft: number)
	local untilTime = now() + secondsLeft
	local source = { untilTime = untilTime }
	for key, value in pairs(item.effects) do source[key] = value end
	BoostService.SetPlayer(player, "Meal_" .. item.id, source)
	player:SetAttribute("Meal_" .. item.id, untilTime)
end

local function secondsLeft(player: Player, id: string): number
	local source = BoostService.GetPlayer(player, "Meal_" .. id)
	return source and source.untilTime and math.max(0, source.untilTime - now()) or 0
end

-- the saved time left, picked up again on join
local function restore(player: Player)
	local data = PlayerData.Get(player)
	if not data then return end
	restored[player] = true
	if type(data.meals) ~= "table" then return end
	for id, left in pairs(data.meals) do
		local item = Meals.ById[id]
		if item and type(left) == "number" and left > 0 then apply(player, item, math.min(left, item.seconds * Meals.MaxStack)) end
	end
end

local function saveTimes(player: Player)
	local data = PlayerData.Get(player)
	-- (never before the restore: that would save "nothing left" over the paused boosts)
	if not data or not restored[player] then return end
	local meals = {}
	for _, item in ipairs(Meals.Items) do
		local left = secondsLeft(player, item.id)
		if left > 0 then meals[item.id] = math.floor(left) end
	end
	data.meals = meals -- (saved with the rest; the client reads the attributes, not this)
end

------------------------------------------------------------------------
-- The shaker in your hand (runtime prop, everyone sees it)
------------------------------------------------------------------------
local function holdShaker(player: Player, item)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	if not hand or not hand:IsA("BasePart") then return end
	local model = Instance.new("Model")
	model.Name = "MealShaker"
	local function piece(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
		-- upright in the hand (a cylinder's axis is X: turn it up), a little in front of the palm
		p.CFrame = hand.CFrame * CFrame.new(0, -0.1, -0.4) * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, p
		weld.Parent = p
		return p
	end
	piece("Body", Vector3.new(1.1, 0.55, 0.55), Vector3.new(0, 0, 0), Color3.fromHex(item.color), Enum.Material.SmoothPlastic)
	piece("Lid", Vector3.new(0.2, 0.58, 0.58), Vector3.new(0, 0.62, 0), Color3.fromHex("#1E1E22"), Enum.Material.SmoothPlastic)
	piece("Cap", Vector3.new(0.12, 0.22, 0.22), Vector3.new(0, 0.77, 0), Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
	model.Parent = character
	ShowOffService.PlayEmote(player, "Chug")
	task.delay(Meals.DrinkSeconds, function() model:Destroy() end)
end

------------------------------------------------------------------------
-- Buying
------------------------------------------------------------------------
local lastBuy = {}

local function buy(player: Player, shopId: any, itemId: any)
	if type(shopId) ~= "string" or type(itemId) ~= "string" then return end
	local shop = Meals.Shops[shopId]
	local item = Meals.ById[itemId]
	if not shop or not item or not table.find(shop.items, itemId) then return end
	local clock = os.clock()
	if clock - (lastBuy[player] or 0) < 0.6 then return end
	lastBuy[player] = clock
	-- standing at that stall
	local near = false
	for part, id in pairs(stalls) do
		if id == shopId and part.Parent and Guard.Near(player, part, Meals.PromptDistance + Guard.DistanceSlack) then near = true end
	end
	if not near then return end
	-- already full (MaxStack purchases' worth): no sale, no coins taken
	local current = secondsLeft(player, item.id)
	if not Meals.CanBuy(item, current) then
		send(player, "Failed", { text = item.name .. " is already as long as it gets (" .. Meals.Clock(current) .. " left)." })
		return
	end
	if not PlayerData.SpendCoins(player, item.price) then
		send(player, "Failed", { text = item.name .. " costs " .. item.price .. " coins." })
		return
	end
	local left = Meals.Extend(item, current)
	apply(player, item, left)
	saveTimes(player)
	holdShaker(player, item)
	send(player, "Bought", { id = item.id, seconds = left })
end

local function addStall(part: Instance)
	if not part:IsA("BasePart") or stalls[part] then return end
	local shopId = part:GetAttribute("MealShop")
	local shop = shopId and Meals.Shops[shopId]
	if not shop then return end
	stalls[part] = shopId
	local prompt = part:FindFirstChild("MealPrompt")
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = "MealPrompt"
		created.ActionText = "Order"
		created.ObjectText = shop.name
		created.MaxActivationDistance = Meals.PromptDistance
		created.RequiresLineOfSight = false
		created.Parent = part
		prompt = created
	end
	Guard.OnTriggered(prompt, function(player)
		if PlayerData.Get(player) then send(player, "Open", { shop = shopId }) end
	end)
end

function MealService.Start()
	local existing = Remotes:FindFirstChild("Meals")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "Meals"
		created.Parent = Remotes
		remote = created
	end
	Guard.Remote(remote, "Meals", 3, 4, function(player, action, shopId, itemId)
		if action == "Buy" then buy(player, shopId, itemId) end
	end)
	-- the stalls: invisible OrderPoint parts in front of each counter (tools/builders/SmoothieCarts)
	if #CollectionService:GetTagged("MealShop") == 0 then
		warn("[MealService] no meal stalls (tag MealShop): build them with tools/builders/SmoothieCarts.luau")
	end
	for _, part in ipairs(CollectionService:GetTagged("MealShop")) do addStall(part) end
	CollectionService:GetInstanceAddedSignal("MealShop"):Connect(addStall)

	PlayerData.Loaded:Connect(function(player) restore(player) end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then restore(player) end
	end
	-- Studio: Workspace attribute TestMealRejoin = n acts out leaving and coming back n seconds later: the saved time left
	-- is taken, every boost and its timer is cleared (as if gone), and after n seconds restored from the save. The time left
	-- should be the same as before (paused while away).
	if game:GetService("RunService"):IsStudio() then
		Workspace:GetAttributeChangedSignal("TestMealRejoin"):Connect(function()
			local away = tonumber(Workspace:GetAttribute("TestMealRejoin"))
			if not away then return end
			Workspace:SetAttribute("TestMealRejoin", nil)
			for _, player in ipairs(Players:GetPlayers()) do
				saveTimes(player)
				restored[player] = nil -- (gone: nothing is saved until the restore)
				for _, item in ipairs(Meals.Items) do
					BoostService.SetPlayer(player, "Meal_" .. item.id, nil)
					player:SetAttribute("Meal_" .. item.id, nil)
				end
				task.delay(away, function() restore(player) end)
			end
		end)
	end
	-- (no save on leaving: BoostService has already dropped the player's boosts by then; the save every SaveEvery
	-- seconds holds the time left, at most a few seconds old)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
		restored[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Meals.SaveEvery)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(saveTimes, player)
				if not ok then warn("[MealService] save:", err) end
				-- a boost that ran out: clear its timer attribute
				for _, item in ipairs(Meals.Items) do
					if player:GetAttribute("Meal_" .. item.id) and secondsLeft(player, item.id) <= 0 then player:SetAttribute("Meal_" .. item.id, nil) end
				end
			end
		end
	end)
end

return MealService
