-- ScreamService (21 Oct, the owner's 13 Oct "Monetization and hype" task 3): hype screams like a commander ability.
-- Triggers (Config/Screams): a heavy rep (HeavyChance), the last rep of a set (always), a new personal record (always, a
-- big one), an arm wrestling or posing competition win (always, big). One per Cooldown per player. The server decides,
-- every client plays it from the screamer's head (ScreamClient: 3D, nearby players only, "Others' Sounds" mutes others).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Screams = require(ReplicatedStorage.Shared.Config.Screams)
local GameEvents = require(script.Parent.GameEvents)

local ScreamService = {}

local remote: RemoteEvent
local last = {} -- [player] = os.clock() of the last scream

function ScreamService.Scream(player: Player, big: boolean?)
	if not remote or not player.Character then return end
	local now = os.clock()
	local wait = if big then Screams.BigCooldown else Screams.Cooldown
	if now - (last[player] or -math.huge) < wait then return end
	last[player] = now
	remote:FireAllClients(player, big == true)
end

-- After a rep (MachineService). info = { pr = a new personal record, lastOfSet = the set's last rep, heavy = at least
-- HeavyShare of the heaviest weight the player can lift there }
function ScreamService.OnRep(player: Player, info)
	if info.pr then
		ScreamService.Scream(player, true)
	elseif info.lastOfSet then
		ScreamService.Scream(player, false)
	elseif info.heavy and math.random() < Screams.HeavyChance then
		ScreamService.Scream(player, false)
	end
end

function ScreamService.Start()
	remote = ReplicatedStorage.Remotes:FindFirstChild("Scream")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Scream"
		remote.Parent = ReplicatedStorage.Remotes
	end
	GameEvents.On("ArmWrestleWon", function(player) ScreamService.Scream(player, true) end)
	GameEvents.On("PosingWon", function(player) ScreamService.Scream(player, true) end)
	Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
end

return ScreamService
