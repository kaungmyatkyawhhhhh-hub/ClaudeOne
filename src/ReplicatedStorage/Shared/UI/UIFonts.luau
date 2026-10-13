--!strict
-- UIFonts: the game's UI fonts in one place (owner's final kit "BLACK + GOLD", 14 Oct).
--   Display  Montserrat Black Italic: titles, names, buttons, numbers (owner's final kit, 14 Oct: one heavy italic
--            athletic font; GothamBlack isn't shipped with an italic face, Montserrat's is built in and matches the mockups)
--   Body     Montserrat Medium: descriptions, small text (gray)
--   BodyBold Montserrat Bold: emphasis in body text
-- (older names Heading / Number point at Display, so every screen keeps working.)
-- (ReplicatedFirst's LoadingScreen runs before this module has replicated and repeats the asset paths.)
local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local display = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local UIFonts = {
	Display = display,
	Heading = display,
	Number = display,
	Body = Font.new(MONTSERRAT, Enum.FontWeight.Medium),
	BodyBold = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
}

return UIFonts
