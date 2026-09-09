# Instructions for AI agents

Read `docs/GUIDE.md` before any change. It explains how the game reads each kind of text, where each text is
edited under `translation/`, the build chain and the known pitfalls.

Build: `sh tools/build_all.sh <name>` rebuilds everything (about 10 minutes). When only `translation/scene*.tsv`
changed, use the fast path `sh tools/build_text.sh <name>` (seconds). Output goes to `builds/<name>.gb` and `.ips`.

Fixed rules:

- Never modify `rom/DB.gb`. The ROM is not in the repo; the user provides it.
- Perl only, no Python. Run every script from the repo root.
- Run `perl tools/checktsv.pl translation/scene*.tsv` before building.
- Mark a box `!18` (wide) only when the Japanese original has a line longer than 14 columns.
- Pages must not exceed 3 lines (`reloc.pl` splits them automatically).
- Preserve the dictionary size when recompressing a resource.
- Every new build gets a copy of `builds/teste.sav` with the same name as the ROM (the build scripts do this).
  Update `teste.sav` when the user says they progressed on another build's save.
