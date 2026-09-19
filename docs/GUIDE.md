# Agent guide: Dragon Ball Z (Game Boy) JP to EN translation

Consolidated reference document (2026-09-08). If you are an agent (or a person) picking up this
project, read this whole file before touching anything. The history of how the project got here is
condensed in `docs/CHANGELOG.md`; this guide is the authoritative reference.

Golden rules:

1. **Never modify the original game file; it is not part of the repository.** Everything is
   generated from it. The chain base, `builds/base.gb` (raw 1:1 translated text, 1 MB, MBC5), is
   created by `build_all.sh` from the original ROM + `tools/data/base.ips`.
2. **Run everything from the repository root.** The scripts do not read a fixed path: the original
   game file is given by the environment variable `ORIGINAL_ROM` or as the second argument of the
   build scripts (`sh tools/build_all.sh <name> <original game file>`).
3. **Perl only.** There is no Python on the machine. Verification images: generate a BMP in Perl and
   convert it to PNG with PowerShell (`System.Drawing`), as the scripts do.
4. **Every new build gets a copy of `builds/teste.sav`** with the same name (`build_all.sh` does this).
   If the user says they progressed in some save, update `teste.sav` from that `.sav` first.
5. **Check widths before building:** `perl tools/checktsv.pl translation/scene*.tsv`.

---

## 1. Folders and build

```
builds/         deliverables: DBZ-english-vN.gb + .sav; teste.sav = canonical test save;
                base.gb = chain base (generated); pre-reloc.gb = everything except the scenes
translation/    ALL EDITABLE TEXT (see section 3)
tools/          Perl scripts (see section 4); tools/data/ = base.ips, training-text.txt
dumps/          Japanese dumps and listings (scenes-jp.tsv = every JP text box with its ids)
patch/          released IPS patch + README.md
docs/           this guide, CHANGELOG.md (preview images are generated locally and never committed: they contain original game graphics)
```

Full chain (`sh tools/build_all.sh DBZ-english-vN <original game file>`), in order:

| step | script | input | what it does |
|---|---|---|---|
| 1 | `build_training_text.pl … 15` | `tools/data/training-text.txt` | training screen tilemap (resource 15) |
| 2 | `build_intro_glossary.pl` | `translation/intro.txt`, `translation/glossary.txt` | opening (res. 18) and glossary/end of battle (res. 20) |
| 3 | `patch_font_opening.pl` | none | HL-relative font routine (required before font.pl) |
| 4 | `build_training_labels.pl` | font built into the script | graphic training labels (res. 14) |
| 5 | `patch_training.pl` | none | digit columns of the training screen (table `$5ACE`) |
| 6 | `font.pl` | none | font with uppercase and punctuation in bank 0x3F + routine `$0061` |
| 7 | `names.pl` | `translation/names.tsv` | name table (bank 03 + mirror 0x21) |
| 8 | `fixed.pl` | `translation/fixed.tsv` | fixed fields: menus, map, password, Ginyu battle, header |
| 9 | `patch_gokou.pl` | none | "GOKOU" to "GOKU" in the status header (res. 4 of bank 06) |
| 10 | `patch_title.pl` | font built into the script | "GOKU GEKITOUDEN" band on the title screen (res. 12 of bank 06) |
| 11 | `reloc.pl` | `translation/scene*.tsv` | all story scenes in new banks |

`build_all.sh` takes about 10 minutes (the search in `build_training_labels.pl`) and leaves
`builds/pre-reloc.gb` (everything except the scenes). **If only the `translation/scene*.tsv` files
changed**, use the fast path (seconds): `sh tools/build_text.sh DBZ-english-vN <original game file>`
(checktsv + reloc + .sav + .ips starting from `pre-reloc.gb`). `perl tools/splitreport.pl translation/scene*.tsv` lists
the pages that `reloc.pl` split with a cut in the middle of a sentence (M) or as a 1-line page (O):
candidates for manual re-pagination.

Each script refuses a base whose slot was already altered (it cannot be applied twice) and
recomputes the global checksum. Order matters: `font.pl` requires the routine from
`patch_font_opening.pl`.

