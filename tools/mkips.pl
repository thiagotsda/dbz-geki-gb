# usage: perl tools/mkips.pl <original.gb> <translated.gb> <output.ips>
# Generates an IPS patch (with RLE records for repeated runs). The translated ROM may be larger than the
# original (expansion to 1 MB): the IPS simply writes past the end.
use strict; use warnings;
my ($orig,$new,$out)=@ARGV; die "usage: mkips.pl original translated output.ips\n" unless $out;
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; my $d=do{local $/;<$f>}; close $f; $d }
my $A=slurp($orig); my $B=slurp($new); die "translated ROM smaller than the original\n" if length($B)<length($A);
my $n=length($B); my @recs; my $i=0; my $bytes=0;
while($i<$n){
  my $same = $i<length($A) && substr($A,$i,1) eq substr($B,$i,1);
  if($same){ $i++; next }
  # start of a differing run: extend while different (tolerating up to 4 equal bytes in between)
  my $s=$i; my $e=$i;
  while($e<$n){ my $eq=0; while($e+$eq<$n && $e+$eq<length($A) && substr($A,$e+$eq,1) eq substr($B,$e+$eq,1)){ $eq++ } last if $eq>4 || $e+$eq>=$n; $e+=$eq+1 }
  $e=$n if $e>$n;
  # split into records of up to 65535 bytes, using RLE when there are >= 16 equal bytes
  my $p=$s;
  while($p<$e){ my $c=substr($B,$p,1); my $r=1; $r++ while $p+$r<$e && substr($B,$p+$r,1) eq $c && $r<65535;
    if($r>=16){ push @recs,[$p,'rle',$r,$c]; $p+=$r; next }
    my $len=$e-$p; $len=65535 if $len>65535;
    # cut before a long RLE sequence
    for my $k (1..$len-1){ my $cc=substr($B,$p+$k,1); my $rr=1; $rr++ while $p+$k+$rr<$e && substr($B,$p+$k+$rr,1) eq $cc && $rr<16; if($rr>=16){ $len=$k; last } }
    push @recs,[$p,'raw',$len,substr($B,$p,$len)]; $p+=$len }
  $i=$e }
open(my $o,'>:raw',$out) or die; print $o "PATCH";
for my $r (@recs){ my ($off,$t,$len,$d)=@$r; die sprintf("offset %X is the IPS EOF marker\n",$off) if $off==0x454F4F; die "offset > 16 MB\n" if $off>0xFFFFFF;
  print $o pack('CCC',($off>>16)&0xFF,($off>>8)&0xFF,$off&0xFF);
  if($t eq 'rle'){ print $o pack('n',0),pack('n',$len),$d } else { print $o pack('n',$len),$d } $bytes+=$len }
print $o "EOF"; close $o;
printf("%s: %d records, %d bytes covered, %d bytes of patch\n",$out,scalar(@recs),$bytes,-s $out);
