-- BoostsPanel (owner, prompt 14, 21 Oct): the Inventory window's ITEMS tab (TitlesClient builds the window and calls this).
-- (prompt 28: BOOSTS and ITEMS became one ITEMS tab.) Left: a grid of big tiles (5 a row):
--   * the boost items you own (Config.Boosts): icon tile, name, "x3"; while its boost runs a teal timer in the corner.
--     Items you have 0 of are hidden.
--   * DNA Tokens (opts.dna) when you have any.
--   * the boosts running now that aren't an item you hold (opts.running: passes, Endless Stamina, drinks, a Server Boost):
--     icon, name and the time left in gold ("Always on" for a pass).
--   Nothing at all: "No items yet. Get boosts at the PUMP SHOP."
-- Right: the picked tile: icon, name, what it does, how long, the time still running, and its buttons:
--   a boost item: USE (ItemService: the drink + its boost) and EQUIP / UNEQUIP (a Tool in the hotbar, HotbarClient)
--   DNA Tokens:   GENETICS (opts.dna.onUse: the Genetics screen)
--   a running boost: no buttons
-- (prompt 40, mockup inv_items) tiles tinted in the item's colour with the hex mesh and an "xN" gold badge, empty dark
-- slots fill the rows (10 at least), the picked one has a gold edge; the detail panel is tinted too: the icon big,
-- the name, a gold "YOU HAVE n" pill, what it does, a big USE and a small EQUIP / UNEQUIP under it.
-- BoostsPanel.Build(parent, opts?) -> { frame, refresh(), pick(key?) }. Placeholder icons: Config/UI icons in the item's color.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Audio = require(script.Parent.Parent.Audio)
local Boosts = require(script.Parent.Parent.Config.Boosts)
local ClientData = require(script.Parent.Parent.ClientData)

local New, Colors = Theme.New, Theme.Colors

local BoostsPanel = {}

local CELL = Vector2.new(112, 104)
local SLOTS = 10 -- (prompt 40: empty slots fill the grid to at least this many)
-- (prompt 40) a tile / panel in a colour: a dark tint of it, the hex mesh, a 3 px edge in it
local function tint(gui: GuiObject, color: Color3?, edge: Color3?)
	Theme.SetPiece(gui, "card")
	local sheen = gui:FindFirstChild("Sheen")
	if sheen and color then
		local base = color:Lerp(Color3.fromHex("#141215"), 0.72)
		sheen.Color = ColorSequence.new(base:Lerp(Color3.new(1, 1, 1), 0.05), base:Lerp(Color3.new(0, 0, 0), 0.4))
	end
	local border = gui:FindFirstChild("Border")
	if border then
		border.Color = edge or color or Colors.Outline
		border.Thickness = if color then 3 else 1.5
		border.Transparency = if color then 0 else 0.3
	end
	Theme.SetHex(gui, nil, 11) -- (owner, 22 Oct: item tiles are cards, solid)
end
local DETAIL_W = 206
local PAD = 8
local ICON = 44

-- the inventory item a running boost belongs to ("Shake" -> the Protein Shake, "Item_Creatine" -> Creatine)
local function itemOf(runningId: string): string?
	if runningId == "Shake" then return "Shake" end
	return string.match(runningId, "^Item_(.+)$")
end

