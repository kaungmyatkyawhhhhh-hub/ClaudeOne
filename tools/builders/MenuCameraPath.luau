-- MenuCameraPath (prompt 60, 23 Oct): Workspace.MenuCameraPath, the title screen's live camera flyover (Shared/UI/MenuFlyover,
-- started by MenuClient). A Model (ModelStreamingMode Persistent, so every client has the points at join) with one Folder per
-- shot, played in name order: "Shot1_Town" .. "Shot6_TownRise". Each shot has two invisible parts, "Start" and "End": the
-- camera glides from Start to End, looking out of each part's FRONT face (move / turn them in Studio to change a shot).
-- A shot's "Seconds" attribute is its length (default 9). Nothing collides, casts shadows or can be clicked.
-- Run once in Studio (command bar / MCP): require(<this module>).Build(). Running it again rebuilds the points from the list
-- below (a moved point is lost: move the list's numbers too, or don't rebuild).
local MenuCameraPath = {}

-- { name, seconds, start = { camera position, looks at }, finish = { camera position, looks at } }
MenuCameraPath.Shots = {
	{ "Shot1_Town", 9, { Vector3.new(-90, 75, 230), Vector3.new(10, 5, 60) }, { Vector3.new(90, 70, 230), Vector3.new(10, 5, 50) } },
	{ "Shot2_PumpShop", 9, { Vector3.new(-25, 22, 150), Vector3.new(-61, 18, 122) }, { Vector3.new(-30, 19, 92), Vector3.new(-61, 18, 116) } },
	-- (through the street window at x 40, above the towel rack; the x 30 window has Coach Dex's desk right behind it)
	{ "Shot3_StarterGymWindow", 9, { Vector3.new(40, 6.5, 24), Vector3.new(40, 5, -20) }, { Vector3.new(39, 6.5, -14), Vector3.new(32, 4, -45) } },
	{ "Shot4_BeachGym", 10, { Vector3.new(-50, 30, 140), Vector3.new(17, 6, 200) }, { Vector3.new(60, 26, 145), Vector3.new(17, 6, 205) } },
	{ "Shot5_ProGymFront", 9, { Vector3.new(118, 18, 42), Vector3.new(80, 10, -4) }, { Vector3.new(64, 15, 38), Vector3.new(88, 10, -4) } },
	{ "Shot6_TownRise", 10, { Vector3.new(40, 14, 48), Vector3.new(10, 8, 0) }, { Vector3.new(10, 85, 210), Vector3.new(10, 0, 30) } },
}

local function point(name: string, from: Vector3, at: Vector3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(1, 1, 2)
	part.CFrame = CFrame.lookAt(from, at)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

function MenuCameraPath.Build()
	local old = workspace:FindFirstChild("MenuCameraPath")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "MenuCameraPath"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, shot in ipairs(MenuCameraPath.Shots) do
		local folder = Instance.new("Folder")
		folder.Name = shot[1]
		folder:SetAttribute("Seconds", shot[2])
		point("Start", shot[3][1], shot[3][2], folder)
		point("End", shot[4][1], shot[4][2], folder)
		folder.Parent = model
	end
	model.Parent = workspace
	return model
end

return MenuCameraPath
