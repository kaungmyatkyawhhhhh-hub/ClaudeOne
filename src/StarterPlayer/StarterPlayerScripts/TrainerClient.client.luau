-- TrainerClient (prompt 24, 21 Oct; was the COACHES hire window): the TRAINER AGENCY. Trainers come from coin rolls, like
-- eggs in pet games (Config/Trainers; every roll is made on the server, TrainerService). Coins only, the odds always shown.
--   * The window (the Trainers tile in the side menu, or the Agency desk's "Roll trainers" prompt). (prompt 27, 22 Oct, the
--     kit design kit_agency_stand.png) On the left the odds grid: 8 rarity slots (the trainer's portrait on a rarity glow,
--     the rarity name and chance; not owned yet = a black silhouette with a rim, Secret a black "?"); on the right the pity
--     counter ("EPIC GUARANTEED IN 37 ROLLS"), the red ROLL (E), flat X3 (R, from Growth Spurt 2) and AUTO (T: keeps
--     rolling while you have coins, stops on Epic or better), a gear (auto-delete toggles: Common, Uncommon duplicates
--     become coins), MY TRAINERS (the window's second tab) and the +1 slot pass.
--   * (prompt 28) Two tabs: AGENCY (the above) and MY TRAINERS (Shared/UI/TrainersPanel: slots, the trainers you own; it
--     was the Inventory's Trainers tab). UIBus.OpenAgency("My") opens it on MY TRAINERS.
--   * The roll (prompt 49: see "The roll reveal" below; Config.RollReveal): per card an orb drops into its slot, pulses
--     (more and slower for rarer), bursts into the card (Legendary+ in slow motion with rays and a shockwave), the card
--     dresses itself; then a bottom bar with the summary, ROLL AGAIN and CLOSE. A tap skips to the end.
--   * (owner, prompt 48) Only a Secret or Eternal roll is told to the whole server: a short gold banner at the top (~4 s),
--     a chat line in the rarity's color and a small sound. Nothing else goes server-wide.
--   * The signs over the Agency desks (tag AgencyBoard): TRAINER AGENCY + the trainers' pictures (prompt 28). (prompt 27,
--     22 Oct: the one stand left, in the starter gym, is an old-school desk with a cork board of photo cards built in Studio,
--     tools/builders/TrainerAgency; no AgencyBoard is tagged now, the code below stays for a sign that gets the tag.)
-- The trainers themselves are drawn by TrainerFollowClient; owning / equipping: the MY TRAINERS tab (Shared/UI/TrainersPanel).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trainers = require(Shared.Config.Trainers)
local PumpShop = require(Shared.Config.PumpShop)
local Monetization = require(Shared.Config.Monetization)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local TrainerPortrait = require(Shared.UI.TrainerPortrait)
local AlterFX = require(Shared.VFX.AlterFX)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Trainers", 60) :: RemoteEvent
if not remote then return end -- the trainer service didn't start

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 780, 306 -- (fits 667 x 375: 702 x 284 px)
local LEFT_W = 372
local PASS = Monetization.PassByKey[Trainers.ExtraSlotPass]
local LUCKIEST = AlterFX.TitleFont

local function tween(instance, props, time, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function hex(c) return Color3.fromHex(c) end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local function data() return ClientData.Get() or {} end
local function state() return Trainers.Migrate(data().trainers) end
local function spurts() return data().growthSpurts or 0 end
local function price(): number return Trainers.RollPrice(PumpShop.Rate(spurts())) end
local function multiOpen(): boolean return spurts() >= Trainers.MultiRollFromSpurt end
local function ownsAny(id: string): boolean
	for _, copy in ipairs(state().copies) do
		if copy.id == id then return true end
	end
	return false
end
-- (prompt 33) how many copies of him you have (any stage)
local function copiesOf(id: string): number
	local n = 0
	for _, copy in ipairs(state().copies) do
		if copy.id == id then n += 1 end
	end
	return n
end
local function rarityOf(trainer) return Trainers.RarityById[trainer.rarity] end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local menuButton = SideMenu.Add("Trainers", "Trainers", Icons.Clipboard, 7.5)
local tab = "My"
local showTab -- (below)
local myPanel -- (below: MY TRAINERS)
local agencyFrame -- (below: the AGENCY tab's content)
local bindKeys, keyboard -- (below: E / R / T while the Agency tab is open)
local modal = Kit.Modal({ name = "Trainers", title = "Trainers", width = W, height = H, displayOrder = 25, coins = true,
	tabs = { { id = "Agency", text = "Agency" }, { id = "My", text = "My trainers" } },
	onTab = function(id)
		tab = id
		Audio.PlayUI("Click")
		agencyFrame.Visible = id == "Agency"
		myPanel.frame.Visible = id == "My"
		if id == "My" then myPanel.refresh() end
		if bindKeys then bindKeys(keyboard and id == "Agency") end
	end })
agencyFrame = New("Frame", { Name = "Agency", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = modal.body })
local titleRow = modal.panel:FindFirstChild("TitleRow", true)
myPanel = require(Shared.UI.TrainersPanel).Build(modal.body, { row = titleRow, group = modal.group })
-- (prompt 52) the references' short gold underline under the title
require(Shared.UI.TrainersPanel).Underline(modal.panel, { Position = UDim2.fromOffset(18, 47), ZIndex = 3 })
local onTab -- (below: the window's look per screen)
-- (prompt 31) a red dot on MY TRAINERS while there's a trainer you haven't seen there yet
do
	local Discovery = require(Shared.UI.Discovery)
	local TrainersPanel = require(Shared.UI.TrainersPanel)
	local myTab = modal.panel:FindFirstChild("Tabs", true)
	myTab = myTab and myTab:FindFirstChild("My")
	local function dot()
		if myTab and ClientData.IsLoaded() then
			Discovery.Dot(myTab, Discovery.HasNew("Trainers", TrainersPanel.Discovered(ClientData.Get().trainers)))
		end
	end
	ClientData.Changed:Connect(function(path)
		if path[1] == "trainers" or path[1] == "settings" then dot() end
	end)
	task.spawn(function()
		ClientData.Get()
		dot()
	end)
end
-- (prompt 54, 23 Oct) one window, two places: the left-nav TRAINERS button opens only MY TRAINERS (your trainers); the
-- Trainer Agency (rolling) opens only at the Agency desk in the Starter Gym (its "ROLL TRAINERS" prompt); its own MY
-- TRAINERS button (bottom of the roll side) switches to your trainers. No tabs.
local tabsRow = modal.panel:FindFirstChild("Tabs", true)
if tabsRow then tabsRow.Visible = false end
function showTab(id: string)
	tab = id
	modal.selectTab(id)
	modal.setTitle(if id == "My" then "Trainers" else "Trainer agency") -- (prompt 52: as in the references)
	agencyFrame.Visible = id == "Agency"
	myPanel.frame.Visible = id == "My"
	if onTab then onTab(id) end
	if id == "My" then myPanel.refresh() end
	if bindKeys then bindKeys(keyboard and id == "Agency" and modal.isOpen()) end
end

-- (prompt 52, 23 Oct: rebuilt to the owner's reference ref_agency.png) ONE panel: TRAINER AGENCY with the gold underline,
-- the 8 rarities as 2 rows of 4 big trainer tiles (Shared/UI/TrainerTile in rarity mode: his name, his portrait (a black
-- silhouette with a rim on a bright burst until you own him; Secret and Eternal "???" too), the rarity name in its color,
-- the chance as a percentage; a gold check when owned, "x2" bottom-right). A tap (or hover) shows his name and boost.
-- UNDER the panel, centred: the pity pill ("EPIC GUARANTEED IN 63 ROLLS" and a thin teal bar), then one row: the red ROLL
-- ("525 COINS"), flat X3 (its price) and AUTO (OFF / ON), MY TRAINERS and the gear (the auto-delete toggles).
-- The tiles take the room the screen has (layoutWindow, below).
local CELL_GAP = 8
local AGENCY_TOP = 54 -- (the panel's header: the title and its underline)
local ROW_H = 46
local CONTROLS_H = 8 + 28 + 6 + ROW_H -- (under the panel: a gap, the pity pill, a gap, the button row)
local ROW_W = 140 + 70 + 70 + 96 + 44 + 4 * 6
local grid = New("Frame", { Name = "Odds", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = agencyFrame }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -CELL_GAP * 3 / 4, 0.5, -CELL_GAP / 2), CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal }),
})
local slots = {}
local slotPx = 0
local tooltip = New("Frame", { Name = "Tooltip", BackgroundColor3 = Color3.fromHex("#0E0E11"), BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(150, 40), Visible = false, ZIndex = 20, Parent = agencyFrame }, {
	New("UICorner", { CornerRadius = UDim.new(0, 8) }),
	New("UIStroke", { Color = Colors.Gold, Thickness = 1, Transparency = 0.3 }),
})
local tipName = Kit.Text({ Name = "Name", Text = "", Font = "Title", TextSize = 12, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 15),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = tooltip })
local tipPerk = Kit.Text({ Name = "Perk", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, TextWrapped = true, Position = UDim2.fromOffset(8, 18),
	Size = UDim2.new(1, -16, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21, Parent = tooltip })
local tipShownAt = 0
local function hideTip() tooltip.Visible = false end
local function showTip(slot)
	local hidden = rarityOf(slot.trainer).hidden == true and not ownsAny(slot.trainer.id)
	tipName.Text = if hidden then "???" else slot.trainer.name
	tipPerk.Text = if hidden then "Hidden until you own one. Who is it?" else slot.trainer.perkText
	-- over the lower part of the slot's own tile (in the Agency frame's mockup px)
	local gridW = 4 * slotPx + 3 * CELL_GAP
	local k = math.max(agencyFrame.AbsoluteSize.X, 1) / math.max(gridW, 1) -- (screen pixels per mockup px)
	local rel = (slot.cell.AbsolutePosition - agencyFrame.AbsolutePosition) / k
	local size = slot.cell.AbsoluteSize.X / k
	tooltip.Position = UDim2.fromOffset(math.clamp(rel.X + size / 2, 75, gridW - 75), rel.Y + size - 3)
	tooltip.Visible = true
	tipShownAt = os.clock()
	local at = tipShownAt
	task.delay(2.5, function() if tipShownAt == at then hideTip() end end)
end

local TrainerTile = require(Shared.UI.TrainerTile)
-- (prompt 47) the portraits and stage backgrounds load once at join, so the first reveal never shows an empty card
task.spawn(function()
	local ids = {}
	for _, portrait in pairs(Trainers.Portraits or {}) do table.insert(ids, portrait.icon) table.insert(ids, portrait.art) end
	for _, art in pairs(Trainers.StageArt or {}) do table.insert(ids, art.hex) table.insert(ids, art.evo) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)
local function refreshRows()
	for id, slot in pairs(slots) do
		local rarity = rarityOf(slot.trainer)
		local owned = ownsAny(id)
		slot.tile:Set({ id = id, rarity = true, silhouette = not owned, owned = owned, caption = Trainers.ChanceText(rarity.chance) })
		local n = copiesOf(id)
		slot.count.Text = if n >= 2 then "x" .. n else ""
	end
end
-- the 8 tiles at this size (made again when the room changes: the words inside are sized from it)
local function buildSlots(px: number)
	if px == slotPx then return end
	slotPx = px
	for _, slot in pairs(slots) do slot.cell:Destroy() end
	table.clear(slots)
	for order, trainer in ipairs(Trainers.List) do
		local cell = New("Frame", { Name = trainer.id, LayoutOrder = order, BackgroundTransparency = 1, Parent = grid })
		local tile = TrainerTile.New({ Name = "Tile", px = px, Size = UDim2.fromScale(1, 1), Parent = cell })
		local countSize = math.max(10, math.floor(px * 0.13))
		local count = Kit.Text({ Name = "Count", Text = "", Font = "Chunky", TextSize = countSize, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4),
			Size = UDim2.fromOffset(countSize * 3, countSize + 3), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12, Parent = tile.button })
		local slot = { cell = cell, tile = tile, count = count, trainer = trainer, order = order }
		slots[trainer.id] = slot
		tile.button.Activated:Connect(function()
			Kit.SelectFeedback(tile.button) -- (prompt 54: bounce + select sound)
			if tooltip.Visible and tipName.Text ~= "" and os.clock() - tipShownAt < 2.5 and tooltip:GetAttribute("For") == trainer.id then hideTip() return end
			tooltip:SetAttribute("For", trainer.id)
			showTip(slot)
		end)
		tile.button.MouseEnter:Connect(function()
			tooltip:SetAttribute("For", trainer.id)
			showTip(slot)
		end)
		tile.button.MouseLeave:Connect(function() if tooltip:GetAttribute("For") == trainer.id then hideTip() end end)
	end
	if ClientData.IsLoaded() then refreshRows() end
