-- Toasts (owner's UI redesign, mockup 01_main_hud): a small card at the bottom center (an icon tile, a title line and an
-- optional second line) that pops in and fades out. A newer toast pushes the older one up; at most two at once.
--   Notify.Show(text, color?, key?)            one line (color tints the icon tile; key throttles repeats of a message)
--   Notify.Toast(title, sub?, icon?, color?, key?)  title + a second line + an icon (Config/UI.Icons)
-- On a machine the toasts sit just above the machine panel. While the genetics screen is up they wait.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local Notify = {}

Notify.Lifetime = 2.8
Notify.MaxVisible = 2
Notify.Bottom = 16        -- mockup px from the bottom of the screen
Notify.TrainingBottom = 216 -- ...while on a machine (above the machine panel and its coach note)

local list
local order = 0
local lastShown = {}
local held = nil -- toasts waiting while the genetics screen is up
local training = false

local function ensure()
	if list then return end
	local gui = Theme.ScreenGui({ Name = "Notifications", DisplayOrder = 50, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = Kit.Root(gui)
	list = New("Frame", { Name = "List", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -Notify.Bottom),
		Size = UDim2.fromOffset(420, 200), BackgroundTransparency = 1, Parent = root }, {
		New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom }),
	})
	task.spawn(function()
		local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
		local machineState = remotes and remotes:WaitForChild("MachineState", 30)
		if machineState then
			machineState.OnClientEvent:Connect(function(state)
				training = state == "Enter"
				list.Position = UDim2.new(0.5, 0, 1, -(training and Notify.TrainingBottom or Notify.Bottom))
			end)
		end
		Players.LocalPlayer.CharacterAdded:Connect(function()
			training = false
			list.Position = UDim2.new(0.5, 0, 1, -Notify.Bottom)
		end)
	end)
end

local function show(title, sub, icon, color)
	ensure()
	local toasts = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") and child.Name == "Toast" then table.insert(toasts, child) end
	end
	table.sort(toasts, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 1, #toasts - Notify.MaxVisible + 1 do toasts[i]:Destroy() end

	order += 1
	local tint = color or Colors.Gold
	local toast = Theme.Panel({ Name = "Toast", LayoutOrder = order, Piece = "hud_box", Shadow = false, Size = UDim2.fromOffset(0, sub and 40 or 34),
		AutomaticSize = Enum.AutomaticSize.X, Parent = list }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14) }),
		Theme.List(Enum.FillDirection.Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(420, 80), Parent = toast })
	local iconSize = sub and 28 or 24
	local tile = Kit.IconTile(icon or "bell", Colors.Ink, iconSize, { LayoutOrder = 1, ImageColor3 = tint, Parent = toast })
	local iconImage = tile:FindFirstChild("Icon")
	if iconImage then iconImage.ImageColor3 = (tint == Colors.Gold or tint == Theme.Bumper.White.Fill or tint == Theme.Bumper.Yellow.Fill) and Colors.Ink or Colors.Text end
	local texts = New("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(0, sub and 32 or 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = toast },
		{ Theme.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	if sub then
		Kit.Text({ LayoutOrder = 1, Text = title, Font = "Title", TextSize = 14, Size = UDim2.fromOffset(0, 17), AutomaticSize = Enum.AutomaticSize.X, Parent = texts })
		Kit.Text({ LayoutOrder = 2, Text = sub, Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, 13), AutomaticSize = Enum.AutomaticSize.X, Parent = texts })
	else
		Kit.Text({ LayoutOrder = 1, Text = title, Font = "Body", TextSize = 11, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = texts })
	end
	local pop = New("UIScale", { Scale = 0.96, Parent = toast })
	Theme.Tween(pop, { Scale = 1 }, 0.18)
	Theme.Fade(toast, true, 0.18)
	task.delay(Notify.Lifetime, function()
		if toast.Parent then
			local tween = Theme.Fade(toast, false, 0.35)
			if tween then tween.Completed:Wait() end
			toast:Destroy()
		end
	end)
end

local function queue(title, sub, icon, color, key)
	if key then
		if lastShown[key] and os.clock() - lastShown[key] < 2 then return end
		lastShown[key] = os.clock()
	end
	if held then
		table.insert(held, { title, sub, icon, color })
		return
	end
	show(title, sub, icon, color)
end

function Notify.Show(text, color, key)
	queue(tostring(text), nil, nil, color, key)
end

function Notify.Toast(title, sub, icon, color, key)
	queue(tostring(title), sub, icon, color, key)
end

UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible then
		held = held or {}
		return
	end
	local waiting = held or {}
	held = nil
	for index, toast in ipairs(waiting) do
		task.delay(0.4 + (index - 1) * 0.3, show, toast[1], toast[2], toast[3], toast[4])
	end
end)

return Notify
