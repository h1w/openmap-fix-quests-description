# Optional provider quest navigation

Approved: three optional integrations on additional-quest details, ordered DungeonJournal, ForeverGuide, AzerothCompendium. All implementation stays in our addon; never modify provider files, preferences, quest state or the map. Existing task branch fix/dungeon-quest-panel retains the current uncommitted addon implementation.

## Adapter contract

Create Navigation.lua after Sources/Data and before Panel. NS.Navigation.List(record) returns available {key,label,open} actions only for record.inLog == false and real provider membership. NS.Navigation.Open(key,record) re-resolves current availability, contains errors and reports an honest unavailable message. Providers must be loaded and compatible. Keep per-provider exact page keys in record.links during source union, independent of metadata priority.

- DungeonJournal: store actual DB dungeon key containing ID. Show its frame before OpenQuestPage(key,id); use OpenQuestFromWorldMap only when its own overlay is already attached. Respect RPG dungeon/quest locks. Never infer wing from OpenMap floor.
- ForeverGuide: use accessible live namespace ShowQuestCard if provided; otherwise invoke its existing slash handler with exact catalogue dungeon key, then use its named global search. Set query to that provider's own English quest title, dispatch existing OnTextChanged(self,true), and inspect actual search result rows scoped to ForeverGuideFrame. Invoke existing left-click only for entry.kind == quests and entry.v.id == wanted ID. Never inject a synthetic row, access Lua upvalues, pick first result, change filters or reload foreign UI. Built-in search indexing is asynchronous: wait at most 5 seconds with cancellation on window close/query change/new navigation. Clear query and report if no exact match. No calls to OnEnterPressed (it has a first-result/item fallback).
- AzerothCompendium: resolve live registered provider, OpenCompendium; use AzerothCompendiumFrame.questTree.OpenInstance(id), then FocusQuest(questID). Preserve list/tree preference, spoiler and class/faction/completion filters. Preflight exact membership in visible instance quest graph and current instance filtering; report unavailable instead of silently opening another quest.

## UI

Panel.lua inserts 'Open in' and vertically stacked native buttons immediately below additional quest title. Full available text width, height22 with6 gap, so three names fit a narrow pane. Reuse frames across renders; hide on active/list views, no gap if actions absent. Click resolves current selected record, not stale closure. Existing Back/CatQuest toolbar unchanged.

## Execution

1. Add isolated navigation regression scenarios for missing/disabled providers, exact page IDs, disjoint source provenance, guide exact-ID versus duplicate-title results, cancellation/timeouts and contained failures; extend panel consumer scenarios for extra buttons, resize and stale selection. Observe expected failure before implementation.
2. Implement source page links, Navigation module, localized labels and pooled UI. Run Lua5.1 scenarios once after integration, fix any observed failure at cause.
3. Install only our runtime folders, reload and click all integrations in the real game. For additional96800 verify DungeonJournal/ForeverGuide, Compendium absent as it lacks this quest. Exercise Compendium with a genuinely unaccepted catalogue quest in another dungeon without accepting/abandoning quests. Check map/floor/zoom/native quest selection before and after.
4. Update README/CHANGELOG, bump both own TOCs to0.1.3, build ZIP and verify owned runtime bytes. No commit/push/publication.
