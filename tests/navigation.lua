-- Catch wrong-wing routing, stale availability, first-result selection and filter mutation.
local loaded, providers, timers, messages = {}, {}, {}, {}
C_AddOns={IsAddOnLoaded=function(name) return loaded[name] end}
local originalGet=NS.GetQuestProvider
NS.GetQuestProvider=function(name) if loaded[name] then return providers[name] end end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function tick() local q=timers; timers={}; for _,fn in ipairs(q) do fn() end end
NS.Print=function(text) messages[#messages+1]=text end
local record={id=42,inLog=false,sources={ForeverDungeonJournal=true,ForeverGuide=true,AzerothCompendium=true},links={
 ForeverDungeonJournal='Scarlet Monastery: Library',ForeverGuide='smlib',AzerothCompendium=189002}}
local nav=NS.Navigation
assert(nav and nav.List and nav.Open,'optional navigation adapter must be available')
assert(#nav.List(record)==0,'missing providers must not leave empty buttons')
local opened
local journal={DB={['Scarlet Monastery: Library']={quests={{id=42}}}},OpenQuestPage=function(page,id) opened={page,id} end}
providers.ForeverDungeonJournal=journal; loaded.ForeverDungeonJournal=true
ForeverDungeonJournalFrame={shown=false,IsShown=function(self) return self.shown end,Show=function(self) self.shown=true end}
assert(nav.Open('ForeverDungeonJournal',record))
assert(opened[1]=='Scarlet Monastery: Library' and opened[2]==42,'route by exact owner page, not map wing')
journal.IsDungeonLocked=function() return true end
assert(#nav.List(record)==0,'locked journal page must not advertise a working deep link')
journal.IsDungeonLocked=nil
record.inLog=true
assert(#nav.List(record)==1 and nav.Open('ForeverDungeonJournal',record),'active details offer exact provider navigation too')
record.inLog=false
loaded.ForeverDungeonJournal=false
assert(not nav.Open('ForeverDungeonJournal',record),'stale button cannot invoke disabled provider')
local dungeon={id=189002,type='dungeon',minLevel=30,maxLevel=41}
local comp={INSTANCES={dungeon},GetInstanceByID=function(_,id) if id==189002 then return dungeon end end,
 GetInstanceQuestGraph=function() return {{id=42}} end,IsQuestNodeMasked=function() return false end,
 GetSelectedContinent=function() end,GetFlavor=function() return 'forever' end}
local tree={OpenInstance=function(id) opened={'comp',id} end,FocusQuest=function(_,id) opened[3]=id; return true end}
AzerothCompendiumFrame={questTree=tree}
comp.OpenCompendium=function() end
providers.AzerothCompendium=comp; loaded.AzerothCompendium=true
ACOTABPC={QUESTVIEW='list'}
assert(nav.Open('AzerothCompendium',record) and opened[2]==189002 and opened[3]==42,'compendium focuses the exact source instance and quest')
assert(ACOTABPC.QUESTVIEW=='list','adapter must not change preferred quest view')
comp.GetInstanceQuestGraph=function() return {{id=7}} end
assert(#nav.List(record)==0,'filtered-out quest must not route to a different record')
loaded.AzerothCompendium=false
local function frame(children)
 return {children=children or {},shown=true,GetChildren=function(self) return unpack(self.children) end,
 IsShown=function(self) return self.shown end,IsVisible=function(self) return self.shown end}
end
local clicked
local wrong=frame(); wrong.entry={kind='quests',v={id=41}}
function wrong:GetScript() return function() error('must not choose matching title with wrong ID') end end
local target=frame(); target.entry={kind='quests',v={id=42}}
function target:GetScript() return function(self) clicked=self.entry.v.id; ForeverGuideGlobalSearch.text='' end end
local drop=frame({wrong,target}); drop.shown=false
ForeverGuideFrame=frame({drop})
local box={text=''}
function box:SetText(text) self.text=text end
function box:GetText() return self.text end
function box:GetScript(event) if event=='OnTextChanged' then return function() drop.shown=true end end end
ForeverGuideGlobalSearch=box
SlashCmdList={FOREVERGUIDE_MAIN=function(key) opened={'guide',key} end}
local guide={DUNGEONS={{key='smlib',q={42}}},DQ={[42]={n='Identical title'}}}
providers.ForeverGuide=guide; loaded.ForeverGuide=true
assert(nav.Open('ForeverGuide',record))
for _=1,3 do tick() end
assert(clicked==42 and opened[2]=='smlib','guide must click only real matching quest-ID result')
clicked=nil; target.entry.v.id=99
assert(nav.Open('ForeverGuide',record)); box.text='user changed query'; tick()
assert(not clicked,'user query change cancels pending guide navigation')
assert(nav.Open('ForeverGuide',record)); ForeverGuideFrame.shown=false; tick()
assert(not clicked,'closing guide cancels pending navigation')
ForeverGuideFrame.shown=true
assert(nav.Open('ForeverGuide',record)); nav.Cancel(); target.entry.v.id=42; tick()
assert(not clicked,'selection cancellation prevents a delayed jump to the old quest')
target.entry.v.id=99
assert(nav.Open('ForeverGuide',record))
for _=1,55 do tick() end
assert(not clicked and box.text=='','missing exact result times out without opening another quest')
local originalSlash=SlashCmdList.FOREVERGUIDE_MAIN
SlashCmdList.FOREVERGUIDE_MAIN=function() error('provider failure') end
assert(not nav.Open('ForeverGuide',record),'provider failure must be contained and reported')
SlashCmdList.FOREVERGUIDE_MAIN=originalSlash
providers.ForeverGuide=nil
assert(#nav.List(record)==0,'missing live provider data removes action')
NS.GetQuestProvider=originalGet
print('PASS: optional exact-ID navigation, wing ownership, filters and guide cancellation')
