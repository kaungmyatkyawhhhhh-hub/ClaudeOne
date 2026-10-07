--[[
	CITY LEGENDS - shared configuration
	Every tunable number in the game lives here.
]]

local Config = {}

-- 1 stud ~= 0.35 m  ->  1 stud/s ~= 0.783 mph
Config.STUDS_TO_MPH = 0.783

function Config.mphToSps(mph: number): number
	return mph / Config.STUDS_TO_MPH
end

function Config.spsToMph(sps: number): number
	return sps * Config.STUDS_TO_MPH
end

---------------------------------------------------------------------
-- City layout
---------------------------------------------------------------------
Config.City = {
	Blocks = 6, -- blocks per side (roads = Blocks + 1 per axis)
	BlockSize = 300, -- distance between road centre lines
	LaneWidth = 12,
	LanesPerSide = 2,
	SidewalkWidth = 10,
	CurbHeight = 0.6,
	OuterRingDepth = 260, -- skyline ring of buildings around the grid

	-- Highway that leaves the city to the east and runs through the tunnel
	HighwayLanesPerSide = 3,
	HighwayLength = 2000,
	TunnelStart = 1300, -- measured from the city edge
	TunnelLength = 600,
	PlazaRadius = 110,
}

Config.City.RoadWidth = Config.City.LaneWidth * Config.City.LanesPerSide * 2
Config.City.HalfExtent = Config.City.Blocks * Config.City.BlockSize / 2
Config.City.HighwayWidth = Config.City.LaneWidth * Config.City.HighwayLanesPerSide * 2

---------------------------------------------------------------------
-- Graphics / city detail. Turn things off here for low-end devices.
---------------------------------------------------------------------
Config.Graphics = {
	PremiumBuildings = true, -- setback towers, fins, lit crowns, lobbies
	Landmarks = true, -- Legends Tower, Twist Tower, Needle
	StreetDetail = true, -- trees, benches, bus stops, hydrants, steam vents
	WetRoads = true, -- glossy rain-soaked asphalt
	Water = true, -- harbour around the city (terrain water) + clouds
	Monorail = true, -- elevated train looping the skyline
	Searchlights = true, -- sweeping sky beams on the landmarks
}

Config.Monorail = {
	Offset = 9, -- distance outside the perimeter road edge
	Height = 48,
	CornerRadius = 40,
	Speed = 95,
	Cars = 4,
	CarLength = 26,
}

---------------------------------------------------------------------
-- Traffic lights (seconds)
---------------------------------------------------------------------
Config.Lights = {
	Green = 9,
	Yellow = 2.5,
	AllRed = 1.5,
}
Config.Lights.Cycle = (Config.Lights.Green + Config.Lights.Yellow + Config.Lights.AllRed) * 2

---------------------------------------------------------------------
-- NPC traffic
---------------------------------------------------------------------
Config.Traffic = {
	CarCount = 55,
	MinSpeedMph = 28,
	MaxSpeedMph = 48,
	TurnSpeedMph = 22,
	Accel = 28, -- studs/s^2
	Brake = 70,
	EmergencyBrake = 140,
	StopGap = 4, -- studs left between bumpers in a queue
	LookAhead = 70,
	RecycleDistance = 700,
	RespawnMin = 220,
	RespawnMax = 520,
	StuckTime = 6,
	-- Weighted pick of classes used for NPCs
	ClassWeights = { Sedan = 40, SUV = 25, Coupe = 18, Supercar = 6, Hypercar = 2 },
}

---------------------------------------------------------------------
-- Economy
---------------------------------------------------------------------
Config.Economy = {
	StartingCash = 5000,
	DriveMinMph = 40, -- passive income only above this speed
	DrivePerSecond = 1 / 18, -- $ per mph per second ( 90mph -> $5/s )
	CutBase = 120,
	CutMinMph = 55,
	ComboWindow = 4.5,
	ComboStep = 0.25, -- +25% per combo level
	ComboMax = 12,
	CutCooldown = 0.18,
	OncomingBonus = 1.6,
	ThreadBonus = 2.5,
	NearMissGap = 5, -- studs of free space that still counts as a cut
}

---------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------
Config.Camera = {
	ChaseFov = 70,
	InteriorFov = 74,
	MaxFovBoost = 32,
	ChaseDistance = 17,
	ChaseHeight = 5.2,
}

---------------------------------------------------------------------
-- Sounds
-- The game ships with a full built-in soundscape (engine, wind, tyres,
-- cut-ups, crashes, backfires, UI, ambience) made from audio inside the
-- Roblox client, so it always works. To use your own recordings, paste an
-- audio asset id from the Creator Store here, e.g. "rbxassetid://1234567".
-- Each id is test-loaded at startup and only used if it loads.
---------------------------------------------------------------------
Config.Sounds = {
	Engine = "", -- a seamless engine loop (pitch follows RPM)
	CutUp = "", -- reward sting when you cut up a car
	Crash = "",
	Music = "", -- looping background music
}

---------------------------------------------------------------------
-- UI theme (dark)
---------------------------------------------------------------------
Config.Theme = {
	Background = Color3.fromRGB(10, 11, 15),
	Panel = Color3.fromRGB(18, 20, 27),
	PanelLight = Color3.fromRGB(27, 30, 40),
	Stroke = Color3.fromRGB(45, 50, 66),
	Text = Color3.fromRGB(236, 238, 245),
	SubText = Color3.fromRGB(140, 146, 165),
	Accent = Color3.fromRGB(0, 229, 255),
	Accent2 = Color3.fromRGB(255, 46, 136),
	Money = Color3.fromRGB(61, 255, 143),
	Warning = Color3.fromRGB(255, 184, 0),
	Danger = Color3.fromRGB(255, 64, 64),
}

return Config
