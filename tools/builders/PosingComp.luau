-- PosingComp builder (run once in Studio; see tools/bake.md): the posing competition's pieces on the existing posing stage
-- (Workspace.Town.PosingStage, from the Town builder), all in one folder so they can be found and deleted easily:
--   Workspace.Town.PosingStage.Feature_PosingComp
--     Mark1..Mark6   taped floor marks in a row across the stage (contestants stand on them; top centre = the spot)
--     Podium         three steps (1st in the middle, 2nd left, 3rd right as the crowd sees them) with Spot1/2/3 parts on top
--     Scoreboard     a framed screen on two posts beside the stage, facing the crowd; SurfaceGui "Screen" with labels
--                    Title, Status and Row1..Row6 (each with "Name" and "Score")
-- PosingCompService finds these by name. Requires Kit loaded next to it (tools/bake.md).
-- Usage (command bar): require(game.ServerStorage._Builders.PosingComp).Build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = ReplicatedStorage.Shared.Config
local Town = require(Config.Town)
local PosingComp = require(Config.PosingComp)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Kit = require(script.Parent.Kit)

local M = Enum.Material
local hex = Kit.hex
local rad = math.rad

local Builder = {}

local WOOD = hex("#5E4632")
local CHARCOAL = hex("#1E1E22")
local STEEL = hex("#C9CCD2")
local TAPE = hex("#F4F1EA")

local function textLabel(parent, name, props)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = Theme.Colors.Text
	label.FontFace = Theme.Fonts.Regular
	label.TextScaled = true -- world sign (SurfaceGui): the only kind of text that may scale
	for key, value in pairs(props) do label[key] = value end
	label.Parent = parent
	return label
end

-- A number painted on a part's face (SurfaceGui, world text).
local function paintNumber(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = part
	textLabel(gui, "Number", { Text = text, TextColor3 = color, FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 1) })
	return gui
end

