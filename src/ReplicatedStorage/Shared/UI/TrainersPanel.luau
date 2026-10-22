-- TrainersPanel (prompt 24, 21 Oct; prompt 33, 22 Oct: rewritten to the planner's v5 mockups): the TRAINERS window's MY
-- TRAINERS screen (TrainerClient builds the window and calls this).
-- (prompt 52, 23 Oct: rebuilt to the owner's reference ref_my_trainers.png, two columns)
--   * The header (the window's title row): TRAINERS, then "● EQUIPPED 3/3" (green dot; a gold + buys the extra slot pass
--     while you don't have it) and "● OWNED 16/400" (teal dot), and EVOLUTIONS (the chart).
--   * LEFT: every trainer you own as a big tile (Shared/UI/TrainerTile), 4 across, best first (stage, then rarity, then
--     level), the ones following you with the gold check; PREV · PAGE 1/2 · NEXT and a small EVOLVE ALL under them.
--   * RIGHT, the picked one in a dark box: his tile big; the EXP bar ("LV 18" · 7.2K / 10K EXP · "LV 19", in the stage's
--     color); his boosts as big colored rows with an icon each; "NEEDS 3X BEAST-MODE · 2/3" with the 3 copies as mini
--     tiles (a missing one dim); a green EQUIP (dark UNEQUIP while he follows you) and the next stage as a button on its
--     own background ("COLOSSUS" / "LV 18"; "MAX STAGE" at the end); the total line small under them.
--     (owner, 23 Oct) The next-stage button is always at full brightness, its stage effect moving. With 3 copies: only a
--     soft glow in the stage color breathing behind it and a highlight running round its outline (Shared/UI/ReadyGlow; no
--     tag), and a tap asks, then evolves. Without: a tap bounces the NEEDS line. Its level is the one he'll have after evolving (the best of the 3, TrainerService combine).
--   * The size comes from the room: on a phone (short screen) 2-3 rows of tiles and the detail side by side (his tile,
--     the boosts and the needs line next to it, the bar and the buttons under); on a PC 4 rows and the detail stacked
--     like the reference. panel.layout(bodyHeight, maxWidth) -> the width it needs.
--   * The evolutions chart (EVOLUTIONS): a wide gold-edged panel over the window, TRAINER EVOLUTIONS, the picked trainer
--     5 times (BASE > ... > LIMITLESS, LV 1), FROM ROLLS / 3x BASE ... under them in gray italic. (owner, 23 Oct) A stage
--     you've never had a trainer at (state.discovered; BASE always) is hidden there: his silhouette, "???", no LV, a dark
--     background with no effect, a gray border (the caption stays). The first time the chart opens after you reach a new
--     stage, its tile flips over with a gold burst and a sparkle (Discovery list "TrainerStages"). Only the chart: the
--     next-stage button always names the real stage.
--   * The evolve moment (panel.evolved): the 3 fly together, shake, a white flash, the new one slams in with its name
--     stamp, confetti in the stage color, a big sound.
--   * (prompt 31) a trainer you haven't seen here yet turns over with a gold burst.
-- Nothing yet: "NO TRAINERS YET" and a red GO TO TRAINER AGENCY button that takes you there (a fade; 10 s cooldown).
-- TrainersPanel.Build(parent, header) -> { frame, refresh(), layout(h, w), evolved(info), closeOverlays() }.
-- header = { row = the window's title row (the pills go in it), group = the window's group (the chart goes over it) }.
-- Every change goes to the server (remote "Trainers").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)
local Pieces = require(script.Parent.Pieces)
local Discovery = require(script.Parent.Discovery)
local TrainerTile = require(script.Parent.TrainerTile)
local ReadyGlow = require(script.Parent.ReadyGlow)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)
local Trainers = require(script.Parent.Parent.Config.Trainers)
local Monetization = require(script.Parent.Parent.Config.Monetization)
local AlterFX = require(script.Parent.Parent.VFX.AlterFX)

local New, Colors = Theme.New, Theme.Colors
local INK = Color3.fromHex("#0A090B")

local TrainersPanel = {}

local COLS, GAP = 4, 8
local PAGER_H = 34
local MAX_TILE = 124 -- (phone: as many rows as fit with tiles up to this size)
local STACK_FROM = 380 -- body height (mockup px) from which the detail stacks like the reference (a PC); under it, the phone layout
local SIDE_BOX = 176 -- (phone) the boosts box / needs line next to his big tile
local BOX_H = 82
local BUTTON_H = 46
local MINI, MINI_GAP = 30, 4
local CHART_TILE, CHEVRON = 140, 22

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

local function shortNumber(n: number): string
	if n >= 10000 then return (string.format("%.1fK", n / 1000):gsub("%.0K", "K")) end
	return tostring(math.floor(n))
end

-- the rainbow (LIMITLESS)
local function rainbow(): ColorSequence
	local keys = {}
	local hues = { 0.95, 0.08, 0.15, 0.33, 0.52, 0.72 }
	for i, h in ipairs(hues) do keys[i] = ColorSequenceKeypoint.new((i - 1) / (#hues - 1), Color3.fromHSV(h, 0.6, 1)) end
	return ColorSequence.new(keys)
end

-- a gold underline (under the screen titles, as in the references)
local function underline(parent, props)
	local bar = New("Frame", { Name = "Underline", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(64, 4), Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C("#FFF3C4")), ColorSequenceKeypoint.new(0.5, C("#F6C75A")),
			ColorSequenceKeypoint.new(1, C("#C98A12")) }) }),
	})
	for k, v in pairs(props or {}) do bar[k] = v end
	return bar
