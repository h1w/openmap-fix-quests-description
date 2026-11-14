# Single-addon experiment — rejected

Native verification on 2026-11-14: importing installed ForeverGuide data directly from the main TOC succeeds when all files exist. Referencing an absent provider generates eleven native file-loading warnings and DoesAddOnHaveLoadError returns true before our Lua can intervene. The client exposes no runtime file loader; ForeverGuide does not opt into namespace access.

Offered tradeoff: one-folder installation with a manifest-generating external installer, or keep the separate optional bridge. User explicitly chose keep_bridge. Restored repository and installed runtime to 0.1.4, retained OpenMapQuestFixGuideData, removed experimental wrappers. No one-folder release or installer is shipped; no foreign files were changed.
