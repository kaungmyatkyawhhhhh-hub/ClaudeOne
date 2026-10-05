-- Mirror builder (run once in Studio; see tools/bake.md): the progress mirror on the entrance hall's right wall,
-- facing into the hall, with its "Progress mirror" label and the Look prompt ("MirrorPrompt").
-- Output: Workspace.ProgressMirror. MirrorService wires the prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Mirror = {}

local SPOT = CFrame.lookAt(Vector3.new(9.85, 4.3, 5), Vector3.new(0, 4.3, 5))

function Mirror.Build(Workspace)
	local model = Kit.fresh(Workspace, "Model", "ProgressMirror")
	local frame = Kit.hex("#1E1E22")
	local function piece(name, size, offset, color, material, props)
		local p = Kit.part(model, name, size, SPOT * offset, color, material, props)
		p.CastShadow = false
		return p
	end
	piece("Back", Vector3.new(4.4, 7.4, 0.2), CFrame.new(0, 0, 0.1), frame, Enum.Material.Metal)
	local glass = piece("Glass", Vector3.new(4, 7, 0.1), CFrame.new(0, 0, -0.05), Kit.hex("#C9D3D8"), Enum.Material.Glass,
		{ Reflectance = 0.55, Transparency = 0.1, CanCollide = false })
	for _, x in ipairs({ -2.15, 2.15 }) do
		piece("Side", Vector3.new(0.15, 7.4, 0.3), CFrame.new(x, 0, -0.05), frame, Enum.Material.Metal, { CanCollide = false })
	end
	for _, y in ipairs({ -3.65, 3.65 }) do
		piece("Edge", Vector3.new(4.4, 0.15, 0.3), CFrame.new(0, y, -0.05), frame, Enum.Material.Metal, { CanCollide = false })
	end
	Kit.sign(model, "Label", Vector3.new(4, 0.7, 0.05), SPOT * CFrame.new(0, 4.2, -0.05), "Progress mirror", Theme.Colors.Text, frame, 50)
	Kit.prompt(glass, "MirrorPrompt", "Look", "Progress mirror", 8)
	return model
end

return Mirror
