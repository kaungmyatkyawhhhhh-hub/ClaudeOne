-- CoachDialog (prompt 39, 22 Oct): the tutorial's Coach Dex dialog box, moved out of TutorialClient so the unlock guides
-- (GuideClient) use the same box: a live portrait of the Coach NPC, "COACH DEX", a gold "+50" coin pill, the words,
-- "Tap to continue (1/3)".
-- Prompts 53a / 53 + the owner's spacing brief (23 Oct): a dark graphite box with the hex mesh, a thin gold outline and a
-- thick dark bottom edge; at most ~55% of the screen wide (CoachDialog.Width), centred at the bottom, clear of the left
-- nav; as tall as its words need. 12-14 px padding everywhere: the portrait (gold frame) on the left; "COACH DEX" in gold
-- chunky with the "+50" coin pill on the same row at the top right (the words start under that row, so they never run
-- under the pill); the words in the body font (Montserrat Bold, sentence case, white, 1.2 line height); "Tap to continue
-- (1/2)" small and grey at the bottom right, with space above it.
--   CoachDialog.new(parent, reward?) -> dialog   (parent: a Kit.Root; reward: the coins shown, nil = no reward)
--   dialog.frame                                 the dialog (anchored at its bottom centre)
--   dialog.Height()                              its height now, edge included (mockup px; 0 while hidden)
--   dialog.Show(pages, onDone?)                  shows the pages; a tap goes to the next; after the last: onDone()
--   dialog.Hide()  dialog.IsShowing()  dialog.SetReward(coins?)
--   CoachDialog.BottomClear(root) -> px          mockup px kept free at the bottom of a Kit.Root: the hotbar, the stamina
--                                                bar (the dialog and the GO TO button sit above them)
--   CoachDialog.Gap                              px between the dialog and the GO TO button above it
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Audio = require(script.Parent.Parent.Audio)
local Quests = require(script.Parent.Parent.Config.Quests)

local New, Colors = Theme.New, Theme.Colors

local CoachDialog = {}
CoachDialog.Width = 460   -- (~55% of the 844 px phone screen)
CoachDialog.Lip = 6       -- the dark bottom edge
CoachDialog.Gap = 12      -- to the GO TO button above it
local PAD = 12
local PORTRAIT = 56
local TEXT_LEFT = PAD + PORTRAIT + PAD
local NAME_ROW = 24       -- the name and the reward pill
local TEXT_SIZE = 14
local LINE_HEIGHT = 1.2
local FOOT = 14           -- "Tap to continue"

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

