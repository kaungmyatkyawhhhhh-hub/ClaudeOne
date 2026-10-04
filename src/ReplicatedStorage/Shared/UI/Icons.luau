-- Simple line icons built from frames, white by default. Each returns a square
-- frame that fills its parent. Pass a color to draw on light backgrounds.
local Theme = require(script.Parent.Theme)
local New, Colors = Theme.New, Theme.Colors

local Icons = {}

local THICKNESS = 0.11

local function canvas(name)
	return New("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, { Theme.Aspect(1) })
end

local function line(parent, color, length, x, y, rotation)
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(length, THICKNESS),
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		Parent = parent,
	}, { Theme.Round("Round") })
end

local function outline(parent, color, w, h, x, y, corner)
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		New("UICorner", { CornerRadius = corner }),
		New("UIStroke", { Color = color, Thickness = Theme.IconStroke }),
	})
end

function Icons.Close(color)
	color = color or Colors.Chalk
	local icon = canvas("Close")
	line(icon, color, 0.85, 0.5, 0.5, 45)
	line(icon, color, 0.85, 0.5, 0.5, -45)
	return icon
end

-- direction: -1 = left, 1 = right
function Icons.Chevron(direction, color)
	color = color or Colors.Chalk
	local icon = canvas("Chevron")
	local tipX = direction < 0 and 0.32 or 0.68
	local armX = tipX - direction * 0.16
	line(icon, color, 0.46, armX, 0.34, direction < 0 and -45 or 45)
	line(icon, color, 0.46, armX, 0.66, direction < 0 and 45 or -45)
	return icon
end

function Icons.Dumbbell(color)
	color = color or Colors.Chalk
	local icon = canvas("Dumbbell")
	line(icon, color, 0.5, 0.5, 0.5)
	outline(icon, color, 0.13, 0.5, 0.25, 0.5, Theme.Corner.Segment)
	outline(icon, color, 0.13, 0.5, 0.75, 0.5, Theme.Corner.Segment)
	outline(icon, color, 0.08, 0.3, 0.1, 0.5, Theme.Corner.Segment)
	outline(icon, color, 0.08, 0.3, 0.9, 0.5, Theme.Corner.Segment)
	return icon
end

-- Coins are drawn as an outline plate.
function Icons.Plate(color)
	color = color or Colors.Chalk
	local icon = canvas("Plate")
	outline(icon, color, 0.8, 0.8, 0.5, 0.5, Theme.Corner.Round)
	outline(icon, color, 0.3, 0.3, 0.5, 0.5, Theme.Corner.Round)
	return icon
end

function Icons.Lock(color)
	color = color or Colors.Chalk
	local icon = canvas("Lock")
	local shackle = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.6, 0.36),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = icon,
	})
	outline(shackle, color, 0.62, 1.6, 0.5, 0.82, Theme.Corner.Round)
	outline(icon, color, 0.66, 0.46, 0.5, 0.66, Theme.Corner.Segment)
	return icon
end

function Icons.Plus(color)
	color = color or Colors.Chalk
	local icon = canvas("Plus")
	line(icon, color, 0.7, 0.5, 0.5)
	line(icon, color, 0.7, 0.5, 0.5, 90)
	return icon
end

function Icons.Minus(color)
	color = color or Colors.Chalk
	local icon = canvas("Minus")
	line(icon, color, 0.7, 0.5, 0.5)
	return icon
end

-- Stats: three bars of different heights on a baseline.
function Icons.Stats(color)
	color = color or Colors.Chalk
	local icon = canvas("Stats")
	line(icon, color, 0.8, 0.5, 0.86)
	line(icon, color, 0.3, 0.27, 0.66, 90)
	line(icon, color, 0.55, 0.5, 0.54, 90)
	line(icon, color, 0.42, 0.73, 0.6, 90)
	return icon
end

-- Flexing figure (front double biceps): head, shoulders/arms, raised forearms, torso, legs.
function Icons.Flex(color)
	color = color or Colors.Chalk
	local icon = canvas("Flex")
	outline(icon, color, 0.2, 0.2, 0.5, 0.15, Theme.Corner.Round)   -- head
	line(icon, color, 0.74, 0.5, 0.33)                              -- shoulders + upper arms
	line(icon, color, 0.22, 0.13, 0.23, 90)                         -- left forearm (up)
	line(icon, color, 0.22, 0.87, 0.23, 90)                         -- right forearm (up)
	outline(icon, color, 0.12, 0.12, 0.13, 0.08, Theme.Corner.Round) -- fists
	outline(icon, color, 0.12, 0.12, 0.87, 0.08, Theme.Corner.Round)
	line(icon, color, 0.3, 0.5, 0.48, 90)                           -- torso
	line(icon, color, 0.36, 0.42, 0.78, 114)                        -- legs
	line(icon, color, 0.36, 0.58, 0.78, 66)
	return icon
