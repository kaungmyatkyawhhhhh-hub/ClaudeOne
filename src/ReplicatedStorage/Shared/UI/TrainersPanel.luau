-- TrainersPanel (prompt 24, 21 Oct; prompt 33, 22 Oct: rewritten to the planner's v5 mockups): the TRAINERS window's MY
-- TRAINERS tab (TrainerClient builds the window and calls this).
--   * LEFT: every trainer you own as a tile (Shared/UI/TrainerTile), 4 columns, 12 a page, nearly touching, highest stage
--     first, then level, then rarity; PREV / PAGE 1 / 2 / NEXT and EVOLVE ALL under it.
--   * RIGHT, the picked one: his tile big; the EXP bar (LV 18 . 7.2K / 10K EXP . LV 19); his boost (stage x level) in a
--     framed box ("+120% EXP", "+60% COINS", "+40% PROGRESS"); "NEEDS 3x BEAST-MODE . 2/3" with the 3 copies as mini
--     tiles (the missing one dim); EQUIP (green; red UNEQUIP while he follows you) and the EVOLVE preview (the next stage's
--     colors and name, "LV x"; dim until 3 copies, grey "MAX EVO" at LIMITLESS); EQUIPPED x / y and OWNED n; EVOLUTIONS
--     (the chart: the same tile five times, BASE -> LIMITLESS, chevrons, FROM ROLLS / 3x BASE ...; a stage nobody of
--     yours has reached yet is "???").
--   * The evolve moment (panel.evolved): the 3 fly together, shake, a white flash, the new one slams in with its name
--     stamp, confetti in the stage color, a big sound. A first discovery: "COLOSSUS DISCOVERED!".
--   * (prompt 31) a trainer you haven't seen here yet turns over with a gold burst; "5/8 FOUND".
-- TrainersPanel.Build(parent) -> { frame, refresh(), evolved(info) }. Every change goes to the server (remote "Trainers").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)
local Pieces = require(script.Parent.Pieces)
local Discovery = require(script.Parent.Discovery)
local TrainerTile = require(script.Parent.TrainerTile)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)
local Trainers = require(script.Parent.Parent.Config.Trainers)
local AlterFX = require(script.Parent.Parent.VFX.AlterFX)

local New, Colors = Theme.New, Theme.Colors
local INK = Color3.fromHex("#0A090B")

local TrainersPanel = {}

local COLS, ROWS = 4, 3
local PER_PAGE = COLS * ROWS
local TILE, GAP = 66, 5
local GRID_W = COLS * TILE + (COLS - 1) * GAP
local GRID_H = ROWS * TILE + (ROWS - 1) * GAP
local BIG = 168
local SIDE_X = GRID_W + 12

local function C(hex: string): Color3 return Color3.fromHex(hex) end

-- (prompt 31) the trainers you've had (any copy, any stage), for the reveal and the tab's red dot
function TrainersPanel.Discovered(trainersData): { string }
	local s = Trainers.Migrate(trainersData)
	local have = {}
	for _, copy in ipairs(s.copies) do have[copy.id] = true end
	local ids = {}
	for _, trainer in ipairs(Trainers.List) do
		if have[trainer.id] then table.insert(ids, trainer.id) end
	end
	return ids
end

-- chunky stroked text (the kit inside the trainer screen: LuckiestGuy, a dark stroke on every word)
local function chunky(parent, props, size)
	local label = Kit.Text({ Text = props.Text or "", Font = "Chunky", TextSize = size, TextColor3 = props.TextColor3 or Color3.new(1, 1, 1), Parent = parent })
	for k, v in pairs(props) do if k ~= "Text" and k ~= "TextColor3" then label[k] = v end end
	local stroke = label:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = label })
	stroke.Color, stroke.Thickness, stroke.Transparency = INK, math.max(1.5, size * 0.1), 0
	return label
