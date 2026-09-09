# usage: perl tools/build_training_text.pl <base_rom> <output_rom> <resource list: 20 18 15>
# Reinserts the translated compressed resources 15/18/20, with the DICTIONARY
# padded to the original size (see docs/GUIDE.md, section 2.3, on why the dictionary
# size matters). Reads the Japanese from rom/DB.gb and the r15en/r18en2/r20en tables.
use strict; use warnings;
my ($base,$outf,@res)=@ARGV; die "usage: build_training_text.pl base output 20 [18] [15]\n" unless $outf && @res;
my $dir=$0; $dir=~s{[^/\\]*$}{}; $dir='./' if $dir eq '';
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; local $/; my $d=<$f>; close $f; [unpack('C*',$d)] }
my $J=slurp('rom/DB.gb'); my $R=slurp($base);
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
  my $n=scalar(@$out); my $ml=255-$ds; my (@maxl);
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
sub enc1 { my $c=shift; return 0x00 if $c eq ' '; return 0x88 if $c eq '_'; return 0x7C if $c eq '.'; return ord($c)-0x40+0x1A if $c ge 'A' && $c le 'Z'; return 0x7B if $c eq ','; return 0x7F if $c eq "'"; return 0x7D if $c eq '?'; return 0x7E if $c eq '!';
  return 0x70+ord($c)-0x30 if $c ge '0' && $c le '9'; return ord($c)-0x60 if $c ge 'a' && $c le 'z'; die "invalid char '$c'\n" }
my %info=(15=>[0x1A2A7,305,'data/training-text.txt']);
for my $n (@res){ my ($addr,$slot,$tab)=@{$info{$n}} or die "resource $n?";
  # check that the slot in the base is still the original Japanese
  for my $k (0..$slot-1){ die sprintf("resource %d: base differs from the original at %06X\n",$n,$addr+$k) if $R->[$addr+$k]!=$J->[$addr+$k] }
  my ($out,$ods)=decomp($J,$addr); my @N=@$out;
  open(my $t,'<',$dir.$tab) or die "$tab: $!"; while(my $l=<$t>){ chomp $l; next unless $l=~/\S/; my ($off,$len,$txt)=split /\t/,$l,3; $txt//='';
    die "$tab: line $off has ".length($txt)." chars, expected $len\n" if length($txt)!=$len;
    die "$tab: line $off overflows the output\n" if $off+$len>@N;
    for my $k (0..$len-1){ my $c=substr($txt,$k,1); next if $c eq '~'; die "$tab: line $off overwrites a control byte at $off+$k\n" if $n!=15 && $out->[$off+$k]>=0xE2; $N[$off+$k]=enc1($c) } } close $t;
  if($n==18){ die "resource 18: header changed\n" if grep { $N[$_]!=$out->[$_] } 0..2 }
  my ($st,$ds)=comp_opt(\@N,$ods);
  die sprintf("resource %d: %d bytes do not fit in %d\n",$n,scalar(@$st),$slot) if @$st>$slot;
  $R->[$addr+$_]=$st->[$_] for 0..$#$st;
  my ($back,$bds)=decomp($R,$addr); my $ok=(@$back==@N && $bds==$ods); if($ok){ for my $k (0..$#N){ if($back->[$k]!=$N[$k]){$ok=0;last} } }
  die "resource $n: round-trip mismatch\n" unless $ok;
  printf("resource %2d: dict %3d (=original), %3d/%3d bytes, output at \$%04X, round-trip OK\n",$n,$ds,scalar(@$st),$slot,0xC4C8+$ds);
}
# global checksum
my $sum=0; for my $i (0..$#$R){ next if $i==0x14E||$i==0x14F; $sum+=$R->[$i] } $sum&=0xFFFF;
$R->[0x14E]=$sum>>8; $R->[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$outf) or die; print $o pack('C*',@$R); close $o;
printf("wrote %s (%d bytes, global checksum %04X)\n",$outf,scalar(@$R),$sum);
