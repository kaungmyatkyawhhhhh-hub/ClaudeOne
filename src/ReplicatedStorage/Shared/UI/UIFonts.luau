--!strict
-- UIFonts: the game's UI fonts in one place.
--   Heading  Oswald Bold: titles, button labels (UPPERCASE), big numbers and grades
--   Number   Oswald SemiBold: numbers inside text rows
--   Body     Nunito Regular: normal text
--   BodyBold Nunito SemiBold: emphasis in body text (names, short labels)
-- (ReplicatedFirst's LoadingScreen runs before this module has replicated and repeats the two asset paths.)
local OSWALD = "rbxasset://fonts/families/Oswald.json"
local NUNITO = "rbxasset://fonts/families/Nunito.json"

local UIFonts = {
	Heading = Font.new(OSWALD, Enum.FontWeight.Bold),
	Number = Font.new(OSWALD, Enum.FontWeight.SemiBold),
	Body = Font.new(NUNITO, Enum.FontWeight.Regular),
	BodyBold = Font.new(NUNITO, Enum.FontWeight.SemiBold),
}

return UIFonts
