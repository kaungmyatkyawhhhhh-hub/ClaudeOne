--!strict
-- UIFonts: the game's UI fonts in one place (owner's UI v2 style, 13 Oct: Gym League style).
--   Display  FredokaOne: labels, titles, buttons, numbers (white with a black outline: Theme.Text adds it)
--   Body     Montserrat SemiBold: descriptions, dialog
--   BodyBold Montserrat Bold: emphasis in body text
-- (older names Heading / Number point at Display, so every screen keeps working.)
-- (ReplicatedFirst's LoadingScreen runs before this module has replicated and repeats the asset paths.)
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"
local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local display = Font.new(FREDOKA, Enum.FontWeight.Regular)
local UIFonts = {
	Display = display,
	Heading = display,
	Number = display,
	Body = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
	BodyBold = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
}

return UIFonts
