-- Stamina extras: the Endless Stamina countdown (every second, only for players in the game; PlayerData), buying Energy Shakes at the shake machine by the door, drinking them (full stamina + bonus gains
-- through BoostService), and Plates the gym cat by the front desk (pet = a tiny refill). All checks on the server.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stamina = require(ReplicatedStorage.Shared.Config.Stamina)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local BoostService = require(script.Parent.BoostService)
local ActionService = require(script.Parent.ActionService)
local ShowOffService = require(script.Parent.ShowOffService)

local Remotes = ReplicatedStorage.Remotes

local StaminaService = {}

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
	if PlayerData.ShakeCount(player) >= Stamina.Shake.MaxCarry then
		event(player, "ShakeResult", { text = "You have as many shakes as you can carry." })
		return
	end
	if not PlayerData.SpendCoins(player, Stamina.Shake.Cost) then
		event(player, "ShakeResult", { text = "Shakes cost " .. Stamina.Shake.Cost .. " coins." })
		return
	end
	PlayerData.AddShakes(player, 1)
	event(player, "ShakeResult", { text = "Bought a Protein Shake. It is in your inventory.", bought = true })
end

-- (prompt 14: the shakes are the inventory's Protein Shakes; ItemService calls this for "Shake", and the quick button's
-- "DrinkShake" action still lands here)
local function drink(player)
	local now = os.clock()
	if now - (lastDrink[player] or 0) < 1 then return false end
	lastDrink[player] = now
	if not PlayerData.Get(player) or PlayerData.ShakeCount(player) <= 0 then return false end
	PlayerData.AddShakes(player, -1)
	PlayerData.SetStamina(player, PlayerData.GetMaxStamina(player))
	BoostService.AddShake(player)
	local flavor = Stamina.Shake.Flavors[rng:NextInteger(1, #Stamina.Shake.Flavors)]
	event(player, "ShakeDrunk", { flavor = flavor })
	ShowOffService.PlayEmote(player, "Chug") -- everyone sees the chug (skipped while on a machine)
	return true
end
StaminaService.DrinkShake = drink

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
	Guard.OnTriggered(prompt, buy)
end

------------------------------------------------------------------------
-- Plates the gym cat (built in Studio: Workspace.NPCs.GymCat, made with tools/builders/GymCat.luau)
------------------------------------------------------------------------
local function wireCat()
	local npcs = Workspace:WaitForChild("NPCs", 10)
	local cat = npcs and npcs:WaitForChild("GymCat", 10)
	local prompt = cat and cat:FindFirstChild("PetPrompt", true)
	if not prompt then
		warn("[StaminaService] The gym cat is missing: build it in Studio with tools/builders/GymCat.luau")
		return
	end
	Guard.OnTriggered(prompt, function(player)
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
	task.spawn(wireCat)
	ActionService.Register("DrinkShake", drink)
	-- Endless Stamina: count the bought time down for everyone here (and keep their stamina full meanwhile)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local t = os.clock()
			local dt = t - last
			last = t
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(PlayerData.TickEndlessStamina, player, dt)
				if not ok then warn("[StaminaService] endless stamina:", err) end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPet[player], lastBuy[player], lastDrink[player] = nil, nil, nil
	end)
end

return StaminaService
