-- DailyClient: the Quests window (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/05_quests). DailyService /
-- QuestService on the server decide and pay everything; this only shows the data (ClientData "dailyQuests" / "daily" /
-- "quests") and asks. Opened by the Quests tile (left menu), the Quests pill and the Daily Reward pill (top bar), and the
-- Daily quests card in the right column. Tabs in the header:
--   Daily   today's 3 quests: an icon tile, the quest (big italic caps), a teal bar, the coin reward in gold, and on the
--           right: a claimable row gets a gold border + glow, a gold icon tile and the red CLAIM; one in progress shows a
--           dark "1 / 2" pill (tap = where to go); a claimed one is faded with a teal DONE. Quest reroll (owner, 14 Oct): the
--           REROLL button in the bonus card ("REROLL - FREE" gold while today's free one is left, then "REROLL - R$ 19",
--           "Free reroll in 5h 12m" under it); tap it, then tap an unfinished quest (its pill says REROLL). The server
--           decides free / paid and asks for the purchase. On the right the ALL 3 BONUS card: a big gold "2 / 3", a gold bar, the bonus coins,
--           CLAIM when all are claimed, "Resets in 6h 12m".
--   Streak  (id "Rewards") the 7-day login streak, its rules and CLAIM DAY N.
--   Goals   (id "Achievements") the Coach's quest chain in order: done ones DONE, the current one with its bar (GO =
--           where to go), later ones locked. After the chain: the Coach's current repeat quest.
-- Claiming: coins fly to the coin counter with a small gold sparkle burst (Kit.CoinBurst).
-- It pops up by itself on the Daily tab after Play (and after the genetics screen) when today's reward is waiting.
-- Badges: the Quests tile and pill show how many things are ready to claim; the Daily Reward pill a dot.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyQuests = require(Shared.Config.DailyQuests)
local Quests = require(Shared.Config.Quests)
local Muscles = require(Shared.Config.Muscles)
local Economy = require(Shared.Config.Economy)
local Boosts = require(Shared.Config.Boosts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local RightColumn = require(Shared.UI.RightColumn)
local TopBar = require(Shared.UI.TopBar)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Daily", 60) :: RemoteEvent
if not remote then return end -- the daily service didn't start

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors
local Horizontal, Vertical = Enum.FillDirection.Horizontal, Enum.FillDirection.Vertical

local W, H = 620, 290 -- the window (mockup px)
local LEFT_W = 424 -- the quest column on the Daily tab
local ROW_H = 66
local DAYS = #Economy.Login.Coins

local function today(): number
	return Economy.Day(math.floor(Workspace:GetServerTimeNow()))
end

local function untilReset(): string
	local left = 86400 - (math.floor(Workspace:GetServerTimeNow()) % 86400)
	local h, m = left // 3600, (left % 3600) // 60
	return h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", math.max(m, 1))
end

-- which icon a daily quest shows, and where GO sends you
local TYPE_ICON = { reps = "biceps-flexed", groupReps = "dumbbell", groups = "list-checks", cardio = "footprints", spots = "users",
	posing = "star", armWins = "hand" }
local function goHint(quest): string
	if quest.type == "groupReps" then return "Train on a " .. string.lower(quest.group) .. " machine" end
	if quest.type == "cardio" then return "Run on a treadmill" end
	if quest.type == "spots" then return "Tap a lifter to spot them" end
	if quest.type == "posing" then return "Find the posing stage at the beach" end
	if quest.type == "armWins" then return "Find the arm wrestling table" end
	if quest.type == "groups" then return "Train different muscle groups" end
	return "Lift on any machine"
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local questTile = SideMenu.Add("Quests", "Quests", Icons.Quest, 7)
local questPill = TopBar.AddPill("Quests", "Quests", Icons.Quest, 1)
local dailyPill = TopBar.AddPill("Daily", "Daily", Icons.Gift, 2)

local pages = {}
local currentTab = "Daily"
local refreshAll -- (below)
local modal = Kit.Modal({ name = "DailyQuests", title = "Quests", icon = "list-checks", width = W, height = H, displayOrder = 26,
	tabs = { { id = "Daily", text = "Daily" }, { id = "Rewards", text = "Streak" }, { id = "Achievements", text = "Goals" } },
	onTab = function(id)
		currentTab = id
		for name, page in pairs(pages) do page.Visible = name == id end
		refreshAll()
	end })
for _, id in ipairs({ "Daily", "Rewards", "Achievements" }) do
	pages[id] = New("Frame", { Name = id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = id == "Daily", Parent = modal.body })
end

------------------------------------------------------------------------
-- Daily tab: quest rows
------------------------------------------------------------------------
local questCol = New("Frame", { Name = "Quests", BackgroundTransparency = 1, Size = UDim2.new(0, LEFT_W, 1, 0), Parent = pages.Daily },
	{ Theme.List(Vertical, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

-- the coin + amount line (the amount in gold)
local function coinAmount(props)
	local frame = New("Frame", props, { Theme.List(Horizontal, 5, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	frame.BackgroundTransparency = 1
	local coin = Kit.Coin(20, { LayoutOrder = 1, Parent = frame })
	local amount = Kit.GoldText(Kit.Text({ Name = "Amount", LayoutOrder = 2, Text = "", Font = "Number", TextSize = 19, Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X, Parent = frame }))
	return frame, amount, coin
end

-- an icon tile: gold when the quest is ready to claim, dark otherwise
local function iconTile(parent)
	local tile = New("Frame", { Name = "Tile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, 9) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Name = "Gloss", Rotation = 90 }),
	})
	local icon = Pieces.Icon("dumbbell", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56), Parent = tile })
	icon:SetAttribute("KeepColor", true)
	return tile, icon
end
local function paintTile(tile, icon, gold: boolean, iconName: string)
	tile.Gloss.Color = gold and Theme.GoldSequence or ColorSequence.new(Color3.fromHex("#2A262B"), Color3.fromHex("#18161A"))
	icon.ImageColor3 = gold and Colors.Ink or Colors.Text
	icon.Image = require(Shared.Config.UI).Icons[iconName] or icon.Image
end

local rows = {}
-- quest reroll state (one table: picking = waiting for the player to tap a quest)
local REROLL = { picking = false, refresh = function() end }
for index = 1, DailyQuests.PerDay do
	local card = Kit.Card({ Name = "Quest" .. index, LayoutOrder = index, Size = UDim2.new(1, 0, 0, ROW_H), Parent = questCol }, {})
	local tile, icon = iconTile(card)
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Title", TextSize = 16, Upper = true, Position = UDim2.fromOffset(62, 13), Size = UDim2.new(1, -250, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local bar, setBar = Kit.Bar(Colors.Teal, { Name = "Bar", Position = UDim2.fromOffset(62, 40), Size = UDim2.new(1, -250, 0, 12), Parent = card })
	local _, amount, coin = coinAmount({ Name = "Reward", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Size = UDim2.fromOffset(76, 24), Parent = card })
	-- right: the red CLAIM, a dark progress pill ("1 / 2"; tap = where to go) or a teal DONE
	local button = Kit.Button("Green", "Claim", { Name = "Action", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = card },
		{ width = 96, height = 36, textSize = 16 })
	local pill, pillText = Kit.PricePill("", { Name = "Progress", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(96, 30),
		AutomaticSize = Enum.AutomaticSize.None, Parent = card })
	-- (the tap area sits in a Folder so the pill's list layout ignores it)
	local pillButton = New("TextButton", { Name = "Tap", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
		Parent = New("Folder", { Name = "Hit", Parent = pill }) })
	local doneLabel = Kit.Text({ Name = "Done", Text = "DONE", Font = "Title", TextSize = 17, TextColor3 = Colors.Teal, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(96, 24), Visible = false, Parent = card })
	local row = { card = card, tile = tile, icon = icon, text = text, bar = bar, setBar = setBar, amount = amount, coin = coin, button = button, pill = pill,
		pillText = pillText, doneLabel = doneLabel, state = "go", quest = nil }
	button.Activated:Connect(function()
		if row.state == "claim" then
			Kit.CoinBurst(button)
			remote:FireServer("Claim", index)
		end
	end)
	pillButton.Activated:Connect(function()
		if REROLL.picking and row.state == "go" then
			REROLL.picking = false
			remote:FireServer("Swap", index)
			REROLL.refresh()
			return
		end
		if row.state == "go" and row.quest then
			modal.close()
			Notify.Hint(goHint(row.quest), "questgo")
		end
	end)
	rows[index] = row
end

-- ALL 3 BONUS (right): a big gold count, a gold bar, the bonus coins, CLAIM when all are claimed, the reset time
local bonus = Kit.Card({ Name = "Bonus", Position = UDim2.fromOffset(LEFT_W + 10, 0), Size = UDim2.new(1, -(LEFT_W + 10), 0, ROW_H * 3 + 16),
	Parent = pages.Daily }, {})
Kit.Text({ Name = "Title", Text = "All " .. DailyQuests.PerDay .. " bonus", Font = "Title", TextSize = 17, Upper = true, Position = UDim2.fromOffset(12, 10),
	Size = UDim2.new(1, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = bonus })
local bonusCount = Kit.GoldText(Kit.Text({ Name = "Count", Text = "0", Font = "Number", TextSize = 50, Position = UDim2.fromOffset(12, 32),
	Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left, Parent = bonus }))
local bonusOf = Kit.Text({ Name = "Of", Text = "/" .. DailyQuests.PerDay, Font = "Number", TextSize = 22, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(46, 54),
	Size = UDim2.fromOffset(40, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = bonus })
bonusCount:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	bonusOf.Position = UDim2.fromOffset(12 + bonusCount.AbsoluteSize.X / math.max(Kit.Scale() * Kit.PanelScale, 0.01) + 6, 54)
end)
local _, setBonusBar = Kit.Bar(Colors.Gold, { Name = "Bar", Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 14), Parent = bonus })
local bonusReward = coinAmount({ Name = "Reward", Position = UDim2.fromOffset(12, 114), Size = UDim2.new(1, -24, 0, 26), Parent = bonus })
bonusReward:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Left
bonusReward:FindFirstChild("Amount").Text = "+" .. Kit.Format(DailyQuests.BonusCoins) -- (prompt 40: "+150")
local bonusClaim = Kit.Button("Green", "Claim", { Name = "Claim", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Visible = false, Parent = bonus },
	{ width = 130, height = 34, textSize = 15 })
bonusClaim.Activated:Connect(function()
	Kit.CoinBurst(bonusClaim)
	remote:FireServer("ClaimBonus")
end)
local resetLabel = Kit.Text({ Name = "Reset", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(1, -24, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = bonus })
-- REROLL: "REROLL - FREE" (gold) / "REROLL - R$ 19", the free one's countdown under it (hidden while the bonus CLAIM shows)
REROLL.button = Kit.Button("Gold", "Reroll - Free", { Name = "Reroll", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -44), Parent = bonus },
	{ width = 150, height = 30, textSize = 13 })
REROLL.note = Kit.Text({ Name = "RerollNote", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(1, -24, 0, 14), Parent = bonus })
REROLL.robux = DailyQuests.RerollRobux
for _, product in ipairs(require(Shared.Config.Monetization).Products) do
	if product.key == "QuestReroll" then REROLL.product = product.id end
end
if REROLL.product then
	task.spawn(function() -- (Roblox's real price; prompt 11: once the player is playing, not on join)
		UIBus.WaitForGameplay()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, REROLL.product, Enum.InfoType.Product)
		if ok and info and info.PriceInRobux then
			REROLL.robux = info.PriceInRobux
			REROLL.refresh()
		end
	end)
end
function REROLL.freeLeft(): boolean
	local dq = ClientData.Get().dailyQuests
	local valid = type(dq) == "table" and dq.day == today()
	return not valid or (dq.swaps or 0) < DailyQuests.FreeRerollsPerDay
end
function REROLL.refresh()
	local free = REROLL.freeLeft()
	local any = false
	for _, row in ipairs(rows) do
		if row.card.Visible and row.state == "go" then any = true end
		-- while picking, each quest that can be rerolled says REROLL on its pill
		if row.quest and row.state == "go" then
			row.pillText.Text = if REROLL.picking then "REROLL" else row.progress or row.pillText.Text
		end
	end
	if not any then REROLL.picking = false end
	REROLL.button.Visible = any and not bonusClaim.Visible
	if REROLL.picking then
		Kit.SetButton(REROLL.button, "Quiet", "Cancel")
	elseif free then
		Kit.SetButton(REROLL.button, "Gold", "Reroll - Free")
	else
		Kit.SetButton(REROLL.button, "Red", "Reroll - R$ " .. REROLL.robux)
	end
	REROLL.note.Visible = REROLL.button.Visible
	REROLL.note.Text = if REROLL.picking then "Tap a quest to reroll it" elseif free then "1 free reroll a day" else "Free reroll in " .. untilReset()
end
REROLL.button.Activated:Connect(function()
	REROLL.picking = not REROLL.picking
	Audio.PlayUI("Click")
	REROLL.refresh()
end)

------------------------------------------------------------------------
-- STREAK tab (prompt 42, 22 Oct, mockup real/quests_streak): "DAILY STREAK DAY X", the 7 day tiles across the full width
-- (equal Scale widths, day 7 1.25x wider and 25% taller), one grey line, CLAIM DAY X (green) / COME BACK TOMORROW
-- (dark), "STREAK RECORD: X DAYS" (data.daily.best). The window shrinks to fit this tab (STREAK_H).
-- Tiles: dark hex, a dark outline + a thin muted inner line; the coin and the reward in gold; bonus items (Config.Boosts
-- LoginItems) a gold line icon on a dark gold-edged circle + "+1"; DNA days (4, 7) gold-edged with a glow, the DNA token
-- big (a cut-out, Downloads\gym_arc_ui_dna) and a gold "+1" pill. Today: a thin white ring, lifted 6 px, a white TODAY
-- tag above it. Claimed: dimmed + a green check. Not reached yet: the coin and the bonus icon dimmed alike.
------------------------------------------------------------------------
local DNA_CUTOUT = "rbxassetid://88290636191617"
local GAP = 0.012 -- (Scale gap between tiles)
local UNIT = (1 - GAP * (DAYS - 1)) / (DAYS - 1 + 1.25)
local TILE_H, BIG_H = 74, 92
local TITLE_H, TAG_ROOM = 21, 22
local ROW_Y = TITLE_H + TAG_ROOM
local DESC_Y = ROW_Y + BIG_H + 8
local CLAIM_Y = DESC_Y + 18
local RECORD_Y = CLAIM_Y + 42
local STREAK_H = RECORD_Y + 14 + 40 -- (the body's content: it ends 40 px under the record line)
local MUTED = Color3.fromHex("#3A363D")
local DIM, AHEAD = 0.5, 0.3 -- (claimed / not reached yet: everything in a tile dims alike)

local streak = { cards = {} }
local page = pages.Rewards
streak.title = Kit.Text({ Name = "Title", Text = "", Font = "Title", TextSize = 17, RichText = true, Size = UDim2.new(1, 0, 0, TITLE_H),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = page })
-- (prompt 44: 6 px in from each side so the glow and the TODAY ring are never cut off by the window's edge)
local row = New("Frame", { Name = "Days", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, ROW_Y), Size = UDim2.new(1, -12, 0, BIG_H), Parent = page }, {
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(GAP, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function hexOn(parent: Instance, corner: number, color: Color3?)
	New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile, TileSize = Theme.HexTile,
		ImageTransparency = Theme.HexStreak, ImageColor3 = color or Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = parent },
		{ New("UICorner", { CornerRadius = UDim.new(0, corner) }) })
end
for day = 1, DAYS do
	local coins, tokens = Economy.LoginReward(day)
	local big = day == DAYS
	local dnaDay = tokens > 0
	local h = if big then BIG_H else TILE_H
	local slot = New("Frame", { Name = "Day" .. day, LayoutOrder = day, BackgroundTransparency = 1, Size = UDim2.new(if big then UNIT * 1.25 else UNIT, 0, 0, BIG_H),
		Parent = row })
	local card = New("Frame", { Name = "Tile", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, h), Parent = slot }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Name = "Border", Color = if dnaDay then Colors.Gold else Colors.Outline, Thickness = if dnaDay then 2.5 else 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Rotation = 90, Color = if dnaDay then ColorSequence.new(Color3.fromHex("#6A4E16"), Color3.fromHex("#2E220C")) -- (prompt 44: brighter)
			else ColorSequence.new(Color3.fromHex("#232023"), Color3.fromHex("#141215")) }),
	})
	hexOn(card, 10, if dnaDay then Color3.fromHex("#FFE9A6") else nil)
	-- the thin muted inner line
	New("Frame", { Name = "Inner", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -4, 1, -4),
		Parent = card }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = if dnaDay then Color3.fromHex("#8A6418") else MUTED, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	-- DNA days glow (day 7 stronger)
	local glow = nil
	if dnaDay then
		glow = New("Frame", { Name = "Glow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 8, 1, 8), Parent = card }, {
			New("UICorner", { CornerRadius = UDim.new(0, 14) }),
			New("UIStroke", { Name = "Stroke", Color = Colors.Gold, Thickness = if big then 5 else 4, Transparency = if big then 0.45 else 0.62, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
	end
	-- today: a thin white ring (off until it's today)
	local ring = New("Frame", { Name = "TodayRing", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 4, 1, 4), Visible = false, Parent = card }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Color = Colors.Text, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local tag = New("Frame", { Name = "TodayTag", BackgroundColor3 = Colors.Text, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(46, 15), Visible = false, ZIndex = 3, Parent = card }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Kit.Text({ Name = "Text", Text = "TODAY", Font = "Chunky", TextSize = 10, TextColor3 = Colors.Ink, Stroke = false, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = tag })
	local label = Kit.Text({ Name = "Day", Text = "DAY " .. day, Font = "Chunky", TextSize = if big then 13 else 11, Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 14), Parent = card })
	local icons = {} -- the coin / bonus / DNA art (dimmed together)
	local coin = nil
	local bonusTag = nil
	if dnaDay then
		local size = if big then 62 else 48
		local dna = New("ImageLabel", { Name = "Dna", Image = DNA_CUTOUT, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -2), Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit, Parent = card })
		icons.dna = dna -- (prompt 44: the DNA token is never dimmed)
		bonusTag = New("Frame", { Name = "PlusPill", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -20),
			Size = UDim2.fromOffset(24, 15), ZIndex = 3, Parent = card }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
		})
		Kit.Text({ Name = "Plus", Text = "+" .. tokens, Font = "Chunky", TextSize = 11, TextColor3 = Colors.Ink, Stroke = false, Size = UDim2.fromScale(1, 1), ZIndex = 4,
			Parent = bonusTag })
	else
		local boostId, boostAmount = next(Boosts.LoginItems[day] or {})
		local iconSize = 20 -- (prompt 42: ~15% smaller than before)
		coin = Kit.Coin(iconSize, { Name = "Coin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(if boostId then 0.33 else 0.5, 0, 0.5, -1), Parent = card })
		coin.ImageColor3 = Color3.fromHex("#E6C27A") -- (muted gold)
		table.insert(icons, coin)
		if boostId then
			local item = Boosts.ById[boostId]
			local circle = New("Frame", { Name = "Bonus", BackgroundColor3 = Color3.fromHex("#141215"), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.67, 0, 0.5, -1), Size = UDim2.fromOffset(iconSize + 2, iconSize + 2), Parent = card }, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
				New("UIStroke", { Name = "Edge", Color = Colors.Gold, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			local glyph = Pieces.Icon(item.icon, Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 13), Parent = circle })
			glyph:SetAttribute("KeepColor", true)
			table.insert(icons, glyph)
			bonusTag = Kit.GoldText(Kit.Text({ Name = "Plus", Text = "+" .. boostAmount, Font = "Chunky", TextSize = 10, AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(1, -1, 1, -2), Size = UDim2.fromOffset(16, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = circle }))
			icons.circle = circle
		end
	end
	local amount = Kit.GoldText(Kit.Text({ Name = "Amount", Text = Kit.Short(coins), Font = "Chunky", TextSize = if big then 17 elseif dnaDay then 14 else 12,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, 0, 0, if big then 19 else 15), Parent = card }))
	-- (GoldText fades the outline for a clean gradient; the reward keeps a stroke)
	local stroke = amount:FindFirstChild("TextStroke")
	if stroke then stroke.Transparency, stroke.Color = 0.2, Colors.Outline end
	local check = New("Frame", { Name = "Check", BackgroundColor3 = Colors.Green, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(15, 15), Visible = false, ZIndex = 5, Parent = card }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 1.5 }),
	})
	Pieces.Icon("check", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 6, Parent = check })
		:SetAttribute("KeepColor", true)
	streak.cards[day] = { card = card, ring = ring, tag = tag, label = label, amount = amount, icons = icons, bonusTag = bonusTag, check = check, glow = glow }
end
Kit.Text({ Name = "Rules", Text = "Days 4 and " .. DAYS .. " give a DNA token. Miss a day and it starts over.", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted,
	Position = UDim2.fromOffset(0, DESC_Y), Size = UDim2.new(1, 0, 0, 12), Parent = page })
streak.claim = Kit.Button("Green", "Claim", { Name = "Claim", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, CLAIM_Y), Parent = page },
	{ width = 260, height = 36, textSize = 15 })
streak.claim.Activated:Connect(function()
	if streak.claim:GetAttribute("CanClaim") then
		streak.claim:SetAttribute("CanClaim", false)
		Kit.CoinBurst(streak.claim)
		remote:FireServer("ClaimLogin")
	end
end)
streak.record = Kit.Text({ Name = "Record", Text = "", Font = "Chunky", TextSize = 12, TextColor3 = Color3.fromHex("#D8D4DA"), Position = UDim2.fromOffset(0, RECORD_Y),
	Size = UDim2.new(1, 0, 0, 14), Parent = page })
-- the window shrinks to fit the STREAK tab (and grows back for the others)
local FULL_SIZE = modal.group.Size
local function fitWindow()
	modal.group.Size = if currentTab == "Rewards" then UDim2.fromOffset(FULL_SIZE.X.Offset, Kit.TitleHeight + STREAK_H) else FULL_SIZE
end

-- Which calendar day is today's, and has it been claimed?
local function calendarState()
	local daily = ClientData.Get().daily or {}
	local day = today()
	local pending = Economy.LoginDay(daily.lastDay or 0, daily.calendarDay or 0, day)
	if pending then return pending, false end
	return daily.calendarDay or 1, true
end

-- (prompt 43, owner 22 Oct: no Daily icon on the top bar) a small DAILY REWARD card at the top of the right-side stack
-- while today's streak reward can be claimed (gold edge, the red "!" chip); a tap opens the STREAK tab. Gone once claimed.
local rewardCard = Theme.Panel({ Name = "DailyReward", Piece = "hud_box", Clickable = true, Size = UDim2.fromOffset(RightColumn.Width, 30), Visible = false })
do
	local edge = rewardCard:FindFirstChild("Border")
	if edge then edge.Color, edge.Thickness, edge.Transparency = Colors.Gold, 2, 0 end
	Pieces.Icon("gift", Colors.Gold, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(16, 16), Parent = rewardCard })
		:SetAttribute("KeepColor", true)
	Kit.Text({ Name = "Title", Text = "DAILY REWARD", Font = "Chunky", TextSize = 13, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 30, 0.5, 0),
		Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = rewardCard })
	local chip = New("Frame", { Name = "Chip", BackgroundColor3 = Colors.Red, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(17, 17), Parent = rewardCard }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.fromHex("#2A0505"), Thickness = 1.5 }),
	})
	Kit.Text({ Name = "Bang", Text = "!", Font = "Chunky", TextSize = 13, Size = UDim2.fromScale(1, 1), Parent = chip })
