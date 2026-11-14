# Dungeon quest panel implementation plan

**Goal:** fix missing dungeon quests and provide readable, navigable quest details beside an unchanged OpenMap dungeon map.

**Architecture:** standalone OpenMapQuestFix addon. ID-based data model, independent panel renderer, isolated OpenMap host adapter, event-driven refresh. Use installed Questie and native client APIs; redistribute no game or provider assets.

**Tech stack:** Lua 5.1, WoW Interface 16001, uv with lupa for developer checks.

## Constraints

- Work in the user-designated repository on fix/dungeon-quest-panel.
- No edits to OpenMap, Questie, or route addon files.
- Whole-dungeon scope, not current-wing filtering.
- Native journal selection, native collapsed headers and map state must not change.
- RU/EN; compact vanilla-style list and parchment details; independent tracking control.
- No commits, pushes or publication during implementation without further instruction.

## Task 1: ID-based quest model

Files: OpenMapQuestFix/Data.lua, tests/data.lua.

- Regression fixture: instance 189, canonical area 796, alternate 10008, decorated wing name, accepted quests 1050 and 1053; no empty result from decorated title.
- Resolve IDs via ZoneDB.instanceIdToAreaId and GetDungeons; normalize alternatives. GetRealZoneText fallback is the undecorated native name only.
- Build database zone index in bounded timer chunks, once after provider readiness. Keep active quests usable before indexing ends.
- Enumerate accepted quest IDs using C_QuestLog.GetInfo and provider QuestiePlayer.currentQuestlog where necessary for collapsed rows; verify IsOnQuest by ID. Use native quest info and GetQuestObjectives for progress.
- Return active and additional lists. Filter race/class for additional only. Mark completed, not-yet-accepted and prerequisite status honestly.
- Read accepted descriptions, objective summary and reward item/choice/money/XP data by quest ID. No global selection mutation.

## Task 2: Panel renderer

Files: OpenMapQuestFix/Panel.lua, OpenMapQuestFix/Locale.lua.

- Panel.New(parent, callbacks): returns panel frame; callbacks open(id), back(), toggle(id), collapse(). Panel:Render(model) consumes title-independent lists/details.
- Render wrapped quest titles with difficulty colors, live objective text, complete status and distinct tracking checkbox. Additional section starts collapsed.
- Details show Back, quest title/status, objectives, full description, reward choices and guaranteed rewards, money and XP; item tooltips use provided links.
- Preserve scroll separately for list and selected details; resize to actual host width; pooled rows, no per-frame rebuilding.
- RU/EN localization and native textures/fonts only.

## Task 3: Host and event integration

Files: OpenMapQuestFix/Host.lua, OpenMapQuestFix/Core.lua, OpenMapQuestFix/OpenMapQuestFix.toc.

- Dependencies OpenMap and Questie; no route dependency. Load on PLAYER_LOGIN.
- Watch native OpenMap side.child SetHeight, side visibility, width and existing tab clicks, plus dungeon callbacks. Install once lazily when view exists.
- On selected dungeon Quests tab, hide native scroll, show own sibling panel inside scroll bounds. Other tabs immediately restore native scroll; no native data/settings writes.
- Core stores current instanceID, selectedID, additionalExpanded and coalesces invalidations via C_Timer.After(0). Data initialization notifies Core when complete.
- Refresh for QUEST_LOG_UPDATE, QUEST_WATCH_UPDATE, QUEST_WATCH_LIST_CHANGED, QUEST_TURNED_IN, QUEST_ACCEPTED, QUEST_REMOVED, CRITERIA_UPDATE, QUEST_DATA_LOAD_RESULT and item-data completion. Register only actual supported events safely.
- Tracking calls C_QuestLog AddQuestWatch/RemoveQuestWatch by ID; update UI from observed state. Do not call native map quest navigation.

## Task 4: Verification and delivery

Files: tests/check.py, pyproject.toml, uv.lock, tools/package.py, README.md, CHANGELOG.md, LICENSE, .gitignore, .gitattributes.

- Run data regression scenarios and Lua 5.1 compilation via uv run python tests/check.py.
- Review implementation for compatibility and lifecycle defects; address findings.
- Install only the new addon directory after preserving affected existing configuration; use real game /reload, or report if new folder needs a user restart.
- Real game: Graveyard → Quests → both active monastery quests → details/rewards → Back → tracking; verify floor, map and routes remain. Test other tabs and native journal.
- Document installation, dependencies, supported versions, scope and verified limits. Package only OpenMapQuestFix in dist/OpenMapQuestFix-0.1.0.zip; exclude game assets and test/developer files.
