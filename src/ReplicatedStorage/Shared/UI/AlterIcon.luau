-- AlterIcon (prompt 54, 23 Oct): the alter icon, a cartoon flexed bicep (Config.AlterThemes.Icon), used for every alter
-- everywhere (Inventory > Looks > Alters, Coach Dex's ALTERS tab, the alter popups, the NEXT alter card, toasts, quest
-- rewards). Undiscovered: the same bicep as a black silhouette with a thin rim in the tier's colour.
--   AlterIcon.New(props) -> holder       a Frame (props: Size, Position, AnchorPoint, ZIndex, Parent ...)
--   AlterIcon.Set(holder, n, mode)       n = the alter number (0 = Natural); mode "lit" (default) | "silhouette"
local Theme = require(script.Parent.Theme)
local Alters = require(script.Parent.Parent.Config.Alters)
local AlterThemes = require(script.Parent.Parent.Config.AlterThemes)

local New = Theme.New

local AlterIcon = {}
local RIM = 1.08 -- the rim copy is this much bigger than the icon

function AlterIcon.New(props)
	props.BackgroundTransparency = 1
	props.Name = props.Name or "AlterIcon"
	local holder = New("Frame", props)
	local z = holder.ZIndex
	New("ImageLabel", { Name = "Rim", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(RIM, RIM), ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = z, Parent = holder })
	New("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = z + 1, Parent = holder }):SetAttribute("KeepColor", true)
	return holder
end

function AlterIcon.Set(holder: Instance, n: number, mode: string?)
	local icon, rim = holder:FindFirstChild("Icon") :: ImageLabel, holder:FindFirstChild("Rim") :: ImageLabel
	if not icon or not rim then return end
	local alter = if n <= 0 then Alters.Natural else Alters.Get(n)
	local image, tint = AlterThemes.Icon(alter and alter.id or "Natural", n)
	icon.Image, rim.Image = image, image
	if mode == "silhouette" then
		-- a black shape with a thin rim in the tier's colour
		icon.ImageColor3 = Color3.new(0, 0, 0)
		rim.ImageColor3 = AlterThemes.Get(math.max(n, 1)).accent
		rim.Visible = true
	else
		icon.ImageColor3 = tint or Color3.new(1, 1, 1)
		rim.Visible = false
	end
end

return AlterIcon
