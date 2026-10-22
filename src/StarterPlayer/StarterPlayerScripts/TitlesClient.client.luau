-- TitlesClient: the INVENTORY tile and window (owner, 14 Oct: was the Titles window), and the unlock toasts.
-- (prompt 28, 21 Oct: 7 tabs -> 3; prompt 39b, 22 Oct: 4) Tabs ITEMS | GEAR | AURAS | LOOKS, all there from the start; the
-- last one opened is remembered (settings.inventoryTab). (prompt 39b) Not open yet = a padlock and a teaser on tap
-- (Config/Guides.TabLocks: GEAR from Growth Spurt 2 or once you own something to wear, AURAS from Growth Spurt 3 or once
-- you own an aura); the window opens on the first open tab (Kit.OpenTab), never an empty page.
-- Trainers are not here: they live in the TRAINERS window (TrainerClient, its MY TRAINERS tab).
--   ITEMS (Shared/UI/BoostsPanel): the boost items you own with USE and EQUIP, DNA Tokens ("Genetics"), and the boosts
--     running now (passes, Endless Stamina, drinks, a Server Boost) with their timers. Empty: "Get boosts at the PUMP SHOP".
--   GEAR (Shared/UI/GearPanel): what you own to wear (PUMP SHOP gear and apparel, the clothing store's gear).
--   LOOKS: chips on top (ALTERS / TITLES; prompt 39b: the ALL chip is gone, AURAS is its own tab; ALTERS locked before 7'0"):
--     ALTERS  Shared/UI/AltersPanel.
--   AURAS: on the left the picked aura big (its art, name, rarity, how to get it, the action button) and "Aura: Off"; on
--             the right a grid of aura tiles (art, name, rarity, and its state: EQUIP / EQUIPPED / a coin price / AURA PACK
--             or VIP (opens that pass's purchase) / how to earn it). The preview is your own character behind the window
--             wearing the picked aura at full power (Roblox doesn't draw particles inside a ViewportFrame; AURA.preview).
--     TITLES  a grid of cards (it scrolls): the rarity word in its color (COMMON gray, UNCOMMON green, RARE blue, EPIC
--             purple, LEGENDARY gold, SECRET red), the title's name, and owned: EQUIPPED (gold, tap = take it off) or EQUIP
--             (green, tap = wear it above your head); locked: the name faded and a lock (secret titles show "???"); tapping
--             it says how to earn it. Titles are kept forever and never bought.
-- Text fit (owner, 14 Oct): every label stays inside its card with 8 px each side; names and rarity words shrink to fit
-- one line (Kit.Fit), how-to-unlock text is the body font in sentence case, up to 2 lines.
-- (prompt 31) UNDISCOVERED (Shared/UI/Discovery): auras you can't see yet, titles that aren't yours or next in their
-- category (secret ones until yours) and alters after the next one show a dark "?" tile, "???" and UNDISCOVERED; each
-- list counts "x / y DISCOVERED"; something new turns over with a gold burst the first time you open its list, and its
-- tab (and chip) has a red dot until then.
-- UIBus.OpenInventory(tab, auraId?) opens it on a tab; the old tab names still work ("Boosts" -> ITEMS, "Titles" / "Auras"
-- / "Alters" -> LOOKS on that chip, "Trainers" -> the TRAINERS window).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Titles = require(Shared.Config.Titles)
local Auras = require(Shared.Config.Auras)
local Meals = require(Shared.Config.Meals)
local Boosts = require(Shared.Config.Boosts)
local Monetization = require(Shared.Config.Monetization)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local AlterFX = require(Shared.VFX.AlterFX)
local Discovery = require(Shared.UI.Discovery)
local AltersPanel = require(Shared.UI.AltersPanel)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local New, Colors = Theme.New, Theme.Colors
local player = Players.LocalPlayer

-- the window's rarity colors (mockup 08)
local RARITY_COLOR = Theme.RarityColor -- (prompt 40: the one rarity table)
local CARD = Vector2.new(152, 92) -- (prompt 28: bigger, 5 a row; prompt 40: nameplates)
local PAD = 8 -- every label keeps this far from its card's edges
-- (prompt 28) a tab name, old or new -> the tab, and the LOOKS chip
local TAB_OF = { Items = "Items", Boosts = "Items", Gear = "Gear", Auras = "Auras", Looks = "Looks", Alters = "Looks", Titles = "Looks" }
local LOOK_OF = { Alters = "Alters", Titles = "Titles" }
local TABS = { "Items", "Gear", "Auras", "Looks" }
local LOOKS_CHIPS = { "Alters", "Titles" }
local CHIP_H = Kit.TabHeight

local menuButton = SideMenu.Add("Inventory", "Inventory", nil, 2)

local tab = "Items"
local look = "Alters" -- the LOOKS chip
local refresh -- (below)
-- (840 x 290: room for 5 big tiles a row, and the LOOKS chips over the Auras preview card; it still fits a 667 x 375 phone)
local modal = Kit.Modal({ name = "Inventory", title = "Inventory", icon = "backpack", width = 840, height = 290, displayOrder = 25,
	tabs = { { id = "Items", text = "Items" }, { id = "Gear", text = "Gear", lock = "Inventory/Gear" }, { id = "Auras", text = "Auras", lock = "Inventory/Auras" },
		{ id = "Looks", text = "Looks" } },
	onTab = function(id)
		if tab ~= id then
			tab = id
			-- remembered for next time (saved with the settings; the server only takes the three tab names)
			Remotes.PlayerAction:FireServer("SetSettings", { inventoryTab = id })
		end
		refresh()
	end })
local countLabel = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 14, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -56, 0, 14), Size = UDim2.fromOffset(200, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = modal.panel })

------------------------------------------------------------------------
-- LOOKS tab: the chips, and the place the four views share under them
------------------------------------------------------------------------
local LOOKS = {}
LOOKS.frame = New("Frame", { Name = "Looks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = modal.body })
local chipRow, selectChip = Kit.Tabs({ { id = "Alters", text = "Alters", lock = "Looks/Alters" }, { id = "Titles", text = "Titles" } },
	function(id)
		look = id
		Audio.PlayUI("Click")
		refresh()
	end, { Name = "Chips", Size = UDim2.fromOffset(0, CHIP_H), Parent = LOOKS.frame })
LOOKS.body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, CHIP_H + 8), Size = UDim2.new(1, 0, 1, -(CHIP_H + 8)),
	Parent = LOOKS.frame })

------------------------------------------------------------------------
-- LOOKS > TITLES
------------------------------------------------------------------------
local grid = New("ScrollingFrame", { Name = "Titles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = LOOKS.body }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(CARD.X, CARD.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})

local cards = {}
local ordered = table.clone(Titles.List)
table.sort(ordered, function(a, b)
	local ra, rb = Titles.Rarities[a.rarity].order, Titles.Rarities[b.rarity].order
	if ra ~= rb then return ra < rb end
	return table.find(Titles.List, a) < table.find(Titles.List, b)
end)

-- (prompt 40, mockups inv_titles / titles_styles) each title is a nameplate: a tile tinted in its rarity colour, the
-- rarity small top-left, the name big in its colour with a dark stroke, a thin bar in the colour, EQUIP (green) /
-- EQUIPPED (dark, gold edge) at the bottom; locked = dimmed, a lock top-right and the condition at the bottom. A tap on
-- a locked one shows how to get it.
for index, title in ipairs(ordered) do
	local color = RARITY_COLOR[title.rarity] or RARITY_COLOR.Common
	local card, api = Kit.RewardTile(color, { Name = title.id, LayoutOrder = index, Parent = grid })
	api.art.Visible = false
	api.sub.Text = string.upper(title.rarity)
	api.sub.Visible = true
	api.sub.AnchorPoint = Vector2.new(0, 0)
	api.sub.Position = UDim2.fromOffset(7, 5)
	api.sub.Size = UDim2.new(1, -30, 0, 11)
	api.sub.TextXAlignment = Enum.TextXAlignment.Left
	api.sub.TextSize = 10
	api.name.AnchorPoint = Vector2.new(0.5, 0)
	api.name.Position = UDim2.new(0.5, 0, 0, 18)
	api.name.Size = UDim2.new(1, -10, 0, 30)
	api.name.Text = string.upper(title.name)
	api.name.TextColor3 = if title.rarity == "Common" then Colors.Text else color:Lerp(Color3.new(1, 1, 1), 0.15)
	Kit.Fit(api.name, 19, 11)
	local bar = New("Frame", { Name = "Bar", BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 51),
		Size = UDim2.new(0.8, 0, 0, 3), ZIndex = 3, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	api.pill.Size = UDim2.new(1, -14, 0, 22)
	local lock = Pieces.Icon("lock", Colors.Text, { Name = "Lock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(15, 15),
		ZIndex = 5, Parent = card })
	lock:SetAttribute("KeepColor", true)
	cards[title.id] = { card = card, api = api, bar = bar, lock = lock, title = title, overlay = Discovery.Overlay(card) }
	card.Activated:Connect(function()
		local data = ClientData.Get()
		if not data.titles.owned[title.id] then
			local hidden = cards[title.id].overlay.Visible
			Notify.Toast(if hidden then "Undiscovered" else title.name, if hidden then "Keep playing to find it." else ("How to get: " .. title.description),
				"lock", color, "titleinfo")
			return
		end
		Remotes.PlayerAction:FireServer("EquipTitle", data.titles.equipped ~= title.id and title.id or nil)
	end)
end

------------------------------------------------------------------------
-- AURAS (prompt 40, mockup inv_auras): a header "OWNED x / y", a grid of wide tiles (the orb big on the left, the name,
-- the rarity in its colour, an EQUIP / EQUIPPED / requirement pill) and a detail panel on the right (the orb big, the
-- name, the rarity, the benefit pill when the aura has one, a tall EQUIP / EQUIPPED button, the SHOW EFFECT switch:
-- off hides your own aura's look for you, "Boost stays active when hidden."). Tiles: owned = in its colour; the next
-- one to earn and the store auras (coins / a pass) = dark with its requirement; the rest = dark "???" tiles with a
-- small spark going round.
-- (owner, 23 Oct) The detail panel is the ALTERS one's twin (same width, padding and spacing; premium, not chunky): the
-- aura's own moving background (Shared/UI/AuraBackdrop) with the outline in its colour, the orb centred with its glow, the
-- name white and stroked like "PUMPED", the benefit in a slim dark pill outlined in its colour ("BOOSTS +10% LONGER"),
-- "RARE · AURA" small and gray (the rarity in its colour), a graphite button (EQUIP / EQUIPPED: thin gold outline and
-- gold words; a price or the pass when it's for sale), and a slim SHOW EFFECT switch in its colour. A "???" aura: the same
-- panel, its theme dark and still, the orb a silhouette, "???".
------------------------------------------------------------------------
local AURA = { tiles = {}, picked = Auras.List[1].id }
local DETAIL_W = 196
local AURA_TILE = Vector2.new(146, 92)
AURA.frame = New("Frame", { Name = "Auras", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = modal.body }) -- (prompt 39b: its own tab)
AURA.header = Kit.GoldText(Kit.Text({ Name = "Owned", Text = "", Font = "Chunky", TextSize = 17, Size = UDim2.new(1, -(DETAIL_W + 10), 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = AURA.frame }))
AURA.grid = New("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -(DETAIL_W + 10), 1, -24), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = AURA.frame }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(AURA_TILE.X, AURA_TILE.Y), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6), PaddingRight = UDim.new(0, 5) }),
})
-- the detail panel (right): the ALTERS detail's twin (AltersPanel: 196 wide, the same rows)
local AuraBackdrop = require(Shared.UI.AuraBackdrop)
AURA.detail = New("Frame", { Name = "Detail", BackgroundColor3 = Color3.fromHex("#1B1B20"), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, DETAIL_W, 1, 0), Parent = AURA.frame }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
AURA.backdrop = AuraBackdrop.New(AURA.detail, 12, UDim2.new(0.5, 0, 0, 34))
-- the orb, centred, with its own glow (a gray rim behind its silhouette for a "???" aura)
AURA.glow = AlterFX.Image(AURA.detail, "ember", { Name = "OrbGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(104, 104),
	ImageTransparency = 0.35, ZIndex = 3 })
AURA.bigRim = New("ImageLabel", { Name = "Rim", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34),
	Size = UDim2.fromOffset(67, 67), ScaleType = Enum.ScaleType.Fit, ImageColor3 = Color3.fromHex("#8A878F"), Visible = false, ZIndex = 4, Parent = AURA.detail })
AURA.bigIcon = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34),
	Size = UDim2.fromOffset(60, 60), ScaleType = Enum.ScaleType.Fit, ZIndex = 5, Parent = AURA.detail })
-- the name: white and stroked, the size and font of the alters' "PUMPED"
AURA.bigName = Kit.Fit(Kit.Text({ Name = "Name", Text = "", Font = "Chunky", TextSize = 22, Position = UDim2.fromOffset(PAD, 66), Size = UDim2.new(1, -2 * PAD, 0, 24),
	ZIndex = 6, Parent = AURA.detail }), 22, 14)
-- the benefit: a slim dark pill outlined in the aura's colour, white words (like "GAINS X1.15")
AURA.benefit = New("Frame", { Name = "Benefit", BackgroundColor3 = Color3.fromHex("#1E1B20"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 91),
	Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = AURA.detail }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Name = "Edge", Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
})
AURA.benefitText = Kit.Text({ Name = "Text", Text = "", Font = "Chunky", TextSize = 14, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7,
	Parent = AURA.benefit })
-- "RARE · AURA": small and gray, the rarity word in its colour (like "ALTER 1 · HUMAN TIER")
AURA.bigRarity = Kit.Text({ Name = "Rarity", Text = "", Font = "Chunky", TextSize = 12, TextColor3 = Colors.Muted, RichText = true, Position = UDim2.fromOffset(PAD, 114),
	Size = UDim2.new(1, -2 * PAD, 0, 14), ZIndex = 6, Parent = AURA.detail }) -- (no Kit.Fit: it would count the colour tags as letters)
-- how to get it (not yours yet)
AURA.bigHow = Kit.Fit(Kit.Text({ Name = "How", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Color3.fromHex("#D9D2D5"), TextWrapped = true,
	Position = UDim2.fromOffset(PAD, 131), Size = UDim2.new(1, -2 * PAD, 0, 26), ZIndex = 6, Parent = AURA.detail }), 11, 9, 2)
-- the button: graphite with a thin outline (like the alters' WORN); EQUIPPED = a thin gold outline and gold words
AURA.action = New("TextButton", { Name = "Action", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#232027"), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -38), Size = UDim2.new(1, -20, 0, 30), ZIndex = 6, Parent = AURA.detail }, {
	New("UICorner", { CornerRadius = UDim.new(0, 10) }),
})
AURA.actionEdge = New("UIStroke", { Name = "Edge", Color = Color3.fromHex("#4A4652"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = AURA.action })
AURA.actionText = Kit.Text({ Name = "Label", Text = "", Font = "Title", KeepItalic = true, TextSize = 15, Upper = true, Size = UDim2.fromScale(1, 1), ZIndex = 7,
	Parent = AURA.action })
Theme.BindPress(AURA.action)
-- SHOW EFFECT: one slim line, the label left and a sleek pill switch right (in the aura's colour when on). Off = your own
-- aura's look is hidden for you (settings.myAura; AuraClient), the aura stays equipped
local showRow = New("Frame", { Name = "ShowEffect", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -17),
	Size = UDim2.new(1, -2 * PAD - 4, 0, 18), ZIndex = 6, Parent = AURA.detail })
Kit.Text({ Name = "Label", Text = "Show effect", Font = "Strong", TextSize = 12, TextColor3 = Color3.fromHex("#D9D6DE"), Size = UDim2.new(1, -44, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = showRow })
local switch = New("TextButton", { Name = "Switch", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#2A2730"), AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 18), ZIndex = 6, Parent = showRow }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = Color3.fromHex("#3A3640"), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
-- (a bigger invisible hit area around the small switch: touch targets stay >= 44 px with the window's scale)
New("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 24, 1, 22), ZIndex = 8, Parent = switch }).Activated:Connect(function() switch:SetAttribute("Tap", (switch:GetAttribute("Tap") or 0) + 1) end)
local knob = New("Frame", { Name = "Knob", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
	Size = UDim2.fromOffset(14, 14), ZIndex = 7, Parent = switch }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local showOn, showColor = true, Colors.Green
local function paintSwitch(animate: boolean?)
	local goal = { BackgroundColor3 = if showOn then showColor else Color3.fromHex("#2A2730") }
	local knobAt = if showOn then UDim2.new(1, -16, 0.5, 0) else UDim2.new(0, 2, 0.5, 0)
	if animate then
		Theme.Tween(switch, goal, 0.15)
		Theme.Tween(knob, { Position = knobAt }, 0.15)
	else
		switch.BackgroundColor3 = goal.BackgroundColor3
		knob.Position = knobAt
	end
end
local function setShowToggle(on: boolean, color: Color3?)
	showOn = on
	if color then showColor = color end
	paintSwitch(false)
end
local function flipShow()
	showOn = not showOn
	paintSwitch(true)
	Audio.PlayUI("Click")
	Remotes.PlayerAction:FireServer("SetSettings", { myAura = if showOn then "On" else "Off" })
end
switch.Activated:Connect(flipShow)
switch:GetAttributeChangedSignal("Tap"):Connect(flipShow)
local note = Kit.Text({ Name = "Note", Text = "Boost stays active when hidden.", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -2 * PAD, 0, 12), ZIndex = 6, Parent = AURA.detail })
note.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Italic)

function AURA.has(aura): boolean
	if aura.unlock.type == "pass" then return player:GetAttribute("Pass_" .. aura.unlock.pass) == true end
	local data = ClientData.Get()
	return data.auras ~= nil and data.auras.owned ~= nil and data.auras.owned[aura.id] ~= nil
end
function AURA.equipped(): string?
	local data = ClientData.Get()
	return data.auras and data.auras.equipped or nil
end
-- what the action button does for an aura: "equip", "equipped", "coins", "pass" or "locked" (+ its text and style)
function AURA.state(aura)
	if AURA.has(aura) then
		if AURA.equipped() == aura.id then return "equipped", "Equipped", "Quiet" end
		return "equip", "Equip", "Green"
	end
	local unlock = aura.unlock
	if unlock.type == "coins" then return "coins", Kit.Format(unlock.price), "Gold" end
	if unlock.type == "pass" then
		local pass = Monetization.PassByKey[unlock.pass]
		if pass and pass.id then return "pass", if unlock.pass == "VIP" then "VIP" else "Aura Pack", "Red" end
	end
	return "locked", "Locked", "Disabled"
end
-- how each tile shows: "owned", "teased" (dark, its requirement) or "hidden" ("???")
function AURA.look(): { [string]: string }
	local looks = {}
	local nextEarned = nil
	for _, aura in ipairs(Auras.List) do
		local kind = aura.unlock.type
		if AURA.has(aura) then
			looks[aura.id] = "owned"
		elseif kind == "pass" or kind == "coins" then
			looks[aura.id] = "teased" -- (the Store shows these anyway)
		elseif not nextEarned then
			nextEarned = aura.id
			looks[aura.id] = "teased"
		else
			looks[aura.id] = "hidden"
		end
	end
	return looks
end
-- (prompt 31) the auras you can see (not "???"), for the reveal and the tab's red dot
function AURA.discovered(): { string }
	local ids = {}
	for id, kind in pairs(AURA.look()) do
		if kind ~= "hidden" then table.insert(ids, id) end
	end
	return ids
end
function AURA.act(aura, button)
	local kind = AURA.state(aura)
	if kind == "equip" then
		Remotes.PlayerAction:FireServer("AuraEquip", aura.id)
	elseif kind == "equipped" then
		Remotes.PlayerAction:FireServer("AuraEquip", nil)
	elseif kind == "coins" then
		if (ClientData.Get().coins or 0) < aura.unlock.price then
			Notify.Toast("Not enough coins", aura.name .. " costs " .. Kit.Format(aura.unlock.price) .. " coins", "coin", Colors.Red, "auracoins")
			local base = button.Position
			task.spawn(function()
				for _, dx in ipairs({ -6, 6, -5, 5, -3, 3, 0 }) do
					button.Position = base + UDim2.fromOffset(dx, 0)
					task.wait(0.035)
				end
				button.Position = base
			end)
			return
		end
		Remotes.PlayerAction:FireServer("AuraBuy", aura.id)
	elseif kind == "pass" then
		local pass = Monetization.PassByKey[aura.unlock.pass]
		if pass and pass.id then MarketplaceService:PromptGamePassPurchase(player, pass.id) end
	else
		Notify.Toast(aura.name, aura.how .. " to unlock it.", "lock", Colors.Muted, "aurainfo")
	end
end

local RARITY_TABLE = Theme.RarityColor
for index, aura in ipairs(Auras.List) do
	local color = RARITY_TABLE[aura.rarity] or RARITY_TABLE.Common
	local tile, api = Kit.RewardTile(color, { Name = aura.id, LayoutOrder = index, Parent = AURA.grid })
	-- wide: the orb on the left, the words on the right
	api.art.Image = aura.Icon
	api.art.AnchorPoint = Vector2.new(0, 0.5)
	api.art.Position = UDim2.new(0, 4, 0.5, 0)
	api.art.Size = UDim2.fromOffset(66, 66)
	for _, label in ipairs({ api.name, api.sub }) do
		label.AnchorPoint = Vector2.new(0, 0)
		label.Size = UDim2.new(1, -78, 0, 17)
	end
	api.name.Position = UDim2.fromOffset(72, 10)
	api.name.Size = UDim2.new(1, -98, 0, 17) -- (clear of the check in the corner)
	api.name.Text = string.upper(aura.name)
	api.sub.Position = UDim2.fromOffset(72, 32)
	api.sub.Size = UDim2.new(1, -78, 0, 13)
	api.sub.Text = string.upper(aura.rarity)
	api.sub.Visible = true
	api.pill.AnchorPoint = Vector2.new(0, 1)
	api.pill.Position = UDim2.new(0, 72, 1, -10)
	-- "???": a small spark going round an empty dark ring
	local ring = New("Frame", { Name = "Mystery", BackgroundColor3 = Color3.fromHex("#0A090B"), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.fromOffset(50, 50), Visible = false, ZIndex = 3, Parent = tile }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.5), Thickness = 1.5 }),
	})
	local spark = New("Frame", { Name = "Spark", BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), ZIndex = 4, Parent = ring },
		{ New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local question = Kit.Text({ Name = "Question", Text = "???", Font = "Chunky", TextSize = 15, TextColor3 = color, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -10, 0, 17), Visible = false, ZIndex = 3, Parent = tile })
	AURA.tiles[aura.id] = { tile = tile, api = api, aura = aura, ring = ring, spark = spark, question = question, overlay = Discovery.Overlay(tile) }
	tile.Activated:Connect(function()
		local changed = AURA.picked ~= aura.id
		AURA.picked = aura.id
		refresh()
		if changed then Kit.DetailIn(AURA.detail) end -- (prompt 54; the bounce + sound: Kit.RewardTile)
	end)
end
-- the sparks go round (only while the tab is open)
task.spawn(function()
	while true do
		task.wait(0.05)
		if modal.isOpen() and tab == "Auras" then
			local angle = os.clock() * 3
			for _, t in pairs(AURA.tiles) do
				if t.ring.Visible then t.spark.Position = UDim2.new(0.5 + 0.5 * math.cos(angle), 0, 0.5 + 0.5 * math.sin(angle), 0) end
			end
		end
	end
end)
AURA.action.Activated:Connect(function()
	local aura = Auras.ById[AURA.picked]
	if aura and AURA.look()[aura.id] ~= "hidden" then AURA.act(aura, AURA.action) end
end)

function AURA.refresh()
	local looks = AURA.look()
	local discovered = AURA.discovered()
	local fresh = Discovery.New("Auras", discovered)
	for _, aura in ipairs(Auras.List) do
		local t = AURA.tiles[aura.id]
		local kind, text = AURA.state(aura)
		local look = looks[aura.id]
		local hidden = look == "hidden"
		t.ring.Visible = false
		t.question.Visible = false
		t.overlay.Visible = hidden
		if fresh[aura.id] then Discovery.Reveal(t.tile, t.overlay) end
		t.api.art.Visible = not hidden
		t.api.name.Visible = not hidden
		t.api.sub.Visible = not hidden
		if look == "owned" then
			t.api:SetState(if kind == "equipped" then "equipped" else "normal")
			if kind == "equipped" then t.api:SetPill("Equipped", Color3.fromHex("#55525A")) else t.api:SetPill("Equip", Colors.Green) end
		else
			t.api:SetState("locked")
			if hidden then t.api.pill.Visible = false else t.api:SetRequirement(if kind == "coins" or kind == "pass" then text else aura.short) end
		end
		t.api.pill.Size = UDim2.new(1, -80, 0, 22)
		local pickScale = t.tile:FindFirstChild("PickScale") or New("UIScale", { Name = "PickScale", Parent = t.tile })
		pickScale.Scale = if AURA.picked == aura.id then 1 else 0.97
	end
	local aura = Auras.ById[AURA.picked] or Auras.List[1]
	local look = looks[aura.id]
	local kind, text = AURA.state(aura)
	local hidden = look == "hidden"
	local color = aura.colors[1]
	do
		local _, _, value = color:ToHSV()
		if value < 0.25 then color = aura.colors[2] or color end -- (a near-black first colour: the brighter one)
	end
	-- the theme (dark and still for "???"), the outline in the aura's colour
	AURA.backdrop:Set(aura, hidden)
	AURA.detail.Border.Color = if hidden then Color3.fromHex("#2E2A30") else color
	-- the orb: lit when it's yours, dimmer when it isn't yet, a black silhouette with a gray rim for "???"
	AURA.bigIcon.Image = aura.Icon
	AURA.bigRim.Image = aura.Icon
	AURA.bigRim.Visible = hidden
	AURA.bigIcon.ImageColor3 = if hidden then Color3.new(0, 0, 0) elseif look == "owned" then Color3.new(1, 1, 1) else Color3.fromRGB(150, 148, 156)
	AURA.glow.Visible = not hidden
	AURA.glow.ImageColor3 = color
	AURA.bigName.Text = if hidden then "???" else string.upper(aura.name)
	AURA.bigName.TextColor3 = Color3.new(1, 1, 1)
	-- the benefit pill when the aura has one (Config/Auras `bonus`, e.g. "Boosts +10% Longer")
	local bonus = aura.bonus
	AURA.benefit.Visible = bonus ~= nil and not hidden
	AURA.benefit.Edge.Color = color
	AURA.benefitText.Text = string.upper(bonus or "")
	-- "RARE · AURA" (the rarity in its colour)
	local rarityColor = RARITY_TABLE[aura.rarity] or Colors.Muted
	AURA.bigRarity.Text = if hidden then "UNDISCOVERED" else string.format('<font color="#%s">%s</font> · AURA', rarityColor:ToHex(), string.upper(aura.rarity))
	-- the rows close up when there's no benefit pill
	AURA.bigRarity.Position = UDim2.fromOffset(PAD, if AURA.benefit.Visible then 114 else 92)
	AURA.bigHow.Position = UDim2.fromOffset(PAD, if AURA.benefit.Visible then 131 else 109)
	AURA.bigHow.Visible = look ~= "owned" and kind ~= "coins" and kind ~= "pass" -- (for sale: the button says it)
	AURA.bigHow.Text = if hidden then "Keep playing to find it." else aura.how
	-- the button: EQUIP / EQUIPPED (gold) / the price / the pass / LOCKED
	AURA.action.Visible = not hidden
	local words = if kind == "coins" then text .. " coins" else text
	AURA.actionText.Text = string.upper(words)
	AURA.actionText.TextColor3 = if kind == "equipped" then Colors.Gold elseif kind == "locked" then Colors.Faint else Colors.Text
	AURA.actionEdge.Color = if kind == "equipped" then Colors.Gold else Color3.fromHex("#4A4652")
	AURA.action.Active = kind ~= "locked"
	local settings = ClientData.Get().settings or {}
	setShowToggle(settings.myAura ~= "Off", if hidden then Color3.fromHex("#6A676F") else color) -- (a "???" aura's colour stays secret)
	AURA.header.Text = "AURAS " .. #discovered .. " / " .. #Auras.List .. " DISCOVERED"
	countLabel.Text = ""
	Discovery.Seen("Auras", discovered)
end

-- the try-on: while the AURAS tab is open, your character wears the picked aura at full power (AuraClient reads the
-- local "AuraPreview" attribute; nothing is equipped or sent to the server)
function AURA.preview()
	local aura = modal.isOpen() and tab == "Auras" and Auras.ById[AURA.picked] or nil
	local want = aura and aura.vfx or nil
	if player:GetAttribute("AuraPreview") ~= want then player:SetAttribute("AuraPreview", want) end
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(AURA.preview) end)

------------------------------------------------------------------------
-- ITEMS tab (Shared/UI/BoostsPanel): the boost items, DNA Tokens and the boosts running now
------------------------------------------------------------------------
-- every boost the client can see: name, icon, color, what it does, and when it ends (nil = not running, math.huge = always)
local function serverNow() return Workspace:GetServerTimeNow() end
local function untilAttr(holder: Instance, name: string): number?
	local value = holder:GetAttribute(name)
	return if type(value) == "number" and value > serverNow() then value else nil
end
local function passOn(key: string): number?
	return if player:GetAttribute("Pass_" .. key) == true then math.huge else nil
end
local BOOSTS = {
	{ id = "DoubleGains", name = "2x EXP", icon = "zap", color = Colors.Gold, sub = "Pass", ends = function() return passOn("DoubleGains") end },
	{ id = "DoubleCoins", name = "2x Coins", icon = "coin", color = Colors.Gold, sub = "Pass", ends = function() return passOn("DoubleCoins") end },
	{ id = "VIP", name = "VIP", icon = "star", color = Colors.Purple, sub = "+10% coins", ends = function() return passOn("VIP") end },
	{ id = "EndlessStamina", name = "Endless Stamina", icon = "zap", color = Colors.Gold, sub = "No stamina drain",
		ends = function() return untilAttr(player, "EndlessStaminaUntil") end },
	{ id = "Shake", name = "Protein Shake", icon = Boosts.ById.Shake.icon, color = Colors.Teal, sub = "+50% gains", ends = function() return untilAttr(player, "ShakeEnds") end },
	{ id = "ServerBoost", name = "Server Boost", icon = "users", color = Colors.Red, sub = "2x gains for all",
		ends = function() return untilAttr(ReplicatedStorage, "ServerBoostEnds") end },
}
for _, item in ipairs(Boosts.Items) do
	if not item.shake then
		table.insert(BOOSTS, { id = "Item_" .. item.id, name = item.name, icon = item.icon, color = Color3.fromHex(item.color), sub = item.text,
			ends = function() return untilAttr(player, "Item_" .. item.id) end })
	end
end
for _, item in ipairs(Meals.Items) do
	table.insert(BOOSTS, { id = "Meal_" .. item.id, name = item.name, icon = item.uiIcon or "cup-soda", color = Color3.fromHex(item.uiColor or item.color),
		sub = string.gsub(item.sub or item.short or "", " · %d+ min$", ""), ends = function() return untilAttr(player, "Meal_" .. item.id) end })
end
local ITEMS_TAB = require(Shared.UI.BoostsPanel).Build(modal.body, {
	running = BOOSTS,
	dna = {
		count = function() return ClientData.Get().dnaTokens or 0 end,
		onUse = function()
			modal.close()
			menuButton:SetActive(false)
			UIBus.MenuPanelVisible:Fire(false)
			UIBus.OpenGenetics:Fire()
		end,
	},
})
-- (prompt 31) the titles you can see: yours, and the next one in each category (list order); secret ones only once yours
local function titlesDiscovered(data): ({ string }, { [string]: boolean })
	local owned = data.titles and data.titles.owned or {}
	local ids, set, nextOf = {}, {}, {}
	for _, title in ipairs(Titles.List) do
		local has = owned[title.id] ~= nil
		local shown = has
		if not has and title.rarity ~= "Secret" and not nextOf[title.category] then
			nextOf[title.category] = true
			shown = true
		end
		if shown then
			table.insert(ids, title.id)
			set[title.id] = true
		end
	end
	return ids, set
end
local aurasDiscovered = AURA.discovered
-- the red dots: the AURAS and LOOKS tabs, the ALTERS and TITLES chips
local tabRow = modal.panel:FindFirstChild("Tabs", true)
local function refreshDots()
	if not ClientData.IsLoaded() then return end
	local data = ClientData.Get()
	local newAuras = Discovery.HasNew("Auras", aurasDiscovered())
	local newTitles = Discovery.HasNew("Titles", (titlesDiscovered(data)))
	local newAlters = Discovery.HasNew("Alters", AltersPanel.Discovered(data))
	if tabRow then
		if tabRow:FindFirstChild("Auras") then Discovery.Dot(tabRow.Auras, newAuras) end
		if tabRow:FindFirstChild("Looks") then Discovery.Dot(tabRow.Looks, newTitles or newAlters) end
	end
	if chipRow:FindFirstChild("Alters") then Discovery.Dot(chipRow.Alters, newAlters) end
	if chipRow:FindFirstChild("Titles") then Discovery.Dot(chipRow.Titles, newTitles) end
end

local GearPanel = require(Shared.UI.GearPanel)
local GEAR_TAB = GearPanel.Build(modal.body)
local ALTERS_TAB = AltersPanel.Build(LOOKS.body) -- (prompt 21) the Body Alter skins

-- (prompt 39b: the ALL view that used Config/Alters here is gone)

------------------------------------------------------------------------
function refresh()
	local data = ClientData.Get()
	-- (prompt 39b) never on a locked tab or chip (one that locks again can't happen, but a stale saved one can)
	local openTab = Kit.OpenTab("Inventory", TABS, tab)
	if openTab ~= tab then
		tab = openTab
		modal.selectTab(tab)
	end
	local openLook = Kit.OpenTab("Looks", LOOKS_CHIPS, look)
	if openLook ~= look then
		look = openLook
		selectChip(look)
	end
	local looks = tab == "Looks"
	LOOKS.frame.Visible = looks
	ITEMS_TAB.frame.Visible = tab == "Items"
	GEAR_TAB.frame.Visible = tab == "Gear"
	grid.Visible = looks and look == "Titles"
	AURA.frame.Visible = tab == "Auras"
	ALTERS_TAB.frame.Visible = looks and look == "Alters"
	AURA.preview()
	countLabel.Text = ""
	if tab == "Items" then
		ITEMS_TAB.refresh()
		return
	elseif tab == "Gear" then
		GEAR_TAB.refresh()
		return
	elseif tab == "Auras" then
		AURA.refresh()
		refreshDots()
		return
	elseif look == "Alters" then
		ALTERS_TAB.refresh()
		refreshDots()
		return
	end
	local discoveredIds, discovered = titlesDiscovered(data)
	local fresh = Discovery.New("Titles", discoveredIds)
	for _, title in ipairs(Titles.List) do
		local c = cards[title.id]
		local has = data.titles.owned[title.id] ~= nil
		local equipped = data.titles.equipped == title.id
		c.overlay.Visible = not discovered[title.id]
		if fresh[title.id] then Discovery.Reveal(c.card, c.overlay) end
		local secret = title.rarity == "Secret"
		c.api.name.Text = string.upper((secret and not has) and "???" or title.name)
		c.lock.Visible = not has
		c.api:SetState(if equipped then "equipped" else "normal")
		c.api.check.Visible = equipped
		c.api.name.TextTransparency = if has then 0 else 0.35
		c.bar.BackgroundTransparency = if has then 0 else 0.5
		if equipped then
			c.api:SetPill("Equipped", Color3.fromHex("#2A272B"))
			c.api.pill.Edge.Color = Colors.Gold
		elseif has then
			c.api:SetPill("Equip", Colors.Green)
		else
			c.api:SetRequirement(if secret then "???" else title.description)
		end
		c.api.pill.Size = UDim2.new(1, -14, 0, 22)
	end
	-- (prompt 40) the header beside the chips (prompt 31: discovered)
	countLabel.Text = #discoveredIds .. " / " .. #Titles.List .. " DISCOVERED"
	Discovery.Seen("Titles", discoveredIds)
	refreshDots()
end

-- the timers tick while the Items tab is open
task.spawn(function()
	while true do
		task.wait(0.5)
		if modal.isOpen() and tab == "Items" then ITEMS_TAB.refresh() end
	end
end)

local function open()
	menuButton:SetActive(true)
	menuButton:SetDot(false)
	UIBus.MenuPanelVisible:Fire(true)
	refresh()
	modal.open()
	Audio.PlayUI("Whoosh")
end
local function close()
	if not modal.isOpen() then return end
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
	modal.close()
end
-- opens on the last tab used (saved), unless a caller asks for one
local function openOn(wanted: string?)
	if not wanted then
		local saved = ClientData.IsLoaded() and ClientData.Get().settings and ClientData.Get().settings.inventoryTab
		wanted = if TAB_OF[saved] then saved else tab
	end
	-- (old names: "Titles" opens LOOKS on its chip)
	if LOOK_OF[wanted :: string] then
		look = LOOK_OF[wanted :: string]
		selectChip(look)
	end
	tab = Kit.OpenTab("Inventory", TABS, TAB_OF[wanted :: string] or "Items") -- (prompt 39b: the first open tab)
	modal.selectTab(tab)
	if not modal.isOpen() then UIBus.PanelOpened("Inventory") open() else refresh() end
end
UIBus.RegisterPanel("Inventory", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else openOn(nil) end
end)
modal.closeButton.Activated:Connect(function()
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
end)
UIBus.OpenInventory.Event:Connect(function(openTab, auraId)
	if openTab ~= "Trainers" and UIBus.IsLocked and UIBus.IsLocked("Inventory") then UIBus.ShowLocked("Inventory") return end -- (prompt 39: still locked, GuideClient)
	-- (the Store's Auras tab opens the Auras tab, with that aura picked)
	if openTab == "Auras" and type(auraId) == "string" and Auras.ById[auraId] then AURA.picked = auraId end
	-- (prompt 28) trainers live in the TRAINERS window now
	if openTab == "Trainers" then
		UIBus.OpenAgency:Fire("My")
		return
	end
	openOn(if TAB_OF[openTab] then openTab else nil)
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if (key == "titles" or key == "auras" or key == "coins" or key == "items" or key == "dnaTokens" or key == "alter" or key == "cosmetics"
		or key == "growthSpurts") and modal.isOpen() then refresh() end
	if key == "titles" or key == "auras" or key == "alter" or key == "settings" then refreshDots() end
end)
task.spawn(function()
	ClientData.Get()
	refreshDots()
end)
player.AttributeChanged:Connect(function(name)
	if (string.sub(name, 1, 5) == "Pass_" or name == "Aura") and modal.isOpen() then refresh() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "AuraUnlocked" and type(info) == "table" then
		local aura = Auras.ById[info.id]
		if aura then
			Notify.Toast("New aura!", aura.name .. (if info.bought then " is yours. Wearing it now." else ". Wear it in Inventory > Auras."), "sparkles",
				RARITY_COLOR[aura.rarity] or Colors.Gold, "aura" .. aura.id)
			Audio.PlayUI("TitleUnlocked")
		end
	elseif kind == "AuraBuyFailed" and type(info) == "table" then
		Notify.Toast("Not enough coins", "That aura costs " .. Kit.Format(tonumber(info.price) or 0) .. " coins", "coin", Colors.Red, "auracoins")
	end
	if kind == "TitleUnlocked" then
		local title = Titles.ById[info.id]
		if title then
			-- (prompt 20: a reward popup, queued with the others)
			Notify.Reward("NEW TITLE", title.name, "medal", RARITY_COLOR[title.rarity] or Colors.Gold, "TitleUnlocked")
			if not modal.isOpen() then menuButton:SetDot(true) end
		end
	end
end)
