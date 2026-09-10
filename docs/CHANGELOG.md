# Changelog

Condensed from the work log of the JP to EN translation of Dragon Ball Z: Goku Gekitouden (Game Boy).
Newest build first. The tool chain is `sh tools/build_all.sh <name> <original game file>` (full chain from the
original ROM plus `tools/data/base.ips`) and `sh tools/build_text.sh <name> <original game file>` (fast path when
only `translation/scene*.tsv` changed). The original game file is not part of the repository; the scripts take
its path from the second argument or from the environment variable `ORIGINAL_ROM`.

## v13 (2026-09-08, night), released as v0.2

- Fixed garbage text in the Dodoria battle and the blank screen plus freeze at the end of the Zarbon battle.
  Global text ids (>= C0) belong to scenes 0 and 1 but are read from the current scene's bank; `reloc.pl` now
  writes the scene 0/1 text as a shared block at `$4000..$4DB8` in every new bank, and scenes 9 and 19 to 25
  point to banks that carry the block.
- Fixed leftovers on the box borders: pages with more than 3 lines were scrolling. `reloc.pl` now rewraps the
  text word by word and paginates with dynamic programming (about 390 boxes, cuts prefer sentence ends).
  The Yes/No boxes of scene 1 were reduced to 3 lines.
- Fixed text overflowing horizontally: 12 boxes marked `!18` whose Japanese never exceeds 14 columns
  (scene 1 ids 1F/23/24, 10 AC, 11 41, 13 22, 15 0A/0E/13, 16 29, 18 1B/1D) were rewritten at 14 columns.
- Map destination menu: "Tsuno" and "Moori" are villages. Their 3-name groups were copied to the free space
  of bank 00 (`$00A1` and `$00CF`) as "Tsuno village" / "Moori village" and the pointers repointed
  (`translation/fixed.tsv`).
- Title screen: the katakana band under the logo (resource 12, rows 5 and 6 of the resource 13 map) is replaced
  by "GOKU GEKITOUDEN" with the 3x5 copyright font (`tools/patch_title.pl`, preview by `tools/title_render.pl`);
  the kanji line was removed at the user's request.

## v12

- Status header "GOKOU" became "GOKU". The header tiles come from resource 4 of bank 06 (mode 0x80, 35 tiles
  loaded at `$8A00`); `tools/patch_gokou.pl` redraws the 32x8 band of tiles B6 to B9, transposes it back and
  recompresses (422/448 bytes, dictionary 65 instead of 64, harmless).
- The `$106D` post-processor was confirmed to be a 4x4 transposition of 2-bit fields; bank 08 resources
  (portraits, face icons) skip it because `$16AB` xors the id with `$C0`.
- `builds/teste.sav` updated from the v11 save.

## v11

- Fixed the broken end-of-battle screen introduced in v7. The status screen uses a pointer table built at run
  time, but the end-of-battle code reads strings 26 to 29 of resource 20 at fixed buffer offsets
  (280, 291, 296, 299), so shortening the glossary strings had shifted everything.
- `tools/build_intro_glossary.pl` now keeps every resource 20 string at exactly its original size, padding with
  spaces before a final `<FB>`; the limits are listed in `translation/glossary.txt`.

## v9 / v10

- Training screen graphic labels centred. `tools/build_training_labels.pl` searches pairs (x position, 1 or 2 px
  spacing) and measures the deviation in half pixels from the centre of the 32 px band, so odd widths (ARM)
  also centre. Result: shadow only below, total deviation 1 px over 12 labels, within the 16 new value budget.
- Translation declared complete (scenes, system text, menus, map, password, intro, glossary, Ginyu battle,
  training screen). v10 was the reference build.

## v8

- Character select box: names come from `0x12772` (bank 04), 5 entries of 8 bytes (4 dakuten tiles above
  4 name tiles). The box ends at the screen edge, so names are limited to 4 letters (Kril, Gohn, Vege, Goku, Picc).
- Status header "N days": the digit drawn at `$982F` was moved to `$982C` (byte `0x11F6F`) so the label reads
  "6 days" / "12 days".
- End of battle: strings 27/28/29 of resource 20 are concatenated on one line with the attribute name; rewritten
  as "<N> team " / "<N> " + attribute + "|up <#> pts!", attribute 1 renamed "Level" to fit 18 columns.

## v7

- Complete retranslation with relocation. `tools/reloc.pl` moves each scene's text to its own zeroed bank
  (`0x22 + scene`, text from `$4000`), rewrites the pointer lists in bank 0x21 and the bank table at `$18F2`.
  16 KB per scene; the largest (11) uses 7.5 KB. The ROM stays 1 MB MBC5.
- 1,165 boxes across 19 scenes, including scenes 7 and 13 which no earlier patch had translated
  (`translation/scene*.tsv`, checked by `tools/checktsv.pl`).
- New font (`tools/font.pl`): 26 lowercase, 26 uppercase and `, . ? ! '` in bank 0x3F, loaded by the routine at
  `$0061..$00A0` into tiles 01 to 34 and 7B to 7F. Any leftover kana in 1B..34 shows up as capitals.
