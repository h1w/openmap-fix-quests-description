local _, NS = ...
local GUIDE = "OpenMapQuestFixGuideData"
local guideAttempted = false
local function loaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return fn and fn(name)
end

function NS.GetQuestProvider(name)
    if not loaded(name) then return end
    local getter = C_AddOns and C_AddOns.GetAddOnLocalTable
    if getter then
        local table = getter(name)
        if type(table) == "table" then return table end
    end
    if name == "ForeverDungeonJournal" then return _G.ForeverDungeonJournal_NS end
    if name == "AzerothCompendium" then
        if type(_G.AzerothCompendium) == "table" then return _G.AzerothCompendium end
        local registry = _G.D4SharedSettingsRegistry
        for _, entry in ipairs(registry and registry.entries or {}) do
            local owner = entry.owner
            if type(owner) == "table" and owner.QUESTS and owner.INSTANCES and owner.GetAddonMeta then
                local title = owner:GetAddonMeta("Title")
                if type(title) == "string" and title:find("AzerothCompendium", 1, true) then return owner end
            end
        end
    elseif name == "ForeverGuide" then
        if not _G.OpenMapQuestFixGuideData and not guideAttempted then
            guideAttempted = true
            local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
            if load then
                local ok, reason = load(GUIDE)
                if not ok and NS.Print then
                    NS.Print((GetLocale() == "ruRU" and "Каталог ForeverGuide не загружен: "
                        or "ForeverGuide catalogue could not be loaded: ") .. tostring(reason))
                end
            end
        end
        return _G.OpenMapQuestFixGuideData
    end
end

function NS.ResetQuestProviders()
    guideAttempted = false
end