end

-- UNDER the panel (in the window's group, not the panel): the pity pill and the button row
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local FLAT = Color3.fromHex("#1A1A1F")
local FLAT_EDGE = Color3.fromHex("#2E2E36")
local TEAL = Color3.fromHex("#2FD4C4")
local INK_TEXT = Color3.fromHex("#0A090B")
local controls = New("Frame", { Name = "AgencyControls", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(ROW_W, CONTROLS_H - 8),
	Visible = false, Parent = modal.group })
local pityPill = New("Frame", { Name = "PityPill", BackgroundColor3 = Color3.fromHex("#111114"), BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(300, 28), Parent = controls }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = FLAT_EDGE, Thickness = 1 }),
})
local pity = Kit.Text({ Name = "Pity", Text = "", Font = "Strong", TextSize = 12, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 16), Parent = pityPill })
Kit.Fit(pity, 12, 8)
-- (prompt 52) a thin teal bar under the words (the old thick block is gone)
local pityTrack = New("Frame", { Name = "Track", BackgroundColor3 = Color3.fromHex("#2A2A31"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 19), Size = UDim2.new(1, -44, 0, 4), Parent = pityPill }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local pityFill = New("Frame", { Name = "Fill", BackgroundColor3 = TEAL, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = pityTrack }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
local function setPity(k: number)
	k = math.clamp(k, 0, 1)
	pityFill.Size = UDim2.fromScale(k, 1)
	pityFill.Visible = k > 0.005
end
local row = New("Frame", { Name = "Row", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, ROW_H), Parent = controls }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

keyboard = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
-- two lines on a button (as in the reference): the big word in the heavy italic, the small value under it
local function twoLines(button: GuiObject, big: string, small: string, bigSize: number)
	local top = Kit.Text({ Name = "Big", Text = big, Font = "Title", KeepItalic = true, TextSize = bigSize, Position = UDim2.new(0, 0, 0, 3), Size = UDim2.new(1, 0, 0.55, -2),
		ZIndex = 6, Parent = button })
	top:SetAttribute("KeepFont", true)
	local stroke = top:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = top })
	stroke.Color, stroke.Thickness = INK_TEXT, 1.5
	local bottom = Kit.Text({ Name = "Small", Text = small, Font = "Strong", TextSize = 12, Position = UDim2.new(0, 0, 0.55, 0), Size = UDim2.new(1, 0, 0.3, 0),
		ZIndex = 6, Parent = button })
	bottom:SetAttribute("KeepFont", true)
	return top, bottom
