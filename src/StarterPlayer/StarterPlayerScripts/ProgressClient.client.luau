-- ProgressClient: the Growth Spurt button in the right column (owner's final kit "BLACK + GOLD", mockup 01_hud) and the
-- short "you grew" moment when the body moves up a muscle tier (BodyService fires "Grew").
--  * The button (a card in the right column, one card at a time: RightColumn.Priority): when every group is at its goal,
--    the wide gold TAP TO GROW CTA ("GROWTH SPURT 2 READY" under it) with a glow that pulses, the first card to show; a
--    tap does the Growth Spurt (same action as the Physique screen's button). Before that it is a quiet dark card
--    "GROWTH SPURT 2" with how far you are ("62%"), shown only when no other card wants the spot; a tap opens Physique.
--    At 7'0" there is no card (owner, 14 Oct and again 15 Oct: the top bar's height reads "7'0" MAX", Stats has the greyed
--    "Max Growth Spurt reached" button).
--  * The next small goal (a new weight a few reps away, coins for the next weight, which group to train) is a hint in the
--    top band now and then (Notify.Hint), not text on the HUD.
--  * (prompt 20, 21 Oct) What the spurt still needs: "62% · Needs LEGS" on the card; a tap opens "Train next" (the
--    machines for those groups, GO = a glowing path there). On a machine a small card at the top left shows the same (the
--    right column folds there), and a hint says when the machine doesn't help ("Your legs are holding you back. Try the
--    Squat Rack."). When the spurt is ready a big READY TO GROW popup shows over everything, once.
--  * (prompt 21) At 7'0" the same card, strip, "Train next" window and popup are for the next Body Alter (Config.Alters):
--    "NEXT: VASCULAR · 62% · Needs LEGS", BODY ALTER READY with an ALTER button, then the transformation moment (camera
--    on you, a flash, the new skin, "ALTER 3: TANNED"). Past the last alter with textures: "MORE ALTERS SOON".
--    (prompt 22) The popup and the transformation are themed per alter: Shared.UI.AlterPopup and Shared.VFX.AlterFX
--    (Config.AlterThemes); nearby players see the flash ("AlterBurst").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local Gains = require(Config.Gains)
local GrowthSpurts = require(Config.GrowthSpurts)
local Alters = require(Config.Alters)
local AlterThemes = require(Config.AlterThemes)
local Onboarding = require(Config.Onboarding)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local RightColumn = require(Shared.UI.RightColumn)
local Notify = require(Shared.UI.Notify)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------
local UIBus = require(Shared.UI.UIBus)
local AlterPopup = require(Shared.UI.AlterPopup)
local AlterFX = require(Shared.VFX.AlterFX)
local ReadyGlow = require(Shared.UI.ReadyGlow)
local TILE_H = 48 -- (owner, 22 Oct: 10% taller)
local holder = New("Frame", { Name = "GrowthSpurt", Size = UDim2.fromOffset(RightColumn.Width, TILE_H + 6), BackgroundTransparency = 1, Visible = false })
local tile = Theme.Button("Gold", { Name = "Tile", Size = UDim2.new(1, 0, 0, TILE_H), Parent = holder }, {})
local tileText = Kit.Text({ Name = "Grow", Text = "TAP TO GROW", Font = "Title", TextSize = 18, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), Parent = tile })
Kit.Fit(tileText, 18, 11) -- ("MAX GROWTH SPURT" fits the card)
local tileLabel = Kit.Text({ Name = "Label", Text = "", Font = "Title", TextSize = 11, Upper = true, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 13), Parent = tile })
-- (prompt 45, mockup 05_hud_dark_chunky) ready: a taller card, TAP TO GROW big and chunky with the line under it
local READY_H = 68 -- (owner, 22 Oct: 10% taller)
local bigText = Kit.Text({ Name = "Big", Text = "TAP TO GROW", Font = "Chunky", TextSize = 28, Position = UDim2.fromOffset(6, 7), Size = UDim2.new(1, -12, 0, 32),
	Visible = false, Parent = tile })
Kit.Fit(bigText, 28, 16)
local growArt -- (below)
local function setReadyLook(on: boolean)
	bigText.Visible = on
	tileText.Visible = not on
	if growArt then growArt.Visible = on end
	tile.Size = UDim2.new(1, 0, 0, if on then READY_H else TILE_H)
	holder.Size = UDim2.fromOffset(RightColumn.Width, (if on then READY_H else TILE_H) + 6)
	bigText.Position = UDim2.fromOffset(6, if on then 12 else 7)
	bigText.Size = UDim2.new(1, -12, 0, if on then 26 else 32)
	tileLabel.Position = UDim2.fromOffset(0, if on then 40 else 26)
	tileLabel.TextSize = if on then 13 else 11
	tileLabel.Size = UDim2.new(1, 0, 0, if on then 15 else 13)
