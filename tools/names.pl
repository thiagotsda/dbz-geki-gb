# usage: perl tools/names.pl <rom_in> <rom_out> translation/names.tsv
# Name table: 31 fields of 6 bytes at $4041 of bank 03 (file 0xC041) and in the 0x21 mirror (0x84041).
use strict; use warnings;
my ($in,$out,$tab)=@ARGV; die "usage\n" unless $tab;
open(my $f,'<:raw',$in) or die; my $d=do{local $/;<$f>}; close $f; my @R=unpack('C*',$d);
sub enc1 { my $c=shift; return ord($c)-0x60 if $c=~/[a-z]/; return ord($c)-0x40+0x1A if $c=~/[A-Z]/; return 0x70+$c if $c=~/[0-9]/; return 0 if $c eq ' '; die "char '$c'\n" }
open(my $t,'<',$tab) or die; my $n=0;
while(my $l=<$t>){ chomp $l; next if $l=~/^\s*(#|$)/; my ($i,$name)=split /\t/,$l; die "name '$name' > 6\n" if length($name)>6;
  my @b=map{enc1($_)}split //,$name; push @b,0 while @b<6;
  for my $base (0xC041,0x84041){ $R[$base+6*$i+$_]=$b[$_] for 0..5 } $n++ } close $t;
my $sum=0; for my $i (0..$#R){ next if $i==0x14E||$i==0x14F; $sum+=$R[$i] } $sum&=0xFFFF; $R[0x14E]=$sum>>8; $R[0x14F]=$sum&0xFF;
open(my $o,'>:raw',$out) or die; print $o pack('C*',@R); close $o; print "$n names written -> $out\n";
