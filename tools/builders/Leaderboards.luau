-- Leaderboards builder (run once in Studio; see tools/bake.md; owner's feature run, task 4): a board wall with the six
-- boards of Config.Leaderboards, in three places, each in its own feature folder:
--   Workspace.Gym.StarterGym.Feature_Leaderboards   on the front wall, left of the door to the hall, above the windows
--   Workspace.ProGym.Feature_Leaderboards           on the front wall's band above the glass
--   Workspace.Town.Feature_Leaderboards             freestanding at the north edge of the plaza, facing the street
-- Each board is a part "Panel" tagged "LeaderboardPanel" (attribute Board = the board id) with a SurfaceGui "Board":
-- Title, Sub, Row1..Row10 (Rank, Head (ImageLabel), Name, Value) and You. LeaderboardClient fills them.
-- Requires Kit next to it. Usage: require(game.ServerStorage._Builders.Leaderboards).Build()
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Leaderboards = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Kit = require(script.Parent.Kit)

local M = Enum.Material
local hex = Kit.hex

local Builder = {}

local PANEL = Vector2.new(3.2, 5) -- studs (the starter wall fits between the windows' tops, 8.35, and the cornice, 15.7)
local GAP = 0.35
local MARGIN = 0.4
local HEADER = 1
local CHARCOAL, BACKING, STEEL, SCREEN = hex("#1E1E22"), hex("#141416"), hex("#C9CCD2"), hex("#0E0E10")

local function label(parent, name, props)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.TextColor3 = Theme.Colors.Text
	text.FontFace = Theme.Fonts.Regular
	text.TextScaled = true -- world board (SurfaceGui): the only kind of text that may scale
	for key, value in pairs(props) do text[key] = value end
	text.Parent = parent
	return text
end

-- One board's screen: title, subtitle, 10 rows, "your rank".
local function screen(panel, board)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 70
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.035, 0), UDim.new(0.03, 0)
	pad.Parent = gui
	label(gui, "Title", { Text = string.upper(board.title), FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 0.1) })
	label(gui, "Sub", { Text = board.sub or "", TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 0.055), Position = UDim2.fromScale(0, 0.105) })
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Theme.Colors.Text
	rule.BackgroundTransparency = 0.8
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.Position = UDim2.fromScale(0, 0.175)
	rule.Parent = gui
	for i = 1, Leaderboards.Top do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundTransparency = i % 2 == 0 and 0.94 or 1
		row.BackgroundColor3 = Theme.Colors.Text
		row.BorderSizePixel = 0
		row.Size = UDim2.fromScale(1, 0.068)
		row.Position = UDim2.fromScale(0, 0.19 + (i - 1) * 0.07)
		row.Parent = gui
		label(row, "Rank", { Text = tostring(i), FontFace = Theme.Fonts.SemiBold, TextColor3 = i == 1 and Theme.Colors.Gold or Theme.Colors.Muted,
			Size = UDim2.fromScale(0.1, 0.8), Position = UDim2.fromScale(0, 0.1) })
		local head = Instance.new("ImageLabel")
		head.Name = "Head"
		head.BackgroundColor3 = CHARCOAL
		head.BackgroundTransparency = 0
		head.BorderSizePixel = 0
		head.Image = ""
		head.Size = UDim2.fromScale(0.09, 0.9)
		head.Position = UDim2.fromScale(0.115, 0.05)
		head.Parent = row
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = head
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = head
		label(row, "Name", { Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.47, 0.72), Position = UDim2.fromScale(0.235, 0.14) })
		label(row, "Value", { Text = "", FontFace = Theme.Fonts.SemiBold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.29, 0.72), Position = UDim2.fromScale(0.71, 0.14) })
	end
	label(gui, "You", { Text = "", TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 0.06), Position = UDim2.fromScale(0, 0.915) })
	return gui
end

