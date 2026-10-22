-- ActiveBoostsClient (prompt 47, 22 Oct; mockup Downloads\gym_arc_ui_style_match\real\boosts_bottom_left.png): every ACTIVE
-- boost as a small square tile in ONE row in the bottom-left corner, above the safe area (pet-sim style). It replaces the
-- old chips above the stamina bar (HudBottom's row is hidden). The hotbar (the boosts you carry) stays where it is.
--   * Shown: the boost items you drank (Config/Boosts, "Item_<id>"), the Protein Shake ("ShakeEnds"), the old smoothie
--     drinks still running ("Meal_<id>"), Endless Stamina ("EndlessStaminaUntil"), the Server Boost and Rush Hour
--     (ReplicatedStorage "ServerBoostEnds" / "RushHourEnds"), and MAX BOOST while your boosts pass the gains cap.
--   * A tile: ~50 px dark graphite, a thin gold outline, the boost's icon filling it, the time left under it in white
--     stroked chunky text; under a minute the timer turns red and pulses. More time than one dose = one tile with a
--     gold "x2" tag. Longest time left first; more than 6 = 5 tiles + a "+3" tile.
--   * Hover (PC) / tap (phone): the tile lifts 4 px with a gold glow and an info card pops up above it (icon, NAME, a gold
--     pill with the effect, "14:52 left · 2 stacked"); it hides when the mouse leaves, or 3 s after a tap.
--   * A new boost pops in (0 -> 1.1 -> 1) with a short sparkle; an ended one shrinks away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Meals = require(Shared.Config.Meals)
local Stamina = require(Shared.Config.Stamina)
local Economy = require(Shared.Config.Economy)
local Monetization = require(Shared.Config.Monetization)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors
local INK = Color3.fromHex("#0A090B")
local GRAPHITE = Color3.fromHex("#1A191E")
local RED = Color3.fromHex("#FF4A4A")

local TILE = 50
local GAP = 6
local MAX_SHOWN = 6
local TAP_HIDE = 3

local function now() return Workspace:GetServerTimeNow() end
local function untilAttr(holder: Instance, name: string): number?
	local value = holder:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

------------------------------------------------------------------------
-- What can be running: { key, name, icon, color, pill, dose (seconds one use gives: the x2 tag), ends(), always }
------------------------------------------------------------------------
local SOURCES = {}
for _, item in ipairs(Boosts.Items) do
	if item.shake then
		table.insert(SOURCES, { key = "Shake", name = item.name, icon = item.icon, pill = item.short or "+50% EXP", dose = Stamina.Shake.Duration,
			ends = function() return untilAttr(player, "ShakeEnds") end })
	else
		table.insert(SOURCES, { key = "Item_" .. item.id, name = item.name, icon = item.icon, pill = (item.short or item.text) .. " · " .. string.upper(item.duration or ""),
			dose = item.seconds, ends = function() return untilAttr(player, "Item_" .. item.id) end })
	end
end
for _, item in ipairs(Meals.Items) do
	table.insert(SOURCES, { key = "Meal_" .. item.id, name = item.name, icon = item.uiIcon or "cup-soda", pill = item.short or "",
		ends = function() return untilAttr(player, "Meal_" .. item.id) end })
end
table.insert(SOURCES, { key = "Endless", name = "Endless Stamina", icon = "zap", pill = "NO STAMINA DRAIN",
	ends = function() return untilAttr(player, "EndlessStaminaUntil") end })
table.insert(SOURCES, { key = "ServerBoost", name = "Server Boost", icon = "users", pill = Monetization.Effects.ServerBoostGains .. "x EXP FOR EVERYONE",
	ends = function() return untilAttr(ReplicatedStorage, "ServerBoostEnds") end })
table.insert(SOURCES, { key = "RushHour", name = "Rush Hour", icon = "timer", pill = Economy.RushHour.Coins .. "x COINS",
	ends = function() return untilAttr(ReplicatedStorage, "RushHourEnds") end })
table.insert(SOURCES, { key = "MaxBoost", name = "Max Boost", icon = "arrow-big-up", pill = "AT THE GAINS CAP", always = true,
	ends = function() return if player:GetAttribute("MaxBoost") == true then math.huge else nil end })

------------------------------------------------------------------------
-- The row
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "ActiveBoosts", DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)
local row = New("Frame", { Name = "Row", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10),
	Size = UDim2.fromOffset(MAX_SHOWN * (TILE + GAP), TILE + 14), Parent = root })

local function chunky(parent, name, size, props)
	local label = Kit.Text({ Name = name, Text = "", Font = "Chunky", TextSize = size, Parent = parent })
	for k, v in pairs(props or {}) do label[k] = v end
	local stroke = label:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = label })
	stroke.Color, stroke.Thickness = INK, math.max(1.5, size * 0.12)
	return label
