# usage: perl tools/unpack_res.pl <bank hex> <index> [output.bmp]
# Decompresses a mode 0x80 resource (table at $4000 of the given bank) and applies the post-processor
# $106D exactly like the game (byte by byte simulation), then draws the 2bpp tiles to a BMP.
use strict; use warnings;
my ($bank,$idx,$bmp)=@ARGV; $bank=hex($bank);
open(my $f,'<:raw','rom/DB.gb') or die; my $d=do{local $/;<$f>}; close $f; my @B=unpack('C*',$d);
my $tab=$bank*0x4000; my $ptr=$B[$tab+2*$idx]|($B[$tab+2*$idx+1]<<8); my $p=$tab+$ptr-0x4000;
my $outlen=$B[$p]|($B[$p+1]<<8); $p+=2; my @D; for my $i(0..31){ my $c=$B[$p+$i]; for my $b(0..7){ push @D,$i*8+$b if ($c>>$b)&1 } } $p+=32; my $ds=@D; my @o;
while(@o<$outlen){ my $b=$B[$p++]; if($b<$ds){ push @o,$D[$b] } else { my $l=$b-$ds+1; my $dd=$B[$p++]+1; my $s=@o-$dd; push @o,$o[$s+$_] for 0..$l-1 } }
printf("bank %02X resource %d: ptr %04X, %d bytes uncompressed, dict %d\n",$bank,$idx,$ptr,scalar(@o),$ds);
# $106D = 4x4 transposition of 2-bit fields in each group of 4 bytes (involution: pack = unpack)
my @T; for(my $g=0;$g+3<@o;$g+=4){ my @b=@o[$g..$g+3]; for my $k (0..3){ my $s=6-2*$k; push @T, (($b[0]>>$s)&3)<<6 | (($b[1]>>$s)&3)<<4 | (($b[2]>>$s)&3)<<2 | (($b[3]>>$s)&3) } }
if($bmp){ my $nt=int(@T/16); my $S=3; my $W=16*(8*$S+1); my $H=int(($nt+15)/16)*(8*$S+1); my @pal=([255,255,255],[190,190,190],[100,100,100],[0,0,0]); my $rb=$W*3; my $pad=(4-($rb%4))%4;
  open(my $ob,'>:raw',$bmp) or die; print $ob pack('A2VVV','BM',54+($rb+$pad)*$H,0,54); print $ob pack('VVVvvVVVVVV',40,$W,-$H,1,24,0,($rb+$pad)*$H,2835,2835,0,0);
  for my $y (0..$H-1){ my $line=''; for my $x (0..$W-1){ my $tx=int($x/(8*$S+1)); my $ty=int($y/(8*$S+1)); my $ix=$x%(8*$S+1); my $iy=$y%(8*$S+1); my $t=$ty*16+$tx; my @c=(200,0,200);
      if($ix<8*$S && $iy<8*$S && $t<$nt){ my $px=int($ix/$S); my $py=int($iy/$S); my $lo=$T[$t*16+$py*2]; my $hi=$T[$t*16+$py*2+1]; my $bit=7-$px; my $v=(($lo>>$bit)&1)|((($hi>>$bit)&1)<<1); @c=@{$pal[$v]} }
      $line.=pack('CCC',$c[2],$c[1],$c[0]) } print $ob $line.("\0"x$pad) } close $ob; print "bmp: $bmp ($nt tiles)\n" }
