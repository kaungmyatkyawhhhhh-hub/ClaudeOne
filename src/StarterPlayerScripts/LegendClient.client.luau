-- LegendClient: the legend challenge tracker in the right column (under the quest tracker), and notes when a
-- legend arrives, leaves, or a challenge is finished. The Title Book doubles as the "Legends met" list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Legends = require(Shared.Config.Legends)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local New, Colors = Theme.New, Theme.Colors
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal
local SEGMENTS = 10

local panel = Theme.Panel({
	Name = "LegendTracker",
	Size = UDim2.fromOffset(RightColumn.Width, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
}, {
	Theme.Pad("M"),
	Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
RightColumn.Add(panel, 3)
local header = Theme.Text({ LayoutOrder = 1, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
local text = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
local bar = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, Parent = panel }, { Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Left) })
local segments = {}
for i = 1, SEGMENTS do
	local back = New("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = bar },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	segments[i] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end
local footer = Theme.Text({ LayoutOrder = 4, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local started = false
local function refresh()
	if not started then return end
	local data = ClientData.Get()
	local active = data.legends and data.legends.active
	local legend = active and Legends.ById[active.id]
	panel.Visible = legend ~= nil
	if not legend then return end
	header.Text = "Legend challenge · " .. legend.name
	text.Text = legend.quest.text
	local filled = active.goal > 0 and active.progress / active.goal * SEGMENTS or 0
	for i, fill in ipairs(segments) do
		Theme.Tween(fill, { Size = UDim2.fromScale(math.clamp(filled - (i - 1), 0, 1), 1) }, Theme.Motion.Time)
	end
	footer.Text = active.progress .. " / " .. active.goal
end

ClientData.Changed:Connect(function(path)
	if path[1] == "legends" then refresh() end
end)

local function metCount()
	local data = ClientData.Get()
	local n = 0
	for _ in pairs(data.legends and data.legends.met or {}) do n += 1 end
	return n
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "LegendArrived" then
		Notify.Show(tostring(info.name) .. " is in the gym for " .. tostring(info.minutes) .. " minutes. Go say hi.")
		Audio.PlayUI("SetComplete")
	elseif kind == "LegendLeft" then
		Notify.Show(tostring(info.name) .. " left the gym.", nil, "legend")
	elseif kind == "LegendDone" then
		Notify.Show("Challenge done: " .. tostring(info.name) .. ". +" .. tostring(info.coins) .. " coins, +" .. tostring(info.dnaTokens) .. " DNA token.")
		Notify.Show("Legends met: " .. metCount() .. " / " .. #Legends.List)
		Audio.PlayUI("TitleUnlocked")
	end
end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	refresh()
end)
