# Dragon Ball Z: Goku Gekitouden (Game Boy), English translation

Fan translation (Japanese to English) of *Dragon Ball Z: Goku Gekitouden* (Bandai, 1995, Game Boy).
**Experimental: the game is playable start to finish, but there may still be bugs.** Reports are welcome.

## Playing it

1. You need your own copy of the original Japanese game. No game data is included or distributed here.
2. Apply [`patch/DBZ-english-v0.3.ips`](patch/DBZ-english-v0.3.ips) to it with Lunar IPS, Floating IPS or any IPS tool.
3. The patched game is expanded to 1 MB (MBC5). That is expected: every story scene got its own bank, so the text no longer has to be abbreviated. Existing saves keep working.

## What is translated

- All 19 story scenes (about 1,165 dialogue boxes), with a new upper and lowercase font and punctuation.
- Menus, file select, map destinations, password screen, party names, status screen and its glossary,
  battle messages and end-of-battle results, the Ginyu battle script, the intro narration,
  the training screen (text and graphic labels) and the title screen subtitle.

## Building from source

Requirements: Perl 5 and a POSIX shell (Git Bash on Windows works). No other dependencies.

```bash
sh tools/build_all.sh DBZ-english-v14 /path/to/your/original/game/file
```

This produces `builds/DBZ-english-v14.gb` and `.ips`. The chain starts from `builds/base.gb`, which the script
creates from your original file plus `tools/data/base.ips` (the raw 1:1 text pass everything else builds on).
When only the scene text in `translation/scene*.tsv` changed, `sh tools/build_text.sh <name> <original file>` rebuilds in seconds.

## Repository layout

| folder | content |
|---|---|
| `translation/` | the translation itself: `scene*.tsv` (story scenes), `fixed.tsv` (menus, map, password), `intro.txt`, `glossary.txt`, `names.tsv` |
| `tools/` | Perl tools: build chain, scene relocation, resource compression, font, IPS make and apply, disassembler |
| `docs/` | `GUIDE.md` (how the game reads each kind of text and how to edit it), `CHANGELOG.md` |
| `dumps/` | Japanese script dumps and the character table used for extraction |
| `patch/` | released IPS patches |
| `builds/` | build output, git-ignored |

Start with [`docs/GUIDE.md`](docs/GUIDE.md) if you want to change anything: text encoding, scene relocation to new banks,
the shared system-text block, LZ resources with dictionary constraints, fixed-width fields and the known pitfalls.

## Credits

Translation and tooling by thiagotsda with Claude (Anthropic). Dragon Ball Z is a trademark of Bird Studio / Shueisha,
Fuji TV and Toei Animation; the game is a Bandai product (1995). This is a non-commercial fan project.
