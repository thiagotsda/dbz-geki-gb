# Instructions for AI agents

Read `docs/GUIDE.md` before any change. It explains how the game reads each kind of text, where each text is
edited under `translation/`, the build chain and the known pitfalls.

Build: `sh tools/build_all.sh <name> <original game file>` rebuilds everything (about 10 minutes). When only `translation/scene*.tsv`
changed, use the fast path `sh tools/build_text.sh <name> <original game file>` (seconds). Output goes to `builds/<name>.gb` and `.ips`.

Fixed rules:

- Never modify the original game file. It is not part of the repository: the build scripts take its path as their second argument (or the ORIGINAL_ROM variable), and no ROM, hash or ROM file name may appear in the repository texts.
- Perl only, no Python. Run every script from the repo root.
- Run `perl tools/checktsv.pl translation/scene*.tsv` before building.
- Mark a box `!18` (wide) only when the Japanese original has a line longer than 14 columns.
- Pages must not exceed 3 lines (`reloc.pl` splits them automatically).
- Preserve the dictionary size when recompressing a resource.
- Every new build gets a copy of `builds/teste.sav` with the same name as the ROM (the build scripts do this).
  Update `teste.sav` when the user says they progressed on another build's save.
