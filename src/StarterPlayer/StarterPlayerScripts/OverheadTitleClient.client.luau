-- OverheadTitleClient: local touches on the server-built TitleTag billboards.
-- Legendary titles get a slow shine every few seconds; the local player's own title is smaller and faded, and hidden on
-- the menu screen (its camera is close: the title hung huge across the top of the screen).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme"))
local UIBus = require(ReplicatedStorage.Shared.UI.UIBus)

local player = Players.LocalPlayer
local SHINE = { Every = 4, Time = 0.9, Light = Color3.fromRGB(255, 196, 196) }
local OWN = { Scale = 0.75, Transparency = 0.4 }
local onMachine = false -- (prompt 53: my own title hides while I'm on a machine)

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
		tag.Enabled = not UIBus.MenuOpen and not onMachine
		tag.Size = UDim2.fromScale(tag.Size.X.Scale * OWN.Scale, tag.Size.Y.Scale * OWN.Scale)
		label.TextTransparency = OWN.Transparency
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = 0.75 end
		if disc then
			disc.BackgroundTransparency = OWN.Transparency
			local rim = disc:FindFirstChildOfClass("UIStroke")
			if rim then rim.Transparency = OWN.Transparency end
		end
	end
end

-- (prompt 21) a small "ALTER 3" pill over the title of anyone with a Body Alter (the player's AlterNumber attribute,
-- BodyService); my own is smaller and faded like my title
-- (owner, 26 Oct) the background of the NEXT alter card (ProgressClient setAlterLook): dark graphite, the alter's popup
-- art (AlterThemes bg) under a dark shade from left to right (pillShade) with its colour wash (pillWash), the outline in the
-- alter's colour; the words in the ALTER button's chunky font (LuckiestGuy), white with a dark stroke.
local AlterThemes = require(ReplicatedStorage.Shared.Config.AlterThemes)
local BADGE = { Width = 1.7, Height = 0.4, Offset = 3.4, MaxDistance = 60 }
local BADGE_OUTLINE = Color3.fromHex("#120A0C")
local BADGE_BASE = Color3.fromHex("#1A181C") -- (the HUD cards' graphite)
local BADGE_GLOW = "rbxassetid://108461610476976" -- Config/UI.SoftGlow
local function updateBadge(other)
	local head = other.Character and other.Character:FindFirstChild("Head")
	if not head then return end
	local n = other:GetAttribute("AlterNumber")
	local badge = head:FindFirstChild("AlterBadge")
	if type(n) ~= "number" or n <= 0 then
		if badge then badge:Destroy() end
		return
	end
	if not badge then
		local mine = other == player
		local scale = if mine then OWN.Scale else 1
		badge = Theme.New("BillboardGui", { Name = "AlterBadge", Size = UDim2.fromScale(BADGE.Width * scale, BADGE.Height * scale),
			StudsOffset = Vector3.new(0, BADGE.Offset, 0), MaxDistance = BADGE.MaxDistance, LightInfluence = 0, Enabled = not (mine and UIBus.MenuOpen),
			Parent = head })
		local fade = if mine then OWN.Transparency else 0
		-- (owner, 26 Oct: "round up the edges or put vfx so it doesn't look unfinished") a fully round pill, a soft glow in the
		-- alter's colour behind it and a shine that sweeps across every few seconds
		-- (a CanvasGroup's round clip doesn't show on a 3D billboard: every layer is its own round Frame / image instead)
		badge.ClipsDescendants = false
		badge:SetAttribute("Fade", fade)
		local function round() return Theme.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) end
		Theme.New("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = BADGE_GLOW, ImageTransparency = 0.35 + fade * 0.5,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.4, 2.6), ZIndex = 1, Parent = badge })
		local pill = Theme.New("Frame", { Name = "Pill", BackgroundColor3 = BADGE_BASE, BackgroundTransparency = fade, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = badge }, { round() })
		Theme.New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = fade, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = badge }, { round() })
		Theme.New("Frame", { Name = "Wash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ZIndex = 4, Parent = badge }, { round() })
		Theme.New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = badge },
			{ round(), Theme.New("UIGradient", { Name = "Gradient", Transparency = NumberSequence.new(0.45, 0.75) }) })
		local peak = 1 - 0.5 * (1 - fade)
		local sweep = Theme.New("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ZIndex = 6, Parent = badge }, {
			round(),
			Theme.New("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, peak),
				NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		task.spawn(function()
			local gradient = sweep:FindFirstChildOfClass("UIGradient")
			while badge.Parent do
				gradient.Offset = Vector2.new(-1, 0)
				TweenService:Create(gradient, TweenInfo.new(SHINE.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) }):Play()
				task.wait(SHINE.Every + math.random())
			end
		end)
		-- (owner, 26 Oct: "remove the yellow border outline in the alter label") no coloured outline round the pill
		Theme.New("TextLabel", { Name = "Text", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.LuckiestGuy), TextColor3 = Color3.new(1, 1, 1), TextTransparency = fade, Text = "", ZIndex = 7, Parent = badge }, {
			Theme.New("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.1, 0) }),
			Theme.New("UIStroke", { Color = BADGE_OUTLINE, Thickness = 2, Transparency = fade }),
		})
	end
	local theme = AlterThemes.Get(n)
	local fade = badge:GetAttribute("Fade") or 0
	local function faded(t) return 1 - (1 - t) * (1 - fade) end
	if theme.bg then
		badge.Art.Image, badge.Art.BackgroundTransparency = theme.bg, 1
	else
		badge.Art.Image, badge.Art.BackgroundTransparency, badge.Art.BackgroundColor3 = "", fade, theme.accent:Lerp(theme.base, 0.4)
	end
	badge.Wash.BackgroundColor3, badge.Wash.BackgroundTransparency = theme.accent, faded(theme.pillWash or 1)
	local shade = theme.pillShade or { 0.45, 0.75 }
	badge.Shade.Gradient.Transparency = NumberSequence.new(faded(shade[1]), faded(shade[2]))
	badge.Glow.ImageColor3 = theme.accent
	badge.Text.Text = "ALTER " .. n
end

-- (prompt 54, 23 Oct) The lines over a head never overlap: a stack with a fixed gap, from just above the head (so a big
-- 7'0" head lifts it too), bottom to top: the ALTER pill, the title, the crew tag. Each line takes its own height (my own
-- are smaller); a hidden or missing line takes no room. Re-stacked whenever a line comes, goes, resizes or shows / hides.
local STACK = { Above = 1.8, Gap = 0.12, Order = { "AlterBadge", "TitleTag", "CrewTag" } }
local function restack(head: Instance)
	if not head:IsA("BasePart") then return end
	local y = head.Size.Y / 2 + STACK.Above
	for _, name in ipairs(STACK.Order) do
		local tag = head:FindFirstChild(name)
		if tag and tag:IsA("BillboardGui") and tag.Enabled then
			local h = tag.Size.Y.Scale
			tag.StudsOffset = Vector3.new(0, y + h / 2, 0)
			y += h + STACK.Gap
		end
	end
end
local function watchHead(head: Instance)
	if head:GetAttribute("StackWatch") then return end
	head:SetAttribute("StackWatch", true)
	local function hook(child: Instance)
		if child:IsA("BillboardGui") and table.find(STACK.Order, child.Name) then
			child:GetPropertyChangedSignal("Size"):Connect(function() restack(head) end)
			child:GetPropertyChangedSignal("Enabled"):Connect(function() restack(head) end)
			task.defer(restack, head)
		end
	end
	head.ChildAdded:Connect(hook)
	head.ChildRemoved:Connect(function(child)
		if table.find(STACK.Order, child.Name) then restack(head) end
	end)
	if head:IsA("BasePart") then head:GetPropertyChangedSignal("Size"):Connect(function() restack(head) end) end
	for _, child in ipairs(head:GetChildren()) do hook(child) end
	restack(head)
end

local function watchCharacter(character)
	character.DescendantAdded:Connect(styleTag)
	for _, d in ipairs(character:GetDescendants()) do styleTag(d) end
	task.spawn(function()
		local head = character:WaitForChild("Head", 10)
		if head then watchHead(head) end
	end)
	-- (the muscle body swaps the head part: watch the new one)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then watchHead(child) end
	end)
end
local function watchPlayer(other)
	other.CharacterAdded:Connect(function(character)
		watchCharacter(character)
		character:WaitForChild("Head", 10)
		updateBadge(other)
	end)
	if other.Character then
		watchCharacter(other.Character)
		task.spawn(updateBadge, other)
	end
	other:GetAttributeChangedSignal("AlterNumber"):Connect(function() updateBadge(other) end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end

-- Play: my title comes back. (prompt 53, 23 Oct) My own title and ALTER pill hide while I'm on a machine (they showed
-- through the bar and plates); everyone else still sees them.
local function applyOwn()
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then return end
	for _, tag in ipairs(head:GetChildren()) do
		if (tag.Name == "TitleTag" or tag.Name == "AlterBadge") and tag:IsA("BillboardGui") then tag.Enabled = not UIBus.MenuOpen and not onMachine end
	end
end
UIBus.MenuClosed.Event:Connect(applyOwn)
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MachineState").OnClientEvent:Connect(function(state)
	if state == "Enter" then onMachine = true elseif state == "Exit" then onMachine = false else return end
	applyOwn()
end)
player.CharacterAdded:Connect(function() onMachine = false end)
