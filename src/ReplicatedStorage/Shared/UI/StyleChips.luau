-- StyleChips (prompt 61, owner 23 Oct): the colour row on the Inventory's aura and alter detail panels: ORIGINAL and the
-- two STYLE colours of that aura / alter (Config/Style). A colour you own: tap = wear it (PlayerAction "WearStyle"); the
-- one worn has a gold outline; a colour you don't own yet is dim with a lock: tap = where to get it (the PUMP SHOP's STYLE).
--   local chips = StyleChips.New(parent, { Position, Size, ZIndex })
--   chips:Set(kind, target, colours, colourHex)   kind "Aura" / "Alter", target = the aura / alter id, colours = its two
--                                                 colour names, colourHex(name) -> "#hex"; nil kind = hidden
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local Audio = require(script.Parent.Parent.Audio)
local ClientData = require(script.Parent.Parent.ClientData)

local New, Colors = Theme.New, Theme.Colors

local StyleChips = {}
StyleChips.__index = StyleChips

local CHIP_H = 24

function StyleChips.New(parent: Instance, props)
	local frame = New("Frame", { Name = "StyleChips", BackgroundTransparency = 1, Visible = false, Parent = parent }, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for k, v in pairs(props or {}) do frame[k] = v end
	return setmetatable({ frame = frame, zindex = frame.ZIndex }, StyleChips)
end

function StyleChips:Set(kind: string?, target: string?, colours: { string }?, colourHex)
	local frame = self.frame
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	if not kind or not target or not colours or #colours == 0 then
		frame.Visible = false
		return
	end
	frame.Visible = true
	local data = ClientData.Get() or {}
	local style = type(data.style) == "table" and data.style or {}
	local owned = type(style.owned) == "table" and style.owned or {}
	local wornMap = if kind == "Aura" then style.aura else style.alter
	local worn = type(wornMap) == "table" and wornMap[target] or nil
	local options = { { name = "Original", variant = nil, have = true } }
	for _, colour in ipairs(colours) do
		table.insert(options, { name = colour, variant = colour, have = owned[kind .. "_" .. target .. "_" .. colour] == true, hex = colourHex(colour) })
	end
	for order, option in ipairs(options) do
		local isWorn = option.variant == worn
		local chip = New("TextButton", { Name = option.name, Text = "", AutoButtonColor = false, LayoutOrder = order, BackgroundColor3 = Color3.fromHex("#232027"),
			Size = UDim2.fromOffset(0, CHIP_H), AutomaticSize = Enum.AutomaticSize.X, ZIndex = self.zindex + 1, Parent = frame }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = if isWorn then Colors.Gold else Color3.fromHex("#4A4652"), Thickness = if isWorn then 2 else 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		if option.hex then
			New("Frame", { Name = "Dot", LayoutOrder = 1, BackgroundColor3 = Color3.fromHex(option.hex), Size = UDim2.fromOffset(10, 10), ZIndex = self.zindex + 2,
				BackgroundTransparency = if option.have then 0 else 0.6, Parent = chip }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		Kit.Text({ Name = "Label", LayoutOrder = 2, Text = string.upper(option.name), Font = "Chunky", TextSize = 11,
			TextColor3 = if isWorn then Colors.Gold elseif option.have then Colors.Text else Colors.Faint, Size = UDim2.fromOffset(0, CHIP_H), AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = self.zindex + 2, Parent = chip })
		-- (a 44 px tap area round the small chip)
		local hit = New("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 4, 0, 44), ZIndex = self.zindex + 3, Parent = chip })
		hit.Activated:Connect(function()
			Audio.PlayUI("Click")
			if not option.have then
				Notify.Hint("Get " .. option.name .. " in the PUMP SHOP's STYLE tab.")
				return
			end
			if isWorn then return end
			ReplicatedStorage.Remotes.PlayerAction:FireServer("WearStyle", { kind = kind, target = target, variant = option.variant })
		end)
	end
end

return StyleChips
