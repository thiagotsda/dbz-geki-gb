# usage: perl tools/patch_gokou.pl <rom_in> <rom_out> [preview.bmp]
# Resource 4 of bank 06 (mode 0x80: LZ + 4x4 transposition of 2-bit fields at $106D):
# 35 tiles loaded at $8A00 (ids A0..C2) for the status screen. Tiles B6-B9 (indices 22-25)
# form the "GOKOU" strip (light letters on a dark background, 6 px per letter). Rewrites the strip
# as "GOKU": columns 0-20 (G O K) kept, "U" copied from columns 26-31, the rest = pattern of the border
# tile (BC). The transposition is an involution, so pack = unpack. Recompresses with dictionary 64.
use strict; use warnings;
my ($in,$out,$bmp)=@ARGV; die "usage: patch_gokou.pl rom_in rom_out [preview.bmp]\n" unless $out;
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; my $d=do{local $/;<$f>}; close $f; [unpack('C*',$d)] }
my $J=slurp('rom/DB.gb'); my $R=slurp($in);
my ($ADDR,$SLOT)=(0x18A32,448);
sub decomp { my ($M,$src)=@_; my $p=$src; my $outlen=$M->[$p]|($M->[$p+1]<<8); $p+=2;
  my @dict; for my $i (0..31){ my $c=$M->[$p+$i]; for my $b (0..7){ push @dict,$i*8+$b if ($c>>$b)&1 } }
  $p+=32; my $ds=scalar @dict; my @out;
  while(scalar(@out)<$outlen){ my $b=$M->[$p++]; die "end" unless defined $b;
    if($b<$ds){ push @out,$dict[$b] } else { my $len=($b-$ds)+1; my $dist=$M->[$p++]+1; my $s=scalar(@out)-$dist; die "dist" if $s<0; push @out,$out[$s+$_] for 0..$len-1 } }
  return (\@out,$ds,$p-$src) }
sub comp_opt { my ($out,$target)=@_;
  my %seen; $seen{$_}=1 for @$out; my @dict=sort{$a<=>$b} keys %seen;
  if($target){ for my $v (0..255){ last if @dict>=$target; next if $seen{$v}; push @dict,$v; $seen{$v}=1 } @dict=sort{$a<=>$b} @dict }
  my %idx; $idx{$dict[$_]}=$_ for 0..$#dict; my $ds=scalar @dict;
  my @bm=(0)x32; $bm[int($_/8)] |= (1<<($_%8)) for @dict;
  my $n=scalar(@$out); my $ml=255-$ds; my @maxl;
  for my $i (0..$n-1){ my $bl=0; my $lo=$i-256; $lo=0 if $lo<0;
    for my $j ($lo..$i-1){ my $l=0; $l++ while $i+$l<$n && $l<$ml && $out->[$j+$l]==$out->[$i+$l]; $bl=$l if $l>$bl }
    $maxl[$i]=$bl }
  my @cost=(0)x($n+1); my @choice=(0)x($n+1);
  for (my $i=$n-1;$i>=0;$i--){ my $best=1+$cost[$i+1]; my $ch=0;
    for (my $L=3;$L<=$maxl[$i];$L++){ my $c=2+$cost[$i+$L]; if($c<$best){$best=$c;$ch=$L} } $cost[$i]=$best; $choice[$i]=$ch }
  my @body; my $i=0;
  while($i<$n){ my $L=$choice[$i];
    if($L){ my $lo=$i-256; $lo=0 if $lo<0; my $dist=0;
      for my $j ($lo..$i-1){ my $ok=1; for my $k (0..$L-1){ if($out->[$j+$k]!=$out->[$i+$k]){$ok=0;last} } if($ok){$dist=$i-$j;last} }
      push @body,$ds+($L-1),$dist-1; $i+=$L } else { push @body,$idx{$out->[$i]}; $i++ } }
  return ([$n&0xFF,($n>>8)&0xFF,@bm,@body],$ds) }
