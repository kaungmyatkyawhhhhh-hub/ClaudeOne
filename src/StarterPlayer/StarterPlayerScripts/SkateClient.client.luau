-- SkateClient: the SKATE button, shown only outdoors in the town hub (Config.Town). Tapping it (or Q on a keyboard) asks
-- the server for the board (SkateService validates and builds it). Riding (momentum, carving, braking, ollies) and the
-- skater pose are below; steering is the normal movement controls, so phones use the usual thumbstick.
-- The button (owner, 14 Oct: easy to find): the owner's round skate art (Config/UI.SkateButton: circle, gold ring and
-- background are in the image) in a square ImageButton, "SKATE" under it. On phones it sits just left of Roblox's jump
-- button, the same size, centred on the same height (measured from TouchControlFrame.JumpButton, again only when the
-- screen size changes); on a PC bottom right with a "Q" key chip. Skating: the same art with a slowly pulsing gold ring
-- and "SKATING"; tap again to stop. Press = scale 0.92 + bounce + click. Hidden on a machine, on the menu and while a
-- window is open. The first time a player walks outdoors for 10 s, one hint bubble points at it (settings.skateHintSeen).
-- Starting to skate: a whoosh and a small dust puff.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared.Config.Town)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Horizontal = Enum.FillDirection.Horizontal

local Kit = require(Shared.UI.Kit)
local UIConfig = require(Shared.Config.UI)
local ClientData = require(Shared.ClientData)
local _ = RightColumn -- (the old Skate button in the right column is gone)