end
-- a FLAT button (no bevel, no gloss, darker): X3, AUTO, MY TRAINERS, the gear
local function flatButton(name: string, width: number, order: number)
	local b = New("TextButton", { Name = name, LayoutOrder = order, Text = "", AutoButtonColor = false, BackgroundColor3 = FLAT, Size = UDim2.fromOffset(width, ROW_H),
		Parent = row }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	local edge = New("UIStroke", { Name = "Edge", Color = FLAT_EDGE, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	Theme.BindPress(b)
	return b, edge
end
local rollButton = Theme.Button("Red", { Name = "Roll", LayoutOrder = 1, Size = UDim2.fromOffset(140, ROW_H), Parent = row }, {})
local _rollBig, rollSmall = twoLines(rollButton, "ROLL", "", 22)
local x3Button, x3Edge = flatButton("X3", 70, 2)
local x3Big, x3Small = twoLines(x3Button, "X3", "", 20)
local autoButton, autoEdge = flatButton("Auto", 70, 3)
local _autoBig, autoSmall = twoLines(autoButton, "AUTO", "OFF", 18)
local myTrainers = flatButton("MyTrainers", 96, 4)
Kit.Text({ Name = "Label", Text = "MY TRAINERS", Font = "Title", KeepItalic = true, TextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(6, 0),
	Size = UDim2.new(1, -12, 1, 0), ZIndex = 6, Parent = myTrainers }):SetAttribute("KeepFont", true)
local gearButton = flatButton("Gear", 44, 5)
local gearIcon = Pieces.Icon("settings", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22),
	ZIndex = 6, Parent = gearButton })
gearIcon:SetAttribute("KeepColor", true)
-- the gear's popover: the auto-delete toggles (it opens upward, over the panel's bottom edge)
local popover = New("Frame", { Name = "AutoDelete", BackgroundColor3 = Color3.fromHex("#0E0E11"), AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 0, 28), Size = UDim2.fromOffset(250, 84), Visible = false, ZIndex = 15, Parent = controls }, {
	New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	New("UIStroke", { Color = Colors.Gold, Thickness = 1, Transparency = 0.3 }),
})
Kit.Text({ Name = "Title", Text = "AUTO-DELETE DUPLICATES", Font = "Title", TextSize = 11, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 14),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = popover })
Kit.Text({ Name = "Hint", Text = "They turn into coins.", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(10, 20),
	Size = UDim2.new(1, -20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = popover })
local deleteToggles = {}
for i, rarityId in ipairs(Trainers.AutoDeleteRarities) do
	local x = 10 + (i - 1) * 120
	Kit.Text({ Text = Trainers.RarityById[rarityId].name, Font = "Strong", TextSize = 11, TextColor3 = hex(Trainers.RarityById[rarityId].color),
		Position = UDim2.fromOffset(x, 40), Size = UDim2.fromOffset(62, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = popover })
	local toggle, set = Kit.Toggle(false, function(on)
		Audio.PlayUI("Click")
		remote:FireServer("AutoDelete", rarityId, on)
	end, { Name = "Delete" .. rarityId, Position = UDim2.fromOffset(x + 62, 40), Size = UDim2.fromOffset(52, 36), ZIndex = 16, Parent = popover })
	deleteToggles[rarityId] = { button = toggle, set = set }
end
gearButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	popover.Visible = not popover.Visible
end)
myTrainers.Activated:Connect(function()
	Audio.PlayUI("Click")
	showTab("My")
end)
-- (prompt 31 / 54) the red dot for a trainer you haven't seen in MY TRAINERS yet: on this button (the tabs are gone)
do
	local Discovery = require(Shared.UI.Discovery)
	local TrainersPanel = require(Shared.UI.TrainersPanel)
	local function dot()
		if ClientData.IsLoaded() then Discovery.Dot(myTrainers, Discovery.HasNew("Trainers", TrainersPanel.Discovered(ClientData.Get().trainers))) end
	end
	ClientData.Changed:Connect(function(path)
		if path[1] == "trainers" or path[1] == "settings" then dot() end
	end)
	task.spawn(function()
		ClientData.Get()
		dot()
	end)
end

-- (prompt 52) the window's size for the screen it's on (mockup px): MY TRAINERS lays itself out in the room (TrainersPanel),
-- the Agency's tiles take the height left over by the controls under the panel
local function rootUnits(): Vector2
	local size = modal.root.Size
	if size.X.Scale == 0 then return Vector2.new(size.X.Offset, size.Y.Offset) end -- (Studio's TestPhoneSize)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Kit.Base
	return Vector2.new(viewport.X * size.X.Scale, viewport.Y * size.Y.Scale)
end
local function layoutWindow()
	local units = rootUnits()
	local under = math.max(16, Kit.UnderTopbar(modal.root))
	local maxW = (units.X - 16) / Kit.PanelScale
	local maxH = math.min((units.Y - under - 16) / Kit.PanelScale, 560)
	local group, panelFrame, body = modal.group, modal.panel, modal.body
	if tab == "My" then
		body.Position = UDim2.fromOffset(14, Kit.TitleHeight)
		local bodyH = math.floor(maxH - Kit.TitleHeight - 14)
		local bodyW = myPanel.layout(bodyH, maxW - 28)
		group.Size = UDim2.fromOffset(bodyW + 28, bodyH + Kit.TitleHeight + 14)
		panelFrame.AnchorPoint, panelFrame.Position, panelFrame.Size = Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1)
	else
		body.Position = UDim2.fromOffset(14, AGENCY_TOP)
		local tile = math.clamp(math.floor((maxH - CONTROLS_H - AGENCY_TOP - 14 - CELL_GAP) / 2), 70, 165)
		if 4 * tile + 3 * CELL_GAP + 28 > maxW then tile = math.floor((maxW - 28 - 3 * CELL_GAP) / 4) end
		local panelW = 4 * tile + 3 * CELL_GAP + 28
		local panelH = AGENCY_TOP + 2 * tile + CELL_GAP + 14
		group.Size = UDim2.fromOffset(math.max(panelW, ROW_W), panelH + CONTROLS_H)
		panelFrame.AnchorPoint, panelFrame.Position, panelFrame.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.fromOffset(panelW, panelH)
		controls.Position = UDim2.new(0.5, 0, 0, panelH + 8)
		buildSlots(tile)
	end
end
Kit.OnScale(function() task.defer(function() if modal.isOpen() then layoutWindow() end end) end)
-- per screen: the title, the coins (the Agency only), the controls under the panel, the size
local titleList = titleRow and titleRow:FindFirstChildOfClass("UIListLayout")
function onTab(id: string)
	local agency = id == "Agency"
	modal.title.TextSize = if agency then 26 else 30
	if modal.closeButton then modal.closeButton.Visible = true end
	if modal.coins then modal.coins.Visible = agency end
	if titleList then titleList.Padding = UDim.new(0, if agency then 14 else 10) end
	controls.Visible = agency
	popover.Visible = false
	hideTip()
	if not agency then myPanel.closeOverlays() end
	layoutWindow()
end
Kit.OnTopbar(function() if modal.isOpen() then layoutWindow() end end)

local autoOn = false
local autoLoop -- (below)
local function setAuto(on: boolean)
	autoOn = on
	autoSmall.Text = if on then "ON" else "OFF"
	-- (prompt 47) AUTO ON: green
	autoSmall.TextColor3 = if on then Color3.fromHex("#4BE07A") else Colors.Muted
	autoEdge.Color = if on then Color3.fromHex("#4BE07A") else FLAT_EDGE
	autoEdge.Thickness = if on then 2.5 else 1.5
end

local function refresh()
	local s = state()
	local p = price()
	local left = Trainers.Pity - (s.pity or 0)
	pity.Text = string.upper(Trainers.PityRarity) .. " GUARANTEED IN " .. left .. " ROLL" .. (if left == 1 then "" else "S")
	setPity((s.pity or 0) / Trainers.Pity)
	local coins = data().coins or 0
	-- (prompt 27c) a free roll from the rebalance gift: "FREE" instead of the price
	local free = (s.freeRolls or 0) > 0
	rollSmall.Text = if free then "FREE" else Kit.Format(p) .. " COINS"
	rollSmall.TextColor3 = Colors.Text
	Theme.SetButtonStyle(rollButton, if free or coins >= p then "Red" else "Disabled")
	if multiOpen() then
		x3Big.Text = "X3"
		x3Small.Text = Kit.Format(p * Trainers.MultiRoll)
		x3Small.TextColor3 = Colors.Muted
		x3Big.TextColor3 = if coins >= p * Trainers.MultiRoll then Colors.Text else Colors.Muted
	else
		x3Big.Text = "X3"
		x3Small.Text = "SPURT " .. Trainers.MultiRollFromSpurt
		x3Big.TextColor3 = Colors.Muted
	end
	x3Edge.Color = FLAT_EDGE
	for rarityId, t in pairs(deleteToggles) do t.set(s.autoDelete[rarityId] == true) end
	refreshRows()
end

------------------------------------------------------------------------
-- The roll reveal (prompt 49, 22 Oct; it replaces prompt 27's card flip and 27b's orb reveal). Every timing, size and
-- volume is in Config.RollReveal.
--   * The screen: ~90% black, the HUD out of the way (the side menu and the top bar step aside, the Agency window hides),
--     gameplay music ducked to ~30% until it closes.
--   * The card: the trainer tile at a larger scale: a dark hex base (small cells), a 4 px outline and sunburst rays in the
--     rarity color (no colored fill), his full body (~65-70% of the card), a near-black rarity pill with the rarity name in
--     its color, his NAME (white chunky, dark stroke), his boost (gold, stroked), for a dupe a pill "X2 · 2/3 TO IRON-BORN"
--     with a bar, for a new one a tilted gold NEW! sticker on the top-left corner. Size by rarity (Common 90% ... Mythic+
--     115%, lifted, a glow past the edge). Everything is scaled to fit between the top bar and the bottom bar.
--   * Per card: the orb drops into its slot (the glow's size is the first tell) -> pulses (Common 1 ... Legendary+ 4, each
--     slower; Epic tints the edges, Legendary+ darkens everything else and holds the last beat) -> the burst (Common /
--     Uncommon small, the rest a hard white flash; the card snaps in 0 -> 1.15 -> 1; Legendary+ in slow motion with a
--     shockwave and turning rays) -> the dress (pill, name slam, boost, NEW!, dupe bar; a shimmer over Legendary+ names)
--     -> the hold (it floats, the glow breathes, a quiet hum).
--   * Batch: dashed dark slots in a row, revealed lowest to highest; the revealed ones dim to 80% while the next plays,
--     then all brighten. Then a 0.4 s beat, a fanfare and the bar slides up: "1 NEW · 2 DUPES", ROLL AGAIN (red, its
--     price) and CLOSE; TAP TO CONTINUE pulses.
--   * A tap during a reveal finishes every card at once (a quick pop each) and shows the bar; the next tap closes.
--   * Auto Roll: the cards snap in and it closes by itself, unless Epic or better (the full reveal; auto roll stops).
--   * Reduced Motion: no shakes, no slow motion, a shorter, softer flash (the pulses stay).
------------------------------------------------------------------------
local RunService = game:GetService("RunService")
local RollReveal = require(Shared.Config.RollReveal)
local RR, RT, RV, Screen = RollReveal.Card, RollReveal.Time, RollReveal.Volume, RollReveal.Screen

-- (over the Notifications gui, 50: the tutorial band and toasts wait under it)
local overlay = Theme.ScreenGui({ Name = "TrainerRoll", DisplayOrder = 52, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
overlay.ScreenInsets = Enum.ScreenInsets.None
overlay.IgnoreGuiInset = true
local dim = New("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = overlay })
local spotlight = AlterFX.Image(overlay, "ember", { Name = "Spotlight", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromScale(0.9, 1.3), ImageColor3 = Color3.fromHex("#FFF3C4"), ImageTransparency = 1, ZIndex = 1 })
local fxLayer = New("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 2, Parent = overlay })
local whiteFlash = New("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20,
	Parent = overlay })
local tapCatcher = New("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30,
	Parent = overlay })
local rollRoot = Kit.Root(overlay)
rollRoot.ZIndex = 5
local barRoot = Kit.Root(overlay, "BarRoot") -- (over the tap catcher: its buttons take their own taps)
barRoot.ZIndex = 40

local GOLD = Color3.fromHex("#F6C75A")
local INK = Color3.fromHex("#0A090B")
local busy = false
local skip = false
local closeWanted = false
local cards = {}
local slots = {}
local transient = {} -- orbs, edge tints, screen rays (cleared on a skip and at the end)
local holdConnection = nil
local humSound = nil
local menuWasHidden = false
local againCount = 1
local requestRoll -- (below: Rolling)

-- the reveal tier: 1 Common, 2 Uncommon / Rare, 3 Epic, 4 Legendary and better
local function tierOf(rarity): number
	if rarity.index >= Trainers.RarityById.Legendary.index then return 4 end
	if rarity.index >= Trainers.RarityById.Epic.index then return 3 end
	if rarity.index >= Trainers.RarityById.Uncommon.index then return 2 end
	return 1
end
-- the rarity's light (outline, orb, rays, rings): its own color (Secret's is near black, so its grey)
local function fxColor(rarity): Color3
	return hex(if rarity.id == "Secret" then rarity.color2 else rarity.color)
end
local function fxTheme(rarity)
	local accent = fxColor(rarity)
	local texture = if rarity.reveal == "lightning" then "lightning" elseif rarity.reveal == "dark" then "smoke" else "spark"
	return { accent = accent, particle = { texture = texture, color = accent, motion = if rarity.reveal == "cosmic" then "drift" else "rise" } }
end
-- a sound: louder for rarer (up to RollReveal.LoudestGain, about +4 dB over Common), cut to OneShotMax
local function sfx(key: string, rarity, volume: number?, opts)
	opts = opts or {}
	local g = if rarity then 1 + (RollReveal.LoudestGain - 1) * (rarity.index - 1) / (#Trainers.Rarities - 1) else 1
	opts.volume = (volume or 1) * g
	if not opts.loop then opts.maxLength = opts.maxLength or RollReveal.OneShotMax end
	return AlterFX.Sound(key, opts)
end
local function isNewResult(result): boolean
	return not result.deleted and (if result.new ~= nil then result.new == true else result.count == 1)
end

-- a wait that a tap cuts short: false = the player skipped
local function wait_(t: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < t do
		if skip then return false end
		task.wait()
	end
	return not skip
end
-- the middle of a GUI object in the FX layer's pixels, and as a share of the screen
local function centerOf(gui: GuiObject): (UDim2, number, number)
	local size = fxLayer.AbsoluteSize
	local p = gui.AbsolutePosition + gui.AbsoluteSize / 2 - fxLayer.AbsolutePosition
	return UDim2.fromOffset(p.X, p.Y), p.X / math.max(size.X, 1), p.Y / math.max(size.Y, 1)
end
-- a small UI shake (Reduced Motion: none)
local function shakeUI(objects: { GuiObject }, strength: number, time: number)
	if Theme.ReducedMotion() then return end
	local bases = {}
	for i, o in ipairs(objects) do bases[i] = o.Position end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			local k = strength * (1 - (os.clock() - t0) / time)
			for i, o in ipairs(objects) do
				if o.Parent then o.Position = bases[i] + UDim2.fromOffset(math.random(-10, 10) / 10 * k, math.random(-10, 10) / 10 * k) end
			end
			task.wait(0.03)
		end
		for i, o in ipairs(objects) do if o.Parent then o.Position = bases[i] end end
	end)
end
-- a tint that creeps in from the 4 screen edges (Epic: its color; Legendary+: black)
local function edgeTint(color: Color3, depth: number, time: number, transparency: number): { Frame }
	local frames = {}
	for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
		local vertical = side == "Top" or side == "Bottom"
		local f = New("Frame", { Name = "Tint" .. side, BackgroundColor3 = color, BorderSizePixel = 0, BackgroundTransparency = transparency,
			AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
			Position = UDim2.fromScale(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
			Size = if vertical then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 1), ZIndex = 3, Parent = fxLayer }, {
			New("UIGradient", { Rotation = ({ Top = 90, Bottom = 270, Left = 0, Right = 180 })[side], Transparency = NumberSequence.new(0, 1) }),
		})
		tween(f, { Size = if vertical then UDim2.fromScale(1, depth) else UDim2.fromScale(depth, 1) }, time, Enum.EasingStyle.Sine)
		table.insert(frames, f)
		table.insert(transient, f)
	end
	return frames
end
-- light rays over the screen behind a card, fading in and turning (~10 degrees a second)
local function screenRays(at: UDim2, color: Color3)
	local rays = New("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(1500, 1500),
		ZIndex = 2, Parent = fxLayer })
	table.insert(transient, rays)
	for i = 0, 7 do
		local ray = New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, if i % 2 == 0 then 70 else 40, 1, 0), Rotation = i * 22.5, BackgroundTransparency = 1, ZIndex = 2, Parent = rays }, {
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1),
				NumberSequenceKeypoint.new(1, 1) }) }),
		})
		tween(ray, { BackgroundTransparency = 0.5 }, 0.6)
	end
	task.spawn(function()
		local last = os.clock()
		while rays.Parent do
			local now = os.clock()
			rays.Rotation += RT.raysDegPerSecond * (now - last)
			last = now
			task.wait(1 / 30)
		end
	end)
