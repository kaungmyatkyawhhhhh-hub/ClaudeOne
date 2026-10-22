-- TrainerTile (prompt 33, 22 Oct): ONE trainer tile (mockups trainers_inventory_v5 / trainer_evolutions_v5), used by MY
-- TRAINERS (the grid, the detail panel, the evolutions chart) and the evolve moment.
--   * A dark base in the stage's hue, the gym-mat hex mesh over it (~40%), a soft radial glow behind his head; the stage's
--     effect on top (BASE none): IRON-BORN pulsing cracks + rising sparks, BEAST-MODE a turning green swirl + flashing claw
--     slashes (the hex again on top), COLOSSUS rain + a lightning flash every 1-2 s, LIMITLESS a turning rainbow spiral +
--     twinkling stars and a hue-shifting border (the hex again on top). All made from frames, gradients and the FX
--     textures we already have (no pictures: owner, 22 Oct). Animated only while the tile is on screen.
--   * His live 3D rig (Shared/UI/TrainerPortrait; no pictures) big, head near the top, a rim light in the stage color.
--   * The stack: his name (white chunky) -> him -> the stage name in its color (BASE white) -> "LV 20". A 4 px border in the
--     stage color (it only ever means the stage), a 2 px near-black ring inside it, a soft glow outside; EQUIPPED = a
--     thicker gold glow (gently pulsing) and a gold check badge on the right under the name.
--   * hidden = a stage you haven't discovered: a dark glitching version, "???" and "COMBINE 3 TO DISCOVER".
--   TrainerTile.New({ Name, LayoutOrder, Size, Position, AnchorPoint, Parent, px = its width in mockup px }) -> tile
--   tile:Set({ id, s, l, equipped, hidden, noLevel, caption }); tile.cell (the frame to place), tile.button (taps)
local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent
local Trainers = require(Shared.Config.Trainers)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local TrainerPortrait = require(script.Parent.TrainerPortrait)
local AlterFX = require(Shared.VFX.AlterFX)

local New = Theme.New
local INK = Color3.fromHex("#0A090B")
local GOLD = Color3.fromHex("#F6C75A")

local TrainerTile = {}
local live = {} -- [tile] = true (the animation loop's list)

local function C(hex: string): Color3 return Color3.fromHex(hex) end

-- chunky white text with a dark stroke (every word in a tile)
local function chunky(parent, name, text, size, color, props)
	local label = Kit.Text({ Name = name, Text = text, Font = "Chunky", TextSize = math.max(7, math.floor(size)), TextColor3 = color or Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0), ZIndex = 8, Parent = parent })
	for k, v in pairs(props or {}) do label[k] = v end
	local stroke = label:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = label })
	stroke.Color, stroke.Thickness, stroke.Transparency = INK, math.max(1.2, size * 0.12), 0
	return label
end

------------------------------------------------------------------------
-- The stage effects (built in the tile's Fx frame; tile.fx = the moving bits for the loop)
------------------------------------------------------------------------
local FX = {}
local function bit(parent, color, size: UDim2, pos: UDim2, props)
	local f = New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, Position = pos, ZIndex = 3, Parent = parent })
	for k, v in pairs(props or {}) do f[k] = v end
	return f
end

FX.IronBorn = function(layer, rng)
	local fx = { cracks = {}, sparks = {} }
	local orange = C("#FF7A1A")
	for i = 1, 5 do
		local crack = bit(layer, orange, UDim2.new(rng:NextNumber(0.35, 0.7), 0, 0, 2), UDim2.fromScale(rng:NextNumber(0.15, 0.85), rng:NextNumber(0.35, 0.95)),
			{ Rotation = rng:NextNumber(-60, 60), BackgroundTransparency = 0.3 })
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = crack })
		table.insert(fx.cracks, { f = crack, phase = i * 1.3 })
	end
	for i = 1, 7 do
		local spark = bit(layer, C("#FFD27A"), UDim2.fromOffset(3, 3), UDim2.fromScale(0.5, 1), { BackgroundTransparency = 0 })
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = spark })
		table.insert(fx.sparks, { f = spark, x = rng:NextNumber(0.08, 0.92), speed = rng:NextNumber(0.25, 0.45), phase = rng:NextNumber() })
	end
	return fx
end

