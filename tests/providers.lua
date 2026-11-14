local _, NS = ...
local loaded = {ForeverGuide=true,ForeverDungeonJournal=true,AzerothCompendium=true}
local calls = 0
local journal = {DB={}}
_G.ForeverDungeonJournal_NS = journal
local compendium = {QUESTS={},INSTANCES={},GetAddonMeta=function() return 'AzerothCompendium by author' end}
_G.D4SharedSettingsRegistry = {entries={{owner=compendium}}}
C_AddOns = {
    IsAddOnLoaded=function(name) return loaded[name] end,
    GetAddOnLocalTable=function() return nil end,
    LoadAddOn=function(name)
        assert(name=='OpenMapQuestFixGuideData')
        calls=calls+1
        _G.OpenMapQuestFixGuideData={DUNGEONS={},DQ={}}
        return true
    end,
}
assert(NS.GetQuestProvider('ForeverDungeonJournal')==journal)
assert(NS.GetQuestProvider('AzerothCompendium')==compendium)
assert(NS.GetQuestProvider('ForeverGuide')==_G.OpenMapQuestFixGuideData and calls==1)
assert(NS.GetQuestProvider('ForeverGuide') and calls==1, 'do not reload isolated catalogue on refresh')
loaded.ForeverGuide=false
assert(NS.GetQuestProvider('ForeverGuide')==nil, 'disabled provider cannot contribute cached bridge')
loaded.ForeverGuide=true
_G.OpenMapQuestFixGuideData=nil
NS.ResetQuestProviders()
C_AddOns.LoadAddOn=function() calls=calls+1; return nil,'MISSING' end
assert(NS.GetQuestProvider('ForeverGuide')==nil)
assert(NS.GetQuestProvider('ForeverGuide')==nil and calls==2, 'missing optional bridge must not retry every refresh')
local native={DUNGEONS={},DQ={}}
C_AddOns.GetAddOnLocalTable=function(name) if name=='ForeverGuide' then return native end end
assert(NS.GetQuestProvider('ForeverGuide')==native, 'native opted-in namespace wins without bridge')
print('PASS: read-only optional provider access and isolated guide bridge lifecycle')
