-- GearPanel (owner, prompt 19, 21 Oct): the Inventory window's GEAR tab (TitlesClient builds the window and calls this).
-- Everything you own to wear: PUMP SHOP gear (belt, wraps, straps, sleeves, with their perk), apparel (shorts and tank
-- top colors, headbands, shakers, gym bags) and the clothing store's gear. Each card: a color tile, the name, what it
-- does (or "Looks only"), and WEAR / TAKE OFF. (Tops from the clothing store stay hidden while the Wardrobe is off.)
-- (prompt 28) Bigger cards, 5 a row; GearPanel.Count(data) = how many you own (the GEAR tab shows once you have any).
-- GearPanel.Build(parent) -> { frame, refresh() }.
-- (prompt 59, 23 Oct) First two tiles: your LIFTING BELT and WRIST WRAPS (the best level you own, its picture and boost,
-- "+10% LOWER BODY"; it always counts, worn or not), or "NO BELT YET" with GET AT COACH DEX (goes there). From Growth
-- Spurt 2 (when gear opens) the tab always shows. Straps and knee sleeves are gone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)
local Config = script.Parent.Parent.Config
local Cosmetics = require(Config.Cosmetics)
local PumpShop = require(Config.PumpShop)
local Body = require(Config.Body)
local Features = require(Config.Features)

local New, Colors = Theme.New, Theme.Colors

local GearPanel = {}

local CARD = Vector2.new(154, 96)


-- how many things you own to wear (as the tab lists them)
function GearPanel.Count(data): number
	local owned = (data and data.cosmetics and data.cosmetics.owned) or {}
	local n = 0
	for _, item in ipairs(Cosmetics.Items) do
		if owned[item.id] and not (item.slot == "Fit" and not Features.Wardrobe) then n += 1 end
	end
	for _, entry in ipairs(Body.ShortsColors) do
		if entry.shop and owned["Shorts_" .. entry.id] then n += 1 end
	end
	for _, entry in ipairs(Body.Tops) do
		if entry.shop and owned["Top_" .. entry.id] then n += 1 end
	end
	-- (prompt 59) the belt and wraps tiles, from when gear opens
	if (data and data.growthSpurts or 0) >= PumpShop.GearAtSpurt then n += #PumpShop.Gear end
	return n
end

