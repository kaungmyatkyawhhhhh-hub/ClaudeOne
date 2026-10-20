-- AltersPanel (prompt 21, 21 Oct): the Inventory window's ALTERS tab (TitlesClient builds the window and calls this).
-- Every Body Alter (Config.Alters) as a card, Natural first: a round skin swatch (the alter's color map tinted with your
-- skin color), the name and the tier. Unlocked: WEAR (the one you wear: a gold WORN, gold border). The next one: a dark
-- swatch and its goal. Later ones: a dark swatch and "Alter n". No textures yet: the placeholder color, "Coming soon".
-- The line on top: your gains bonus (always the highest alter's, whatever skin you wear).
-- AltersPanel.Build(parent) -> { frame, refresh() }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)
local Config = script.Parent.Parent.Config
local Alters = require(Config.Alters)
local Muscles = require(Config.Muscles)
local GrowthSpurts = require(Config.GrowthSpurts)

local New, Colors = Theme.New, Theme.Colors

local AltersPanel = {}

local CARD = Vector2.new(124, 112)
local SWATCH = 44

function AltersPanel.Build(parent: Instance)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local player = Players.LocalPlayer
	local panel = {}
	local holder = New("Frame", { Name = "Alters", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local header = Kit.Text({ Name = "Bonus", Text = "", Font = "Strong", TextSize = 13, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder })
	local grid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 1, -22), ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = holder }, {
		New("UIGridLayout", { CellSize = UDim2.fromOffset(CARD.X, CARD.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
	})

	local cards = {}
	local function makeCard(alter)
		local card = Kit.Card({ Name = alter.id, LayoutOrder = alter.number, Parent = grid }, {})
		local swatch = New("ImageLabel", { Name = "Swatch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(SWATCH, SWATCH),
			BackgroundColor3 = Colors.Panel, ScaleType = Enum.ScaleType.Crop, Parent = card }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Colors.Outline, Thickness = 2 }),
		})
		local name = Kit.Text({ Name = "Name", Text = alter.name, Font = "Title", TextSize = 13, Position = UDim2.fromOffset(4, SWATCH + 8), Size = UDim2.new(1, -8, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		local sub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(4, SWATCH + 24),
			Size = UDim2.new(1, -8, 0, 13), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		local button = Kit.Button("Green", "Wear", { Name = "Wear", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Visible = false,
			Parent = card }, { height = 22, width = CARD.X - 16, textSize = 11 })
		button.Activated:Connect(function()
			local state = Alters.State(ClientData.Get())
			if alter.number <= (state.highest or 0) and alter.number ~= (state.equipped or 0) then
				Audio.PlayUI("Click")
				remotes.PlayerAction:FireServer("EquipAlter", alter.number)
			end
		end)
		cards[alter.number] = { card = card, swatch = swatch, name = name, sub = sub, button = button, alter = alter }
	end
	makeCard(Alters.Natural)
	for _, alter in ipairs(Alters.List) do makeCard(alter) end

	function panel.refresh()
		local data = ClientData.Get()
		if not data then return end
		local state = Alters.State(data)
		local highest, worn = state.highest or 0, state.equipped or 0
		local skin = player:GetAttribute("SkinColor")
		if typeof(skin) ~= "Color3" then skin = Color3.fromHex("#E0A878") end
		local maxed = GrowthSpurts.IsMaxed(data.growthSpurts or 0)
		local last = Alters.LastAvailable()
		header.Text = if maxed then string.format("%s · gains x%.2f (your highest alter)", Alters.Label(highest), Alters.Bonus(highest))
			else "Body Alters open at 7'0\". Each alter keeps 25% of your EXP and adds +15% gains."
		for n, c in pairs(cards) do
			local alter = c.alter
			local unlocked = n <= highest
			local textured = n == 0 or alter.textures ~= nil
			c.button.Visible = unlocked
			-- the swatch: the alter's color map tinted with your skin (Natural: plain skin); dark while locked
			if n == 0 then
				c.swatch.Image = ""
				c.swatch.BackgroundColor3 = skin
				c.swatch.ImageColor3 = Color3.new(1, 1, 1)
			elseif alter.textures then
				c.swatch.Image = alter.textures.color
				c.swatch.ImageColor3 = if unlocked then skin else Color3.fromHex("#1B1B20")
				c.swatch.BackgroundColor3 = if unlocked then skin else Color3.fromHex("#1B1B20")
			else
				c.swatch.Image = ""
				c.swatch.BackgroundColor3 = Color3.fromHex(alter.placeholder):Lerp(Color3.fromHex("#1B1B20"), 0.55)
			end
			c.name.TextTransparency = if unlocked or n == highest + 1 then 0 else 0.4
			local tierName = if n == 0 then "Natural" else Alters.Tiers[alter.tier].name .. " tier"
			if unlocked then
				c.sub.Text = tierName
				if n == worn then Kit.SetButton(c.button, "Gold", "Worn") else Kit.SetButton(c.button, "Green", "Wear") end
			elseif not textured or n > last then
				c.sub.Text = "Coming soon"
			elseif n == highest + 1 then
				c.sub.Text = "Next · " .. Muscles.FormatExpShort(Muscles.Shown(Alters.Goal(n))) .. " exp each"
			else
				c.sub.Text = "Alter " .. n
			end
			local stroke = c.card:FindFirstChild("WornStroke")
			if n == worn and unlocked then
				if not stroke then New("UIStroke", { Name = "WornStroke", Color = Colors.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = c.card }) end
			elseif stroke then
				stroke:Destroy()
			end
		end
	end

	panel.frame = holder
	return panel
end

return AltersPanel
