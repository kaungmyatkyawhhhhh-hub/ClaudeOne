--!strict
-- UIFonts: the game's UI fonts in one place (owner's UI redesign brief, 13 Oct: Oswald + Montserrat, both built into Roblox).
--   Heading  Oswald Bold: titles, button labels, tabs (UPPERCASE), grades
--   Number   Oswald SemiBold: numbers
--   Body     Montserrat SemiBold: body text, descriptions
--   BodyBold Montserrat Bold: emphasis in body text (names, item names in rows)
-- (ReplicatedFirst's LoadingScreen runs before this module has replicated and repeats the asset paths.)
local OSWALD = "rbxasset://fonts/families/Oswald.json"
local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local UIFonts = {
	Heading = Font.new(OSWALD, Enum.FontWeight.Bold),
	Number = Font.new(OSWALD, Enum.FontWeight.SemiBold),
	Body = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
	BodyBold = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
}

return UIFonts