function GearPanel.Build(parent: Instance)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local panel = {}
	local holder = New("Frame", { Name = "Gear", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local frame = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = holder }, {
		New("UIGridLayout", { CellSize = UDim2.fromOffset(CARD.X, CARD.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
	})
	panel.frame = holder
	-- (prompt 40, mockup inv_gear_empty) nothing yet: a big gold dumbbell, NOTHING TO WEAR YET, what gear does, GO TO PUMP SHOP
	local empty = New("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = holder })
	local glow = New("Frame", { Name = "Glow", BackgroundColor3 = Colors.Gold, BackgroundTransparency = 0.82, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -52), Size = UDim2.fromOffset(110, 70), Parent = empty }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local _ = glow
	require(script.Parent.Pieces).Icon("dumbbell", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -52), Size = UDim2.fromOffset(64, 64),
		Parent = empty }):SetAttribute("KeepColor", true)
	Kit.Text({ Name = "Title", Text = "NOTHING TO WEAR YET", Font = "Chunky", TextSize = 22, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -6),
		Size = UDim2.new(1, -20, 0, 26), Parent = empty })
	local line = Kit.Text({ Name = "Line", Text = "A lifting belt and wrist wraps make your lifts stronger.", Font = "Body", TextSize = 13, TextColor3 = Colors.Muted,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20), Size = UDim2.new(1, -20, 0, 16), Parent = empty })
	line.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Italic)
	-- (prompt 31) Basic gear is sold by Coach Dex now
	local goShop = Kit.Button("Gold", "Go to Coach Dex", { Name = "GoCoach", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 56), Parent = empty },
		{ width = 190, height = 36, textSize = 16 })
	goShop.Activated:Connect(function()
		local UIBus = require(script.Parent.UIBus)
		UIBus.CloseAllPanels()
		UIBus.GoCoach:Fire()
	end)

	local function card(order, name, sub, color, wearing, onTap)
		local c = Kit.Card({ Name = name, LayoutOrder = order, Parent = frame }, {})
		New("Frame", { Name = "Swatch", BackgroundColor3 = color, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(30, 30), Parent = c },
			{ New("UICorner", { CornerRadius = UDim.new(0, 6) }), New("UIStroke", { Color = Colors.Outline, Thickness = 1.5 }) })
		Kit.Fit(Kit.Text({ Name = "Name", Text = name, Font = "Title", Position = UDim2.fromOffset(44, 7), Size = UDim2.new(1, -52, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left, Parent = c }), 14, 9)
		Kit.Fit(Kit.Text({ Name = "Sub", Text = sub, Font = "Body", TextColor3 = Colors.Muted, Position = UDim2.fromOffset(44, 24), Size = UDim2.new(1, -52, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left, Parent = c }), 11, 8)
		local button = Kit.Button(if wearing then "Gold" else "Quiet", if wearing then "Take off" else "Wear",
			{ Name = "Wear", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Parent = c }, { width = CARD.X - 16, height = 40, textSize = 13 })
		button.Activated:Connect(function()
			Audio.PlayUI("Click")
			onTap()
		end)
	end

	-- (prompt 59) a gear tile: the picture, "PRO BELT", "+10% LOWER BODY" (it counts worn or not; WEAR only shows when
	-- something else is worn in its place); none yet: "NO BELT YET" and GET AT COACH DEX
	local function gearCard(order, gear, level, equipped)
		local c = Kit.Card({ Name = gear.id, LayoutOrder = order, Parent = frame }, {})
		local itemId = level and PumpShop.GearItemId(gear.id, level.id)
		local icon = PumpShop.GearIcons[itemId or PumpShop.GearItemId(gear.id, "Basic")]
		New("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = icon, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(40, 40), ImageTransparency = if level then 0 else 0.6, ImageColor3 = if level then Color3.new(1, 1, 1) else Color3.fromRGB(120, 120, 120), Parent = c })
		local title = if level then string.upper(level.name .. " " .. gear.short) else "NO " .. string.upper(gear.short) .. " YET"
		Kit.Fit(Kit.Text({ Name = "Name", Text = title, Font = "Title", Position = UDim2.fromOffset(50, 7), Size = UDim2.new(1, -56, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left, Parent = c }), 14, 9)
		local sub = if level then PumpShop.GearBoostText(gear, level) else string.upper(gear.half) .. " BOOST"
		Kit.Fit(Kit.Text({ Name = "Sub", Text = sub, Font = "Chunky", TextColor3 = if level then Colors.Gold else Colors.Muted, Position = UDim2.fromOffset(50, 25),
			Size = UDim2.new(1, -56, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = c }), 11, 8)
		local button = nil
		if not level then
			button = Kit.Button("Gold", "Get at Coach Dex", { Name = "Get", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Parent = c },
				{ width = CARD.X - 16, height = 40, textSize = 12 })
			button.Activated:Connect(function()
				Audio.PlayUI("Click")
				local UIBus = require(script.Parent.UIBus)
				UIBus.CloseAllPanels()
				UIBus.GoCoach:Fire()
			end)
		elseif equipped[gear.slot] ~= itemId then
			button = Kit.Button("Quiet", "Wear", { Name = "Wear", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Parent = c },
				{ width = CARD.X - 16, height = 40, textSize = 13 })
			button.Activated:Connect(function()
				Audio.PlayUI("Click")
				remotes.PlayerAction:FireServer("EquipCosmetic", itemId)
			end)
		else
			Kit.Text({ Name = "Active", Text = "ALWAYS ON", Font = "Chunky", TextSize = 12, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -16, 0, 16), Parent = c })
		end
	end

	function panel.refresh()
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		local data = ClientData.Get() or {}
		local state = data.cosmetics or {}
		local owned, equipped = state.owned or {}, state.equipped or {}
		local settings = data.settings or {}
		local order = 0
		-- (prompt 59) the belt and the wraps first: the best level you own, or where to get one
		for _, gear in ipairs(PumpShop.Gear) do
			order += 1
			gearCard(order, gear, PumpShop.GearBest(owned, gear.id), equipped)
		end
		-- then apparel and the rest, in Config order
		for _, item in ipairs(Cosmetics.Items) do
			if owned[item.id] and not item.gear and not (item.slot == "Fit" and not Features.Wardrobe) then
				order += 1
				local wearing = equipped[item.slot] == item.id
				card(order + 100, item.name, "Looks only", item.color, wearing, function()
					remotes.PlayerAction:FireServer("EquipCosmetic", item.id)
				end)
			end
		end
		for _, entry in ipairs(Body.ShortsColors) do
			if entry.shop and owned["Shorts_" .. entry.id] then
				order += 1
				local wearing = (settings.shorts or Body.DefaultShorts) == entry.id
				card(order + 200, entry.name .. " shorts", "Looks only", entry.color, wearing, function()
					remotes.PlayerAction:FireServer("SetSettings", { shorts = if wearing then Body.DefaultShorts else entry.id })
				end)
			end
		end
		for _, entry in ipairs(Body.Tops) do
			if entry.shop and owned["Top_" .. entry.id] then
				order += 1
				local wearing = (settings.top or Body.DefaultTop) == entry.id
				card(order + 300, entry.name, "Looks only", entry.color or Colors.Text, wearing, function()
					remotes.PlayerAction:FireServer("SetSettings", { top = if wearing then Body.DefaultTop else entry.id })
				end)
			end
		end
		empty.Visible = order == 0
	end

	ClientData.Changed:Connect(function(path)
		if holder.Visible and (path[1] == "cosmetics" or path[1] == "settings") then panel.refresh() end
	end)
	return panel
end

return GearPanel
