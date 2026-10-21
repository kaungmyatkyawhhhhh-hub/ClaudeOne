-- AltersPanel (prompt 21, 21 Oct): the Inventory window's LOOKS > Alters (prompt 28; was the ALTERS tab; TitlesClient builds the
-- window and calls this).
-- (prompt 40, 22 Oct, mockup inv_alters) Header "ALTER x / 12" + "SHREDDED IS YOUR HIGHEST · GAINS X1.30". The alters as
-- a PATH of tiles (row 1 left to right, row 2 right to left under it, ...: Vascular sits under Tanned):
--   reached   the alter's banner (Config.AlterThemes bg, else its colours) behind the whole tile, the skin swatch big
--             (the alter's colour map tinted with your skin), the name; the one you wear: gold edge + gold check
--   next      the banner dimmed, a dark swatch, the progress bar (muscle groups at the goal) and a NEXT ALTER pill
--   later     smaller dim "???" tiles with one small spark going round
-- A tap shows it in the detail panel (right): banner, swatch, name, "GAINS X1.15", "ALTER 1 · HUMAN TIER", WEAR / WORN.
-- (no body renders per alter yet: the tile shows the skin swatch; swap in art when it exists)
-- AltersPanel.Build(parent) -> { frame, refresh() }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)
local Config = script.Parent.Parent.Config
local Alters = require(Config.Alters)
local AlterThemes = require(Config.AlterThemes)
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local GrowthSpurts = require(Config.GrowthSpurts)

local New, Colors = Theme.New, Theme.Colors

local AltersPanel = {}

local TILE = Vector2.new(140, 92)
local GAP = 8
local COLUMNS = 4
local DETAIL_W = 196
local SWATCH = 40
local DARK = Color3.fromHex("#1B1B20")