end
-- (prompt 31) "NEXT: TANNED" wears the next alter's theme (Config.AlterThemes, prompt 22): a dark base in its colour, its
-- accent edge, a thin strip of its background art along the bottom, the name in its title gradient; the progress "55%"
-- in white top-right and "TAP FOR WHAT TO TRAIN" small and gray. It changes by itself for each next alter.
-- (owner, 23 Oct) the art covers the WHOLE card behind everything (Crop, clipped to the rounded corners by a CanvasGroup),
-- under a dark gradient (55% black on the left behind the words, 25% on the right); it drifts slowly sideways (~20 s
-- loop; still with Reduced Motion on). (`alterStrip` is that whole-card layer; the name stays from the thin strip it was.)
local alterStrip = New("CanvasGroup", { Name = "AlterArt", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -3, 1, -3), ZIndex = tile.ZIndex, Visible = false, Parent = tile }, { New("UICorner", { CornerRadius = UDim.new(0, 9) }) })
local alterArt = New("ImageLabel", { Name = "Art", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.16, 1), Parent = alterStrip })
-- (prompt 57) a wash of the alter's colour over a dark art (AlterThemes pillWash; SHREDDED) and the shade's strength per alter
-- (pillShade), so every alter's art shows about as much as PUMPED's
local alterWash = New("Frame", { Name = "Wash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
	ZIndex = 2, Parent = alterStrip })
