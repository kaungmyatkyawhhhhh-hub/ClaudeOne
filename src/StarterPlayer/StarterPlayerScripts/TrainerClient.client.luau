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
--   * (owner, prompt 48; 23 Oct) Only a roll of The Shadow (Mythic) or Atlas (Secret) is told to the whole server: a short gold banner at the top (~4 s),
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
-- silhouette with a rim on a bright burst until you own him; the Secret one, Atlas, "???" too), the rarity name in its color,
-- the chance as a percentage; "x2" bottom-right; owner, 23 Oct: no check, his art says he's owned). A tap (or hover) shows his name and boost.
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
		-- (owner, 23 Oct: each trainer's own chance; Legendary has two)
		slot.tile:Set({ id = id, rarity = true, silhouette = not owned, owned = owned, caption = Trainers.ChanceText(slot.trainer.chance or rarity.chance) })
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
-- (prompt 61) TRAINER SNACKS: a SNACKS button in the row opens a small popover (upward) with the three snacks: what each
-- gives, its price at your stage, how many you have; BUY one. Feed them from MY TRAINERS (FEED). (one do-block: this
-- script is near Luau's local limit)
do
	local Style = require(Shared.Config.Style)
	local snackButton = flatButton("Snacks", 70, 6)
	local _snackBig, snackSmall = twoLines(snackButton, "SNACKS", "", 15)
	local pop = New("Frame", { Name = "Snacks", BackgroundColor3 = Color3.fromHex("#0E0E11"), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, 28),
		Size = UDim2.fromOffset(330, 92), Visible = false, ZIndex = 15, Parent = controls }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 1.5 }),
	})
	Kit.Text({ Name = "Title", Text = "TRAINER SNACKS", Font = "Title", TextSize = 11, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = pop })
	Kit.Text({ Name = "Hint", Text = "Trainer EXP. Feed them in MY TRAINERS.", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(10, 20),
		Size = UDim2.new(1, -20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = pop })
	local labels = {}
	for i, snack in ipairs(Style.Snacks) do
		local b = New("TextButton", { Name = snack.id, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#1A191E"),
			Position = UDim2.fromOffset(10 + (i - 1) * 104, 38), Size = UDim2.fromOffset(98, 46), ZIndex = 16, Parent = pop }, {
			New("UICorner", { CornerRadius = UDim.new(0, 8) }),
			New("UIStroke", { Color = hex(snack.color), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local top = Kit.Text({ Name = "Name", Text = string.upper(snack.id) .. " +" .. snack.xp .. " EXP", Font = "Chunky", TextSize = 11, Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 14), ZIndex = 17, Parent = b })
		local bottom = Kit.Text({ Name = "Price", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Colors.Gold, Position = UDim2.fromOffset(4, 22),
			Size = UDim2.new(1, -8, 0, 18), ZIndex = 17, Parent = b })
		labels[snack.id] = { top = top, bottom = bottom }
		b.Activated:Connect(function()
			Audio.PlayUI("Click")
			remote:FireServer("BuySnack", snack.id)
		end)
	end
	local function paint()
		local d = data()
		local snacks = type(d.snacks) == "table" and d.snacks or {}
		local total = 0
		for _, snack in ipairs(Style.Snacks) do
			local have = tonumber(snacks[snack.id]) or 0
			total += have
			labels[snack.id].bottom.Text = Kit.Format(Style.SnackPrice(snack, d.growthSpurts)) .. " · YOU HAVE " .. have
		end
		snackSmall.Text = if total > 0 then "x" .. total else ""
	end
	snackButton.Activated:Connect(function()
		Audio.PlayUI("Click")
		paint()
		pop.Visible = not pop.Visible
	end)
	ClientData.Changed:Connect(function(path)
		if path[1] == "snacks" or path[1] == "growthSpurts" then paint() end
	end)
	remote.OnClientEvent:Connect(function(kind, info)
		info = type(info) == "table" and info or {}
		if kind == "SnackBought" then
			Audio.PlayUI("ShopBuy")
		elseif kind == "Fed" then
			local levels = tonumber(info.levels) or 0
			Notify.Reward("SNACK TIME!", if levels > 0 then "+" .. levels .. " LV · now LV " .. tostring(info.level) else "Trainer EXP added", "star", Colors.Gold, "QuestClaim", "trainerfed")
		end
	end)
	task.spawn(function()
		ClientData.Get()
		paint()
	end)
end

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
--   * (prompt 55, 23 Oct; it replaces prompt 49's orb, pulses and spinning sunburst) The background: the world stays
--     visible but dark (a vignette, blur, a haze in the rarity colour from the bottom, a few slow particles drifting up).
--   * Per card: the ROLLER, trainer names flicking past in their rarity colours (fast, then slowing like a slot machine,
--     a tick each, the last few hovering on rarer ones) lands on the result (a pop 1.2 -> 1 and its sound; the Secret
--     one stops dead on "???") -> Legendary+: the CINEMATIC in the world (Shared/VFX/RollCinematic; nearby players see
--     the beam and the shockwave) -> the card slides up into place -> the dress (pill, name slam, boost, NEW!, dupe bar; a
--     shimmer over Legendary+ names) -> the hold (it floats, the glow breathes, a quiet hum).
--   * Batch: dashed dark slots in a row, revealed lowest to highest; the revealed ones dim to 80% while the next plays,
--     then all brighten. Then a 0.4 s beat, a fanfare and the bar slides up: "1 NEW · 2 DUPES", ROLL AGAIN (red, its
--     price) and CLOSE; TAP TO CONTINUE pulses.
--   * A tap during a reveal finishes every card at once (a quick pop each) and shows the bar; the next tap closes. A
--     player's first-ever Mythic / Secret can't be skipped for its first 2 s.
--   * Auto Roll: the fast roller (0.6 s) and it closes by itself, unless Legendary or better (the full reveal and the
--     cinematic; auto roll stops).
--   * Reduced Motion: no shakes, no camera orbit, no flicker; fades instead.
--   * (prompt 56, 23 Oct) The card comes alive: no sunburst; each trainer's own animated background (Volta a storm, Duke a
--     forge, The Shadow smoke and eyes, Atlas clouds, beams and a laurel; Common-Epic the hex in the rarity colour) and a
--     faint version on the screen behind (Shared/UI/RollCardFX); the art breathes; ReadyGlow's soft glow and travelling
--     highlight on the outline; it floats and leans toward the mouse / finger; Legendary+ lets particles escape its
--     edges. The rarity pill glows, the NAME is bigger with a shimmer, the boosts are stat rows (icon + "+35% EXP")
--     popping in with a tick, NEW! stamps in with a bounce, a dupe's bar fills. The bar: "1 NEW" as a sticker, TAP TO
--     CONTINUE pulsing, ROLL AGAIN with a coin and a soft red glow; it slides up after the stat rows.
------------------------------------------------------------------------
local RunService = game:GetService("RunService")
local RollReveal = require(Shared.Config.RollReveal)
local RollCardFX = require(Shared.UI.RollCardFX)
local ReadyGlow = require(Shared.UI.ReadyGlow)
local UIConfig = require(Shared.Config.UI)
local UserInputService = game:GetService("UserInputService")
local RR, RT, RV, Screen = RollReveal.Card, RollReveal.Time, RollReveal.Volume, RollReveal.Screen
-- (prompt 56) the boosts' rows, as in MY TRAINERS: an icon in a colored badge and "+35% EXP" in that color
local STAT = { gains = { "zap", hex("#5AA8FF"), "EXP" }, coins = { "coin", hex("#F6C75A"), "COINS" }, progress = { "arrow-big-up", hex("#5CE07A"), "PROGRESS" },
	maxStamina = { "heart-pulse", hex("#FF6A7A"), "MAX STAMINA" }, staminaRegen = { "heart-pulse", hex("#36C2C2"), "STAMINA REGEN" } }
local function statsHeight(trainer): number
	local n = math.max(1, #Trainers.PerkLines(trainer))
	return n * RR.stat + (n - 1) * RR.statGap + 2 * RR.statPad
end

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
local holdConnection = nil
local humSound = nil
local menuWasHidden = false
local againCount = 1
local skipLockUntil = 0 -- (prompt 55) a tap can't skip before this
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
-- (prompt 55) the calm background: the world dark but visible (a black wash, a vignette, blur), a haze in the rarity
-- colour from the bottom and a few slow particles drifting up. Made at the start of a reveal, gone at the close.
local BG = RollReveal.Background
local background = nil
local screenTheme = nil -- (prompt 56) the card's theme, faint, on the screen behind (setScreenTheme, below)
local function removeBackground()
	if screenTheme then screenTheme:Destroy() screenTheme = nil end
	if not background then return end
	background.connection:Disconnect()
	background.layer:Destroy()
	local blur = background.blur
	tween(blur, { Size = 0 }, 0.2)
	task.delay(0.25, function() blur:Destroy() end)
	background = nil
end
local function makeBackground()
	removeBackground() -- (never two at once)
	for _, old in ipairs(game:GetService("Lighting"):GetChildren()) do
		if old.Name == "RollBlur" then old:Destroy() end
	end
	local layer = New("Frame", { Name = "Background", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = overlay })
	for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
		local vertical = side == "Top" or side == "Bottom"
		New("Frame", { Name = "Vignette" .. side, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
			Position = UDim2.fromScale(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
			Size = if vertical then UDim2.fromScale(1, BG.vignette) else UDim2.fromScale(BG.vignette, 1), ZIndex = 1, Parent = layer }, {
			New("UIGradient", { Rotation = ({ Top = 90, Bottom = 270, Left = 0, Right = 180 })[side], Transparency = NumberSequence.new(0.05, 1) }),
		})
	end
	local haze = New("Frame", { Name = "Haze", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, BG.hazeHeight), BackgroundTransparency = 1, ZIndex = 1, Parent = layer }, {
		New("UIGradient", { Rotation = 270, Transparency = NumberSequence.new(BG.haze, 1) }),
	})
	local dots = {}
	for i = 1, BG.particles do
		local dot = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(math.random(3, 6), math.random(3, 6)),
			BackgroundTransparency = 1, ZIndex = 1, Parent = layer }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		dots[i] = { f = dot, x = math.random(), speed = 0.04 + math.random() * 0.05, phase = math.random() }
	end
	local blur = New("BlurEffect", { Name = "RollBlur", Size = 0, Parent = game:GetService("Lighting") })
	tween(blur, { Size = BG.blur }, RT.setup)
	local t0 = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		for _, d in ipairs(dots) do
			local k = (t * d.speed + d.phase) % 1
			d.f.Position = UDim2.fromScale(d.x + 0.015 * math.sin(t * 0.8 + d.phase * 9), 1.02 - k * 0.75)
			d.f.BackgroundTransparency = 0.35 + 0.65 * k
		end
	end)
	background = { layer = layer, haze = haze, dots = dots, blur = blur, connection = connection }
end
-- the haze and the particles take the rarity's colour
local function backgroundColor(color: Color3)
	if not background then return end
	background.haze.BackgroundTransparency = 0
	tween(background.haze, { BackgroundColor3 = color }, 0.4)
	for _, d in ipairs(background.dots) do tween(d.f, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3) }, 0.4) end
end

------------------------------------------------------------------------
-- Layout: every card fits between the top bar and the bottom bar (one shared scale for the batch)
------------------------------------------------------------------------
-- the dupe line's height under the stats (none for a new one)
local function dupeHeight(result): number
	if result.deleted then return 4 + RR.dupe end
	if not isNewResult(result) then return 4 + RR.dupe + 3 + RR.dupeBar end
	return 0
end
-- (prompt 57) a card's shape (mockup px, before its scale). Stacked (desktop): the picture on top, the rarity, NAME, stat
-- rows and dupe line under it. Side (phones, when stacked would be under ~90%): the picture on the left, the rest in a
-- column on the right, so the card is wide and short. art* = the picture's box (x / width as shares of the card), col* =
-- the text column (px), infoTop = where its first row starts.
local RS = RollReveal.Side
local function shapeOf(entry, side: boolean, sideWidth: number?)
	local trainer, result = entry.trainer, entry.result
	local statsH = statsHeight(trainer)
	if not side then
		local h = RR.pad + RR.art + RR.pill + 2 + RR.name + 2 + statsH + dupeHeight(result) + RR.bottom
		return { side = false, w = RR.width, h = h, artX = 0.5, artW = RR.artWidth, artTop = RR.pad, artH = RR.art, colX = 0, colW = RR.width,
			infoTop = RR.pad + RR.art, name = RR.name, pill = 0.62, stats = 0.86, dupe = 0.9 }
	end
	local w = sideWidth or RS.width
	local artCol = math.floor(w * RS.artShare)
	local infoH = RR.pill + RS.gap + RS.name + RS.gap + statsH + dupeHeight(result)
	local h = math.max(RS.artMin + 2 * RR.pad, infoH + 2 * RR.pad)
	return { side = true, w = w, h = h, artX = artCol / 2 / w, artW = artCol * 1.08 / w, artTop = RR.pad, artH = h - 2 * RR.pad, colX = artCol,
		colW = w - artCol - RR.pad, infoTop = math.floor((h - infoH) / 2), name = RS.name, pill = 0.72, stats = 1, dupe = 1 }
end
-- sets entry.shape / entry.pos / entry.scale / entry.bubble; -> the slot size
local function layout(order): Vector2
	local uiScale = rollRoot:FindFirstChildOfClass("UIScale")
	local s = math.max(if uiScale then uiScale.Scale else Kit.Scale(), 0.01)
	local units = rollRoot.AbsoluteSize / s
	-- (never under Roblox's top bar: its height + 8)
	local top = math.max(Screen.top, game:GetService("GuiService"):GetGuiInset().Y / s + Kit.TopbarGap)
	local availH = units.Y - top - Screen.bottom
	local availW = units.X - 32
	local gaps = Screen.gap * (#order - 1)
	-- the scale every card gets in one shape (shapes set on the entries)
	local function fitFor(side: boolean, sideWidth: number?): number
		local tallest, totalW = 0, gaps
		for _, entry in ipairs(order) do
			local r = RollReveal.RarityScale[entry.rarity.id] or 1
			entry.shape = shapeOf(entry, side, sideWidth)
			tallest = math.max(tallest, entry.shape.h * r + (RollReveal.RarityLift[entry.rarity.id] or 0))
			totalW += entry.shape.w * r
		end
		return math.min(1.15, availH / tallest, availW / totalW)
	end
	local fit = fitFor(false)
	-- (prompt 57) stacked would be small (phones): the side shape, as wide as the row allows, when it comes out bigger
	if fit < RS.threshold then
		local shares = 0
		for _, entry in ipairs(order) do shares += RollReveal.RarityScale[entry.rarity.id] or 1 end
		local sideWidth = math.clamp((availW - gaps) / shares, RS.minWidth, RS.width)
		local sideFit = fitFor(true, sideWidth)
		if sideFit > fit then fit = sideFit else fit = fitFor(false) end
	end
	local tallest, totalW = 0, gaps
	for _, entry in ipairs(order) do
		local r = RollReveal.RarityScale[entry.rarity.id] or 1
		tallest = math.max(tallest, entry.shape.h * r + (RollReveal.RarityLift[entry.rarity.id] or 0))
		totalW += entry.shape.w * r
	end
	-- one card: the speech bubble above it when there's room (not on phones)
	local bubble = #order == 1 and availH - tallest * fit >= Screen.bubbleRoom
	local centerY = top + availH / 2 + (if bubble then Screen.bubbleRoom / 2 else 0)
	local x = -totalW * fit / 2
	for _, entry in ipairs(order) do
		local r = RollReveal.RarityScale[entry.rarity.id] or 1
		local w = entry.shape.w * r * fit
		entry.x = x + w / 2
		x += w + Screen.gap * fit
		entry.scale = r * fit
		entry.slotPos = UDim2.new(0.5, entry.x, 0, centerY)
		entry.pos = UDim2.new(0.5, entry.x, 0, centerY - (RollReveal.RarityLift[entry.rarity.id] or 0) * fit)
		entry.bubble = bubble
	end
	local tallestSlot = 0
	for _, entry in ipairs(order) do tallestSlot = math.max(tallestSlot, entry.shape.h) end
	return Vector2.new(order[1].shape.w * fit, tallestSlot * fit)
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
	local edge = fxColor(rarity)
	local tier = tierOf(rarity)
	-- (prompt 56) his theme: the card's background, its glow and highlight, the screen behind (Shared/UI/RollCardFX)
	local theme = RollCardFX.ThemeFor(trainer, rarity)
	local themeColor = hex(theme.color)
	-- (prompt 57) its shape (stacked, or side on phones: layout) and the text floor: no word smaller than the HUD's
	-- smallest label once the card's scale is applied
	local g = entry.shape or shapeOf(entry, false)
	local h = g.h
	local minText = math.ceil(Theme.TextSize.Label / math.max(entry.scale or 1, 0.1))
	local function textSize(base: number): number return math.max(base, minText) end
	local cx = g.colX + g.colW / 2 -- (the text column's middle)
	local function colPos(y: number): UDim2 return UDim2.new(0, cx, 0, y) end
	local holder = New("Frame", { Name = "Card" .. index, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = entry.pos,
		Size = UDim2.fromOffset(g.w, h), Visible = false, ZIndex = 5, Parent = rollRoot })
	New("UIScale", { Scale = entry.scale, Parent = holder })
	-- (the pop scales from the middle)
	local pop = New("Frame", { Name = "Pop", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	local popScale = New("UIScale", { Parent = pop })
	local card = New("Frame", { Name = "Card", BackgroundColor3 = Color3.fromHex("#141317"), Size = UDim2.fromScale(1, 1), ZIndex = 5, ClipsDescendants = true,
		Parent = pop }, { New("UICorner", { CornerRadius = UDim.new(0, RR.corner) }) })
	local cardEdge = New("UIStroke", { Color = themeColor, Thickness = RR.outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	-- (prompt 56) the evolve button's glow (Shared/UI/ReadyGlow): a soft glow in the theme colour past the edge and a
	-- bright highlight travelling round the outline; on when the card comes in
	local glow = ReadyGlow.New(card, { stroke = cardEdge, pad = if tier == 4 then 30 else 22 })
	New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(RR.hexTile.X, RR.hexTile.Y), ImageColor3 = edge:Lerp(Color3.new(1, 1, 1), 0.35), ImageTransparency = RR.hexTransparency,
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(0, RR.corner) }) })
	-- (owner, 23 Oct) the rays and the burst are bigger than the card: they sit in a frame inset by ~0.3 of the corner
	-- radius (ClipsDescendants clips square), so no square corner shows past the rounded edge
	local cardInset = math.ceil(RR.corner * 0.3)
	local cardClip = New("Frame", { Name = "Clip", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(cardInset, cardInset),
		Size = UDim2.new(1, -2 * cardInset, 1, -2 * cardInset), ZIndex = 5, Parent = card })
	-- (prompt 56: no more sunburst) his art (it breathes) on his theme's animated background (Shared/UI/RollCardFX)
	local art = TrainerPortrait.Art(trainer.id, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(g.artX, 0, 0, g.artTop), Size = UDim2.new(g.artW, 0, 0, g.artH),
		ZIndex = 6, Parent = card })
	if g.side and art:IsA("ImageLabel") then
		-- (the picture's faint backdrop would end in a hard edge inside the card: it fades out on the right)
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1) }), Parent = art })
	end
	local fx = RollCardFX.Card({ card = card, clip = cardClip, pop = pop, art = art, size = Vector2.new(g.w, h), artTop = g.artTop, artHeight = g.artH,
		artWidth = g.artW, artX = g.artX, theme = theme, escape = tier == 4 })
	local y = g.infoTop
	-- the rarity pill: near black, the rarity name in its color
	local pillPos = colPos(y)
	local pill = New("Frame", { Name = "Rarity", BackgroundColor3 = Color3.fromHex("#0B0A0D"), AnchorPoint = Vector2.new(0.5, 0), Position = pillPos,
		Size = UDim2.fromOffset(g.colW * g.pill, RR.pill), ZIndex = 7, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local pillEdge = New("UIStroke", { Color = edge, Thickness = 1.5, Parent = pill })
	-- (prompt 56) the pill glows in its colour (a soft glow just behind it, breathing in the hold)
	local pillGlow = New("ImageLabel", { Name = "RarityGlow", BackgroundTransparency = 1, Image = UIConfig.SoftGlow, ImageColor3 = edge, ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = colPos(y + RR.pill / 2), Size = UDim2.fromOffset(g.colW * g.pill + 46, RR.pill + 30), ZIndex = 6, Parent = card })
	local pillText = Kit.Text({ Name = "Text", Text = string.upper(rarity.name), Font = "Chunky", TextSize = textSize(RR.textSizes.pill), TextColor3 = edge,
		Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = pill })
	strokeOf(pillText).Color = INK
	y += RR.pill + (if g.side then RS.gap else 2)
	-- the NAME: white chunky with a dark stroke (on the pop, so the slam isn't clipped)
	local nameLabel = New("TextLabel", { Name = "Name", BackgroundTransparency = 1, Text = string.upper(trainer.name), FontFace = LUCKIEST, TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = colPos(y + g.name / 2), Size = UDim2.fromOffset(g.colW - 12, g.name),
		ZIndex = 9, Parent = pop })
	local nameStroke = New("UIStroke", { Thickness = 3, Color = INK, Parent = nameLabel })
	local nameScale = New("UIScale", { Parent = nameLabel })
	-- (prompt 56) every name: a shimmer sweeps across once (gold on Legendary+, his theme colour below)
	local band = if tier == 4 then GOLD else themeColor:Lerp(Color3.new(1, 1, 1), 0.35)
	local shimmer = New("UIGradient", { Name = "Shimmer", Offset = Vector2.new(-1.2, 0), Rotation = 20, Parent = nameLabel,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, band), ColorSequenceKeypoint.new(0.58, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }) })
	y += g.name + (if g.side then RS.gap else 2)
	-- (prompt 56) his boosts: one row per stat (an icon in a colored badge, "+35% EXP" in that color) in a dark box
	local statsH = statsHeight(trainer)
	local statBox = New("Frame", { Name = "Boosts", BackgroundColor3 = Color3.fromHex("#0B0A0D"), BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0),
		Position = colPos(y), Size = UDim2.fromOffset(g.colW * g.stats, statsH), ZIndex = 7, Parent = card }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = Color3.fromHex("#2E2B33"), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local statRows = {}
	for i, line in ipairs(Trainers.PerkLines(trainer)) do
		local look = STAT[line.kind] or STAT.gains
		local row = New("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(8, RR.statPad + (i - 1) * (RR.stat + RR.statGap)),
			Size = UDim2.new(1, -16, 0, RR.stat), Visible = false, ZIndex = 8, Parent = statBox })
		local rowScale = New("UIScale", { Parent = row })
		local badge = New("Frame", { Name = "Badge", BackgroundColor3 = look[2], AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(RR.stat - 3, RR.stat - 3), ZIndex = 8, Parent = row }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = INK, Thickness = 1.2 }),
		})
		local icon = Pieces.Icon(look[1], INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68), ZIndex = 9,
			Parent = badge })
		icon:SetAttribute("KeepColor", true)
		local text = Kit.Text({ Name = "Text", Text = "+" .. line.pct .. "% " .. look[3], Font = "Chunky", TextSize = textSize(RR.textSizes.stat), TextColor3 = look[2],
			Position = UDim2.fromOffset(RR.stat + 3, 0), Size = UDim2.new(1, -(RR.stat + 3), 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = row })
		Kit.Fit(text, textSize(RR.textSizes.stat), minText)
		strokeOf(text).Color = INK
		statRows[i] = { row = row, scale = rowScale }
	end
	y += statsH
	-- a dupe: "X2 · 2/3 TO IRON-BORN" in a small pill with a bar under it (the next evolution, always its real name)
	local dupePill, setDupe, dupeShare, dupeFill = nil, nil, 0, nil
	if result.deleted or not isNewResult(result) then
		local text
		if result.deleted then
			text = "DUPLICATE: +" .. Kit.Format(math.floor(price() * Trainers.AutoDeleteRefund)) .. " COINS"
		else
			local need = Trainers.EvolveCount
			local count = math.max(1, result.count or 1)
			-- (prompt 64: a console gift can be any stage; rolls are BASE)
			local stage = math.clamp(math.floor(tonumber(result.stage) or 1), 1, #Trainers.Stages)
			local nextStage = Trainers.Stages[stage + 1]
			local nextName = nextStage and nextStage.name
			dupeShare = if nextName then math.min(count, need) / need else 1
			-- (prompt 57: the ready line is shorter, so it fits at the text floor)
			text = if not nextName then "X" .. count .. " · " .. Trainers.Stages[stage].name
				elseif count >= need then "X" .. count .. " · READY: " .. nextName else "X" .. count .. " · " .. count .. "/" .. need .. " TO " .. nextName
		end
		dupePill = New("Frame", { Name = "Dupe", BackgroundColor3 = Color3.fromHex("#0B0A0D"), AnchorPoint = Vector2.new(0.5, 0), Position = colPos(y + 4),
			Size = UDim2.fromOffset(g.colW * g.dupe, RR.dupe), ZIndex = 7, Parent = card }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = if result.deleted then Colors.Muted else GOLD, Thickness = 1, Transparency = 0.3 }),
		})
		local t = Kit.Text({ Name = "Text", Text = text, Font = "Chunky", TextSize = textSize(RR.textSizes.dupe), TextColor3 = if result.deleted then Colors.Muted else GOLD,
			Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = dupePill })
		Kit.Fit(t, textSize(RR.textSizes.dupe), minText)
		if not result.deleted then
			local _bar
			_bar, setDupe, dupeFill = Kit.Bar(GOLD, { AnchorPoint = Vector2.new(0.5, 0), Position = colPos(y + 4 + RR.dupe + 3), Size = UDim2.fromOffset(g.colW * 0.6, RR.dupeBar),
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
		local t = Kit.Text({ Name = "Text", Text = "NEW!", Font = "Chunky", TextSize = textSize(RR.textSizes.sticker), TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1),
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
	statBox.BackgroundTransparency = 1
	if dupePill then dupePill.Visible = false end
	return { entry = entry, holder = holder, pop = pop, popScale = popScale, glow = glow, card = card, pill = pill, pillPos = pillPos, pillEdge = pillEdge,
		pillText = pillText, pillGlow = pillGlow, name = nameLabel, nameStroke = nameStroke, nameScale = nameScale, shimmer = shimmer, statBox = statBox, statRows = statRows,
		dupePill = dupePill, setDupe = setDupe, dupeFill = dupeFill, dupeShare = dupeShare, sticker = sticker, shade = shade, bubble = bubble, rarity = rarity,
		trainer = trainer, tier = tier, pos = entry.pos, fx = fx, theme = theme, themeColor = themeColor, tiltX = 0, tiltY = 0 }
end

-- the rows come in top to bottom (instant = all at once: a skip; quick = Auto Roll, at 40% of the time). -> how long it takes
-- (prompt 56) pill (its glow on), the NAME slams in and a shimmer sweeps across it once, the NEW! sticker stamps in with a
-- bounce, the stat rows pop in one by one with a tick each, then a dupe's bar fills
local function dress(card, instant: boolean, quick: boolean?): number
	if card.dressed then return 0 end
	card.dressed = true
	card.dressedAt = os.clock()
	local rarity = card.rarity
	local k = if quick then 0.4 else 1
	local function pillIn(t)
		tween(card.pill, { Position = card.pillPos, BackgroundTransparency = 0 }, t, Enum.EasingStyle.Back)
		tween(card.pillEdge, { Transparency = 0 }, t)
		textAlpha(card.pillText, 0, t)
	end
	local function rowIn(row, t)
		row.row.Visible = true
		if t <= 0 then
			row.scale.Scale = 1
			return
		end
		row.scale.Scale = 0.3
		tween(row.scale, { Scale = 1 }, t, Enum.EasingStyle.Back)
	end
	local function dupeIn(t)
		if card.dupePill then card.dupePill.Visible = true end
		if not card.setDupe then return end
		card.setDupe(card.dupeShare)
		if t > 0 and card.dupeFill and card.dupeShare > 0 then
			card.dupeFill.Size = UDim2.new(0, 0, 1, 0)
			tween(card.dupeFill, { Size = UDim2.new(card.dupeShare, 0, 1, 0) }, t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		end
	end
	if instant then
		card.dressedAt = os.clock() - 1
		pillIn(0.05)
		card.name.Visible = true
		card.nameScale.Scale = 1
		card.statBox.BackgroundTransparency = 0.25
		for _, row in ipairs(card.statRows) do rowIn(row, 0) end
		if card.sticker then card.sticker.Visible = true end
		dupeIn(0)
		return 0
	end
	pillIn(0.18 * k)
	Audio.PlayUI("Click", { volume = RV.pillClick })
	task.delay(RT.nameAt * k, function()
		-- the name slams in with a stroke flash, then the shimmer sweeps across once
		card.name.Visible = true
		card.nameScale.Scale = 1.3
		card.nameStroke.Color = Color3.new(1, 1, 1)
		tween(card.nameScale, { Scale = 1 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.14, function() tween(card.nameStroke, { Color = INK }, 0.2) end)
		sfx("Stamp", rarity, RV.nameStamp, { pitch = 0.9 + rarity.index * 0.05 })
		task.delay(0.2, function() tween(card.shimmer, { Offset = Vector2.new(1.2, 0) }, 0.7, Enum.EasingStyle.Sine) end)
	end)
	task.delay(RT.stickerAt * k, function()
		if not card.sticker then return end
		-- NEW! stamps in: from nothing, overshooting, a little bounce back
		local scale = card.sticker:FindFirstChildOfClass("UIScale")
		card.sticker.Visible = true
		card.sticker.Rotation = -40
		scale.Scale = 0
		tween(scale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
		tween(card.sticker, { Rotation = -12 }, 0.4, Enum.EasingStyle.Back)
		task.delay(0.08, function() sfx("Stamp", rarity, RV.sticker, { pitch = 0.75 }) end)
	end)
	local rowsAt = RT.rowsAt * k
	task.delay(math.max(0, rowsAt - 0.1), function() tween(card.statBox, { BackgroundTransparency = 0.25 }, 0.2) end)
	for i, row in ipairs(card.statRows) do
		task.delay(rowsAt + (i - 1) * RT.rowStagger * k, function()
			rowIn(row, 0.22)
			Audio.PlayUI("Click", { volume = RV.rowTick, pitch = 1.05 + i * 0.12 })
		end)
	end
	local rowsEnd = rowsAt + #card.statRows * RT.rowStagger * k
	if not card.dupePill then return rowsEnd end
	task.delay(rowsEnd, function()
		dupeIn(RT.dupeFill * k)
		if card.setDupe then
			for i = 1, 3 do task.delay((i - 1) * 0.12 * k, function() Audio.PlayUI("Click", { volume = RV.barTick, pitch = 1.2 + i * 0.1 }) end) end
		end
	end)
	return rowsEnd + RT.dupeFill * k
end

-- (prompt 56) the screen behind takes the theme of the card that came in last (a batch: the best), faintly
-- (Shared/UI/RollCardFX: Volta's lightning lights up the dark world, The Shadow's smoke ...)
local function setScreenTheme(theme)
	if not background then return end
	if screenTheme then screenTheme:Destroy() end
	screenTheme = RollCardFX.Screen(background.layer, theme, { flash = function(light: number)
		dim.BackgroundTransparency = BG.dim + (1 - BG.dim) * 0.4 * light
	end })
	backgroundColor(hex(theme.color))
end

-- the hold: every revealed card floats (+-4 px, 2 s); (prompt 56) it leans a little toward the mouse / finger (a slow
-- sway when there's none: phones), its theme moves, the pill's glow breathes, the screen's theme moves. Reduced Motion:
-- no lean, no sway.
local pointer, pointerAt = nil, 0
local pointerConnections = {}
local function trackPointer(input: InputObject)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
		-- (input positions start under the top bar; the reveal's gui ignores it)
		pointer, pointerAt = Vector2.new(input.Position.X, input.Position.Y + game:GetService("GuiService"):GetGuiInset().Y), os.clock()
	end
end
local function stopHold()
	if holdConnection then holdConnection:Disconnect() holdConnection = nil end
	for _, c in ipairs(pointerConnections) do c:Disconnect() end
	table.clear(pointerConnections)
	pointer = nil
end
local function startHold()
	if holdConnection then return end
	local AL = RollReveal.Alive
	local reduced = Theme.ReducedMotion()
	table.insert(pointerConnections, UserInputService.InputChanged:Connect(trackPointer))
	table.insert(pointerConnections, UserInputService.InputBegan:Connect(trackPointer))
	local t0 = os.clock()
	local last = t0
	holdConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local t, dt = now - t0, now - last
		last = now
		local follow = math.min(1, dt * AL.tiltSpeed)
		local half = rollRoot.AbsoluteSize / 2
		for i, card in ipairs(cards) do
			if card.settled and card.holder.Parent then
				local phase = i * 0.7
				local tx, ty = 0, 0
				if not reduced then
					if pointer and now - pointerAt < 4 then
						local c = card.holder.AbsolutePosition + card.holder.AbsoluteSize / 2
						tx = math.clamp((pointer.X - c.X) / math.max(half.X, 1), -1, 1)
						ty = math.clamp((pointer.Y - c.Y) / math.max(half.Y, 1), -1, 1)
					else
						tx = AL.idleSway * math.sin(t * 0.6 + phase)
						ty = AL.idleSway * 0.5 * math.sin(t * 0.45 + phase * 1.3)
					end
				end
				card.tiltX += (tx - card.tiltX) * follow
				card.tiltY += (ty - card.tiltY) * follow
				local float = math.sin((t + phase) * 2 * math.pi / RT.floatPeriod) * RT.floatPx
				card.holder.Position = card.pos + UDim2.fromOffset(card.tiltX * AL.tiltPx, float + card.tiltY * AL.tiltPx * 0.6)
				card.fx:Tilt(card.tiltX, card.tiltY)
				card.fx:Step(t, dt)
				-- the pill's glow fades in with the pill, then breathes
				if card.dressedAt then
					local on = math.clamp((now - card.dressedAt) / 0.4, 0, 1)
					local breathe = AL.pillGlow + 0.25 * (0.5 + 0.5 * math.sin(t * 2.2 + phase))
					card.pillGlow.ImageTransparency = 1 - on * (1 - breathe)
				end
			end
		end
		if screenTheme then screenTheme:Step(t) end
	end)
end
local function settle(card)
	card.settled = true
	card.holder.Visible = true
	if card.bubble then card.bubble.Visible = true end
	setScreenTheme(card.theme)
	startHold()
	-- the hum in this card's mood
	if humSound then AlterFX.FadeOut(humSound, 0.3) end
	humSound = sfx("Hum", card.rarity, RV.hum, { loop = true, fadeIn = 0.6, pitch = RollReveal.HumPitch[card.rarity.id] or 1 })
end
local function shadeCard(card, amount: number)
	tween(card.shade, { BackgroundTransparency = amount }, 0.2)
end

------------------------------------------------------------------------
-- (prompt 55) One card's reveal: the roller, then (Legendary+) the cinematic, then the card slides up. false = skipped
------------------------------------------------------------------------
local RollCinematic = require(Shared.VFX.RollCinematic)
local RL = RollReveal.Roller
local rollerText = Kit.Text({ Name = "Roller", Text = "", Font = "Chunky", TextSize = RL.textSize, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, RL.y), Size = UDim2.new(1, -40, 0, RL.textSize + 12), Visible = false, ZIndex = 8, Parent = rollRoot })
Kit.Fit(rollerText, RL.textSize, 18)
local rollerStroke = strokeOf(rollerText)
rollerStroke.Color, rollerStroke.Thickness = INK, 3
local rollerScale = New("UIScale", { Parent = rollerText })
local rollerGlow = AlterFX.Image(rollRoot, "ember", { Name = "RollerGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, RL.y),
	Size = UDim2.fromOffset(420, 150), ImageTransparency = 1, Visible = false, ZIndex = 7 })
-- what the roller shows for a trainer: his name in his rarity's colour (the Secret one, not owned yet: "???")
local function rollerLook(trainer): (string, Color3)
	local rarity = rarityOf(trainer)
	if rarity.hidden and not ownsAny(trainer.id) then return "???", Color3.fromHex("#D9D6DE") end
	return string.upper(trainer.name), fxColor(rarity)
end
local function showName(trainer, scale: number?)
	local text, color = rollerLook(trainer)
	rollerText.Text = text
	rollerText.TextColor3 = color
	rollerGlow.ImageColor3 = color
	rollerScale.Scale = scale or 1
end
local function hideRoller(time: number)
	if time <= 0 then
		rollerText.Visible, rollerGlow.Visible = false, false
		return
	end
	tween(rollerText, { Position = UDim2.fromScale(0.5, RL.y - 0.08) }, time)
	textAlpha(rollerText, 1, time)
	tween(rollerGlow, { ImageTransparency = 1 }, time)
	task.delay(time, function()
		rollerText.Visible, rollerGlow.Visible = false, false
		rollerText.Position = UDim2.fromScale(0.5, RL.y)
	end)
end
-- the names before the result: random (never the same twice in a row), the last few rarer than him where there are
-- any (the tension), then him
local function rollerNames(result, count: number)
	local list, last = {}, nil
	for _ = 1, count - RL.tease do
		local pick
		repeat pick = Trainers.List[math.random(#Trainers.List)] until pick ~= last
		table.insert(list, pick)
		last = pick
	end
	local rarer = {}
	for _, t in ipairs(Trainers.List) do
		if rarityOf(t).index > rarityOf(result).index then table.insert(rarer, t) end
	end
	if #rarer == 0 then
		for _, t in ipairs(Trainers.List) do
			if t ~= result and rarityOf(t).index >= Trainers.RarityById.Legendary.index then table.insert(rarer, t) end
		end
	end
	for _ = 1, RL.tease do
		local pick
		repeat pick = rarer[math.random(#rarer)] until pick ~= last or #rarer == 1
		table.insert(list, pick)
		last = pick
	end
	return list
end
-- the roller for one card; fast = Auto Roll. false = skipped
local function roll(card, fast: boolean): boolean
	local trainer, rarity = card.trainer, card.rarity
	local count = if fast then RL.fastNames else RL.names
	local total = if fast then RL.fastTime else RL.time
	local names = rollerNames(trainer, count)
	local secret = rarity.hidden == true
	-- the gaps grow (ease-out) and add up to the roll's time; the Secret one never slows: it stops dead
	local weights, sum = {}, 0
	for i = 1, count do
		weights[i] = if secret then 1 else 1 + (i / count) ^ RL.slowdown * 6
		sum += weights[i]
	end
	rollerText.Visible, rollerGlow.Visible = true, true
	rollerText.Position = UDim2.fromScale(0.5, RL.y)
	textAlpha(rollerText, 0)
	rollerGlow.ImageTransparency = 0.55
	backgroundColor(fxColor(rarity))
	for i, t in ipairs(names) do
		showName(t, 1.06)
		tween(rollerScale, { Scale = 1 }, 0.06)
		Audio.PlayUI("Click", { volume = RL.tick, pitch = 0.8 + 0.5 * i / count })
		if not wait_(total * weights[i] / sum) then return false end
	end
	-- the landing: his name pops 1.2 -> 1 with its sound
	showName(trainer, RL.land)
	tween(rollerScale, { Scale = 1 }, RL.landTime, Enum.EasingStyle.Back)
	rollerGlow.ImageTransparency = 0.25
	tween(rollerGlow, { ImageTransparency = 0.5 }, 0.5)
	local tier = card.tier
	if tier == 1 then
		Audio.PlayUI("GeneticsPop", { volume = RV.pop })
	elseif tier == 2 then
		Audio.PlayUI("GeneticsPop", { volume = RV.pop })
		sfx("Chime", rarity, RV.chime, { pitch = 1.2 })
	elseif tier == 3 then
		sfx("WarmWhoosh", rarity, RV.whoosh)
		sfx("Chime", rarity, RV.chime, { pitch = 1.1 })
	elseif not secret then
		sfx("Stamp", rarity, RV.nameStamp, { pitch = 0.7 })
		sfx("ChargeUp", rarity, RV.swell, { maxLength = 1 })
	end
	if secret then
		-- (the Secret one: "???" and a dead stop; the cinematic's blackout follows at once)
		Audio.Duck(0, 0.05)
		return wait_(0.25)
	end
	return wait_(if fast then 0.15 else RL.holdAfter)
end
-- the card slides up into place (from where the roller's name was)
local function cardIn(card, instant: boolean)
	card.holder.Visible = true
	card.glow:Set(true, card.themeColor)
	if instant then
		card.popScale.Scale = 1
		return
	end
	card.holder.Position = card.pos + UDim2.fromOffset(0, 70)
	card.popScale.Scale = 0.85
	tween(card.holder, { Position = card.pos }, RT.cardIn, Enum.EasingStyle.Back)
	tween(card.popScale, { Scale = 1 }, RT.cardIn, Enum.EasingStyle.Back)
	if card.tier == 4 then
		whiteFlash.BackgroundTransparency = if Theme.ReducedMotion() then 0.6 else 0.2
		tween(whiteFlash, { BackgroundTransparency = 1 }, 0.35)
		sfx("ImpactSub", card.rarity, RV.thump, { maxLength = 1 })
	end
	Audio.PlayUI("Whoosh", { volume = RV.swoosh * 0.7 })
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
-- (prompt 56) "1 NEW" in the NEW! sticker's style (gold, white stroked words, tilted), then "· 2 DUPES" in white
local summary = New("Frame", { Name = "Summary", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -300, 0, 26), ZIndex = 41,
	Parent = bar }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder }),
})
local summarySticker = New("Frame", { Name = "NewSticker", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
	Rotation = -6, LayoutOrder = 1, ZIndex = 41, Parent = summary }, {
	New("UICorner", { CornerRadius = UDim.new(0, 6) }),
	New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
	New("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})
local summaryNew = Kit.Text({ Name = "Text", Text = "", Font = "Chunky", TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, ZIndex = 42, Parent = summarySticker })
strokeOf(summaryNew).Color = INK
local summaryDupes = Kit.Text({ Name = "Dupes", Text = "", Font = "Chunky", TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 41, Parent = summary })
strokeOf(summaryDupes).Color = INK
-- (prompt 56) TAP TO CONTINUE in white, pulsing gently
local continueText = Kit.Text({ Name = "Continue", Text = "TAP TO CONTINUE", Font = "Title", TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(14, 32),
	Size = UDim2.new(1, -300, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41, Parent = bar })
local againButton = Theme.Button("Red", { Name = "Again", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -128, 0.5, 0), Size = UDim2.fromOffset(150, 44),
	ZIndex = 41, Parent = bar }, {})
local _againBig, againSmall = twoLines(againButton, "ROLL AGAIN", "", 15)
-- (prompt 56) the price with a coin in front, a soft red glow round the button (the screen's one pulsing CTA; it presses
-- in like every button, Theme.BindPress)
local againPrice = New("Frame", { Name = "Price", BackgroundTransparency = 1, Position = againSmall.Position, Size = againSmall.Size, ZIndex = 6, Parent = againButton }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local againCoin = Kit.Coin(13, { LayoutOrder = 1, ZIndex = 7, Parent = againPrice })
againSmall.Size = UDim2.new(0, 0, 1, 0)
againSmall.AutomaticSize = Enum.AutomaticSize.X
againSmall.LayoutOrder = 2
againSmall.Parent = againPrice
local againGlow = ReadyGlow.New(againButton, { pad = 14 })
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
	summarySticker.Visible = new > 0
	summaryNew.Text = new .. " NEW"
	summaryDupes.Visible = dupes > 0
	summaryDupes.Text = (if new > 0 then "· " else "") .. dupes .. (if dupes == 1 then " DUPE" else " DUPES")
	local ok, priceText = againState()
	againSmall.Text = priceText
	againSmall.TextColor3 = GOLD
	againCoin.Visible = priceText ~= "FREE" and string.sub(priceText, 1, 5) ~= "SPURT" -- (a price: the coin; FREE / SPURT 2: none)
	Theme.SetButtonStyle(againButton, if ok then "Red" else "Disabled")
	againGlow:Set(ok, Colors.Red)
	bar.Visible = true
	bar.Position = UDim2.new(0.5, 0, 1, 10)
	tween(bar, { Position = UDim2.new(0.5, 0, 1, -(Screen.barHeight + 8)) }, 0.3, Enum.EasingStyle.Back)
	Audio.PlayUI("Whoosh", { volume = RV.swoosh })
	if ok then Theme.Shine(againButton, 0.35) end
	task.spawn(function()
		local reduced = Theme.ReducedMotion()
		while bar.Visible do
			if reduced then
				continueText.TextTransparency = 0.1
				task.wait(0.3)
			else
				tween(continueText, { TextTransparency = 0.55 }, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.9)
				tween(continueText, { TextTransparency = 0.05 }, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.9)
			end
		end
		continueText.TextTransparency = 0.05
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
	local fast = quick and bestRarity.index < Trainers.RarityById[Trainers.AutoStopRarity].index -- (the fast roller, then it closes)
	againCount = #results
	-- the setup: the calm dark background (prompt 55), the HUD and the Agency step aside
	overlay.Enabled = true
	bar.Visible = false
	whiteFlash.BackgroundTransparency = 1
	dim.BackgroundTransparency = 1
	spotlight.ImageTransparency = 1
	tween(dim, { BackgroundTransparency = RollReveal.Background.dim }, RT.setup)
	tween(spotlight, { ImageTransparency = 0.9 }, RT.setup)
	makeBackground()
	menuWasHidden = SideMenu.IsHidden()
	SideMenu.SetHidden(true)
	if modal.root then modal.root.Visible = false end
	task.wait() -- (the root has its size)
	local slotSize = layout(order)
	for i, entry in ipairs(order) do
		if #order > 1 then dashedSlot(entry.slotPos, slotSize) end
		cards[i] = makeCard(entry, i)
	end
	Audio.Duck(RollReveal.MusicDuck, 0.3)
	if not fast then wait_(RT.setup) end
	-- (a first-ever Mythic / Secret can't be skipped for its first seconds)
	local firstRare = false
	for _, entry in ipairs(order) do
		if entry.rarity.index >= Trainers.RarityById.Mythic.index and isNewResult(entry.result) then firstRare = true end
	end
	if firstRare then skipLockUntil = os.clock() + RollReveal.Cinematic.unskippable end
	local dressEnd = 0 -- (prompt 56) when the last card's stat rows and dupe bar are done (the bar comes after)
	-- one card at a time, left to right (lowest first): the roller, the cinematic (Legendary+), the card
	for i, card in ipairs(cards) do
		if skip then break end
		if i > 1 then
			sfx("Riser", nil, RV.riser, { fadeIn = 0.1, maxLength = 0.6 })
			for j = 1, i - 1 do shadeCard(cards[j], 0.2) end
			if not wait_(RT.gapBetweenCards) then break end
		end
		if not roll(card, fast) then break end
		if card.tier == 4 then
			-- the cinematic in the world (the overlay hides itself while it plays)
			hideRoller(0)
			local played = RollCinematic.Play({ trainer = card.trainer, rarity = card.rarity, color = fxColor(card.rarity),
				chanceText = Trainers.ChanceText(card.trainer.chance or card.rarity.chance), skipped = function() return skip end,
				onTap = function() if os.clock() >= skipLockUntil then skip = true end end })
			Audio.Duck(RollReveal.MusicDuck, 0.3)
			if not played or skip then break end
		else
			hideRoller(0.2)
		end
		cardIn(card, false)
		local took = dress(card, false, fast)
		dressEnd = os.clock() + took
		settle(card)
		if i < #cards then
			-- (prompt 56) the next roller waits for this card's stat rows
			if not wait_(math.max(RT.dress, took)) then break end
		end
	end
	if skip then
		-- every card not done yet: a quick pop each (one combined pop-pop-pop)
		RollCinematic.Stop()
		hideRoller(0)
		dressEnd = 0
		whiteFlash.BackgroundTransparency = 1
		dim.BackgroundTransparency = RollReveal.Background.dim
		spotlight.ImageTransparency = 0.9
		local n = 0
		for _, card in ipairs(cards) do
			if not card.settled then
				card.holder.Visible = true
				card.popScale.Scale = 0.6
				tween(card.popScale, { Scale = 1 }, RT.skipPop, Enum.EasingStyle.Back)
				card.glow:Set(true, card.themeColor)
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
	skipLockUntil = 0
	if fast then
		busy = false
		local t1 = os.clock()
		while (os.clock() - t1 < RT.autoClose or os.clock() < dressEnd) and not closeWanted do task.wait() end
		closeWanted = true
	else
		-- (prompt 56) the bar slides up after the stat rows (a tap: at once)
		while os.clock() < dressEnd and not skip do task.wait() end
		skip = false
		task.wait(RT.beforeBar)
		fanfare(bestRarity)
		showBar(order)
		busy = false
	end
	while not closeWanted do task.wait() end
	-- close
	busy = true
	RollCinematic.Stop()
	hideRoller(0)
	removeBackground()
	tween(dim, { BackgroundTransparency = 1 }, 0.2)
	tween(spotlight, { ImageTransparency = 1 }, 0.2)
	if bar.Visible then tween(bar, { Position = UDim2.new(0.5, 0, 1, 10) }, 0.2) end
	for _, card in ipairs(cards) do tween(card.popScale, { Scale = 0.85 }, 0.15) end
	if humSound then AlterFX.FadeOut(humSound, 0.3) humSound = nil end
	Audio.Duck(1, 0.4)
	task.wait(0.2)
	overlay.Enabled = false
	bar.Visible = false
	stopHold() -- (prompt 56: every effect stops with it)
	for _, c in ipairs(cards) do c.holder:Destroy() end
	for _, s in ipairs(slots) do s:Destroy() end
	cards, slots = {}, {}
	SideMenu.SetHidden(menuWasHidden)
	if modal.root then modal.root.Visible = true end
	busy = false
	return bestRarity.index
end
tapCatcher.Activated:Connect(function()
	if busy then
		if os.clock() < skipLockUntil then return end -- (a first-ever Mythic / Secret: not yet)
		skip = true
	else
		closeWanted = true
	end
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
-- (owner, prompt 48; 23 Oct) the only server-wide message: someone rolled The Shadow (Mythic) or Atlas (Secret). "Rong rolled ATLAS!
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
	elseif kind == "Beam" then
		-- (prompt 55) someone near me rolled a Legendary+: the beam and the shockwave beside them (no letterbox, no camera)
		local who = Players:GetPlayerByUserId(tonumber(info.userId) or 0)
		local rarity = Trainers.RarityById[tostring(info.rarity)]
		if who and who ~= player and rarity then
			task.delay(math.clamp(tonumber(info.delay) or 0, 0, 20), function()
				local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
				if not root then return end
				local look = RollReveal.Cinematic[rarity.id] or {}
				local right = root.CFrame.RightVector * Vector3.new(1, 0, 1)
				local color = if look.color then Color3.fromHex(look.color) else fxColor(rarity)
				require(Shared.VFX.RollCinematic).Beam(root.Position + right * RollReveal.Cinematic.beamSide, color, look.light)
			end)
		end
	elseif kind == "Gift" then
		-- (owner, 23 Oct) the group perks welcome gift: a toast, then his normal reveal ("NEW!" or a dupe), once the player is
		-- really playing (after the menu and the genetics screen) and the tutorial is over (only the tutorial shows during it)
		local results = type(info.results) == "table" and info.results or {}
		task.spawn(function()
			UIBus.WaitForGameplay(1)
			while UIBus.InTutorial and UIBus.InTutorial() do task.wait(1) end
			local gift = Trainers.GroupGift
			local Economy = require(Shared.Config.Economy) -- (prompt 61: at your stage, as the server paid it)
			local giftCoins = Economy.Reward(ClientData.Get().growthSpurts, Economy.Rewards.GroupGift, gift.coins)
			Notify.Reward("WELCOME, CREW MEMBER!", "+" .. Kit.Format(giftCoins) .. " coins, " .. gift.rolls .. " free roll, the CREW MEMBER title and Coach Lou",
				"gift", Colors.Gold, "TitleUnlocked", "groupgift")
			task.wait(1.5)
			play(results, false)
			if modal.isOpen() then refresh() end
		end)
	elseif kind == "AdminGift" then
		-- (prompt 64) a trainer from the owner's console (AdminService): a toast, then the normal reveal, once really playing
		local results = type(info.results) == "table" and info.results or {}
		task.spawn(function()
			UIBus.WaitForGameplay(1)
			while UIBus.InTutorial and UIBus.InTutorial() do task.wait(1) end
			Notify.Reward("A GIFT FOR YOU!", string.upper(tostring(info.name)) .. " · " .. tostring(info.stage), "gift", Colors.Gold, "TitleUnlocked", "admingift")
			task.wait(1.5)
			play(results, false)
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
			local Economy = require(Shared.Config.Economy) -- (prompt 61: at your stage, as the server paid it)
			local giftCoins = Economy.Reward(ClientData.Get().growthSpurts, Economy.Rewards.RebalanceGift, gift.coins)
			Notify.Reward("TRAINER BOOSTS WERE REBALANCED", "A gift for you: +" .. Kit.Format(giftCoins) .. " coins and " .. gift.rolls .. " free roll",
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
