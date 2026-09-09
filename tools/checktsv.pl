# usage: perl tools/checktsv.pl translation/scene*.tsv
# Checks widths (14 columns; 18 with the !18 prefix) and counts pages over the line limit
# (3 lines, any width). Those are split automatically by reloc.pl, but it is better to adjust by hand
# when the split lands in the middle of a sentence.
use strict; use warnings; my $W = (@ARGV && $ARGV[0]=~/^\d+$/) ? shift : 14; my ($n,$over)=(0,0);
for my $fn (@ARGV){
  open(my $t,"<",$fn) or die "$fn: $!";
  while(my $l=<$t>){ chomp $l; $l=~s/\r$//; next if $l=~/^\s*(#|$)/; my ($s,$id,$txt)=split /\t/,$l,3; $txt="" unless defined $txt;
    my $w=$W; my $maxl=3; if($txt=~s/^!18//){ $w=18; $maxl=3 }
    for my $pg (split /<FB>/,$txt){ my @lines=split /\|/,$pg; $over++ if @lines>$maxl }
    my @lines=split /\||<FB>/,$txt; my $k=0;
    for my $ln (@lines){ $k++; my $c=$ln; $c=~s/\.\.\./x/g; $c=~s/<N>/xxxxxx/g; $c=~s/<#>/xxx/g;
      if(length($c)>$w){ printf("%s scene %s id %s line %d: %d columns: %s\n",$fn,$s,$id,$k,length($c),$ln); $n++ } } }
  close $t }
print "$n lines over the column limit; $over pages over the line limit (they will be split by reloc.pl)\n";
