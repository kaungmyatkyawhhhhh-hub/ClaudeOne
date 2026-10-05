-- SkateService: a skateboard for the town hub. The player taps Skate (SkateClient); the server checks they're outdoors
-- in the hub (Config.Town) and not on a machine, welds a board under their feet and makes them faster. Normal movement
-- controls steer (thumbstick on phones), so there's nothing new to learn. Leaving the outdoor area, getting on a
-- machine or dying takes the board away. Everyone sees the board; the "Skating" attribute drives SkateClient.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Town = require(Config.Town)
local ActionService = require(script.Parent.ActionService)

local SkateService = {}

local SKATE = {
	WalkSpeed = 30,   -- normal is 16
	Lift = 0.45,      -- studs the board raises the character (board + wheels)
	DeckColor = Color3.fromHex("#2B2B2B"),
	GripColor = Color3.fromHex("#1A1A1C"),
	WheelColor = Color3.fromHex("#F4F1EA"),
	Check = 0.5,      -- seconds between "still allowed to skate?" checks
}

local riders = {} -- [player] = { board, walkSpeed, hipHeight }

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

local function makeBoard(root, hipHeight)
	local board = Instance.new("Model")
	board.Name = "Skateboard"
	-- the deck sits right under the feet of the lifted character (hipHeight includes the lift), wheels on the ground
	local feetY = -(root.Size.Y / 2 + hipHeight)
	local base = root.CFrame * CFrame.new(0, feetY - 0.06, 0) * CFrame.Angles(0, math.rad(90), 0) -- board lies along the walk
	local function piece(name, size, offset, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
		if shape then p.Shape = shape end
		p.CFrame = base * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, p
		weld.Parent = p
		p.Parent = board
		return p
	end
	piece("Deck", Vector3.new(3.2, 0.12, 0.95), CFrame.new(), SKATE.DeckColor, Enum.Material.Wood)
	piece("Grip", Vector3.new(3.1, 0.02, 0.9), CFrame.new(0, 0.07, 0), SKATE.GripColor, Enum.Material.Sand)
	for _, x in ipairs({ -1.05, 1.05 }) do
		piece("Truck", Vector3.new(0.18, 0.1, 0.8), CFrame.new(x, -0.11, 0), Color3.fromHex("#9EA2A8"), Enum.Material.Metal)
		for _, z in ipairs({ -0.42, 0.42 }) do
			piece("Wheel", Vector3.new(0.12, 0.26, 0.26), CFrame.new(x, -0.2, z) * CFrame.Angles(0, math.rad(90), 0), SKATE.WheelColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	return board
end

function SkateService.Stop(player)
	local rider = riders[player]
	if not rider then return end
	riders[player] = nil
	if rider.board then rider.board:Destroy() end
	local _, humanoid = parts(player)
	if humanoid then
		humanoid.WalkSpeed = rider.walkSpeed
		humanoid.HipHeight = rider.hipHeight
	end
	player:SetAttribute("Skating", nil)
end

local function start(player)
	if riders[player] or not allowed(player) then return end
	local character, humanoid, root = parts(player)
	local rider = { walkSpeed = humanoid.WalkSpeed, hipHeight = humanoid.HipHeight }
	humanoid.HipHeight = rider.hipHeight + SKATE.Lift
	local board = makeBoard(root, humanoid.HipHeight)
	humanoid.WalkSpeed = SKATE.WalkSpeed
	board.Parent = character
	rider.board = board
	riders[player] = rider
	player:SetAttribute("Skating", true)
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
