local H = require("./harness")
local D = H.module("ReplicatedStorage/Shared/Config/DayNight")
print("Clock")
H.check(math.abs(D.ClockFromElapsed(0) - D.StartHour) < 1e-6, "a server starts at StartHour")
H.check(math.abs(D.ClockFromElapsed(D.Length) - D.StartHour) < 1e-6, "a full cycle comes back to the same time")
local dayStart = (D.StartHour - D.Dawn) / (D.Dusk - D.Dawn) * D.Length * D.DayShare
H.check(math.abs(D.ClockFromElapsed(D.Length * D.DayShare - dayStart) - D.Dusk) < 1e-6, "dusk after DayShare of the cycle from dawn")
local nightSeconds, step = 0, 1
for t = 0, D.Length - step, step do
	if D.IsNight(D.ClockFromElapsed(t)) then nightSeconds += step end
end
H.check(math.abs(nightSeconds / D.Length - (1 - D.DayShare)) < 0.01, "night takes the rest of the cycle")
H.check(D.Length == 20 * 60, "a full day is 20 minutes by default")
print("Night amount")
H.check(D.NightAmount(12) == 0, "noon: none")
H.check(D.NightAmount(0) == 1, "midnight: full")
H.check(math.abs(D.NightAmount(18) - 0.5) < 1e-6 and math.abs(D.NightAmount(6) - 0.5) < 1e-6, "half at dusk and dawn")
H.check(D.NightAmount(17) > 0 and D.NightAmount(17) < 0.5, "fades in before dusk")
H.done()