function AltersPanel.Build(parent: Instance)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local player = Players.LocalPlayer
	local panel = {}
	local picked = nil -- the alter number shown in the detail panel (nil = the one you wear)
	local holder = New("Frame", { Name = "Alters", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local count = Kit.GoldText(Kit.Text({ Name = "Count", Text = "", Font = "Chunky", TextSize = 17, Size = UDim2.fromOffset(110, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = holder }))
	local header = Kit.Text({ Name = "Bonus", Text = "", Font = "Chunky", TextSize = 12, Position = UDim2.fromOffset(116, 0), Size = UDim2.new(1, -(116 + DETAIL_W + 10), 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = holder })
	local path = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -(DETAIL_W + 10), 1, -24), ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = holder })

	-- one tile's look: a banner (image or colours) behind everything
	local function banner(parent: Instance, n: number, noHex: boolean?): GuiObject
		local theme = if n > 0 then AlterThemes.Get(n) else nil
		local bg = New(if theme and theme.bg then "ImageLabel" else "Frame", { Name = "Banner", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		if theme and theme.bg then
			bg.Image = theme.bg
			bg.ScaleType = Enum.ScaleType.Crop
			bg.BackgroundTransparency = 1
		else
			local base = if theme then theme.base else Color3.fromHex("#1E1C21")
			local accent = if theme then theme.accent else Color3.fromHex("#3A363D")
			New("UIGradient", { Rotation = -90, Color = ColorSequence.new(accent:Lerp(base, 0.55), base), Parent = bg })
		end
		if not noHex then New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = Theme.HexTile,
			ImageTransparency = Theme.HexAlpha, ImageColor3 = if theme then theme.accent else Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent },
			{ New("UICorner", { CornerRadius = UDim.new(0, 10) }) }) end
		return bg
	end
	local function swatchOf(parent: Instance, size: number, y: number): ImageLabel
		return New("ImageLabel", { Name = "Swatch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Colors.Panel, ScaleType = Enum.ScaleType.Crop, ZIndex = 3, Parent = parent }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Name = "Edge", Color = Colors.Outline, Thickness = 2.5 }),
		})
	end
	local function paintSwatch(swatch: ImageLabel, alter, n: number, lit: boolean)
		local skin = player:GetAttribute("SkinColor")
		if typeof(skin) ~= "Color3" then skin = Color3.fromHex("#E0A878") end
		if n == 0 then
			swatch.Image = ""
			swatch.BackgroundColor3 = skin
		elseif alter.textures then
			swatch.Image = alter.textures.color
			swatch.ImageColor3 = if lit then Alters.Tint(alter.id, skin) else DARK -- (prompt 38b: a tan's bronze)
			swatch.BackgroundColor3 = if lit then Alters.PlainSkin(alter.id, skin) else DARK
		else
			swatch.Image = ""
			swatch.BackgroundColor3 = if lit then Color3.fromHex(alter.placeholder) else DARK
		end
	end

	local tiles = {}
	local all = { Alters.Natural }
	for _, alter in ipairs(Alters.List) do table.insert(all, alter) end
	for index, alter in ipairs(all) do
		local n = alter.number or (index - 1)
		local row, col = (index - 1) // COLUMNS, (index - 1) % COLUMNS
		if row % 2 == 1 then col = COLUMNS - 1 - col end -- (the path turns back on every other row)
		local slot = New("Frame", { Name = "Slot_" .. n, BackgroundTransparency = 1, Position = UDim2.fromOffset(4 + col * (TILE.X + GAP), 4 + row * (TILE.Y + GAP)),
			Size = UDim2.fromOffset(TILE.X, TILE.Y), Parent = path })
		local tile = New("TextButton", { Name = alter.id, Text = "", AutoButtonColor = false, BackgroundColor3 = DARK, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = slot }, {
			New("UICorner", { CornerRadius = UDim.new(0, 10) }),
			New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local bg = banner(tile, n)
		local swatch = swatchOf(tile, SWATCH, 5)
		local name = Kit.Text({ Name = "Name", Text = string.upper(alter.name), Font = "Chunky", TextSize = 15, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, SWATCH + 7), Size = UDim2.new(1, -10, 0, 17), ZIndex = 4, Parent = tile })
		Kit.Fit(name, 15, 11)
		local _, setBar = Kit.Bar(Colors.Gold, { Name = "Bar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, SWATCH + 25), Size = UDim2.new(1, -16, 0, 7),
			ZIndex = 4, Visible = false, Parent = tile }, { outline = 1 })
		local bar = tile:FindFirstChild("Bar")
		local nextPill = New("Frame", { Name = "NextPill", BackgroundColor3 = Color3.fromHex("#1E1B20"), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -16, 0, 16), ZIndex = 4, Visible = false, Parent = tile }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Gold, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		Kit.Text({ Name = "Text", Text = "NEXT ALTER", Font = "Chunky", TextSize = 11, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = nextPill })
		local question = Kit.Text({ Name = "Question", Text = "???", Font = "Chunky", TextSize = 15, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -10, 0, 17), ZIndex = 4, Visible = false, Parent = tile })
		local spark = New("Frame", { Name = "Spark", BackgroundColor3 = Colors.Gold, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), ZIndex = 5,
			Visible = false, Parent = swatch }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local check = New("Frame", { Name = "Check", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Colors.Gold, Visible = false, ZIndex = 6, Parent = tile }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Outline, Thickness = 1.5 }),
		})
		require(script.Parent.Pieces).Icon("check", Colors.Ink, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
			ZIndex = 7, Parent = check }):SetAttribute("KeepColor", true)
		tiles[n] = { tile = tile, bg = bg, swatch = swatch, name = name, bar = bar, setBar = setBar, nextPill = nextPill, question = question, spark = spark,
			check = check, alter = alter }
		tile.Activated:Connect(function()
			Audio.PlayUI("Click")
			picked = n
			panel.refresh()
		end)
	end
	local rows = math.ceil(#all / COLUMNS)
	path.CanvasSize = UDim2.fromOffset(0, 8 + rows * (TILE.Y + GAP))

	-- the detail panel (right)
	local detail = New("Frame", { Name = "Detail", BackgroundColor3 = DARK, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, DETAIL_W, 1, 0), ClipsDescendants = true, Parent = holder }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local detailArt = New("Frame", { Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = detail })
	local bigSwatch = swatchOf(detail, 56, 8)
	local bigName = Kit.Fit(Kit.Text({ Name = "Name", Text = "", Font = "Chunky", TextSize = 22, Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 24),
		ZIndex = 4, Parent = detail }), 22, 14)
	local gains = New("Frame", { Name = "Gains", BackgroundColor3 = Color3.fromHex("#1E1B20"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 91),
		Size = UDim2.fromOffset(120, 20), ZIndex = 4, Parent = detail }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Name = "Edge", Color = Colors.Red, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local gainsText = Kit.Text({ Name = "Text", Text = "", Font = "Chunky", TextSize = 14, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = gains })
	local tierText = Kit.Fit(Kit.Text({ Name = "Tier", Text = "", Font = "Chunky", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(8, 114),
		Size = UDim2.new(1, -16, 0, 14), ZIndex = 4, Parent = detail }), 12, 10)
	local wear = Kit.Button("Green", "Wear", { Name = "Wear", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 4, Parent = detail },
		{ width = DETAIL_W - 20, height = 30, textSize = 16 })
	wear.Activated:Connect(function()
		local state = Alters.State(ClientData.Get())
		local n = picked or state.equipped or 0
		if n <= (state.highest or 0) and n ~= (state.equipped or 0) then
			remotes.PlayerAction:FireServer("EquipAlter", n)
		end
	end)

	-- the sparks on the "???" tiles go round (only while shown)
	task.spawn(function()
		while holder.Parent do
			task.wait(0.05)
			if holder.Visible then
				local angle = os.clock() * 2.5
				for _, t in pairs(tiles) do
					if t.spark.Visible then t.spark.Position = UDim2.new(0.5 + 0.55 * math.cos(angle), 0, 0.5 + 0.55 * math.sin(angle), 0) end
				end
			end
		end
	end)

	function panel.refresh()
		local data = ClientData.Get()
		if not data then return end
		local state = Alters.State(data)
		local highest, worn = state.highest or 0, state.equipped or 0
		local maxed = GrowthSpurts.IsMaxed(data.growthSpurts or 0)
		local progress = Alters.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
		count.Text = "ALTER " .. highest .. " / " .. #Alters.List
		header.Text = if maxed then string.upper(string.format("%s is your highest · gains x%.2f", Alters.Get(highest).name, Alters.Bonus(highest)))
			else "BODY ALTERS OPEN AT 7'0\". EACH ONE ADDS +15% GAINS."
		for n, t in pairs(tiles) do
			local reached = n <= highest
			local isNext = n == highest + 1
			local later = not reached and not isNext
			t.bg.Visible = not later
			local dim = if isNext then 0.55 else 0
			if t.bg:IsA("ImageLabel") then t.bg.ImageTransparency = dim else t.bg.BackgroundTransparency = dim end
			paintSwatch(t.swatch, t.alter, n, reached)
			t.swatch.Visible = true
			t.name.Visible = not later
			t.question.Visible = later
			t.spark.Visible = later
			t.bar.Visible = isNext and maxed
			t.nextPill.Visible = isNext
			if isNext then t.setBar(if progress.total > 0 then progress.met / progress.total else 0) end
			t.check.Visible = reached and n == worn
			local theme = if n > 0 then AlterThemes.Get(n) else nil
			t.tile.Border.Color = if reached and n == worn then Colors.Gold elseif reached then (if theme then theme.accent else Colors.Text) else Color3.fromHex("#2E2A30")
			t.tile.Border.Thickness = if later then 2 else 3
			-- later ones are smaller and quiet
			t.tile.Size = if later then UDim2.new(1, -14, 1, -14) else UDim2.fromScale(1, 1)
			t.tile.BackgroundColor3 = if later then Color3.fromHex("#141216") else DARK
			local pickedNow = (picked or worn) == n
			local scale = t.tile:FindFirstChild("PickScale") or New("UIScale", { Name = "PickScale", Parent = t.tile })
			scale.Scale = if pickedNow and not later then 1.03 else 1
		end
		-- the detail panel
		local n = picked or worn
		local alter = Alters.Get(n) or Alters.Natural
		local reached = n <= highest
		local later = n > highest + 1
		detailArt:ClearAllChildren()
		if not later then banner(detailArt, n, true) end -- (no mesh on the detail panel)
		paintSwatch(bigSwatch, alter, n, reached)
		bigName.Text = if later then "???" else string.upper(alter.name)
		local theme = if n > 0 then AlterThemes.Get(n) else nil
		gains.Visible = not later
		gains.Edge.Color = if theme then theme.accent else Colors.Muted
		gainsText.Text = string.format("GAINS X%.2f", Alters.Bonus(n))
		tierText.Text = if later then "KEEP GROWING TO FIND IT" elseif n == 0 then "YOUR OWN SKIN"
			else string.upper("Alter " .. n .. " · " .. Alters.Tiers[alter.tier].name .. " tier")
		detail.Border.Color = if reached and n == worn then Colors.Gold elseif theme and not later then theme.accent else Colors.Outline
		wear.Visible = reached
		if reached then
			if n == worn then Kit.SetButton(wear, "Quiet", "Worn") else Kit.SetButton(wear, "Green", "Wear") end
		end
	end

	panel.frame = holder
	return panel
end

return AltersPanel
