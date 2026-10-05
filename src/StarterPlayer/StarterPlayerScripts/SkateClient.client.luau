-- SkateClient: the Skate button in the right column, shown only outdoors in the town hub (Config.Town). Tapping it
-- asks the server for the board (SkateService validates and welds it); steering is the normal movement controls, so
-- phones use the usual thumbstick. While skating the character leans a little into turns.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared.Config.Town)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Horizontal = Enum.FillDirection.Horizontal

local button = Theme.Button("Secondary", {
	Name = "Skate",
	Size = UDim2.fromOffset(RightColumn.Width, Theme.MinTouch + 4),
	Visible = false,
}, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left),
})
RightColumn.Add(button, 4)
local label = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = button })

local function skating()
	return player:GetAttribute("Skating") == true
end

local function refresh()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local outdoors = root ~= nil and not UIBus.MenuOpen and Town.IsOutdoors(root.Position)
	button.Visible = outdoors or skating()
	label.Text = skating() and "Stop skating" or "Skate"
end

button.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("Skate", not skating())
	Audio.PlayUI("Click")
end)
player:GetAttributeChangedSignal("Skating"):Connect(refresh)

task.spawn(function()
	while true do
		task.wait(0.5)
		refresh()
	end
end)

-- a small lean into turns (local only, on the root joint's Transform after animations)
local lean = 0
RunService.Stepped:Connect(function(_, dt)
	if not skating() then
		lean = 0
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local lower = character and character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root")
	if not root or not joint or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local turn = root.AssemblyAngularVelocity.Y
	lean += (math.clamp(-turn * 0.06, -0.25, 0.25) - lean) * math.min(1, dt * 8)
	joint.Transform = joint.Transform * CFrame.Angles(0, 0, lean)
end)
