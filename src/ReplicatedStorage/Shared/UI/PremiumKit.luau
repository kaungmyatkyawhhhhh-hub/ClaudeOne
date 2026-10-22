-- PremiumKit (owner, 23 Oct; moved out of PumpShopClient for prompt 61 so the Store uses the same pieces): the premium
-- shop look of the Alters / Auras panels and the PUMP SHOP.
--   PremiumKit.ThemedBackground(parent, corner, center, ringSizes) -> paint(color)
--     a soft background in a colour (a dark gradient filling the parent, rounded) with faint rings round `center`
--   PremiumKit.SlimButton(parent, props, label?, price?, look, textSize?, currency?) -> TextButton
--     a slim graphite button with a thin outline: an optional label ("x1"), a coin (currency "robux": the Robux icon) and a
--     number, or just words. look = "buy" (gold outline), "plain" (gray outline), "need" (the price red), "owned" (gold
--     outline, gold words), "off" (faint words)
--   PremiumKit.GRAPHITE, GRAPHITE_EDGE, PILL_DARK, NEED_RED
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

local New, Colors = Theme.New, Theme.Colors

local PremiumKit = {}
PremiumKit.GRAPHITE = Color3.fromHex("#232027")
PremiumKit.GRAPHITE_EDGE = Color3.fromHex("#4A4652")
PremiumKit.PILL_DARK = Color3.fromHex("#1E1B20")
PremiumKit.NEED_RED = Color3.fromHex("#FF5A5F")

function PremiumKit.ThemedBackground(parent: GuiObject, corner: number, center: UDim2, ringSizes: { number })
	local base = New("Frame", { Name = "Theme", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, corner) }),
	})
	local gradient = New("UIGradient", { Rotation = 90, Parent = base })
	-- (the rings in a frame inset by ~0.3 of the corner radius: ClipsDescendants clips square, no corner pokes out)
	local inset = math.ceil(corner * 0.3)
	local clip = New("Frame", { Name = "Rings", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset), ZIndex = 1, Parent = parent })
	local strokes = {}
	for _, size in ipairs(ringSizes) do
		local ring = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = center - UDim2.fromOffset(inset, inset), Size = UDim2.fromOffset(size, size),
			ZIndex = 1, Parent = clip }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		table.insert(strokes, New("UIStroke", { Thickness = 1.5, Transparency = 0.72, Parent = ring }))
	end
	return function(color: Color3)
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.66), color:Lerp(Color3.new(0, 0, 0), 0.86))
		for _, stroke in ipairs(strokes) do stroke.Color = color end
	end
end

function PremiumKit.SlimButton(parent, props, label: string?, price: number?, look: string, textSize: number?, currency: string?)
	local size = textSize or 14
	local button = New("TextButton", { Name = props.Name or "Button", Text = "", AutoButtonColor = false, BackgroundColor3 = PremiumKit.GRAPHITE, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Name = "Edge", Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = if look == "buy" or look == "owned" then Colors.Gold else PremiumKit.GRAPHITE_EDGE }),
	})
	for k, v in pairs(props) do if k ~= "Name" then button[k] = v end end
	local row = New("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = button.ZIndex + 1, Parent = button }, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local color = if look == "owned" then Colors.Gold elseif look == "need" then PremiumKit.NEED_RED elseif look == "off" then Colors.Faint else Colors.Text
	if label then
		Kit.Text({ Name = "Label", LayoutOrder = 1, Text = label, Font = "Title", KeepItalic = true, TextSize = size, Upper = true, TextColor3 = color,
			Size = UDim2.fromOffset(0, size + 4), AutomaticSize = Enum.AutomaticSize.X, ZIndex = button.ZIndex + 2, Parent = row })
	end
	if price then
		if currency == "robux" then
			local icon = Pieces.Icon("robux", Color3.new(1, 1, 1), { Name = "Robux", LayoutOrder = 2, Size = UDim2.fromOffset(math.floor(size * 1.05), math.floor(size * 1.05)),
				ZIndex = button.ZIndex + 2, Parent = row })
			icon:SetAttribute("KeepColor", true)
		else
			Kit.Coin(math.floor(size * 1.05), { LayoutOrder = 2, ZIndex = button.ZIndex + 2, Parent = row })
		end
		Kit.Text({ Name = "Price", LayoutOrder = 3, Text = Kit.Format(price), Font = "Title", KeepItalic = true, TextSize = size, TextColor3 = color,
			Size = UDim2.fromOffset(0, size + 4), AutomaticSize = Enum.AutomaticSize.X, ZIndex = button.ZIndex + 2, Parent = row })
	end
	Theme.BindPress(button)
	return button
end

return PremiumKit
