-- CosmeticService: the clothing store's gear (Config.Cosmetics). Buying (only at the store counter, coins checked
-- here), wearing (one item per slot, only owned items) and building the gear on characters from simple parts welded
-- to the body. Gear is rebuilt when a body part changes size (muscle growth, Growth Spurts). Cosmetic only.
-- Save data: cosmetics = { owned = { [itemId] = true }, equipped = { [slot] = itemId }, fitsRefunded = true? }.
-- While Config/Features.Wardrobe is false (owner, 13 Oct) the tops (slot "Fit") can't be bought or worn, and on join a
-- player who owns any gets them taken back with their coins refunded, once (fitsRefunded). The cause of the "broken
-- clothes" is fixed in MuscleRig / LimbStages / BodyStages; the switch stays off until the owner turns it on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Cosmetics = require(Config.Cosmetics)
local Town = require(Config.Town)
local Features = require(Config.Features)
local PlayerData = require(script.Parent.PlayerData)
local ActionService = require(script.Parent.ActionService)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local CosmeticService = {}

local STORE_REACH = 22 -- studs from the clothing store's middle where buying is allowed
local FOLDER = "Cosmetics"
local FIT_SHIRT = "GymArcFit" -- the classic Shirt a worn gym fit puts on the character

-- a top (gym fit) while the Wardrobe is switched off
local function fitBlocked(item)
	return item ~= nil and item.slot == "Fit" and not Features.Wardrobe
end

local function event(player, kind, info)
	if player.Parent then Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

local function stateOf(data)
	local state = data.cosmetics
	if type(state) ~= "table" then state = {} end
	state.owned = type(state.owned) == "table" and state.owned or {}
	state.equipped = type(state.equipped) == "table" and state.equipped or {}
	return state
end

