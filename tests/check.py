"""Compile addon with Lua 5.1 and run isolated behavior scenarios."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
for scenario in sorted((root / "tests").glob("*.lua")):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('NS = {}; GetLocale = function() return "enUS" end')
    load = lua.eval('function(code,name) local f,e=loadstring(code,name); assert(f,e); return f("OpenMapQuestFix",NS) end')
    for directory in ("OpenMapQuestFix", "OpenMapQuestFixGuideData"):
        for path in (root / directory).glob("*.lua"):
            lua.eval('function(code,name) assert(loadstring(code,name)) end')(path.read_text(encoding="utf-8-sig"), str(path))
    for name in ("Locale", "Providers", "Sources", "Data", "Reader", "Navigation", "Panel", "Host"):
        path = root / "OpenMapQuestFix" / (name + ".lua")
        if path.exists():
            load(path.read_text(encoding="utf-8-sig"), str(path))
    load(scenario.read_text(encoding="utf-8-sig"), str(scenario))
print("PASS: Lua 5.1 syntax and quest regression scenarios")
