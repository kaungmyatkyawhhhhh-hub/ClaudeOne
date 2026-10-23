-- AltersPanel (prompt 21, 21 Oct): the Inventory window's LOOKS > Alters (prompt 28; was the ALTERS tab; TitlesClient builds the
-- window and calls this). (prompt 54) Coach Dex's shop ALTERS tab uses the same panel (opts.mode = "shop").
-- (prompt 40, 22 Oct, mockup inv_alters) Header "ALTER x / 12" + "SHREDDED IS YOUR HIGHEST · GAINS X1.30". The alters as
-- a PATH of tiles (row 1 left to right, row 2 right to left under it, ...: Vascular sits under Tanned):
--   reached   the alter's banner (Config.AlterThemes bg, else its colours) behind the whole tile, its bicep icon
--             (prompt 54, Shared/UI/AlterIcon; was the skin swatch), the name; the one you wear: gold edge + gold check
--   next      the banner dimmed, the progress bar (muscle groups at the goal) and a NEXT ALTER pill
--   later     (prompt 31) UNDISCOVERED (Shared/UI/Discovery): a dark tile, the bicep as a black silhouette with a rim in
--             the tier's colour, "???", a small gray UNDISCOVERED. Tiers with no textures yet aren't shown at all. Header:
--             "ALTERS 2 / 30 UNLOCKED" (the ones you've reached; owner, 23 Oct); one that's new since you last looked turns over with a
--             gold burst.
-- A tap picks it (gold border, a bounce + the select sound, Kit.SelectFeedback) and shows it in the detail panel (right):
-- banner, bicep, name, "GAINS X1.15", "ALTER 1 · HUMAN TIER", then
--   inventory  WEAR / WORN
--   shop       the goal ("1.3M EXP in every group"), a progress bar with %, and ALTER NOW (ready) / WHAT TO TRAIN (in
--              progress) / OWNED + MY SKINS (reached) / "Reach the previous alter first" (undiscovered). Opens on the next.
-- AltersPanel.Build(parent, opts?) -> { frame, refresh(), selectNext() }. opts: { mode = "shop"?, columns = 4,
-- onClose = function (the shop window closes before ALTER NOW / WHAT TO TRAIN / MY SKINS) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local Discovery = require(script.Parent.Discovery)
local AlterIcon = require(script.Parent.AlterIcon)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local AltersPanel = {}

-- (prompt 31) a tier shows only once one of its alters has textures
local function tierShown(tier: number): boolean
	for _, alter in ipairs(Alters.List) do
		if alter.tier == tier and alter.textures then return true end
	end
	return false
end

-- the discovered alters' ids (the ones you've reached + the next one), for the reveal and the tab's red dot
function AltersPanel.Discovered(data): { string }
	local highest = (Alters.State(data).highest or 0)
	local ids = {}
	for _, alter in ipairs(Alters.List) do
		if alter.number <= highest + 1 and tierShown(alter.tier) then table.insert(ids, alter.id) end
	end
	return ids
end

local TILE = Vector2.new(140, 92)
local GAP = 8
local DETAIL_W = 196
local ICON = 46
local DARK = Color3.fromHex("#1B1B20")

-- the next alter's progress, 0..1: every muscle group's EXP toward the goal (like the shop's % and the NEXT card)
local function nextShare(progress): number
	local have, need = 0, 0
	for _, group in ipairs(Muscles.Groups) do
		have += Muscles.Shown(math.min(progress.groups[group.id] or 0, progress.required))
		need += Muscles.Shown(progress.required)
	end
	return if need > 0 then have / need else 0
end

function AltersPanel.Build(parent: Instance, opts: { [string]: any }?)
	opts = opts or {}
	local shop = opts.mode == "shop"
	local COLUMNS = opts.columns or 4
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local panel = {}
	local picked = nil -- the alter number shown in the detail panel (nil = the one you wear; the shop: the next one)
	local holder = New("Frame", { Name = "Alters", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local count = Kit.GoldText(Kit.Text({ Name = "Count", Text = "", Font = "Chunky", TextSize = 15, Size = UDim2.fromOffset(196, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = holder }))
	local header = Kit.Text({ Name = "Bonus", Text = "", Font = "Chunky", TextSize = 12, Position = UDim2.fromOffset(200, 0), Size = UDim2.new(1, -(200 + DETAIL_W + 10), 0, 20),
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

	local tiles = {}
	local all = { Alters.Natural }
	for _, alter in ipairs(Alters.List) do
		if tierShown(alter.tier) then table.insert(all, alter) end
	end
	local detail -- (below)
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
		-- (prompt 54) the bicep, above the UNDISCOVERED face too (there: a black silhouette)
		local icon = AlterIcon.New({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(ICON, ICON), ZIndex = 23, Parent = tile })
		local name = Kit.Text({ Name = "Name", Text = string.upper(alter.name), Font = "Chunky", TextSize = 15, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, ICON + 4), Size = UDim2.new(1, -10, 0, 17), ZIndex = 4, Parent = tile })
		Kit.Fit(name, 15, 11)
		local _, setBar = Kit.Bar(Colors.Gold, { Name = "Bar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, ICON + 22), Size = UDim2.new(1, -16, 0, 7),
			ZIndex = 4, Visible = false, Parent = tile }, { outline = 1 })
		local bar = tile:FindFirstChild("Bar")
		local nextPill = New("Frame", { Name = "NextPill", BackgroundColor3 = Color3.fromHex("#1E1B20"), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -16, 0, 16), ZIndex = 4, Visible = false, Parent = tile }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Gold, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		Kit.Text({ Name = "Text", Text = "NEXT ALTER", Font = "Chunky", TextSize = 11, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = nextPill })
		-- (owner, 23 Oct) the alter you wear: a small WORN tag (and the thin gold outline), like the auras' EQUIPPED
		local check = New("Frame", { Name = "Worn", BackgroundColor3 = Color3.fromHex("#141317"), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(40, 14), Visible = false, ZIndex = 6, Parent = tile }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Gold, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		Kit.Text({ Name = "Text", Text = "WORN", Font = "Chunky", TextSize = 8, TextColor3 = Colors.Gold, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = check })
		local overlay = Discovery.Overlay(tile)
		local ring = overlay:FindFirstChild("Ring")
		if ring then ring.Visible = false end -- (the silhouette takes the "?"'s place)
		tiles[n] = { tile = tile, bg = bg, icon = icon, name = name, bar = bar, setBar = setBar, nextPill = nextPill, check = check, alter = alter, overlay = overlay }
		tile.Activated:Connect(function()
			picked = n
			panel.refresh()
			Kit.SelectFeedback(tile, detail) -- (prompt 54: bounce + select sound, the detail slides in)
		end)
	end
	local rows = math.ceil(#all / COLUMNS)
	path.CanvasSize = UDim2.fromOffset(0, 8 + rows * (TILE.Y + GAP))

	-- the detail panel (right)
	detail = New("Frame", { Name = "Detail", BackgroundColor3 = DARK, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, DETAIL_W, 1, 0), ClipsDescendants = true, Parent = holder }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local detailArt = New("Frame", { Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = detail })
	local bigIcon = AlterIcon.New({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(60, 60), ZIndex = 4, Parent = detail })
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
	local wear = Kit.Button("Green", "Wear", { Name = "Wear", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 4, Visible = not shop,
		Parent = detail }, { width = DETAIL_W - 20, height = 30, textSize = 16 })
	-- (prompt 61; owner 23 Oct) the Inventory: the alter's STYLE tints you own (off sale now) as round swatches in their own
	-- row under the tier line; none owned: nothing there. A tap previews the tint on you for a few seconds, WEAR wears it.
	local player = game:GetService("Players").LocalPlayer
	local previewToken = 0
	local chips = if shop then nil else require(script.Parent.StyleChips).New(detail, { Size = UDim2.new(1, -16, 0, 30), ZIndex = 4 }, {
		preview = function(variant)
			previewToken += 1
			local mine = previewToken
			local Style = require(script.Parent.Parent.Config.Style)
			local hex = variant and Style.AlterTints[variant]
			player:SetAttribute("AlterTintPreview", if hex then Color3.fromHex(hex) else nil)
			task.delay(6, function()
				if previewToken == mine then player:SetAttribute("AlterTintPreview", nil) end
			end)
		end,
		changed = function() panel.refresh() end,
	})
	if not shop then
		-- (owner, 23 Oct) the inventory detail lays out top to bottom with equal gaps (nothing can overlap the tier line)
		local stack = New("Frame", { Name = "Stack", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -44), ZIndex = 4, Parent = detail }, {
			New("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		bigIcon.Size = UDim2.fromOffset(52, 52) -- (room for the swatch row above WEAR in the short Looks panel)
		for order, gui in ipairs({ bigIcon, bigName, gains, tierText, chips.frame }) do
			gui.AnchorPoint = Vector2.new(0, 0)
			gui.LayoutOrder = order
			gui.Parent = stack
		end
	end
	wear.Activated:Connect(function()
		local state = Alters.State(ClientData.Get())
		local n = picked or state.equipped or 0
		if n > (state.highest or 0) then return end
		-- a tint picked in the swatches that isn't the one worn: wear it (and the alter)
		if chips and chips.frame.Visible and chips:Selected() ~= chips:Worn() then
			local alter = Alters.Get(n)
			if alter then remotes.PlayerAction:FireServer("WearStyle", { kind = "Alter", target = alter.id, variant = chips:Selected() }) end
		end
		if n ~= (state.equipped or 0) then
			remotes.PlayerAction:FireServer("EquipAlter", n)
		end
	end)

	-- (prompt 54) the shop's detail: the goal, the progress bar with %, and its buttons
	local goalText, setGoalBar, goalBar, pctText, action, mySkins
	if shop then
		goalText = Kit.Text({ Name = "Goal", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Color3.fromHex("#D9D2D5"), Position = UDim2.fromOffset(8, 131),
			Size = UDim2.new(1, -16, 0, 14), ZIndex = 4, Parent = detail })
		Kit.Fit(goalText, 11, 9)
		local _, setter = Kit.Bar(Colors.Gold, { Name = "GoalBar", Position = UDim2.fromOffset(10, 151), Size = UDim2.new(1, -60, 0, 8), ZIndex = 4, Parent = detail }, { outline = 1 })
		setGoalBar, goalBar = setter, detail:FindFirstChild("GoalBar")
		pctText = Kit.Text({ Name = "Pct", Text = "", Font = "Number", TextSize = 13, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 146),
			Size = UDim2.fromOffset(44, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = detail })
		action = Kit.Button("Gold", "Alter now", { Name = "Action", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), ZIndex = 4, Parent = detail },
			{ width = DETAIL_W - 20, height = 32, textSize = 15 })
		mySkins = Kit.Button("Quiet", "My skins", { Name = "MySkins", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6), ZIndex = 4, Visible = false,
			Parent = detail }, { width = (DETAIL_W - 26) / 2, height = 32, textSize = 13 })
		action.Activated:Connect(function()
			local what = action:GetAttribute("Does")
			if what == "alter" then
				if opts.onClose then opts.onClose() end
				UIBus.StartAlter:Fire()
			elseif what == "train" then
				if opts.onClose then opts.onClose() end
				UIBus.OpenNeeds:Fire()
			end
		end)
		mySkins.Activated:Connect(function()
			if opts.onClose then opts.onClose() end
			UIBus.OpenInventory:Fire("Alters")
		end)
	end

	function panel.selectNext()
		local data = ClientData.Get()
		local highest = data and (Alters.State(data).highest or 0) or 0
		picked = if tiles[highest + 1] then highest + 1 else highest
		panel.refresh()
	end

	function panel.refresh()
		local data = ClientData.Get()
		if not data then return end
		local state = Alters.State(data)
		local highest, worn = state.highest or 0, state.equipped or 0
		local maxed = GrowthSpurts.IsMaxed(data.growthSpurts or 0)
		local progress = Alters.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
		local discovered = AltersPanel.Discovered(data)
		count.Text = "ALTERS " .. highest .. " / " .. #Alters.List .. " UNLOCKED" -- (owner, 23 Oct: the alters you've reached, not DISCOVERED)
		header.Text = if maxed then string.upper(string.format("%s is your highest · gains x%.2f", Alters.Get(highest).name, Alters.Bonus(highest)))
			else "BODY ALTERS OPEN AT 7'0\". EACH ONE ADDS +15% GAINS."
		local shown = picked or (if shop then highest + 1 else worn)
		for n, t in pairs(tiles) do
			local reached = n <= highest
			local isNext = n == highest + 1
			local later = not reached and not isNext
			t.bg.Visible = not later
			local dim = if isNext then 0.55 else 0
			if t.bg:IsA("ImageLabel") then t.bg.ImageTransparency = dim else t.bg.BackgroundTransparency = dim end
			AlterIcon.Set(t.icon, n, if later then "silhouette" else "lit")
			t.icon.Size = if later then UDim2.fromOffset(34, 34) else UDim2.fromOffset(ICON, ICON)
			t.icon.Position = if later then UDim2.new(0.5, 0, 0, 8) else UDim2.new(0.5, 0, 0, 3)
			t.name.Visible = not later
			t.overlay.Visible = later
			t.bar.Visible = isNext and maxed
			t.nextPill.Visible = isNext
			if isNext then t.setBar(if progress.total > 0 then progress.met / progress.total else 0) end
			t.check.Visible = reached and n == worn
			local theme = if n > 0 then AlterThemes.Get(n) else nil
			local pickedNow = shown == n
			-- the picked tile: a gold border (prompt 54); the worn one gold too in the inventory
			t.tile.Border.Color = if pickedNow and not later then Colors.Gold elseif reached and n == worn and not shop then Colors.Gold
				elseif reached then (if theme then theme.accent else Colors.Text) else Color3.fromHex("#2E2A30")
			t.tile.Border.Thickness = if later then 2 elseif reached and n == worn and not shop then 1.5 else 3
			-- later ones are smaller and quiet
			t.tile.Size = if later then UDim2.new(1, -14, 1, -14) else UDim2.fromScale(1, 1)
			t.tile.BackgroundColor3 = if later then Color3.fromHex("#141216") else DARK
			local scale = t.tile:FindFirstChild("PickScale") or New("UIScale", { Name = "PickScale", Parent = t.tile })
			scale.Scale = if pickedNow and not later then 1.03 else 1
		end
		-- the detail panel
		local n = shown
		local alter = Alters.Get(n) or Alters.Natural
		local reached = n <= highest
		local isNext = n == highest + 1
		local later = n > highest + 1
		detailArt:ClearAllChildren()
		if not later then banner(detailArt, n, true) end -- (no mesh on the detail panel)
		AlterIcon.Set(bigIcon, n, if later then "silhouette" else "lit")
		bigName.Text = if later then "???" else string.upper(alter.name)
		local theme = if n > 0 then AlterThemes.Get(n) else nil
		gains.Visible = not later
		gains.Edge.Color = if theme then theme.accent else Colors.Muted
		gainsText.Text = string.format("GAINS X%.2f", Alters.Bonus(n))
		tierText.Text = if later then (if shop then "REACH THE PREVIOUS ALTER FIRST" else "UNDISCOVERED · KEEP GROWING") elseif n == 0 then "YOUR OWN SKIN"
			else string.upper("Alter " .. n .. " · " .. Alters.Tiers[alter.tier].name .. " tier")
		detail.Border.Color = if not shop and reached and n == worn then Colors.Gold elseif theme and not later then theme.accent else Colors.Outline
		if not shop then
			wear.Visible = reached
			if chips then
				local Style = require(script.Parent.Parent.Config.Style)
				local colours = alter and alter.id and Style.AlterVariants[alter.id]
				chips:Set(if reached and n > 0 and colours then "Alter" else nil, alter and alter.id, colours, function(name) return Style.AlterTints[name] or "#FFFFFF" end,
					"#" .. (if theme then theme.accent else Colors.Text):ToHex())
			end
			if reached then
				local newTint = chips and chips.frame.Visible and chips:Selected() ~= chips:Worn()
				if newTint then Kit.SetButton(wear, "Green", "Wear " .. chips:Name(chips:Selected()))
				elseif n == worn then Kit.SetButton(wear, "Quiet", "Worn") else Kit.SetButton(wear, "Green", "Wear") end
			end
		else
			local share = if reached then 1 elseif isNext then nextShare(progress) else 0
			goalText.Visible = not later and n > 0
			goalText.Text = if n > 0 then Muscles.FormatExpShort(Muscles.Shown(Alters.Goal(n))) .. " EXP in every group" else ""
			goalBar.Visible = not later and n > 0
			pctText.Visible = not later and n > 0
			setGoalBar(share)
			pctText.Text = math.floor(share * 100) .. "%"
			action.Visible = not later
			mySkins.Visible = reached
			if reached then
				action.Size = UDim2.fromOffset((DETAIL_W - 26) / 2, 32)
				Kit.SetButton(action, "Disabled", "Owned")
				action:SetAttribute("Does", nil)
			elseif isNext and progress.ready and maxed then
				action.Size = UDim2.fromOffset(DETAIL_W - 20, 32)
				Kit.SetButton(action, "Gold", "Alter now")
				action:SetAttribute("Does", "alter")
			elseif isNext then
				action.Size = UDim2.fromOffset(DETAIL_W - 20, 32)
				Kit.SetButton(action, "Quiet", "What to train")
				action:SetAttribute("Does", "train")
			end
		end
		-- (prompt 31) new since you last looked: it turns over with a gold burst (only while the tab is on screen)
		if holder.Visible then
			local fresh = Discovery.New("Alters", discovered)
			for _, t in pairs(tiles) do
				if t.alter.id and fresh[t.alter.id] then Discovery.Reveal(t.tile, t.overlay) end
			end
			Discovery.Seen("Alters", discovered)
		end
	end

	panel.frame = holder
	return panel
end

return AltersPanel