FX.BeastMode = function(layer, rng)
	local fx = { slashes = {} }
	local swirl = New("Frame", { Name = "Swirl", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), SizeConstraint = Enum.SizeConstraint.RelativeXX, ZIndex = 3, Parent = layer })
	New("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C("#6BFF4F")), ColorSequenceKeypoint.new(0.5, C("#0B3A12")),
		ColorSequenceKeypoint.new(1, C("#9BFF7A")) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.25, 0.92),
		NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(0.75, 0.92), NumberSequenceKeypoint.new(1, 0.55) }), Parent = swirl })
	fx.swirl = swirl
	for i = 1, 3 do
		local slash = bit(layer, C("#D8FFD0"), UDim2.new(0.75, 0, 0, 3), UDim2.fromScale(0.3 + i * 0.12, 0.55 + i * 0.02), { Rotation = -38, BackgroundTransparency = 1 })
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = slash })
		table.insert(fx.slashes, slash)
	end
	return fx
end

FX.Colossus = function(layer, rng)
	local fx = { rain = {} }
	for i = 1, 9 do
		local drop = bit(layer, C("#9AD8FF"), UDim2.new(0, 1, 0.16, 0), UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), { Rotation = 18, BackgroundTransparency = 0.45 })
		table.insert(fx.rain, { f = drop, x = rng:NextNumber(0, 1.1), speed = rng:NextNumber(0.9, 1.4), phase = rng:NextNumber() })
	end
	fx.bolt = AlterFX.Image(layer, "lightning", { Name = "Bolt", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.9, 0.9),
		ImageColor3 = C("#DFF4FF"), ImageTransparency = 1, ZIndex = 3 })
	fx.flash = bit(layer, C("#CFEFFF"), UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { BackgroundTransparency = 1, ZIndex = 6 })
	fx.next = os.clock() + rng:NextNumber(0.8, 1.6)
	return fx
end

FX.Limitless = function(layer, rng)
	local fx = { stars = {} }
	local keys = {}
	local hues = { 0, 0.08, 0.16, 0.33, 0.5, 0.66, 0.8, 1 }
	for i, h in ipairs(hues) do keys[i] = ColorSequenceKeypoint.new((i - 1) / (#hues - 1), Color3.fromHSV(h % 1, 0.75, 1)) end
	local spiral = New("Frame", { Name = "Spiral", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.8, 1.8), SizeConstraint = Enum.SizeConstraint.RelativeXX, ZIndex = 3, Parent = layer }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	New("UIGradient", { Color = ColorSequence.new(keys), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.62), NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0.62) }), Parent = spiral })
	fx.spiral = spiral
	for i = 1, 9 do
		local star = bit(layer, Color3.new(1, 1, 1), UDim2.fromOffset(3, 3), UDim2.fromScale(rng:NextNumber(0.06, 0.94), rng:NextNumber(0.06, 0.94)), { Rotation = 45 })
		table.insert(fx.stars, { f = star, phase = rng:NextNumber() * 6 })
	end
	return fx
end

------------------------------------------------------------------------
-- A tile
------------------------------------------------------------------------
local Tile = {}
Tile.__index = Tile

