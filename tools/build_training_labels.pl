# usage (from the repository root): perl tools/build_training_labels.pl <base_rom> <output_rom> [preview.bmp]
# Redraws the graphic labels of the training screen (resource 14, 2bpp tiles) in English,
# recompresses and writes them into the 2171-byte slot.
#
# IMPORTANT CONSTRAINT: the decompressor writes the output at $C4C8 + (dictionary size).
# The original has 214 distinct values and the output ends at $D2AE; $D2B0 is already used by the game.
# So the dictionary must NOT exceed 214. The untouched tiles use 198 values, leaving 16 for
# the new labels. The script searches, per label, for the horizontal position and shadow style
# that keep the total of new values <= 16.
#
# Mapping (see docs/GUIDE.md, section 2.3):
#   body parts   VRAM $B0+4v -> tile 0x28+4v  (4 tiles x 1 row)   v=0..5
#   intensity    VRAM $C8+4v -> tile 0x40+4v  (4 tiles x 1 row)   v=0..2
#   speed        VRAM $D4+8v -> tile 0x4C+8v  (4 tiles x 2 rows)  v=0..2, label inside the curve
use strict; use warnings;
my ($base,$outf,$prev)=@ARGV; die "usage: build_training_labels.pl base output [preview.bmp]\n" unless $outf;
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; local $/; my $d=<$f>; close $f; [unpack('C*',$d)] }
my $J=slurp('rom/DB.gb'); my $R=slurp($base);
my ($ADDR,$SLOT,$MAXDICT)=(0x19A2C,2171,214);
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

