# usage: perl tools/show_tiles.pl [resource] [rom]  -> draws the 2bpp tiles of a resource in ASCII
use strict; use warnings;
my $res=shift // 14; my $rom=shift // 'rom/DB.gb';
open(my $f,'<:raw',$rom) or die; local $/; my $d=<$f>; close $f; my @B=unpack('C*',$d);
my $ptr=$B[0x18000+2*$res]|($B[0x18001+2*$res]<<8); my $addr=0x18000+$ptr-0x4000;
my $p=$addr; my $outlen=$B[$p]|($B[$p+1]<<8); $p+=2;
my @dict; for my $i (0..31){ my $c=$B[$p+$i]; for my $b (0..7){ push @dict,$i*8+$b if ($c>>$b)&1 } } $p+=32; my $ds=@dict; my @o;
while(@o<$outlen){ my $b=$B[$p++]; if($b<$ds){ push @o,$dict[$b] } else { my $l=$b-$ds+1; my $dd=$B[$p++]+1; my $s=@o-$dd; push @o,$o[$s+$_] for 0..$l-1 } }
my $nt=int(@o/16); printf("resource %d: file %06X, %d bytes = %d tiles, dict %d, compressed %d bytes\n",$res,$addr,scalar(@o),$nt,$ds,$p-$addr);
my @ch=(' ','.','+','#');
for(my $t0=0;$t0<$nt;$t0+=16){
  printf("--- tiles %02X..%02X (VRAM \$8880+ => tiles %02X..)\n",$t0,$t0+15,0x88+$t0);
  for my $y (0..7){ my $line='';
    for my $t ($t0..$t0+15){ last if $t>=$nt; my $lo=$o[$t*16+$y*2]; my $hi=$o[$t*16+$y*2+1];
      for my $x (0..7){ my $bit=7-$x; $line.=$ch[(($lo>>$bit)&1)|((($hi>>$bit)&1)<<1)] } $line.='|' }
    print "$line\n" } }
