# Additional quest source union implementation plan

**Goal:** additional dungeon quests come strictly from the union of AzerothCompendium, ForeverDungeonJournal and ForeverGuide, excluding active and completed nonrepeatable quests.

**Architecture:** Sources.lua reads public live provider namespaces, maps whole-dungeon identities, and returns normalized records keyed by numeric quest ID. Providers.lua reads journal globals and Compendium registry; the native getter is used only if a source opts in. ForeverGuide's closed namespace is handled by optional OpenMapQuestFixGuideData, loading only the installed guide's data modules into a private table through relative TOC paths. No provider files are edited. Data.lua retains native active states and merges source membership with active discovery, never adds Questie-only additional quests. Core handles optional provider load order/events; Panel consumes existing records.

**Constraints:** Lua 5.1 / Interface 16001; existing task branch; no upstream file changes or data redistribution; no commits/push. Keep active/dungeon map/navigation unchanged. Preserve explicit faction/class/race restrictions. Minimum level/prerequisites do not hide source quests. Completed repeatables retained only with explicit repeatable evidence. Zero installed sources means empty additional list, not Questie fallback.

## Task 1: provider adapters

- Create OpenMapQuestFix/Sources.lua and tests/sources.lua.
- API NS.Sources.New(getter) -> sources; getter(addonName) returns provider data table; default uses NS.GetQuestProvider. sources:List(inst) returns { [numericQuestID] = {id,name,level,objectives,allowed,sources,repeatable,status,pickup} }.
- Read Compendium QUESTS and INSTANCES, including parentID/areaID/synthetic IDs and raid quests already in QUESTS at runtime. Journal DB[name].quests and INSTANCE_ID_TO_DUNGEON. Guide DUNGEONS[].q and DQ, optional DungeonQuestRealID for named IDs. Merge all wings with matching base instance.
- Deduplicate by exact numeric quest ID; missing metadata from one provider must not erase fields found by another. Prefer native localized title only if nonempty, then source localized text, then source English name.
- Source constraints are provider faction/class/race facts, not independent UI settings in source windows. Unknown constraints do not block records. Do not copy provider tables or mutate them. Provide source names for diagnostics.
- Fixtures exercise three unique contributions, duplicate IDs, all wings, synthetic IDs, unavailable sources, faction/class filtering, source-only records missing Questie, repeatability, live acceptance and completion at Data boundary.

## Task 2: model/controller integration

- Modify Data.New(db,zones,changed,sources) to accept source object. List uses sources:List(inst), never byZone for additional output. Active membership remains Questie/native but also considers accepted source-only IDs.
- Source additional records get current native done state, IsActive filter, and repeatability via source or native C_QuestLog.IsRepeatableQuest. No fallback to Questie additional on absent sources.
- Details for source-only quests use normalized source metadata; native accepted details remain authoritative. Keep selected-source lookup per current dungeon, clear obsolete details if quest was removed after completion.
- Core constructs Sources object, listens ADDON_LOADED for these providers, and sets TOC OptionalDeps for deterministic startup. Update version 0.1.1.
- Update tests/data.lua to provide explicit source catalogue fixtures rather than relying on Questie membership; remove completed-row contract. Run uv run python tests/check.py to see regression RED before implementation, once GREEN after integration.
- Bundle optional OpenMapQuestFixGuideData with no SavedVariables/UI/hooks. Relative external files: DungeonData, DungeonLoot, DungeonTrash, ClassData, ItemStatsData, DalaranData, ForeverDungeonUpdates, Verified1390, Verified1392, NewDungeonData, DungeonReference. Export only DUNGEONS/DQ/date. Include both owned addon folders in ZIP; never include external files. Validate against the installed modules and in the actual game loader.

## Task 3: actual verification/delivery

- Use installed provider namespaces in Lua acceptance script: independently collect IDs per provider and compare exact union against additional + native active/completed/faction filters. Verify duplicate and active exclusion, source provenance, unknown provider fallback empty and source-only quest details.
- In game open monastery Graveyard Additional and one extra quest; ensure active count unchanged and no completed duplicates. Additional-only fixture changes must not mutate real quest completion.
- Update README, CHANGELOG and existing design. uv run python tools/package.py; inspect ZIP CRC/runtime-only contents. Preserve older ZIP, no publication.
