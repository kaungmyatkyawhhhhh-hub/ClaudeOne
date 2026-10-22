-- AuraBackdrop (owner, 23 Oct): the themed, moving background behind an aura in the Inventory's AURAS detail panel, like
-- the alters' banners (Pumped = red rings + a heartbeat). Made from frames, gradients and the FX textures we already have
-- (Shared/VFX/AlterFX), no pictures. Every look has soft rings spreading from the orb, on a dark gradient in the aura's
-- colour (dark enough for white text), plus its own motion:
--   toxic     rising bubbles
--   flame     (Ember, Inferno, Titan, ...) drifting embers and a low glow
--   golden    (Golden, Royal, Living Legend, Gemstone) turning light rays and sparkles
--   frost     frost cracks that glint and slow flakes
--   electric  (Storm, Neon, Forged) a faint lightning flash now and then, drifting sparks
--   smoke     (Shadow, Void, Blood Moon) slow smoke
--   stars     (Galaxy) twinkling stars and a slow nebula
-- A locked ("???") aura: the same theme much darker and still.
--   local backdrop = AuraBackdrop.New(parent, cornerRadius, orbCenter: UDim2)
--   backdrop:Set(aura, locked)   -- (Config/Auras entry)
-- It only moves while it's on screen (and not with Reduced Motion).
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local AlterFX = require(script.Parent.Parent.VFX.AlterFX)

local New = Theme.New
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local AuraBackdrop = {}
AuraBackdrop.__index = AuraBackdrop
local live = {}

local function kindOf(aura): string
	if aura.vfx == "golden" or aura.vfx == "royal" then return "golden" end
	if aura.style == "toxic" or aura.style == "frost" or aura.style == "electric" or aura.style == "smoke" or aura.style == "stars" then return aura.style end
	return "flame"
end
AuraBackdrop.KindOf = kindOf

local function dot(parent, color: Color3, size: number, props)
	local f = New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 2,
		Parent = parent }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	for k, v in pairs(props or {}) do f[k] = v end
	return f
end

function AuraBackdrop.New(parent: GuiObject, corner: number, orbCenter: UDim2)
	local self = setmetatable({ rng = Random.new(), orb = orbCenter, parts = {}, key = nil }, AuraBackdrop)
	-- the dark gradient (static, rounded like the panel)
	self.base = New("Frame", { Name = "AuraBackdrop", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, corner) }),
	})
	self.gradient = New("UIGradient", { Rotation = 90, Parent = self.base })
	-- the moving layer: in a frame inset by ~0.3 of the corner radius (ClipsDescendants clips square: no corner pokes out)
	local inset = math.ceil(corner * 0.3)
	self.layer = New("Frame", { Name = "Motion", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset), ZIndex = 1, Parent = parent })
	-- a locked aura: much darker
	self.shade = New("Frame", { Name = "LockedShade", BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 2, Visible = false,
		Parent = parent }, { New("UICorner", { CornerRadius = UDim.new(0, corner) }) })
	live[self] = true
	parent.Destroying:Connect(function() live[self] = nil end)
	return self
end

