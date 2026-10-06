-- Small corner notifications that fade out. Notify.Show(text, color?, key?)
-- `key` throttles repeats of the same message. While the genetics screen is up (it owns the top right), toasts wait
-- and show when it closes.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local UIBus = require(script.Parent.UIBus)
local RightColumn = require(script.Parent.RightColumn)

local Notify = {}

local LIFETIME = 2.5
local MAX_VISIBLE = 4

local list
local reposition -- set in ensure()
local order = 0
local lastShown = {}
local held = nil -- { {text, color} } while the genetics screen is up
local training = false -- on a machine (phones show fewer notes then)

local function ensure()
	if list then return end
	local gui = Theme.ScreenGui({
		Name = "Notifications",
		DisplayOrder = 50,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- top right, stacked just under the right column (quest, shake button...)
	list = Theme.New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, 260, 0, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.New("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	-- the notifications use the same safe area as the right column, so they follow its bottom edge
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	-- phones: the right side under the column is the jump button and the bottom is the machine panel, so notes go to
	-- the top left, beside the menu button and left of the Growth Spurt bar (narrow, wrapped)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	local function follow()
		if Theme.IsCompact() then
			list.AnchorPoint = Vector2.new(0, 0)
			list.Position = UDim2.new(0, 66, 0, 8)
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		else
			list.AnchorPoint = Vector2.new(1, 0)
			list.Position = UDim2.new(1, -12, 0, RightColumn.Bottom() + 8)
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		end
	end
	follow()
	RightColumn.Changed:Connect(follow)
	Theme.OnCompactChanged(function() task.defer(follow) end)
	reposition = follow
	task.spawn(function()
		local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
		local machineState = remotes and remotes:WaitForChild("MachineState", 30)
		if machineState then machineState.OnClientEvent:Connect(function(state) training = state == "Enter" end) end
		Players.LocalPlayer.CharacterAdded:Connect(function() training = false end)
	end)
end

local function show(text, color)
	ensure()
	reposition()

	local toasts = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then table.insert(toasts, child) end
	end
	table.sort(toasts, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	local compact = Theme.IsCompact()
	local maxVisible = compact and (training and 1 or 2) or MAX_VISIBLE
	for i = 1, #toasts - maxVisible + 1 do
		toasts[i]:Destroy()
	end

	order += 1
	-- big screens: one line that grows to fit; phones: a fixed narrow width with the text wrapped
	local toast = Theme.New("Frame", {
		LayoutOrder = order,
		AutomaticSize = compact and Enum.AutomaticSize.Y or Enum.AutomaticSize.X,
		Size = compact and UDim2.new(0, 150, 0, 0) or UDim2.new(0, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Parent = list,
	}, {
		Theme.Round("Button"),
		Theme.Stroke(),
		Theme.New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, compact and 6 or 0), PaddingBottom = UDim.new(0, compact and 6 or 0) }),
		Theme.New("Frame", {
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.new(0, -8, 0, 6),
			BackgroundColor3 = color or Theme.Colors.Muted, -- a rarity color for titles, otherwise gray
			BorderSizePixel = 0,
		}, { Theme.Round("Segment") }),
		Theme.New("TextLabel", {
			AutomaticSize = compact and Enum.AutomaticSize.Y or Enum.AutomaticSize.X,
			Size = compact and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Regular,
			TextSize = compact and Theme.TextSize.Small or Theme.TextSize.Body,
			TextWrapped = compact,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.Colors.Text,
			Text = text,
		}),
	})
	Theme.AddDepth(toast, "Button")

	Theme.Fade(toast, true, 0.2)
	task.delay(LIFETIME, function()
		if toast.Parent then
			local tween = Theme.Fade(toast, false, 0.4)
			if tween then tween.Completed:Wait() end
			toast:Destroy()
		end
	end)
end

function Notify.Show(text, color, key)
	if key then
		if lastShown[key] and os.clock() - lastShown[key] < 2 then return end
		lastShown[key] = os.clock()
	end
	if held then
		table.insert(held, { text, color })
		return
	end
	show(text, color)
end

UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible then
		held = held or {}
		return
	end
	local waiting = held or {}
	held = nil
	for index, toast in ipairs(waiting) do
		task.delay(0.4 + (index - 1) * 0.3, show, toast[1], toast[2])
	end
end)

return Notify
