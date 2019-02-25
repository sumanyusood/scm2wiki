scm2wiki: scm2wiki-bin-wrapper.scm scm2wiki.scm
	csc scm2wiki-bin-wrapper.scm -b -O3 -o scm2wiki

doc-test: scm2wiki
	$(info $(shell mkdir -p docs))
	./scm2wiki -i scm2wiki.scm -o docs/scm2wiki.wiki
	./scm2wiki -m -i scm2wiki.scm -o docs/scm2wiki.md

.PHONY: clean

clean:
	rm scm2wiki