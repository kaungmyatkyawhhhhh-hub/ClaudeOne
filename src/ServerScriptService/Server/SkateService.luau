-- SkateService: a skateboard for the town hub. The player taps Skate (SkateClient); the server checks they're outdoors
-- in the hub (Config.Town) and not on a machine and puts a board under their feet. SkateClient does the riding (push,
-- carve, coast, brake, ollie) with the normal movement controls (thumbstick on phones). Leaving the outdoor area, getting on a
-- machine or dying takes the board away. Everyone sees the board; the "Skating" attribute drives SkateClient.
-- Upgrades come from the clothing store (Config.Cosmetics): a deck design (slot Board) and faster wheels (slot Wheels,
-- item.speed); changing them while skating rebuilds the board (SkateService.Refresh, called by CosmeticService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Town = require(Config.Town)
local Cosmetics = require(Config.Cosmetics)
local ActionService = require(script.Parent.ActionService)
local PlayerData = require(script.Parent.PlayerData)

local SkateService = {}

local SKATE = {
	WalkSpeed = 32,   -- top speed without upgraded wheels (walking is 16); SkateClient drives the board
	Lift = 0.4,       -- studs the board raises the character (wheels + deck: the deck top)
	DeckColor = Color3.fromHex("#C99A62"), -- natural maple (the grip on top is black)
	GripColor = Color3.fromHex("#1A1A1C"),
	WheelColor = Color3.fromHex("#F4F1EA"),
	Check = 0.5,      -- seconds between "still allowed to skate?" checks
}

local riders = {} -- [player] = { board, hipHeight }
local TRUCK = Color3.fromHex("#B4B8BE")

local function parts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function allowed(player)
	local _, humanoid, root = parts(player)
	if not humanoid or not root or humanoid.Health <= 0 then return false end
	if root.Anchored or humanoid.PlatformStand or humanoid.Sit then return false end -- on a machine or seated
	return Town.IsOutdoors(root.Position)
end

-- The deck and wheels the player uses (Config.Cosmetics slots Board and Wheels, bought at the clothing store):
-- { deck, stripe, wheel, speed }. Without them: the plain black board at the normal speed.
local function lookOf(player)
	local data = PlayerData.Get(player)
	local equipped = data and data.cosmetics and data.cosmetics.equipped or {}
	local owned = data and data.cosmetics and data.cosmetics.owned or {}
	local function item(slot)
		local id = equipped[slot]
		local found = id and owned[id] and Cosmetics.ById[id]
		return found and found.slot == slot and found or nil
	end
	local deck, wheels = item("Board"), item("Wheels")
	return {
		deck = deck and deck.color or SKATE.DeckColor,
		stripe = deck and deck.color2 or nil,
		wheel = wheels and wheels.color or SKATE.WheelColor,
		speed = wheels and wheels.speed or SKATE.WalkSpeed,
	}
end

-- The board: a deck with kicked-up nose and tail, grip tape, two trucks (baseplate, hanger, axle) and four wheels. The deck
-- hangs on a Motor6D ("BoardJoint", root -> deck) so every client can tilt it (carving, ollies) without the server; the other
-- pieces are welded to the deck. Deck local axes: +X = nose (the way the rider rolls), +Y up.
local function makeBoard(root, hipHeight, look)
	local board = Instance.new("Model")
	board.Name = "Skateboard"
	-- hipHeight includes the lift, so this is the ground; the wheels stand on it and the deck top ends up right under the
	-- lifted feet (deck centre 0.33 up: wheel radius 0.13 + axle 0.2)
	local groundY = -(root.Size.Y / 2 + hipHeight)
	local deckCFrame = root.CFrame * CFrame.new(0, groundY + 0.33, 0) * CFrame.Angles(0, math.rad(90), 0)
	local deck
	local function piece(name, size, offset, color, material, shape, shadow)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CastShadow = shadow == true
		if shape then p.Shape = shape end
		p.CFrame = deckCFrame * offset
		if deck then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = deck, p
			weld.Parent = p
		end
		p.Parent = board
		return p
	end
	local wood, metal, grip = Enum.Material.Wood, Enum.Material.Metal, Enum.Material.Sand
	deck = piece("Deck", Vector3.new(2.5, 0.1, 0.95), CFrame.new(), look.deck, wood, nil, true)
	piece("Grip", Vector3.new(2.46, 0.02, 0.9), CFrame.new(0, 0.06, 0), SKATE.GripColor, grip)
	if look.stripe then
		piece("Stripe", Vector3.new(2.3, 0.02, 0.16), CFrame.new(0, 0.075, 0), look.stripe, Enum.Material.SmoothPlastic)
	end
	-- kicked-up nose and tail (each a tilted deck piece with grip, rounded end)
	for _, dir in ipairs({ 1, -1 }) do
		local hinge = CFrame.new(dir * 1.25, 0, 0) * CFrame.Angles(0, 0, dir * math.rad(17))
		piece("Kick", Vector3.new(0.5, 0.1, 0.95), hinge * CFrame.new(dir * 0.25, 0, 0), look.deck, wood, nil, true)
		piece("KickGrip", Vector3.new(0.46, 0.02, 0.9), hinge * CFrame.new(dir * 0.25, 0.06, 0), SKATE.GripColor, grip)
		piece("KickEnd", Vector3.new(0.1, 0.95, 0.95), hinge * CFrame.new(dir * 0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), look.deck, wood, Enum.PartType.Cylinder)
	end
	-- trucks and wheels
	for _, x in ipairs({ -0.95, 0.95 }) do
		piece("Baseplate", Vector3.new(0.34, 0.05, 0.3), CFrame.new(x, -0.075, 0), TRUCK, metal)
		piece("Hanger", Vector3.new(0.16, 0.12, 0.62), CFrame.new(x, -0.16, 0), TRUCK, metal)
		piece("Axle", Vector3.new(0.9, 0.05, 0.05), CFrame.new(x, -0.2, 0) * CFrame.Angles(0, math.rad(90), 0), TRUCK, metal, Enum.PartType.Cylinder)
		for _, z in ipairs({ -0.38, 0.38 }) do
			piece("Wheel", Vector3.new(0.14, 0.26, 0.26), CFrame.new(x, -0.2, z) * CFrame.Angles(0, math.rad(90), 0), look.wheel, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			piece("Bearing", Vector3.new(0.15, 0.1, 0.1), CFrame.new(x, -0.2, z) * CFrame.Angles(0, math.rad(90), 0), TRUCK, metal, Enum.PartType.Cylinder)
		end
	end
	local joint = Instance.new("Motor6D")
	joint.Name = "BoardJoint"
	joint.Part0, joint.Part1 = root, deck
	joint.C0 = root.CFrame:ToObjectSpace(deckCFrame)
	joint.Parent = deck
	return board
end

function SkateService.Stop(player)
	local rider = riders[player]
	if not rider then return end
	riders[player] = nil
	if rider.board then rider.board:Destroy() end
	local _, humanoid = parts(player)
	if humanoid then humanoid.HipHeight = rider.hipHeight end
	-- (SkateClient gives the player their walk speed and turning back)
	player:SetAttribute("SkateSpeed", nil)
	player:SetAttribute("Skating", nil)
end

local function start(player)
	if riders[player] or not allowed(player) then return end
	-- out of a held pose first (it freezes walking and owns the joints)
	local poseOk, ShowOffService = pcall(require, script.Parent.ShowOffService)
	if poseOk and ShowOffService.ReleasePose then ShowOffService.ReleasePose(player) end
	local character, humanoid, root = parts(player)
	local rider = { hipHeight = humanoid.HipHeight }
	humanoid.HipHeight = rider.hipHeight + SKATE.Lift
	local look = lookOf(player)
	local board = makeBoard(root, humanoid.HipHeight, look)
	board.Parent = character
	rider.board = board
	riders[player] = rider
	player:SetAttribute("SkateSpeed", look.speed) -- the top speed; SkateClient drives the board (the server only checks the rules)
	player:SetAttribute("Skating", true)
end

-- The player changed deck or wheels (CosmeticService): rebuild the board if they're on it.
function SkateService.Refresh(player)
	local rider = riders[player]
	local character, humanoid, root = parts(player)
	if not rider or not humanoid or not root then return end
	if rider.board then rider.board:Destroy() end
	local look = lookOf(player)
	rider.board = makeBoard(root, humanoid.HipHeight, look)
	rider.board.Parent = character
	player:SetAttribute("SkateSpeed", look.speed) -- the top speed; SkateClient drives the board (the server only checks the rules)
end

function SkateService.Start()
	-- PlayerAction "Skate" (true = on, false = off)
	ActionService.Register("Skate", function(player, on)
		if on == true then start(player) elseif on == false then SkateService.Stop(player) end
	end)
	Players.PlayerRemoving:Connect(function(player) riders[player] = nil end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function() riders[player] = nil player:SetAttribute("Skating", nil) end)
	end)
	task.spawn(function()
		while true do
			task.wait(SKATE.Check)
			for player in pairs(riders) do
				if not allowed(player) then SkateService.Stop(player) end
			end
		end
	end)
end

return SkateService
