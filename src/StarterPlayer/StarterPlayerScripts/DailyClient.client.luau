-- DailyClient: the Quests window (owner's UI v2, mockup 05_quests). DailyService / QuestService on the server decide and
-- pay everything; this only shows the data (ClientData "dailyQuests" / "daily" / "quests") and asks.
-- Opened by the Quests tile (left menu), the Quests pill and the Daily Reward pill (top bar), and the Daily quests card in
-- the right column. Tabs above the window:
--   Daily         today's 3 quests (blue icon, text, bar "50/50", coins, CLAIM green / GO gray / DONE dark; a small swap
--                 button once a day for an unfinished one), the "Complete all 3" bonus row, and on the right the 7-day
--                 Daily Reward grid with CLAIM DAY N.
--   Rewards       the 7-day login streak big, with its rules and CLAIM DAY N.
--   Achievements  the Coach's quest chain in order: done ones DONE, the current one with its bar (GO = where to go),
--                 later ones locked. After the chain: the Coach's current repeat quest.
-- It pops up by itself on the Daily tab after Play (and after the genetics screen) when today's reward is waiting.
-- Badges: the Quests tile and pill show how many things are ready to claim; the Daily Reward pill a dot.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyQuests = require(Shared.Config.DailyQuests)
local Quests = require(Shared.Config.Quests)
local Muscles = require(Shared.Config.Muscles)
local Economy = require(Shared.Config.Economy)
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

local W, H = 580, 290 -- the window (mockup px)
local LEFT_W = 360 -- the quest column on the Daily tab
local ROW_H = 52
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
	tabs = { { id = "Daily", text = "Daily", icon = "list-checks" }, { id = "Rewards", text = "Rewards", icon = "calendar-days" },
		{ id = "Achievements", text = "Achievements", icon = "trophy" } },
	onTab = function(id)
		currentTab = id
		for name, page in pairs(pages) do page.Visible = name == id end
		refreshAll()
	end })
for _, id in ipairs({ "Daily", "Rewards", "Achievements" }) do
	pages[id] = New("Frame", { Name = id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = id == "Daily", Parent = modal.body })
end
local resetLabel = Kit.Text({ Name = "Reset", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -56, 0, 15), Size = UDim2.fromOffset(200, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = modal.panel })

