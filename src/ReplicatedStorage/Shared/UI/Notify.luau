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
local order = 0
local lastShown = {}
local held = nil -- { {text, color} } while the genetics screen is up

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
	local function follow()
		list.Position = UDim2.new(1, -12, 0, RightColumn.Bottom() + 8)
	end
	follow()
	RightColumn.Changed:Connect(follow)
end

local function show(text, color)
	ensure()

	local toasts = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then table.insert(toasts, child) end
	end
	table.sort(toasts, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 1, #toasts - MAX_VISIBLE + 1 do
		toasts[i]:Destroy()
	end

	order += 1
	local toast = Theme.New("Frame", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Parent = list,
	}, {
		Theme.Round("Button"),
		Theme.Stroke(),
		Theme.New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12) }),
		Theme.New("Frame", {
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.new(0, -8, 0, 6),
			BackgroundColor3 = color or Theme.Colors.Muted, -- a rarity color for titles, otherwise gray
			BorderSizePixel = 0,
		}, { Theme.Round("Segment") }),
		Theme.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Regular,
			TextSize = Theme.TextSize.Body,
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
