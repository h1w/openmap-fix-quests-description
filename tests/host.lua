-- A refresh must replace only dungeon quests, restore the native list on tab
-- changes, and keep a hidden journal/map hidden.
local function frame(parent)
    local f = { parent = parent, shown = true, scripts = {}, level = 10 }
    f.children, f.regions = {}, {}
    if parent then parent.children[#parent.children+1] = f end
    function f:GetParent() return self.parent end
    function f:GetChildren() return unpack(self.children) end
    function f:GetRegions() return unpack(self.regions) end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = not not v end
    function f:HookScript(event, fn) self.scripts[event] = fn end
    function f:SetPoint(...) end
    function f:SetFrameLevel(v) self.level = v end
    function f:GetFrameLevel() return self.level end
    function f:SetAllPoints(...) end
    function f:SetSize(...) end
    function f:ClearAllPoints() end
    return f
end
CreateFrame = function(_, _, parent) return frame(parent) end
hooksecurefunc = function(object, method, fn)
    local old = object[method]
    object[method] = function(...) local result = old(...); fn(...); return result end
end
local map = frame()
map.QuestLog = frame(map)
local view = frame(map)
view.inst = {189, 'Scarlet Monastery - Graveyard'}
view.side = frame(map.QuestLog)
local box = frame(view.side)
view.side.scroll = frame(box)
local rim = frame(box)
rim.regions = {{GetAtlas=function() return 'QuestLog-frame' end}}
local unrelated = frame(box)
unrelated.regions = {{GetAtlas=function() return 'unrelated-native-art' end}}
view.side.child = frame(view.side.scroll)
function view.side.child:SetHeight(h) self.height = h end
view.side.tabs = {frame(view.side), frame(view.side)}
_G.OpenMapDungeonView = view
local mod = {db = {dungeonTab = 'quests', dungeonQuests = true, dungeonBosses = true}}
local rendered = 0
local panel
NS.Panel = {New = function(parent)
    panel = frame(parent)
    function panel:Render(model) self.model = model; rendered = rendered + 1 end
    return panel
end}
assert(NS.Host, 'Host module must exist')
local host = NS.Host.New(map, mod, function() end)
local inst = host:Current()
assert(inst and inst[1] == 189, 'visible dungeon context is available')
host:Render({instanceID=189,active={},additional={}})
assert(panel:IsVisible() and not view.side.scroll:IsShown(), 'quest replacement exclusively owns visible list')
assert(not rim:IsShown(), 'unnecessary inner ornament must not cover reader controls')
assert(unrelated:IsShown(), 'border removal must not hide unrelated host chrome')
mod.db.dungeonTab = 'bosses'
assert(host:Current() == nil, 'boss tab must not return quest context')
assert(view.side.scroll:IsShown() and not panel:IsVisible(), 'native bosses list restored')
assert(rim:IsShown(), 'original ornament restored for unmodified native tabs')
mod.db.dungeonTab = 'quests'
mod.db.dungeonQuests = false
assert(host:Current() == nil, 'disabled quest tab must not cover native fallback')
assert(view.side.scroll:IsShown(), 'native fallback remains readable')
mod.db.dungeonTab = 'bosses'
mod.db.dungeonBosses = false
mod.db.dungeonQuests = true
assert(host:Current(), 'fallback to visible Quests must activate replacement')
view.floors = {{}, {}}
assert(host:Current() == nil, 'Floors wins over Quests in native fallback order')
view.floors = nil
mod.db.dungeonTab = 'quests'
view.side:Hide()
assert(host:Current() == nil, 'native quest log tab hides replacement')
assert(not panel:IsVisible(), 'hidden side must not leave floating quest panel')
view.side:Show()
map:Hide()
assert(host:Current() == nil, 'closed map has no active replacement')
print('PASS: quest-only host replacement and native list restoration')
