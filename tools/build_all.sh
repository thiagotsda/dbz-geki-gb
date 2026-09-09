#!/bin/sh
# usage (from the repository root): sh tools/build_all.sh <name>   -> builds/<name>.gb + .sav
# Full chain starting from builds/base.gb (raw 1:1 text already translated).
set -e
[ -f rom/DB.gb ] || { echo "put the original Japanese ROM at rom/DB.gb (512 KB, SHA-1 1f7a08d2e51e90d770d9dbf4092166b2bfa5697e)"; exit 1; }
[ -f builds/base.gb ] || { mkdir -p builds; echo "creating builds/base.gb (base of the chain) = rom/DB.gb + tools/data/base.ips"; perl tools/applyips.pl rom/DB.gb tools/data/base.ips builds/base.gb; }
[ -f builds/teste.sav ] || { mkdir -p builds; cp rom/DB.sav builds/teste.sav 2>/dev/null || true; }
N=${1:?build name}; T=builds/.tmp
perl tools/build_training_text.pl builds/base.gb $T.1.gb 15          # training screen tilemap
perl tools/build_intro_glossary.pl $T.1.gb $T.2.gb                            # opening (18) and glossary/end of battle (20)
perl tools/patch_font_opening.pl $T.2.gb $T.3.gb                             # HL-relative font (opening)
perl tools/build_training_labels.pl $T.3.gb $T.4.gb | grep -v '^style\|^tiles intact'   # training graphic labels
perl tools/patch_training.pl $T.4.gb $T.5.gb                            # training digit columns
perl tools/font.pl $T.5.gb $T.6.gb                                    # capitals and punctuation
perl tools/names.pl $T.6.gb $T.7.gb translation/names.tsv                # name table
perl tools/fixed.pl $T.7.gb $T.8.gb translation/fixed.tsv                # menus, places, password, battle script
perl tools/patch_gokou.pl $T.8.gb $T.9.gb                             # "GOKOU" -> "GOKU" in the status header
perl tools/patch_title.pl $T.9.gb $T.10.gb                           # "GOKU GEKITOUDEN" banner on the title screen
perl tools/reloc.pl $T.10.gb builds/$N.gb translation/scene*.tsv           # all scenes into new banks
cp $T.10.gb builds/pre-reloc.gb   # base with everything except the scenes: to only re-text, run reloc.pl from it (build_text.sh)
rm -f $T.*.gb
[ -f builds/teste.sav ] && cp builds/teste.sav builds/$N.sav && echo "test save copied (builds/teste.sav)"
perl tools/mkips.pl rom/DB.gb builds/$N.gb builds/$N.ips        # IPS patch for distribution