---

## 2. How the game reads text (what you need to know to break nothing)

### 2.1 Encoding and font

- Original kana: `00` space, `01-7F` kana/digits/punctuation, `B0-E1` kana with dakuten/handakuten.
- **English (installed font):** `a-z = 01-1A`, `A-Z = 1B-34`, space `00`, `0-9 = 70-79`,
  `... = 7A` (a single tile), `, = 7B`, `. = 7C`, `? = 7D`, `! = 7E`, `' = 7F`, `- = 6F` (the long
  bar ー).
- Control codes: `FD` line break, `FE` end of box, `FB` pause/page (waits for a button and clears),
  `E3` inserts a name, `E2` inserts a number.
- 1bpp glyphs in bank `0x3F` (`$4000`, 456 bytes). The routine at `$0061-$00A0` (HOME) switches
  banks while keeping `$FFA5` consistent with the vblank and expands at `HL+$10` (tiles 01-34) and
  `HL+$7B0` (7B-7F). Five hooks at sites that used to call `$072A` (1bpp to 2bpp expander). The
  opening loads the font at `$8000` (routine `$7398`), the other screens at `$9000`; that is why the
  routine is HL-relative.
- **Consequence:** any leftover Japanese kana in `01-34` shows up as a Latin letter. There is no
  known Japanese text left apart from the pending items (section 6).

### 2.2 Story scenes (the bulk of the text)

- Master table at `$4000` of bank 03 (file offset `0xC000`): entry `scene+1` = address of the
  scene's pointer list; entry 0 = ids >= `0xC0` (aliases, not used by constants).
- **Loader `$0A65`** reads the list in bank **0x21** (a copy of bank 03; the 4 `ld a,3/rst 0`
  selectors in HOME were changed to 0x21). Scene index = `$C1BE`.
- **Reader `$1766`** (inside the vblank) reads the TEXT BYTES in bank `$18F2[scene]` and restores
  the bank afterwards. Only text is read from that bank, which is why each scene can live in a new
  bank.
- **Global ids (>= `0xC0`)**: they index the continuous list starting at entry 0 = the lists of
  scenes 0 and 1 (system messages: save, choose character, food, "events" in the middle of the
  Zarbon/Frieza/Ginyu battles, results). They are read with the bank of the **current scene**
  (`$18F2[$C1BE]`; the battle sets `$C1BE` = 2..8 according to the chapter in `$D602`). For this
  reason the text of scenes 0 and 1 plus the first 19 boxes of scene 2 (ids C0-FF cover 8 + 37 + 19
  boxes) is a **shared block** (about 3.9 KB) written at the SAME address (`$4000..`) in ALL new
  banks; each scene's own text comes after it. Without this: garbage text
  (Dodoria) or a blank box plus freeze (end of the Zarbon fight), the v12 bugs.
- `reloc.pl` puts scene `s` in bank `0x22+s`: shared block at `$4000`, then the scene text, and
  updates the list and `$18F2`. Scenes that are not relocated (9, 19-25) also get a bank with the
  block (the bank of the scene with the same list, otherwise 0x22). Capacity is 16 KB per scene; the
  largest uses about 11 KB.
- Real scenes: 0,1,4,17 (system/tutorials, formerly bank 05), 2,6,16,26 (formerly 1E), 3,8,10,11,12
  (formerly 03), 5 (formerly 06), 7 (formerly 0A), 13 (formerly 0D), 14 (formerly 01), 15 (formerly
  04), 18 (formerly 1D). Scene 9 = list in RAM (`$C4C8`, it is the battle script of resource 21).
  Scenes 19-25 are empty/duplicated, do not use them.
- **List length:** a list runs until the next list (or the text that follows it). Entries equal to
  `0000` are placeholders, not the end: scene 4 has 131 boxes (ids 52-54 are `0000`, ids 55-82 are the
  in-battle lines of Vegeta vs Zarbon and Gohan/Krillin vs Guldo) and scene 6 has 56 (id 0A is `0000`,
  ids 0B-37 are the Ginyu battle lines). The tools stop only at the first non-zero invalid pointer.
  Until v14 those 94 boxes were never relocated, so battles showed text of other boxes cut mid-way.
