local _, NS = ...
local Sources = {}
NS.Sources = Sources
local PRIORITY = {ForeverDungeonJournal=1, ForeverGuide=2, AzerothCompendium=3}

-- Instance map IDs, not AreaTable or UI map IDs. Provider wing names are
-- deliberately collapsed: OpenMap's selected floor must not trim the union.
local names = {
    [33]={'Shadowfang Keep'}, [34]={'The Stockade','The Stockades'},
    [36]={'The Deadmines','Deadmines'}, [43]={'Wailing Caverns'},
    [47]={'Razorfen Kraul'}, [48]={'Blackfathom Deeps'}, [70]={'Uldaman'},
    [90]={'Gnomeregan'}, [109]={'Sunken Temple',"The Temple of Atal'Hakkar"},
    [129]={'Razorfen Downs'}, [189]={'Scarlet Monastery'},
    [209]={"Zul'Farrak"}, [229]={'Blackrock Spire','Lower Blackrock Spire','Upper Blackrock Spire'},
    [230]={'Blackrock Depths'}, [249]={"Onyxia's Lair"}, [289]={'Scholomance'},
    [309]={"Zul'Gurub"}, [329]={'Stratholme'}, [349]={'Maraudon'},
    [389]={'Ragefire Chasm'}, [409]={'Molten Core'}, [429]={'Dire Maul'},
    [469]={'Blackwing Lair'}, [509]={"Ruins of Ahn'Qiraj"},
    [531]={"Ahn'Qiraj","Temple of Ahn'Qiraj"}, [533]={'Naxxramas'},
    [2959]={'City of Dalaran'}, [2970]={'The Drowned City'},
    [2974]={'Blackmaw Hold'}, [2994]={'Alcaz Prison'},
    [2998]={'Excavation Site: Wetlands'}, [2999]={'Ruins of Lordaeron'},
    [3001]={"Shaper's Terrace","The Shaper's Terrace"},
    [3039]={"Krol'dok Stronghold"}, [3065]={'Hall of Thanes','The Hall of Thanes'},
}
local providerIDs = {
    [16919]=3065, [16611]=2999, [16732]=2998, [16544]=2959,
    [900001]=2970, [900002]=3039, [900003]=2994, [900004]=2974, [900005]=3001,
}
local customAreas = {
    [16919]=3065, [16611]=2999, [16732]=2998, [16544]=2959,
    [16550]=2970, [16842]=3039, [16620]=2994, [16554]=2974, [16667]=3001,
}
local nameIDs = {}
for id, aliases in pairs(names) do
    for _, name in ipairs(aliases) do nameIDs[name] = id end
