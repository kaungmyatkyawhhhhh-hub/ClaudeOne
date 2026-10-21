-- TrainersPanel (prompt 24, 21 Oct): the TRAINERS window's MY TRAINERS tab (prompt 28; it was the Inventory's Trainers tab;
-- TrainerClient builds the window and calls this).
-- On top the following slots (1 at start, 2 at Growth Spurt 2, 3 at the first alter, +1 with the pass; a locked slot says
-- what opens it): each shows the trainer in it (rarity color, name; Golden in gold), tap = he stops following.
-- Below every trainer you own (rarest first; Golden ones as their own cards): a 3D portrait, name, rarity, boost, how many
-- ("x3"), EQUIP (into the first free slot, or the last slot when all are full; duplicates can fill several slots) and
-- "3/5 to Golden" or MAKE GOLDEN (5 of the same -> 1 Golden with 1.5x his boost). Nothing yet: a button to the Agency.
-- TrainersPanel.Build(parent) -> { frame, refresh() }. Every change goes to the server (remote "Trainers").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)
local TrainerPortrait = require(script.Parent.TrainerPortrait)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)
local Trainers = require(script.Parent.Parent.Config.Trainers)

local New, Colors = Theme.New, Theme.Colors

local TrainersPanel = {}

local CARD = Vector2.new(160, 128)
local SLOT = Vector2.new(126, 44)

local function hex(c) return Color3.fromHex(c) end

