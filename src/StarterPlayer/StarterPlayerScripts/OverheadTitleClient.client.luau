-- OverheadTitleClient: local touches on the server-built TitleTag billboards.
-- Legendary titles get a slow shine every few seconds; the local player's own title is smaller and faded.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme"))

local player = Players.LocalPlayer
local SHINE = { Every = 4, Time = 0.9, Light = Color3.fromRGB(255, 196, 196) }
local OWN = { Scale = 0.75, Transparency = 0.4 }

local function shine(tag, label)
	local base = Theme.Rarity.Legendary.Fill
	label.TextColor3 = Color3.new(1, 1, 1) -- the gradient carries the color
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.42, base),
		ColorSequenceKeypoint.new(0.5, SHINE.Light),
		ColorSequenceKeypoint.new(0.58, base),
		ColorSequenceKeypoint.new(1, base),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = label
	task.spawn(function()
		while tag.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			TweenService:Create(gradient, TweenInfo.new(SHINE.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(SHINE.Every)
		end
	end)
end

local function styleTag(tag)
	if tag.Name ~= "TitleTag" or not tag:IsA("BillboardGui") then return end
	local label = tag:WaitForChild("Title", 5)
	local disc = tag:WaitForChild("Disc", 5)
	if not label then return end
	if tag:GetAttribute("Rarity") == "Legendary" then shine(tag, label) end
	if tag:GetAttribute("Owner") == player.UserId then
		tag.Size = UDim2.fromScale(tag.Size.X.Scale * OWN.Scale, tag.Size.Y.Scale * OWN.Scale)
		label.TextTransparency = OWN.Transparency
		label:FindFirstChildOfClass("UIStroke").Transparency = 0.75
		if disc then
			disc.BackgroundTransparency = OWN.Transparency
			local rim = disc:FindFirstChildOfClass("UIStroke")
			if rim then rim.Transparency = OWN.Transparency end
		end
	end
end

local function watchCharacter(character)
	character.DescendantAdded:Connect(styleTag)
	for _, d in ipairs(character:GetDescendants()) do styleTag(d) end
end
local function watchPlayer(other)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then watchCharacter(other.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
