# usage: perl tools/font.pl <rom_in> <rom_out>
# Full font: 26 lowercase letters (already present at $3E43) + 26 UPPERCASE + punctuation
# (, . ? ! ') written to bank $3F ($4000, file 0xFC000), 1bpp, 8 bytes per glyph.
# New routine at $0061 switches to bank $3F (keeping $FFA5 consistent with vblank),
# expands the glyphs at (input HL)+$10 (tiles $01-$34) and +$7B0 (tiles $7B-$7F).
#
# Resulting encoding of the English text:
#   a-z = 01-1A   A-Z = 1B-34   space = 00   0-9 = 70-79
#   ... = 7A (original ellipsis tile)   , = 7B   . = 7C   ? = 7D   ! = 7E   ' = 7F
use strict; use warnings;
my ($in,$out)=@ARGV; die "usage: font.pl rom_in rom_out\n" unless $out;
open(my $f,'<:raw',$in) or die; my $d=do{local $/;<$f>}; close $f; my @R=unpack('C*',$d);
die "ROM must be 1 MB (expanded)\n" unless @R==0x100000;
# previous routine (patch_font_opening) must be at $0061
my $old=join(" ",map{sprintf("%02X",$R[0x61+$_])}0..32);
die "expected routine not found at \$0061:\n$old\n" unless $old=~/^E5 CD 2A 07 F5 C5 D5 E5 F8 08 2A 66 6F 11 10 00 19 11 43 3E 01 D0 00 CD 2A 07 E1 D1 C1 F1 33 33 C9$/;

my %F=(
 A=>".##. #..# #..# #### #..# #..# #..#", B=>"###. #..# #..# ###. #..# #..# ###.", C=>".### #... #... #... #... #... .###",
 D=>"###. #..# #..# #..# #..# #..# ###.", E=>"### #.. #.. ##. #.. #.. ###", F=>"### #.. #.. ##. #.. #.. #..",
 G=>".### #... #... #.## #..# #..# .###", H=>"#..# #..# #..# #### #..# #..# #..#", I=>"### .#. .#. .#. .#. .#. ###",
 J=>"..# ..# ..# ..# ..# #.# .#.", K=>"#..# #.#. ##.. ##.. #.#. #..# #..#", L=>"#.. #.. #.. #.. #.. #.. ###",
 M=>"#...# ##.## #.#.# #.#.# #...# #...# #...#", N=>"#..# ##.# ##.# #.## #.## #..# #..#", O=>".##. #..# #..# #..# #..# #..# .##.",
 P=>"###. #..# #..# ###. #... #... #...", Q=>".##. #..# #..# #..# #.## #..# .###", R=>"###. #..# #..# ###. #.#. #..# #..#",
 S=>".### #... #... .##. ...# ...# ###.", T=>"### .#. .#. .#. .#. .#. .#.", U=>"#..# #..# #..# #..# #..# #..# .##.",
 V=>"#..# #..# #..# #..# #..# .##. .##.", W=>"#...# #...# #...# #.#.# #.#.# ##.## #...#", X=>"#..# #..# .##. .##. .##. #..# #..#",
 Y=>"#.# #.# #.# .#. .#. .#. .#.", Z=>"#### ...# ..#. .#.. #... #... ####",
 ','=>"..... ..... ..... ..... ..... ..##. ...#. ..#..", '.'=>"..... ..... ..... ..... ..... ..##. ..##.",
 '?'=>".###. #...# ....# ...#. ..#.. ..... ..#..", '!'=>"..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..",
 "'"=>"..#.. ..#.. .#... ..... ..... ..... .....",
);
sub glyph { my $g=shift; my @rows=split / /,$F{$g}; my @b=(0)x8;
  for my $r (0..$#rows){ my $v=0; my @px=split //,$rows[$r]; for my $i (0..$#px){ $v|=(0x40>>$i) if $px[$i] eq '#' } $b[$r]=$v } @b }   # column 1 = bit 6
my @data; push @data,@R[0x3E43..0x3E43+207];                       # existing lowercase letters
push @data,glyph($_) for ('A'..'Z');                                # uppercase -> tiles 1B-34
push @data,glyph($_) for (',','.','?','!',"'");                     # tiles 7B-7F
die "size" unless @data==456;
my $GB=0x3F; my $go=$GB*0x4000; $R[$go+$_]=$data[$_] for 0..$#data;
my @code=(0xE5, 0xCD,0x2A,0x07, 0xF5,0xC5,0xD5,0xE5, 0xF0,0xA5, 0xF5, 0x3E,$GB, 0xE0,0xA5, 0xEA,0x00,0x21,
  0xF8,0x0A, 0x2A,0x66,0x6F, 0xE5, 0x11,0x10,0x00, 0x19, 0x11,0x00,0x40, 0x01,0xA0,0x01, 0xCD,0x2A,0x07,
  0xE1, 0x11,0xB0,0x07, 0x19, 0x11,0xA0,0x41, 0x01,0x28,0x00, 0xCD,0x2A,0x07,
  0xF1, 0xE0,0xA5, 0xEA,0x00,0x21, 0xE1,0xD1,0xC1,0xF1, 0x33,0x33, 0xC9);
for my $k (33..@code-1){ die sprintf("byte %02X is not free\n",0x61+$k) if $R[0x61+$k]!=0 }
$R[0x61+$_]=$code[$_] for 0..$#code;
my $sum=0; for my $i (0..$#R){ next if $i==0x14E||$i==0x14F; $sum+=$R[$i] } $sum&=0xFFFF; $R[0x14E]=$sum>>8; $R[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@R); close $o;
printf("font: %d bytes of glyphs in bank %02X, %d-byte routine at \$0061-\$%04X -> %s\n",scalar(@data),$GB,scalar(@code),0x61+@code-1,$out);
