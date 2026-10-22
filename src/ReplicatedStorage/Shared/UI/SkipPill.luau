-- SkipPill (prompt 52 / 53, 23 Oct): the tutorial's and the unlock guides' SKIP. One small dark pill, always in the same
-- spot: top right, just under Roblox's top bar, left of the right-hand column (the machine controls, the Growth Spurt
-- card), on and off machines. "SKIP" in white chunky. Tap twice: the first tap turns it gold, "TAP AGAIN TO SKIP", for
-- 3 s; the second calls onSkip. confirm = false: one tap skips (the unlock guides).
--   SkipPill.new(name, onSkip, confirm?) -> { SetShown(on), Destroy() }
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local RightColumn = require(script.Parent.RightColumn)
local Audio = require(script.Parent.Parent.Audio)

local SkipPill = {}
SkipPill.Width, SkipPill.ArmedWidth, SkipPill.Height = 64, 168, 28
SkipPill.Right = RightColumn.Width + 12 + 8 -- px from the right edge: clear of the column (and the machine controls)

function SkipPill.new(name: string, onSkip: () -> (), confirm: boolean?)
	-- (the tutorial's / guide's own layer, 23: menu windows, 24+, cover it)
	local gui = Theme.ScreenGui({ Name = name, DisplayOrder = 23, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = Kit.Root(gui)
	local button = Kit.Button("Quiet", "Skip", { Name = "Skip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -SkipPill.Right, 0, 52), Parent = root },
		{ width = SkipPill.Width, height = SkipPill.Height, textSize = 12 })
	Kit.OnTopbar(function() button.Position = UDim2.new(1, -SkipPill.Right, 0, Kit.UnderTopbar(root)) end)
	local armedAt = -math.huge
	local function disarm()
		button.Size = UDim2.fromOffset(SkipPill.Width, SkipPill.Height)
		Kit.SetButton(button, "Quiet", "Skip")
	end
	button.Activated:Connect(function()
		Audio.PlayUI("Click")
		if confirm ~= false and os.clock() - armedAt > 3 then
			-- the first tap only asks (a stray tap never skips)
			armedAt = os.clock()
			button.Size = UDim2.fromOffset(SkipPill.ArmedWidth, SkipPill.Height)
			Kit.SetButton(button, "Gold", "Tap again to skip")
			task.delay(3, function()
				if button.Parent and os.clock() - armedAt >= 3 then disarm() end
			end)
			return
		end
		armedAt = -math.huge
		disarm()
		onSkip()
	end)
	return {
		SetShown = function(on: boolean) gui.Enabled = on end,
		Destroy = function() gui:Destroy() end,
	}
end

return SkipPill
