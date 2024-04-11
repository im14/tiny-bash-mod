#!/bin/bash
in=su.asm
obj=su.o
out=s

# TODO: could probably save more room if the section was removed properly from headers
rmshstrtab() {
  end=$(strings -t d "$out" | awk '$2 == ".shstrtab" {print $1}')
  dd if=$out bs=1 count=$end 2>/dev/null
}

nasm -f elf64 -o "$obj" "$in"
ld -v -T ld.t --hash-style=sysv -shared -o "$out" "$obj"
strip "$out"
rmshstrtab < "$out" > "$out.noshstrtab"

declare -A code=() msg=()
min=0
for cmd in gzip:gunzip bzip2:bunzip; do
  zip=${cmd%:*} unzip=${cmd#*:}
  printf 'Determining smallest %s...' "$zip"
  zipmin=0
  for ((i = 1; i <= 9; i++)); do
    k="$zip -$i"
    z=$(rmshstrtab | $k -c | base64 -w 0)
    code[$k]=$z
    msg[$k]="# recode /64<<<${z}|$unzip>$out;enable -f./$out $out;$out;>/z;id"
    ((${#code[$k]} < zipmin || zipmin == 0)) && zipmin=${#code[$k]}
    ((${#msg[$k]} < min || min == 0)) && {
      min=${#msg[$k]}
      km=$k
    }
  done
  printf ' %d\n' $zipmin
done

printf 'smallest code=%d msg=%d produced by: %s\n' ${#code[$km]} ${#msg[$km]} "$km"
echo "${msg[$km]}"