end
RightColumn.Add(rewardCard, 1, true)
local rewardWanted = false
local function showRewardCard()
	rewardCard.Visible = rewardWanted and not UIBus.InTutorial()
end
UIBus.AfterTutorial(showRewardCard)

local function refreshCalendars()
	fitWindow()
	local current, claimed = calendarState()
	streak.title.Text = "DAILY STREAK <font color=\"#" .. Colors.Gold:ToHex() .. "\">DAY " .. current .. "</font>"
	for day, c in ipairs(streak.cards) do
		local got = day < current or (day == current and claimed)
		local isToday = day == current
		local future = day > current
		c.ring.Visible = isToday and not claimed
		c.tag.Visible = isToday
		c.card.Position = UDim2.new(0.5, 0, 0.5, if isToday then -6 else 0)
		c.check.Visible = got
		local dim = if got then DIM elseif future then AHEAD else 0
		for _, icon in ipairs(c.icons) do
			if icon:IsA("ImageLabel") then icon.ImageTransparency = dim end
		end
		if c.icons.circle then c.icons.circle.BackgroundTransparency = dim; c.icons.circle.Edge.Transparency = dim end
		c.amount.TextTransparency = dim
		c.label.TextTransparency = if got then DIM else 0
		if c.bonusTag then
			if c.bonusTag:IsA("TextLabel") then c.bonusTag.TextTransparency = dim else c.bonusTag.BackgroundTransparency = dim end
		end
	end
	streak.claim:SetAttribute("CanClaim", not claimed)
	Kit.SetButton(streak.claim, claimed and "Quiet" or "Green", claimed and "Come back tomorrow" or ("Claim day " .. current))
	local best = (ClientData.Get().daily or {}).best or 0
	streak.record.Text = "STREAK RECORD: " .. best .. (if best == 1 then " DAY" else " DAYS")
	dailyPill:SetDot(not claimed)
	rewardWanted = not claimed
	showRewardCard()
