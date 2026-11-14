# OpenMapQuestFix

Approved behavior: a separate WoW Forever 1.60.1 addon repairs the dungeon Quests tab without modifying OpenMap, Questie, or OpenMapDungeonRoutes files. Target installed OpenMap v0.8.8, Interface 16001, Lua 5.1.

## Identity and data

Resolve instance IDs through Questie's ZoneDB.instanceIdToAreaId, then normalize dungeon alternative areas. Never use OpenMap's decorated wing display name as an identity. Show quests for the whole dungeon, including other wings. Active quests come from C_QuestLog by quest ID; Questie and the three source catalogues supply membership. Active log membership takes precedence over database race/class filtering.

Additional quests are the deduplicated union of dungeon catalogues from installed AzerothCompendium, ForeverDungeonJournal and ForeverGuide, keyed by numeric quest ID. Questie never contributes additional membership or a fallback catalogue. Remove all currently accepted quests and completed nonrepeatable quests; retain explicitly repeatable quests after previous completion. Preserve own-faction/class/race filtering from source facts. Pending prerequisites and minimum level do not hide a catalogue quest or imply that it is available. If a source is absent, read the other installed sources; if all are absent, show an empty additional section without a Questie fallback. Read publicly available live namespaces for journal/Compendium, or the native getter when a provider opts in. ForeverGuide has no public namespace and does not opt in: a bundled optional LoadOnDemand adapter loads the installed guide's data-only modules into its own private namespace through relative TOC paths. No upstream files, globals or SavedVariables are changed; no provider assets or databases are redistributed. Source aliases and synthetic instance IDs are resolved to the selected numeric instance, with all wings merged.

## Surface

Replace only the contents below the dungeon's existing tabs while Quests is selected. Keep the title, tab rail, map, floor, pan, zoom, route overlays, and native quest log untouched. Active rows have wrapped difficulty-colored titles, status icons, objective progress, and a separate tracking checkbox. Clicking a row opens description, objectives and rewards inside this panel, with Back restoring list scroll. The additional section is collapsible. All copy is RU/EN.

Detail cards reuse native Blizzard atlases, QuestTitleFont/QuestFont and reward button templates, not the global QuestMapFrame.DetailsFrame singleton or QuestInfo_Display. The dark list stays unchanged. Native-looking parchment text and brown toolbar/reward section replace the old cropped flat texture and generic shadowed fonts. Metadata priority per nonempty field is DungeonJournal, ForeverGuide, AzerothCompendium, retaining client-localized text over untranslated fallback. Active game data remains authoritative.

An optional CatQuest button is created through CatQuestCore.CreateFrameButton and reads the displayed quest ID. Its playback/queue state derives from that ID rather than selected native journal quest. Native/saved CatQuest ReadQuest calls restore native selection synchronously even on failure; source-only known text goes through CatQuestCore playback with quest metadata. No direct substitute TTS engine, provider file modifications, fake description or global API replacement. Poll CatQuest playback state only while the button's card is visible.

Native client reads supply accepted quest descriptions and rewards. Database-only quests show their known objectives and status, without fabricated description or rewards. Item rewards have icons, quantities and tooltips. Update on journal/progress/watch/reward-data events. Preserve selected details and scrolling across refresh; clear selection on a different dungeon. Never expand/collapse native journal headers to enumerate quests. Never trigger native quest detail navigation, which can close or replace the dungeon map.

## Boundaries

Sources.lua reads the three installed provider tables and normalizes their dungeon quests. Data.lua owns active membership, live quest snapshots and exclusion of accepted/completed additional records. Panel.lua owns reusable UI rows, details and interaction state. Host.lua owns access to OpenMapDungeonView internals and replacement lifecycle. Core.lua owns loading and event coalescing. Unsupported host shape leaves the original UI visible and reports a specific error. Disabling the addon and reloading restores unmodified OpenMap.

## Verification

Regression fixtures exercise wing/decorated-name independence, parent areas, active quests missing from the DB, class/race filtering of additional quests, hidden native headers, selection and live progress. Lua 5.1 syntax and scenarios run with uv/lupa. Actual game verification: Graveyard lists the two monastery quests, open each, inspect description/rewards, Back, tracking, switch floors/tabs, native journal, close/reopen map. No claims about unobserved live behavior.
