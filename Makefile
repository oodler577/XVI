# --- config ---
JAVA        ?= java
PROG8C_JAR  ?= prog8c-11.4.1-all.jar
PROG8C      := $(JAVA) -jar $(PROG8C_JAR)

TARGET  ?= cx16
EMU     ?= x16emu
VERSION ?= 1.2.0
PKG     ?= XVI

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

run:
	cd $(PKG) && $(EMU) -scale 2

trace:
	$(EMU) -scale 2 -prg ./$(PKG) -run -trace

io-test:
	$(PROG8C) -target $(TARGET) src/file-io-test.p8

iso-test:
	$(PROG8C) -target $(TARGET) src/iso-test.p8

xvi2:
	$(PROG8C) -target $(TARGET) src/xvi2.p8
	mv xvi2.prg dist/xvi2

structs:
	$(PROG8C) -target $(TARGET) src/structs.p8

runstructs:
	$(EMU) -debug -scale 2 -prg structs.prg -run

sendtox16:
	cp xvi2.prg xvi2
	curl -F "file=@xvi2" http://192.168.0.1/upload.cgi > /dev/null

run2:
	$(EMU) -scale 2 -prg ./dist/xvi2 -run

run2demo:
	$(EMU) -scale 2 -prg ./dist/xvi2 -run -gif demo.gif

run-xvi2-no-scale:
	$(EMU) -prg ./xvi2.prg -run -debug

debug:
	$(EMU) -scale 2 -prg ./xvi2.prg -run -debug

clean:
	rm -fv xvi xvi.prg *.asm 2> /dev/null || echo -n
	rm -rf ./$(PKG) *.zip 2> /dev/null || echo -n
