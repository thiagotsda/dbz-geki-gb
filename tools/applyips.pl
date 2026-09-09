# usage: perl tools/applyips.pl <rom.gb> <patch.ips> <output.gb>   (to verify the patch)
use strict; use warnings;
my ($rom,$ips,$out)=@ARGV; die "usage\n" unless $out;
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; my $d=do{local $/;<$f>}; close $f; $d }
my $R=slurp($rom); my $P=slurp($ips); die "not an IPS file\n" unless substr($P,0,5) eq 'PATCH'; my $p=5;
while($p<length($P)){ my $tag=substr($P,$p,3); last if $tag eq 'EOF'; my ($h,$m,$l)=unpack('CCC',$tag); my $off=($h<<16)|($m<<8)|$l; $p+=3;
  my $len=unpack('n',substr($P,$p,2)); $p+=2; my $data;
  if($len==0){ my $rl=unpack('n',substr($P,$p,2)); $p+=2; $data=substr($P,$p,1) x $rl; $p++ } else { $data=substr($P,$p,$len); $p+=$len }
  $R.="\0" x ($off+length($data)-length($R)) if $off+length($data)>length($R); substr($R,$off,length($data))=$data }
open(my $o,'>:raw',$out) or die; print $o $R; close $o; printf("applied: %s (%d bytes)\n",$out,length($R));