# ---------- font: proportional capitals, 7 rows ----------
my %F=(
 A=>[split / /,".##. #..# #..# #### #..# #..# #..#"],
 B=>[split / /,"###. #..# #..# ###. #..# #..# ###."],
 C=>[split / /,".### #... #... #... #... #... .###"],
 D=>[split / /,"###. #..# #..# #..# #..# #..# ###."],
 E=>[split / /,"### #.. #.. ##. #.. #.. ###"],
 F=>[split / /,"### #.. #.. ##. #.. #.. #.."],
 G=>[split / /,".### #... #... #.## #..# #..# .###"],
 H=>[split / /,"#..# #..# #..# #### #..# #..# #..#"],
 I=>[split / /,"### .#. .#. .#. .#. .#. ###"],
 K=>[split / /,"#..# #.#. ##.. ##.. #.#. #..# #..#"],
 L=>[split / /,"#.. #.. #.. #.. #.. #.. ###"],
 M=>[split / /,"#...# ##.## #.#.# #.#.# #...# #...# #...#"],
 N=>[split / /,"#..# ##.# ##.# #.## #.## #..# #..#"],
 O=>[split / /,".##. #..# #..# #..# #..# #..# .##."],
 R=>[split / /,"###. #..# #..# ###. #.#. #..# #..#"],
 S=>[split / /,".### #... #... .##. ...# ...# ###."],
 T=>[split / /,"### .#. .#. .#. .#. .#. .#."],
 W=>[split / /,"#...# #...# #...# #.#.# #.#.# ##.## #...#"],
 Y=>[split / /,"#.# #.# #.# .#. .#. .#. .#."],
);
sub textw { my ($t,$sp)=@_; $sp//=1; my $w=0; for my $c (split //,$t){ die "letter $c\n" unless $F{$c}; $w+=length($F{$c}[0])+$sp } $w-$sp }

# ---------- tiles ----------
my ($orig,$ods)=decomp($J,$ADDR); my @N=@$orig;
sub getpx { my ($t,$x,$y)=@_; my $lo=$N[$t*16+$y*2]; my $hi=$N[$t*16+$y*2+1]; my $b=7-$x; (($lo>>$b)&1)|((($hi>>$b)&1)<<1) }
sub setpx { my ($t,$x,$y,$v)=@_; my $b=7-$x; my $m=(~(1<<$b))&0xFF;
  $N[$t*16+$y*2]=($N[$t*16+$y*2]&$m)|(($v&1)<<$b); $N[$t*16+$y*2+1]=($N[$t*16+$y*2+1]&$m)|((($v>>1)&1)<<$b) }
sub bpx { my ($blk,$x,$y,$v)=@_; my $t=$blk->[int($y/8)*4+int($x/8)]; defined $v ? setpx($t,$x%8,$y%8,$v) : getpx($t,$x%8,$y%8) }
sub restore { my $blk=shift; for my $t (@$blk){ $N[$t*16+$_]=$orig->[$t*16+$_] for 0..15 } }
# shadow styles: (dx,dy) or none
my %STYLE=(shadow=>[1,1], down=>[0,1], none=>undef);
# draws text at x (absolute within the block), clearing the rectangle first
sub draw { my ($blk,$text,$x0,$y0,$x1,$y1,$x,$style,$sp)=@_; $sp//=1;
  restore($blk); for my $y ($y0..$y1){ for my $xx ($x0..$x1){ bpx($blk,$xx,$y,1) } }
  my @pts; my $cx=$x; for my $c (split //,$text){ my $g=$F{$c}; for my $r (0..6){ my @row=split //,$g->[$r]; for my $i (0..$#row){ push @pts,[$cx+$i,$y0+$r] if $row[$i] eq '#' } } $cx+=length($g->[0])+$sp }
  if(my $s=$STYLE{$style}){ for (@pts){ my ($px,$py)=($_->[0]+$s->[0],$_->[1]+$s->[1]); bpx($blk,$px,$py,2) if $px<=$x1 && $py<=$y1 && bpx($blk,$px,$py)==1 } }
  for (@pts){ bpx($blk,$_->[0],$_->[1],3) } }
sub blockvals { my $blk=shift; my %v; for my $t (@$blk){ $v{$N[$t*16+$_]}=1 for 0..15 } \%v }

# labels: [tiles, text, x0,y0,x1,y1]
my @L;
my @body=qw(ARM LEG KI HEAD BELLY CHEST);      # JP: ude ashi ki atama onaka mune
my @inten=qw(HARD MED LIGHT);                   # JP: kitsui futsuu karui
my @speed=qw(FAST MED SLOW);                    # JP: hayai futsuu osoi
for my $v (0..5){ push @L,[[map{0x28+4*$v+$_}0..3],$body[$v],0,0,31,7,'c'] }
for my $v (0..2){ push @L,[[map{0x40+4*$v+$_}0..3],$inten[$v],0,0,31,7,'c'] }
for my $v (0..2){ my $b=[map{0x4C+8*$v+$_}0..7]; push @L, $v<2 ? [$b,$speed[$v],10,8,31,15,'r'] : [$b,$speed[$v],0,0,21,7,'l'] }

# values already used by the tiles that do not change
my %chg; for my $l (@L){ $chg{$_}=1 for @{$l->[0]} }
my %used; for my $t (0..int(@N/16)-1){ next if $chg{$t}; $used{$N[$t*16+$_]}=1 for 0..15 }
my $budget=$MAXDICT-scalar(keys %used);
printf("tiles intact use %d values; budget for new values: %d\n",scalar(keys %used),$budget);

# search: per style, coordinate descent over the x position of each label.
# cost = 1000 * (new values above the budget) + sum of each label's deviation from
# its preferred position (center / right / left). So the labels stay aligned whenever
# the budget allows, and only move the minimum necessary.
# Each candidate is a pair [x, letter spacing] (spacing 1 or 2 px). The deviation is measured in
# half-pixels from the exact center of the rectangle (or from the edge, for 'l'/'r'), so a label of
# odd width can be perfectly centered by choosing x or the spacing.
my ($bestStyle,@bestX,$bestCost,$bestBad);
for my $style (qw(shadow down none)){
  my @xs; my @cand; my @devof;
  for my $i (0..$#L){ my ($blk,$t,$x0,$y0,$x1,$y1,$al)=@{$L[$i]}; my $extra=($STYLE{$style}?1:0); my @c;
    for my $sp (1,2){ my $w=textw($t,$sp); for my $x ($x0..$x1){ next if $x+$w-1+$extra>$x1;
      my $dev = $al eq 'l' ? 2*($x-$x0) : $al eq 'r' ? 2*($x1-$extra-($x+$w-1)) : abs(2*$x+$w-1-($x0+$x1));   # half-pixels
      push @c,[$x,$sp,$dev] } }
    die "'$t' does not fit\n" unless @c; @c=sort{$a->[2]<=>$b->[2]}@c; $cand[$i]=\@c; $xs[$i]=$c[0] }
  my @bad;
  my $eval=sub { my ($i,$p)=@_; my ($blk,$t,$x0,$y0,$x1,$y1)=@{$L[$i]}; draw($blk,$t,$x0,$y0,$x1,$y1,$p->[0],$style,$p->[1]); my $v=blockvals($blk); my %b; for (keys %$v){ $b{$_}=1 unless $used{$_} } \%b };
  my $cost=sub { my ($i,$b,$p)=@_; my %u; for my $j (0..$#L){ next if $j==$i; $u{$_}=1 for keys %{$bad[$j]} } $u{$_}=1 for keys %$b; my $n=scalar(keys %u);
    my $dev=0; for my $j (0..$#L){ $dev+= ($j==$i?$p:$xs[$j])->[2] } return (($n>$budget?1000*($n-$budget):0)+$dev, $n) };
  srand(12345); my ($rc,$rn,@rx);
  for my $restart (0..39){
    if($restart>0){ for my $i (0..$#L){ my @c=@{$cand[$i]}; $xs[$i]=$c[int(rand(@c))] } } else { $xs[$_]=$cand[$_][0] for 0..$#L }
    $bad[$_]=$eval->($_,$xs[$_]) for 0..$#L;
    for my $round (1..15){ my $changed=0;
      for my $i (0..$#L){ my ($bp,$bc)=($xs[$i],1e9);
        for my $p (@{$cand[$i]}){ my $b=$eval->($i,$p); my ($c)=$cost->($i,$b,$p); if($c<$bc){ ($bp,$bc)=($p,$c) } }
        if($bp!=$xs[$i]){ $xs[$i]=$bp; $changed=1 } $bad[$i]=$eval->($i,$bp) }
      last unless $changed }
    my ($c,$n)=$cost->(0,$bad[0],$xs[0]);
    if(!defined $rc || $c<$rc){ ($rc,$rn,@rx)=($c,$n,@xs) } last if $c==0 }
  @xs=@rx; my ($c,$n)=($rc,$rn);
  my $dev=0; $dev+=$xs[$_][2] for 0..$#L;
  printf("style %-6s: %d new values (limit %d), total deviation %.1f px\n",$style,$n,$budget,$dev/2);
  if(!defined $bestCost || $c<$bestCost){ ($bestStyle,$bestCost,$bestBad,@bestX)=($style,$c,$n,@xs) } }
die "no style fit within the value budget (best: $bestBad)\n" if $bestBad>$budget;
for my $i (0..$#L){ my ($blk,$t,$x0,$y0,$x1,$y1)=@{$L[$i]}; draw($blk,$t,$x0,$y0,$x1,$y1,$bestX[$i][0],$bestStyle,$bestX[$i][1]) }
printf("chosen: style %s, (x,spacing) = %s\n",$bestStyle,join(" ",map{"$_->[0],$_->[1]"}@bestX));

# ---------- BMP preview ----------
if($prev){ my @blocks=map{$_->[0]}@L; my $S=6; my $W=32*$S; my $H=0; $H+=(@$_==8?16:8)*$S+4 for @blocks;
  my @pal=([255,255,255],[255,230,150],[150,100,50],[0,0,0]); my $rb=$W*3; my $pad=(4-($rb%4))%4;
  open(my $o,'>:raw',$prev) or die; print $o pack('A2VVV','BM',54+($rb+$pad)*$H,0,54); print $o pack('VVVvvVVVVVV',40,$W,-$H,1,24,0,($rb+$pad)*$H,2835,2835,0,0);
  for my $bl (@blocks){ my $rows=(@$bl==8?16:8); for my $y (0..$rows*$S+3){ my $line='';
    for my $x (0..$W-1){ my @c=(200,0,200); if($y<$rows*$S){ my $v=bpx($bl,int($x/$S),int($y/$S)); @c=@{$pal[$v]} } $line.=pack('CCC',$c[2],$c[1],$c[0]) }
    print $o $line.("\0"x$pad) } } close $o; print "preview: $prev\n" }

# ---------- recompression and insertion ----------
for my $k (0..$SLOT-1){ die sprintf("base differs from the original at %06X (resource 14 already changed?)\n",$ADDR+$k) if $R->[$ADDR+$k]!=$J->[$ADDR+$k] }
my ($st,$ds)=comp_opt(\@N,$MAXDICT);
printf("resource 14: dict %d (original %d), %d / %d bytes -> %s\n",$ds,$ods,scalar(@$st),$SLOT,(@$st<=$SLOT?"FITS":"DOES NOT FIT"));
die "dictionary larger than $MAXDICT\n" if $ds>$MAXDICT; die "does not fit\n" if @$st>$SLOT;
$R->[$ADDR+$_]=$st->[$_] for 0..$#$st;
my ($back,$bds)=decomp($R,$ADDR); my $ok=(@$back==@N && $bds==$MAXDICT); if($ok){ for my $k (0..$#N){ if($back->[$k]!=$N[$k]){$ok=0;last} } }
die "round-trip mismatch\n" unless $ok; print "round-trip OK, output at \$C4C8+$bds\n";
my $sum=0; for my $i (0..$#$R){ next if $i==0x14E||$i==0x14F; $sum+=$R->[$i] } $sum&=0xFFFF;
$R->[0x14E]=$sum>>8; $R->[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$outf) or die; print $o pack('C*',@$R); close $o;
printf("wrote %s (global checksum %04X)\n",$outf,$sum);
