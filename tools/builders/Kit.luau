-- Kit: shared part helpers for the world builders (tools/builders). These builders are NOT part of the game: they
-- were run once in Studio (tools/bake.md) to create the parts that are now saved in the place. Run them again only to
-- rebuild an area from scratch (they replace what they built before).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Kit = {}

function Kit.hex(value) return Color3.fromHex(value) end

function Kit.part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do p[key] = value end
	p.Parent = parent
	return p
end

-- small decorative part: no collisions, no shadow, not hit by raycasts
function Kit.prop(parent, name, size, cframe, color, material, props)
	local p = Kit.part(parent, name, size, cframe, color, material, props)
	p.CanCollide, p.CastShadow, p.CanQuery, p.CanTouch = false, false, false, false
	return p
end

function Kit.wedge(parent, name, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.Anchored = true
	p.Parent = parent
	return p
end

function Kit.cylinder(parent, name, length, diameter, cframe, color, material, solid)
	local p = (solid and Kit.part or Kit.prop)(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A board with one line of text on its front face (-Z). Turn it to the reader with CFrame.lookAt(position, reader).
function Kit.sign(parent, name, size, cframe, text, textColor, boardColor, pixelsPerStud)
	local board = Kit.prop(parent, name, size, cframe, boardColor or Kit.hex("#1E1E22"), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Theme.Colors.Text
	label.FontFace = Theme.Fonts.SemiBold
	label.TextScaled = true -- world-space sign: the only place text may scale
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.Parent = label
	return board, label
end

function Kit.prompt(parent, name, action, object, distance, hold)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.MaxActivationDistance = distance or 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = hold or 0
	prompt.Parent = parent
	return prompt
end

-- Remove what a builder made before (a direct child of `parent` with this name), then make a fresh container.
function Kit.fresh(parent, className, name)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local container = Instance.new(className)
	container.Name = name
	container.Parent = parent
	return container
end

return Kit