- **Width:** box with portrait = 14 columns (`$35E6`, `ld a,$0E`); narration/battle = 18 (`!18`
  prefix in the TSV). The box shows 3 lines and **scrolls** when the 4th arrives (`$187A`); scrolling
  leaves leftovers on the borders, so **every page has at most 3 lines**, and **wide boxes (`!18`) at most 2**: a 3rd wide line
  leaves its first 4 columns under the next portrait box, which clears only columns 5-18 ("hosp"
  residue in the hospital scene, v14). `!18/3` allows 3 lines only where the Japanese itself has
  3-line pages and no portrait box follows (scene 1 tutorials, scene 5 id 16, scene 18 id 1C). The original
  JP respects this, apart from very rare 4-line boxes that scroll in the original too. `reloc.pl`
  re-wraps, word by word, every chunk (between `<FB>`) that exceeds 3 lines, choosing lines and pages
  together by dynamic programming: it prefers closing a page at the end of a sentence
  (`. ! ? ...`), then at a comma, and avoids 1-line pages and short lines in the middle of a page.
  Chunks that already fit are kept exactly as written (choice boxes, manual pauses). `checktsv.pl`
  counts how many are re-wrapped. You can paginate by hand in the TSV when the automatic cut looks
  bad.
- **Only mark `!18` if some line of the original JP has more than 14 columns** (the width is decided
  by the code that opens the box, not by the text). Text of 15-18 columns in a 14-column box leaks
  through the border and is not cleared (v12 bug in 12 boxes; fixed in v13). Text <= 14 in a wide box
  is harmless.
- `<N>` counts as 6 columns and `<#>` as 3 in the checker.
- `perl tools/scenes.pl <rom>` lists every box (JP from the original ROM, read from `ORIGINAL_ROM`
  or given as an extra argument, EN from the given ROM); use it to verify a build. `dumps/scenes-jp.tsv` is the reference JP dump with the ids.

### 2.3 Compressed resources (bank 06, table at `$4000` = file offset `0x18000`)

- **Title screen** = resource 12 (116 logo tiles, ids `40..B3`, mode 0x80) + resource 13 (20x18
  map). `perl tools/title_render.pl [rom] [bmp]` composes the screen for checking; `patch_title.pl`
  erases the katakana band and the kanji (x 40..111, y 44..63), writes "GOKU GEKITOUDEN" with a 3x5
  font and recompresses (1094/1345 bytes, dictionary of 148 preserved). Pixels can only be drawn
  where the map has a logo tile (columns 3-13 in rows 5-6; the rest is tile 00, empty).

- Loader `$10DE`: `A & 3F` = index, `A & C0` = mode (`00` raw, `40` LZ, `80` LZ + `$106D`).
- LZ (`$0FDF`): `[outlen 2B][32-byte dictionary bitmap][stream]`; `byte < ds` = literal
  `dict[byte]`, otherwise `len=(byte-ds)+1`, next byte = `dist-1`. **The output lands at
  `$C4C8 + ds`** (the dictionary is written first). So the dictionary size changes the output
  address: **always pad the dictionary to the original size** (`comp_opt(..., target)`). Documented
  exception: res. 4 of bank 06 (`patch_gokou.pl`) uses 65 instead of 64, a harmless shift.
- Mode `80` (`$106D`): 4x4 transposition of 2-bit fields in each group of 4 bytes (an involution:
  pack = unpack). `unpack_res.pl` renders it. Beware: `$16AB` (used by the status screen for pieces
  from bank 08) does `xor $C0` on the id, so ids `8x` become mode `40` (plain 2bpp) and `4x` become
  `80`.
- **Resource 20** (glossary + end of battle, 315 B, dict 84, slot 262): the status screen builds a
  table of 30 pointers at `$C4C8` by searching for `FE` (`$3C12`), BUT the end of battle reads
  strings 26-29 by **fixed offset** (280/291/296/299). `build_intro_glossary.pl` keeps each string
  at exactly its original size (padding with spaces). The English has to repeat words to fit in
  262 B. Strings 27/28 are glued to the attribute name and to string 29 on the same line:
  `<N>'s ` + `Exp` + ` |up <#> points!`.
