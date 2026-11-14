local _, NS = ...
local Reader = {}
NS.Reader = Reader

local RU = GetLocale() == "ruRU"
local labels = RU and {read = "Читать", stop = "Стоп", enqueue = "В очередь", queued = "В очереди"}
    or {read = "Read", stop = "Stop", enqueue = "Enqueue", queued = "Queued"}
local requiredMethods = {"CreateFrameButton", "ReadQuest", "Speak", "Enqueue", "FillSpeaker", "ClearQueue"}

local function compatibleCore()
    local core = _G.CatQuestCore
    if type(core) ~= "table" or type(_G.CatQuestDB) ~= "table" or type(core.state) ~= "table" then return end
    for _, name in ipairs(requiredMethods) do
        if type(core[name]) ~= "function" then return end
    end
    return core
end

local function report(message)
    local text = "CatQuest: " .. tostring(message)
    if NS.Print then NS.Print(text)
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text)
    else error(text, 0) end
end

local function action(core, questID)
    local state = core.state
    local current = state.pending and state.pending.meta or state.paused and state.paused.meta
        or state.playing and state.meta
    if current and current.quest == questID then return "stop" end
    for _, item in ipairs(core.queue or {}) do
        if item.meta and item.meta.quest == questID then return "queued" end
    end
    if (state.playing or state.pending or state.paused) and CatQuestDB.queue then return "enqueue" end
    return "read"
end

local function nonempty(text)
    return type(text) == "string" and text:find("%S") and text
end

local function knownText(record)
    local parts = {}
    local title, desc = nonempty(record.name), nonempty(record.description)
    if CatQuestDB.readTitle and title then parts[#parts + 1] = title .. "." end
    if desc then parts[#parts + 1] = desc end
    if CatQuestDB.readObjectives then
        local goal = nonempty(record.summary) or nonempty(record.goal)
        if goal then
            parts[#parts + 1] = goal
        else
            for _, objective in ipairs(record.objectives or {}) do
                local text = nonempty(objective.text)
                if text then parts[#parts + 1] = text end
            end
        end
    end
    return table.concat(parts, "\n\n"), title, desc
end

-- ReadQuest may synchronously select its ID before looking up journal text.
-- Restore the original selection even if reading or speaker lookup throws.
local function readQuest(core, questID, enqueue)
    local get, set
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        get, set = C_QuestLog.GetSelectedQuest, C_QuestLog.SetSelectedQuest
    elseif GetQuestLogSelection and SelectQuestLogEntry then
        get, set = GetQuestLogSelection, SelectQuestLogEntry
    end
    if set and not get then error(RU and "Нельзя сохранить выбор журнала заданий." or "Cannot preserve the quest journal selection.", 0) end
    local selection = get and get()
    if set and selection == nil then
        error(RU and "Не удалось получить выбор журнала заданий." or "Cannot read the quest journal selection.", 0)
    end
    local ok, problem = pcall(core.ReadQuest, questID, enqueue)
    local restored, restoreProblem = true
    if set then restored, restoreProblem = pcall(set, selection) end
    if not ok then
        if not restored then problem = tostring(problem) .. "; " .. tostring(restoreProblem) end
        error(problem, 0)
    end
    if not restored then error(restoreProblem, 0) end
end

local function readRecord(core, record, enqueue)
    local saved = CatQuestDB.quests and CatQuestDB.quests[record.id]
    if record.inLog or saved and saved.detail then
        readQuest(core, record.id, enqueue)
        return
    end
    -- Additional quests have no journal entry: only speak known catalogue text.
    -- CatQuest resolves packs by this quest ID before its normal TTS fallback.
    local text, title, desc = knownText(record)
    if text == "" then error(RU and "Нет известного текста для чтения." or "No known quest text is enabled for reading.", 0) end
    local meta = core.FillSpeaker({kind = "log", quest = record.id, title = title, desc = desc, byHand = true})
    if enqueue then core.Enqueue(text, meta) else core.Speak(text, meta) end
end

function Reader.New(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(100, 22)
    container:Hide()
    container.tick = 0
    local updating = false
    local function updateButton()
        if updating then return end
        local core, record = compatibleCore(), container.record
        if not core or not record or not record.id then return end
        local what = action(core, record.id)
        updating = true
        container.button:SetText(core.LOG_LABELS and core.LOG_LABELS[what] or labels[what])
        container.button:SetEnabled(what ~= "queued")
        updating = false
    end

    local function click()
        local core, record = compatibleCore(), container.record
        if not core or not record then container:Refresh(); return end
        local what = action(core, record.id)
        if what == "queued" then container:Refresh(); return end
        local ok, problem = pcall(function()
            if what == "stop" then core.ClearQueue()
            else readRecord(core, record, what == "enqueue") end
        end)
        if not ok then report(problem) end
        container:Refresh()
    end

    function container:Refresh()
        local core = compatibleCore()
        local record = self.record
        if not core or not record or not record.id then
            if self.button then self.button:Hide() end
            self:Hide()
            return
        end
        if not self.button then
            local ok, button = pcall(core.CreateFrameButton, self, click)
            if not ok or not button then
                self:Hide()
                report(ok and (RU and "Не удалось создать кнопку чтения." or "Could not create the reading button.") or button)
                return
            end
            self.button = button
            button:ClearAllPoints()
            button:SetAllPoints(self)
            -- The public factory defaults to DIALOG; this embedded reader must
            -- inherit its journal toolbar's strata instead of floating over it.
            button:SetFrameStrata(self:GetFrameStrata())
            -- CatQuest also updates every factory child's label globally. Keep
            -- this child's identity-specific state without touching its core or
            -- opting into isLog, which follows the native journal selection.
            hooksecurefunc(button, "SetText", function()
                if container:IsVisible() then updateButton() end
            end)
        end
        updateButton()
        self.button:Show()
        self:Show()
    end

    function container:SetQuest(record)
        self.record = record
        self.tick = 0
        self:Refresh()
    end

    container:RegisterEvent("ADDON_LOADED")
    container:SetScript("OnEvent", function(self) self:Refresh() end)
    container:SetScript("OnShow", function(self) self.tick = 0; self:Refresh() end)
    container:SetScript("OnHide", function(self) self.tick = 0 end)
    container:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsVisible() then return end
        self.tick = self.tick + elapsed
        if self.tick < 0.25 then return end
        self.tick = 0
        self:Refresh()
    end)
    return container
end