function TrainerTile.New(props)
	local px = props.px or 80
	local self = setmetatable({ px = px, key = nil, rng = Random.new() }, Tile)
	local radius = math.max(8, math.floor(px * 0.11))
	self.radius = radius
	self.cell = New("Frame", { Name = props.Name or "Tile", LayoutOrder = props.LayoutOrder or 0, BackgroundTransparency = 1, Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, Parent = props.Parent })
	-- the soft glow outside (the stage color; gold and thicker when equipped)
	self.glow = New("Frame", { Name = "Glow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = self.cell }, {
		New("UICorner", { CornerRadius = UDim.new(0, radius + 2) }),
	})
	self.glowStroke = New("UIStroke", { Thickness = math.max(3, px * 0.05), Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = self.glow })
	self.button = New("TextButton", { Name = "Button", Text = "", AutoButtonColor = false, BackgroundColor3 = INK, Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
		ZIndex = 2, Parent = self.cell }, {
		New("UICorner", { CornerRadius = UDim.new(0, radius) }),
	})
	self.border = New("UIStroke", { Name = "Border", Thickness = math.max(2, px * 0.03), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = self.button })
	self.hex = New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(math.floor(px * 0.2), math.floor(px * 0.115)), ImageTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = self.button })
	self.radial = AlterFX.Image(self.button, "ember", { Name = "Radial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(1.25, 1.25), SizeConstraint = Enum.SizeConstraint.RelativeXX, ImageTransparency = 0.35, ZIndex = 2 })
	self.fxLayer = New("Frame", { Name = "Fx", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = self.button })
	self.hexTop = self.hex:Clone()
	self.hexTop.Name = "HexTop"
	self.hexTop.ImageTransparency = 0.65
	self.hexTop.ZIndex = 4
	self.hexTop.Visible = false
	self.hexTop.Parent = self.button
	self.artHolder = New("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(1.02, 0.62), ZIndex = 5, Parent = self.button })
	self.name = chunky(self.button, "Name", "", px * 0.115, nil, { Position = UDim2.fromScale(0.5, 0.025), Size = UDim2.fromScale(0.94, 0.13) })
	Kit.Fit(self.name, math.floor(px * 0.115), 7)
	self.stage = chunky(self.button, "Stage", "", px * 0.14, nil, { Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.96, 0.16) })
	Kit.Fit(self.stage, math.floor(px * 0.14), 7)
	self.level = chunky(self.button, "Level", "", px * 0.13, nil, { Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.94, 0.15) })
	Kit.Fit(self.level, math.floor(px * 0.13), 6, 2)
	-- the 2 px near-black ring just inside the border
	local ringInset = math.max(2, math.floor(px * 0.03))
	New("Frame", { Name = "InnerRing", BackgroundTransparency = 1, Position = UDim2.fromOffset(ringInset, ringInset), Size = UDim2.new(1, -2 * ringInset, 1, -2 * ringInset),
		ZIndex = 9, Parent = self.button }, {
		New("UICorner", { CornerRadius = UDim.new(0, math.max(2, radius - ringInset)) }),
		New("UIStroke", { Color = INK, Thickness = 2, Transparency = 0.1 }),
	})
	-- equipped: a gold circle check on the right, under the name
	local badge = math.max(12, math.floor(px * 0.15))
	self.check = New("Frame", { Name = "Check", BackgroundColor3 = GOLD, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -math.floor(px * 0.05), 0.15, 0),
		Size = UDim2.fromOffset(badge, badge), Visible = false, ZIndex = 10, Parent = self.button }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = INK, Thickness = 1.5 }),
	})
	Pieces.Icon("check", INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), ZIndex = 11,
		Parent = self.check }):SetAttribute("KeepColor", true)
	live[self] = true
	self.cell.Destroying:Connect(function() live[self] = nil end)
	return self
end

-- info = { id, s, l, equipped, hidden (a stage not discovered yet), noLevel, caption (instead of "LV n"), mini (no words: the
-- small tiles of the needs line) }
function Tile:Set(info)
	local stage = Trainers.Stages[info.s or 1] or Trainers.Stages[1]
	local trainer = Trainers.ById[info.id]
	self.info = info
	self.stageInfo = stage
	local color = C(stage.color)
	local hidden = info.hidden == true
	self.button.BackgroundColor3 = if hidden then C("#070608") else C(stage.base)
	self.hex.ImageColor3 = if hidden then C("#2A2830") else C(stage.hex):Lerp(Color3.new(1, 1, 1), 0.15)
	self.hexTop.ImageColor3 = self.hex.ImageColor3
	self.radial.ImageColor3 = if hidden then C("#3A3640") else color
	self.radial.ImageTransparency = if hidden then 0.6 else 0.35
	self.border.Color = if hidden then C("#3A3640") else color
	self.name.Text = string.upper(trainer and trainer.name or "")
	self.stage.Text = if hidden then "???" else stage.name
	self.stage.TextColor3 = if hidden then C("#8A878F") elseif stage.index == 1 then Color3.new(1, 1, 1) else color
	self.level.Text = if hidden then "COMBINE 3 TO DISCOVER" elseif info.caption then info.caption elseif info.noLevel then "" else "LV " .. (info.l or 1)
	self.level.TextColor3 = if hidden then C("#8A878F") else Color3.new(1, 1, 1)
	self.check.Visible = info.equipped == true and not hidden
	self.name.Visible, self.stage.Visible, self.level.Visible = not info.mini, not info.mini, not info.mini
	self.artHolder.Position = if info.mini then UDim2.fromScale(0.5, 0.04) else UDim2.fromScale(0.5, 0.12)
	self.artHolder.Size = if info.mini then UDim2.fromScale(1.05, 0.96) else UDim2.fromScale(1.02, 0.62)
	self.hexTop.Visible = not hidden and (stage.id == "BeastMode" or stage.id == "Limitless")
	-- the art and the effect only change when he or the stage does
	local key = tostring(info.id) .. "|" .. stage.id .. "|" .. tostring(hidden)
	if key ~= self.key then
		self.key = key
		self.artHolder:ClearAllChildren()
		if trainer then
			local art = TrainerPortrait.New(trainer.id, { Size = UDim2.fromScale(1, 1), shot = "bust", pose = "Relaxed", ZIndex = 5, Parent = self.artHolder,
				silhouette = hidden })
			art.LightColor = if hidden then Color3.new(0, 0, 0) else Color3.new(1, 1, 1):Lerp(color, 0.25)
		end
		self.fxLayer:ClearAllChildren()
		local build = FX[stage.id]
		self.fx = build and build(self.fxLayer, self.rng) or nil
	end
	self:Paint(os.clock())
