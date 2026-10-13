-- TrainerClient (owner's feature run, task 7B): the Trainers panel. A "Trainers" tile in the side menu opens it anywhere
-- (equip / unequip); a Trainer Desk's prompt opens it in hire mode (HIRE buttons work only there, TrainerService checks).
-- Each row: the trainer, his coach name and perk, and one button: HIRE · price / EQUIP / UNEQUIP. Slots on top.
-- The trainers themselves are drawn by TrainerFollowClient.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trainers = require(Shared.Config.Trainers)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Trainers", 60) :: RemoteEvent
if not remote then return end -- the trainer service didn't start

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors
local Vertical = Enum.FillDirection.Vertical

local menuButton = SideMenu.Add("Trainers", "Trainers", Icons.Clipboard, 7.5)

local gui = Theme.ScreenGui({ Name = "Trainers", Enabled = false, DisplayOrder = 25, Parent = player:WaitForChild("PlayerGui") })
local panel = Theme.Panel({
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = true, Parent = gui,
}, { Theme.Pad("L"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

local header = New("Frame", { Name = "Header", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = panel })
local title = Theme.Text({ Text = "Personal trainers", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -52, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
Theme.Uppercase(title)
local slotsLine = Theme.Text({ Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, -52, 0, 18), Position = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local close = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch), Parent = header }, {})
local closeIcon = New("Frame", { Size = UDim2.fromScale(0.42, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = close })
Icons.Close(Colors.Text).Parent = closeIcon
local note = Theme.Text({ Name = "Note", LayoutOrder = 1, Text = "", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local rows = {}
for order, trainer in ipairs(Trainers.List) do
	local row = New("Frame", { Name = trainer.id, LayoutOrder = 10 + order, Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Parent = panel })
	local iconSlot = New("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(0, 4), BackgroundTransparency = 1, Parent = row })
	Icons.Clipboard(Colors.Text).Parent = iconSlot
	Theme.Text({ Text = trainer.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(36, 2), TextXAlignment = Enum.TextXAlignment.Left, Upper = false, Parent = row })
	Theme.Text({ Text = trainer.coachName .. " · " .. trainer.perkText, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, TextWrapped = true,
		Size = UDim2.new(1, -170, 0, 32), Position = UDim2.fromOffset(36, 22), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
	local button = Theme.Button("Primary", { Name = "Action", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(128, Theme.MinTouch), Parent = row }, {
		Theme.Text({ Name = "Label", Text = "", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	rows[trainer.id] = { trainer = trainer, button = button, label = button:FindFirstChild("Label") :: TextLabel, action = nil }
	button.Activated:Connect(function()
		local entry = rows[trainer.id]
		if entry.action == "Hire" and (ClientData.Get().coins or 0) < trainer.price then
			Notify.Show(trainer.name .. " costs " .. trainer.price .. " coins.", Colors.NeedsWork, "trainercoins")
			return
		end
		if entry.action then remote:FireServer(entry.action, trainer.id) end
	end)
end

local isOpen = false
local atDesk = false
local openedAt = nil -- where you stood when it opened from a desk (walking away closes it)

local function state()
	local data = ClientData.Get()
	local t = type(data.trainers) == "table" and data.trainers or {}
	return type(t.owned) == "table" and t.owned or {}, type(t.equipped) == "table" and t.equipped or {}
end

local function refresh()
	-- phones (short screens): no note line and tighter spacing, so the four rows fit the height
	local compact = Theme.IsCompact()
	note.Visible = not compact
	local pad = panel:FindFirstChildOfClass("UIPadding")
	local space = compact and Theme.Spacing.M or Theme.Spacing.L
	if pad then pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, space), UDim.new(0, space), UDim.new(0, space), UDim.new(0, space) end
	local owned, equipped = state()
	local slots = Trainers.SlotsFor(player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) == true)
	slotsLine.Text = "Following you: " .. #equipped .. " / " .. slots
	note.Text = atDesk and "Hire a coach to follow you around and cheer you on. Each one has a small perk."
		or "Hire coaches at the Trainer Desk at the front of any gym."
	local coins = ClientData.Get().coins or 0
	for id, entry in pairs(rows) do
		local action, text, enabled
		if table.find(equipped, id) then
			action, text, enabled = "Unequip", "Unequip", true
		elseif table.find(owned, id) then
			action, text, enabled = "Equip", "Equip", true
		else
			action, text, enabled = "Hire", "Hire · " .. entry.trainer.price, atDesk
			if not atDesk then action = nil end
			enabled = enabled and coins >= entry.trainer.price
		end
		entry.action = action
		entry.label.Text = text
		entry.button.BackgroundTransparency = enabled and Theme.Alpha.Primary or 0.92
		entry.label.TextTransparency = enabled and 0 or 0.5
	end
end

local function setOpen(open: boolean, fromDesk: boolean?)
	if open then
		atDesk = fromDesk == true
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		openedAt = atDesk and root and root.Position or nil
		refresh()
		if isOpen then return end
		isOpen = true
		UIBus.PanelOpened("Trainers")
		menuButton:SetActive(true)
		gui.Enabled = true
		Audio.PlayUI("Whoosh")
		Theme.Fade(panel, true)
	else
		if not isOpen then return end
		isOpen = false
		atDesk = false
		menuButton:SetActive(false)
		local tween = Theme.Fade(panel, false)
		if tween then
			tween.Completed:Connect(function() if not isOpen then gui.Enabled = false end end)
		else
			gui.Enabled = false
		end
	end
end

menuButton.Activated:Connect(function() setOpen(not isOpen, false) end)
close.Activated:Connect(function() setOpen(false) end)
UIBus.RegisterPanel("Trainers", function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and isOpen then setOpen(false) end
end)
ClientData.Changed:Connect(function(path)
	if isOpen and (path[1] == "coins" or path[1] == "trainers") then refresh() end
end)
player:GetAttributeChangedSignal("Pass_" .. Trainers.ExtraSlotPass):Connect(function() if isOpen then refresh() end end)

remote.OnClientEvent:Connect(function(kind, info)
	info = type(info) == "table" and info or {}
	if kind == "Open" then
		setOpen(true, info.desk == true)
	elseif kind == "Hired" then
		local trainer = Trainers.ById[info.id]
		if trainer then
			Notify.Show(trainer.coachName .. " is your " .. string.lower(trainer.name) .. " now (" .. trainer.perkText .. ").")
			Audio.PlayUI("ShopBuy")
		end
		refresh()
	elseif kind == "Failed" then
		Notify.Show(tostring(info.text), Colors.NeedsWork, "trainerfail")
	end
end)

-- walked away from the desk: the hire mode ends (the panel closes)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 or not (isOpen and atDesk and openedAt) then return end
	acc = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - openedAt).Magnitude > Trainers.DeskDistance + 6 then setOpen(false) end
end)
