-- The Powerlifting Gym (prompt 58, 23 Oct; opens at Growth Spurt 5, Machines.GymUnlock). Its machines are
-- Config/Machines.PowerliftingCopies (lift = "Squat" | "Bench" | "Deadlift" for the board). Server/PowerliftingService,
-- Client/PowerliftingClient; built in Studio with tools/builders/PowerliftingGym (Workspace.PowerliftingGym).
--   * RECORD BOARD: a big board on the back wall: for each lift the server's heaviest lift in this gym (name + weight) and
--     the all-time top 3 (saved in the DataStore below, one entry per player per lift, their best).
--   * PR BELL: a new personal record on any machine in this gym rings the bell for everyone inside, with a gold flash
--     and a toast ("NAME hit a 1,250 LB DEADLIFT PR!") shown only inside the gym.
--   * A new SERVER RECORD: the board flashes, the name goes to the top, the three judge lights turn white (GOOD LIFT) and
--     the crowd cheers.
--   * MEET: every MeetEvery seconds a MeetSeconds window: reps on the competition platform's machines give MeetBonus more
--     EXP and the judge lights answer every rep.
local Powerlifting = {}

Powerlifting.Lifts = { "Squat", "Bench", "Deadlift" }
Powerlifting.LiftNames = { Squat = "SQUAT", Bench = "BENCH", Deadlift = "DEADLIFT" }

Powerlifting.TopCount = 3               -- all-time places per lift on the board
Powerlifting.Store = "PowerliftingRecords_v1" -- DataStore (one key, "AllTime")
Powerlifting.SaveEvery = 90             -- seconds between two saves of the all-time records (and on close)

Powerlifting.MeetEvery = 600            -- a MEET every 10 minutes
Powerlifting.MeetSeconds = 60           -- that lasts 60 seconds
Powerlifting.MeetBonus = 1.2            -- +20% EXP on the competition platform during a meet
Powerlifting.MeetWarn = 15              -- seconds of "MEET STARTS IN" before it opens

Powerlifting.BellCooldown = 2.5         -- seconds between two bells (several PRs at once ring once)
Powerlifting.JudgeHold = 2.2            -- seconds the judge lights stay on

-- the toast inside the gym: "Rong hit a 1,250 LB DEADLIFT PR!"
function Powerlifting.FormatWeight(weight: number): string
	local text = tostring(math.floor(weight))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
function Powerlifting.PRText(name: string, weight: number, liftName: string): string
	return string.format("%s hit a %s LB %s PR!", name, Powerlifting.FormatWeight(weight), string.upper(liftName))
end

return Powerlifting