end

-- the info card (one, moved over the tile it belongs to)
local card = New("Frame", { Name = "Info", BackgroundColor3 = Color3.fromHex("#141317"), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(224, 82), Visible = false,
	ZIndex = 20, Parent = root }, {
	New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), -- (owner, 23 Oct, chrome reset: no gold edge, no mesh)
})
local cardIcon = New("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(46, 46), ZIndex = 21, Parent = card })
local cardName = chunky(card, "Name", 15, { Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -70, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
Kit.Fit(cardName, 15, 10)
local pill = New("Frame", { Name = "Pill", BackgroundColor3 = Colors.Gold, Position = UDim2.fromOffset(62, 30), Size = UDim2.fromOffset(150, 20), AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 21, Parent = card }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = INK, Thickness = 1.5 }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})
pill.Size = UDim2.fromOffset(0, 20)
local pillText = chunky(pill, "Text", 12, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 22 })
local cardLine = Kit.Text({ Name = "Line", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Color3.fromHex("#9A97A0"), Position = UDim2.fromOffset(62, 56),
	Size = UDim2.new(1, -70, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = card })
local cardFor = nil -- the tile the card belongs to
local cardToken = 0

local tiles = {} -- [key] = tile
local more = nil -- the "+3" tile

local function iconInto(parent: GuiObject, icon: string, size: UDim2)
	parent:ClearAllChildren()
	local art = string.sub(icon, 1, 13) == "rbxassetid://"
	local image = Pieces.Icon(icon, if art then Color3.new(1, 1, 1) else Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size,
		ZIndex = parent.ZIndex + 1, Parent = parent })
	image:SetAttribute("KeepColor", true)
	return image
end

local function hideCard(tile)
	if tile and cardFor ~= tile then return end
	card.Visible = false
	if cardFor then
		TweenService:Create(cardFor.lift, TweenInfo.new(0.12), { Position = UDim2.fromScale(0.5, 0) }):Play()
		cardFor.glow.Transparency = 1
	end
	cardFor = nil
end

local function showCard(tile)
	if cardFor and cardFor ~= tile then hideCard() end
	cardFor = tile
	TweenService:Create(tile.lift, TweenInfo.new(0.12), { Position = UDim2.new(0.5, 0, 0, -4) }):Play()
	tile.glow.Transparency = 0.25
	iconInto(cardIcon, tile.source.icon, UDim2.fromScale(1, 1))
	cardName.Text = string.upper(tile.source.name)
	pillText.Text = tile.source.pill
	pill.Visible = tile.source.pill ~= ""
	-- above the tile, never over it (and inside the screen)
	local x = tile.frame.AbsolutePosition.X - row.AbsolutePosition.X + 12
	card.Position = UDim2.new(0, math.max(8, x - 6), 1, -(10 + TILE + 22))
	card.Visible = true
	tile.updateCard()
end

