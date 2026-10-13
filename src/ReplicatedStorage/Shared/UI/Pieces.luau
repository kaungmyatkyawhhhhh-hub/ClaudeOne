-- Pieces: the UI images (Config/UI) as ImageLabels.
--   Pieces.Icon(name, color?, props?)  -> ImageLabel showing white line icon `name` (Config/UI.Icons), tinted `color`
--   Pieces.ShopIcon(name, props?)      -> ImageLabel showing shop art `name` (Config/UI.ShopIcons)
--   Pieces.Image(name, props?)         -> ImageLabel showing a named picture: a 3D menu icon (MenuIcons), a trainer
--                                         portrait (Trainers) or a shop icon; anything else is blank
--   Pieces.Apply(image, name)          sets an existing ImageLabel / ImageButton to picture `name`
-- (The 9-slice pieces of the cancelled dark style are gone: panels and buttons are Theme surfaces now.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UI"))

local Pieces = {}

local function lookup(name: string): string
	return UI.MenuIcons[name] or UI.Trainers[name] or UI.ShopIcons[name] or (name == "menu_art" and UI.MenuArt) or ""
end

function Pieces.Apply(image: any, name: string)
	image.Image = lookup(name)
	image.ScaleType = Enum.ScaleType.Fit
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
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = UI.ShopIcons[name] or ""
	return set(image, props)
end

return Pieces
