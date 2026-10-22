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
--   * The roll (tap to skip; prompt 48: rarity-scaled, see "The roll reveal" below): Common / Uncommon a quick drop (~0.6 s),
--     Rare an orb that bursts into the card (~1.2 s), Epic bigger pulses and a purple tint (~1.8 s), Legendary and better
--     the darkening, a white flash, rays, a shockwave and the name slamming in (~3 s). Layered sounds (Config.AlterThemes.Sounds).
--   * Legendary and better: the whole server is told (a chat line + a toast); Secret and Eternal: a big banner too.
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
local tab = "Agency"
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
myPanel = require(Shared.UI.TrainersPanel).Build(modal.body)
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
local function showTab(id: string)
	tab = id
	modal.selectTab(id)
	agencyFrame.Visible = id == "Agency"
	myPanel.frame.Visible = id == "My"
	if id == "My" then myPanel.refresh() end
	if bindKeys then bindKeys(keyboard and id == "Agency" and modal.isOpen()) end
end

-- (prompt 27, 22 Oct: the kit design kit_agency_stand.png) LEFT: the odds grid, 2 rows of 4 rarity slots. A slot: a dark tile
-- with a deep radial glow and faint light rays in the rarity color, a thin border in a darker rarity color, the trainer's
-- portrait (Config/Trainers icon); one you haven't owned yet is a black silhouette with a thin rim in the rarity color on a
-- brighter burst (owner, 22 Oct: the hidden rarities, Secret and Eternal, too, and their name is "???" until you own
-- them). Under it the rarity name (loud, its color) and the chance (small, gray: Trainers.ChanceText, "50%", "0.035%").
-- Owned: a small gold check; a count "x2" bottom-right. A tap (or hover) shows his name and boost.
local GRID_W = 384
local CELL_GAP = 8
local SLOT_TEXT = 0 -- (prompt 47: the rarity name and the chance are inside the tile now)
local DARK_TILE = Color3.fromHex("#16161A")
local grid = New("Frame", { Name = "Odds", BackgroundTransparency = 1, Size = UDim2.new(0, GRID_W, 1, 0), Parent = agencyFrame }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -CELL_GAP * 3 / 4, 0.5, -CELL_GAP / 2), CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal }),
})
local slots = {}
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
	-- (over the lower part of the slot's own tile, in mockup px: the cell's column / row times its size)
	local cell = slot.cell
	local column, row = (slot.order - 1) % 4, (slot.order - 1) // 4
	local cellW = (GRID_W - CELL_GAP * 3) / 4
	local px = math.max(cell.AbsoluteSize.X / cellW, 0.01) -- (pixels per mockup px)
	local cellH = cell.AbsoluteSize.Y / px
	local x = math.clamp(column * (cellW + CELL_GAP) + cellW / 2, 75, GRID_W - 75)
	tooltip.Position = UDim2.fromOffset(x, row * (cellH + CELL_GAP) + cellH - SLOT_TEXT - 3)
	tooltip.Visible = true
	tipShownAt = os.clock()
	local at = tipShownAt
	task.delay(2.5, function() if tipShownAt == at then hideTip() end end)
end

-- (prompt 47, 22 Oct) the slots are the one trainer tile (Shared/UI/TrainerTile) in rarity mode: his name, his portrait (a
-- black silhouette with a rim in the rarity color until you own him; Secret and Eternal "???" too), the rarity name and
-- the chance; a gold check when owned, "x2" bottom-right
local TrainerTile = require(Shared.UI.TrainerTile)
-- (prompt 47) the portraits and stage backgrounds load once at join, so the first reveal never shows an empty card
task.spawn(function()
	local ids = {}
	for _, portrait in pairs(Trainers.Portraits or {}) do table.insert(ids, portrait.icon) table.insert(ids, portrait.art) end
	for _, art in pairs(Trainers.StageArt or {}) do table.insert(ids, art.hex) table.insert(ids, art.evo) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)
for order, trainer in ipairs(Trainers.List) do
	local cell = New("Frame", { Name = trainer.id, LayoutOrder = order, BackgroundTransparency = 1, Parent = grid })
	local tile = TrainerTile.New({ Name = "Tile", px = 92, Size = UDim2.fromScale(1, 1), Parent = cell })
	local count = Kit.Text({ Name = "Count", Text = "", Font = "Chunky", TextSize = 12, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4),
		Size = UDim2.fromOffset(40, 15), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12, Parent = tile.button })
	local slot = { cell = cell, tile = tile, count = count, trainer = trainer, order = order }
	slots[trainer.id] = slot
	tile.button.Activated:Connect(function()
		Audio.PlayUI("Click")
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
local function refreshRows()
	for id, slot in pairs(slots) do
		local rarity = rarityOf(slot.trainer)
		local owned = ownsAny(id)
		slot.tile:Set({ id = id, rarity = true, silhouette = not owned, owned = owned, caption = Trainers.ChanceText(rarity.chance) })
		local n = copiesOf(id)
		slot.count.Text = if n >= 2 then "x" .. n else ""
	end
end

-- RIGHT (kit_agency_stand.png): the pity counter in a dark pill with a thin teal bar, then the red ROLL CTA ("525 COINS",
-- the only red thing here), flat X3 and AUTO (teal edge when on), a flat gear (the auto-delete toggles), then MY TRAINERS,
-- "Following 1 / 3" and the +1 slot pass. On a keyboard: E / R / T keycaps (and keys) while the Agency tab is open.
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local FLAT = Color3.fromHex("#1A1A1F")
local FLAT_EDGE = Color3.fromHex("#2E2E36")
local TEAL = Color3.fromHex("#2FD4C4")
local right = New("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromOffset(GRID_W + 14, 0), Size = UDim2.new(1, -(GRID_W + 14), 1, 0),
	Parent = agencyFrame })
