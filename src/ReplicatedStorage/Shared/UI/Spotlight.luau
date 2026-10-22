-- Spotlight (prompt 53a, 23 Oct): points at a button on screen, for the tutorial and the unlock guides (GuideClient's
-- pointer, moved here so both use one look, mockup tutorial2.png): the rest of the screen dims (four dark frames around
-- the button, so the button itself stays bright), the button gets a pulsing gold glow, and a gold arrow bounces next to it
-- pointing at it, with an optional gold word ("TAP STOP"). Taps pass through the dim (nothing here is Active).
--   Spotlight.Point(object?, label?)   point at a GuiObject (nil = stop)
--   Spotlight.Pointed() -> GuiObject?
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

local New, Colors = Theme.New, Theme.Colors
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Spotlight = {}
Spotlight.Dim = 0.5        -- the dim's transparency
Spotlight.DimOrder = 22    -- under the tutorial / guide gui (23: the dialog, SKIP and GO TO stay bright)
Spotlight.Pad = 4          -- px around the button (the glow and the hole)

local dimGui = New("ScreenGui", { Name = "SpotlightDim", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, DisplayOrder = Spotlight.DimOrder,
	Parent = playerGui })
dimGui.ScreenInsets = Enum.ScreenInsets.None
local sides = {}
for _, name in ipairs({ "Top", "Bottom", "Left", "Right" }) do
	sides[name] = New("Frame", { Name = name, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Spotlight.Dim, BorderSizePixel = 0, Active = false,
		Parent = dimGui })
end

local pointGui = New("ScreenGui", { Name = "SpotlightPoint", DisplayOrder = 60, ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
pointGui.ScreenInsets = Enum.ScreenInsets.None -- (whole-screen pixels: the target's position is converted below)
local glow = New("Frame", { Name = "Glow", BackgroundTransparency = 1, Parent = pointGui }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Name = "Stroke", Color = Colors.Gold, Thickness = 3 }),
})
-- a softer, wider gold ring outside it
local halo = New("Frame", { Name = "Halo", BackgroundTransparency = 1, Parent = pointGui }, {
	New("UICorner", { CornerRadius = UDim.new(0, 16) }),
	New("UIStroke", { Name = "Stroke", Color = Colors.Gold, Thickness = 6, Transparency = 0.7 }),
})
-- the arrow: a gold arrow on a dark copy of itself (its outline), pointing at the button; the word sits behind its tail
local arrow = New("Frame", { Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, Parent = pointGui })
local arrowEdge = Pieces.Icon("arrow-big-up", Colors.Outline, { Name = "Edge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(50, 50), Parent = arrow })
arrowEdge:SetAttribute("KeepColor", true)
local arrowFace = Pieces.Icon("arrow-big-up", Colors.Gold, { Name = "Face", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(42, 42), ZIndex = 2, Parent = arrow })
arrowFace:SetAttribute("KeepColor", true)
local word = Kit.GoldText(Kit.Text({ Name = "Word", Text = "", Font = "Chunky", Upper = true, TextSize = 22, Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = pointGui }))
local wordStroke = word:FindFirstChild("TextStroke")
if wordStroke then wordStroke.Transparency = 0 end

local pointed: GuiObject? = nil

function Spotlight.Pointed(): GuiObject?
	return pointed
end

function Spotlight.Point(object: GuiObject?, label: string?)
	pointed = object
	pointGui.Enabled = object ~= nil
	dimGui.Enabled = object ~= nil
	word.Text = label or ""
	word.Visible = label ~= nil and label ~= ""
end

-- is it on screen? (every frame above it visible, its gui enabled)
local function shown(object: GuiObject?): boolean
	if not object or not object:IsDescendantOf(playerGui) or object.AbsoluteSize.X < 2 then return false end
	local node: Instance? = object
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("LayerCollector") and not node.Enabled then return false end
		node = node.Parent
	end
	return true
end
Spotlight.Shown = shown

local function layout()
	local object = pointed
	if not object then return end
	if not object.Parent then Spotlight.Point(nil) return end
	-- (a button that steps aside for a moment, e.g. under an open window: the spotlight waits, hidden)
	local visible = shown(object)
	pointGui.Enabled, dimGui.Enabled = visible, visible
	if not visible then return end
	-- (AbsolutePositions share one screen space; this gui's own origin sits at its AbsolutePosition, so subtract it)
	local pad = Spotlight.Pad
	local position = object.AbsolutePosition - pointGui.AbsolutePosition
	local size = object.AbsoluteSize
	local screen = pointGui.AbsoluteSize
	local x0, y0 = position.X - pad, position.Y - pad
	local x1, y1 = position.X + size.X + pad, position.Y + size.Y + pad
	-- the dim: four frames around the hole
	sides.Top.Position, sides.Top.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(screen.X, math.max(y0, 0))
	sides.Bottom.Position, sides.Bottom.Size = UDim2.fromOffset(0, y1), UDim2.fromOffset(screen.X, math.max(screen.Y - y1, 0))
	sides.Left.Position, sides.Left.Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(math.max(x0, 0), y1 - y0)
	sides.Right.Position, sides.Right.Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(math.max(screen.X - x1, 0), y1 - y0)
	glow.Position = UDim2.fromOffset(x0, y0)
	glow.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
	halo.Position = UDim2.fromOffset(x0 - 4, y0 - 4)
	halo.Size = UDim2.fromOffset(x1 - x0 + 8, y1 - y0 + 8)
	local t = os.clock()
	local pulse = 0.5 + 0.5 * math.sin(t * 5)
	glow.Stroke.Transparency = 0.05 + 0.35 * pulse
	halo.Stroke.Transparency = 0.55 + 0.35 * pulse
	local bounce = math.sin(t * 6) * 6
	local center = position + size / 2
	local half = arrow.AbsoluteSize.X / 2
	if center.X < screen.X * 0.35 then -- (a button on the left: the arrow on its right, pointing at it; outside the side menu)
		local bar = object:FindFirstAncestor("MenuBar") :: GuiObject?
		local right = if bar and bar:IsA("GuiObject") then bar.AbsolutePosition.X + bar.AbsoluteSize.X - pointGui.AbsolutePosition.X else x1
		local ax = math.max(x1, right) + half + 6 + bounce
		arrow.Rotation = -90
		arrow.Position = UDim2.fromOffset(ax, center.Y)
		word.AnchorPoint = Vector2.new(0, 0.5)
		word.Position = UDim2.fromOffset(ax + half + 4, center.Y)
	elseif center.X > screen.X * 0.65 then
		local ax = x0 - half - 6 - bounce
		arrow.Rotation = 90
		arrow.Position = UDim2.fromOffset(ax, center.Y)
		word.AnchorPoint = Vector2.new(1, 0.5)
		word.Position = UDim2.fromOffset(ax - half - 4, center.Y)
	else
		local ay = y0 - half - 6 - bounce
		arrow.Rotation = 180
		arrow.Position = UDim2.fromOffset(center.X, ay)
		word.AnchorPoint = Vector2.new(0.5, 1)
		word.Position = UDim2.fromOffset(center.X, ay - half - 2)
	end
end
RunService.RenderStepped:Connect(layout)

return Spotlight