- **Resource 18** (opening, 998 B, dict 104, slot 860): 3 header bytes (`02 01 08`: column, flag,
  lines per page) + lines separated by `FD` + `FF`. Usable width 17, pages of 8 lines.
  `translation/intro.txt` = one line per line.
- **Resource 15** (20x27 tilemap of the training screen, slot 305): `tools/data/training-text.txt`
  (`offset size text`; `_` = tile `$88`, frame background; `~` preserves the byte). Rows 0-8 are off
  screen. Digits are drawn by code (table `$5ACE` of bank 04; `patch_training.pl` moved two of them).
- **Resource 14** (training graphics, 3344 B, dict 214, slot 2171): the labels ウデ/ムネ… are tiles
  with a shadow. `$5976` picks the tile: body parts `$B0+4v`, intensity `$C8+4v`, speed `$D4+8v`
  (2 rows). **The dictionary cannot exceed 214** (`$D2B0` is a game variable); the untouched tiles
  use 198 values, leaving 16 for the labels. `build_training_labels.pl` searches for
  position/spacing/shadow per label within that budget (chosen style: shadow below only, centered).
- **Resource 21** (Ginyu battle script, raw, 4437 B): pointer list in the first 176 bytes, copied to
  RAM. Boxes embedded in the bytecode, so **exact size**, width 18, edited through `fixed.tsv`
  (offsets `01AF6D…01B339`).
- **Resource 4 of bank 06** (35 tiles of the status header, ids A0-C2): the `EXP` tab (B0-B2) and
  `GOKOU` to `GOKU` (B6-B9). Header tilemap at `0x121A8` (3x20, copied to `$9800`).

### 2.4 Fixed fields (`translation/fixed.tsv`: `offset size text`, padded with `00`)

- Bank 04: options menu record list at `0x139F0` (relocated from `0x12543`, pointer at `0x124A0`): records of
  address (big-endian), width, height, tiles, ended by `00`, drawn by `$0BA1`. Option columns must match the
  cursor table at `0x12586` (per row: `y|count`, then up to three cursor x positions in pixels).
- Bank 02: GAME OVER tile record (`9C 65 09` + 9 tiles at `0xBFD0`, free tail of the bank; the original
  8-tile record at `0xAB34` is unused now, its `ld hl` at `0xAB21` was repointed). Records drawn by `$0BBE`
  have the form address (big-endian), length, tiles.
- Bank 02: the "who plays?" prompt (`0xBDB8`, 11 bytes + `FB`), embedded in the battle engine.
- Bank 00: the battle fighter choice (`0x2292`, 20 bytes `FD 00 00 name FD 00 00 name FE`, copied to RAM
  by `$0A9C` and shown as a two-option menu with a 2-column cursor margin; the trailing `FE` stays).
- Bank 00: map place names (`0x2124…0x21F5`, strings terminated by `FE`, table of 16-bit pointers at
  `0x20E6…0x2123`). Two groups are "3 names of the same village" with a `FD xx yy` prefix (before
  arriving / after the attack / village name: Tsuno and Moori). To fit "Tsuno village" and
  "Moori village" (13 columns, the JP maximum) those two groups were copied to the free space of
  bank 00 at `$00A1` and `$00CF` (right after the font routine) and the table pointers were
  repointed (`fixed.tsv`, entries `0000A1`/`0000CF`/`0020xx`). About 4 bytes are left there; `$0100`
  is the entry point. Password (`0x38F4/0x3909/0x3917`, format `9C 41 len text`).
- Bank 04: main menu (`0x12223…0x12273`, irregular fields), battle options (`0x12547…`, format
  `9C addr len 01 text`; options at fixed positions), files (`0x1230D`, 5 chars), selection box list
  (`0x12772`, 5 x [4 mark tiles + 4 name tiles], **max. 4 letters**, the box touches the border),
  "N days" header (`0x121C8`; digit drawn by `0x11F6E`, byte `0x11F6F` = column).