local pityPill = New("Frame", { Name = "PityPill", BackgroundColor3 = Color3.fromHex("#111114"), Size = UDim2.new(1, 0, 0, 44), Parent = right }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Color = FLAT_EDGE, Thickness = 1 }),
})
-- (prompt 47, mockup 02b_roll_closeup) one thick bar: a dark hex track, the teal fill, the words on it
pityPill.Size = UDim2.new(1, 0, 0, 40)
New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = Theme.HexTile, ImageTransparency = 0.8,
	Size = UDim2.fromScale(1, 1), Parent = pityPill }, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
local pityFill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -8), ZIndex = 2,
	Parent = pityPill }, {
	New("UICorner", { CornerRadius = UDim.new(0, 9) }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#6FF0E2"), Color3.fromHex("#1FB5A6")) }),
})
local function setPity(k: number)
	k = math.clamp(k, 0, 1)
	pityFill.Size = UDim2.new(k, -8 * k, 1, -8)
end
local pity = Kit.Text({ Name = "Pity", Text = "", Font = "Chunky", TextSize = 14, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = pityPill })
do
	local stroke = pity:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = pity })
	stroke.Color, stroke.Thickness = Color3.fromHex("#0A090B"), 1.8
end

keyboard = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local function keycap(parent: GuiObject, key: string)
	local cap = New("Frame", { Name = "Key", BackgroundColor3 = Color3.fromHex("#0B0B0D"), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(20, 20), Visible = keyboard, ZIndex = 8, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, 5) }),
		New("UIStroke", { Color = Color3.fromHex("#4A4A54"), Thickness = 1 }),
	})
	Kit.Text({ Text = key, Font = "Title", TextSize = 12, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = cap })
	return cap
end
-- two lines on a button: the big word and the small value under it
local function twoLines(button: GuiObject, big: string, small: string, bigSize: number)
	-- (prompt 45: the chunky font, like ROLL; prompt 47: its position was lost inside that comment, so the word floated
	-- above the button. Both lines chunky with a dark stroke, like mockup 02b_roll_closeup)
	local top = Kit.Text({ Name = "Big", Text = big, Font = "Chunky", TextSize = bigSize, Position = UDim2.new(0, 0, 0, 5), Size = UDim2.new(1, 0, 0.55, -3),
		ZIndex = 6, Parent = button })
	local bottom = Kit.Text({ Name = "Small", Text = small, Font = "Chunky", TextSize = 13, Position = UDim2.new(0, 0, 0.55, 0), Size = UDim2.new(1, 0, 0.35, 0),
		ZIndex = 6, Parent = button })
	for _, label in ipairs({ top, bottom }) do
		top:SetAttribute("KeepFont", true)
		local stroke = label:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = label })
		stroke.Color, stroke.Thickness = Color3.fromHex("#0A090B"), if label == top then 2.2 else 1.5
	end
	return top, bottom
end
-- a FLAT button (no bevel, no gloss, darker): X3, AUTO, the gear
local function flatButton(name: string, width: number)
	local b = New("TextButton", { Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = FLAT, Size = UDim2.fromOffset(width, 64), Parent = right }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	})
	local edge = New("UIStroke", { Name = "Edge", Color = FLAT_EDGE, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	Theme.BindPress(b)
	return b, edge
end
local ROW_Y = 54
local rollButton = Theme.Button("Red", { Name = "Roll", Position = UDim2.fromOffset(0, ROW_Y), Size = UDim2.fromOffset(150, 64), Parent = right }, {})
local _rollBig, rollSmall = twoLines(rollButton, "ROLL", "", 24)
keycap(rollButton, "E")
local x3Button, x3Edge = flatButton("X3", 66)
x3Button.Position = UDim2.fromOffset(158, ROW_Y)
local x3Big, x3Small = twoLines(x3Button, "X3", "", 18)
keycap(x3Button, "R")
local autoButton, autoEdge = flatButton("Auto", 66)
autoButton.Position = UDim2.fromOffset(232, ROW_Y)
local _autoBig, autoSmall = twoLines(autoButton, "AUTO", "OFF", 16)
keycap(autoButton, "T")
local gearButton = flatButton("Gear", 44)
gearButton.Position = UDim2.fromOffset(306, ROW_Y)
local gearIcon = Pieces.Icon("settings", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24),
	ZIndex = 6, Parent = gearButton })
gearIcon:SetAttribute("KeepColor", true)
local priceLine = Kit.Text({ Name = "PriceLine", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(0, ROW_Y + 70),
	Size = UDim2.new(1, -4, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = right })
-- the gear's popover: the auto-delete toggles
local popover = New("Frame", { Name = "AutoDelete", BackgroundColor3 = Color3.fromHex("#0E0E11"), AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, ROW_Y + 70), Size = UDim2.fromOffset(250, 84), Visible = false, ZIndex = 15, Parent = right }, {
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
-- bottom: my trainers, slots, the +1 slot pass
local myTrainers = Kit.Button("Quiet", "My trainers", { Name = "MyTrainers", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Parent = right },
	{ width = 130, height = 44, textSize = 13 })
local slotButton = Kit.Button("Quiet", "+1 slot", { Name = "ExtraSlot", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, 0), Parent = right },
	{ width = 118, height = 44, textSize = 12 })
local slotsLine = Kit.Text({ Name = "Slots", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 136, 1, -14), Size = UDim2.fromOffset(90, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = right })
slotButton.Visible = PASS ~= nil and PASS.id ~= nil
if PASS and PASS.id then
	task.spawn(function()
		UIBus.WaitForGameplay() -- (prompt 11: once the player is playing, not on join)
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(PASS.id, Enum.InfoType.GamePass) end)
		if ok and info and info.PriceInRobux then Kit.SetButton(slotButton, nil, "R$ " .. Kit.Format(info.PriceInRobux) .. " · +1 slot") end
	end)
