-- DailyClient (owner's feature run, task 2): the daily quests and the login streak calendar on screen. DailyService on the
-- server decides and pays everything; this only shows the data (ClientData "dailyQuests" / "daily") and asks.
--   * Quests tile (left side menu) -> a small panel beside the tiles: today's 3 quests with chunky progress bars, CLAIM
--     when done, one SWAP a day, and the bonus for claiming all three. "New quests in 5h 12m".
--   * Daily pill (top bar) -> the 7-day calendar card: day cards with their coins, today highlighted, CLAIM. It also
--     pops up by itself after Play (and after the genetics screen) when today's reward is waiting.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyQuests = require(Shared.Config.DailyQuests)
local Economy = require(Shared.Config.Economy)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
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
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal
local SEGMENTS = 10

local function today(): number
	return Economy.Day(math.floor(Workspace:GetServerTimeNow()))
end

local function untilReset(): string
	local left = 86400 - (math.floor(Workspace:GetServerTimeNow()) % 86400)
	local h, m = left // 3600, (left % 3600) // 60
	return h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", math.max(m, 1))
end

------------------------------------------------------------------------
-- Daily quests panel (beside the side menu, like the Poses panel)
------------------------------------------------------------------------
local questTile = SideMenu.Add("Quests", "Quests", Icons.Quest, 7)
local questGui = Theme.ScreenGui({ Name = "DailyQuests", Enabled = false, DisplayOrder = 24, Parent = playerGui })
local questPanel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 0.5, 0),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Active = true,
	Parent = questGui,
}, { Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local questTitle = Theme.Text({ LayoutOrder = 0, Text = "Daily quests", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = questPanel })
Theme.Uppercase(questTitle)
local resetLine = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = questPanel })

