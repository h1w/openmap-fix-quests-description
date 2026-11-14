local _, NS = ...
local Navigation = {}
NS.Navigation = Navigation
local order = {"ForeverDungeonJournal", "ForeverGuide", "AzerothCompendium"}
local labels = {ForeverDungeonJournal="DungeonJournal", ForeverGuide="ForeverGuide", AzerothCompendium="AzerothCompendium"}
local serial = 0
local settingGuideQuery = false
function Navigation.Cancel()
    serial = serial + 1
end
local function report(key, reason)
    if NS.Print then NS.Print(labels[key] .. ": " .. NS.T("navigationUnavailable") .. (reason and (" (" .. tostring(reason) .. ")") or "")) end
end
local function walk(root, visit, depth)
    if not root or (depth or 0) > 12 then return end
    if visit(root) then return root end
    if root.GetChildren then
        for _, child in ipairs({root:GetChildren()}) do
            local result = walk(child, visit, (depth or 0) + 1)
            if result then return result end
        end
    end
end
local function member(list, id)
    for _, q in ipairs(list or {}) do if q.id == id then return q end end
end
local function instance(provider, id)
    if provider.GetInstanceByID then return provider:GetInstanceByID(id) end
    for _, d in ipairs(provider.INSTANCES or {}) do if d.id == id then return d end end
end
local function compAllowed(provider, dungeon, id)
    if not provider.GetInstanceQuestGraph then return false end
    local db = ACOTABPC or {}
    local level = UnitLevel and UnitLevel("player") or 0
    if db.ONLYRELEVANT and dungeon.type ~= "raid" and (not dungeon.minLevel or not dungeon.maxLevel or level < dungeon.minLevel or level > dungeon.maxLevel) then return false end
    if db.ONLYMAXLEVEL and provider.IsMaxLevelInstance and not provider:IsMaxLevelInstance(dungeon) then return false end
    if db.HIDENEWFOREVER and dungeon.forever then return false end
    local continent = provider.GetSelectedContinent and provider:GetSelectedContinent()
    if continent and provider.GetInstanceContinent and provider:GetInstanceContinent(dungeon) ~= continent then return false end
    if provider.GetFlavor and provider:GetFlavor() ~= "forever" and provider.IsInstanceInFlavor and not provider:IsInstanceInFlavor(dungeon) then return false end
    local graph = provider:GetInstanceQuestGraph(dungeon, nil, db.QUESTHIDECOMPLETED == true)
    local node = member(graph, id)
    if not node or provider.IsQuestNodeMasked and provider:IsQuestNodeMasked(node) then return false end
    if db.HIDECOMPLETED and provider.GetInstanceQuests and provider.IsQuestCompleted then
        local all, count = true, 0
        for _, q in ipairs(provider:GetInstanceQuests(dungeon)) do count=count+1; if not provider:IsQuestCompleted(q[1]) then all=false end end
        if count>0 and all then return false end
    end
    return true
end
local function resolve(key, record)
    if not record or not record.sources or not record.sources[key] then return end
    local page = record.links and record.links[key]
    if not page then return end
    local provider = NS.GetQuestProvider(key)
    if type(provider) ~= "table" then return end
    if key == "ForeverDungeonJournal" then
        local dungeon = provider.DB and provider.DB[page]
        local quest = dungeon and member(dungeon.quests, record.id)
        if not quest or type(provider.OpenQuestPage) ~= "function" or not ForeverDungeonJournalFrame then return end
        if provider.IsDungeonLocked and provider.IsDungeonLocked(page) then return end
        if provider.RPGQuestHidden and provider.RPGQuestHidden(page, quest) then return end
    elseif key == "ForeverGuide" then
        if not provider.DQ or not provider.DQ[record.id] then return end
        local found
        for _, dungeon in ipairs(provider.DUNGEONS or {}) do
            if dungeon.key == page then for _, id in ipairs(dungeon.q or {}) do if id == record.id then found=true end end end
        end
        if not found then return end
        if type(provider.ShowQuestCard) ~= "function" and not (SlashCmdList and type(SlashCmdList.FOREVERGUIDE_MAIN) == "function" and C_Timer and C_Timer.After) then return end
    else
        local dungeon = instance(provider, page)
        if not dungeon or type(provider.OpenCompendium) ~= "function" or not compAllowed(provider, dungeon, record.id) then return end
    end
    return provider, page