end
slotButton.Activated:Connect(function()
	if PASS and PASS.id and not player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) then MarketplaceService:PromptGamePassPurchase(player, PASS.id) end
end)
myTrainers.Activated:Connect(function()
	Audio.PlayUI("Click")
	showTab("My")
end)

local autoOn = false
local autoLoop -- (below)
local function setAuto(on: boolean)
	autoOn = on
	autoSmall.Text = if on then "ON" else "OFF"
	-- (prompt 47) AUTO ON: green
	autoSmall.TextColor3 = if on then Color3.fromHex("#4BE07A") else Colors.Text
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
	rollSmall.Text = Kit.Format(p)
	rollSmall.TextColor3 = Colors.Gold
	Theme.SetButtonStyle(rollButton, if coins >= p then "Red" else "Disabled")
	if multiOpen() then
		x3Big.Text = "X3"
		x3Small.Text = Kit.Format(p * Trainers.MultiRoll)
		x3Small.TextColor3 = Colors.Gold
		x3Big.TextColor3 = if coins >= p * Trainers.MultiRoll then Colors.Text else Colors.Muted
	else
		x3Big.Text = "X3"
		x3Small.Text = "SPURT " .. Trainers.MultiRollFromSpurt
		x3Big.TextColor3 = Colors.Muted
	end
	x3Edge.Color = FLAT_EDGE
	priceLine.Text = "One roll = " .. Kit.Format(p) .. " coins (about " .. Trainers.RollMinutes .. " min of training). Coins only. Auto stops on "
		.. Trainers.AutoStopRarity .. " or better."
	for rarityId, t in pairs(deleteToggles) do t.set(s.autoDelete[rarityId] == true) end
	local slotsCount = player:GetAttribute("TrainerSlots") or 1
	local following = player:GetAttribute("Trainers")
	local n = 0
	if type(following) == "string" then for _ in string.gmatch(following, "[^,]+") do n += 1 end end
	slotsLine.Text = "Following " .. n .. " / " .. slotsCount
	slotButton.Visible = PASS ~= nil and PASS.id ~= nil and player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) ~= true
	refreshRows()
end

------------------------------------------------------------------------
-- The roll reveal (prompt 27, 22 Oct; prompt 48, 22 Oct: rarity-scaled, it replaced the card back + flip). A full-screen
-- dark backdrop hides the Agency, a soft spotlight in the middle. The card: the trainer's full body big on the rarity glow
-- with light rays, the rarity pill, his NAME (Luckiest Guy, white with the rarity color outline), his boost, his line in a
-- speech bubble, and "NEW!" (gold) or "x2 · 2/3 to IRON-BORN" with a small bar. "Tap to continue" pulses at the bottom.
-- The rarer, the longer and bigger:
--   * Common / Uncommon (~0.6 s): the card drops in with a small bounce and a pop.
--   * Rare (~1.2 s): an orb in the rarity color floats in, pulses twice, bursts into the card (a small UI shake, sparks).
--   * Epic (~1.8 s): slower, bigger pulses, a purple tint creeps in from the screen edges, a bigger burst.
--   * Legendary and better (~3 s): the screen darkens around the orb, the pulses slow almost to a stop, a hard white
--     flash, light rays and a shockwave ring in the rarity color (gold; Mythic / Secret / Eternal their own), the card
--     lands with an overshoot (1.2 -> 1.0) and the NAME slams in last with a hit; then the rarity's extras (Legendary
--     brass, Mythic lightning, Secret a deep boom, Eternal stars and a cheer).
-- Textures: the aura VFX set (AlterFX.TEX: shockwave_ring, spark_star, rim_glow). Layered sounds (Config.AlterThemes.Sounds).
-- X3: the cards resolve one at a time in the middle, sorted so the BEST is last, then all three are shown together. A tap
-- during a reveal skips straight to that final view. Auto Roll: the quick drop, except Epic or better (the full reveal,
-- and auto roll stops). Reduced Motion: no shake, a shorter, softer flash.
------------------------------------------------------------------------
local overlay = Theme.ScreenGui({ Name = "TrainerRoll", DisplayOrder = 47, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
overlay.ScreenInsets = Enum.ScreenInsets.None
overlay.IgnoreGuiInset = true
local dim = New("Frame", { Name = "Dim", BackgroundColor3 = Color3.fromHex("#07070A"), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = overlay })
local spotlight = AlterFX.Image(overlay, "ember", { Name = "Spotlight", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromScale(0.9, 1.3), ImageColor3 = Color3.fromHex("#FFF3C4"), ImageTransparency = 1, ZIndex = 1 })
local fxLayer = New("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 2, Parent = overlay })
local whiteFlash = New("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20,
	Parent = overlay })
local tapCatcher = New("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30,
	Parent = overlay })
local rollRoot = Kit.Root(overlay)
rollRoot.ZIndex = 5
local continueText = Kit.Text({ Name = "Continue", Text = "TAP TO CONTINUE", Font = "Title", TextSize = 15, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(300, 20), Visible = false, ZIndex = 9, Parent = rollRoot })

local CARD_ONE = Vector2.new(236, 330) -- one card: the trainer about half the screen high
local CARD_THREE = Vector2.new(184, 258)
local CARD_Y = 0.47
local GOLD = Color3.fromHex("#F6C75A")
local busy = false
local skip = false
local closeWanted = false
local cards = {}
local transient = {} -- the orb, edge tints and screen rays of a reveal (cleared on a skip and at the end)

-- the reveal tier of a rarity: 1 the drop (Common, Uncommon), 2 the orb (Rare), 3 Epic, 4 Legendary and better
local function tierOf(rarity): number
	if rarity.index >= Trainers.RarityById.Legendary.index then return 4 end
	if rarity.index >= Trainers.RarityById.Epic.index then return 3 end
	if rarity.index >= Trainers.RarityById.Rare.index then return 2 end
	return 1
end
-- the rarity's light (orb, rays, rings): its own color (Secret's is near black, so its grey)
local function fxColor(rarity): Color3
	return hex(if rarity.id == "Secret" then rarity.color2 else rarity.color)
