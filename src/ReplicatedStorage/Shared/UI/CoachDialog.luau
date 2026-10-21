-- CoachDialog (prompt 39, 22 Oct): the tutorial's Coach Dex dialog box, moved out of TutorialClient unchanged (owner: keep
-- it as it is) so the unlock guides (GuideClient) use the same box: a live portrait of the Coach NPC, "Coach Dex · Reward
-- (coin) 50", the words, "Tap to continue (1/3)".
--   CoachDialog.new(parent, reward?) -> dialog   (parent: a Kit.Root; reward: the coins shown, nil = no reward)
--   dialog.frame                                 the panel (TutorialClient lifts it above the hotbar)
--   dialog.Show(pages, onDone?)                  shows the pages; a tap goes to the next; after the last: onDone()
--   dialog.Hide()  dialog.IsShowing()  dialog.SetReward(coins?)
local CollectionService = game:GetService("CollectionService")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Audio = require(script.Parent.Parent.Audio)
local Quests = require(script.Parent.Parent.Config.Quests)

local New, Colors = Theme.New, Theme.Colors

local CoachDialog = {}

-- the Coach's face: a copy of the Coach NPC in the portrait (no scripts, prompts or labels)
local function fillPortrait(portrait: ViewportFrame)
	task.spawn(function()
		local coach = CollectionService:GetTagged("Coach")[1]
		local waited = 0
		while not coach and waited < 15 do
			task.wait(0.5)
			waited += 0.5
			coach = CollectionService:GetTagged("Coach")[1]
		end
		-- (owner, 15 Oct: Dex's body is rebuilt by the server after he loads; copy him once his face head and his muscle
		-- meshes are there, so the portrait shows the new Dex, not the plain body)
		waited = 0
		while coach and (not coach:FindFirstChild("ClassicHead") or not coach:FindFirstChild("MuscleMeshes")) and waited < 30 do
			task.wait(0.5)
			waited += 0.5
		end
		if coach then task.wait(1) end
		local head = coach and coach:FindFirstChild("Head")
		if not head then
			Pieces.Image("trainer_exp", { Size = UDim2.fromScale(1, 1), Parent = portrait })
			return
		end
		local ok = pcall(function()
			coach.Archivable = true
			for _, d in ipairs(coach:GetDescendants()) do d.Archivable = true end
			local copy = coach:Clone()
			for _, d in ipairs(copy:GetDescendants()) do
				if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") then d:Destroy() end
			end
			local world = New("WorldModel", { Parent = portrait })
			copy.Parent = world
			local copyHead = copy:FindFirstChild("Head") :: BasePart
			local camera = New("Camera", { FieldOfView = 30, Parent = portrait })
			local face = copyHead.CFrame
			-- head and his huge shoulders (owner, 15 Oct: the new Dex is far wider, so the camera sits further back)
			camera.CFrame = CFrame.lookAt(face.Position + face.LookVector * 9 + Vector3.new(0, 0.6, 0), face.Position - Vector3.new(0, 0.9, 0))
			portrait.CurrentCamera = camera
		end)
		if not ok then Pieces.Image("trainer_exp", { Size = UDim2.fromScale(1, 1), Parent = portrait }) end
	end)
end

function CoachDialog.new(parent: Instance, reward: number?)
	local dialog = Theme.Panel({ Name = "CoachDialog", Clickable = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(540, 92), Visible = false, Parent = parent }, {})
	local portrait = New("ViewportFrame", { Name = "Portrait", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Colors.Blue, Ambient = Color3.fromRGB(190, 190, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -0.6, -1),
		Parent = dialog }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }),
	})
	local nameRow = New("Frame", { Name = "NameRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(94, 7), Size = UDim2.new(1, -104, 0, 22), Parent = dialog }, {
		Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local who = Kit.Text({ LayoutOrder = 1, Text = Quests.CoachName .. " · Reward", Font = "Title", TextSize = 17, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X, Parent = nameRow })
	local coin = Kit.Coin(17, { LayoutOrder = 2, Parent = nameRow })
	local amount = Kit.Text({ LayoutOrder = 3, Text = tostring(reward or 0), Font = "Title", TextSize = 17, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X, Parent = nameRow })
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(94, 30), Size = UDim2.new(1, -106, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = dialog })
	local foot = Kit.Text({ Name = "Continue", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(94, 70), Size = UDim2.new(1, -106, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = dialog })
	fillPortrait(portrait)

	local api = { frame = dialog }
	local pages, index, onDone = nil, 0, nil

	function api.SetReward(coins: number?)
		who.Text = Quests.CoachName .. (if coins and coins > 0 then " · Reward" else "")
		coin.Visible = coins ~= nil and coins > 0
		amount.Visible = coins ~= nil and coins > 0
		amount.Text = tostring(coins or 0)
	end
	api.SetReward(reward)

	local function showPage()
		if not pages or index > #pages then
			if dialog.Visible then
				local tween = Theme.Fade(dialog, false, 0.2)
				if tween then tween.Completed:Connect(function() if not pages then dialog.Visible = false end end) else dialog.Visible = false end
			end
			local done = onDone
			pages, onDone = nil, nil
			if done then done() end
			return
		end
		text.Text = pages[index]
		foot.Text = string.format("Tap to continue (%d/%d)", index, #pages)
		if not dialog.Visible then
			dialog.Visible = true
			Theme.Fade(dialog, true, 0.2)
		end
	end
	function api.Show(newPages, done)
		pages, index, onDone = newPages, 1, done
		showPage()
	end
	function api.Hide()
		pages, onDone = nil, nil
		showPage()
	end
	function api.IsShowing(): boolean
		return pages ~= nil
	end
	dialog.Activated:Connect(function()
		if not pages then return end
		Audio.PlayUI("Click")
		index += 1
		showPage()
	end)
	return api
end

return CoachDialog
