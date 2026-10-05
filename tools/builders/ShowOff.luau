-- ShowOff builder (run once in Studio; see tools/bake.md): the "Strongest lifters" leaderboard board above the front
-- desk (Workspace.LeaderboardWall: one column per muscle group named by group id, rows "Rank1".."Rank5" with "Name"
-- and "Level" labels, a crown on rank 1) and the statue pedestal in the entrance hall (Workspace.StatuePedestal with a
-- "Plaque" label). ShowOffService fills in the names and puts the statue on the pedestal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage.Shared.Config
local ShowOff = require(Config.ShowOff)
local Muscles = require(Config.Muscles)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Builder = {}

local function label(parent, props)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = Theme.Colors.Text
	text.FontFace = Theme.Fonts.Regular
	text.TextScaled = true -- sign on a wall (SurfaceGui): the only kind of screen text that may scale
	text.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in pairs(props) do text[key] = value end
	text.Parent = parent
	return text
end

-- A small crown from frames: a base and three points.
local function crown(parent)
	local holder = Instance.new("Frame")
	holder.Name = "Crown"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.09, 0.8)
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.fromScale(0, 0.5)
	holder.Parent = parent
	local gold = Theme.Bumper.Yellow.Fill
	local base = Instance.new("Frame")
	base.BackgroundColor3 = gold
	base.BorderSizePixel = 0
	base.Size = UDim2.fromScale(1, 0.32)
	base.Position = UDim2.fromScale(0, 0.68)
	base.Parent = holder
	for i, x in ipairs({ 0.15, 0.5, 0.85 }) do
		local point = Instance.new("Frame")
		point.BackgroundColor3 = gold
		point.BorderSizePixel = 0
		point.AnchorPoint = Vector2.new(0.5, 0.5)
		point.Size = UDim2.fromScale(0.3, 0.36)
		point.SizeConstraint = Enum.SizeConstraint.RelativeYY
		point.Position = UDim2.fromScale(x, i == 2 and 0.42 or 0.52)
		point.Rotation = 45
		point.Parent = holder
	end
	return holder
end

local function buildBoard(Workspace)
	local cfg = ShowOff.Leaderboard
	local old = Workspace:FindFirstChild("LeaderboardWall")
	if old then old:Destroy() end
	local board = Instance.new("Part")
	board.Name = "LeaderboardWall"
	board.Size = Vector3.new(cfg.BoardSize.X, cfg.BoardSize.Y, 0.2)
	board.CFrame = CFrame.lookAt(cfg.BoardCenter, cfg.BoardCenter + Vector3.new(0, 0, -1)) -- faces into the gym
	board.Color = Theme.Colors.Panel
	board.Material = Enum.Material.SmoothPlastic
	board.Anchored = true
	board.CanCollide = false
	board.Parent = Workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.Parent = board
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.03, 0), UDim.new(0.03, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.Parent = root
	label(root, { Text = "Strongest lifters", FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 0.13) })
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromScale(0, 0.18)
	grid.Size = UDim2.fromScale(1, 0.82)
	grid.Parent = root
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -12, 0.5, -10)
	layout.CellPadding = UDim2.fromOffset(12, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for index, group in ipairs(Muscles.Groups) do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.LayoutOrder = index
		column.Name = group.id
		column.Parent = grid
		label(column, { Text = group.name, FontFace = Theme.Fonts.SemiBold, TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 1 / 6) })
		for rank = 1, ShowOff.Leaderboard.Top do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromScale(0, rank / 6)
			row.Size = UDim2.fromScale(1, 1 / 6)
			row.Name = "Rank" .. rank
			row.Parent = column
			label(row, { Name = "Name", Text = rank .. "  -", Position = UDim2.fromScale(rank == 1 and 0.12 or 0, 0), Size = UDim2.fromScale(rank == 1 and 0.6 or 0.72, 1) })
			label(row, { Name = "Level", Text = "", Position = UDim2.fromScale(0.72, 0), Size = UDim2.fromScale(0.28, 1), TextXAlignment = Enum.TextXAlignment.Right })
			if rank == 1 then crown(row) end
		end
	end
end

local function buildPedestal(Workspace)
	local cfg = ShowOff.Statue
	local old = Workspace:FindFirstChild("StatuePedestal")
	if old then old:Destroy() end
	local pedestal = Instance.new("Part")
	pedestal.Name = "StatuePedestal"
	pedestal.Size = Vector3.new(3.4, 1.2, 3.4)
	pedestal.CFrame = CFrame.new(cfg.Spot + Vector3.new(0, 0.6, 0))
	pedestal.Color = Color3.fromHex("#2B2B2B")
	pedestal.Material = Enum.Material.Slate
	pedestal.Anchored = true
	pedestal.Parent = Workspace
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- faces +X, toward the middle of the hall
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = pedestal
	local text = label(gui, { Name = "Plaque", Text = "Strongest lifter", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Colors.Text })
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.25, 0), UDim.new(0.25, 0)
	pad.Parent = text
	return pedestal, text
end

function Builder.Build(Workspace)
	buildBoard(Workspace)
	buildPedestal(Workspace)
end

return Builder
