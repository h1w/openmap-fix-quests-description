-- These cases catch using the journal selection instead of the displayed ID,
-- leaking selection changes, borrowing another quest's text, and queue mistakes.
local function frame(parent)
    local f = {parent = parent, shown = true, enabled = true, scripts = {}, events = {}}
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(value) self.shown = not not value end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:SetPoint(...) end
    function f:ClearAllPoints() end
    function f:SetAllPoints(parentFrame) self.fill = parentFrame end
    function f:SetFrameStrata(value) self.strata = value end
    function f:SetText(value) self.text = value end
    function f:SetEnabled(value) self.enabled = not not value end
    function f:Click() if self.enabled then self.scripts.OnClick(self) end end
    function f:GetFrameStrata() return self.strata or 'MEDIUM' end
    return f
end
CreateFrame = function(_, _, parent) return frame(parent) end
hooksecurefunc = function(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        original(...)
        callback(...)
    end
end
local selected, selectionWrites = 900, 0
C_QuestLog = {
    GetSelectedQuest = function() return selected end,
    SetSelectedQuest = function(id) selected = id; selectionWrites = selectionWrites + 1 end,
}
GetQuestLogQuestText = function() error('source-only reading must not borrow journal text') end
local errors = {}
NS.Print = function(message) errors[#errors + 1] = message end
local factoryCalls, readCalls, spoken, enqueued, clearCalls = 0, {}, {}, {}, 0
local core = {state = {}, queue = {}, LOG_LABELS = {
    read = 'Read', stop = 'Stop', enqueue = 'Enqueue', queued = 'Queued',
}}
local frameButtons = {}
function core.UpdateUI()
    for _, button in ipairs(frameButtons) do
        button:SetText(core.state.playing and 'Stop' or 'Read')
    end
end
function core.CreateFrameButton(parent, onClick)
    factoryCalls = factoryCalls + 1
    local button = frame(parent)
    button:SetScript('OnClick', onClick)
    frameButtons[#frameButtons + 1] = button
    return button
end
function core.ReadQuest(id, enqueue)
    readCalls[#readCalls + 1] = {id = id, enqueue = enqueue}
    C_QuestLog.SetSelectedQuest(id)
    if core.fail then error('reader fixture failure') end
end
function core.FillSpeaker(meta) meta.npcID = 77; return meta end
function core.Speak(text, meta) spoken[#spoken + 1] = {text = text, meta = meta} end
function core.Enqueue(text, meta) enqueued[#enqueued + 1] = {text = text, meta = meta} end
function core.ClearQueue() clearCalls = clearCalls + 1; core.state = {}; core.queue = {} end
CatQuestDB = {readTitle = true, readObjectives = true, queue = true, quests = {}}
CatQuestCore = nil
local parent = frame()
assert(NS.Reader, 'Reader module must be loaded')
local reader = NS.Reader.New(parent)
reader:SetQuest({id = 101, name = 'Wanted', inLog = true})
assert(not reader:IsShown() and not reader.button, 'missing optional CatQuest hides the reader')
CatQuestCore = {CreateFrameButton = core.CreateFrameButton}
reader:Refresh()
assert(not reader:IsShown(), 'incompatible CatQuest must stay hidden')
CatQuestCore = core
assert(reader.events.ADDON_LOADED, 'late CatQuest load must be observed even while reader is hidden')
reader.scripts.OnEvent(reader, 'ADDON_LOADED', 'CatQuest')
assert(reader:IsVisible() and reader.button and factoryCalls == 1, 'late load creates the CatQuest factory child once')
assert(reader.button.parent == reader and reader.button.fill == reader, 'factory gets a real owned container')
assert(reader.button.text == 'Read' and reader.button.enabled, 'idle displayed quest is readable')
assert(selectionWrites == 0, 'rendering and refreshing never change native selection')
reader.button:Click()
assert(readCalls[1].id == 101 and readCalls[1].enqueue == false, 'read must target displayed ID rather than selected 900')
assert(selected == 900, 'successful ReadQuest restores native selection')
core.fail = true
reader.button:Click()
assert(selected == 900, 'failed ReadQuest also restores native selection')
assert(#errors == 1 and errors[1]:find('reader fixture failure', 1, true), 'read errors must be visible')
core.fail = nil
selected = 0
reader.button:Click()
assert(selected == 0, 'no selected quest is restored too, without retaining the read quest')
selected = 900

-- Saved detail is safe for additional quests; no saved detail must use only the model.
CatQuestDB.quests[202] = {detail = {text = 'Saved NPC words'}}
reader:SetQuest({id = 202, name = 'Saved', inLog = false})
reader.button:Click()
assert(readCalls[#readCalls].id == 202 and selected == 900, 'saved additional detail uses CatQuest ReadQuest safely')
reader:SetQuest({id = 303, name = 'Known title', inLog = false,
    description = 'Known description', summary = 'Known goal', objectives = {{text = 'Progress must not duplicate goal'}}})
local readCount = #readCalls
reader.button:Click()
assert(#readCalls == readCount, 'unsaved additional quests never call journal-based ReadQuest')
assert(#spoken == 1 and spoken[1].text:find('Known title', 1, true)
    and spoken[1].text:find('Known description', 1, true) and spoken[1].text:find('Known goal', 1, true),
    'source-only speech contains known title, description and goal')
assert(not spoken[1].text:find('Progress must not duplicate goal', 1, true), 'goal replaces redundant progress text')
assert(spoken[1].meta.kind == 'log' and spoken[1].meta.quest == 303 and spoken[1].meta.title == 'Known title'
    and spoken[1].meta.desc == 'Known description' and spoken[1].meta.byHand and spoken[1].meta.npcID == 77,
    'public Speak receives quest identity, explicit-click flag and FillSpeaker metadata for packs')
assert(selected == 900, 'source-only read does not navigate the journal')
CatQuestDB.readTitle, CatQuestDB.readObjectives = false, false
reader.button:Click()
assert(spoken[#spoken].text == 'Known description', 'source fallback respects title and objectives settings')
assert(CatQuestDB.readTitle == false and CatQuestDB.readObjectives == false, 'reader never changes settings')
reader:SetQuest({id = 304, name = 'Hidden title', objectives = {{text = 'Hidden objective'}}})
reader.button:Click()
assert(#spoken == 2 and #errors == 2, 'empty enabled text is visibly explained, never fabricated')
CatQuestDB.readTitle, CatQuestDB.readObjectives = true, true
reader:SetQuest({id = 305, name = 'Objectives only', objectives = {{text = 'Known target'}}})
reader.button:Click()
assert(spoken[#spoken].text:find('Known target', 1, true), 'known objective rows are read when summary is absent')

-- Pending and paused metadata belong to their own quest, not the native selection.
reader:SetQuest({id = 101, name = 'Wanted', inLog = true})
core.state = {playing = true, meta = {quest = 900}}
core.UpdateUI()
assert(reader.button.text == 'Enqueue' and reader.button.enabled,
    'shared CatQuest updates immediately preserve displayed identity during foreign playback')
assert(reader.button.text == 'Enqueue', 'other quest playing offers enqueue')
reader.button:Click()
assert(readCalls[#readCalls].id == 101 and readCalls[#readCalls].enqueue == true, 'busy accepted quest queues correct ID')
assert(selected == 900, 'queued ReadQuest restores native selection')
core.queue = {{text = 'Queued wanted quest', meta = {quest = 101}}}
core.UpdateUI()
assert(reader.button.text == 'Queued' and not reader.button.enabled,
    'shared CatQuest updates immediately preserve queued label and disabled state')
local before = #readCalls
reader.button:Click()
assert(reader.button.text == 'Queued' and not reader.button.enabled and #readCalls == before,
    'already queued displayed quest is disabled and never duplicated')
core.queue = {}
core.state = {pending = {text = 'Pending wanted', meta = {quest = 101}}, meta = {quest = 900}}
reader:Refresh()
assert(reader.button.text == 'Stop', 'pending displayed quest takes precedence over stale playing metadata')
reader.button:Click()
assert(clearCalls == 1 and reader.button.text == 'Read', 'stop clears playback and queue like native journal')
core.state = {paused = {text = 'Paused wanted', meta = {quest = 101}}, meta = {quest = 900}}
reader:Refresh()
assert(reader.button.text == 'Stop', 'paused displayed quest can be stopped')
reader.button:Click()
assert(clearCalls == 2, 'paused stop also calls ClearQueue')
core.state = {paused = {text = 'Paused other', meta = {quest = 900}}}
reader:SetQuest({id = 303, name = 'Source queued', description = 'Only known source words'})
reader.button:Click()
assert(#enqueued == 1 and enqueued[1].meta.quest == 303 and enqueued[1].meta.byHand,
    'source-only explicit click enters public CatQuest queue with correct metadata')
assert(enqueued[1].text:find('Only known source words', 1, true), 'source queue uses known model text')
CatQuestDB.queue = false
reader:Refresh()
assert(reader.button.text == 'Read', 'queue-disabled playback offers immediate reading')
reader.button:Click()
assert(#enqueued == 1 and spoken[#spoken].meta.quest == 303, 'queue disabled source click uses Speak')
CatQuestDB.queue = true

-- Poll only while visible, four times a second, and do not rebuild a factory button.
core.state = {}
reader:SetQuest({id = 101, name = 'Wanted', inLog = true})
core.state = {playing = true, meta = {quest = 101}}
reader.scripts.OnUpdate(reader, 0.24)
assert(reader.button.text == 'Read', 'poll waits for quarter-second threshold')
reader.scripts.OnUpdate(reader, 0.01)
assert(reader.button.text == 'Stop', 'visible poll refreshes playback state')
parent:Hide()
core.state = {}
reader.scripts.OnUpdate(reader, 1)
assert(reader.button.text == 'Stop', 'hidden ancestor prevents polling work')
core.UpdateUI()
assert(not reader:IsVisible() and not reader.button:IsVisible(), 'shared updates never reveal a hidden ancestor')
parent:Show()
reader.scripts.OnShow(reader)
assert(reader.button.text == 'Read', 'show refreshes stale playback state immediately')
assert(factoryCalls == 1, 'refreshes reuse the CatQuest-created button')
reader:SetQuest(nil)
assert(not reader:IsShown() and not reader.button:IsShown(), 'cleared quest hides reader and child')
print('PASS: CatQuest reader identity, selection restoration, known text, queue and optional loading')
