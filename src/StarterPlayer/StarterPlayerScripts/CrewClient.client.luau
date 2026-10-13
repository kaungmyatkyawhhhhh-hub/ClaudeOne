-- CrewClient: the Crew tile (two-people icon) and the Crew window (tabs My Crew / Top Crews). Without a crew: create one
-- (name + tag) and see invites; with a crew: members (n/8, who's here), invite players in this server, leave.
-- All checks, filtering and saving happen in CrewService; this only shows what it sends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Muscles = require(Shared.Config.Muscles)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local New, Colors = Theme.New, Theme.Colors
local Vertical = Enum.FillDirection.Vertical
local CREW = Social.Crew

local remote = Remotes:WaitForChild("Crew", 30)
if not remote then return end -- the crew service didn't start

local menuButton = SideMenu.Add("Crew", "Crew", Icons.People, 5)

-- the window (owner's UI v2: the same window style as the other menus): tabs My Crew / Top Crews
local pages = {}
local modal = Kit.Modal({ name = "Crew", title = "Crew", icon = "users", width = 520, height = 272, displayOrder = 24,
	tabs = { { id = "Mine", text = "My Crew", icon = "users" }, { id = "Top", text = "Top Crews", icon = "trophy" } },
	onTab = function(id)
		for name, page in pairs(pages) do page.Visible = name == id end
	end })
for _, id in ipairs({ "Mine", "Top" }) do
	pages[id] = New("ScrollingFrame", { Name = id, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = id == "Mine",
		ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
		Theme.List(Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
	})
end
local scroll = pages.Mine

------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function heading(text, parent)
	return Kit.Text({ LayoutOrder = nextOrder(), Text = text, Font = "Title", TextSize = 16, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent or scroll })
end

local function line(text, color, parent)
	return Kit.Text({ LayoutOrder = nextOrder(), Text = text, Font = "Body", TextSize = 13, TextColor3 = color or Colors.Muted, Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent or scroll })
end

local function button(text, style)
	local holder = New("Frame", { LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = scroll })
	return Kit.Button(style or "Gray", text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = holder }, { width = 220, height = 36, textSize = 15 })
end

local function textBox(placeholder, maxLength)
	local box = New("TextBox", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Colors.Well,
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = Colors.Muted,
		TextColor3 = Colors.Text,
		FontFace = Theme.Fonts.SemiBold,
		TextSize = 15,
		ClearTextOnFocus = false,
		Parent = scroll,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = Colors.Edge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > maxLength then box.Text = box.Text:sub(1, maxLength) end
	end)
	return box
end

-- a card row: an icon tile (or a player's headshot: icon = { userId = n, name = s }), text (and a smaller line under it),
-- and optionally a button on the right
local function rowCard(parent, icon: any, color: Color3, text: string, sub: string?, buttonText: string?, buttonStyle: string?, onClick: (() -> ())?)
	local card = Kit.Card({ LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 44), Parent = parent }, {})
	if type(icon) == "table" then
		Kit.Headshot(icon.userId, icon.name, 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Parent = card })
	else
		Kit.IconTile(icon, color, 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Parent = card })
	end
	Kit.Text({ Text = text, Font = "Title", TextSize = 14, Position = UDim2.fromOffset(46, sub and 4 or 0), Size = UDim2.new(1, buttonText and -150 or -56, 0, sub and 19 or 44),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	if sub then
		Kit.Text({ Text = sub, Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, buttonText and -150 or -56, 0, 15),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	end
	if buttonText and onClick then
		local b = Kit.Button(buttonStyle or "Blue", buttonText, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = card },
			{ width = 92, height = 30, textSize = 13 })
		b.Activated:Connect(onClick)
	end
	return card
end

------------------------------------------------------------------------
-- Render what the server sent
------------------------------------------------------------------------
local function clear()
	for _, page in pairs(pages) do
		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
	order = 0
end

local RANK_COLORS = { Colors.Gold, Color3.fromHex("#B8B8C4"), Color3.fromHex("#C77B3A") }
local function render(info)
	clear()
	if info.crew then
		local crew = info.crew
		heading(crew.name .. "  [" .. crew.tag .. "]")
		line(#crew.members .. " / " .. crew.max .. " members")
		for _, member in ipairs(crew.members) do
			local sub = (member.owner and "Leader · " or "") .. (member.here and "In this server · " or "") .. Muscles.FormatExp(member.score) .. " exp"
			rowCard(scroll, { userId = member.userId, name = member.name }, Colors.Card, member.name, sub)
		end
		if #crew.members < crew.max then
			heading("Invite")
			if #info.eligible == 0 then line("Nobody without a crew is in this server.") end
			for _, other in ipairs(info.eligible) do
				rowCard(scroll, { userId = other.userId, name = other.name }, Colors.Card, other.name, nil, "Invite", "Blue", function() remote:FireServer("Invite", other.userId) end)
			end
		end
		local leave = button("Leave crew", "Red")
		leave.Activated:Connect(function() remote:FireServer("Leave") end)
	else
		heading("Start a crew")
		line("Name (" .. CREW.NameLength[1] .. "-" .. CREW.NameLength[2] .. ") and tag (" .. CREW.TagLength[1] .. "-" .. CREW.TagLength[2] .. " letters)")
		local nameBox = textBox("Crew name", CREW.NameLength[2])
		local tagBox = textBox("Tag, e.g. GAIN", CREW.TagLength[2])
		local create = button(CREW.CreateCost > 0 and ("Create · " .. CREW.CreateCost .. " coins") or "Create", "Green")
		create.Activated:Connect(function() remote:FireServer("Create", nameBox.Text, tagBox.Text) end)
		if #info.invites > 0 then
			heading("Invites")
			for _, invite in ipairs(info.invites) do
				rowCard(scroll, "users", Colors.Gold, invite.name .. " [" .. invite.tag .. "]", "From " .. invite.from, "Join", "Green", function()
					remote:FireServer("Accept", invite.crewId)
				end)
			end
		end
	end
	if info.top and #info.top > 0 then
		for rank, crew in ipairs(info.top) do
			rowCard(pages.Top, "trophy", RANK_COLORS[rank] or Colors.Blue, rank .. ".  " .. crew.name .. " [" .. crew.tag .. "]",
				crew.members .. " members · " .. Muscles.FormatExp(crew.score) .. " exp")
		end
	else
		line("No crews yet. Start one!", nil, pages.Top)
	end
end

remote.OnClientEvent:Connect(function(kind, payload)
	if kind == "Info" and type(payload) == "table" then
		render(payload)
	elseif kind == "Result" and type(payload) == "string" then
		Notify.Toast(payload, nil, "users", Colors.Blue, "crew")
	end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "CrewInvite" then
		Notify.Toast("Crew invite", tostring(info.from) .. " invited you to " .. tostring(info.name) .. " [" .. tostring(info.tag) .. "]", "users", Colors.Gold)
		menuButton:SetDot(true)
		Audio.PlayUI("SetComplete")
	elseif kind == "CrewJoined" then
		Notify.Toast("New crew member", tostring(info.name) .. " joined your crew", "users", Colors.Green)
	end
end)

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function close()
	if modal.isOpen() then modal.close() end
end
local function open()
	menuButton:SetActive(true)
	menuButton:SetDot(false)
	clear()
	line("Loading...")
	modal.open()
	Audio.PlayUI("Whoosh")
	remote:FireServer("Info")
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then menuButton:SetActive(false) end
end)
UIBus.RegisterPanel("Crew", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else UIBus.PanelOpened("Crew") open() end
end)