end
-- a box framed like a tile: a dark base, the hex mesh, an outline + an inner dark ring
local function framed(parent, props, color: Color3)
	local box = New("Frame", { BackgroundColor3 = C("#141317"), Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	for k, v in pairs(props) do box[k] = v end
	New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = Theme.HexTile, ImageTransparency = 0.82,
		Size = UDim2.fromScale(1, 1), Parent = box }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	New("Frame", { Name = "InnerRing", BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 3, Parent = box }, {
		New("UICorner", { CornerRadius = UDim.new(0, 7) }),
		New("UIStroke", { Color = INK, Thickness = 1.5 }),
	})
	return box
end

local function shortNumber(n: number): string
	if n >= 10000 then return (string.format("%.1fK", n / 1000):gsub("%.0K", "K")) end
	return tostring(math.floor(n))
end

function TrainersPanel.Build(parent: Instance)
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trainers", 30)
	local panel = {}
	local page, pickedUid = 1, nil
	local holder = New("Frame", { Name = "Trainers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })

	local function state() return Trainers.Migrate((ClientData.Get() or {}).trainers) end
	local function slots(): number return player:GetAttribute("TrainerSlots") or 1 end
	local function sorted(s)
		local list = table.clone(s.copies)
		table.sort(list, function(a, b)
			if a.s ~= b.s then return a.s > b.s end
			if a.l ~= b.l then return a.l > b.l end
			local ra, rb = Trainers.ById[a.id].index, Trainers.ById[b.id].index
			if ra ~= rb then return ra > rb end
			return a.u < b.u
		end)
		return list
	end

	------------------------------------------------------------------------
	-- LEFT: the grid and the paging row
	------------------------------------------------------------------------
	local grid = New("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromOffset(GRID_W, GRID_H), Parent = holder })
	local tiles = {}
	for i = 1, PER_PAGE do
		local column, row = (i - 1) % COLS, (i - 1) // COLS
		local tile = TrainerTile.New({ Name = "Tile" .. i, px = TILE, Size = UDim2.fromOffset(TILE, TILE), Position = UDim2.fromOffset(column * (TILE + GAP), row * (TILE + GAP)),
			Parent = grid })
		tile.button.Activated:Connect(function()
			if not tile.copy then return end
			Audio.PlayUI("Click")
			pickedUid = tile.copy.u
			panel.refresh()
		end)
		tiles[i] = tile
	end
	local pager = New("Frame", { Name = "Pager", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, GRID_H + 6), Size = UDim2.fromOffset(GRID_W, 30), Parent = holder })
	local prev = Kit.Button("Dark", "Prev", { Name = "Prev", Position = UDim2.fromOffset(0, 0), Parent = pager }, { width = 58, height = 30, textSize = 12 })
	local pageText = chunky(pager, { Name = "Page", Position = UDim2.fromOffset(62, 0), Size = UDim2.fromOffset(78, 30) }, 13)
	local nextButton = Kit.Button("Dark", "Next", { Name = "Next", Position = UDim2.fromOffset(142, 0), Parent = pager }, { width = 58, height = 30, textSize = 12 })
	local evolveAll = Kit.Button("Gold", "Evolve all", { Name = "EvolveAll", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = pager },
		{ width = 76, height = 30, textSize = 11 })
	prev.Activated:Connect(function() page = math.max(1, page - 1) Audio.PlayUI("Click") panel.refresh() end)
	nextButton.Activated:Connect(function() page += 1 Audio.PlayUI("Click") panel.refresh() end)
	evolveAll.Activated:Connect(function()
		Audio.PlayUI("Click")
		remote:FireServer("EvolveAll")
	end)

	-- nothing yet: a line and a button to the Agency
	local empty = New("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 90), Visible = false, Parent = holder })
	Kit.Text({ Text = "No trainers yet. Roll for one at the Trainer Agency (the desk at the front of each gym).", Font = "Strong", TextSize = 13, TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36), Parent = empty })
	local openAgency = Kit.Button("Gold", "Roll trainers", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 42), Parent = empty },
		{ width = 200, height = 44, textSize = 15 })
	openAgency.Activated:Connect(function()
		Audio.PlayUI("Click")
		UIBus.OpenAgency:Fire()
	end)

	------------------------------------------------------------------------
	-- RIGHT: the picked one
	------------------------------------------------------------------------
	local side = New("Frame", { Name = "Detail", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE_X, 0), Size = UDim2.new(1, -SIDE_X, 1, 0), Parent = holder })
	local big = TrainerTile.New({ Name = "Big", px = BIG, Size = UDim2.fromOffset(BIG, BIG), Parent = side })
	local counts = chunky(side, { Name = "Counts", Position = UDim2.fromOffset(0, BIG + 6), Size = UDim2.fromOffset(BIG, 16), TextXAlignment = Enum.TextXAlignment.Left }, 10)
	Kit.Fit(counts, 10, 7)
	local chartButton = Kit.Button("Dark", "Evolutions", { Name = "Chart", Position = UDim2.fromOffset(0, BIG + 26), Parent = side }, { width = BIG, height = 30, textSize = 12 })
	local COL_X = BIG + 10
	local col = New("Frame", { Name = "Column", BackgroundTransparency = 1, Position = UDim2.fromOffset(COL_X, 0), Size = UDim2.new(1, -COL_X, 1, 0), Parent = side })
	-- the EXP bar
	local bar = framed(col, { Name = "ExpBar", Size = UDim2.new(1, 0, 0, 30) }, C("#5AA8FF"))
	local fill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -8), ZIndex = 2, Parent = bar }, {
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(C("#9AD8FF"), C("#2F7BFF")) }),
	})
	local lvLeft = chunky(bar, { Name = "Left", Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(40, 30), ZIndex = 4, TextXAlignment = Enum.TextXAlignment.Left }, 10)
	local lvRight = chunky(bar, { Name = "Right", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(40, 30), ZIndex = 4,
		TextXAlignment = Enum.TextXAlignment.Right }, 10)
	local expText = chunky(bar, { Name = "Exp", Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -88, 1, 0), ZIndex = 4 }, 13)
	-- the boost box
	local stats = framed(col, { Name = "Stats", Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 86) }, C("#3A3640"))
	local statRows = {}
	local STAT = { gains = { "zap", C("#5AA8FF"), "EXP" }, coins = { "coin", C("#F6C75A"), "COINS" }, progress = { "arrow-big-up", C("#5CE07A"), "PROGRESS" },
		maxStamina = { "heart-pulse", C("#FF6A7A"), "MAX STAMINA" }, staminaRegen = { "heart-pulse", C("#36C2C2"), "STAMINA REGEN" } }
	for i = 1, 3 do
		local row = New("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6 + (i - 1) * 26), Size = UDim2.new(1, -16, 0, 24), ZIndex = 4,
			Parent = stats })
		local badge = New("Frame", { Name = "Badge", BackgroundColor3 = Colors.Gold, Size = UDim2.fromOffset(22, 22), ZIndex = 4, Parent = row }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = INK, Thickness = 1.5 }),
		})
		local icon = Pieces.Icon("zap", INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), ZIndex = 5, Parent = badge })
		icon:SetAttribute("KeepColor", true)
		local text = chunky(row, { Name = "Text", Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 1, 0), ZIndex = 4, TextXAlignment = Enum.TextXAlignment.Left }, 15)
		statRows[i] = { row = row, badge = badge, icon = icon, text = text }
	end
	-- NEEDS 3x BEAST-MODE . 2/3 + the 3 mini tiles
	local needs = chunky(col, { Name = "Needs", Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, -110, 0, 34), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true }, 11)
	Kit.Fit(needs, 11, 8, 2)
	local minis = {}
	for i = 1, Trainers.EvolveCount do
		minis[i] = TrainerTile.New({ Name = "Mini" .. i, px = 32, Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(Trainers.EvolveCount - i) * 36, 0, 129), Parent = col })
	end
	-- the two buttons
	local equipButton = Kit.Button("Green", "Equip", { Name = "Equip", Position = UDim2.fromOffset(0, 168), Parent = col }, { width = 128, height = 46, textSize = 18 })
	equipButton.Size = UDim2.new(0.5, -5, 0, 46)
	local evolveButton = New("TextButton", { Name = "Evolve", Text = "", AutoButtonColor = false, BackgroundColor3 = C("#141317"), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 168), Size = UDim2.new(0.5, -5, 0, 46), ClipsDescendants = true, Parent = col }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	local evolveStroke = New("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = evolveButton })
	local evolveHex = New("ImageLabel", { BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = Theme.HexTile, ImageTransparency = 0.55,
		Size = UDim2.fromScale(1, 1), Parent = evolveButton })
	local evolveName = chunky(evolveButton, { Name = "Stage", Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 24), ZIndex = 3 }, 16)
	Kit.Fit(evolveName, 16, 9)
	local evolveSub = chunky(evolveButton, { Name = "Sub", Position = UDim2.fromOffset(4, 26), Size = UDim2.new(1, -8, 0, 16), ZIndex = 3 }, 11)

	------------------------------------------------------------------------
	-- The evolutions chart (over the panel)
	------------------------------------------------------------------------
	-- (a little past the panel on every side: the grid tiles' glows reach out a few px)
	local chart = New("Frame", { Name = "Chart", BackgroundColor3 = C("#0E0D10"), BackgroundTransparency = 0.02, Position = UDim2.fromOffset(-8, -8), Size = UDim2.new(1, 16, 1, 16),
		Visible = false, ZIndex = 20,
		Parent = holder }, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	chunky(chart, { Name = "Title", Text = "EVOLUTIONS", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -80, 0, 26), ZIndex = 21,
		TextXAlignment = Enum.TextXAlignment.Left }, 20)
	local chartClose = Kit.Button("Dark", "Back", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), ZIndex = 21, Parent = chart },
		{ width = 64, height = 30, textSize = 12 })
	local CHART_TILE, CHEVRON = 112, 22
	local chartRow = New("Frame", { Name = "Row", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(5 * CHART_TILE + 4 * CHEVRON, CHART_TILE + 40), ZIndex = 21, Parent = chart })
	local chartTiles = {}
	for i, stage in ipairs(Trainers.Stages) do
		local x = (i - 1) * (CHART_TILE + CHEVRON)
		chartTiles[i] = TrainerTile.New({ Name = stage.id, px = CHART_TILE, Size = UDim2.fromOffset(CHART_TILE, CHART_TILE), Position = UDim2.fromOffset(x, 0), Parent = chartRow })
		chunky(chartRow, { Name = "Caption" .. i, Text = stage.from, Position = UDim2.fromOffset(x, CHART_TILE + 6), Size = UDim2.fromOffset(CHART_TILE, 18), ZIndex = 22,
			TextColor3 = C("#BDBAC4") }, 11)
		if i < #Trainers.Stages then
			chunky(chartRow, { Name = "Chevron" .. i, Text = ">", Position = UDim2.fromOffset(x + CHART_TILE, CHART_TILE / 2 - 14), Size = UDim2.fromOffset(CHEVRON, 28),
				ZIndex = 22, TextColor3 = C(Trainers.Stages[i + 1].color) }, 22)
		end
	end
	local chartNote = Kit.Text({ Name = "Note", Text = "3 of the same trainer at the same stage make 1 of the next (x2 the boost). He keeps the best level of the 3.",
		Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, CHART_TILE + 96), Size = UDim2.new(1, -24, 0, 16),
		ZIndex = 21, Parent = chart })
	chartNote.TextWrapped = true
	chartClose.Activated:Connect(function() Audio.PlayUI("Click") chart.Visible = false end)

	------------------------------------------------------------------------
	-- Refresh
	------------------------------------------------------------------------
	local currentSet, current = {}, nil
	function panel.refresh()
		local s = state()
		local list = sorted(s)
		local slotCount = slots()
		local equippedUids = Trainers.CleanEquipped(s, slotCount)
		local equippedSet = {}
		for _, u in ipairs(equippedUids) do equippedSet[u] = true end
		local pages = math.max(1, math.ceil(#list / PER_PAGE))
		page = math.clamp(page, 1, pages)
		empty.Visible = #list == 0
		grid.Visible, pager.Visible, side.Visible = #list > 0, #list > 0, #list > 0
		if #list == 0 then return end
		-- (prompt 31) new trainers since you last looked turn over with a gold burst
		local discovered = TrainersPanel.Discovered((ClientData.Get() or {}).trainers)
		local fresh = if holder.Visible then Discovery.New("Trainers", discovered) else {}
		local map = Trainers.CopyByUid(s)
		if not pickedUid or not map[pickedUid] then pickedUid = list[1].u end
		for i, tile in ipairs(tiles) do
			local copy = list[(page - 1) * PER_PAGE + i]
			tile.copy = copy
			tile.cell.Visible = copy ~= nil
			if copy then
				tile:Set({ id = copy.id, s = copy.s, l = copy.l, equipped = equippedSet[copy.u] })
				local scale = tile.cell:FindFirstChild("Picked") or New("UIScale", { Name = "Picked", Parent = tile.cell })
				scale.Scale = if copy.u == pickedUid then 1.06 else 1
				if fresh[copy.id] then
					fresh[copy.id] = nil
					Discovery.Reveal(tile.button)
				end
			end
		end
		if holder.Visible then Discovery.Seen("Trainers", discovered) end
		pageText.Text = "PAGE " .. page .. " / " .. pages
		Kit.SetButton(prev, if page > 1 then "Dark" else "Disabled", "Prev")
		Kit.SetButton(nextButton, if page < pages then "Dark" else "Disabled", "Next")
		-- anything to evolve?
		local canAny = false
		local groups = {}
		for _, copy in ipairs(s.copies) do
			if copy.s < #Trainers.Stages then
				local key = copy.id .. "@" .. copy.s
				groups[key] = (groups[key] or 0) + 1
				if groups[key] >= Trainers.EvolveCount then canAny = true end
			end
		end
		Kit.SetButton(evolveAll, if canAny then "Gold" else "Disabled", "Evolve all")
		counts.Text = string.format("EQUIPPED %d/%d  ·  OWNED %d  ·  %d/%d FOUND", #equippedUids, slotCount, #s.copies, #discovered, #Trainers.List)
		-- the picked one
		current = map[pickedUid]
		local trainer = Trainers.ById[current.id]
		local stage = Trainers.Stages[current.s]
		big:Set({ id = current.id, s = current.s, l = current.l, equipped = equippedSet[current.u] })
		if current.l >= Trainers.MaxLevel then
			lvLeft.Text, lvRight.Text, expText.Text = "LV " .. current.l, "", "MAX LEVEL"
			fill.Size = UDim2.new(1, -8, 1, -8)
		else
			local need = Trainers.LevelXp(current.l, current.s)
			local k = math.clamp(current.x / need, 0, 1)
			lvLeft.Text, lvRight.Text = "LV " .. current.l, "LV " .. (current.l + 1)
			expText.Text = shortNumber(current.x) .. " / " .. shortNumber(need) .. " EXP"
			fill.Size = UDim2.new(k, -8 * k, 1, -8)
		end
		local lines = Trainers.PerkLines(trainer, current)
		local icons = require(script.Parent.Parent.Config.UI).Icons
		for i, row in ipairs(statRows) do
			local line = lines[i]
			row.row.Visible = line ~= nil
			if line then
				local look = STAT[line.kind]
				row.badge.BackgroundColor3 = look[2]
				row.icon.Image = icons[look[1]] or row.icon.Image
				row.text.Text = "+" .. line.pct .. "% " .. look[3]
				row.text.TextColor3 = look[2]
			end
		end
		-- evolving
		currentSet = Trainers.EvolveSet(s, current)
		local maxed = current.s >= #Trainers.Stages
		local ready = not maxed and #currentSet >= Trainers.EvolveCount
		local nextStage = Trainers.Stages[current.s + 1]
		needs.Text = if maxed then "MAX EVOLUTION" else string.format("NEEDS %dx %s  ·  %d/%d", Trainers.EvolveCount, stage.name, math.min(#currentSet, Trainers.EvolveCount),
			Trainers.EvolveCount)
		for i, mini in ipairs(minis) do
			local have = currentSet[i] ~= nil
			mini.cell.Visible = not maxed
			mini:Set({ id = current.id, s = current.s, l = 1, mini = true })
			for _, d in ipairs(mini.cell:GetDescendants()) do
				if d:IsA("ViewportFrame") then d.ImageTransparency = if have then 0 else 0.75 end
			end
			mini.button.BackgroundTransparency = if have then 0 else 0.6
		end
		local isEquipped = equippedSet[current.u] == true
		Kit.SetButton(equipButton, if isEquipped then "Red" else "Green", if isEquipped then "Unequip" else "Equip")
		if maxed then
			evolveButton.BackgroundColor3 = C("#2A282E")
			evolveStroke.Color = C("#55525A")
			evolveHex.ImageColor3 = C("#55525A")
			evolveName.Text, evolveName.TextColor3 = "MAX EVO", C("#9A97A0")
			evolveSub.Text = ""
		else
			local known = s.discovered[nextStage.id] == true
			local bestLevel = 1
			for _, c in ipairs(currentSet) do bestLevel = math.max(bestLevel, c.l) end
			evolveButton.BackgroundColor3 = if ready then C(nextStage.base) else C("#1A191D")
			evolveStroke.Color = if ready then C(nextStage.color) else C("#3A3640")
			evolveHex.ImageColor3 = C(nextStage.hex)
			evolveName.Text = if known then nextStage.name else "???"
			evolveName.TextColor3 = if ready then C(nextStage.color) else C("#8A878F")
			evolveSub.Text = if ready then "EVOLVE · LV " .. bestLevel else "NEEDS " .. Trainers.EvolveCount
		end
		-- the chart: this trainer at every stage
		for i, tile in ipairs(chartTiles) do
			local st = Trainers.Stages[i]
			tile:Set({ id = current.id, s = i, l = 1, hidden = s.discovered[st.id] ~= true })
		end
	end

	equipButton.Activated:Connect(function()
		if not current then return end
		Audio.PlayUI("Click")
		local s = state()
		local uids = Trainers.CleanEquipped(s, slots())
		local at = table.find(uids, current.u)
		if at then
			remote:FireServer("Unequip", at)
		else
			-- the first free slot, or the last one when all are full
			remote:FireServer("Equip", math.min(#uids + 1, slots()), current.u)
		end
	end)
	evolveButton.Activated:Connect(function()
		if not current or current.s >= #Trainers.Stages or #currentSet < Trainers.EvolveCount then return end
		Audio.PlayUI("Click")
		remote:FireServer("Evolve", current.u)
	end)
	chartButton.Activated:Connect(function()
		Audio.PlayUI("Click")
		panel.refresh()
		chart.Visible = true
	end)

	------------------------------------------------------------------------
	-- The evolve moment
	------------------------------------------------------------------------
	local stageGui = nil
	local playing = false
	function panel.evolved(info)
		local result = info and info.results and info.results[1]
		if not result or playing then return end
		playing = true
		pickedUid = result.u
		local stage = Trainers.Stages[result.stage]
		stageGui = stageGui or Theme.ScreenGui({ Name = "TrainerEvolve", DisplayOrder = 60, Parent = player:WaitForChild("PlayerGui") })
		stageGui.Enabled = true
		stageGui:ClearAllChildren()
		local root = Kit.Root(stageGui)
		local dim = New("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
		-- the 3 fly together and shake
		local three = {}
		for i = 1, Trainers.EvolveCount do
			local t = TrainerTile.New({ Name = "From" .. i, px = 90, Size = UDim2.fromOffset(90, 90), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, (i - 2) * 120, 0.5, 0), Parent = root })
			t:Set({ id = result.id, s = result.stage - 1, l = 1, noLevel = true })
			table.insert(three, t)
		end
		Audio.PlayUI("Whoosh")
		task.wait(0.35)
		for _, t in ipairs(three) do
			TweenService:Create(t.cell, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		end
		task.wait(0.38)
		for _ = 1, 8 do
			for _, t in ipairs(three) do t.cell.Position = UDim2.new(0.5, math.random(-5, 5), 0.5, math.random(-5, 5)) end
			task.wait(0.03)
		end
		-- the flash, the new one slams in
		local flash = New("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = root })
		for _, t in ipairs(three) do t.cell:Destroy() end
		pcall(function() AlterFX.Sound("TitleHit") end)
		Audio.PlayUI("TitleUnlocked")
		local made = TrainerTile.New({ Name = "Made", px = 180, Size = UDim2.fromOffset(180, 180), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
			Parent = root })
		made:Set({ id = result.id, s = result.stage, l = result.level })
		local scale = New("UIScale", { Scale = 1.8, Parent = made.cell })
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		-- the name stamp and the confetti in the stage color
		local stamp = chunky(root, { Name = "Stamp", Text = if info.first then stage.name .. " DISCOVERED!" else stage.name .. "!", AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.45, 100), Size = UDim2.fromOffset(420, 40), TextColor3 = Color3.fromHex(stage.color), ZIndex = 40 }, 30)
		local stampScale = New("UIScale", { Scale = 2.2, Parent = stamp })
		TweenService:Create(stampScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local sub = if info.all and #info.results > 1 then "Evolved " .. #info.results .. " trainers" else Trainers.ById[result.id].name .. " · LV " .. result.level
		chunky(root, { Name = "Sub", Text = sub, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 140), Size = UDim2.fromOffset(420, 24), ZIndex = 40 }, 16)
		local confetti = New("Frame", { Name = "Confetti", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 45, Parent = root })
		local color = Color3.fromHex(stage.color)
		for k = 1, 36 do
			local piece = New("Frame", { BackgroundColor3 = if k % 3 == 0 then Color3.new(1, 1, 1) elseif stage.rainbow then Color3.fromHSV(math.random(), 0.7, 1) else color,
				BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(math.random(5, 9), math.random(8, 14)),
				Rotation = math.random(0, 360), ZIndex = 45, Parent = confetti })
			local angle = math.random() * math.pi * 2
			local dist = math.random(160, 360)
			TweenService:Create(piece, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(angle) * dist, 0.45, math.sin(angle) * dist * 0.7 + 60), Rotation = math.random(-360, 360), BackgroundTransparency = 0.2 }):Play()
		end
		task.wait(2.4)
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		stageGui.Enabled = false
		stageGui:ClearAllChildren()
		playing = false
		panel.refresh()
	end

	-- live: a roll, an equip, a new slot, a level
	ClientData.Changed:Connect(function(path)
		if holder.Visible and path[1] == "trainers" then panel.refresh() end
	end)
	player:GetAttributeChangedSignal("Trainers"):Connect(function() if holder.Visible then panel.refresh() end end)
	player:GetAttributeChangedSignal("TrainerSlots"):Connect(function() if holder.Visible then panel.refresh() end end)

	panel.frame = holder
	return panel
end

return TrainersPanel
