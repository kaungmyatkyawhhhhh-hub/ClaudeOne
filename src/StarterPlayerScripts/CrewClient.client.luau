-- CrewClient: the Crew side button (two-people icon) and panel. Without a crew: create one (name + tag) and see
-- invites; with a crew: members (n/8, who's here), invite players in this server, leave. Top crews at the bottom.
-- All checks, filtering and saving happen in CrewService; this only shows what it sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical = Enum.FillDirection.Vertical
local CREW = Social.Crew

local remote = Remotes:WaitForChild("Crew", 30)
if not remote then return end -- the crew service didn't start

local menuButton = SideMenu.Add("Crew", "Crew", Icons.People, 5)
local gui = Theme.ScreenGui({ Name = "Crew", Enabled = false, DisplayOrder = 24, Parent = player:WaitForChild("PlayerGui") })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, Spacing.L + 64 + Spacing.M, 0.5, 0),
	Size = UDim2.fromOffset(320, 420),
	Parent = gui,
}, { Theme.Pad("M") })
local scroll = New("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, { Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function heading(text)
	return Theme.Text({ LayoutOrder = nextOrder(), Text = text, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -8, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll })
end

local function line(text, color)
	return Theme.Text({ LayoutOrder = nextOrder(), Text = text, Font = "Regular", TextSize = "Small", TextColor3 = color or Colors.Muted, Size = UDim2.new(1, -8, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = scroll })
end

local function button(text, style, width, parent)
	local b = Theme.Button(style or "Secondary", { LayoutOrder = nextOrder(), Size = UDim2.new(width or 1, width and 0 or -8, 0, Theme.MinTouch), Parent = parent or scroll })
	Theme.Text({ Text = text, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = b })
	return b
end

local function textBox(placeholder, maxLength)
	local box = New("TextBox", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, Theme.MinTouch),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = Colors.Muted,
		TextColor3 = Colors.Text,
		FontFace = Theme.Fonts.Regular,
		TextSize = Theme.TextSize.Body,
		ClearTextOnFocus = false,
		Parent = scroll,
	}, { Theme.Round("Button"), Theme.Stroke(), New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.M), PaddingRight = UDim.new(0, Spacing.M) }) })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > maxLength then box.Text = box.Text:sub(1, maxLength) end
	end)
	return box
end

-- a row: text on the left, a small button on the right
local function rowWithButton(text, buttonText, onClick)
	local row = New("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = scroll })
	Theme.Text({ Text = text, Font = "Regular", TextSize = "Body", Size = UDim2.new(1, -110, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local b = Theme.Button("Secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 100, 0, Theme.MinTouch - 4), Parent = row })
	Theme.Text({ Text = buttonText, Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(1, 1), Parent = b })
	b.Activated:Connect(onClick)
	return row
end

------------------------------------------------------------------------
-- Render what the server sent
------------------------------------------------------------------------
local function clear()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	order = 0
end

local function render(info)
	clear()
	if info.crew then
		local crew = info.crew
		heading(crew.name .. "  [" .. crew.tag .. "]")
		line(#crew.members .. " / " .. crew.max .. " members")
		for _, member in ipairs(crew.members) do
			line(member.name .. (member.owner and "  · leader" or "") .. (member.here and "  · here" or "") .. "   " .. member.score, member.here and Colors.Text or Colors.Muted)
		end
		if #crew.members < crew.max then
			heading("Invite")
			if #info.eligible == 0 then line("Nobody without a crew is in this server.") end
			for _, other in ipairs(info.eligible) do
				rowWithButton(other.name, "Invite", function() remote:FireServer("Invite", other.userId) end)
			end
		end
		local leave = button("Leave crew")
		leave.Activated:Connect(function() remote:FireServer("Leave") end)
	else
		heading("Start a crew")
		line("Name (" .. CREW.NameLength[1] .. "-" .. CREW.NameLength[2] .. ") and tag (" .. CREW.TagLength[1] .. "-" .. CREW.TagLength[2] .. " letters)")
		local nameBox = textBox("Crew name", CREW.NameLength[2])
		local tagBox = textBox("Tag, e.g. GAIN", CREW.TagLength[2])
		local create = button(CREW.CreateCost > 0 and ("Create · " .. CREW.CreateCost .. " coins") or "Create", "Primary")
		create.Activated:Connect(function() remote:FireServer("Create", nameBox.Text, tagBox.Text) end)
		if #info.invites > 0 then
			heading("Invites")
			for _, invite in ipairs(info.invites) do
				rowWithButton(invite.name .. " [" .. invite.tag .. "] from " .. invite.from, "Join", function()
					remote:FireServer("Accept", invite.crewId)
				end)
			end
		end
	end
	if info.top and #info.top > 0 then
		heading("Top crews")
		for rank, crew in ipairs(info.top) do
			line(rank .. ".  " .. crew.name .. " [" .. crew.tag .. "]  ·  " .. crew.members .. " members  ·  " .. crew.score)
		end
	end
end

remote.OnClientEvent:Connect(function(kind, payload)
	if kind == "Info" and type(payload) == "table" then
		render(payload)
	elseif kind == "Result" and type(payload) == "string" then
		Notify.Show(payload, nil, "crew")
	end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "CrewInvite" then
		Notify.Show(tostring(info.from) .. " invited you to " .. tostring(info.name) .. " [" .. tostring(info.tag) .. "]. Open Crew to join.")
		menuButton:SetDot(true)
		Audio.PlayUI("SetComplete")
	elseif kind == "CrewJoined" then
		Notify.Show(tostring(info.name) .. " joined your crew.")
	end
end)

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local isOpen = false
local function close()
	isOpen = false
	menuButton:SetActive(false)
	local tween = Theme.Fade(panel, false)
	if tween then tween.Completed:Connect(function() if not isOpen then gui.Enabled = false end end) else gui.Enabled = false end
end
local function open()
	isOpen = true
	menuButton:SetActive(true)
	menuButton:SetDot(false)
	clear()
	line("Loading...")
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(panel, true)
	remote:FireServer("Info")
end
menuButton.Activated:Connect(function()
	if isOpen then close() else open() end
end)

