-- RivalClient (owner's feature run, task 6): the NPC rivals' challenge card, win card and lines. RivalService decides
-- everything; this only shows it.
--   * a small "RIVAL" tag over every rival (NPCs with the Rival attribute)
--   * challenge card (centre): name, gym, his line, the challenge, his record vs your best, the reward (title plate in its
--     rarity color + coins), I'M IN / LATER (or a note when it's on / beaten). X, Esc or walking away closes it.
--   * win card (bottom centre, fades after a few seconds): "YOU BEAT BENNY", his line, coins + title, the next rival
--   * his lines in a speech bubble over his head ("Not bad, rookie." / "Come back stronger.")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rivals = require(Shared.Config.Rivals)
local Titles = require(Shared.Config.Titles)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Rival", 60) :: RemoteEvent
if not remote then return end -- the rival service didn't start

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local titleById = {}
for _, title in ipairs(Titles.List) do titleById[title.id] = title end

-- the rival's NPC model (Workspace.NPCs, attribute Rival = id)
local function rivalModel(id)
	local npcs = Workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:GetAttribute("Rival") == id then return npc end
	end
	return nil
end

------------------------------------------------------------------------
-- Challenge card
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "RivalCard", Enabled = false, DisplayOrder = 25, Parent = playerGui })
local panel = Theme.Panel({
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = true, Parent = gui,
}, { Theme.Pad("L"), Theme.List(Vertical, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

local header = New("Frame", { Name = "Header", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = panel })
local nameLabel = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -52, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
Theme.Uppercase(nameLabel)
local gymLabel = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, -52, 0, 18), Position = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local close = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = header }, {})
local closeIcon = New("Frame", { Size = UDim2.fromScale(0.42, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = close })
Icons.Close(Colors.Text).Parent = closeIcon

local quote = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Body", TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
local challengeHead = Theme.Text({ LayoutOrder = 2, Text = "Challenge", Font = "SemiBold", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
Theme.Uppercase(challengeHead)
local challenge = Theme.Text({ LayoutOrder = 3, Text = "", Font = "Regular", TextSize = "Body", TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

-- his record vs your best (lift challenges)
local numbers = New("Frame", { Name = "Numbers", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local function numberBox(order, caption)
	local box = Theme.Panel({ LayoutOrder = order, Size = UDim2.new(0.5, -6, 1, 0), Parent = numbers }, { Theme.Pad("S") })
	local top = Theme.Text({ Text = caption, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	local value = Theme.Text({ Text = "", Font = "Bold", TextSize = "Large", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	return top, value
end
local recordCaption, recordValue = numberBox(1, "His record")
local _, bestValue = numberBox(2, "Your best")

-- reward: the title as a plate disc in its rarity color + its name, and the coins
local reward = New("Frame", { Name = "Reward", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
local rewardHead = Theme.Text({ LayoutOrder = 1, Text = "Reward", Font = "SemiBold", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Parent = reward })
Theme.Uppercase(rewardHead)
local disc = Theme.PlateDisc(Theme.Rarity.Common, { LayoutOrder = 2, Size = UDim2.fromOffset(14, 14), Parent = reward })
local rewardText = Theme.Text({ LayoutOrder = 3, Text = "", Font = "Regular", TextSize = "Body", Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = reward })

local status = Theme.Text({ LayoutOrder = 6, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local buttons = New("Frame", { Name = "Buttons", LayoutOrder = 7, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
local accept = Theme.Button("Primary", { Name = "Accept", LayoutOrder = 1, Size = UDim2.new(0.5, -4, 1, 0), Parent = buttons }, {
	Theme.Text({ Name = "Label", Text = "I'm in", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local later = Theme.Button("Secondary", { Name = "Later", LayoutOrder = 2, Size = UDim2.new(0.5, -4, 1, 0), Parent = buttons }, {
	Theme.Text({ Name = "Label", Text = "Later", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local laterLabel = later:FindFirstChild("Label") :: TextLabel

local openId = nil -- rival id while the card is open
local openAt = nil -- where you stood when it opened (walking away from there closes it)

local function setOpen(id)
	if id == openId then return end
	openId = id
	if id then
		gui.Enabled = true
		Audio.PlayUI("Whoosh")
		Theme.Fade(panel, true)
	else
		local tween = Theme.Fade(panel, false)
		if tween then
			tween.Completed:Connect(function() if not openId then gui.Enabled = false end end)
		else
			gui.Enabled = false
		end
	end
end

local function showCard(info)
	local rival = Rivals.ById[info.id]
	if not rival then return end
	nameLabel.Text = rival.name
	gymLabel.Text = rival.gymName .. " rival"
	local state = info.state
	-- phones (short screens): no quote and no "CHALLENGE" heading, tighter spacing, so the card fits the height
	local compact = Theme.IsCompact()
	quote.Visible = not compact
	challengeHead.Visible = not compact
	local pad = panel:FindFirstChildOfClass("UIPadding")
	local list = panel:FindFirstChildOfClass("UIListLayout")
	local space = compact and Theme.Spacing.M or Theme.Spacing.L
	if pad then pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, space), UDim.new(0, space), UDim.new(0, space), UDim.new(0, space) end
	if list then list.Padding = UDim.new(0, compact and Theme.Spacing.S or Theme.Spacing.M) end
	quote.Text = "\"" .. (state == "beaten" and rival.lines.beaten or rival.lines.intro) .. "\""
	challenge.Text = tostring(info.challenge or "")
	local lift = rival.challenge.kind == "lift"
	numbers.Visible = lift
	if lift then
		recordCaption.Text = "His record · " .. tostring(info.machine or "")
		recordValue.Text = tostring(info.record or "")
		bestValue.Text = info.best or "None yet"
	end
	local title = titleById[rival.reward.title]
	disc.BackgroundColor3 = (Theme.Rarity[title and title.rarity or "Common"] or Theme.Rarity.Common).Fill
	local rim = disc:FindFirstChildOfClass("UIStroke")
	if rim then rim.Color = (Theme.Rarity[title and title.rarity or "Common"] or Theme.Rarity.Common).Rim end
	rewardText.Text = (title and title.name or "") .. " title · " .. rival.reward.coins .. " coins"
	accept.Visible = state == "new"
	if state == "new" then
		status.Text = ""
		status.Visible = false
		laterLabel.Text = "Later"
	elseif state == "active" then
		status.Visible = true
		status.Text = lift and ("Challenge on. Do it on any " .. tostring(info.machine or "machine") .. " in town.")
			or ("Challenge on. Sit at an arm wrestling table and pick " .. rival.name .. ".")
		laterLabel.Text = "Got it"
	else
		status.Visible = true
		status.Text = "You beat " .. rival.name .. "." .. (rival.challenge.kind == "arm" and " Pick " .. rival.name .. " at a table for a rematch." or "")
		laterLabel.Text = "Close"
	end
	UIBus.PanelOpened("RivalCard")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	openAt = root and root.Position
	setOpen(info.id)
end

accept.Activated:Connect(function()
	if openId then remote:FireServer("Accept", openId) end
	setOpen(nil)
end)
later.Activated:Connect(function() setOpen(nil) end)
close.Activated:Connect(function() setOpen(nil) end)
UIBus.RegisterPanel("RivalCard", function() setOpen(nil) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and openId then setOpen(nil) end
end)

------------------------------------------------------------------------
-- Win card (bottom centre, small, fades out on its own)
------------------------------------------------------------------------
local winGui = Theme.ScreenGui({ Name = "RivalWin", Enabled = false, DisplayOrder = 24, Parent = playerGui })
local winPanel = Theme.Panel({
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150),
	Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = true, Parent = winGui,
}, { Theme.Pad("M"), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
local winTitle = Theme.Text({ LayoutOrder = 1, Text = "", Font = "Bold", TextSize = "Title", Size = UDim2.new(1, 0, 0, 36), Parent = winPanel })
Theme.Uppercase(winTitle)
local winLine = Theme.Text({ LayoutOrder = 2, Text = "", Font = "Regular", TextSize = "Body", TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = winPanel })
local winRewardRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = winPanel },
	{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local winDisc = Theme.PlateDisc(Theme.Rarity.Common, { LayoutOrder = 1, Size = UDim2.fromOffset(14, 14), Parent = winRewardRow })
local winReward = Theme.Text({ LayoutOrder = 2, Text = "", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Upper = false, Parent = winRewardRow })
local winNext = Theme.Text({ LayoutOrder = 4, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = winPanel })
local winToken = 0

local function hideWin()
	winToken += 1
	local tween = Theme.Fade(winPanel, false)
	if tween then tween.Completed:Connect(function() winGui.Enabled = false end) else winGui.Enabled = false end
end
winPanel.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then hideWin() end
end)

local function showWin(info)
	local rival = Rivals.ById[info.id]
	if not rival then return end
	local title = titleById[tostring(info.title)]
	local plate = Theme.Rarity[title and title.rarity or "Common"] or Theme.Rarity.Common
	winTitle.Text = "You beat " .. rival.name
	winLine.Text = "\"" .. tostring(info.line or "") .. "\""
	winDisc.BackgroundColor3 = plate.Fill
	local rim = winDisc:FindFirstChildOfClass("UIStroke")
	if rim then rim.Color = plate.Rim end
	winReward.Text = "+" .. tostring(info.coins or 0) .. " coins · " .. (title and title.name or "") .. " title"
	winNext.Text = tostring(info.next or "")
	winPanel.Position = UDim2.new(0.5, 0, 1, Theme.IsCompact() and -96 or -150) -- (above the machine panel)
	winGui.Enabled = true
	Theme.Fade(winPanel, true)
	Audio.PlayUI("RivalWin")
	winToken += 1
	local token = winToken
	task.delay(7, function() if winToken == token then hideWin() end end)
end

------------------------------------------------------------------------
-- Rival tags and speech bubbles (over his head)
------------------------------------------------------------------------
local bubbles = {} -- [rival id] = { gui, text, token }

local function head(npc)
	return npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
end

local function bubbleFor(id)
	local npc = rivalModel(id)
	local h = npc and head(npc)
	if not h then return nil end
	local entry = bubbles[id]
	if entry and entry.gui.Parent then
		entry.gui.Adornee = h
		return entry
	end
	local bill = New("BillboardGui", { Name = "RivalBubble", Adornee = h, Size = UDim2.fromOffset(240, 60), StudsOffset = Vector3.new(0, 4.2, 0),
		AlwaysOnTop = false, MaxDistance = 40, Enabled = false, ResetOnSpawn = false, Parent = playerGui })
	local box = Theme.Panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, Parent = bill }, { Theme.Pad("S") })
	local text = Theme.Text({ Text = "", Font = "Regular", TextSize = "Body", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false, Parent = box })
	New("UISizeConstraint", { MaxSize = Vector2.new(236, 200), Parent = box })
	entry = { gui = bill, box = box, text = text, token = 0 }
	bubbles[id] = entry
	return entry
end

local function say(id, line)
	local entry = bubbleFor(id)
	if not entry then return end
	entry.text.TextWrapped = #line > 30
	if entry.text.TextWrapped then entry.text.Size = UDim2.fromOffset(220, 0) else entry.text.Size = UDim2.fromOffset(0, 0) end
	entry.text.Text = line
	entry.gui.Enabled = true
	Theme.Fade(entry.box, true)
	entry.token += 1
	local token = entry.token
	task.delay(Rivals.BubbleSeconds, function()
		if entry.token ~= token then return end
		local tween = Theme.Fade(entry.box, false)
		if tween then tween.Completed:Connect(function() if entry.token == token then entry.gui.Enabled = false end end) else entry.gui.Enabled = false end
	end)
end

-- the small RIVAL tag (under his name label, white with a dark outline; sized in studs, only near him). Owner, 14 Oct:
-- only while his challenge is on (data.rivals[id] == "active"), never on every rival all the time.
local tags = {}
local function tag(npc)
	local id = npc:GetAttribute("Rival")
	if not id then return end
	local bill = tags[npc]
	if not bill then
		local h = head(npc)
		if not h then return end
		bill = New("BillboardGui", { Name = "RivalTag", Adornee = h, Size = UDim2.new(2.4, 0, 0.42, 0), StudsOffset = Vector3.new(0, 2.6, 0),
			AlwaysOnTop = false, MaxDistance = 40, LightInfluence = 0, ResetOnSpawn = false, Parent = playerGui })
		local label = Theme.Text({ Text = "Rival", Font = "Bold", TextSize = "Small", TextScaled = true, Size = UDim2.fromScale(1, 1), Parent = bill })
		Theme.Uppercase(label)
		Theme.TextShadow(label)
		tags[npc] = bill
	end
	local data = require(Shared.ClientData).Get()
	bill.Enabled = data ~= nil and type(data.rivals) == "table" and data.rivals[id] == "active"
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 then return end
	acc = 0
	local npcs = Workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:GetAttribute("Rival") then tag(npc) end
	end
	-- walked away: close his card (from where you opened it: he may walk off himself)
	if openId and openAt then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - openAt).Magnitude > Rivals.PromptDistance then setOpen(nil) end
	end
end)

------------------------------------------------------------------------
-- Messages
------------------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	local rival = Rivals.ById[info.id]
	if not rival then return end
	if kind == "Card" then
		showCard(info)
	elseif kind == "Say" then
		say(rival.id, tostring(info.line or ""))
		if info.line == rival.lines.lose then Audio.PlayUI("RivalLose") end
	elseif kind == "Result" then
		setOpen(nil)
		say(rival.id, tostring(info.line or ""))
		showWin(info)
	end
end)