end
-- a theme-like table for AlterFX helpers (particles, rings)
local function fxTheme(rarity)
	local accent = fxColor(rarity)
	local texture = if rarity.reveal == "lightning" then "lightning" elseif rarity.reveal == "dark" then "smoke" else "spark"
	return { accent = accent, particle = { texture = texture, color = accent, motion = if rarity.reveal == "cosmic" then "drift" else "rise" } }
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
-- the middle of a GUI object in the FX layer's pixels (offset UDim2) and as a share of the screen
local function centerOf(gui: GuiObject): (UDim2, number, number)
	local size = fxLayer.AbsoluteSize
	local p = gui.AbsolutePosition + gui.AbsoluteSize / 2 - fxLayer.AbsolutePosition
	return UDim2.fromOffset(p.X, p.Y), p.X / math.max(size.X, 1), p.Y / math.max(size.Y, 1)
end
-- a small UI shake of these objects around their places (Reduced Motion: none)
local function shakeUI(objects: { GuiObject }, strength: number, time: number)
	if Theme.ReducedMotion() then return end
	local bases = {}
	for i, o in ipairs(objects) do bases[i] = o.Position end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time and not skip do
			local k = strength * (1 - (os.clock() - t0) / time)
			for i, o in ipairs(objects) do o.Position = bases[i] + UDim2.fromOffset(math.random(-10, 10) / 10 * k, math.random(-10, 10) / 10 * k) end
			task.wait(0.03)
		end
		for i, o in ipairs(objects) do o.Position = bases[i] end
	end)
end
-- a tint that creeps in from the 4 screen edges (Epic: purple; Legendary+: black, the darkening around the orb)
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
-- light rays over the whole screen behind the card, turning slowly
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
		tween(ray, { BackgroundTransparency = 0.45 }, 0.25)
	end
	task.spawn(function()
		while rays.Parent do
			rays.Rotation += 0.25
			task.wait(1 / 30)
		end
	end)
end

