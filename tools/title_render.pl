# usage: perl tools/title_render.pl [rom] [out.bmp]
# Composes the title screen: 20x18 map of resource 13 (bank 06) with the tiles of resource 12 (ids 40..B3,
# both mode 80 = LZ + transposition $106D). Tiles outside 40..B3 (ground/scenery) are drawn in purple.
use strict; use warnings;
my ($rom,$bmp)=@ARGV; $rom//='rom/DB.gb'; $bmp//='docs/images/title/title.bmp';
open(my $f,'<:raw',$rom) or die; my $d=do{local $/;<$f>}; close $f; my @B=unpack('C*',$d);
sub lz { my $idx=shift; my $tab=0x18000; my $ptr=$B[$tab+2*$idx]|($B[$tab+2*$idx+1]<<8); my $p=$tab+$ptr-0x4000; my $outlen=$B[$p]|($B[$p+1]<<8); $p+=2; my @D; for my $i(0..31){ my $c=$B[$p+$i]; for my $b(0..7){ push @D,$i*8+$b if ($c>>$b)&1 } } $p+=32; my $ds=@D; my @o; while(@o<$outlen){ my $b=$B[$p++]; if($b<$ds){ push @o,$D[$b] } else { my $l=$b-$ds+1; my $dd=$B[$p++]+1; my $s=@o-$dd; push @o,$o[$s+$_] for 0..$l-1 } } @o }
sub transpose { my @o=@_; my @T; for(my $g=0;$g+3<@o;$g+=4){ my @b=@o[$g..$g+3]; for my $k (0..3){ my $s=6-2*$k; push @T, (($b[0]>>$s)&3)<<6 | (($b[1]>>$s)&3)<<4 | (($b[2]>>$s)&3)<<2 | (($b[3]>>$s)&3) } } @T }
my @T=transpose(lz(12)); my @M=lz(13);
my $S=3; my $W=160*$S; my $H=144*$S; my @pal=([255,255,255],[190,190,190],[100,100,100],[0,0,0]); my $rb=$W*3; my $pad=(4-($rb%4))%4;
open(my $ob,'>:raw',$bmp) or die; print $ob pack('A2VVV','BM',54+($rb+$pad)*$H,0,54); print $ob pack('VVVvvVVVVVV',40,$W,-$H,1,24,0,($rb+$pad)*$H,2835,2835,0,0);
for my $y (0..$H-1){ my $line=''; for my $x (0..$W-1){ my $px=int($x/$S); my $py=int($y/$S); my $id=$M[int($py/8)*20+int($px/8)]; my @c=(200,0,200);
    if($id==0){ @c=(255,255,255) } elsif($id>=0x40 && $id<0x40+int(@T/16)){ my $t=$id-0x40; my $lo=$T[$t*16+($py%8)*2]; my $hi=$T[$t*16+($py%8)*2+1]; my $bit=7-($px%8); my $v=(($lo>>$bit)&1)|((($hi>>$bit)&1)<<1); @c=@{$pal[$v]} }
    $line.=pack('CCC',$c[2],$c[1],$c[0]) } print $ob $line.("\0"x$pad) } close $ob; print "bmp: $bmp\n";
