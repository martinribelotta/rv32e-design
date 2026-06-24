# Thin wrapper around the project-root Makefile.
#   make            build firmware images for this app
#   make flash-fw   patch IMEM+DROM via icebram and program the board (~3 s)
#   make fw         build the patched bitstream without programming
APP  := timer_blink
ROOT := $(abspath $(CURDIR)/../../..)

.PHONY: all flash-fw fw flash-core core sim clean
all:
	$(MAKE) -C $(ROOT) APP=$(APP) firmware
flash-fw fw flash-core core sim clean:
	$(MAKE) -C $(ROOT) APP=$(APP) $@