-- the orb: a glowing ball in the rarity color that floats up into the card's place (it bursts into the card)
local function makeOrb(card, size: number)
	local color = fxColor(card.rarity)
	local orb = New("Frame", { Name = "Orb", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, card.x, CARD_Y, 90),
		Size = UDim2.fromOffset(size, size), ZIndex = 6, Parent = rollRoot })
	table.insert(transient, orb)
	local scale = New("UIScale", { Scale = 0.3, Parent = orb })
	local halo = AlterFX.Image(orb, "rim", { Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.8, 2.8),
		ImageColor3 = color, ImageTransparency = 1, ZIndex = 6 })
	local core = New("Frame", { Name = "Core", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = orb }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), color) }),
	})
	local edge = New("UIStroke", { Color = color, Thickness = 3, Transparency = 1, Parent = core })
	local star = AlterFX.Image(orb, "spark", { Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6),
		ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 1, ZIndex = 8 })
	tween(orb, { Position = UDim2.new(0.5, card.x, CARD_Y, 0) }, 0.4, Enum.EasingStyle.Sine)
	tween(scale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
	tween(halo, { ImageTransparency = 0.25 }, 0.4)
	tween(core, { BackgroundTransparency = 0 }, 0.3)
	tween(edge, { Transparency = 0 }, 0.3)
	tween(star, { ImageTransparency = 0.3 }, 0.4)
	task.spawn(function()
		while orb.Parent do
			star.Rotation += 3
			task.wait(1 / 30)
		end
	end)
	return { frame = orb, scale = scale, halo = halo, color = color }
end
-- one pulse: the orb swells to `size` and back over `time` with a thump and a chime a step higher each time; false = skipped
local function pulse(orb, size: number, time: number, step: number): boolean
	tween(orb.scale, { Scale = size }, time * 0.45, Enum.EasingStyle.Sine)
	tween(orb.halo, { ImageTransparency = 0 }, time * 0.45)
	AlterFX.Sound("Stamp", { volume = 0.5 + step * 0.1, pitch = 0.7 })
	AlterFX.Sound("Chime", { volume = 0.7, pitch = 0.75 + step * 0.12 })
	AlterFX.Ring(fxLayer, orb.color, 40, 140 + size * 60, time, (centerOf(orb.frame)))
	if not wait_(time * 0.45) then return false end
	tween(orb.scale, { Scale = 1 }, time * 0.55, Enum.EasingStyle.Sine)
	tween(orb.halo, { ImageTransparency = 0.3 }, time * 0.55)
	return wait_(time * 0.55)
end
-- the orb is gone and the card bursts out of it: from `from` up past 1 to `peak`, then settles at 1
local function burst(card, orb, from: number, peak: number, time: number)
	if orb then orb.frame:Destroy() end
	card.holder.Visible = true
	card.scale.Scale = from
	tween(card.scale, { Scale = peak }, time * 0.4, Enum.EasingStyle.Quad)
	task.delay(time * 0.4, function() tween(card.scale, { Scale = 1 }, time * 0.6, Enum.EasingStyle.Back) end)
	card.glow.ImageColor3 = hex(card.rarity.color)
	tween(card.glow, { ImageTransparency = 0.15 }, time)
end
-- the final look of a card (a skip lands here at once)
local function settle(card, instant: boolean?)
	local t = if instant then 0.06 else 0.12
	card.holder.Visible = true
	tween(card.holder, { Position = UDim2.new(0.5, card.x, CARD_Y, 0) }, t)
	tween(card.scale, { Scale = 1 }, t)
	tween(card.nameScale, { Scale = 1 }, t)
	card.name.Visible = true
	card.glow.ImageColor3 = hex(card.rarity.color)
	card.glow.ImageTransparency = 0.15
	if card.bubble then card.bubble.Visible = true end
end

-- the card: hidden at its place until its reveal shows it
local function makeCard(result, index: number, total: number)
	local trainer = Trainers.ById[result.id]
	local rarity = rarityOf(trainer)
	local size = if total > 1 then CARD_THREE else CARD_ONE
	local accent = hex(rarity.color)
	local outline = hex(rarity.color2 or rarity.color)
	local x = (index - (total + 1) / 2) * (size.X + 18)
	local holder = New("Frame", { Name = "Card" .. index, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, CARD_Y, 0),
		Size = UDim2.fromOffset(size.X, size.Y), Visible = false, ZIndex = 5, Parent = rollRoot })
	local scale = New("UIScale", { Parent = holder })
	local glow = AlterFX.Image(holder, "rim", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 110, 1, 110),
		ImageColor3 = accent, ImageTransparency = 1, ZIndex = 4 })
	local front = New("Frame", { Name = "Front", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 5, ClipsDescendants = true,
		Parent = holder }, {
		New("UICorner", { CornerRadius = UDim.new(0, 16) }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(accent:Lerp(Color3.fromHex("#1C1C21"), 0.5), Color3.fromHex("#101013")) }),
	})
	local stroke = New("UIStroke", { Color = outline, Thickness = 3, Parent = front })
	AlterFX.Image(front, "ember", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(1.4, 0.95),
		ImageColor3 = accent, ImageTransparency = 0.25, ZIndex = 5 })
	local rays = New("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = front })
	for i = 0, 5 do
		New("Frame", { BackgroundColor3 = accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.08, 1.6), Rotation = i * 30, BackgroundTransparency = 0.7, ZIndex = 5, Parent = rays }, {
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15),
				NumberSequenceKeypoint.new(1, 1) }) }),
		})
	end
	-- (the rays behind his picture turn slowly)
	task.spawn(function()
		while holder.Parent do
			rays.Rotation += 0.4
			task.wait(1 / 30)
		end
	end)
	-- the rows (mockup px): his full body big on top, then the rarity pill, the name, the boost, NEW! / the count at the bottom
	local small = total > 1
	local pillY = math.floor(size.Y * (if small then 0.55 else 0.62))
	local nameY, nameH = pillY + 24, if small then 24 else 32
	local perkY, perkH = nameY + nameH + 2, if small then 24 else 26
	TrainerPortrait.Art(trainer.id, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(1, -16, 0, pillY - 10), ZIndex = 6, Parent = front })
	local pill = New("Frame", { Name = "Rarity", BackgroundColor3 = accent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, pillY),
		Size = UDim2.new(0.62, 0, 0, 22), ZIndex = 7, Parent = front }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	if rarity.color2 then New("UIGradient", { Color = ColorSequence.new(accent, hex(rarity.color2)), Parent = pill }) end
	local pillText = Kit.Text({ Text = string.upper(rarity.name), Font = "Title", TextSize = 13, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = pill })
	pillText.TextColor3 = if rarity.id == "Common" or rarity.id == "Eternal" or rarity.id == "Legendary" then Color3.fromHex("#141417") else Color3.new(1, 1, 1)
	-- (the name sits on top of the card, so it can slam in from big)
	local nameLabel = New("TextLabel", { Name = "Name", BackgroundTransparency = 1, Text = string.upper(trainer.name), FontFace = LUCKIEST, TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, nameY + nameH / 2), Size = UDim2.new(1, -16, 0, nameH),
		ZIndex = 9, Parent = holder })
	New("UIStroke", { Thickness = 2.5, Color = if rarity.id == "Secret" then outline else accent:Lerp(Color3.new(0, 0, 0), 0.25), Parent = nameLabel })
	local nameScale = New("UIScale", { Parent = nameLabel })
	Kit.Text({ Name = "Perk", Text = trainer.perkText, Font = "Strong", TextSize = if small then 10 else 12, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, perkY), Size = UDim2.new(1, -16, 0, perkH), ZIndex = 7, Parent = front })
	local tagY = UDim2.new(0.5, 0, 1, -10)
	local isNew = if result.new ~= nil then result.new == true else result.count == 1
	if result.deleted then
		Kit.Text({ Text = "Duplicate: +" .. Kit.Format(math.floor(price() * Trainers.AutoDeleteRefund)) .. " coins", Font = "Strong", TextSize = 11, TextColor3 = Colors.Muted,
			AnchorPoint = Vector2.new(0.5, 1), Position = tagY, Size = UDim2.new(1, -12, 0, 16), ZIndex = 7, Parent = front })
	elseif isNew then
		local new = Kit.Text({ Name = "New", Text = "NEW!", Font = "Title", TextSize = 18, AnchorPoint = Vector2.new(0.5, 1), Position = tagY, Size = UDim2.new(1, -12, 0, 22),
			ZIndex = 8, Parent = front })
		Kit.GoldText(new)
	else
		-- (prompt 33; prompt 48: Golden is gone) his BASE copies toward the next evolution: 3 make an IRON-BORN (a stage
		-- you haven't reached yet is "???", like everywhere else)
		local need = Trainers.EvolveCount
		local count = math.max(1, result.count or 1)
		local have = math.min(count, need)
		local nextStage = Trainers.Stages[2]
		local nextName = if state().discovered[nextStage.id] then nextStage.name else "???"
		local text = if count >= need then "x" .. count .. " · READY: EVOLVE TO " .. nextName else "x" .. count .. " · " .. have .. "/" .. need .. " to " .. nextName
		local line = Kit.Text({ Name = "Evolve", Text = text, Font = "Strong", TextSize = 11, TextColor3 = GOLD, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -12, 0, 14), ZIndex = 7, Parent = front })
		Kit.Fit(line, 11, 8)
		local _bar, setBar = Kit.Bar(GOLD, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.6, 0, 0, 6), ZIndex = 7, Parent = front })
		setBar(have / need)
	end
	-- his line in a small speech bubble over the card's top edge (one card only: three get crowded)
	local bubble = nil
	if trainer.line and total == 1 then
		bubble = Kit.Text({ Name = "Line", Text = "\"" .. trainer.line .. "\"", Font = "Strong", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 9, Parent = holder })
		bubble.BackgroundTransparency = 0.05
		bubble.BackgroundColor3 = Color3.fromHex("#F4F1EA")
		bubble.TextColor3 = Color3.fromHex("#141417")
		New("UICorner", { CornerRadius = UDim.new(0, 10), Parent = bubble })
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = bubble })
	end
	return { holder = holder, scale = scale, front = front, stroke = stroke, glow = glow, bubble = bubble, rays = rays, name = nameLabel, nameScale = nameScale,
		rarity = rarity, trainer = trainer, result = result, x = x, size = size }
