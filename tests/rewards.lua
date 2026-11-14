-- Consumer-visible regression: queried quest cache has two choices, accepted
-- log entry has four; unrelated selected quest must never supply rewards.
local selected, fail = 999, false
C_QuestLog={GetSelectedQuest=function() return selected end,SetSelectedQuest=function(id) selected=id end}
GetNumQuestLogChoices=function(id) assert(id==1053); return 2 end
local ids={6829,6830,6831,11262}
GetQuestLogChoiceInfo=function(index,id)
    if id then return 'Filtered '..index,1,1,3,true,ids[index+2] end
    assert(selected==1053,'native lookup must target displayed quest')
    if fail and index==2 then error('item query failed') end
    local itemID=ids[index]
    if not itemID then return end
    -- First two names have not entered the client cache yet.
    return index>2 and ('Item '..itemID) or nil,nil,1,3,true,itemID
end
GetQuestLogItemLink=function(kind,index,id)
    assert(kind=='choice' and selected==1053 and id==nil,'links use matching native slot context')
    return 'item:'..ids[index]
end
GetItemInfo=function(id) return 'Cached '..id,'item:'..id,3,nil,nil,nil,nil,nil,nil,1000+id end
GetQuestLogQuestText=function() return 'Description','Summary' end
GetNumQuestLogRewards=function() return 0 end
GetQuestLogRewardMoney=function() return 100 end
GetQuestLogRewardXP=function() return 200 end
local data=NS.Data.New({}, {})
function data:IsActive() return true end
function data:LogIndex() return 7 end
function data:Record(id) return {id=id,inLog=true,rewards={}} end
local record=data:Details(1053)
assert(#record.rewards==4,'all four live choices survive a filtered two-item quest query')
for i,id in ipairs(ids) do
    local r=record.rewards[i]
    assert(r.itemID==id and r.link=='item:'..id and r.choice,'native item identity and order retained')
    assert(r.name and r.texture,'uncached native names resolve from matching item ID')
end
assert(selected==999,'original native selection restored after reading rewards')
fail=true
local ok=pcall(data.Details,data,1053)
assert(not ok and selected==999,'query error must restore original selection before propagating')
fail=false
GetItemInfo=function() end
record=data:Details(1053)
assert(#record.rewards==4 and record.rewards[1].itemID==6829,'unloaded item text must not remove reward slots')
selected=1053
local originalQuery=GetQuestLogChoiceInfo
GetQuestLogChoiceInfo=function() selected=999; error('callback changes selection before failing') end
assert(not pcall(data.Details,data,1053) and selected==1053,'restore even when the requested quest was initially selected')
GetQuestLogChoiceInfo=originalQuery
print('PASS: complete accepted reward choices, cached identity and selection restoration')
