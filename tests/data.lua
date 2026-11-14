local _, NS = ...

local function equal(actual, expected, message)
    assert(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function find(rows, id)
    for _, row in ipairs(rows) do
        if row.id == id then return row end
    end
end

local function fixture(options)
    options = options or {}
    local state = {timers = {}, queries = 0, notifications = 0, selected = 444, textCalls = {}, watched = {[1050] = 0},
        active = {[1050] = true, [1053] = true, [9999] = true}, completed = {[1200] = true}, repeatable = {}, progress = 0, shift = 0}
    local records = {
        [1050] = {name = "Mythology", questLevel = 38, zoneOrSort = 796, requiredRaces = 2, requiredClasses = 2},
        [1053] = {name = "In the Name of the Light", questLevel = 40, zoneOrSort = 10008},
        [1100] = {name = "Another wing", questLevel = 35, zoneOrSort = 10010, objectivesText = {"Find the book"}},
        [1101] = {name = "Wrong race", questLevel = 35, zoneOrSort = 796, requiredRaces = 2},
        [1102] = {name = "Wrong class", questLevel = 35, zoneOrSort = 796, requiredClasses = 2},
        [1103] = {name = "Prerequisite", questLevel = 35, zoneOrSort = 796, preQuestSingle = {777}},
        [1104] = {name = "Parent area", questLevel = 35, zoneOrSort = 12345},
        [1200] = {name = "Already completed", questLevel = 35, zoneOrSort = 796},
        [1300] = {name = "Unrelated Questie quest", questLevel = 35, zoneOrSort = 796},
    }
    state.catalogue = {
        [1050] = {id = 1050, sources = {AzerothCompendium = true}},
        [1053] = {id = 1053, sources = {ForeverDungeonJournal = true}},
        [1100] = {id = 1100, sources = {ForeverGuide = true}},
        [1101] = {id = 1101, allowed = false, sources = {AzerothCompendium = true}},
        [1102] = {id = 1102, sources = {ForeverDungeonJournal = true}},
        [1103] = {id = 1103, sources = {ForeverGuide = true}},
        [1104] = {id = 1104, sources = {AzerothCompendium = true}},
        [1200] = {id = 1200, sources = {ForeverGuide = true}},
    }
    local pointers = {}
    for id in pairs(records) do pointers[id] = true end
    if options.large then
        for id = 20000, 20600 do pointers[id] = true; records[id] = {zoneOrSort = 12, name = "Outside"} end
    end
    local db = {QuestPointers = pointers}
    if options.latePointers then
        db.QuestPointers = nil
        state.publishPointers = function() db.QuestPointers = pointers end
    end
    function db.QueryQuestSingle(id, field)
        state.queries = state.queries + 1
        return records[id] and records[id][field]
    end
    local zones = {instanceIdToAreaId = {[189] = options.alias and 10008 or 796}}
    if options.unknownArea then zones.instanceIdToAreaId = {} end
    if options.unmapped then zones.instanceIdToAreaId = {} end
    function zones:GetDungeons()
        if options.delayed and not state.ready then return nil end
        return {[796] = {"Scarlet Monastery", {10008, 10009, 10010}}}
    end
    function zones:GetParentZoneId(area) if area == 12345 then return 10009 end end
    function zones:GetAreaIdByName(name)
        equal(name, "Scarlet Monastery", "fallback uses undecorated native name")
        if options.unknownArea then return nil end
        return 796
    end
    local player = {currentQuestlog = options.emptyProvider and {} or {[1050] = true, [1053] = true, [9999] = true}}
    function player.HasRequiredRace(mask) return not mask or mask == 0 or mask % 2 >= 1 end
    function player.HasRequiredClass(mask) return not mask or mask == 0 or mask % 2 >= 1 end
    QuestieLoader = {ImportModule = function(_, name)
        if name == "QuestiePlayer" then return player end
        if name == "QuestLogCache" then return {questLog_DO_NOT_MODIFY = {}} end
    end}
    C_Timer = {After = function(_, callback) state.timers[#state.timers + 1] = callback end}
    GetRealZoneText = function(id) equal(id, 189, "native name uses instanceID"); return "Scarlet Monastery" end
    local function info(index)
        if index == 1 then return {title = "Scarlet Monastery", isHeader = true, isCollapsed = options.collapsed or false} end
        if index > 1 then index = index - state.shift end
        if options.collapsed then return nil end
        if index == 2 and state.active[1050] then return {title = "Native Mythology", level = 38, questID = 1050} end
        if index == 3 and state.active[1053] then return {title = "Native Light", level = 40, questID = 1053} end
        if index == 4 and state.active[9999] then return {title = "Undocumented accepted quest", level = 36, questID = 9999} end
    end
    C_QuestLog = {
        GetNumQuestLogEntries = function() return options.collapsed and 1 or 4, 3 end,
        GetInfo = info,
        GetLogIndexForQuestID = function(id)
            local index = ({[1050] = 2, [1053] = 3, [9999] = 4})[id]
            if state.active[id] and index then return index + state.shift end
        end,
        IsOnQuest = function(id) return state.active[id] or false end,
        GetTitleForQuestID = function(id) return ({[1050] = "Native Mythology", [1053] = "Native Light", [9999] = "Undocumented accepted quest"})[id] end,
        GetQuestObjectives = function(id)
            assert(state.active[id], "objectives must only be requested for active IDs")
            return {{text = "Defeat target: " .. state.progress .. "/1", numFulfilled = state.progress, numRequired = 1, finished = state.progress == 1}}
        end,
        IsComplete = function(id) return id == 1050 and state.progress == 1 end,
        IsFailed = function(id) return state.failed == id end,
        IsQuestFlaggedCompleted = function(id) return state.completed[id] or false end,
        IsRepeatableQuest = function(id) return state.repeatable[id] or false end,
        GetQuestWatchType = function(id) return state.watched[id] end,
        AddQuestWatch = function(id) state.watched[id] = 0; return true end,
        RemoveQuestWatch = function(id) state.watched[id] = nil; return true end,
        GetSelectedQuest = function() return state.selected end,
        SetSelectedQuest = function(id) state.selected = id end,
    }
    ExpandQuestHeader = function() error("must not expand native headers") end
    CollapseQuestHeader = function() error("must not collapse native headers") end
    SelectQuestLogEntry = function() error("must not select native quest") end
    GetQuestLogQuestText = function(index)
        state.textCalls[#state.textCalls + 1] = index
        if index == 2 + state.shift then return "Full accepted description", "Accepted summary" end
        if index == 3 + state.shift then return "Light description", "Light summary" end
    end
    GetNumQuestLogRewards = function(id) equal(id, 1053, "guaranteed rewards use quest ID"); return 1 end
    GetNumQuestLogChoices = function(id) equal(id, 1053, "choice rewards use quest ID"); return 1 end
    GetQuestLogRewardInfo = function(index, id) equal(index, 1); equal(id, 1053); return "Guaranteed item", 501, 2, 3, true, 601 end
    GetQuestLogChoiceInfo = function(index, id)
        equal(id, nil, "choices use live selected entry"); equal(state.selected, 1053)
        if index > 1 then return end
        return "Choice item", 502, 1, 3, true, 602
    end
    GetQuestLogItemLink = function(kind, index, id)
        equal(index, 1)
        if kind == "choice" then equal(id, nil); equal(state.selected, 1053) else equal(id, 1053) end
        return "item:" .. (kind == "choice" and "602" or "601")
    end
    GetQuestLogRewardMoney = function(id) equal(id, 1053); return 15300 end
    GetQuestLogRewardXP = function(id) equal(id, 1053); return 15300 end
    IsRepeatableQuest = nil
    local instance = {189, "Scarlet Monastery — Graveyard (wing)"}
    local sources
    if not options.omitSources then
        sources = {List = function(_, inst)
            equal(inst, instance, "source lookup receives original OpenMap instance")
            return state.catalogue
        end}
    end
    local data = NS.Data.New(db, zones, function() state.notifications = state.notifications + 1 end, sources)
    local function drain()
        local iterations = 0
        while #state.timers > 0 do
            iterations = iterations + 1
            assert(iterations < 100, "index must finish in bounded chunks")
            table.remove(state.timers, 1)()
        end
    end
    return data, state, instance, drain, records
end

-- A decorated wing title must not become the zone identity; all monastery wings belong together.
do
    local data, state, instance, drain = fixture({large = true})
    data:Start()
    local before = data:List(instance)
    assert(find(before.active, 1050) and find(before.active, 1053), "accepted quests stay usable during indexing")
    assert(before.loading, "large database indexing must yield")
    assert(state.queries < 600, "Start/List must not synchronously scan the full provider database")
    drain()
    local model = data:List(instance)
    equal(model.loading, false); equal(model.known, true)
    equal(#model.active, 3)
    assert(find(model.active, 9999), "native header retains an accepted quest missing from QuestieDB")
    assert(find(model.additional, 1100), "other wing belongs to whole dungeon")
    assert(find(model.additional, 1104), "parent zone aliases normalize recursively")
    assert(not find(model.additional, 1101), "opposite race is excluded only from additional quests")
    assert(not find(model.additional, 1102), "opposite class is excluded only from additional quests")
    equal(find(model.additional, 1103).status, "unknownPrerequisites")
    assert(not find(model.additional, 1200), "completed nonrepeatable quests are hidden")
    assert(not find(model.additional, 1300), "Questie area membership cannot add unrelated quests")
    equal(find(model.additional, 1100).status, "notAccepted")
    equal(find(model.additional, 1100).description, nil)
    equal(find(model.additional, 1100).objectives[1].text, "Find the book")
    assert(find(model.active, 1050), "native acceptance overrides opposite race and class masks")
    local reads = state.queries
    for _ = 1, 3 do data:List(instance) end
    assert(state.queries - reads < 300, "refreshes must not rescan unrelated provider quests")
    data:Start(); drain()
    assert(state.notifications >= 1, "completed indexing notifies host")
end

-- Mapping can itself be an alternative area; list output cannot depend on an English label.
do
    local data, _, instance, drain = fixture({alias = true})
    data:Start(); drain()
    instance[2] = "Completely unrelated decorated label"
    assert(find(data:List(instance).active, 1053), "alternative mapped area resolves to canonical monastery")
end

-- Progress, membership and completion are live native reads, not a permanent snapshot.
do
    local data, state, instance, drain = fixture()
    data:Start(); drain()
    equal(find(data:List(instance).active, 1050).objectives[1].text, "Defeat target: 0/1")
    state.progress = 1
    local updated = find(data:List(instance).active, 1050)
    equal(updated.objectives[1].text, "Defeat target: 1/1"); equal(updated.objectives[1].finished, true)
    equal(updated.complete, true); equal(updated.status, "complete")
    state.failed = 1053
    equal(find(data:List(instance).active, 1053).status, "failed")
    state.active[1050] = nil
    equal(data:IsActive(1050), false)
    assert(not find(data:List(instance).active, 1050), "stale provider pointer cannot resurrect abandoned quest")
end

-- Text takes the current log index; choices use the live entry and restore selection.
do
    local data, state, instance, drain = fixture()
    data:Start(); drain()
    data:List(instance)
    local details = data:Details(1053)
    equal(details.description, "Light description"); equal(details.summary, "Light summary")
    equal(state.textCalls[1], 3, "text receives current log index, never questID")
    equal(details.money, 15300); equal(details.xp, 15300); equal(#details.rewards, 2)
    local guaranteed, choice
    for _, reward in ipairs(details.rewards) do if reward.choice then choice = reward else guaranteed = reward end end
    equal(guaranteed.name, "Guaranteed item"); equal(guaranteed.texture, 501); equal(guaranteed.count, 2)
    equal(guaranteed.link, "item:601"); equal(guaranteed.index, 1)
    equal(choice.name, "Choice item"); equal(choice.texture, 502); equal(choice.count, 1)
    equal(choice.link, "item:602"); equal(choice.index, 1)
    equal(state.selected, 444)
    state.shift = 1
    equal(data:Details(1053).description, "Light description")
    equal(state.textCalls[2], 4, "details must resolve the current index after journal changes")
    local additional = data:Details(1100)
    equal(additional.description, nil); equal(additional.money, nil); equal(additional.xp, nil)
    equal(#state.textCalls, 2, "unaccepted quests cannot borrow selected quest text")
end

-- Watch type zero is watched (Lua truthiness); toggling is native and inactive quests are not watchable.
do
    local data, state, instance, drain = fixture()
    data:Start(); drain()
    equal(find(data:List(instance).active, 1050).watched, true)
    data:ToggleWatch(1050); equal(state.watched[1050], nil)
    equal(find(data:List(instance).active, 1050).watched, false)
    data:ToggleWatch(1050); equal(state.watched[1050], 0)
    equal(find(data:List(instance).active, 1050).watched, true)
    data:ToggleWatch(1100); equal(state.watched[1100], nil)
end

-- Completely hidden rows are discovered from provider pointers/IsOnQuest, never header expansion.
do
    local data, state, instance, drain = fixture({collapsed = true})
    data:Start(); drain()
    local model = data:List(instance)
    assert(find(model.active, 1050) and find(model.active, 1053), "collapsed DB quests retain native membership")
    assert(find(model.active, 9999), "provider-known missing DB quest uses native header by current log index")
    equal(state.selected, 444)
end

-- Without provider log caches the chunked DB pointer index still finds collapsed accepted quests.
do
    local data, _, instance, drain = fixture({collapsed = true, emptyProvider = true})
    data:Start(); drain()
    local model = data:List(instance)
    assert(find(model.active, 1050) and find(model.active, 1053), "IsOnQuest discovers hidden quests from DB pointers")
end

-- A missing instance map may use only the native undecorated instance name.
do
    local data, _, instance, drain = fixture({unmapped = true})
    data:Start(); drain()
    assert(find(data:List(instance).active, 1053), "native name fallback resolves canonical dungeon")
end

-- Accepted status changes after indexing, even for quests formerly shown as additional.
do
    local data, state, instance, drain = fixture()
    data:Start(); drain()
    state.active[1100] = true
    local model = data:List(instance)
    assert(find(model.active, 1100), "fresh IsOnQuest state moves additional quest into active list")
    assert(not find(model.additional, 1100), "newly accepted quest cannot appear twice")
end

-- Provider readiness retries are bounded timers and Start cannot rebuild a finished index.
do
    local data, state, instance, drain = fixture({delayed = true})
    data:Start()
    equal(data:List(instance).loading, true)
    equal(#state.timers, 1)
    state.ready = true
    drain()
    equal(data:List(instance).loading, false)
    equal(state.notifications, 1)
    local reads = state.queries
    data:Start(); drain()
    equal(state.queries, reads, "repeated Start must not rescan database")
    equal(state.notifications, 1)
end

-- Early native records cannot permanently cache absent database metadata before pointers arrive.
do
    local data, state, instance, drain, records = fixture({latePointers = true})
    records[1053].objectivesText = {"Defeat the monastery commanders"}
    local early = data:List(instance)
    equal(find(early.active, 1053).name, "Native Light")
    assert(find(early.active, 1050), "native header fallback works before provider pointers exist")
    state.publishPointers()
    data:Start(); drain()
    state.active[1050] = nil
    state.active[1053] = nil
    local ready = data:List(instance)
    local additional = find(ready.additional, 1053)
    assert(additional, "abandoned quest retains database entry after late readiness")
    equal(additional.name, "In the Name of the Light")
    equal(additional.objectives[1].text, "Defeat the monastery commanders")
    assert(not find(ready.additional, 1050), "late database masks filter abandoned opposite race/class quest")
end

-- Additional membership comes only from the live source catalogue, never Questie pointers.
do
    local data, state, instance, drain = fixture()
    data:Start(); drain()
    state.catalogue = {}
    local model = data:List(instance)
    equal(#model.additional, 0, "empty source catalogue has no Questie fallback")
    assert(find(model.active, 1053), "native accepted dungeon quests remain without sources")
    equal(data:Details(1100), nil, "removed source membership cannot survive in details")
end

-- Omitting the fourth argument selects the runtime source adapter, or an empty union.
do
    local original = NS.Sources
    NS.Sources = nil
    local data, _, instance, drain = fixture({omitSources = true})
    data:Start(); drain()
    equal(#data:List(instance).additional, 0, "missing adapter must not fall back to Questie extras")
    NS.Sources = {New = function()
        return {List = function() return {[1500] = {id = 1500, name = "Default source", level = 30, allowed = true}} end}
    end}
    data, _, instance, drain = fixture({omitSources = true})
    data:Start(); drain()
    assert(find(data:List(instance).additional, 1500), "omitted fourth argument creates default adapter")
    NS.Sources = original
end

-- Source metadata survives an unrelated Questie zone and overrides supplemental restrictions.
do
    local data, state, instance, drain, records = fixture()
    records[1100].zoneOrSort = 12
    records[1100].requiredRaces = 2
    records[1100].requiredClasses = 2
    state.catalogue[1100] = {
        id = 1100, name = "Локализованное задание", level = 37, allowed = true,
        objectives = {{text = "Найдите книгу", finished = false}},
        sources = {AzerothCompendium = true, ForeverGuide = true}, repeatable = true,
        status = "unknownPrerequisites", pickup = "Библиотекарь", hasRequirements = true,
    }
    data:Start(); drain()
    local row = find(data:List(instance).additional, 1100)
    assert(row, "source membership ignores mismatched Questie area and masks")
    equal(row.name, "Локализованное задание"); equal(row.level, 37)
    equal(row.objectives[1].text, "Найдите книгу"); equal(row.status, "unknownPrerequisites")
    equal(row.pickup, "Библиотекарь"); equal(row.hasRequirements, true); equal(row.repeatable, true)
    assert(row.sources.AzerothCompendium and row.sources.ForeverGuide, "all contributing sources survive")
    local details = data:Details(1100)
    equal(details.name, "Локализованное задание"); equal(details.objectives[1].text, "Найдите книгу")
    equal(details.pickup, "Библиотекарь"); equal(details.description, nil)
    state.active[1100] = true
    local accepted = data:List(instance)
    equal(find(accepted.active, 1100).name, "Локализованное задание", "accepted source membership overrides mismatched area")
    equal(find(accepted.active, 1100).objectives[1].text, "Defeat target: 0/1")
    assert(not find(accepted.additional, 1100), "mismatched-area accepted source quest is not duplicated")
    state.active[1100] = nil
    state.catalogue[1100].name = "Обновлённое задание"
    data:List(instance)
    equal(data:Details(1100).name, "Обновлённое задание", "details read the current source metadata")
end

-- Source-only accepted IDs need neither a log row nor a Questie zone, even when disallowed.
do
    local data, state, instance, drain = fixture({unknownArea = true, collapsed = true, emptyProvider = true})
    state.catalogue = {
        [1500] = {id = 1500, name = "Source-only accepted", level = 32, allowed = false,
            sources = {ForeverGuide = true}, pickup = "Guide pickup"},
        [1501] = {id = 1501, name = "Source-only available", level = 33, allowed = true,
            sources = {ForeverDungeonJournal = true}, objectives = {{text = "Known source goal", finished = false}}},
        [1502] = {id = 1502, name = "Source-only restricted", level = 34, allowed = false},
    }
    state.active[1500] = true
    data:Start(); drain()
    local model = data:List(instance)
    equal(model.known, true, "source catalogue establishes a known dungeon without a Questie area")
    local active = find(model.active, 1500)
    assert(active, "native acceptance overrides source restrictions and missing Questie metadata")
    equal(active.name, "Source-only accepted"); equal(active.pickup, "Guide pickup")
    equal(active.objectives[1].text, "Defeat target: 0/1", "active objectives keep live native progress")
    assert(not find(model.additional, 1500), "accepted source-only quest never appears twice")
    assert(not find(model.additional, 1502), "source restriction excludes unaccepted source-only quest")
    equal(find(model.additional, 1501).objectives[1].text, "Known source goal")
    equal(data:Details(1501).name, "Source-only available")
    state.active[1500] = nil
    assert(not find(data:List(instance).additional, 1500), "abandon restores source restriction")
    state.catalogue = {}
    equal(data:List(instance).known, false, "unknown area with empty catalogue remains unknown")
    equal(data:Details(1501), nil, "details use the current catalogue, not a previous dungeon")
end

-- Accept, abandon and complete transitions are live and cannot leave duplicate or completed extras.
do
    local data, state, instance, drain = fixture()
    data:Start(); drain()
    assert(find(data:List(instance).additional, 1100), "available quest starts as additional")
    state.active[1100] = true
    local accepted = data:List(instance)
    assert(find(accepted.active, 1100) and not find(accepted.additional, 1100), "accept moves quest once")
    state.active[1100] = nil
    assert(find(data:List(instance).additional, 1100), "abandoned quest returns to additional")
    state.completed[1100] = true
    local completed = data:List(instance)
    assert(not find(completed.active, 1100) and not find(completed.additional, 1100), "completed nonrepeatable disappears")
    equal(data:Details(1100), nil, "completed additional cannot be resurrected by stale details selection")
end

-- Only explicit native or source repeatability exempts a completed additional quest.
do
    local data, state, instance, drain = fixture()
    state.completed[1100] = true
    state.completed[1103] = true
    state.completed[1104] = true
    state.catalogue[1100].repeatable = true
    state.repeatable[1103] = true
    IsRepeatableQuest = function(id) return id == 1104 and 1 or nil end
    data:Start(); drain()
    local model = data:List(instance)
    for _, id in ipairs({1100, 1103, 1104}) do
        local row = find(model.additional, id)
        assert(row, "explicitly repeatable completed quest is retained")
        equal(row.repeatable, true); equal(row.done, false, "retained repeatable is not labelled completed")
        assert(row.status ~= "completed", "retained repeatable keeps its available/prerequisite status")
        equal(data:Details(id).done, false)
    end
    assert(not find(model.additional, 1200), "ordinary completed quest is still excluded")
    IsRepeatableQuest = nil
end

print("PASS: quest data regression scenarios")