function TrainersPanel.Build(parent: Instance)
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trainers", 30)
	local panel = {}
	local holder = New("Frame", { Name = "Trainers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local top = New("Frame", { Name = "Slots", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, SLOT.Y), Parent = holder }, {
		Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	Kit.Text({ Name = "Label", LayoutOrder = 0, Text = "FOLLOWING", Font = "Title", TextSize = 12, Size = UDim2.fromOffset(76, SLOT.Y),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, SLOT.Y + 6),
		Size = UDim2.new(1, 0, 1, -(SLOT.Y + 6)), ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = holder }, {
		New("UIGridLayout", { CellSize = UDim2.fromOffset(CARD.X, CARD.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
	})
	local empty = New("Frame", { Name = "Empty", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, SLOT.Y + 10), Size = UDim2.new(1, 0, 0, 90), Visible = false,
		Parent = holder })
	Kit.Text({ Text = "No trainers yet. Roll for one at the Trainer Agency (the desk at the front of each gym).", Font = "Strong", TextSize = 13, TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36), Parent = empty })
	local openAgency = Kit.Button("Gold", "Roll trainers", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 42), Parent = empty },
		{ width = 200, height = 44, textSize = 15 })
	openAgency.Activated:Connect(function()
		Audio.PlayUI("Click")
		UIBus.OpenAgency:Fire()
	end)

	local function state() return Trainers.Migrate((ClientData.Get() or {}).trainers) end
	local function following(): { string }
		local list = {}
		local value = player:GetAttribute("Trainers")
		if type(value) == "string" then for entry in string.gmatch(value, "[^,]+") do table.insert(list, entry) end end
		return list
	end
	local function slots(): number return player:GetAttribute("TrainerSlots") or 1 end
	-- what opens slot n (for the locked ones)
	local function unlockText(n: number): string
		for _, step in ipairs(Trainers.SlotSteps) do
			if step.slots == n then
				if step.spurts then return "Growth Spurt " .. step.spurts end
				if step.alter then return "Body Alter " .. step.alter end
			end
		end
		return "+1 slot pass"
	end

	local function clear(frame)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") and child.Name ~= "Label" then child:Destroy() end
		end
	end

	function panel.refresh()
		local s = state()
		local list = following()
		local n = slots()
		-- the slots
		clear(top)
		for i = 1, Trainers.MaxSlots do
			local entry = list[i]
			local id, golden = Trainers.ParseEntry(entry or "")
			local trainer = id and Trainers.ById[id]
			local box = New("TextButton", { Name = "Slot" .. i, LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#1C1C21"),
				Size = UDim2.fromOffset(SLOT.X, SLOT.Y), Parent = top }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
			local stroke = New("UIStroke", { Thickness = 2, Color = Color3.fromHex("#3A3A42"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
			if trainer then
				local rarity = Trainers.RarityById[trainer.rarity]
				stroke.Color = if golden then Colors.Gold elseif rarity.hidden then hex(rarity.color2 or rarity.color) else hex(rarity.color)
				Kit.Text({ Text = (if golden then "Golden " else "") .. trainer.name, Font = "Strong", TextSize = 11, Position = UDim2.fromOffset(6, 4),
					Size = UDim2.new(1, -12, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
				Kit.Text({ Text = "Tap to remove", Font = "Body", TextSize = 9, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(6, 22), Size = UDim2.new(1, -12, 0, 14),
					Parent = box })
				box.Activated:Connect(function()
					Audio.PlayUI("Click")
					remote:FireServer("Unequip", i)
				end)
			elseif i <= n then
				Kit.Text({ Text = "Empty slot", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 1), Parent = box })
			else
				box.BackgroundTransparency = 0.5
				Kit.Text({ Text = "Locked\n" .. unlockText(i), Font = "Body", TextSize = 10, TextColor3 = Colors.Faint, Size = UDim2.fromScale(1, 1), TextWrapped = true,
					Parent = box })
			end
		end
		-- the owned trainers, rarest first; Golden ones as their own cards
		clear(grid)
		local cards = {}
		for _, trainer in ipairs(Trainers.List) do
			if (s.golden[trainer.id] or 0) > 0 then table.insert(cards, { trainer = trainer, golden = true, count = s.golden[trainer.id] }) end
			if (s.owned[trainer.id] or 0) > 0 then table.insert(cards, { trainer = trainer, golden = false, count = s.owned[trainer.id] }) end
		end
		table.sort(cards, function(a, b)
			if a.trainer.index ~= b.trainer.index then return a.trainer.index > b.trainer.index end
			return a.golden and not b.golden
		end)
		empty.Visible = #cards == 0
		grid.Visible = #cards > 0
		local used = {}
		for _, entry in ipairs(list) do used[entry] = (used[entry] or 0) + 1 end
		for order, c in ipairs(cards) do
			local trainer = c.trainer
			local rarity = Trainers.RarityById[trainer.rarity]
			local color = if c.golden then Colors.Gold elseif rarity.hidden then hex(rarity.color2 or rarity.color) else hex(rarity.color)
			local card = Kit.Card({ Name = trainer.id .. (if c.golden then "_Golden" else ""), LayoutOrder = order, Parent = grid }, {})
			New("UIStroke", { Name = "Rarity", Color = color, Thickness = if c.golden then 2.5 else 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
			local box = New("Frame", { Name = "PortraitBox", BackgroundColor3 = Color3.fromHex("#141417"), Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(46, 46),
				ClipsDescendants = true, Parent = card }, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
			TrainerPortrait.Icon(trainer.id, { Size = UDim2.fromScale(1, 1), golden = c.golden, Parent = box })
			Kit.Text({ Text = (if c.golden then "GOLDEN " else "") .. string.upper(rarity.name), Font = "Title", TextSize = 10, TextColor3 = color,
				Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -64, 0, 13), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			Kit.Text({ Text = trainer.name .. "  x" .. c.count, Font = "Strong", TextSize = 12, Position = UDim2.fromOffset(58, 20), Size = UDim2.new(1, -64, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
			Kit.Text({ Text = Trainers.PerkText(trainer, c.golden), Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(6, 56),
				Size = UDim2.new(1, -12, 0, 26), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
			-- EQUIP (the first free slot, or the last one) unless all of him already follow you
			local key = Trainers.Entry(trainer.id, c.golden)
			local canEquip = (used[key] or 0) < c.count
			local equip = Kit.Button(if canEquip then "Green" else "Quiet", if canEquip then "Equip" else "Following", { Name = "Equip", AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 6, 1, -6), Parent = card }, { width = 70, height = 34, textSize = 12 })
			equip.Activated:Connect(function()
				if not canEquip then return end
				Audio.PlayUI("Click")
				local slot = math.min(#list + 1, n)
				remote:FireServer("Equip", slot, key)
			end)
			if not c.golden then
				if c.count >= Trainers.GoldenCount then
					local make = Kit.Button("Gold", "Make Golden", { Name = "Golden", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Parent = card },
						{ width = 72, height = 34, textSize = 10 })
					make.Activated:Connect(function()
						Audio.PlayUI("Click")
						remote:FireServer("Golden", trainer.id)
					end)
				else
					Kit.Text({ Text = c.count .. "/" .. Trainers.GoldenCount .. " to Golden", Font = "Number", TextSize = 10, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -6, 1, -14), Size = UDim2.fromOffset(74, 16), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
				end
			end
		end
	end

	-- live: a roll, an equip, a new slot
	ClientData.Changed:Connect(function(path)
		if holder.Visible and path[1] == "trainers" then panel.refresh() end
	end)
	player:GetAttributeChangedSignal("Trainers"):Connect(function() if holder.Visible then panel.refresh() end end)
	player:GetAttributeChangedSignal("TrainerSlots"):Connect(function() if holder.Visible then panel.refresh() end end)

	panel.frame = holder
	return panel
end

return TrainersPanel
