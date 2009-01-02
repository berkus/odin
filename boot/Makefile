
all: ../bin/odin.bin

odin.bin: boot.asm ../bin/orb.bin
	nasm -fbin boot.asm -o odin.bin

../bin/odin.bin: odin.bin
	cp odin.bin ../bin/odin.bin

clean:
	-rm -f odin.bin ../bin/odin.bin *.lst

realclean: clean
