-- RollCardFX (prompt 56, 23 Oct): the roll result card's own animated background and the faint version of it on the screen
-- behind (TrainerClient's roll reveal). Every number is in Config.RollReveal (Themes, Alive). Code-drawn with the aura
-- textures (AlterFX.TEX) and the hex texture; no new images.
--   * Themes (by trainer, else by rarity): Volta = a dark blue storm (lightning behind him, sparks crawling round the
--     border); Duke = dark steel with glowing orange forge cracks and drifting sparks; The Shadow = black-purple smoke and
--     two purple eyes glinting; Atlas = warm gold with white-gold clouds, slow light beams and a faint laurel; Common-Epic
--     = the hex texture in the rarity colour with a few soft drifting dots (calm).
--   * Alive: the art breathes (a slow swell, a small flex now and then), a light sheen follows the tilt, Legendary+ cards
--     let small particles escape from their edges (sparks, embers, smoke, petals).
--   * The screen: storm = lightning flashes light up the dark world; forge = embers; smoke = slow purple smoke at the
--     bottom; clouds = soft light beams from the top; the rest: the reveal's own haze and dots in the rarity colour.
--   * Light on phones: a few particles each (half with low graphics), everything stops when the reveal closes (the
--     caller destroys it). Reduced Motion: no flicker (no lightning, no flashes), no tilt.
--   local fx = RollCardFX.Card({ card = Frame, clip = Frame, pop = Frame, art = ImageLabel, size = Vector2 (the card,
--     mockup px), artTop = px, artHeight = px, artWidth = share, artX = share (the picture's middle; prompt 57: the
--     phones' side card has it on the left; default 0.5), theme = RollCardFX.ThemeFor(trainer, rarity),
--     escape = bool })
--   fx:Step(t, dt)  fx:Tilt(x, y) (-1..1)
--   local screen = RollCardFX.Screen(layer, theme, { flash = function(alpha) end })  screen:Step(t, dt)  screen:Destroy()
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = script.Parent.Parent
local RollReveal = require(Shared.Config.RollReveal)
local Theme = require(script.Parent.Theme)
local AlterFX = require(Shared.VFX.AlterFX)

local New = Theme.New
local A = RollReveal.Alive

local RollCardFX = {}

local function tween(instance, props, time, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function hex(c) return Color3.fromHex(c) end
local function sequence(list)
	local keys = {}
	for i, c in ipairs(list) do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), hex(c))) end
	return ColorSequence.new(keys)
end
local function budget(n: number): number
	return if AlterFX.LowGraphics() then math.max(1, math.floor(n / 2)) else n
end

-- the theme of a trainer's card: his own (Config.RollReveal.Themes by id), else his rarity's colour on the hex
function RollCardFX.ThemeFor(trainer, rarity)
	local own = RollReveal.Themes[trainer.id]
	if own then return own end
	local c = if rarity.id == "Secret" then rarity.color2 else rarity.color
	local dark = hex(c):Lerp(hex("#0B0A0D"), 0.88):ToHex()
	return { kind = "hex", color = c, bg = { "#" .. dark, "#141317", "#0E0D10" }, particle = { texture = "ember", color = c } }
end

------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------
local Card = {}
Card.__index = Card

