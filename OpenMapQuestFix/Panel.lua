local _, NS = ...

local T = NS.T
local Panel = {}
NS.Panel = Panel

local PADDING, SCROLLBAR, LINE_GAP = 10, 20, 5
local BODY_SIZE, TITLE_SIZE = 13, 14
local WHITE = { 0.92, 0.88, 0.76 }
local INK = { 0.20, 0.13, 0.07 }
local MUTED = { 0.65, 0.63, 0.55 }
local REWARD_TEXT = { 0.902, 0.788, 0.671 }
local TOOLBAR_HEIGHT = 52
local STATUS_KEYS = {
    active = true, failed = true, complete = true, completed = true,
    notAccepted = true, unknownPrerequisites = true,
}

local function Font(parent, template, size)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    local file, _, flags = text:GetFont()
    text:SetFont(file, size, flags)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
    return text
end

local function NativeFont(text, template)
    text:SetFontObject(template)
    local file, size = text:GetFont()
    text:SetFont(file, size, "")
    text:SetShadowOffset(0, 0)
    text:SetShadowColor(0, 0, 0, 0)
end

-- Match FrameXML's natural atlas heights; only the plain center spans the host.
-- Sampling the atlas' own UV rectangle avoids QuestBG's transparent padding.
local function AtlasStrip(parent, atlas, layer, sampleTop, sampleBottom)
    local info = C_Texture.GetAtlasInfo(atlas)
    assert(info, "OpenMapQuestFix: missing native atlas " .. atlas)
    local strip = CreateFrame("Frame", nil, parent)
    sampleTop, sampleBottom = sampleTop or 0, sampleBottom or 1
    strip:SetHeight(info.height * (sampleBottom - sampleTop))
    local edge = math.min(12, info.width / 3)
    local u0, u1 = info.leftTexCoord, info.rightTexCoord
    local v0, v1 = info.topTexCoord, info.bottomTexCoord
    assert(u0 and u1 and v0 and v1, "OpenMapQuestFix: invalid native atlas " .. atlas)
    local nativeTop, nativeBottom = v0, v1
    v0 = nativeTop + (nativeBottom - nativeTop) * sampleTop
    v1 = nativeTop + (nativeBottom - nativeTop) * sampleBottom
    -- OpenMap recursively relifts descendants when its dungeon pane redocks.
    -- Preserve its relative-level contract, not only today's absolute level.
    strip.levelOver = 0
    strip:SetFrameLevel(parent:GetFrameLevel())
    for index = 1, 3 do
        local texture = strip:CreateTexture(nil, layer or "BACKGROUND")
        texture:SetAtlas(atlas)
        local left = index == 1 and 0 or (index == 2 and edge or info.width - edge)
        local right = index == 1 and edge or (index == 2 and info.width - edge or info.width)
        texture:SetTexCoord(u0 + (u1 - u0) * left / info.width,
            u0 + (u1 - u0) * right / info.width, v0, v1)
        if index == 1 then
            texture:SetPoint("TOPLEFT")
            texture:SetPoint("BOTTOMLEFT")
            texture:SetWidth(edge)
        elseif index == 3 then
            texture:SetPoint("TOPRIGHT")
            texture:SetPoint("BOTTOMRIGHT")
            texture:SetWidth(edge)
        else
            texture:SetPoint("TOPLEFT", edge, 0)
            texture:SetPoint("BOTTOMRIGHT", -edge, 0)
        end
    end
    return strip
end

local function FillSurface(surface, atlas, width, height, topInset)
    surface:SetWidth(width)
    surface:SetHeight(math.max(1, height))
    local info = C_Texture.GetAtlasInfo(atlas)
    assert(info, "OpenMapQuestFix: missing native atlas " .. atlas)
    topInset = topInset or 0
    local used, offset = 0, topInset
    while offset > -math.max(1, height) do
        used = used + 1
        local strip = surface.strips[used]
        if not strip then
            if topInset > 0 and used > 1 then
                -- Extend only a natural-height interior parchment band. The
                -- composite's dark header/footer must never repeat mid-page.
                strip = AtlasStrip(surface, atlas, nil, 0.5 - 32 / info.height, 0.5 + 32 / info.height)
            else
                strip = AtlasStrip(surface, atlas, nil, 0, topInset > 0 and 1 - 32 / info.height or 1)
            end
            surface.strips[used] = strip
        end
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", 0, offset)
        strip:SetWidth(width)
        strip:Show()
        offset = offset - strip:GetHeight()
    end
    for index = used + 1, #surface.strips do surface.strips[index]:Hide() end
