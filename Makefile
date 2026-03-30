.PHONY: build run clean install

build:
	swift build -c release

run: build
	.build/release/SlapMacClone

debug:
	swift build
	.build/debug/SlapMacClone

clean:
	swift package clean
	rm -rf .build

install: build
	mkdir -p /usr/local/bin
	cp .build/release/SlapMacClone /usr/local/bin/slapmacpro
	@echo "Installed to /usr/local/bin/slapmacpro"
	@echo "Run with: slapmacpro"
