#========================================================================================
#
# Odin makefile
#
# TODO
# - add src_dist target for making source distribution archive
#========================================================================================
#
# current odin version:
#
VER = 1.2
#
# choose a libos to build
#
LIBOS = ./libos/odin
#
# choose a libos deploy method
# options: fdcopy dd tftp bochs
#
DEPLOY = bochs
#
# location of bochs images files (for bochs deploy method)
#
BOCHS_PATH = /home/berk/.bochs/
#
# end of user defined settings
#========================================================================================


AWK = gawk -f


.PHONY: all build tools lib libos orb boot install

all : build tools lib libos orb boot install
	@echo "**"
	@echo "** build completed"
	@echo "**"

#
# Increase build number
#
build:
	$(AWK) ./tools/buildversion.awk include/version $(VER)
	mkdir -p bin

#
# Build tools
#
tools:
	make -C tools/sjofn
	make -C tools/idlc
	@echo "**"
	@echo "** tools built"
	@echo "**"

#
# Build support libraries
#
lib:
	make -C lib

#
# Build library OS
# produces ./bin/libos.bin
#
libos:
	make -C $(LIBOS)

#
# Build the ORB
# produces ./bin/orb.bin
#
orb:
	make -C orb

#
# And finally, build the boot from ORB and library OS images
# produces ./bin/odin.bin
#
boot:
	make -C boot

#
# Image deploy methods
#
install: $(DEPLOY)
	@echo "**"
	@echo "** odin installed"
	@echo "**"

fdcopy:
	fdcopy ./bin/odin.bin

dd:
	dd if=./bin/odin.bin of=/dev/fd0 bs=512

bochs:
	cp ./bin/odin.bin $(BOCHS_PATH)
	@echo "Make sure you have the following line in your .bochsrc:"
	@echo "floppya: 1_44=$(BOCHS_PATH)odin.bin"

tftp:
	cp ./bin/odin.bin /tftpboot

#
# Clean everything but leave tools in place
#
clean:
	make -C tools/sjofn clean
	make -C tools/idlc  clean
	make -C lib         clean
	make -C orb         clean
	make -C boot        clean
	make -C libos       clean
	make -C $(LIBOS)    clean

#
# Wipe 'em out!
#
realclean: clean
	make -C tools/sjofn realclean
	make -C tools/idlc  realclean
	make -C lib         realclean
	make -C orb         realclean
	make -C boot        realclean
	make -C libos       realclean
	make -C $(LIBOS)    realclean

