-- CrewClient: the Crew tile (two-people icon) and the Crew window (tabs My Crew / Top Crews). Without a crew: create one
-- (name + tag) and see invites; with a crew: members (n/8, who's here), invite players in this server, leave.
-- All checks, filtering and saving happen in CrewService; this only shows what it sends.
-- One crew view (owner, 15 Oct: "the same member view as MY CREW, not a second version"): crewHeader + memberRow show
-- MY CREW and a top crew alike (name, tag, rank, score, n / max; each member's headshot with an online dot, name, role,
-- level, height and score; leader first, then by score). Tapping a row in TOP CREWS opens that crew read-only over the
-- list (a back arrow returns to the list where it was scrolled); your own crew opens MY CREW instead. The view is asked
-- from the server ("View") and kept 60 s; meanwhile shimmer rows show. Its button: JOIN (open crews), REQUEST TO JOIN,
-- REQUESTED, FULL or IN A CREW (greyed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
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
local VIEW_CACHE = 60 -- seconds a top crew's members are kept on this device

local remote = Remotes:WaitForChild("Crew", 30)
if not remote then return end -- the crew service didn't start

local menuButton = SideMenu.Add("Crew", "Crew", Icons.People, 5)

-- the window (owner's UI v2: the same window style as the other menus): tabs My Crew / Top Crews
local pages = {}
local currentTab = "Mine"
local viewing = nil -- crewId of the top crew shown over the Top Crews list
local viewingEntry = nil -- its Top Crews row ({ name, tag, score, members })
local showTab
local modal = Kit.Modal({ name = "Crew", title = "Crew", icon = "users", width = 520, height = 272, displayOrder = 24,
	tabs = { { id = "Mine", text = "My Crew", icon = "users" }, { id = "Top", text = "Top Crews", icon = "trophy" } },
	onTab = function(id)
		viewing = nil -- (a tab tap goes back to that tab's own page)
		showTab(id)
	end })
for _, id in ipairs({ "Mine", "Top", "View" }) do
	pages[id] = New("ScrollingFrame", { Name = id, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = id == "Mine",
		ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = modal.body }, {
		Theme.List(Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
	})
end
local scroll = pages.Mine
function showTab(id)
	currentTab = id
	pages.Mine.Visible = id == "Mine"
	pages.Top.Visible = id == "Top" and viewing == nil
	pages.View.Visible = id == "Top" and viewing ~= nil
end

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
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent or scroll })
end

local function line(text, color, parent)
	return Kit.Text({ LayoutOrder = nextOrder(), Text = text, Font = "Body", TextSize = 13, TextColor3 = color or Colors.Muted, Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent or scroll })
end

local function button(text, style, parent)
	local holder = New("Frame", { LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = parent or scroll })
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
-- (26 Oct, retention) INVITE FRIENDS: Roblox's invite prompt; friends in your server give the Friend Boost (FriendService)
local function inviteFriendsRow(parent)
	local friendCfg = Social.Friends
	local percent = math.floor(friendCfg.GainsPer * 100 + 0.5)
	rowCard(parent, "users", Colors.Green, "Invite friends", "Every friend here: +" .. percent .. "% gains (up to +" .. percent * friendCfg.Max .. "%)", "Invite", "Green", function()
		UIBus.InviteFriends:Fire() -- (FriendClient: with the invite-boost launch data)
	end)
end

------------------------------------------------------------------------
-- The crew view (shared by MY CREW and a top crew)
------------------------------------------------------------------------
local ROLE_COLORS = { Leader = Colors.Gold, Officer = Color3.fromHex("#7FB6FF"), Member = Colors.Muted }

-- name [TAG], then "#2 · 1.2M score · 8 / 8 members"; onBack: a back arrow on the left
local function crewHeader(parent, crew, onBack: (() -> ())?)
	local card = Kit.Card({ Name = "CrewHeader", LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 50), Parent = parent }, {})
	local left = 10
	if onBack then
		local back = Kit.Button("Quiet", "", { Name = "Back", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = card },
			{ width = 44, height = 36, icon = "chevron-left" })
		back.Activated:Connect(function()
			Audio.PlayUI("Click")
			onBack()
		end)
		left = 60
	end
	local rankWidth = crew.rank and 44 or 0
	if crew.rank then
		Kit.Tag("#" .. crew.rank, crew.rank == 1 and Colors.Gold or Colors.Text, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(0, 22), Parent = card })
	end
	Kit.Text({ Name = "Name", Text = (crew.name or "?") .. "  [" .. (crew.tag or "") .. "]", Font = "Title", TextSize = 16, Position = UDim2.fromOffset(left, 6),
		Size = UDim2.new(1, -left - 12 - rankWidth, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local bits = {}
	if crew.score then table.insert(bits, Muscles.FormatExp(crew.score) .. " score") end
	table.insert(bits, #crew.members .. " / " .. (crew.max or CREW.MaxMembers) .. " members")
	if crew.rank then table.insert(bits, 1, "Rank #" .. crew.rank) end
	Kit.Text({ Name = "Sub", Text = table.concat(bits, "  ·  "), Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(left, 28),
		Size = UDim2.new(1, -left - 12 - rankWidth, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	return card
end

-- (owner, 24 Oct) the leader's KICK button on a member row: one tap turns it into a red "Sure?" for 3 s, a second tap kicks
local KICK_W = 64
local function kickButton(card, member)
	local current
	local function make(text, style, onClick)
		current = Kit.Button(style, text, { Name = "Kick", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -88, 0.5, 0), Parent = card },
			{ width = KICK_W, height = 28, textSize = 12 })
		current.Activated:Connect(onClick)
	end
	local function ask()
		Audio.PlayUI("Click")
		current:Destroy()
		make("Sure?", "Red", function()
			current.Active = false
			remote:FireServer("Kick", member.userId)
		end)
		local sure = current
		task.delay(3, function()
			if current == sure and sure.Parent then
				sure:Destroy()
				make("Kick", "Quiet", ask)
			end
		end)
	end
	make("Kick", "Quiet", ask)
end

-- one member: headshot + online dot, name, "Leader · LVL 45 · 6'0" · In this server", score on the right; canKick: the
-- leader's KICK button (MY CREW only)
local function memberRow(parent, member, canKick: boolean?)
	local card = Kit.Card({ Name = "Member", LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 46), Parent = parent }, {})
	local face = Kit.Headshot(member.userId, member.name, 32, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Parent = card })
	New("Frame", { Name = "Online", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1.05, 1.05), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = member.online and Colors.Green or Color3.fromHex("#4A4448"), ZIndex = 3, Parent = face }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Card, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local scoreW = 74
	local kickW = canKick and (KICK_W + 10) or 0
	Kit.Text({ Name = "PlayerName", Text = member.name or "?", Font = "Title", TextSize = 14, Position = UDim2.fromOffset(48, 5), Size = UDim2.new(1, -48 - scoreW - 8 - kickW, 0, 19),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local role = member.role or "Member"
	local color = ROLE_COLORS[role] or Colors.Muted
	local bits = { string.format('<font color="#%s">%s</font>', color:ToHex(), role) }
	if member.level then table.insert(bits, "LVL " .. member.level) end
	table.insert(bits, GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(member.spurts or 0), true))
	if member.here then table.insert(bits, "In this server") end
	Kit.Text({ Name = "Sub", Text = table.concat(bits, "  ·  "), RichText = true, Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(48, 25),
		Size = UDim2.new(1, -48 - scoreW - 8 - kickW, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	if canKick then kickButton(card, member) end
	Kit.Text({ Name = "Score", Text = Muscles.FormatExp(member.score or 0), Font = "Number", TextSize = 15, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(scoreW, 19), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
	Kit.Text({ Name = "ScoreLabel", Text = "score", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 26), Size = UDim2.fromOffset(scoreW, 13), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
	return card
end

local function crewMembers(parent, crew, onBack)
	crewHeader(parent, crew, onBack)
	-- (the leader can kick everyone but themselves, only in MY CREW)
	for _, member in ipairs(crew.members) do memberRow(parent, member, crew.leader == true and member.role ~= "Leader") end
end

-- loading rows: the row's shape in dark blocks with a soft light sweeping across (one tween per row, stopped on clear)
local shimmerTweens = {}
local function shimmerRow(parent)
	local card = Kit.Card({ Name = "Loading", LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 46), ClipsDescendants = true, Parent = parent }, {})
	New("Frame", { BackgroundColor3 = Colors.Well, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(32, 32), Parent = card },
		{ New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	for _, bar in ipairs({ { 48, 9, 0.38 }, { 48, 28, 0.24 } }) do
		New("Frame", { BackgroundColor3 = Colors.Well, Position = UDim2.fromOffset(bar[1], bar[2]), Size = UDim2.new(bar[3], 0, 0, 9), Parent = card },
			{ New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	end
	local sweep = New("Frame", { Name = "Sweep", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 4, Parent = card })
	local gradient = New("UIGradient", { Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = sweep })
	local tween = TweenService:Create(gradient, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) })
	tween:Play()
	table.insert(shimmerTweens, tween)
end

------------------------------------------------------------------------
-- Render what the server sent
------------------------------------------------------------------------
local function clearPage(page)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	if page == pages.View then
		for _, tween in ipairs(shimmerTweens) do tween:Cancel() end
		table.clear(shimmerTweens)
	end
end
local function clear()
	clearPage(pages.Mine)
	clearPage(pages.Top)
	order = 0
end

local myCrewId = nil
local viewCache = {} -- [crewId] = { at = os.clock(), view = view }
local openCrew -- (below)

local RANK_COLORS = { Colors.Gold, Color3.fromHex("#B8B8C4"), Color3.fromHex("#C77B3A") }
local function render(info)
	local topScroll = pages.Top.CanvasPosition -- (kept: the list stays where it was scrolled)
	clear()
	myCrewId = info.crew and info.crew.crewId or nil
	if info.crew then
		local crew = info.crew
		crewMembers(scroll, crew, nil)
		-- join requests (leader / officers)
		if crew.manage and crew.requests and #crew.requests > 0 then
			heading("Join requests (" .. #crew.requests .. ")")
			for _, request in ipairs(crew.requests) do
				local card = rowCard(scroll, { userId = request.userId, name = request.name }, Colors.Card, request.name, "Wants to join", "Accept", "Green", function()
					remote:FireServer("AnswerRequest", request.userId, true)
				end)
				local no = Kit.Button("Quiet", "", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -106, 0.5, 0), Parent = card },
					{ width = 34, height = 30, icon = "x" })
				no.Activated:Connect(function() remote:FireServer("AnswerRequest", request.userId, false) end)
			end
		end
		-- who can join from Top Crews (the leader picks)
		if crew.leader then
			local open = crew.joinMode == "open"
			rowCard(scroll, "users", Colors.Blue, "Who can join", open and "Anyone can join from Top Crews" or "Players send a request you accept",
				open and "Open" or "Requests", "Quiet", function()
					remote:FireServer("SetJoinMode", open and "request" or "open")
				end)
		end
		if #crew.members < crew.max then
			heading("Invite")
			if #info.eligible == 0 then line("Nobody without a crew is in this server.") end
			for _, other in ipairs(info.eligible) do
				rowCard(scroll, { userId = other.userId, name = other.name }, Colors.Card, other.name, nil, "Invite", "Blue", function() remote:FireServer("Invite", other.userId) end)
			end
		end
		inviteFriendsRow(scroll)
		local leave = button("Leave crew", "Red")
		leave.Activated:Connect(function() remote:FireServer("Leave") end)
	else
		inviteFriendsRow(scroll)
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
			local card = rowCard(pages.Top, "trophy", RANK_COLORS[rank] or Colors.Blue, rank .. ".  " .. crew.name .. " [" .. crew.tag .. "]",
				crew.members .. " / " .. CREW.MaxMembers .. " members · " .. Muscles.FormatExp(crew.score) .. " score" .. (crew.crewId == myCrewId and " · your crew" or ""))
			card.Name = "TopCrew" .. rank
			-- the whole row is the button (the chevron says so)
			local go = require(Shared.UI.Pieces).Icon("chevron-left", Colors.Muted, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(14, 14), Rotation = 180, Parent = card })
			go:SetAttribute("KeepColor", true)
			local hit = New("TextButton", { Name = "Open", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
			hit.Activated:Connect(function()
				if crew.crewId then
					Audio.PlayUI("Click")
					openCrew(crew.crewId, rank, crew)
				end
			end)
		end
	else
		line("No crews yet. Start one!", nil, pages.Top)
	end
	task.defer(function() pages.Top.CanvasPosition = topScroll end)
end

-- the top crew's view (over the Top Crews list)
local function backToList()
	viewing = nil
	showTab("Top")
end

local function renderView(view, rank)
	clearPage(pages.View)
	if view.gone then
		-- (its name and tag from the Top Crews row that was tapped)
		local entry = viewingEntry or {}
		crewHeader(pages.View, { name = entry.name or "Crew", tag = entry.tag or "-", members = {}, max = CREW.MaxMembers }, backToList)
		line("This crew no longer exists.", Colors.Text, pages.View)
		return
	end
	view.rank = view.rank or rank
	crewMembers(pages.View, view, backToList)
	-- the button (no management here: that's MY CREW)
	local full = #view.members >= (view.max or CREW.MaxMembers)
	local text, style, enabled
	if view.mine then
		text, style, enabled = "Your crew", "Disabled", false
	elseif view.inCrew then
		text, style, enabled = "In a crew", "Disabled", false
	elseif full then
		text, style, enabled = "Full", "Disabled", false
	elseif view.requested then
		text, style, enabled = "Requested", "Disabled", false
	elseif view.joinMode == "open" then
		text, style, enabled = "Join", "Gold", true
	else
		text, style, enabled = "Request to join", "Red", true
	end
	local join = button(text, style, pages.View)
	join.Name = "Join"
	join.Activated:Connect(function()
		if not enabled then return end
		enabled = false
		Kit.SetButton(join, "Disabled", "...")
		viewCache[view.crewId] = nil
		remote:FireServer("Request", view.crewId)
	end)
end

function openCrew(crewId: string, rank: number?, entry)
	if crewId == myCrewId then -- (your own crew: MY CREW)
		viewing = nil
		modal.selectTab("Mine")
		showTab("Mine")
		return
	end
	viewing = crewId
	viewingEntry = entry
	showTab("Top")
	pages.View.CanvasPosition = Vector2.zero
	local cached = viewCache[crewId]
	if cached and os.clock() - cached.at < VIEW_CACHE then
		renderView(cached.view, rank)
		return
	end
	-- shimmer while the server reads it: the header from the list row, then loading rows
	clearPage(pages.View)
	crewHeader(pages.View, { name = entry and entry.name or "Crew", tag = entry and entry.tag or "", rank = rank, score = entry and entry.score,
		members = table.create(entry and entry.members or 0, {}), max = CREW.MaxMembers }, backToList)
	for _ = 1, math.clamp(entry and entry.members or 4, 1, 5) do shimmerRow(pages.View) end
	pages.View:SetAttribute("Rank", rank)
	remote:FireServer("View", crewId)
end

remote.OnClientEvent:Connect(function(kind, payload)
	if kind == "Info" and type(payload) == "table" then
		render(payload)
	elseif kind == "View" and type(payload) == "table" and type(payload.crewId) == "string" then
		if not payload.gone then viewCache[payload.crewId] = { at = os.clock(), view = payload } end
		if viewing == payload.crewId then renderView(payload, pages.View:GetAttribute("Rank")) end
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
	elseif kind == "CrewRequest" then
		Notify.Toast("Join request", tostring(info.name) .. " wants to join your crew", "users", Colors.Gold)
		menuButton:SetDot(true)
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
	if not modal.isOpen() then
		menuButton:SetActive(false)
		viewing = nil
		showTab(currentTab)
	end
end)
UIBus.RegisterPanel("Crew", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else UIBus.PanelOpened("Crew") open() end
end)