end

local function SetText(text, value, width, color)
    text:SetWidth(math.max(1, width))
    text:SetText(value or "")
    text:SetTextColor(color[1], color[2], color[3])
    return math.max(text:GetStringHeight(), BODY_SIZE)
end

local function QuestColor(quest)
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(quest.level or 0)
    if not color then return WHITE end
    return { color.r, color.g, color.b }
end

local function Status(quest)
    if quest.failed then return T("failed") end
    if quest.done then return T("completed") end
    if quest.complete then return T("complete") end
    if quest.status and STATUS_KEYS[quest.status] then return T(quest.status) end
    return T(quest.inLog and "active" or "notAccepted")
end

local function Title(quest)
    local name = quest.name or ("#" .. tostring(quest.id))
    if quest.level and quest.level > 0 then
        return "[" .. tostring(quest.level) .. "] " .. name
    end
    return name
end

local function HideTooltip(owner)
    if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function WatchTooltip(self)
    if not GameTooltip or not self.quest then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(T(self.quest.watched and "untrack" or "track"), 1, 0.82, 0)
    GameTooltip:Show()
end

local function CreateWatch(parent, panel)
    local watch = CreateFrame("CheckButton", nil, parent)
    watch:SetWidth(22)
    watch:SetHeight(22)
    watch:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    watch:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    watch:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    watch:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    watch:SetScript("OnClick", function(self)
        local quest = self.quest
        if not quest then return end
        -- Do not let the widget's automatic toggle invent watch state.
        self:SetChecked(quest.watched and true or false)
        if panel.callbacks.toggle then panel.callbacks.toggle(quest.id) end
    end)
    watch:SetScript("OnEnter", WatchTooltip)
    watch:SetScript("OnLeave", HideTooltip)
    return watch
end

local function NewQuestRow(panel)
    local row = CreateFrame("Button", nil, panel.content)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(16)
    row.icon:SetHeight(16)
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.title = Font(row, "GameFontNormal", TITLE_SIZE)
    row.title:SetPoint("TOPLEFT", 22, -2)
    row.status = Font(row, "GameFontHighlightSmall", 11)
    row.status:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.objectives = {}
    row.watch = CreateWatch(row, panel)
    row.watch:SetPoint("TOPRIGHT", 2, 2)
    row.rule = row:CreateTexture(nil, "BACKGROUND")
    row.rule:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.rule:SetVertexColor(0.65, 0.53, 0.25, 0.18)
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", 2, 0)
    row.rule:SetPoint("BOTTOMRIGHT", -2, 0)
    row:SetScript("OnClick", function(self)
        if panel.callbacks.open and self.quest then panel.callbacks.open(self.quest.id) end
    end)
    row:SetScript("OnHide", function(self) HideTooltip(self.watch) end)
    return row
end

local function LayoutQuest(row, quest, width)
    row.quest, row.watch.quest = quest, quest
    local titleWidth = width - 26 - (quest.inLog and 24 or 0)
    local height = 2 + SetText(row.title, Title(quest), titleWidth, QuestColor(quest))
    height = height + 4 + SetText(row.status, Status(quest), width - 26, MUTED)
    if quest.complete or quest.done then
        row.icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    elseif quest.failed then
        row.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    else
        row.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    row.icon:SetDesaturated(not quest.inLog and not quest.done)
    if quest.inLog then
        row.watch:SetChecked(quest.watched and true or false)
        row.watch:Show()
    else
        row.watch:Hide()
    end
    local objectives = quest.objectives or {}
    for index, objective in ipairs(objectives) do
        local text = row.objectives[index]
        if not text then
            text = Font(row, "GameFontHighlight", BODY_SIZE)
            row.objectives[index] = text
        end
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", 22, -height - LINE_GAP)
        local color = objective.finished and { 0.55, 0.77, 0.49 } or WHITE
        height = height + LINE_GAP + SetText(text, "- " .. (objective.text or ""), width - 26, color)
        text:Show()
    end
    for index = #objectives + 1, #row.objectives do row.objectives[index]:Hide() end
    row:SetHeight(height + 12)
    return height + 12
end

local function NewBlock(panel)
    local block = CreateFrame("Frame", nil, panel.content)
    block.text = Font(block, "GameFontHighlight", BODY_SIZE)
    block.text:SetPoint("TOPLEFT", 0, 0)
    return block
