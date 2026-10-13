-- StatsClient: the Stats tile, the Muscles tile and the PHYSIQUE window (owner's final kit "BLACK + GOLD", mockup
-- gym_arc_ui_final/07_physique).
--  * Stats (menu tile): shows / hides your stats as labels around your character in the world (StatsLabelsClient does
--    the drawing; this script fires UIBus.StatsLabels). Hidden by default. The tutorial's "open Stats" step counts it.
--    The window has the same switch: a small eye button in the body card's corner (gold while the labels show).
--  * Muscles (menu tile), the GROW tile (UIBus.OpenStats) and the machine body map (UIBus.OpenMuscles) open the window.
--    Tabs in the header (MUSCLES / LIFTS / GENES):
--      Muscles   left: your body card (the muscle figure lit by level on a dark red glow, a big gold "71%" and
--                "PHYSIQUE / AESTHETIC"; when a Growth Spurt is ready the gold TAP TO GROW CTA takes the number's place);
--                right: the six groups, best first: a grade on a small gold plate, the name, a fat metallic bar in the
--                grade's color (S red, A gold, B teal, C steel, D dark gray) and the %.
--                (owner, 14 Oct) One number drives all of it: a group's % = its muscles' progress to the full aesthetic
--                look (Muscles.LookG, 1 = full; the mass monster beyond counts as 100%); its grade comes from that %
--                (S 90+, A 75+, B 55+, C 35+, D below); the big total = the average of the six groups.
--      Lifts     every open machine: its main muscle, the heaviest weight you lifted and the weights bought.
--      Genetics  (tab "GENES") the six grades with their multipliers, frame and body type, the overall grade, and a button to the
--                genetics screen (reroll there).
--  * The Growth Spurt moment (a line of text, a bell, a chalk burst) is played here too.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local Genetics = require(Config.Genetics)
local GrowthSpurts = require(Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local BodyFigure = require(Shared.UI.BodyFigure)
local Icons = require(Shared.UI.Icons)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local W, H = 566, 290 -- the window (mockup px; clear of the left menu on a phone)
local BODY_W = 196 -- the body card on the Muscles tab
local ROW_H = 30

-- the six group rows (owner's final kit: the groups only, sorted best first)
local CARDS = {
	{ id = "Chest", group = "Chest" }, { id = "Back", group = "Back" }, { id = "Shoulders", group = "Shoulders" },
	{ id = "Arms", group = "Arms" }, { id = "Legs", group = "Legs" }, { id = "Core", group = "Core" },
}
-- the bar colors by grade (mockup 07: S red, A gold, B teal, C steel, D dark gray)
local BAR_COLORS = { S = Color3.fromHex("#E8343C"), A = Color3.fromHex("#F2B640"), B = Color3.fromHex("#3CC8B4"), C = Color3.fromHex("#8E9AA6"), D = Color3.fromHex("#4A4548") }
-- a group's grade from its % (owner, 14 Oct)
local GRADE_FROM = { { 90, "S" }, { 75, "A" }, { 55, "B" }, { 35, "C" } }
local function gradeFor(pct: number): string
	for _, entry in ipairs(GRADE_FROM) do
		if pct >= entry[1] then return entry[2] end
	end
	return "D"
end
-- the physique word under the body card, by the average muscle look (1 = the full aesthetic look)
local PHYSIQUES = { { 0.15, "Beginner" }, { 0.4, "Getting Fit" }, { 0.7, "Athletic" }, { 1, "Aesthetic" }, { 1.25, "Shredded" }, { math.huge, "Mass Monster" } }
local OVERALL_WORD = { S = "Genetic Freak", A = "Blessed", B = "Gifted", C = "Average", D = "Hardgainer" }

------------------------------------------------------------------------
-- Tiles
------------------------------------------------------------------------
local statsButton = SideMenu.Add("Stats", "Stats", Icons.Flex, 1)
local musclesTile = SideMenu.Add("Muscles", "Muscles", Icons.Stats, 2)
local labelsOn = false
local musclesOpen = false

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local pages = {}
local currentTab = "Muscles"
local refreshScreen -- (below)
local modal = Kit.Modal({ name = "MusclesScreen", title = "Physique", width = W, height = H, displayOrder = 27,
	tabs = { { id = "Muscles", text = "Muscles" }, { id = "Lifts", text = "Lifts" }, { id = "Genetics", text = "Genes" } },
	onTab = function(id)
		currentTab = id
		for name, page in pairs(pages) do page.Visible = name == id end
		refreshScreen()
	end })
for _, id in ipairs({ "Muscles", "Lifts", "Genetics" }) do
	pages[id] = New("Frame", { Name = id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = id == "Muscles", Parent = modal.body })
end

-- the stats labels switch (the Stats tile does the same): a small eye button in the body card's corner (made below)
local labelsButton
local function setLabels(on: boolean)
	labelsOn = on
	statsButton:SetActive(on)
	Kit.SetButton(labelsButton, on and "Gold" or "Quiet", "")
	UIBus.StatsLabels:Fire(on)
	UIBus.StatsVisible:Fire(on) -- (the tutorial's "open Stats" step)
end

------------------------------------------------------------------------
-- Muscles tab
------------------------------------------------------------------------
-- the body card: the muscle figure lit by level on a dark red glow, the big gold % and the physique word
local bodyCard = Kit.Card({ Name = "Body", Size = UDim2.new(0, BODY_W, 1, 0), Parent = pages.Muscles }, {})
bodyCard:FindFirstChild("Sheen").Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#3A1416")), ColorSequenceKeypoint.new(0.55, Color3.fromHex("#1E1416")), ColorSequenceKeypoint.new(1, Color3.fromHex("#141215")),
})
local figure = New("Frame", { Name = "Figure", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(1, -16, 1, -70), Parent = bodyCard }, { New("UIAspectRatioConstraint", { AspectRatio = 0.8 }) })
local front = New("Frame", { Name = "Front", BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Parent = figure })
local back = New("Frame", { Name = "Back", BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), Parent = figure })
-- "71" big gold + "%" muted on the left; "PHYSIQUE" small muted over "AESTHETIC" in gold on the right
local sizeRow = New("Frame", { Name = "SizeRow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -20),
	Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, Parent = bodyCard }, {
	Theme.List(Horizontal, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom),
})
local sizeLabel = Kit.GoldText(Kit.Text({ Name = "Size", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 50, Size = UDim2.fromOffset(0, 54),
	AutomaticSize = Enum.AutomaticSize.X, Parent = sizeRow }))
Kit.Text({ Name = "Percent", LayoutOrder = 2, Text = "%", Font = "Number", TextSize = 20, TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X, Parent = sizeRow })
Kit.Text({ Name = "PhysiqueWord", Text = "PHYSIQUE", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -10, 1, -44), Size = UDim2.fromOffset(100, 14), TextXAlignment = Enum.TextXAlignment.Right, Parent = bodyCard })
local physiqueLabel = Kit.GoldText(Kit.Text({ Name = "Physique", Text = "", Font = "Title", TextSize = 17, Upper = true, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -10, 1, -24), Size = UDim2.fromOffset(110, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = bodyCard }))
-- (owner, 14 Oct) above the starting height the % is honest but lower: a taller frame has more muscle to fill
local tallerNote = Kit.Text({ Name = "TallerNote", Text = "Taller frame - more muscle to fill", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted,
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.new(1, -20, 0, 13), TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd, Visible = false, Parent = bodyCard })
-- the labels switch: a small eye button in the card's top right corner (gold while the labels show)
labelsButton = Kit.Button("Quiet", "", { Name = "Labels", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 4, Parent = bodyCard },
	{ width = 32, height = 32, icon = "eye" })
