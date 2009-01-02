/*
 *  Jotun file format structures definitions
 *  According to Jotun Format Specification, version 1.0.2.
 *
 *  Typed in by Stanislav Karchebny <berk@madfire.net>, 2002
 *  This file is in Public Domain.
 */

#ifndef __FF_JOTUN_H
#define __FF_JOTUN_H

/*
 * Jotun data types
 */
typedef unsigned int    Jotun32_Off;    /* 4 bytes/4 align/unsigned */
typedef unsigned int    Jotun32_Word;   /* 4 bytes/4 align/unsigned */
typedef unsigned short  Jotun32_Short;  /* 2 bytes/2 align/unsigned */
typedef unsigned char   Jotun32_Byte;   /* 1 byte /1 align/unsigned */

/*
 * Jotun structures: Jotun file Header
 */
 /* a fix for the future version: make hdrsize a byte, remove rsvd byte and use
    whole word for version field, i.e. magic,version,hdrsize,then the rest.. */
typedef struct Jotun32_FileHeader_t
{
   Jotun32_Word    magic;    /* `E',`T',`i',`N' (english for Jotun)                              */
   Jotun32_Short   hdrsize;  /* header size in bytes including magic and extra fields (min = 16) */
   Jotun32_Short   version;  /* Odin version this file is produced/compatible with               */
   Jotun32_Byte    reserved; /* padding, zero                                                    */
   Jotun32_Byte    machine;  /* machine architecture (JOTUN_ARCH_*)                              */
   Jotun32_Byte    capacity; /* file capacity (JOTUN_CAPACITY_*)                                 */
   Jotun32_Byte    encoding; /* file endianness (JOTUN_ENCODING_*)                               */
   Jotun32_Word    flags;    /* flags (JF_*)                                                     */
}  Jotun32_FileHeader;

/* Jotun32_FileHeader.magic */
#define JOTUN_MAGIC    0x4e695445

/* Jotun32_FileHeader.capacity */
#define JOTUN_CAPACITY_NONE  0x00  /* Invalid capacity */
#define JOTUN_CAPACITY_32    0x01  /* 32 bit objects   */
#define JOTUN_CAPACITY_64    0x02  /* 64 bit objects   */

/* Jotun32_FileHeader.encoding */
#define JOTUN_ENCODING_NONE  0x00  /* Invalid data encoding   */
#define JOTUN_ENCODING_LSB   0x01  /* LSB (Intel) encoding    */
#define JOTUN_ENCODING_MSB   0x02  /* MSB (Motorola) encoding */

/* Jotun32_FileHeader.machine */
#define JOTUN_ARCH_NONE      0x00  /* No machine */
#define JOTUN_ARCH_386       0x01  /* x86        */

/* Jotun32_FileHeader.flags */
#define JF_TEXTINFO    0x00000001  /* Text info present                    */
#define JF_ODSHDR      0x00000002  /* Overlay Data Sections header present */
#define JF_SINGLETON   0x00000004  /* Component is a singleton             */

/*
 * Jotun structures: Jotun Sections Header
 */
typedef struct Jotun32_SectionsHeader_t
{
   Jotun32_Word   sh_size;  /* size of sections header including this field (32) */
   Jotun32_Off    t_start;  /* start in file of text section                     */
   Jotun32_Word   t_size;   /* size in bytes of text section                     */
   Jotun32_Off    d_start;  /* start in file of data section                     */
   Jotun32_Word   d_size;   /* size in bytes of data section                     */
   Jotun32_Word   b_size;   /* size in bytes of bss section                      */
   Jotun32_Off    m_start;  /* start in file of method table section             */
   Jotun32_Word   m_size;   /* size in bytes of method table section             */
}  Jotun32_SectionsHeader;

/*
 * Jotun structures: Jotun Overlay Data Sections Entry
 */
typedef struct Jotun32_ODSEntry_t
{
   Jotun32_Word      start; /* start of OD section in linear memory */
   Jotun32_Word      size;  /* size of OD section                   */
}  Jotun32_ODSEntry;

/*
 * Jotun structures: Jotun Overlay Data Sections Header
 */
typedef struct Jotun32_ODSHeader_t
{
   Jotun32_Word      count;      /* number of overlay data entries */
   Jotun32_ODSEntry  entries[0]; /* list of overlay data sections  */
}  Jotun32_ODSHeader;

#endif /* __FF_JOTUN_H */
