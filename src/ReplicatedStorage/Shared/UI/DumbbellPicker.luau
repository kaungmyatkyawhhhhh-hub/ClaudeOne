-- DumbbellPicker (prompt 16, 21 Oct): the exercise picker of a dumbbell spot (a Kit.Modal: "DUMBBELLS"). A card grid,
-- 3 per row, scrolling: a dumbbell icon, the exercise name and the muscles it trains (names only). The last exercise you
-- picked (settings.dumbbellLast) comes first with a gold LAST tag; while changing exercise on a spot the one you're
-- doing has the gold border (CURRENT). Tapping a card picks it and closes the window.
--   DumbbellPicker.Open(currentId?, onSpot, onPick(id))   onSpot: changing exercise on your spot (shows CURRENT)
--   DumbbellPicker.Close()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Machines = require(Shared.Config.Machines)
local Muscles = require(Shared.Config.Muscles)
local ClientData = require(Shared.ClientData)
local Audio = require(Shared.Audio)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local New, Colors = Theme.New, Theme.Colors

local DumbbellPicker = {}

local W, H = 600, 250
local CARD_H = 66
local modal, list = nil, nil
local onPicked = nil

local function build()
	modal = Kit.Modal({ name = "DumbbellPicker", title = "Dumbbells", icon = "dumbbell", width = W, height = H, displayOrder = 27 })
	list = New("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
		New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, CARD_H), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
	})
end

-- "Biceps · Forearms": the muscles by share, names only
local function muscleLine(exercise): string
	local names = {}
	for _, entry in ipairs(exercise.muscles) do
		local muscle = Muscles.ById[entry.id]
		if muscle then table.insert(names, muscle.name) end
	end
	return table.concat(names, " · ")
end

local function fill(currentId: string?, onSpot: boolean)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local settings = ClientData.Get().settings or {}
	local last = settings.dumbbellLast
	for index, exercise in ipairs(Machines.Dumbbells) do
		local isCurrent = onSpot and exercise.id == currentId
		local isLast = exercise.id == last
		local card = Kit.Card({ Name = exercise.id, LayoutOrder = if isLast then 0 else index, Clickable = true,
			Piece = if isCurrent then "card_gold" else "card", Parent = list }, {})
		Kit.IconTile("dumbbell", Color3.fromHex("#C98A12"), 40, { Name = "Tile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = card })
		-- (a tagged card keeps the top-right corner free for its tag: the name wraps instead)
		local name = Kit.Text({ Name = "Name", Text = exercise.name, Font = "Title", TextSize = 14, Position = UDim2.fromOffset(56, 8),
			Size = UDim2.new(1, if isCurrent or isLast then -128 else -62, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		Kit.Fit(name, 14, 10, 2)
		local muscles = Kit.Text({ Name = "Muscles", Text = muscleLine(exercise), Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 56, 1, -7), Size = UDim2.new(1, -62, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		Kit.Fit(muscles, 11, 8)
		if isCurrent or isLast then
			Kit.Tag(if isCurrent then "CURRENT" else "LAST", Colors.Gold, { Name = "Tag", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5),
				ZIndex = 3, Parent = card })
		end
		card.Activated:Connect(function()
			local picked = onPicked
			DumbbellPicker.Close()
			if isCurrent then return end
			Audio.PlayUI("Click")
			if picked then picked(exercise.id) end
		end)
	end
	list.CanvasPosition = Vector2.zero
end

function DumbbellPicker.Open(currentId: string?, onSpot: boolean, onPick: (string) -> ())
	if not modal then build() end
	onPicked = onPick
	modal.setTitle(if onSpot then "Change exercise" else "Dumbbells")
	fill(currentId, onSpot)
	modal.open()
	Audio.PlayUI("Whoosh")
end

function DumbbellPicker.Close()
	onPicked = nil
	if modal and modal.isOpen() then modal.close() end
end

return DumbbellPicker
