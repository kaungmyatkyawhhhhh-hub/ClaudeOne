-- BeachGymSails: the two shade sails over the beach gym's machine area, as smooth triangles (the first version was
-- stacked strips with a stepped edge that looked like a wire outline from far away). Run once in Studio with Kit +
-- TownKit loaded next to it, then save:  require(game.ServerStorage._Builders.BeachGymSails).Build()
-- Uses the four SailPole parts in Workspace.Town.BeachGym (two tall, two short, at the corners) and replaces every
-- part named "Sail". Each sail is shrunk a little toward its middle (a gap between them and the poles) and tied to
-- each pole with a short rope.
local Kit = require(script.Parent.Kit)
local TownKit = require(script.Parent.TownKit)

local Sails = {}

local M = Enum.Material
local CREAM, CORAL, ROPE = Kit.hex("#F2EADB"), Kit.hex("#E59A7A"), Kit.hex("#CDBA94")
local INSET = 0.07   -- how much each triangle shrinks toward its middle
local BELOW_TOP = 0.6 -- studs the tie point sits below the pole top

function Sails.Build()
	local gym = workspace.Town.BeachGym
	local poles = {}
	for _, part in ipairs(gym:GetChildren()) do
		if part.Name == "SailPole" and part:IsA("BasePart") then
			local top = part.Position + Vector3.yAxis * (part.Size.X / 2) -- the poles are upright cylinders (length along X)
			table.insert(poles, { part = part, top = top - Vector3.yAxis * BELOW_TOP, tall = part.Size.X > 16 })
		end
	end
	assert(#poles == 4, "expected 4 SailPole parts, found " .. #poles)
	local tall, short = {}, {}
	for _, pole in ipairs(poles) do table.insert(pole.tall and tall or short, pole) end
	assert(#tall == 2 and #short == 2, "expected 2 tall and 2 short poles")

	for _, part in ipairs(gym:GetChildren()) do
		if part.Name == "Sail" or part.Name == "SailRope" then part:Destroy() end
	end

	-- one sail per short pole: tall A, tall B and that short pole (cream on one side, coral on the other)
	for index, low in ipairs(short) do
		local a, b, c = tall[1].top, tall[2].top, low.top
		local middle = (a + b + c) / 3
		local function inset(point) return point:Lerp(middle, INSET) end
		local color = index == 1 and CREAM or CORAL
		local w1, w2 = TownKit.triangle(gym, "Sail", inset(a), inset(b), inset(c), 0.08, color, M.Fabric)
		w1.CastShadow, w2.CastShadow = true, true
		for _, corner in ipairs({ a, b, c }) do
			local tied = inset(corner)
			TownKit.p(gym, "SailRope", Vector3.new(0.06, 0.06, (tied - corner).Magnitude), CFrame.lookAt((tied + corner) / 2, corner), ROPE, M.Fabric)
		end
	end
	return true
end

return Sails