end

-- one animation step (also the glow, which depends on equipped)
function Tile:Paint(t: number)
	local info, stage = self.info, self.stageInfo
	if not info then return end
	local color = C(stage.color)
	local hidden = info.hidden == true
	if info.equipped and not hidden then
		self.glowStroke.Color = GOLD
		self.glowStroke.Thickness = math.max(4, self.px * 0.07)
		self.glowStroke.Transparency = 0.35 + 0.2 * math.sin(t * 3)
	else
		self.glowStroke.Color = if hidden then C("#3A3640") else color
		self.glowStroke.Thickness = math.max(3, self.px * 0.05)
		self.glowStroke.Transparency = 0.55
	end
	local fx = self.fx
	if hidden then
		-- the glitch: the effect flickers dark
		self.fxLayer.Visible = math.floor(t * 9) % 5 == 0
		return
	end
	self.fxLayer.Visible = true
	if not fx then return end
	if stage.id == "IronBorn" then
		for _, c in ipairs(fx.cracks) do c.f.BackgroundTransparency = 0.25 + 0.55 * (0.5 + 0.5 * math.sin(t * 2.4 + c.phase)) end
		for _, sp in ipairs(fx.sparks) do
			local k = (t * sp.speed + sp.phase) % 1
			sp.f.Position = UDim2.fromScale(sp.x + 0.04 * math.sin(t * 3 + sp.phase * 9), 1 - k)
			sp.f.BackgroundTransparency = k
		end
	elseif stage.id == "BeastMode" then
		fx.swirl.Rotation = (t * 25) % 360
		local beat = (t * 0.9) % 1
		for i, slash in ipairs(fx.slashes) do
			local local01 = (beat * 3 - (i - 1) * 0.25)
			slash.BackgroundTransparency = if local01 > 0 and local01 < 0.35 then 0.1 + local01 * 2 else 1
		end
	elseif stage.id == "Colossus" then
		for _, d in ipairs(fx.rain) do
			local k = (t * d.speed + d.phase) % 1
			d.f.Position = UDim2.fromScale(d.x - k * 0.3, k * 1.2 - 0.1)
		end
		local now = os.clock()
		if now >= fx.next then
			fx.next = now + self.rng:NextNumber(1, 2)
			fx.flashAt = now
			local frame = self.rng:NextInteger(0, 15)
			fx.bolt.ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256)
			fx.bolt.Position = UDim2.fromScale(self.rng:NextNumber(0.3, 0.7), 0)
		end
		local since = now - (fx.flashAt or -10)
		local on = since < 0.06 or (since > 0.12 and since < 0.18)
		fx.bolt.ImageTransparency = if on then 0.05 elseif since < 0.3 then 0.6 else 1
		fx.flash.BackgroundTransparency = if on then 0.55 else 1
	elseif stage.id == "Limitless" then
		fx.spiral.Rotation = (t * 40) % 360
		for _, s in ipairs(fx.stars) do s.f.BackgroundTransparency = 0.5 + 0.5 * math.sin(t * 4 + s.phase) end
		local hue = Color3.fromHSV((t * 0.12) % 1, 0.65, 1)
		self.border.Color = hue
		if not info.equipped then self.glowStroke.Color = hue end
	end
end

-- on screen: its ScreenGui is on and every frame above it is visible
local function shown(tile): boolean
	local node = tile.cell
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
	local t = os.clock()
	for tile in pairs(live) do
		if tile.info and shown(tile) then tile:Paint(t) end
	end
end)

return TrainerTile
