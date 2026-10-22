-- PumpShopClient (owner, prompt 19, 21 Oct): the shop window and its HUD bits (PumpShopService sells; numbers in
-- Config.PumpShop). Coins only.
-- (prompt 31, 22 Oct) ONE window for the three shops (Config.PumpShop.Shops): Coach Dex (normal supplements, Basic / Pro
-- gear, ALTERS), the PUMP SHOP (specials, Elite / Champion gear, DNA LAB) and the coconut stand (Coconut Water x1 / x5).
-- (prompt 47) The window is a row of Store-style tiles + a detail strip (see "The window" below).
-- The title and tabs follow the shop that opened it; tabs are always SUPPLEMENTS / GEAR (+ ALTERS / DNA LAB). Apparel
-- is off sale (no try-on any more).
--   * The window (a counter's "Shop" prompt opens it on that section; every section has a tab): on the left the picked
--     item big (art, name, what it does, price, buttons), on the right the section's tiles.
--       SUPPLEMENTS  the boosts (Config.Boosts): BUY x1 / x5 / x10 (into the inventory)
--       GEAR         belt, wraps, straps, sleeves: Basic -> Pro -> Elite, what each helps, BUY the next level
--       APPAREL      shorts and tank top colors, headbands, shakers, gym bags: TRY ON (a few seconds) and BUY
--       DNA LAB      a DNA token (this week's price: +10% for each one bought this week) and "Reroll genetics"
--     Gear and Apparel show a lock until Growth Spurt 2.
--   * Going there (10 s cooldown): the Shop window's "Go to PUMP SHOP" link (UIBus.GoPumpShop; prompt 28: it was a tile in
--     the left menu, the menu keeps 8 buttons).
--   * "You can afford: Pro Lifting Belt!": a small gold note once a newly affordable thing appears (at most every 5 min);
--     tapping it goes to the shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PumpShop = require(Shared.Config.PumpShop)
local Boosts = require(Shared.Config.Boosts)
local Body = require(Shared.Config.Body)
local Cosmetics = require(Shared.Config.Cosmetics)
local DNA = require(Shared.Config.DNA)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local Alters = require(Shared.Config.Alters)
local AlterThemes = require(Shared.Config.AlterThemes)
local Muscles = require(Shared.Config.Muscles)
local Machines = require(Shared.Config.Machines)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local AlterFX = require(Shared.VFX.AlterFX)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("PumpShop", 60) :: RemoteEvent
if not remote then return end

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 770, 290 -- (wide enough for the title, the tabs and the coins pill; prompt 47: taller for the tile row + detail strip)
local shopId = "Pump" -- the shop the window shows (PumpShop.Shops)
local function shop() return PumpShop.Shops[shopId] or PumpShop.Shops.Pump end

------------------------------------------------------------------------
-- What's on sale
------------------------------------------------------------------------
local function data() return ClientData.Get() or {} end
local function spurts() return data().growthSpurts or 0 end
local function coins() return data().coins or 0 end
local function owned() return (data().cosmetics or {}).owned or {} end
local function sectionOpen(id: string): boolean
	local open = player:GetAttribute("PumpShop")
	if not open then return false end
	for _, section in ipairs(PumpShop.Sections) do
		if section.id == id then
			if section.atMax then return GrowthSpurts.IsMaxed(spurts()) end
			return spurts() >= (section.fromSpurt or 0)
		end
	end
	return false
end

-- one tile = { key, section, name, sub, icon, color, price(), state() }
local function bodyEntry(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then return entry end
	end
	return nil
end

local entries = { Supplements = {}, Gear = {}, DnaLab = {}, Alters = {} }

-- (prompt 21) ALTERS: the alters of the tier you're in (the next one picked first), each with its state; nothing is sold
local function alterProgress()
	local d = data()
	return Alters.Progress(d, Muscles.Groups, Machines.TrainableMuscles(d.growthSpurts or 0))
end
local function alterEntries()
	local progress = alterProgress()
	local tier = math.max(1, Alters.TierOf(math.min(progress.next, #Alters.List)))
	local list = {}
	for _, alter in ipairs(Alters.List) do
		if alter.tier == tier then
			table.insert(list, { key = alter.id, section = "Alters", alter = alter, name = alter.name, icon = "flame",
				color = AlterThemes.Get(alter.number).accent, price = function() return nil end })
		end
	end
	return list, progress
end
local function alterStatus(entry, progress): (string, Color3)
	local n = entry.alter.number
	if n < progress.next then return "DONE", Colors.Green end
	if not entry.alter.textures or n > Alters.LastAvailable() then return "SOON", Colors.Muted end
	if n == progress.next then
		if progress.ready then return "READY", Colors.Gold end
		local have, need = 0, 0
		for _, group in ipairs(Muscles.Groups) do
			have += Muscles.Shown(math.min(progress.groups[group.id] or 0, progress.required))
			need += Muscles.Shown(progress.required)
		end
		return math.floor(need > 0 and have / need * 100 or 0) .. "%", Colors.Teal
	end
	return "ALTER " .. n, Colors.Muted
end
for _, supplement in ipairs(PumpShop.Supplements) do
	local item = Boosts.ById[supplement.id]
	table.insert(entries.Supplements, { key = item.id, section = "Supplements", name = item.name, sub = item.text .. " Lasts " .. item.duration .. ".",
		icon = item.icon, color = Color3.fromHex(item.color), price = function() return PumpShop.SupplementPrice(item.id, spurts()) end })
end
for _, gear in ipairs(PumpShop.Gear) do
	table.insert(entries.Gear, { key = gear.id, section = "Gear", gear = gear, name = gear.name, icon = "dumbbell",
		color = Color3.fromHex("#C98A12"), sub = "Worn: more EXP on " .. gear.area .. "." })
end
table.insert(entries.DnaLab, { key = "DnaToken", section = "DnaLab", name = "DNA Token", icon = "sparkles", color = Colors.Gold,
	sub = "One genetics reroll.", price = function() return PumpShop.DnaPriceFor(data(), DNA.CoinPrice) end })

-- gear: the next level to buy (nil = all owned) and the highest owned
local function gearLevels(gear)
	local have, nextLevel = nil, nil
	for _, level in ipairs(PumpShop.GearLevels) do
		if owned()[PumpShop.GearItemId(gear.id, level.id)] then have = level elseif not nextLevel then nextLevel = level end
	end
	return have, nextLevel
end

local function isOwned(entry): boolean
	if entry.section == "Gear" then
		local _, nextLevel = gearLevels(entry.gear)
		return nextLevel == nil
	end
	return false
end

local function priceOf(entry): number?
	if entry.section == "Gear" then
		local _, nextLevel = gearLevels(entry.gear)
		return nextLevel and nextLevel.price
	end
	return entry.price and entry.price()
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local tab = "Supplements"
local picked = {} -- [section] = entry key
local refresh -- (below)
local openOn -- (below)
local tabs = {}
for _, section in ipairs(PumpShop.Sections) do table.insert(tabs, { id = section.id, text = section.name, icon = section.icon }) end
local modal = Kit.Modal({ name = "PumpShop", title = "Pump Shop", icon = "dumbbell", width = W, height = H, displayOrder = 25, tabs = tabs, coins = true,
	onTab = function(id)
		tab = id
		refresh()
	end })
-- (prompt 31) only the shop's own tabs show
local tabRow = modal.panel:FindFirstChild("Tabs", true)
local function showShopTabs()
	for _, section in ipairs(PumpShop.Sections) do
		local button = tabRow and tabRow:FindFirstChild(section.id)
		if button then button.Visible = table.find(shop().tabs, section.id) ~= nil end
	end
	modal.setTitle(shop().title)
end

-- (prompt 47, 22 Oct; like the Store, prompt 40 mockups 01_store_A / real\store_auras) A row of item tiles (Kit.RewardTile:
-- the item's big icon on a soft glow in its color, the name, the effect as a gold pill "+50% EXP · 15 MIN", a chunky
-- green BUY button with the coin price; can't afford = grey + "NEED 1,200 MORE"; owned gear = a gold OWNED stamp; the
-- Champion gear's border has a gold highlight running round it). The picked tile shows a detail strip at the bottom:
-- icon, name, what it does in one plain line, and its buttons (BUY x1 / x5 for supplements, the next gear level, DNA:
-- BUY TOKEN / REROLL, alters: ALTER NOW / MY SKINS). Buying: the coins count down, the item flies to the Inventory button.
local STRIP_H = 64
local TILE_W, TILE_H = 132, 148
local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -(STRIP_H + 8)),
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.X, Parent = modal.body }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
})
local lockNote = Kit.Text({ Name = "Locked", Text = "", Font = "Chunky", TextSize = 18, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(0.8, 0, 0, 60), Visible = false, Parent = modal.body })

-- the detail strip
local strip = New("Frame", { Name = "Detail", BackgroundColor3 = Color3.fromHex("#141317"), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, STRIP_H), Parent = modal.body }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Name = "Edge", Color = Colors.Gold, Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
-- (owner, 23 Oct, chrome reset: no mesh on a child of the panel)
local stripIcon = New("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(52, 52), Parent = strip })
local stripName = Kit.Text({ Name = "Name", Text = "", Font = "Chunky", TextSize = 18, Position = UDim2.fromOffset(68, 8), Size = UDim2.new(1, -340, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = strip })
Kit.Fit(stripName, 18, 11)
local stripLine = Kit.Text({ Name = "Line", Text = "", Font = "Strong", TextSize = 12, TextColor3 = Color3.fromHex("#BDBAC4"), TextWrapped = true, Position = UDim2.fromOffset(68, 30),
	Size = UDim2.new(1, -340, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = strip })
Kit.Fit(stripLine, 12, 9, 2)
local buttonRow = New("Frame", { Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(330, 48), Parent = strip }, { Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })

local function clearButtons()
	for _, child in ipairs(buttonRow:GetChildren()) do
		if child:IsA("GuiButton") then child:Destroy() end
	end
end
local function addButton(style, text, width, onTap, order)
	local button = Kit.Button(style, text, { LayoutOrder = order or 1, Parent = buttonRow }, { width = width, height = 44, textSize = 15, icon = if style == "Green" then "coin" else nil })
	button.Activated:Connect(function()
		if style == "Disabled" then return end
		Audio.PlayUI("Click")
		onTap(button)
	end)
	return button
end

local function iconOf(entry): string
	local item = Boosts.ById[entry.key]
	return if item then item.icon else entry.icon
end
local function setIcon(holder: GuiObject, entry)
	holder:ClearAllChildren()
	local icon = iconOf(entry)
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		New("ImageLabel", { BackgroundTransparency = 1, Image = icon, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Parent = holder })
	else
		Kit.IconTile(icon, entry.color, math.floor(holder.AbsoluteSize.X > 0 and holder.AbsoluteSize.X or 52), { Size = UDim2.fromScale(1, 1), Parent = holder })
	end
end

-- the effect pill text: "+50% EXP · 15 MIN"
local function effectText(entry): string
	if entry.section == "Supplements" then
		local item = Boosts.ById[entry.key]
		return (item.short or item.text) .. (if item.duration then " · " .. string.upper(item.duration) else "")
	elseif entry.section == "Gear" then
		local _, nextLevel = gearLevels(entry.gear)
		local level = nextLevel or PumpShop.GearLevels[#PumpShop.GearLevels]
		return "+" .. math.floor(level.bonus * 100 + 0.5) .. "% EXP · " .. string.upper(level.name)
	elseif entry.section == "DnaLab" then
		return "1 REROLL"
	end
	return ""
end

-- the item flies from its tile to the Inventory button (after a buy)
local function flyToInventory(entry, from: GuiObject?)
	local target = nil
	local hud = player.PlayerGui:FindFirstChild("MainHud")
	target = hud and hud:FindFirstChild("Inventory", true)
	local gui = Theme.ScreenGui({ Name = "BuyFly", DisplayOrder = 60, Parent = player.PlayerGui })
	gui.IgnoreGuiInset = true
	local start = if from then from.AbsolutePosition + from.AbsoluteSize / 2 else Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
	local goal = if target and target.AbsoluteSize.X > 0 then target.AbsolutePosition + target.AbsoluteSize / 2 else Vector2.new(60, workspace.CurrentCamera.ViewportSize.Y / 2)
	local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(start.X, start.Y + 58), Size = UDim2.fromOffset(56, 56),
		Parent = gui })
	setIcon(holder, entry)
	local TweenService = game:GetService("TweenService")
	TweenService:Create(holder, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(goal.X, goal.Y + 58), Size = UDim2.fromOffset(26, 26) }):Play()
	task.delay(0.6, function()
		gui:Destroy()
		if target then
			local scale = target:FindFirstChild("BuyPop") or New("UIScale", { Name = "BuyPop", Parent = target })
			scale.Scale = 1.2
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
end

local tilesByKey = {}
local lastBuyTile = nil
local function buy(entry, ...)
	lastBuyTile = tilesByKey[entry.key]
	remote:FireServer("Buy", shopId, ...)
end

local function showStrip(entry)
	if not entry then
		strip.Visible = false
		return
	end
	strip.Visible = true
	setIcon(stripIcon, entry)
	stripName.Text = string.upper(entry.name)
	clearButtons()
	local price = priceOf(entry)
	local afford = price ~= nil and coins() >= price
	if entry.section == "Supplements" then
		local item = Boosts.ById[entry.key]
		local have = (data().items or {})[entry.key] or 0
		stripLine.Text = item.text .. " Lasts " .. item.duration .. ". You have " .. have .. "."
		for i, quantity in ipairs(shop().quantities or { 1, 5 }) do
			if quantity <= 5 then
				local cost = (price or 0) * quantity
				addButton(if coins() >= cost then "Green" else "Disabled", "x" .. quantity .. "  " .. Kit.Format(cost), 140, function()
					buy(entry, "Supplements", entry.key, quantity)
				end, i)
			end
		end
	elseif entry.section == "Gear" then
		local have, nextLevel = gearLevels(entry.gear)
		local parts = { "Worn: more EXP on " .. entry.gear.area .. "." }
		if have then table.insert(parts, "You have " .. have.name .. ".") end
		stripLine.Text = table.concat(parts, " ")
		if nextLevel and table.find(shop().gear, nextLevel.id) then
			addButton(if afford then "Green" else "Disabled", "Buy " .. nextLevel.name .. "  " .. Kit.Format(nextLevel.price), 230, function()
				buy(entry, "Gear", entry.gear.id)
			end)
		elseif nextLevel then
			local atCoach = table.find(PumpShop.Shops.Coach.gear, nextLevel.id) ~= nil
			addButton("Quiet", if atCoach then "Go to Coach Dex" else "Go to Pump Shop", 200, function()
				modal.close()
				if atCoach then UIBus.GoCoach:Fire() else UIBus.GoPumpShop:Fire() end
			end)
		else
			stripLine.Text = stripLine.Text .. " Every level owned."
		end
	elseif entry.section == "Alters" then
		local progress = alterProgress()
		local status = alterStatus(entry, progress)
		local n = entry.alter.number
		stripName.Text = "ALTER " .. n .. ": " .. string.upper(entry.alter.name)
		if n < progress.next then
			stripLine.Text = "Done. Wear this skin from Inventory > Looks."
		elseif status == "SOON" then
			stripLine.Text = "Coming soon in an update."
		else
			stripLine.Text = string.format("Goal: %s exp in every group. Gains x%.2f after.", Muscles.FormatExpShort(Muscles.Shown(Alters.Goal(n))), Alters.Bonus(n))
		end
		addButton("Quiet", "My skins", 130, function()
			modal.close()
			UIBus.OpenInventory:Fire("Alters")
		end, 1)
		if n == progress.next and progress.ready then
			addButton("Gold", "Alter now", 150, function()
				modal.close()
				UIBus.StartAlter:Fire()
			end, 2)
		end
	elseif entry.section == "DnaLab" then
		local state = data().dnaWeek
		local bought = if type(state) == "table" and state.week == PumpShop.Week() then state.bought or 0 else 0
		stripLine.Text = string.format("One genetics reroll. You have %d. This week: %d bought (+10%% each, resets Monday).", data().dnaTokens or 0, bought)
		addButton("Quiet", "Reroll", 110, function()
			modal.close()
			UIBus.OpenGenetics:Fire()
		end, 1)
		addButton(if afford then "Green" else "Disabled", "Buy  " .. Kit.Format(price or 0), 160, function()
			lastBuyTile = tilesByKey[entry.key]
			Remotes.PlayerAction:FireServer("BuyDnaToken")
		end, 2)
	end
end

-- the Champion gear's border: a gold highlight runs round it
local spinning = {}
task.spawn(function()
	while true do
		task.wait(1 / 30)
		if modal.isOpen() then
			for gradient in pairs(spinning) do
				if gradient.Parent then gradient.Rotation = (os.clock() * 90) % 360 else spinning[gradient] = nil end
			end
		end
	end
end)

-- (prompt 54, 23 Oct) the ALTERS tab works like the Inventory's Looks > Alters (Shared/UI/AltersPanel, shop mode): the
-- tiles on the left (the path, bicep icons, ??? undiscovered), the picked one in a detail panel on the right with ALTER
-- NOW / WHAT TO TRAIN / OWNED + MY SKINS. It opens on the next alter.
local AltersPanel = require(Shared.UI.AltersPanel)
local altersPanel = AltersPanel.Build(modal.body, { mode = "shop", columns = 3, onClose = function() modal.close() end })
local altersWasShown = false

function refresh()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(tilesByKey)
	table.clear(spinning)
	local open = sectionOpen(tab)
	lockNote.Visible = not open
	local altersShown = open and tab == "Alters"
	altersPanel.frame.Visible = altersShown
	if altersShown then
		grid.Visible = false
		strip.Visible = false
		if not altersWasShown then altersPanel.selectNext() else altersPanel.refresh() end
		altersWasShown = true
		return
	end
	altersWasShown = false
	grid.Visible = open
	if not open then
		lockNote.Text = if tab == "Alters" then "BODY ALTERS OPEN AT 7'0\". KEEP GROWING!" else "GEAR OPENS AT GROWTH SPURT 2. KEEP TRAINING!"
		strip.Visible = false
		return
	end
	local list = entries[tab]
	if tab == "Supplements" then
		local mine = {}
		for _, id in ipairs(shop().supplements) do
			for _, entry in ipairs(entries.Supplements) do
				if entry.key == id then table.insert(mine, entry) end
			end
		end
		list = mine
		if picked.Supplements and not bodyEntry(list, picked.Supplements) then picked.Supplements = nil end
		for _, entry in ipairs(list) do entry.id = entry.key end
	end
	local altersNow = nil
	if tab == "Alters" then
		list, altersNow = alterEntries()
		local nextAlter = Alters.Get(altersNow.next)
		if not picked.Alters or not bodyEntry(list, picked.Alters) then picked.Alters = nextAlter and nextAlter.id or (list[1] and list[1].key) end
		for _, entry in ipairs(list) do entry.id = entry.key end
	end
	if not picked[tab] and list[1] then picked[tab] = list[1].key end
	for order, entry in ipairs(list) do
		local color = entry.color or Colors.Gold
		local champion = false
		if entry.section == "Gear" then
			local have, nextLevel = gearLevels(entry.gear)
			local level = nextLevel or have
			if level then
				color = Color3.fromHex(level.color)
				champion = level.id == "Champion"
			end
		elseif entry.section == "Alters" then
			color = AlterThemes.Get(entry.alter.number).accent
		end
		if color == Color3.fromHex("#2B2B30") then color = Color3.fromHex("#8A8790") end -- (Basic black: readable)
		local tile, api = Kit.RewardTile(color, { Name = entry.key, LayoutOrder = order, Size = UDim2.fromOffset(TILE_W, TILE_H), Parent = grid })
		tilesByKey[entry.key] = tile
		-- the big icon on a soft glow
		local icon = iconOf(entry)
		AlterFX.Image(tile, "ember", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 42), Size = UDim2.fromOffset(104, 104),
			ImageColor3 = color, ImageTransparency = 0.55, ZIndex = 1 })
		if string.sub(icon, 1, 13) == "rbxassetid://" then
			api.art.Image = icon
		else
			api.art.Image = ""
			local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(60, 60),
				ZIndex = 2, Parent = tile })
			Kit.IconTile(icon, color, 60, { Size = UDim2.fromScale(1, 1), Parent = holder })
		end
		api.art.Size = UDim2.new(0.8, 0, 0, 74)
		api.name.Text = entry.name
		api.name.Position = UDim2.new(0.5, 0, 1, -48)
		-- the effect as a gold pill (sub line), the price on the green button (pill)
		local effect = effectText(entry)
		api.sub.Visible = effect ~= ""
		api.sub.Text = effect
		api.sub.TextColor3 = Colors.Gold
		api.sub.Position = UDim2.new(0.5, 0, 1, -33)
		local price = priceOf(entry)
		if entry.section == "Alters" then
			local status = alterStatus(entry, altersNow)
			api:SetState(if entry.alter.number < altersNow.next then "owned" else "normal", status)
			if entry.alter.number >= altersNow.next then api:SetRequirement(status) end
		elseif isOwned(entry) then
			api:SetState("owned", "OWNED")
			-- the gold stamp
			api.pill.Size = UDim2.new(0.7, 0, 0, 22)
			api:SetPill("OWNED", Colors.Gold)
			api.check.BackgroundColor3 = Colors.Gold
		elseif entry.section == "Gear" and price and not table.find(shop().gear, (select(2, gearLevels(entry.gear))).id) then
			-- (sold in the other shop)
			local _, nextLevel = gearLevels(entry.gear)
			api:SetRequirement(if table.find(PumpShop.Shops.Coach.gear, nextLevel.id) then "AT COACH DEX" else "AT PUMP SHOP")
		elseif price then
			if coins() >= price then
				api:SetPill(Kit.Format(price), Colors.Green)
			else
				api:SetPill("NEED " .. Kit.Format(price - coins()) .. " MORE", Color3.fromHex("#4A474F"))
			end
		end
		if champion then
			local border = tile:FindFirstChild("Border")
			if border then
				border.Color = Color3.new(1, 1, 1)
				local gradient = New("UIGradient", { Name = "Spin", Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#C98A12")),
					ColorSequenceKeypoint.new(0.45, Color3.fromHex("#F6C75A")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FFF3C4")),
					ColorSequenceKeypoint.new(0.55, Color3.fromHex("#F6C75A")), ColorSequenceKeypoint.new(1, Color3.fromHex("#C98A12")) }), Parent = border })
				spinning[gradient] = true
			end
		end
		local scale = tile:FindFirstChild("PickScale") or New("UIScale", { Name = "PickScale", Parent = tile })
		scale.Scale = if picked[tab] == entry.key then 1 else 0.96
		tile:SetAttribute("Picked", picked[tab] == entry.key)
		tile.Activated:Connect(function()
			-- (prompt 54) the grid is rebuilt: the new tile does the bounce (quiet: Kit.RewardTile's hook played the sound)
			picked[tab] = entry.key
			refresh()
			local now = tilesByKey[entry.key]
			if now then Kit.SelectFeedback(now, strip, true) end
		end)
	end
	local current = nil
	for _, entry in ipairs(list) do
		if entry.key == picked[tab] then current = entry end
	end
	showStrip(current)
end

function openOn(section: string?, newShop: string?)
	if newShop and PumpShop.Shops[newShop] then shopId = newShop end
	showShopTabs()
	if section and not table.find(shop().tabs, section) then section = "Supplements" end
	if section then
		tab = section
		modal.selectTab(section)
	end
	refresh()
	if not modal.isOpen() then
		UIBus.PanelOpened("PumpShop")
		modal.open()
		Audio.PlayUI("Whoosh")
	end
end
UIBus.RegisterPanel("PumpShop", function() modal.close() end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if modal.isOpen() and (key == "coins" or key == "items" or key == "cosmetics" or key == "dnaWeek" or key == "dnaTokens" or key == "growthSpurts") then refresh() end
end)

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" then
		openOn(info.section, info.shop)
	elseif kind == "Failed" then
		Notify.Toast("Can't buy that", tostring(info.text or ""), "coin", Colors.Red, "pumpfail")
	elseif kind == "Bought" then
		Audio.PlayUI("ShopBuy")
		-- (prompt 47) the item flies into the Inventory button
		local entry = nil
		for _, list in pairs(entries) do
			for _, e in ipairs(list) do
				if e.key == info.id or (e.gear and info.id and string.sub(info.id, 1, #e.gear.id + 1) == e.gear.id .. "_") then entry = e end
			end
		end
		if entry then pcall(flyToInventory, entry, lastBuyTile) end
		if info.section == "Gear" then
			local item = Cosmetics.ById[info.id]
			Notify.Reward("NEW GEAR", (item and item.name or "Gear") .. " · wearing it now", "dumbbell", Colors.Gold)
		end
		if modal.isOpen() then refresh() end
	elseif kind == "Teleported" then
		Notify.Hint("Welcome to the PUMP SHOP! Walk up to the counter.")
	elseif kind == "TeleportedCoach" then
		-- the camera behind you, looking at him (it kept its old angle and could end up inside the gym's front wall)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if root and camera then
			local look = root.CFrame.LookVector
			camera.CFrame = CFrame.lookAt(root.Position - look * 10 + Vector3.new(0, 4, 0), root.Position + look * 6)
		end
		Notify.Hint("Talk to Coach Dex to shop.")
	end
end)

------------------------------------------------------------------------
-- Go to the shop (10 s cooldown): the Shop window's link (prompt 28; was a left menu tile)
------------------------------------------------------------------------
local lastGo = -math.huge
local function goToShop()
	if os.clock() - lastGo < PumpShop.TeleportCooldown then
		Notify.Show(string.format("Wait %d s to go to the PUMP SHOP again.", math.ceil(PumpShop.TeleportCooldown - (os.clock() - lastGo))), nil, "pumpwait")
		return
	end
	lastGo = os.clock()
	remote:FireServer("Teleport")
end
UIBus.GoPumpShop.Event:Connect(goToShop)
-- (prompt 31) the Shop window's "Coach Dex" link: to his counter in the Starter Gym (10 s cooldown, checked on the server)
local lastCoach = -math.huge
UIBus.GoCoach.Event:Connect(function()
	if os.clock() - lastCoach < PumpShop.CoachTeleportCooldown then
		Notify.Show(string.format("Wait %d s to go to Coach Dex again.", math.ceil(PumpShop.CoachTeleportCooldown - (os.clock() - lastCoach))), nil, "coachwait")
		return
	end
	lastCoach = os.clock()
	remote:FireServer("TeleportCoach")
end)

------------------------------------------------------------------------
-- "You can afford: ..." (a newly affordable gear level or apparel item; at most every AffordEvery seconds)
------------------------------------------------------------------------
local affordGui = Theme.ScreenGui({ Name = "PumpShopAfford", DisplayOrder = 47, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
affordGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local affordRoot = Kit.Root(affordGui)
local affordButton = Kit.Button("Gold", "", { Name = "Afford", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Parent = affordRoot },
	{ height = 44, textSize = 14, icon = "coin" })
Kit.OnTopbar(function() affordButton.Position = UDim2.new(0.5, 0, 0, Kit.UnderTopbar(affordRoot) + 40) end)
local announced = {} -- [key] = true (this session)
local lastAfford = -math.huge
local affordToken = 0
local affordAtCoach = false -- (prompt 31) the newly affordable level is sold by Coach Dex (Basic / Pro), not the PUMP SHOP
affordButton.Activated:Connect(function()
	affordGui.Enabled = false
	if affordAtCoach then UIBus.GoCoach:Fire() else goToShop() end
end)

local function checkAfford()
	if not player:GetAttribute("PumpShop") or os.clock() - lastAfford < PumpShop.AffordEvery or UIBus.MenuOpen then return end
	local best = nil
	for _, section in ipairs({ "Gear" }) do
		if sectionOpen(section) then
			for _, entry in ipairs(entries[section]) do
				local price = priceOf(entry)
				local key = entry.key .. "@" .. tostring(price)
				if price and not isOwned(entry) and not announced[key] and coins() >= price and (not best or price > best.price) then
					best = { entry = entry, price = price, key = key }
				end
			end
		end
	end
	if not best then return end
	announced[best.key] = true
	lastAfford = os.clock()
	local name = best.entry.name
	affordAtCoach = false
	if best.entry.section == "Gear" then
		local _, nextLevel = gearLevels(best.entry.gear)
		name = (nextLevel and nextLevel.name .. " " or "") .. name
		affordAtCoach = nextLevel ~= nil and table.find(PumpShop.Shops.Coach.gear, nextLevel.id) ~= nil
	end
	Kit.SetButton(affordButton, nil, "You can afford: " .. name .. "!")
	affordGui.Enabled = true
	Audio.PlayUI("QuestClaim")
	affordToken += 1
	local mine = affordToken
	task.delay(6, function() if affordToken == mine then affordGui.Enabled = false end end)
end
task.spawn(function()
	ClientData.Get()
	-- (things already affordable when you join don't all pop up at once: only what becomes affordable later)
	task.wait(20)
	for _, section in ipairs({ "Gear" }) do
		for _, entry in ipairs(entries[section]) do
			local price = priceOf(entry)
			if price and coins() >= price then announced[entry.key .. "@" .. tostring(price)] = true end
		end
	end
	while true do
		task.wait(5)
		pcall(checkAfford)
	end
end)
