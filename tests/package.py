"""Verify the installable ZIP independently of installed game addons."""
import argparse
import re
from pathlib import Path
from zipfile import ZipFile

parser = argparse.ArgumentParser()
parser.add_argument("--tag")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
folders = ("OpenMapQuestFix", "OpenMapQuestFixGuideData")
versions = []
expected = {}
for folder in folders:
    directory = root / folder
    toc = directory / f"{folder}.toc"
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc.read_text(), re.MULTILINE)
    assert match, f"Missing semantic version: {toc}"
    versions.append(match[1])
    for path in directory.iterdir():
        if path.suffix in {".lua", ".toc"}:
            expected[f"{folder}/{path.name}"] = path.read_bytes()
assert len(set(versions)) == 1, "Addon and optional data module versions differ"
version = versions[0]
if args.tag:
    assert args.tag == f"v{version}", f"Tag {args.tag!r} does not match v{version}"
archive = root / "dist" / f"OpenMapQuestFix-{version}.zip"
with ZipFile(archive) as zip_file:
    names = zip_file.namelist()
    assert len(names) == len(set(names)), "Duplicate archive members"
    assert set(names) == set(expected), "ZIP must contain only owned runtime files in both addon folders"
    assert zip_file.testzip() is None, "ZIP CRC failure"
    for name, content in expected.items():
        assert zip_file.read(name) == content, f"Stale archive member: {name}"
print(f"PASS: OpenMapQuestFix-{version}.zip; {len(expected)} owned runtime files, versions and CRC verified")