end
local function nameID(name)
    if type(name) ~= 'string' then return nil end
    if nameIDs[name] then return nameIDs[name] end
    for _, group in ipairs({'Scarlet Monastery','Dire Maul','Stratholme','Maraudon','Blackrock Depths'}) do
        if name:sub(1,#group+1)==group..':' or name:sub(1,#group+3)==group..' - ' then
            return nameIDs[group]
        end
    end
end
local function text(value)
    if type(issecretvalue)=='function' and issecretvalue(value) then return nil end
    if type(value)=='string' and value:find('%S') then return value end
end
local function call(fn, ...)
    if type(fn)~='function' then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function hasBit(mask, id)
    return type(mask)~='number' or mask<=0 or type(id)~='number' or id<=0
        or math.floor(mask / 2^(id-1)) % 2 == 1
end
local function factionAllowed(required, faction)
    if not faction then return true end
    if required==1 or required=='A' or required=='Alliance' then return faction=='Alliance' end
    if required==2 or required=='H' or required=='Horde' then return faction=='Horde' end
    return true
end
local function nonempty(value)
    if type(value)=='table' then return next(value)~=nil end
    return value~=nil and value~=false and value~=''
end
local function restrictions(q, faction, class, classID, race, raceID)
    if not factionAllowed(q.faction or q.fa, faction) then return false end
    if q.classOnly and class and q.classOnly:upper()~=class then return false end
    if not hasBit(q.cl, classID) then return false end
    if type(q.unavailableRaces)=='table' and race and q.unavailableRaces[race] then return false end
    if type(q.rc)=='table' and raceID then
        local found=false
        for _, id in ipairs(q.rc) do if id==raceID then found=true break end end
        if not found then return false end
    end
    return true
end

function Sources.New(getter)
    local self = {}
    local function provider(name)
        local get = getter or NS.GetQuestProvider
        local value = call(get, name)
        if type(value)=='table' then return value end
    end
    function self:List(inst)
        local result = {}
        local fieldRanks = {}
        local instanceID = type(inst)=='table' and tonumber(inst[1])
        if not instanceID then return result end
        local locale = call(GetLocale) or 'enUS'
        local faction = call(UnitFactionGroup, 'player')
        local class, classID, race, raceID
        if type(UnitClass)=='function' then local _, token, id=UnitClass('player'); class,classID=token,id end
        if type(UnitRace)=='function' then local _, token, id=UnitRace('player'); race,raceID=token,id end
        local function add(id, source, q, name, objective, localizedName, localizedObjective, pickup, localizedPickup)
            id=tonumber(id)
            if not id or id<=0 or id~=math.floor(id) then return end
            local record=result[id]
            if not record then
                record={id=id,allowed=true,sources={},links={},objectives={},repeatable=false,status='notAccepted'}
                result[id]=record
            end
            local ranks=fieldRanks[id]
            if not ranks then ranks={}; fieldRanks[id]=ranks end
            local rank=PRIORITY[source]
            record.sources[source]=true
            record.allowed=record.allowed and restrictions(q,faction,class,classID,race,raceID)
            name=text(name)
            if name and (not record.name or localizedName and not record.localizedName
                or (not not localizedName)==(not not record.localizedName) and rank<(ranks.name or 99)) then
                record.name,record.localizedName=name,localizedName
                ranks.name=rank
            end
            objective=text(objective)
            if objective and (#record.objectives==0 or localizedObjective and not record.localizedObjectives
                or (not not localizedObjective)==(not not record.localizedObjectives) and rank<(ranks.objective or 99)) then
                record.objectives={{text=objective,finished=false}}
                record.localizedObjectives=localizedObjective
                ranks.objective=rank
            end
            local level=q.level or q.lv
            if type(level)=='number' and level>0 and rank<(ranks.level or 99) then record.level=level; ranks.level=rank end
            pickup=text(pickup) or text(q.pickup) or text(q.g)
            if pickup and (not record.pickup or localizedPickup and not record.localizedPickup
                or (not not localizedPickup)==(not not record.localizedPickup) and rank<(ranks.pickup or 99)) then
                record.pickup,record.localizedPickup=pickup,localizedPickup
                ranks.pickup=rank
            end
            record.repeatable=record.repeatable or q.repeatable==true
            local required=q.requirementsUnknown or nonempty(q.pre) or nonempty(q.pg) or nonempty(q.ps)
                or nonempty(q.pt) or nonempty(q.sk) or nonempty(q.rep) or nonempty(q.prerequisites)
            record.hasRequirements=record.hasRequirements or not not required
            if q.requirementsUnknown then record.status='unknownPrerequisites' end
            return record
        end
        local comp=provider('AzerothCompendium')
        if comp then
            local keys={[instanceID]=true}
            for _, dungeon in ipairs(comp.INSTANCES or {}) do
                local root=dungeon.parentID or dungeon.id
                local canonical=providerIDs[root] or (names[root] and root) or nameID(dungeon.name)
                    or customAreas[dungeon.areaID]
                if canonical==instanceID then keys[dungeon.id]=true end
            end
            -- Custom provider IDs also work when INSTANCES is not yet loaded.
            for id, canonical in pairs(providerIDs) do if canonical==instanceID then keys[id]=true end end
            for key in pairs(keys) do
                for _, row in ipairs((comp.QUESTS or {})[key] or {}) do
                    local id=row[1]
                    local record=add(id,'AzerothCompendium',{level=row[2],faction=row[3],cl=(comp.QUESTCLASSES or {})[id]},row[4])
                    if record then
                        local prior=record.links.AzerothCompendium
                        if not prior or key<prior then record.links.AzerothCompendium=key end
                        record.allowed=record.allowed and factionAllowed((comp.QUESTSIDES or {})[id],faction)
                        local chain=(comp.QUESTCHAINS or {})[id]
                        record.hasRequirements=record.hasRequirements or type(chain)=='table' and #chain>1
                            or nonempty((comp.QUESTPREANY or {})[id]) or false
                    end
                end
            end
        end
        local journal=provider('ForeverDungeonJournal')
        if journal then
            local content=(journal.ContentLocales or {})[locale] or {}
            local mapped=(journal.INSTANCE_ID_TO_DUNGEON or {})[instanceID]
            for key,dungeon in pairs(journal.DB or {}) do
                if nameID(key)==instanceID or mapped and (key==mapped or key:sub(1,#mapped+1)==mapped..':') then
                    for _,q in ipairs(dungeon.quests or {}) do
                        local translation=(content.quests or {})[q.id] or {}
                        local title=text(translation.name) or q.name
                        local goal=text(translation.objective) or q.objective
                        local record=add(q.id,'ForeverDungeonJournal',q,title,goal,text(translation.name)~=nil,text(translation.objective)~=nil,text(translation.pickup),text(translation.pickup)~=nil)
                        if record then
                            local prior=record.links.ForeverDungeonJournal
                            if not prior or key<prior then record.links.ForeverDungeonJournal=key end
                            record.hasRequirements=record.hasRequirements or nonempty((journal.QUEST_PREREQ_CHAINS or {})[q.id])
                            record.repeatable=record.repeatable or (journal.TRACKER_REPEATABLE_QUESTS or {})[q.id]==true
                        end
                    end
                end
            end
        end
        local guide=provider('ForeverGuide')
        if guide then
            for _,dungeon in ipairs(guide.DUNGEONS or {}) do
                if nameID(dungeon.en)==instanceID then
                    for _,id in ipairs(dungeon.q or {}) do
                        local q=(guide.DQ or {})[id] or {}
                        local title,goal,translatedTitle,translatedGoal=q.n,text(q.oe) or q.o,false,false
                        if locale=='ruRU' then
                            title=text(q.r) or title; goal=text(q.o) or goal
                            translatedTitle=text(q.r)~=nil; translatedGoal=text(q.o)~=nil
                        elseif guide.LZ then
                            local titleTranslation=(guide.LZ.q or {})[id]
                            local goalTranslation=(guide.LZ.qo or {})[id]
                            title=text(titleTranslation) or title; goal=text(goalTranslation) or goal
                            translatedTitle=text(titleTranslation)~=nil; translatedGoal=text(goalTranslation)~=nil
                        end
                        local route=q.guide
                        local localPickup=type(route)=='table' and locale=='ruRU' and type(route.ru)=='table' and text(route.ru.pickup)
                        local pickup=localPickup or type(route)=='table' and text(route.pickup)
                        local record=add(id,'ForeverGuide',q,title,goal,translatedTitle,translatedGoal,pickup,not not localPickup)
                        if record and dungeon.key then
                            local prior=record.links.ForeverGuide
                            if not prior or dungeon.key<prior then record.links.ForeverGuide=dungeon.key end
                        end
                        if record and type(route)=='table' then
                            record.repeatable=record.repeatable or route.repeatable==true
                        end
                    end
                end
            end
        end
        return result
    end
    return self
end
