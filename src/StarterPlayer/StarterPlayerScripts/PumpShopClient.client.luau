-- PumpShopClient (owner, prompt 19, 21 Oct): the PUMP SHOP window and its HUD bits (PumpShopService sells; numbers in
-- Config.PumpShop). Coins only.
--   * The window (a counter's "Shop" prompt opens it on that section; every section has a tab): on the left the picked
--     item big (art, name, what it does, price, buttons), on the right the section's tiles.
--       SUPPLEMENTS  the boosts (Config.Boosts): BUY x1 / x5 / x10 (into the inventory)
--       GEAR         belt, wraps, straps, sleeves: Basic -> Pro -> Elite, what each helps, BUY the next level
--       APPAREL      shorts and tank top colors, headbands, shakers, gym bags: TRY ON (a few seconds) and BUY
--       DNA LAB      a DNA token (this week's price: +10% for each one bought this week) and "Reroll genetics"
--     Gear and Apparel show a lock until Growth Spurt 2.
--   * The PUMP SHOP tile in the left menu (once the shop is open): a tap goes to the entrance (10 s cooldown).
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
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("PumpShop", 60) :: RemoteEvent
if not remote then return end

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 770, 262 -- (wide enough for the title, five tabs and the coins pill; 693 px on a 667 x 375 phone)
local HERO_W = 214
local TILE = Vector2.new(112, 78)

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

local entries = { Supplements = {}, Gear = {}, Apparel = {}, DnaLab = {}, Alters = {} }

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
for _, entry in ipairs(PumpShop.Apparel) do
	local name, color, icon
	if entry.kind == "Shorts" then
		local shorts = bodyEntry(Body.ShortsColors, entry.id)
		name, color, icon = shorts.name .. " shorts", shorts.color, "star"
	elseif entry.kind == "Top" then
		local top = bodyEntry(Body.Tops, entry.id)
		name, color, icon = top.name, top.color, "star"
	else
		local item = Cosmetics.ById[entry.id]
		name, color, icon = item.name, item.color, if item.slot == "Hip" then "cup-soda" elseif item.slot == "Back" then "backpack" else "star"
	end
	table.insert(entries.Apparel, { key = entry.kind .. "_" .. entry.id, section = "Apparel", kind = entry.kind, id = entry.id, name = name,
		icon = icon, color = color, sub = "Looks only.", price = function() return entry.price end })
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
	if entry.section == "Apparel" then
		return owned()[if entry.kind == "Cosmetic" then entry.id else entry.key] == true
	elseif entry.section == "Gear" then
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
local tryingOn = nil -- the apparel entry being tried on (the window steps aside so you can see it)
local startTryOn -- (below)
local picked = {} -- [section] = entry key
local refresh -- (below)
local openOn -- (below)
local tabs = {}
for _, section in ipairs(PumpShop.Sections) do table.insert(tabs, { id = section.id, text = section.name, icon = section.icon }) end
local modal = Kit.Modal({ name = "PumpShop", title = "Pump Shop", icon = "dumbbell", width = W, height = H, displayOrder = 25, tabs = tabs, coins = true,
	onTab = function(id)
		tab = id
		refresh()
	end, onClose = function()
		if not tryingOn then remote:FireServer("TryOff") end
	end })

local hero = Kit.Card({ Name = "Hero", Size = UDim2.new(0, HERO_W, 1, 0), Parent = modal.body }, {})
local heroTile = New("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(52, 52), Parent = hero })
local heroName = Kit.Fit(Kit.Text({ Name = "Name", Text = "", Font = "Title", TextColor3 = Colors.Gold, Position = UDim2.fromOffset(70, 10),
	Size = UDim2.new(1, -78, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = hero }), 17, 11)
local heroPrice = Kit.Text({ Name = "Price", Text = "", Font = "Number", TextSize = 14, Position = UDim2.fromOffset(70, 34), Size = UDim2.new(1, -78, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = hero })
local heroText = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 12, TextWrapped = true, Position = UDim2.fromOffset(10, 68),
	Size = UDim2.new(1, -20, 0, 48), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = hero })
local buttonRow = New("Frame", { Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8),
	Size = UDim2.new(1, -16, 0, 44), Parent = hero }, { Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local secondRow = New("Frame", { Name = "Second", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -58),
	Size = UDim2.new(1, -16, 0, 44), Parent = hero }, { Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(HERO_W + 10, 0),
	Size = UDim2.new(1, -(HERO_W + 10), 1, 0), ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
	New("UIGridLayout", { CellSize = UDim2.fromOffset(TILE.X, TILE.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
})
local lockNote = Kit.Text({ Name = "Locked", Text = "", Font = "Strong", TextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(HERO_W + 16, 20),
	Size = UDim2.new(1, -(HERO_W + 30), 0, 60), TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = modal.body })

local function clearButtons()
	for _, row in ipairs({ buttonRow, secondRow }) do
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA("GuiButton") then child:Destroy() end
		end
	end
end
local function addButton(row, style, text, width, onTap)
	local button = Kit.Button(style, text, { Parent = row }, { width = width, height = 44, textSize = 14 })
	button.Activated:Connect(function()
		Audio.PlayUI("Click")
		onTap()
	end)
	return button
end

local function setArt(entry)
	for _, child in ipairs(heroTile:GetChildren()) do child:Destroy() end
	Kit.IconTile(entry.icon, entry.color, 52, { Parent = heroTile })
end

local function showHero(entry)
	if not entry then
		hero.Visible = false
		return
	end
	hero.Visible = true
	setArt(entry)
	heroName.Text = entry.name
	clearButtons()
	local price = priceOf(entry)
	local afford = price ~= nil and coins() >= price
	heroPrice.Text = if price then Kit.Format(price) .. " coins" else "Owned"
	heroPrice.TextColor3 = if price and not afford then Colors.NeedsWork else Colors.Gold
	if entry.section == "Supplements" then
		local have = (data().items or {})[entry.key] or 0
		heroText.Text = entry.sub .. "\nYou have " .. have .. "."
		for _, quantity in ipairs(PumpShop.Quantities) do
			addButton(buttonRow, if coins() >= (price or 0) * quantity then "Gold" else "Disabled", "x" .. quantity, 60, function()
				remote:FireServer("Buy", "Supplements", entry.key, quantity)
			end)
		end
	elseif entry.section == "Gear" then
		local have, nextLevel = gearLevels(entry.gear)
		local lines = { entry.sub }
		for _, level in ipairs(PumpShop.GearLevels) do
			local mark = if have and level.bonus <= have.bonus then "owned" else Kit.Format(level.price)
			table.insert(lines, string.format("%s +%d%%  ·  %s", level.name, math.floor(level.bonus * 100 + 0.5), mark))
		end
		heroText.Text = table.concat(lines, "\n")
		heroText.Size = UDim2.new(1, -20, 0, 70)
		if nextLevel then
			addButton(buttonRow, if afford then "Gold" else "Disabled", "Buy " .. nextLevel.name, 180, function()
				remote:FireServer("Buy", "Gear", entry.gear.id)
			end)
		end
	elseif entry.section == "Apparel" then
		heroText.Text = entry.sub
		if isOwned(entry) then
			heroPrice.Text = "Owned: wear it from Inventory > Gear"
			heroPrice.TextColor3 = Colors.Green
		else
			addButton(secondRow, "Quiet", "Try on", 180, function() startTryOn(entry) end)
			addButton(buttonRow, if afford then "Gold" else "Disabled", "Buy", 180, function()
				remote:FireServer("Buy", "Apparel", entry.id, entry.kind)
			end)
		end
	elseif entry.section == "Alters" then
		local progress = alterProgress()
		local status, color = alterStatus(entry, progress)
		local n = entry.alter.number
		heroName.Text = "Alter " .. n .. ": " .. entry.alter.name
		heroPrice.Text = status
		heroPrice.TextColor3 = color
		if n == progress.next and not progress.locked then
			heroText.Text = string.format("Goal: %s exp in every group. Keeps 25%% of your EXP. Gains x%.2f after.",
				Muscles.FormatExpShort(Muscles.Shown(Alters.Goal(n))), Alters.Bonus(n))
		elseif n < progress.next then
			heroText.Text = "Done. Wear this skin from Inventory > Alters."
		elseif status == "SOON" then
			heroText.Text = "Coming soon in an update."
		else
			heroText.Text = string.format("Goal: %s exp in every group. Gains x%.2f after.", Muscles.FormatExpShort(Muscles.Shown(Alters.Goal(n))), Alters.Bonus(n))
		end
		addButton(secondRow, "Quiet", "My skins", 180, function()
			modal.close()
			UIBus.OpenInventory:Fire("Alters")
		end)
		if n == progress.next and progress.ready then
			addButton(buttonRow, "Gold", "Alter now", 180, function()
				modal.close()
				UIBus.StartAlter:Fire() -- (prompt 22: the themed transformation fires the action at its flash)
			end)
		end
	elseif entry.section == "DnaLab" then
		local state = data().dnaWeek
		local bought = if type(state) == "table" and state.week == PumpShop.Week() then state.bought or 0 else 0
		heroText.Text = string.format("You have %d. Bought this week: %d (each one costs 10%% more until Monday).", data().dnaTokens or 0, bought)
		addButton(secondRow, "Quiet", "Reroll genetics", 180, function()
			modal.close()
			UIBus.OpenGenetics:Fire()
		end)
		addButton(buttonRow, if afford then "Gold" else "Disabled", "Buy token", 180, function()
			Remotes.PlayerAction:FireServer("BuyDnaToken")
		end)
	end
	if entry.section ~= "Gear" then heroText.Size = UDim2.new(1, -20, 0, 48) end
end

function refresh()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local open = sectionOpen(tab)
	lockNote.Visible = not open
	grid.Visible = open
	if not open then
		lockNote.Text = if tab == "Alters" then "Body Alters open at 7'0\". Keep growing!" else "Gear and Apparel open at Growth Spurt 2. Keep training!"
		hero.Visible = false
		return
	end
	local list = entries[tab]
	local altersNow = nil
	if tab == "Alters" then
		list, altersNow = alterEntries()
		-- (the next alter first)
		local nextAlter = Alters.Get(altersNow.next)
		if not picked.Alters or not bodyEntry(list, picked.Alters) then picked.Alters = nextAlter and nextAlter.id or (list[1] and list[1].key) end
		for _, entry in ipairs(list) do entry.id = entry.key end
	end
	if not picked[tab] and list[1] then picked[tab] = list[1].key end
	for order, entry in ipairs(list) do
		local card = Kit.Card({ Name = entry.key, LayoutOrder = order, Clickable = true, Parent = grid }, {})
		if entry.section == "Alters" then
			-- (prompt 22) a strip of the alter's popup art (or its theme colors) behind the icon, a line in its accent color
			local theme = AlterThemes.Get(entry.alter.number)
			local strip = New(if theme.bg then "ImageLabel" else "Frame", { Name = "Strip", BackgroundColor3 = Color3.new(1, 1, 1),
				Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0, 34), Parent = card }, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
			if theme.bg then
				strip.Image, strip.ScaleType, strip.BackgroundTransparency = theme.bg, Enum.ScaleType.Crop, 1
			else
				New("UIGradient", { Rotation = -90, Color = ColorSequence.new(theme.accent:Lerp(theme.base, 0.4), theme.base), Parent = strip })
			end
			New("Frame", { Name = "Accent", BackgroundColor3 = theme.accent, Position = UDim2.fromOffset(3, 37), Size = UDim2.new(1, -6, 0, 2), Parent = card })
		end
		Kit.IconTile(entry.icon, entry.color, 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Parent = card })
		Kit.Fit(Kit.Text({ Text = entry.name, Font = "Title", Position = UDim2.fromOffset(4, 38), Size = UDim2.new(1, -8, 0, 16), Parent = card }), 12, 9)
		local price = priceOf(entry)
		local label = Kit.Text({ Text = if isOwned(entry) then "OWNED" elseif price then Kit.Format(price) else "", Font = "Number", TextSize = 12,
			Position = UDim2.fromOffset(4, 56), Size = UDim2.new(1, -8, 0, 16), Parent = card })
		label.TextColor3 = if isOwned(entry) then Colors.Green elseif price and coins() >= price then Colors.Gold else Colors.Muted
		if entry.section == "Alters" then
			local status, color = alterStatus(entry, altersNow)
			label.Text, label.TextColor3 = status, color
		end
		if entry.section == "Gear" then
			local have = gearLevels(entry.gear)
			if have then label.Text = have.name .. " · next " .. (if price then Kit.Format(price) else "max") end
		end
		Theme.SetPiece(card, if picked[tab] == entry.key then "card_gold" else "card")
		card.Activated:Connect(function()
			Audio.PlayUI("Click")
			picked[tab] = entry.key
			refresh()
		end)
	end
	local current = nil
	for _, entry in ipairs(list) do
		if entry.key == picked[tab] then current = entry end
	end
	showHero(current)
end

------------------------------------------------------------------------
-- Trying on: the window steps aside and a small bar says what you wear, with BUY and BACK (it ends by itself after
-- TryOnSeconds, like on the server)
------------------------------------------------------------------------
local tryGui = Theme.ScreenGui({ Name = "PumpShopTryOn", DisplayOrder = 26, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
tryGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local tryRoot = Kit.Root(tryGui)
local tryBar = Theme.Panel({ Name = "Bar", Piece = "hud_box", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(470, 60),
	Parent = tryRoot }, { New("UIStroke", { Color = Colors.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
local tryText = Kit.Text({ Name = "Text", Text = "", Font = "Title", TextSize = 15, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -230, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = tryBar })
local tryBuy = Kit.Button("Gold", "Buy", { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Parent = tryBar }, { width = 100, height = 44, textSize = 15 })
local tryBack = Kit.Button("Quiet", "Back", { Name = "Back", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = tryBar }, { width = 96, height = 44, textSize = 15 })
local tryToken = 0
local function endTryOn(reopen: boolean)
	local entry = tryingOn
	tryingOn = nil
	tryGui.Enabled = false
	remote:FireServer("TryOff")
	if reopen and entry then openOn("Apparel") end
end
function startTryOn(entry)
	tryingOn = entry
	remote:FireServer("TryOn", entry.kind, entry.id)
	modal.close()
	tryText.Text = "Trying on: " .. entry.name .. " (" .. Kit.Format(entry.price()) .. ")"
	tryGui.Enabled = true
	tryToken += 1
	local mine = tryToken
	task.delay(PumpShop.TryOnSeconds, function()
		if tryToken == mine and tryingOn then endTryOn(false) end
	end)
end
tryBuy.Activated:Connect(function()
	local entry = tryingOn
	if not entry then return end
	Audio.PlayUI("Click")
	remote:FireServer("Buy", "Apparel", entry.id, entry.kind)
	tryingOn = nil
	tryGui.Enabled = false
end)
tryBack.Activated:Connect(function()
	Audio.PlayUI("Click")
	endTryOn(true)
end)

function openOn(section: string?)
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
		openOn(info.section)
	elseif kind == "Failed" then
		Notify.Toast("Can't buy that", tostring(info.text or ""), "coin", Colors.Red, "pumpfail")
	elseif kind == "Bought" then
		Audio.PlayUI("QuestClaim")
		if info.section == "Gear" then
			local item = Cosmetics.ById[info.id]
			Notify.Reward("NEW GEAR", (item and item.name or "Gear") .. " · wearing it now", "dumbbell", Colors.Gold)
		elseif info.section == "Apparel" then
			Notify.Toast("Bought!", "Wearing it now. Change it in Inventory > Gear.", "star", Colors.Gold, "pumpapparel")
		end
		if modal.isOpen() then refresh() end
	elseif kind == "Teleported" then
		Notify.Hint("Welcome to the PUMP SHOP! Walk up to a counter.")
	end
end)

------------------------------------------------------------------------
-- The left menu tile: go to the shop (10 s cooldown)
------------------------------------------------------------------------
local tile = SideMenu.Add("PumpShop", "Pump Shop", nil, 8)
local lastGo = -math.huge
local function goToShop()
	if os.clock() - lastGo < PumpShop.TeleportCooldown then
		Notify.Show(string.format("Wait %d s to go to the PUMP SHOP again.", math.ceil(PumpShop.TeleportCooldown - (os.clock() - lastGo))), nil, "pumpwait")
		return
	end
	lastGo = os.clock()
	remote:FireServer("Teleport")
end
tile.Activated:Connect(goToShop)
local function refreshTile()
	tile:SetShown(player:GetAttribute("PumpShop") ~= nil)
end
player:GetAttributeChangedSignal("PumpShop"):Connect(refreshTile)
refreshTile()

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
affordButton.Activated:Connect(function()
	affordGui.Enabled = false
	goToShop()
end)

local function checkAfford()
	if not player:GetAttribute("PumpShop") or os.clock() - lastAfford < PumpShop.AffordEvery or UIBus.MenuOpen then return end
	local best = nil
	for _, section in ipairs({ "Gear", "Apparel" }) do
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
	if best.entry.section == "Gear" then
		local _, nextLevel = gearLevels(best.entry.gear)
		name = (nextLevel and nextLevel.name .. " " or "") .. name
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
	for _, section in ipairs({ "Gear", "Apparel" }) do
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
