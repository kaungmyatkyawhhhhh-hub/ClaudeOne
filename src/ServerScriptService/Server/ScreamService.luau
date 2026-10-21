-- ScreamService (21 Oct; owner, 22 Oct: grunts, no screams): the lifting voices. Triggers (Config/Screams): every
-- EveryHeavy-th heavy rep and a new personal record; never a light rep, never every rep. One per Cooldown per player. The
-- server decides, every client plays it from the lifter's head (ScreamClient: 3D, quiet, nearby players only; Settings
-- "Lifting Voices" / "Others' Sounds").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Screams = require(ReplicatedStorage.Shared.Config.Screams)

local ScreamService = {}

local remote: UnreliableRemoteEvent -- (cosmetic: a lost scream doesn't matter, 14 Oct performance brief)
local last = {} -- [player] = os.clock() of the last grunt
local heavyReps = {} -- [player] = heavy reps since joining

function ScreamService.Scream(player: Player)
	if not remote or not player.Character then return end
	local now = os.clock()
	if now - (last[player] or -math.huge) < Screams.Cooldown then return end
	last[player] = now
	remote:FireAllClients(player, false)
end

-- After a rep (MachineService). info = { pr = a new personal record, lastOfSet = the set's last rep, heavy = at least
-- HeavyShare of the heaviest weight the player can lift there }
function ScreamService.OnRep(player: Player, info)
	if info.pr then
		ScreamService.Scream(player)
	elseif info.heavy then
		heavyReps[player] = (heavyReps[player] or 0) + 1
		if heavyReps[player] % Screams.EveryHeavy == 0 then ScreamService.Scream(player) end
	end
end

function ScreamService.Start()
	remote = ReplicatedStorage.Remotes:FindFirstChild("Scream")
	if not remote then
		remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = "Scream"
		remote.Parent = ReplicatedStorage.Remotes
	end
	-- (22 Oct: no more win screams for arm wrestling / posing)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
		heavyReps[player] = nil
	end)
end

return ScreamService
