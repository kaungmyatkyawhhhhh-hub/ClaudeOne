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
-- (prompt 47, 22 Oct) The owner's pictures are in the group now: his portrait (Config/Trainers Portraits) instead of the
-- 3D rig (a not-owned one = the portrait in black with a rim), the planner's backgrounds per stage (Trainers.StageArt:
-- hex = the base, evo = the stage effect on top, animated: IRON-BORN pulses, BEAST-MODE / LIMITLESS turn, COLOSSUS
-- flashes with its lightning), and a highlight that runs round the border. Rarity mode (the Agency): the rarity's colors,
-- the rarity name and the chance instead of the stage and LV, a gold check when owned.
--   TrainerTile.New({ Name, LayoutOrder, Size, Position, AnchorPoint, Parent, px = its width in mockup px }) -> tile
--   tile:Set({ id, s, l, equipped, noLevel, caption, hidden }); tile.cell (the frame to place), tile.button (taps)
-- (owner, 23 Oct) hidden = a stage the player has never had (the evolutions chart): him as a black silhouette, "???" for the
-- stage, no LV, the background at ~35% with its effect off, a gray border.
-- (owner, prompt 48: the "hidden" undiscovered stage, dark and glitching, is gone: every stage shows)
-- (prompt 52, 23 Oct: the owner's references ref_agency / ref_my_trainers / ref_evolutions) the one tile of all three
-- screens: a 4 px border in the stage (or rarity) color with a soft glow, the background filling the whole tile (the
-- stage art; on the Agency the rarity's hex, a bright burst and turning light rays), the stage / rarity word big in its
-- color (LIMITLESS a rainbow, MYTHIC and ETERNAL their two colors), the LV or chance big and white.
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

-- the border: its color with a brighter streak (it turns: Paint)
local function borderColors(color: Color3): ColorSequence
	local bright = color:Lerp(Color3.new(1, 1, 1), 0.7)
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.4, color), ColorSequenceKeypoint.new(0.5, bright),
		ColorSequenceKeypoint.new(0.6, color), ColorSequenceKeypoint.new(1, color) })
end

-- his picture (the portrait, or the 3D rig when there is none); silhouette = black with a rim in `rim`
local function placeArt(holder: Frame, trainer, silhouette: boolean, rim: Color3)
	holder:ClearAllChildren()
	if trainer.icon and trainer.icon ~= "" then
		if silhouette then
			New("ImageLabel", { Name = "Rim", BackgroundTransparency = 1, Image = trainer.icon, ScaleType = Enum.ScaleType.Fit, ImageColor3 = rim, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.07, 1.07), ZIndex = 5, Parent = holder })
		end
		New("ImageLabel", { Name = "Portrait", BackgroundTransparency = 1, Image = trainer.icon, ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = if silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = holder })
		return
	end
	local art = TrainerPortrait.New(trainer.id, { Size = UDim2.fromScale(1, 1), shot = "bust", pose = "Relaxed", ZIndex = 5, Parent = holder, silhouette = silhouette })
	art.LightColor = if silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
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
	self.border = New("UIStroke", { Name = "Border", Color = Color3.new(1, 1, 1), Thickness = math.max(2.5, px * 0.035), ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = self.button })
	-- (prompt 47) the highlight that runs round the border (the border's color is this gradient)
	self.spin = New("UIGradient", { Name = "Spin", Parent = self.border })
	self.hex = New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(math.floor(px * 0.2), math.floor(px * 0.115)), ImageTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = self.button }, {
		New("UICorner", { CornerRadius = UDim.new(0, radius) }),
	})
	-- (owner, 23 Oct) ClipsDescendants clips to a square, so the moving / oversized layers (the stage effect, the burst, the
	-- rays, the effects) sit in a frame inset by ~0.3 of the corner radius: its square corners fall inside the rounded edge
	-- (the rounded background shows in that thin rim). A CanvasGroup per tile would re-render ~25 animated tiles a frame.
	local inset = math.ceil(radius * 0.3)
	self.clip = New("Frame", { Name = "Clip", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset), ZIndex = 3, Parent = self.button })
	-- (prompt 47) the planner's stage backgrounds (hex = the base, evo = the effect)
	self.bgImage = New("ImageLabel", { Name = "HexArt", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 2,
		Visible = false, Parent = self.button }, { New("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	self.radial = AlterFX.Image(self.clip, "ember", { Name = "Radial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(1.25, 1.25), SizeConstraint = Enum.SizeConstraint.RelativeXX, ImageTransparency = 0.35, ZIndex = 1 })
	self.evoImage = New("ImageLabel", { Name = "EvoArt", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 2, Visible = false, Parent = self.clip })
	self.fxLayer = New("Frame", { Name = "Fx", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = self.clip })
	-- (prompt 52) the Agency's light rays: thin bars through his middle, bright at the centre, fading out
	self.rays = New("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1.6, 1.6), SizeConstraint = Enum.SizeConstraint.RelativeXX, Visible = false, ZIndex = 3, Parent = self.clip })
	self.rayBars = {}
	for i = 0, 5 do
		local ray = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(if i % 2 == 0 then 0.13 else 0.07, 0, 1, 0), Rotation = i * 30, ZIndex = 3, Parent = self.rays }, {
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 1) }) }),
		})
		table.insert(self.rayBars, ray)
	end
	self.hexTop = self.hex:Clone()
	self.hexTop.Name = "HexTop"
	self.hexTop.ImageTransparency = 0.65
	self.hexTop.ZIndex = 4
	self.hexTop.Visible = false
	self.hexTop.Parent = self.button
	-- (hidden stage) the background darkened to ~35%
	self.shade = New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 4,
		Visible = false, Parent = self.button }, { New("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	self.artHolder = New("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(1.02, 0.62), ZIndex = 5, Parent = self.button })
	self.name = chunky(self.button, "Name", "", px * 0.115, nil, { Position = UDim2.fromScale(0.5, 0.025), Size = UDim2.fromScale(0.94, 0.13) })
	Kit.Fit(self.name, math.floor(px * 0.115), 7)
	self.stage = chunky(self.button, "Stage", "", px * 0.14, nil, { Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.96, 0.16) })
	Kit.Fit(self.stage, math.floor(px * 0.14), 7)
	self.level = chunky(self.button, "Level", "", px * 0.14, nil, { Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.94, 0.15) })
	Kit.Fit(self.level, math.floor(px * 0.14), 6, 2)
	-- (prompt 52) LIMITLESS in a rainbow, MYTHIC / ETERNAL in their two colors (the text white under the gradient)
	self.stageGradient = New("UIGradient", { Name = "Colors", Enabled = false, Parent = self.stage })
	-- the 2 px near-black ring just inside the border
	local ringInset = math.max(2, math.floor(px * 0.035))
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

