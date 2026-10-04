-- Legend NPCs (original characters only). One shows up in the gym every 20-30 minutes for 3 minutes.
-- Talk to a legend to take their one-time challenge; finish it any time after (even once they've left) for the
-- reward and their matching title in the Title Book. Adding a legend = adding an entry (and its title in Titles).
local Legends = {}

Legends.Visit = {
	EveryMinutes = { 20, 30 }, -- random gap between visits
	StayMinutes = 3,
	FirstVisitSeconds = 120,   -- after a server starts (30 in Studio, for testing)
	Spot = Vector3.new(0, 0.1, -34.5), -- in front of the bench row, facing the door
}

-- look: colors + scale (legends are big). quest: like Coach quests ("reps" or "machineReps").
Legends.List = {
	{ id = "LanceLats", name = "Lance Lats", title = "Wingspan",
		look = { skin = "#C68642", shirt = "#1E1E22", pants = "#2B2B2B", scale = { height = 1.12, width = 1.45, depth = 1.15, head = 1 } },
		line = "They call it a lat spread. I call it a Tuesday.",
		quest = { text = "Do 15 reps on the Pull-Up Bar", type = "machineReps", machines = { "PullUpBar" }, count = 15 } },
	{ id = "BrodyPumpkins", name = "Brody Pumpkins", title = "Pumpkin Delts",
		look = { skin = "#F1C27D", shirt = "#E8C21C", pants = "#1E1E22", scale = { height = 1.08, width = 1.4, depth = 1.2, head = 1 } },
		line = "Round shoulders, round plates. Coincidence? No.",
		quest = { text = "Do 15 Overhead Press reps", type = "machineReps", machines = { "OverheadPress" }, count = 15 } },
	{ id = "TankMcFlex", name = "Tank McFlex", title = "Tank Mode",
		look = { skin = "#8D5524", shirt = "#2E9E4F", pants = "#1E1E22", scale = { height = 1.15, width = 1.5, depth = 1.3, head = 1 } },
		line = "Legs are the foundation. I'm basically a building.",
		quest = { text = "Do 15 reps on the Squat Rack", type = "machineReps", machines = { "SquatRack" }, count = 15 } },
	{ id = "KyleSwole", name = "Kyle Swole", title = "Certified Swole",
		look = { skin = "#E0AC69", shirt = "#D7262E", pants = "#2B2B2B", scale = { height = 1.1, width = 1.4, depth = 1.25, head = 1 } },
		line = "Bench day is every day if you believe hard enough.",
		quest = { text = "Do 15 reps on the Flat Bench", type = "machineReps", machines = { "FlatBench" }, count = 15 } },
	{ id = "RickyReps", name = "Ricky Reps", title = "Rep Machine",
		look = { skin = "#C68642", shirt = "#F4F1EA", pants = "#1E1E22", scale = { height = 1.05, width = 1.3, depth = 1.15, head = 1 } },
		line = "I stopped counting at a million. Then I started again.",
		quest = { text = "Do 40 reps on any machine", type = "reps", count = 40 } },
	{ id = "BigBeefington", name = "Big Beefington", title = "Beefcake",
		look = { skin = "#F1C27D", shirt = "#1F5FBF", pants = "#1E1E22", scale = { height = 1.2, width = 1.55, depth = 1.35, head = 1.05 } },
		line = "Pick it up, put it down. Repeat until legendary.",
		quest = { text = "Do 15 Deadlift reps", type = "machineReps", machines = { "Deadlift" }, count = 15 } },
	{ id = "TinyTimGains", name = "Tiny Tim Gains", title = "Small but Mighty",
		look = { skin = "#E0AC69", shirt = "#2E9E4F", pants = "#2B2B2B", scale = { height = 0.85, width = 1.25, depth = 1.1, head = 1 } },
		line = "Everyone starts tiny. Some of us stay tiny and get strong anyway.",
		quest = { text = "Do 20 reps on the Crunch Bench", type = "machineReps", machines = { "CrunchBench" }, count = 20 } },
	{ id = "ChadGainsworth", name = "Chad Gainsworth", title = "Gainsworth Approved",
		look = { skin = "#F1C27D", shirt = "#1E1E22", pants = "#1F5FBF", scale = { height = 1.15, width = 1.45, depth = 1.2, head = 1 } },
		line = "Upper chest is the secret. Don't tell anyone. Except you.",
		quest = { text = "Do 15 reps on the Incline Bench", type = "machineReps", machines = { "InclineBench" }, count = 15 } },
}

Legends.Reward = { coins = 60, dnaTokens = 1 }

Legends.ById = {}
for _, legend in ipairs(Legends.List) do Legends.ById[legend.id] = legend end

-- The title id for a legend (titles live in Config.Titles with condition { type = "legend", id = legendId }).
function Legends.TitleId(legendId)
	return "Legend" .. legendId
end

return Legends
