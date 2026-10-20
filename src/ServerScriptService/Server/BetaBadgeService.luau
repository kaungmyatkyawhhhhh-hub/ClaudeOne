-- BetaBadgeService: the BETA TESTER badge (owner, 20 Oct). While Config/Titles BETA_BADGE_ENABLED is on, every player who
-- joins and doesn't have the badge (BETA_BADGE_ID) yet gets it, and that one time their client shows a toast
-- (PlayerEvent "BetaBadge", RetentionClient). Joining never waits for it: each check runs in its own thread, and both Roblox
-- calls are in pcall, tried once more after RETRY seconds if they error. Never in Studio test sessions.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Titles = require(ReplicatedStorage.Shared.Config.Titles)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BetaBadgeService = {}

local RETRY = 5

-- call(fn): fn's result, with one more try after RETRY seconds if it errored; ok = false if both failed
local function call(fn): (boolean, any)
	local ok, result = pcall(fn)
	if ok then return true, result end
	task.wait(RETRY)
	return pcall(fn)
end

local function check(player: Player)
	local id = Titles.BETA_BADGE_ID
	local okHas, has = call(function() return BadgeService:UserHasBadgeAsync(player.UserId, id) end)
	if not okHas then
		warn("[BetaBadgeService] couldn't check the badge for " .. player.Name .. ": " .. tostring(has))
		return
	end
	if has or not player.Parent then return end
	local okAward, awarded = call(function() return BadgeService:AwardBadge(player.UserId, id) end)
	if not okAward then
		warn("[BetaBadgeService] couldn't award the badge to " .. player.Name .. ": " .. tostring(awarded))
		return
	end
	if awarded and player.Parent then
		Remotes.PlayerEvent:FireClient(player, "BetaBadge", {})
	end
end

function BetaBadgeService.Start()
	if not Titles.BETA_BADGE_ENABLED or not Titles.BETA_BADGE_ID or RunService:IsStudio() then return end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(check, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(check, player)
	end
end

return BetaBadgeService
