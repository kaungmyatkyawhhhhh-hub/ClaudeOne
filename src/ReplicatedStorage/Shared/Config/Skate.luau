-- Skating (owner, 14 Oct: it must feel fast at every size). SkateService sets the rider's top speed and board size from
-- their height; SkateClient rolls the board with no force cap, so body size / mass never slows it down.
--   top speed = (wheels speed or BaseSpeed) * (1 + HeightBoost * (heightScale - 1)), at most MaxSpeed
--   heightScale = the character's height / 4'0" (1 at Growth Spurt 0, 1.75 at 7'0")
-- Push, brake and turning scale by the same factor, so speeding up and carving feel the same at every size.
local GrowthSpurts = require(script.Parent.GrowthSpurts)

local Skate = {}

Skate.BaseSpeed = 32     -- studs/s with the plain wheels at 4'0" (walking is 16); the wheels upgrades set their own (Cosmetics)
Skate.HeightBoost = 0.35 -- how much faster a taller rider goes (x1.26 at 7'0")
Skate.MaxSpeed = 54      -- never faster than this (the fastest wheels at 7'0" are just under it)
-- the board under a 4'0" rider and under a 7'0" one (in between: by height)
Skate.BoardScaleMin = 0.85
Skate.BoardScaleMax = 1.3

function Skate.HeightScale(growthSpurts: number): number
	return GrowthSpurts.GetHeight(growthSpurts or 0) / GrowthSpurts.StartHeight
end

-- the speed / handling factor for a height
function Skate.SpeedFactor(heightScale: number): number
	return 1 + Skate.HeightBoost * (heightScale - 1)
end

function Skate.TopSpeed(baseSpeed: number, heightScale: number): number
	return math.min(baseSpeed * Skate.SpeedFactor(heightScale), Skate.MaxSpeed)
end

function Skate.BoardScale(heightScale: number): number
	local maxScale = GrowthSpurts.MaxHeightInches / GrowthSpurts.StartHeight
	local t = math.clamp((heightScale - 1) / (maxScale - 1), 0, 1)
	return Skate.BoardScaleMin + (Skate.BoardScaleMax - Skate.BoardScaleMin) * t
end

return Skate