function RollCardFX.Card(spec)
	local theme = spec.theme
	local self = setmetatable({ spec = spec, theme = theme, kind = theme.kind, clip = spec.clip, pop = spec.pop, art = spec.art, reduced = Theme.ReducedMotion(),
		rng = Random.new(), tiltX = 0, tiltY = 0, live = {}, nextEscape = 0, nextStrike = 1.2, strike = nil, flexAt = A.flexEvery * 0.5 }, Card)
	local card, clip, size = spec.card, spec.clip, spec.size
	self.color = hex(theme.color)
	-- the base: the theme's dark gradient (top to bottom)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	New("UIGradient", { Name = "ThemeBase", Rotation = 90, Color = sequence(theme.bg), Parent = card })
	-- the hex in the theme colour (Common-Epic: ~18%; the trainer themes much fainter, their own layers show instead)
	local hexImage = card:FindFirstChild("Hex")
	if hexImage then
		hexImage.ImageColor3 = self.color:Lerp(Color3.new(1, 1, 1), 0.25)
		hexImage.ImageTransparency = if self.kind == "hex" then A.hexTransparency else 0.94
	end
	local artMid = (spec.artTop + spec.artHeight * 0.42) / size.Y
	local artX = spec.artX or 0.5
	self.artMid, self.artX = artMid, artX
	-- the art breathes from his feet
	if self.art then
		self.art.AnchorPoint = Vector2.new(0.5, 1)
		self.art.Position = UDim2.new(artX, 0, 0, spec.artTop + spec.artHeight)
		self.artBase = Vector2.new(spec.artWidth, spec.artHeight)
	end
	-- the sheen: a faint light band over his art that follows the tilt
	self.sheenFrame = New("Frame", { Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.87, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(artX, 0, 0, spec.artTop - 6), Size = UDim2.new(math.min(1, spec.artWidth), 0, 0, spec.artHeight + 6),
		ZIndex = 7, Parent = card })
	self.sheen = New("UIGradient", { Rotation = 25, Offset = Vector2.new(-0.3, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }),
		Parent = self.sheenFrame })
	-- the soft radial light behind him
	AlterFX.Image(clip, "ember", { Name = "Radial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(artX, artMid), Size = UDim2.new(spec.artWidth * 1.16, 0, 0, spec.artHeight * 1.05),
		ImageColor3 = self.color, ImageTransparency = if self.kind == "clouds" then 0.35 else 0.55, ZIndex = 5 })
	local build = self["build_" .. self.kind]
	if build then build(self) end
	return self
end

-- drifting dots / embers inside the card (rising slowly, looping)
function Card:dots(count: number, texture: string, color: Color3, speed: number, sizeRange: Vector2)
	self.drift = self.drift or {}
	for _ = 1, budget(count) do
		local s = self.rng:NextNumber(sizeRange.X, sizeRange.Y)
		local label = AlterFX.Image(self.clip, texture, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(s, s), ImageColor3 = color, ImageTransparency = 1,
			ZIndex = 5 })
		table.insert(self.drift, { label = label, x = self.rng:NextNumber(0.08, 0.92), phase = self.rng:NextNumber(), speed = speed * self.rng:NextNumber(0.7, 1.3) })
	end
end

-- Common-Epic: the hex and a few calm dots
function Card:build_hex()
	self:dots(A.hexDots, "ember", self.color:Lerp(Color3.new(1, 1, 1), 0.3), 0.07, Vector2.new(6, 12))
end

-- Volta: lightning behind him, sparks crawling round the border
function Card:build_storm()
	self.bolts = {}
	for i = 1, 2 do
		local bolt = AlterFX.Image(self.clip, "lightning", { Name = "Bolt" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.67 * self.spec.artWidth, 0.62),
			ImageColor3 = hex("#BFE4FF"), ImageTransparency = 1, ZIndex = 5 })
		self.bolts[i] = bolt
	end
	self.flashFrame = New("Frame", { Name = "Flash", BackgroundColor3 = hex("#9FD0FF"), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 5, Parent = self.clip })
	self.crawlers = {}
	for i = 1, budget(A.borderSparks) do
		local spark = AlterFX.Image(self.pop, "spark", { Name = "Crawl" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), ImageColor3 = hex("#CFEAFF"),
			ZIndex = 6 })
		table.insert(self.crawlers, { label = spark, at = (i - 1) / A.borderSparks, speed = self.rng:NextNumber(0.06, 0.1) * (if i % 2 == 0 then -1 else 1) })
	end
	self:dots(3, "spark", hex("#7FC0FF"), 0.05, Vector2.new(6, 10))
end