function AuraBackdrop:Set(aura, locked: boolean?)
	local key = aura.id .. "|" .. tostring(locked == true)
	if key == self.key then return end
	self.key = key
	self.locked = locked == true
	local main, light = aura.colors[1], aura.colors[2] or aura.colors[1]
	-- (a near-black colour, e.g. Shadow's second one, would make it all black: the brighter of the two leads)
	local _, _, value = main:ToHSV()
	if value < 0.25 then main, light = light, main end
	self.kind = kindOf(aura)
	self.main, self.light = main, light
	self.gradient.Color = ColorSequence.new(main:Lerp(BLACK, 0.62), main:Lerp(BLACK, 0.9))
	self.shade.Visible = self.locked
	self.layer:ClearAllChildren()
	local parts = { rings = {} }
	self.parts = parts
	local rng = self.rng
	local layer = self.layer
	-- the soft rings spreading from the orb (every look)
	for i = 1, 3 do
		local ring = New("Frame", { Name = "Ring" .. i, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = self.orb, Size = UDim2.fromOffset(60, 60),
			ZIndex = 1, Parent = layer }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local stroke = New("UIStroke", { Color = main, Thickness = 2, Transparency = 0.7, Parent = ring })
		table.insert(parts.rings, { f = ring, s = stroke, phase = (i - 1) / 3 })
	end
	local kind = self.kind
	if kind == "toxic" then
		parts.bubbles = {}
		for _ = 1, 10 do
			local size = rng:NextInteger(4, 10)
			local b = dot(layer, light, size, { BackgroundTransparency = 0.85 })
			New("UIStroke", { Color = light, Thickness = 1.2, Transparency = 0.35, Parent = b })
			table.insert(parts.bubbles, { f = b, x = rng:NextNumber(0.06, 0.94), speed = rng:NextNumber(0.05, 0.11), phase = rng:NextNumber(), sway = rng:NextNumber(0.01, 0.03) })
		end
	elseif kind == "flame" then
		AlterFX.Image(layer, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1.25), Size = UDim2.fromScale(1.6, 0.8),
			ImageColor3 = main, ImageTransparency = 0.55, ZIndex = 1 })
		parts.embers = {}
		for _ = 1, 14 do
			local e = dot(layer, if rng:NextNumber() < 0.5 then light else main, rng:NextInteger(2, 4))
			table.insert(parts.embers, { f = e, x = rng:NextNumber(0.05, 0.95), speed = rng:NextNumber(0.08, 0.16), phase = rng:NextNumber(), sway = rng:NextNumber(0.02, 0.05) })
		end
	elseif kind == "golden" then
		local rays = New("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = self.orb, Size = UDim2.fromOffset(420, 420),
			ZIndex = 1, Parent = layer })
		for i = 0, 5 do
			New("Frame", { BackgroundColor3 = light, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, if i % 2 == 0 then 34 else 18, 1, 0), Rotation = i * 30, BackgroundTransparency = 0.8, ZIndex = 1, Parent = rays }, {
				New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(1, 1) }) }),
			})
		end
		parts.rays = rays
		parts.sparkles = {}
		for _ = 1, 7 do
			local s = New("Frame", { BackgroundColor3 = light, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Size = UDim2.fromOffset(4, 4),
				Position = UDim2.fromScale(rng:NextNumber(0.08, 0.92), rng:NextNumber(0.1, 0.9)), ZIndex = 2, Parent = layer })
			table.insert(parts.sparkles, { f = s, phase = rng:NextNumber() * 6 })
		end
	elseif kind == "frost" then
		parts.cracks = {}
		for _ = 1, 7 do
			local c = New("Frame", { BackgroundColor3 = light, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(rng:NextInteger(30, 70), 1),
				Position = UDim2.fromScale(rng:NextNumber(0.1, 0.9), rng:NextNumber(0.1, 0.95)), Rotation = rng:NextNumber(-70, 70), ZIndex = 1, Parent = layer }, {
				New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
			})
			table.insert(parts.cracks, { f = c, phase = rng:NextNumber() * 6 })
		end
		parts.flakes = {}
		for _ = 1, 9 do
			local f = dot(layer, WHITE, rng:NextInteger(2, 3), { BackgroundTransparency = 0.3 })
			table.insert(parts.flakes, { f = f, x = rng:NextNumber(0.05, 0.95), speed = rng:NextNumber(0.04, 0.08), phase = rng:NextNumber(), sway = rng:NextNumber(0.01, 0.03) })
		end
	elseif kind == "electric" then
		parts.bolt = AlterFX.Image(layer, "lightning", { Name = "Bolt", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 0.9),
			ImageColor3 = light, ImageTransparency = 1, ZIndex = 1 })
		parts.flash = New("Frame", { Name = "Flash", BackgroundColor3 = light, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = layer })
		parts.nextFlash = os.clock() + rng:NextNumber(1, 2)
		parts.sparks = {}
		for _ = 1, 7 do
			local s = dot(layer, light, 2)
			table.insert(parts.sparks, { f = s, x = rng:NextNumber(0.05, 0.95), y = rng:NextNumber(0.1, 0.9), phase = rng:NextNumber() * 6 })
		end
	elseif kind == "smoke" then
		parts.smoke = {}
		for i = 1, 4 do
			local frame = rng:NextInteger(0, 15)
			local puff = AlterFX.Image(layer, "smoke", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 150), ImageColor3 = main:Lerp(WHITE, 0.25),
				ImageTransparency = 0.78, ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256), ZIndex = 1 })
			table.insert(parts.smoke, { f = puff, x = (i - 0.5) / 4, speed = rng:NextNumber(0.02, 0.04), phase = rng:NextNumber(), spin = rng:NextNumber(-8, 8) })
		end
	elseif kind == "stars" then
		parts.nebula = {
			AlterFX.Image(layer, "ember", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.55), Size = UDim2.fromOffset(200, 160), ImageColor3 = main,
				ImageTransparency = 0.45, ZIndex = 1 }),
			AlterFX.Image(layer, "ember", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.75, 0.3), Size = UDim2.fromOffset(170, 140), ImageColor3 = light,
				ImageTransparency = 0.75, ZIndex = 1 }),
		}
		parts.stars = {}
		for _ = 1, 24 do
			local s = dot(layer, WHITE, rng:NextInteger(1, 3), { Position = UDim2.fromScale(rng:NextNumber(0.03, 0.97), rng:NextNumber(0.03, 0.97)) })
			table.insert(parts.stars, { f = s, phase = rng:NextNumber() * 6, speed = rng:NextNumber(1.5, 3.5) })
		end
	end
	self:Paint(os.clock())
