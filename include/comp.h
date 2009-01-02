#ifndef __odin_COMP_H
#define __odin_COMP_H

// FIXME: obsolete
// keep in sync with orb/comp.inc and ../orb/impl_xcp.asm

struct comp_desc
{
   struct rgn
   {
      Elf32_Addr start;
      Elf32_Word size;
   };

   rgn         text;
   rgn         data;
   rgn         bss;
   rgn         mt;
   Elf32_Word  version;
};

#endif
