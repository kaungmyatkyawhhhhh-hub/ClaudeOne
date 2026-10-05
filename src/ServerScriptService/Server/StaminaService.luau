-- Stamina extras: buying Energy Shakes at the shake machine by the door, drinking them (full stamina + bonus gains
-- through BoostService), and Plates the gym cat by the front desk (pet = a tiny refill). All checks on the server.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stamina = require(ReplicatedStorage.Shared.Config.Stamina)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local ActionService = require(script.Parent.ActionService)
local ShowOffService = require(script.Parent.ShowOffService)

local Remotes = ReplicatedStorage.Remotes

local StaminaService = {}

local CAT_SPOT = CFrame.new(25.4, 0.1, -8.6) * CFrame.Angles(0, math.rad(-90), 0) -- in front of the cat bed, facing the room
local rng = Random.new()
local lastPet = {}  -- [player] = os.clock()
local lastBuy = {}  -- [player] = os.clock()
local lastDrink = {} -- [player] = os.clock()

local function event(player, kind, info)
	Remotes.PlayerEvent:FireClient(player, kind, info or {})
end

------------------------------------------------------------------------
-- Shakes
------------------------------------------------------------------------
local function buy(player)
	local now = os.clock()
	if now - (lastBuy[player] or 0) < 0.5 then return end
	lastBuy[player] = now
	local data = PlayerData.Get(player)
	if not data then return end
	if data.shakes >= Stamina.Shake.MaxCarry then
		event(player, "ShakeResult", { text = "Your bag is full of shakes." })
		return
	end
	if not PlayerData.SpendCoins(player, Stamina.Shake.Cost) then
		event(player, "ShakeResult", { text = "Shakes cost " .. Stamina.Shake.Cost .. " coins." })
		return
	end
	PlayerData.AddShakes(player, 1)
	event(player, "ShakeResult", { text = "Bought an Energy Shake.", bought = true })
end

local function drink(player)
	local now = os.clock()
	if now - (lastDrink[player] or 0) < 1 then return end
	lastDrink[player] = now
	local data = PlayerData.Get(player)
	if not data or data.shakes <= 0 then return end
	PlayerData.AddShakes(player, -1)
	PlayerData.SetStamina(player, PlayerData.GetMaxStamina(player))
	BoostService.AddShake(player)
	local flavor = Stamina.Shake.Flavors[rng:NextInteger(1, #Stamina.Shake.Flavors)]
	event(player, "ShakeDrunk", { flavor = flavor })
	ShowOffService.PlayEmote(player, "Chug") -- everyone sees the chug (skipped while on a machine)
end

-- A free shake (tutorial gift, quest rewards use PlayerData.AddShakes directly).
function StaminaService.GiveShake(player, amount)
	PlayerData.AddShakes(player, amount or 1)
end

local function setupShakeMachine()
	local machine = Workspace:FindFirstChild("ShakeMachine", true)
	if not machine then
		warn("[StaminaService] No ShakeMachine in Workspace; shakes can only be earned")
		return
	end
	-- the prompt goes on the machine's biggest part
	local holder, biggest = nil, 0
	for _, part in ipairs(machine:GetDescendants()) do
		if part:IsA("BasePart") and part.Size.Magnitude > biggest then holder, biggest = part, part.Size.Magnitude end
	end
	if machine:IsA("BasePart") then holder = machine end
	if not holder then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyShake"
	prompt.ActionText = "Buy shake"
	prompt.ObjectText = Stamina.Shake.Cost .. " coins"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	prompt.Triggered:Connect(buy)
end

------------------------------------------------------------------------
-- Plates the gym cat (built from simple parts; the client wags the tail)
------------------------------------------------------------------------
local function part(model, name, size, offset, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.CFrame = CAT_SPOT * offset
	p.Parent = model
	return p
end

local function buildCat()
	local model = Instance.new("Model")
	model.Name = "GymCat"
	local fur = Color3.fromHex("#3A3A3E")
	local light = Color3.fromHex("#D9D4CB")
	local body = part(model, "Body", Vector3.new(1.5, 0.7, 0.8), CFrame.new(0, 0.75, 0), fur)
	part(model, "Chest", Vector3.new(0.45, 0.55, 0.62), CFrame.new(-0.62, 0.72, 0), light)
	local head = part(model, "Head", Vector3.new(0.6, 0.55, 0.6), CFrame.new(-0.95, 1.2, 0), fur)
	part(model, "Muzzle", Vector3.new(0.2, 0.22, 0.32), CFrame.new(-1.27, 1.12, 0), light)
	part(model, "EarL", Vector3.new(0.12, 0.26, 0.2), CFrame.new(-0.95, 1.55, 0.18) * CFrame.Angles(0, 0, math.rad(10)), fur)
	part(model, "EarR", Vector3.new(0.12, 0.26, 0.2), CFrame.new(-0.95, 1.55, -0.18) * CFrame.Angles(0, 0, math.rad(10)), fur)
	part(model, "EyeL", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.26, 1.28, 0.14), Color3.fromHex("#E8C21C"))
	part(model, "EyeR", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.26, 1.28, -0.14), Color3.fromHex("#E8C21C"))
	for i, x in ipairs({ -0.5, 0.5 }) do
		for j, z in ipairs({ 0.25, -0.25 }) do
			part(model, "Leg" .. i .. j, Vector3.new(0.18, 0.45, 0.18), CFrame.new(x, 0.22, z), fur)
		end
	end
	local tail = part(model, "Tail", Vector3.new(0.9, 0.14, 0.14), CFrame.new(1.15, 1.05, 0) * CFrame.Angles(0, 0, math.rad(35)), fur)
	tail:SetAttribute("BaseCFrame", tail.CFrame)
	model.PrimaryPart = body
	body.CanCollide = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = Stamina.Cat.Name
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = head
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- Workspace streaming: always on every client
	CollectionService:AddTag(model, "GymCat")
	local npcs = Workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	npcs.Name = "NPCs"
	npcs.Parent = Workspace
	model.Parent = npcs

	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		local data = PlayerData.Get(player)
		if not data then return end
		if now - (lastPet[player] or -math.huge) < Stamina.Cat.Cooldown then
			event(player, "CatPet", { refill = 0 })
			return
		end
		lastPet[player] = now
		PlayerData.SetStamina(player, data.stamina + Stamina.Cat.Refill)
		event(player, "CatPet", { refill = Stamina.Cat.Refill })
	end)
end

function StaminaService.Start()
	setupShakeMachine()
	buildCat()
	ActionService.Register("DrinkShake", drink)
	Players.PlayerRemoving:Connect(function(player)
		lastPet[player], lastBuy[player], lastDrink[player] = nil, nil, nil
	end)
end

return StaminaService