end

local function NewSection(panel)
    local section = CreateFrame("Button", nil, panel.content)
    section.text = Font(section, "GameFontNormal", TITLE_SIZE)
    section.text:SetPoint("TOPLEFT", 2, -5)
    section:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    section:SetScript("OnClick", function(self)
        if self.collapsible and panel.callbacks.collapse then panel.callbacks.collapse() end
    end)
    return section
end

local function RewardTooltip(self)
    if not GameTooltip or not self.reward then return end
    local reward = self.reward
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shown = false
    if reward.link and GameTooltip.SetHyperlink then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, reward.link)
    end
    if not shown and reward.index and self.quest.inLog and GameTooltip.SetQuestLogItem then
        shown = pcall(GameTooltip.SetQuestLogItem, GameTooltip,
            reward.choice and "choice" or "reward", reward.index, self.quest.id)
    end
    if not shown then
        GameTooltip:SetText(reward.name or T("itemPending"), 1, 0.82, 0)
        GameTooltip:AddLine(T("itemUnavailable"), 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function RewardLink(row)
    local reward, quest = row.reward, row.quest
    if not reward then return end
    if reward.link then return reward.link end
    if quest.inLog and reward.index and GetQuestLogItemLink then
        return GetQuestLogItemLink(reward.choice and "choice" or "reward", reward.index, quest.id)
    end
end

local function NewReward(panel, template)
    local row = CreateFrame("Button", nil, panel.content, template or "SmallQuestRewardItemButtonTemplate")
    -- Every inherited script is replaced: Blizzard's reward mixin reads the
    -- singleton QuestInfoFrame and the journal selection, not this record.
    row:SetScript("OnEnter", RewardTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnHide", HideTooltip)
    row:SetScript("OnUpdate", nil)
    row:SetScript("OnClick", function(self)
        if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
            local link = RewardLink(self)
            if link then HandleModifiedItemClick(link) end
        end
    end)
    row.UpdateTooltip = RewardTooltip
    row.icon, row.count, row.text = row.Icon, row.Count, row.Name
    NativeFont(row.text, "QuestFont")
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    row.text:ClearAllPoints()
    row.text:SetHeight(0)
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    return row
end

local function NewValueReward(panel)
    return NewReward(panel, "SmallItemButtonTemplate")
end

local function Take(panel, kind, create)
    local pool = panel.pools[kind]
    pool.used = pool.used + 1
    local widget = pool[pool.used]
    if not widget then
        widget = create(panel)
        pool[pool.used] = widget
    end
    widget:Show()
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", PADDING, -panel.cursor)
    widget:SetWidth(panel.contentWidth - PADDING * 2)
    return widget
end

local function Advance(panel, height, gap)
    panel.cursor = panel.cursor + height + (gap or LINE_GAP)
end

local function Block(panel, value, heading, color)
    if not value or value == "" then return end
    local block = Take(panel, "blocks", NewBlock)
    if panel.detail then
        NativeFont(block.text, heading and "QuestTitleFont" or "QuestFont")
    else
        block.text:SetFontObject("GameFontHighlight")
        local file, _, flags = block.text:GetFont()
        block.text:SetFont(file, heading and TITLE_SIZE or BODY_SIZE, flags)
    end
    local height = SetText(block.text, value, block:GetWidth(), color or (panel.detail and INK or WHITE))
    block:SetHeight(height)
    Advance(panel, height, heading and 8 or LINE_GAP)
end

local function Section(panel, title, collapsible)
    local section = Take(panel, "sections", NewSection)
    section.collapsible = collapsible
    section:EnableMouse(collapsible)
    local height = 10 + SetText(section.text, title, section:GetWidth() - 4, { 1, 0.82, 0 })
    section:SetHeight(height)
    Advance(panel, height, 8)
end

local function List(panel, model)
    local active, additional = model.active or {}, model.additional or {}
    Section(panel, T("activeQuests") .. " (" .. #active .. ")", false)
    if #active == 0 then Block(panel, T("noActiveQuests")) end
    for _, quest in ipairs(active) do
        local row = Take(panel, "quests", NewQuestRow)
        Advance(panel, LayoutQuest(row, quest, row:GetWidth()), 6)
    end
    if model.loading then Block(panel, T("indexing"), false, MUTED) end
    if model.known == false then Block(panel, T("unknownDungeon"), false, MUTED) end
    panel.cursor = panel.cursor + 8
    local prefix = model.expanded and "[-] " or "[+] "
    Section(panel, prefix .. T("additionalQuests") .. " (" .. #additional .. ")", true)
    if model.expanded then
        Block(panel, T("databaseNotice"), false, MUTED)
        if #additional == 0 and not model.loading then Block(panel, T("noAdditionalQuests")) end
        for _, quest in ipairs(additional) do
            local row = Take(panel, "quests", NewQuestRow)
            Advance(panel, LayoutQuest(row, quest, row:GetWidth()), 6)
        end
    end
end

local function Money(amount)
    amount = math.floor(amount)
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    local parts = {}
    local gold = math.floor(amount / 10000)
    local silver = math.floor(amount / 100) % 100
    local copper = amount % 100
    if gold > 0 then parts[#parts + 1] = string.format(T("goldAmount"), gold) end
    if silver > 0 then parts[#parts + 1] = string.format(T("silverAmount"), silver) end
    if copper > 0 then parts[#parts + 1] = string.format(T("copperAmount"), copper) end
    return table.concat(parts, " ")
end

local function RewardLabel(panel, value, heading)
    local block = Take(panel, "rewardLabels", NewBlock)
    NativeFont(block.text, heading and "QuestFont_Huge" or "QuestFont")
    block.text:SetJustifyH(heading and "CENTER" or "LEFT")
    local height = SetText(block.text, value, block:GetWidth(), REWARD_TEXT)
    block:SetHeight(height)
    Advance(panel, height, heading and 16 or 8)
end

local function LayoutReward(panel, row, name, texture, count)
    row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.count:SetText((count or 1) > 1 and tostring(count) or "")
    row.text:SetWidth(math.max(1, row:GetWidth() - row.icon:GetWidth() - 12))
    row.text:SetHeight(0)
    local height = SetText(row.text, name, row.text:GetWidth(), REWARD_TEXT)
    height = math.max(row.icon:GetHeight(), height + 4)
    row:SetHeight(height)
    row.NameFrame:ClearAllPoints()
    row.NameFrame:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 2, 0)
    row.NameFrame:SetWidth(math.max(1, row:GetWidth() - row.icon:GetWidth() - 2))
    row.NameFrame:SetHeight(height)
    Advance(panel, height, 8)
end

local function RewardGroup(panel, quest, choice)
    local started = false
    for _, reward in ipairs(quest.rewards or {}) do
        if (reward.choice and true or false) == choice then
            if not started then
                RewardLabel(panel, T(choice and "chooseReward" or "guaranteedRewards"))
                started = true
            end
            local row = Take(panel, "rewards", NewReward)
            row.reward, row.quest = reward, quest
            LayoutReward(panel, row, reward.name or T("itemPending"), reward.texture, reward.count)
        end
    end
end

local function ValueReward(panel, quest, value, texture)
    local row = Take(panel, "values", NewValueReward)
    row.reward, row.quest = nil, quest
    LayoutReward(panel, row, value, texture)
end

local function Rewards(panel, quest)
    local hasItems = quest.rewards and #quest.rewards > 0
    if not hasItems and (quest.money or 0) <= 0 and (quest.xp or 0) <= 0 then return end
    panel.cursor = panel.cursor + 12
    local top = panel.cursor
    panel.rewardSurface:ClearAllPoints()
    panel.rewardSurface:SetPoint("TOPLEFT", 0, -top)
    panel.rewardSurface:SetWidth(panel.contentWidth)
    panel.rewardSurface:Show()
    panel.cursor = top + 22
    RewardLabel(panel, T("rewards"), true)
    RewardGroup(panel, quest, true)
    RewardGroup(panel, quest, false)
    if (quest.xp or 0) > 0 then
        ValueReward(panel, quest, string.format(T("xpAmount"), quest.xp), "Interface\\Icons\\XP_Icon")
    end
    if (quest.money or 0) > 0 then
        ValueReward(panel, quest, Money(quest.money), "Interface\\Icons\\inv_misc_coin_01")
    end
    panel.cursor = panel.cursor + 12
    FillSurface(panel.rewardSurface, "questlog-reward-tile-vertical", panel.contentWidth,
        math.max(panel.rewardTop:GetHeight() + panel.rewardBottom:GetHeight(), panel.cursor - top))
    panel.cursor = top + panel.rewardSurface:GetHeight()
    return top
end

local function NavigationButtons(panel, quest)
    if not NS.Navigation then return end
    local actions = NS.Navigation.List(quest)
    if #actions == 0 then return end
    if panel.rewardSurface:IsShown() then RewardLabel(panel, T("openIn"))
    else Block(panel, T("openIn")) end
    local pool = panel.pools.navigation
    for _, action in ipairs(actions) do
        pool.used = pool.used + 1
        local button = pool[pool.used]
        if not button then
            button = CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
            button:SetHeight(22)
            button:SetScript("OnClick", function()
                local record = panel.model and panel.model.selected
                if record then NS.Navigation.Open(button.providerKey, record) end
            end)
            pool[pool.used] = button
        end
        button.providerKey = action.key
        button:SetText(action.label)
        button:SetWidth(math.max(1, panel.contentWidth - PADDING * 2))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", PADDING, -panel.cursor)
        button:Show()
        Advance(panel, 22, 6)
    end
    panel.cursor = panel.cursor + 4
end

local function Details(panel, quest)
    Block(panel, quest.name or ("#" .. tostring(quest.id)), true)
    Block(panel, quest.summary)
    local objectives = quest.objectives or {}
    for _, objective in ipairs(objectives) do
        Block(panel, "- " .. (objective.text or ""), false,
            objective.finished and { 0.16, 0.35, 0.12 } or INK)
    end
    if #objectives == 0 and (not quest.summary or quest.summary == "") then
        Block(panel, T("noObjectives"))
    end
    if quest.description and quest.description ~= "" then
        panel.cursor = panel.cursor + 12
        Block(panel, T("description"), true)
        Block(panel, quest.description)
    elseif quest.inLog then
        panel.cursor = panel.cursor + 12
        Block(panel, T("description"), true)
        Block(panel, T("descriptionUnavailable"))
    end
    -- Source-only records may expose known prose/goals, never invented offers.
    panel.cursor = panel.cursor + 12
    Block(panel, Status(quest))
    if not quest.inLog then Block(panel, T("databaseNotice")) end
    if quest.inLog then
        panel.watch:ClearAllPoints()
        panel.watch:SetPoint("TOPLEFT", panel.content, "TOPLEFT", PADDING - 2, -panel.cursor)
        panel.watchLabel:ClearAllPoints()
        panel.watchLabel:SetPoint("TOPLEFT", panel.content, "TOPLEFT", PADDING + 22, -panel.cursor - 4)
        local height = SetText(panel.watchLabel, T("track"), panel.contentWidth - PADDING * 2 - 24, INK)
        panel.watchLabel:Show()
        Advance(panel, math.max(22, height + 4), 8)
    end
    local rewardTop = Rewards(panel, quest)
    NavigationButtons(panel, quest)
    if rewardTop and panel.pools.navigation.used > 0 then
        FillSurface(panel.rewardSurface, "questlog-reward-tile-vertical", panel.contentWidth, panel.cursor - rewardTop)
        panel.cursor = rewardTop + panel.rewardSurface:GetHeight()
    end
end

local function Offset(panel, value)
    local maximum = math.max(0, panel.content:GetHeight() - panel.scroll:GetHeight())
    value = math.max(0, math.min(value or 0, maximum))
    panel.scroll:SetVerticalScroll(value)
    if panel.detail then panel.detailOffset = value else panel.listOffset = value end
    panel.settingScroll = true
    panel.bar:SetValue(value)
    panel.settingScroll = false
    if value > 0 then panel.up:Enable() else panel.up:Disable() end
    if value < maximum then panel.down:Enable() else panel.down:Disable() end
end

local function Arrow(panel, direction)
    local button = CreateFrame("Button", nil, panel)
    button:SetWidth(16)
    button:SetHeight(16)
    local name = direction == 1 and "Down" or "Up"
    button:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Highlight", "ADD")
    button:SetScript("OnClick", function()
        Offset(panel, panel.scroll:GetVerticalScroll() + direction * 40)
    end)
    return button
end

local function Render(self, model)
    if self.rendering then return end
    self.rendering = true
    local selectedID = model.selected and model.selected.id
    if NS.Navigation and (selectedID ~= self.selectedID or model.instanceID ~= self.instanceID) then NS.Navigation.Cancel() end
    if self.instanceID ~= model.instanceID then
        self.listOffset, self.detailOffset, self.selectedID = 0, 0, nil
    end
    if selectedID ~= self.selectedID then self.detailOffset = 0 end
    self.instanceID, self.selectedID, self.model = model.instanceID, selectedID, model
    self.detail = model.selected ~= nil
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", 0, self.detail and -TOOLBAR_HEIGHT or -4)
    self.scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, 4)
    self.contentWidth = math.max(1, self.scroll:GetWidth())
    self.content:SetWidth(self.contentWidth)
    self.rewardSurface:Hide()
    self.watchLabel:Hide()
    self.watch.quest = nil
    self.reader:SetQuest(model.selected)
    if self.detail then
        self.background:SetVertexColor(0.22, 0.15, 0.08, 1)
        -- Native details art begins behind the brown header, not at the text
        -- viewport. Clip that dark upper vignette away without stretching UVs.
        FillSurface(self.paper, "QuestDetailsBackgrounds", self.contentWidth, self.scroll:GetHeight(), TOOLBAR_HEIGHT)
        self.paper:Show()
        self.toolbar:Show()
        self.back:Show()
        local buttonWidth = math.min(100, math.max(1, (self:GetWidth() - 28) / 2))
        self.back:SetWidth(buttonWidth)
        self.reader:SetWidth(buttonWidth)
        if model.selected.inLog then
            self.watch.quest = model.selected
            self.watch:SetChecked(model.selected.watched and true or false)
            self.watch:Show()
        else self.watch:Hide() end
    else
        self.background:SetVertexColor(0.05, 0.045, 0.03, 0.96)
        self.paper:Hide()
        self.toolbar:Hide()
        self.back:Hide()
        self.watch:Hide()
    end
    self.up:ClearAllPoints()
    self.up:SetPoint("TOPRIGHT", -2, self.detail and -TOOLBAR_HEIGHT - 2 or -4)
    self.cursor = 8
    for _, pool in pairs(self.pools) do pool.used = 0 end
    if self.detail then Details(self, model.selected) else List(self, model) end
    for _, pool in pairs(self.pools) do
        for index = pool.used + 1, #pool do pool[index]:Hide() end
    end
    self.content:SetHeight(math.max(1, self.cursor + 8))
    self.scroll:UpdateScrollChildRect()
    local maximum = math.max(0, self.content:GetHeight() - self.scroll:GetHeight())
    self.settingScroll = true
    self.bar:SetMinMaxValues(0, maximum)
    self.settingScroll = false
    Offset(self, self.detail and self.detailOffset or self.listOffset)
    self.rendering = false
end

function Panel.New(parent, callbacks)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)
    panel.callbacks = callbacks or {}
    panel.listOffset, panel.detailOffset = 0, 0
    panel.pools = {
        quests = { used = 0 }, blocks = { used = 0 }, sections = { used = 0 },
        rewards = { used = 0 }, values = { used = 0 }, rewardLabels = { used = 0 },
        navigation = { used = 0 },
    }
    panel.Render = Render
    panel.background = panel:CreateTexture(nil, "BACKGROUND")
    panel.background:SetAllPoints(panel)
    panel.background:SetTexture("Interface\\Buttons\\WHITE8X8")
    panel.background:SetVertexColor(0.05, 0.045, 0.03, 0.96)
    panel.paper = CreateFrame("Frame", nil, panel)
    panel.paper:SetPoint("TOPLEFT", 0, -TOOLBAR_HEIGHT)
    panel.paper:SetClipsChildren(true)
    panel.paper.strips = {}
    panel.paper:Hide()
    panel.scroll = CreateFrame("ScrollFrame", nil, panel)
    panel.scroll:SetPoint("TOPLEFT", 0, -4)
    panel.scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, 4)
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetWidth(1)
    panel.content:SetHeight(1)
    panel.scroll:SetScrollChild(panel.content)
    panel.scroll.levelOver = 2
    panel.scroll:SetFrameLevel(panel:GetFrameLevel() + 2)
    panel.rewardSurface = CreateFrame("Frame", nil, panel.content)
    panel.rewardSurface.levelOver = 0
    panel.rewardSurface:SetFrameLevel(panel.content:GetFrameLevel())
    panel.rewardSurface:SetClipsChildren(true)
    panel.rewardSurface.strips = {}
    panel.rewardTop = AtlasStrip(panel.rewardSurface, "questlog-reward-header-top", "BORDER")
    panel.rewardTop:SetPoint("TOPLEFT")
    panel.rewardTop:SetPoint("TOPRIGHT")
    panel.rewardBottom = AtlasStrip(panel.rewardSurface, "questlog-reward-bottom", "BORDER")
    panel.rewardBottom:SetPoint("BOTTOMLEFT")
    panel.rewardBottom:SetPoint("BOTTOMRIGHT")
    panel.rewardSurface:Hide()
    panel.scroll:EnableMouseWheel(true)
    panel.scroll:SetScript("OnMouseWheel", function(_, delta)
        Offset(panel, panel.scroll:GetVerticalScroll() - delta * 40)
    end)
    panel.up = Arrow(panel, -1)
    panel.up:SetPoint("TOPRIGHT", -2, -4)
    panel.down = Arrow(panel, 1)
    panel.down:SetPoint("BOTTOMRIGHT", -2, 4)
    panel.bar = CreateFrame("Slider", nil, panel)
    panel.bar:SetOrientation("VERTICAL")
    panel.bar:SetWidth(14)
    panel.bar:SetPoint("TOP", panel.up, "BOTTOM", 0, -1)
    panel.bar:SetPoint("BOTTOM", panel.down, "TOP", 0, 1)
    panel.bar:SetMinMaxValues(0, 0)
    panel.bar:SetValueStep(1)
    panel.bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    panel.bar:GetThumbTexture():SetWidth(14)
    panel.bar:GetThumbTexture():SetHeight(24)
    panel.bar.track = panel.bar:CreateTexture(nil, "BACKGROUND")
    panel.bar.track:SetAllPoints(panel.bar)
    panel.bar.track:SetTexture("Interface\\Buttons\\WHITE8X8")
    panel.bar.track:SetVertexColor(0.08, 0.06, 0.03, 0.5)
    panel.bar:SetScript("OnValueChanged", function(_, value)
        if not panel.settingScroll then Offset(panel, value) end
    end)
    panel.bar:EnableMouseWheel(true)
    panel.bar:SetScript("OnMouseWheel", function(_, delta)
        Offset(panel, panel.scroll:GetVerticalScroll() - delta * 40)
    end)
    panel.toolbar = CreateFrame("Frame", nil, panel)
    panel.toolbar:SetPoint("TOPLEFT")
    panel.toolbar:SetPoint("TOPRIGHT")
    panel.toolbar:SetHeight(TOOLBAR_HEIGHT)
    panel.toolbar:SetClipsChildren(true)
    panel.toolbar.background = AtlasStrip(panel.toolbar, "questlog-reward-top-frame", "BORDER")
    panel.toolbar.background:SetPoint("TOPLEFT")
    panel.toolbar.background:SetPoint("TOPRIGHT")
    panel.toolbar:Hide()
    panel.back = CreateFrame("Button", nil, panel.toolbar, "UIPanelButtonTemplate")
    panel.back.levelOver = 2
    panel.back:SetFrameLevel(panel.toolbar:GetFrameLevel() + 2)
    panel.back:SetWidth(100)
    panel.back:SetHeight(22)
    panel.back:SetPoint("TOPLEFT", 8, -6)
    panel.back:SetText(T("back"))
    panel.back:SetScript("OnClick", function()
        if panel.callbacks.back then panel.callbacks.back() end
    end)
    panel.back:Hide()
    panel.reader = NS.Reader.New(panel.toolbar)
    panel.reader.levelOver = 2
    panel.reader:SetFrameLevel(panel.toolbar:GetFrameLevel() + 2)
    panel.reader:SetPoint("TOPRIGHT", -8, -6)
    panel.reader:SetSize(100, 22)
    panel.watch = CreateWatch(panel.content, panel)
    panel.watchLabel = Font(panel.content, "QuestFont", BODY_SIZE)
    NativeFont(panel.watchLabel, "QuestFont")
    panel.watchLabel:Hide()
    panel.watch:Hide()
    panel:SetScript("OnSizeChanged", function(self)
        if self.model and not self.rendering then self:Render(self.model) end
    end)
    panel:SetScript("OnShow", function(self)
        if self.model then self:Render(self.model) end
    end)
    panel:SetScript("OnHide", function(self)
        if NS.Navigation then NS.Navigation.Cancel() end
        HideTooltip(self.watch)
        for _, pool in pairs(self.pools) do
            for index = 1, #pool do
                local row = pool[index]
                HideTooltip(row)
                if row.watch then HideTooltip(row.watch) end
            end
        end
    end)
    return panel
end
