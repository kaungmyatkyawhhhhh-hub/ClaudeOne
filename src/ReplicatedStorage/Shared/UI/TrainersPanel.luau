-- TrainersPanel (prompt 24, 21 Oct; prompt 33, 22 Oct: rewritten to the planner's v5 mockups): the TRAINERS window's MY
-- TRAINERS tab (TrainerClient builds the window and calls this).
--   * LEFT: every trainer you own as a tile (Shared/UI/TrainerTile), 4 columns, 12 a page, nearly touching, highest stage
--     first, then level, then rarity; PREV / PAGE 1 / 2 / NEXT and EVOLVE ALL under it.
--   * RIGHT, the picked one: his tile big; the EXP bar (LV 18 . 7.2K / 10K EXP . LV 19); his boost (stage x level) in a
--     framed box ("+120% EXP", "+60% COINS", "+40% PROGRESS"); "NEEDS 3x BEAST-MODE . 2/3" with the 3 copies as mini
--     tiles (the missing one dim); EQUIP (green; red UNEQUIP while he follows you) and the EVOLVE preview (the next stage's
--     colors and name, "LV x"; dim until 3 copies, grey "MAX STAGE" at LIMITLESS); EQUIPPED x / y and OWNED n; EVOLUTIONS
--     (the chart: the same tile five times, BASE -> LIMITLESS, chevrons, FROM ROLLS / 3x BASE ...). (owner, prompt 48:
--     every stage's real name shows, no "???" stages.)
--   * The evolve moment (panel.evolved): the 3 fly together, shake, a white flash, the new one slams in with its name
--     stamp, confetti in the stage color, a big sound.
--   * (prompt 31) a trainer you haven't seen here yet turns over with a gold burst; "5/8 FOUND".
-- (prompt 47, 22 Oct) Restyled with the chunky kit: the big tile with the EQUIPPED / OWNED pills under it; on the right his
-- name, rarity and LV (gold), the EXP bar, his boosts as stat pills, the evolve bar (copies 2 / 3 + the mini tiles), a
-- big gold EVOLVE button and a quiet EQUIP / UNEQUIP. Nothing yet: "NO TRAINERS YET" and a red GO TO TRAINER AGENCY
-- button that takes you there (a fade; 10 s cooldown, checked on the server).
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
	-- (owner, 23 Oct, chrome reset: no mesh on a bar inside the panel)
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
			Kit.SelectFeedback(tile.button) -- (prompt 54: bounce + select sound)
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

	-- nothing yet: NO TRAINERS YET + a red button that takes you to the Agency (a fade; 10 s cooldown)
	local empty = New("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = holder })
	chunky(empty, { Name = "Title", Text = "NO TRAINERS YET", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 0), Size = UDim2.new(1, -20, 0, 36) }, 30)
	Kit.Text({ Name = "Line", Text = "Roll for one at the Trainer Agency: they follow you, cheer you on and boost your gains.", Font = "Strong", TextSize = 13,
		TextColor3 = Colors.Muted, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 44), Size = UDim2.new(0.8, 0, 0, 36), Parent = empty })
	local goAgency = Kit.Button("Red", "Go to Trainer Agency", { Name = "GoAgency", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 92), Parent = empty },
		{ width = 280, height = 56, textSize = 20 })
	local lastGo = -math.huge
	goAgency.Activated:Connect(function()
		if os.clock() - lastGo < 10 then
			require(script.Parent.Notify).Show(string.format("Wait %d s.", math.ceil(10 - (os.clock() - lastGo))), nil, "agencywait")
			return
		end
		lastGo = os.clock()
		Audio.PlayUI("Click")
		-- a quick fade to black and back while you move
		local fadeGui = Theme.ScreenGui({ Name = "AgencyFade", DisplayOrder = 90, Parent = player:WaitForChild("PlayerGui") })
		fadeGui.IgnoreGuiInset = true
		fadeGui.ScreenInsets = Enum.ScreenInsets.None
		local black = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = fadeGui })
		TweenService:Create(black, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
		task.delay(0.27, function()
			remote:FireServer("TeleportAgency")
			UIBus.CloseAllPanels()
			task.wait(0.35)
			TweenService:Create(black, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			task.delay(0.4, function() fadeGui:Destroy() end)
		end)
	end)

	------------------------------------------------------------------------
	-- RIGHT: the picked one
	------------------------------------------------------------------------
	local side = New("Frame", { Name = "Detail", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE_X, 0), Size = UDim2.new(1, -SIDE_X, 1, 0), Parent = holder })
	local big = TrainerTile.New({ Name = "Big", px = BIG, Size = UDim2.fromOffset(BIG, BIG), Parent = side })
	-- under the big tile: the two pills, and the evolutions chart button
	local function pillFrame(name, x)
		local pill = New("Frame", { Name = name, BackgroundColor3 = C("#141317"), Position = UDim2.fromOffset(x, BIG + 6), Size = UDim2.fromOffset(BIG / 2 - 3, 22), Parent = side }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Gold, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		return chunky(pill, { Name = "Text", Size = UDim2.fromScale(1, 1) }, 10)
	end
	local equippedPill = pillFrame("Equipped", 0)
	local ownedPill = pillFrame("Owned", BIG / 2 + 3)
	local chartButton = Kit.Button("Dark", "Evolutions", { Name = "Chart", Position = UDim2.fromOffset(0, BIG + 34), Parent = side }, { width = BIG, height = 30, textSize = 12 })
	local COL_X = BIG + 10
	local col = New("Frame", { Name = "Column", BackgroundTransparency = 1, Position = UDim2.fromOffset(COL_X, 0), Size = UDim2.new(1, -COL_X, 1, 0), Parent = side })
	-- his name, the rarity, LV in gold
	local nameText = chunky(col, { Name = "Name", Size = UDim2.new(1, -70, 0, 22), TextXAlignment = Enum.TextXAlignment.Left }, 19)
	Kit.Fit(nameText, 19, 11)
	local rarityText = chunky(col, { Name = "Rarity", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -70, 0, 14), TextXAlignment = Enum.TextXAlignment.Left }, 11)
	local levelText = chunky(col, { Name = "Level", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(70, 30),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Colors.Gold }, 22)
	-- the EXP bar
	local bar = framed(col, { Name = "ExpBar", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 26) }, C("#5AA8FF"))
	local fill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -8), ZIndex = 2, Parent = bar }, {
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(C("#9AD8FF"), C("#2F7BFF")) }),
	})
	local expText = chunky(bar, { Name = "Exp", Size = UDim2.fromScale(1, 1), ZIndex = 4 }, 12)
	-- the boosts as stat pills
	local pillsRow = New("Frame", { Name = "Stats", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 56), Parent = col }, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local STAT = { gains = { "zap", C("#5AA8FF"), "EXP" }, coins = { "coin", C("#F6C75A"), "COINS" }, progress = { "arrow-big-up", C("#5CE07A"), "PROGRESS" },
		maxStamina = { "heart-pulse", C("#FF6A7A"), "MAX STAMINA" }, staminaRegen = { "heart-pulse", C("#36C2C2"), "STAMINA REGEN" } }
	local statPills = {}
	for i = 1, 3 do
		local pill = New("Frame", { Name = "Stat" .. i, LayoutOrder = i, BackgroundColor3 = C("#141317"), Size = UDim2.fromOffset(0, 25), AutomaticSize = Enum.AutomaticSize.X,
			Parent = pillsRow }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Name = "Edge", Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center }),
			New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 9) }),
		})
		local badge = New("Frame", { Name = "Badge", BackgroundColor3 = Colors.Gold, Size = UDim2.fromOffset(19, 19), Parent = pill }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = INK, Thickness = 1.2 }),
		})
		local icon = Pieces.Icon("zap", INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68), Parent = badge })
		icon:SetAttribute("KeepColor", true)
		local text = chunky(pill, { Name = "Text", LayoutOrder = 2, Size = UDim2.fromOffset(0, 25), AutomaticSize = Enum.AutomaticSize.X }, 13)
		statPills[i] = { pill = pill, badge = badge, icon = icon, text = text }
	end
	-- the evolve bar: copies 2 / 3 toward the next stage, the 3 mini tiles
	local evoBar = framed(col, { Name = "EvolveBar", Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, -112, 0, 30) }, C("#3A3640"))
	local evoFill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -8), ZIndex = 2, Parent = evoBar }, {
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(C("#FFE38A"), C("#C98A12")) }),
	})
	local needs = chunky(evoBar, { Name = "Needs", Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), ZIndex = 4 }, 10)
	Kit.Fit(needs, 10, 7)
	local minis = {}
	for i = 1, Trainers.EvolveCount do
		minis[i] = TrainerTile.New({ Name = "Mini" .. i, px = 32, Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(Trainers.EvolveCount - i) * 36, 0, 129), Parent = col })
	end
	-- the gold EVOLVE button (the next stage's name on it) and the quiet EQUIP / UNEQUIP
	local evolveButton = Kit.Button("Gold", "Evolve", { Name = "Evolve", Position = UDim2.fromOffset(0, 166), Parent = col }, { width = 200, height = 40, textSize = 18 })
	evolveButton.Size = UDim2.new(1, 0, 0, 40)
	local equipButton = Kit.Button("Quiet", "Equip", { Name = "Equip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 212), Parent = col },
		{ width = 108, height = 30, textSize = 13 })
	-- (prompt 27b) the following trainers' real total, after the cap: "TOTAL +180% EXP (MAX +400%)", the other kinds under it
	local totalMain = chunky(col, { Name = "Total", Position = UDim2.fromOffset(0, 210), Size = UDim2.new(1, -114, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Gold }, 13)
	Kit.Fit(totalMain, 13, 8)
	local totalSub = Kit.Text({ Name = "TotalMore", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(0, 228),
		Size = UDim2.new(1, -114, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = col })
	Kit.Fit(totalSub, 10, 7)

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
	local mults = {}
	for i = 2, #Trainers.Stages do table.insert(mults, "x" .. Trainers.Stages[i].mult) end
	local chartNote = Kit.Text({ Name = "Note", Text = "3 of the same trainer at the same stage make 1 of the next (the boost " .. table.concat(mults, ", ")
		.. "; LV 20 +" .. math.floor(Trainers.MaxLevelBonus * 100 + 0.5) .. "%). He keeps the best level of the 3.",
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
		local equippedUids, equippedCopies = Trainers.CleanEquipped(s, slotCount)
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
		equippedPill.Text = string.format("EQUIPPED %d/%d", #equippedUids, slotCount)
		ownedPill.Text = string.format("OWNED %d/%d", #s.copies, Trainers.MaxCopies)
		local cap = math.floor(Trainers.BoostCap * 100 + 0.5)
		local totals = Trainers.TotalLines(equippedCopies)
		if totals[1] then
			totalMain.Text = string.format("TOTAL +%d%% %s (MAX +%d%%)", totals[1].pct, STAT[totals[1].kind][3], cap)
			local more = {}
			for i = 2, #totals do table.insert(more, string.format("+%d%% %s", totals[i].pct, string.lower(STAT[totals[i].kind][3]))) end
			totalSub.Text = if #more > 0 then table.concat(more, ", ") else "from the trainers following you"
		else
			totalMain.Text = string.format("TOTAL +0%% (MAX +%d%%)", cap)
			totalSub.Text = "Equip a trainer to get his boost"
		end
		-- the picked one
		current = map[pickedUid]
		local trainer = Trainers.ById[current.id]
		local stage = Trainers.Stages[current.s]
		local rarity = Trainers.RarityById[trainer.rarity]
		big:Set({ id = current.id, s = current.s, l = current.l, equipped = equippedSet[current.u] })
		nameText.Text = string.upper(trainer.name)
		rarityText.Text = string.upper(rarity.name) .. "  ·  " .. stage.name
		rarityText.TextColor3 = C(if rarity.id == "Secret" then rarity.color2 else rarity.color)
		levelText.Text = "LV " .. current.l
		if current.l >= Trainers.MaxLevel then
			expText.Text = "MAX LEVEL"
			fill.Size = UDim2.new(1, -8, 1, -8)
		else
			local need = Trainers.LevelXp(current.l, current.s)
			local k = math.clamp(current.x / need, 0, 1)
			expText.Text = shortNumber(current.x) .. " / " .. shortNumber(need) .. " EXP  ·  LV " .. (current.l + 1)
			fill.Size = UDim2.new(k, -8 * k, 1, -8)
		end
		local lines = Trainers.PerkLines(trainer, current)
		local icons = require(script.Parent.Parent.Config.UI).Icons
		for i, sp in ipairs(statPills) do
			local line = lines[i]
			sp.pill.Visible = line ~= nil
			if line then
				local look = STAT[line.kind]
				sp.badge.BackgroundColor3 = look[2]
				sp.icon.Image = icons[look[1]] or sp.icon.Image
				sp.text.Text = "+" .. line.pct .. "% " .. look[3]
				sp.text.TextColor3 = look[2]
				sp.pill:FindFirstChild("Edge").Color = look[2]
			end
		end
		-- evolving
		currentSet = Trainers.EvolveSet(s, current)
		local maxed = current.s >= #Trainers.Stages
		local ready = not maxed and #currentSet >= Trainers.EvolveCount
		local nextStage = Trainers.Stages[current.s + 1]
		local have = math.min(#currentSet, Trainers.EvolveCount)
		needs.Text = if maxed then "MAX STAGE" else string.format("%d/%d  ·  3x %s", have, Trainers.EvolveCount, stage.name)
		local k = if maxed then 1 else have / Trainers.EvolveCount
		evoFill.Size = UDim2.new(k, -8 * k, 1, -8)
		for i, mini in ipairs(minis) do
			local got = currentSet[i] ~= nil
			mini.cell.Visible = not maxed
			mini:Set({ id = current.id, s = current.s, l = 1, mini = true })
			for _, d in ipairs(mini.cell:GetDescendants()) do
				if d:IsA("ImageLabel") and d.Name == "Portrait" then d.ImageTransparency = if got then 0 else 0.7 end
				if d:IsA("ViewportFrame") then d.ImageTransparency = if got then 0 else 0.75 end
			end
			mini.button.BackgroundTransparency = if got then 0 else 0.6
		end
		-- (owner, prompt 48) "EVOLVE > IRON-BORN": the next stage's real name in its color (a 3 px dark stroke); "MAX STAGE"
		-- at LIMITLESS
		local evolveLabel = evolveButton:FindFirstChild("Label")
		if evolveLabel then evolveLabel.RichText = true end -- (set before the text: Theme.Uppercase leaves the tags alone)
		local nextText = if nextStage then string.format('<font color="#%s">%s</font>', C(nextStage.color):ToHex(), nextStage.name) else ""
		if maxed then
			Kit.SetButton(evolveButton, "Disabled", "Max stage")
		elseif ready then
			local bestLevel = 1
			for _, c in ipairs(currentSet) do bestLevel = math.max(bestLevel, c.l) end
			Kit.SetButton(evolveButton, "Gold", "Evolve > " .. nextText .. " · LV " .. bestLevel)
		else
			Kit.SetButton(evolveButton, "Disabled", "Evolve > " .. nextText)
		end
		local evolveStroke = evolveLabel and evolveLabel:FindFirstChildOfClass("UIStroke")
		if evolveStroke and not maxed then
			evolveStroke.Color, evolveStroke.Thickness, evolveStroke.Transparency = INK, 3, 0
		end
		local isEquipped = equippedSet[current.u] == true
		Kit.SetButton(equipButton, "Quiet", if isEquipped then "Unequip" else "Equip")
		-- the chart: this trainer at every stage
		for i, tile in ipairs(chartTiles) do
			tile:Set({ id = current.id, s = i, l = 1 })
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
		local stamp = chunky(root, { Name = "Stamp", Text = stage.name .. "!", AnchorPoint = Vector2.new(0.5, 0),
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