------------------------------------------------------------------------
-- Building gear on a character
------------------------------------------------------------------------
local function piece(folder, bodyPart, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
	if shape then p.Shape = shape end
	p.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = bodyPart, p
	weld.Parent = p
	p.Parent = folder
	return p
end

-- A band around a box-shaped body part: a slightly bigger box, short in height. The inside is hidden by the body,
-- so only the band shows.
local function band(folder, bodyPart, name, height, y, extra, color, material)
	local s = bodyPart.Size
	return piece(folder, bodyPart, name, Vector3.new(s.X + extra, height, s.Z + extra), CFrame.new(0, y, 0), color, material)
end

local BUILD = {}
local tryOn = {} -- [player] = { id } (a PUMP SHOP try-on, prompt 19)
BUILD.Belt = function(folder, character, item)
	local waist = character:FindFirstChild("LowerTorso")
	if not waist then return end
	-- around the waist joint (the narrowest part of the body), as wide as the waist there
	local joint = waist:FindFirstChild("WaistRigAttachment")
	local y = joint and joint.Position.Y or 0
	local s = waist.Size
	local w, d, h = s.X * 0.9, s.Z * 0.9, math.min(0.36, s.Y * 0.3)
	piece(folder, waist, "Belt", Vector3.new(w, h, d), CFrame.new(0, y, 0), item.color, Enum.Material.Leather)
	piece(folder, waist, "Buckle", Vector3.new(w * 0.26, h * 0.8, 0.08), CFrame.new(0, y, -(d / 2 + 0.04)), Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
end
BUILD.Headband = function(folder, character, item)
	local head = character:FindFirstChild("Head")
	if not head then return end
	local s = head.Size
	-- a flat round band around the forehead (the head hides its middle)
	piece(folder, head, "Headband", Vector3.new(s.Y * 0.16, s.X * 1.06, s.Z * 1.06), CFrame.new(0, s.Y * 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)), item.color, Enum.Material.Fabric, Enum.PartType.Cylinder)
end
BUILD.Wraps = function(folder, character, item)
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			band(folder, arm, "Wrap", arm.Size.Y * 0.22, -arm.Size.Y * 0.36, 0.08, item.color, Enum.Material.Fabric)
		end
	end
end
BUILD.Shaker = function(folder, character, item)
	local waist = character:FindFirstChild("LowerTorso")
	if not waist then return end
	local s = waist.Size
	local side = CFrame.new(s.X / 2 + 0.24, -s.Y * 0.1, 0)
	piece(folder, waist, "Shaker", Vector3.new(0.85, 0.42, 0.42), side * CFrame.Angles(0, 0, math.rad(90)), item.color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(folder, waist, "ShakerCap", Vector3.new(0.16, 0.44, 0.44), side * CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("#2B2B2B"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

-- (prompt 19) PUMP SHOP gear and apparel
BUILD.Straps = function(folder, character, item)
	-- a strap band at the wrist and a tail hanging over the hand
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			band(folder, arm, "Strap", arm.Size.Y * 0.14, -arm.Size.Y * 0.44, 0.06, item.color, Enum.Material.Fabric)
			piece(folder, arm, "StrapTail", Vector3.new(0.12, arm.Size.Y * 0.32, arm.Size.Z * 0.5), CFrame.new(arm.Size.X / 2 + 0.06, -arm.Size.Y * 0.55, 0),
				item.color, Enum.Material.Fabric)
		end
	end
end
BUILD.Sleeves = function(folder, character, item)
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do
		local leg = character:FindFirstChild(name)
		if leg then band(folder, leg, "Sleeve", leg.Size.Y * 0.32, leg.Size.Y * 0.3, 0.1, item.color, Enum.Material.Fabric) end
	end
end
BUILD.Bag = function(folder, character, item)
	local torso = character:FindFirstChild("UpperTorso")
	if not torso then return end
	local s = torso.Size
	-- a duffel bag on the back with its strap across the chest
	piece(folder, torso, "Bag", Vector3.new(s.X * 0.75, s.Y * 0.38, 0.55), CFrame.new(0, -s.Y * 0.12, s.Z / 2 + 0.3), item.color, Enum.Material.Fabric)
	piece(folder, torso, "BagStrap", Vector3.new(0.18, s.Y * 1.25, s.Z + 0.12), CFrame.Angles(0, 0, math.rad(35)), item.color, Enum.Material.Fabric)
end

local function build(player)
	local character = player.Character
	local data = PlayerData.Get(player)
	if not character or not data then return end
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = character
	-- the gym fit: a classic Shirt on the character itself (the body swap strips clothing, so it is put back on every build)
	local fit = Cosmetics.ById[stateOf(data).equipped.Fit or ""]
	if fitBlocked(fit) then fit = nil end
	local shirt = character:FindFirstChild(FIT_SHIRT)
	if fit and fit.shirt and fit.shirt ~= "" then
		if not (shirt and shirt:IsA("Shirt")) then
			if shirt then shirt:Destroy() end
			shirt = Instance.new("Shirt")
			shirt.Name = FIT_SHIRT
		end
		shirt.ShirtTemplate = fit.shirt
		shirt.Parent = character
	elseif shirt then
		shirt:Destroy()
	end
	-- a PUMP SHOP try-on (prompt 19): that item instead of whatever is worn in its slot, for a few seconds
	local trying = tryOn[player] and Cosmetics.ById[tryOn[player].id]
	for slot, itemId in pairs(stateOf(data).equipped) do
		local item = Cosmetics.ById[itemId]
		local builder = item and BUILD[item.style]
		if builder and not (trying and trying.slot == slot) then pcall(builder, folder, character, item) end
	end
	if trying and BUILD[trying.style] then pcall(BUILD[trying.style], folder, character, trying) end
end

-- Rebuild (debounced) whenever a body part the gear sits on changes size.
local pending = {}
local function scheduleBuild(player)
	if pending[player] then return end
	pending[player] = true
	task.delay(0.3, function()
		pending[player] = nil
		if player.Parent then build(player) end
	end)
end

-- Once per player while the Wardrobe is off: every top they own is taken back and its price refunded.
local function refundFits(player)
	if Features.Wardrobe then return end
	local data = PlayerData.WaitFor(player)
	if not data then return end
	local state = stateOf(data)
	if state.fitsRefunded then return end
	local refund, count = 0, 0
	for itemId in pairs(state.owned) do
		local item = Cosmetics.ById[itemId]
		if item and item.slot == "Fit" then
			state.owned[itemId] = nil
			refund += item.price or 0
			count += 1
		end
	end
	state.equipped.Fit = nil
	state.fitsRefunded = true
	PlayerData.SetTable(player, "cosmetics", state)
	if refund > 0 then
		PlayerData.AddCoins(player, refund)
		event(player, "FitsRefunded", { coins = refund, count = count })
	end
	scheduleBuild(player)
end

local function watchCharacter(player, character)
	-- BodyService swaps the body parts (muscle body tiers): rebuild the gear on the new parts
	character:GetAttributeChangedSignal("BodyVersion"):Connect(function() scheduleBuild(player) end)
	for _, name in ipairs({ "LowerTorso", "Head", "LeftLowerArm", "RightLowerArm", "UpperTorso", "LeftLowerLeg", "RightLowerLeg" }) do
		local bodyPart = character:WaitForChild(name, 10)
		if bodyPart and bodyPart:IsA("BasePart") then
			bodyPart:GetPropertyChangedSignal("Size"):Connect(function() scheduleBuild(player) end)
		end
	end
	PlayerData.WaitFor(player)
	scheduleBuild(player)
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
local function nearStore(player)
	return Guard.Near(player, Town.ClothingStore.Center, STORE_REACH)
end

-- Skateboard decks and wheels live on the board, not the body: if the player is skating, rebuild the board.
local function refreshBoard(player, item)
	if item.slot == "Board" or item.slot == "Wheels" then
		require(script.Parent.SkateService).Refresh(player) -- (required here: SkateService loads after this module)
	end
end

local function buy(player, itemId)
	local item = type(itemId) == "string" and Cosmetics.ById[itemId]
	local data = PlayerData.Get(player)
	if not item or not data then return end
	if fitBlocked(item) then return end
	if not nearStore(player) then return end -- only at the store counter
	local state = stateOf(data)
	if state.owned[item.id] then return end
	if not PlayerData.SpendCoins(player, item.price) then
		event(player, "CosmeticBought", { failed = true, price = item.price })
		return
	end
	state.owned[item.id] = true
	state.equipped[item.slot] = item.id -- wear it right away
	PlayerData.SetTable(player, "cosmetics", state)
	build(player)
	refreshBoard(player, item)
	event(player, "CosmeticBought", { id = item.id })
end

-- Wear an owned item, or take it off if it's the one worn in its slot.
local function equip(player, itemId)
	local item = type(itemId) == "string" and Cosmetics.ById[itemId]
	local data = PlayerData.Get(player)
	if not item or not data then return end
	local state = stateOf(data)
	if not state.owned[item.id] then return end
	if fitBlocked(item) then return end
	state.equipped[item.slot] = state.equipped[item.slot] ~= item.id and item.id or nil
	PlayerData.SetTable(player, "cosmetics", state)
	build(player)
	refreshBoard(player, item)
end

-- PUMP SHOP (prompt 19): give an item (bought there; the shop checks the coins and the place), worn right away.
function CosmeticService.Grant(player, itemId, wear)
	local item = Cosmetics.ById[itemId]
	local data = PlayerData.Get(player)
	if not item or not data then return false end
	local state = stateOf(data)
	state.owned[item.id] = true
	if wear then state.equipped[item.slot] = item.id end
	PlayerData.SetTable(player, "cosmetics", state)
	build(player)
	return true
end

function CosmeticService.Owns(player, itemId): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and stateOf(data).owned[itemId] == true
end

-- A try-on: the item shows on the character for `seconds` (itemId nil = stop now).
function CosmeticService.TryOn(player, itemId, seconds)
	local mine = if itemId then { id = itemId } else nil
	tryOn[player] = mine
	build(player)
	if mine then
		task.delay(seconds or 10, function()
			if tryOn[player] == mine then
				tryOn[player] = nil
				if player.Parent then build(player) end
			end
		end)
	end
end

function CosmeticService.Start()
	ActionService.Register("BuyCosmetic", buy)
	ActionService.Register("EquipCosmetic", equip)
	local function hook(player)
		task.spawn(refundFits, player)
		player.CharacterAdded:Connect(function(character) watchCharacter(player, character) end)
		if player.Character then task.spawn(watchCharacter, player, player.Character) end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		tryOn[player] = nil
	end)
end

return CosmeticService
