-- ReadyGlow (owner, 23 Oct): the one "ready" glow (first used on MY TRAINERS' next-evolution button; for the alter ready
-- pill and claim buttons later). ONE soft glow image BEHIND the target (a sibling just under it, so it never covers the
-- words): a white blurred rounded rectangle (assets/ui/ready_glow.png, 9-slice) tinted in the color, ~22 px past the target
-- on every side, breathing (transparency 0.35 <-> 0.7, +6 px, 1.6 s a loop, sine in / out). On the target's own outline a
-- lighter highlight travels round (a UIGradient on the UIStroke, ~3 s a lap). Reduced Motion: the glow stays, still.
--   local glow = ReadyGlow.New(target, { stroke = its UIStroke, pad = 22 })
--   glow:Set(on, color)   -- off: the glow hidden, the outline back to `color`
-- Until the texture is uploaded (Config/UI.ReadyGlow empty) it uses the round soft glow (Config/UI.SoftGlow), stretched.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.Parent.Config.UI)

local ReadyGlow = {}
ReadyGlow.__index = ReadyGlow

local SOURCE_EDGE = 64 -- (the texture: 256 px, the rounded rectangle's edge 64 px in, the blur fading out past it)
local SLICE = Rect.new(110, 110, 146, 146)
local BREATHE = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true) -- (there and back: 1.6 s)
local LAP = TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

function ReadyGlow.New(target: GuiObject, opts)
	opts = opts or {}
	local self = setmetatable({ target = target, pad = opts.pad or 22, stroke = opts.stroke, on = false, tweens = {} }, ReadyGlow)
	local sliced = type(UI.ReadyGlow) == "string" and UI.ReadyGlow ~= ""
	self.sliced = sliced
	self.image = Theme.New("ImageLabel", { Name = (target.Name or "") .. "Glow", BackgroundTransparency = 1, Image = if sliced then UI.ReadyGlow else UI.SoftGlow,
		ScaleType = if sliced then Enum.ScaleType.Slice else Enum.ScaleType.Stretch, SliceCenter = SLICE, SliceScale = self.pad / SOURCE_EDGE,
		AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.5, Visible = false, ZIndex = math.max(1, target.ZIndex - 1), Active = false,
		Parent = target.Parent })
	self.highlight = nil
	if self.stroke then
		self.highlight = Theme.New("UIGradient", { Name = "ReadyHighlight", Enabled = false, Parent = self.stroke })
	end
	local function follow() self:Place() end
	target:GetPropertyChangedSignal("Position"):Connect(follow)
	target:GetPropertyChangedSignal("Size"):Connect(follow)
	target:GetPropertyChangedSignal("AnchorPoint"):Connect(follow)
	target:GetPropertyChangedSignal("Visible"):Connect(function() self.image.Visible = self.on and target.Visible end)
	target.Destroying:Connect(function() self:Stop() self.image:Destroy() end)
	self:Place()
	return self
end

-- centred on the target, `grow` px bigger in all (the round fallback reaches further: it fades sooner)
function ReadyGlow:Size(grow: number): UDim2
	local s = self.target.Size
	local pad = (if self.sliced then self.pad else self.pad * 1.8) * 2 + grow
	return UDim2.new(s.X.Scale, s.X.Offset + pad, s.Y.Scale, s.Y.Offset + pad)
end

function ReadyGlow:Place()
	local t = self.target
	local a, p, s = t.AnchorPoint, t.Position, t.Size
	self.image.Position = UDim2.new(p.X.Scale + (0.5 - a.X) * s.X.Scale, p.X.Offset + (0.5 - a.X) * s.X.Offset,
		p.Y.Scale + (0.5 - a.Y) * s.Y.Scale, p.Y.Offset + (0.5 - a.Y) * s.Y.Offset)
	if not self.on or #self.tweens == 0 then self.image.Size = self:Size(0) end
end

function ReadyGlow:Stop()
	for _, tween in ipairs(self.tweens) do tween:Cancel() end
	table.clear(self.tweens)
end

function ReadyGlow:Set(on: boolean, color: Color3?)
	color = color or Color3.new(1, 1, 1)
	local changed = on ~= self.on or color ~= self.color
	self.on, self.color = on, color
	self.image.Visible = on and self.target.Visible
	self.image.ImageColor3 = color
	if self.stroke then
		-- the outline: plain `color` when off; white under the travelling highlight when on
		self.stroke.Color = if on then Color3.new(1, 1, 1) else color
		local light = color:Lerp(Color3.new(1, 1, 1), 0.65)
		self.highlight.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.38, color), ColorSequenceKeypoint.new(0.5, light),
			ColorSequenceKeypoint.new(0.62, color), ColorSequenceKeypoint.new(1, color) })
		self.highlight.Enabled = on
	end
	if not changed then return end
	self:Stop()
	self.image.Size = self:Size(0)
	if not on then return end
	if Theme.ReducedMotion() then
		self.image.ImageTransparency = 0.45
		return
	end
	self.image.ImageTransparency = 0.7
	table.insert(self.tweens, TweenService:Create(self.image, BREATHE, { ImageTransparency = 0.35, Size = self:Size(6) }))
	if self.highlight then
		self.highlight.Rotation = 0
		table.insert(self.tweens, TweenService:Create(self.highlight, LAP, { Rotation = 360 }))
	end
	for _, tween in ipairs(self.tweens) do tween:Play() end
end

return ReadyGlow
