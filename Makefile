# --- config ---
JAVA    ?= java
JAR     ?= prog8c-12.0.1-all.jar
PROG8C  := $(JAVA) -jar $(JAR)

TARGET  ?= cx16
EMU     ?= x16emu
VERSION ?= 1.2.0
PKG     ?= XVI

# --- preprocessing for xvi2 ---
XVI2_SRC := src/xvi2.p8
XVI2_PP  := src/xvi2.pp.p8

$(XVI2_PP): $(XVI2_SRC)
	@echo "CPP $< -> $@"
	cpp -P -x assembler-with-cpp $< -o $@

# --- targets ---
all: clean build bundle run

build:
	$(PROG8C) -target $(TARGET) src/xvi.p8

bundle:
	rm -rfv ./$(PKG)
	mkdir ./$(PKG)
	cp xvi.prg $(PKG)/XVI.PRG
	cp xvi.prg $(PKG)/AUTOBOOT.X16
	cp BASLOAD $(PKG)/BASLOAD
	cp readme.txt $(PKG)/readme.txt
	zip $(PKG)-$(VERSION).zip $(PKG)/
	mkdir ./releases 2> /dev/null || echo -n
	cp *.zip releases/

trace:
	$(EMU) -scale 2 -prg ./$(PKG) -run -trace


# --- xvi2 build using cpp output ---
#xvi2: $(XVI2_PP)
#	$(PROG8C) -target $(TARGET) $(XVI2_PP)
#	mv -f xvi2.pp.prg xvi2.prg

xvi2:
	$(PROG8C) -target $(TARGET) $(XVI2_SRC)

run:
	$(EMU) -debug -scale 2 -prg xvi2.prg -run -gif demo.gif

sendtox16:
	# using Flashair ...
	cp xvi2.prg xvi2
	curl -F "file=@xvi2" http://192.168.0.1/upload.cgi > /dev/null

debug:
	$(EMU) -scale 2 -prg ./xvi2.prg -run -debug

clean:
	rm -fv xvi xvi.prg xvi2 xvi2.prg *.asm strucst.* src/*.pp.p8 2> /dev/null || echo -n
	rm -rf ./$(PKG) *.zip 2> /dev/null || echo -n

