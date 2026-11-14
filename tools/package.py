"""Package only addon-owned runtime files, never installed game/provider data."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
addon = root / "OpenMapQuestFix"
version = next(line.split(":", 1)[1].strip() for line in (addon / "OpenMapQuestFix.toc").read_text().splitlines() if line.startswith("## Version:"))
out = root / "dist" / f"OpenMapQuestFix-{version}.zip"
out.parent.mkdir(exist_ok=True)
with ZipFile(out, "w", ZIP_DEFLATED) as archive:
    for folder in (addon, root / "OpenMapQuestFixGuideData"):
        for path in sorted(folder.iterdir()):
            if path.suffix in {".toc", ".lua"}:
                info = ZipInfo(path.relative_to(root).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = ZIP_DEFLATED
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                archive.writestr(info, path.read_bytes())
print(out)
