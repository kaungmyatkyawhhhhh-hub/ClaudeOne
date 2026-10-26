-- GeneticsClient: the genetics reveal (first join) and reroll screen.
-- (owner, 14 Oct: the 3D stage is back; phones frame it exactly like a PC) The camera pose is worked out ONCE on a virtual
-- 1920x1080 screen (the stage between 17% and 70% of its height) and used on every device; the FieldOfView follows the
-- screen's aspect ratio: the PC's vertical FOV, widened on screens narrower than 16:9 so the PC's horizontal view still
-- fits (nothing is ever cut at the top or bottom; wider phones just see a little more at the sides). No UI ever sits on
-- the stage: GENETICS and the DNA tokens are on Roblox's top bar line, everything else (Overall and the six groups in
-- one row, Frame / Body, View odds, REROLL, KEEP) is one final-kit panel in the bottom band.
-- (Below: the stage as built before 14 Oct; the labels that used to sit under each plate are the bottom panel's cells.)
-- A small dark 3D stage of its own, far above the town (this client only), seen by the real camera (Scriptable, restored
-- on close), so the plates are truly 3D and cast real shadows: a warm key light from the top left (Shadows on; the bar,
-- plates, collar and overall plate cast shadows), a soft fill from the right, a cool rim from behind on the plate edges.
-- The bar lies low over a dark matte floor (the biggest plates almost touch it). ONE shadow source: the key light's real
-- shadows, or (low graphics, where real shadows don't render) soft contact shadows under the plates instead. No stands.
-- The camera looks at the bar about 28 degrees from straight-on, slightly above, and drifts a little; bigger plates sit
-- tight on a thicker bar with a small steel microplate between every two, and each label sits right under its plate.
--  * The bar carries a DNA helix: a cyan and a magenta strand (opposite phase) with base-pair rungs every ~0.3 studs in
--    the A/T/G/C colors (red, yellow, green, blue), glowing, with a few soft colored lights along it; one turn every 6s.
--    The plates turn slowly with the bar (one turn every 20s) and the overall plate on its centre (every 25s); both
--    pause during the reveal and ease back in. The background is plain dark.
--  * Layout: the overall plate is placed and sized from the camera (left part of the screen, ~42% of the screen height
--    or less on small screens), the bar group fills the right part. One row of labels: each right under its own plate
--    (projected every frame), all scaled down together when neighbours would touch.
--  * Plates are rubber bumper plates (stepped bevel edge, raised rim, inset ring, chrome hub, the grade letter printed on
--    the face). They slide onto the sleeve about 0.2s apart, best grade first (so it ends up innermost), each with a
--    clank; S plates get a quick shine sweep. A collar closes the sleeve and the overall grade drops in as a bigger
--    matching plate standing on the floor next to the bar. The whole reveal is under 3s; a tap (or Space) skips.
--  * Under each plate its label, stacked: group name (gray, 18px), grade letter in a 32px circle (the only color) and
--    the multiplier ("x1.50", 22px white). Tap / hover one for what it means. Frame (with a small
--    silhouette of the shoulder width) and body type are two cards. Reroll (shows its cost)
--    replays the reveal: plates that got better show a green arrow, worse ones a gray one; a good roll asks first.
--  * DNA tokens (owner, 14 Oct, Config/DNA): the count in gold top right. With no free reroll and no token, REROLL opens a
--    small choice in the buttons row: "25,000" coins or "R$ 99" (the DNA Token product); nothing is spent without a tap.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Genetics = require(Config.Genetics)
local Machines = require(Config.Machines)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local UIBus = require(Shared.UI.UIBus)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------
local STAGE_CF = CFrame.new(0, 1600, 0) -- far above the town, inside its own dark room
-- Plates: wide and thin (diameter about 3x thickness), all the same thickness; better grade = a little wider.
local PLATE = { Thickness = 0.8, Diameter = { S = 3.0, A = 2.8, B = 2.6, C = 2.4, D = 2.2 }, Hub = 0.86 }
local HERO = { Thickness = 1.1, Diameter = 4.0, Hub = 1.1 }
-- a small steel change plate between every two stat plates (they sit tight against each other, no gaps)
local MICRO = { Thickness = 0.24, Diameter = 1.95, Color = Color3.fromHex("#D3D7DE") }
local BAR_SIZE = { Grip = 0.38, Core = 0.12, Sleeve = 0.72, InnerCollar = 1.05, Collar = 1.0 }
-- Along the bar's own X axis: grip on the left, the inner collar at 0, plates from SlotStart outward, sleeve end.
-- the plates sit Gap apart on the sleeve, so every face shows (the sleeve is long enough for six plates and the collar)
local BAR = { GripStart = -2.2, SlotStart = 0.2, Gap = MICRO.Thickness, SleeveEnd = 6.9, Yaw = math.rad(-28) }
local BAR_CF = STAGE_CF * CFrame.new(-0.4, 0, 0) * CFrame.Angles(0, BAR.Yaw, 0) -- ~28 degrees from straight-on, the sleeve end toward the camera
-- where plate `slot` (1 = innermost) sits along the bar
local function slotX(slot)
	return BAR.SlotStart + PLATE.Thickness / 2 + (slot - 1) * (PLATE.Thickness + BAR.Gap)
end
local function slotCF(slot)
	return BAR_CF * CFrame.new(slotX(slot), 0, 0)
end
local FLOOR_Y = -PLATE.Diameter.S / 2 - 0.04 -- the floor's top: an S plate (the biggest) almost touches it
local HERO_CF = STAGE_CF * CFrame.new(-8.2, FLOOR_Y + HERO.Diameter / 2, 1.0) * CFrame.Angles(0, math.rad(-70), 0) -- on its rim on the floor, facing the camera
-- a 3/4 view: about 35 degrees off the bar's side (BAR.Yaw), slightly from above, drifting a little so the light moves
local CAMERA = { Fov = 30, Pitch = 8, Height = 0, Drift = math.rad(2.5), DriftSpeed = 0.35 }
-- Fine-tuning in Studio without code: ReplicatedStorage.GeneticsCameraRig (a Configuration) with CamPitch (degrees the
-- camera looks down) and CamHeight (studs up / down after the framing). Edited while the screen is open, it re-frames.
-- (kept in the CAMERA table: this script is at the top-level local limit)
CAMERA.Rig = ReplicatedStorage:FindFirstChild("GeneticsCameraRig")
function CAMERA.Value(name: string, default: number): number
	local value = CAMERA.Rig and CAMERA.Rig:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end
local HELIX = {
	Color = Color3.fromRGB(0, 200, 255), -- (the glowing core in the grip)
	Strands = { Color3.fromRGB(0, 200, 255), Color3.fromRGB(255, 60, 170) }, -- cyan, magenta
	Radius = 0.36, Turns = 5, Points = 110, Speed = 2 * math.pi / 6, Width = 0.05, Transparency = 0.15,
	RungStep = 0.3, RungWidth = 0.028, RungTransparency = 0.25,
	-- base pairs A, T, G, C, repeating
	RungColors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 230, 120), Color3.fromRGB(80, 140, 255) },
	Lights = { -1.4, 1.4, 4.4 }, -- soft colored lights along the bar (bar-local x), alternating cyan / magenta
}
-- the slow spin: plates with the bar, the overall plate on its centre (radians per second), eased in after the reveal
local SPIN = { Bar = 2 * math.pi / 20, Hero = 2 * math.pi / 25, EaseIn = 1 }
local CHROME = Color3.fromHex("#D6D8DE")
local KEY_LIGHT = { Brightness = 3.4, Range = 32, Angle = 80, Color = Color3.fromHex("#FFE2C2") }
local ROOM = Color3.fromHex("#050507")
-- The dim gym around the stage (ReplicatedStorage.GeneticsSet, baked by tools/builders/GeneticsSet): the gym floor lies
-- Ground below the platform top (FLOOR_Y); J-hooks under the grip and the sleeve end; the overall plate's plate tree
-- (built for a TreeD-stud plate, scaled to it). Also holds the tree while the stage is up.
local SET = { Ground = 0.12, HookGrip = BAR.GripStart + 0.3, HookSleeve = BAR.SleeveEnd - 0.2, HelixStart = BAR.GripStart + 0.55, TreeD = 4, tree = nil,
	Platform = { -6.5, 9.5, 5 } } -- (the platform's extent along the bar and to either side of it, from GeneticsSet)
-- how far below the platform top the floor is at a point (0 on the platform)
function SET.DropAt(position: Vector3): number
	if not SET.tree then return 0 end
	local rel = BAR_CF:PointToObjectSpace(position)
	local on = rel.X > SET.Platform[1] and rel.X < SET.Platform[2] and math.abs(rel.Z) < SET.Platform[3]
	return if on then 0 else SET.Ground
end
local WORDS = { S = "Genetic Freak", A = "Blessed", B = "Gifted", C = "Average", D = "Hardgainer" }
local FLIP_PITCH = { S = 0.85, A = 0.92, B = 1, C = 1.06, D = 1.12 }
local PLURAL = { Shoulders = true, Arms = true, Legs = true }
local TIME = { Slide = 0.22, Gap = 0.2, Collar = 0.15, Drop = 0.28 } -- (the whole reveal stays under 3 seconds)

local camera = Workspace.CurrentCamera

------------------------------------------------------------------------
-- Text for frames / body types and the plate cards
------------------------------------------------------------------------
local function percentText(amount)
	return string.format("+%d%%", math.floor(amount * 100 + 0.5))
end
-- "+10% Arms" / "+5% all" / "+15% Back, Legs, Traps"
local function bonusText(bonus)
	local parts = {}
	if bonus.all then table.insert(parts, percentText(bonus.all) .. " all") end
	local named, amount = {}, nil
	for id, value in pairs(bonus.groups or {}) do table.insert(named, Muscles.GroupById[id].name) amount = value end
	for id, value in pairs(bonus.muscles or {}) do table.insert(named, Muscles.ById[id].name) amount = value end
	table.sort(named)
	if #named > 0 then table.insert(parts, percentText(amount) .. " " .. table.concat(named, ", ")) end
	return table.concat(parts, ", ")
end
local function frameLine(frame)
	local bonus = bonusText(frame.bonus)
	return "Frame: " .. frame.name, bonus ~= "" and bonus or "no bonus"
end
local function bodyLine(body)
	local bonus = bonusText(body.bonus)
	if bonus == "" then
		bonus = if body.detailLevelMult < 1 then "abs show earlier" elseif body.detailLevelMult > 1 then "abs show later" else "no bonus"
	end
	return "Body: " .. body.name, bonus
end
-- What one plate means: "Chest genetics A", "Your chest grows 20% faster", plus any frame / body bonus on that group.
local function plateMeaning(genetics, groupId)
	local grade = genetics.grades[groupId]
	local mult = Genetics.GradeById[grade].mult
	local name = Muscles.GroupById[groupId].name
	local pct = math.floor(math.abs(mult - 1) * 100 + 0.5)
	local speed = if mult > 1 then pct .. "% faster" elseif mult < 1 then pct .. "% slower" else "at normal speed"
	local lines = { "Your " .. string.lower(name) .. (PLURAL[name] and " grow " or " grows ") .. speed }
	local function extra(label, bonus)
		local amount = bonus.all or (bonus.groups and bonus.groups[groupId])
		if amount then
			table.insert(lines, label .. ": " .. percentText(amount) .. (bonus.all and " all muscles" or " " .. name))
		end
		for id, value in pairs(bonus.muscles or {}) do
			if Muscles.ById[id].group == groupId then table.insert(lines, label .. ": " .. percentText(value) .. " " .. Muscles.ById[id].name) end
		end
	end
	local frame, body = Genetics.FrameById[genetics.frame], Genetics.BodyTypeById[genetics.bodyType]
	extra(frame.name .. " frame", frame.bonus)
	extra(body.name .. " body", body.bonus)
	return name .. " genetics " .. grade, lines
end
local function percent(list, entry)
	local total = 0
	for _, e in ipairs(list) do total += e.weight end
	return math.floor(entry.weight / total * 100 + 0.5)
end
local function multOf(grade)
	return Genetics.GradeById[grade].mult
end

------------------------------------------------------------------------
-- Screen (2D): the header on the top bar line, and the bottom panel (owner, 14 Oct: never over the stage)
------------------------------------------------------------------------
local Kit = require(Shared.UI.Kit)
local GuiService = game:GetService("GuiService")
local gui = Theme.ScreenGui({ Name = "GeneticsScreen", Enabled = false, DisplayOrder = 26, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None -- full screen: the stage is framed in the camera's viewport pixels

-- taps anywhere skip the reveal (everything tappable sits above this)
local skipCatcher = New("TextButton", { Name = "Skip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 1, Parent = gui })
local labelLayer = New("Frame", { Name = "Labels", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
-- a black cover for the cut into the stage and back
local fader = New("Frame", { Name = "Fader", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Shadow, BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
local root = Kit.Root(gui)
root.ZIndex = 3

-- Header on Roblox's top bar line (after Roblox's own buttons): GENETICS left, the DNA token chip right
local header = New("Frame", { Name = "Header", BackgroundTransparency = 1, ZIndex = 3, Parent = gui })
local headerScale = New("UIScale", { Parent = header })
local titleLabel = Kit.Text({ Name = "Title", Text = "YOUR GENETICS", Font = "Title", TextSize = 20, Size = UDim2.new(1, -160, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
local _tokenChip, tokensLabel = Kit.PricePill("0 DNA TOKENS", { Name = "Tokens", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(0, 26), Parent = header })
tokensLabel.TextSize = 13
Kit.GoldText(tokensLabel)
local function placeHeader()
	local inset = GuiService.TopbarInset
	local s = Kit.Scale()
	headerScale.Scale = s
	header.Position = UDim2.fromOffset(inset.Min.X + 8, inset.Min.Y + math.max(0, (inset.Height - 30 * s) / 2))
	header.Size = UDim2.fromOffset(math.max(inset.Width - 16, 200) / s, 30)
end
Kit.OnTopbar(placeHeader)

-- The bottom panel: row 1 = Overall + the six groups (best first, filled as the plates land), row 2 = Frame / Body chips,
-- View odds, REROLL and KEEP (or the reroll confirm)
local PANEL_W = 820
local bottom = Theme.Panel({ Name = "Bottom", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(PANEL_W, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Clickable = true, Parent = root }, {
	New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	Theme.List(Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
New("UISizeConstraint", { MaxSize = Vector2.new(PANEL_W, math.huge), Parent = bottom })
local cellsRow = New("Frame", { Name = "Cells", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = bottom }, {
	Theme.List(Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
local CELL_W = (PANEL_W - 20 - 6 * 6) / 7
-- Overall (first): "OVERALL", the gold plate and the word in gold
local heroLabels = Kit.Card({ Name = "Overall", Piece = "card_gold", LayoutOrder = 0, Size = UDim2.fromOffset(CELL_W, 44), Visible = false, Parent = cellsRow }) -- (prompt 40: gold-outlined)
Kit.Text({ Name = "Label", Text = "OVERALL", Font = "Label", TextSize = 10, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 12),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = heroLabels })
local overallBadge = Kit.GradeBadge("B", 20, { Name = "Grade", Position = UDim2.fromOffset(8, 19), Parent = heroLabels })
local wordLabel = Kit.GoldText(Kit.Text({ Name = "Word", Text = "", Font = "Title", TextSize = 12, Upper = true, Position = UDim2.fromOffset(32, 19),
	Size = UDim2.new(1, -38, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = heroLabels }))
-- one cell per group: the name, the gold grade plate, "x1.50" (and UP / DOWN after a reroll)
local groupCells = {}
for index, group in ipairs(Muscles.Groups) do
	local cell = Kit.Card({ Name = group.id, LayoutOrder = index, Size = UDim2.fromOffset(CELL_W, 44), Visible = false, Parent = cellsRow })
	local scale = New("UIScale", { Parent = cell })
	Kit.Text({ Name = "Name", Text = group.name, Font = "Title", TextSize = 11, Upper = true, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = cell })
	local badge = Kit.GradeBadge("B", 20, { Name = "Grade", Position = UDim2.fromOffset(8, 19), Parent = cell })
	local mult = Kit.Text({ Name = "Mult", Text = "", Font = "Number", TextSize = 12, Position = UDim2.fromOffset(32, 19), Size = UDim2.fromOffset(44, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = cell })
	local change = Kit.Text({ Name = "Change", Text = "", Font = "Title", TextSize = 10, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 23),
		Size = UDim2.fromOffset(40, 12), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = cell })
	groupCells[group.id] = { cell = cell, scale = scale, badge = badge, mult = mult, change = change }
end
local function hideCells()
	for _, c in pairs(groupCells) do c.cell.Visible = false end
	heroLabels.Visible = false
end

-- row 2: Frame / Body chips and View odds on the left, the buttons on the right
local row2 = New("Frame", { Name = "Row2", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = bottom })
local cardsRow = New("Frame", { Name = "Cards", Size = UDim2.new(1, -300, 1, 0), BackgroundTransparency = 1, Parent = row2 }, {
	Theme.List(Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
local function infoCard(order)
	local chip = Theme.Panel({ Name = "Card" .. order, LayoutOrder = order, Piece = "well", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Parent = cardsRow }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(190, 26), Parent = chip })
	local label = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 10, RichText = true, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = chip })
	return label, chip
end
local frameCard = infoCard(1)
local bodyCard = infoCard(2)
local oddsLink = New("TextButton", { Name = "ViewOdds", LayoutOrder = 3, Text = "<u>View odds</u>", RichText = true, FontFace = Theme.Fonts.Regular, TextSize = 11,
	TextColor3 = Colors.Muted, BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 26), Parent = cardsRow })
local function drawSilhouette(_f: number) end -- (the frame card is text only in this panel)
local function setCard(label, name, bonus)
	local gray = "#" .. Colors.Muted:ToHex()
	label.Text = string.format('<b>%s</b>  <font color="%s">· %s</font>', name, gray, bonus)
end
local buttons = New("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(292, 40), BackgroundTransparency = 1, Parent = row2 },
	{ Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
-- (prompt 40, mockup genetics) REROLL red, KEEP green
local rerollButton = Kit.Button("Red", "Reroll · free", { Name = "Reroll", LayoutOrder = 1, Parent = buttons }, { width = 178, height = 40, textSize = 14 })
local keepButton = Kit.Button("Green", "Keep", { Name = "Keep", LayoutOrder = 2, Parent = buttons }, { width = 104, height = 40, textSize = 18 })
-- Reroll confirm (a good roll is about to be replaced): replaces the chips and the buttons
local confirm = New("Frame", { Name = "Confirm", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = row2 },
	{ Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
local confirmText = Kit.Text({ Name = "Text", LayoutOrder = 0, Text = "", Font = "Body", TextSize = 12, TextWrapped = true, Size = UDim2.new(1, -300, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = confirm })
local confirmCancel = Kit.Button("Quiet", "Cancel", { Name = "Cancel", LayoutOrder = 1, Parent = confirm }, { width = 120, height = 40, textSize = 14 })
local confirmYes = Kit.Button("Red", "Reroll", { Name = "Yes", LayoutOrder = 2, Parent = confirm }, { width = 150, height = 40, textSize = 16 })
-- No DNA token: the choice how to get one (replaces the chips and the buttons, like the confirm)
-- (one table: this script is near Luau's 200 locals limit)
local BUY = { DNA = require(Config.DNA), market = game:GetService("MarketplaceService") }
-- (prompt 60) "Need a DNA Token": what a token does, the coin price, x1 and x3 for Robux (x3 only once that product is
-- set up), and an X. Only after you tap REROLL with no token (never by itself).
for _, product in ipairs(require(Config.Monetization).Products) do
	if product.key == "DnaToken" then BUY.product = product.id end
	if product.key == "DnaTokenPack" then BUY.pack, BUY.packPrice = product.id, product.price end
end
BUY.frame = New("Frame", { Name = "BuyToken", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = row2 },
	{ Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
Kit.Text({ Name = "Text", LayoutOrder = 0, Text = "Need a DNA Token. " .. BUY.DNA.TokenLine, Font = "Body", TextSize = 12, TextWrapped = true,
	Size = UDim2.new(1, -(if BUY.pack then 470 else 344), 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = BUY.frame })
BUY.coins = Kit.Button("Gold", Kit.Format(BUY.DNA.CoinPrice), { Name = "Coins", LayoutOrder = 2, Parent = BUY.frame },
	{ width = 130, height = 40, textSize = 16, icon = "coin" })
BUY.robux, BUY.robuxLabel = Kit.Button("Red", "x1 R$ " .. BUY.DNA.RobuxPrice, { Name = "Robux", LayoutOrder = 3, Parent = BUY.frame },
	{ width = 118, height = 40, textSize = 15 })
if BUY.pack then
	BUY.robux3, BUY.robux3Label = Kit.Button("Red", "x3 R$ " .. BUY.packPrice, { Name = "Robux3", LayoutOrder = 4, Parent = BUY.frame },
		{ width = 118, height = 40, textSize = 15 })
	BUY.robux3.Activated:Connect(function() BUY.market:PromptProductPurchase(player, BUY.pack) end)
end
BUY.cancel = Kit.CloseButton({ Name = "Cancel", LayoutOrder = 5, Size = UDim2.fromOffset(44, 44), Parent = BUY.frame })
task.spawn(function() -- (Roblox's real prices)
	for _, entry in ipairs({ { BUY.product, BUY.robuxLabel, "x1 R$ " }, { BUY.pack, BUY.robux3Label, "x3 R$ " } }) do
		if entry[1] and entry[2] then
			local ok, info = pcall(BUY.market.GetProductInfo, BUY.market, entry[1], Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then entry[2].Text = entry[3] .. Kit.Format(info.PriceInRobux) end
		end
	end
end)

local skipHint = Kit.Text({ Name = "SkipHint", Text = "Tap to skip", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(200, 16), Visible = false, Parent = root })

-- Odds panel (opened by "View odds")
local oddsPanel = Theme.Panel({ Name = "Odds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 5, Parent = root }, {
	New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16) }),
	Theme.List(Vertical, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local oddsHeader = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = oddsPanel })
Kit.Text({ Text = "ODDS", Font = "Title", TextSize = 20, Size = UDim2.new(1, -50, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsHeader })
local oddsClose = Kit.CloseButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = oddsHeader })
Kit.Text({ LayoutOrder = 2, Text = "Grade (each group)", Font = "Label", TextSize = 11, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
local gradeRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = oddsPanel }, { Theme.List(Horizontal, 14, Enum.HorizontalAlignment.Left) })
for index, grade in ipairs(Genetics.Grades) do
	local cell = New("Frame", { LayoutOrder = index, Size = UDim2.fromOffset(52, 48), BackgroundTransparency = 1, Parent = gradeRow }, { Theme.List(Vertical, 4) })
	Kit.GradeBadge(grade.id, 26, { LayoutOrder = 1, Parent = cell })
	Kit.Text({ LayoutOrder = 2, Text = percent(Genetics.Grades, grade) .. "%", Font = "Number", TextSize = 12, Size = UDim2.new(1, 0, 0, 16), Parent = cell })
end
local function oddsList(order, title, list)
	local items = {}
	for _, entry in ipairs(list) do table.insert(items, entry.name .. " " .. percent(list, entry) .. "%") end
	Kit.Text({ LayoutOrder = order, Text = title, Font = "Label", TextSize = 11, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
	Kit.Text({ LayoutOrder = order + 1, Text = table.concat(items, "  ·  "), Font = "Body", TextSize = 12, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
end
oddsList(4, "Frame", Genetics.Frames)
oddsList(6, "Body type", Genetics.BodyTypes)

-- (the plate card is gone: nothing sits on the stage; kept as a hidden frame for the code that hides it)
local card = New("Frame", { Name = "PlateCard", Visible = false, Parent = labelLayer })

-- Side menu button
local menuButton = SideMenu.Add("Genetics", "Genetics", Icons.DNA, 3)

------------------------------------------------------------------------
-- The 3D stage
------------------------------------------------------------------------
local stage = nil   -- Model (client only) while the screen is open
local lights = {}   -- { light, base brightness }
local helix = nil   -- { strands = { { attachments, beams } }, phase, pulse }
local dof = nil

local function part(props)
	local p = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth })
	for key, value in pairs(props) do p[key] = value end
	return p
end
local function cylinder(name, length, diameter, color, material, cf, parent)
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), Color = color, Material = material or Enum.Material.SmoothPlastic, CFrame = cf or CFrame.new(), Parent = parent })
end

local function castShadows(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Transparency < 1 then item.CastShadow = true end
	end
end

-- A circle drawn on a SurfaceGui (rings on the plate faces)
local function ring(parent, scale, color, thickness, transparency)
	return New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale), BackgroundTransparency = 1, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		New("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 }),
	})
end

-- One plate (axis = X, front face = +X), built like a real rubber bumper plate: a slightly smaller core over a wider,
-- thinner edge band (a stepped bevel all round), a raised rim on the front face (a ring of short segments), a chrome
-- hub with a flange, a groove ring, and on both faces the competition-plate printing (M WEIGHTS above and upside down below
-- the hub, the grade letter at 9 and 3 o'clock). Rubber finish, no glow. S plates get a shine layer that can
-- sweep across the face once.
local PPS = 100 -- SurfaceGui pixels per stud on the faces
local BRAND_SIZE = 1.05 -- the brand's font size vs the band between hub and groove ring (its capitals fill most of it)
local BRAND_TRACK = 0.9 -- letter advance vs the letter's own width (under 1 = tighter than normal)
local BRAND_SPACE = 0.2 -- the small gap between "M" and "WEIGHTS" (font-size units)

-- Each brand letter's box at font size 1 ({ch, x, y}), measured once in the plate font so the curved letters can sit
-- close together.
local brandCache = {}
local function brandWidths(text: string)
	if brandCache[text] then return brandCache[text] end
	local list = {}
	for ch in string.gmatch(text, ".") do
		local x, y = 0.55, 1.25
		local ok, bounds = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = ch
			params.Font = Theme.Fonts.Bold
			params.Size = 100
			params.Width = 1000
			return TextService:GetTextBoundsAsync(params)
		end)
		if ok and bounds then x, y = bounds.X / 100, bounds.Y / 100 end
		table.insert(list, { ch = ch, x = if ch == " " then BRAND_SPACE else x, y = y })
	end
	brandCache[text] = list
	return list
end
local RIM_SEGMENTS = 36
local function makePlate(grade, diameter, thickness, hub, parent)
	local style = Theme.GradePlates[grade]
	local fill = style.Fill:Lerp(Color3.new(0, 0, 0), 0.08) -- (a touch deeper than the label colors)
	local model = New("Model", { Name = "Plate" })
	local body = cylinder("Body", thickness, diameter - 0.08, fill, nil, nil, model)
	model.PrimaryPart = body
	cylinder("Edge", thickness - 0.1, diameter, fill:Lerp(Color3.new(0, 0, 0), 0.12), nil, nil, model) -- the bevel step
	-- the raised rim on the front face
	local rimRadius = diameter / 2 - 0.13
	local chord = 2 * math.pi * rimRadius / RIM_SEGMENTS * 1.08
	for i = 1, RIM_SEGMENTS do
		local angle = (i / RIM_SEGMENTS) * math.pi * 2
		part({
			Name = "Rim",
			Size = Vector3.new(0.035, 0.09, chord),
			CFrame = CFrame.new(thickness / 2 + 0.0175, math.cos(angle) * rimRadius, math.sin(angle) * rimRadius) * CFrame.Angles(angle, 0, 0),
			Color = fill:Lerp(Color3.new(1, 1, 1), 0.06),
			Parent = model,
		})
	end
	-- the metal hub: flange + sleeve tube + the hole
	cylinder("Flange", thickness + 0.03, hub * 1.45, CHROME:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Metal, nil, model)
	cylinder("Hub", thickness + 0.08, hub, CHROME, Enum.Material.Metal, nil, model)
	cylinder("Hole", thickness + 0.1, hub * 0.6, Color3.fromRGB(20, 20, 24), nil, nil, model)
	-- printed like a competition bumper plate, on both faces: "M WEIGHTS" big across the band above the hub and upside down
	-- below it, the grade letter at 9 o'clock (upright) and at 3 o'clock (turned 180), all bold white in the colored band
	-- between the hub and the groove ring
	local face = diameter - 0.08
	local px = face * PPS
	local hubR = hub * 1.45 / 2 / face -- the flange's edge, as a share of the face
	local ringR = 0.43                 -- the groove ring
	local BRAND_ARC = 128              -- the most of the band the brand may span (clear of the letters at 9 and 3 o'clock)
	local mid, band = (hubR + ringR) / 2, ringR - hubR
	local canvas = nil
	for _, side in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local surface = New("SurfaceGui", { Name = "Face" .. side.Name, Face = side, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = PPS, LightInfluence = 1, Parent = body })
		local c = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = surface })
		canvas = canvas or c
		ring(c, ringR * 2, style.Rim, math.max(px * 0.014, 3), 0.1)                                 -- the groove ring
		ring(c, ringR * 2 + 0.02, fill:Lerp(Color3.new(1, 1, 1), 0.25), math.max(px * 0.005, 1), 0.4) -- its lit edge
		local function printText(name, text, x, y, w, h, rotation)
			New("TextLabel", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromScale(w, h),
				Rotation = rotation,
				BackgroundTransparency = 1,
				Text = text,
				FontFace = Theme.Fonts.Bold,
				TextScaled = true, -- world-space text on a plate face
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.8,
				ZIndex = 3,
				Parent = c,
			})
		end
		-- the brand follows the band's curve, one letter at a time, filling the band from the hub to the groove ring and
		-- set tight (each letter advances by its own width): over the top (upright) and, turned 180, under the hub
		local widths = brandWidths(Machines.Brand)
		local size = band * BRAND_SIZE -- the font size, as a share of the face
		local total = 0
		for _, w in ipairs(widths) do total += w.x * BRAND_TRACK end
		size = math.min(size, math.rad(BRAND_ARC) * mid / total) -- (shrinks only if the word would reach the grade letters)
		for _, base in ipairs({ 0, math.pi }) do
			local along = -total * size / 2
			for _, w in ipairs(widths) do
				local advance = w.x * BRAND_TRACK * size
				local angle = base + (along + advance / 2) / mid
				along += advance
				if w.ch ~= " " then printText("Brand", w.ch, 0.5 + math.sin(angle) * mid, 0.5 - math.cos(angle) * mid, w.x * size, w.y * size, math.deg(angle)) end
			end
		end
		-- the grade letter as big as the brand's letters (a touch bigger), centred on the hole's height
		local letter, letterSize = brandWidths(grade)[1], size * 1.1
		printText("GradeLeft", grade, 0.5 - mid, 0.5, letter.x * letterSize, letter.y * letterSize, 0)
		printText("GradeRight", grade, 0.5 + mid, 0.5, letter.x * letterSize, letter.y * letterSize, 180)
	end
	-- S: a shine band that can sweep across the face once (clipped to the round face by a CanvasGroup)
	local shine = nil
	if grade == "S" then
		local clip = New("CanvasGroup", { Name = "ShineClip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas },
			{ New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		shine = New("Frame", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.4, 0.5),
			Size = UDim2.fromScale(0.18, 1.6),
			Rotation = 22,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			Parent = clip,
		}, { New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
	end
	castShadows(model)
	model.Parent = parent
	return { model = model, body = body, shine = shine, diameter = diameter }
end
local function addLight(class, cf, props, parent)
	local holder = part({ Name = class .. "Holder", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = cf, Parent = parent })
	local light = New(class, props)
	light.Parent = holder
	table.insert(lights, { light = light, base = light.Brightness })
	return light
end

-- the points of one helix strand along the bar (bar-local positions)
local function helixPoint(index, count, phase, radius, startX, endX, turns)
	local alpha = (index - 1) / (count - 1)
	local x = startX + (endX - startX) * alpha
	local theta = phase + alpha * turns * math.pi * 2
	return x, Vector3.new(x, math.cos(theta) * radius, math.sin(theta) * radius)
end

-- A helix of two strands of light (Beams between Attachments on an invisible part at `cf`).
local function makeHelix(cf, count, radius, startX, endX, turns, width, color, transparency, parent)
	local root = part({ Name = "Helix", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = cf, Parent = parent })
	local h = { root = root, strands = {}, count = count, radius = radius, startX = startX, endX = endX, turns = turns, phase = 0, width = width, transparency = transparency }
	for s = 1, 2 do
		local strand = { attachments = {}, beams = {}, xs = {} }
		local strandColor = if typeof(color) == "table" then color[s] else color
		for i = 1, count do
			local x, position = helixPoint(i, count, (s - 1) * math.pi, radius, startX, endX, turns)
			strand.xs[i] = x
			strand.attachments[i] = New("Attachment", { Position = position, Parent = root })
			if i > 1 then
				strand.beams[i - 1] = New("Beam", {
					Attachment0 = strand.attachments[i - 1],
					Attachment1 = strand.attachments[i],
					Color = ColorSequence.new(strandColor),
					Transparency = NumberSequence.new(transparency),
					Width0 = width,
					Width1 = width,
					FaceCamera = true,
					LightEmission = 1,
					LightInfluence = 0,
					Segments = 1,
					Texture = "",
					Parent = root,
				})
			end
		end
		h.strands[s] = strand
	end
	-- the rungs: a short bar between the two strands every RungStep studs (the strands are opposite each other)
	h.rungs = {}
	local x = startX + HELIX.RungStep / 2
	local index = 0
	while x < endX do
		index += 1
		local a0 = New("Attachment", { Parent = root })
		local a1 = New("Attachment", { Parent = root })
		New("Beam", {
			Attachment0 = a0, Attachment1 = a1,
			Color = ColorSequence.new(HELIX.RungColors[(index - 1) % #HELIX.RungColors + 1]),
			Transparency = NumberSequence.new(HELIX.RungTransparency),
			Width0 = HELIX.RungWidth, Width1 = HELIX.RungWidth,
			FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1, Texture = "",
			Parent = root,
		})
		table.insert(h.rungs, { x = x, a0 = a0, a1 = a1 })
		x += HELIX.RungStep
	end
	return h
end

local function updateHelix(h, dt, speed, pulse)
	h.phase += dt * speed
	for _, rung in ipairs(h.rungs or {}) do
		local alpha = (rung.x - h.startX) / (h.endX - h.startX)
		local theta = h.phase + alpha * h.turns * math.pi * 2
		local c, s = math.cos(theta) * h.radius, math.sin(theta) * h.radius
		rung.a0.Position = Vector3.new(rung.x, c, s)
		rung.a1.Position = Vector3.new(rung.x, -c, -s)
	end
	for s, strand in ipairs(h.strands) do
		for i, attachment in ipairs(strand.attachments) do
			local _, position = helixPoint(i, h.count, h.phase + (s - 1) * math.pi, h.radius, h.startX, h.endX, h.turns)
			attachment.Position = position
		end
		-- the lock-on flash: a bright band running down the strands
		for i, beam in ipairs(strand.beams) do
			local intensity = 0
			if pulse then
				local mid = (strand.xs[i] + strand.xs[i + 1]) / 2
				intensity = math.exp(-((mid - pulse) / 0.4) ^ 2)
			end
			if beam:GetAttribute("I") ~= math.floor(intensity * 20) then
				beam:SetAttribute("I", math.floor(intensity * 20))
				beam.Width0 = h.width * (1 + 2.5 * intensity)
				beam.Width1 = beam.Width0
				beam.Transparency = NumberSequence.new(h.transparency * (1 - intensity))
			end
		end
	end
end

-- Real shadows don't render on low graphics (most phones): there the contact shadows stand in for them instead.
local function lowGraphics()
	local ok, level = pcall(function() return UserSettings().GameSettings.SavedQualityLevel end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		local okRender, render = pcall(function() return settings().Rendering.QualityLevel end)
		return okRender and render.Value > 0 and render.Value <= 4
	end
	return level.Value <= 4
end
local useContactShadows = false -- decided when the stage is built (one shadow source, never both)

-- A soft contact shadow on the floor: a dark blurred pill made of stacked see-through rounded frames on a SurfaceGui
-- (no image needed), centred under the given point, its length along the yaw's X axis.
local SHADOW_LAYERS = 7
local function contactShadow(name, center, yaw, length, width, drop)
	if not useContactShadows then return nil end
	local holder = part({ Name = name, Size = Vector3.new(length, 0.02, width), Transparency = 1,
		CFrame = CFrame.new(center.X, STAGE_CF.Position.Y + FLOOR_Y + 0.012 - (drop or 0), center.Z) * yaw, Parent = stage })
	local surface = New("SurfaceGui", { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0, Parent = holder })
	for i = 1, SHADOW_LAYERS do
		local k = 1 - (i - 1) / SHADOW_LAYERS * 0.75
		New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(k, k),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.86, Parent = surface }, { New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return holder
end

local function buildStage()
	stage = New("Model", { Name = "GeneticsStage" })
	table.clear(lights)
	useContactShadows = lowGraphics()
	-- the dark room (closed, so no sky or sun gets in; big enough that the lights fade out before the walls)
	local roomSize = Vector3.new(110, 80, 110)
	for _, face in ipairs({ { Vector3.new(0, -40, 0), Vector3.new(roomSize.X, 1, roomSize.Z) }, { Vector3.new(0, 40, 0), Vector3.new(roomSize.X, 1, roomSize.Z) },
		{ Vector3.new(0, 0, -50), Vector3.new(roomSize.X, roomSize.Y, 1) }, { Vector3.new(0, 0, 55), Vector3.new(roomSize.X, roomSize.Y, 1) },
		{ Vector3.new(-55, 0, 0), Vector3.new(1, roomSize.Y, roomSize.Z) }, { Vector3.new(55, 0, 0), Vector3.new(1, roomSize.Y, roomSize.Z) } }) do
		part({ Name = "Room", Size = face[2], CFrame = STAGE_CF * CFrame.new(face[1]), Color = ROOM, Parent = stage })
	end
	-- the dim gym: rubber tiles, the back wall with a squat rack, a dumbbell rack and plates; the lifting platform under
	-- the bar, J-hooks holding it, the plate tree for the overall plate (placed with it). Without the baked set: a plain floor.
	local set = ReplicatedStorage:FindFirstChild("GeneticsSet")
	SET.tree = nil
	if set then
		local room = set.Room:Clone()
		room:PivotTo(STAGE_CF * CFrame.new(0, FLOOR_Y, 0))
		room.Parent = stage
		local platform = set.Platform:Clone()
		platform:PivotTo(BAR_CF * CFrame.new(0, FLOOR_Y, 0))
		platform.Parent = stage
		for _, spec in ipairs({ { "HookGrip", SET.HookGrip }, { "HookSleeve", SET.HookSleeve } }) do
			local hook = set[spec[1]]:Clone()
			hook:PivotTo(BAR_CF * CFrame.new(spec[2], 0, 0))
			castShadows(hook)
			hook.Parent = stage
		end
		SET.tree = set.PlateTree:Clone()
		castShadows(SET.tree)
		SET.tree.Parent = stage
	else
		part({ Name = "Floor", Size = Vector3.new(100, 1, 96), CFrame = STAGE_CF * CFrame.new(-0.5, FLOOR_Y - 0.5, 0.5), Color = Color3.fromHex("#141417"), Material = Enum.Material.Rubber, Parent = stage })
	end
	-- lights: one warm overhead spot on the platform (the only one with shadows), a faint fill from the right, a cool rim
	-- from behind that catches the plate edges, and a dim warm glow on the back wall so the gym reads in the dark
	addLight("SpotLight", CFrame.lookAt((STAGE_CF * CFrame.new(-2.5, 13, 3)).Position, (STAGE_CF * CFrame.new(-1.8, FLOOR_Y, 0)).Position),
		{ Face = Enum.NormalId.Front, Brightness = KEY_LIGHT.Brightness, Range = KEY_LIGHT.Range, Angle = KEY_LIGHT.Angle, Color = KEY_LIGHT.Color, Shadows = not useContactShadows }, stage)
	addLight("PointLight", STAGE_CF * CFrame.new(9, 2, 6), { Brightness = 0.3, Range = 20, Color = Color3.fromHex("#DCE6FF"), Shadows = false }, stage)
	addLight("PointLight", STAGE_CF * CFrame.new(0, 7, -24), { Brightness = 0.3, Range = 24, Color = Color3.fromHex("#FFC98A"), Shadows = false }, stage)
	addLight("SpotLight", CFrame.lookAt((STAGE_CF * CFrame.new(2, 5, -8)).Position, (STAGE_CF * CFrame.new(1, 0, 0)).Position),
		{ Face = Enum.NormalId.Front, Brightness = 3, Range = 18, Angle = 60, Color = Color3.fromHex("#9CC2FF"), Shadows = false }, stage)

	-- the bar: a glassy grip with a soft glowing core, the inner collar, the chrome sleeve
	local barModel = New("Model", { Name = "Bar", Parent = stage })
	local gripLength = 0 - BAR.GripStart - 0.15
	local grip = cylinder("Grip", gripLength, BAR_SIZE.Grip, Color3.fromHex("#9FB4C8"), Enum.Material.Glass, BAR_CF * CFrame.new(BAR.GripStart + gripLength / 2, 0, 0), barModel)
	grip.Transparency = 0.35
	cylinder("Core", gripLength, BAR_SIZE.Core, HELIX.Color, Enum.Material.Neon, grip.CFrame, barModel).Transparency = 0.45
	cylinder("GripEnd", 0.08, BAR_SIZE.Grip + 0.06, CHROME, Enum.Material.Metal, BAR_CF * CFrame.new(BAR.GripStart, 0, 0), barModel)
	cylinder("InnerCollar", 0.36, BAR_SIZE.InnerCollar, CHROME, Enum.Material.Metal, BAR_CF * CFrame.new(0, 0, 0), barModel)
	local sleeveLength = BAR.SleeveEnd - 0.15
	cylinder("Sleeve", sleeveLength, BAR_SIZE.Sleeve, CHROME, Enum.Material.Metal, BAR_CF * CFrame.new(0.15 + sleeveLength / 2, 0, 0), barModel)
	cylinder("EndCap", 0.1, BAR_SIZE.Sleeve + 0.08, CHROME:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Metal, BAR_CF * CFrame.new(BAR.SleeveEnd, 0, 0), barModel)
	castShadows(barModel)
	-- the DNA helix along the whole bar (thin, soft, slow)
	helix = makeHelix(BAR_CF, HELIX.Points, HELIX.Radius, SET.HelixStart, BAR.SleeveEnd, HELIX.Turns, HELIX.Width, HELIX.Strands, HELIX.Transparency, stage)
	for i, x in ipairs(HELIX.Lights) do
		addLight("PointLight", BAR_CF * CFrame.new(x, 0, 0), { Brightness = 1.5, Range = 6, Color = HELIX.Strands[(i - 1) % 2 + 1], Shadows = false }, stage)
	end

	stage.Parent = Workspace
end

local function destroyStage()
	if stage then stage:Destroy() end
	stage, helix = nil, nil
	table.clear(lights)
end

------------------------------------------------------------------------
-- Camera: framed so the bar and the overall plate fit between the header and the labels
------------------------------------------------------------------------
local savedCamera = nil
local cameraBase = nil
local fovPunch, shakeUntil, shakeStrength = 0, 0, 0
-- (owner, 14 Oct) The pose is framed once on a virtual 1920x1080 screen at CAMERA.Fov, the same on every device; the
-- real camera's FieldOfView then keeps that view on any aspect ratio (screenFov).
local VIRTUAL = Vector2.new(1920, 1080)
local BAND = { Left = 0.04, Right = 0.96, Top = 0.17, Bottom = 0.70 } -- where the stage may be on the virtual screen
local function focal(): number
	return (VIRTUAL.Y / 2) / math.tan(math.rad(CAMERA.Fov) / 2)
end
local function project(cf: CFrame, point: Vector3): (number, number, number)
	local rel = cf:PointToObjectSpace(point)
	local depth = -rel.Z
	local f = focal()
	return VIRTUAL.X / 2 + rel.X / depth * f, VIRTUAL.Y / 2 - rel.Y / depth * f, depth
end
local function rayThrough(cf: CFrame, x: number, y: number): (Vector3, Vector3)
	local f = focal()
	return cf.Position, cf:VectorToWorldSpace(Vector3.new((x - VIRTUAL.X / 2) / f, -(y - VIRTUAL.Y / 2) / f, -1)).Unit
end
-- The real FieldOfView: the PC's vertical FOV, widened on screens narrower than 16:9 so the PC's horizontal view fits.
local function screenFov(): number
	local size = camera.ViewportSize
	local aspect = size.X / math.max(size.Y, 1)
	local base = math.rad(CAMERA.Fov)
	local halfH = math.atan(math.tan(base / 2) * VIRTUAL.X / VIRTUAL.Y)
	return math.deg(math.max(base, 2 * math.atan(math.tan(halfH) / aspect)))
end
-- the overall plate, placed from the camera: { cf = rest CFrame, d = diameter }
local heroLayout = nil

-- the bar group's real outline: the grip end and sleeve end (helix width), and the rims of the innermost and outermost
-- plates (a ring of points each, so the fit follows the discs instead of a box around them)
local function framePoints()
	local points = {}
	local thin = HELIX.Radius + 0.1
	for _, x in ipairs({ BAR.GripStart, BAR.SleeveEnd }) do
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			table.insert(points, (BAR_CF * CFrame.new(x, math.cos(a) * thin, math.sin(a) * thin)).Position)
		end
	end
	local r = PLATE.Diameter.S / 2 + 0.05
	for _, slot in ipairs({ 1, 6 }) do
		for _, dx in ipairs({ -PLATE.Thickness / 2, PLATE.Thickness / 2 }) do
			for k = 0, 15 do
				local a = k / 16 * math.pi * 2
				table.insert(points, (BAR_CF * CFrame.new(slotX(slot) + dx, math.cos(a) * r, math.sin(a) * r)).Position)
			end
		end
	end
	return points
end
local HERO_SHARE = 0.27   -- the left part of the band for the overall plate (the bar group gets the rest)
local HERO_HEIGHT = 0.36  -- the overall plate's diameter on the virtual screen, as a share of its height (when it fits)

local function bandRect()
	return VIRTUAL.X * BAND.Left, VIRTUAL.Y * BAND.Top, VIRTUAL.X * BAND.Right, VIRTUAL.Y * BAND.Bottom
end

local function fitCamera()
	local left, top, right, bandBottom = bandRect()
	left = left + (right - left) * HERO_SHARE + 12 -- the bar group: the right part
	local points = framePoints()
	local center = (STAGE_CF * CFrame.new(-0.4, 0.2, 0.6)).Position
	local distance = 16
	local look = STAGE_CF.Rotation * CFrame.Angles(-math.rad(CAMERA.Value("CamPitch", CAMERA.Pitch)), 0, 0)
	for _ = 1, 16 do
		local cf = CFrame.new(center) * look * CFrame.new(0, 0, distance)
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, p in ipairs(points) do
			local x, y = project(cf, p)
			minX, minY, maxX, maxY = math.min(minX, x), math.min(minY, y), math.max(maxX, x), math.max(maxY, y)
		end
		local scale = math.max((maxX - minX) / (right - left), (maxY - minY) / (bandBottom - top))
		distance = math.clamp(distance * scale, 6, 60)
		local studsPerPx = 2 * distance * math.tan(math.rad(CAMERA.Fov) / 2) / VIRTUAL.Y
		local dx = (left + right) / 2 - (minX + maxX) / 2
		local dy = (top + bandBottom) / 2 - (minY + maxY) / 2
		center -= cf.RightVector * dx * studsPerPx
		center += cf.UpVector * dy * studsPerPx
	end
	cameraBase = CFrame.new(center + Vector3.new(0, CAMERA.Value("CamHeight", CAMERA.Height), 0)) * look * CFrame.new(0, 0, distance)
	camera.CFrame = cameraBase
	camera.FieldOfView = screenFov()
	if dof then dof.FocusDistance = (cameraBase.Position - BAR_CF.Position).Magnitude end
end

-- The overall plate: standing on its rim on the floor, in the middle of the band's left part, sized to HERO_HEIGHT of the
-- virtual screen (or what fits). Solved from the camera pose: its centre lies on the ray through that point, at the height
-- its diameter needs.
local function layoutHero()
	local left, top, right, bandBottom = bandRect()
	local split = left + (right - left) * HERO_SHARE
	local allowH = math.max(bandBottom - top, 60)
	local target = math.min(VIRTUAL.Y * HERO_HEIGHT, (split - left) * 0.9, allowH * 0.95)
	local origin, direction = rayThrough(cameraBase, (left + split) / 2, top + allowH / 2)
	local look = cameraBase.LookVector
	local function placeAt(d: number): (Vector3?, number)
		if direction.Y > -1e-3 then return nil, math.huge end
		local t = (STAGE_CF.Position.Y + FLOOR_Y + d / 2 - origin.Y) / direction.Y
		if t <= 0 then return nil, math.huge end
		local point = origin + direction * t
		local depth = (point - origin):Dot(look)
		return point, d * focal() / depth
	end
	local low, high = 0.5, 40
	for _ = 1, 30 do
		local mid = (low + high) / 2
		local _, pixels = placeAt(mid)
		if pixels > target then high = mid else low = mid end
	end
	local d = low
	local position = placeAt(d)
	if not position then
		heroLayout = { cf = HERO_CF, d = HERO.Diameter }
		return
	end
	position = Vector3.new(position.X, STAGE_CF.Position.Y + FLOOR_Y + d / 2, position.Z)
	-- the face toward the camera, turned a little so its thickness shows
	local toCamera = (cameraBase.Position - position) * Vector3.new(1, 0, 1)
	local facing = CFrame.Angles(0, math.rad(-20), 0):VectorToWorldSpace(toCamera.Unit)
	heroLayout = { cf = CFrame.fromMatrix(position, facing, Vector3.yAxis), d = d }
end

-- The same pose on every screen: the bar group in the band's right part, the overall plate in its left part.
local function frameCamera()
	if not stage then return end
	fitCamera()
	layoutHero()
	if dof and heroLayout and cameraBase then
		local focus = (cameraBase.Position - BAR_CF.Position).Magnitude
		local heroDepth = (cameraBase.Position - heroLayout.cf.Position).Magnitude
		dof.FocusDistance = focus
		dof.InFocusRadius = math.max(4, math.abs(heroDepth - focus) + 2.5)
	end
	SET.SyncTree()
end

local function punch(amount)
	fovPunch = math.max(fovPunch, amount)
end
local function shake(strength, time)
	shakeStrength, shakeUntil = strength, os.clock() + (time or 0.15)
end

------------------------------------------------------------------------
-- Reveal state and helpers
------------------------------------------------------------------------
local isOpen = false
local revealing = false
local skipping = false
local plates = {}   -- on the bar, inner to outer: { group, grade, prev, parts, cf, slot, column, line, hit, arrow }
local collar = nil
local hero = nil    -- { parts, cf, d }
-- after a re-frame (screen resized): the overall plate moves to its new spot (it keeps its size)
local function moveHero()
	if hero and heroLayout then
		hero.cf = CFrame.new(heroLayout.cf.Position + Vector3.new(0, (hero.d - heroLayout.d) / 2, 0)) * heroLayout.cf.Rotation
		hero.parts.model:PivotTo(hero.cf)
	end
	SET.SyncTree()
end
-- the plate tree: at the overall plate's rest spot (or where it will land), scaled to it, its feet on the gym floor
function SET.SyncTree()
	local tree = SET.tree
	local cf = if hero then hero.cf else heroLayout and heroLayout.cf
	local d = if hero then hero.d else heroLayout and heroLayout.d
	if not tree or not cf or not d then return end
	tree:ScaleTo(d / SET.TreeD)
	tree:PivotTo(cf)
	local lowest = math.huge
	for _, item in ipairs(tree:GetChildren()) do
		if item.Name == "Foot" and item:IsA("BasePart") then lowest = math.min(lowest, item.Position.Y - item.Size.Y / 2) end
	end
	if lowest < math.huge then tree:PivotTo(cf + Vector3.new(0, STAGE_CF.Position.Y + FLOOR_Y - SET.DropAt(cf.Position) - lowest, 0)) end
end
local barShadow, heroShadow = nil, nil -- the contact shadows on the floor
local landed = 0     -- plates on the bar so far (the bar shadow grows with them)
local hoverPlate = nil
local pinnedPlate = nil
local current = nil -- the genetics on screen

-- Runs `step(alpha)` every frame for `duration` (or once at 1 when skipping).
local function animate(duration, step)
	if skipping or duration <= 0 then step(1) return end
	local start = os.clock()
	while true do
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		step(t)
		if t >= 1 then break end
		if skipping then step(1) break end
		RunService.RenderStepped:Wait()
	end
end
local function pause(seconds)
	local stop = os.clock() + seconds
	while not skipping and os.clock() < stop do RunService.RenderStepped:Wait() end
end
local function easeOut(t) return 1 - (1 - t) ^ 3 end
local function easeIn(t) return t * t end
local function play(name, opts)
	if skipping then return nil end
	return Audio.Play2D(name, opts)
end

-- Studio test hook: Workspace attribute "TestGeneticsHold" = n holds the reveal for screenshots: 6 = all plates on the
-- bar, 7 = the overall plate landed. Tweens started meanwhile pause while held.
local held = false
local activeTweens = {}
local function track(tween)
	table.insert(activeTweens, tween)
	if #activeTweens > 40 then table.remove(activeTweens, 1) end
	return tween
end
local function testHold(index)
	if not RunService:IsStudio() then return end
	if not (isOpen and not skipping and Workspace:GetAttribute("TestGeneticsHold") == index) then return end
	held = true
	for _, tween in ipairs(activeTweens) do tween:Pause() end
	while isOpen and not skipping and Workspace:GetAttribute("TestGeneticsHold") == index do task.wait(0.1) end
	for _, tween in ipairs(activeTweens) do
		if tween.PlaybackState == Enum.PlaybackState.Paused then tween:Play() end
	end
	table.clear(activeTweens)
	held = false
end

local function place(entry, cf)
	entry.cf = cf
	entry.parts.model:PivotTo(cf)
end
-- S plates: one quick shine sweep across the face
local function shineSweep(entry)
	local shine = entry.parts.shine
	if skipping or not shine then return end
	shine.Position = UDim2.fromScale(-0.4, 0.5)
	track(Theme.Tween(shine, { Position = UDim2.fromScale(1.4, 0.5) }, 0.5, Enum.EasingStyle.Sine))
end

------------------------------------------------------------------------
-- The plate's cell in the bottom panel (owner, 14 Oct: no labels on the stage)
------------------------------------------------------------------------
local function makeColumn(entry)
	local c = groupCells[entry.group]
	if not c then return end
	c.cell.LayoutOrder = entry.slot -- (best first, like the plates on the bar)
	Kit.SetGrade(c.badge, entry.grade)
	c.mult.Text = string.format("x%.2f", multOf(entry.grade))
	-- (prompt 40) above x1 in gold, under it grey
	local m = multOf(entry.grade)
	c.mult.TextColor3 = if m > 1 then Colors.Gold elseif m < 1 then Colors.Muted else Colors.Text
	-- after a reroll: green UP for a better grade, gray DOWN for a worse one
	local changed = entry.prev ~= nil and entry.prev ~= entry.grade
	c.change.Visible = changed
	if changed then
		local better = multOf(entry.grade) > multOf(entry.prev)
		c.change.Text = better and "UP" or "DOWN"
		c.change.TextColor3 = better and Colors.Green or Colors.Muted
	end
	c.cell.Visible = true
	if skipping then
		c.scale.Scale = 1
	else
		c.scale.Scale = 0.6
		Theme.Tween(c.scale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
		if entry.grade == "S" then task.delay(0.2, function() Theme.Shine(c.cell) end) end
	end
end

local function updateLabels() end -- (nothing follows the stage on screen any more)

------------------------------------------------------------------------
-- The moments
------------------------------------------------------------------------
-- The bar's contact shadow covers the plates on it so far.
local function setBarShadow(count)
	if barShadow then barShadow:Destroy() end
	barShadow = nil
	if count < 1 or not stage then return end
	local first, last = slotX(1) - PLATE.Thickness / 2, slotX(count) + PLATE.Thickness / 2
	local center = BAR_CF * CFrame.new((first + last) / 2, 0, 0)
	barShadow = contactShadow("BarShadow", center.Position, BAR_CF.Rotation, last - first + 0.6, PLATE.Diameter.S * 0.75)
end

-- A plate slides onto the sleeve from its end into its slot (best grade first, so it ends up innermost) and lands with
-- a clank (pitch by grade); S plates get a quick shine sweep.
-- A steel microplate (rim, face and a hole), axis = X like the plates.
local function makeMicro()
	local model = New("Model", { Name = "Micro" })
	local body = cylinder("Body", MICRO.Thickness, MICRO.Diameter, MICRO.Color, Enum.Material.Metal, nil, model)
	model.PrimaryPart = body
	cylinder("Rim", MICRO.Thickness + 0.02, MICRO.Diameter + 0.05, MICRO.Color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal, nil, model).Transparency = 0
	body.Size = Vector3.new(MICRO.Thickness + 0.04, MICRO.Diameter - 0.06, MICRO.Diameter - 0.06)
	cylinder("Hole", MICRO.Thickness + 0.06, BAR_SIZE.Sleeve + 0.04, Color3.fromRGB(28, 28, 32), nil, nil, model)
	castShadows(model)
	model.Parent = stage
	return model
end
-- the microplate rides on the inner side of its plate (between it and the plate before)
local MICRO_OFFSET = CFrame.new(-(PLATE.Thickness + MICRO.Thickness) / 2, 0, 0)
local function placeMicro(entry)
	if entry.micro then entry.micro:PivotTo(entry.cf * MICRO_OFFSET) end
end

local function slideOn(entry, slot)
	local target = slotCF(slot)
	local from = BAR_CF * CFrame.new(BAR.SleeveEnd + 1.6, 0, 0)
	place(entry, from)
	if slot > 1 then entry.micro = makeMicro() end
	animate(TIME.Slide, function(t)
		place(entry, from:Lerp(target, easeIn(t)))
		placeMicro(entry)
	end)
	place(entry, target)
	placeMicro(entry)
	landed += 1
	setBarShadow(landed)
	play("GeneticsClank", { pitch = FLIP_PITCH[entry.grade] })
	punch(0.4)
	shake(0.04)
	if entry.grade == "S" then
		play("GeneticsShimmer")
		shineSweep(entry)
	end
	makeColumn(entry)
end

local function closeCollar(count)
	collar = { parts = { model = New("Model", { Name = "Collar" }) } }
	local model = collar.parts.model
	local ringPart = cylinder("Ring", 0.34, BAR_SIZE.Collar, CHROME, Enum.Material.Metal, nil, model)
	cylinder("Lever", 0.16, 0.22, CHROME:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal, CFrame.new(0, BAR_SIZE.Collar / 2 + 0.06, 0), model)
	model.PrimaryPart = ringPart
	castShadows(model)
	model.Parent = stage
	local rest = BAR_CF * CFrame.new(slotX(count) + PLATE.Thickness / 2 + 0.16, 0, 0)
	local start = BAR_CF * CFrame.new(BAR.SleeveEnd + 1.2, 0, 0)
	animate(TIME.Collar, function(t) model:PivotTo(start:Lerp(rest, easeOut(t))) end)
	model:PivotTo(rest)
	collar.cf = rest
	play("Click", { pitch = 0.8 })
end

-- The overall plate drops onto the floor next to the bar (standing on its rim) with a thud, then its word fades in.
local function dropHero(grade)
	local layout = heroLayout or { cf = HERO_CF, d = HERO.Diameter }
	local k = layout.d / HERO.Diameter
	hero = { parts = makePlate(grade, layout.d, HERO.Thickness, HERO.Hub * k, stage), d = layout.d }
	local rest = layout.cf
	local from = rest + Vector3.new(0, 6, 0)
	animate(TIME.Drop, function(t) place(hero, from:Lerp(rest, easeIn(t))) end)
	place(hero, rest)
	SET.SyncTree()
	if heroShadow then heroShadow:Destroy() end
	heroShadow = contactShadow("HeroShadow", rest.Position, rest.Rotation, HERO.Thickness * 2.2, layout.d * 0.6, SET.DropAt(rest.Position))
	play("GeneticsThud")
	play("GeneticsThudLow")
	play("GeneticsClank", { pitch = 0.7, volume = 0.7 })
	shake(0.18, 0.18)
	punch(1)
	if grade == "S" then shineSweep(hero) end
	wordLabel.Text = WORDS[grade]
	Kit.SetGrade(overallBadge, grade)
	heroLabels.Visible = true
	if not skipping then Theme.Fade(heroLabels, true, 0.3) end
	pause(0.2)
	testHold(7)
end

local function clearBoard()
	for _, entry in ipairs(plates) do
		entry.parts.model:Destroy()
		if entry.micro then entry.micro:Destroy() end
		for _, item in ipairs({ entry.column, entry.hit }) do
			if item then item:Destroy() end
		end
	end
	table.clear(plates)
	hideCells()
	landed = 0
	setBarShadow(0)
	if heroShadow then heroShadow:Destroy() heroShadow = nil end
	if collar then collar.parts.model:Destroy() collar = nil end
	if hero then hero.parts.model:Destroy() hero = nil end
	heroLabels.Visible = false
	hoverPlate, pinnedPlate = nil, nil
	card.Visible = false
end

------------------------------------------------------------------------
-- Buttons, confirm
------------------------------------------------------------------------
local function refreshButtons()
	local data = ClientData.Get()
	-- (with no token the button still works: it opens the choice how to get one)
	Kit.SetButton(rerollButton, "Red", data.freeReroll and "Reroll · free" or "Reroll · 1 DNA token")
	rerollButton.Active = not revealing
	rerollButton.AutoButtonColor = false
	-- (26 Oct: no purchase offers in a new player's first minutes) during the tutorial, with the free reroll used and no token,
	-- the button hides instead of opening the R$ / 25,000 coins choice
	local Onboarding = require(Shared.Config.Onboarding)
	local inTutorial = ((data.onboarding or {}).tutorialStep or Onboarding.Done) < Onboarding.Done
	rerollButton.Visible = not (inTutorial and not data.freeReroll and (data.dnaTokens or 0) <= 0)
	tokensLabel.Text = data.dnaTokens .. (data.dnaTokens == 1 and " DNA TOKEN" or " DNA TOKENS")
end

local function setBottom(visible)
	-- (the panel stays up during the reveal, the cells fill in; only the buttons row waits)
	row2.Visible = visible
	if visible then Theme.Fade(row2, true, 0.3) end
end

local function showCards(genetics)
	local frame, body = Genetics.FrameById[genetics.frame], Genetics.BodyTypeById[genetics.bodyType]
	setCard(frameCard, frameLine(frame))
	drawSilhouette(frame.shoulders or 1)
	setCard(bodyCard, bodyLine(body))
end

------------------------------------------------------------------------
-- The reveal
------------------------------------------------------------------------
local spinFactor, barAngle, heroAngle = 0, 0, 0 -- (the slow spin, see renderStep; declared before the reveal resets it)
local function runReveal(genetics, previous)
	revealing, skipping = true, false
	spinFactor, barAngle, heroAngle = 0, 0, 0
	current = genetics
	titleLabel.Text = previous and "NEW GENETICS" or "YOUR GENETICS"
	clearBoard()
	setBottom(false)
	showCards(genetics)
	skipHint.Visible = true
	-- best grade first: it slides furthest and ends up innermost; the rest stack outward (ties keep the group order)
	local order = {}
	for index, group in ipairs(Muscles.Groups) do
		table.insert(order, { group = group, index = index, grade = genetics.grades[group.id] })
	end
	table.sort(order, function(a, b)
		local ma, mb = multOf(a.grade), multOf(b.grade)
		if ma ~= mb then return ma > mb end
		return a.index < b.index
	end)
	for slot, item in ipairs(order) do
		if not isOpen then return end
		local entry = { group = item.group.id, grade = item.grade, index = item.index, slot = slot, prev = previous and previous.grades[item.group.id] }
		entry.parts = makePlate(item.grade, PLATE.Diameter[item.grade], PLATE.Thickness, PLATE.Hub, stage)
		place(entry, BAR_CF * CFrame.new(BAR.SleeveEnd + 1.6, 0, 0))
		plates[slot] = entry
		task.spawn(slideOn, entry, slot)
		pause(TIME.Gap)
	end
	pause(TIME.Slide)
	if not isOpen then return end
	testHold(6)
	closeCollar(#plates)
	dropHero(genetics.overall)
	revealing = false
	skipHint.Visible = false
	setBottom(true)
	refreshButtons()
end

-- Everything comes off the bar (outermost first) and the overall plate lifts away (before a reroll's reveal).
local function slideOff()
	if collar then
		local model = collar.parts.model
		local from = model:GetPivot()
		animate(0.15, function(t) model:PivotTo(from:Lerp(BAR_CF * CFrame.new(BAR.SleeveEnd + 1.5, 0, 0), easeIn(t))) end)
		model:Destroy()
		collar = nil
	end
	Audio.Play2D("PlateSlide")
	landed = 0
	setBarShadow(0)
	for i = #plates, 1, -1 do
		local entry = plates[i]
		for _, item in ipairs({ entry.column, entry.hit }) do if item then item:Destroy() end end
		local from = entry.cf
		local to = BAR_CF * CFrame.new(BAR.SleeveEnd + 2.5, 0, 0)
		task.spawn(function()
			animate(0.2, function(t)
				place(entry, from:Lerp(to, easeIn(t)))
				placeMicro(entry)
			end)
			entry.parts.model:Destroy()
			if entry.micro then entry.micro:Destroy() end
		end)
		task.wait(0.06)
	end
	table.clear(plates)
	hideCells()
	card.Visible = false
	if heroShadow then heroShadow:Destroy() heroShadow = nil end
	if hero then
		local h = hero
		local from = h.cf
		animate(0.22, function(t) place(h, from + Vector3.new(0, 7 * easeIn(t), 0)) end)
		h.parts.model:Destroy()
		hero = nil
	end
	heroLabels.Visible = false
	task.wait(0.2)
end

------------------------------------------------------------------------
-- Frame loop: helix, camera punch / shake, labels
------------------------------------------------------------------------
local function renderStep(dt)
	if not stage then return end
	if helix then updateHelix(helix, dt, HELIX.Speed, nil) end
	-- the slow spin: paused while the reveal plays, then eased back in; the labels follow positions, not the spin
	if revealing then
		spinFactor = 0
	else
		spinFactor = math.min(1, spinFactor + dt / SPIN.EaseIn)
		local ease = spinFactor * spinFactor * (3 - 2 * spinFactor)
		barAngle = (barAngle + dt * SPIN.Bar * ease) % (2 * math.pi)
		heroAngle = (heroAngle + dt * SPIN.Hero * ease) % (2 * math.pi)
		local turn = CFrame.Angles(barAngle, 0, 0)
		for _, entry in ipairs(plates) do
			if entry.cf then
				entry.parts.model:PivotTo(entry.cf * turn)
				if entry.micro then entry.micro:PivotTo(entry.cf * MICRO_OFFSET * turn) end
			end
		end
		if collar and collar.cf then collar.parts.model:PivotTo(collar.cf * turn) end
		if hero and hero.cf then hero.parts.model:PivotTo(hero.cf * CFrame.Angles(heroAngle, 0, 0)) end
	end
	if cameraBase then
		fovPunch *= math.exp(-dt * 9)
		camera.FieldOfView = screenFov() - fovPunch
		local offset = CFrame.new()
		local now = os.clock()
		if now < shakeUntil then
			local m = shakeStrength * ((shakeUntil - now) / 0.15)
			offset = CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
		end
		-- a slow small swing around the bar, so the light moves across the plates
		local pivot = BAR_CF.Position
		local drift = math.sin(os.clock() * CAMERA.DriftSpeed) * CAMERA.Drift
		camera.CFrame = CFrame.new(pivot) * CFrame.Angles(0, drift, 0) * CFrame.new(-pivot) * cameraBase * offset
	end
	updateLabels()
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function freeze()
	return Enum.ContextActionResult.Sink
end

local function applyLayout()
	placeHeader()
end

local function open()
	if isOpen then return end
	isOpen = true
	applyLayout()
	SideMenu.SetHidden(true) -- the stage gets the whole screen
	menuButton:SetActive(true)
	oddsPanel.Visible = false
	confirm.Visible, buttons.Visible, cardsRow.Visible = false, true, true
	UIBus.GeneticsVisible:Fire(true)
	ContextActionService:BindActionAtPriority("GeneticsFreeze", freeze, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	Audio.PlayUI("Whoosh")
	-- cut into the stage behind a quick fade to black
	gui.Enabled = true
	labelLayer.Visible = false
	fader.BackgroundTransparency = 1
	Theme.Tween(fader, { BackgroundTransparency = 0 }, 0.18).Completed:Wait()
	if not isOpen then return end
	savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
	buildStage()
	camera.CameraType = Enum.CameraType.Scriptable
	showCards(ClientData.Get().genetics) -- (the cards' height is part of the framing)
	refreshButtons()
	setBottom(false)
	task.wait() -- (one frame, so the header and bottom have their sizes)
	dof = New("DepthOfFieldEffect", { Name = "GeneticsDOF", FarIntensity = 0.6, NearIntensity = 0, InFocusRadius = 5, FocusDistance = 30, Parent = Lighting })
	frameCamera()
	RunService:BindToRenderStep("GeneticsStage", Enum.RenderPriority.Camera.Value + 2, renderStep)
	labelLayer.Visible = true
	Theme.Tween(fader, { BackgroundTransparency = 1 }, 0.3)
	task.spawn(runReveal, ClientData.Get().genetics, nil)
end

local function close()
	if not isOpen then return end
	isOpen = false
	skipping = true -- (a running reveal finishes at once)
	menuButton:SetActive(false)
	ContextActionService:UnbindAction("GeneticsFreeze")
	Theme.Tween(fader, { BackgroundTransparency = 0 }, 0.18).Completed:Wait()
	RunService:UnbindFromRenderStep("GeneticsStage")
	clearBoard()
	destroyStage()
	if dof then dof:Destroy() dof = nil end
	cameraBase = nil
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = savedCamera and savedCamera.fov or 70
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	SideMenu.SetHidden(false)
	UIBus.GeneticsVisible:Fire(false)
	labelLayer.Visible = false
	setBottom(false)
	Theme.Tween(fader, { BackgroundTransparency = 1 }, 0.25).Completed:Wait()
	if not isOpen then gui.Enabled = false end
end

local function keep()
	if revealing then return end
	if not ClientData.Get().onboarding.geneticsRevealed then
		Remotes.PlayerAction:FireServer("GeneticsSeen")
	end
	close()
end
keepButton.Activated:Connect(keep)

-- skip: tap anywhere (or the Space / Enter key) while the reveal runs
skipCatcher.Activated:Connect(function()
	if revealing then skipping = true end
	pinnedPlate = nil
end)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or not isOpen or not revealing then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then skipping = true end
end)

-- Reroll: asks first when a good roll (overall A or S, or any S plate) is about to be replaced
local pendingReroll = false
local function doReroll()
	if revealing or not isOpen then return end
	revealing = true
	pendingReroll = true
	refreshButtons()
	local previous = table.clone(current or ClientData.Get().genetics)
	previous.grades = table.clone(previous.grades)
	Remotes.PlayerAction:FireServer("Reroll")
	task.spawn(function()
		setBottom(false)
		slideOff()
		-- wait for the server's new genetics, then the new reveal
		local deadline = os.clock() + 5
		while pendingReroll and os.clock() < deadline do task.wait() end
		if isOpen then runReveal(ClientData.Get().genetics, previous) end
	end)
end
local function needsConfirm()
	local genetics = current or ClientData.Get().genetics
	if genetics.overall == "S" or genetics.overall == "A" then return true end
	for _, grade in pairs(genetics.grades) do if grade == "S" then return true end end
	return false
end
function BUY.close()
	BUY.frame.Visible, buttons.Visible, cardsRow.Visible = false, true, true
end
rerollButton.Activated:Connect(function()
	if revealing or not rerollButton.Active then return end
	local data = ClientData.Get()
	if not data.freeReroll and (data.dnaTokens or 0) <= 0 then
		buttons.Visible, cardsRow.Visible, confirm.Visible, BUY.frame.Visible = false, false, false, true
		Theme.Fade(BUY.frame, true, 0.2)
		Audio.PlayUI("Click")
		Remotes.PlayerAction:FireServer("ShopEvent", { event = "OfferShown", offer = "DnaNeed" }) -- (prompt 60)
		return
	end
	if needsConfirm() then
		local genetics = current or ClientData.Get().genetics
		confirmText.Text = "Replace your " .. genetics.overall .. " genetics? You can't get them back."
		buttons.Visible, cardsRow.Visible, confirm.Visible = false, false, true
		Theme.Fade(confirm, true, 0.2)
	else
		doReroll()
	end
end)
confirmCancel.Activated:Connect(function()
	confirm.Visible, buttons.Visible, cardsRow.Visible = false, true, true
end)
confirmYes.Activated:Connect(function()
	confirm.Visible, buttons.Visible, cardsRow.Visible = false, true, true
	doReroll()
end)
BUY.cancel.Activated:Connect(BUY.close)
-- a short side-to-side shake (not enough coins)
function BUY.shake(gui: GuiObject)
	local base = gui.Position
	task.spawn(function()
		for _, dx in ipairs({ -6, 6, -5, 5, -3, 3, 0 }) do
			gui.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		gui.Position = base
	end)
end
-- (prompt 19) each DNA token bought this week costs 10% more (Config/PumpShop.DnaPriceFor)
local function dnaPrice(): number
	return require(Shared.Config.PumpShop).DnaPriceFor(ClientData.Get(), BUY.DNA.CoinPrice)
end
local function refreshDnaPrice()
	local label = BUY.coins:FindFirstChild("Label")
	if label then label.Text = Kit.Format(dnaPrice()) end
end
refreshDnaPrice()
ClientData.Changed:Connect(function(path) if path[1] == "dnaWeek" then refreshDnaPrice() end end)
BUY.coins.Activated:Connect(function()
	if (ClientData.Get().coins or 0) < dnaPrice() then
		BUY.shake(BUY.coins)
		require(Shared.UI.Notify).Toast("Not enough coins", "A DNA token costs " .. Kit.Format(dnaPrice()) .. " coins", "coin", Colors.Red, "dnacoins")
		return
	end
	Remotes.PlayerAction:FireServer("BuyDnaToken") -- (the server checks and takes the coins)
end)
BUY.robux.Activated:Connect(function()
	if BUY.product then BUY.market:PromptProductPurchase(player, BUY.product) end
end)
BUY.robux.Visible = BUY.product ~= nil
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Rerolled" then pendingReroll = false end
	if kind == "DnaTokenBought" and type(info) == "table" and info.failed then BUY.shake(BUY.coins) end
end)

oddsLink.Activated:Connect(function()
	oddsPanel.Visible = true
	Theme.Fade(oddsPanel, true)
end)
oddsClose.Activated:Connect(function()
	local tween = Theme.Fade(oddsPanel, false)
	if tween then tween.Completed:Connect(function() oddsPanel.Visible = false end) end
end)

ClientData.Changed:Connect(function(path)
	if path[1] == "dnaTokens" and BUY.frame.Visible and (ClientData.Get().dnaTokens or 0) > 0 then BUY.close() end
	if isOpen and (path[1] == "dnaTokens" or path[1] == "freeReroll") and not revealing then refreshButtons() end
end)

function CAMERA.Reframe()
	if isOpen and stage then
		applyLayout()
		task.defer(function()
			frameCamera()
			moveHero()
		end)
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(CAMERA.Reframe)
if CAMERA.Rig then CAMERA.Rig.AttributeChanged:Connect(CAMERA.Reframe) end

menuButton.Activated:Connect(function()
	if isOpen then keep() else open() end
end)
UIBus.OpenGenetics.Event:Connect(function(...)
	if UIBus.IsLocked and UIBus.IsLocked("Genetics") then UIBus.ShowLocked("Genetics") return end -- (prompt 39: still locked, GuideClient)
	open(...)
end)

-- First join: reveal right after the player presses Play on the menu screen.
task.spawn(function()
	local data = ClientData.Get()
	UIBus.WaitForMenu()
	if not data.onboarding.geneticsRevealed then
		task.wait(0.6)
		open()
	end
end)