- Ginyu Force battle script (resource 21, 44 boxes, exact size, width 18), map places, password, menus and file
  screen via `tools/fixed.pl` from `translation/fixed.tsv`.
- Intro narration (resource 18, 65 lines of at most 17 columns) from `translation/intro.txt` and status
  glossary plus end of battle (resource 20) from `translation/glossary.txt`, both via `tools/build_intro_glossary.pl`.
- Name table with uppercase via `tools/names.pl` from `translation/names.tsv`.
- Game placeholders kept as "No message." / "Event not finished." (scenes 4 and 11).

## v5 / v6

- Intermediate builds of the relocation work, superseded by v7 (not detailed in the log).

## v4

- Training screen text labels revised (`tools/build_training_text.pl`): `_` maps to tile `$88` (frame
  background) and erases kana leftovers and orphan dakuten marks. Meanings confirmed from the Japanese tilemap:
  part, level, rest, totl, status, "N days / left", "senzu N", fatigue, G up.
- Two digits moved to another column via `tools/patch_training.pl` (table `$5ACE` of bank 04).
- `tools/build_all.sh` created: rebuilds the whole chain and copies the latest test `.sav`.

## v3

- Training screen graphic labels (resource 14) redrawn with an internal font by `tools/build_training_labels.pl`
  (`tools/show_tiles.pl` dumps the tiles). Routine `$5976` (bank 04) picks the first tile: body parts `$B0+4v`,
  intensity `$C8+4v`, speed `$D4+8v`.
- Constraint found: the resource 14 dictionary cannot exceed 214 values because the output ends at `$D2AE`
  and `$D2B0` is already a game variable; at most 16 new tile values could be added (15 were used).

## v2

- Resources 20 (glossary and end of battle), 18 (intro narration) and 15 (training tilemap) reinserted for good.
  Earlier attempts froze the battle: the decompressor writes the dictionary at `$C4C8` and the output right after
  it, and the end-of-battle code builds a 60 byte pointer table at `$C4C8`. The translated dictionary was smaller
  than the original 84 bytes, so the table overwrote the first strings. Fix: pad the dictionary to the original
  size (zero cost in bytes).
- Resource 18: the first 3 output bytes (`02 01 08`) are a header, not text; the text starts at offset 3.
- The intro loads its font at `$8000` while the font hook always wrote at `$9010`; `tools/patch_font_opening.pl`
  makes the routine write at `HL+$10`.

## Starting point (before v2)

- 1:1 text pass kept as `tools/data/base.ips`: character table, control codes (FD line break, FE end of box,
  FB page, E2 number, E3 name), lowercase font hooked at the five `$072A` call sites, ROM expanded to 1 MB
  (MBC5), about 1,930 dialogue lines translated at exact byte length, resource 21 translated in place.
- LZ format of `$0FDF` fully reverse engineered (2 byte output size, 32 byte dictionary bitmap, literal if
  byte < dictionary size, else match of length byte-ds+1 with distance next byte+1), with an optimal parse
  compressor validated by round trip against the original data.

## Key discoveries

- When recompressing a resource the dictionary size must be preserved (pad it to the original count): the
  decompressor puts the output right after the dictionary in RAM and other code depends on that address.
- Resource 18 (intro narration) has a 3 byte header before the text.
- Bank 03 is mirrored in bank 0x21 (offset +0x78000); the game reads the copy, so any signature must be
  searched in the whole ROM and written to every copy.
- Global text ids >= C0 are read from the current scene's bank, so scenes 0 and 1 form a shared block
  replicated at `$4000` in every scene bank.
- A box shows 3 lines and scrolls on the 4th; pages are limited to 3 lines (`reloc.pl` splits them).
- `!18` (wide box, no portrait) only when the Japanese line exceeds 14 columns; otherwise 14 columns.
- End-of-battle strings (26 to 29 of resource 20) are read at fixed buffer offsets; every string of resource 20
  must keep its original size, only the total (315) and dictionary (84) are otherwise constrained.
- Resource 21 is the Ginyu Force battle script: raw, not compressed, pointer list in the first 176 bytes
  copied to `$C4C8`; boxes must stay in place with exact size and width 18.
- Some bank 00 place names start with `FD xx yy` code pointers; the text begins after them.
- Scenes 19 to 25 are empty or duplicated in the master table and unused.
- `$072A` is the 1bpp to 2bpp font expander and `$070E` the 1:1 graphics copy: font hooks go only on `$072A`
  sites, both `call` and `jp` forms. Glyphs go to `$9010` (BG), never `$8010` (sprites).
- Uppercase must not be stamped over 0x1B..0x34 without translating everything: those are kana tiles.
- Translate per box, not per line, and always at exact byte length; a checker aborts the batch on overflow.
- When static checks pass but the game still fails, ask for a run-time observation (BGB, PC and HL at the
  freeze) instead of iterating blindly.

## Release numbering

Internal build numbers (v2 ... v13) are the ones used in this log and in the build scripts. Public releases
on GitHub use their own numbering: v0.2 = build v13.
