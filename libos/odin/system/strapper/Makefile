
OBJS = micro.o ../console.o ../../lib/bintree/bintree.o ../../lib/bintree/test.o

.PHONY: clean

LD = ../../bin/sjofn.exe
ID = ../../bin/idlc.exe
AS = nasm
ASFLAGS = -i../../include -i../../include/orb -D_VERBOSE_STARTUP

all: inf ../../bin/libos.bin
	@echo "**"
	@echo "** libos built"
	@echo "**"

%.o: %.asm
	$(AS) -felf $(ASFLAGS) $< -l $<.lst

%.inf: %.idl
	$(ID) $<

inf:
	make -C idl

libos.bin: $(OBJS) micro.inf
	$(LD) -v -o libos.bin $(OBJS) --mt=micro.inf --xref -i idl

../../bin/libos.bin: libos.bin
	cp libos.bin ../../bin/libos.bin

clean:
	-rm -f $(OBJS) *.lst *.sym *.o *.inf libos.bin ../../bin/libos.bin
	make -C idl clean

realclean: clean
	make -C idl realclean