-- Duke: dark steel, glowing orange cracks, drifting sparks
function Card:build_forge()
	local size = self.spec.size
	self.cracks = {}
	local rng = self.rng
	local starts = { Vector2.new(0, 0.22), Vector2.new(1, 0.4), Vector2.new(0.15, 1), Vector2.new(0.9, 0.95), Vector2.new(0.6, 0) }
	for i, start in ipairs(starts) do
		local p = Vector2.new(start.X * size.X, start.Y * size.Y)
		local toward = (Vector2.new(size.X * self.artX, size.Y * self.artMid) - p).Unit
		for _ = 1, 4 do
			local angle = math.atan2(toward.Y, toward.X) + rng:NextNumber(-0.7, 0.7)
			local length = rng:NextNumber(14, 26)
			local q = p + Vector2.new(math.cos(angle), math.sin(angle)) * length
			local mid = (p + q) / 2
			for layer = 1, 2 do
				local line = New("Frame", { Name = "Crack" .. i, BackgroundColor3 = if layer == 1 then hex("#FF6A10") else hex("#FFD08A"), BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mid.X, mid.Y), Size = UDim2.fromOffset(length + 2, if layer == 1 then 5 else 1.5),
					Rotation = math.deg(angle), BackgroundTransparency = 1, ZIndex = 5, Parent = self.clip }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				table.insert(self.cracks, { line = line, glow = layer == 1, phase = i * 1.3 })
			end
			p = q
		end
	end
	self:dots(A.forgeEmbers, "ember", hex("#FF9A3A"), 0.16, Vector2.new(5, 9))
end