end
local function clearTransient()
	for _, o in ipairs(transient) do
		if o.Parent then o:Destroy() end
	end
	table.clear(transient)
end

------------------------------------------------------------------------
-- Layout: every card fits between the top bar and the bottom bar (one shared scale for the batch)
------------------------------------------------------------------------
local function cardHeight(result): number
	local h = RR.pad + RR.art + RR.pill + 2 + RR.name + 2 + RR.perk + RR.bottom
	if result.deleted then
		h += 4 + RR.dupe
	elseif not isNewResult(result) then
		h += 4 + RR.dupe + 3 + RR.dupeBar
	end
	return h
end
-- sets entry.pos / entry.scale / entry.bubble; -> the slot size
local function layout(order): Vector2
	local uiScale = rollRoot:FindFirstChildOfClass("UIScale")
	local s = math.max(if uiScale then uiScale.Scale else Kit.Scale(), 0.01)
	local units = rollRoot.AbsoluteSize / s
	-- (never under Roblox's top bar: its height + 8)
	local top = math.max(Screen.top, game:GetService("GuiService"):GetGuiInset().Y / s + Kit.TopbarGap)
	local availH = units.Y - top - Screen.bottom
	local availW = units.X - 32
	local tallest, totalW = 0, 0
	for _, entry in ipairs(order) do
		local r = RollReveal.RarityScale[entry.rarity.id] or 1
		tallest = math.max(tallest, cardHeight(entry.result) * r + (RollReveal.RarityLift[entry.rarity.id] or 0))
		totalW += RR.width * r
	end
	totalW += Screen.gap * (#order - 1)
	local fit = math.min(1.15, availH / tallest, availW / totalW)
	-- one card: the speech bubble above it when there's room (not on phones)
	local bubble = #order == 1 and availH - tallest * fit >= Screen.bubbleRoom
	local centerY = top + availH / 2 + (if bubble then Screen.bubbleRoom / 2 else 0)
	local x = -totalW * fit / 2
	for _, entry in ipairs(order) do
		local r = RollReveal.RarityScale[entry.rarity.id] or 1
		local w = RR.width * r * fit
		entry.x = x + w / 2
		x += w + Screen.gap * fit
		entry.scale = r * fit
		entry.slotPos = UDim2.new(0.5, entry.x, 0, centerY)
		entry.pos = UDim2.new(0.5, entry.x, 0, centerY - (RollReveal.RarityLift[entry.rarity.id] or 0) * fit)
		entry.bubble = bubble
	end
	return Vector2.new(RR.width * fit, (RR.pad + RR.art + RR.pill + RR.name + RR.perk + RR.bottom) * fit)
end
-- a dark slot with a faint dashed outline
local function dashedSlot(at: UDim2, size: Vector2)
	local slot = New("Frame", { Name = "Slot", BackgroundColor3 = Color3.fromHex("#101013"), BackgroundTransparency = 0.4, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 3, Parent = rollRoot }, { New("UICorner", { CornerRadius = UDim.new(0, RR.corner) }) })
	local dash, gap, thick = 8, 6, 1.5
	for _, edge in ipairs({ "Top", "Bottom", "Left", "Right" }) do
		local horizontal = edge == "Top" or edge == "Bottom"
		local length = if horizontal then size.X else size.Y
		local n = math.max(0, math.floor((length - 2 * RR.corner + gap) / (dash + gap)))
		local start = (length - (n * (dash + gap) - gap)) / 2
		for i = 0, n - 1 do
			local offset = start + i * (dash + gap)
			New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, BorderSizePixel = 0,
				Position = if horizontal then UDim2.new(0, offset, if edge == "Top" then 0 else 1, if edge == "Top" then 0 else -thick)
					else UDim2.new(if edge == "Left" then 0 else 1, if edge == "Left" then 0 else -thick, 0, offset),
				Size = if horizontal then UDim2.fromOffset(dash, thick) else UDim2.fromOffset(thick, dash), ZIndex = 3, Parent = slot })
		end
	end
	slot.BackgroundTransparency = 1
	tween(slot, { BackgroundTransparency = 0.4 }, RT.setup)
	table.insert(slots, slot)
	return slot
end

------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------
local function strokeOf(label: TextLabel): UIStroke
	return label:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Color = INK, Parent = label })
end
-- a label's text and its outlines together (an outline alone would show while the text is faded out)
local function textAlpha(label: TextLabel, alpha: number, time: number?)
	local targets = { label }
	for _, s in ipairs(label:GetChildren()) do
		if s:IsA("UIStroke") then table.insert(targets, s) end
	end
	for _, o in ipairs(targets) do
		local prop = if o:IsA("UIStroke") then "Transparency" else "TextTransparency"
		if time and time > 0 then tween(o, { [prop] = alpha }, time) else o[prop] = alpha end
	end
