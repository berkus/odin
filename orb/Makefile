#========================================================================================
#
# The ORB makefile
#
#========================================================================================

include ../config.makefile

LD = ../bin/sjofn.exe
AS = nasm
ASFLAGS = -i../include -i../include/orb

all: ../bin/orb.bin
	@echo "**"
	@echo "** orb built"
	@echo "**"

%.o: %.asm
	$(AS) -felf $(ASFLAGS) $(AS_EXTRA_FLAGS) $< -l $<.lst

orb.img: jmp_tbl.o ctor.o create.o destroy.o install.o uninstall.o load_gdt.o locks.o switch_stacks.o control.o misc.o xcp.o console.o desc.o dump.o
	$(LD) -v --make-orb -o orb.img $^ --xref --no-abs --abort-on-warning --bochs-sym

orb.bin: ../bin/libos.bin orb.img multiboot.asm
	$(AS) -fbin $(ASFLAGS) $(AS_EXTRA_FLAGS) multiboot.asm -o orb.bin -l orb.bin.lst

../bin/orb.bin: orb.bin
	cp orb.bin ../bin/orb.bin

../bin/libos.bin:
	make -C .. libos

clean:
	-rm -f *.o *.lst *.sym ../bin/orb.bin orb.bin orb.img

realclean: clean
