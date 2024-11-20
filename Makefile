PCC=prog8c

all: clean build bundle run

build:
	$(PCC) -target cx16 src/xvi.p8

bundle:
	rm -rfv ./XVI
	mkdir ./XVI 
	cp xvi.prg XVI/XVI.PRG
	cp xvi.prg XVI/AUTOBOOT.X16 
	cp BASLOAD XVI/BASLOAD
	
	cp readme.txt XVI/readme.txt
	zip -r XVI-1.2.0.zip XVI/ 
	mkdir ./releases 2> /dev/null || echo -n
	cp *.zip releases/

run:
	cd XVI && x16emu -scale 2

trace:
	x16emu -scale 2 -prg ./XVI -run -trace

io-test:
	$(PCC) -target cx16 src/file-io-test.p8

iso-test:
	$(PCC) -target cx16 src/iso-test.p8

txt-viewer:
	$(PCC) -target cx16 src/txt-viewer.p8

debug:
	x16emu -scale 2 -prg ./XVI -run -debug

clean:
	rm -fv xvi xvi.prg *.asm 2> /dev/null || echo -n
	rm -rf ./XVI *.zip       2> /dev/null || echo -n
