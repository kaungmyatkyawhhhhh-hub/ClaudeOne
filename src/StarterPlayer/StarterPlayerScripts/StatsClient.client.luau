-- StatsClient: the Stats tile, the Muscles tile and the Stats window (owner's UI v2, mockup 07_stats).
--  * Stats (menu tile): shows / hides your stats as labels around your character in the world (StatsLabelsClient does
--    the drawing; this script fires UIBus.StatsLabels). Hidden by default. The tutorial's "open Stats" step counts it.
--    The window has the same switch ("LABELS ON / OFF" next to the X).
--  * Muscles (menu tile), the GROW tile (UIBus.OpenStats) and the machine body map (UIBus.OpenMuscles) open the window.
--    Tabs above it:
--      Muscles   left: your body card (the muscle figure lit by level, "71% SIZE", "Physique: Aesthetic"); right: 8 cards
--                (Chest, Back, Shoulders, Arms, Legs, Core, Forearms, Calves) with the genetics grade badge, the name and a
--                bar with the % toward the Growth Spurt goal; under them the Growth Spurt row (next height, groups at
--                their goal, GROW when ready, "MAX GROWTH SPURT REACHED" at 7'0").
--      Lifts     every open machine: its main muscle, the heaviest weight you lifted and the weights bought.
--      Genetics  the six grades with their multipliers, frame and body type, the overall grade, and a button to the
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
local BODY_W = 160 -- the body card on the Muscles tab
local CARD_H = 38

-- the 8 cards: the six groups plus forearms and calves on their own (grade = their group's genetics)
local CARDS = {
	{ id = "Chest", group = "Chest" }, { id = "Back", group = "Back" }, { id = "Shoulders", group = "Shoulders" },
	{ id = "Arms", group = "Arms" }, { id = "Legs", group = "Legs" }, { id = "Core", group = "Core" },
	{ id = "Forearms", group = "Arms", muscle = "Forearms" }, { id = "Calves", group = "Legs", muscle = "Calves" },
}
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
local modal = Kit.Modal({ name = "MusclesScreen", title = "Stats", icon = "biceps-flexed", width = W, height = H, displayOrder = 27,
	tabs = { { id = "Muscles", text = "Muscles", icon = "biceps-flexed" }, { id = "Lifts", text = "Lifts", icon = "dumbbell" },
		{ id = "Genetics", text = "Genetics", icon = "star" } },
	onTab = function(id)
		currentTab = id
		for name, page in pairs(pages) do page.Visible = name == id end
		refreshScreen()
	end })
for _, id in ipairs({ "Muscles", "Lifts", "Genetics" }) do
	pages[id] = New("Frame", { Name = id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = id == "Muscles", Parent = modal.body })
end

-- the stats labels switch (the Stats tile does the same)
local labelsButton = Kit.Button("Gray", "Labels Off", { Name = "Labels", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 10), Parent = modal.panel },
	{ width = 104, height = 26, textSize = 12, icon = "eye" })
local function setLabels(on: boolean)
	labelsOn = on
	statsButton:SetActive(on)
	Kit.SetButton(labelsButton, on and "Green" or "Gray", on and "Labels On" or "Labels Off")
	UIBus.StatsLabels:Fire(on)
	UIBus.StatsVisible:Fire(on) -- (the tutorial's "open Stats" step)
end

------------------------------------------------------------------------
-- Muscles tab
------------------------------------------------------------------------
-- the body card: the muscle figure lit by level on a dark red glow
local bodyCard = Kit.Card({ Name = "Body", Size = UDim2.new(0, BODY_W, 1, 0), Piece = "well", Parent = pages.Muscles }, {
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#5A1A1E"), Color3.fromHex("#141418")) }),
})
bodyCard.BackgroundColor3 = Color3.new(1, 1, 1) -- (the gradient gives the color)
local figure = New("Frame", { Name = "Figure", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(1, -16, 1, -66), Parent = bodyCard }, { New("UIAspectRatioConstraint", { AspectRatio = 0.8 }) })
local front = New("Frame", { Name = "Front", BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Parent = figure })
local back = New("Frame", { Name = "Back", BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), Parent = figure })
local sizeLabel = Kit.Text({ Name = "Size", Text = "", Font = "Title", TextSize = 22, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(1, -8, 0, 26), Parent = bodyCard })
local physiqueLabel = Kit.Text({ Name = "Physique", Text = "", Font = "Title", TextSize = 13, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -8, 0, 16), Parent = bodyCard })

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

local right = New("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromOffset(BODY_W + 10, 0), Size = UDim2.new(1, -(BODY_W + 10), 1, 0),
	Parent = pages.Muscles })