end
local function makeCard(entry, index: number)
	local result, trainer, rarity = entry.result, entry.trainer, entry.rarity
	local accent = hex(rarity.color)
	local edge = fxColor(rarity)
	local tier = tierOf(rarity)
	local h = cardHeight(result)
	local holder = New("Frame", { Name = "Card" .. index, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = entry.pos,
		Size = UDim2.fromOffset(RR.width, h), Visible = false, ZIndex = 5, Parent = rollRoot })
	New("UIScale", { Scale = entry.scale, Parent = holder })
	-- (the pop scales from the middle)
	local pop = New("Frame", { Name = "Pop", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	local popScale = New("UIScale", { Parent = pop })
	local glowBleed = if rarity.index >= Trainers.RarityById.Mythic.index then 170 elseif tier == 4 then 140 else 100
	local glow = AlterFX.Image(pop, "rim", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, glowBleed, 1, glowBleed), ImageColor3 = edge, ImageTransparency = 1, ZIndex = 4 })
	local card = New("Frame", { Name = "Card", BackgroundColor3 = Color3.fromHex("#141317"), Size = UDim2.fromScale(1, 1), ZIndex = 5, ClipsDescendants = true,
		Parent = pop }, { New("UICorner", { CornerRadius = UDim.new(0, RR.corner) }) })
	New("UIStroke", { Color = edge, Thickness = RR.outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(RR.hexTile.X, RR.hexTile.Y), ImageColor3 = edge:Lerp(Color3.new(1, 1, 1), 0.35), ImageTransparency = RR.hexTransparency,
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(0, RR.corner) }) })
	-- (owner, 23 Oct) the rays and the burst are bigger than the card: they sit in a frame inset by ~0.3 of the corner
	-- radius (ClipsDescendants clips square), so no square corner shows past the rounded edge
	local cardInset = math.ceil(RR.corner * 0.3)
	local cardClip = New("Frame", { Name = "Clip", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(cardInset, cardInset),
		Size = UDim2.new(1, -2 * cardInset, 1, -2 * cardInset), ZIndex = 5, Parent = card })
	-- the sunburst from his chest (turning on Legendary+)
	local artMid = (RR.pad + RR.art * 0.42) / h
	local rays = New("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, artMid),
		Size = UDim2.fromOffset(RR.width * 2.2, RR.width * 2.2), ZIndex = 5, Parent = cardClip })
	for i = 0, RR.rays - 1 do
		New("Frame", { BackgroundColor3 = edge, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 22, 1, 0), Rotation = i * 180 / RR.rays, BackgroundTransparency = RR.raysTransparency, ZIndex = 5, Parent = rays }, {
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1) }) }),
		})
	end
	AlterFX.Image(cardClip, "ember", { Name = "Radial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, artMid), Size = UDim2.new(1.3, 0, 0, RR.art * 1.05),
		ImageColor3 = accent, ImageTransparency = 0.55, ZIndex = 5 })
	TrainerPortrait.Art(trainer.id, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, RR.pad), Size = UDim2.new(RR.artWidth, 0, 0, RR.art),
		ZIndex = 6, Parent = card })
	local y = RR.pad + RR.art
	-- the rarity pill: near black, the rarity name in its color
	local pillPos = UDim2.new(0.5, 0, 0, y)
	local pill = New("Frame", { Name = "Rarity", BackgroundColor3 = Color3.fromHex("#0B0A0D"), AnchorPoint = Vector2.new(0.5, 0), Position = pillPos,
		Size = UDim2.new(0.62, 0, 0, RR.pill), ZIndex = 7, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local pillEdge = New("UIStroke", { Color = edge, Thickness = 1.5, Parent = pill })
	local pillText = Kit.Text({ Name = "Text", Text = string.upper(rarity.name), Font = "Chunky", TextSize = RR.textSizes.pill, TextColor3 = edge, Size = UDim2.fromScale(1, 1),
		ZIndex = 8, Parent = pill })
	strokeOf(pillText).Color = INK
	y += RR.pill + 2
	-- the NAME: white chunky with a dark stroke (on the pop, so the slam isn't clipped)
	local nameLabel = New("TextLabel", { Name = "Name", BackgroundTransparency = 1, Text = string.upper(trainer.name), FontFace = LUCKIEST, TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y + RR.name / 2), Size = UDim2.new(1, -16, 0, RR.name),
		ZIndex = 9, Parent = pop })
	local nameStroke = New("UIStroke", { Thickness = 2.5, Color = INK, Parent = nameLabel })
	local nameScale = New("UIScale", { Parent = nameLabel })
	local shimmer = nil
	if tier == 4 then
		shimmer = New("UIGradient", { Name = "Shimmer", Offset = Vector2.new(-1.2, 0), Rotation = 20, Parent = nameLabel,
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(0.58, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }) })
	end
	y += RR.name + 2
	-- his boost: gold, stroked
	local perk = Kit.Text({ Name = "Perk", Text = trainer.perkText, Font = "Chunky", TextSize = RR.textSizes.perk, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.new(1, -14, 0, RR.perk), ZIndex = 8, Parent = card })
	Kit.Fit(perk, RR.textSizes.perk, 9)
	Kit.GoldText(perk)
	y += RR.perk
	-- a dupe: "X2 · 2/3 TO IRON-BORN" in a small pill with a bar under it (the next evolution, always its real name)
	local dupePill, setDupe, dupeShare = nil, nil, 0
	if result.deleted or not isNewResult(result) then
		local text
		if result.deleted then
			text = "DUPLICATE: +" .. Kit.Format(math.floor(price() * Trainers.AutoDeleteRefund)) .. " COINS"
		else
			local need = Trainers.EvolveCount
			local count = math.max(1, result.count or 1)
			local nextName = Trainers.Stages[2].name
			dupeShare = math.min(count, need) / need
			text = if count >= need then "X" .. count .. " · READY: EVOLVE TO " .. nextName else "X" .. count .. " · " .. count .. "/" .. need .. " TO " .. nextName
		end
		dupePill = New("Frame", { Name = "Dupe", BackgroundColor3 = Color3.fromHex("#0B0A0D"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y + 4),
			Size = UDim2.new(0.84, 0, 0, RR.dupe), ZIndex = 7, Parent = card }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = if result.deleted then Colors.Muted else GOLD, Thickness = 1, Transparency = 0.3 }),
		})
		local t = Kit.Text({ Name = "Text", Text = text, Font = "Chunky", TextSize = RR.textSizes.dupe, TextColor3 = if result.deleted then Colors.Muted else GOLD,
			Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = dupePill })
		Kit.Fit(t, RR.textSizes.dupe, 7)
		if not result.deleted then
			local _bar
			_bar, setDupe = Kit.Bar(GOLD, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y + 4 + RR.dupe + 3), Size = UDim2.new(0.6, 0, 0, RR.dupeBar),
				ZIndex = 7, Parent = card })
			setDupe(0)
		end
	end
	-- NEW!: a tilted gold sticker on the top-left corner
	local sticker = nil
	if isNewResult(result) then
		sticker = New("Frame", { Name = "New", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(28, 16),
			Size = UDim2.fromOffset(64, 26), Rotation = -12, Visible = false, ZIndex = 12, Parent = pop }, {
			New("UICorner", { CornerRadius = UDim.new(0, 6) }),
			New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
			New("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		New("UIScale", { Parent = sticker })
		local t = Kit.Text({ Name = "Text", Text = "NEW!", Font = "Chunky", TextSize = RR.textSizes.sticker, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1),
			ZIndex = 13, Parent = sticker })
		strokeOf(t).Color = INK
	end
	-- dims it to 80% while another card plays
	local shade = New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 14,
		Parent = pop }, { New("UICorner", { CornerRadius = UDim.new(0, RR.corner) }) })
	-- his line in a speech bubble (one card, when there's room)
	local bubble = nil
	if entry.bubble and trainer.line then
		bubble = Kit.Text({ Name = "Line", Text = "\"" .. trainer.line .. "\"", Font = "Strong", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 9, Parent = holder })
		bubble.BackgroundTransparency = 0
		bubble.BackgroundColor3 = Color3.fromHex("#141317")
		bubble.TextColor3 = Color3.new(1, 1, 1)
		New("UICorner", { CornerRadius = UDim.new(0, 10), Parent = bubble })
		New("UIStroke", { Color = edge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bubble })
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = bubble })
	end
	-- undressed: the rows wait for the dress
	pill.BackgroundTransparency, pillEdge.Transparency = 1, 1
	textAlpha(pillText, 1)
	pill.Position = pillPos - UDim2.fromOffset(30, 0)
	nameLabel.Visible = false
	textAlpha(perk, 1)
	if dupePill then dupePill.Visible = false end
	return { entry = entry, holder = holder, pop = pop, popScale = popScale, glow = glow, card = card, rays = rays, pill = pill, pillPos = pillPos, pillEdge = pillEdge,
		pillText = pillText, name = nameLabel, nameStroke = nameStroke, nameScale = nameScale, shimmer = shimmer, perk = perk, dupePill = dupePill, setDupe = setDupe,
		dupeShare = dupeShare, sticker = sticker, shade = shade, bubble = bubble, rarity = rarity, trainer = trainer, tier = tier, pos = entry.pos,
		glowBase = if rarity.index >= Trainers.RarityById.Mythic.index then 0.05 elseif tier == 4 then 0.12 else 0.25 }
end

-- the rows come in top to bottom (instant = all at once: a skip)
local function dress(card, instant: boolean)
	if card.dressed then return end
	card.dressed = true
	local rarity = card.rarity
	local function pillIn(t)
		tween(card.pill, { Position = card.pillPos, BackgroundTransparency = 0 }, t, Enum.EasingStyle.Back)
		tween(card.pillEdge, { Transparency = 0 }, t)
		textAlpha(card.pillText, 0, t)
	end
	local function perkIn(t)
		local at = card.perk.Position
		card.perk.Position = at + UDim2.fromOffset(0, 6)
		tween(card.perk, { Position = at }, t)
		textAlpha(card.perk, 0, t)
	end
	local function dupeIn(t)
		if card.dupePill then card.dupePill.Visible = true end
		if card.setDupe then card.setDupe(card.dupeShare) end
	end
	if instant then
		pillIn(0.05)
		card.name.Visible = true
		card.nameScale.Scale = 1
		perkIn(0.05)
		if card.sticker then card.sticker.Visible = true end
		dupeIn(0)
		return
	end
	local stagger = RT.dressStagger
	pillIn(0.18)
	Audio.PlayUI("Click", { volume = RV.pillClick })
	task.delay(stagger, function()
		-- the name slams in with a stroke flash
		card.name.Visible = true
		card.nameScale.Scale = 1.3
		card.nameStroke.Color = Color3.new(1, 1, 1)
		tween(card.nameScale, { Scale = 1 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.14, function() tween(card.nameStroke, { Color = INK }, 0.2) end)
		sfx("Stamp", rarity, RV.nameStamp, { pitch = 0.9 + rarity.index * 0.05 })
		if card.shimmer then
			task.delay(0.25, function() tween(card.shimmer, { Offset = Vector2.new(1.2, 0) }, 0.6, Enum.EasingStyle.Sine) end)
		end
	end)
	task.delay(stagger * 2, function() perkIn(0.25) end)
	task.delay(stagger * 3, function()
		if not card.sticker then return end
		local scale = card.sticker:FindFirstChildOfClass("UIScale")
		card.sticker.Visible = true
		card.sticker.Rotation = -32
		scale.Scale = 2
		tween(scale, { Scale = 1 }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(card.sticker, { Rotation = -12 }, 0.16)
		task.delay(0.15, function() sfx("Stamp", rarity, RV.sticker, { pitch = 0.75 }) end)
	end)
	task.delay(stagger * 4, function()
		dupeIn()
		if card.setDupe then
			for i = 1, 3 do task.delay((i - 1) * 0.07, function() Audio.PlayUI("Click", { volume = RV.barTick, pitch = 1.2 + i * 0.1 }) end) end
		end
	end)
end

-- the hold: every revealed card floats (+-4 px, 2 s), its glow breathes, Legendary+ rays keep turning
local function startHold()
	if holdConnection then return end
	local t0 = os.clock()
	holdConnection = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		for i, card in ipairs(cards) do
			if card.settled and card.holder.Parent then
				local phase = i * 0.7
				card.holder.Position = card.pos + UDim2.fromOffset(0, math.sin((t + phase) * 2 * math.pi / RT.floatPeriod) * RT.floatPx)
				card.glow.ImageTransparency = card.glowBase + 0.12 * (0.5 + 0.5 * math.sin((t + phase) * 2.4))
				if card.tier == 4 then card.rays.Rotation += RT.raysDegPerSecond * dt end
			end
		end
	end)
end
local function settle(card)
	card.settled = true
	card.holder.Visible = true
	if card.bubble then card.bubble.Visible = true end
	startHold()
	-- the hum in this card's mood
	if humSound then AlterFX.FadeOut(humSound, 0.3) end
	humSound = sfx("Hum", card.rarity, RV.hum, { loop = true, fadeIn = 0.6, pitch = RollReveal.HumPitch[card.rarity.id] or 1 })
end
local function shadeCard(card, amount: number)
	tween(card.shade, { BackgroundTransparency = amount }, 0.2)
end

------------------------------------------------------------------------
-- One card's reveal: the orb, the pulses, the burst. false = skipped
------------------------------------------------------------------------
local function dropOrb(card)
	local rarity = card.rarity
	local color = fxColor(rarity)
	local size = RollReveal.OrbSize
	local orb = New("Frame", { Name = "Orb", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = card.pos - UDim2.fromOffset(0, 240),
		Size = UDim2.fromOffset(size, size), ZIndex = 6, Parent = rollRoot })
	table.insert(transient, orb)
	local scale = New("UIScale", { Parent = orb })
	local glowSize = RollReveal.OrbGlow[rarity.id] or 2
	local halo = AlterFX.Image(orb, "rim", { Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(glowSize, glowSize),
		ImageColor3 = color, ImageTransparency = 0.4, ZIndex = 6 })
	New("Frame", { Name = "Core", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = orb }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), color) }),
		New("UIStroke", { Color = color, Thickness = 3 }),
	})
	local star = AlterFX.Image(orb, "spark", { Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6),
		ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.3, ZIndex = 8 })
	task.spawn(function()
		while orb.Parent do
			star.Rotation += 3
			task.wait(1 / 30)
		end
	end)
	tween(orb, { Position = card.pos }, RT.orbDrop, Enum.EasingStyle.Bounce)
	-- the trail
	task.spawn(function()
		for _ = 1, 6 do
			if not orb.Parent then return end
			local at = centerOf(orb)
			local dot = AlterFX.Image(fxLayer, "spark", { AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(16, 16), ImageColor3 = color,
				ImageTransparency = 0.2, ZIndex = 3 })
			tween(dot, { ImageTransparency = 1, Size = UDim2.fromOffset(4, 4) }, 0.4)
			task.delay(0.42, function() dot:Destroy() end)
			task.wait(RT.orbDrop / 6)
		end
	end)
	task.delay(RT.orbDrop * 0.7, function()
		sfx("Stamp", nil, RV.orbThud, { pitch = 0.6 })
		sfx("Shimmer", nil, RV.orbShimmer)
	end)
	return { frame = orb, scale = scale, halo = halo, color = color }
