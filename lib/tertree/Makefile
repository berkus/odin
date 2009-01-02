AS = nasm
ASFLAGS = -i../../include

all: tertree.o test.o

%.o: %.asm
	$(AS) -felf $(ASFLAGS) $< -l $<.lst

clean:
	-rm -f *.o *.lst

realclean: clean
