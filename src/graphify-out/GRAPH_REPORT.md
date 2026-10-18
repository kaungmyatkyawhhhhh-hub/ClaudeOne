# Graph Report - src  (2026-10-19)

## Corpus Check
- 172 files · ~264,263 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1764 nodes · 4048 edges · 111 communities (83 shown, 28 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 694 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6907bb5f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- SpotService.luau
- MachineClient.client.luau
- GeneticsClient.client.luau
- script_parent_playerdata
- Icon/init.luau
- StatsLabelsClient.client.luau
- Theme.Tween
- ArmWrestleClient.client.luau
- TutorialClient.client.luau
- ClientData.Get
- Kit.Text
- Theme.luau
- CosmeticService.luau
- Theme.Text
- MachineService.luau
- Janitor.luau
- Icons.luau
- BodyShape.luau
- TrainerFollowClient.client.luau
- Audio.luau
- BodyService.luau
- CrewService.luau
- Kit.luau
- CrewClient.client.luau
- shared_ui_theme
- RivalService.luau
- StatsClient.client.luau
- ArmWrestleService.luau
- SideMenu.luau
- PhotoModeClient.client.luau
- ShowOffService.luau
- PosingCompService.luau
- MuscleRig.luau
- Themes/init.luau
- Muscles.Shown
- DailyClient.client.luau
- WardrobeClient.client.luau
- PosingCompClient.client.luau
- TrainerService.luau
- Icon.new
- GrowthSpurts.luau
- MuscleClient.client.luau
- RightColumn.luau
- StoreClient.client.luau
- makeGiant
- QuestService.luau
- script_parent_guard
- PlayerData.luau
- TitleService.luau
- LegendService.luau
- HudBottom.luau
- shared_audio
- LoadingScreen.client.luau
- Shared/LimbStages.luau
- AuraService.luau
- BodyMapClient.client.luau
- SkateClient.client.luau
- MirrorClient.client.luau
- update
- TopBar.luau
- Gains.luau
- shared_clientdata
- AuraVFX.luau
- Icon:getInstance
- Shared/BodyStages.luau
- Dropdown.luau
- GrowthSpurts.GetHeight
- config_muscles
- Icon.getIconByUID
- Overflow.luau
- Muscles.GetGroupLevel
- CoachDexClient.client.luau
- MuscleMeshes.luau
- Caption.luau
- Icon:refreshAppearance
- BodyFigure.luau
- MealClient.client.luau
- TrainerClient.client.luau
- ShutdownService.luau
- Container.luau
- Gamepad.luau
- VERSION.luau
- AccessoryService.luau
- SocialClient.client.luau
- Machines.luau
- PoseApply.luau
- Theme.Stroke
- productId

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
Cohesion: 0.06
Nodes (64): key(), Seasons.Active(), Social.Strength(), Spotting.BoostFor(), Spotting.Tap(), alive(), BoostService.AddShake(), BoostService.Cardio() (+56 more)

### Community 1 - "MachineClient.client.luau"
Cohesion: 0.06
Nodes (40): animate(), bars.arm(), bars.armIK(), bars.base(), bars.bodyDir(), bars.boneTurn(), bars.c0(), bars.c1() (+32 more)

### Community 2 - "GeneticsClient.client.luau"
Cohesion: 0.09
Nodes (49): Kit.SetGrade(), SideMenu.SetHidden(), animate(), applyLayout(), bandRect(), CAMERA.Reframe(), CAMERA.Value(), clearBoard() (+41 more)

### Community 3 - "script_parent_playerdata"
Cohesion: 0.07
Nodes (49): DailyQuests.Pick(), DailyQuests.SwapFor(), Economy.Day(), Economy.LoginDay(), Economy.LoginReward(), Economy.OfflineCoins(), Economy.RushHourAt(), Leaderboards.StoreName() (+41 more)

### Community 4 - "Icon/init.luau"
Cohesion: 0.06
Nodes (24): Icon:bindEvent(), Icon:bindToggleItem(), Icon:bindToggleKey(), Icon:clearNotices(), Icon:destroy(), Icon:freezeMenu(), Icon:leave(), Icon:modifyTheme() (+16 more)

### Community 5 - "StatsLabelsClient.client.luau"
Cohesion: 0.13
Nodes (29): anchorPoint(), applySize(), applyTilt(), clearOf(), commas(), fitAll(), fitBacking(), hold() (+21 more)

### Community 6 - "Theme.Tween"
Cohesion: 0.15
Nodes (21): setBlur(), Theme.Tween(), aim(), amLifting(), closeCard(), coinBurst(), flashBorder(), floatText() (+13 more)

### Community 7 - "ArmWrestleClient.client.luau"
Cohesion: 0.06
Nodes (29): commas(), Leaderboards.Format(), Leaderboards.YourRankText(), lookup(), Pieces.Apply(), Pieces.Image(), UIBus.CoverOpen(), animate() (+21 more)

### Community 8 - "TutorialClient.client.luau"
Cohesion: 0.11
Nodes (34): applyBand(), bandVisible(), hintsOn(), Notify.BandBottom(), Notify.Hint(), Notify.Reserve(), Notify.SetBand(), Notify.Show() (+26 more)

### Community 9 - "ClientData.Get"
Cohesion: 0.23
Nodes (11): ClientData.Get(), Notify.Toast(), needsConfirm(), gainNumbersMode(), refresh(), updateVisible(), AURA.act(), AURA.equipped() (+3 more)

### Community 10 - "Kit.Text"
Cohesion: 0.17
Nodes (27): Kit.Button(), Kit.Chip(), Kit.CloseButton(), Kit.Coin(), Kit.CoinBurst(), Kit.GoldText(), Kit.GradeBadge(), Kit.IconTile() (+19 more)

### Community 11 - "Theme.luau"
Cohesion: 0.12
Nodes (30): Audio.StopMenuMusic(), ctaLayers(), depthOf(), fadeProps(), fitLayer(), fitLayers(), gradientFor(), lookOf() (+22 more)

### Community 12 - "CosmeticService.luau"
Cohesion: 0.06
Nodes (48): Meals.CanBuy(), Meals.Clock(), Meals.Extend(), Skate.BoardScale(), Skate.HeightScale(), Skate.SpeedFactor(), Skate.TopSpeed(), Town.IsOutdoors() (+40 more)

### Community 13 - "Theme.Text"
Cohesion: 0.14
Nodes (21): Theme.IsCompact(), Theme.OnCompactChanged(), Theme.Pad(), Theme.StrokeFor(), Theme.Text(), Theme.TextShadow(), Theme.Uppercase(), applySize() (+13 more)

### Community 14 - "MachineService.luau"
Cohesion: 0.08
Nodes (47): BoostService.Pump(), animator(), chat(), goToSpot(), GymGoerService.Hold(), GymGoerService.Start(), gymMachines(), loadTracks() (+39 more)

### Community 15 - "Janitor.luau"
Cohesion: 0.11
Nodes (16): acquireRunnerThreadAndCallEventHandler(), Connection.new(), runEventHandlerInFreeThread(), Signal:Connect(), Signal:Once(), Signal:Wait(), getPromiseReference(), Janitor.__index:Add() (+8 more)

### Community 16 - "Icons.luau"
Cohesion: 0.23
Nodes (26): canvas(), Icons.Bowl(), Icons.Camera(), Icons.Chevron(), Icons.Clipboard(), Icons.Close(), Icons.Cup(), Icons.DNA() (+18 more)

### Community 17 - "BodyShape.luau"
Cohesion: 0.27
Nodes (12): baseY(), BodyShape.ApplyProportions(), BodyShape.EnsureJoints(), BodyShape.SolveJoints(), jointInfo(), remapY(), reshape(), scaleAxis() (+4 more)

### Community 18 - "TrainerFollowClient.client.luau"
Cohesion: 0.11
Nodes (21): fadeNearCamera(), ghost(), setFade(), blocked(), bubble(), clearAt(), coachIdle(), destroyTrainer() (+13 more)

### Community 19 - "Audio.luau"
Cohesion: 0.14
Nodes (19): applyVolumes(), Audio.AdoptMenuMusic(), Audio.Loop(), Audio.Play2D(), Audio.PlayAt(), Audio.SetArea(), Audio.SetVolumes(), Audio.StartMusic() (+11 more)

### Community 20 - "BodyService.luau"
Cohesion: 0.15
Nodes (21): BodyShape.ApplyWidths(), Muscles.LooksFromLevels(), strengthOf(), applyBody(), applyFrame(), bodyIntact(), BodyService.EncodeLevels(), BodyService.LevelsOf() (+13 more)

### Community 21 - "CrewService.luau"
Cohesion: 0.11
Nodes (36): GrowthSpurts.FormatHeight(), Muscles.CumXp(), Muscles.EntryXp(), Muscles.ExactLevel(), Muscles.GroupExp(), Muscles.LookG(), Muscles.MonsterG(), Muscles.MuscleExp() (+28 more)

### Community 22 - "Kit.luau"
Cohesion: 0.16
Nodes (14): Kit.ApplyHeadshot(), Kit.Bar(), Kit.Fit(), Kit.Headshot(), Kit.Metal(), Kit.ScaleFor(), Kit.Slider(), Kit.Tag() (+6 more)

### Community 23 - "CrewClient.client.luau"
Cohesion: 0.25
Nodes (20): Muscles.FormatExp(), Kit.Card(), backToList(), button(), clear(), clearPage(), crewHeader(), crewMembers() (+12 more)

### Community 24 - "shared_ui_theme"
Cohesion: 0.11
Nodes (10): metCount(), refresh(), coachHead(), coachSays(), refreshPill(), rushLeft(), applyLowGraphics(), save() (+2 more)

### Community 25 - "RivalService.luau"
Cohesion: 0.20
Nodes (19): Rivals.ArmId(), Rivals.BeatsLift(), Rivals.BuildSpec(), Rivals.ChallengeText(), Rivals.FromArmId(), ArmWrestleService.SetExtraOpponents(), accept(), armOpponents() (+11 more)

### Community 26 - "StatsClient.client.luau"
Cohesion: 0.12
Nodes (3): isNew(), lockText(), setLabels()

### Community 27 - "ArmWrestleService.luau"
Cohesion: 0.26
Nodes (21): ArmWrestleService.Start(), broadcast(), choicesFor(), chooseNpc(), clearNpc(), finish(), giveXp(), joined() (+13 more)

### Community 28 - "SideMenu.luau"
Cohesion: 0.13
Nodes (25): Kit.OnScale(), Kit.OnTopbar(), Kit.Root(), Kit.Scale(), Kit.UnderTopbar(), MachineHud.Build(), ensure(), ensure() (+17 more)

### Community 29 - "PhotoModeClient.client.luau"
Cohesion: 0.26
Nodes (9): distanceTo(), enterPhoto(), exitPhoto(), findAll(), hideOtherGuis(), nearSpot(), refreshRay(), rootPart() (+1 more)

### Community 30 - "ShowOffService.luau"
Cohesion: 0.31
Nodes (12): busy(), findBoard(), findPlaque(), nameOf(), onEmote(), refreshBoard(), ShowOffService.PlayEmote(), ShowOffService.ReleasePose() (+4 more)

### Community 31 - "PosingCompService.luau"
Cohesion: 0.11
Nodes (14): PosingComp.TapValue(), PosingComp.VoteBonus(), GameEvents.Fire(), GameEvents.On(), cleanupRound(), onTap(), onVote(), PosingCompService.Start() (+6 more)

### Community 32 - "MuscleRig.luau"
Cohesion: 0.09
Nodes (8): SkinStages.Pick(), MuscleRig.Flash(), MuscleRig.PulseModel(), MuscleRig.SetHighlight(), MuscleRig.SetMirrorMode(), step(), tintBody(), repFlash()

### Community 33 - "Themes/init.luau"
Cohesion: 0.18
Nodes (17): Themes.apply(), Themes.change(), Themes.getClippedClone(), Themes.getInstanceValue(), Themes.getModifications(), Themes.getRealInstance(), Themes.getThemeValue(), Themes.merge() (+9 more)

### Community 34 - "Muscles.Shown"
Cohesion: 0.14
Nodes (7): Muscles.GroupShown(), Muscles.Shown(), exp(), Quests.ForIndex(), Quests.RewardText(), exp(), Titles.Check()

### Community 35 - "DailyClient.client.luau"
Cohesion: 0.17
Nodes (19): Kit.SetButton(), UIBus.PanelOpened(), calendarState(), close(), iconTile(), open(), paintTile(), progressText() (+11 more)

### Community 36 - "WardrobeClient.client.luau"
Cohesion: 0.31
Nodes (6): clearWardrobe(), openStore(), openWardrobe(), refreshStore(), refreshWardrobe(), state()

### Community 37 - "PosingCompClient.client.luau"
Cohesion: 0.14
Nodes (15): boundTap(), clock(), hideVote(), myRoot(), nearStage(), now(), onStage(), placeUnderTopbar() (+7 more)

### Community 38 - "TrainerService.luau"
Cohesion: 0.30
Nodes (13): Trainers.CleanEquipped(), Trainers.SlotsFor(), addDesk(), apply(), equip(), extras(), hire(), prop() (+5 more)

### Community 39 - "Icon.new"
Cohesion: 0.13
Nodes (13): Themes.modify(), Icon:deselect(), Icon.new(), Icon:oneClick(), Icon:setOrder(), Icon:setState(), Icon:setTheme(), Icon:_setToggleItemsVisible() (+5 more)

### Community 40 - "GrowthSpurts.luau"
Cohesion: 0.24
Nodes (10): GrowthSpurts.Get(), GrowthSpurts.GetGoal(), GrowthSpurts.GetLevelCap(), GrowthSpurts.GetMasteryLevel(), GrowthSpurts.GoalLevel(), GrowthSpurts.MaxSpurts(), GrowthSpurts.Progress(), Muscles.LevelFromXp() (+2 more)

### Community 41 - "MuscleClient.client.luau"
Cohesion: 0.18
Nodes (18): Body.TopColor(), MuscleRig.Decode(), MuscleRig.StyleFrom(), candidates(), distanceTo(), far(), isStatic(), myTargets() (+10 more)

### Community 42 - "RightColumn.luau"
Cohesion: 0.16
Nodes (14): frame(), MachineHud.LayoutMode(), testSwitch(), touchControls(), container(), ensure(), noticeReady(), pickCard() (+6 more)

### Community 43 - "StoreClient.client.luau"
Cohesion: 0.10
Nodes (15): Theme.Pulse(), Theme.ReducedMotion(), fadeInHud(), layoutMenu(), placeArt(), playAlive(), reveal(), stageSize() (+7 more)

### Community 44 - "makeGiant"
Cohesion: 0.27
Nodes (12): Body.ApplyTo(), Body.ShortsColor(), classicFace(), dressNpc(), makeCoach(), makeGiant(), color(), fallbackModel() (+4 more)

### Community 45 - "QuestService.luau"
Cohesion: 0.38
Nodes (11): countTitles(), giveNext(), grant(), measure(), newActive(), pick(), QuestService.OnRep(), QuestService.Start() (+3 more)

### Community 46 - "script_parent_guard"
Cohesion: 0.16
Nodes (8): ActionService.Start(), Guard.Allow(), Guard.Near(), Guard.OnTriggered(), Guard.Remote(), positionOf(), TownService.Start(), wire()

### Community 47 - "PlayerData.luau"
Cohesion: 0.18
Nodes (10): DataTemplate.new(), deepCopy(), load(), newLock(), PlayerData.Start(), reconcile(), replicate(), snapshot() (+2 more)

### Community 48 - "TitleService.luau"
Cohesion: 0.38
Nodes (8): clearTags(), context(), session(), textRatio(), TitleService.Check(), TitleService.Equip(), TitleService.OnRep(), updateTag()

### Community 49 - "LegendService.luau"
Cohesion: 0.29
Nodes (8): complete(), event(), eventAll(), LegendService.OnRep(), save(), say(), talk(), visit()

### Community 50 - "HudBottom.luau"
Cohesion: 0.32
Nodes (12): endlessLeft(), ensure(), HudBottom.Chip(), HudBottom.Refresh(), HudBottom.SetHidden(), HudBottom.SetTraining(), placeRow(), refresh() (+4 more)

### Community 51 - "shared_audio"
Cohesion: 0.20
Nodes (6): frontArm(), resetPose(), setJoint(), sideArm(), onPlayer(), watch()

### Community 52 - "LoadingScreen.client.luau"
Cohesion: 0.26
Nodes (12): checkUpdating(), drawDots(), fadeOut(), finish(), graphite(), menuProgress(), new(), rescale() (+4 more)

### Community 53 - "Shared/LimbStages.luau"
Cohesion: 0.23
Nodes (9): BodyStages.new(), fade(), LimbStages.IsOn(), LimbStages.new(), LimbStages.Update(), makePart(), nearestStage(), place() (+1 more)

### Community 54 - "AuraService.luau"
Cohesion: 0.34
Nodes (11): GrowthSpurts.IsMaxed(), auraData(), AuraService.Has(), averageLevel(), buy(), checkEarned(), earnedNow(), equip() (+3 more)

### Community 55 - "BodyMapClient.client.luau"
Cohesion: 0.25
Nodes (13): buildFigures(), clearTraining(), figure(), fitHolder(), flash(), leaveMachine(), refreshMap(), restFor() (+5 more)

### Community 56 - "SkateClient.client.luau"
Cohesion: 0.21
Nodes (6): boardJoint(), follow(), isPress(), pose(), skating(), toggle()

### Community 57 - "MirrorClient.client.luau"
Cohesion: 0.23
Nodes (14): addLiveMuscles(), clearMuscles(), close(), copyLiveMesh(), copySize(), gymLight(), lightCard(), liveMeshOf() (+6 more)

### Community 58 - "update"
Cohesion: 0.30
Nodes (8): DayNight.ClockFromElapsed(), DayNight.IsNight(), DayNight.Now(), applyLamp(), applySign(), applyWindow(), NightLightService.Start(), update()

### Community 59 - "TopBar.luau"
Cohesion: 0.18
Nodes (6): Icon.setTopbarEnabled(), SideMenu.IsHidden(), noticeSetter(), refreshVisible(), TopBar.AddPill(), TopBar.NewIcon()

### Community 60 - "Gains.luau"
Cohesion: 0.33
Nodes (3): Gains.IsBalanced(), Gains.PerRep(), GrowthSpurts.GetBonus()

### Community 61 - "shared_clientdata"
Cohesion: 0.17
Nodes (8): refresh(), refreshAll(), goalText(), machineGoal(), refresh(), repsToLevel(), spurtProgress(), unlocked()

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
Cohesion: 0.21
Nodes (10): GrowthSpurts.GetHeight(), BodyService.EncodeShare(), BodyService.OriginalDescription(), avatarDescription(), MirrorService.Start(), openFor(), saveDayOne(), wireMirror() (+2 more)

### Community 67 - "config_muscles"
Cohesion: 0.31
Nodes (5): MuscleOfTheDay.GroupId(), MuscleOfTheDay.MultiplierFor(), MuscleOfTheDay.SecondsLeft(), MuscleOfTheDayService.Start(), updateBoard()

### Community 68 - "Icon.getIconByUID"
Cohesion: 0.25
Nodes (8): updateMaxIconsListener(), Icon.getIcon(), Icon.getIconByUID(), Icon:joinDropdown(), Icon:joinMenu(), Icon:modifyChildTheme(), Utility.joinFeature(), TopBar.CoinsPosition()

### Community 69 - "Overflow.luau"
Cohesion: 0.36
Nodes (6): Overflow.getAvailableIcons(), Overflow.getWidth(), Overflow.start(), Overflow.updateAvailableIcons(), Utility.createStagger(), Utility.round()

### Community 71 - "Muscles.GetGroupLevel"
Cohesion: 0.25
Nodes (7): Muscles.GetGroupLevel(), ShowOff.GroupScore(), ShowOff.SplitGroupScore(), ShowOff.TotalScore(), writeScores(), averageLevel(), averageLevel()

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

### Community 77 - "MealClient.client.luau"
Cohesion: 0.36
Nodes (5): Kit.SetTileColor(), now(), refreshTiles(), setOpen(), soldAt()

### Community 78 - "TrainerClient.client.luau"
Cohesion: 0.43
Nodes (6): open(), refresh(), shake(), slots(), state(), tap()

### Community 84 - "VERSION.luau"
Cohesion: 0.83
Nodes (3): VERSION.getAppVersion(), VERSION.getLatestVersion(), VERSION.isUpToDate()

### Community 85 - "AccessoryService.luau"
Cohesion: 0.83
Nodes (3): AccessoryService.ShouldHide(), AccessoryService.Start(), check()

### Community 103 - "SocialClient.client.luau"
Cohesion: 0.40
Nodes (3): sendTap(), setLive(), showMeter()

### Community 104 - "Machines.luau"
Cohesion: 0.50
Nodes (3): Machines.LiftTier(), Machines.UsableTier(), Machines.WeightText()

### Community 105 - "PoseApply.luau"
Cohesion: 0.50
Nodes (3): PoseApply.Apply(), poseCFrame(), flexPose()

### Community 106 - "Theme.Stroke"
Cohesion: 0.60
Nodes (5): Theme.PlateDisc(), Theme.Round(), Theme.Stroke(), column(), swatch()

## Knowledge Gaps
- **28 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Icon.new()` connect `Icon.new` to `Icon/init.luau`, `Icon.getIconByUID`, `Icon:refreshAppearance`, `Janitor.luau`, `TopBar.luau`, `Icon:getInstance`?**
  _High betweenness centrality (0.107) - this node is a cross-community bridge._
- **Are the 44 inferred relationships involving `ClientData.Get()` (e.g. with `ensure()` and `refresh()`) actually correct?**
  _`ClientData.Get()` has 44 INFERRED edges - model-reasoned connections that need verification._
- **Should `SpotService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.061621621621621624 - nodes in this community are weakly interconnected._
- **Why does `TopBar.AddPill()` connect `TopBar.luau` to `Icon.new`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Are the 35 inferred relationships involving `Theme.Tween()` (e.g. with `setShown()` and `Kit.CoinBurst()`) actually correct?**
  _`Theme.Tween()` has 35 INFERRED edges - model-reasoned connections that need verification._
- **Should `MachineClient.client.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.05875706214689266 - nodes in this community are weakly interconnected._
- **Are the 20 inferred relationships involving `Kit.Text()` (e.g. with `ensure()` and `HudBottom.Chip()`) actually correct?**
  _`Kit.Text()` has 20 INFERRED edges - model-reasoned connections that need verification._