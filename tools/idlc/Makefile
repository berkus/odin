
IDLC = ../../bin/idlc.exe
CFILES=idlc.tab.c lex.yy.c

all: $(IDLC)

$(IDLC): $(CFILES)
	gcc -s -g -o $(IDLC) $^

idlc.tab.c : idlc.y
	bison -d idlc.y

lex.yy.c : idlc.tab.c idlc.l
	flex idlc.l

clean:
	-rm -f *.d

realclean: clean
	-rm -f $(IDLC) $(CFILES) idlc.tab.h