-- info = { id, s, l, equipped, noLevel, caption (instead of "LV n"), mini (no words: the
-- small tiles of the needs line) }
function Tile:Set(info)
	local stage = Trainers.Stages[info.s or 1] or Trainers.Stages[1]
	local trainer = Trainers.ById[info.id]
	self.info = info
	self.stageInfo = stage
	local rarityMode = info.rarity == true
	local hidden = info.hidden == true and not rarityMode
	local rarity = trainer and Trainers.RarityById[trainer.rarity]
	-- the tile's color: the stage's (or, on the Agency, the rarity's)
	local color = if rarityMode and rarity then C(rarity.color2 or rarity.color) else C(stage.color)
	if rarityMode and rarity and rarity.id ~= "Secret" then color = C(rarity.color) end
	if hidden then color = C("#5A5860") end
	self.color = color
	self.shade.Visible = hidden
	local art = Trainers.StageArt[stage.id]
	local useArt = art ~= nil and not rarityMode
	self.bgImage.Visible = useArt
	self.evoImage.Visible = useArt and not hidden -- (a hidden stage: its effect off)
	if useArt then
		self.bgImage.Image = art.hex
		self.evoImage.Image = art.evo
		self.evoImage.ImageTransparency = if stage.index == 1 then 0.35 else 0.12
		self.evoImage.Size, self.evoImage.Rotation = UDim2.fromScale(1, 1), 0
		self.evoImage.SizeConstraint = Enum.SizeConstraint.RelativeXY
	end
	self.hex.Visible = not useArt
	-- (prompt 52) the Agency: the rarity's hex filling the tile, a bright burst behind him (brighter still for a silhouette)
	-- and light rays
	self.button.BackgroundColor3 = if rarityMode then color:Lerp(Color3.new(0, 0, 0), 0.62) else C(stage.base)
	self.hex.ImageColor3 = if rarityMode then color:Lerp(Color3.new(1, 1, 1), 0.25) else C(stage.hex):Lerp(Color3.new(1, 1, 1), 0.15)
	self.hex.ImageTransparency = if rarityMode then 0.5 else 0.6
	self.hexTop.ImageColor3 = self.hex.ImageColor3
	self.radial.ImageColor3 = if rarityMode then color:Lerp(Color3.new(1, 1, 1), 0.2) else color
	self.radial.ImageTransparency = if hidden then 1 elseif useArt then 0.7 elseif rarityMode then (if info.silhouette then 0 else 0.15) else 0.35
	self.rays.Visible = rarityMode
	if rarityMode then
		for _, ray in ipairs(self.rayBars) do
			ray.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
			ray.BackgroundTransparency = if info.silhouette then 0.35 else 0.55
		end
	end
	self.spin.Color = borderColors(color)
	local nameHidden = rarityMode and info.silhouette and rarity and rarity.hidden
	self.name.Text = if nameHidden then "???" else string.upper(trainer and trainer.name or "")
	local twoColors = nil
	if rarityMode then
		self.stage.Text = string.upper(rarity and rarity.name or "")
		self.stage.TextColor3 = color
		self.level.Text = info.caption or ""
		self.level.TextColor3 = Color3.new(1, 1, 1)
		if rarity and rarity.color2 and rarity.id ~= "Secret" then twoColors = ColorSequence.new(C(rarity.color), C(rarity.color2)) end
	else
		self.stage.Text = stage.name
		self.stage.TextColor3 = if stage.index == 1 then Color3.new(1, 1, 1) else color
		self.level.Text = if info.caption then info.caption elseif info.noLevel or hidden then "" else "LV " .. (info.l or 1)
		self.level.TextColor3 = Color3.new(1, 1, 1)
		if hidden then
			self.stage.Text = "???"
			self.stage.TextColor3 = Color3.new(1, 1, 1)
		elseif stage.rainbow then
			local keys = {}
			local hues = { 0.95, 0.08, 0.15, 0.33, 0.52, 0.72 }
			for i, h in ipairs(hues) do keys[i] = ColorSequenceKeypoint.new((i - 1) / (#hues - 1), Color3.fromHSV(h, 0.6, 1)) end
			twoColors = ColorSequence.new(keys)
		end
	end
	self.stageGradient.Enabled = twoColors ~= nil
	if twoColors then
		self.stageGradient.Color = twoColors
		self.stage.TextColor3 = Color3.new(1, 1, 1)
	end
	self.check.Visible = info.equipped == true or (rarityMode and info.owned == true)
	self.name.Visible, self.stage.Visible, self.level.Visible = not info.mini, not info.mini, not info.mini
	self.artHolder.Position = if info.mini then UDim2.fromScale(0.5, 0.04) else UDim2.fromScale(0.5, 0.12)
	self.artHolder.Size = if info.mini then UDim2.fromScale(1.05, 0.96) else UDim2.fromScale(1.02, 0.62)
	self.hexTop.Visible = useArt and not hidden and (stage.id == "BeastMode" or stage.id == "Limitless")
	-- the art and the effect only change when he, the stage, the mode or hidden does
	local silhouette = info.silhouette == true or hidden
	local key = tostring(info.id) .. "|" .. stage.id .. "|" .. tostring(silhouette) .. "|" .. tostring(rarityMode) .. "|" .. tostring(hidden)
	if key ~= self.key then
		self.key = key
		if trainer then placeArt(self.artHolder, trainer, silhouette, color) end
		self.fxLayer:ClearAllChildren()
		local build = (not rarityMode and not hidden) and FX[stage.id] or nil
		self.fx = build and build(self.fxLayer, self.rng) or nil
	end
	self:Paint(os.clock())
end

-- one animation step (also the glow, which depends on equipped)
function Tile:Paint(t: number)
	local info, stage = self.info, self.stageInfo
	if not info then return end
	local color = self.color or C(stage.color)
	-- the highlight runs round the border
	self.spin.Rotation = (t * 80) % 360
	if self.rays.Visible then self.rays.Rotation = (t * 8) % 360 end
	if info.equipped then
		self.glowStroke.Color = GOLD
		self.glowStroke.Thickness = math.max(4, self.px * 0.07)
		self.glowStroke.Transparency = 0.35 + 0.2 * math.sin(t * 3)
	else
		self.glowStroke.Color = color
		self.glowStroke.Thickness = math.max(3, self.px * 0.05)
		self.glowStroke.Transparency = 0.55
	end
	local fx = self.fx
	self.fxLayer.Visible = true
	-- the planner's stage effect moves too
	if self.evoImage.Visible then
		if stage.id == "IronBorn" then
			self.evoImage.ImageTransparency = 0.08 + 0.25 * (0.5 + 0.5 * math.sin(t * 2.6))
		elseif stage.id == "BeastMode" or stage.id == "Limitless" then
			self.evoImage.Size = UDim2.fromScale(1.45, 1.45)
			self.evoImage.SizeConstraint = Enum.SizeConstraint.RelativeXX
			self.evoImage.Rotation = (t * (if stage.id == "Limitless" then 22 else 14)) % 360
		end
	end
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
		if self.evoImage.Visible then self.evoImage.ImageTransparency = if on then 0 else 0.22 end
	elseif stage.id == "Limitless" then
		fx.spiral.Rotation = (t * 40) % 360
		for _, s in ipairs(fx.stars) do s.f.BackgroundTransparency = 0.5 + 0.5 * math.sin(t * 4 + s.phase) end
		local hue = Color3.fromHSV((t * 0.12) % 1, 0.65, 1)
		self.spin.Color = borderColors(hue)
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
