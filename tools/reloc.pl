# usage: perl tools/reloc.pl <rom_in> <rom_out> <script.tsv> [script2.tsv ...]
# Relocates the text of whole scenes to new banks (bank = $22 + scene).
#   - The text engine ($1766) reads the scene's bank from $18F2[scene] and only fetches TEXT BYTES from it
#     (inside vblank, which restores the bank afterwards). The pointer lists stay in bank $21
#     (loader $0A65). So the new bank only needs to hold the scene's text.
#   - GLOBAL IDS (>= C0) index the continuous list starting at master[0] = lists of scenes 0 and 1
#     (system notices: choose character, save, food, battle events). They are read with the
#     CURRENT SCENE's bank. That is why the text of scenes 0 and 1 is a SHARED BLOCK, written at the same
#     address ($4000..) in ALL new banks; each scene's own text comes after it.
#   - Each page (between <FB>) has at most 3 lines (the original JP too): beyond that the game scrolls
#     the text and leaves leftovers at the edges. Larger pages are split automatically with <FB>.
#   - Boxes missing from the script are copied from the source bank (warning); pointers without <FE> become empty.
# Script TSV: scene(dec) <TAB> id(hex) <TAB> text     ('#' = comment)
#   '|' line break, <FB> pause/page, <N> name (6 cols), <#> number (3 cols). <FE> automatic.
#   Width 14; prefix "!18" = wide box (narration/battle). Characters: a-z A-Z 0-9 . , ? ! ' - "..."
use strict; use warnings;
my ($in,$out,@scripts)=@ARGV; die "usage: reloc.pl rom_in rom_out script.tsv...\n" unless @scripts;
open(my $f,'<:raw',$in) or die; my $d=do{local $/;<$f>}; close $f; my @R=unpack('C*',$d);
die "ROM must be 1 MB\n" unless @R==0x100000;
my $LOADER_BANK=0x21; my $LB=$LOADER_BANK*0x4000; my @SHARED=(0,1);
sub wlen { my $w=shift; my $t=$w; $t=~s/\.\.\./x/g; $t=~s/<N>/xxxxxx/g; $t=~s/<#>/xxx/g; length $t }
sub endcost { my $w=shift; ($w=~/[.!?]$/ || $w=~/\.\.\.$/) ? 0 : ($w=~/,$/ ? 1 : 3) }
sub paginate { my ($t,$max,$width)=@_; my @pages;
  # Each chunk between <FB> with more than $max lines is re-wrapped word by word (lines <= $width,
  # pages <= $max lines) by dynamic programming: cost 0 for a page ending in . ! ? ...,
  # 1 at a comma, 3 mid-sentence, +0.3 for a 1-line page, +0.1 per line, + the empty fraction of each
  # line that is not the last of the page (avoids short lines in the middle). Chunks that already fit
  # are kept exactly as written (choice boxes, manual pauses).
  for my $pg (split /<FB>/,$t,-1){ my @ln=split /\|/,$pg,-1;
    if(@ln<=$max){ push @pages,$pg; next }
    my @w=grep{length}split / /,join(' ',@ln); my $n=@w; die "page without words: $pg\n" unless $n;
    # best[i][l] = lowest cost having consumed i words with l lines in the current page (l=0: page closed)
    my @best; my @from; $best[0][0]=0;
    for my $i (0..$n-1){ for my $l (0..$max-1){ next unless defined $best[$i][$l]; my $c0=$best[$i][$l];
        my $wd=0; for my $j ($i..$n-1){ $wd += ($j>$i?1:0)+wlen($w[$j]); last if $wd>$width; my $nl=$l+1;
          my $fill=2*(1-$wd/$width)**2; my $c=$c0+0.1+$fill;   # continue the page: a short line in the middle of the page costs
          if($nl<$max && $j<$n-1){ if(!defined $best[$j+1][$nl] || $c<$best[$j+1][$nl]){ $best[$j+1][$nl]=$c; $from[$j+1][$nl]=[$i,$l,0] } }
          my $ec=($j<$n-1 ? endcost($w[$j]) : 0); $ec+=($max-$nl)+3*(1-$wd/$width) if $ec>=3;   # a mid-sentence cut costs more on an incomplete page and after a short line ("Dragon<FB>Ball")
          my $cc=$c-$fill+$ec+($nl==1?0.3:0);   # close the page after this line (the last line may be short)
          if(!defined $best[$j+1][0] || $cc<$best[$j+1][0]){ $best[$j+1][0]=$cc; $from[$j+1][0]=[$i,$l,1] } } } }
    die "could not paginate: $pg\n" unless defined $best[$n][0];
    my @lines; my ($i,$l)=($n,0); my @out;
    while($i>0){ my ($pi,$pl,$close)=@{$from[$i][$l]}; unshift @lines, [join(' ',@w[$pi..$i-1]),$close]; ($i,$l)=($pi,$pl) }
    my @cur; for my $x (@lines){ push @cur,$x->[0]; if($x->[1]){ push @pages,join('|',@cur); @cur=() } } push @pages,join('|',@cur) if @cur }
  join('<FB>',@pages) }
sub enc { my $t=shift; my @o; my @lines=(0);
  while(length $t){
    if($t=~s/^\.\.\.//){ push @o,0x7A; $lines[-1]++ }
    elsif($t=~s/^\|//){ push @o,0xFD; push @lines,0 }
    elsif($t=~s/^<FB>//){ push @o,0xFB; push @lines,0 }
    elsif($t=~s/^<N>//){ push @o,0xE3; $lines[-1]+=6 }
    elsif($t=~s/^<#>//){ push @o,0xE2; $lines[-1]+=3 }
    else { my $c=substr($t,0,1,''); my $b;
      if($c=~/[a-z]/){ $b=ord($c)-0x60 } elsif($c=~/[A-Z]/){ $b=ord($c)-0x40+0x1A } elsif($c eq ' '){ $b=0 }
      elsif($c=~/[0-9]/){ $b=0x70+$c } elsif($c eq ','){ $b=0x7B } elsif($c eq '.'){ $b=0x7C } elsif($c eq '?'){ $b=0x7D }
      elsif($c eq '!'){ $b=0x7E } elsif($c eq "'"){ $b=0x7F } elsif($c eq '-'){ $b=0x6F } else { die "character without glyph: '$c'\n" }
      push @o,$b; $lines[-1]++ } }
  push @o,0xFE; return (\@o,\@lines) }
my %S; my %order;
for my $fn (@scripts){ open(my $t,'<',$fn) or die "$fn: $!"; while(my $l=<$t>){ chomp $l; $l=~s/\r$//; next if $l=~/^\s*(#|$)/; my ($s,$id,$txt)=split /\t/,$l,3; $txt//='';
  die "$fn: invalid line: $l\n" unless defined $id && $s=~/^\d+$/;
  die sprintf("$fn: scene %d id %s repeated\n",$s,$id) if exists $S{$s+0}{hex($id)};
  $S{$s+0}{hex($id)}=$txt; $order{$s+0}=1 } close $t }
for my $s (@SHARED){ die "scene $s (shared block) must be in the scripts\n" unless $order{$s} }
my @start=map{ $R[$LB+2*($_+1)]|($R[$LB+2*($_+1)+1]<<8) } 0..26;
my @sorted=sort{$a<=>$b} grep{$_>=0x4000&&$_<0x8000}@start;
my ($sum,$warn,$splits)=(0,0,0);
# ---- encode the boxes of each scene ----
my %BOX;   # scene -> [ [bytes...], ... ]  (one entry per id)
my %CNT; my %ST;
for my $s (sort{$a<=>$b} keys %order){
  my $st=$start[$s]; die "scene $s: list outside the ROM\n" if $st<0x4000||$st>=0x8000; $ST{$s}=$st;
  my ($next)=grep{$_>$st}@sorted; my $cnt=int(($next-$st)/2);
  my @ptr; for my $k (0..$cnt-1){ my $q=$R[$LB+$st-0x4000+2*$k]|($R[$LB+$st-0x4000+2*$k+1]<<8); last if ($q<0x4000||$q>=0x8000) && $q!=0; push @ptr,$q } $cnt=scalar(@ptr); $CNT{$s}=$cnt;   # 0000 entries are placeholders (scenes 4 and 6 have real boxes after them)
  my $src=$R[0x18F2+$s]; my $srcoff=$src*0x4000;
  for my $id (0..$cnt-1){ my @bytes;
    if($ptr[$id]==0){ die sprintf("scene %d id %02X: placeholder entry (0000) cannot have a translation\n",$s,$id) if exists $S{$s}{$id}; push @{$BOX{$s}},undef; next }
    if(exists $S{$s}{$id}){ my $txt=$S{$s}{$id}; my $width=14; my $maxl=3; if($txt=~s/^!18//){ $width=18; $maxl=3 }
      my $p=paginate($txt,$maxl,$width); $splits++ if $p ne $txt; my ($o,$lines)=enc($p);
      for my $k (0..$#$lines){ die sprintf("scene %d id %02X: line %d has %d columns (max %d): %s\n",$s,$id,$k+1,$lines->[$k],$width,$txt) if $lines->[$k]>$width } @bytes=@$o }
    else { my $q=$ptr[$id]; my $l=0; $l++ while $R[$srcoff+$q-0x4000+$l]!=0xFE && $l<300;
      if($l>=300){ @bytes=(0xFE) } else { @bytes=@R[$srcoff+$q-0x4000 .. $srcoff+$q-0x4000+$l]; $warn++; printf("  warning: scene %d id %02X has no translation in the script (kept)\n",$s,$id) } }
    push @{$BOX{$s}},\@bytes }
  for my $id (keys %{$S{$s}}){ die sprintf("scene %d: id %02X does not exist (list has %d)\n",$s,$id,$cnt) if $id>=$cnt } }
# ---- shared block: scenes 0 and 1 starting at $4000 (same address in all banks) ----
my @shared; my %ADDR;
for my $s (@SHARED){ for my $id (0..$CNT{$s}-1){ my $b=$BOX{$s}[$id]; if(!$b){ $ADDR{$s}[$id]=0; next } $ADDR{$s}[$id]=0x4000+@shared; push @shared,@$b } }
my $sharedEnd=0x4000+@shared;
printf("shared block (scenes %s): %d bytes, %04X-%04X, replicated in all banks\n",join('+',@SHARED),scalar(@shared),0x4000,$sharedEnd-1);
# ---- build each bank ----
for my $s (sort{$a<=>$b} keys %order){
  my $nb=0x22+$s; die "invalid bank $nb\n" if $nb>=0x3F; my $nboff=$nb*0x4000;
  $R[$nboff+$_]=0 for 0..0x3FFF;
  $R[$nboff+$_]=$shared[$_] for 0..$#shared;
  my $w=$sharedEnd; my $own=0;
  unless(grep{$_==$s}@SHARED){ for my $id (0..$CNT{$s}-1){ my $b=$BOX{$s}[$id]; if(!$b){ $ADDR{$s}[$id]=0; next } die sprintf("scene %d: no room in bank %02X (id %02X)\n",$s,$nb,$id) if $w+@$b>0x8000;
      $R[$nboff+$w-0x4000+$_]=$b->[$_] for 0..$#$b; $ADDR{$s}[$id]=$w; $w+=@$b; $own+=@$b } }
  for my $id (0..$CNT{$s}-1){ my $a=$ADDR{$s}[$id]; $R[$LB+$ST{$s}-0x4000+2*$id]=$a&0xFF; $R[$LB+$ST{$s}-0x4000+2*$id+1]=$a>>8 }
  $R[0x18F2+$s]=$nb;
  printf("scene %2d: bank %02X, %d boxes, %d own bytes after the block, %d free\n",$s,$nb,$CNT{$s},$own,0x8000-$w) }
# scenes not relocated (9 = list in RAM, 19-25 empty/duplicated): point them to a bank that has the shared block
my %bankOfList; $bankOfList{$ST{$_}}=0x22+$_ for keys %order;
for my $s (0..26){ next if $order{$s}; my $nb=$bankOfList{$start[$s]} // 0x22; printf("scene %2d: not relocated, bank %02X -> %02X (shared block)\n",$s,$R[0x18F2+$s],$nb); $R[0x18F2+$s]=$nb }
printf("pages split automatically (>3 lines): %d\n",$splits);
for my $i (0..$#R){ next if $i==0x14E||$i==0x14F; $sum+=$R[$i] } $sum&=0xFFFF; $R[0x14E]=$sum>>8; $R[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@R); close $o; printf("written %s (checksum %04X)%s\n",$out,$sum,$warn?" with $warn warnings":"");