end
TrainersPanel.Underline = underline

function TrainersPanel.Build(parent: Instance, header)
	header = header or {}
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trainers", 30)
	local PASS = Monetization.PassByKey and Monetization.PassByKey[Trainers.ExtraSlotPass]
	local panel = {}
	local page, pickedUid = 1, nil
	local holder = New("Frame", { Name = "Trainers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local L = { mode = "side", rows = 0, tile = 0, big = 0, bodyH = 0, gridW = 0, detailW = 0 }

	local function state() return Trainers.Migrate((ClientData.Get() or {}).trainers) end
	local function slots(): number return player:GetAttribute("TrainerSlots") or 1 end
	-- (prompt 52) best first: the stage, then the rarity, then the level
	local function sorted(s)
		local list = table.clone(s.copies)
		table.sort(list, function(a, b)
			if a.s ~= b.s then return a.s > b.s end
			local ra, rb = Trainers.ById[a.id].index, Trainers.ById[b.id].index
			if ra ~= rb then return ra > rb end
			if a.l ~= b.l then return a.l > b.l end
			return a.u < b.u
		end)
		return list
	end

	------------------------------------------------------------------------
	-- The header: EQUIPPED / OWNED pills, EVOLUTIONS (in the window's title row)
	------------------------------------------------------------------------
	local headerItems = {}
	local function headerPill(name: string, dotColor: Color3, order: number)
		local pill = New("Frame", { Name = name, LayoutOrder = order, BackgroundColor3 = C("#141317"), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
			Parent = header.row or holder }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = C("#2E2B33"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		New("Frame", { Name = "Dot", LayoutOrder = 1, BackgroundColor3 = dotColor, Size = UDim2.fromOffset(9, 9), Parent = pill }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		local text = Kit.Text({ Name = "Text", LayoutOrder = 2, Text = "", Font = "Strong", TextSize = 14, Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
		table.insert(headerItems, pill)
		return pill, text
	end
	local equippedPill, equippedText = headerPill("EquippedPill", C("#4BE07A"), 10)
	local _ownedPill, ownedText = headerPill("OwnedPill", C("#2FD4C4"), 11)
	-- the extra slot pass: a small gold + at the end of the EQUIPPED pill (while you don't have it)
	local slotPlus = New("TextButton", { Name = "ExtraSlot", LayoutOrder = 3, Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Gold,
		Size = UDim2.fromOffset(20, 20), Visible = false, Parent = equippedPill }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = INK, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Pieces.Icon("plus", INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), Parent = slotPlus })
		:SetAttribute("KeepColor", true)
	slotPlus.Activated:Connect(function()
		if PASS and PASS.id and not player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) then
			Audio.PlayUI("Click")
			MarketplaceService:PromptGamePassPurchase(player, PASS.id)
		end
	end)
	local chartButton = Kit.Button("Dark", "Evolutions", { Name = "EvolutionsButton", LayoutOrder = 12, Parent = header.row or holder },
		{ width = 104, height = 30, textSize = 12 })
	table.insert(headerItems, chartButton)
	local function headerShown()
		for _, item in ipairs(headerItems) do item.Visible = holder.Visible end
	end
	holder:GetPropertyChangedSignal("Visible"):Connect(headerShown)
	headerShown()

	------------------------------------------------------------------------
	-- LEFT: the grid and the paging row
	------------------------------------------------------------------------
	local grid = New("Frame", { Name = "Grid", BackgroundTransparency = 1, Parent = holder })
	local tiles = {}
	local detail -- (below)
	local function buildGrid()
		for _, tile in ipairs(tiles) do tile.cell:Destroy() end
		table.clear(tiles)
		for i = 1, COLS * L.rows do
			local column, row = (i - 1) % COLS, (i - 1) // COLS
			local tile = TrainerTile.New({ Name = "Tile" .. i, px = L.tile, Size = UDim2.fromOffset(L.tile, L.tile),
				Position = UDim2.fromOffset(column * (L.tile + GAP), row * (L.tile + GAP)), Parent = grid })
			tile.button.Activated:Connect(function()
				if not tile.copy then return end
				pickedUid = tile.copy.u
				panel.refresh()
				-- (prompt 54: bounce + select sound; the detail slides in. After the refresh: the slide-in's fade keeps the
				-- transparencies it finds, so it must find the new trainer's)
				Kit.SelectFeedback(tile.button, detail)
			end)
			tiles[i] = tile
		end
	end
	local pager = New("Frame", { Name = "Pager", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, PAGER_H), Parent = holder })
	local trio = New("Frame", { Name = "Pages", BackgroundTransparency = 1, Size = UDim2.fromOffset(244, PAGER_H), Parent = pager })
	local prev = Kit.Button("Dark", "Prev", { Name = "Prev", Position = UDim2.fromOffset(0, 0), Parent = trio }, { width = 70, height = PAGER_H, textSize = 15 })
	local pageText = chunky(trio, { Name = "Page", Position = UDim2.fromOffset(74, 0), Size = UDim2.fromOffset(96, PAGER_H) }, 17)
	Kit.Fit(pageText, 17, 10)
	local nextButton = Kit.Button("Dark", "Next", { Name = "Next", Position = UDim2.fromOffset(174, 0), Parent = trio }, { width = 70, height = PAGER_H, textSize = 15 })
	local evolveAll = Kit.Button("Dark", "Evolve all", { Name = "EvolveAll", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = pager },
		{ width = 92, height = PAGER_H, textSize = 11 })
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
	-- RIGHT: the picked one (a dark box)
	------------------------------------------------------------------------
	detail = New("Frame", { Name = "Detail", BackgroundColor3 = C("#151418"), Parent = holder }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Color = C("#2A2830"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local big = nil -- his big tile (made again when its size changes)
	local function buildBig()
		if big then big.cell:Destroy() end
		big = TrainerTile.New({ Name = "Big", px = L.big, Size = UDim2.fromOffset(L.big, L.big), Parent = detail })
	end
	-- the EXP bar: a pill in the stage's color, "LV 18" and "LV 19" chips on its ends, the EXP in the middle
	local expBar = New("Frame", { Name = "ExpBar", BackgroundColor3 = C("#0E0D10"), Size = UDim2.fromOffset(100, 22), Parent = detail }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local expEdge = New("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = expBar })
	local expFill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(2, 2), Size = UDim2.new(0, 0, 1, -4), ZIndex = 2,
		Parent = expBar }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local expGradient = New("UIGradient", { Rotation = 90, Parent = expFill })
	local function endChip(right: boolean)
		local chip = New("Frame", { Name = if right then "To" else "From", BackgroundColor3 = INK, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(if right then 1 else 0, 0.5),
			Position = UDim2.new(if right then 1 else 0, if right then -3 else 3, 0.5, 0), Size = UDim2.fromOffset(40, 16), ZIndex = 4, Parent = expBar }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.55, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local text = chunky(chip, { Name = "Text", Size = UDim2.fromScale(1, 1), ZIndex = 5 }, 10)
		Kit.Fit(text, 10, 7)
		return chip, text
	end
	local _fromChip, lvFrom = endChip(false)
	local toChip, lvTo = endChip(true)
	local expText = chunky(expBar, { Name = "Exp", Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -92, 1, 0), ZIndex = 4 }, 13)
	Kit.Fit(expText, 13, 8)
	-- the boosts: big colored rows with an icon each, in a dark box
	local boostBox = New("Frame", { Name = "Boosts", BackgroundColor3 = C("#0E0D10"), ClipsDescendants = true, Parent = detail }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = C("#2E2B33"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(18, 10),
			ImageTransparency = 0.93, Size = UDim2.fromScale(1, 1) }),
	})
	local STAT = { gains = { "zap", C("#5AA8FF"), "EXP" }, coins = { "coin", C("#F6C75A"), "COINS" }, progress = { "arrow-big-up", C("#5CE07A"), "PROGRESS" },
		maxStamina = { "heart-pulse", C("#FF6A7A"), "MAX STAMINA" }, staminaRegen = { "heart-pulse", C("#36C2C2"), "STAMINA REGEN" } }
	local boostRows = {}
	for i = 1, 3 do
		local row = New("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 6 + (i - 1) * 24), Size = UDim2.new(1, -16, 0, 22),
			ZIndex = 2, Parent = boostBox })
		local badge = New("Frame", { Name = "Badge", BackgroundColor3 = Colors.Gold, Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(20, 20), ZIndex = 2, Parent = row }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = INK, Thickness = 1.2 }),
		})
		local icon = Pieces.Icon("zap", INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68), ZIndex = 3,
			Parent = badge })
		icon:SetAttribute("KeepColor", true)
		local text = chunky(row, { Name = "Text", Position = UDim2.fromOffset(27, 0), Size = UDim2.new(1, -27, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, 18)
		Kit.Fit(text, 18, 10)
		boostRows[i] = { row = row, badge = badge, icon = icon, text = text }
	end
	-- "NEEDS 3X BEAST-MODE · 2/3" and the 3 copies as mini tiles
	local needs = chunky(detail, { Name = "Needs", TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }, 12)
	Kit.Fit(needs, 12, 8, 2)
	local minis = {}
	for i = 1, Trainers.EvolveCount do
		minis[i] = TrainerTile.New({ Name = "Mini" .. i, px = MINI, Size = UDim2.fromOffset(MINI, MINI), Parent = detail })
	end
	-- the two big buttons: EQUIP (green; dark UNEQUIP) and the next stage on its own background
	local equipButton = Kit.Button("Green", "Equip", { Name = "Equip", Parent = detail }, { width = 100, height = BUTTON_H, textSize = 20 })
	-- (prompt 61) FEED: a trainer snack (Config/Style.Snacks, bought at the Agency) for the picked trainer's EXP; a small
	-- popover with the three and how many you have
	-- (a slim pill at the end of the EXP bar, with a 44 px tap area round it)
	local feed = { size = 56 }
	feed.button = New("TextButton", { Name = "Feed", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#232027"), Size = UDim2.fromOffset(feed.size, 22),
		ZIndex = 6, Parent = detail }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.fromHex("#4A4652"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Kit.Text({ Name = "Label", Text = "FEED", Font = "Chunky", TextSize = 12, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = feed.button })
	local feedHit = New("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 0, 44), ZIndex = 8, Parent = feed.button })
	feed.pop = New("Frame", { Name = "FeedPop", BackgroundColor3 = Color3.fromHex("#0E0E11"), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(250, 58),
		Visible = false, ZIndex = 30, Parent = detail }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 1.5 }),
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local nextCell = New("Frame", { Name = "NextCell", BackgroundTransparency = 1, Parent = detail })
	local nextStageButton = New("TextButton", { Name = "NextStage", Text = "", AutoButtonColor = false, BackgroundColor3 = C("#1A181B"), ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = nextCell }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	local nextEdge = New("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = nextStageButton })
	-- (owner, 23 Oct) ready: the soft glow behind it and a highlight travelling round its outline (Shared/UI/ReadyGlow)
	local nextReady = ReadyGlow.New(nextStageButton, { stroke = nextEdge, pad = 22 })
	-- (owner, 23 Oct) the picture has the button's own rounded corners (the outline sits on its edge: the stroke is drawn
	-- outside); the moving effect sits in a clip inset by ~0.3 of the radius, so no square corner shows past the curve
	local nextHex = New("ImageLabel", { Name = "HexArt", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 2,
		Parent = nextStageButton }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	local nextClip = New("Frame", { Name = "Clip", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6),
		ZIndex = 3, Parent = nextStageButton })
	local nextEvo = New("ImageLabel", { Name = "EvoArt", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.25, Size = UDim2.fromScale(1, 1),
		ZIndex = 3, Parent = nextClip })
	local nextName = chunky(nextStageButton, { Name = "Stage", Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0.55, -4), ZIndex = 6 }, 20)
	Kit.Fit(nextName, 20, 9)
	local nextGradient = New("UIGradient", { Name = "Colors", Enabled = false, Parent = nextName })
	local nextLevel = chunky(nextStageButton, { Name = "Level", Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(1, 0.38), ZIndex = 6 }, 13)
	Theme.BindPress(nextStageButton)
	-- its stage effect moves (like the tiles: IRON-BORN pulses, BEAST-MODE / LIMITLESS turn, COLOSSUS flashes), only while
	-- the panel is on screen
	local nextStageId = nil
	task.spawn(function()
		while true do
			task.wait(1 / 30)
			local gui = holder:FindFirstAncestorOfClass("ScreenGui")
			if holder.Visible and gui and gui.Enabled and nextStageId and nextEvo.Visible then
				local t = os.clock()
				if nextStageId == "IronBorn" then
					nextEvo.ImageTransparency = 0.08 + 0.25 * (0.5 + 0.5 * math.sin(t * 2.6))
				elseif nextStageId == "BeastMode" or nextStageId == "Limitless" then
					nextEvo.Rotation = (t * (if nextStageId == "Limitless" then 22 else 14)) % 360
				elseif nextStageId == "Colossus" then
					local k = (t * 0.7) % 1
					nextEvo.ImageTransparency = if k < 0.04 or (k > 0.08 and k < 0.11) then 0 else 0.25
				end
			end
		end
	end)
	-- (prompt 27b) the following trainers' real total, after the cap: "TOTAL +180% EXP (MAX +400%)"
	local totalMain = chunky(detail, { Name = "Total", TextColor3 = Colors.Gold }, 11)
	Kit.Fit(totalMain, 11, 7)

	-- places the detail's pieces for the layout (side = phone, stack = PC / the reference)
	local function placeDetail()
		local w, b = L.detailW, L.big
		local function at(gui, x, y, width, height)
			gui.Position = UDim2.fromOffset(x, y)
			if width then gui.Size = UDim2.fromOffset(width, height) end
		end
		if L.mode == "side" then
			local rx, rw = 16 + b, w - (16 + b) - 8
			at(big.cell, 8, 8)
			at(boostBox, rx, 8, rw, BOX_H)
			at(needs, rx, 16 + BOX_H, rw, 28)
			for i, mini in ipairs(minis) do at(mini.cell, rx + (i - 1) * (MINI + MINI_GAP), 48 + BOX_H) end
			at(expBar, 8, 16 + b, w - 16, 22)
			local by = b + 46
			local bw = math.floor((w - 24) / 2)
			at(equipButton, 8, by, bw, BUTTON_H)
			at(expBar, 8, 16 + b, w - 22 - feed.size, 22)
			at(feed.button, w - 8 - feed.size, 16 + b)
			at(feed.pop, math.max(8, w - 8 - 250), 12 + b)
			at(nextCell, 16 + bw, by, w - 24 - bw, BUTTON_H)
			at(totalMain, 8, by + BUTTON_H + 6, w - 16, 14)
		else
			at(big.cell, math.floor((w - b) / 2), 8)
			at(expBar, 8, 16 + b, w - 16, 22)
			at(boostBox, 8, b + 46, w - 16, BOX_H)
			local minisW = Trainers.EvolveCount * MINI + (Trainers.EvolveCount - 1) * MINI_GAP
			at(needs, 8, b + 136, w - 24 - minisW, 30)
			for i, mini in ipairs(minis) do at(mini.cell, w - 8 - minisW + (i - 1) * (MINI + MINI_GAP), b + 136) end
			local by = b + 174
			local bw = math.floor((w - 24) / 2)
			at(equipButton, 8, by, bw, BUTTON_H)
			at(expBar, 8, 16 + b, w - 22 - feed.size, 22)
			at(feed.button, w - 8 - feed.size, 16 + b)
			at(feed.pop, math.max(8, w - 8 - 250), 12 + b)
			at(nextCell, 16 + bw, by, w - 24 - bw, BUTTON_H)
			at(totalMain, 8, by + BUTTON_H + 6, w - 16, 14)
		end
	end

	-- the layout for the room the window has (body height and the widest it may be, mockup px); returns the width it needs
	function panel.layout(bodyH: number, maxW: number): number
		local mode = if bodyH >= STACK_FROM then "stack" else "side"
		local gridH = bodyH - PAGER_H - GAP
		local rows = if mode == "stack" then 4 else math.clamp(math.ceil((gridH + GAP) / (MAX_TILE + GAP)), 1, 4)
		local tile = math.floor((gridH - (rows - 1) * GAP) / rows)
		local bigSize, detailW
		if mode == "stack" then
			bigSize = math.clamp(bodyH - 250, 120, 210)
			detailW = math.max(bigSize + 16, 220)
		else
			bigSize = math.clamp(bodyH - 120, 100, 210)
			detailW = 8 + bigSize + 8 + SIDE_BOX + 8
		end
		local gridW = COLS * tile + (COLS - 1) * GAP
		if gridW + 14 + detailW > maxW then
			tile = math.max(56, math.floor((maxW - 14 - detailW - (COLS - 1) * GAP) / COLS))
			gridW = COLS * tile + (COLS - 1) * GAP
		end
		local gridChanged = tile ~= L.tile or rows ~= L.rows
		local bigChanged = bigSize ~= L.big
		L.mode, L.rows, L.tile, L.big, L.bodyH, L.gridW, L.detailW = mode, rows, tile, bigSize, bodyH, gridW, detailW
		if gridChanged then buildGrid() end
		if bigChanged or not big then buildBig() end
		grid.Size = UDim2.fromOffset(gridW, rows * tile + (rows - 1) * GAP)
		pager.Position = UDim2.fromOffset(0, bodyH - PAGER_H)
		pager.Size = UDim2.fromOffset(gridW, PAGER_H)
		trio.Position = UDim2.fromOffset(math.max(0, math.floor((gridW - 96 - 244) / 2)), 0)
		detail.Position = UDim2.fromOffset(gridW + 14, 0)
		detail.Size = UDim2.fromOffset(detailW, bodyH)
		detail:SetAttribute("HomePosition", detail.Position)
		placeDetail()
		if gridChanged or bigChanged then panel.refresh() end
		return gridW + 14 + detailW
	end

	------------------------------------------------------------------------
	-- The evolutions chart and the evolve question (over the window)
	------------------------------------------------------------------------
	local overParent = header.group or holder
	local function overlay(name: string, width: number, height: number, z: number)
		local shade = New("TextButton", { Name = name .. "Shade", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 40, 1, 40), Visible = false, ZIndex = z, Parent = overParent }, {
			New("UICorner", { CornerRadius = UDim.new(0, 16) }),
		})
		local box = New("Frame", { Name = name, BackgroundColor3 = C("#121115"), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height), Active = true, Visible = false, ZIndex = z + 1, Parent = overParent }, {
			New("UICorner", { CornerRadius = UDim.new(0, 16) }),
			New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(18, 10),
				ImageTransparency = 0.9, Size = UDim2.fromScale(1, 1), ZIndex = z + 1 }),
		})
		-- a gold edge with a soft gold glow outside
		New("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box }, {
			New("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C("#FFE08A")), ColorSequenceKeypoint.new(1, C("#C98A12")) }) }),
		})
		local glow = New("Frame", { Name = "Glow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 6, 1, 6), ZIndex = z + 1, Parent = box }, { New("UICorner", { CornerRadius = UDim.new(0, 19) }) })
		New("UIStroke", { Color = C("#F6C75A"), Thickness = 8, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = glow })
		local function show(on: boolean)
			shade.Visible, box.Visible = on, on
		end
		shade.Activated:Connect(function() Audio.PlayUI("Click") show(false) end)
		local close = Kit.CloseButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), ZIndex = z + 4, Parent = box })
		close.Activated:Connect(function() show(false) end)
		return box, show
	end

	local CHART_W = 5 * CHART_TILE + 4 * CHEVRON + 48
	local chart, showChart = overlay("Chart", CHART_W, 70 + CHART_TILE + 40, 40)
	Kit.Text({ Name = "Title", Text = "Trainer evolutions", Font = "Title", TextSize = 30, Upper = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, -120, 0, 36), ZIndex = 44, Parent = chart })
	underline(chart, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), ZIndex = 44 })
	local chartRow = New("Frame", { Name = "Row", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(5 * CHART_TILE + 4 * CHEVRON, CHART_TILE + 30), ZIndex = 44, Parent = chart })
	local chartTiles = {}
	local revealing = {} -- [stage id] = true: newly discovered, still "???" until its flip plays
	for i, stage in ipairs(Trainers.Stages) do
		local x = (i - 1) * (CHART_TILE + CHEVRON)
		chartTiles[i] = TrainerTile.New({ Name = stage.id, px = CHART_TILE, Size = UDim2.fromOffset(CHART_TILE, CHART_TILE), Position = UDim2.fromOffset(x, 0), Parent = chartRow })
		Kit.Text({ Name = "Caption" .. i, Text = stage.from, Font = "Title", KeepItalic = true, TextSize = 13, TextColor3 = C("#8C8994"), Position = UDim2.fromOffset(x, CHART_TILE + 8),
			Size = UDim2.fromOffset(CHART_TILE, 18), ZIndex = 45, Parent = chartRow })
		if i < #Trainers.Stages then
			Pieces.Icon("chevron-left", C("#D8D6DE"), { Name = "Arrow" .. i, Rotation = 180, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + CHART_TILE + CHEVRON / 2, CHART_TILE / 2),
				Size = UDim2.fromOffset(20, 20), ZIndex = 45, Parent = chartRow }):SetAttribute("KeepColor", true)
		end
	end

	-- "EVOLVE?" (the next-stage button asks first)
	local ask, showAsk = overlay("Ask", 380, 176, 50)
	Kit.Text({ Name = "Title", Text = "Evolve?", Font = "Title", TextSize = 28, Upper = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, -100, 0, 34), ZIndex = 54, Parent = ask })
	local askLine = chunky(ask, { Name = "Line", RichText = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(1, -40, 0, 50), ZIndex = 54 }, 15)
	Kit.Fit(askLine, 15, 9, 2)
	local askYes = Kit.Button("Gold", "Evolve", { Name = "Yes", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -6, 1, -14), ZIndex = 54, Parent = ask },
		{ width = 150, height = 46, textSize = 20 })
	local askNo = Kit.Button("Dark", "Cancel", { Name = "No", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 6, 1, -14), ZIndex = 54, Parent = ask },
		{ width = 120, height = 46, textSize = 16 })

	function panel.closeOverlays()
		showChart(false)
		showAsk(false)
	end
	holder:GetPropertyChangedSignal("Visible"):Connect(function() if not holder.Visible then panel.closeOverlays() end end)

	------------------------------------------------------------------------
	-- Refresh
	------------------------------------------------------------------------
	local currentSet, current = {}, nil
	function panel.refresh()
		if L.rows == 0 or not big then return end -- (no layout yet)
		local s = state()
		local list = sorted(s)
		local slotCount = slots()
		local perPage = COLS * L.rows
		local equippedUids, equippedCopies = Trainers.CleanEquipped(s, slotCount)
		local equippedSet = {}
		for _, u in ipairs(equippedUids) do equippedSet[u] = true end
		local pages = math.max(1, math.ceil(#list / perPage))
		page = math.clamp(page, 1, pages)
		equippedText.Text = string.format("EQUIPPED %d/%d", #equippedUids, slotCount)
		ownedText.Text = string.format("OWNED %d/%d", #s.copies, Trainers.MaxCopies)
		slotPlus.Visible = PASS ~= nil and PASS.id ~= nil and player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) ~= true
		empty.Visible = #list == 0
		grid.Visible, pager.Visible, detail.Visible = #list > 0, #list > 0, #list > 0
		chartButton.Visible = holder.Visible and #list > 0
		if #list == 0 then return end
		-- (prompt 31) new trainers since you last looked turn over with a gold burst
		local discovered = TrainersPanel.Discovered((ClientData.Get() or {}).trainers)
		local fresh = if holder.Visible then Discovery.New("Trainers", discovered) else {}
		local map = Trainers.CopyByUid(s)
		if not pickedUid or not map[pickedUid] then pickedUid = list[1].u end
		for i, tile in ipairs(tiles) do
			local copy = list[(page - 1) * perPage + i]
			tile.copy = copy
			tile.cell.Visible = copy ~= nil
			if copy then
				tile:Set({ id = copy.id, s = copy.s, l = copy.l, equipped = equippedSet[copy.u] })
				local scale = tile.cell:FindFirstChild("Picked") or New("UIScale", { Name = "Picked", Parent = tile.cell })
				scale.Scale = if copy.u == pickedUid then 1.05 else 1
				if fresh[copy.id] then
					fresh[copy.id] = nil
					Discovery.Reveal(tile.button)
				end
			end
		end
		if holder.Visible then Discovery.Seen("Trainers", discovered) end
		pageText.Text = "PAGE " .. page .. "/" .. pages
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
		Kit.SetButton(evolveAll, if canAny then "Dark" else "Disabled", "Evolve all")
		local cap = math.floor(Trainers.BoostCap * 100 + 0.5)
		local totals = Trainers.TotalLines(equippedCopies)
		if totals[1] then
			totalMain.Text = string.format("TOTAL +%d%% %s (MAX +%d%%)", totals[1].pct, STAT[totals[1].kind][3], cap)
		else
			totalMain.Text = string.format("TOTAL +0%% (MAX +%d%%)", cap)
		end
		-- the picked one
		current = map[pickedUid]
		local trainer = Trainers.ById[current.id]
		local stage = Trainers.Stages[current.s]
		local stageColor = C(stage.color)
		big:Set({ id = current.id, s = current.s, l = current.l, equipped = equippedSet[current.u] })
		-- the EXP bar, in the stage's color
		expEdge.Color = stageColor
		expGradient.Color = ColorSequence.new(stageColor:Lerp(Color3.new(1, 1, 1), 0.35), stageColor:Lerp(Color3.new(0, 0, 0), 0.25))
		lvFrom.Text = "LV " .. current.l
		if current.l >= Trainers.MaxLevel then
			expText.Text = "MAX LEVEL"
			toChip.Visible = false
			expFill.Size = UDim2.new(1, -4, 1, -4)
		else
			local need = Trainers.LevelXp(current.l, current.s)
			local k = math.clamp(current.x / need, 0, 1)
			expText.Text = shortNumber(current.x) .. " / " .. shortNumber(need) .. " EXP"
			toChip.Visible = true
			lvTo.Text = "LV " .. (current.l + 1)
			expFill.Size = UDim2.new(k, -4 * k, 1, -4)
		end
		-- the boosts
		local lines = Trainers.PerkLines(trainer, current)
		local icons = require(script.Parent.Parent.Config.UI).Icons
		for i, r in ipairs(boostRows) do
			local line = lines[i]
			r.row.Visible = line ~= nil
			if line then
				local look = STAT[line.kind]
				r.badge.BackgroundColor3 = look[2]
				r.icon.Image = icons[look[1]] or r.icon.Image
				r.text.Text = "+" .. line.pct .. "% " .. look[3]
				r.text.TextColor3 = look[2]
			end
		end
		-- evolving
		currentSet = Trainers.EvolveSet(s, current)
		local maxed = current.s >= #Trainers.Stages
		local ready = not maxed and #currentSet >= Trainers.EvolveCount
		local nextStage = Trainers.Stages[current.s + 1]
		local have = math.min(#currentSet, Trainers.EvolveCount)
		needs.Visible = not maxed -- (the button says MAX STAGE)
		needs.Text = if maxed then "" else string.format("NEEDS %dX %s · %d/%d", Trainers.EvolveCount, stage.name, have, Trainers.EvolveCount)
		for i, mini in ipairs(minis) do
			local got = currentSet[i] ~= nil
			mini.cell.Visible = not maxed
			mini:Set({ id = current.id, s = current.s, l = 1, mini = true })
			for _, d in ipairs(mini.cell:GetDescendants()) do
				if d:IsA("ImageLabel") and d.Name == "Portrait" then d.ImageTransparency = if got then 0 else 0.7 end
				if d:IsA("ViewportFrame") then d.ImageTransparency = if got then 0 else 0.75 end
			end
			mini.button.BackgroundTransparency = if got then 0 else 0.6
			local dim = mini.button:FindFirstChild("Missing") or New("Frame", { Name = "Missing", BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1),
				ZIndex = 12, Parent = mini.button })
			dim.BackgroundTransparency = if got then 1 else 0.45
		end
		-- the next stage's button: its background, its name in its color, the level he'll keep; dim until 3 copies
		local bestLevel = current.l
		for _, c in ipairs(currentSet) do bestLevel = math.max(bestLevel, c.l) end
		if maxed then
			nextHex.Visible, nextEvo.Visible = false, false
			nextStageButton.BackgroundColor3 = C("#232127")
			nextEdge.Color = C("#3A3740")
			nextName.Text = "MAX STAGE"
			nextName.TextColor3 = C("#8C8994")
			nextGradient.Enabled = false
			nextLevel.Text = ""
			nextStageId = nil
			nextReady:Set(false, C("#3A3740"))
		else
			local art = Trainers.StageArt[nextStage.id]
			nextHex.Visible, nextEvo.Visible = art ~= nil, art ~= nil
			if art then nextHex.Image, nextEvo.Image = art.hex, art.evo end
			nextStageButton.BackgroundColor3 = C(nextStage.base)
			nextEdge.Color = C(nextStage.color)
			nextName.Text = nextStage.name
			nextGradient.Enabled = nextStage.rainbow == true
			if nextStage.rainbow then nextGradient.Color = rainbow() end
			nextName.TextColor3 = if nextStage.rainbow then Color3.new(1, 1, 1) else C(nextStage.color)
			nextLevel.Text = "LV " .. bestLevel
			-- (owner, 23 Oct) always full brightness; ready = only the pulsing glow in its color (no tag)
			nextStageId = nextStage.id
			nextEvo.Rotation, nextEvo.ImageTransparency = 0, 0.25
			local turning = nextStage.id == "BeastMode" or nextStage.id == "Limitless"
			nextEvo.SizeConstraint = if turning then Enum.SizeConstraint.RelativeXX else Enum.SizeConstraint.RelativeXY
			nextEvo.AnchorPoint, nextEvo.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			nextEvo.Size = if turning then UDim2.fromScale(1.2, 1.2) else UDim2.fromScale(1, 1)
			nextReady:Set(ready, C(nextStage.color))
		end
		local isEquipped = equippedSet[current.u] == true
		Kit.SetButton(equipButton, if isEquipped then "Dark" else "Green", if isEquipped then "Unequip" else "Equip")
		-- the chart and the question: this trainer
		local discovered = s.discovered or { Base = true }
		for i, tile in ipairs(chartTiles) do
			local stageId = Trainers.Stages[i].id
			tile:Set({ id = current.id, s = i, l = 1, hidden = i > 1 and (not discovered[stageId] or revealing[stageId] == true) })
		end
		if ready then
			askLine.Text = string.format('%d %s <font color="#%s">%s</font> make 1 <font color="#%s">%s</font> · LV %d', Trainers.EvolveCount,
				string.upper(trainer.name), stageColor:ToHex(), stage.name, C(nextStage.color):ToHex(), nextStage.name, bestLevel)
		end
	end

	-- (prompt 61) FEED: the popover with the snacks you have; a tap feeds one to this trainer
	local function openFeed()
		if not current then return end
		Audio.PlayUI("Click")
		local Style = require(script.Parent.Parent.Config.Style)
		local data = ClientData.Get()
		local snacks = type(data.snacks) == "table" and data.snacks or {}
		for _, child in ipairs(feed.pop:GetChildren()) do
			if child:IsA("GuiButton") then child:Destroy() end
		end
		local any = false
		for order, snack in ipairs(Style.Snacks) do
			local have = tonumber(snacks[snack.id]) or 0
			any = any or have > 0
			local b = Kit.Button(if have > 0 then "Dark" else "Disabled", string.upper(snack.id) .. " x" .. have, { Name = snack.id, LayoutOrder = order, ZIndex = 31,
				Parent = feed.pop }, { width = 74, height = 44, textSize = 12 })
			b.Activated:Connect(function()
				if have <= 0 or not current then return end
				Audio.PlayUI("Click")
				remote:FireServer("Feed", current.u, snack.id)
				feed.pop.Visible = false
			end)
		end
		if not any then
			feed.pop.Visible = false
			require(script.Parent.Notify).Hint("Buy trainer snacks at the Trainer Agency (SNACKS).")
			return
		end
		feed.pop.Visible = not feed.pop.Visible
	end
	feed.button.Activated:Connect(openFeed)
	feedHit.Activated:Connect(openFeed)

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
	nextStageButton.Activated:Connect(function()
		if not current or current.s >= #Trainers.Stages then return end
		Audio.PlayUI("Click")
		if #currentSet < Trainers.EvolveCount then
			-- (owner, 23 Oct) not yet: the NEEDS line bounces so you see what's missing
			if needs:GetAttribute("Hopping") then return end
			needs:SetAttribute("Hopping", true)
			local home = needs.Position
			needs.TextColor3 = Colors.Gold
			Theme.Tween(needs, { Position = home - UDim2.fromOffset(0, 5) }, 0.08, Enum.EasingStyle.Quad)
			task.delay(0.08, function()
				Theme.Tween(needs, { Position = home }, 0.25, Enum.EasingStyle.Bounce)
				task.delay(0.45, function()
					needs.Position = home
					needs.TextColor3 = Color3.new(1, 1, 1)
					needs:SetAttribute("Hopping", nil)
				end)
			end)
			return
		end
		showAsk(true)
	end)
	askYes.Activated:Connect(function()
		showAsk(false)
		if not current or current.s >= #Trainers.Stages or #currentSet < Trainers.EvolveCount then return end
		remote:FireServer("Evolve", current.u)
	end)
	askNo.Activated:Connect(function() Audio.PlayUI("Click") showAsk(false) end)
	-- a newly discovered stage's tile turns over (folds to nothing, comes back revealed) with the gold burst
	local function flip(index: number, stageId: string)
		local cell = chartTiles[index].cell
		local home, size = cell.Position, cell.Size
		TweenService:Create(cell, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.fromOffset(0, size.Y.Offset), Position = home + UDim2.fromOffset(size.X.Offset / 2, 0) }):Play()
		task.delay(0.15, function()
			revealing[stageId] = nil
			panel.refresh()
			TweenService:Create(cell, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size, Position = home }):Play()
			Discovery.Reveal(chartTiles[index].button)
			pcall(function() AlterFX.Sound("Sparkle", { volume = 0.7 }) end)
		end)
	end
	chartButton.Activated:Connect(function()
		Audio.PlayUI("Click")
		-- the stages reached since the chart was last open (none the first time: what you have then counts as seen)
		local ids = {}
		local discovered = state().discovered or {}
		for i, stage in ipairs(Trainers.Stages) do
			if i > 1 and discovered[stage.id] then table.insert(ids, stage.id) end
		end
		local fresh = Discovery.New("TrainerStages", ids)
		for id in pairs(fresh) do revealing[id] = true end
		panel.refresh()
		showChart(true)
		Discovery.Seen("TrainerStages", ids)
		local after = 0.45
		for i, stage in ipairs(Trainers.Stages) do
			if fresh[stage.id] then
				task.delay(after, function() if chart.Visible then flip(i, stage.id) else revealing[stage.id] = nil end end)
				after += 0.3
			end
		end
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
