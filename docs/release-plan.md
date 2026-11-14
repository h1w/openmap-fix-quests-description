# Release automation

User authorized pushing all implemented work to main and publishing an installable ZIP. Existing feature branch fix/dungeon-quest-panel contains the complete uncommitted implementation; remote main is initial commit1a0b24bfe9ee02d79d6c6b6bb22debaa939437a3. Preserve existing runtime behavior.

1. Add .github/workflows/check.yml: push/PR Lua5.1 scenarios, uv locked Python3.12 install, package both owned addon folders, validate archive, upload artifact. Tag v* uses same checks, requires exact matching TOC versions, then release job requires tag commit on origin/main. Only release job gets contents:write. No installed third-party data required in hosted CI.
2. tests/package.py validates version agreement, optional release tag, exact archive runtime membership/bytes/CRC and filenames, excluding all upstream assets. Documentation explains tag-driven publishing and artifact download.
3. Run locked checks/package validator/actionlint locally once, commit source and automation, fast-forward remote main without force. Push annotated v0.1.5 after main CI succeeds. Wait for GitHub Actions completion and inspect/download release ZIP; verify members, CRC and own byte identity. Retry job publication idempotently without overwriting divergent published asset. No production systems involved.
