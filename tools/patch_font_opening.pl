# usage: perl patch_font_opening.pl <rom_in> <rom_out>
# Replaces the font patch routine at $0061 with a version that writes the
# Latin letters at (input HL)+$10 instead of always at $9010.
# This way the opening (which loads the font at $8000 via $7398) also gets the alphabet.
use strict; use warnings;
my ($in,$out)=@ARGV; die "usage: patch_font_opening.pl rom_in rom_out\n" unless $out;
open(my $f,'<:raw',$in) or die; my $d=do{local $/;<$f>}; close $f; my @R=unpack('C*',$d);
my @code=(
 0xE5,             # push hl            ; save base destination
 0xCD,0x2A,0x07,   # call $072A         ; original load (kana)
 0xF5,0xC5,0xD5,0xE5, # push af,bc,de,hl ; preserve what $072A returned
 0xF8,0x08,        # ld hl,sp+8         ; point to the saved base
 0x2A,0x66,0x6F,   # ld a,(hl+) / ld h,(hl) / ld l,a  ; HL = base
 0x11,0x10,0x00,   # ld de,$0010
 0x19,             # add hl,de          ; HL = base + $10 (tile 0x01)
 0x11,0x43,0x3E,   # ld de,$3E43        ; 1bpp glyphs
 0x01,0xD0,0x00,   # ld bc,208
 0xCD,0x2A,0x07,   # call $072A
 0xE1,0xD1,0xC1,0xF1, # pop hl,de,bc,af
 0x33,0x33,        # inc sp / inc sp    ; discard the base
 0xC9);            # ret
my $old=join(" ",map{sprintf("%02X",$R[0x61+$_])}0..23);
die "old routine at \$0061 not found ($old)\n" unless $old eq "CD 2A 07 F5 C5 D5 E5 21 10 90 11 43 3E 01 D0 00 CD 2A 07 E1 D1 C1 F1 C9";
for my $k (24..@code-1){ die sprintf("byte %02X is not free\n",0x61+$k) if $R[0x61+$k]!=0 }
$R[0x61+$_]=$code[$_] for 0..$#code;
my $sum=0; for my $i (0..$#R){ next if $i==0x14E||$i==0x14F; $sum+=$R[$i] } $sum&=0xFFFF;
$R[0x14E]=$sum>>8; $R[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@R); close $o;
printf("written %s: %d-byte routine at \$0061-\$%04X, global checksum %04X\n",$out,scalar(@code),0x61+@code-1,$sum);