-- the gold "+50" coin pill: the gold ChunkyButton's face and thick darker edge, a coin and the amount in stroked white
local function rewardPill(parent: Instance)
	local pill = New("Frame", { Name = "Reward", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -PAD, 0, PAD), Size = UDim2.fromOffset(0, NAME_ROW),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")), ColorSequenceKeypoint.new(0.55, Color3.fromHex("#F6C75A")),
			ColorSequenceKeypoint.new(0.78, Color3.fromHex("#C98A12")), ColorSequenceKeypoint.new(0.8, Color3.fromHex("#8A5A08")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#8A5A08")) }) }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 3) }),
		Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	Kit.Coin(18, { LayoutOrder = 1, Parent = pill })
	local amount = Kit.Text({ Name = "Amount", LayoutOrder = 2, Text = "", Font = "Chunky", TextSize = 14, Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
	return pill, amount
end

-- the words' height at the dialog's width (wrapped, 1.2 line height)
local function wordsHeight(label: TextLabel, text: string): number
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size, params.Width = text, label.FontFace, TEXT_SIZE, CoachDialog.Width - TEXT_LEFT - PAD
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	local lines = if ok then math.max(1, math.floor(bounds.Y / TEXT_SIZE + 0.3)) else 2
	return math.ceil(lines * TEXT_SIZE * LINE_HEIGHT)
end

function CoachDialog.new(parent: Instance, reward: number?)
	-- the whole dialog is one tap target (an ImageButton without an image): the edge, then the face on top of it
	local dialog = New("ImageButton", { Name = "CoachDialog", AutoButtonColor = false, BackgroundTransparency = 1, Image = "", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(CoachDialog.Width, 96), Visible = false, Parent = parent })
	local lip = New("Frame", { Name = "Lip", Position = UDim2.fromOffset(0, CoachDialog.Lip), Size = UDim2.new(1, 0, 1, -CoachDialog.Lip),
		BackgroundColor3 = Color3.fromHex("#0B090C"), Parent = dialog }, {
		New("UICorner", { CornerRadius = UDim.new(0, 14) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local face = Theme.Panel({ Name = "Face", Size = UDim2.new(1, 0, 1, -CoachDialog.Lip), ZIndex = 2, Parent = dialog }, {})
	face.BackgroundTransparency = 0.04
	local border = face:FindFirstChild("Border") :: UIStroke
	if border then border.Color, border.Thickness, border.Transparency = Colors.Gold, 2, 0 end
	Theme.SetHex(face, Theme.HexAlpha, 14)
	lip.ZIndex = 1

	-- his live portrait in a gold frame, on the light backdrop of tutorial2.png (a gradient on a ViewportFrame tints the
	-- model too: a light one, so he stays bright and only the bottom darkens a little)
	local portrait = New("ViewportFrame", { Name = "Portrait", Position = UDim2.fromOffset(PAD, PAD), Size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
		BackgroundColor3 = Colors.Blue, Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -0.6, -1),
		Parent = face }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = Colors.Gold, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }),
	})
	local pill, amount = rewardPill(face)
	local who = Kit.GoldText(Kit.Text({ Name = "Name", Text = Quests.CoachName, Font = "Chunky", Upper = true, TextSize = 16, Position = UDim2.fromOffset(TEXT_LEFT, PAD),
		Size = UDim2.new(1, -TEXT_LEFT - PAD - 76, 0, NAME_ROW), TextXAlignment = Enum.TextXAlignment.Left, Parent = face }))
	local whoStroke = who:FindFirstChild("TextStroke")
	if whoStroke then whoStroke.Transparency = 0 end
	local text = Kit.Text({ Name = "Text", Text = "", Font = "Strong", TextSize = TEXT_SIZE, TextWrapped = true, LineHeight = LINE_HEIGHT,
		Position = UDim2.fromOffset(TEXT_LEFT, PAD + NAME_ROW + 4), Size = UDim2.new(1, -TEXT_LEFT - PAD, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = face })
	local foot = Kit.Text({ Name = "Continue", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -PAD, 1, -10), Size = UDim2.fromOffset(180, FOOT), TextXAlignment = Enum.TextXAlignment.Right, Parent = face })
	fillPortrait(portrait)

	local api = { frame = dialog }
	local pages, index, onDone = nil, 0, nil

	function api.SetReward(coins: number?)
		pill.Visible = coins ~= nil and coins > 0
		amount.Text = "+" .. tostring(coins or 0)
	end
	api.SetReward(reward)

	function api.Height(): number
		return if pages and dialog.Visible then dialog.Size.Y.Offset else 0
	end

	-- the box fits the words: the name row, the words, 6 px, "Tap to continue", the padding; never shorter than the portrait
	local function fit(words: string)
		local h = wordsHeight(text, words)
		text.Size = UDim2.new(1, -TEXT_LEFT - PAD, 0, h)
		local inner = math.max(PAD + NAME_ROW + 4 + h + 6 + FOOT + 10, PAD + PORTRAIT + PAD)
		dialog.Size = UDim2.fromOffset(CoachDialog.Width, inner + CoachDialog.Lip)
	end

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
		fit(pages[index])
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

-- mockup px kept free at the bottom of `root`: 10 px, the hotbar when it shows (HotbarClient: a 54 px slot + 10 px), the
-- stamina bar when it shows (HudBottom's "StaminaGroup": its top + 8 px)
function CoachDialog.BottomClear(root: GuiObject): number
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local clear = 10
	local hotbar = playerGui and playerGui:FindFirstChild("Hotbar")
	if hotbar and hotbar:IsA("LayerCollector") and hotbar.Enabled then clear = 74 end
	local stamina = playerGui and playerGui:FindFirstChild("StaminaGroup", true)
	local staminaGui = stamina and stamina:FindFirstAncestorWhichIsA("LayerCollector")
	if stamina and stamina:IsA("CanvasGroup") and stamina.Visible and stamina.GroupTransparency < 0.9 and staminaGui and staminaGui.Enabled then
		local scale = math.max(Kit.Scale(), 0.01)
		local bottom = root.AbsolutePosition.Y + root.AbsoluteSize.Y
		clear = math.max(clear, (bottom - stamina.AbsolutePosition.Y) / scale + 8)
	end
	return clear
end

return CoachDialog