end

local function pulses(card, orb): boolean
	local rarity = card.rarity
	local tier = card.tier
	local spec = RollReveal.Pulses[rarity.id] or RollReveal.Pulses.Common
	local tones = RollReveal.Tones[rarity.id] or RollReveal.Tones.Legendary
	local swell = nil
	if tier == 3 then
		edgeTint(fxColor(rarity), 0.3, 1.2, 0.4)
		swell = sfx("Swell", rarity, RV.swell, { fadeIn = 0.4, pitch = 0.8 })
	elseif tier == 4 then
		-- everything else goes dark
		tween(dim, { BackgroundTransparency = 0 }, 0.5)
		tween(spotlight, { ImageTransparency = 1 }, 0.5)
		edgeTint(Color3.new(0, 0, 0), 0.45, 1.5, 0)
		for _, other in ipairs(cards) do
			if other ~= card and other.settled then shadeCard(other, 0.45) end
		end
		swell = sfx("Swell", rarity, RV.swell, { fadeIn = 0.6, pitch = 0.75, maxLength = 4 })
	end
	for i, time in ipairs(spec.times) do
		local up = spec.scale + (i - 1) * 0.04
		tween(orb.scale, { Scale = up }, time * 0.45, Enum.EasingStyle.Sine)
		tween(orb.halo, { ImageTransparency = math.max(0, 0.3 - i * 0.08) }, time * 0.45)
		if tier == 1 then
			Audio.PlayUI("Click", { volume = RV.tick, pitch = 0.8 })
		else
			sfx("Chime", rarity, RV.tone, { pitch = 0.8 * (tones[i] or tones[#tones]) })
		end
		AlterFX.Ring(fxLayer, orb.color, 30, 110 + up * 60, time, (centerOf(orb.frame)))
		if not wait_(time * 0.45) then return false end
		tween(orb.scale, { Scale = 1 }, time * 0.55, Enum.EasingStyle.Sine)
		if not wait_(time * 0.55) then return false end
	end
	if tier == 4 then
		-- the held beat: the orb almost still, the swell down to near silence, a tiny heartbeat; then a shake tick
		if swell then tween(swell, { Volume = swell.Volume * 0.08 }, RT.hold) end
		sfx("Heartbeat", nil, RV.heartbeat, { maxLength = 0.6 })
		tween(orb.scale, { Scale = 0.9 }, RT.hold, Enum.EasingStyle.Sine)
		if not wait_(RT.hold) then return false end
		shakeUI({ orb.frame }, 4, 0.1)
	end
	if swell then AlterFX.FadeOut(swell, 0.3) end
	return true
end

local function burst(card, orb)
	local rarity = card.rarity
	local tier = card.tier
	local reduced = Theme.ReducedMotion()
	local slow = tier == 4 and not reduced
	local time = RT.burst * (if slow then RT.burstSlow else 1)
	local small = rarity.index <= Trainers.RarityById.Uncommon.index
	local color = fxColor(rarity)
	local at, x, y = centerOf(orb.frame)
	orb.frame:Destroy()
	if not small then
		whiteFlash.BackgroundTransparency = if reduced then 0.5 else 0
		task.delay(if reduced then RT.flashReduced else RT.flash, function() tween(whiteFlash, { BackgroundTransparency = 1 }, 0.25) end)
	end
	local count = if small then 8 elseif tier == 2 then 14 elseif tier == 3 then 22 else 30
	AlterFX.UIParticles(fxLayer, fxTheme(rarity), count, 0.1, { burst = true, peak = true, scale = if small then 0.9 else 1.3, x = x, y = y })
	AlterFX.Ring(fxLayer, color, 40, if small then 260 else 420, 0.45, at)
	if tier == 4 then
		dim.BackgroundTransparency = Screen.dim
		tween(spotlight, { ImageTransparency = 0.8 }, 0.6)
		AlterFX.Ring(fxLayer, color, 80, 1000, 0.9 * (if slow then 1.5 else 1), at)
		task.delay(0.12, function() AlterFX.Ring(fxLayer, Color3.new(1, 1, 1), 60, 700, 0.7, at) end)
		screenRays(at, color)
		if not reduced then shakeUI({ card.holder }, 8, 0.3) end
	elseif tier >= 2 and not reduced then
		shakeUI({ card.holder }, if tier == 3 then 6 else 3, 0.2)
	end
	-- the card snaps in: 0 -> 1.15 -> 1
	card.holder.Visible = true
	card.popScale.Scale = 0
	tween(card.popScale, { Scale = 1.15 }, time * 0.55, Enum.EasingStyle.Quad)
	task.delay(time * 0.55, function() tween(card.popScale, { Scale = 1 }, time * 0.45, Enum.EasingStyle.Back) end)
	tween(card.glow, { ImageTransparency = card.glowBase }, time)
	-- the sound
	if tier == 1 then
		Audio.PlayUI("GeneticsPop", { volume = RV.pop })
	elseif tier == 2 then
		Audio.PlayUI("GeneticsPop", { volume = RV.pop })
		sfx("Chime", rarity, RV.chime, { pitch = 1.2 })
	elseif tier == 3 then
		sfx("WarmWhoosh", rarity, RV.whoosh)
		sfx("Chime", rarity, RV.chime, { pitch = 1.1 })
		sfx("ImpactSub", rarity, RV.thump, { maxLength = 1 })
	else
		sfx("ImpactPunch", rarity, RV.impact)
		sfx("FlashBoom", rarity, RV.sub)
		sfx("CosmicSwell", rarity, RV.shine, { delay = 0.1, maxLength = 3 }) -- (the long shine: the one sound past 1.5 s)
		sfx("WarmWhoosh", rarity, RV.whoosh, { pitch = 0.6, delay = 0.15 })
		sfx("TitleHit", rarity, RV.ringBoom, { delay = 0.05 })
		-- the rarity's own extras (prompt 24): Mythic lightning, Eternal stars, Legendary a brass stab
		local theme = fxTheme(rarity)
		if rarity.reveal == "lightning" then
			AlterFX.Sound("Crackle", { delay = 0.2 })
			AlterFX.ScreenFX(fxLayer, { accent = hex(rarity.color2 or rarity.color), particle = theme.particle }, "storm", 1.4)
		elseif rarity.reveal == "cosmic" then
			AlterFX.ScreenFX(fxLayer, { accent = theme.accent, particle = { texture = "spark", color = Color3.new(1, 1, 1), motion = "drift" } }, "legend", 2)
		elseif rarity.reveal == "explosion" then
			sfx("Brass", rarity, 0.6, { delay = 0.2 })
		end
	end
	wait_(time)
end

-- the fanfare after the last card: two notes, or a four-note sting when the batch has Legendary+
local function fanfare(bestRarity)
	local notes = if tierOf(bestRarity) == 4 then { 1, 1.26, 1.5, 2 } else { 1, 1.5 }
	for i, pitch in ipairs(notes) do sfx("Chime", bestRarity, RV.fanfare, { pitch = pitch, delay = (i - 1) * 0.11 }) end
	if #notes == 4 then sfx("Brass", bestRarity, 0.5, { delay = 0.4 }) end
end

------------------------------------------------------------------------
-- The bottom bar: the batch summary, ROLL AGAIN (red, its price) and CLOSE (dark, outlined), TAP TO CONTINUE
------------------------------------------------------------------------
local bar = New("Frame", { Name = "Bar", BackgroundColor3 = Color3.fromHex("#141317"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10),
	Size = UDim2.fromOffset(Screen.barWidth, Screen.barHeight), Visible = false, ZIndex = 40, Parent = barRoot }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.45 }),
})
local summary = Kit.Text({ Name = "Summary", Text = "", Font = "Chunky", TextSize = 18, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -300, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41, Parent = bar })
Kit.Fit(summary, 18, 10)
local continueText = Kit.Text({ Name = "Continue", Text = "TAP TO CONTINUE", Font = "Title", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(14, 31),
	Size = UDim2.new(1, -300, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41, Parent = bar })
local againButton = Theme.Button("Red", { Name = "Again", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -128, 0.5, 0), Size = UDim2.fromOffset(150, 44),
	ZIndex = 41, Parent = bar }, {})
local _againBig, againSmall = twoLines(againButton, "ROLL AGAIN", "", 15)
local closeButton = Kit.Button("Dark", "Close", { Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 41, Parent = bar },
	{ width = 112, height = 44, textSize = 15 })
New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = closeButton })

local function againState(): (boolean, string)
	local count = againCount
	if count > 1 and not multiOpen() then return false, "SPURT " .. Trainers.MultiRollFromSpurt end
	if count == 1 and (state().freeRolls or 0) > 0 then return true, "FREE" end
	local cost = price() * count
	return (data().coins or 0) >= cost, Kit.Format(cost)
