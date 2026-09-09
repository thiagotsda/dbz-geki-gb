# usage: perl tools/build_intro_glossary.pl <input_rom> <output_rom>
# Resource 18 (opening narration) from translation/intro.txt: one line per screen line
# (max 17 columns; empty line = blank line; every 8 lines the game waits for the button).
#   Output = original 3-byte header + lines separated by FD + padding with FD + FF,
#   with exactly the original size (998 bytes).
# Resource 20 (status glossary + end of battle) from translation/glossary.txt: 30 strings,
#   one per line ('|' line break, <FB> pause, <N> name, <#> number), separated by FE; the last one is
#   padded with spaces up to the original size (315 bytes). The table of 30 pointers is built
#   by the game at run time ($3C12) by looking for the FEs, so the sizes are free.
# Both recompressed with the dictionary padded to the original size (output at the same address).
use strict; use warnings;
my ($in,$out)=@ARGV; die "usage: build_intro_glossary.pl input output\n" unless $out;
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; my $d=do{local $/;<$f>}; close $f; [unpack('C*',$d)] }
my $J=slurp('rom/DB.gb'); my $R=slurp($in);
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
sub enc { my $t=shift; my @o; my $w=0; my $maxw=0;
  while(length $t){
    if($t=~s/^\.\.\.//){ push @o,0x7A; $w++ }
    elsif($t=~s/^\|//){ push @o,0xFD; $maxw=$w if $w>$maxw; $w=0 }
    elsif($t=~s/^<FB>//){ push @o,0xFB; $maxw=$w if $w>$maxw; $w=0 }
    elsif($t=~s/^<N>//){ push @o,0xE3; $w+=6 }
    elsif($t=~s/^<#>//){ push @o,0xE2; $w+=3 }
    else { my $c=substr($t,0,1,''); my $b;
      if($c=~/[a-z]/){ $b=ord($c)-0x60 } elsif($c=~/[A-Z]/){ $b=ord($c)-0x40+0x1A } elsif($c eq ' '){ $b=0 }
      elsif($c=~/[0-9]/){ $b=0x70+$c } elsif($c eq ','){ $b=0x7B } elsif($c eq '.'){ $b=0x7C } elsif($c eq '?'){ $b=0x7D }
      elsif($c eq '!'){ $b=0x7E } elsif($c eq "'"){ $b=0x7F } elsif($c eq '-'){ $b=0x6F } else { die "character without a glyph: '$c'\n" }
      push @o,$b; $w++ } }
  $maxw=$w if $w>$maxw; return (\@o,$maxw) }
sub insert { my ($name,$addr,$slot,$bytes)=@_;
  my ($orig,$ods)=decomp($J,$addr); die "$name: size %d != original %d\n" if @$bytes!=@$orig;
  for my $k (0..$slot-1){ die sprintf("$name: base differs from the original at %06X (already changed?)\n",$addr+$k) if $R->[$addr+$k]!=$J->[$addr+$k] }
  my ($st,$ds)=comp_opt($bytes,$ods); die sprintf("$name: %d bytes do not fit in the %d-byte slot\n",scalar(@$st),$slot) if @$st>$slot;
  die "$name: dictionary $ds > original $ods\n" if $ds>$ods;
  $R->[$addr+$_]=$st->[$_] for 0..$#$st;
  my ($back,$bds)=decomp($R,$addr); my $ok=(@$back==@$bytes && $bds==$ods); if($ok){ for my $k (0..$#$bytes){ if($back->[$k]!=$bytes->[$k]){$ok=0;last} } }
  die "$name: round-trip mismatch\n" unless $ok;
  printf("%s: %d bytes uncompressed, dict %d (=original), %d/%d compressed, round-trip OK\n",$name,scalar(@$bytes),$ds,scalar(@$st),$slot) }
# ---- resource 18 ----
{ my ($orig)=decomp($J,0x1A8CB); my $size=scalar(@$orig); my @b=@$orig[0..2]; my $lines=0;
  open(my $t,'<','translation/intro.txt') or die; while(my $l=<$t>){ chomp $l; $l=~s/\r$//; next if $l=~/^#/; my ($e,$w)=enc($l); die "intro: line '$l' has $w columns (max 17)\n" if $w>17; push @b,@$e,0xFD; $lines++ } close $t;
  die sprintf("intro: %d bytes, only %d fit (%d lines)\n",scalar(@b)+1,$size,$lines) if @b+1>$size;
  my $padlines=0; while(@b+1<$size){ push @b,0xFD; $padlines++ } push @b,0xFF;
  printf("intro: %d text lines + %d blank at the end\n",$lines,$padlines);
  insert('resource 18',0x1A8CB,860,\@b) }
# ---- resource 20 ----
{ my ($orig)=decomp($J,0x1AD54); my $size=scalar(@$orig); my @s;
  open(my $t,'<','translation/glossary.txt') or die; while(my $l=<$t>){ chomp $l; $l=~s/\r$//; next if $l=~/^#/; my ($e,$w)=enc($l); die "glossary: '$l' has $w columns (max 18)\n" if $w>18; push @s,$e } close $t;
  die "glossary: needs 30 strings, has ".scalar(@s)."\n" unless @s==30;
  # each string keeps EXACTLY the size of the original (the end of battle reads by fixed offset in the buffer)
  my @olen; { my $l=0; for my $b (@$orig){ if($b==0xFE){ push @olen,$l; $l=0 } else { $l++ } } }
  die "glossary: original has ".scalar(@olen)." strings\n" unless @olen==30;
  my @b; my $pad=0;
  for my $i (0..29){ my @e=@{$s[$i]}; my $L=$olen[$i];
    die sprintf("glossary: string %d '%s' has %d bytes, original has %d\n",$i,join('',map{chr(0x60+$_)}grep{$_>=1&&$_<=26}@e),scalar(@e),$L) if @e>$L;
    # pad with spaces BEFORE a trailing <FB>, otherwise at the end
    my $fb = (@e && $e[-1]==0xFB) ? pop @e : undef; while(@e+($fb?1:0)<$L){ push @e,0x00; $pad++ } push @e,$fb if defined $fb;
    push @b,@e,0xFE }
  die sprintf("glossary: %d bytes != %d\n",scalar(@b),$size) if @b!=$size;
  printf("glossary: 30 strings at the original offsets, %d padding spaces\n",$pad);
  insert('resource 20',0x1AD54,262,\@b) }
my $sum=0; for my $i (0..$#$R){ next if $i==0x14E||$i==0x14F; $sum+=$R->[$i] } $sum&=0xFFFF; $R->[0x14E]=$sum>>8; $R->[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@$R); close $o; printf("wrote %s (checksum %04X)\n",$out,$sum);
