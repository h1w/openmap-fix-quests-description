local _, catalogue = ...
-- Only installed data files are loaded, into this adapter's private namespace.
-- No ForeverGuide UI, events, SavedVariables or live provider tables are changed.
_G.OpenMapQuestFixGuideData = {
    DUNGEONS = catalogue.DUNGEONS,
    DQ = catalogue.DQ,
    DUNGEON_REFERENCE_DATE = catalogue.DUNGEON_REFERENCE_DATE,
}
