"""Read installed optional data without copying or changing provider files."""
import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument("--addons", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('GetLocale=function() return "enUS" end; UnitFactionGroup=function() return "Alliance" end; UnitClass=function() return "Druid","DRUID",11 end; UnitRace=function() return "Night Elf","NightElf",4 end; C_QuestLog={GetTitleForQuestID=function() end}; NS={}; tinsert=table.insert; tremove=table.remove')
load = lua.eval('function(code,name,ns) local f,e=loadstring(code,name); assert(f,e); return f(name,ns) end')
guide = lua.table()
manifest = root / "OpenMapQuestFixGuideData/OpenMapQuestFixGuideData.toc"
for line in manifest.read_text().splitlines():
    if line.startswith("..\\"):
        path = args.addons / line[3:].replace("\\", "/")
        load(path.read_text(encoding="utf-8-sig"), str(path), guide)
assert guide.DQ[96800].n == "Past Due"
assert guide.DQ[95799].n == "Findings for the Explorer's League"
assert all(isinstance(qid, (int, float)) for _, d in guide.DUNGEONS.items() for _, qid in (d.q or lua.table()).items()), "unresolved guide dungeon IDs"
compendium = lua.table()
for part in ("instances", "quests", "raid_quests"):
    path = args.addons / "AzerothCompendium/data" / (part + ".lua")
    load(path.read_text(encoding="utf-8-sig"), str(path), compendium)
path = args.addons / "AzerothCompendium/data/instance_wings.lua"
load(path.read_text(encoding="utf-8-sig"), str(path), compendium)
journal = lua.table(Constants=lua.table(ALBA_FAIRMOON_LOCATION="Alba Fairmoon"))
path = args.addons / "ForeverDungeonJournal/Data/Dungeons.lua"
load(path.read_text(encoding="utf-8-sig"), str(path), journal)
providers = lua.table(AzerothCompendium=compendium, ForeverDungeonJournal=journal, ForeverGuide=guide)
lua.globals().providers = providers
load((root / "OpenMapQuestFix/Sources.lua").read_text(encoding="utf-8-sig"), "Sources", lua.globals().NS)
lua.execute('''
local source=NS.Sources.New(function(name) return providers[name] end)
local list=source:List({189,"Scarlet Monastery - Graveyard"})
assert(list[1050] and list[1053] and list[96800], "whole monastery catalogue")
assert(list[1050].sources.AzerothCompendium and list[1050].sources.ForeverDungeonJournal and list[1050].sources.ForeverGuide, "all three providers contribute")
local onlyGuide=NS.Sources.New(function(name) if name=="ForeverGuide" then return providers[name] end end)
local g=onlyGuide:List({2970,"The Drowned City"})
assert(g[95799], "updated guide-only follow-up is imported")
''')
print("PASS: installed guide data-only loader; three provider monastery union; updated Drowned City guide quest")
