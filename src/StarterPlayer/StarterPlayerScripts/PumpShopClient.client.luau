-- PumpShopClient (owner, prompt 19, 21 Oct): the shop window and its HUD bits (PumpShopService sells; numbers in
-- Config.PumpShop). Coins only.
-- (prompt 31, 22 Oct) ONE window for the three shops (Config.PumpShop.Shops): Coach Dex (normal supplements, Basic / Pro
-- gear, ALTERS), the PUMP SHOP (specials, Elite / Champion gear, DNA LAB) and the coconut stand (Coconut Water x1 / x5).
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
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("PumpShop", 60) :: RemoteEvent
if not remote then return end

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local W, H = 770, 262 -- (wide enough for the title, the tabs and the coins pill; 693 px on a 667 x 375 phone)
local shopId = "Pump" -- the shop the window shows (PumpShop.Shops)
local function shop() return PumpShop.Shops[shopId] or PumpShop.Shops.Pump end
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
		for _, quantity in ipairs(shop().quantities or PumpShop.Quantities) do
			addButton(buttonRow, if coins() >= (price or 0) * quantity then "Gold" else "Disabled", "x" .. quantity, 60, function()
				remote:FireServer("Buy", shopId, "Supplements", entry.key, quantity)
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
		if nextLevel and table.find(shop().gear, nextLevel.id) then
			addButton(buttonRow, if afford then "Gold" else "Disabled", "Buy " .. nextLevel.name, 180, function()
				remote:FireServer("Buy", shopId, "Gear", entry.gear.id)
			end)
		elseif nextLevel then
			-- (prompt 31) sold in the other shop: Basic / Pro at Coach Dex, Elite / Champion at the PUMP SHOP
			local atCoach = table.find(PumpShop.Shops.Coach.gear, nextLevel.id) ~= nil
			heroPrice.Text = "Next: " .. nextLevel.name
			heroPrice.TextColor3 = Colors.Muted
			addButton(buttonRow, "Quiet", if atCoach then "Go to Coach Dex" else "Go to Pump Shop", 180, function()
				modal.close()
				if atCoach then UIBus.GoCoach:Fire() else UIBus.GoPumpShop:Fire() end
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
			heroText.Text = "Done. Wear this skin from Inventory > Looks."
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
		lockNote.Text = if tab == "Alters" then "Body Alters open at 7'0\". Keep growing!" else "Gear opens at Growth Spurt 2. Keep training!"
		hero.Visible = false
		return
	end
	local list = entries[tab]
	if tab == "Supplements" then
		-- (prompt 31) only this shop's supplements, in its order
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
		Audio.PlayUI("QuestClaim")
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
