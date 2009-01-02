# TODO: make all idls compile automatically

ID = ../../../bin/idlc.exe

all: Runnable.inf #MemoryManager.inf
	@echo "**"
	@echo "** interfaces built"
	@echo "**"

%.inf: %.idl
	$(ID) $<

clean:
	-rm -f *.inf

realclean: clean
