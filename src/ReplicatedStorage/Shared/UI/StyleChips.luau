-- StyleChips (prompt 61; owner 23 Oct: round swatches in the detail panel only, and aura / alter colours are off sale: only the
-- ones you already bought show): the colour row on the Inventory's aura and alter detail panels. ORIGINAL + each STYLE colour
-- of that aura / alter you own, as small round swatches (a 40 x 30 tap area each: the detail panels are short); the picked
-- one has a gold ring, the worn one a white dot in it (the panel's button names the picked colour). A tap picks it and previews it on you for a few seconds (opts.preview); the panel's own EQUIP / WEAR
-- button then wears it (chips:Selected()). No colour owned: the row is hidden (never an empty bar).
--   local chips = StyleChips.New(parent, { LayoutOrder / Position / Size / ZIndex }, { preview = function(variant?) end, changed = function() end })
--   chips:Set(kind, target, colours, colourHex, baseHex) -> shown   kind "Aura" / "Alter" (nil = hide), target = its id,
--                                                       colours = its colour names, colourHex(name) -> "#hex", baseHex = ORIGINAL's
--   chips:Selected() -> the picked variant (nil = ORIGINAL); chips:Worn() -> the variant worn
local Theme = require(script.Parent.Theme)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)

local New, Colors = Theme.New, Theme.Colors

local StyleChips = {}
StyleChips.__index = StyleChips

local SWATCH = 22
local ROW_H = 30 -- (the swatches' tap height)

function StyleChips.New(parent: Instance, props, opts)
	local frame = New("Frame", { Name = "StyleChips", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW_H), Visible = false, Parent = parent })
	for k, v in pairs(props or {}) do frame[k] = v end
	local row = New("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = frame.ZIndex, Parent = frame }, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return setmetatable({ frame = frame, row = row, opts = opts or {}, selected = nil, worn = nil, key = nil }, StyleChips)
end

function StyleChips:Selected() return self.selected end
-- the picked colour's name ("Original" for nil)
function StyleChips:Name(variant: string?): string return variant or "Original" end
function StyleChips:Worn() return self.worn end

function StyleChips:Set(kind: string?, target: string?, colours: { string }?, colourHex, baseHex: string?): boolean
	for _, child in ipairs(self.row:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local data = ClientData.Get() or {}
	local style = type(data.style) == "table" and data.style or {}
	local owned = type(style.owned) == "table" and style.owned or {}
	local have = {}
	if kind and target then
		for _, colour in ipairs(colours or {}) do
			if owned[kind .. "_" .. target .. "_" .. colour] then table.insert(have, colour) end
		end
	end
	if #have == 0 then
		self.frame.Visible = false
		self.selected, self.worn, self.key = nil, nil, nil
		return false
	end
	self.frame.Visible = true
	local wornMap = if kind == "Aura" then style.aura else style.alter
	self.worn = type(wornMap) == "table" and wornMap[target] or nil
	-- (a new aura / alter in the panel: start on the colour it wears)
	local key = kind .. "_" .. target
	if self.key ~= key then
		self.key = key
		self.selected = self.worn
	end
	local options = { { name = "Original", variant = nil, hex = baseHex or "#FFFFFF" } }
	for _, colour in ipairs(have) do table.insert(options, { name = colour, variant = colour, hex = colourHex(colour) }) end
	local z = self.frame.ZIndex
	for order, option in ipairs(options) do
		local picked = option.variant == self.selected
		local hit = New("TextButton", { Name = option.name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = order,
			Size = UDim2.fromOffset(40, ROW_H), ZIndex = z + 1, Parent = self.row })
		local dot = New("Frame", { Name = "Swatch", BackgroundColor3 = Color3.fromHex(option.hex), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(SWATCH, SWATCH), ZIndex = z + 2, Parent = hit }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = if picked then Colors.Gold else Color3.fromHex("#4A4652"), Thickness = if picked then 2.5 else 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		if option.variant == self.worn then
			-- the colour worn: a tiny white dot in it
			New("Frame", { Name = "Worn", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(6, 6), ZIndex = z + 3, Parent = dot }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		hit.Activated:Connect(function()
			Audio.PlayUI("Click")
			self.selected = option.variant
			if self.opts.preview then self.opts.preview(option.variant) end
			if self.opts.changed then self.opts.changed() end
		end)
	end
	return true
end

return StyleChips
