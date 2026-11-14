local _, NS = ...
local Host = {}
NS.Host = Host

function Host.New(map, mod, changed, callbacks)
    local self = { map = map, mod = mod, changed = changed, callbacks = callbacks }
    return setmetatable(self, { __index = Host })
end

function Host:Attach()
    local view = _G.OpenMapDungeonView
    if self.view == view and self.panel then return true end
    if not view then return false end
    local side = view.side
    if not (side and side.scroll and side.child and side.tabs and view.inst) then
        if not self.warned and NS.Print then
            self.warned = true
            NS.Print(GetLocale() == "ruRU" and "Несовместимая панель данжей OpenMap; оставлена исходная вкладка."
                or "Unsupported OpenMap dungeon panel; original tab retained.")
        end
        return false
    end
    self.view, self.side = view, side
    -- The native inset's ornamental frame is drawn above its entire contents.
    -- Keep it for native tabs, but not over this replacement's reading controls.
    local box = side.scroll:GetParent()
    for _, child in ipairs({box:GetChildren()}) do
        if child ~= side.scroll then
            for _, region in ipairs({child:GetRegions()}) do
                local atlas = region.GetAtlas and region:GetAtlas()
                if type(atlas) == "string" and atlas:lower() == "questlog-frame" then
                    self.ornament = child
                    break
                end
            end
        end
        if self.ornament then break end
    end
    local bounds = CreateFrame("Frame", nil, side)
    bounds:SetPoint("TOPLEFT", side.scroll, "TOPLEFT")
    bounds:SetPoint("BOTTOMRIGHT", side.scroll, "BOTTOMRIGHT", 22, 0)
    bounds:SetFrameLevel(side.scroll:GetFrameLevel() + 1)
    self.bounds = bounds
    self.panel = NS.Panel.New(bounds, self.callbacks)
    bounds:Hide()
    local function changed() self.changed() end
    -- FillSide finishes with SetHeight even if a dungeon's identity changed while
    -- the view stayed shown; the callback runs after OpenMap's synchronous layout.
    hooksecurefunc(side.child, "SetHeight", changed)
    side:HookScript("OnShow", changed)
    side:HookScript("OnHide", function() bounds:Hide(); changed() end)
    side:HookScript("OnSizeChanged", changed)
    view:HookScript("OnShow", changed)
    view:HookScript("OnHide", function() bounds:Hide(); changed() end)
    for _, tab in ipairs(side.tabs) do tab:HookScript("OnClick", changed) end
    return true
end

function Host:Restore()
    if self.bounds then self.bounds:Hide() end
    if self.panel then self.panel:Hide() end
    if self.side then self.side.scroll:Show() end
    if self.ornament and self.ornamentWasShown ~= nil then
        self.ornament:SetShown(self.ornamentWasShown)
        self.ornamentWasShown = nil
    end
end

function Host:QuestTabSelected()
    local db = self.mod.db
    -- FillSide resolves unavailable stored tabs locally, without writing db.
    -- Follow that exact visibility and priority before replacing its contents.
    local shown = { bosses = db.dungeonBosses, quests = db.dungeonQuests, loot = true,
        floors = self.view.floors and #self.view.floors > 1 }
    local tab = db.dungeonTab
    if not shown[tab] then
        tab = shown.floors and "floors" or shown.bosses and "bosses" or shown.quests and "quests" or "loot"
    end
    return tab == "quests"
end

function Host:Current()
    if not self:Attach() then return end
    local on = self.map:IsVisible() and self.view:IsVisible() and not self.view.leaving
        and self.side:IsVisible() and self:QuestTabSelected()
    if not on then self:Restore(); return end
    return self.view.inst
end

function Host:Render(model)
    if not self:Current() then return end
    self.side.scroll:Hide()
    if self.ornament then
        if self.ornamentWasShown == nil then self.ornamentWasShown = self.ornament:IsShown() end
        self.ornament:Hide()
    end
    self.bounds:Show()
    self.panel:Show()
    self.panel:Render(model)
end

function Host:Install()
    local function changed() self.changed() end
    self.map:HookScript("OnShow", function()
        changed()
        -- OpenMap creates its dungeon view in its own deferred OnShow handler.
        C_Timer.After(0.25, changed)
    end)
    self.map:HookScript("OnHide", function() self:Restore(); changed() end)
    if self.map.QuestLog then
        self.map.QuestLog:HookScript("OnShow", changed)
        self.map.QuestLog:HookScript("OnHide", changed)
    end
    for _, method in ipairs({ "RefreshDungeonCard", "RefreshRail", "PlaceDungeonTabs", "CloseDungeonView" }) do
        if type(self.mod[method]) == "function" then hooksecurefunc(self.mod, method, changed) end
    end
end
