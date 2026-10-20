-- BoostsPanel (owner, prompt 14, 21 Oct): the Inventory window's BOOSTS tab (TitlesClient builds the window and calls this).
-- Left: a grid of the boost items you own (Config.Boosts): icon tile, name, "x3"; items you have 0 of are hidden. Right:
-- the picked item: icon, name, what it does, how long, the time still running, and two buttons:
--   USE    uses one now (ItemService: the drink + its boost)
--   EQUIP  puts it in your backpack as a Tool (the Roblox hotbar; activating the Tool uses one). "UNEQUIP" takes it out.
-- BoostsPanel.Build(parent) -> { frame, refresh(), pick(id?) }. Placeholder icons: Config/UI icons in the item's color.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Audio = require(script.Parent.Parent.Audio)
local Boosts = require(script.Parent.Parent.Config.Boosts)
local ClientData = require(script.Parent.Parent.ClientData)

local New, Colors = Theme.New, Theme.Colors

local BoostsPanel = {}

local CELL = Vector2.new(100, 88)
local DETAIL_W = 206
local PAD = 8

function BoostsPanel.Build(parent: Instance)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local panel = { picked = nil }
	local frame = New("Frame", { Name = "Boosts", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	panel.frame = frame

	local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -(DETAIL_W + 10), 1, 0),
		ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = frame }, {
		New("UIGridLayout", { CellSize = UDim2.fromOffset(CELL.X, CELL.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
	})
	local empty = Kit.Text({ Name = "Empty", Text = "No boosts yet. Daily rewards, quests and the shake machine give them.", Font = "Body", TextSize = 13,
		TextColor3 = Colors.Faint, TextWrapped = true, Size = UDim2.new(1, -(DETAIL_W + 14), 0, 40), TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false, Parent = frame })

	-- the picked item
	local detail = Kit.Card({ Name = "Detail", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, DETAIL_W, 1, 0), Parent = frame }, {})
	local tileHolder = New("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, PAD), Size = UDim2.fromOffset(40, 40), Parent = detail })
	local name = Kit.Fit(Kit.Text({ Name = "Name", Text = "", Font = "Title", Position = UDim2.fromOffset(PAD + 48, PAD), Size = UDim2.new(1, -(2 * PAD + 48), 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = detail }), 16, 10)
	local owned = Kit.GoldText(Kit.Text({ Name = "Owned", Text = "", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(PAD + 48, PAD + 22),
		Size = UDim2.new(1, -(2 * PAD + 48), 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = detail }))
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 12, TextWrapped = true, Position = UDim2.fromOffset(PAD, 54),
		Size = UDim2.new(1, -2 * PAD, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
	local duration = Kit.Text({ Name = "Duration", Text = "", Font = "Strong", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(PAD, 88),
		Size = UDim2.new(1, -2 * PAD, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	local half = (DETAIL_W - 3 * PAD) / 2
	local useButton = Kit.Button("Green", "Use", { Name = "Use", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, PAD, 1, -PAD), Parent = detail },
		{ width = half, height = 40, textSize = 15 })
	local equipButton = Kit.Button("Quiet", "Equip", { Name = "Equip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -PAD, 1, -PAD), Parent = detail },
		{ width = half, height = 40, textSize = 14 })

	local cards = {}
	for order, item in ipairs(Boosts.Items) do
		local color = Color3.fromHex(item.color)
		local card = Kit.Card({ Name = item.id, LayoutOrder = order, Clickable = true, Visible = false, Parent = grid }, {})
		Kit.IconTile(item.icon, color, 38, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7), Parent = card })
		Kit.Fit(Kit.Text({ Name = "Name", Text = item.name, Font = "Title", Position = UDim2.fromOffset(4, 48), Size = UDim2.new(1, -8, 0, 16), Parent = card }), 13, 9)
		local count = Kit.GoldText(Kit.Text({ Name = "Count", Text = "x0", Font = "Number", TextSize = 13, Position = UDim2.fromOffset(4, 66), Size = UDim2.new(1, -8, 0, 16),
			Parent = card }))
		card.Activated:Connect(function()
			Audio.PlayUI("Click")
			panel.pick(item.id)
		end)
		cards[item.id] = { card = card, count = count }
	end

	local function countOf(id: string): number
		local items = ClientData.Get().items
		return items and tonumber(items[id]) or 0
	end

	function panel.refresh()
		local any = nil
		for _, item in ipairs(Boosts.Items) do
			local n = countOf(item.id)
			local c = cards[item.id]
			c.card.Visible = n > 0
			c.count.Text = "x" .. Kit.Format(n)
			Theme.SetPiece(c.card, if panel.picked == item.id then "card_gold" else "card")
			if n > 0 and not any then any = item.id end
		end
		empty.Visible = any == nil
		-- the picked one ran out (or nothing picked yet): the first one you have
		if not panel.picked or (countOf(panel.picked) <= 0 and not player:GetAttribute("Equipped_" .. panel.picked)) then
			panel.picked = any
		end
		detail.Visible = panel.picked ~= nil
		local item = panel.picked and Boosts.ById[panel.picked]
		if not item then return end
		for _, child in ipairs(tileHolder:GetChildren()) do child:Destroy() end
		Kit.IconTile(item.icon, Color3.fromHex(item.color), 40, { Parent = tileHolder })
		name.Text = item.name
		local n = countOf(item.id)
		owned.Text = "You have " .. Kit.Format(n)
		text.Text = item.text
		local ends = player:GetAttribute("Item_" .. item.id)
		local left = if type(ends) == "number" then ends - Workspace:GetServerTimeNow() else 0
		duration.Text = (if item.shake then "Lasts " .. item.duration .. " (stacks to 90 s)" else item.duration .. " per use, up to 60 min")
			.. (if left > 0 then " · " .. Boosts.Clock(left) .. " left" else "")
		Kit.SetButton(useButton, if n > 0 then "Green" else "Disabled", "Use")
		Kit.SetButton(equipButton, if n > 0 or player:GetAttribute("Equipped_" .. item.id) then "Quiet" else "Disabled",
			if player:GetAttribute("Equipped_" .. item.id) then "Unequip" else "Equip")
	end

	function panel.pick(id: string?)
		panel.picked = id
		panel.refresh()
	end

	useButton.Activated:Connect(function()
		local id = panel.picked
		if not id or countOf(id) <= 0 then return end
		remotes.PlayerAction:FireServer(if id == "Shake" then "DrinkShake" else "UseItem", id)
	end)
	equipButton.Activated:Connect(function()
		local id = panel.picked
		if not id then return end
		Audio.PlayUI("Click")
		remotes.PlayerAction:FireServer("EquipItem", id)
	end)
	player.AttributeChanged:Connect(function(attribute)
		if frame.Visible and (string.sub(attribute, 1, 5) == "Item_" or string.sub(attribute, 1, 9) == "Equipped_") then panel.refresh() end
	end)
	return panel
end

return BoostsPanel
