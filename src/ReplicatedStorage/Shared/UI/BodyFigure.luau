-- BodyFigure: the body silhouette made of muscle shapes (the body-map widget).
-- Drawn on a 40 x 100 grid (head = 12.8: torso 3 heads, legs 3.5 heads, arms end at mid-thigh).
local BodyFigure = {}

-- The 40 x 100 grid. Shapes are { x, y, w, h, roundness }; paired muscles are drawn mirrored left / right.
local function mirror(shape) return { 40 - shape[1] - shape[3], shape[2], shape[3], shape[4], shape[5] } end
local function pair(shape) return { shape, mirror(shape) } end
local function both(list)
	local out = {}
	for _, shape in ipairs(list) do table.insert(out, shape); table.insert(out, mirror(shape)) end
	return out
end

local BODY = both({ -- one side of every paired piece (mirrored) + the middle pieces below
	{ 3.6, 16.5, 5.2, 23.5, 0.5 },  -- upper arm (to y 40)
	{ 3.4, 40, 4.9, 18, 0.5 },      -- forearm (to 58)
	{ 3.6, 58, 4.4, 7, 1 },         -- hand (ends at mid-thigh, y 65)
	{ 11.2, 54, 8.2, 22.6, 0.4 },   -- thigh (to 76.6)
	{ 12, 76.6, 6.6, 19.6, 0.4 },   -- shin (to 96.2)
	{ 11.6, 96.2, 7.6, 3.2, 0.5 },  -- foot
})
table.insert(BODY, { 14.6, 0, 10.8, 12.8, 1 })     -- head (1 head = 12.8)
table.insert(BODY, { 17.6, 12.2, 4.8, 3.6, 0.3 })  -- neck
table.insert(BODY, { 9.5, 15.3, 21, 22, 0.25 })    -- chest and shoulders (the top of the V)
table.insert(BODY, { 11.4, 35, 17.2, 19, 0.25 })   -- waist (narrower: the bottom of the V)

local FRONT = {
	FrontDelts = pair({ 8.9, 16.4, 3.4, 6, 0.6 }),
	SideDelts = pair({ 3.8, 16.8, 4.8, 6, 0.6 }),
	UpperChest = pair({ 12.6, 18.4, 7, 4.6, 0.4 }),
	MidChest = pair({ 12.6, 23.4, 7, 5.2, 0.4 }),
	Biceps = pair({ 4, 23.6, 4.6, 11, 0.6 }),
	Forearms = pair({ 3.8, 40.6, 4.4, 15.4, 0.5 }),
	Abs = { { 16.8, 30, 6.4, 18.4, 0.25 } },
	Obliques = pair({ 12.4, 30.4, 3.8, 15.6, 0.5 }),
	Quads = pair({ 12, 56.2, 6.8, 18.4, 0.5 }),
}
local BACK = {
	Traps = { { 14.2, 14.6, 11.6, 6.4, 0.5 } },
	RearDelts = pair({ 3.8, 16.6, 5.2, 5.8, 0.6 }),
	Rhomboids = { { 16.2, 21.8, 7.6, 7.6, 0.3 } },
	Lats = pair({ 11.6, 22.2, 4.4, 15.8, 0.5 }),
	LowerBack = { { 15.4, 38.6, 9.2, 10.4, 0.3 } },
	Triceps = pair({ 4, 23.6, 4.6, 12, 0.6 }),
	Glutes = pair({ 12, 49.8, 7.2, 8.2, 0.6 }),
	Hamstrings = pair({ 12.2, 58.8, 6.6, 15.4, 0.5 }),
	Calves = pair({ 12.6, 78, 5.6, 14.8, 0.6 }),
}


BodyFigure.Body, BodyFigure.Front, BodyFigure.Back = BODY, FRONT, BACK
BodyFigure.Mirror, BodyFigure.Pair, BodyFigure.Both = mirror, pair, both
BodyFigure.GridWidth = 40

-- Draws one view ("Front" / "Back") into `parent` (fills it; keep it 40:100). colorOf(muscleId) -> (Color3, transparency)
-- or nil for an untinted muscle; body = (Color3, transparency) of the faint body behind.
function BodyFigure.Draw(parent: GuiObject, view: string, colorOf: (string) -> (Color3?, number?), bodyColor: Color3, bodyTransparency: number)
	local function shape(spec, color, transparency, z)
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromScale(spec[1] / 40, spec[2] / 100)
		frame.Size = UDim2.fromScale(spec[3] / 40, spec[4] / 100)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = transparency
		frame.ZIndex = z
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(spec[5], 0)
		corner.Parent = frame
		frame.Parent = parent
	end
	for _, spec in ipairs(BODY) do shape(spec, bodyColor, bodyTransparency, 1) end
	for id, shapes in pairs(if view == "Back" then BACK else FRONT) do
		local color, transparency = colorOf(id)
		if color then
			for _, spec in ipairs(shapes) do shape(spec, color, transparency or 0, 2) end
		end
	end
end

return BodyFigure
