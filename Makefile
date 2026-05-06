# --- config ---
ROOT := $(CURDIR)

JAVA    ?= java
JAR     ?= $(ROOT)/prog8c-12.0.1-all.jar
PROG8C  := $(JAVA) -jar "$(JAR)"

EMU_X16 ?= x16emu
OPT     ?=

SRC     := src/xvi2.p8pp
NAME    := xvi2

MKDIR_P := mkdir -p

VERSION ?= 1.2.0
PKG     ?= XVI

# --- helpers ---
UPPER = $(shell echo $(1) | tr a-z A-Z)

# --- default ---
all: x16
br: x16 run-x16

# --- build macro ---
# $(1) = friendly target dir/name, e.g. x16
# $(2) = Prog8 compiler target, e.g. cx16
define BUILD_template
$(1):
	@echo "=== Building for $(1) / Prog8 target $(2) ==="
	@$(MKDIR_P) build/$(1)

	@echo "CPP -> src/$(NAME)-$(1).p8"
	cpp -P -x assembler-with-cpp -DTARGET_$(call UPPER,$(1)) \
		$(SRC) > src/$(NAME)-$(1).p8

	@echo "COMPILING"
	$(PROG8C) $(OPT) -target $(2) src/$(NAME)-$(1).p8

	@echo "MOVING OUTPUT -> build/$(1)/"
	mv -f $(NAME)-$(1).prg build/$(1)/$(NAME)-$(1).prg
	mv -f $(NAME)-$(1).asm build/$(1)/$(NAME)-$(1).asm 2> /dev/null || echo -n
	mv -f $(NAME)-$(1).vice-mon-list build/$(1)/$(NAME)-$(1).vice-mon-list 2> /dev/null || echo -n

	@echo "COPYING GENERATED SOURCE -> build/$(1)/"
	cp src/$(NAME)-$(1).p8 build/$(1)/$(NAME)-$(1).p8

	@echo "Done: build/$(1)/$(NAME)-$(1).prg"
endef

# --- targets ---
$(eval $(call BUILD_template,x16,cx16))
$(eval $(call BUILD_template,c64,c64))
$(eval $(call BUILD_template,vic20,vic20))
$(eval $(call BUILD_template,atari,atari))

# --- run/debug helpers ---
run: run-x16

run-x16: x16
	$(EMU_X16) -debug -scale 2 -prg build/x16/$(NAME)-x16.prg -run -gif demo.gif

debug-x16: x16
	$(EMU_X16) -scale 2 -prg build/x16/$(NAME)-x16.prg -run -debug

trace-x16: x16
	$(EMU_X16) -scale 2 -prg build/x16/$(NAME)-x16.prg -run -trace

run: run-c64

run-c64: c64
	$(EMU_X16) -debug -scale 2 -prg build/c64/$(NAME)-c64.prg -run -gif demo.gif

debug-c64: c64
	$(EMU_X16) -scale 2 -prg build/c64/$(NAME)-c64.prg -run -debug

trace-c64: c64
	$(EMU_X16) -scale 2 -prg build/c64/$(NAME)-c64.prg -run -trace

# --- package ---
bundle: x16
	rm -rfv ./$(PKG)
	$(MKDIR_P) ./$(PKG) ./releases
	cp build/x16/$(NAME)-x16.prg $(PKG)/XVI.PRG
	cp build/x16/$(NAME)-x16.prg $(PKG)/AUTOBOOT.X16
	cp BASLOAD $(PKG)/BASLOAD
	cp readme.txt $(PKG)/readme.txt
	zip $(PKG)-$(VERSION).zip $(PKG)/*
	cp *.zip releases/

# --- cleanup ---
clean:
	rm -rf build
	rm -fv $(NAME)-x16.p8 src/$(NAME)-c64.p8 src/$(NAME)-vic20.p8 src/$(NAME)-atari.p8
	rm -fv $(NAME)-x16.prg src/$(NAME)-c64.prg src/$(NAME)-vic20.prg src/$(NAME)-atari.prg
	rm -fv $(NAME)-x16.asm src/$(NAME)-c64.asm src/$(NAME)-vic20.asm src/$(NAME)-atari.asm
	rm -fv xvi xvi.prg xvi2 xvi2.prg *.asm strucst.* demo.gif 2> /dev/null || echo -n
	rm -rf ./$(PKG) *.zip 2> /dev/null || echo -n