-- The Shadow: black-purple smoke drifting, two purple eyes glinting
function Card:build_smoke()
	self.smoke = {}
	for i = 1, budget(3) do
		local puff = AlterFX.Image(self.clip, "smoke", { Name = "Smoke" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(1.1, 0.75),
			ImageColor3 = if i % 2 == 0 then hex("#7A3CB0") else hex("#4E2478"), ImageTransparency = 0.35, ZIndex = 5 })
		AlterFX.AnimateFlipbook(puff, 8)
		table.insert(self.smoke, { label = puff, phase = (i - 1) / 3, x = 0.3 + 0.2 * i })
	end
	self.eyes = {}
	local aw = self.spec.artWidth
	for i, x in ipairs({ self.artX - 0.3 * aw, self.artX - 0.21 * aw }) do
		local glow = AlterFX.Image(self.clip, "ember", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.11), Size = UDim2.fromOffset(26, 18),
			ImageColor3 = hex("#B65CFF"), ImageTransparency = 1, ZIndex = 5 })
		local eye = New("Frame", { Name = "Eye" .. i, BackgroundColor3 = hex("#E6C8FF"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.11),
			Size = UDim2.fromOffset(9, 3), Rotation = if i == 1 then 8 else -8, BackgroundTransparency = 1, ZIndex = 5, Parent = self.clip },
			{ New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		table.insert(self.eyes, { eye = eye, glow = glow })
	end
	self.nextGlint = 0.8
end

-- Atlas: warm gold, white-gold clouds, slow light beams, a faint laurel
function Card:build_clouds()
	local size = self.spec.size
	self.beams = {}
	for i, x in ipairs({ 0.28, 0.52, 0.76 }) do
		-- (a soft light shaft: the round glow stretched long, fading down)
		local beam = AlterFX.Image(self.clip, "ember", { Name = "Beam" .. i, ImageColor3 = hex("#FFF3C4"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, -0.3),
			Size = UDim2.new(0, 34 + i * 6, 1.5, 0), ImageTransparency = 0.4, ZIndex = 5 })
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.5),
			NumberSequenceKeypoint.new(1, 1) }), Parent = beam })
		table.insert(self.beams, { beam = beam, base = -14 + i * 9, phase = i * 1.9 })
	end
	self.clouds = {}
	for i = 1, budget(3) do
		local puff = AlterFX.Image(self.clip, "smoke", { Name = "Cloud" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(1, 0.42),
			ImageColor3 = hex("#FFF6E0"), ImageTransparency = 0.45, ZIndex = 5, ImageRectOffset = Vector2.new((i % 4) * 256, 256) })
		table.insert(self.clouds, { label = puff, y = 0.12 + (i - 1) * 0.24, phase = i * 0.37, speed = 0.025 + i * 0.006 })
	end
	-- the laurel: a big faint wreath behind him, two branches of leaves meeting at the bottom, open at the top
	local center = Vector2.new(size.X * self.artX, self.spec.artTop + self.spec.artHeight * 0.36)
	local radius = math.min(size.X * self.spec.artWidth * 0.36, self.spec.artHeight * 0.45)
	for side = -1, 1, 2 do
		for k = 0, 8 do
			local a = math.rad(90 + side * (18 + k * 16)) -- (from the bottom up each side)
			local p = center + Vector2.new(math.cos(a), math.sin(a)) * radius
			for _, lean in ipairs({ -1, 1 }) do -- (a pair of leaves on the stem, either side)
				New("Frame", { Name = "Leaf", BackgroundColor3 = hex("#FFE7A3"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(p.X + math.cos(a) * lean * 5, p.Y + math.sin(a) * lean * 5), Size = UDim2.fromOffset(5, 12),
					Rotation = math.deg(a) + 90 + side * lean * 40, BackgroundTransparency = 0.7, ZIndex = 5, Parent = self.clip },
					{ New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			end
		end
	end
end

-- a point on the card's outline (0..1 round it, clockwise from the top-left), in the pop's scale
local function perimeter(k: number, aspect: number): UDim2
	k %= 1
	local w, h = 1, aspect
	local d = k * 2 * (w + h)
	if d < w then return UDim2.fromScale(d / w, 0) end
	d -= w
	if d < h then return UDim2.fromScale(1, d / h) end
	d -= h
	if d < w then return UDim2.fromScale(1 - d / w, 1) end
	d -= w
	return UDim2.fromScale(0, 1 - d / h)
end

-- Legendary+: a small particle escapes from a point on the edge, outward and up, and fades
function Card:escape()
	local p = self.theme.particle
	local rng = self.rng
	local k = rng:NextNumber()
	local at = perimeter(k, self.spec.size.Y / self.spec.size.X)
	local out = Vector2.new(at.X.Scale - 0.5, at.Y.Scale - 0.5).Unit
	local s = rng:NextNumber(8, 14) * (if p.texture == "smoke" then 2.2 else 1)
	local label = AlterFX.Image(self.pop, p.texture, { AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ImageColor3 = hex(p.color),
		ImageTransparency = if p.texture == "smoke" then 0.4 else 0.05, Rotation = rng:NextNumber(0, 360), ZIndex = 6 })
	if p.texture == "smoke" then label.ImageRectOffset = Vector2.new(rng:NextInteger(0, 3) * 256, rng:NextInteger(0, 3) * 256) end
	local life = rng:NextNumber(0.9, 1.4)
	local dist = rng:NextNumber(18, 36)
	tween(label, { Position = at + UDim2.fromOffset(out.X * dist, out.Y * dist - 14), Rotation = label.Rotation + rng:NextNumber(-120, 120),
		ImageTransparency = 1, Size = UDim2.fromOffset(s * 0.5, s * 0.5) }, life, Enum.EasingStyle.Sine)
	table.insert(self.live, os.clock() + life)
	Debris:AddItem(label, life + 0.05)
end

function Card:Tilt(x: number, y: number)
	self.tiltX, self.tiltY = x, y
end

function Card:Step(t: number, dt: number)
	-- the breath (a slow swell) and now and then a short flex
	if self.art then
		local breath = math.sin(t * 2 * math.pi / A.breathPeriod)
		local since = (t - self.flexAt) % A.flexEvery
		local flex = if since < A.flexTime then math.sin(since / A.flexTime * math.pi) else 0
		local grow = A.breath * (0.5 + 0.5 * breath) + A.flex * flex
		self.art.Size = UDim2.new(self.artBase.X * (1 + grow * 0.7), 0, 0, self.artBase.Y * (1 + grow))
		self.art.Position = UDim2.new(self.artX, self.tiltX * A.artParallax, 0, self.spec.artTop + self.spec.artHeight)
	end
	-- the sheen follows the tilt (and drifts slowly on its own)
	self.sheen.Offset = Vector2.new(math.clamp(self.tiltX * 0.5 + 0.25 * math.sin(t * 0.5), -0.9, 0.9), 0)
	-- the drifting dots
	if self.drift then
		for _, d in ipairs(self.drift) do
			local k = (t * d.speed + d.phase) % 1
			d.label.Position = UDim2.fromScale(d.x + 0.03 * math.sin(t * 0.9 + d.phase * 7), 1.04 - k * 1.08)
			d.label.ImageTransparency = 0.3 + 0.7 * math.abs(k * 2 - 1)
		end
	end
	local kind = self.kind
	if kind == "storm" then
		-- lightning behind him (Reduced Motion: none)
		if not self.reduced then
			if not self.strike and t >= self.nextStrike then
				local bolt = self.bolts[self.rng:NextInteger(1, #self.bolts)]
				local side = if self.rng:NextNumber() < 0.5 then -1 else 1
				bolt.Position = UDim2.fromScale(self.artX + side * 0.23 * self.spec.artWidth, self.rng:NextNumber(0.2, 0.4))
				bolt.ImageRectOffset = Vector2.new(self.rng:NextInteger(0, 3) * 256, self.rng:NextInteger(0, 3) * 256)
				bolt.Rotation = self.rng:NextNumber(-15, 15)
				self.strike = { bolt = bolt, at = t }
			end
			if self.strike then
				local e = t - self.strike.at
				-- on, off, on, fade
				local alpha = if e < 0.05 then 0.05 elseif e < 0.1 then 0.9 elseif e < 0.18 then 0.15 elseif e < 0.5 then 0.15 + (e - 0.18) / 0.32 * 0.85 else 1
				self.strike.bolt.ImageTransparency = alpha
				self.flashFrame.BackgroundTransparency = 0.72 + 0.28 * alpha
				if e >= 0.5 then
					self.strike = nil
					self.nextStrike = t + self.rng:NextNumber(A.strikeEvery.X, A.strikeEvery.Y)
				end
			end
		end
		local aspect = self.spec.size.Y / self.spec.size.X
		for _, c in ipairs(self.crawlers) do
			c.at += c.speed * dt
			c.label.Position = perimeter(c.at, aspect)
			local flick = 0.5 + 0.5 * math.sin(t * 23 + c.at * 40)
			c.label.ImageTransparency = if self.reduced then 0.2 else 0.05 + 0.35 * flick
			c.label.Rotation = t * 240
		end
	elseif kind == "forge" then
		for _, c in ipairs(self.cracks) do
			local glow = 0.5 + 0.5 * math.sin(t * 1.8 + c.phase)
			c.line.BackgroundTransparency = if c.glow then 0.55 - 0.3 * glow else 0.35 - 0.3 * glow
		end
	elseif kind == "smoke" then
		for _, s in ipairs(self.smoke) do
			local k = (t * 0.045 + s.phase) % 1
			s.label.Position = UDim2.fromScale(s.x + 0.08 * math.sin(t * 0.3 + s.phase * 6), 1.15 - k * 1.3)
			s.label.ImageTransparency = 0.15 + 0.75 * math.abs(k * 2 - 1)
		end
		-- the eyes: a slow glint now and then
		if t >= self.nextGlint then
			self.glintAt = t
			self.nextGlint = t + self.rng:NextNumber(2.5, 4.5)
		end
		local e = if self.glintAt then t - self.glintAt else 99
		local alpha = if e < 0.35 then 1 - e / 0.35 elseif e < 1.1 then 0 elseif e < 1.6 then (e - 1.1) / 0.5 else 1
		for _, eye in ipairs(self.eyes) do
			eye.eye.BackgroundTransparency = alpha
			eye.glow.ImageTransparency = 0.3 + 0.7 * alpha
		end
	elseif kind == "clouds" then
		for _, b in ipairs(self.beams) do
			b.beam.Rotation = b.base + 4 * math.sin(t * 0.35 + b.phase)
			b.beam.ImageTransparency = 0.3 + 0.35 * (0.5 + 0.5 * math.sin(t * 0.6 + b.phase))
		end
		for _, c in ipairs(self.clouds) do
			local k = (t * c.speed + c.phase) % 1
			c.label.Position = UDim2.fromScale(-0.4 + k * 1.8, c.y + 0.02 * math.sin(t * 0.4 + c.phase * 5))
		end
	end
	-- Legendary+: particles escape from the edges (a few at a time)
	if self.spec.escape then
		local now = os.clock()
		for i = #self.live, 1, -1 do
			if self.live[i] <= now then table.remove(self.live, i) end
		end
		if t >= self.nextEscape and #self.live < budget(A.escapeMax) then
			self:escape()
			self.nextEscape = t + 1 / A.escapeRate * self.rng:NextNumber(0.6, 1.4)
		end
	end
end

------------------------------------------------------------------------
-- The screen behind (faint)
------------------------------------------------------------------------
local Screen = {}
Screen.__index = Screen

function RollCardFX.Screen(layer: GuiObject, theme, hooks)
	local self = setmetatable({ layer = layer, kind = theme.kind, theme = theme, hooks = hooks or {}, reduced = Theme.ReducedMotion(), rng = Random.new(), items = {},
		nextStrike = 0.6, folder = New("Frame", { Name = "Theme", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = layer }) }, Screen)
	local folder = self.folder
	if self.kind == "storm" then
		self.flashFrame = New("Frame", { Name = "Flash", BackgroundColor3 = hex("#7FB8FF"), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ZIndex = 1, Parent = folder })
	elseif self.kind == "smoke" then
		for i = 1, budget(3) do
			local puff = AlterFX.Image(folder, "smoke", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromScale(0.6, 0.55), ImageColor3 = hex("#5A2484"),
				ImageTransparency = 0.5, ZIndex = 1 })
			AlterFX.AnimateFlipbook(puff, 6)
			table.insert(self.items, { label = puff, x = -0.1 + i * 0.3, phase = i * 1.7 })
		end
	elseif self.kind == "clouds" then
		for i, x in ipairs({ 0.22, 0.5, 0.78 }) do
			-- (soft light shafts: the round glow stretched long, fading down)
			local beam = AlterFX.Image(folder, "ember", { ImageColor3 = hex("#FFF3C4"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, -0.35),
				Size = UDim2.new(0.16, 0, 1.6, 0), ImageTransparency = 0.75, ZIndex = 1 })
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.6),
				NumberSequenceKeypoint.new(1, 1) }), Parent = beam })
			table.insert(self.items, { beam = beam, base = -18 + i * 9, phase = i * 2.1 })
		end
	elseif self.kind == "forge" then
		for i = 1, budget(8) do
			local s = self.rng:NextNumber(4, 8)
			local ember = AlterFX.Image(folder, "ember", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(s, s), ImageColor3 = hex("#FF8A2A"), ZIndex = 1 })
			table.insert(self.items, { label = ember, x = self.rng:NextNumber(), phase = self.rng:NextNumber(), speed = self.rng:NextNumber(0.08, 0.14), i = i })
		end
	end
	return self