local BUTTON = {
	PcSize = 64,     -- mockup px on a PC / console
	PcEdge = 16,     -- from the bottom right corner
	Gap = 10,        -- left of the jump button
	Label = 14,      -- the SKATE / SKATING label under it
	HintAfter = 10,  -- seconds of walking outdoors before the one-time hint
}
local playerGui = player:WaitForChild("PlayerGui")
local gui = Theme.ScreenGui({ Name = "SkateButton", DisplayOrder = 6, Enabled = false, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None
gui.IgnoreGuiInset = true -- (the jump button's AbsolutePosition is in the same space)
local root = Kit.Root(gui)
local holder = Theme.New("Frame", { Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -BUTTON.PcEdge, 1, -BUTTON.PcEdge), Size = UDim2.fromOffset(BUTTON.PcSize, BUTTON.PcSize + BUTTON.Label), Parent = root })
local button = Theme.New("ImageButton", { Name = "Skate", Image = UIConfig.SkateButton, BackgroundTransparency = 1, AutoButtonColor = false,
	Size = UDim2.new(1, 0, 1, -BUTTON.Label), Parent = holder }, {
	Theme.New("UIAspectRatioConstraint", { AspectRatio = 1 }),
	Theme.New("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
-- skating: a gold ring just outside the art that pulses slowly (off = no stroke at all)
local ring = Theme.New("UIStroke", { Name = "Ring", Color = Theme.Colors.Gold, Thickness = 3, Transparency = 0.2, Enabled = false,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
local label = Kit.Text({ Name = "Label", Text = "SKATE", Font = "Title", TextSize = 11, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
	Size = UDim2.new(1, 24, 0, BUTTON.Label), Parent = holder })
-- the Q key chip (keyboards only)
local keyChip = Theme.Panel({ Name = "Key", Piece = "well", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(20, 20),
	Visible = false, ZIndex = 3, Parent = holder })
Kit.Text({ Name = "Q", Text = "Q", Font = "Title", TextSize = 12, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = keyChip })

local function skating()
	return player:GetAttribute("Skating") == true
end
local function toggle()
	Remotes.PlayerAction:FireServer("Skate", not skating())
end

-- press: 0.92 and bounce back (the art's one UIScale), a click
do
	local press = Theme.ButtonScale(button).press
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then Theme.Tween(press, { Value = 0.92 }, 0.08) end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then Theme.Tween(press, { Value = 1 }, 0.25, Enum.EasingStyle.Back) end
	end)
end
button.Activated:Connect(function()
	Audio.PlayUI("Click")
	toggle()
end)

-- Where: left of the jump button on touch screens (its size, its height), else the bottom right corner. Measured once per
-- screen size (only a jump button in the lower half of the screen counts: right after spawning it isn't placed yet).
local placedFor = nil -- the viewport size the touch spot was measured for
local function place()
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.zero
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local controls = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = controls and controls:FindFirstChild("JumpButton")
	local touch = UserInputService.TouchEnabled and jump ~= nil and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0
		and jump.AbsolutePosition.Y > root.AbsolutePosition.Y + root.AbsoluteSize.Y / 2
	keyChip.Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	if not touch then
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -BUTTON.PcEdge, 1, -BUTTON.PcEdge)
		holder.Size = UDim2.fromOffset(BUTTON.PcSize, BUTTON.PcSize + BUTTON.Label)
		return
	end
	if placedFor == view then return end
	local s = math.max(Kit.Scale(), 0.01)
	local size = jump.AbsoluteSize.X / s
	local centreY = (jump.AbsolutePosition.Y + jump.AbsoluteSize.Y / 2 - root.AbsolutePosition.Y) / s
	local right = (jump.AbsolutePosition.X - root.AbsolutePosition.X) / s - BUTTON.Gap
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Size = UDim2.fromOffset(size, size + BUTTON.Label)
	holder.Position = UDim2.fromOffset(right, centreY - size / 2)
	placedFor = view
end
do
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() placedFor = nil end) end
end

-- ON / OFF look; the ring pulses slowly while skating
local function refreshLook()
	local on = skating()
	ring.Enabled = on
	label.Text = if on then "SKATING" else "SKATE"
	label.TextColor3 = if on then Theme.Colors.Gold else Theme.Colors.Text
end
task.spawn(function()
	while true do
		if ring.Enabled and not Theme.ReducedMotion() then
			Theme.Tween(ring, { Transparency = 0.65, Thickness = 5 }, 0.9, Enum.EasingStyle.Sine)
			task.wait(0.9)
			Theme.Tween(ring, { Transparency = 0.15, Thickness = 3 }, 0.9, Enum.EasingStyle.Sine)
			task.wait(0.9)
		else
			task.wait(0.3)
		end
	end
end)

-- Q toggles it (while the button is there)
ContextActionService:BindAction("SkateToggle", function(_, state)
	if state == Enum.UserInputState.Begin and gui.Enabled then toggle() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q)

-- shown outdoors (or while skating), never on a machine, on the menu or under a window
local function refresh()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local outdoors = rootPart ~= nil and Town.IsOutdoors(rootPart.Position)
	local blocked = UIBus.MenuOpen or UIBus.Training or UIBus.CoverOpen(playerGui)
	gui.Enabled = (outdoors or skating()) and not blocked
	if gui.Enabled then place() end
	refreshLook()
end
player:GetAttributeChangedSignal("Skating"):Connect(refresh)

-- the one-time hint: after 10 s of walking outdoors, a small bubble above the button (saved, never again)
local hint = Theme.Panel({ Name = "Hint", Piece = "hud_box", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -8), Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 4, Parent = holder }, {
	Theme.New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
})
Kit.Text({ Name = "Text", Text = "Tap to skate - get around faster!", Font = "Body", TextSize = 12, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 4, Parent = hint })
local walked = 0
local hintDone = false
local function showHint()
	hintDone = true
	Remotes.PlayerAction:FireServer("SetSettings", { skateHintSeen = true })
	hint.Visible = true
	Theme.Fade(hint, true, 0.25)
	task.delay(6, function()
		local tween = Theme.Fade(hint, false, 0.4)
		if tween then tween.Completed:Connect(function() hint.Visible = false end) else hint.Visible = false end
	end)
end

task.spawn(function()
	local data = ClientData.Get()
	hintDone = (data.settings or {}).skateHintSeen == true
	while true do
		task.wait(0.5)
		refresh()
		if not hintDone and gui.Enabled and not skating() then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then walked += 0.5 end
			if walked >= BUTTON.HintAfter then showHint() end
		end
	end
end)

-- starting to skate: a whoosh and a little dust puff at the feet
player:GetAttributeChangedSignal("Skating"):Connect(function()
	if not skating() then return end
	Audio.PlayUI("Whoosh")
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then return end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -(humanoid.HipHeight + rootPart.Size.Y / 2), 0)
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(205, 196, 180))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.4) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(3, 6)
	dust.SpreadAngle = Vector2.new(180, 10)
	dust.Drag = 4
	dust.Rate = 0
	dust.Parent = attachment
	attachment.Parent = rootPart
	dust:Emit(14)
	task.delay(1, function() attachment:Destroy() end)
end)

local function angleTo(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

------------------------------------------------------------------------
-- RIDING (my own board). The board has momentum: holding a direction pushes you up to the top speed and the board CARVES
-- toward it (it can't snap around: the faster you go, the wider the turn); letting go coasts and slowly rolls to a stop;
-- holding the opposite way brakes. Jump = ollie. Downhill speeds you up, uphill slows you down, a wall stops you.
-- How: the Humanoid stands still (WalkSpeed 0) but still reports what the player asks for (MoveDirection, from keys, the
-- phone thumbstick or a gamepad, whatever Roblox's control scripts use); a LinearVelocity on the root rolls the board along its
-- heading (horizontal only, so gravity and jumping stay the Humanoid's).
------------------------------------------------------------------------
local RIDE = {
	Push = 16,      -- studs/s² while pushing
	Coast = 2.2,    -- studs/s² rolling friction when you let go
	Brake = 26,     -- studs/s² holding the opposite way
	Slope = 0.9,    -- how much hills speed you up / slow you down
	TurnSlow = 7,   -- radians/s the board can turn when nearly stopped
	TurnFast = 2.1, -- radians/s at top speed (wide carves)
	MinSpeed = 0.4,
}

local ride = nil -- { heading, speed, walkSpeed, slowFor, pushing, mover, grind, grindReady, sparks }

------------------------------------------------------------------------
-- GRINDING. The skate park's rails are tagged "GrindRail" (a round bar lying flat, its axis = local X, length Size.X).
-- Ollie onto one while rolling roughly along it and the board locks on: it slides along the bar (a little friction,
-- steering ignored) until it runs off an end, slows down, or you jump off. The bar is solid, so the Humanoid stands on it
-- (height and jumping stay normal); each frame the board is pulled onto the bar's line and points along it. Sparks fly
-- from the board while grinding.
------------------------------------------------------------------------
local GRIND = {
	Reach = 1.3,     -- studs sideways from the bar's line to lock on
	Above = 1.6,     -- the feet may be this far above the bar's top (landing on it) ...
	Below = 0.6,     -- ... or this far below it (catching its edge: the board is lifted on)
	Align = 0.45,    -- |cos| between the board and the bar (about 63 degrees or less)
	MinSpeed = 4,
	MaxRise = 4,     -- no lock-on while still going up fast from the ollie
	Friction = 1.6,  -- studs/s² lost while sliding
	Cooldown = 0.35, -- seconds after leaving a bar before the next lock-on
}
local rails = {} -- [part] = true (streamed in / out)
local function trackRail(part)
	if part:IsA("BasePart") then rails[part] = true end
end
for _, part in ipairs(CollectionService:GetTagged("GrindRail")) do trackRail(part) end
CollectionService:GetInstanceAddedSignal("GrindRail"):Connect(trackRail)
CollectionService:GetInstanceRemovedSignal("GrindRail"):Connect(function(part) rails[part] = nil end)

local function feetY(humanoid, root): number
	return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
end

-- the bar under / near the board that it can lock onto, or nil
local function findRail(humanoid, root, forward: Vector3)
	local feet = feetY(humanoid, root)
	local best, bestSide = nil, math.huge
	for part in pairs(rails) do
		if part.Parent then
			local axis = part.CFrame.RightVector
			local half = part.Size.X / 2
			local t = (root.Position - part.Position):Dot(axis)
			if math.abs(t) < half - 0.3 then
				local onLine = part.Position + axis * t
				local side = ((root.Position - onLine) * Vector3.new(1, 0, 1)).Magnitude
				local top = onLine.Y + part.Size.Y / 2
				local flat = axis * Vector3.new(1, 0, 1)
				local align = if flat.Magnitude > 0.01 then math.abs(forward:Dot(flat.Unit)) else 0
				if side < GRIND.Reach and side < bestSide and feet > top - GRIND.Below and feet < top + GRIND.Above and align > GRIND.Align then
					best, bestSide = { part = part, axis = axis, half = half, top = top }, side
				end
			end
		end
	end
	return best
end

-- sparks under the board while grinding (my own board, this client only)
local function setSparks(root, humanoid, on: boolean)
	if not ride then return end
	if on and not ride.sparks then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GrindSparks"
		attachment.Position = Vector3.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 236, 170), Color3.fromRGB(255, 150, 60))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.18, 0.35)
		emitter.Speed = NumberRange.new(5, 9)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Acceleration = Vector3.new(0, -30, 0)
		emitter.Drag = 2
		emitter.Rate = 45
		emitter.Parent = attachment
		attachment.Parent = root
		ride.sparks = attachment
	end
	if ride.sparks then
		local emitter = ride.sparks:FindFirstChildOfClass("ParticleEmitter")
		if emitter then emitter.Enabled = on end
	end
end

-- the direction the player is asking for, flat in the world (nil when the stick / keys are idle)
local function inputDirection(humanoid): Vector3?
	-- Studio test hook: a "TestSkateMove" Vector3 attribute on Workspace stands in for the stick (scripted ride tests)
	local test = if RunService:IsStudio() then workspace:GetAttribute("TestSkateMove") else nil
	if typeof(test) == "Vector3" and test.Magnitude > 0.1 then return (test * Vector3.new(1, 0, 1)).Unit end
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if move.Magnitude < 0.15 then return nil end
	return move.Unit
end

local function headingVector(heading: number): Vector3
	return Vector3.new(-math.sin(heading), 0, -math.cos(heading))
end

local function startRide(humanoid, root)
	local look = root.CFrame.LookVector
	ride = {
		heading = math.atan2(-look.X, -look.Z),
		speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
		walkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else 16,
		slowFor = 0,
		pushing = false,
		grind = nil, -- { part, axis, half, top, dir } while on a bar
		grindReady = 0, -- os.clock() after which the next lock-on may happen
	}
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	local attachment = Instance.new("Attachment")
	attachment.Name = "SkateAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "SkateMover"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	-- no force cap (owner's bug, 14 Oct: a fixed 60000 lost to the Humanoid's own grip on big characters, a 7'0" rider
	-- topped out at ~14 studs/s instead of 32); walls still stop the board (the "a wall stops you" check below)
	mover.ForceLimitsEnabled = false
	mover.PlaneVelocity = Vector2.zero
	mover.Parent = root
	ride.mover, ride.attachment = mover, attachment
end

local function stopRide()
	if not ride then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = ride.walkSpeed
	end
	if ride.mover then ride.mover:Destroy() end
	if ride.attachment then ride.attachment:Destroy() end
	if ride.sparks then ride.sparks:Destroy() end
	ride = nil
	player:SetAttribute("SkatePushing", nil)
end

RunService:BindToRenderStep("SkateRide", Enum.RenderPriority.Input.Value + 1, function(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not skating() or not humanoid or not root or humanoid.Health <= 0 then
		stopRide()
		return
	end
	if not ride or not ride.mover.Parent then
		stopRide()
		startRide(humanoid, root)
	end
	dt = math.min(dt, 0.1)
	local top = player:GetAttribute("SkateSpeed")
	top = if type(top) == "number" then top else 32
	-- taller riders go faster, so they also push, brake and turn faster (Config.Skate): the same feel at every size
	local factor = player:GetAttribute("SkateFactor")
	factor = if type(factor) == "number" then factor else 1
	local velocity = root.AssemblyLinearVelocity
	local now = os.clock()
	-- grinding: let go of the bar, or lock onto one
	if ride.grind then
		local g = ride.grind
		local t = (root.Position - g.part.Position):Dot(g.axis)
		if not g.part.Parent or math.abs(t) > g.half + 0.2 or ride.speed < 2 or velocity.Y > 6 or feetY(humanoid, root) < g.top - 0.9 then
			ride.grind = nil
			ride.grindReady = now + GRIND.Cooldown
			setSparks(root, humanoid, false)
		end
	elseif ride.speed > GRIND.MinSpeed and now > ride.grindReady and velocity.Y < GRIND.MaxRise then
		local g = findRail(humanoid, root, headingVector(ride.heading))
		if g then
			-- point along the bar the way we were going; catching its edge lifts the board onto it
			g.dir = if headingVector(ride.heading):Dot(g.axis) >= 0 then g.axis else -g.axis
			ride.heading = math.atan2(-g.dir.X, -g.dir.Z)
			local standY = g.top + humanoid.HipHeight + root.Size.Y / 2 + 0.05
			if root.Position.Y < standY then
				root.CFrame = CFrame.new(root.Position.X, standY, root.Position.Z) * CFrame.Angles(0, ride.heading, 0)
				root.AssemblyLinearVelocity = velocity * Vector3.new(1, 0, 1)
			end
			ride.grind = g
			setSparks(root, humanoid, true)
		end
	end
	local want = if ride.grind then nil else inputDirection(humanoid)
	local forward = headingVector(ride.heading)
	ride.pushing = false
	if ride.grind then
		-- on the bar: no steering, a little friction
		ride.speed = math.max(ride.speed - GRIND.Friction * dt, 0)
	elseif want then
		local agree = want:Dot(forward)
		if agree < -0.55 and ride.speed > 3 then
			-- holding the opposite way: brake (the board keeps pointing where it goes)
			ride.speed = math.max(ride.speed - RIDE.Brake * factor * dt, 0)
		else
			-- carve toward the input: the turn rate falls with speed
			local rate = (RIDE.TurnSlow + (RIDE.TurnFast - RIDE.TurnSlow) * math.clamp(ride.speed / top, 0, 1)) * factor
			local delta = angleTo(ride.heading, math.atan2(-want.X, -want.Z))
			ride.heading += math.clamp(delta, -rate * dt, rate * dt)
			if agree > 0.3 and ride.speed < top then
				ride.speed = math.min(ride.speed + RIDE.Push * factor * dt, top)
				ride.pushing = true
			end
		end
	else
		ride.speed = math.max(ride.speed - RIDE.Coast * factor * dt, 0)
	end
	-- hills: going down speeds you up, climbing slows you down
	if humanoid.FloorMaterial ~= Enum.Material.Air and not ride.grind then
		ride.speed = math.clamp(ride.speed - velocity.Y * RIDE.Slope * dt, 0, top * 1.35)
	end
	-- a wall (or anything solid) stops the board instead of letting it push on forever
	forward = headingVector(ride.heading)
	local actual = (velocity * Vector3.new(1, 0, 1)):Dot(forward)
	if ride.speed > 6 and actual < ride.speed * 0.45 and not ride.grind then
		ride.slowFor += dt
		if ride.slowFor > 0.25 then
			ride.speed = math.max(actual, 0)
			ride.slowFor = 0
		end
	else
		ride.slowFor = 0
	end
	-- apply: face the board's heading and roll at our speed (on a bar: pulled onto its line)
	local position = root.Position
	if ride.grind then
		local g = ride.grind
		local onLine = g.part.Position + g.axis * (position - g.part.Position):Dot(g.axis)
		position = Vector3.new(onLine.X, position.Y, onLine.Z)
	end
	root.CFrame = CFrame.new(position) * CFrame.Angles(0, ride.heading, 0)
	if ride.speed < RIDE.MinSpeed then ride.speed = 0 end
	humanoid.WalkSpeed = 0
	local roll = forward * ride.speed
	ride.mover.PlaneVelocity = Vector2.new(roll.X, roll.Z)
	if (player:GetAttribute("SkatePushing") == true) ~= ride.pushing then
		player:SetAttribute("SkatePushing", ride.pushing or nil)
	end
end)

------------------------------------------------------------------------
-- THE SKATER'S POSE, for every player you can see on a board (only on this client; set on the joints' Transforms after the
-- run animation, like the emote poses). Regular stance: body side-on to the board (chest to the right of travel, left foot
-- forward), knees bent and deeper at speed, arms out for balance, head looking down the board. Pushing: the back foot steps
-- off and sweeps the ground. Carving: the rider leans onto the toes or heels and the board tilts with them. Ollie: the nose
-- pops up and the knees tuck. Joint signs (measured in Studio): Root/Waist +X leans back, hip +X brings the thigh forward,
-- knee -X bends, shoulder +Z (right) / -Z (left) raises the arm to the side, elbow +X bends.
------------------------------------------------------------------------
local rad, Angles = math.rad, CFrame.Angles
local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	RAnkle = { "RightFoot", "RightAnkle" },
	LAnkle = { "LeftFoot", "LeftAnkle" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RWrist = { "RightHand", "RightWrist" },
	LWrist = { "LeftHand", "LeftWrist" },
}
local function set(character, key, cframe)
	local spec = JOINTS[key]
	local part = character:FindFirstChild(spec[1])
	local m = part and part:FindFirstChild(spec[2])
	if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m.Transform = cframe end
end
local function boardJoint(character)
	local board = character:FindFirstChild("Skateboard")
	local deck = board and board:FindFirstChild("Deck")
	return deck and deck:FindFirstChild("BoardJoint")
end

local poses = setmetatable({}, { __mode = "k" }) -- [character] = smoothed values (weak: a character that is gone must not be kept alive)
local function follow(value, target, rate, dt)
	return value + (target - value) * math.min(1, dt * rate)
end

local function pose(other, character, root, dt)
	local s = poses[character]
	if not s then
		s = { speed = 0, carve = 0, crouch = 0, push = 0, pushPhase = 0, air = 0, pop = 0, grind = 0, lastYaw = nil }
		poses[character] = s
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = (velocity * Vector3.new(1, 0, 1)).Magnitude
	-- turn rate from the heading change (AutoRotate is off while skating, so angular velocity isn't reliable)
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = if s.lastYaw then angleTo(s.lastYaw, yaw) / math.max(dt, 1 / 240) else 0
	s.lastYaw = yaw
	local top = other:GetAttribute("SkateSpeed")
	top = if type(top) == "number" then top else 32
	-- pushing: told by the rider's own client, or guessed from speeding up (other players)
	local pushing = other:GetAttribute("SkatePushing") == true
	if other ~= player and not pushing then
		pushing = speed > s.speed + 4 * dt and speed < top * 0.97 and speed > 0.5
	end
	s.speed = follow(s.speed, speed, 6, dt)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local airborne = (humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air) or math.abs(velocity.Y) > 6
	s.air = follow(s.air, if airborne then 1 else 0, 10, dt)
	-- grinding: my own board knows; for others, a board rolling on metal (the rails) is a grind
	local grinding = if other == player then (ride ~= nil and ride.grind ~= nil)
		else (humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Metal and speed > 2)
	s.grind = follow(s.grind, if grinding then 1 else 0, 10, dt)
	if grinding then pushing = false end
	-- the ollie pop: a quick nose-up when the board leaves the ground going up
	if airborne and velocity.Y > 8 and s.pop <= 0 then s.pop = 1 end
	s.pop = math.max(s.pop - dt * 3.2, 0)
	s.push = follow(s.push, if pushing and not airborne then 1 else 0, 8, dt)
	if s.push > 0.05 then s.pushPhase = (s.pushPhase + dt * 1.6) % 1 end
	s.carve = follow(s.carve, math.clamp(-turn * 0.16, -1, 1) * math.clamp(speed / 12, 0, 1), 7, dt)
	s.crouch = follow(s.crouch, math.clamp(speed / top, 0, 1), 3, dt)

	local tuck = s.air * 0.6
	local knee = rad(22) + rad(16) * s.crouch + rad(38) * tuck + rad(14) * s.grind -- (lower on a rail)
	local flex = knee * 0.5
	-- the pelvis drops so the feet stay on the deck while the knees bend
	local thigh = character:FindFirstChild("LeftUpperLeg")
	local shin = character:FindFirstChild("LeftLowerLeg")
	local l1 = if thigh then thigh.Size.Y else 1.3
	local l2 = if shin then shin.Size.Y else 1.1
	local drop = l1 * (1 - math.cos(flex)) + l2 * (1 - math.cos(knee - flex))
	-- carving leans onto the toes (turning toward the chest, i.e. right) or onto the heels
	local lean = s.carve * rad(16)
	set(character, "Root", CFrame.new(0, -drop, 0) * Angles(0, rad(-90), 0) * Angles(-lean - rad(6), 0, 0)) -- (= rootPitch below)
	-- the upper body twists back a little toward the nose; the head looks down the board
	set(character, "Waist", Angles(rad(4), rad(18), 0))
	set(character, "Neck", Angles(0, rad(62), 0))
	-- legs: spread along the board (left/front foot over the front truck, right/back foot over the tail)
	local spread = rad(13)
	local rootPitch = -lean - rad(6)
	local frontHip = flex + lean + rad(6)
	set(character, "LHip", Angles(frontHip, 0, -spread))
	-- the back leg pushes: steps down beside the board, sweeps back along the ground, comes back up
	local phase = s.pushPhase * 2 * math.pi
	local sweep = math.sin(phase)
	local down = math.max(0, math.sin(phase + 0.6))
	local backHip = flex + lean + rad(6) - s.push * (rad(18) * sweep + rad(8))
	local backKnee = knee * (1 - s.push * 0.75 * down)
	local frontKnee = knee + s.push * rad(20) * down -- the front knee bends more while the back foot reaches down
	set(character, "RHip", Angles(backHip, 0, spread + s.push * rad(6)))
	set(character, "RKnee", Angles(-backKnee, 0, 0))
	set(character, "LKnee", Angles(-frontKnee, 0, 0))
	-- feet flat on the deck: the ankles undo the pelvis, hip and knee angles (they all turn the same way)
	set(character, "LAnkle", Angles(-(rootPitch + frontHip - frontKnee), 0, 0))
	set(character, "RAnkle", Angles(-(rootPitch + backHip - backKnee), 0, 0))
	-- arms out for balance (more in turns and in the air), elbows soft
	local balance = rad(38) + math.abs(s.carve) * rad(18) + s.air * rad(22) + s.grind * rad(16)
	set(character, "LShoulder", Angles(rad(8), 0, -balance - s.carve * rad(10)))
	set(character, "RShoulder", Angles(-rad(8), 0, balance - s.carve * rad(10)))
	set(character, "LElbow", Angles(rad(18), 0, 0))
	set(character, "RElbow", Angles(rad(18), 0, 0))
	set(character, "LWrist", CFrame.identity)
	set(character, "RWrist", CFrame.identity)
	-- the board tilts with the carve and pops its nose on an ollie
	local joint = boardJoint(character)
	if joint then
		local pop = if s.pop > 0 then math.sin((1 - s.pop) * math.pi) else 0
		joint.Transform = CFrame.new(0, s.air * 0.08, 0) * Angles(lean * 0.6, 0, rad(16) * pop)
	end
end

local function clearPose(character)
	poses[character] = nil
	for key in pairs(JOINTS) do set(character, key, CFrame.identity) end
end

-- The speed zoom is an OFFSET we add to whatever field of view the camera has (menus, pose punches, machines change it too):
-- we only ever add or take back our own part, and never pull the camera to a remembered value.
local fovOffset = 0
RunService.Stepped:Connect(function(_, dt)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if other:GetAttribute("Skating") == true and character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then pose(other, character, root, dt) end
		elseif character and poses[character] then
			clearPose(character)
		end
	end
	-- a little more field of view at speed for me
	local camera = workspace.CurrentCamera
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if camera then
		local want = 0
		if mine and skating() then
			local speed = (mine.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			want = math.clamp((speed - 16) * 0.4, 0, 8)
		end
		local nextOffset = fovOffset + (want - fovOffset) * math.min(1, dt * 4)
		if math.abs(nextOffset - fovOffset) > 0.001 then
			camera.FieldOfView += nextOffset - fovOffset
			fovOffset = nextOffset
		end
	end
end)
