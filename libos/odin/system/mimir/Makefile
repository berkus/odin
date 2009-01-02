
OBJS = mimir.o ../../stack_str.o ../../../lib/bintree/bintree.o ../../../lib/tertree/tertree.o

.PHONY: clean

LD = ../../../bin/sjofn.exe
ID = ../../../bin/idlc.exe
AS = nasm
ASFLAGS = -i../../../include -i../../../include/orb

all: mimir.cmp
	@echo "** mimir built"

%.o: %.asm
	$(AS) -felf $(ASFLAGS) $< -l $<.lst

%.inf: %.idl
	$(ID) $<

mimir.cmp: $(OBJS) ../idl/mem_mgr.inf
	$(LD) -v -o mimir.cmp $(OBJS) --mt=../idl/mem_mgr.inf --xref -i ../idl

clean:
	-rm -f $(OBJS) *.lst *.sym *.o *.inf mimir.cmp

realclean: clean