- Name table: `0xC041` (31 x 6 bytes, no terminator) + mirror `0x84041`: `names.tsv`.
- `<xx>` in the text writes a raw byte (used for the digit patch).

---

## 3. Where to edit each thing

| I want to change… | file | then |
|---|---|---|
| a story line | `translation/sceneS.tsv` (scene S, hex id; `\|` line break, `<FB>` page, `!18` wide) | `checktsv.pl`, then `build_all.sh` |
| menus, map, password, Ginyu battle, header | `translation/fixed.tsv` (respect the size) | `build_all.sh` |
| opening | `translation/intro.txt` (<= 17 columns, about 66 lines fit) | `build_all.sh` |
| glossary / end of battle | `translation/glossary.txt` (each string <= original size, listed in the file header) | `build_all.sh` |
| names (<= 6) | `translation/names.tsv` | `build_all.sh` |
| training text labels | `tools/data/training-text.txt` | `build_all.sh` |
| training graphic labels | `@body/@inten/@speed` lists and the font in `build_training_labels.pl` | `build_all.sh` |
| font letters/punctuation | `%F` in `font.pl` (7 rows, columns 1-5) | `build_all.sh` |

To see the Japanese of a box: `grep -P '^10\t3A\t' dumps/scenes-jp.tsv` (scene 10, id 3A).

---

## 4. Tools (`tools/`)

| script | use |
|---|---|
| `build_all.sh NAME ORIGINAL` | full chain, produces `builds/NAME.gb` + `.sav` + `.ips` |
| `build_text.sh NAME ORIGINAL` | fast path when only the scene TSVs changed (from `builds/pre-reloc.gb`) |
| `checktsv.pl [width] tsv…` | lines above the width (honors `!18`) |
| `splitreport.pl tsv…` | pages that `reloc.pl` split mid-sentence (M) or into 1-line pages (O) |
| `scenes.pl ROM [summary]` | lists/compares every scene box (JP vs EN) |
| `reloc.pl`, `fixed.pl`, `names.pl`, `build_intro_glossary.pl`, `build_training_text.pl`, `build_training_labels.pl`, `font.pl`, `patch_font_opening.pl`, `patch_training.pl`, `patch_gokou.pl`, `patch_title.pl` | chain steps (the header of each one explains its format) |
| `title_render.pl [rom] [bmp]` | composes the title screen (res. 12 + 13) for checking |
| `gbdis.pl ROM off len` | SM83 disassembler (file offsets; bank addresses computed) |
| `show_tiles.pl [res] [rom]` | 2bpp tiles of a bank 06 resource as ASCII |
| `unpack_res.pl bank idx [bmp]` | mode 0x80 resource (with transposition) as BMP |
| `pairs.pl ROM` | byte-by-byte diff original vs translated (slow; inventory only) |
| `mkips.pl`, `applyips.pl` | create / apply IPS patches (section 7) |

`ORIGINAL` is the path of the original game file; it can also be given through the environment
variable `ORIGINAL_ROM`. The standalone tools that need the original (`scenes.pl`, `pairs.pl`,
`show_tiles.pl`, `unpack_res.pl`, `title_render.pl`, `patch_gokou.pl`, `patch_title.pl`,
`build_training_text.pl`, `build_intro_glossary.pl`, `build_training_labels.pl`, `mkips.pl`,
`applyips.pl`) read `ORIGINAL_ROM` or take the path as an argument (see the header of each one).

The one-off exploration scripts from the first sessions were not kept in the repository.

Useful routines already mapped (HOME): `$06E2` memcpy · `$070E` 1:1 VRAM copy (graphics) ·
`$072A` 1bpp to 2bpp expander (font) · `$07C9` copies a BxC block to VRAM · `$0A65` box loader ·
`$0B43` numbers · `$0E75` opens a window (A = width) · `$0FDF` LZ · `$106D` transposition ·
`$10DE`/`$10E3` resource loader · `$16A5` assembles tiles from pieces · `$1766` text reader ·
`$3C12` glossary table · `rst 0` switches bank saving it in `$FFA6`, `rst 8` restores it.

