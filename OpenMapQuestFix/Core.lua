local ADDON, NS = ...
_G.OpenMapQuestFix = NS
local RU = GetLocale() == "ruRU"
function NS.Print(text) DEFAULT_CHAT_FRAME:AddMessage("|cffe6b85cOpenMap Quest Fix|r: " .. tostring(text)) end

local events = CreateFrame("Frame")
local queued, data, host, instanceID, selectedID, expanded
local function refresh()
    queued = false
    if not host then return end
    local inst = host:Current()
    if not inst then return end
    if instanceID ~= inst[1] then
        instanceID, selectedID, expanded = inst[1], nil, false
    end
    local model = data:List(inst)
    model.instanceID, model.expanded = instanceID, expanded
    if selectedID then
        local present = false
        for _, list in ipairs({model.active, model.additional}) do
            for _, quest in ipairs(list) do if quest.id == selectedID then present = true; break end end
        end
        if present then model.selected = data:Details(selectedID) else selectedID = nil end
    end
    host:Render(model)
end
local function invalidate()
    if queued then return end
    queued = true
    C_Timer.After(0, refresh)
end
NS.Refresh = invalidate

local function start()
    if not (OpenMap and OpenMap.GetModule and QuestieLoader and WorldMapFrame) then
        NS.Print(RU and "Не загружены OpenMap или Questie." or "OpenMap or Questie is not loaded.")
        return
    end
    local db = QuestieLoader:ImportModule("QuestieDB")
    local zones = QuestieLoader:ImportModule("ZoneDB")
    local mod = OpenMap:GetModule("worldmap")
    data = NS.Data.New(db, zones, invalidate, NS.Sources.New())
    NS.data = data
    host = NS.Host.New(WorldMapFrame, mod, invalidate, {
        open = function(id) selectedID = id; invalidate() end,
        back = function() selectedID = nil; invalidate() end,
        toggle = function(id) data:ToggleWatch(id); invalidate() end,
        collapse = function() expanded = not expanded; invalidate() end,
    })
    NS.host = host
    host:Install()
    data:Start()
    -- Event availability differs across Forever client builds. Unsupported
    -- optional events are ignored; QUEST_LOG_UPDATE is always authoritative.
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED",
        "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "CRITERIA_UPDATE",
        "QUEST_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "PLAYER_LEVEL_UP" }) do
        pcall(events.RegisterEvent, events, event)
    end
    invalidate()
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then start()
    elseif event == "ADDON_LOADED" then
        if name == "AzerothCompendium" or name == "ForeverDungeonJournal" or name == "ForeverGuide" or name == "CatQuest" then
            NS.ResetQuestProviders()
            invalidate()
        end
    else invalidate() end
end)
SLASH_OPENMAPQUESTFIX1 = "/omqf"
SlashCmdList.OPENMAPQUESTFIX = function()
    invalidate()
    local inst = host and host:Current()
    if inst then
        local model = data:List(inst)
        NS.Print(("instance=%d active=%d additional=%d indexing=%s"):format(inst[1], #model.active,
            #model.additional, tostring(model.loading)))
    else
        NS.Print(RU and "Открой вкладку «Задания» на карте подземелья." or "Open the Quests tab on a dungeon map.")
    end
end
