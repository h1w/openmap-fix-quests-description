# Native-style quest details and CatQuest

Approved: independent quest card assembled from existing Blizzard templates/fonts/atlases, not the singleton QuestMapFrame.DetailsFrame; keep map/floor/zoom/routes and native journal selection unchanged. List stays dark. Add functional CatQuest Read button for the currently displayed record. Metadata priority DungeonJournal, ForeverGuide, AzerothCompendium, first nonempty field; union membership unchanged.

## Native evidence

Forever UI QuestMapFrame_ShowQuestDetails changes native selection and SetMapID; QuestInfo_Display reparents global singleton text/reward widgets. Do not call either. Actual game probes confirmed QuestFramePanelTemplate Bg atlas QuestBG-Parchment, QuestFont and SmallQuestRewardItemButtonTemplate. FrameXML research under Z:/Dev/h1w/native-quest-ui-research, outside repo; do not redistribute Blizzard source/assets.

## Task 1: priority

Sources.lua/tests/sources.lua: define rank journal=1 guide=2 compendium=3 per text/level/pickup field. Missing field falls through. Keep localized text preferred to untranslated fallback, deterministic rank among comparable locale fields. Preserve AND restrictions and OR repeatability/provenance. Regression conflict fixtures assert journal wins, then guide without journal, then compendium; goals/name/level/pickup independently filled.

## Task 2: native components

Panel.lua: retain list behavior, data model and callbacks. Replace cropped QuestBG and body GameFontHighlight on parchment with QuestDetailsBackgrounds/QuestBG-Parchment atlas, QuestTitleFont/QuestFont font objects without shadows/outline. Header uses questlog-reward-top-frame; Back left, CatQuest reader right. Details start with title, summary/objectives then Description; no redundant Objectives header before native summary. Rewards use native header top/tile/bottom atlases and QuestFont_Huge label, native SmallQuestRewardItemButtonTemplate populated from record (override built-in selected-quest scripts with explicit questID tooltip/link), XP/money reward cards. No borrowing native frame or selection, no copied assets. Handle resize/list/detail transition/scroll preservation. Native templates available target client; fail visibly if unsupported rather than fake placeholders.

## Task 3: CatQuest

Reader.lua/tests/reader.lua: use published CatQuestCore and its CreateFrameButton factory to create the button; no provider edits or reparenting original journal button. NS.Reader.New(parent) returns button with SetQuest(record) and Refresh methods. If CatQuest absent/incompatible hide button. State derived from core.state/queue and displayed quest.id, never global selected quest: read, stop, enqueue, queued. Explicit click uses core.ReadQuest(id, enqueue) for native/saved text with synchronous native selection restored on success or error; additional source-only fallback uses only known record text through CatQuestCore.Speak/Enqueue and FillSpeaker by questID. No direct TTS implementation or invented descriptions. Respect CatQuest readTitle/readObjectives settings; no change saved settings. Preserve native journal selection, map and focused quest. Stop uses CatQuest ClearQueue as native journal button; queued state disabled. Refresh while visible only at 0.25s for playback state, never rebuild card.

## Integration and proof

TOC OptionalDeps CatQuest; Reader before Panel; version 0.1.2. tests/check.py load Reader for isolated scenarios. Parent integrates/validates once after disjoint slices complete. Unit cases actual wanted quest when native selection differs, missing CatQuest, stop/queue states, restore selection on error. UI proof in running game active quest title/description/reward view and Read starts correct quest, stop works; additional record can be read without selection navigation. No quest acceptance/abandonment. Update README/CHANGELOG, package two owned folders only, no upstream file changes/commits/push.