function BoostsPanel.Build(parent: Instance, opts: { [string]: any }?)
	opts = opts or {}
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local running = opts.running or {}
	local dna = opts.dna
	local panel = { picked = nil }
	local frame = New("Frame", { Name = "Items", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	panel.frame = frame

	local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -(DETAIL_W + 10), 1, 0),
		ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = frame }, {
		New("UIGridLayout", { CellSize = UDim2.fromOffset(CELL.X, CELL.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
	})
	-- the empty state: a centred line with the shop's name in gold
	local empty = New("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = frame })
	Pieces.Icon("backpack", Colors.Faint, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -6), Size = UDim2.fromOffset(40, 40), Parent = empty })
	Kit.Text({ Name = "Line", Text = "No items yet. Get boosts at the <font color=\"#F6C75A\">PUMP SHOP</font>.", RichText = true, Font = "Strong",
		TextSize = 15, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, 22),
		Parent = empty })

	-- the picked tile
	local detail = Kit.Card({ Name = "Detail", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, DETAIL_W, 1, 0), Parent = frame }, {})
	local tileHolder = New("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, PAD),
		Size = UDim2.fromOffset(56, 56), Parent = detail })
	local name = Kit.Fit(Kit.Text({ Name = "Name", Text = "", Font = "Chunky", Upper = true, Position = UDim2.fromOffset(PAD, 68), Size = UDim2.new(1, -2 * PAD, 0, 20),
		Parent = detail }), 18, 11)
	local ownedPill = New("Frame", { Name = "OwnedPill", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(112, 18), Parent = detail }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
	})
	local owned = Kit.Text({ Name = "Owned", Text = "", Font = "Chunky", TextSize = 12, Upper = true, Size = UDim2.fromScale(1, 1), Parent = ownedPill })
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 12, TextWrapped = true, Position = UDim2.fromOffset(PAD, 112),
		Size = UDim2.new(1, -2 * PAD, 0, 30), TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
	text.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Italic)
	local duration = Kit.Text({ Name = "Duration", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(PAD, 142),
		Size = UDim2.new(1, -2 * PAD, 0, 14), Parent = detail })
	local useButton = Kit.Button("Green", "Use", { Name = "Use", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -32), Parent = detail },
		{ width = DETAIL_W - 2 * PAD, height = 32, textSize = 17 })
	local equipButton = Kit.Button("Quiet", "Equip", { Name = "Equip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = detail },
		{ width = DETAIL_W - 2 * PAD, height = 22, textSize = 12 })
	local wideButton = Kit.Button("Green", "Genetics", { Name = "Genetics", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -PAD),
		Visible = false, Parent = detail }, { width = DETAIL_W - 2 * PAD, height = 34, textSize = 16 })

	-- a tile: the icon on top, the name, and a gold line (the count or the time left); a small teal timer in the corner
	local tiles = {} -- [key] = { card, line, timer }
	local function makeTile(key: string, order: number, label: string, makeIcon: (Instance) -> ())
		local card = Kit.Card({ Name = key, LayoutOrder = order, Clickable = true, Visible = false, Parent = grid }, {})
		local icon = New("Frame", { Name = "IconHolder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(ICON + 8, ICON + 8), Parent = card })
		makeIcon(icon)
		Kit.Fit(Kit.Text({ Name = "Name", Text = string.upper(label), Font = "Chunky", Position = UDim2.fromOffset(PAD, ICON + 24), Size = UDim2.new(1, -2 * PAD, 0, 16), Parent = card }), 13, 10)
		-- the count: a small gold badge top-right ("x2"); a running boost's time left
		local badge = New("Frame", { Name = "Count", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5),
			Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = card }, {
			New("UICorner", { CornerRadius = UDim.new(0, 6) }),
			New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
			New("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }),
		})
		local line = Kit.Text({ Name = "Line", Text = "", Font = "Chunky", TextSize = 11, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 4, Parent = badge })
		local timer = Kit.Text({ Name = "Timer", Text = "", Font = "Number", TextSize = 11, TextColor3 = Colors.Teal, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(48, 14), TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = card })
		timer.AnchorPoint = Vector2.new(0, 0)
		timer.Position = UDim2.fromOffset(6, 5)
		card.Activated:Connect(function()
			Audio.PlayUI("Click")
			panel.pick(key)
		end)
		tiles[key] = { card = card, line = line, timer = timer }
	end
	-- the item colour of each tile key
	local colorOf = {}
	for _, item in ipairs(Boosts.Items) do colorOf["item:" .. item.id] = Color3.fromHex(item.color) end
	colorOf.dna = Theme.RarityColor.Mythic
	for _, boost in ipairs(running) do colorOf["run:" .. boost.id] = boost.color end
	-- the empty slots (dark, quiet)
	local slots = {}
	for i = 1, SLOTS do
		local slot = New("Frame", { Name = "Slot" .. i, LayoutOrder = 1000 + i, BackgroundColor3 = Color3.new(1, 1, 1), Parent = grid })
		Theme.SetPiece(slot, "card")
		Theme.SetHex(slot, nil, 11)
		slots[i] = slot
	end
	for order, item in ipairs(Boosts.Items) do
		makeTile("item:" .. item.id, order, item.name, function(holder)
			Kit.IconTile(item.icon, Color3.fromHex(item.color), ICON + 8, { Parent = holder })
		end)
	end
	if dna then
		makeTile("dna", 100, "DNA Tokens", function(holder)
			Pieces.ShopIcon("product_dna_token", { Size = UDim2.fromScale(1, 1), Parent = holder })
		end)
	end
	for order, boost in ipairs(running) do
		makeTile("run:" .. boost.id, 200 + order, boost.name, function(holder)
			Kit.IconTile(boost.icon, boost.color, ICON + 8, { Parent = holder })
		end)
	end

	local function countOf(id: string): number
		local items = ClientData.Get().items
		return items and tonumber(items[id]) or 0
	end
	local function serverNow() return Workspace:GetServerTimeNow() end
	local function itemEnds(id: string): number?
		local ends = player:GetAttribute(if id == "Shake" then "ShakeEnds" else "Item_" .. id)
		return if type(ends) == "number" and ends > serverNow() then ends else nil
	end
	local function clock(ends: number): string
		return if ends == math.huge then "Always on" else Boosts.Clock(ends - serverNow())
	end
	local runningById = {}
	for _, boost in ipairs(running) do runningById[boost.id] = boost end

	function panel.refresh()
		local first = nil
		local shown = {}
		for _, item in ipairs(Boosts.Items) do
			local key = "item:" .. item.id
			local n = countOf(item.id)
			local t = tiles[key]
			t.card.Visible = n > 0
			t.line.Text = "x" .. Kit.Format(n)
			local ends = itemEnds(item.id)
			t.timer.Visible = ends ~= nil
			if ends then t.timer.Text = clock(ends) end
			if n > 0 then
				shown[key] = true
				first = first or key
			end
		end
		if dna then
			local n = dna.count()
			tiles.dna.card.Visible = n > 0
			tiles.dna.line.Text = "x" .. Kit.Format(n)
			if n > 0 then
				shown.dna = true
				first = first or "dna"
			end
		end
		for _, boost in ipairs(running) do
			local key = "run:" .. boost.id
			local ends = boost.ends()
			local item = itemOf(boost.id)
			-- (an item you hold shows its own timer on its tile)
			local on = ends ~= nil and not (item and shown["item:" .. item])
			tiles[key].card.Visible = on
			if on then
				tiles[key].line.Text = clock(ends)
				shown[key] = true
				first = first or key
			end
		end
		local count = 0
		for key, t in pairs(tiles) do
			tint(t.card, colorOf[key], if panel.picked == key then Colors.Gold else nil)
			if t.card.Visible then count += 1 end
		end
		for i, slot in ipairs(slots) do slot.Visible = count + i <= math.max(SLOTS, count) end
		empty.Visible = first == nil
		grid.Visible = first ~= nil
		-- the picked one is gone (used up, ran out) or nothing picked yet: the first one there is
		if not panel.picked or not shown[panel.picked] then
			local keep = panel.picked and string.sub(panel.picked, 1, 5) == "item:" and player:GetAttribute("Equipped_" .. string.sub(panel.picked, 6))
			if not keep then panel.picked = first end
		end
		detail.Visible = panel.picked ~= nil
		if not panel.picked then return end
		for _, child in ipairs(tileHolder:GetChildren()) do child:Destroy() end
		local key = panel.picked
		local kind, id = string.match(key, "^(%a+):?(.*)$")
		tint(detail, colorOf[key])
		useButton.Visible, equipButton.Visible, wideButton.Visible = false, false, false
		if kind == "item" then
			local item = Boosts.ById[id]
			if not item then return end
			Kit.IconTile(item.icon, Color3.fromHex(item.color), 56, { Parent = tileHolder })
			name.Text = item.name
			local n = countOf(item.id)
			owned.Text = "You have " .. Kit.Format(n)
			text.Text = item.text
			local ends = itemEnds(item.id)
			duration.Text = (if item.shake then "Lasts " .. item.duration .. " (stacks to 90 s)" else item.duration .. " per use, up to 60 min")
				.. (if ends then " · " .. clock(ends) .. " left" else "")
			useButton.Visible, equipButton.Visible = true, true
			Kit.SetButton(useButton, if n > 0 then "Green" else "Disabled", "Use")
			Kit.SetButton(equipButton, if n > 0 or player:GetAttribute("Equipped_" .. item.id) then "Quiet" else "Disabled",
				if player:GetAttribute("Equipped_" .. item.id) then "Unequip" else "Equip")
		elseif kind == "dna" and dna then
			Pieces.ShopIcon("product_dna_token", { Size = UDim2.fromScale(1, 1), Parent = tileHolder })
			name.Text = "DNA Tokens"
			owned.Text = "You have " .. Kit.Format(dna.count())
			text.Text = "Reroll your genetics on the Genetics screen."
			duration.Text = ""
			wideButton.Visible = true
		elseif kind == "run" then
			local boost = runningById[id]
			if not boost then return end
			Kit.IconTile(boost.icon, boost.color, 56, { Parent = tileHolder })
			name.Text = boost.name
			local ends = boost.ends()
			owned.Text = if ends then (if ends == math.huge then "Always on" else clock(ends) .. " left") else ""
			text.Text = boost.sub
			duration.Text = "Running now"
		end
	end

	-- (the gold pill only when it has words)
	owned:GetPropertyChangedSignal("Text"):Connect(function() ownedPill.Visible = owned.Text ~= "" end)

	function panel.pick(key: string?)
		panel.picked = key
		panel.refresh()
	end

	local function pickedItem(): string?
		local key = panel.picked
		return if key and string.sub(key, 1, 5) == "item:" then string.sub(key, 6) else nil
	end
	useButton.Activated:Connect(function()
		local id = pickedItem()
		if not id or countOf(id) <= 0 then return end
		remotes.PlayerAction:FireServer(if id == "Shake" then "DrinkShake" else "UseItem", id)
	end)
	equipButton.Activated:Connect(function()
		local id = pickedItem()
		if not id then return end
		Audio.PlayUI("Click")
		remotes.PlayerAction:FireServer("EquipItem", id)
	end)
	wideButton.Activated:Connect(function()
		Audio.PlayUI("Click")
		if dna and dna.onUse then dna.onUse() end
	end)
	player.AttributeChanged:Connect(function(attribute)
		if frame.Visible and (string.sub(attribute, 1, 5) == "Item_" or string.sub(attribute, 1, 9) == "Equipped_" or attribute == "ShakeEnds") then panel.refresh() end
	end)
	return panel
end

return BoostsPanel