------------------------------------------------------------------------
-- Daily tab: quest rows
------------------------------------------------------------------------
local questCol = New("Frame", { Name = "Quests", BackgroundTransparency = 1, Size = UDim2.new(0, LEFT_W, 1, 0), Parent = pages.Daily },
	{ Theme.List(Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

-- the coin + amount line
local function coinAmount(props)
	local frame = New("Frame", props, { Theme.List(Horizontal, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	frame.BackgroundTransparency = 1
	Kit.Coin(15, { LayoutOrder = 1, Parent = frame })
	local amount = Kit.Text({ Name = "Amount", LayoutOrder = 2, Text = "", Font = "Number", TextSize = 15, Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X, Parent = frame })
	return frame, amount
end

local rows = {}
for index = 1, DailyQuests.PerDay do
	local card = Kit.Card({ Name = "Quest" .. index, LayoutOrder = index, Size = UDim2.new(1, 0, 0, ROW_H), Parent = questCol }, {})
	local tile = Kit.IconTile("dumbbell", Colors.Blue, 38, { Name = "Tile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Parent = card })
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(52, 6), Size = UDim2.new(1, -150, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local bar, setBar = Kit.Bar(Colors.Green, { Name = "Bar", Position = UDim2.fromOffset(52, 29), Size = UDim2.new(1, -150, 0, 15), Parent = card }, { text = true, textSize = 11 })
	local _, amount = coinAmount({ Name = "Reward", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 3), Size = UDim2.fromOffset(84, 18), Parent = card })
	local button = Kit.Button("Green", "Claim", { Name = "Action", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -5), Parent = card },
		{ width = 84, height = 26, textSize = 13 })
	-- one swap a day for an unfinished quest (e.g. spotting on an empty server)
	local swap = Theme.Button("Dark", { Name = "Swap", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(26, 26), Parent = card }, {})
	Pieces.Icon("repeat", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Parent = swap })
	local row = { card = card, tile = tile, text = text, bar = bar, setBar = setBar, amount = amount, button = button, swap = swap, state = "go", quest = nil }
	button.Activated:Connect(function()
		if row.state == "claim" then
			remote:FireServer("Claim", index)
		elseif row.state == "go" and row.quest then
			modal.close()
			Notify.Hint(goHint(row.quest), "questgo")
		end
	end)
	swap.Activated:Connect(function() remote:FireServer("Swap", index) end)
	rows[index] = row
end

-- "Complete all 3": the bonus for claiming all of today's quests
local bonus = Kit.Card({ Name = "Bonus", LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 46), Piece = "banner_gold", Parent = questCol }, {})
Pieces.Icon("trophy", Colors.Gold, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(24, 24), Parent = bonus })
	:SetAttribute("KeepColor", true)
Kit.Text({ Text = "Complete all " .. DailyQuests.PerDay, Font = "Title", TextSize = 15, Position = UDim2.fromOffset(50, 5), Size = UDim2.new(1, -150, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = bonus })
Kit.Text({ Text = "Bonus " .. Kit.Format(DailyQuests.BonusCoins) .. " coins", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(50, 24),
	Size = UDim2.new(1, -150, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = bonus })
local bonusCount = Kit.Text({ Name = "Count", Text = "", Font = "Title", TextSize = 20, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(80, 26), TextXAlignment = Enum.TextXAlignment.Right, Parent = bonus })
local bonusClaim = Kit.Button("Green", "Claim", { Name = "Claim", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Visible = false, Parent = bonus },
	{ width = 84, height = 28, textSize = 13 })
bonusClaim.Activated:Connect(function() remote:FireServer("ClaimBonus") end)

------------------------------------------------------------------------
-- Daily reward grids (the small one on the Daily tab, the big one on the Rewards tab)
------------------------------------------------------------------------
local calendars = {}
local function makeCalendar(parent, cell: Vector2, columns: number, titleSize: number)
	local frame = New("Frame", { Name = "Calendar", BackgroundTransparency = 1, Parent = parent })
	local title = Kit.Text({ Name = "Title", Text = "", Font = "Title", TextSize = titleSize, RichText = true, Size = UDim2.new(1, 0, 0, titleSize + 4),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local grid = New("Frame", { Name = "Days", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, titleSize + 8),
		Size = UDim2.new(1, 0, 0, math.ceil(DAYS / columns) * (cell.Y + 6)), Parent = frame }, {
		New("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local cards = {}
	for day = 1, DAYS do
		local coins, tokens = Economy.LoginReward(day)
		local card = Kit.Card({ Name = "Day" .. day, LayoutOrder = day, Parent = grid }, {})
		local label = Kit.Text({ Name = "Day", Text = "DAY " .. day, Font = "Title", TextSize = 12, Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 14), Parent = card })
		local coin = Kit.Coin(math.floor(cell.Y * 0.34), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = card })
		local amount = Kit.Text({ Name = "Amount", Text = Kit.Short(coins) .. (tokens > 0 and " + DNA" or ""), Font = "Number", TextSize = 12,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 14), Parent = card })
		local check = Pieces.Icon("check", Colors.Green, { Name = "Check", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(13, 13), Visible = false, Parent = card })
		check:SetAttribute("KeepColor", true)
		cards[day] = { card = card, label = label, coin = coin, amount = amount, check = check }
	end
	local claim = Kit.Button("Green", "Claim", { Name = "Claim", Parent = frame }, { height = 32, textSize = 15 })
	claim.AutomaticSize = Enum.AutomaticSize.None
	claim.Activated:Connect(function()
		if claim:GetAttribute("CanClaim") then
			claim:SetAttribute("CanClaim", false)
			remote:FireServer("ClaimLogin")
		end
	end)
	local entry = { frame = frame, title = title, grid = grid, cards = cards, claim = claim }
	table.insert(calendars, entry)
	return entry
end

local smallCal = makeCalendar(pages.Daily, Vector2.new(56, 44), 3, 15)
smallCal.frame.Position = UDim2.fromOffset(LEFT_W + 12, 0)
smallCal.frame.Size = UDim2.new(1, -(LEFT_W + 12), 1, 0)
smallCal.claim.AnchorPoint = Vector2.new(0, 1)
smallCal.claim.Position = UDim2.fromScale(0, 1)
smallCal.claim.Size = UDim2.new(1, 0, 0, 32)

local bigCal = makeCalendar(pages.Rewards, Vector2.new(72, 70), DAYS, 17)
bigCal.frame.Size = UDim2.fromScale(1, 1)
bigCal.grid.Size = UDim2.new(1, 0, 0, 76)
Kit.Text({ Name = "Rules", Text = "Log in every day to keep your streak. Day " .. DAYS .. " also gives a DNA token and the Dedicated title. Missing a day starts again at day 1.",
	Font = "Body", TextSize = 13, TextColor3 = Colors.Muted, TextWrapped = true, Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = bigCal.frame })
bigCal.claim.AnchorPoint = Vector2.new(0.5, 1)
bigCal.claim.Position = UDim2.new(0.5, 0, 1, 0)
bigCal.claim.Size = UDim2.fromOffset(260, 36)

-- Which calendar day is today's, and has it been claimed?
local function calendarState()
	local daily = ClientData.Get().daily or {}
	local day = today()
	local pending = Economy.LoginDay(daily.lastDay or 0, daily.calendarDay or 0, day)
	if pending then return pending, false end
	return daily.calendarDay or 1, true
end

local function refreshCalendars()
	local current, claimed = calendarState()
	for _, cal in ipairs(calendars) do
		cal.title.Text = "Daily Reward <font color=\"#" .. Colors.Gold:ToHex() .. "\">Day " .. current .. "</font>"
		for day, c in ipairs(cal.cards) do
			local got = day < current or (day == current and claimed)
			local isToday = day == current and not claimed
			Theme.SetPiece(c.card, "card")
			if isToday then
				c.card.BackgroundColor3 = Colors.Green
				c.card:FindFirstChild("Border").Color = Colors.Green:Lerp(Color3.new(1, 1, 1), 0.35)
			end
			local future = day > current
			c.label.TextTransparency = future and 0.45 or 0
			c.amount.TextTransparency = future and 0.45 or 0
			c.coin.ImageTransparency = future and 0.5 or 0
			c.check.Visible = got
		end
		cal.claim:SetAttribute("CanClaim", not claimed)
		Kit.SetButton(cal.claim, claimed and "Gray" or "Green", claimed and "Come back tomorrow" or ("Claim day " .. current))
	end
	dailyPill:SetDot(not claimed)
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
	local bar, setBar = Kit.Bar(Colors.Green, { Name = "Bar", Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -150, 0, 13), Parent = card }, { text = true, textSize = 10 })
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
		if isDone then
			setTile(row.tile, "check", Colors.Green)
			Kit.SetButton(row.button, "Gray", "Done")
		elseif isCurrent and active.ready then
			setTile(row.tile, "trophy", Colors.Gold)
			row.sub.Text = "Done! Talk to " .. Quests.CoachName .. ": " .. Quests.RewardText(quest.reward)
			row.go = "Talk to " .. Quests.CoachName .. " at the front desk"
			Kit.SetButton(row.button, "Green", "Go")
		elseif isCurrent then
			setTile(row.tile, "trophy", Colors.Blue)
			row.setBar(active.goal > 0 and active.progress / active.goal or 0, Muscles.FormatExp(active.progress) .. "/" .. Muscles.FormatExp(active.goal))
			row.go = quest.text
			Kit.SetButton(row.button, "Dark", "Go")
		elseif isActive then
			setTile(row.tile, "trophy", Colors.Blue)
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
local tracker = RightColumn.Tracker({ name = "DailyTracker", title = "Daily quests", color = Colors.Green, order = 2, idleOnly = true, clickable = true })
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
	if currentQuest then
		tracker:SetText(currentQuest.text)
		tracker:SetProgress(math.clamp((current.progress or 0) / currentQuest.count, 0, 1), (current.progress or 0) .. "/" .. currentQuest.count)
	else
		tracker:SetText(valid and "All done for today!" or "New quests soon")
		tracker:SetProgress(valid and 1 or nil, valid and (done .. "/" .. total) or nil)
	end
end

local function progressText(quest, value: number): string
	if quest.type == "cardio" then
		return string.format("%s/%s m", Kit.Format(value), Kit.Format(quest.count))
	end
	return value .. "/" .. quest.count
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
			row.setBar(progress / quest.count, progressText(quest, progress))
			row.amount.Text = Kit.Format(quest.coins)
			setTile(row.tile, TYPE_ICON[quest.type] or "dumbbell", Colors.Blue)
			if entry.claimed then
				row.state = "done"
				claimed += 1
				Kit.SetButton(row.button, "Gray", "Done")
			elseif entry.done then
				row.state = "claim"
				claimable += 1
				Kit.SetButton(row.button, "Green", "Claim")
			else
				row.state = "go"
				Kit.SetButton(row.button, "Dark", "Go")
			end
			allClaimed = allClaimed and entry.claimed == true
			row.swap.Visible = not entry.done and (dq.swaps or 0) < DailyQuests.SwapsPerDay
			-- the text and bar end before the swap button when it shows
			local width = row.swap.Visible and -184 or -150
			row.text.Size = UDim2.new(1, width, 0, 18)
			row.bar.Size = UDim2.new(1, width, 0, 15)
		end
	end
	local bonusDone = valid and dq.bonus == true
	local bonusReady = allClaimed and not bonusDone
	bonusClaim.Visible = bonusReady
	bonusCount.Visible = not bonusReady
	bonusCount.Text = bonusDone and "Done" or (claimed .. "/" .. DailyQuests.PerDay)
	if bonusReady then claimable += 1 end
	refreshTracker(dq, valid)
	resetLabel.Text = "New quests in " .. untilReset()
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
	resetLabel.Visible = currentTab == "Daily"
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
		Notify.Toast("Daily quest done!", tostring(info.text), "list-checks", Colors.Green, "dailyquest")
		Audio.PlayUI("QuestComplete")
	elseif kind == "Claimed" then
		Notify.Toast(info.bonus and "Daily bonus" or "Quest reward", "+" .. Kit.Format(tonumber(info.coins) or 0) .. " coins", "coin", Colors.Gold)
		Audio.PlayUI("QuestClaim")
	elseif kind == "Swapped" then
		Notify.Toast("New quest", tostring(info.text), "repeat", Colors.Blue)
	elseif kind == "LoginClaimed" then
		local sub = "+" .. Kit.Format(tonumber(info.coins) or 0) .. " coins"
		if (tonumber(info.tokens) or 0) > 0 then sub ..= " and a DNA token" end
		Notify.Toast("Day " .. tostring(info.day) .. " reward", sub, "gift", Colors.Gold)
		Audio.PlayUI("StreakClaim")
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
	if modal.isOpen() then resetLabel.Text = "New quests in " .. untilReset() end
	local day = today()
	if day ~= lastDay then
		lastDay = day
		refreshAll()
	end
end)

-- after Play (and the genetics screen for new players): the window opens on the Daily tab when today's reward is waiting
task.spawn(function()
	ClientData.Get()
	refreshAll()
	UIBus.WaitForMenu()
	task.wait(1.5)
	while playerGui:FindFirstChild("GeneticsScreen") and playerGui.GeneticsScreen.Enabled do task.wait(0.5) end
	local _, claimed = calendarState()
	if not claimed and not modal.isOpen() then
		UIBus.PanelOpened("DailyQuests")
		open("Daily")
	end
end)