-- a Growth Spurt is ready: the gold TAP TO GROW CTA takes the number's place
local spurtButton = Kit.Button("Gold", "Tap to grow", { Name = "GrowthSpurt", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
	Visible = false, Parent = bodyCard }, { width = BODY_W - 20, height = 40, textSize = 16 })

local looks = {} -- [muscleId] = look (0..monster) for the figure
local function muscleColor(muscleId: string)
	local g = looks[muscleId] or 0
	return Colors.Red:Lerp(Color3.fromHex("#FF9A8A"), math.clamp(g - 1, 0, 1)), 0.75 - 0.7 * math.clamp(g, 0, 1)
end
local function drawFigure()
	front:ClearAllChildren()
	back:ClearAllChildren()
	BodyFigure.Draw(front, "Front", muscleColor, Color3.fromHex("#E8D9CF"), 0.82)
	BodyFigure.Draw(back, "Back", muscleColor, Color3.fromHex("#E8D9CF"), 0.82)
end

local right = New("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromOffset(BODY_W + 14, 2), Size = UDim2.new(1, -(BODY_W + 14), 1, -2),
	Parent = pages.Muscles }, {
	Theme.List(Vertical, 7, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local cards = {}
for index, spec in ipairs(CARDS) do
	local row = New("Frame", { Name = spec.id, LayoutOrder = index, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW_H), Parent = right })
	local badge = Kit.GradeBadge("B", 26, { Name = "Grade", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Parent = row })
	Kit.Text({ Name = "Label", Text = spec.id, Font = "Title", TextSize = 16, Upper = true, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 36, 0.5, 0),
		Size = UDim2.fromOffset(96, ROW_H), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local _, setBar, fill = Kit.Bar(Colors.Teal, { Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 136, 0.5, 0), Size = UDim2.new(1, -196, 0, 18), Parent = row })
	local pct = Kit.Text({ Name = "Pct", Text = "", Font = "Number", TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(52, ROW_H), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	cards[spec.id] = { card = row, badge = badge, setBar = setBar, fill = fill, pct = pct, spec = spec }
end

------------------------------------------------------------------------
-- Lifts tab
------------------------------------------------------------------------
local liftList = New("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = pages.Lifts }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 44), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 2) }),
})
local liftRows = {}
for index, machine in ipairs(Machines.List) do
	if machine.trains == "Stamina" or not machine.tiers then continue end
	local card = Kit.Card({ Name = machine.id, LayoutOrder = index, Parent = liftList }, {})
	local mainId = machine.muscles and machine.muscles[1] and machine.muscles[1].id
	local group = mainId and Muscles.ById[mainId] and Muscles.ById[mainId].group
	Kit.IconTile("dumbbell", Color3.fromHex("#2A262B"), 30, { Name = "Tile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Parent = card })
	Kit.Text({ Name = "Name", Text = machine.name, Font = "Title", TextSize = 13, Position = UDim2.fromOffset(44, 5), Size = UDim2.new(1, -120, 0, 17),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	Kit.Text({ Name = "Muscle", Text = mainId and Muscles.ById[mainId].name or "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted,
		Position = UDim2.fromOffset(44, 23), Size = UDim2.new(1, -120, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local best = Kit.Text({ Name = "Best", Text = "", Font = "Number", TextSize = 14, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5),
		Size = UDim2.fromOffset(80, 17), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
	local tiers = Kit.Text({ Name = "Tiers", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 23),
		Size = UDim2.fromOffset(80, 14), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
	liftRows[machine.id] = { card = card, best = best, tiers = tiers, machine = machine, group = group }
end

------------------------------------------------------------------------
-- Genetics tab
------------------------------------------------------------------------
local geneGrid = New("Frame", { Name = "Grades", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 2 * 44 + 6), Parent = pages.Genetics }, {
	New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 44), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local geneCards = {}
for index, group in ipairs(Muscles.Groups) do
	local card = Kit.Card({ Name = group.id, LayoutOrder = index, Parent = geneGrid }, {})
	local badge = Kit.GradeBadge("B", 28, { Name = "Grade", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Parent = card })
	Kit.Text({ Name = "Label", Text = group.name, Font = "Title", TextSize = 14, Position = UDim2.fromOffset(42, 5), Size = UDim2.new(1, -48, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local mult = Kit.Text({ Name = "Mult", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(42, 23), Size = UDim2.new(1, -48, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	geneCards[group.id] = { badge = badge, mult = mult }
end
local function infoCard(name: string, order: number, x: number)
	local card = Kit.Card({ Name = name, Position = UDim2.new(x, x > 0 and 4 or 0, 0, 2 * 44 + 6 + 8), Size = UDim2.new(0.5, -4, 0, 44), Parent = pages.Genetics }, {})
	local title = Kit.Text({ Name = "Title", Text = "", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -20, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local sub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(12, 23), Size = UDim2.new(1, -20, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	return title, sub
end
local frameTitle, frameSub = infoCard("Frame", 1, 0)
local bodyTitle, bodySub = infoCard("BodyType", 2, 0.5)
local overall = Kit.Card({ Name = "Overall", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 48), Piece = "banner_gold", Parent = pages.Genetics }, {})
local overallBadge = Kit.GradeBadge("B", 32, { Name = "Grade", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = overall })
local overallText = Kit.Text({ Name = "Word", Text = "", Font = "Title", TextSize = 16, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 50, 0.5, 0),
	Size = UDim2.new(1, -220, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = overall })
local geneticsButton = Kit.Button("Red", "Open Genetics", { Name = "OpenGenetics", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = overall },
	{ width = 150, height = 32, textSize = 13, icon = "star" })

local function bonusText(entry): string
	if not entry or not entry.bonus then return "" end
	local parts = {}
	if entry.bonus.all then table.insert(parts, string.format("+%d%% all", entry.bonus.all * 100)) end
	for id, value in pairs(entry.bonus.groups or {}) do table.insert(parts, string.format("+%d%% %s", value * 100, id)) end
	for id, value in pairs(entry.bonus.muscles or {}) do table.insert(parts, string.format("+%d%% %s", value * 100, Muscles.ById[id] and Muscles.ById[id].name or id)) end
	if entry.detailLevelMult and entry.detailLevelMult < 1 then table.insert(parts, "abs show earlier") end
	if entry.detailLevelMult and entry.detailLevelMult > 1 then table.insert(parts, "abs show later") end
	return #parts > 0 and table.concat(parts, ", ") or "No bonus"
end

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------
local wasReady = nil
function refreshScreen()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	if progress.ready and wasReady == false then
		statsButton:SetDot(true) -- something new: clears when the window opens
		musclesTile:SetDot(true)
	end
	wasReady = progress.ready
	if not modal.isOpen() then return end

	local grades = data.genetics and data.genetics.grades or {}
	if currentTab == "Muscles" then
		-- every muscle's look (1 = the full aesthetic look; the figure and the physique word use it as is)
		local levels = {}
		for _, muscle in ipairs(Muscles.List) do levels[muscle.id] = Muscles.ExactLevel(data.muscles[muscle.id]) end
		local goal = math.max(progress.required, 1)
		local sum, count = 0, 0
		for _, muscle in ipairs(Muscles.List) do
			looks[muscle.id] = Muscles.LookG(muscle.id, levels[muscle.id], goal)
			sum += looks[muscle.id]
			count += 1
		end
		local average = count > 0 and sum / count or 0
		-- the six rows from ONE number: the group's progress to the full look -> the %, the bar, the grade, its color
		local order, total = {}, 0
		for _, group in ipairs(Muscles.Groups) do
			local c = cards[group.id]
			local groupSum = 0
			for _, muscle in ipairs(group.muscles) do groupSum += math.clamp(looks[muscle.id] or 0, 0, 1) end
			local share = groupSum / math.max(#group.muscles, 1)
			local pct = math.floor(share * 100 + 0.5)
			local grade = gradeFor(pct)
			Kit.SetGrade(c.badge, grade)
			local gloss = c.fill:FindFirstChild("Gloss")
			if gloss then gloss.Color = Kit.Metal(BAR_COLORS[grade]) end
			c.setBar(share)
			c.pct.Text = pct .. "%"
			total += pct
			table.insert(order, { c = c, share = share })
		end
		table.sort(order, function(a, b) return a.share > b.share end)
		for i, entry in ipairs(order) do entry.c.card.LayoutOrder = i end
		-- the body card: the total = the average of the six groups
		sizeLabel.Text = tostring(math.floor(total / #Muscles.Groups + 0.5))
		for _, entry in ipairs(PHYSIQUES) do
			if average < entry[1] then
				physiqueLabel.Text = entry[2]
				break
			end
		end
		drawFigure()
		-- a Growth Spurt is ready: TAP TO GROW replaces the number
		local ready = progress.ready and not progress.maxed
		spurtButton.Visible = ready
		sizeLabel.Parent.Visible = not ready
		physiqueLabel.Visible = not ready
		tallerNote.Visible = not ready and GrowthSpurts.GetHeight(data.growthSpurts or 0) > GrowthSpurts.GetHeight(0)
		bodyCard:FindFirstChild("PhysiqueWord").Visible = not ready
		if ready then Theme.Pulse(spurtButton, function() return modal.isOpen() and spurtButton.Visible end) end
	elseif currentTab == "Lifts" then
		for _, row in pairs(liftRows) do
			local machine = row.machine
			local open = Machines.GymOpenAt(machine) <= (data.growthSpurts or 0)
			row.card.Visible = open
			local state = data.machines and data.machines[machine.id]
			local bestTier = state and state.best and machine.tiers[state.best]
			row.best.Text = bestTier and Machines.WeightText(bestTier) or "-"
			row.tiers.Text = string.format("%d/%d weights", math.min(state and state.unlocked or 1, #machine.tiers), #machine.tiers)
		end
	elseif currentTab == "Genetics" then
		local genetics = data.genetics
		for _, group in ipairs(Muscles.Groups) do
			local c = geneCards[group.id]
			Kit.SetGrade(c.badge, grades[group.id] or "B")
			c.mult.Text = string.format("Grows x%.2f", Genetics.GetMultiplier(genetics, group.muscles[1].id))
		end
		local frame = genetics and Genetics.FrameById[genetics.frame]
		local bodyType = nil
		for _, entry in ipairs(Genetics.BodyTypes) do
			if genetics and entry.id == genetics.bodyType then bodyType = entry end
		end
		frameTitle.Text = "Frame: " .. (frame and frame.name or "-")
		frameSub.Text = bonusText(frame)
		bodyTitle.Text = "Body: " .. (bodyType and bodyType.name or "-")
		bodySub.Text = bonusText(bodyType)
		local overallGrade = next(grades) and Genetics.GetOverallGrade(grades) or "B"
		Kit.SetGrade(overallBadge, overallGrade)
		overallText.Text = "Overall: " .. (OVERALL_WORD[overallGrade] or "")
	end
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function openTab(tab: string?)
	if UIBus.MenuOpen then return end
	tab = if tab and pages[tab] then tab else currentTab
	modal.selectTab(tab)
	currentTab = tab
	for name, page in pairs(pages) do page.Visible = name == tab end
	if not modal.isOpen() then
		UIBus.PanelOpened("Muscles") -- (side panels close behind the window)
		musclesOpen = true
		musclesTile:SetActive(true)
		musclesTile:SetDot(false)
		statsButton:SetDot(false)
		modal.open()
		Audio.PlayUI("Whoosh")
		UIBus.MusclesVisible:Fire(true)
	end
	refreshScreen()
end
local function closeMuscles()
	if modal.isOpen() then modal.close() end
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	-- (the X, the backdrop and Esc close the window inside Kit.Modal)
	if not modal.isOpen() and musclesOpen then
		musclesOpen = false
		musclesTile:SetActive(false)
		UIBus.MusclesVisible:Fire(false)
	end
end)

spurtButton.Activated:Connect(function()
	if GrowthSpurts.IsMaxed(ClientData.Get().growthSpurts) then return end
	Remotes.PlayerAction:FireServer("GrowthSpurt")
end)
geneticsButton.Activated:Connect(function()
	closeMuscles()
	UIBus.OpenGenetics:Fire()
end)
labelsButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	setLabels(not labelsOn)
end)
UIBus.RegisterPanel("Muscles", closeMuscles)
UIBus.OpenMuscles.Event:Connect(function() openTab("Muscles") end)
UIBus.OpenStats.Event:Connect(function(tab) openTab(tab or "Muscles") end)
-- Studio test hook: Workspace attribute TestOpenPanel = "Physique" opens the window (the Device Emulator's clicks can miss
-- the menu tiles)
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestOpenPanel"):Connect(function()
		if workspace:GetAttribute("TestOpenPanel") == "Physique" then openTab("Muscles") end
	end)
end
UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible and modal.isOpen() then closeMuscles() end
end)

musclesTile.Activated:Connect(function()
	Audio.PlayUI("Click")
	if modal.isOpen() then closeMuscles() else openTab("Muscles") end
end)
statsButton.Activated:Connect(function()
	statsButton:SetDot(false)
	Audio.PlayUI("Click")
	setLabels(not labelsOn)
end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	refreshScreen()
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "growthSpurts" or key == "muscles" or key == "genetics" or key == "machines" then
		refreshScreen() -- live while the window is open, and keeps the "ready" dot current
	end
end)

------------------------------------------------------------------------
-- Growth Spurt moment: a short line of text, a bell, a chalk burst (no pop-up window)
------------------------------------------------------------------------
local celebration = Theme.ScreenGui({ Name = "Celebration", DisplayOrder = 30, Parent = playerGui })
local function chalkBurst()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local attachment = New("Attachment", { Parent = rootPart })
	local emitter = New("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Colors.Chalk),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rate = 0,
		Parent = attachment,
	})
	emitter:Emit(40)
	Debris:AddItem(attachment, 2)
end
local celebrationRoot = Kit.Root(celebration)
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind ~= "GrowthSpurt" then return end
	closeMuscles()
	-- the big gold line and what it gave, in the middle of the screen (clear of the toasts at the top)
	local banner = New("Frame", { Name = "GrowthSpurt", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, Spacing.XL), Size = UDim2.fromOffset(460, 76), Parent = celebrationRoot })
	Kit.Text({ Text = "Growth Spurt!", Font = "Title", TextSize = 40, TextColor3 = Colors.Gold, Size = UDim2.new(1, 0, 0, 50), Parent = banner })
	Kit.Text({ Text = string.format("You're now %s. Gains x%.2f forever!", GrowthSpurts.FormatHeight(info.height), info.bonus), Font = "Title", TextSize = 17,
		Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 22), Parent = banner })
	Theme.Fade(banner, true)
	Theme.Tween(banner, { Position = UDim2.fromScale(0.5, 0.5) })
	task.delay(2.8, function()
		local tween = Theme.Fade(banner, false, 0.4)
		if tween then tween.Completed:Connect(function() banner:Destroy() end) else banner:Destroy() end
	end)
	Audio.Play2D("GrowthSpurt")
	chalkBurst()
	-- once per Growth Spurt, after the big line: why the % dropped (owner, 14 Oct)
	task.delay(3.4, function()
		require(Shared.UI.Notify).Show("You grew! Your muscles have more room to grow.", nil, "grewRoom")
	end)
end)
