-- QuestClient: the quest tracker (small panel, right middle), the Coach's (and legends') lines above their heads, quest
-- notes in the corner, and a note about today's Muscle of the Day after Play.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Quests = require(Config.Quests)
local Onboarding = require(Config.Onboarding)
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
local New, Colors = Theme.New, Theme.Colors


local SPEECH = { Time = 5, Width = 9, Height = 1.6, Offset = 3.2 } -- seconds, studs

------------------------------------------------------------------------
-- Tracker
------------------------------------------------------------------------
-- the coach quest card (RightColumn.Tracker, mockup 01 look)
-- (one card at a time on the right, RightColumn.Priority: a quest ready to hand in comes before today's quest)
local tracker = RightColumn.Tracker({ name = "QuestTracker", title = "Coach quest", color = Colors.Green, order = 3, idleOnly = true,
	priority = RightColumn.Priority.Coach })
local panel = tracker.frame
panel.Visible = false -- shown after Play

local function refresh()
	local data = ClientData.Get()
	local active = data.quests and data.quests.active
	local quest = active and Quests.ById[active.id]
	panel:SetAttribute("CardPriority", (quest and active.ready) and RightColumn.Priority.CoachReady or RightColumn.Priority.Coach)
	if not quest then
		tracker:SetCount("")
		tracker:SetText("Talk to " .. Quests.CoachName .. " at the front desk")
		tracker:SetProgress(nil)
		tracker:SetFooter("")
		return
	end
	tracker:SetText(quest.text)
	tracker:SetProgress(active.goal > 0 and active.progress / active.goal or 0,
		active.ready and "Done" or (Muscles.FormatExp(active.progress) .. "/" .. Muscles.FormatExp(active.goal)))
	tracker:SetFooter(active.ready and "Done. Claim it in Quests > Goals" or "") -- (prompt 31)
	tracker:SetCount(active.ready and "Ready" or "")
end

-- New players see the tracker once the tutorial sends them to the Coach, so it never competes with the coach line.
local COACH_STEP = Onboarding.Done
for i, step in ipairs(Onboarding.Steps) do
	if step.target == "Coach" then COACH_STEP = i break end
end
-- (the Quests pill at the top right opens the Quests window, DailyClient; its badge counts a coach quest ready to hand in)
local playing = false -- after Play
local function updateVisible()
	local data = ClientData.Get()
	local step = data.onboarding and data.onboarding.tutorialStep or Onboarding.Done
	local show = playing and (step >= COACH_STEP or (data.quests and data.quests.active) ~= nil)
	if show and not panel.Visible then
		refresh()
		panel.Visible = true
		Theme.Fade(panel, true)
	elseif not show then
		panel.Visible = false
	end
end

ClientData.Changed:Connect(function(path)
	if path[1] == "quests" and panel.Visible then refresh() end
	if path[1] == "onboarding" or path[1] == "quests" then updateVisible() end
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

-- `npc` = a model to speak from (legends); defaults to the Coach.
local function coachSays(text, npc)
	local head = (typeof(npc) == "Instance" and npc:FindFirstChild("Head")) or coachHead()
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
	elseif kind == "NpcSays" then
		coachSays(info.text, info.npc)
	elseif kind == "QuestReady" then
		-- (prompt 20: a reward popup, queued with the others)
		Notify.Reward("QUEST DONE", "Claim your reward in Quests > Goals", "list-checks", Colors.Green, "QuestComplete") -- (prompt 31)
	elseif kind == "QuestDone" then
		-- (prompt 47) the reward with the shake's picture when it gives shakes
		local reward = tostring(info.reward)
		local shake = require(ReplicatedStorage.Shared.Config.Boosts).ById.Shake
		Notify.Reward("QUEST REWARD", reward, if string.find(reward, "shake") then shake.icon else "coin", Colors.Gold, "QuestClaim")
	end
end)

------------------------------------------------------------------------
-- Show after Play
------------------------------------------------------------------------
task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	playing = true
	updateVisible()
	task.wait(2)
	local group = Muscles.GroupById[MuscleOfTheDay.GroupId()]
	-- (22 Oct, owner: no non-tutorial popups during the tutorial: after it)
	UIBus.AfterTutorial(function()
		Notify.Show("Muscle of the Day: " .. group.name .. " (" .. MuscleOfTheDay.Multiplier .. "x gains)")
	end)
end)
