# usage: perl tools/splitreport.pl translation/scene*.tsv   -> lists the pages split by reloc.pl
# whose cut landed in the middle of a sentence (M) or produced a 1-line page (O): candidates for manual pagination.
use strict; use warnings;
my $src=do{ open(my $f,'<','tools/reloc.pl') or die; local $/; <$f> }; my ($fn)=$src=~/(sub wlen .*?\n  join\('<FB>',\@pages\) \}\n)/s; die "could not find paginate in reloc.pl\n" unless $fn; eval $fn; die $@ if $@;
my ($tot,$bad,$orph)=(0,0,0);
for my $file (@ARGV){ open(my $t,'<',$file) or die; while(my $l=<$t>){ chomp $l; next if $l=~/^\s*(#|$)/; my ($s,$id,$txt)=split /\t/,$l,3; $txt//=''; my $max=3; my $w=$txt; my $width=14; if($w=~s/^!18(\/3)?//){ $width=18; $max=$1?3:2 }
  my $p=paginate($w,$max,$width); next if $p eq $w; $tot++; my @pg=split /<FB>/,$p,-1; my $flag='';
  for my $i (0..$#pg-1){ my $e=$pg[$i]; $e=~s/.*\|//; $flag.='M' unless $e=~/[.!?,]$/ } $flag.='O' if grep{ !/\|/ && length }@pg;
  if($flag){ $bad++ if $flag=~/M/; $orph++ if $flag=~/O/; printf("%s\tscene %s id %s\t%s\t%s\n",$flag,$s,$id,$file,$p) } } close $t }
print STDERR "split: $tot; cut in the middle of a sentence: $bad; with a 1-line page: $orph\n";
