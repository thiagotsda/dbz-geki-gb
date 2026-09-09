# usage: perl tools/scenes.pl <translated_rom> [summary]
# Walks the master scene table (bank 03, $4000), the bank-per-scene table ($18F2)
# and lists each box: scene, id, bank, address, JP (rom/DB.gb) and EN (translated rom).
# With a second argument (e.g. "summary"), only prints totals per scene.
use strict; use warnings; use utf8; binmode STDOUT,':utf8';
my ($rom,$mode)=@ARGV; $rom or die "usage: scenes.pl rom [summary]\n";
sub slurp { my $fn=shift; open(my $f,'<:raw',$fn) or die "$fn: $!"; local $/; my $d=<$f>; close $f; [unpack('C*',$d)] }
my $J=slurp('rom/DB.gb'); my $E=slurp($rom);
my @kana=split //,"　あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんっゃゅょァィゥェォアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンッャュョァィゥェォー０１２３４５６７８９…・。？！゛";
my @hd=split //,"がぎぐげござじずぜぞだぢづでどばびぶべぼ"; my @kd=split //,"ガギグゲゴザジズゼゾダヂヅデドバビブベボ";
my %T; $T{$_}=$kana[$_] for 0..0x7F; $T{0xB0+$_}=$hd[$_] for 0..19; $T{0xC4+$_}=$kd[$_] for 0..19;
my @hh=split //,"ぱぴぷぺぽ"; my @kh=split //,"パピプペポ"; $T{0xD8+$_}=$hh[$_] for 0..4; $T{0xDD+$_}=$kh[$_] for 0..4;
sub jp { my $b=shift; return '|' if $b==0xFD; return '' if $b==0xFE; return '<N>' if $b==0xE3; return '<#>' if $b==0xE2; return '<FB>' if $b==0xFB; return $T{$b} if defined $T{$b}; sprintf("<%02X>",$b) }
sub en { my $b=shift; return '|' if $b==0xFD; return '' if $b==0xFE; return '<N>' if $b==0xE3; return '<#>' if $b==0xE2; return '<FB>' if $b==0xFB; return ' ' if $b==0; return chr(0x60+$b) if $b>=1&&$b<=26; return chr(0x40+$b-0x1A) if $b>=0x1B&&$b<=0x34;
  return chr(0x30+$b-0x70) if $b>=0x70&&$b<=0x79; return '...' if $b==0x7A; return ',' if $b==0x7B; return '.' if $b==0x7C; return '?' if $b==0x7D; return '!' if $b==0x7E; return "'" if $b==0x7F; return '-' if $b==0x6F; return $T{$b} if defined $T{$b}; sprintf("<%02X>",$b) }
sub fileoff { my ($bank,$addr)=@_; $bank*0x4000 + ($addr-0x4000) }
my $M=0xC000; my @start; for my $s (0..26){ $start[$s]=$J->[$M+2*($s+1)]|($J->[$M+2*($s+1)+1]<<8) }  # scene s -> entry s+1 (entry 0 = ids >= C0)
my @bank=map{ $J->[0x18F2+$_] } 0..27; my @ebank=map{ $E->[0x18F2+$_] } 0..27; my $LB=0x84000; my @estart; for my $s (0..26){ $estart[$s]=$E->[$LB+2*($s+1)]|($E->[$LB+2*($s+1)+1]<<8) }
# count = next list start (among all of them) minus this start
my @sorted=sort{$a<=>$b} grep{$_>=0x4000&&$_<0x8000} @start;
my $total=0;
for my $s (0..27){ my $st=$start[$s]; if($st<0x4000||$st>=0x8000){ printf("# scene %2d: table %04X outside the ROM (RAM)\n",$s,$st); next }
  my ($next)=grep{$_>$st}@sorted; my $cnt = $next ? int(($next-$st)/2) : 0;
  # limit the count to valid, increasing text pointers
  my @ptr; for my $k (0..$cnt-1){ my $q=$J->[$M+$st-0x4000+2*$k]|($J->[$M+$st-0x4000+2*$k+1]<<8); last if $q<0x4000||$q>=0x8000; push @ptr,$q }
  my ($jb,$eb)=(0,0); my ($lo,$hi)=(0xFFFF,0); my $untr=0;
  my @rows;
  for my $id (0..$#ptr){ my $q=$ptr[$id]; my $fo=fileoff($bank[$s],$q); my ($jt,$et)=('',''); my $l=0;
    while($l<400){ my $b=$J->[$fo+$l]; last unless defined $b; $jt.=jp($b); $l++; last if $b==0xFE }
    my $eq=$E->[$LB+$estart[$s]-0x4000+2*$id]|($E->[$LB+$estart[$s]-0x4000+2*$id+1]<<8); my $efo=fileoff($ebank[$s],$eq); my $el=0;
    while($el<600){ my $b=$E->[$efo+$el]; last unless defined $b; $et.=en($b); $el++; last if $b==0xFE }
    $jb+=$l; $lo=$q if $q<$lo; $hi=$q+$l if $q+$l>$hi; my $same=1; for my $k (0..$l-1){ if($J->[$fo+$k]!=$E->[$fo+$k]){$same=0;last} } $untr++ if $same;
    push @rows,sprintf("%2d\t%02X\t%02X\t%04X\t%d\t%s\t%s\n",$s,$id,$bank[$s],$q,$l,$jt,$et) }
  printf("# scene %2d: bank %02X, list %04X, %d boxes, %d JP bytes, range %04X-%04X, %d boxes identical to JP\n",$s,$bank[$s],$st,scalar(@ptr),$jb,$lo,$hi,$untr);
  $total+=$jb; print @rows unless $mode; }
printf("# total %d JP bytes\n",$total);
