#ifndef __odin_MT_H
#define __odin_MT_H

struct mt_entry
{
   void           *start;
   unsigned short  cs;
   unsigned short  psize;             // size of parameters to pass
};

struct mt
{
   unsigned int       mcount;         //0x00
   unsigned int       pad;            //0x04
   void              *ctor_entry;     //0x08
   unsigned int       ctor_cs;        //0x0C
   void              *dtor_entry;     //0x10
   unsigned int       dtor_cs;        //0x14

   inline mt_entry& operator[]( unsigned int i );
   inline const size_t sz();

private:
   mt_entry m_entries[0];  //0x18
};

inline const size_t mt::sz()
{
   return( sizeof( mt_entry ) * (mcount) + sizeof( mt ) );
}

inline mt_entry& mt::operator[]( unsigned int i )
{
   return m_entries[ i ];
}

#endif