end
local function showBar(order)
	local new, dupes = 0, 0
	for _, entry in ipairs(order) do
		if isNewResult(entry.result) then new += 1 else dupes += 1 end
	end
	local parts = {}
	if new > 0 then table.insert(parts, new .. " NEW") end
	if dupes > 0 then table.insert(parts, dupes .. (if dupes == 1 then " DUPE" else " DUPES")) end
	summary.Text = table.concat(parts, " · ")
	local ok, priceText = againState()
	againSmall.Text = priceText
	againSmall.TextColor3 = GOLD
	Theme.SetButtonStyle(againButton, if ok then "Red" else "Disabled")
	bar.Visible = true
	bar.Position = UDim2.new(0.5, 0, 1, 10)
	tween(bar, { Position = UDim2.new(0.5, 0, 1, -(Screen.barHeight + 8)) }, 0.3, Enum.EasingStyle.Back)
	Audio.PlayUI("Whoosh", { volume = RV.swoosh })
	task.spawn(function()
		while bar.Visible do
			tween(continueText, { TextTransparency = 0.6 }, 0.6)
			task.wait(0.6)
			tween(continueText, { TextTransparency = 0 }, 0.6)
			task.wait(0.6)
		end
		continueText.TextTransparency = 0
	end)
end
againButton.Activated:Connect(function()
	if busy or not bar.Visible then return end
	local ok = againState()
	if not ok then
		Audio.PlayUI("Click", { volume = 0.5 })
		return
	end
	Audio.PlayUI("Click")
	Audio.PlayUI("QuestClaim", { volume = 0.8 }) -- (the coin-spend jingle)
	local count = againCount
	closeWanted = true
	task.spawn(function()
		while overlay.Enabled do task.wait() end
		requestRoll(count, false)
	end)
end)
closeButton.Activated:Connect(function()
	if busy then return end
	Audio.PlayUI("Click", { volume = 0.6 })
	closeWanted = true
end)

------------------------------------------------------------------------
-- The whole reveal. results = the server's list; quick = auto roll (the cards snap in and it closes by itself, unless
-- Epic or better came). -> the best rarity index
------------------------------------------------------------------------
local function play(results, quick: boolean)
	busy, skip, closeWanted = true, false, false
	for _, c in ipairs(cards) do c.holder:Destroy() end
	for _, s in ipairs(slots) do s:Destroy() end
	cards, slots = {}, {}
	clearTransient()
	for _, child in ipairs(fxLayer:GetChildren()) do child:Destroy() end
	-- lowest to highest (the best last)
	local order = {}
	for i, result in ipairs(results) do
		local trainer = Trainers.ById[result.id]
		if trainer then table.insert(order, { result = result, trainer = trainer, rarity = rarityOf(trainer), i = i }) end
	end
	table.sort(order, function(a, b) return if a.rarity.index ~= b.rarity.index then a.rarity.index < b.rarity.index else a.i < b.i end)
	if #order == 0 then
		busy = false
		return 0
	end
	local bestRarity = order[#order].rarity
	local fast = quick and bestRarity.index < Trainers.RarityById[Trainers.AutoStopRarity].index
	againCount = #results
	-- the setup: ~90% black, the HUD and the Agency step aside
	overlay.Enabled = true
	bar.Visible = false
	whiteFlash.BackgroundTransparency = 1
	dim.BackgroundTransparency = 1
	spotlight.ImageTransparency = 1
	tween(dim, { BackgroundTransparency = Screen.dim }, RT.setup)
	tween(spotlight, { ImageTransparency = 0.85 }, RT.setup)
	menuWasHidden = SideMenu.IsHidden()
	SideMenu.SetHidden(true)
	if modal.root then modal.root.Visible = false end
	task.wait() -- (the root has its size)
	local slotSize = layout(order)
	for i, entry in ipairs(order) do
		if #order > 1 then dashedSlot(entry.slotPos, slotSize) end
		cards[i] = makeCard(entry, i)
	end
	if fast then
		skip = true
	else
		Audio.Duck(RollReveal.MusicDuck, 0.3)
		wait_(RT.setup)
	end
	-- one card at a time, left to right
	for i, card in ipairs(cards) do
		if skip then break end
		if i > 1 then
			sfx("Riser", nil, RV.riser, { fadeIn = 0.1, maxLength = 0.6 })
			for j = 1, i - 1 do shadeCard(cards[j], 0.2) end
			if not wait_(RT.gapBetweenCards) then break end
		end
		local orb = dropOrb(card)
		if not wait_(RT.orbDrop) then break end
		if not pulses(card, orb) then break end
		clearTransient()
		burst(card, orb)
		if skip then break end
		dress(card, false)
		settle(card)
		if i < #cards then
			if not wait_(RT.dress) then break end
		end
	end
	if skip then
		-- every card not done yet: a quick pop each (one combined pop-pop-pop)
		clearTransient()
		whiteFlash.BackgroundTransparency = 1
		dim.BackgroundTransparency = Screen.dim
		spotlight.ImageTransparency = 0.85
		local n = 0
		for _, card in ipairs(cards) do
			if not card.settled then
				card.holder.Visible = true
				card.popScale.Scale = 0.6
				tween(card.popScale, { Scale = 1 }, RT.skipPop, Enum.EasingStyle.Back)
				card.glow.ImageTransparency = card.glowBase
				dress(card, true)
				settle(card)
				task.delay(n * 0.07, function() Audio.PlayUI("GeneticsPop", { volume = RV.pop }) end)
				n += 1
			end
		end
	end
	-- all bright together (the slots step away)
	for _, card in ipairs(cards) do shadeCard(card, 1) end
	for _, s in ipairs(slots) do
		tween(s, { BackgroundTransparency = 1 }, 0.3)
		for _, dash in ipairs(s:GetChildren()) do
			if dash:IsA("Frame") then tween(dash, { BackgroundTransparency = 1 }, 0.3) end
		end
	end
	skip = false
	if fast then
		busy = false
		local t1 = os.clock()
		while os.clock() - t1 < RT.autoClose and not closeWanted do task.wait() end
		closeWanted = true
	else
		task.wait(RT.beforeBar)
		fanfare(bestRarity)
		showBar(order)
		busy = false
	end
	while not closeWanted do task.wait() end
	-- close
	busy = true
	tween(dim, { BackgroundTransparency = 1 }, 0.2)
	tween(spotlight, { ImageTransparency = 1 }, 0.2)
	if bar.Visible then tween(bar, { Position = UDim2.new(0.5, 0, 1, 10) }, 0.2) end
	for _, card in ipairs(cards) do tween(card.popScale, { Scale = 0.85 }, 0.15) end
	if humSound then AlterFX.FadeOut(humSound, 0.3) humSound = nil end
	Audio.Duck(1, 0.4)
	task.wait(0.2)
	overlay.Enabled = false
	bar.Visible = false
	if holdConnection then holdConnection:Disconnect() holdConnection = nil end
	for _, c in ipairs(cards) do c.holder:Destroy() end
	for _, s in ipairs(slots) do s:Destroy() end
	cards, slots = {}, {}
	clearTransient()
	SideMenu.SetHidden(menuWasHidden)
	if modal.root then modal.root.Visible = true end
	busy = false
	return bestRarity.index
end
tapCatcher.Activated:Connect(function()
	if busy then skip = true else closeWanted = true end
end)

------------------------------------------------------------------------
-- Rolling and Auto Roll
------------------------------------------------------------------------
local waiting = false
local lastBest = 0
local resultSignal = Instance.new("BindableEvent")
function requestRoll(count: number, auto: boolean): boolean
	if waiting or busy or overlay.Enabled then return false end
	local cost = price() * count
	local free = count == 1 and (state().freeRolls or 0) > 0
	if not free and (data().coins or 0) < cost then
		Notify.Toast("Not enough coins", "A roll costs " .. Kit.Format(cost) .. " coins", "coin", Colors.Red, "trainercoins")
		return false
	end
	waiting = true
	remote:FireServer("Roll", count, auto)
	local done = false
	local connection = resultSignal.Event:Connect(function() done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 6 do task.wait() end
	connection:Disconnect()
	waiting = false
	return done
end

function autoLoop()
	while autoOn do
		if (data().coins or 0) < price() and (state().freeRolls or 0) == 0 then
			Notify.Toast("Auto Roll stopped", "Out of coins", "coin", Colors.Red, "trainerauto")
			break
		end
		if not requestRoll(1, true) then break end
		while overlay.Enabled do task.wait() end
		if lastBest >= Trainers.RarityById[Trainers.AutoStopRarity].index then
			Notify.Toast("Auto Roll stopped", "You pulled a " .. Trainers.Rarities[lastBest].name .. "!", "star", hex(Trainers.Rarities[lastBest].color), "trainerauto")
			break
		end
		task.wait(0.15)
	end
	setAuto(false)
end

local function rollOnce()
	Audio.PlayUI("Click")
	task.spawn(requestRoll, 1, false)
end
local function rollThree()
	if not multiOpen() then
		Notify.Toast("Roll x3", "Opens at Growth Spurt " .. Trainers.MultiRollFromSpurt, "lock", Colors.Muted, "trainerx3")
		return
	end
	Audio.PlayUI("Click")
	task.spawn(requestRoll, Trainers.MultiRoll, false)
end
local function toggleAuto()
	Audio.PlayUI("Click")
	setAuto(not autoOn)
	if autoOn then task.spawn(autoLoop) end
end
rollButton.Activated:Connect(rollOnce)
x3Button.Activated:Connect(rollThree)
autoButton.Activated:Connect(toggleAuto)
-- E / R / T while the Agency tab is open (a keyboard; ContextActionService so they win over the world's E prompts)
function bindKeys(on: boolean)
	if on then
		ContextActionService:BindActionAtPriority("AgencyKeys", function(_, inputState, input)
			if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			if input.KeyCode == Enum.KeyCode.E then rollOnce()
			elseif input.KeyCode == Enum.KeyCode.R then rollThree()
			elseif input.KeyCode == Enum.KeyCode.T then toggleAuto() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T)
	else
		ContextActionService:UnbindAction("AgencyKeys")
	end
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function open()
	refresh()
	if modal.isOpen() then return end
	menuButton:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	modal.open()
	Theme.Pulse(rollButton, function() return modal.isOpen() and tab == "Agency" end)
	Audio.PlayUI("Whoosh")
	bindKeys(keyboard and tab == "Agency")
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then
		menuButton:SetActive(false)
		UIBus.MenuPanelVisible:Fire(false)
		bindKeys(false)
		popover.Visible = false
		hideTip()
		myPanel.closeOverlays()
	end
end)
menuButton.Activated:Connect(function()
	-- (prompt 54) the TRAINERS button: MY TRAINERS only (rolling is at the Agency desk)
	if modal.isOpen() then modal.close() else UIBus.PanelOpened("Trainers") showTab("My") open() end
end)
UIBus.RegisterPanel("Trainers", function() modal.close() end)
-- (prompt 54: always MY TRAINERS; the Agency opens only at its desk)
UIBus.OpenAgency.Event:Connect(function(_openTab)
	if UIBus.IsLocked and UIBus.IsLocked("Trainers") then UIBus.ShowLocked("Trainers") return end -- (prompt 39: still locked, GuideClient)
	if not modal.isOpen() then UIBus.PanelOpened("Trainers") end
	showTab("My")
	open()
end)
ClientData.Changed:Connect(function(path)
	if modal.isOpen() and (path[1] == "coins" or path[1] == "trainers" or path[1] == "growthSpurts") then refresh() end
end)
player:GetAttributeChangedSignal("TrainerSlots"):Connect(function() if modal.isOpen() then refresh() end end)

------------------------------------------------------------------------
-- Server events
------------------------------------------------------------------------
-- (owner, prompt 48) the only server-wide message: someone rolled the Secret or Eternal trainer. "Rong rolled ATLAS!
-- (Eternal)" as a chat line in the rarity's color for everyone; for everyone else also a short gold banner at the top
-- (~4 s, under the top bar) and a small sound (the roller has the reveal).
local bannerGui = Theme.ScreenGui({ Name = "RarePullBanner", DisplayOrder = 46, Parent = player:WaitForChild("PlayerGui") })
local bannerRoot = Kit.Root(bannerGui)
local BANNER_Y = 64 -- (mockup px: under the top bar's chips)
local banner = New("Frame", { Name = "Banner", BackgroundColor3 = Color3.fromHex("#141417"), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -10), Size = UDim2.fromOffset(440, 52), Visible = false, Parent = bannerRoot }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#2A2A31"), Color3.fromHex("#0E0E11")) }),
})
local bannerEdge = New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = banner }, {
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#F6C75A")), ColorSequenceKeypoint.new(1, Color3.fromHex("#C98A12")) }) }),
})
local bannerTitle = Kit.Text({ Name = "Title", Text = "", Font = "Chunky", TextSize = 20, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 0, 26),
	Parent = banner })