sub transpose { my @o=@_; my @T; for(my $g=0;$g+3<@o;$g+=4){ my @b=@o[$g..$g+3]; for my $k (0..3){ my $s=6-2*$k; push @T, (($b[0]>>$s)&3)<<6 | (($b[1]>>$s)&3)<<4 | (($b[2]>>$s)&3)<<2 | (($b[3]>>$s)&3) } } @T }
my ($orig,$ods)=decomp($J,$ADDR); my @T=transpose(@$orig);
sub getpx { my ($k,$x,$y)=@_; my $lo=$T[$k*16+$y*2]; my $hi=$T[$k*16+$y*2+1]; my $b=7-$x; (($lo>>$b)&1)|((($hi>>$b)&1)<<1) }
sub setpx { my ($k,$x,$y,$v)=@_; my $b=7-$x; my $m=(~(1<<$b))&0xFF; $T[$k*16+$y*2]=($T[$k*16+$y*2]&$m)|(($v&1)<<$b); $T[$k*16+$y*2+1]=($T[$k*16+$y*2+1]&$m)|((($v>>1)&1)<<$b) }
# 32x8 strip of tiles 22..25
my @S; for my $y (0..7){ for my $x (0..31){ $S[$y][$x]=getpx(22+int($x/8),$x%8,$y) } }
my @N; for my $y (0..7){
  for my $x (0..20){ $N[$y][$x]=$S[$y][$x] }                 # G O K
  for my $x (21..26){ $N[$y][$x]=$S[$y][$x+5] }              # separator + U (original columns 26..31)
  for my $x (27..31){ $N[$y][$x]=getpx(28,$x%8,$y) } }       # box border (tile BC)
for my $y (0..7){ for my $x (0..31){ setpx(22+int($x/8),$x%8,$y,$N[$y][$x]) } }
if($bmp){ my $Sc=8; my $W=32*$Sc; my $H=16*$Sc; my @pal=([255,255,255],[190,190,190],[100,100,100],[0,0,0]); my $rb=$W*3; my $pad=(4-($rb%4))%4;
  open(my $o,'>:raw',$bmp) or die; print $o pack('A2VVV','BM',54+($rb+$pad)*$H,0,54); print $o pack('VVVvvVVVVVV',40,$W,-$H,1,24,0,($rb+$pad)*$H,2835,2835,0,0);
  for my $y (0..$H-1){ my $line=''; my $py=int($y/$Sc); for my $x (0..$W-1){ my $px=int($x/$Sc); my $v = $py<8 ? $S[$py][$px] : $N[$py-8][$px]; my @c=@{$pal[$v]}; $line.=pack('CCC',$c[2],$c[1],$c[0]) } print $o $line.("\0"x$pad) } close $o; print "preview: $bmp (top: original, bottom: new)\n" }
my @packed=transpose(@T); die "size" unless @packed==@$orig;
for my $k (0..$SLOT-1){ die sprintf("base differs from the original at %06X\n",$ADDR+$k) if $R->[$ADDR+$k]!=$J->[$ADDR+$k] }
my ($st,$ds)=comp_opt(\@packed,$ods); printf("GOKU: dict %d (original %d), %d/%d compressed bytes\n",$ds,$ods,scalar(@$st),$SLOT);
die "does not fit\n" if @$st>$SLOT; die "dictionary grew too much\n" if $ds>$ods+8;   # +N shifts the output by N bytes in RAM; this resource's buffer (560 B) ends at $C739, far from $D2B0
$R->[$ADDR+$_]=$st->[$_] for 0..$#$st;
my ($back,$bds)=decomp($R,$ADDR); my $ok=(@$back==@packed && $bds==$ds); if($ok){ for my $k (0..$#packed){ if($back->[$k]!=$packed[$k]){$ok=0;last} } } die "round-trip mismatch\n" unless $ok;
my $sum=0; for my $i (0..$#$R){ next if $i==0x14E||$i==0x14F; $sum+=$R->[$i] } $sum&=0xFFFF; $R->[0x14E]=$sum>>8; $R->[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@$R); close $o; printf("written %s (checksum %04X)\n",$out,$sum);