-- One board wall. `base` = the centre of the panels' bottom edge, LookVector = toward the people reading it.
function Builder.Unit(parent, name, base, freestanding)
	local unit = Kit.fresh(parent, "Model", name)
	local count = #Leaderboards.Boards
	local width = count * PANEL.X + (count - 1) * GAP + MARGIN * 2
	local height = PANEL.Y + HEADER + MARGIN * 2
	local depth = 0.25
	-- the backing (flush on a wall, or on posts when freestanding), a steel trim top and bottom
	local centre = base * CFrame.new(0, height / 2 - MARGIN, depth / 2)
	local back = Kit.part(unit, "Backing", Vector3.new(width, height, depth), centre, BACKING, M.SmoothPlastic)
	back.CastShadow = freestanding == true
	Kit.prop(unit, "TrimTop", Vector3.new(width + 0.1, 0.12, depth + 0.12), centre * CFrame.new(0, height / 2, 0), STEEL, M.Metal)
	Kit.prop(unit, "TrimBottom", Vector3.new(width + 0.1, 0.12, depth + 0.12), centre * CFrame.new(0, -height / 2, 0), STEEL, M.Metal)
	-- header: "LEADERBOARDS" with a thin warm light strip under it
	local headerCf = base * CFrame.new(0, PANEL.Y + HEADER / 2 + 0.05, -0.02)
	local header = Kit.prop(unit, "Header", Vector3.new(width - MARGIN * 2, HEADER - 0.2, 0.05), headerCf, BACKING, M.SmoothPlastic)
	header.CFrame = CFrame.lookAt(headerCf.Position, headerCf.Position + base.LookVector)
	local headGui = Instance.new("SurfaceGui")
	headGui.Face = Enum.NormalId.Front
	headGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	headGui.PixelsPerStud = 60
	headGui.LightInfluence = 0
	headGui.MaxDistance = 120
	headGui.Parent = header
	label(headGui, "Text", { Text = "LEADERBOARDS", FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1) })
	local strip = Kit.prop(unit, "LightStrip", Vector3.new(width - MARGIN * 2, 0.06, 0.06), base * CFrame.new(0, PANEL.Y + 0.17, -0.08), hex("#FFE7C2"), M.Neon)
	strip.Transparency = 0.2
	-- the six screens, each in a thin frame
	for index, board in ipairs(Leaderboards.Boards) do
		-- (left to right as you read it: the unit's +X is the reader's left)
		local x = width / 2 - MARGIN - PANEL.X / 2 - (index - 1) * (PANEL.X + GAP)
		local at = base * CFrame.new(x, PANEL.Y / 2, -0.06)
		local frame = Kit.prop(unit, "PanelFrame", Vector3.new(PANEL.X + 0.14, PANEL.Y + 0.14, 0.08), at * CFrame.new(0, 0, 0.03), CHARCOAL, M.Metal)
		frame.CastShadow = false
		local panel = Kit.prop(unit, "Panel", Vector3.new(PANEL.X, PANEL.Y, 0.05), at, SCREEN, M.SmoothPlastic)
		panel.CFrame = CFrame.lookAt(at.Position, at.Position + base.LookVector)
		panel:SetAttribute("Board", board.id)
		CollectionService:AddTag(panel, "LeaderboardPanel")
		screen(panel, board)
	end
	if freestanding then
		-- posts with feet and a cap, and a plain back with the game name
		local floor = base * CFrame.new(0, -base.Position.Y, 0)
		for _, x in ipairs({ -width / 2 + 1, 0, width / 2 - 1 }) do
			local postHeight = base.Position.Y + height - MARGIN
			Kit.part(unit, "Post", Vector3.new(0.4, postHeight, 0.4), floor * CFrame.new(x, postHeight / 2, depth + 0.2), STEEL, M.Metal)
			Kit.part(unit, "Foot", Vector3.new(1.4, 0.3, 1.6), floor * CFrame.new(x, 0.15, depth + 0.2), CHARCOAL, M.Concrete)
		end
		Kit.prop(unit, "Cap", Vector3.new(width + 0.6, 0.18, depth + 0.8), centre * CFrame.new(0, height / 2 + 0.15, 0.1), STEEL, M.Metal)
		local backFace = Kit.prop(unit, "BackPlate", Vector3.new(width - 1, 1.2, 0.05), centre * CFrame.new(0, height / 2 - 1.2, depth / 2 + 0.03), BACKING, M.SmoothPlastic)
		backFace.CFrame = CFrame.lookAt(backFace.Position, backFace.Position - base.LookVector)
		local backGui = Instance.new("SurfaceGui")
		backGui.Face = Enum.NormalId.Front
		backGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		backGui.PixelsPerStud = 50
		backGui.LightInfluence = 0.5
		backGui.Parent = backFace
		label(backGui, "Text", { Text = "GYM ARC LEADERBOARDS", FontFace = Theme.Fonts.SemiBold, TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0, 0.15) })
	end
	for _, part in ipairs(unit:GetDescendants()) do
		if part:IsA("BasePart") then part.CanTouch = false end
	end
	return unit
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- the paving under a spot (cast from just above it, so string lights, lamps and trees overhead are never hit)
local function groundY(x, z)
	local hit = Workspace:Raycast(Vector3.new(x, 4, z), Vector3.new(0, -10, 0))
	return hit and hit.Position.Y or 0
end

function Builder.Build()
	local made = {}
	-- the starter gym: front wall (inner face z = -4), facing into the room (-Z), above the windows (tops 8.35), under the
	-- cornice (15.7), between the speaker in the corner (x -41) and the "Show up" poster (x -18.6)
	local starter = Workspace.Gym.StarterGym
	table.insert(made, Builder.Unit(folder(starter, "Feature_Leaderboards"), "LeaderboardWall",
		CFrame.lookAt(Vector3.new(-29.8, 8.9, -4.06), Vector3.new(-29.8, 8.9, -10)), false))
	-- the pro gym: the band above the front glass (inner face z = -4)
	local pro = Workspace.ProGym
	table.insert(made, Builder.Unit(folder(pro, "Feature_Leaderboards"), "LeaderboardWall",
		CFrame.lookAt(Vector3.new(70, 9.7, -4.06), Vector3.new(70, 9.7, -10)), false))
	-- the town plaza: freestanding near the north edge (west of the path to the park, clear of the corner tree, light pole
	-- and planter), facing the street (-Z)
	local town = Workspace.Town
	local y = groundY(-14.5, 84)
	table.insert(made, Builder.Unit(folder(town, "Feature_Leaderboards"), "LeaderboardStand",
		CFrame.lookAt(Vector3.new(-14.5, y + 1.6, 84), Vector3.new(-14.5, y + 1.6, 76)), true))
	return made
end

return Builder
