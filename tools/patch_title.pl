# usage: perl tools/patch_title.pl <rom_in> <rom_out> [preview.bmp]
# Title screen: resource 12 of bank 06 (mode 0x80: LZ + transposition $106D) holds the 116 logo tiles
# (ids 40..B3), the 20x18 map and resource 13. Below the logo there is a katakana strip "DRAGON BALL"
# (7 bubbles, pixels x 43..103, y 44..50, tiles of map rows 5 and 6) and the title in kanji.
# This patch erases the katakana strip AND the kanji (user request) and writes "GOKU GEKITOUDEN"
# (3x5 font, same as the copyright) centered at x 40..111, y 48..52. Recompresses with the original dictionary (148 entries).
use strict; use warnings;
my ($in,$out,$bmp)=@ARGV; die "usage: patch_title.pl rom_in rom_out [preview.bmp]\n" unless $out;
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; my $d=do{local $/;<$f>}; close $f; [unpack('C*',$d)] }
my $J=slurp('rom/DB.gb'); my $R=slurp($in);
my $TAB=0x18000; my $RES=12; my $PTR=$J->[$TAB+2*$RES]|($J->[$TAB+2*$RES+1]<<8); my $ADDR=$TAB+$PTR-0x4000;
my $NEXT=$J->[$TAB+2*($RES+1)]|($J->[$TAB+2*($RES+1)+1]<<8); my $SLOT=$NEXT-$PTR;
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
my $MPTR=$J->[$TAB+26]|($J->[$TAB+27]<<8); my ($map)=decomp($J,$TAB+$MPTR-0x4000);   # resource 13
sub tileat { my ($x,$y)=@_; my $id=$map->[int($y/8)*20+int($x/8)]; die "pixel ($x,$y) lands on an empty tile\n" if $id<0x40 || $id>=0x40+@T/16; $id-0x40 }
sub getpx { my ($x,$y)=@_; my $id=$map->[int($y/8)*20+int($x/8)]; return 0 if $id<0x40 || $id>=0x40+@T/16; my $k=$id-0x40; my $lo=$T[$k*16+($y%8)*2]; my $hi=$T[$k*16+($y%8)*2+1]; my $b=7-($x%8); (($lo>>$b)&1)|((($hi>>$b)&1)<<1) }
sub setpx { my ($x,$y,$v)=@_; my $k=tileat($x,$y); my $b=7-($x%8); my $m=(~(1<<$b))&0xFF; $T[$k*16+($y%8)*2]=($T[$k*16+($y%8)*2]&$m)|(($v&1)<<$b); $T[$k*16+($y%8)*2+1]=($T[$k*16+($y%8)*2+1]&$m)|((($v>>1)&1)<<$b) }
my ($X0,$X1,$Y0,$Y1)=(40,111,44,63);   # katakana strip (y 44..50) + kanji (y 53..63): all erased
my @before; for my $y ($Y0-2..$Y1+2){ push @before,[map{ getpx($_,$y) }$X0-8..$X1+8] }
for my $y ($Y0..$Y1){ for my $x ($X0..$X1){ my $id=$map->[int($y/8)*20+int($x/8)]; setpx($x,$y,0) if $id>=0x40 && $id<0x40+@T/16 } }   # empty tiles are already white
my %F=(
 G=>["###","#..","#.#","#.#","###"], O=>[".#.","#.#","#.#","#.#",".#."], K=>["#.#","#.#","##.","#.#","#.#"],
 U=>["#.#","#.#","#.#","#.#","###"], E=>["###","#..","##.","#..","###"], I=>["###",".#.",".#.",".#.","###"],
 T=>["###",".#.",".#.",".#.",".#."], D=>["##.","#.#","#.#","#.#","##."], N=>["#..#","##.#","#.##","#..#","#..#"],
 ' '=>["..","..","..","..",".."]);
my $text="GOKU GEKITOUDEN"; my $w=0; for my $c (split //,$text){ $w+=length($F{$c}[0])+1 } $w--;
my $x=$X0+int(($X1-$X0+1-$w)/2); my $y=$Y0+4; printf("text '%s': %d px, x %d..%d, y %d..%d\n",$text,$w,$x,$x+$w-1,$y,$y+4);
for my $c (split //,$text){ my $g=$F{$c}; for my $r (0..4){ my @row=split //,$g->[$r]; for my $i (0..$#row){ setpx($x+$i,$y+$r,3) if $row[$i] eq '#' } } $x+=length($g->[0])+1 }
if($bmp){ my $Sc=4; my @rows; for my $yy ($Y0-2..$Y1+2){ push @rows,[map{ getpx($_,$yy) }$X0-8..$X1+8] }
  my $W=scalar(@{$rows[0]})*$Sc; my $H=(2*@rows+1)*$Sc; my @pal=([255,255,255],[190,190,190],[100,100,100],[0,0,0]); my $rb=$W*3; my $pad=(4-($rb%4))%4;
  open(my $o,'>:raw',$bmp) or die; print $o pack('A2VVV','BM',54+($rb+$pad)*$H,0,54); print $o pack('VVVvvVVVVVV',40,$W,-$H,1,24,0,($rb+$pad)*$H,2835,2835,0,0);
  for my $py (0..$H-1){ my $line=''; my $r=int($py/$Sc); for my $px (0..$W-1){ my @c=(200,0,200); if($r<@before){ @c=@{$pal[$before[$r][int($px/$Sc)]]} } elsif($r>@before){ @c=@{$pal[$rows[$r-@before-1][int($px/$Sc)]]} } $line.=pack('CCC',$c[2],$c[1],$c[0]) } print $o $line.("\0"x$pad) } close $o; print "preview: $bmp (top: original, bottom: new)\n" }
my @packed=transpose(@T); die "size" unless @packed==@$orig;
for my $k (0..$SLOT-1){ die sprintf("base differs from the original at %06X\n",$ADDR+$k) if $R->[$ADDR+$k]!=$J->[$ADDR+$k] }
my ($st,$ds)=comp_opt(\@packed,$ods); printf("title: dict %d (original %d), %d/%d compressed bytes\n",$ds,$ods,scalar(@$st),$SLOT);
die "does not fit\n" if @$st>$SLOT; die "dictionary grew\n" if $ds!=$ods;
$R->[$ADDR+$_]=$st->[$_] for 0..$#$st; $R->[$ADDR+$_]=0xFF for scalar(@$st)..$SLOT-1;
my ($back,$bds)=decomp($R,$ADDR); my $ok=(@$back==@packed && $bds==$ds); if($ok){ for my $k (0..$#packed){ if($back->[$k]!=$packed[$k]){$ok=0;last} } } die "round-trip mismatch\n" unless $ok;
my $sum=0; for my $i (0..$#$R){ next if $i==0x14E||$i==0x14F; $sum+=$R->[$i] } $sum&=0xFFFF; $R->[0x14E]=$sum>>8; $R->[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@$R); close $o; printf("written %s (checksum %04X)\n",$out,$sum);