end

-- Common / Uncommon (and every quick auto roll): the card drops in with a small bounce and a pop (~0.6 s)
local function revealDrop(card, quick: boolean)
	local k = if quick then 0.7 else 1
	card.holder.Visible = true
	card.holder.Position = UDim2.new(0.5, card.x, CARD_Y, -60)
	card.scale.Scale = 0.7
	tween(card.holder, { Position = UDim2.new(0.5, card.x, CARD_Y, 0) }, 0.3 * k, Enum.EasingStyle.Back)
	tween(card.scale, { Scale = 1 }, 0.3 * k, Enum.EasingStyle.Back)
	tween(card.glow, { ImageTransparency = 0.15 }, 0.3 * k)
	Audio.PlayUI("GeneticsPop")
	AlterFX.Sound("Chime", { pitch = 0.85 + card.rarity.index * 0.06, volume = 0.8 })
	if not wait_(0.25 * k) then return end
	AlterFX.Ring(fxLayer, hex(card.rarity.color), 60, 360, 0.45, (centerOf(card.holder)))
	wait_(0.35 * k)
end

-- Rare: an orb floats in, pulses twice, bursts into the card with a small UI shake and sparks (~1.2 s)
local function revealRare(card)
	local orb = makeOrb(card, 46)
	AlterFX.Sound("Riser", { fadeIn = 0.15, delay = 0.1 })
	if not wait_(0.3) then return end
	if not pulse(orb, 1.3, 0.3, 1) then return end
	if not pulse(orb, 1.45, 0.3, 2) then return end
	local at, x, y = centerOf(orb.frame)
	burst(card, orb, 0.4, 1.08, 0.3)
	AlterFX.Ring(fxLayer, fxColor(card.rarity), 60, 520, 0.5, at)
	AlterFX.UIParticles(fxLayer, fxTheme(card.rarity), 12, 0.1, { burst = true, peak = true, x = x, y = y })
	shakeUI({ card.holder }, 4, 0.2)
	AlterFX.Sound("ImpactPunch", { volume = 0.7 })
	AlterFX.Sound("Shimmer")
	wait_(0.3)
end

-- Epic: slower, bigger pulses, a purple tint creeps in from the edges, a bigger burst (~1.8 s)
local function revealEpic(card)
	local color = fxColor(card.rarity)
	local tint = edgeTint(color, 0.32, 1.4, 0.35)
	local orb = makeOrb(card, 54)
	AlterFX.Sound("Swell", { fadeIn = 0.3, volume = 0.7 })
	AlterFX.Sound("Riser", { fadeIn = 0.2, delay = 0.55 })
	if not wait_(0.4) then return end
	if not pulse(orb, 1.5, 0.5, 1) then return end
	if not pulse(orb, 1.75, 0.55, 2) then return end
	local at, x, y = centerOf(orb.frame)
	burst(card, orb, 0.3, 1.1, 0.35)
	AlterFX.Ring(fxLayer, color, 70, 700, 0.6, at)
	task.delay(0.1, function() AlterFX.Ring(fxLayer, Color3.new(1, 1, 1), 50, 480, 0.5, at) end)
	AlterFX.UIParticles(fxLayer, fxTheme(card.rarity), 24, 0.1, { burst = true, peak = true, scale = 1.4, x = x, y = y })
	shakeUI({ card.holder }, 7, 0.3)
	AlterFX.Sound("ImpactPunch", { volume = 0.8 })
	AlterFX.Sound("ImpactSub", { volume = 0.7 })
	AlterFX.Sound("Shimmer")
	for _, f in ipairs(tint) do tween(f, { BackgroundTransparency = 0.6 }, 0.6) end
	wait_(0.35)
end

