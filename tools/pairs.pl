# usage: perl tools/pairs.pl <translated_rom> > dumps/review-pairs.tsv
# Compares the original game file (ORIGINAL_ROM) with the translated ROM and lists each translated text line:
#   offset  bank  budget  JAPANESE  ENGLISH  terminator
# Lines are delimited by control bytes >= 0xFB (FD line break, FE end of box, FB).
use strict; use warnings; use utf8; binmode STDOUT,':utf8';
my $rom=shift or die "usage: pairs.pl rom\n";
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; local $/; my $d=<$f>; close $f; [unpack('C*',$d)] }
my $J=slurp(($ENV{ORIGINAL_ROM} // die "set ORIGINAL_ROM to the path of the original game file\n")); my $E=slurp($rom);
my @kana=split //,"　あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんっゃゅょァィゥェォアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンッャュョァィゥェォー０１２３４５６７８９…・。？！゛";
my @hd=split //,"がぎぐげござじずぜぞだぢづでどばびぶべぼ"; my @kd=split //,"ガギグゲゴザジズゼゾダヂヅデドバビブベボ";
my %T; $T{$_}=$kana[$_] for 0..0x7F; $T{0xB0+$_}=$hd[$_] for 0..19; $T{0xC4+$_}=$kd[$_] for 0..19;
my @hh=split //,"ぱぴぷぺぽ"; my @kh=split //,"パピプペポ"; $T{0xD8+$_}=$hh[$_] for 0..4; $T{0xDD+$_}=$kh[$_] for 0..4;
sub jp { my $b=shift; return $T{$b} if defined $T{$b}; sprintf("<%02X>",$b) }
sub en { my $b=shift; return ' ' if $b==0; return chr(0x60+$b) if $b>=1&&$b<=26; return chr(0x30+$b-0x70) if $b>=0x70&&$b<=0x79;
  return '.' if $b==0x7A; return '?' if $b==0x7D; return '!' if $b==0x7E; return '…' if $b==0x7B; sprintf("<%02X>",$b) }
my $n=@$J; my $i=0; my $last=-1;
# only the original ROM (512K) matters for the diff; the 0x21 mirror is a copy of bank 03
while($i<$n){
  if($J->[$i]!=$E->[$i]){
    my ($s,$e)=($i,$i); while($e+1<$n && ($J->[$e+1]!=$E->[$e+1] || ($e+2<$n && $J->[$e+2]!=$E->[$e+2]))){ $e++ }
    # extend to a control byte >= 0xFB (limit 24 bytes per side)
    my ($a,$b)=($s,$e); my $k=0; while($a>0 && $J->[$a-1]<0xFB && $k<24){ $a--; $k++ } $k=0; while($b+1<$n && $J->[$b+1]<0xFB && $k<24){ $b++; $k++ }
    my $term = $b+1<$n ? $J->[$b+1] : 0; my $bank=int($a/0x4000);
    next if $bank>=7 && $bank<0x20; # graphics
    my $jt=join('',map{jp($J->[$_])}$a..$b); my $et=join('',map{en($E->[$_])}$a..$b);
    printf("%06X\t%02X\t%d\t%s\t%s\t%02X\n",$a,$bank,$b-$a+1,$jt,$et,$term);
    $i=$b+1; next }
  $i++ }
