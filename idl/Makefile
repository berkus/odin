# TODO: make all idls compile automatically

ID = ../bin/idlc.exe

all: console.inf
	@echo "**"
	@echo "** system interfaces built"
	@echo "**"

%.inf: %.idl
	$(ID) $<

clean:
	-rm -f *.inf

realclean: clean
