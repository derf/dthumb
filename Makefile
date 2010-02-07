prefix = /usr/local

default: build/gen-xhtml-thumbnails.1

build/%.1: bin/%
	mkdir -p build
	pod2man $< > $@

install: build/gen-xhtml-thumbnails.1
	mkdir -p $(prefix)/bin $(prefix)/share/man/man1
	cp bin/gen-xhtml-thumbnails $(prefix)/bin/gen-xhtml-thumbnails
	cp build/gen-xhtml-thumbnails.1 $(prefix)/share/man/man1/gen-xhtml-thumbnails.1
	chmod 755 $(prefix)/bin/gen-xhtml-thumbnails
	chmod 644 $(prefix)/share/man/man1/gen-xhtml-thumbnails.1

uninstall:
	rm -f $(prefix)/bin/gen-xhtml-thumbnails
	rm -f $(prefix)/share/man/man1/gen-xhtml-thumbnails.1

clean:
	rm -rf build

.PHONY: install uninstall clean