function Builder.Build()
	local stageModel = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("PosingStage")
	assert(stageModel, "Workspace.Town.PosingStage is missing (Town builder)")
	local stagePart = stageModel:FindFirstChild("Stage")
	assert(stagePart, "PosingStage.Stage is missing")
	local folder = Kit.fresh(stageModel, "Folder", "Feature_PosingComp")

	local spec = Town.Stage
	local c, s = spec.Center, spec.Size
	local top = stagePart.Position.Y + stagePart.Size.Y / 2 -- the stage floor
	-- the stage faces the crowd at -Z (its steps and benches are on the south side)
	local base = CFrame.new(c.X, top, c.Z)

	-- 1. Contestant marks: a row of taped "T" marks with a small number, across the front half of the stage
	local count = PosingComp.MaxPlayers
	local spacing = math.min(2.5, (s.X - 3) / math.max(count - 1, 1))
	for i = 1, count do
		local x = (i - (count + 1) / 2) * spacing
		local cf = base * CFrame.new(x, 0.02, -1.5)
		local mark = Kit.prop(folder, "Mark" .. i, Vector3.new(1.2, 0.04, 0.16), cf, TAPE, M.SmoothPlastic)
		Kit.prop(mark, "Stem", Vector3.new(0.16, 0.04, 0.9), cf * CFrame.new(0, 0, 0.53), TAPE, M.SmoothPlastic)
		-- the mark's number, painted on the floor in front of the T (reads from the crowd)
		local tag = Kit.prop(mark, "NumberPlate", Vector3.new(0.6, 0.03, 0.6), cf * CFrame.new(0, 0, -0.5), CHARCOAL, M.SmoothPlastic)
		tag.Transparency = 1
		paintNumber(tag, Enum.NormalId.Top, tostring(i), TAPE)
	end

	-- 2. Podium: three wooden steps at the back of the stage, in front of the backdrop
	local podium = Instance.new("Model")
	podium.Name = "Podium"
	podium.Parent = folder
	local steps = {
		{ place = 1, x = 0, height = 1.5 },
		{ place = 2, x = 2.6, height = 1 },  -- (+X is the crowd's left: they look north, toward +Z)
		{ place = 3, x = -2.6, height = 0.65 },
	}
	local plateColors = { Theme.Bumper.Red, Theme.Bumper.Blue, Theme.Bumper.Yellow } -- bumper plate rims as trims
	for _, step in ipairs(steps) do
		local h = step.height
		local cf = base * CFrame.new(step.x, h / 2, 3.2)
		local block = Kit.part(podium, "Step" .. step.place, Vector3.new(2.5, h, 2.2), cf, CHARCOAL, M.SmoothPlastic)
		block.CastShadow = true
		Kit.prop(podium, "Trim", Vector3.new(2.6, 0.12, 2.3), cf * CFrame.new(0, h / 2 - 0.06, 0), STEEL, M.Metal)
		Kit.prop(podium, "Kick", Vector3.new(2.6, 0.1, 2.3), cf * CFrame.new(0, -h / 2 + 0.05, 0), hex("#141416"), M.Rubber)
		Kit.prop(podium, "Band", Vector3.new(2.52, math.min(0.18, h * 0.25), 0.04), cf * CFrame.new(0, h / 2 - 0.3, -1.11), plateColors[step.place].Fill, M.SmoothPlastic)
		local face = Kit.prop(podium, "Face", Vector3.new(1.4, math.max(h - 0.5, 0.3), 0.02), cf * CFrame.new(0, -0.12, -1.11), CHARCOAL, M.SmoothPlastic)
		face.Transparency = 1
		paintNumber(face, Enum.NormalId.Front, tostring(step.place), TAPE)
		local spot = Kit.prop(podium, "Spot" .. step.place, Vector3.new(0.5, 0.05, 0.5), cf * CFrame.new(0, h / 2 + 0.03, 0), CHARCOAL, M.SmoothPlastic)
		spot.Transparency = 1
	end

	-- 3. Scoreboard: a framed screen on two posts beside the stage (crowd's left = east, +X; the west side has the
	-- boardwalk from the beach gym), turned to the benches
	local boardCenter = Vector3.new(c.X + s.X / 2 + 7, 0, c.Z - s.Z / 2 + 3)
	local crowd = Vector3.new(c.X, 0, c.Z - s.Z / 2 - 14)
	local facing = CFrame.lookAt(boardCenter, Vector3.new(crowd.X, 0, crowd.Z))
	local board = Instance.new("Model")
	board.Name = "Scoreboard"
	board.Parent = folder
	local W, H, bottom = 7, 4.6, 3.4
	for _, x in ipairs({ -W / 2 + 0.6, W / 2 - 0.6 }) do
		Kit.part(board, "Post", Vector3.new(0.35, bottom + H, 0.35), facing * CFrame.new(x, (bottom + H) / 2, 0.15), STEEL, M.Metal)
		Kit.part(board, "Foot", Vector3.new(1.2, 0.3, 1.2), facing * CFrame.new(x, 0.15, 0.15), CHARCOAL, M.Concrete)
	end
	local frame = Kit.part(board, "Frame", Vector3.new(W + 0.3, H + 0.3, 0.3), facing * CFrame.new(0, bottom + H / 2, 0.05), CHARCOAL, M.Metal)
	frame.CastShadow = true
	local screen = Kit.prop(board, "Screen", Vector3.new(W, H, 0.1), facing * CFrame.new(0, bottom + H / 2, -0.15), hex("#0E0E10"), M.SmoothPlastic)
	Kit.prop(board, "Cap", Vector3.new(W + 0.5, 0.15, 0.6), facing * CFrame.new(0, bottom + H + 0.22, 0), STEEL, M.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = screen
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.05, 0), UDim.new(0.04, 0)
	pad.Parent = gui
	textLabel(gui, "Title", { Text = "POSING COMPETITION", FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 0.16) })
	textLabel(gui, "Status", { Text = "Next round soon", TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.17) })
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Theme.Colors.Text
	rule.BackgroundTransparency = 0.8
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.Position = UDim2.fromScale(0, 0.3)
	rule.Parent = gui
	for i = 1, 6 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.105)
		row.Position = UDim2.fromScale(0, 0.33 + (i - 1) * 0.112)
		row.Parent = gui
		textLabel(row, "Name", { Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.75, 1) })
		textLabel(row, "Score", { Text = "", FontFace = Theme.Fonts.SemiBold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.25, 1), Position = UDim2.fromScale(0.75, 0) })
	end

	for _, part in ipairs(folder:GetDescendants()) do
		if part:IsA("BasePart") then part.CanTouch = false end
	end
	return folder
end

return Builder