local function makeTile(source)
	local frame = New("Frame", { Name = source.key, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE, TILE + 14), Parent = row })
	local scale = New("UIScale", { Scale = 0, Parent = frame })
	local lift = New("TextButton", { Name = "Tile", Text = "", AutoButtonColor = false, BackgroundColor3 = GRAPHITE, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(TILE, TILE), Parent = frame }, {
		New("UICorner", { CornerRadius = UDim.new(0, 9) }),
		New("UIStroke", { Name = "Edge", Color = Colors.Gold, Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local glow = New("UIStroke", { Name = "Glow", Color = Colors.Gold, Thickness = 5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local glowFrame = New("Frame", { Name = "GlowRing", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = lift }, {
		New("UICorner", { CornerRadius = UDim.new(0, 9) }), glow,
	})
	local iconHolder = New("Frame", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = lift })
	iconInto(iconHolder, source.icon, UDim2.fromScale(if string.sub(source.icon, 1, 13) == "rbxassetid://" then 0.92 else 0.62, if string.sub(source.icon, 1, 13) == "rbxassetid://" then 0.92 else 0.62))
	local timer = chunky(frame, "Timer", 13, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 10, 0, 17), ZIndex = 4 })
	local tag = New("Frame", { Name = "Stack", BackgroundColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(22, 14),
		Visible = false, ZIndex = 5, Parent = lift }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = INK, Thickness = 1.2 }),
	})
	local tagText = chunky(tag, "Text", 9, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
	local tile = { source = source, frame = frame, scale = scale, lift = lift, glow = glow, glowFrame = glowFrame, timer = timer, tag = tag, tagText = tagText,
		left = 0, stacks = 1, leaving = false }
	function tile.updateCard()
		if cardFor ~= tile then return end
		local parts = {}
		if tile.left < math.huge then table.insert(parts, Boosts.Clock(tile.left) .. " left") else table.insert(parts, "while it lasts") end
		if tile.stacks > 1 then table.insert(parts, tile.stacks .. " stacked") end
		cardLine.Text = table.concat(parts, "  ·  ")
	end
	-- PC: hover; phone: tap (3 s)
	lift.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled then showCard(tile) end
	end)
	lift.MouseLeave:Connect(function()
		if not UserInputService.TouchEnabled then hideCard(tile) end
	end)
	lift.Activated:Connect(function()
		if cardFor == tile then hideCard(tile) return end
		Audio.PlayUI("Click")
		showCard(tile)
		cardToken += 1
		local mine = cardToken
		task.delay(TAP_HIDE, function() if cardToken == mine and cardFor == tile then hideCard(tile) end end)
	end)
	-- pop in with a sparkle
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
	task.delay(0.16, function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	if not source.always then Audio.PlayUI("GeneticsShimmer") end
	return tile
end

local function removeTile(key: string)
	local tile = tiles[key]
	if not tile or tile.leaving then return end
	tile.leaving = true
	hideCard(tile)
	TweenService:Create(tile.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.delay(0.22, function()
		tile.frame:Destroy()
		if tiles[key] == tile then tiles[key] = nil end
	end)
end

local started = false
local function step()
	local t = now()
	local running = {}
	for _, source in ipairs(SOURCES) do
		local ends = source.ends()
		local left = if ends == math.huge then math.huge elseif ends then ends - t else 0
		if started and left > 0 then table.insert(running, { source = source, left = left }) end
	end
	-- longest time left first (MAX BOOST, which has none, last)
	table.sort(running, function(a, b)
		local la = if a.left == math.huge then -1 else a.left
		local lb = if b.left == math.huge then -1 else b.left
		return la > lb
	end)
	local keep = {}
	local shownCount = if #running > MAX_SHOWN then MAX_SHOWN - 1 else #running
	for i, entry in ipairs(running) do
		local key = entry.source.key
		if i <= shownCount then
			keep[key] = true
			local tile = tiles[key]
			if not tile or tile.leaving then
				tile = makeTile(entry.source)
				tiles[key] = tile
			end
			tile.left = entry.left
			tile.stacks = if entry.source.dose and entry.left < math.huge then math.max(1, math.ceil(entry.left / entry.source.dose - 0.001)) else 1
			tile.frame.LayoutOrder = i
			tile.frame.Position = UDim2.fromOffset((i - 1) * (TILE + GAP), 0)
			if entry.left == math.huge then
				tile.timer.Text = if entry.source.key == "MaxBoost" then "MAX" else ""
				tile.timer.TextColor3 = Colors.Gold
			else
				tile.timer.Text = Boosts.Clock(entry.left)
				local low = entry.left < 60
				tile.timer.TextColor3 = if low then RED else Color3.new(1, 1, 1)
				tile.timer.TextTransparency = if low then 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 6)) else 0
			end
			tile.tag.Visible = tile.stacks > 1
			tile.tagText.Text = "x" .. tile.stacks
			tile.updateCard()
		end
	end
	for key in pairs(tiles) do
		if not keep[key] then removeTile(key) end
	end
	-- "+3": the ones that don't fit
	local hidden = #running - shownCount
	if hidden > 0 then
		if not more then
			more = New("Frame", { Name = "More", BackgroundColor3 = GRAPHITE, Size = UDim2.fromOffset(TILE, TILE), Parent = row }, {
				New("UICorner", { CornerRadius = UDim.new(0, 9) }),
				New("UIStroke", { Color = Colors.Gold, Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			chunky(more, "Text", 18, { Size = UDim2.fromScale(1, 1) })
		end
		more.Visible = true
		more.Position = UDim2.fromOffset(shownCount * (TILE + GAP), 0)
		more.Text.Text = "+" .. hidden
	elseif more then
		more.Visible = false
	end
end

-- hidden on the title screen; shown after PLAY
task.spawn(function()
	UIBus.WaitForMenu()
	started = true
end)
-- (prompt 53) hidden while the tutorial runs (only the tutorial on screen); it fades back in when the tutorial ends
task.spawn(function()
	while true do
		local tutorial = UIBus.InTutorial()
		if row.Visible == tutorial then
			row.Visible = not tutorial
			if not tutorial then Theme.Fade(row, true, 0.4) end
		end
		local ok, err = pcall(step)
		if not ok then warn("[ActiveBoostsClient]", err) end
		task.wait(0.1)
	end
end)
