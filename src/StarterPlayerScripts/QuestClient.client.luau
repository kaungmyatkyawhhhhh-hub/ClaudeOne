-- QuestClient: the quest tracker (small panel, right middle), the Coach's one-liners above his head, quest
-- notes in the corner, and a note about today's Muscle of the Day after Play.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Quests = require(Config.Quests)
local Muscles = require(Config.Muscles)
local MuscleOfTheDay = require(Config.MuscleOfTheDay)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local SEGMENTS = 10
local SPEECH = { Time = 5, Width = 9, Height = 1.6, Offset = 3.2 } -- seconds, studs

------------------------------------------------------------------------
-- Tracker
------------------------------------------------------------------------
local panel = Theme.Panel({
	Name = "QuestTracker",
	Size = UDim2.fromOffset(RightColumn.Width, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false, -- shown after Play
}, {
	Theme.Pad("M"),
	Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
RightColumn.Add(panel, 2)
local header = Theme.Text({ LayoutOrder = 1, Text = "Quest", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
local questText = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
local bar = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, Parent = panel }, { Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Left) })
local segments = {}
for i = 1, SEGMENTS do
	local back = New("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = bar },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	segments[i] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end
local footer = Theme.Text({ LayoutOrder = 4, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local function refresh()
	local data = ClientData.Get()
	local active = data.quests and data.quests.active
	local quest = active and Quests.ById[active.id]
	if not quest then
		header.Text = "Quest"
		questText.Text = "Talk to " .. Quests.CoachName .. " at the front desk"
		bar.Visible = false
		footer.Text = ""
		footer.Visible = false
		return
	end
	header.Text = "Quest"
	questText.Text = quest.text
	bar.Visible = true
	local filled = active.goal > 0 and active.progress / active.goal * SEGMENTS or 0
	for i, fill in ipairs(segments) do
		Theme.Tween(fill, { Size = UDim2.fromScale(math.clamp(filled - (i - 1), 0, 1), 1) }, Theme.Motion.Time)
	end
	footer.Visible = true
	footer.Text = active.ready and ("Done. Talk to " .. Quests.CoachName) or (active.progress .. " / " .. active.goal)
	footer.TextColor3 = active.ready and Colors.Text or Colors.Muted
end

ClientData.Changed:Connect(function(path)
	if path[1] == "quests" and panel.Visible then refresh() end
end)

------------------------------------------------------------------------
-- The Coach's speech: a line above his head, only for this player
------------------------------------------------------------------------
local speech = nil
local speechToken = 0

local function coachHead()
	for _, model in ipairs(CollectionService:GetTagged("Coach")) do
		local head = model:FindFirstChild("Head")
		if head then return head end
	end
	return nil
end

local function coachSays(text)
	local head = coachHead()
	if not head then
		Notify.Show(Quests.CoachName .. ": " .. text)
		return
	end
	if speech then speech:Destroy() end
	speechToken += 1
	local token = speechToken
	speech = New("BillboardGui", {
		Name = "CoachSpeech",
		Adornee = head,
		Size = UDim2.fromScale(SPEECH.Width, SPEECH.Height),
		StudsOffset = Vector3.new(0, SPEECH.Offset, 0),
		MaxDistance = 40,
		LightInfluence = 0,
		AlwaysOnTop = true,
		Parent = playerGui,
	})
	local box = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Parent = speech,
	}, { New("UICorner", { CornerRadius = UDim.new(0.2, 0) }), Theme.Stroke(), New("UIPadding", { PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0), PaddingTop = UDim.new(0.08, 0), PaddingBottom = UDim.new(0.08, 0) }) })
	New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		FontFace = Theme.Fonts.Regular,
		TextScaled = true, -- stud-sized billboard: the only place text may scale
		TextColor3 = Colors.Text,
		Parent = box,
	}, { New("UITextSizeConstraint", { MinTextSize = Theme.TextSize.Small, MaxTextSize = 28 }) })
	Theme.Fade(box, true, 0.2)
	task.delay(SPEECH.Time, function()
		if token ~= speechToken or not speech then return end
		local tween = Theme.Fade(box, false, 0.4)
		local current = speech
		if tween then
			tween.Completed:Connect(function() if current then current:Destroy() end end)
		else
			current:Destroy()
		end
	end)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "CoachSays" then
		coachSays(info.text)
	elseif kind == "QuestReady" then
		Notify.Show("Quest done. Talk to " .. Quests.CoachName .. ".", nil, "quest")
		Audio.PlayUI("LevelUp")
	elseif kind == "QuestDone" then
		Notify.Show("Quest reward: " .. tostring(info.reward))
	end
end)

------------------------------------------------------------------------
-- Show after Play
------------------------------------------------------------------------
task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	refresh()
	panel.Visible = true
	Theme.Fade(panel, true)
	task.wait(2)
	local group = Muscles.GroupById[MuscleOfTheDay.GroupId()]
	Notify.Show("Muscle of the Day: " .. group.name .. " (" .. MuscleOfTheDay.Multiplier .. "x gains)")
end)
