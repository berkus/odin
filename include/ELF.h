/*
 *  ELF file format structures definitions
 *  According to Portable Formats Specification, version 1.1
 *
 *  Typed in by Stanislav Karchebny <berk@madfire.net>, 2001
 *  This file is in Public Domain.
 */

#ifndef __FF_ELF_H
#define __FF_ELF_H


/*
 * ELF data types
 */
typedef unsigned int    Elf32_Addr;  /* 4 bytes/4 align/unsigned */
typedef unsigned short  Elf32_Half;  /* 2 bytes/2 align/unsigned */
typedef unsigned int    Elf32_Off;   /* 4 bytes/4 align/unsigned */
typedef signed   int    Elf32_Sword; /* 4 bytes/4 align/signed   */
typedef unsigned int    Elf32_Word;  /* 4 bytes/4 align/unsigned */
typedef unsigned char   Elf32_Byte;  /* 1 byte /1 align/unsigned */


/*
 * ELF structures: ELF file Header
 */
typedef struct Elf32_Ehdr
{
   Elf32_Word e_magic;
   Elf32_Byte e_class;
   Elf32_Byte e_data;
   Elf32_Byte e_hdrversion;
   Elf32_Byte e_padding[9];
   Elf32_Half e_type;            /* Identifies object file type */
   Elf32_Half e_machine;         /* Specifies required architecture */
   Elf32_Word e_version;         /* Identifies object file version */
   Elf32_Addr e_entry;           /* Entry point virtual address */
   Elf32_Off  e_phoff;           /* Program header table file offset */
   Elf32_Off  e_shoff;           /* Section header table file offset */
   Elf32_Word e_flags;           /* Processor-specific flags */
   Elf32_Half e_ehsize;          /* ELF header size in bytes */
   Elf32_Half e_phentsize;       /* Program header table entry size */
   Elf32_Half e_phnum;           /* Program header table entry count */
   Elf32_Half e_shentsize;       /* Section header table entry size */
   Elf32_Half e_shnum;           /* Section header table entry count */
   Elf32_Half e_shstrndx;        /* Section header string table index */
};

/* Elf32_Ehdr.e_magic */
#define ELFMAGIC  0x464C457F

/* Elf32_Ehdr.e_class */
#define ELFCLASSNONE 0x00  /* Invalid class  */
#define ELFCLASS32   0x01  /* 32 bit objects */
#define ELFCLASS64   0x02  /* 64 bit objects */

/* Elf32_Ehdr.e_data */
#define ELFDATANONE  0x00  /* Invalid data encoding   */
#define ELFDATA2LSB  0x01  /* LSB (Intel) encoding    */
#define ELFDATA2MSB  0x02  /* MSB (Motorola) encoding */

/* Elf32_Ehdr.e_type */
#define ET_NONE  0x0000      /* No type     */
#define ET_REL   0x0001      /* Relocatable */
#define ET_EXEC  0x0002      /* Executable  */
#define ET_DYN   0x0003      /* Shared      */
#define ET_CORE  0x0004      /* Core        */

/* Elf32_Ehdr.e_machine */
#define EM_NONE  0x0000      /* No machine     */
#define EM_M32   0x0001      /* AT&T WE32100   */
#define EM_SPARC 0x0002      /* SPARC          */
#define EM_386   0x0003      /* x86            */
#define EM_68K   0x0004      /* Motorola 68000 */
#define EM_88K   0x0005      /* Motorola 88000 */
#define EM_860   0x0007      /* Intel 80860    */
#define EM_MIPS  0x0008      /* MIPS RS3000    */

/* Elf32_Ehdr.e_version */
#define EV_CURRENT 0x00000001


/*
 * ELF structures: Section header
 */
typedef struct Elf32_Shdr
{
   Elf32_Word sh_name;           /* Section name, index in string table */
   Elf32_Word sh_type;           /* Type of section */
   Elf32_Word sh_flags;          /* Miscellaneous section attributes */
   Elf32_Addr sh_addr;           /* Section virtual addr at execution */
   Elf32_Off  sh_offset;         /* Section file offset */
   Elf32_Word sh_size;           /* Size of section in bytes */
   Elf32_Word sh_link;           /* Index of another section */
   Elf32_Word sh_info;           /* Additional section information */
   Elf32_Word sh_addralign;      /* Section alignment */
   Elf32_Word sh_entsize;        /* Entry size if section holds table */
};

