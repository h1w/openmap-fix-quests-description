-- Fixtures mirror the three installed provider schemas; no provider UI is loaded.
local oldFaction, oldClass, oldRace, oldLocale = UnitFactionGroup, UnitClass, UnitRace, GetLocale
UnitFactionGroup = function() return 'Horde' end
UnitClass = function() return 'Mage', 'MAGE', 8 end
UnitRace = function() return 'Undead', 'Scourge', 5 end
GetLocale = function() return 'ruRU' end
local comp = {
    INSTANCES = {{id=189001,parentID=189,name='Scarlet Monastery',areaID=796},
        {id=189004,parentID=189,name='Scarlet Monastery',areaID=796}},
    QUESTS = {[189001]={{101,30,3,'English title',20},{102,30,1,'Alliance only',20}},
        [189004]={{103,40,2,'Other wing',30},{104,40,3,'Wrong class',30}}},
    QUESTCLASSES = {[104]=2}, QUESTSTARTITEMS = {[101]={444,'Letter'}},
}
local journal = {INSTANCE_ID_TO_DUNGEON={[189]='Scarlet Monastery'}, DB={
    ['Scarlet Monastery: Library']={quests={
        {id=101,name='English journal',objective='English objective',faction='Both',pickup='Archivist',repeatable=true},
        {id=105,name='Race denied',faction='Horde',unavailableRaces={Scourge=true}},
        {id=106,name='Class denied',faction='Both',classOnly='PALADIN'},
        {id=107,name='Race conflict',faction='Both'},
    }},
    ['Scarlet Monastery: Cathedral']={quests={{id=108,name='Cathedral only',faction='Horde'}}},
}}
local guide = {DUNGEONS={
    {key='smgy',en='Scarlet Monastery: Graveyard',q={101,102,104,107,109,110,'n:placeholder'}},
    {key='smarm',en='Scarlet Monastery: Armory',q={111}},
}, DQ={
    [101]={n='English guide',r='Локальное имя',lv=30,o='Локальная цель',oe='English goal',fa='H',pre={99}},
    [102]={n='Unknown faction cannot override denial'},
    [104]={n='Unknown class cannot override denial'},
    [107]={n='Human only',rc={1}},
    [109]={n='Mage only',cl=128,rc={5},fa='H',requirementsUnknown=true,g='Trainer'},
    [110]={n='No goal'}, [111]={n='Armory only'},
    [999]={n='Not a member'},
}}
local providers = {AzerothCompendium=comp,ForeverDungeonJournal=journal,ForeverGuide=guide}
local sources = NS.Sources.New(function(name) return providers[name] end)
local list = sources:List({189,'Scarlet Monastery - Graveyard'})
local count = 0
for _ in pairs(list) do count=count+1 end
assert(count==11, 'union deduplicates IDs and excludes nonmember DQ records and synthetic strings')
assert(list[101].sources.AzerothCompendium and list[101].sources.ForeverDungeonJournal and list[101].sources.ForeverGuide, 'provenance retains all duplicate owners')
assert(list[101].links.ForeverDungeonJournal=='Scarlet Monastery: Library' and list[101].links.ForeverGuide=='smgy' and list[101].links.AzerothCompendium==189001,'source union retains exact owner pages independently of winning text')
assert(list[101].name=='Локальное имя' and list[101].objectives[1].text=='Локальная цель', 'localized metadata overrides English only')
assert(list[101].objectives[1].finished==false and list[101].repeatable and list[101].pickup=='Archivist' and list[101].hasRequirements, 'duplicates preserve source-only metadata')
assert(not list[102].allowed and not list[104].allowed and not list[105].allowed and not list[106].allowed and not list[107].allowed, 'known faction class and race denials survive unknown duplicates')
assert(list[109].allowed and list[109].status=='unknownPrerequisites', 'matching class bitmask/race and unknown requirements are preserved')
assert(#list[110].objectives==0, 'missing goals are not fabricated')
assert(list[103] and list[108] and list[111], 'all wings belong to the whole numeric instance')
assert(comp.QUESTS[189001][1][4]=='English title' and journal.DB['Scarlet Monastery: Library'].quests[1].name=='English journal', 'union never mutates provider data')
-- Each installed provider works independently, and sources are discovered live.
for _,name in ipairs({'AzerothCompendium','ForeverDungeonJournal','ForeverGuide'}) do
    local single=NS.Sources.New(function(key) if key==name then return providers[key] end end):List({189,'unrelated wing label'})
    local id=name=='AzerothCompendium' and 103 or name=='ForeverDungeonJournal' and 108 or 111
    assert(single[id] and single[id].sources[name], 'independent provider must match by numeric instance identity: '..name)
end
    UnitFactionGroup=function() return 'Alliance' end
    UnitClass=function() return 'Paladin','PALADIN',2 end
    UnitRace=function() return 'Human','Human',1 end
    local changed=sources:List({189,'Scarlet Monastery'})
    assert(changed[102].allowed and changed[104].allowed and changed[106].allowed and changed[107].allowed, 'eligibility follows current faction class and race')
    assert(not changed[103].allowed and not changed[109].allowed, 'own-character restrictions ignore provider show-all settings')
    UnitFactionGroup=function() return 'Horde' end
    UnitClass=function() return 'Mage','MAGE',8 end
    UnitRace=function() return 'Undead','Scourge',5 end
providers.ForeverGuide.DUNGEONS[2].q[2]=112
providers.ForeverGuide.DQ[112]={n='New guide entry'}
assert(sources:List({189,'Scarlet Monastery'})[112], 'live guide additions are not hidden by stale caches')
assert(next(NS.Sources.New(function() end):List({189,'Scarlet Monastery'}))==nil, 'all providers absent means empty union without Questie fallback')
local customs={
    {2970,900001,16550,'The Drowned City'}, {3039,900002,16842,"Krol'dok Stronghold"},
    {2994,900003,16620,'Alcaz Prison'}, {2974,900004,16554,'Blackmaw Hold'},
    {3001,900005,16667,"The Shaper's Terrace"},
}
for _,row in ipairs(customs) do
    local provider={INSTANCES={{id=row[2],areaID=row[3],name=row[4]}},QUESTS={[row[2]]={{95775,40,3,'Custom quest',30}}}}
    local s=NS.Sources.New(function(key) if key=='AzerothCompendium' then return provider end end)
    assert(s:List({row[1],'Localized label'})[95775], 'synthetic Compendium IDs must map to real instance IDs')
    assert(not s:List({209,'Zul\'Farrak'})[95775], 'area IDs must not collide with instance IDs')
    provider.INSTANCES[1]={id=880000,areaID=row[3]}
    provider.QUESTS={[880000]={{95775,40,3,'Area-only custom quest',30}}}
    assert(s:List({row[1],'Localized label'})[95775], 'custom AreaTable identity resolves without assuming it is an instance ID')
end
local aliases={ForeverDungeonJournal={DB={['Sunken Temple']={quests={{id=201,name='Temple'}}},['Molten Core']={quests={{id=202,name='Raid'}}}}},
    ForeverGuide={DUNGEONS={{en="The Temple of Atal'Hakkar",q={203}}},DQ={[203]={n='Guide temple'}}}}
local a=NS.Sources.New(function(name) return aliases[name] end)
assert(a:List({109,'Sunken Temple'})[201] and a:List({109,'Sunken Temple'})[203], 'explicit Temple alias joins providers')
assert(a:List({409,'Localized raid'})[202], 'raids work without journal instance mapping')
aliases.ForeverDungeonJournal.ContentLocales={ruRU={quests={[202]={name='Локальный рейд',objective='Цель рейда'}}}}
local raid=a:List({409,'Localized raid'})[202]
assert(raid.name=='Локальный рейд' and raid.objectives[1].text=='Цель рейда', 'journal content locale supplies localized name and goal without querying native quest APIs')
aliases.ForeverDungeonJournal.GetLanguage=function() return 'deDE' end
aliases.ForeverDungeonJournal.ContentLocales.deDE={quests={[202]={name='Deutscher Titel',objective='Deutsches Ziel'}}}
local clientRaid=a:List({409,'Localized raid'})[202]
assert(clientRaid.name=='Локальный рейд' and clientRaid.objectives[1].text=='Цель рейда', 'journal UI language cannot override client-localized source metadata')
aliases.ForeverGuide.DQ[203].guide={repeatable=true}
assert(a:List({109,'Sunken Temple'})[203].repeatable, 'guide route repeatable flag survives without another source')
aliases.ForeverGuide.DQ[203].guide.repeatable=false
assert(not a:List({109,'Sunken Temple'})[203].repeatable, 'guide route repeatability is read live and false is not repeatable')
assert(next(a:List({33,'Sunken Temple'}))==nil, 'numeric instance identity wins over a misleading display title')
-- Field priority is Journal, Guide, Compendium, not traversal order.
journal.ContentLocales={ruRU={quests={[101]={name='Название журнала',objective='Цель журнала',pickup='Выдаёт журнал'}}}}
journal.DB['Scarlet Monastery: Library'].quests[1].level=38
guide.DQ[101].lv=35
local preferred=sources:List({189,'Scarlet Monastery'})[101]
assert(preferred.name=='Название журнала' and preferred.objectives[1].text=='Цель журнала', 'Journal wins conflicts with localized Guide metadata')
assert(preferred.level==38 and preferred.pickup=='Выдаёт журнал', 'level and pickup independently obey Journal priority')
journal.ContentLocales.ruRU.quests[101].objective=nil
journal.DB['Scarlet Monastery: Library'].quests[1].objective=nil
local filled=sources:List({189,'Scarlet Monastery'})[101]
assert(filled.name=='Название журнала' and filled.objectives[1].text=='Локальная цель', 'missing Journal goal falls through without replacing its title')
journal.ContentLocales.ruRU.quests[101].pickup=nil
guide.DQ[101].guide={ru={pickup='Русский квестодатель'},pickup='Guide English giver'}
assert(sources:List({189,'Scarlet Monastery'})[101].pickup=='Русский квестодатель', 'localized Guide pickup beats untranslated Journal fallback')
providers.ForeverDungeonJournal=nil
local second=sources:List({189,'Scarlet Monastery'})[101]
assert(second.name=='Локальное имя' and second.level==35, 'Guide wins over Compendium without Journal')
providers.ForeverGuide=nil
local third=sources:List({189,'Scarlet Monastery'})[101]
assert(third.name=='English title' and third.level==30, 'Compendium supplies final fallback')
UnitFactionGroup, UnitClass, UnitRace, GetLocale = oldFaction, oldClass, oldRace, oldLocale
print('PASS: strict provider union, identity aliases, localization and intersected restrictions')