end

------------------------------------------------------------------------
-- Achievements tab: the Coach's quest chain
------------------------------------------------------------------------
local chainList = New("ScrollingFrame", { Name = "Chain", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = pages.Achievements }, {
	Theme.List(Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
})
local function chainRow(order: number)
	local card = Kit.Card({ Name = "Coach" .. order, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), Parent = chainList }, {})
	local tile = Kit.IconTile("trophy", Colors.Gold, 32, { Name = "Tile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Parent = card })
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -150, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local sub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -150, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local bar, setBar = Kit.Bar(Colors.Teal, { Name = "Bar", Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -150, 0, 13), Parent = card }, { text = true, textSize = 10 })
	local button = Kit.Button("Gray", "Done", { Name = "Action", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = card },
		{ width = 84, height = 28, textSize = 13 })
	local row = { card = card, tile = tile, text = text, sub = sub, bar = bar, setBar = setBar, button = button, go = nil }
	button.Activated:Connect(function()
		if row.go then
			modal.close()
			Notify.Hint(row.go, "questgo")
		end
	end)
	return row
end
local chainRows = {}
for i = 1, #Quests.Chain + 1 do chainRows[i] = chainRow(i) end -- (+1: the repeat quest after the chain)

local function setTile(tile, icon: string, color: Color3)
	Kit.SetTileColor(tile, color)
	local image = tile:FindFirstChildWhichIsA("ImageLabel", true)
	if image then image.Image = require(Shared.Config.UI).Icons[icon] or image.Image end
end

local function refreshChain()
	local qs = ClientData.Get().quests or {}
	local index = qs.index or 1
	local active = qs.active
	local done = 0
	for i, row in ipairs(chainRows) do
		local quest = i <= #Quests.Chain and Quests.Chain[i] or nil
		if not quest then
			-- after the chain: the Coach's current repeat quest
			local repeatQuest = index > #Quests.Chain and active and Quests.ById[active.id] or nil
			row.card.Visible = repeatQuest ~= nil
			quest = repeatQuest
			if not quest then continue end
		end
		local isDone = i <= #Quests.Chain and i < index
		local isActive = (i <= #Quests.Chain and i == index) or i > #Quests.Chain
		local isCurrent = isActive and active ~= nil and active.id == quest.id
		if isDone then done += 1 end
		row.card.Visible = true
		row.text.Text = quest.text
		row.text.TextTransparency = (isDone or isActive) and 0 or 0.45
		row.bar.Visible = isCurrent and not active.ready
		row.sub.Visible = not row.bar.Visible
		row.sub.Text = Quests.RewardText(quest.reward)
		row.go = nil
		Theme.SetPiece(row.card, (isCurrent and active.ready) and "card_gold" or "card")
		if isDone then
			setTile(row.tile, "check", Colors.Teal)
			Kit.SetButton(row.button, "Flat", "Done")
		elseif isCurrent and active.ready then
			setTile(row.tile, "trophy", Colors.Gold)
			row.sub.Text = "Done! Talk to " .. Quests.CoachName .. ": " .. Quests.RewardText(quest.reward)
			row.go = "Talk to " .. Quests.CoachName .. " at the front desk"
			Kit.SetButton(row.button, "Red", "Go")
		elseif isCurrent then
			setTile(row.tile, "trophy", Color3.fromHex("#2A262B"))
			row.setBar(active.goal > 0 and active.progress / active.goal or 0, Muscles.FormatExp(active.progress) .. "/" .. Muscles.FormatExp(active.goal))
			row.go = quest.text
			Kit.SetButton(row.button, "Dark", "Go")
		elseif isActive then
			setTile(row.tile, "trophy", Color3.fromHex("#2A262B"))
			row.go = "Talk to " .. Quests.CoachName .. " at the front desk for your next quest"
			Kit.SetButton(row.button, "Dark", "Go")
		else
			setTile(row.tile, "lock", Colors.Faint)
			Kit.SetButton(row.button, "Dark", "Locked")
		end
	end
	return done
end

------------------------------------------------------------------------
-- Daily quests
------------------------------------------------------------------------
-- the DAILY QUESTS card in the right column (mockup 01): the first quest still going, its bar, and "1 / 3" done
-- (one card at a time on the right, RightColumn.Priority: today's quest; once all are done it steps back for the coach)
local tracker = RightColumn.Tracker({ name = "DailyTracker", title = "Today's quest", color = Colors.Teal, order = 2, idleOnly = true, clickable = true,
	priority = RightColumn.Priority.Daily })
-- (22 Oct, owner: no quest card during the tutorial; it comes back when the tutorial ends)
task.spawn(function()
	ClientData.Get()
	if UIBus.InTutorial() then
		tracker.frame.Visible = false
		UIBus.AfterTutorial(function() tracker.frame.Visible = true end)
	end
end)
local function refreshTracker(dq, valid)
	local done, total = 0, DailyQuests.PerDay
	local current, currentQuest = nil, nil
	for i = 1, total do
		local entry = valid and dq.list[i] or nil
		local quest = entry and DailyQuests.ById[entry.id]
		if entry and entry.done then done += 1 end
		if quest and not entry.done and not current then current, currentQuest = entry, quest end
	end
	tracker:SetCount(done .. " / " .. total)
	tracker.frame:SetAttribute("CardPriority", currentQuest and RightColumn.Priority.Daily or RightColumn.Priority.Grow + 1)
	if currentQuest then
		tracker:SetText(currentQuest.text)
		tracker:SetProgress(math.clamp((current.progress or 0) / currentQuest.count, 0, 1), (current.progress or 0) .. "/" .. currentQuest.count)
	else
		tracker:SetText(valid and "All done for today!" or "New quests soon")
		tracker:SetProgress(valid and 1 or nil, valid and (done .. "/" .. total) or nil)
	end
end

local function progressText(quest, value: number, spaced: boolean?): string
	local gap = spaced and " / " or "/"
	if quest.type == "cardio" then
		return string.format("%s%s%s m", Kit.Format(value), gap, Kit.Format(quest.count))
	end
	return value .. gap .. quest.count
end

local function refreshQuests(): number
	local data = ClientData.Get()
	local dq = data.dailyQuests
	local valid = type(dq) == "table" and type(dq.list) == "table" and dq.day == today()
	local claimable, claimed, allClaimed = 0, 0, valid
	for i, row in ipairs(rows) do
		local entry = valid and dq.list[i] or nil
		local quest = entry and DailyQuests.ById[entry.id]
		row.card.Visible = quest ~= nil
		row.quest = quest
		if quest then
			local progress = math.min(entry.progress or 0, quest.count)
			row.text.Text = quest.text
			row.setBar(progress / quest.count)
			row.amount.Text = "+" .. Kit.Format(quest.coins) -- (prompt 40: "+60")
			if entry.claimed then
				row.state = "done"
				claimed += 1
			elseif entry.done then
				row.state = "claim"
				claimable += 1
			else
				row.state = "go"
			end
			local state = row.state
			paintTile(row.tile, row.icon, state == "claim", TYPE_ICON[quest.type] or "dumbbell")
			Theme.SetPiece(row.card, state == "claim" and "card_gold" or "card")
			row.button.Visible = state == "claim"
			row.pill.Visible = state == "go"
			row.progress = progressText(quest, progress, true)
			row.pillText.Text = row.progress
			row.doneLabel.Visible = state == "done"
			-- a claimed quest fades back (DONE stays bright)
			local faded = state == "done"
			row.text.TextTransparency = faded and 0.5 or 0
			row.amount.TextTransparency = faded and 0.5 or 0
			row.coin.ImageTransparency = faded and 0.5 or 0
			row.icon.ImageTransparency = faded and 0.5 or 0
			row.bar.BackgroundTransparency = faded and 0.4 or 0
			allClaimed = allClaimed and entry.claimed == true
		end
	end
	local bonusDone = valid and dq.bonus == true
	local bonusReady = allClaimed and not bonusDone
	bonusClaim.Visible = bonusReady
	if bonusReady then Theme.Pulse(bonusClaim, function() return modal.isOpen() and bonusClaim.Visible end) end
	bonusCount.Text = tostring(claimed)
	setBonusBar(claimed / DailyQuests.PerDay)
	bonusReward.Visible = not bonusReady
	if bonusDone then bonusCount.Text = tostring(DailyQuests.PerDay) end
	if bonusReady then claimable += 1 end
	refreshTracker(dq, valid)
	resetLabel.Text = "Resets in " .. untilReset()
	REROLL.refresh()
	return claimable
end

function refreshAll()
	local claimable = refreshQuests()
	refreshCalendars()
	refreshChain()
	local qs = ClientData.Get().quests
	local coachReady = qs and qs.active and qs.active.ready == true
	questTile:SetBadge(claimable)
	questPill:SetBadge(claimable + (coachReady and 1 or 0))
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function open(tab: string?)
	if tab then
		modal.selectTab(tab)
		currentTab = tab
		for name, page in pairs(pages) do page.Visible = name == tab end
	end
	refreshAll()
	if modal.isOpen() then return end
	questTile:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	modal.open()
	Audio.PlayUI("Whoosh")
end
local function close()
	if not modal.isOpen() then return end
	modal.close()
end
local wasOpen = false
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	-- (the X, the backdrop and Esc close the window inside Kit.Modal)
	if not modal.isOpen() and wasOpen then
		questTile:SetActive(false)
		UIBus.MenuPanelVisible:Fire(false)
	end
	wasOpen = modal.isOpen()
end)
UIBus.RegisterPanel("DailyQuests", close)
UIBus.RegisterPanel("Daily", close)
local function toggle(tab: string)
	if modal.isOpen() and currentTab == tab then
		close()
	else
		if not modal.isOpen() then UIBus.PanelOpened("DailyQuests") end
		open(tab)
	end
end
questTile.Activated:Connect(function() toggle("Daily") end)
questPill.Activated:Connect(function() toggle("Daily") end)
dailyPill.Activated:Connect(function() toggle("Rewards") end)
tracker.Activated:Connect(function() if not modal.isOpen() then UIBus.PanelOpened("DailyQuests") open("Daily") end end)
rewardCard.Activated:Connect(function()
	if not modal.isOpen() then UIBus.PanelOpened("DailyQuests") end
	open("Rewards")
end)
if UIBus.OpenQuests then
	UIBus.OpenQuests.Event:Connect(function(tab)
		if not modal.isOpen() then UIBus.PanelOpened("DailyQuests") end
		open(if pages[tab] then tab else "Daily")
	end)
end

------------------------------------------------------------------------
-- Server messages and data
------------------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "QuestDone" then
		-- (prompt 20: a reward popup, queued with the others)
		Notify.Reward("QUEST DONE", tostring(info.text), "list-checks", Colors.Green, "QuestComplete")
	elseif kind == "Claimed" then
		Notify.Toast(info.bonus and "Daily bonus" or "Quest reward", "+" .. Kit.Format(tonumber(info.coins) or 0) .. " coins", "coin", Colors.Gold)
		Audio.PlayUI("QuestClaim")
	elseif kind == "BuyReroll" then
		-- (the server remembered which quest; the reroll happens after the purchase)
		if REROLL.product then MarketplaceService:PromptProductPurchase(player, REROLL.product) end
	elseif kind == "RerollFailed" then
		Notify.Show("That quest can't be rerolled.", nil, "rerollfail")
	elseif kind == "RerollCredit" then
		Notify.Toast("Quest reroll saved", "Your next reroll is free", "repeat", Colors.Gold)
	elseif kind == "Swapped" then
		Notify.Toast("New quest", tostring(info.text), "repeat", Colors.Blue)
	elseif kind == "LoginClaimed" then
		local sub = "+" .. Kit.Format(tonumber(info.coins) or 0) .. " coins"
		Notify.Toast("Day " .. tostring(info.day) .. " reward", sub, "gift", Colors.Gold)
		Audio.PlayUI("StreakClaim")
		if (tonumber(info.tokens) or 0) > 0 then
			Notify.Toast("+" .. tostring(info.tokens) .. " DNA Token", "Reroll your genetics on the Genetics screen", "sparkles", Colors.Gold, "dailydna")
		end
		for id, amount in pairs(type(info.items) == "table" and info.items or {}) do
			local item = Boosts.ById[id]
			if item then Notify.Toast("+" .. tostring(amount) .. " " .. item.name, "Added to your inventory (Boosts)", item.icon, Color3.fromHex(item.color), "dailyitem") end
		end
	end
end)

ClientData.Changed:Connect(function(path)
	if path[1] == "dailyQuests" or path[1] == "daily" or path[1] == "quests" then refreshAll() end
end)

-- the "New quests in" line and a new UTC day while playing (the calendar's claim opens again)
local lastDay = today()
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 then return end
	acc = 0
	if modal.isOpen() then
		resetLabel.Text = "Resets in " .. untilReset()
		REROLL.refresh()
	end
	local day = today()
	if day ~= lastDay then
		lastDay = day
		refreshAll()
	end
end)

-- after Play (and the genetics screen): the window opens on the reward calendar when today's reward is waiting. Not
-- during the tutorial (owner's brief: no pop-ups in a new player's first minutes): it waits until the tutorial is done.
local Onboarding = require(Shared.Config.Onboarding)
task.spawn(function()
	ClientData.Get()
	refreshAll()
	UIBus.WaitForMenu()
	task.wait(1.5)
	while playerGui:FindFirstChild("GeneticsScreen") and playerGui.GeneticsScreen.Enabled do task.wait(0.5) end
	while ((ClientData.Get().onboarding or {}).tutorialStep or Onboarding.Done) < Onboarding.Done do task.wait(2) end
	local _, claimed = calendarState()
	if not claimed and not modal.isOpen() and not UIBus.Training then
		UIBus.PanelOpened("DailyQuests")
		open("Rewards")
	end
end)