/* predefined section table indices */
#define SHN_UNDEF     0x0000
#define SHN_LORESERVE 0xff00
#define SHN_LOPROC    0xff00
#define SHN_HIPROC    0xff1f
#define SHN_ABS       0xfff1
#define SHN_COMMON    0xfff2
#define SHN_HIRESERVE 0xffff

/* Elf32_Shdr.sh_type */
#define SHT_NULL      0x00000000
#define SHT_PROGBITS  0x00000001
#define SHT_SYMTAB    0x00000002
#define SHT_STRTAB    0x00000003
#define SHT_RELA      0x00000004
#define SHT_HASH      0x00000005
#define SHT_DYNAMIC   0x00000006
#define SHT_NOTE      0x00000007
#define SHT_NOBITS    0x00000008
#define SHT_REL       0x00000009
#define SHT_SHLIB     0x0000000A
#define SHT_DYNSYM    0x0000000B

/* Elf32_Shdr.sh_flags */
#define SHF_WRITE     0x00000001
#define SHF_ALLOC     0x00000002
#define SHF_EXECINSTR 0x00000004
#define SHF_MASKPROC  0xf0000000


/*
 * ELF structures: Symbol Table
 */
typedef struct Elf32_Sym
{
   Elf32_Word st_name;  /* symbol name, index into string table */
   Elf32_Addr st_value; /* symbol value */
   Elf32_Word st_size;  /* size occupied by this symbol */
   Elf32_Byte st_info;  /* symbol type and binding */
   Elf32_Byte st_other;
   Elf32_Half st_shndx; /* section index this symbol belongs to */
};

/* Symbol Table index: first/undefined entry */
#define STN_UNDEF 0x0000

/* Elf32_Sym.st_info manipulation macros */
#define ELF32_ST_BIND(i)    ((i) >> 4)
#define ELF32_ST_TYPE(i)    ((i) & 0xF)
#define ELF32_ST_INFO(b,t)  ((b) << 4 + ((t) & 0xF))

/* ELF32_ST_BIND(Elf32_Sym.st_info) values */
#define STB_LOCAL  0x0
#define STB_GLOBAL 0x1
#define STB_WEAK   0x2

/* ELF32_ST_TYPE(Elf32_Sym.st_info) values */
#define STT_NOTYPE  0x0
#define STT_OBJECT  0x1
#define STT_FUNC    0x2
#define STT_SECTION 0x3
#define STT_FILE    0x4


/*
 * ELF structures: Relocation Entries
 */
typedef struct Elf32_Rel
{
   Elf32_Addr r_offset;
   Elf32_Word r_info;
};

typedef struct Elf32_Rela
{
   Elf32_Addr  r_offset;
   Elf32_Word  r_info;
   Elf32_Sword r_addend;
};

/* Elf32_Rel|a.r_info manipulation macros */
#define ELF32_R_SYM(i)     ((i) >> 8)
#define ELF32_R_TYPE(i)    ((i) & 0xFF)
#define ELF32_R_INFO(s,t)  ((s) << 8 + (t) & 0xFF)

/* ELF32_R_TYPE(Elf32_Rel|a.r_info) values */
#define R_386_NONE      0x00
#define R_386_32        0x01
#define R_386_PC32      0x02
#define R_386_GOT32     0x03
#define R_386_PLT32     0x04
#define R_386_COPY      0x05
#define R_386_GLOB_DAT  0x06
#define R_386_JMP_SLOT  0x07
#define R_386_RELATIVE  0x08
#define R_386_GOTOFF    0x09
#define R_386_GOTPC     0x0A


/*
 * ELF structures: Program Header
 */
typedef struct Elf32_Phdr
{
   Elf32_Word p_type;   /* program section type */
   Elf32_Off  p_offset; /* file offset */
   Elf32_Addr p_vaddr;  /* execution virtual address */
   Elf32_Addr p_paddr;  /* execution physical address */
   Elf32_Word p_filesz; /* size in file */
   Elf32_Word p_memsz;  /* size in memory */
   Elf32_Word p_flags;  /* section flags */
   Elf32_Word p_align;  /* section alignment */
};

/* Elf32_Phdr.p_type */
#define PT_NULL     0
#define PT_LOAD     1
#define PT_DYNAMIC  2
#define PT_INTERP   3
#define PT_NOTE     4
#define PT_SHLIB    5
#define PT_PHDR     6


#endif