end

-- one step (a locked aura stays still: the first frame)
function AuraBackdrop:Paint(t: number)
	local parts = self.parts
	if self.locked then t = 0 end
	for _, r in ipairs(parts.rings or {}) do
		local k = (t * 0.22 + r.phase) % 1
		r.f.Size = UDim2.fromOffset(60 + k * 220, 60 + k * 220)
		r.s.Transparency = 0.55 + 0.45 * k
	end
	local function rise(list, fade)
		for _, p in ipairs(list or {}) do
			local k = (t * p.speed + p.phase) % 1
			p.f.Position = UDim2.fromScale(p.x + p.sway * math.sin(t * 1.6 + p.phase * 9), 1.05 - k * 1.1)
			if fade then p.f.BackgroundTransparency = 0.15 + 0.85 * k end
		end
	end
	rise(parts.bubbles, false)
	rise(parts.embers, true)
	for _, p in ipairs(parts.flakes or {}) do
		local k = (t * p.speed + p.phase) % 1
		p.f.Position = UDim2.fromScale(p.x + p.sway * math.sin(t + p.phase * 7), -0.05 + k * 1.1)
	end
	if parts.rays then parts.rays.Rotation = (t * 6) % 360 end
	for _, s in ipairs(parts.sparkles or {}) do s.f.BackgroundTransparency = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2.4 + s.phase)) end
	for _, c in ipairs(parts.cracks or {}) do c.f.BackgroundTransparency = 0.35 + 0.5 * (0.5 + 0.5 * math.sin(t * 1.3 + c.phase)) end
	for _, s in ipairs(parts.sparks or {}) do
		s.f.Position = UDim2.fromScale(s.x + 0.03 * math.sin(t * 0.7 + s.phase), s.y + 0.03 * math.cos(t * 0.9 + s.phase))
		s.f.BackgroundTransparency = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * 5 + s.phase))
	end
	if parts.bolt then
		local now = os.clock()
		if not self.locked and now >= parts.nextFlash then
			parts.nextFlash = now + self.rng:NextNumber(1.6, 3)
			parts.flashAt = now
			local frame = self.rng:NextInteger(0, 15)
			parts.bolt.ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256)
			parts.bolt.Position = UDim2.fromScale(self.rng:NextNumber(0.25, 0.75), 0)
		end
		local since = now - (parts.flashAt or -10)
		local on = since < 0.06 or (since > 0.12 and since < 0.17)
		parts.bolt.ImageTransparency = if on then 0.35 elseif since < 0.3 then 0.75 else 1
		parts.flash.BackgroundTransparency = if on then 0.88 else 1
	end
	for _, p in ipairs(parts.smoke or {}) do
		local k = (t * p.speed + p.phase) % 1
		p.f.Position = UDim2.fromScale(p.x + 0.08 * math.sin(t * 0.3 + p.phase * 6), 1.1 - k * 1.3)
		p.f.Rotation = t * p.spin
		p.f.ImageTransparency = 0.7 + 0.3 * math.abs(k - 0.5) * 2
	end
	for _, s in ipairs(parts.stars or {}) do s.f.BackgroundTransparency = 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * s.speed + s.phase)) end
	if parts.nebula then
		parts.nebula[1].Position = UDim2.fromScale(0.3 + 0.05 * math.sin(t * 0.15), 0.55)
		parts.nebula[2].Position = UDim2.fromScale(0.75, 0.3 + 0.05 * math.cos(t * 0.12))
	end
end

-- on screen: its ScreenGui is on and every frame above it is visible
local function shown(self): boolean
	local node = self.base
	if not node.Parent or node.AbsoluteSize.X < 2 then return false end
	while node do
		if node:IsA("ScreenGui") then return node.Enabled end
		if node:IsA("GuiObject") and not node.Visible then return false end
		node = node.Parent
	end
	return false
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then return end
	acc = 0
	if Theme.ReducedMotion() then return end
	local t = os.clock()
	for backdrop in pairs(live) do
		if backdrop.key and not backdrop.locked and shown(backdrop) then backdrop:Paint(t) end
	end
end)

return AuraBackdrop
