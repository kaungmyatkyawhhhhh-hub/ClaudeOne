-- Guard: server-side protection for everything a client can trigger.
--   Guard.Allow(player, key, perSecond, burst)  token-bucket rate limit per player and key (true = go ahead)
--   Guard.Near(player, target, maxDistance)     is the player's character within reach of a part/attachment/position
--   Guard.OnTriggered(prompt, handler, opts)    connects a ProximityPrompt with a server distance check and a rate
--                                               limit, so a modified client can't trigger prompts from across the map
--   Guard.Remote(remote, key, perSecond, burst, handler)  OnServerEvent with a per-player rate limit
-- Every check fails closed (no character, no player data → no action).
local Players = game:GetService("Players")

local Guard = {}

local buckets = {} -- [player] = { [key] = { tokens, time } }

-- Extra studs on top of a prompt's MaxActivationDistance (latency, the character's own size).
Guard.DistanceSlack = 6

function Guard.Allow(player, key, perSecond, burst)
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local bucket = mine[key]
	if not bucket then
		bucket = { tokens = burst, time = now }
		mine[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.time) * perSecond)
	bucket.time = now
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end

local function positionOf(target)
	if typeof(target) == "Vector3" then return target end
	if typeof(target) ~= "Instance" then return nil end
	if target:IsA("BasePart") then return target.Position end
	if target:IsA("Attachment") then return target.WorldPosition end
	if target:IsA("Model") then return target:GetPivot().Position end
	return nil
end

function Guard.Near(player, target, maxDistance)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = positionOf(target)
	if not root or not position then return false end
	return (root.Position - position).Magnitude <= maxDistance
end

-- opts: { perSecond = 2, burst = 3, slack = Guard.DistanceSlack }
function Guard.OnTriggered(prompt, handler, opts)
	opts = opts or {}
	local key = "prompt:" .. prompt:GetFullName()
	return prompt.Triggered:Connect(function(player)
		if not Guard.Near(player, prompt.Parent, prompt.MaxActivationDistance + (opts.slack or Guard.DistanceSlack)) then return end
		if not Guard.Allow(player, key, opts.perSecond or 2, opts.burst or 3) then return end
		handler(player)
	end)
end

function Guard.Remote(remote, key, perSecond, burst, handler)
	return remote.OnServerEvent:Connect(function(player, ...)
		if not Guard.Allow(player, "remote:" .. key, perSecond, burst) then return end
		handler(player, ...)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return Guard