local alterShade = New("UIGradient", { Transparency = NumberSequence.new(0.45, 0.75) })
New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = alterStrip }, { alterShade })
-- (owner, 23 Oct) READY: the same pill and the art drifts a bit faster (alterReadyColor set by setAlterLook; nil =
-- progressing). (prompt 57) The pill's outline is the HUD cards' own (chrome: 1.5 px, solid) tinted in the next alter's
-- colour, no gold; READY = that outline does the ready glow (Shared/UI/ReadyGlow: a soft glow breathing behind the pill
-- and a highlight travelling round the outline), still in the alter's colour. (prompt 58) The GROWTH SPURT card the same,
-- in GROW_ACCENT (the gold of the TAP TO GROW button).
local alterReadyColor: Color3? = nil
local GROW_ACCENT = Colors.Gold
-- a card's outline in `color` (nil = the plain chrome outline), glowing when ready; the glow is made on first use (the
-- outline is the card's own Border, from its style). (prompt 58: the machine strip uses it too)
local function outliner(target: GuiObject, pad: number)
	local glow = nil
	return function(color: Color3?, ready: boolean)
		local edge = target:FindFirstChild("Border")
		if not (edge and edge:IsA("UIStroke")) then return end
		if not glow then
			if not color then return end
			-- (the glow goes one layer under the card: at layer 1 they'd tie and the glow could cover the card)
			if target.ZIndex < 2 then target.ZIndex = 2 end
			glow = ReadyGlow.New(target, { stroke = edge, pad = pad })
		end
		glow:Set(color ~= nil and ready, color or Colors.Outline)
	end
end
local cardOutline = outliner(tile, 16)
task.spawn(function()
	local phase, last = 0, os.clock()
	while alterStrip.Parent do
		local now = os.clock()
		local dt = now - last
		last = now
		local still = Theme.ReducedMotion()
		phase += dt * 2 * math.pi / (if alterReadyColor then 9 else 20)
		if alterStrip.Visible and holder.Parent and not still then
			alterArt.Position = UDim2.fromScale(0.5 + 0.07 * math.sin(phase), 0.5)
		else
			alterArt.Position = UDim2.fromScale(0.5, 0.5)
		end
		task.wait(1 / 20)
	end
end)
-- the small gold "!" chip in the %'s place when ready
local readyChip = New("Frame", { Name = "ReadyChip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 6), Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = Colors.Gold, Visible = false, ZIndex = tile.ZIndex + 4, Parent = tile }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 1.5 }),
})
Kit.Text({ Name = "Bang", Text = "!", Font = "Chunky", TextSize = 13, TextColor3 = Colors.Ink, Stroke = false, Size = UDim2.fromScale(1, 1), ZIndex = tile.ZIndex + 5,
	Parent = readyChip }):SetAttribute("KeepColor", true)
local alterPct = Kit.Text({ Name = "Pct", Text = "", Font = "Number", TextSize = 15, TextColor3 = Colors.Text, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(46, 22), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = tile })
alterPct:SetAttribute("KeepColor", true)
local titleGradient = New("UIGradient", { Name = "AlterTitle", Rotation = 90, Enabled = false, Parent = tileText })
-- (owner, 23 Oct: no bicep icon on this pill, only the alter's art and the words; the icons stay in the panels)
for _, words in ipairs({ tileText, tileLabel, bigText, alterPct }) do words.ZIndex = tile.ZIndex + 4 end
local function setAlterLook(theme, percent: number?, ready: boolean?)
	local on = theme ~= nil
	alterReadyColor = if on and ready then theme.accent else nil
	readyChip.Visible = on and ready == true
	titleGradient.Enabled = on and not ready
	alterStrip.Visible = on
	alterPct.Visible = on and not ready
	cardOutline(if on then theme.accent else nil, ready == true)
	tileText.Position = UDim2.fromOffset(8, 4)
	tileLabel.Position = UDim2.fromOffset(if on then 4 else 0, tileLabel.Position.Y.Offset)
	tileLabel.Size = UDim2.new(1, if on then -4 else 0, 0, tileLabel.Size.Y.Offset)
	tileText.Size = UDim2.new(1, if on then -60 else -16, 0, 22)
	tileText.TextXAlignment = if on then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	if not on then return end
	-- (owner, 23 Oct, chrome reset) the card stays dark graphite (prompt 57: its chrome outline in the alter's colour,
	-- cardOutline above); the name keeps its alter gradient, the strip its art
	local shade = theme.pillShade or { 0.45, 0.75 }
	alterShade.Transparency = NumberSequence.new(shade[1], shade[2])
	alterWash.BackgroundColor3, alterWash.BackgroundTransparency = theme.accent, theme.pillWash or 1
	if theme.bg then
		alterArt.Image, alterArt.BackgroundTransparency = theme.bg, 1
	else
		alterArt.Image, alterArt.BackgroundTransparency, alterArt.BackgroundColor3 = "", 0, theme.accent:Lerp(theme.base, 0.4)
	end
	tileText.TextColor3 = if ready then theme.accent else Color3.new(1, 1, 1)
	local stroke = tileText:FindFirstChild("TextStroke")
	if stroke then stroke.Color, stroke.Transparency, stroke.Thickness = Colors.Outline, if ready then 0 else 0.5, if ready then 1.5 else 1 end
	titleGradient.Color = ColorSequence.new(theme.title[1], theme.title[2])
	alterPct.Text = (percent or 0) .. "%"
	alterPct.TextColor3 = Colors.Gold
	tileLabel.TextColor3 = if ready then Color3.new(1, 1, 1) else Color3.fromHex("#9A97A0")
end

-- (owner, 23 Oct, chrome reset) the card's look: chrome, dark graphite, clean italic words. (prompts 57 / 58) No gold
-- outline any more: the HUD cards' own outline tinted in the card's colour (cardOutline: the next alter's, or GROW_ACCENT
-- for a Growth Spurt), and READY = that outline glows (TAP TO GROW is the same card, taller, its words in GROW_ACCENT).
local function styleTile(style: string, chrome: boolean)
	tile:SetAttribute("Chrome", chrome or nil)
	Theme.SetButtonStyle(tile, style)
end
tileLabel.RichText = true
local GOLD_HEX = "#" .. Colors.Gold:ToHex()

-- (owner, 15 Oct: always shown under the one priority card; it had vanished behind Today's Quest)
RightColumn.Add(holder, 9, "bottom")
local started = false -- (shown after the data is in)

-- (prompt 57, owner 23 Oct) no "Finish faster: Shake Bundle >" upsell lines on the HUD any more (they were under this card
-- and the machine strip, prompt 12)

-- (prompt 57) READY: the same dark card, taller: "GROWTH SPURT 2" big white stroked, "TAP TO GROW" small in the growth colour
-- under it, both upright (not italic), fixed sizes that fit on a 667x375 phone; a faint upward arrow fills the right side
local UPRIGHT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
growArt = New("ImageLabel", { Name = "GrowArt", BackgroundTransparency = 1, Image = require(Config.UI).Icons["arrow-big-up"] or "", ImageColor3 = Colors.Gold,
	ImageTransparency = 0.82, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(58, 58), Visible = false,
	ZIndex = tile.ZIndex + 1, Parent = tile })

------------------------------------------------------------------------
-- Progress + goals
------------------------------------------------------------------------
local currentMachine = nil -- the machine the player is on (MachineState)
local ready = false

local function spurtProgress(data)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	if progress.maxed then
		-- (prompt 21) at 7'0": the next Body Alter (maxed = nothing to work toward: the next alter isn't out yet)
		progress = Alters.Progress(data, Muscles.Groups, trainable)
		progress.alter = true
		progress.maxed = progress.locked
	end
	local have, need = 0, 0
	for _, group in ipairs(Muscles.Groups) do
		local level = progress.groups[group.id] or 0
		have += Muscles.Shown(math.min(level, progress.required))
		need += Muscles.Shown(progress.required)
	end
	return progress, have, need
end

-- Reps of `machine` (at the tier the player lifts now) until its main muscle reaches `level`.
local function repsToLevel(data, machine, level)
	local main = data.muscles[machine.muscles[1].id]
	local need = -main.xp
	for l = main.level, level - 1 do need += Muscles.XpToNext(l) end
	local tierIndex = Machines.LiftTier(machine, data.machines[machine.id], main.level)
	local perRep = Gains.PerRep(data, machine, tierIndex, player:GetAttribute("GainsBoost"))[machine.muscles[1].id] or 1
	return math.max(1, math.ceil(need / math.max(perRep, 0.01)))
end

-- The next small goal for a machine: a heavier weight.
local function machineGoal(data, machine)
	local progress = data.machines[machine.id]
	local level = data.muscles[machine.muscles[1].id].level
	local usable = Machines.UsableTier(machine, progress, level)
	local nextTier = machine.tiers[usable + 1]
	if not nextTier then return nil end
	local weight = Machines.WeightText(nextTier)
	if level < nextTier.unlockLevel then
		if machine.trains == "Stamina" then -- (running trains stamina: the faster speeds unlock with leg training)
			return "Train " .. Muscles.ById[machine.muscles[1].id].name .. " to unlock " .. weight
		end
		local reps = repsToLevel(data, machine, nextTier.unlockLevel)
		return reps .. (reps == 1 and " rep" or " reps") .. " to unlock " .. weight
	end
	return weight .. " is ready: press + on the panel" -- (weights are free, owner 14 Oct)
end

-- The open machines that train a group (their main muscle is in it), one per machine type; then up to 2 dumbbell
-- exercises (prompt 32: before Growth Spurt 2 the arms only have dumbbells).
local DUMBBELLS_SHOWN = 2
local function machinesFor(data, groupId)
	local list, dumbbells, seen = {}, {}, {}
	for _, machine in ipairs(Machines.List) do
		local open = data.growthSpurts >= Machines.OpenAt(machine) and machine.gym ~= "Seasonal"
		if open and machine.trains ~= "Stamina" and not seen[machine.id] and Muscles.ById[machine.muscles[1].id].group == groupId then
			seen[machine.id] = true
			table.insert(machine.dumbbell and dumbbells or list, machine)
		end
	end
	for i = 1, math.min(DUMBBELLS_SHOWN, #dumbbells) do table.insert(list, dumbbells[i]) end
	return list
end

local function goalText(data, progress)
	if progress.maxed or progress.ready then return "" end
	if currentMachine then
		local goal = machineGoal(data, currentMachine)
		if goal then return goal end
	end
	-- the group furthest from the goal, and a machine that trains it
	local lowest, lowestLevel = nil, math.huge
	for _, group in ipairs(Muscles.Groups) do
		local level = progress.groups[group.id]
		if level < progress.required and level < lowestLevel then lowest, lowestLevel = group, level end
	end
	if not lowest then return "" end
	local machine = machinesFor(data, lowest.id)[1]
	if machine then
		return "Next: " .. lowest.name .. (machine.dumbbell and (" with the " .. machine.name .. " (dumbbells)") or (" on the " .. machine.name))
	end
	return "Next: train " .. lowest.name
end

------------------------------------------------------------------------
-- What the Growth Spurt still needs (prompt 20, 21 Oct: the bar got stuck at 78% / 96% and nothing said which muscles
-- were missing). The groups under the goal, furthest behind first; the card, the machine strip and the stamina bar's
-- "Recovering" line name the first two ("Needs LEGS, BACK"), and the Body Map colors them red.
------------------------------------------------------------------------
local NEEDS_SHOWN = 2
local function missingGroups(progress)
	local list = {}
	if progress.maxed or progress.ready then return list end
	for _, group in ipairs(Muscles.Groups) do
		local level = progress.groups[group.id] or 0
		if level < progress.required then table.insert(list, { group = group, share = level / math.max(progress.required, 1) }) end
	end
	table.sort(list, function(a, b) return a.share < b.share end)
	return list
end

-- Only groups clearly behind the best one are named (at the start of a spurt every group is at 0%: nothing to single out).
local BEHIND = 0.15
local function needsText(missing, progress): string
	local best = 0
	for _, group in ipairs(Muscles.Groups) do best = math.max(best, math.min((progress.groups[group.id] or 0) / math.max(progress.required, 1), 1)) end
	local names = {}
	for _, item in ipairs(missing) do
		if #names < NEEDS_SHOWN and item.share <= best - BEHIND then table.insert(names, string.upper(item.group.name)) end
	end
	return table.concat(names, ", ")
end


-- does this machine train any of these groups (main or a real secondary muscle)?
local function helps(machine, missing): boolean
	for _, entry in ipairs(machine.muscles) do
		if (entry.share or 1) >= Machines.GoalShare then
			local group = Muscles.ById[entry.id].group
			for _, item in ipairs(missing) do
				if item.group.id == group then return true end
			end
		end
	end
	return false
end

------------------------------------------------------------------------
-- The "what to train" window: the missing groups, their machines, and a GO button each (a glowing path to the nearest
-- free one, Shared/UI/GuidePath; it goes away when you get on that machine; a dumbbell exercise leads to the nearest free
-- dumbbell Train spot).
------------------------------------------------------------------------
local GuidePath = require(Shared.UI.GuidePath)
local needsModal = Kit.Modal({ name = "SpurtNeeds", title = "Train next", width = 520, height = 262, displayOrder = 26, icon = "dumbbell" })
local needsIntro = Kit.Text({ Name = "Intro", Text = "", Font = "Strong", TextSize = 14, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
	Parent = needsModal.body })
-- (owner, 22 Oct) the rows scroll in a fixed-height list; SEE YOUR PHYSIQUE has its own strip under it (never over a row)
local STRIP_H = 44
local needsList = New("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 1, -(26 + STRIP_H + 10)), ClipsDescendants = true, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = needsModal.body }, {
	Theme.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local physiqueButton = Kit.Button("Quiet", "See your physique", { Name = "Physique", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
	Parent = needsModal.body }, { height = STRIP_H, textSize = 14 })
physiqueButton.Activated:Connect(function()
	needsModal.close()
	UIBus.OpenStats:Fire("Muscles")
end)

-- (22 Oct, owner: every GO TO button teleports) a short fade, the server puts you in front of the nearest free one (off
-- your machine first; GoToService), its gold outline for a few seconds. If the teleport can't happen: the glowing path.
local function goTo(machine)
	needsModal.close()
	Audio.PlayUI("Click")
	task.spawn(function()
		local moved = GuidePath.Teleport(machine.id)
		GuidePath.Show(machine.id, "Needs")
		local place = if machine.dumbbell then "dumbbells (" .. machine.name .. ")" else machine.name
		if not moved then Notify.Hint("Follow the glowing dots to the " .. place .. ".") end
		local shownAt = os.clock()
		local keep = if moved then 8 else 120
		task.delay(keep, function() -- (never left on forever)
			if os.clock() - shownAt >= keep - 1 then GuidePath.Hide("Needs") end
		end)
	end)
end

local function openNeeds()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local progress = spurtProgress(data)
	local missing = missingGroups(progress)
	for _, child in ipairs(needsList:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	needsModal.setTitle(if progress.alter then "Alter " .. progress.next .. ": " .. Alters.Get(progress.next).name else "Growth Spurt " .. (data.growthSpurts + 1))
	if #missing == 0 then
		needsIntro.Text = if progress.ready then (if progress.alter then "Every muscle group is ready. Tap ALTER!" else "Every muscle group is ready. Tap TAP TO GROW!")
			else "Nothing left to train for now."
	else
		local names = {}
		for i = 1, math.min(NEEDS_SHOWN, #missing) do table.insert(names, string.lower(missing[i].group.name)) end
		needsIntro.Text = "Your " .. table.concat(names, " and ") .. (#names == 1 and " is" or " are") .. " furthest behind. Train:"
	end
	local order = 0
	for i = 1, math.min(NEEDS_SHOWN, #missing) do
		local group = missing[i].group
		for _, machine in ipairs(machinesFor(data, group.id)) do
			order += 1
			local row = Theme.Panel({ Name = machine.id, LayoutOrder = order, Piece = "hud_box", Size = UDim2.new(1, -8, 0, 50), Parent = needsList })
			Kit.Tag(string.upper(group.name), Colors.Red, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(0, 18), Parent = row })
			Kit.Text({ Text = if machine.dumbbell then machine.name .. " (dumbbells)" else machine.name, Font = "Title", TextSize = 15, Position = UDim2.fromOffset(90, 0), Size = UDim2.new(1, -200, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
			-- (owner, 22 Oct) GO fits inside the row: 36 tall, centred, 12 px from the right
			local go = Kit.Button("Green", "Go", { Name = "Go", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row },
				{ height = 36, width = 80, textSize = 15 })
			go.Activated:Connect(function() goTo(machine) end)
		end
	end
	UIBus.PanelOpened("SpurtNeeds")
	needsModal.open()
end
UIBus.RegisterPanel("SpurtNeeds", function() needsModal.close() end)

------------------------------------------------------------------------
-- On a machine (the right column folds away there): a small Growth Spurt card at the top left, under the top bar, with
-- the % and what it needs; when every group is ready it says TAP TO GROW (ALTER NOW). (prompt 58) Chrome like the right
-- column's card: its outline in the card's colour (GROW_ACCENT, or the next alter's), glowing when ready (no gold button).
------------------------------------------------------------------------
local stripGui = Theme.ScreenGui({ Name = "SpurtStrip", DisplayOrder = 6, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
stripGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local stripRoot = Kit.Root(stripGui)
local strip = Theme.Button("Quiet", { Name = "Strip", Position = UDim2.fromOffset(12, 52), Size = UDim2.fromOffset(196, 50), Parent = stripRoot }, {})
Theme.SetChrome(strip)
local stripOutline = outliner(strip, 14)
local stripTitle = Kit.Text({ Name = "Title", Text = "", Font = "Title", TextSize = 13, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = strip })
local _, setStripBar = Kit.Bar(Colors.Teal, { Name = "Bar", Position = UDim2.fromOffset(10, 23), Size = UDim2.new(1, -20, 0, 6), Parent = strip }, { outline = 1 })
local stripNeeds = Kit.Text({ Name = "Needs", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Colors.Red, Position = UDim2.fromOffset(10, 31),
	Size = UDim2.new(1, -20, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = strip })
Kit.OnTopbar(function() strip.Position = UDim2.fromOffset(12, Kit.UnderTopbar(stripRoot)) end)

-- the Growth Spurt (or at 7'0" the Body Alter) from a machine: off the machine first (the body changes), then grow
local alterMode = false
local alterController = nil -- (prompt 22) the transformation playing (its title card takes the "Altered" reward)
local lastLocalAlter = -math.huge
local function alterInfo(n: number)
	local alter = Alters.Get(n)
	local tier = Alters.Tiers[Alters.TierOf(n)]
	return { alter = n, name = alter and alter.name or "", bonus = Alters.Bonus(n), tier = Alters.TierOf(n), tierName = tier and tier.name }
end
-- (prompt 22) the Body Alter: the themed transformation (AlterFX); the ALTER action goes to the server at its flash, so the
-- new skin appears under the white
local function startAlter()
	if AlterFX.Running() then return end
	local data = ClientData.Get()
	local progress = Alters.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
	if not progress.ready or progress.locked then return end
	local n = progress.next
	lastLocalAlter = os.clock()
	local function go()
		alterController = AlterFX.Transform(AlterThemes.Get(n), alterInfo(n), {
			onFlash = function() Remotes.PlayerAction:FireServer("Alter") end,
			onDone = function() alterController = nil end,
		})
	end
	if currentMachine then
		Remotes.MachineAction:FireServer("Leave")
		task.delay(0.6, go)
	else
		go()
	end
end
local function growNow()
	if alterMode then
		startAlter()
		return
	end
	if currentMachine then
		Remotes.MachineAction:FireServer("Leave")
		task.delay(0.6, function() Remotes.PlayerAction:FireServer("GrowthSpurt") end)
	else
		Remotes.PlayerAction:FireServer("GrowthSpurt")
	end
end
strip.Activated:Connect(function()
	Audio.PlayUI("Click")
	if ready then growNow() else openNeeds() end
end)

------------------------------------------------------------------------
-- READY TO GROW: a big popup with a sound and a glowing button, on top of everything (the machine HUD too), once each time
-- the Growth Spurt becomes ready. It stays until tapped (or "Later").
------------------------------------------------------------------------
local readyGui = Theme.ScreenGui({ Name = "GrowReady", DisplayOrder = 45, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
readyGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local readyRoot = Kit.Root(readyGui)
local readyCard = Theme.Panel({ Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(340, 150),
	Parent = readyRoot }, { New("UIStroke", { Color = Colors.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
local readyTitle = Kit.Text({ Name = "Title", Text = "READY TO GROW!", Font = "Title", TextSize = 30, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 36),
	Parent = readyCard })
Kit.GoldText(readyTitle)
local readySub = Kit.Text({ Name = "Sub", Text = "", Font = "Strong", TextSize = 13, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 18), Parent = readyCard })
local readyGo = Kit.Button("Gold", "Tap to grow", { Name = "Grow", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -40, 1, -14), Parent = readyCard },
	{ height = 48, width = 190, textSize = 18 })
local readyLater = Kit.Button("Quiet", "Later", { Name = "Later", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 112, 1, -14), Parent = readyCard },
	{ height = 48, width = 84, textSize = 14 })
local readyScale = New("UIScale", { Parent = readyCard })
local readyShownFor = nil -- the Growth Spurt ("S2") or alter ("A3") the popup was shown for
local function hideReady()
	readyGui.Enabled = false
	AlterPopup.Hide()
end
local function showReady(data, progress)
	if progress.alter then
		-- (prompt 22) the alter's own popup (Shared.UI.AlterPopup), themed per alter
		AlterPopup.Show(progress.next, alterInfo(progress.next), { onAlter = startAlter })
		return
	else
		readyTitle.Text = "READY TO GROW!"
		readySub.Text = "Growth Spurt " .. (data.growthSpurts + 1) .. ": grow to " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts + 1), true)
		Kit.SetButton(readyGo, nil, "Tap to grow")
	end
	readyGui.Enabled = true
	readyScale.Scale = 0.5
	Theme.Tween(readyScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	Theme.Pulse(readyGo, function() return readyGui.Enabled end)
	Audio.Play2D("TitleUnlocked")
end
readyGo.Activated:Connect(function()
	hideReady()
	growNow()
end)
readyLater.Activated:Connect(function()
	Audio.PlayUI("Click")
	hideReady()
end)

local lastGoal, lastGoalAt = "", 0
local hintedMachine = nil -- the machine session the "holding you back" hint was shown for
local function refresh()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local progress, have, need = spurtProgress(data)
	ready = progress.ready and not progress.maxed
	alterMode = progress.alter == true
	local nextName = if progress.alter then Alters.Get(progress.next).name else nil
	local missing = missingGroups(progress)
	local needs = needsText(missing, progress)
	player:SetAttribute("SpurtNeeds", if needs ~= "" then needs else nil)
	local percent = math.floor((need > 0 and have / need or 0) * 100)
	-- (prompt 58) the gym the next Growth Spurt opens ("Next: Powerlifting Gym"; not every spurt opens one)
	local nextGym = nil
	if not alterMode and not progress.maxed then
		local gym, gymName, at = Machines.NextGym(data.growthSpurts)
		if gym and at == data.growthSpurts + 1 and Machines.GymLevel(data) < at then nextGym = gymName end
	end
	-- the machine strip (prompt 53: not while the tutorial runs, only the tutorial on screen)
	stripGui.Enabled = started and currentMachine ~= nil and not progress.maxed and not UIBus.InTutorial()
	if ready then
		stripTitle.Text = if alterMode then "ALTER NOW" else "TAP TO GROW"
		stripNeeds.Text = if alterMode then "Alter " .. progress.next .. ": " .. nextName .. " ready" else "Growth Spurt " .. (data.growthSpurts + 1) .. " ready"
		stripNeeds.TextColor3 = Colors.Text
		setStripBar(1)
	else
		stripTitle.Text = (if alterMode then "NEXT: " .. string.upper(nextName) else "GROWTH SPURT " .. (data.growthSpurts + 1)) .. " · " .. percent .. "%"
		stripNeeds.Text = if needs ~= "" then "Needs " .. needs elseif nextGym then "Next: " .. nextGym else ""
		stripNeeds.TextColor3 = Colors.Red
		setStripBar(percent / 100)
	end
	local stripTheme = if alterMode then AlterThemes.Get(progress.next) else nil
	local stripColor = if stripTheme then stripTheme.accent else GROW_ACCENT
	Theme.SetButtonStyle(strip, "Quiet")
	stripOutline(stripColor, ready)
	stripTitle.TextColor3 = if ready then stripColor else Colors.Text
	-- READY TO GROW / BODY ALTER READY: once per spurt / alter
	local readyKey = if alterMode then "A" .. progress.next else "S" .. data.growthSpurts
	if ready and started and readyShownFor ~= readyKey then
		readyShownFor = readyKey
		showReady(data, progress)
	elseif not ready and (readyGui.Enabled or AlterPopup.IsOpen()) then
		hideReady()
	end
	-- on a machine that doesn't help the groups that are behind: one hint per machine session
	-- (no hints while the tutorial runs: its own line is in the same band, and two different "next" steps confuse; prompt 20)
	local inTutorial = (data.onboarding and data.onboarding.tutorialStep or Onboarding.Done) < Onboarding.Done
	if not inTutorial and currentMachine and not ready and #missing > 0 and hintedMachine ~= currentMachine and not helps(currentMachine, missing) then
		hintedMachine = currentMachine
		local first = missing[1].group
		local suggestion = machinesFor(data, first.id)[1]
		Notify.Hint("Your " .. string.lower(first.name) .. " " .. (string.sub(first.name, -1) == "s" and "are" or "is") .. " holding you back."
			.. (suggestion and (" Try the " .. suggestion.name .. ".") or ""))
		lastGoalAt = os.clock()
	end
	holder:SetAttribute("CardPriority", ready and RightColumn.Priority.GrowReady or RightColumn.Priority.Grow)
	setReadyLook(ready and not alterMode) -- (an alter keeps the same pill when ready)
	-- (owner, 15 Oct, later: at the 7'0" cap NO card on the HUD; the top bar's "7'0" MAX" and the Stats panel's greyed
	-- button show it)
	holder.Visible = started and (alterMode or not progress.maxed)
	setAlterLook(nil)
	if alterMode and progress.maxed then
		-- (the next alter has no textures yet)
		tileText.Text = "MORE ALTERS SOON"
		tileLabel.Text = Alters.Label(Alters.State(data).highest or 0)
		styleTile("Disabled", true)
	elseif alterMode and ready then
		-- (owner, 23 Oct) the same pill as while progressing: "PUMPED READY" in the alter's colour, "TAP TO ALTER", a gold
		-- "!" chip; the outline pulses in the alter's colour; a tap opens the BODY ALTER READY popup
		tileText.Text = string.upper(nextName) .. " READY"
		tileLabel.Text = "Tap to alter"
		styleTile("Quiet", true) -- (prompt 57: no gold outline; setAlterLook tints it in the alter's colour)
		setAlterLook(AlterThemes.Get(progress.next), percent, true)
	elseif alterMode then
		tileText.Text = "NEXT: " .. string.upper(nextName)
		tileLabel.Text = if needs ~= "" then "Needs " .. needs else "Tap for what to train"
		styleTile("Quiet", true)
		setAlterLook(AlterThemes.Get(progress.next), percent)
	elseif progress.maxed then
		tileText.Text = "MAX GROWTH SPURT"
		tileLabel.Text = "Reached · " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts), true)
		styleTile("Disabled", true)
	elseif ready then
		tileText.Text = "TAP TO GROW"
		styleTile("Quiet", true)
		cardOutline(GROW_ACCENT, true) -- (prompt 58: the outline glows; it was the loud gold button pulsing)
		-- (prompt 57) the spurt big and white, TAP TO GROW small in the growth colour (fonts set after the style: it resets them)
		bigText.Text = "GROWTH SPURT " .. (data.growthSpurts + 1)
		bigText.FontFace, bigText.TextColor3, bigText.TextSize = UPRIGHT, Color3.new(1, 1, 1), 22
		local bigStroke = bigText:FindFirstChild("TextStroke")
		if bigStroke then bigStroke.Color, bigStroke.Transparency, bigStroke.Thickness = Colors.Outline, 0, 2 end
		Kit.Fit(bigText, 22, 15)
		tileLabel.Text = "TAP TO GROW" .. (if nextGym then " · " .. string.upper(nextGym) else "")
		tileLabel.FontFace, tileLabel.TextColor3 = UPRIGHT, GROW_ACCENT
	else
		tileText.Text = "GROWTH SPURT " .. (data.growthSpurts + 1)
		tileLabel.Text = '<font color="' .. GOLD_HEX .. '">' .. percent .. "%</font>" .. (if nextGym then " · Next: " .. nextGym elseif needs ~= "" then " · Needs " .. needs else " · tap for your physique")
		styleTile("Quiet", true)
		cardOutline(GROW_ACCENT, false)
	end
	-- the next small goal: a hint now and then (never more than one a minute, and only a new one)
	local goal = goalText(data, progress)
	if not inTutorial and goal ~= "" and goal ~= lastGoal and os.clock() - lastGoalAt > 60 then
		lastGoal, lastGoalAt = goal, os.clock()
		Notify.Hint(goal)
	end
end
UIBus.TutorialChanged.Event:Connect(function() refresh() end)
UIBus.OpenNeeds.Event:Connect(function() openNeeds() end) -- (prompt 54: Coach Dex's ALTERS tab, WHAT TO TRAIN)

tile.Activated:Connect(function()
	if alterMode and not ready and Alters.Progress(ClientData.Get(), Muscles.Groups, Machines.TrainableMuscles(ClientData.Get().growthSpurts)).locked then
		return
	end
	if ready and alterMode then
		-- (owner, 23 Oct) the ready alter pill opens the BODY ALTER READY popup
		local data = ClientData.Get()
		showReady(data, spurtProgress(data))
	elseif ready then
		growNow()
	else
		openNeeds() -- (prompt 20: what to train, with GO buttons; the window links to the physique)
	end
end)

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		currentMachine = Machines.ById[model:GetAttribute("MachineId")]
		-- arrived where a GO button led: the path is done
		local target = Machines.ById[GuidePath.Target() or ""]
		if currentMachine and (GuidePath.Target() == currentMachine.id or (target and target.dumbbell and model:GetAttribute("Dumbbell"))) then
			GuidePath.Hide("Needs")
		end
	elseif state == "Exit" then
		currentMachine = nil
		hintedMachine = nil
	end
	refresh()
end)

------------------------------------------------------------------------
-- "You grew": a quick pulse on the body, a sound and a small note
------------------------------------------------------------------------
local function grewMoment(tier)
	local character = player.Character
	if not character then return end
	Audio.Play2D("Grew")
	local glow = New("Highlight", {
		FillColor = Colors.Text,
		FillTransparency = 0.45,
		OutlineColor = Colors.Text,
		OutlineTransparency = 0.3,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Adornee = character,
		Parent = character,
	})
	Theme.Tween(glow, { FillTransparency = 1, OutlineTransparency = 1 }, 0.8)
	task.delay(0.85, function() glow:Destroy() end)
	local camera = Workspace.CurrentCamera
	local fov = camera.FieldOfView
	camera.FieldOfView = fov + 3
	Theme.Tween(camera, { FieldOfView = fov }, 0.35)
	Notify.Show("You grew! Muscle tier " .. tier)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, payload)
	if kind == "Grew" and type(payload) == "table" and type(payload.tier) == "number" then
		grewMoment(payload.tier)
	elseif kind == "Altered" and type(payload) == "table" and type(payload.alter) == "number" then
		hideReady()
		if alterController then
			alterController.setReward(payload.reward)
		elseif os.clock() - lastLocalAlter > 8 then
			-- (an alter that didn't start here: the flash at once, the skin is already on)
			local info = alterInfo(payload.alter)
			info.instant = true
			AlterFX.Transform(AlterThemes.Get(payload.alter), info).setReward(payload.reward)
		end
	elseif kind == "AlterBurst" and type(payload) == "table" and type(payload.userId) == "number" and type(payload.alter) == "number" then
		-- (prompt 22) someone nearby altered: their flash, shockwave and particles (no camera move)
		local other = Players:GetPlayerByUserId(payload.userId)
		if other and other ~= player and other.Character then AlterFX.Burst(other.Character, AlterThemes.Get(payload.alter), false) end
	end
end)
UIBus.StartAlter.Event:Connect(function()
	hideReady()
	startAlter()
end)

-- (prompt 11) the 25 / 50 / 75% rewards on the way to a Growth Spurt (SpurtMilestoneService): a popup with the coins and a
-- sound; at 75% "Almost there!"
task.spawn(function()
	local remote = Remotes:WaitForChild("SpurtMilestone", 30)
	if not remote then return end
	remote.OnClientEvent:Connect(function(info)
		if type(info) ~= "table" or type(info.percent) ~= "number" then return end
		local title = "GROWTH SPURT " .. tostring(info.spurt or "") .. ": " .. info.percent .. "%"
		local sub = "+" .. Kit.Format(tonumber(info.coins) or 0) .. " coins · " .. (if info.last then "Almost there!" else "You're growing. Keep going!")
		Notify.Reward(title, sub, "arrow-big-up", Colors.Gold, if info.last then "LevelUp" else "QuestClaim", "spurtmilestone")
	end)
end)

------------------------------------------------------------------------
-- (26 Oct, funnel: 54% of new players left between the end of the tutorial and the first Growth Spurt goal, with nothing
-- on screen saying where to train) Until the first Growth Spurt, off a machine: a gold GO TRAIN button at the bottom
-- centre (the tutorial's GO TO spot) for the group furthest from the goal; it teleports you to a machine for it (goTo).
-- Hidden while a window or a Coach Dex dialog / GO TO button (tutorial, unlock guides) is up.
------------------------------------------------------------------------
local CoachDialog = require(Shared.UI.CoachDialog)
local playerGui = player:WaitForChild("PlayerGui")
local trainGui = Theme.ScreenGui({ Name = "GoTrain", DisplayOrder = 5, Parent = playerGui })
local trainRoot = Kit.Root(trainGui)
local trainButton = Kit.Button("Gold", "Go train", { Name = "GoTrain", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Visible = false,
	Parent = trainRoot }, { width = 240, height = 38, textSize = 15 })
Theme.SetChrome(trainButton)
local trainTarget = nil -- the machine the button leads to
local trainHiddenUntil = 0 -- (just teleported: the button steps aside so it's not over the machine's Occupy prompt)
trainButton.Activated:Connect(function()
	if not trainTarget then return end
	trainHiddenUntil = os.clock() + 12
	trainButton.Visible = false
	goTo(trainTarget)
end)

local function otherGuideUp(): boolean
	for _, name in ipairs({ "Tutorial", "Guide" }) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("LayerCollector") and gui.Enabled then
			for _, child in ipairs(gui:GetDescendants()) do
				if (child.Name == "CoachDialog" or child.Name == "GoTo") and child:IsA("GuiObject") and child.Visible then return true end
			end
		end
	end
	return false
end

local function updateTrainButton()
	local data = ClientData.Get()
	local show = false
	if started and data and data.muscles and (data.growthSpurts or 0) == 0 and not currentMachine and not ready and not UIBus.InTutorial()
		and (data.onboarding and (data.onboarding.tutorialStep or Onboarding.Done) >= Onboarding.Done) and os.clock() >= trainHiddenUntil
		and not UIBus.CoverOpen(playerGui) and not needsModal.isOpen() and not otherGuideUp() then
		local progress = spurtProgress(data)
		local missing = missingGroups(progress)
		local first = missing[1]
		local machine = first and machinesFor(data, first.group.id)[1]
		if machine then
			show = true
			if trainTarget ~= machine then
				trainTarget = machine
				Kit.SetButton(trainButton, "Gold", "Go train " .. string.lower(first.group.name))
			end
		end
	end
	trainButton.Visible = show
	if show then trainButton.Position = UDim2.new(0.5, 0, 1, -CoachDialog.BottomClear(trainRoot)) end
end
task.spawn(function()
	while true do
		local ok, err = pcall(updateTrainButton)
		if not ok then warn("[GoTrain] " .. tostring(err)) end
		task.wait(0.5)
	end
end)

------------------------------------------------------------------------
task.spawn(function()
	ClientData.Get() -- waits for the data snapshot
	started = true
	refresh()
end)
ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" or key == "machines" or key == "coins" or key == "alter" then refresh() end
end)
task.spawn(function()
	while true do
		task.wait(2)
		refresh()
	end
end)
