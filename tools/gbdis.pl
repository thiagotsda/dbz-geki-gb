# usage: perl tools/gbdis.pl ROM start_file_offset length [bank_base_addr]
use strict; use warnings;
my ($rom,$start,$len,$base)=@ARGV; $start=hex($start); $len=hex($len); $base = defined $base ? hex($base) : ($start<0x4000 ? 0 : 0x4000 - ($start & 0x3FFF) + ($start&0x3FFF));
open(my $f,'<:raw',$rom) or die; local $/; my $d=<$f>; my @B=unpack('C*',$d);
my @r8=qw(b c d e h l (hl) a); my @r16=qw(bc de hl sp); my @r16p=qw(bc de hl af); my @cc=qw(nz z nc c);
my @alu=qw(add adc sub sbc and xor or cp); my @cb=qw(rlc rrc rl rr sla sra swap srl);
sub addr { my $o=shift; return $start<0x4000 ? $o : 0x4000+($o & 0x3FFF) }
my $p=$start; my $end=$start+$len;
while($p<$end){
  my $o=$B[$p]; my $a=addr($p); my ($s,$n)=("",1);
  my $imm8=$B[$p+1]//0; my $imm16=($B[$p+1]//0)|(($B[$p+2]//0)<<8);
  my $x=$o>>6; my $y=($o>>3)&7; my $z=$o&7;
  if($o==0x00){$s="nop"} elsif($o==0x10){$s="stop";$n=2} elsif($o==0x76){$s="halt"}
  elsif($o==0x08){$s=sprintf("ld (\$%04X),sp",$imm16);$n=3}
  elsif($o==0x18){$s=sprintf("jr \$%04X",$a+2+(($imm8^0x80)-0x80));$n=2}
  elsif($o>=0x20&&$o<=0x38&&$z==0){$s=sprintf("jr %s,\$%04X",$cc[$y-4],$a+2+(($imm8^0x80)-0x80));$n=2}
  elsif($x==0&&$z==1){ if($y&1){$s="add hl,".$r16[$y>>1]} else {$s=sprintf("ld %s,\$%04X",$r16[$y>>1],$imm16);$n=3} }
  elsif($x==0&&$z==2){ my @m=("(bc)","(de)","(hl+)","(hl-)"); $s = ($y&1) ? "ld a,$m[$y>>1]" : "ld $m[$y>>1],a" }
  elsif($x==0&&$z==3){ $s = ($y&1) ? "dec ".$r16[$y>>1] : "inc ".$r16[$y>>1] }
  elsif($x==0&&$z==4){$s="inc $r8[$y]"} elsif($x==0&&$z==5){$s="dec $r8[$y]"}
  elsif($x==0&&$z==6){$s=sprintf("ld %s,\$%02X",$r8[$y],$imm8);$n=2}
  elsif($x==0&&$z==7){$s=(qw(rlca rrca rla rra daa cpl scf ccf))[$y]}
  elsif($x==1){$s="ld $r8[$y],$r8[$z]"}
  elsif($x==2){$s="$alu[$y] $r8[$z]"}
  elsif($x==3&&$z==0){ if($y<4){$s="ret $cc[$y]"} elsif($y==4){$s=sprintf("ldh (\$FF%02X),a",$imm8);$n=2} elsif($y==5){$s=sprintf("add sp,%d",($imm8^0x80)-0x80);$n=2} elsif($y==6){$s=sprintf("ldh a,(\$FF%02X)",$imm8);$n=2} else {$s=sprintf("ld hl,sp%+d",($imm8^0x80)-0x80);$n=2} }
  elsif($x==3&&$z==1){ if($y&1){$s=(qw(ret reti jp_hl ld_sp_hl))[$y>>1]; $s="jp (hl)" if $s eq 'jp_hl'; $s="ld sp,hl" if $s eq 'ld_sp_hl'} else {$s="pop ".$r16p[$y>>1]} }
  elsif($x==3&&$z==2){ if($y<4){$s=sprintf("jp %s,\$%04X",$cc[$y],$imm16);$n=3} elsif($y==4){$s="ldh (c),a"} elsif($y==5){$s=sprintf("ld (\$%04X),a",$imm16);$n=3} elsif($y==6){$s="ldh a,(c)"} else {$s=sprintf("ld a,(\$%04X)",$imm16);$n=3} }
  elsif($x==3&&$z==3){ if($y==0){$s=sprintf("jp \$%04X",$imm16);$n=3} elsif($y==1){ my $c=$B[$p+1]; my $cy=($c>>3)&7; my $cz=$c&7; my $cx=$c>>6; $s = $cx==0 ? "$cb[$cy] $r8[$cz]" : $cx==1 ? "bit $cy,$r8[$cz]" : $cx==2 ? "res $cy,$r8[$cz]" : "set $cy,$r8[$cz]"; $n=2} elsif($y==6){$s="di"} elsif($y==7){$s="ei"} else {$s="??"} }
  elsif($x==3&&$z==4){ if($y<4){$s=sprintf("call %s,\$%04X",$cc[$y],$imm16);$n=3} else {$s="??"} }
  elsif($x==3&&$z==5){ if($y&1){ if($y==1){$s=sprintf("call \$%04X",$imm16);$n=3} else {$s="??"} } else {$s="push ".$r16p[$y>>1]} }
  elsif($x==3&&$z==6){$s=sprintf("%s \$%02X",$alu[$y],$imm8);$n=2}
  elsif($x==3&&$z==7){$s=sprintf("rst \$%02X",$y*8)}
  my $hex=join(" ",map{sprintf("%02X",$B[$p+$_])}0..$n-1);
  printf("%06X  %04X  %-9s %s\n",$p,$a,$hex,$s); $p+=$n;
}