end

-- Trophy: cup with handles, stem and base.
function Icons.Trophy(color)
	color = color or Colors.Chalk
	local icon = canvas("Trophy")
	outline(icon, color, 0.44, 0.38, 0.5, 0.3, UDim.new(0.35, 0))     -- cup
	outline(icon, color, 0.18, 0.2, 0.22, 0.28, Theme.Corner.Round)    -- handles
	outline(icon, color, 0.18, 0.2, 0.78, 0.28, Theme.Corner.Round)
	line(icon, color, 0.18, 0.5, 0.6, 90)                              -- stem
	line(icon, color, 0.34, 0.5, 0.71)                                 -- base top
	outline(icon, color, 0.48, 0.12, 0.5, 0.82, Theme.Corner.Segment)  -- base
	return icon
end

-- DNA: two strands crossing like a ladder twisted, with rungs.
function Icons.DNA(color)
	color = color or Colors.Chalk
	local icon = canvas("DNA")
	local function segment(x1, y1, x2, y2)
		local dx, dy = x2 - x1, y2 - y1
		line(icon, color, math.sqrt(dx * dx + dy * dy), (x1 + x2) / 2, (y1 + y2) / 2, math.deg(math.atan2(dy, dx)))
	end
	local ys = { 0.08, 0.36, 0.64, 0.92 }
	for i = 1, #ys - 1 do
		local a, b = (i % 2 == 1) and 0.28 or 0.72, (i % 2 == 1) and 0.72 or 0.28
		segment(a, ys[i], b, ys[i + 1]) -- strand one
		segment(b, ys[i], a, ys[i + 1]) -- strand two
	end
	for _, y in ipairs(ys) do line(icon, color, 0.3, 0.5, y) end -- rungs
	return icon
end

-- Gear (settings): a ring with six short teeth and a small hub.
function Icons.Gear(color)
	color = color or Colors.Chalk
	local icon = canvas("Gear")
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		line(icon, color, 0.2, 0.5 + math.cos(angle) * 0.36, 0.5 + math.sin(angle) * 0.36, i * 60)
	end
	outline(icon, color, 0.56, 0.56, 0.5, 0.5, Theme.Corner.Round)
	outline(icon, color, 0.2, 0.2, 0.5, 0.5, Theme.Corner.Round)
	return icon
end

-- Recolor any icon built here (lines are filled frames, outlines are strokes).
-- Shaker cup: body, lid line and a straw.
function Icons.Shake(color)
	color = color or Colors.Chalk
	local icon = canvas("Shake")
	outline(icon, color, 0.44, 0.56, 0.5, 0.62, UDim.new(0.18, 0))
	line(icon, color, 0.56, 0.5, 0.3)
	line(icon, color, 0.26, 0.6, 0.16, -60)
	return icon
end

-- Clock-style timer: a ring with one hand (shake boost time left).
function Icons.Timer(color)
	color = color or Colors.Chalk
	local icon = canvas("Timer")
	outline(icon, color, 0.7, 0.7, 0.5, 0.52, UDim.new(1, 0))
	line(icon, color, 0.24, 0.5, 0.42, 90)
	line(icon, color, 0.14, 0.5, 0.12)
	return icon
end

-- Figure flexing with both arms up (emotes).
function Icons.Pose(color)
	color = color or Colors.Chalk
	local icon = canvas("Pose")
	outline(icon, color, 0.2, 0.2, 0.5, 0.18, UDim.new(1, 0))
	line(icon, color, 0.36, 0.5, 0.48, 90)
	line(icon, color, 0.26, 0.3, 0.36, -40)
	line(icon, color, 0.26, 0.7, 0.36, 40)
	line(icon, color, 0.28, 0.42, 0.8, 70)
	line(icon, color, 0.28, 0.58, 0.8, -70)
	return icon
end

-- Two people (crews).
function Icons.People(color)
	color = color or Colors.Chalk
	local icon = canvas("People")
	outline(icon, color, 0.24, 0.24, 0.36, 0.28, UDim.new(1, 0))
	outline(icon, color, 0.4, 0.3, 0.36, 0.7, UDim.new(0.5, 0))
	outline(icon, color, 0.2, 0.2, 0.7, 0.32, UDim.new(1, 0))
	outline(icon, color, 0.32, 0.26, 0.72, 0.7, UDim.new(0.5, 0))
	return icon
end

function Icons.Tint(icon, color)
	for _, part in ipairs(icon:GetDescendants()) do
		if part:IsA("UIStroke") then
			part.Color = color
		elseif part:IsA("Frame") and part.BackgroundTransparency < 1 then
			part.BackgroundColor3 = color
		end
	end
end

return Icons