local rows = {}
local function makeRow(index: number)
	local row = New("Frame", { Name = "Quest" .. index, LayoutOrder = 10 + index, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = questPanel },
		{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local text = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	-- chunky segmented bar (like stacked plates)
	local bar = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, Parent = row },
		{ Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local segments = {}
	for i = 1, SEGMENTS do
		segments[i] = New("Frame", { LayoutOrder = i, Size = UDim2.new(1 / SEGMENTS, -Spacing.XS, 1, 0), BackgroundColor3 = Colors.Chalk, BackgroundTransparency = 0.8, Parent = bar }, { Theme.Round("Segment") })
	end
	local bottom = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = row })
	local count = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = bottom })
	local claim = Theme.Button("Primary", { Name = "Claim", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(112, Theme.MinTouch), Visible = false, Parent = bottom }, {
		Theme.Text({ Name = "Label", Text = "Claim", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	local swap = Theme.Button("Secondary", { Name = "Swap", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(76, Theme.MinTouch), Visible = false, Parent = bottom }, {
		Theme.Text({ Text = "Swap", Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(1, 1) }),
	})
	local reward = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(110, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = bottom })
	claim.Activated:Connect(function() remote:FireServer("Claim", index) end)
	swap.Activated:Connect(function() remote:FireServer("Swap", index) end)
	rows[index] = { frame = row, text = text, segments = segments, count = count, claim = claim, swap = swap, reward = reward }
end
for i = 1, DailyQuests.PerDay do makeRow(i) end

local bonusRow = New("Frame", { Name = "Bonus", LayoutOrder = 50, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = questPanel })
local bonusText = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = bonusRow })
local bonusClaim = Theme.Button("Primary", { Name = "ClaimBonus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(112, Theme.MinTouch), Visible = false, Parent = bonusRow }, {
	Theme.Text({ Text = "Claim", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
bonusClaim.Activated:Connect(function() remote:FireServer("ClaimBonus") end)

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

local function refreshQuests()
	local data = ClientData.Get()
	local dq = data.dailyQuests
	local valid = type(dq) == "table" and type(dq.list) == "table" and dq.day == today()
	local anyClaimable, allClaimed = false, valid
	for i, row in ipairs(rows) do
		local entry = valid and dq.list[i] or nil
		local quest = entry and DailyQuests.ById[entry.id]
		row.frame.Visible = quest ~= nil
		if quest then
			local fraction = math.clamp((entry.progress or 0) / quest.count, 0, 1)
			row.text.Text = quest.text
			row.text.TextColor3 = entry.claimed and Colors.Muted or Colors.Text
			for s, segment in ipairs(row.segments) do
				segment.BackgroundTransparency = (s <= math.floor(fraction * SEGMENTS + 1e-6)) and 0 or 0.8
			end
			if quest.type == "cardio" then
				row.count.Text = string.format("%d / %d m", entry.progress or 0, quest.count)
			else
				row.count.Text = string.format("%d / %d", entry.progress or 0, quest.count)
			end
			local claimable = entry.done and not entry.claimed
			anyClaimable = anyClaimable or claimable
			allClaimed = allClaimed and entry.claimed
			row.claim.Visible = claimable
			local label = row.claim:FindFirstChild("Label")
			if label then label.Text = "Claim +" .. quest.coins end
			-- one swap a day, for a quest you haven't finished (e.g. spotting on an empty server)
			row.swap.Visible = not entry.done and (dq.swaps or 0) < DailyQuests.SwapsPerDay
			row.reward.Visible = not claimable
			row.reward.Text = entry.claimed and "Claimed" or ("+" .. quest.coins .. " coins")
			row.reward.Position = row.swap.Visible and UDim2.new(1, -84, 0.5, 0) or UDim2.new(1, 0, 0.5, 0)
		end
	end
	local bonusDone = valid and dq.bonus == true
	bonusClaim.Visible = allClaimed and not bonusDone
	bonusText.Text = bonusDone and ("All done: +" .. DailyQuests.BonusCoins .. " coins claimed")
		or ("Claim all " .. DailyQuests.PerDay .. ": +" .. DailyQuests.BonusCoins .. " bonus coins")
	local claimableCount = 0
	for i = 1, #rows do
		local entry = valid and dq.list[i] or nil
		if entry and entry.done and not entry.claimed then claimableCount += 1 end
	end
	if allClaimed and not bonusDone then claimableCount += 1 end
	questTile:SetBadge(claimableCount)
	refreshTracker(dq, valid)
	resetLine.Text = "New quests in " .. untilReset()
end

local questsOpen = false
local function setQuests(open: boolean)
	if open == questsOpen then return end
	questsOpen = open
	questTile:SetActive(open)
	if open then
		refreshQuests()
		questPanel.Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 0.5, 0)
		questGui.Enabled = true
		Audio.PlayUI("Whoosh")
		Theme.Fade(questPanel, true)
	else
		local tween = Theme.Fade(questPanel, false)
		if tween then
			tween.Completed:Connect(function() if not questsOpen then questGui.Enabled = false end end)
		else
			questGui.Enabled = false
		end
	end
end
UIBus.RegisterPanel("DailyQuests", function() setQuests(false) end)
questTile.Activated:Connect(function()
	if not questsOpen then UIBus.PanelOpened("DailyQuests") end
	setQuests(not questsOpen)
end)
tracker.Activated:Connect(function()
	if not questsOpen then UIBus.PanelOpened("DailyQuests") end
	setQuests(true)
end)

------------------------------------------------------------------------
-- Login streak calendar (top bar Daily pill; pops up after Play when today's reward is waiting)
------------------------------------------------------------------------
local dailyPill = TopBar.AddPill("Daily", "Daily", Icons.Gift, 2)
local calGui = Theme.ScreenGui({ Name = "LoginCalendar", Enabled = false, DisplayOrder = 26, Parent = playerGui })
local calPanel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 560, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Active = true,
	Parent = calGui,
}, { Theme.Limit(Vector2.new(300, 0), Vector2.new(560, math.huge)), Theme.Pad("L"), Theme.List(Vertical, "M", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
local calHeader = New("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = calPanel })
local calTitle = Theme.Text({ Text = "Login streak", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -48, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = calHeader })
Theme.Uppercase(calTitle)
local calClose = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = calHeader }, {})
local closeIcon = New("Frame", { Size = UDim2.fromScale(0.42, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = calClose })
Icons.Close(Colors.Text).Parent = closeIcon
local calLine = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = calPanel })

local strip = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1, Parent = calPanel },
	{ Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local DAYS = #Economy.Login.Coins
local dayCards = {}
for day = 1, DAYS do
	local card = New("Frame", { Name = "Day" .. day, LayoutOrder = day, Size = UDim2.new(1 / DAYS, -Spacing.XS, 1, 0), BackgroundColor3 = Colors.Panel, BackgroundTransparency = Theme.Alpha.Panel, Parent = strip },
		{ Theme.Round("Button"), Theme.Stroke(), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local dayLabel = Theme.Text({ LayoutOrder = 1, Text = "Day " .. day, Font = "SemiBold", TextSize = "Small", Size = UDim2.new(1, 0, 0, 16), Parent = card })
	Theme.Uppercase(dayLabel)
	local coins, tokens = Economy.LoginReward(day)
	local amount = Theme.Text({ LayoutOrder = 2, Text = tostring(coins), Font = "SemiBold", TextSize = day == DAYS and "Large" or "Body", Size = UDim2.new(1, 0, 0, day == DAYS and 26 or 20), Parent = card })
	local sub = Theme.Text({ LayoutOrder = 3, Text = tokens > 0 and "+ DNA" or "coins", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), Parent = card })
	dayCards[day] = { card = card, stroke = card:FindFirstChildOfClass("UIStroke"), amount = amount, sub = sub, tokens = tokens }
end
Theme.Text({ LayoutOrder = 3, Text = "Day 7 also gives a DNA token and the Dedicated title. Missing a day starts again at day 1.", Font = "Regular", TextSize = "Small",
	TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Parent = calPanel })
local calClaim = Theme.Button("Primary", { Name = "Claim", LayoutOrder = 4, Size = UDim2.fromOffset(220, 52), Parent = calPanel }, {
	Theme.Text({ Name = "Label", Text = "Claim", Font = "SemiBold", TextSize = "Large", Size = UDim2.fromScale(1, 1) }),
})
local calClaimLabel = calClaim:FindFirstChild("Label") :: TextLabel

-- Which calendar day is today's, and has it been claimed?
local function calendarState()
	local daily = ClientData.Get().daily or {}
	local day = today()
	local pending = Economy.LoginDay(daily.lastDay or 0, daily.calendarDay or 0, day)
	if pending then return pending, false end
	return daily.calendarDay or 1, true
end

local function refreshCalendar()
	local current, claimed = calendarState()
	for day, entry in ipairs(dayCards) do
		local got = day < current or (day == current and claimed)
		entry.card.BackgroundTransparency = got and 0.75 or Theme.Alpha.Panel
		entry.amount.TextColor3 = got and Colors.Muted or Colors.Text
		entry.sub.Text = got and "Claimed" or (entry.tokens > 0 and "+ DNA" or "coins")
		if entry.stroke then
			entry.stroke.Color = day == current and Colors.Text or Theme.Border.Color
			entry.stroke.Transparency = day == current and 0.1 or Theme.Border.Transparency
			entry.stroke.Thickness = day == current and 2 or 1
		end
	end
	if claimed then
		calLine.Text = "Day " .. current .. " claimed. Come back tomorrow for day " .. (current % DAYS + 1) .. "."
	else
		calLine.Text = "Day " .. current .. " of " .. DAYS .. ". Claim today's reward!"
	end
	calClaim.Visible = not claimed
	calClaimLabel.Text = "Claim " .. Economy.LoginReward(current) .. " coins"
	dailyPill:SetDot(not claimed)
	dailyPill:SetText("Day " .. current)
end

local calOpen = false
local function setCalendar(open: boolean)
	if open == calOpen then return end
	calOpen = open
	dailyPill:SetActive(open)
	if open then
		refreshCalendar()
		calGui.Enabled = true
		Audio.PlayUI("Whoosh")
		Theme.Fade(calPanel, true)
	else
		local tween = Theme.Fade(calPanel, false)
		if tween then
			tween.Completed:Connect(function() if not calOpen then calGui.Enabled = false end end)
		else
			calGui.Enabled = false
		end
	end
end
UIBus.RegisterPanel("Daily", function() setCalendar(false) end)
dailyPill.Activated:Connect(function()
	if not calOpen then UIBus.PanelOpened("Daily") end
	setCalendar(not calOpen)
end)
calClose.Activated:Connect(function() setCalendar(false) end)
calClaim.Activated:Connect(function()
	calClaim.Active = false
	remote:FireServer("ClaimLogin")
	task.delay(1, function() calClaim.Active = true end)
end)

------------------------------------------------------------------------
-- Server messages and data
------------------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "QuestDone" then
		Notify.Show("Daily quest done: " .. tostring(info.text), nil, "dailyquest")
		Audio.PlayUI("QuestComplete")
	elseif kind == "Claimed" then
		Notify.Show((info.bonus and "Daily bonus: +" or "Quest reward: +") .. tostring(info.coins) .. " coins")
		Audio.PlayUI("QuestClaim")
	elseif kind == "Swapped" then
		Notify.Show("New quest: " .. tostring(info.text))
	elseif kind == "LoginClaimed" then
		local text = "Day " .. tostring(info.day) .. " reward: +" .. tostring(info.coins) .. " coins"
		if (tonumber(info.tokens) or 0) > 0 then text ..= " and a DNA token" end
		Notify.Show(text, info.day == DAYS and Colors.Gold or nil)
		Audio.PlayUI("StreakClaim")
		task.delay(1.2, function() setCalendar(false) end)
	end
end)

ClientData.Changed:Connect(function(path)
	if path[1] == "dailyQuests" then refreshQuests() end
	if path[1] == "daily" then refreshCalendar() end
end)

-- the "resets in" line and a new UTC day while playing (the calendar's claim opens again)
local lastDay = today()
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 then return end
	acc = 0
	if questsOpen then resetLine.Text = "New quests in " .. untilReset() end
	local day = today()
	if day ~= lastDay then
		lastDay = day
		refreshCalendar()
		refreshQuests()
	end
end)

-- after Play (and the genetics screen for new players): the calendar pops up when today's reward is waiting
task.spawn(function()
	ClientData.Get()
	refreshQuests()
	refreshCalendar()
	UIBus.WaitForMenu()
	task.wait(1.5)
	while playerGui:FindFirstChild("GeneticsScreen") and playerGui.GeneticsScreen.Enabled do task.wait(0.5) end
	local _, claimed = calendarState()
	if not claimed then
		UIBus.PanelOpened("Daily")
		setCalendar(true)
	end
end)