-- the rarity's own extras after a Legendary+ landing (rarity.reveal)
local function extras(card)
	local rarity = card.rarity
	local kind = rarity.reveal
	local theme = fxTheme(rarity)
	if kind == "explosion" then
		AlterFX.Sound("Brass")
		AlterFX.ScreenFX(fxLayer, { accent = theme.accent, particle = theme.particle }, "rise", 1.5)
	elseif kind == "lightning" then
		AlterFX.Sound("Thunder")
		AlterFX.Sound("Crackle", { delay = 0.05 })
		shakeUI({ card.holder }, 6, 0.4)
		AlterFX.ScreenFX(fxLayer, { accent = hex(rarity.color2 or rarity.color), particle = theme.particle }, "storm", 1.4)
	elseif kind == "dark" then
		AlterFX.Sound("ImpactSub")
		AlterFX.ScreenFX(fxLayer, { accent = theme.accent, particle = theme.particle }, "rise", 1.5)
	elseif kind == "cosmic" then
		AlterFX.Sound("CosmicSwell", { delay = 0.1 })
		AlterFX.Sound("CheerBig", { delay = 0.4 })
		AlterFX.ScreenFX(fxLayer, { accent = theme.accent, particle = { texture = "spark", color = Color3.new(1, 1, 1), motion = "drift" } }, "legend", 2)
		AlterFX.UIParticles(fxLayer, { accent = theme.accent, particle = { texture = "spark", color = Color3.fromHex("#FFF3C4"), motion = "fall" } }, 18, 2)
	end
end

