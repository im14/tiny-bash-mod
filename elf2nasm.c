#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <sys/mman.h>
#include <string.h>
#include <elf.h> 

#define SECTION_SEEK(s,o) do{\
    opos = ftell(fp);\
    fseek(fp, o, SEEK_SET);\
    pos = ftell(fp);\
    printf("; end@0x%x\n\n%s_sz equ $ - $$\n", opos, g_section);\
    printf("section %s start=0x%"PRIx64"\n", #s, pos);\
    printf("%s_addr equ $\n\n", #s);\
    g_section=#s;\
  }while(0)

#define _DATA(a,b,c,d,e) printf(#a " " #b "%-" #c d " ; " #e "\n", s.e)

#define UCHAR(x)  _DATA(db,   , 22, PRIu8 , x)
#define HALF(x)   _DATA(dw,   , 22, PRIu16, x)
#define SHALF(x)  _DATA(dw,   , 22, PRId16, x)
#define WORD(x)   _DATA(dd,   , 22, PRIu32, x)
#define SWORD(x)  _DATA(dd,   , 22, PRId32, x)
#define ADDR(x)   _DATA(dq, 0x, 20, PRIx64, x)
#define OFF(x)    _DATA(dq,   , 22, PRIu64, x)
#define XWORD(x)  _DATA(dq,   , 22, PRIu64, x)
#define SXWORD(x) _DATA(dq,   , 22, PRId64, x)

char *g_section;
Elf64_Word g_nchain = 0; // needed for DT_SYMTAB size
char *g_mmstrtab;

void print_ehdr(Elf64_Ehdr s) {
  for (int i = 0; i < EI_NIDENT; i++) {
    UCHAR(e_ident[i]);
  }
  HALF(e_type);
  HALF(e_machine);
  WORD(e_version);
  XWORD(e_entry);
  XWORD(e_phoff);
  XWORD(e_shoff);
  WORD(e_flags);
  HALF(e_ehsize);
  HALF(e_phentsize);
  HALF(e_phnum);
  HALF(e_shentsize);
  HALF(e_shnum);
  HALF(e_shstrndx);
}

void print_phdr(Elf64_Phdr s) {
  WORD(p_type);
  WORD(p_flags);
  XWORD(p_offset);
  XWORD(p_vaddr);
  XWORD(p_paddr);
  XWORD(p_filesz);
  XWORD(p_memsz);
  XWORD(p_align);
}

void print_shdr(Elf64_Shdr s) {
  WORD(sh_name);
  WORD(sh_type);
  XWORD(sh_flags);
  ADDR(sh_addr);
  OFF(sh_offset);
  XWORD(sh_size);
  WORD(sh_link);
  WORD(sh_info);
  XWORD(sh_addralign);
  XWORD(sh_entsize);
}

void print_dyn(Elf64_Dyn s) {
//  XWORD(d_tag);
//  XWORD(d_un.d_val);
  printf("dq 0x%"PRIx64",0x%"PRIx64"\n", s.d_tag, s.d_un.d_val);
}

void print_rela(Elf64_Rela s) {
  ADDR(r_offset);
  XWORD(r_info);
  SXWORD(r_addend);
}

void print_sym(Elf64_Sym s) {
//  printf("; '%s'\n", g_mmstrtab[s.st_name]);
  WORD(st_name);
  UCHAR(st_info);
  UCHAR(st_other);
  HALF(st_shndx); // XXX Elf64_Section
  ADDR(st_value);
  XWORD(st_size);
}

void myread(void *ptr, size_t size, size_t nmemb, FILE* restrict stream) {
  if (fread(ptr, size, nmemb, stream) != nmemb) {
    perror("fread");
    exit(1);
  }
}

void decode_hash(FILE* fp, uint64_t d[]) {
  Elf64_Word nbucket, nchain;
  Elf64_Word  bucket,  chain;
  int pos, opos, i;

  printf("; HASH   @ %x\n", d[DT_HASH]);
  SECTION_SEEK(hash, d[DT_HASH]);

  myread(&nbucket, sizeof(nbucket), 1, fp);
  myread(&nchain,  sizeof(nchain),  1, fp);
  g_nchain = nchain;
  printf("dd %-22"PRIx32" ; nbucket\n", nbucket);
  printf("dd %-22"PRIx32" ; nchain\n", nchain);
  for (i = 0; i < nbucket; i++) {
    myread(&bucket, sizeof(chain), 1, fp);
    printf("dd %-22"PRIx32" ; bucket[%d]\n", bucket, i);
  }
  for (i = 0; i < nchain; i++) {
    myread(&chain, sizeof(chain), 1, fp);
    printf("dd %-22"PRIx32" ;  chain[%d]\n", chain, i);
  }
}

void decode_rela(FILE* fp, uint64_t d[]) {
  Elf64_Rela r;
  int opos, pos, i;

  printf("; RELA   @ %x\n", d[DT_RELA]);
  printf(";   %d/%d = %d entries\n", d[DT_RELASZ], d[DT_RELAENT], d[DT_RELASZ] / d[DT_RELAENT]);

  SECTION_SEEK(rela, d[DT_RELA]);
  for (int i = 0; i < d[DT_RELASZ]; i += d[DT_RELAENT]) {
    myread(&r, d[DT_RELAENT], 1, fp);
    printf("\n.rela%d:\n", i / d[DT_RELAENT]);
    print_rela(r);
  }
}

void decode_symtab(FILE* fp, uint64_t d[]) {
  Elf64_Sym s;
  int opos, pos, i;

  printf("; SYMTAB @ %x\n", d[DT_SYMTAB]);
  printf(";  size/entry = %d\n", d[DT_SYMENT]);
  SECTION_SEEK(symtab, d[DT_SYMTAB]);
  for (i = 0; i < g_nchain; i++) {
    myread(&s, d[DT_SYMENT], 1, fp);
    printf("\n.sym%d:\n", i);
    print_sym(s);
  }
}

void decode_strtab(FILE* fp, uint64_t d[]) {
  int opos, pos, i = 0;
  char *mmbase = mmap(0, d[DT_STRTAB] + d[DT_STRSZ], PROT_READ, MAP_PRIVATE, fileno(fp), 0);
  char *mm = mmbase + d[DT_STRTAB];

  if (mmbase == MAP_FAILED) {
    perror("mmap");
    exit(1);
  }
  g_mmstrtab = mm;
  printf("; STRTAB @ %x\n", d[DT_STRTAB]);
  printf(";  size = %d\n", d[DT_STRSZ]);

  SECTION_SEEK(strtab, d[DT_STRTAB]);

  if (mm[i] == 0) { // it better be...
    printf(".undef:\n");
    printf(".str0: db 0 ; undef entry\n");
  }
  for (i = 1; i < d[DT_STRSZ]; i+=1+strlen(mm+i)) {
    printf(".str%d: db '%s',0\n", i, mm+i);
  }
}

void decode_dynamic(FILE* fp, uint64_t d[]) {
  int pos, opos;

  // the mandatory pointers
  if (d[DT_HASH]) {
    // hash's nchain is needed before decode_symtab
    decode_hash(fp, d);
  }
  if (d[DT_STRTAB]) {
    decode_strtab(fp, d);
  }
  if (d[DT_SYMTAB]) {
    if (g_nchain) {
      decode_symtab(fp, d);
    } else {
      printf("; no nchain. I don't know how to read SYMTAB :(\n");
    }
  }
  if (d[DT_RELA]) {
    decode_rela(fp, d);
  }
}

int main(int argc, char **argv) {
  FILE* fp;
  int opos, pos, i, j;
  uint64_t dynamic[19];
  Elf64_Dyn dyn;
  Elf64_Ehdr ehdr;
  Elf64_Off dynaddr = 0;
  Elf64_Word dynsize = 0;

  if (argc != 2) {
    printf("usage: dump <elf>\n");
    exit(1);
  }
  fp = fopen(argv[1], "rb");
  if(fp == NULL) {
      printf("failed to load\n");
      exit(1);
  }
  
  g_section = "EHdr";
  printf("BITS 64\n\n");
  printf("section EHdr start=0\n");
  printf("EHdr_addr equ $\n");
  myread(&ehdr, sizeof(ehdr), 1, fp);
  print_ehdr(ehdr);

  SECTION_SEEK(PHdr, ehdr.e_phoff);

  for (i = 0; i < ehdr.e_phnum; i++) {
    Elf64_Phdr phdr;
    myread(&phdr, sizeof(phdr), 1, fp);
    print_phdr(phdr);

    // let's look into this next
    if (phdr.p_type == PT_DYNAMIC) {
      dynaddr = phdr.p_offset;
      dynsize = phdr.p_filesz;
    }
  }

  if (dynaddr && dynsize) {
    SECTION_SEEK(dynamic, dynaddr);

    for (j = 0; j < dynsize; j += sizeof(Elf64_Dyn)) {
      myread(&dyn, sizeof(dyn), 1, fp);
      print_dyn(dyn);

      // remember some parts and decode them later
      // XXX mmap this
      if (dyn.d_tag < 20) {
        dynamic[dyn.d_tag] = dyn.d_un.d_ptr;
      }
    }
    fseek(fp, opos, SEEK_SET);
    decode_dynamic(fp, dynamic);
  }

  if (ehdr.e_shoff) {
    SECTION_SEEK(SHdr, ehdr.e_shoff);
  
    for (int i = 0; i < ehdr.e_shnum; i++) {
      Elf64_Shdr shdr;
      myread(&shdr, sizeof(shdr), 1, fp);
      pos = ftell(fp);
      printf("\n; @0x%x\n", pos);
      print_shdr(shdr);
    }
  }
  
  return 0;
}