end

function Screen:Step(t: number)
	local kind = self.kind
	if kind == "storm" and not self.reduced then
		-- a lightning flash lights up the dark world now and then (a double flicker)
		if not self.strikeAt and t >= self.nextStrike then self.strikeAt = t end
		if self.strikeAt then
			local e = t - self.strikeAt
			local light = if e < 0.06 then 1 elseif e < 0.12 then 0.2 elseif e < 0.2 then 0.8 elseif e < 0.6 then 0.8 * (1 - (e - 0.2) / 0.4) else 0
			self.flashFrame.BackgroundTransparency = 1 - A.screenFlash * light
			if self.hooks.flash then self.hooks.flash(light) end
			if e >= 0.6 then
				self.strikeAt = nil
				self.nextStrike = t + self.rng:NextNumber(A.strikeEvery.X + 0.6, A.strikeEvery.Y + 1.2)
			end
		end
	elseif kind == "smoke" then
		for _, s in ipairs(self.items) do
			s.label.Position = UDim2.fromScale(s.x + 0.06 * math.sin(t * 0.18 + s.phase), 1.08 + 0.04 * math.sin(t * 0.25 + s.phase))
		end
	elseif kind == "clouds" then
		for _, b in ipairs(self.items) do
			b.beam.Rotation = b.base + 5 * math.sin(t * 0.25 + b.phase)
			b.beam.ImageTransparency = 0.7 + 0.15 * (0.5 + 0.5 * math.sin(t * 0.5 + b.phase))
		end
	elseif kind == "forge" then
		for _, e in ipairs(self.items) do
			local k = (t * e.speed + e.phase) % 1
			e.label.Position = UDim2.fromScale(e.x + 0.02 * math.sin(t * 1.3 + e.i), 1.02 - k * 0.8)
			e.label.ImageTransparency = 0.2 + 0.8 * k
		end
	end
end

function Screen:Destroy()
	if self.hooks.flash then self.hooks.flash(0) end
	self.folder:Destroy()
end

return RollCardFX
