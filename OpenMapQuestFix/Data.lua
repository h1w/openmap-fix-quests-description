local _, NS = ...

local Data = {}
NS.Data = Data

local CHUNK_SIZE = 100
local metadataFields = {"name", "questLevel", "requiredRaces", "requiredClasses", "objectivesText", "preQuestSingle", "preQuestGroup", "parentQuest"}

local function import(name)
    if not QuestieLoader or not QuestieLoader.ImportModule then return nil end
    local ok, module = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    if ok then return module end
end

local function truth(value)
    return value == true or value == 1
end

local function nonempty(value)
    return type(value) == "table" and next(value) ~= nil
end

local function sortQuests(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

function Data.New(db, zones, changed, sources)
    local self = setmetatable({
        db = db, zones = zones, changed = changed,
        sources = sources or (NS.Sources and NS.Sources.New()), catalogue = {},
        player = import("QuestiePlayer"), logCache = import("QuestLogCache"),
        aliases = {}, byZone = {}, zoneByQuest = {}, metadata = {},
        loading = true, started = false,
    }, {__index = Data})
    return self
end

function Data:Normalize(area)
    if type(area) ~= "number" or area <= 0 then return nil end
    local seen = {}
    while not seen[area] do
        seen[area] = true
        local parent = self.aliases[area]
        if not parent and self.zones.GetParentZoneId then parent = self.zones:GetParentZoneId(area) end
        if type(parent) ~= "number" or parent <= 0 or parent == area then break end
        area = parent
    end
    return area
end

function Data:Area(inst)
    local id = inst and (inst[1] or inst.instanceID)
    if type(id) ~= "number" then return nil end
    local mapped = self.zones.instanceIdToAreaId and self.zones.instanceIdToAreaId[id]
    if mapped then return self:Normalize(mapped) end
    -- GetRealZoneText(instanceID) is undecorated, unlike OpenMap's wing title.
    local name = GetRealZoneText and GetRealZoneText(id)
    if name and name ~= "" and self.zones.GetAreaIdByName then
        return self:Normalize(self.zones:GetAreaIdByName(name))
    end
end

function Data:Start()
    if self.started then return end
    self.started = true
    local function step()
        if not self.indexPointers then
            local dungeons = self.zones:GetDungeons()
            local pointers = self.db.QuestPointers
            if type(dungeons) ~= "table" or type(pointers) ~= "table" then
                C_Timer.After(0.2, step)
                return
            end
            self.dungeons = dungeons
            for area, entry in pairs(dungeons) do
                for _, alternative in ipairs(entry[2] or {}) do self.aliases[alternative] = area end
            end
            self.indexPointers = pointers
        end
        for _ = 1, CHUNK_SIZE do
            local id = next(self.indexPointers, self.cursor)
            self.cursor = id
            if not id then
                self.loading = false
                if self.changed then self.changed() end
                return
            end
            local area = self:QuestArea(id)
            if area then
                local quests = self.byZone[area]
                if not quests then quests = {}; self.byZone[area] = quests end
                quests[id] = true
            end
        end
        C_Timer.After(0, step)
    end
    step()
end

function Data:QuestArea(id)
    local cached = self.zoneByQuest[id]
    if cached ~= nil then return self:Normalize(cached) end
    if not self.db.QuestPointers or not self.db.QuestPointers[id] then return nil end
    local area = self.db.QueryQuestSingle(id, "zoneOrSort")
    -- Cache the raw area: provider initialization can publish aliases after an
    -- early native-log refresh, and those must normalize on subsequent reads.
    self.zoneByQuest[id] = area or false
    return self:Normalize(area)
end

function Data:Metadata(id)
    if self.metadata[id] then return self.metadata[id] end
    local record = {}
    -- Native log/header fallback is usable before Questie's pointer table exists.
    -- A temporary absence must not become a permanent missing-quest cache entry.
    if type(self.db.QuestPointers) ~= "table" then return record end
    if self.db.QuestPointers and self.db.QuestPointers[id] then
        for _, field in ipairs(metadataFields) do record[field] = self.db.QueryQuestSingle(id, field) end
    end
    self.metadata[id] = record
    return record
end

function Data:IsActive(id)
    if not C_QuestLog then return false end
    if C_QuestLog.IsOnQuest then return truth(C_QuestLog.IsOnQuest(id)) end
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    return type(index) == "number" and index > 0
end

function Data:LogIndex(id)
    local index = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    if type(index) == "number" and index > 0 then return index end
end

function Data:NativeHeader(id, index)
    index = index or self:LogIndex(id)
    if not index or not C_QuestLog.GetInfo then return nil end
    -- Reads only: a collapsed native header must remain collapsed.
    for row = index - 1, 1, -1 do
        local info = C_QuestLog.GetInfo(row)
        if info and info.isHeader then return info.title end
    end
end

function Data:ActiveCandidates(area, catalogue)
    local candidates = {}
    local function add(id, info, header)
        if type(id) == "number" and id > 0 and self:IsActive(id) then
            local entry = candidates[id] or {}
            entry.info = info or entry.info
            entry.header = header or entry.header
            candidates[id] = entry
        end
    end
    local header
    if C_QuestLog and C_QuestLog.GetInfo then
        local count = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
        for index = 1, count do
            local info = C_QuestLog.GetInfo(index)
            if info then
                if info.isHeader then header = info.title else add(info.questID, info, header) end
            end
        end
    end
    -- Provider tables enumerate hidden accepted IDs, but never decide membership.
    local function addProvider(entries)
        for key, entry in pairs(entries or {}) do
            local id = type(entry) == "table" and (entry.questID or entry.questId or entry.Id or entry.id)
            if not id and type(entry) == "number" and self:IsActive(entry) then id = entry end
            if not id then id = type(key) == "number" and key end
            add(id)
        end
    end
    addProvider(self.player and self.player.currentQuestlog)
    addProvider(self.logCache and self.logCache.questLog_DO_NOT_MODIFY)
    -- The bounded pointer scan creates this list without race/class filtering.
    -- IsOnQuest sees collapsed quests even when Questie's current log cache is empty.
    for id in pairs(self.byZone[area] or {}) do add(id) end
    -- Source membership also discovers accepted IDs missing from Questie's index.
    for id in pairs(catalogue or {}) do add(id) end
    return candidates
end

function Data:Allowed(metadata, source)
    if source and source.allowed ~= nil then return source.allowed ~= false end
    local player = self.player
    if player and player.HasRequiredRace and not player.HasRequiredRace(metadata.requiredRaces) then return false end
    if player and player.HasRequiredClass and not player.HasRequiredClass(metadata.requiredClasses) then return false end
    -- Core supplies initialized Questie modules; if a predicate is unavailable,
    -- retain the quest rather than guessing the provider's high-bit race masks.
    return true
end

function Data:IsRepeatable(id, source)
    if source and truth(source.repeatable) then return true end
    if C_QuestLog and C_QuestLog.IsRepeatableQuest and truth(C_QuestLog.IsRepeatableQuest(id)) then return true end
    return IsRepeatableQuest and truth(IsRepeatableQuest(id)) or false
end

function Data:IsCompleted(id)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and truth(C_QuestLog.IsQuestFlaggedCompleted(id)) or false
end

function Data:CanAdd(id, source)
    return source and self:Allowed(self:Metadata(id), source)
        and (not self:IsCompleted(id) or self:IsRepeatable(id, source))
end

function Data:Record(id, inLog, info)
    local metadata = self:Metadata(id)
    local source = self.catalogue[id]
    local index = inLog and self:LogIndex(id)
    if not info and index and C_QuestLog.GetInfo then
        local native = C_QuestLog.GetInfo(index)
        if native and not native.isHeader and native.questID == id then info = native end
    end
    local name = inLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    local complete = inLog and C_QuestLog.IsComplete and truth(C_QuestLog.IsComplete(id)) or false
    local failed = inLog and C_QuestLog.IsFailed and truth(C_QuestLog.IsFailed(id)) or false
    local repeatable = self:IsRepeatable(id, source)
    local done = self:IsCompleted(id) and not repeatable
    local watched = inLog and C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil or false
    local record = {}
    -- Preserve provider provenance, pickup and requirement metadata even without
    -- any matching Questie record; native active state below remains authoritative.
    for field, value in pairs(source or {}) do record[field] = value end
    if type(name) ~= "string" or name == "" then name = nil end
    local sourceName = source and source.name
    if type(sourceName) ~= "string" or sourceName == "" then sourceName = nil end
    record.id = id
    record.name = name or (info and info.title) or sourceName or metadata.name or tostring(id)
    record.level = (info and info.level) or (source and source.level) or metadata.questLevel or 0
    record.inLog, record.complete, record.failed = inLog, complete, failed
    record.done, record.watched, record.repeatable = done, watched, repeatable
    record.objectives, record.rewards = {}, {}
    if inLog then
        if failed then record.status = "failed"
        elseif complete then record.status = "complete"
        else record.status = "active" end
        -- Native text already includes localized, current counters. Never replace it
        -- with database target names or append a second set of progress numbers.
        local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
        for _, objective in ipairs(objectives or {}) do
            if type(objective.text) == "string" and objective.text ~= "" then
                record.objectives[#record.objectives + 1] = {
                    text = objective.text, finished = truth(objective.finished),
                    numFulfilled = objective.numFulfilled, numRequired = objective.numRequired,
                }
            end
        end
    else
        if source and source.status then record.status = source.status
        elseif nonempty(metadata.preQuestSingle) or nonempty(metadata.preQuestGroup)
            or (type(metadata.parentQuest) == "number" and metadata.parentQuest > 0) then
            record.status = "unknownPrerequisites"
        else record.status = "notAccepted" end
        for _, objective in ipairs(source and source.objectives or {}) do
            if type(objective.text) == "string" and objective.text ~= "" then
                record.objectives[#record.objectives + 1] = {text = objective.text, finished = false}
            end
        end
        if #record.objectives == 0 then
            for _, text in ipairs(metadata.objectivesText or {}) do
                if type(text) == "string" and text ~= "" then
                    record.objectives[#record.objectives + 1] = {text = text, finished = false}
                end
            end
        end
    end
    return record
end

function Data:List(inst)
    local area = self:Area(inst)
    local catalogue = self.sources and self.sources:List(inst) or {}
    self.catalogue = catalogue
    local model = {active = {}, additional = {}, loading = self.loading, known = area ~= nil or nonempty(catalogue)}
    local instanceID = inst and (inst[1] or inst.instanceID)
    local nativeName = instanceID and GetRealZoneText and GetRealZoneText(instanceID)
    local accepted = {}
    for id, candidate in pairs(self:ActiveCandidates(area, catalogue)) do
        local questArea = self:QuestArea(id)
        local belongs = catalogue[id] ~= nil or (area ~= nil and questArea == area)
        if not belongs and not questArea and nativeName and nativeName ~= "" then
            local header = candidate.header or self:NativeHeader(id)
            belongs = header == nativeName
        end
        if belongs then
            accepted[id] = true
            model.active[#model.active + 1] = self:Record(id, true, candidate.info)
        end
    end
    for id, source in pairs(catalogue) do
        if not accepted[id] and not self:IsActive(id) and self:CanAdd(id, source) then
            model.additional[#model.additional + 1] = self:Record(id, false)
        end
    end
    table.sort(model.active, sortQuests)
    table.sort(model.additional, sortQuests)
    return model
end

function Data:Details(id)
    local active = self:IsActive(id)
    if not active and not self:CanAdd(id, self.catalogue[id]) then return nil end
    local record = self:Record(id, active)
    if not active then return record end
    local index = self:LogIndex(id)
    -- Quest text takes a log index; explicit-ID reward queries can expose a
    -- different (filtered/cached) list from the accepted log entry on Forever.
    if index and GetQuestLogQuestText then record.description, record.summary = GetQuestLogQuestText(index) end
    local function items(countAPI, infoAPI)
        if not countAPI or not infoAPI then return end
        local count = countAPI(id) or 0
        for rewardIndex = 1, count do
            local name, texture, quantity, _, _, itemID = infoAPI(rewardIndex, id)
            local kind = "reward"
            local link = GetQuestLogItemLink and GetQuestLogItemLink(kind, rewardIndex, id)
            record.rewards[#record.rewards + 1] = {
                name = name, texture = texture, count = quantity or 1, link = link,
                choice = false, index = rewardIndex, itemID = itemID,
            }
        end
    end
    items(GetNumQuestLogRewards, GetQuestLogRewardInfo)
    if GetQuestLogChoiceInfo then
        local get = C_QuestLog.GetSelectedQuest
        local set = C_QuestLog.SetSelectedQuest
        assert(get and set, "OpenMapQuestFix: cannot preserve native quest selection")
        local previous = get()
        assert(previous ~= nil, "OpenMapQuestFix: unknown native quest selection")
        local ok, problem = pcall(function()
            if previous ~= id then set(id) end
            -- Classic/Forever has six physical choice slots. The ID-based
            -- count may say two while the live entry contains four; enumerate
            -- live slots by item ID, including items whose names are uncached.
            for slot = 1, 6 do
                local name, texture, quantity, _, _, itemID = GetQuestLogChoiceInfo(slot)
                assert(get() == id, "OpenMapQuestFix: reward quest selection changed")
                if not itemID or itemID <= 0 then break end
                local link = GetQuestLogItemLink and GetQuestLogItemLink("choice", slot)
                assert(get() == id, "OpenMapQuestFix: reward link selection changed")
                if GetItemInfo and (not name or not texture) then
                    local cachedName, cachedLink, _, _, _, _, _, _, _, cachedTexture = GetItemInfo(itemID)
                    name, texture, link = name or cachedName, texture or cachedTexture, link or cachedLink
                end
                link = link or ("item:" .. itemID)
                record.rewards[#record.rewards + 1] = {
                    name = name, texture = texture, count = quantity or 1,
                    itemID = itemID, link = link, choice = true, index = slot,
                }
            end
        end)
        local restored, restoreProblem = true
        if get() ~= previous then restored, restoreProblem = pcall(set, previous) end
        if not restored then error(restoreProblem, 0) end
        if not ok then error(problem, 0) end
    end
    if GetQuestLogRewardMoney then record.money = GetQuestLogRewardMoney(id) end
    if GetQuestLogRewardXP then record.xp = GetQuestLogRewardXP(id) end
    return record
end

function Data:ToggleWatch(id)
    if not self:IsActive(id) or not C_QuestLog.GetQuestWatchType then return false end
    local result
    if C_QuestLog.GetQuestWatchType(id) ~= nil then
        if not C_QuestLog.RemoveQuestWatch then return false end
        result = C_QuestLog.RemoveQuestWatch(id)
    else
        if not C_QuestLog.AddQuestWatch then return false end
        local manual = Enum and Enum.QuestWatchType and Enum.QuestWatchType.Manual or 0
        result = C_QuestLog.AddQuestWatch(id, manual)
    end
    if self.changed then self.changed() end
    return result
end
