
SOURCES = sjofn.c options.c

LINK = ../../bin/sjofn.exe
CFLAGS = -Wall -I../../include #-D__DEBUG__

all: $(LINK)

$(LINK) : $(SOURCES)
	g++ $(CFLAGS) -s -o $@ $(SOURCES)

clean:

realclean: clean
	-rm -f $(LINK)