Kit.Fit(bannerTitle, 20, 12)
Kit.GoldText(bannerTitle)
local bannerSub = Kit.Text({ Name = "Rarity", Text = "", Font = "Chunky", TextSize = 13, Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 16),
	Parent = banner })
local bannerShownAt = 0
local function showBanner(title: string, sub: string, color: Color3)
	bannerTitle.Text = title
	bannerSub.Text = sub
	bannerSub.TextColor3 = color
	bannerEdge.Enabled = true
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -10)
	tween(banner, { Position = UDim2.new(0.5, 0, 0, BANNER_Y + 52) }, 0.35, Enum.EasingStyle.Back)
	bannerShownAt = os.clock()
	local at = bannerShownAt
	task.delay(4, function()
		if bannerShownAt ~= at then return end
		tween(banner, { Position = UDim2.new(0.5, 0, 0, -10) }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.32, function() if bannerShownAt == at then banner.Visible = false end end)
	end)
end

local function announce(info)
	local rarity = Trainers.RarityById[info.rarity]
	local trainer = Trainers.ById[info.trainer]
	if not rarity or not trainer or rarity.announce ~= "banner" then return end
	local mine = info.userId == player.UserId
	local who = if mine then "You" else tostring(info.name)
	local color = hex(if rarity.id == "Secret" then rarity.color2 else rarity.color)
	local text = who .. " rolled " .. string.upper(trainer.name) .. "! (" .. rarity.name .. ")"
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then general:DisplaySystemMessage(string.format('<font color="#%s"><b>%s</b></font>', color:ToHex(), text)) end
	end)
	if mine then return end
	showBanner(who .. " rolled " .. string.upper(trainer.name) .. "!", string.upper(rarity.name) .. " TRAINER", color)
	AlterFX.Sound("Chime", { pitch = 1.15, volume = 0.8 })
	AlterFX.Sound("Sparkle", { delay = 0.08, volume = 0.6 })
end

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" then
		if UIBus.IsLocked and UIBus.IsLocked("Trainers") then UIBus.ShowLocked("Trainers") return end -- (prompt 39: still locked, GuideClient)
		if not modal.isOpen() then UIBus.PanelOpened("Trainers") end
		showTab("Agency") -- (the Agency desk's prompt)
		open()
	elseif kind == "Rolled" then
		resultSignal:Fire()
		local results = type(info.results) == "table" and info.results or {}
		task.spawn(function()
			lastBest = play(results, info.auto == true) or 0
			if modal.isOpen() then refresh() end
		end)
	elseif kind == "Failed" then
		resultSignal:Fire()
		Notify.Toast(tostring(info.text), nil, "coin", Colors.Red, "trainerfail")
		if info.auto then setAuto(false) end
	elseif kind == "Evolved" then
		-- (prompt 33) the evolve moment (MY TRAINERS)
		task.spawn(myPanel.evolved, info)
	elseif kind == "LevelUp" then
		-- (prompt 33) "COACH LOU LV 12!" with a ding, and a quick glow on him
		local trainer = Trainers.ById[info.id]
		if trainer then
			Notify.Reward(string.upper(trainer.name) .. " LV " .. tostring(info.level) .. "!", Trainers.PerkText(trainer, { id = trainer.id, s = info.stage or 1, l = info.level or 1 }),
				"users", Colors.Gold, "QuestClaim", "trainerlevel")
			local folder = workspace:FindFirstChild("LocalTrainers")
			for _, model in ipairs(folder and folder:GetChildren() or {}) do
				if model:IsA("Model") and string.find(model.Name, trainer.id, 1, true) then
					local glow = Instance.new("Highlight")
					glow.FillColor, glow.OutlineColor = Colors.Gold, Color3.new(1, 1, 1)
					glow.FillTransparency, glow.OutlineTransparency = 0.4, 0
					glow.Parent = model
					TweenService:Create(glow, TweenInfo.new(0.9), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
					task.delay(1, function() glow:Destroy() end)
				end
			end
		end
	elseif kind == "Pulled" then
		announce(info)
	end
end)

------------------------------------------------------------------------
-- The signs over the Agency desks (tag AgencyBoard; prompt 28: was a table of names and odds, too much small text): the
-- gold "TRAINER AGENCY" on black and the trainers' pictures in a row in their rarity color (the Secret one a black
-- silhouette until you own him). The odds stay in the Agency window.
------------------------------------------------------------------------
local boards = {}
local function fillBoard(part: BasePart)
	local gui = part:FindFirstChild("AgencyGui") or Instance.new("SurfaceGui")
	gui.Name = "AgencyGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui:ClearAllChildren()
	gui.Parent = part
	local root = New("Frame", { BackgroundColor3 = Color3.fromHex("#0E0E11"), Size = UDim2.fromScale(1, 1), Parent = gui }, {
		New("UIPadding", { PaddingTop = UDim.new(0.06, 0), PaddingBottom = UDim.new(0.08, 0), PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0) }),
	})
	local title = New("TextLabel", { BackgroundTransparency = 1, Text = "TRAINER AGENCY", FontFace = LUCKIEST, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 0.34), Parent = root })
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#F6C75A")), ColorSequenceKeypoint.new(1, Color3.fromHex("#C98A12")),
	}), Parent = title })
	New("Frame", { BackgroundColor3 = Color3.fromHex("#C98A12"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.39),
		Size = UDim2.fromScale(0.6, 0.012), Parent = root })
	local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.47), Size = UDim2.fromScale(1, 0.53), Parent = root }, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local size = 1 / #Trainers.List - 0.014
	for order, trainer in ipairs(Trainers.List) do
		local rarity = rarityOf(trainer)
		local hidden = rarity.hidden and not ownsAny(trainer.id)
		local frame = New("Frame", { LayoutOrder = order, BackgroundColor3 = Color3.fromHex("#1F1F25"), Size = UDim2.fromScale(size, 1), Parent = row }, {
			New("UIAspectRatioConstraint", { AspectRatio = 1 }),
			New("UICorner", { CornerRadius = UDim.new(0.14, 0) }),
			New("UIStroke", { Color = if rarity.hidden then hex(rarity.color2) else hex(rarity.color), Thickness = 3 }),
		})
		-- (prompt 25) his icon (the Secret one a black "???" silhouette until you own him)
		-- (owner, 22 Oct: no pictures) his 3D rig, black until you own the Secret one
		TrainerPortrait.Icon(trainer.id, { Size = UDim2.fromScale(1, 1), Parent = frame, silhouette = hidden })
	end
end
local function addBoard(part)
	if not part:IsA("BasePart") or boards[part] then return end
	boards[part] = true
	fillBoard(part)
end
task.spawn(function()
	ClientData.Get()
	for _, part in ipairs(CollectionService:GetTagged("AgencyBoard")) do addBoard(part) end
	CollectionService:GetInstanceAddedSignal("AgencyBoard"):Connect(addBoard)
	-- (owning the Secret one reveals him on the boards)
	local secretShown = nil
	ClientData.Changed:Connect(function(path)
		if path[1] ~= "trainers" then return end
		local now = ownsAny(Trainers.ByRarity.Secret.id)
		if now ~= secretShown then
			secretShown = now
			for part in pairs(boards) do if part.Parent then fillBoard(part) end end
		end
	end)
end)

-- (owner, prompt 27c) the trainer boosts were rebalanced (lowered): a player who already owned trainers sees this once,
-- after the menu, with the gift (TrainerService gives it at join; state.rebalance 1 = given, not seen yet)
do
	local shown = false
	local function check()
		if shown or not ClientData.IsLoaded() or state().rebalance ~= 1 then return end
		shown = true
		task.spawn(function()
			UIBus.WaitForMenu()
			local gift = Trainers.RebalanceGift
			Notify.Reward("TRAINER BOOSTS WERE REBALANCED", "A gift for you: +" .. Kit.Format(gift.coins) .. " coins and " .. gift.rolls .. " free roll",
				"gift", Colors.Gold, "TitleUnlocked", "trainerrebalance")
			remote:FireServer("SeenRebalance")
		end)
	end
	ClientData.Changed:Connect(function(path)
		if path[1] == "trainers" then check() end
	end)
	task.spawn(function()
		ClientData.Get()
		check()
	end)
end
