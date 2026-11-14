-- These consumers catch stale list/detail styling, reader identity, scroll jumps,
-- and reward template scripts accidentally consulting the selected native quest.
-- WoW owns layout/rendering; this double retains dimensions and visible output.
local function widget(parent)
    local f = {parent=parent, shown=true, scripts={}, points={}, width=320, height=400, text='', font='GameFontHighlight', size=13}
    f.children={}
    if parent then parent.children[#parent.children+1]=f end
    function f:SetWidth(v) self.width=v end
    function f:SetHeight(v) self.height=v end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:GetWidth()
        if self.scrollChild then return self.parent:GetWidth()-20 end
        if self.kind=='ScrollFrame' then return self.parent:GetWidth()-20 end
        return self.width
    end
    function f:GetHeight()
        if self.kind=='ScrollFrame' then return self.parent:GetHeight()-(self.topInset or 4)-4 end
        return self.height
    end
    function f:SetPoint(point,...)
        self.points[#self.points+1]={point,...}
        if self.kind=='ScrollFrame' and point=='TOPLEFT' then local a={...}; self.topInset=-(a[#a] or 0) end
    end
    function f:ClearAllPoints() self.points={} end
    function f:SetAllPoints() end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:SetShown(v) self.shown=not not v end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:SetScript(event,fn) self.scripts[event]=fn end
    function f:GetScript(event) return self.scripts[event] end
    function f:RegisterForClicks() end
    function f:EnableMouse() end
    function f:EnableMouseWheel() end
    function f:SetClipsChildren() end
    function f:SetFrameLevel(value) self.level=value end
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetNormalTexture() end
    function f:SetPushedTexture() end
    function f:SetHighlightTexture() end
    function f:SetDisabledTexture() end
    function f:SetCheckedTexture() end
    function f:SetChecked(v) self.checked=v end
    function f:SetTexture(v) self.texture=v end
    function f:SetAtlas(v,useSize) self.atlas=v; if useSize then self.height=64 end end
    function f:SetTexCoord(...) self.uv={...} end
    function f:SetVertexColor(...) self.color={...} end
    function f:SetDesaturated() end
    function f:SetOrientation() end
    function f:SetMinMaxValues(lo,hi) self.minimum,self.maximum=lo,hi end
    function f:SetValueStep() end
    function f:SetValue(v) self.value=v end
    function f:SetThumbTexture() self.thumb=widget(self) end
    function f:GetThumbTexture() return self.thumb end
    function f:SetScrollChild(child) self.child=child end
    function f:UpdateScrollChildRect() end
    function f:SetVerticalScroll(v) self.offset=v end
    function f:GetVerticalScroll() return self.offset or 0 end
    function f:Enable() self.enabled=true end
    function f:Disable() self.enabled=false end
    function f:SetID(v) self.id=v end
    function f:SetText(v) self.text=v or '' end
    function f:GetText() return self.text end
    function f:GetFont() return self.font,self.size,self.flags end
    function f:SetFont(file,size,flags) self.font,self.size,self.flags=file,size,flags end
    function f:SetFontObject(font) self.font=font end
    function f:SetTextColor(...) self.color={...} end
    function f:SetShadowOffset(...) self.shadow={...} end
    function f:SetShadowColor() end
    function f:SetJustifyH() end
    function f:SetJustifyV() end
    function f:SetWordWrap() end
    function f:SetNonSpaceWrap() end
    function f:GetStringHeight()
        local height=math.max(13,math.ceil(#self.text/math.max(1,math.floor(self:GetWidth()/7)))*13)
        if self.fixedTextHeight and self.height>0 then return math.min(height,self.height) end
        return height
    end
    function f:CreateTexture() return widget(self) end
    function f:CreateFontString(_,_,font) local t=widget(self); t.font=font; return t end
    return f
end
CreateFrame=function(kind,_,parent,template)
    local f=widget(parent); f.kind,f.template=kind,template
    if template=='SmallQuestRewardItemButtonTemplate' or template=='SmallItemButtonTemplate' then
        f.Icon,f.Count,f.Name,f.NameFrame=widget(f),widget(f),widget(f),widget(f)
        f.Icon:SetSize(30,30)
        f.Name:SetSize(92,36); f.Name.fixedTextHeight=true
        f.NameFrame:SetSize(104,30)
        -- The real template consults QuestInfoFrame/selection. Render must replace it.
        for _,event in ipairs({'OnEnter','OnLeave','OnClick','OnUpdate'}) do
            f.scripts[event]=function() error('native selected-quest script leaked') end
        end
    end
    return f
end
C_Texture={GetAtlasInfo=function(name)
    local width,height=307,64
    if name=='QuestDetailsBackgrounds' then width,height=287,464 end
    return {width=width,height=height,leftTexCoord=0,rightTexCoord=1,topTexCoord=0,bottomTexCoord=1}
end}
GetQuestDifficultyColor=function() return {r=1,g=0.82,b=0} end
GetCoinTextureString=function(amount) return tostring(amount)..' coins' end
local oldReader=NS.Reader
NS.Reader={New=function(parent)
    local reader=widget(parent)
    function reader:SetQuest(quest) self.quest=quest; self:SetShown(quest~=nil) end
    return reader
end}
local root=widget(); root:SetSize(320,400)
local opened,backed,tracked
local panel=NS.Panel.New(root,{open=function(id) opened=id end,back=function() backed=true end,toggle=function(id) tracked=id end})
local active={id=42,name='A real quest',inLog=true,summary='Known summary',description=string.rep('Long real description. ',120),objectives={{text='Known goal'}},rewards={{name='Real item',index=1,count=2,texture=1}},xp=50,money=100}
local function model(selected)
    return {instanceID=1,selected=selected,active={active,active,active,active,active,active,active,active},additional={},expanded=true}
end
panel:Render(model(nil))
panel.scroll.scripts.OnMouseWheel(panel.scroll,-2)
assert(panel.scroll:GetVerticalScroll()>0,'list fixture needs a scroll offset')
local listOffset=panel.scroll:GetVerticalScroll()
panel:Render(model(active))
assert(panel.reader.quest==active,'reader targets the displayed record')
local paperStrip=panel.paper.strips[1]
assert(paperStrip.points[1][3]==52,'parchment upper vignette sits clipped behind the native toolbar')
assert(paperStrip:GetHeight()==432,'parchment retains native pixels while excluding its dark bottom border')
assert(panel.toolbar:IsShown(),'native detail navigation is visible')
assert(panel.paper:IsShown(),'quest text has its parchment surface')
local function relift(frame,level)
    frame:SetFrameLevel(level)
    for _,child in ipairs(frame.children) do relift(child,level+(child.levelOver or 1)) end
end
relift(panel,600)
assert(panel.back:GetFrameLevel()>panel.toolbar.background:GetFrameLevel(),'redocking keeps Back above the native toolbar art')
assert(panel.reader:GetFrameLevel()>panel.toolbar.background:GetFrameLevel(),'redocking keeps Reader above native toolbar art')
assert(panel.pools.rewards[1]:GetFrameLevel()>panel.rewardTop:GetFrameLevel(),'redocking keeps reward cards above the brown reward background')
assert(panel.scroll:GetVerticalScroll()==0,'opening a different quest starts at its title')
local title,summary,description,objectiveHeading
for _,block in ipairs(panel.pools.blocks) do
    if block:IsShown() then
        local value=block.text:GetText()
        if value=='A real quest' then title=block end
        if value=='Known summary' then summary=block end
        if value==NS.T('description') then description=block end
        if value==NS.T('objectives') then objectiveHeading=block end
    end
end
assert(title and title.text.font=='QuestTitleFont','detail title uses the native title font')
assert(summary and summary.text.font=='QuestFont','summary uses native parchment body font')
assert(summary.text.shadow[1]==0 and summary.text.shadow[2]==0,'parchment body has no inherited shadow')
assert(description and not objectiveHeading,'summary flows below title without a redundant Objectives heading')
local reward=panel.pools.rewards[1]
assert(reward.template=='SmallQuestRewardItemButtonTemplate','reward uses the native item card')
local tooltipQuest,clickedLink
GameTooltip={SetOwner=function() end,SetQuestLogItem=function(_,kind,index,id) tooltipQuest=id end,Show=function() end,IsOwned=function() return false end}
reward.scripts.OnEnter(reward)
assert(tooltipQuest==42,'reward tooltip receives explicit displayed quest ID')
GetQuestLogItemLink=function(kind,index,id) assert(id==42,'reward link must not use native selection'); return 'item:123' end
IsModifiedClick=function() return true end
HandleModifiedItemClick=function(link) clickedLink=link end
reward.scripts.OnClick(reward,'LeftButton')
assert(clickedLink=='item:123','modified reward click handles the displayed reward link')
assert(reward.scripts.OnUpdate==nil,'native reward update must not depend on singleton state')
reward.reward={choice=true,index=1,itemID=6829,link='item:6829',name='Live sword'}
local tooltipLink
GameTooltip.SetHyperlink=function(_,link) tooltipLink=link end
reward.scripts.OnEnter(reward)
assert(tooltipLink=='item:6829','live choice tooltip must not query a filtered slot with a different item')
reward.scripts.OnClick(reward,'LeftButton')
assert(clickedLink=='item:6829','choice chat link preserves item ID after native selection restoration')
panel.scroll.scripts.OnMouseWheel(panel.scroll,-3)
local detailOffset=panel.scroll:GetVerticalScroll()
assert(detailOffset>0,'detail fixture needs a scroll offset')
panel:Render(model(active))
assert(panel.scroll:GetVerticalScroll()==detailOffset,'refresh preserves current quest reading position')
active.watched=true
panel:Render(model(active))
assert(panel.watch.checked and panel.watchLabel:GetText()==NS.T('track'),'checked tracking control describes enabled tracking, not the inverse action')
panel.watch.scripts.OnClick(panel.watch)
assert(tracked==42,'tracking checkbox toggles the displayed quest')
active.watched=false
panel:Render(model(active))
assert(not panel.watch.checked and panel.watchLabel:GetText()==NS.T('track'),'unchecked tracking retains the same positive state label')
panel:SetWidth(240); panel:Render(model(active))
assert(panel.back:GetWidth()+panel.reader:GetWidth()<=212,'narrow toolbar never overlaps Back and Read')
local shortHeight=reward:GetHeight()
active.rewards[1].name=string.rep('Длинное локализованное название награды ',5)
panel:Render(model(active))
assert(reward:GetHeight()>36 and reward:GetHeight()>shortHeight,'long localized reward grows beyond the inherited name height')
assert(reward.text:GetStringHeight()+4<=reward:GetHeight(),'reward row contains the entire wrapped item name')
assert(reward.NameFrame:GetHeight()==reward:GetHeight(),'native card background grows with all wrapped lines')
assert(reward.NameFrame:GetWidth()>=reward.text:GetWidth()+6,'native card background covers the full expanded label width')
active.rewards[1].name='Real item'
assert(panel.scroll:GetVerticalScroll()==detailOffset,'width changes preserve reading position when still scrollable')
panel:SetWidth(320)
panel:Render(model(nil))
assert(panel.reader.quest==nil and not panel.toolbar:IsShown(),'return to list clears reader and detail navigation')
assert(not panel.paper:IsShown() and not reward:IsShown(),'return to list hides parchment and reward cards')
assert(panel.scroll:GetVerticalScroll()==listOffset,'return restores list reading position')
assert(panel.pools.blocks[1].text.font=='GameFontHighlight','pooled list notices do not inherit parchment font')
local additional={id=99,name='Catalogue quest',summary='Catalogue summary',objectives={{text='Catalogue goal'}},description='Known catalogue description'}
local oldNavigation=NS.Navigation
local navigated
NS.Navigation={List=function(record)
    return {{key='ForeverDungeonJournal',label='DungeonJournal'},{key='ForeverGuide',label='ForeverGuide'},{key='AzerothCompendium',label='AzerothCompendium'}}
end,Open=function(key,record) navigated={key,record.id} end}
NS.Navigation.Cancel=function() end
panel:Render(model(additional))
assert(panel.reader.quest==additional,'source-only record also reaches reader')
assert(not panel.watch:IsShown(),'source-only records do not offer native tracking')
for _,row in ipairs(panel.pools.rewards) do assert(not row:IsShown(),'unknown rewards are not fabricated') end
local knownDescription=false
for _,block in ipairs(panel.pools.blocks) do
    if block:IsShown() and block.text:GetText()=='Known catalogue description' then knownDescription=true end
end
assert(knownDescription,'known source-only text is not discarded')
assert(panel.pools.navigation and panel.pools.navigation[3]:IsShown(),'additional details expose all available provider actions')
local firstAction=panel.pools.navigation[1]
assert(not panel.rewardSurface:IsShown(),'without rewards navigation retains light parchment')
for _,block in ipairs(panel.pools.blocks) do
    if block:IsShown() and block.text:GetText()=='Known catalogue description' then
        assert(firstAction.points[1][3]<block.points[1][3]-block:GetHeight(),'without rewards provider actions follow the description')
    end
end
panel.pools.navigation[2].scripts.OnClick()
assert(navigated[1]=='ForeverGuide' and navigated[2]==99,'provider button opens the currently displayed record')
local second={id=100,name='Other catalogue quest',objectives={}}
panel:Render(model(second)); panel.pools.navigation[2].scripts.OnClick()
assert(navigated[2]==100,'reused provider button must not retain the previous quest')
panel:SetWidth(180); panel:Render(model(second))
for _,button in ipairs(panel.pools.navigation) do assert(button:GetWidth()<=panel.contentWidth-20,'provider buttons fit narrow content') end
panel:SetWidth(320)
panel:Render(model(active))
assert(panel.pools.navigation[3]:IsShown(),'active quest exposes available provider actions')
local action=panel.pools.navigation[1]
local lastValue=panel.pools.values[panel.pools.values.used]
assert(action.points[1][3]<lastValue.points[1][3]-lastValue:GetHeight(),'provider actions follow XP and money')
local lastAction=panel.pools.navigation[3]
assert(panel.rewardSurface.points[1][3]-panel.rewardSurface:GetHeight()<=lastAction.points[1][3]-lastAction:GetHeight(),'dark reward background extends beneath every provider button')
panel.pools.navigation[3].scripts.OnClick()
assert(navigated[1]=='AzerothCompendium' and navigated[2]==42,'active navigation targets the active displayed quest')
panel:Render(model(additional))
assert(not panel.rewardSurface:IsShown(),'switching from rewarded quest restores light navigation background')
panel:Render(model(active))
NS.Navigation=oldNavigation
panel.scroll.scripts.OnMouseWheel(panel.scroll,-3)
assert(panel.scroll:GetVerticalScroll()>0,'clamp fixture starts scrolled down')
local short={id=42,name='A real quest',inLog=true,summary='Short known text',objectives={}}
root:SetHeight(2000); panel:SetHeight(2000); panel:Render(model(short))
assert(panel.scroll:GetVerticalScroll()==0,'shorter same-quest data clamps stale reading position')
local tail=panel.paper.strips[#panel.paper.strips]
assert(tail.points[1][3]-tail:GetHeight()<=-panel.paper:GetHeight(),'interior parchment tiles cover a tall viewport completely')
for index=2,#panel.paper.strips do
    local strip=panel.paper.strips[index]
    assert(math.abs(strip:GetHeight()-64)<0.001,'extension uses only native interior bands, never another composite header')
end
panel.back.scripts.OnClick(); assert(backed,'Back retains navigation callback')
NS.Reader=oldReader
print('PASS: native detail transitions, honest known text, reader identity and reward identity')
