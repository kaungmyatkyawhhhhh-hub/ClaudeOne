-- Pieces: the UI image pieces (Config/UI.Pieces, owner's UI redesign) as ImageLabels with their 9-slice data, so corners
-- stay sharp at any size. Panels, cards, buttons, tabs, chips, bars, toggles, tags and badges are these images; text,
-- numbers and icons stay live on top.
--   Pieces.Image(name, props?)        -> ImageLabel showing piece `name` (props: any ImageLabel properties)
--   Pieces.Apply(image, name)          sets an existing ImageLabel / ImageButton to piece `name`
--   Pieces.Icon(name, color?, props?)  -> ImageLabel showing icon `name` (Config/UI.Icons), tinted `color`
--   Pieces.ShopIcon(name, props?)      -> ImageLabel showing shop icon `name` (Config/UI.ShopIcons)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UI"))

local Pieces = {}

function Pieces.Apply(image: any, name: string)
	local piece = UI.Pieces[name]
	if not piece then
		warn("[Pieces] unknown piece " .. tostring(name))
		return
	end
	image.Image = piece.image
	if piece.scaleType == "Slice" then
		local c = piece.sliceCenter
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = Rect.new(c[1], c[2], c[3], c[4])
		image.SliceScale = piece.sliceScale or 1
	else
		image.ScaleType = Enum.ScaleType.Fit
	end
end

local function set(instance, props)
	for key, value in pairs(props or {}) do instance[key] = value end
	return instance
end

function Pieces.Image(name: string, props: { [string]: any }?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	Pieces.Apply(image, name)
	return set(image, props)
end

function Pieces.Icon(name: string, color: Color3?, props: { [string]: any }?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = UI.Icons[name] or ""
	if not UI.Icons[name] then warn("[Pieces] unknown icon " .. tostring(name)) end
	image.ImageColor3 = color or Color3.new(1, 1, 1)
	return set(image, props)
end

function Pieces.ShopIcon(name: string, props: { [string]: any }?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "ShopIcon"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Crop
	image.Image = UI.ShopIcons[name] or ""
	return set(image, props)
end

Pieces.Config = UI
return Pieces