-- Legendary and better: the screen darkens around the orb, the pulses slow almost to a stop, a hard white flash, rays and a
-- shockwave, the card lands with an overshoot (1.2 -> 1.0), the NAME slams in last (~3 s)
local function revealLegend(card)
	local color = fxColor(card.rarity)
	local reduced = Theme.ReducedMotion()
	tween(spotlight, { ImageTransparency = 1 }, 0.8)
	local dark = edgeTint(Color3.new(0, 0, 0), 0.44, 1.8, 0)
	local orb = makeOrb(card, 64)
	AlterFX.Sound("Swell", { fadeIn = 0.4 })
	AlterFX.Sound("Riser", { fadeIn = 0.2, delay = 1.45 })
	if not wait_(0.45) then return end
	-- slower and slower
	for i, t in ipairs({ 0.36, 0.5, 0.74 }) do
		if not pulse(orb, 1.3 + i * 0.15, t, i) then return end
	end
	-- the held breath: it shrinks a little, nearly still
	tween(orb.scale, { Scale = 0.8 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if not wait_(0.3) then return end
	-- THE flash
	local at, x, y = centerOf(orb.frame)
	whiteFlash.BackgroundTransparency = if reduced then 0.4 else 0
	tween(whiteFlash, { BackgroundTransparency = 1 }, if reduced then 0.25 else 0.7)
	for _, f in ipairs(dark) do tween(f, { BackgroundTransparency = 0.5 }, 0.8) end
	tween(spotlight, { ImageTransparency = 0.75 }, 0.6)
	screenRays(at, color)
	AlterFX.Ring(fxLayer, color, 80, 950, 0.8, at)
	task.delay(0.12, function() AlterFX.Ring(fxLayer, Color3.new(1, 1, 1), 60, 650, 0.6, at) end)
	AlterFX.UIParticles(fxLayer, fxTheme(card.rarity), 26, 0.1, { burst = true, peak = true, scale = 1.5, x = x, y = y })
	card.name.Visible = false
	burst(card, orb, 0.2, 1.2, 0.45)
	shakeUI({ card.holder }, 10, 0.35)
	AlterFX.Sound("FlashBoom")
	AlterFX.Sound("FlashPunch")
	AlterFX.Sound("Sparkle", { delay = 0.05 })
	if not wait_(0.45) then return end
	-- the NAME slams in last
	card.nameScale.Scale = 2.6
	card.name.Visible = true
	tween(card.nameScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if not wait_(0.16) then return end
	AlterFX.Sound("TitleHit")
	AlterFX.Sound("Stamp", { volume = 0.9 })
	shakeUI({ card.holder }, 5, 0.15)
	extras(card)
	wait_(0.3)
end

local function clearTransient()
	for _, o in ipairs(transient) do
		if o.Parent then o:Destroy() end
	end
	table.clear(transient)
end

-- results = the server's list; quick = auto roll (a quick reveal and it closes by itself, unless Epic or better came)
local function play(results, quick: boolean)
	busy = true
	skip = false
	closeWanted = false
	for _, c in ipairs(cards) do c.holder:Destroy() end
	cards = {}
	clearTransient()
	for _, child in ipairs(fxLayer:GetChildren()) do child:Destroy() end
	overlay.Enabled = true
	continueText.Visible = false
	dim.BackgroundTransparency = 1
	spotlight.ImageTransparency = 1
	whiteFlash.BackgroundTransparency = 1
	tween(dim, { BackgroundTransparency = 0 }, 0.2) -- (hides the Agency behind it)
	tween(spotlight, { ImageTransparency = 0.82 }, 0.3)
	-- (X3: the best one last)
	local order = {}
	for i, result in ipairs(results) do
		local trainer = Trainers.ById[result.id]
		if trainer then table.insert(order, { result = result, rank = rarityOf(trainer).index, i = i }) end
	end
	table.sort(order, function(a, b) return if a.rank ~= b.rank then a.rank < b.rank else a.i < b.i end)
	if #order == 0 then
		busy = false
		overlay.Enabled = false
		return 0
	end
	local best = order[#order].rank
	local fast = quick and best < Trainers.RarityById[Trainers.AutoStopRarity].index
	wait_(0.15)
	-- one at a time in the middle
	for _, entry in ipairs(order) do
		if skip then break end
		clearTransient()
		tween(spotlight, { ImageTransparency = 0.82 }, 0.2)
		local card = makeCard(entry.result, 1, 1)
		cards = { card }
		local tier = if fast then 1 else tierOf(card.rarity)
		if tier == 4 then revealLegend(card)
		elseif tier == 3 then revealEpic(card)
		elseif tier == 2 then revealRare(card)
		else revealDrop(card, fast) end
		if skip then break end
		settle(card)
		if #order > 1 then
			-- a moment to look, then out of the way for the next
			if not wait_(if fast then 0.35 else 0.6) then break end
			tween(card.scale, { Scale = 0.5 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			if not wait_(0.15) then break end
			card.holder:Destroy()
			cards = {}
		end
	end
	if #order > 1 then
		-- all of them together (a skip lands here at once)
		for _, c in ipairs(cards) do c.holder:Destroy() end
		cards = {}
		clearTransient()
		local instant = skip
		for i, entry in ipairs(order) do
			local card = makeCard(entry.result, i, #order)
			table.insert(cards, card)
			if instant then
				settle(card, true)
			else
				card.holder.Visible = true
				card.scale.Scale = 0.6
				task.delay((i - 1) * 0.06, function() settle(card) end)
			end
		end
		if not instant then
			AlterFX.Sound("ImpactPunch", { volume = 0.5 })
			AlterFX.Sound("Shimmer")
		end
	else
		if not cards[1] then cards = { makeCard(order[1].result, 1, 1) } end
		if skip then
			clearTransient()
			settle(cards[1], true)
		end
	end
	if skip then
		whiteFlash.BackgroundTransparency = 1
		spotlight.ImageTransparency = 0.82
	end
	-- done: wait for a tap (auto roll: closes by itself unless something big came)
	busy = false
	skip = false
	continueText.Visible = true
	task.spawn(function()
		while continueText.Visible do
			tween(continueText, { TextTransparency = 0.5 }, 0.6)
			task.wait(0.6)
			tween(continueText, { TextTransparency = 0 }, 0.6)
			task.wait(0.6)
		end
		continueText.TextTransparency = 0
	end)
	if fast then
		local t1 = os.clock()
		while os.clock() - t1 < 0.6 and not closeWanted do task.wait() end
		closeWanted = true
	end
	while not closeWanted do task.wait() end
	continueText.Visible = false
	tween(dim, { BackgroundTransparency = 1 }, 0.2)
	tween(spotlight, { ImageTransparency = 1 }, 0.2)
	for _, card in ipairs(cards) do tween(card.scale, { Scale = 0.85 }, 0.15) end
	task.wait(0.2)
	overlay.Enabled = false
	for _, c in ipairs(cards) do c.holder:Destroy() end
	cards = {}
	clearTransient()
	return best
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
local function requestRoll(count: number, auto: boolean): boolean
	if waiting or busy or overlay.Enabled then return false end
	local cost = price() * count
	if (data().coins or 0) < cost then
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
		if (data().coins or 0) < price() then
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
	end
end)
menuButton.Activated:Connect(function()
	if modal.isOpen() then modal.close() else UIBus.PanelOpened("Trainers") showTab(tab) open() end
end)
UIBus.RegisterPanel("Trainers", function() modal.close() end)
-- (tab "My" = MY TRAINERS; nothing = the Agency)
UIBus.OpenAgency.Event:Connect(function(openTab)
	if UIBus.IsLocked and UIBus.IsLocked("Trainers") then UIBus.ShowLocked("Trainers") return end -- (prompt 39: still locked, GuideClient)
	if not modal.isOpen() then UIBus.PanelOpened("Trainers") end
	showTab(if openTab == "My" then "My" else "Agency")
	open()
end)
ClientData.Changed:Connect(function(path)
	if modal.isOpen() and (path[1] == "coins" or path[1] == "trainers" or path[1] == "growthSpurts") then refresh() end
end)
player:GetAttributeChangedSignal("TrainerSlots"):Connect(function() if modal.isOpen() then refresh() end end)

------------------------------------------------------------------------
-- Server events
------------------------------------------------------------------------
local function announce(info)
	local rarity = Trainers.RarityById[info.rarity]
	local trainer = Trainers.ById[info.trainer]
	if not rarity or not trainer then return end
	local who = if info.userId == player.UserId then "You" else tostring(info.name)
	-- (owner, 22 Oct: a hidden trainer's name stays "???" for players who don't own him)
	local name = if rarity.hidden and info.userId ~= player.UserId and not ownsAny(trainer.id) then "???" else trainer.name
	local text = who .. " pulled " .. (if rarity.id == "Eternal" or rarity.id == "Epic" then "an " else "a ") .. string.upper(rarity.name) .. " trainer: " .. name .. "!"
	-- a chat-style line for everyone
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(string.format('<font color="#%s"><b>%s</b></font>', hex(rarity.color2 or rarity.color):ToHex(), text))
		end
	end)
	-- (your own pull: the reveal is the celebration; only the chat line)
	if info.userId == player.UserId then return end
	if rarity.announce == "banner" then
		Notify.Reward(string.upper(rarity.name) .. " PULL!", text, "star", hex(rarity.color2 or rarity.color), "TitleUnlocked", "trainerpull")
	else
		Notify.Toast(string.upper(rarity.name) .. " pull", text, "star", hex(rarity.color), "trainerpull")
	end
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
	elseif kind == "Discovered" then
		-- (prompt 33) a player reached a stage for the first time: "Rong discovered COLOSSUS!" for everyone
		local stage = Trainers.Stages[tonumber(info.stage) or 0]
		if stage then
			local who = if info.userId == player.UserId then "You" else tostring(info.name)
			local text = who .. " discovered " .. stage.name .. "!"
			pcall(function()
				local channels = TextChatService:FindFirstChild("TextChannels")
				local general = channels and channels:FindFirstChild("RBXGeneral")
				if general then general:DisplaySystemMessage(string.format('<font color="#%s"><b>%s</b></font>', hex(stage.color):ToHex(), text)) end
			end)
			if info.userId ~= player.UserId then Notify.Toast("New evolution", text, "star", hex(stage.color), "trainerdiscover") end
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
