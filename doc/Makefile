
SRCS = orb.tex sched.tex Jotun.tex style.tex
TARG = $(SRCS:.tex=.ps)

all: $(TARG) clean-support

%.ps: %.tex
	texi2dvi $< >tex2ps.log 2>&1
	dvips -f $*.dvi > $@ 2>/dev/null

clean: clean-support
	rm -f $(TARG)

clean-support:
	rm -f *.dvi *.aux *.log *.bbl *.blg tex2ps.log
