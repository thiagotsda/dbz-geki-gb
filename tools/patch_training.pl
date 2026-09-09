# usage: perl tools/patch_training.pl <rom_in> <rom_out>
# Moves the two-number column of the training screen (table $5ACE, bank 04):
#   remaining days: row 21, column 5 -> column 1  ("6 days")
#   senzu:          row 23, column 5 -> column 7  ("senzu  6")
use strict; use warnings;
my ($in,$out)=@ARGV; die "usage: patch_training.pl rom_in rom_out\n" unless $out;
open(my $f,'<:raw',$in) or die; my $d=do{local $/;<$f>}; close $f; my @R=unpack('C*',$d);
my @p=([0x11AEE,[0x01,0x80,0xA5,0x9A],[0x01,0x80,0xA1,0x9A]],[0x11AF2,[0x01,0x81,0xE5,0x9A],[0x01,0x81,0xE7,0x9A]]);
for my $e (@p){ my ($o,$old,$new)=@$e; for my $k (0..3){ die sprintf("unexpected byte at %06X (%02X)\n",$o+$k,$R[$o+$k]) if $R[$o+$k]!=$old->[$k] } $R[$o+$_]=$new->[$_] for 0..3 }
my $sum=0; for my $i (0..$#R){ next if $i==0x14E||$i==0x14F; $sum+=$R[$i] } $sum&=0xFFFF; $R[0x14E]=$sum>>8; $R[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@R); close $o; printf("written %s (checksum %04X)\n",$out,$sum);
