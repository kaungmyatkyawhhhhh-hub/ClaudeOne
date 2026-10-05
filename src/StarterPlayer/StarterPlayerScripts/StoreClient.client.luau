-- StoreClient: the Store side button and panel (only items with ids in Config.Monetization; hidden entirely when
-- none are set, during the tutorial, and for the first minutes of every session). Purchases open only when the
-- player taps Buy. Also: the Auto Lift toggle (pass owners), the server boost pill and purchase notes.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Onboarding = require(Shared.Config.Onboarding)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Server boost pill (anyone in the server sees it)
------------------------------------------------------------------------
local pill = Theme.Panel({ Name = "ServerBoost", Size = UDim2.fromOffset(RightColumn.Width, 36), Visible = false },
	{ Theme.Pad("S"), Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
RightColumn.Add(pill, 0)
local pillIcon = New("Frame", { LayoutOrder = 1, Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, Parent = pill }, { Theme.Aspect(1, Enum.DominantAxis.Height) })
Icons.Timer(Colors.Text).Parent = pillIcon
local pillText = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Small", Size = UDim2.new(1, -30, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pill })

local started = false
task.spawn(function()
	while true do
		task.wait(1)
		local ends = ReplicatedStorage:GetAttribute("ServerBoostEnds")
		local left = type(ends) == "number" and math.max(0, ends - Workspace:GetServerTimeNow()) or 0
		pill.Visible = started and left > 0
		if left > 0 then
			pillText.Text = string.format("%dx gains %d:%02d · by %s", Monetization.Effects.ServerBoostGains, left // 60,
				math.floor(left % 60), tostring(ReplicatedStorage:GetAttribute("ServerBoostBy") or "someone"))
		end
	end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "Purchased" then
		Notify.Show("Thanks! " .. tostring(info.name) .. " is yours.")
		Audio.PlayUI("TitleUnlocked")
	elseif kind == "ServerBoost" then
		Notify.Show(tostring(info.name) .. " boosted the server: 2x gains for " .. tostring(info.minutes) .. " minutes!")
		Audio.PlayUI("SetComplete")
	elseif kind == "ShakeFridge" then
		Notify.Show("Shake Fridge: +1 Energy Shake.", nil, "fridge")
	end
end)

------------------------------------------------------------------------
-- Auto Lift toggle (only for owners)
------------------------------------------------------------------------
local autoButton = Theme.Button("Secondary", { Name = "AutoLift", Size = UDim2.fromOffset(RightColumn.Width, Theme.MinTouch), Visible = false }, {})
RightColumn.Add(autoButton, 4)
local autoLabel = Theme.Text({ Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = autoButton })
local function refreshAuto()
	local owns = player:GetAttribute("Pass_AutoLift") == true
	autoButton.Visible = started and owns
	autoLabel.Text = player:GetAttribute("AutoLiftOn") and "Auto lift: on" or "Auto lift: off"
end
autoButton.Activated:Connect(function()
	-- a local attribute: MachineClient reads it on this client only
	player:SetAttribute("AutoLiftOn", not player:GetAttribute("AutoLiftOn"))
	refreshAuto()
end)
player:GetAttributeChangedSignal("Pass_AutoLift"):Connect(refreshAuto)

------------------------------------------------------------------------
-- Store (only when something is for sale)
------------------------------------------------------------------------
if not Monetization.AnyConfigured() then
	task.spawn(function()
		ClientData.Get()
		UIBus.WaitForMenu()
		started = true
		refreshAuto()
	end)
	return
end

local gui = Theme.ScreenGui({ Name = "Store", Enabled = false, DisplayOrder = 25, Parent = player:WaitForChild("PlayerGui") })
local backdrop = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.5, Parent = gui })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 460, 1, -Spacing.L * 2), -- as tall as the screen allows (phones), up to 420
	Parent = backdrop,
}, { Theme.Pad("L"), New("UISizeConstraint", { MaxSize = Vector2.new(460, 420) }) })
local header = New("Frame", { Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = panel })
Theme.Text({ Text = "Store", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -120, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local closeButton = Theme.Button("Secondary", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 100, 1, 0), Parent = header }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local list = New("ScrollingFrame", {
	Position = UDim2.fromOffset(0, Theme.MinTouch + Spacing.M),
	Size = UDim2.new(1, 0, 1, -(Theme.MinTouch + Spacing.M)),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, { Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

local rows = {}
local function addRow(order, item, isPass)
	local row = Theme.Panel({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 64), Parent = list }, { Theme.Pad("S") })
	Theme.Text({ Text = item.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, -120, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	Theme.Text({ Text = item.text, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -120, 0, 26), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
	local buy = Theme.Button("Primary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 100, 0, Theme.MinTouch), Parent = row })
	local buyLabel = Theme.Text({ Text = "Buy", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = buy })
	buy.Activated:Connect(function()
		if isPass then
			if player:GetAttribute("Pass_" .. item.key) then return end
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	end)
	rows[item.key] = { isPass = isPass, label = buyLabel, button = buy }
end
local order = 0
for _, pass in ipairs(Monetization.Passes) do
	if pass.id then order += 1 addRow(order, pass, true) end
end
for _, product in ipairs(Monetization.Products) do
	if product.id then order += 1 addRow(order, product, false) end
end

local function refreshRows()
	for key, row in pairs(rows) do
		if row.isPass then
			local owned = player:GetAttribute("Pass_" .. key) == true
			row.label.Text = owned and "Owned" or "Buy"
			row.button.Active = not owned
		end
	end
end
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) == "Pass_" then refreshRows() refreshAuto() end
end)

local menuButton = nil
local isOpen = false
local function close()
	isOpen = false
	if menuButton then menuButton:SetActive(false) end
	local tween = Theme.Fade(backdrop, false)
	if tween then tween.Completed:Connect(function() if not isOpen then gui.Enabled = false end end) else gui.Enabled = false end
end
local function open()
	isOpen = true
	if menuButton then menuButton:SetActive(true) end
	refreshRows()
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(backdrop, true)
end
closeButton.Activated:Connect(close)

-- The Store button: after the tutorial and a few minutes of play, never before.
task.spawn(function()
	local data = ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	refreshAuto()
	local playStart = os.clock()
	while (data.onboarding.tutorialStep or Onboarding.Done) < Onboarding.Done
		or os.clock() - playStart < Monetization.StoreAfterMinutes * 60 do
		task.wait(5)
	end
	menuButton = SideMenu.Add("Store", "Store", Icons.Plate, 8)
	menuButton.Activated:Connect(function()
		if isOpen then close() else open() end
	end)
end)
