# Graph Report - src  (2026-10-19)

## Corpus Check
- 172 files · ~270,649 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1768 nodes · 4059 edges · 111 communities (83 shown, 28 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 693 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e0a1d6a6`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- SpotService.luau
- MachineClient.client.luau
- GeneticsClient.client.luau
- DailyService.luau
- Icon/init.luau
- StatsLabelsClient.client.luau
- Theme.Tween
- ArmWrestleClient.client.luau
- TutorialClient.client.luau
- ClientData.Get
- Kit.Text
- Theme.luau
- CosmeticService.luau
- RivalClient.client.luau
- MachineService.luau
- Janitor.luau
- Icons.luau
- LegendService.luau
- TrainerFollowClient.client.luau
- Audio.luau
- BodyService.luau
- CrewService.luau
- Notify.luau
- CrewClient.client.luau
- shared_ui_theme
- RivalService.luau
- StatsClient.client.luau
- ArmWrestleService.luau
- SideMenu.luau
- PhotoModeClient.client.luau
- LeaderboardService.luau
- QuestService.luau
- MuscleRig.luau
- Themes/init.luau
- Analytics.luau
- DailyClient.client.luau
- WardrobeClient.client.luau
- PosingCompClient.client.luau
- TrainerClient.client.luau
- Icon.new
- Guard.OnTriggered
- RightColumn.luau
- StoreClient.client.luau
- GymGoerService.luau
- script_parent_guard
- PlayerData.luau
- ShowOffService.luau
- PosingCompService.luau
- HudBottom.luau
- shared_audio
- LoadingScreen.client.luau
- Shared/LimbStages.luau
- Gains.luau
- BodyMapClient.client.luau
- SkateClient.client.luau
- MirrorClient.client.luau
- update
- TopBar.luau
- ProgressClient.client.luau
- AuraVFX.luau
- Icon:getInstance
- Shared/BodyStages.luau
- Dropdown.luau
- GrowthSpurts.GetHeight
- AuraService.luau
- Icon.getIconByUID
- Overflow.luau
- CoachDexClient.client.luau
- MuscleMeshes.luau
- Caption.luau
- Icon:refreshAppearance
- BodyFigure.luau
- StoreClient.client.luau
- SettingsClient.client.luau
- ShutdownService.luau
- Container.luau
- Gamepad.luau
- VERSION.luau
- AccessoryService.luau
- MachineHud.luau
- Machines.luau
- Theme.Text
- Theme.Stroke
- productId
- TitleService.luau
- Muscles.GetGroupLevel
- MealClient.client.luau
- PoseApply.luau

## God Nodes (most connected - your core abstractions)
1. `ClientData.Get()` - 45 edges
2. `Theme.Tween()` - 40 edges
3. `Kit.Text()` - 28 edges
4. `Theme.Fade()` - 28 edges
5. `canvas()` - 25 edges
6. `Theme.New()` - 25 edges
7. `line()` - 22 edges
8. `Theme.Text()` - 20 edges
9. `Kit.Button()` - 19 edges
10. `Theme.List()` - 19 edges

## Surprising Connections (you probably didn't know these)
- `TopBar.NewIcon()` --calls--> `Icon.new()`  [INFERRED]
  src/ReplicatedStorage/Shared/UI/TopBar.luau → src/ReplicatedStorage/Packages/Icon/init.luau
- `metCount()` --calls--> `ClientData.Get()`  [INFERRED]
  src/StarterPlayer/StarterPlayerScripts/LegendClient.client.luau → src/ReplicatedStorage/Shared/ClientData.luau
- `refresh()` --calls--> `ClientData.Get()`  [INFERRED]
  src/StarterPlayer/StarterPlayerScripts/LegendClient.client.luau → src/ReplicatedStorage/Shared/ClientData.luau
- `isNew()` --calls--> `ClientData.Get()`  [INFERRED]
  src/StarterPlayer/StarterPlayerScripts/MachineSignsClient.client.luau → src/ReplicatedStorage/Shared/ClientData.luau
- `lockText()` --calls--> `ClientData.Get()`  [INFERRED]
  src/StarterPlayer/StarterPlayerScripts/MachineSignsClient.client.luau → src/ReplicatedStorage/Shared/ClientData.luau

## Import Cycles
- None detected.

## Communities (111 total, 28 thin omitted)

### Community 0 - "SpotService.luau"
Cohesion: 0.05
Nodes (75): Meals.CanBuy(), Meals.Clock(), Meals.Extend(), key(), Seasons.Active(), Spotting.BoostFor(), Spotting.Tap(), alive() (+67 more)

### Community 1 - "MachineClient.client.luau"
Cohesion: 0.06
Nodes (40): animate(), bars.arm(), bars.armIK(), bars.base(), bars.bodyDir(), bars.boneTurn(), bars.c0(), bars.c1() (+32 more)

### Community 2 - "GeneticsClient.client.luau"
Cohesion: 0.10
Nodes (48): Kit.SetGrade(), animate(), applyLayout(), bandRect(), CAMERA.Reframe(), CAMERA.Value(), clearBoard(), close() (+40 more)

### Community 3 - "DailyService.luau"
Cohesion: 0.12
Nodes (30): DailyQuests.Pick(), DailyQuests.SwapFor(), Economy.Day(), Economy.LoginDay(), Economy.LoginReward(), Economy.OfflineCoins(), Economy.RushHourAt(), advance() (+22 more)

### Community 4 - "Icon/init.luau"
Cohesion: 0.06
Nodes (24): Icon:bindEvent(), Icon:bindToggleItem(), Icon:bindToggleKey(), Icon:clearNotices(), Icon:destroy(), Icon:freezeMenu(), Icon:leave(), Icon:modifyTheme() (+16 more)

### Community 5 - "StatsLabelsClient.client.luau"
Cohesion: 0.05
Nodes (61): GrowthSpurts.FormatHeight(), Muscles.CumXp(), Muscles.EntryXp(), Muscles.ExactLevel(), Muscles.GroupExp(), Muscles.LevelFromXp(), Muscles.LookG(), Muscles.LooksFromLevels() (+53 more)

### Community 6 - "Theme.Tween"
Cohesion: 0.15
Nodes (20): setBlur(), Theme.Tween(), aim(), amLifting(), closeCard(), coinBurst(), flashBorder(), handsPose() (+12 more)

### Community 7 - "ArmWrestleClient.client.luau"
Cohesion: 0.07
Nodes (25): commas(), Leaderboards.Format(), Leaderboards.YourRankText(), Kit.ApplyHeadshot(), lookup(), Pieces.Apply(), Pieces.Image(), animate() (+17 more)

### Community 8 - "TutorialClient.client.luau"
Cohesion: 0.17
Nodes (21): advance(), approachPoint(), check(), finish(), gymCenter(), hidePath(), machineModel(), onStatsVisible() (+13 more)

### Community 9 - "ClientData.Get"
Cohesion: 0.27
Nodes (9): ClientData.Get(), Notify.Toast(), needsConfirm(), gainNumbersMode(), AURA.act(), AURA.equipped(), AURA.has(), AURA.state() (+1 more)

### Community 10 - "Kit.Text"
Cohesion: 0.11
Nodes (38): HudBottom.Chip(), Kit.Bar(), Kit.Button(), Kit.Chip(), Kit.CloseButton(), Kit.Coin(), Kit.CoinBurst(), Kit.Fit() (+30 more)

### Community 11 - "Theme.luau"
Cohesion: 0.13
Nodes (30): ctaLayers(), depthOf(), fitLayer(), fitLayers(), gradientFor(), lookOf(), outlineOf(), padOf() (+22 more)

### Community 12 - "CosmeticService.luau"
Cohesion: 0.08
Nodes (35): Skate.BoardScale(), Skate.HeightScale(), Skate.SpeedFactor(), Skate.TopSpeed(), Town.IsOutdoors(), ActionService.Register(), AuraService.Start(), band() (+27 more)

### Community 13 - "RivalClient.client.luau"
Cohesion: 0.20
Nodes (10): Theme.IsCompact(), Theme.OnCompactChanged(), applySize(), bubbleFor(), hideWin(), rivalModel(), say(), setOpen() (+2 more)

### Community 14 - "MachineService.luau"
Cohesion: 0.15
Nodes (22): armReach(), bodyCFrame(), c1(), clearUprights(), displayTier(), enter(), getPrompt(), isNpc() (+14 more)

### Community 15 - "Janitor.luau"
Cohesion: 0.11
Nodes (16): acquireRunnerThreadAndCallEventHandler(), Connection.new(), runEventHandlerInFreeThread(), Signal:Connect(), Signal:Once(), Signal:Wait(), getPromiseReference(), Janitor.__index:Add() (+8 more)

### Community 16 - "Icons.luau"
Cohesion: 0.23
Nodes (26): canvas(), Icons.Bowl(), Icons.Camera(), Icons.Chevron(), Icons.Clipboard(), Icons.Close(), Icons.Cup(), Icons.DNA() (+18 more)

### Community 17 - "LegendService.luau"
Cohesion: 0.29
Nodes (8): complete(), event(), eventAll(), LegendService.OnRep(), save(), say(), talk(), visit()

### Community 18 - "TrainerFollowClient.client.luau"
Cohesion: 0.11
Nodes (21): fadeNearCamera(), ghost(), setFade(), blocked(), clearAt(), coachIdle(), destroyTrainer(), fistPump() (+13 more)

### Community 19 - "Audio.luau"
Cohesion: 0.13
Nodes (21): applyVolumes(), Audio.AdoptMenuMusic(), Audio.Loop(), Audio.Play2D(), Audio.PlayAt(), Audio.SetArea(), Audio.SetVolumes(), Audio.StartMusic() (+13 more)

### Community 20 - "BodyService.luau"
Cohesion: 0.06
Nodes (60): baseY(), BodyShape.ApplyProportions(), BodyShape.ApplyWidths(), BodyShape.EnsureJoints(), BodyShape.SolveJoints(), jointInfo(), remapY(), reshape() (+52 more)

### Community 21 - "CrewService.luau"
Cohesion: 0.21
Nodes (25): canManage(), checkInbox(), claim(), count(), crewIdOf(), CrewService.Start(), crewView(), isTest() (+17 more)

### Community 22 - "Notify.luau"
Cohesion: 0.24
Nodes (16): Kit.UnderTopbar(), applyBand(), bandVisible(), ensure(), hintsOn(), Notify.BandBottom(), Notify.Hint(), Notify.Reserve() (+8 more)

### Community 23 - "CrewClient.client.luau"
Cohesion: 0.24
Nodes (21): Muscles.FormatExp(), Kit.Card(), Kit.Headshot(), backToList(), button(), clear(), clearPage(), crewHeader() (+13 more)

### Community 24 - "shared_ui_theme"
Cohesion: 0.10
Nodes (11): refresh(), refreshAll(), metCount(), refresh(), unlocked(), coachHead(), coachSays(), refresh() (+3 more)

### Community 25 - "RivalService.luau"
Cohesion: 0.17
Nodes (21): Rivals.ArmId(), Rivals.BeatsLift(), Rivals.BuildSpec(), Rivals.ChallengeText(), Rivals.FromArmId(), ArmWrestleService.SetExtraOpponents(), GameEvents.Fire(), GameEvents.On() (+13 more)

### Community 26 - "StatsClient.client.luau"
Cohesion: 0.12
Nodes (4): isNew(), lockText(), infoCard(), setLabels()

### Community 27 - "ArmWrestleService.luau"
Cohesion: 0.22
Nodes (23): Social.Strength(), ArmWrestleService.Start(), broadcast(), choicesFor(), chooseNpc(), clearNpc(), finish(), giveXp() (+15 more)

### Community 28 - "SideMenu.luau"
Cohesion: 0.19
Nodes (17): Kit.Scale(), ensure(), folded(), layout(), makeTile(), refreshArrowDot(), setCollapsed(), shownEntries() (+9 more)

### Community 29 - "PhotoModeClient.client.luau"
Cohesion: 0.12
Nodes (15): UIBus.CloseAllPanels(), UIBus.CoverOpen(), shine(), styleTag(), watchCharacter(), watchPlayer(), distanceTo(), enterPhoto() (+7 more)

### Community 30 - "LeaderboardService.luau"
Cohesion: 0.29
Nodes (12): Leaderboards.StoreName(), addRep(), heaviestLift(), LeaderboardService.Start(), nameOf(), readBoard(), refresh(), store() (+4 more)

### Community 31 - "QuestService.luau"
Cohesion: 0.22
Nodes (16): Muscles.GroupShown(), Muscles.Shown(), exp(), Quests.ForIndex(), Quests.RewardText(), countTitles(), giveNext(), grant() (+8 more)

### Community 32 - "MuscleRig.luau"
Cohesion: 0.09
Nodes (7): SkinStages.Pick(), MuscleRig.Flash(), MuscleRig.PulseModel(), MuscleRig.SetHighlight(), step(), tintBody(), repFlash()

### Community 33 - "Themes/init.luau"
Cohesion: 0.18
Nodes (17): Themes.apply(), Themes.change(), Themes.getClippedClone(), Themes.getInstanceValue(), Themes.getModifications(), Themes.getRealInstance(), Themes.getThemeValue(), Themes.merge() (+9 more)

### Community 34 - "Analytics.luau"
Cohesion: 0.29
Nodes (9): Analytics.GeneticsKept(), Analytics.GrowthSpurt(), Analytics.Joined(), Analytics.TutorialStep(), log(), saved(), check(), ProGymService.IsInside() (+1 more)

### Community 35 - "DailyClient.client.luau"
Cohesion: 0.17
Nodes (19): Kit.SetButton(), UIBus.PanelOpened(), calendarState(), close(), iconTile(), open(), paintTile(), progressText() (+11 more)

### Community 36 - "WardrobeClient.client.luau"
Cohesion: 0.19
Nodes (12): fadeProps(), Theme.Fade(), Theme.Hide(), Theme.Show(), clearWardrobe(), closeStore(), closeWardrobe(), openStore() (+4 more)

### Community 37 - "PosingCompClient.client.luau"
Cohesion: 0.14
Nodes (14): applyBanner(), boundTap(), hideVote(), myRoot(), nearStage(), now(), onStage(), sendTap() (+6 more)

### Community 38 - "TrainerClient.client.luau"
Cohesion: 0.46
Nodes (6): open(), refresh(), shake(), slots(), state(), tap()

### Community 39 - "Icon.new"
Cohesion: 0.13
Nodes (13): Themes.modify(), Icon:deselect(), Icon.new(), Icon:oneClick(), Icon:setOrder(), Icon:setState(), Icon:setTheme(), Icon:_setToggleItemsVisible() (+5 more)

### Community 40 - "Guard.OnTriggered"
Cohesion: 0.29
Nodes (10): BoostService.Pump(), Guard.Allow(), Guard.Near(), Guard.OnTriggered(), Guard.Remote(), positionOf(), pumpNow(), serverNow() (+2 more)

### Community 42 - "RightColumn.luau"
Cohesion: 0.29
Nodes (11): container(), ensure(), noticeReady(), pickCard(), RightColumn.Add(), RightColumn.Bottom(), RightColumn.Layout(), RightColumn.SetCollapsed() (+3 more)

### Community 43 - "StoreClient.client.luau"
Cohesion: 0.11
Nodes (10): fadeInHud(), layoutMenu(), placeArt(), playAlive(), reveal(), stageSize(), refreshPill(), rushLeft() (+2 more)

### Community 44 - "GymGoerService.luau"
Cohesion: 0.19
Nodes (20): animator(), chat(), goToSpot(), GymGoerService.Hold(), GymGoerService.Start(), gymMachines(), loadTracks(), lookAtPlayers() (+12 more)

### Community 46 - "script_parent_guard"
Cohesion: 0.24
Nodes (3): ActionService.Start(), MirrorService.Start(), wireMirror()

### Community 47 - "PlayerData.luau"
Cohesion: 0.16
Nodes (10): DataTemplate.new(), deepCopy(), load(), newLock(), PlayerData.Start(), reconcile(), replicate(), snapshot() (+2 more)

### Community 48 - "ShowOffService.luau"
Cohesion: 0.18
Nodes (19): GrowthSpurts.GetGoal(), ShowOff.SplitGroupScore(), BodyService.EncodeLevels(), busy(), findBoard(), findPlaque(), judge(), nameOf() (+11 more)

### Community 49 - "PosingCompService.luau"
Cohesion: 0.13
Nodes (11): PosingComp.TapValue(), PosingComp.VoteBonus(), cleanupRound(), onTap(), onVote(), PosingCompService.Start(), results(), runCountdown() (+3 more)

### Community 50 - "HudBottom.luau"
Cohesion: 0.35
Nodes (11): endlessLeft(), ensure(), HudBottom.Refresh(), HudBottom.SetHidden(), HudBottom.SetTraining(), placeRow(), refresh(), refreshVisible() (+3 more)

### Community 51 - "shared_audio"
Cohesion: 0.14
Nodes (9): frontArm(), resetPose(), setJoint(), sideArm(), onPlayer(), watch(), sendTap(), setLive() (+1 more)

### Community 52 - "LoadingScreen.client.luau"
Cohesion: 0.26
Nodes (12): checkUpdating(), drawDots(), fadeOut(), finish(), graphite(), menuProgress(), new(), rescale() (+4 more)

### Community 53 - "Shared/LimbStages.luau"
Cohesion: 0.20
Nodes (11): BodyStages.new(), fade(), jointAttachment(), LimbStages.IsOn(), LimbStages.new(), LimbStages.Update(), makePart(), nearestStage() (+3 more)

### Community 54 - "Gains.luau"
Cohesion: 0.11
Nodes (9): Gains.IsBalanced(), Gains.PerRep(), MuscleOfTheDay.GroupId(), MuscleOfTheDay.MultiplierFor(), MuscleOfTheDay.SecondsLeft(), exp(), Titles.Check(), MuscleOfTheDayService.Start() (+1 more)

### Community 55 - "BodyMapClient.client.luau"
Cohesion: 0.25
Nodes (13): buildFigures(), clearTraining(), figure(), fitHolder(), flash(), leaveMachine(), refreshMap(), restFor() (+5 more)

### Community 56 - "SkateClient.client.luau"
Cohesion: 0.19
Nodes (7): boardJoint(), follow(), isPress(), place(), pose(), skating(), toggle()

### Community 57 - "MirrorClient.client.luau"
Cohesion: 0.26
Nodes (13): MuscleRig.SetMirrorMode(), addLiveMuscles(), clearMuscles(), close(), copyLiveMesh(), copySize(), gymLight(), lightCard() (+5 more)

### Community 58 - "update"
Cohesion: 0.30
Nodes (8): DayNight.ClockFromElapsed(), DayNight.IsNight(), DayNight.Now(), applyLamp(), applySign(), applyWindow(), NightLightService.Start(), update()

### Community 59 - "TopBar.luau"
Cohesion: 0.18
Nodes (6): Icon.setTopbarEnabled(), SideMenu.IsHidden(), noticeSetter(), refreshVisible(), TopBar.AddPill(), TopBar.NewIcon()

### Community 61 - "ProgressClient.client.luau"
Cohesion: 0.39
Nodes (6): goalText(), grewMoment(), machineGoal(), refresh(), repsToLevel(), spurtProgress()

### Community 62 - "AuraVFX.luau"
Cohesion: 0.29
Nodes (9): AuraVFX:_apply(), AuraVFX.Build(), AuraVFX:SetLOD(), AuraVFX:SetPower(), bodyParts(), CS3(), emitter(), NS() (+1 more)

### Community 63 - "Icon:getInstance"
Cohesion: 0.29
Nodes (8): Icon:addToJanitor(), Icon:convertLabelToNumberSpinner(), Icon:debounce(), Icon:getInstance(), Icon:lock(), Icon:setEnabled(), Icon:unlock(), Icon:updateParent()

### Community 64 - "Shared/BodyStages.luau"
Cohesion: 0.24
Nodes (5): BodyStages.Available(), BodyStages.Missing(), makePart(), offsetOf(), place()

### Community 65 - "Dropdown.luau"
Cohesion: 0.31
Nodes (5): getTweenInfo(), updateChildSize(), updateMaxIcons(), updateVisibility(), totalChildrenChanged()

### Community 66 - "GrowthSpurts.GetHeight"
Cohesion: 0.20
Nodes (14): GrowthSpurts.Get(), GrowthSpurts.GetBonus(), GrowthSpurts.GetHeight(), GrowthSpurts.GetLevelCap(), GrowthSpurts.GetMasteryLevel(), GrowthSpurts.GoalLevel(), GrowthSpurts.IsMaxed(), GrowthSpurts.MaxSpurts() (+6 more)

### Community 67 - "AuraService.luau"
Cohesion: 0.56
Nodes (8): auraData(), AuraService.Has(), buy(), checkEarned(), equip(), event(), replicateWorn(), save()

### Community 68 - "Icon.getIconByUID"
Cohesion: 0.25
Nodes (8): updateMaxIconsListener(), Icon.getIcon(), Icon.getIconByUID(), Icon:joinDropdown(), Icon:joinMenu(), Icon:modifyChildTheme(), Utility.joinFeature(), TopBar.CoinsPosition()

### Community 69 - "Overflow.luau"
Cohesion: 0.36
Nodes (6): Overflow.getAvailableIcons(), Overflow.getWidth(), Overflow.start(), Overflow.updateAvailableIcons(), Utility.createStagger(), Utility.round()

### Community 72 - "CoachDexClient.client.luau"
Cohesion: 0.38
Nodes (4): envelope(), findJoints(), joint(), smoothstep()

### Community 74 - "Caption.luau"
Cohesion: 0.53
Nodes (4): getCaptionPosition(), setCaptionEnabled(), updateHotkey(), updatePosition()

### Community 75 - "Icon:refreshAppearance"
Cohesion: 0.22
Nodes (9): Icon:clipOutside(), Icon:getCollective(), Icon:getDropdown(), Icon:getInstanceOrCollective(), Icon:refresh(), Icon:refreshAppearance(), Icon:setBehaviour(), Icon:setDropdown() (+1 more)

### Community 76 - "BodyFigure.luau"
Cohesion: 0.47
Nodes (5): BodyFigure.Draw(), both(), mirror(), pair(), drawFigure()

### Community 77 - "StoreClient.client.luau"
Cohesion: 0.29
Nodes (5): endlessFull(), open(), owned(), refresh(), select()

### Community 78 - "SettingsClient.client.luau"
Cohesion: 0.36
Nodes (5): applyLowGraphics(), open(), refreshAll(), row(), save()

### Community 84 - "VERSION.luau"
Cohesion: 0.83
Nodes (3): VERSION.getAppVersion(), VERSION.getLatestVersion(), VERSION.isUpToDate()

### Community 85 - "AccessoryService.luau"
Cohesion: 0.83
Nodes (3): AccessoryService.ShouldHide(), AccessoryService.Start(), check()

### Community 103 - "MachineHud.luau"
Cohesion: 0.28
Nodes (4): MachineHud.LayoutMode(), stepButton(), testSwitch(), touchControls()

### Community 104 - "Machines.luau"
Cohesion: 0.40
Nodes (4): Machines.LiftTier(), Machines.UsableTier(), Machines.WeightText(), maxWeight()

### Community 105 - "Theme.Text"
Cohesion: 0.36
Nodes (9): Theme.StrokeFor(), Theme.Text(), Theme.TextShadow(), Theme.Uppercase(), head(), tag(), assistPop(), floatText() (+1 more)

### Community 106 - "Theme.Stroke"
Cohesion: 0.60
Nodes (5): Theme.PlateDisc(), Theme.Round(), Theme.Stroke(), column(), swatch()

### Community 111 - "TitleService.luau"
Cohesion: 0.38
Nodes (8): clearTags(), context(), session(), textRatio(), TitleService.Check(), TitleService.Equip(), TitleService.OnRep(), updateTag()

### Community 112 - "Muscles.GetGroupLevel"
Cohesion: 0.29
Nodes (6): Muscles.GetGroupLevel(), ShowOff.GroupScore(), ShowOff.TotalScore(), writeScores(), averageLevel(), averageLevel()

### Community 113 - "MealClient.client.luau"
Cohesion: 0.36
Nodes (5): Kit.SetTileColor(), now(), refreshTiles(), setOpen(), soldAt()

### Community 115 - "PoseApply.luau"
Cohesion: 0.50
Nodes (3): PoseApply.Apply(), poseCFrame(), flexPose()

## Knowledge Gaps
- **28 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Icon.new()` connect `Icon.new` to `Icon/init.luau`, `Icon.getIconByUID`, `Icon:refreshAppearance`, `Janitor.luau`, `TopBar.luau`, `Icon:getInstance`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **Are the 44 inferred relationships involving `ClientData.Get()` (e.g. with `ensure()` and `refresh()`) actually correct?**
  _`ClientData.Get()` has 44 INFERRED edges - model-reasoned connections that need verification._
- **Should `SpotService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.0545308740978348 - nodes in this community are weakly interconnected._
- **Why does `Icon.setTopbarEnabled()` connect `TopBar.luau` to `Icon/init.luau`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Are the 35 inferred relationships involving `Theme.Tween()` (e.g. with `setShown()` and `Kit.CoinBurst()`) actually correct?**
  _`Theme.Tween()` has 35 INFERRED edges - model-reasoned connections that need verification._
- **Should `MachineClient.client.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.05875706214689266 - nodes in this community are weakly interconnected._
- **Are the 20 inferred relationships involving `Kit.Text()` (e.g. with `ensure()` and `HudBottom.Chip()`) actually correct?**
  _`Kit.Text()` has 20 INFERRED edges - model-reasoned connections that need verification._