---

## 5. Pitfalls that already cost time

- A `0000` entry inside a scene list is a placeholder, not the end of the list (section 2.2); stopping
  there hid 94 battle boxes until v14. The base image also overwrote the last 4 entries of the scene 4
  list (ids 7F-82, bank 03 `$6DE5`) with scene 3 text: `translation/fixed.tsv` restores them.
- Global ids (>= C0) read the text of scenes 0/1 in the bank of the current scene: any relocation
  must keep that block at the same address in every bank (section 2.2). The v12 bugs.
- `!18` only based on the JP (section 2.2); `fixed.pl` refuses to write over existing `FE/FF`, so
  new fields cannot overlap (`0000A1`+46 ends at `0000CE`).
- Preserve the dictionary size when recompressing (section 2.3). It was the cause of the battle
  freeze.
- Resource 18 has a 3-byte header (x column, scroll flag, frames per scrolled pixel; original `02 01 08`): never write text at offsets 0-2. The scroll speed is set with `# scroll-frames-per-pixel: N` in `translation/intro.txt`.
- Bank 03 has a mirror at 0x21: write to both (`names.pl` and `fixed.pl` do this for
  `0xC000-0xFFFF`).
- `rst $00` overwrites `$FFA6`; inside the font routine use `ld ($2100),a` + manual `$FFA5`.
- Font hooks only at `$072A` sites; at `$070E` the alphabet ends up in the scenery.
- Slurp in Perl: `my $d=do{local $/;<$f>};`. A loose `local $/` at file scope breaks the
  line-by-line reading of the TSVs (it happened).
- `local $/` must also not be active while reading text tables; and `sed -i` with `$` and quotes in
  Git Bash fails silently: prefer Perl scripts saved to a file.
- List pointers that do not reach an `FE` within 300 bytes are garbage (scenes 7 and 26 have one
  each); `reloc.pl` writes an empty box for them.
- The compressed glossary closes at exactly 262/262: any edit has to reuse words.
- "No message." / "Event not finished." are the game's own debug strings (scenes 4 and 11).
- In tournament mode (scene 2) the `<#>` code inserts a fighter name; estimated width 3.
- The katakana `ー` (6F) serves as the hyphen; a dedicated glyph would need one more free tile (7A
  is taken by the single-tile ellipsis).

---

## 6. Pending items

- Title screen: the katakana band "ドラゴンボール" under the logo became "GOKU GEKITOUDEN"
  (`patch_title.pl`, in v13) and the kanji title "悟空激闘伝" below it was erased at the user's
  request (pixels x 40..111, y 44..63; the new text sits at y 48..52).
- Selection box names limited to 4 letters (Kril, Gohn, Vege, Goku, Picc); widening them would
  require redrawing the box, which ends at the screen edge.
- In-game tests still pending in v13: events in the middle of the Zarbon/Frieza/Ginyu battles
  (shared block), hospital narration (pagination), "Tsuno village"/"Moori village" destinations.
- About 500 pages are split automatically by `reloc.pl`; review by hand the ones that ended up with
  a pause in the middle of a sentence (`checktsv.pl` counts them; the TSV keeps the original pages).

---

## 7. Distribution (IPS patch)

`perl tools/mkips.pl <original game file> builds/X.gb builds/X.ips` generates the patch (RLE
records for the repeated stretches; about 95 KB). `build_all.sh` already generates the `.ips`
together with the build. `perl tools/applyips.pl` applies an IPS to the original game file (to
verify: the result must be identical to the build, `cmp`). The IPS writes beyond the end of the
original and produces the 1 MB ROM. Text for people who download it: `patch/README.md`.
Independent verification with Lunar IPS (an external tool, command line):
`powershell -Command "& 'path\to\Lunar IPS.exe' -ApplyIPS 'builds\X.ips' '<copy of the original game file>'"`
and then `cmp` against the build. Done in v12: identical.
