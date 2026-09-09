# usage: perl tools/fixed.pl <rom_in> <rom_out> translation/fixed.tsv
# Fixed-width texts (bank 04 menus, bank 00 place names, password, battle script
# of resource 21). Each line: offset(hex) <TAB> size <TAB> text. The text is encoded with the
# new font (a-z A-Z 0-9 . , ? ! ' - "..." | <FB> <N> <#> <xx> raw byte) and padded with
# spaces (00) up to the size. Never overflows the field. Bank 03 offsets are mirrored in 0x21.
use strict; use warnings;
my ($in,$out,$tab)=@ARGV; die "usage: fixed.pl rom_in rom_out fixed.tsv\n" unless $tab;
open(my $f,'<:raw',$in) or die; my $d=do{local $/;<$f>}; close $f; my @R=unpack('C*',$d);
sub enc { my $t=shift; my @o;
  while(length $t){
    if($t=~s/^\.\.\.//){ push @o,0x7A }
    elsif($t=~s/^\|//){ push @o,0xFD }
    elsif($t=~s/^<FB>//){ push @o,0xFB }
    elsif($t=~s/^<N>//){ push @o,0xE3 }
    elsif($t=~s/^<#>//){ push @o,0xE2 }
    elsif($t=~s/^<([0-9A-Fa-f]{2})>//){ push @o,hex($1) }
    else { my $c=substr($t,0,1,''); my $b;
      if($c=~/[a-z]/){ $b=ord($c)-0x60 } elsif($c=~/[A-Z]/){ $b=ord($c)-0x40+0x1A } elsif($c eq ' '){ $b=0 }
      elsif($c=~/[0-9]/){ $b=0x70+$c } elsif($c eq ','){ $b=0x7B } elsif($c eq '.'){ $b=0x7C } elsif($c eq '?'){ $b=0x7D }
      elsif($c eq '!'){ $b=0x7E } elsif($c eq "'"){ $b=0x7F } elsif($c eq '-'){ $b=0x6F } else { die "character without glyph: '$c'\n" }
      push @o,$b } }
  \@o }
open(my $t,'<',$tab) or die "$tab: $!"; my ($n,$pad)=(0,0);
while(my $l=<$t>){ chomp $l; $l=~s/\r$//; next if $l=~/^\s*(#|$)/; my ($off,$len,$txt)=split /\t/,$l,3; $txt//='';
  my $o=hex($off); my $e=enc($txt);
  die sprintf("%06X: '%s' is %d bytes, field of %d\n",$o,$txt,scalar(@$e),$len) if @$e>$len;
  my @targets=($o); push @targets,0x84000+($o-0xC000) if $o>=0xC000 && $o<0x10000;
  for my $tg (@targets){ for my $k (0..$len-1){ die sprintf("%06X+%d: field contains control byte %02X\n",$tg,$k,$R[$tg+$k]) if $R[$tg+$k]>=0xFE } }
  for my $tg (@targets){ for my $k (0..$len-1){ $R[$tg+$k] = $k<@$e ? $e->[$k] : 0x00 } }
  $pad+=$len-@$e; $n++ }
close $t;
my $sum=0; for my $i (0..$#R){ next if $i==0x14E||$i==0x14F; $sum+=$R[$i] } $sum&=0xFFFF; $R[0x14E]=$sum>>8; $R[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@R); close $o;
printf("fixed: %d fields written (%d padding bytes) -> %s\n",$n,$pad,$out);