end
local function openGuide(provider, page, record, token)
    if type(provider.ShowQuestCard) == "function" then provider.ShowQuestCard(record.id); return end
    SlashCmdList.FOREVERGUIDE_MAIN(page)
    local box, frame = ForeverGuideGlobalSearch, ForeverGuideFrame
    local changed = box and box:GetScript("OnTextChanged")
    local query = provider.DQ[record.id].n
    if not (box and frame and changed and type(query)=="string" and query~="") then error(NS.T("navigationUnavailable"), 0) end
    if frame.HookScript and not frame.omqNavigationHooked then
        frame:HookScript("OnHide", Navigation.Cancel)
        frame.omqNavigationHooked = true
    end
    if box.HookScript and not box.omqNavigationHooked then
        box:HookScript("OnTextChanged", function(_, user)
            if user and not settingGuideQuery then Navigation.Cancel() end
        end)
        box.omqNavigationHooked = true
    end
    box:SetText("")
    box:SetText(query)
    settingGuideQuery = true
    local changedOK, changedError = pcall(changed, box, true)
    settingGuideQuery = false
    if not changedOK then error(changedError, 0) end
    local attempts = 0
    local function finish()
        if serial ~= token then return end
        if not frame:IsShown() or box:GetText() ~= query then Navigation.Cancel(); return end
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        if loaded and not loaded("ForeverGuide") then Navigation.Cancel(); return end
        local row = walk(frame, function(f)
            local e=f.entry
            return f.IsVisible and f:IsVisible() and type(e)=="table" and e.kind=="quests" and e.v and e.v.id==record.id and f.GetScript and f:GetScript("OnClick")
        end)
        if row then
            row:GetScript("OnClick")(row, "LeftButton")
            return
        end
        attempts=attempts+1
        if attempts>=50 then box:SetText(""); report("ForeverGuide"); return end
        C_Timer.After(0.1, function()
            local ok, problem = pcall(finish)
            if not ok then report("ForeverGuide", problem) end
        end)
    end
    finish()
end
function Navigation.List(record)
    local result = {}
    for _, key in ipairs(order) do
        local ok, provider = pcall(resolve, key, record)
        if ok and provider then result[#result+1]={key=key,label=labels[key]} end
    end
    return result
end
function Navigation.Open(key, record)
    if not labels[key] then return false end
    serial=serial+1
    local token=serial
    local ok, problem=pcall(function()
        local provider, page=resolve(key, record)
        if not provider then error(NS.T("navigationUnavailable"),0) end
        if key=="ForeverDungeonJournal" then
            if provider.IsWorldMapOverlayAttached and provider.IsWorldMapOverlayAttached() and provider.OpenQuestFromWorldMap then
                provider.OpenQuestFromWorldMap(page,record.id)
            else
                if not ForeverDungeonJournalFrame:IsShown() then ForeverDungeonJournalFrame:Show() end
                provider.OpenQuestPage(page,record.id)
            end
        elseif key=="ForeverGuide" then openGuide(provider,page,record,token)
        else
            provider:OpenCompendium()
            local tree=AzerothCompendiumFrame and AzerothCompendiumFrame.questTree
            if not (tree and tree.OpenInstance and tree.FocusQuest) then error(NS.T("navigationUnavailable"),0) end
            tree.OpenInstance(page)
            if not tree:FocusQuest(record.id) then error(NS.T("navigationUnavailable"),0) end
            if provider.BringCompendiumToFront then provider:BringCompendiumToFront() end
        end
    end)
    if not ok then report(key,problem) end
    return ok
end
