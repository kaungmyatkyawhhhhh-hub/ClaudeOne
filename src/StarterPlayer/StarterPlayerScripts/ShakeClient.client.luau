-- ShakeClient: the "Drink shake" button in the right column (shown while you have shakes), the shake boost
-- countdown, notes for buying/drinking shakes and petting the cat, and the gym cat's tail wag (local only).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stamina = require(Shared.Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Colors, Spacing = Theme.Colors, Theme.Spacing
local Horizontal = Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------
local button = Theme.Button("Secondary", {
	Name = "DrinkShake",
	Size = UDim2.fromOffset(RightColumn.Width, Theme.MinTouch + 4),
	Visible = false,
}, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left),
})
RightColumn.Add(button, 1)
local iconSlot = Theme.New("Frame", { LayoutOrder = 1, Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, Parent = button }, { Theme.Aspect(1, Enum.DominantAxis.Height) })
Icons.Shake(Colors.Text).Parent = iconSlot
local label = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -40, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = button })

local started = false

local function boostLeft()
	local ends = player:GetAttribute("ShakeEnds")
	if type(ends) ~= "number" then return 0 end
	return math.max(0, ends - Workspace:GetServerTimeNow())
end

local function refresh()
	if not started then return end
	local shakes = ClientData.Get().shakes or 0
	local left = boostLeft()
	button.Visible = shakes > 0 or left > 0
	if left > 0 then
		label.Text = string.format("Shake boost %ds", math.ceil(left)) .. (shakes > 0 and ("  ·  " .. shakes) or "")
		label.TextColor3 = Colors.Text
	else
		label.Text = shakes == 1 and "Drink shake" or ("Drink shake  ·  " .. shakes)
		label.TextColor3 = Colors.Text
	end
end

button.Activated:Connect(function()
	if (ClientData.Get().shakes or 0) <= 0 then return end
	Remotes.PlayerAction:FireServer("DrinkShake")
end)

ClientData.Changed:Connect(function(path)
	if path[1] == "shakes" then refresh() end
end)
player:GetAttributeChangedSignal("ShakeEnds"):Connect(refresh)

-- countdown
task.spawn(function()
	while true do
		task.wait(0.5)
		if started and boostLeft() > 0 then refresh() end
	end
end)

------------------------------------------------------------------------
-- Notes
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "ShakeResult" then
		Notify.Show(info.text, nil, "shake")
		if info.bought then Audio.PlayUI("Click") end
	elseif kind == "ShakeDrunk" then
		Notify.Show(tostring(info.flavor) .. " shake. Stamina full, +" .. math.floor((Stamina.Shake.GainsBoost - 1) * 100 + 0.5) .. "% gains.")
		Audio.PlayUI("LevelUp")
	elseif kind == "CatPet" then
		if (info.refill or 0) > 0 then
			Notify.Show(Stamina.Cat.Name .. " purrs. +" .. info.refill .. " stamina.", nil, "cat")
		else
			Notify.Show(Stamina.Cat.Name .. " is napping. Try again soon.", nil, "cat")
		end
	end
end)

-- Recovery stations (sauna, stretching area, cardio): one small note when you step in (BoostService sets the
-- player attribute Recovery to the station you stand in)
local lastStation = nil
player:GetAttributeChangedSignal("Recovery"):Connect(function()
	local station = player:GetAttribute("Recovery")
	if station and station ~= lastStation and Stamina.RecoveryNotes[station] then
		Notify.Show(Stamina.RecoveryNotes[station], nil, "recovery")
	end
	lastStation = station
end)

------------------------------------------------------------------------
-- The cat's tail wags (local, so it costs no network)
------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	for _, cat in ipairs(CollectionService:GetTagged("GymCat")) do
		local tail = cat:FindFirstChild("Tail")
		local base = tail and tail:GetAttribute("BaseCFrame")
		-- (only near the camera: nobody sees a tail wag from across the town)
		if base and camera and (camera.CFrame.Position - base.Position).Magnitude < 60 then
			local swing = math.sin(os.clock() * 2.2) * math.rad(18)
			-- pivot at the tail's root (the end touching the body)
			local root = base * CFrame.new(-tail.Size.X / 2, 0, 0)
			tail.CFrame = root * CFrame.Angles(0, swing, 0) * CFrame.new(tail.Size.X / 2, 0, 0) -- side to side
		end
	end
end)

------------------------------------------------------------------------
task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	refresh()
end)
