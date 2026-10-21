-- GoToService (22 Oct, owner: "GO TO buttons teleport"): the GO TO buttons (the tutorial's "GO TO COACH DEX" / "GO TO
-- SQUAT RACK", the Growth Spurt's "Train next" window) move the player in front of the target instead of walking them there.
-- The client fades to black and asks (PlayerAction "GoTo", target); this checks it and answers PlayerEvent "GoTo" { ok }:
--   * target = a MachineId or "Coach" (Shared/GoTo.Valid), and that machine exists in a gym the player has opened
--     (Shared/GoTo.Find: the nearest free one, like the glowing path);
--   * at most once per Cooldown seconds per player;
--   * on a machine: off it first (MachineService.LeavePlayer);
--   * the spot: just outside the machine on the room side (Shared/GoTo.Spot), on the floor (a ray down), with room to stand
--     (no solid part in a character-sized box); if that spot is blocked, the same distance around the machine in steps of
--     45 degrees. The player faces the target.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GoTo = require(ReplicatedStorage.Shared.GoTo)
local PlayerData = require(script.Parent.PlayerData)
local MachineService = require(script.Parent.MachineService)
local ActionService = require(script.Parent.ActionService)

local Remotes = ReplicatedStorage.Remotes

local GoToService = {}

GoToService.Cooldown = 3
local BODY = Vector3.new(2.2, 4.6, 2.2) -- the room a character needs to stand

local last = {} -- [player] = os.clock() of the last teleport

-- (at = the point the player was turned to face: the client turns its camera there too)
local function answer(player, ok: boolean, at: Vector3?)
	if player.Parent then Remotes.PlayerEvent:FireClient(player, "GoTo", { ok = ok, at = at }) end
end

-- the floor under `at` (a ray down from a little above it) and whether a character fits standing there
local function standAt(at: Vector3, character: Model): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	if not hit then return nil end
	local floor = hit.Position
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	local box = CFrame.new(floor + Vector3.new(0, BODY.Y / 2 + 0.15, 0))
	if #Workspace:GetPartBoundsInBox(box, BODY, overlap) > 0 then return nil end
	return floor
end

local function teleport(player, target)
	if not GoTo.Valid(target) then return end
	local now = os.clock()
	if last[player] and now - last[player] < GoToService.Cooldown then
		answer(player, false)
		return
	end
	local data = PlayerData.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not humanoid or not root or humanoid.Health <= 0 then
		answer(player, false)
		return
	end
	-- (prompt 39) a place with no model (the posing stage): its spot, facing it
	local point = GoTo.Point(target)
	local model = if point then nil else GoTo.Find(target, root.Position, data.growthSpurts or 0)
	if not point and (not model or not model:IsDescendantOf(Workspace)) then
		answer(player, false)
		return
	end
	last[player] = now
	MachineService.LeavePlayer(player) -- (off a machine first)
	-- the spot in front of it, or around it
	local Town = require(ReplicatedStorage.Shared.Config.Town)
	local center = if model then model:GetBoundingBox().Position else Town.Stage.Center
	local first = if model then GoTo.Spot(model) else point :: Vector3
	local floor = standAt(first, character)
	if not floor then
		local offset = (first - center) * Vector3.new(1, 0, 1)
		local distance = math.max(offset.Magnitude, 3)
		local angle0 = math.atan2(offset.Z, offset.X)
		for step = 1, 7 do
			local angle = angle0 + step * math.pi / 4
			local try = Vector3.new(center.X + math.cos(angle) * distance, first.Y, center.Z + math.sin(angle) * distance)
			floor = standAt(try, character)
			if floor then break end
		end
	end
	if not floor then
		answer(player, false)
		return
	end
	local lift = humanoid.HipHeight + root.Size.Y / 2
	local stand = floor + Vector3.new(0, lift, 0)
	local look = Vector3.new(center.X, stand.Y, center.Z)
	if (look - stand).Magnitude < 0.1 then look = stand + Vector3.new(0, 0, -1) end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(stand, look))
	answer(player, true, look)
end

function GoToService.Start()
	ActionService.Register("GoTo", teleport)
	Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
end

return GoToService