local cardGrid = New("Frame", { Name = "Cards", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 4 * CARD_H + 3 * 6), Parent = right }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, CARD_H), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local cards = {}
for index, spec in ipairs(CARDS) do
	local card = Kit.Card({ Name = spec.id, LayoutOrder = index, Parent = cardGrid }, {})
	local badge = Kit.GradeBadge("B", 26, { Name = "Grade", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Parent = card })
	Kit.Text({ Name = "Label", Text = spec.id, Font = "Title", TextSize = 14, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 38, 0.5, 0),
		Size = UDim2.new(1, -112, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local _, setBar, fill = Kit.Bar(Colors.Green, { Name = "Bar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(66, 16), Parent = card },
		{ text = true, textSize = 11 })
	cards[spec.id] = { card = card, badge = badge, setBar = setBar, fill = fill, spec = spec }
end

-- the Growth Spurt row
local spurtRow = Kit.Card({ Name = "Spurt", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 44), Piece = "banner_gold", Parent = right }, {})
local spurtTitle = Kit.Text({ Name = "Title", Text = "", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -130, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = spurtRow })
local spurtSub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(12, 23), Size = UDim2.new(1, -130, 0, 15),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = spurtRow })
local spurtButton = Kit.Button("Gold", "Grow!", { Name = "GrowthSpurt", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = spurtRow },
	{ width = 110, height = 30, textSize = 14, icon = "arrow-big-up" })
local spurtCount = Kit.Text({ Name = "Count", Text = "", Font = "Title", TextSize = 18, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(110, 24), TextXAlignment = Enum.TextXAlignment.Right, Parent = spurtRow })

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
	Kit.IconTile("dumbbell", Colors.Blue, 30, { Name = "Tile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Parent = card })
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
local geneticsButton = Kit.Button("Blue", "Open Genetics", { Name = "OpenGenetics", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = overall },
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
	local nextSpurt = data.growthSpurts + 1
	if progress.ready and wasReady == false then
		statsButton:SetDot(true) -- something new: clears when the window opens
		musclesTile:SetDot(true)
	end
	wasReady = progress.ready
	if not modal.isOpen() then return end

	local grades = data.genetics and data.genetics.grades or {}
	if currentTab == "Muscles" then
		-- the 8 cards: % toward the Growth Spurt goal
		for _, c in pairs(cards) do
			local spec = c.spec
			local grade = grades[spec.group] or "B"
			Kit.SetGrade(c.badge, grade)
			-- the bar in the grade's color (mockup 07)
			local color = Kit.GradeColors[grade] or Colors.Green
			local gloss = c.fill:FindFirstChild("Gloss")
			if gloss then gloss.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2)) end
			local share
			if spec.muscle then
				share = Muscles.ExactLevel(data.muscles[spec.muscle]) / math.max(progress.required, 1)
			else
				share = progress.groups[spec.group] / math.max(progress.required, 1)
			end
			if progress.maxed then share = math.max(share, 1) end
			local pct = math.floor(math.clamp(share, 0, 9.99) * 100 + 0.5)
			c.setBar(math.min(share, 1), pct .. "%")
		end
		-- the body card
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
		sizeLabel.Text = math.floor(average * 100 + 0.5) .. "% SIZE"
		for _, entry in ipairs(PHYSIQUES) do
			if average < entry[1] then physiqueLabel.Text = "Physique: " .. entry[2] break end
		end
		drawFigure()
		-- the Growth Spurt row
		if progress.maxed then
			spurtTitle.Text = "Growth Spurt " .. data.growthSpurts .. "  ·  " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts)) .. " (MAX)"
			spurtSub.Text = "Max Growth Spurt reached. Your muscles keep growing."
		else
			spurtTitle.Text = "Growth Spurt " .. nextSpurt .. "  ·  " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(nextSpurt))
			spurtSub.Text = string.format("%d/%d groups at their goal  ·  gains x%.2f after", progress.met, progress.total, GrowthSpurts.GetBonus(nextSpurt))
		end
		spurtButton.Visible = progress.ready and not progress.maxed
		spurtCount.Visible = not spurtButton.Visible
		spurtCount.Text = progress.maxed and "MAX" or (progress.met .. "/" .. progress.total)
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
end)
