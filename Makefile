all:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-10.4-all.jar -target cx16 src/xvi.p8
	cp -f xvi.prg XVI 

run:
	x16emu -scale 2 -prg ./XVI -run

trace:
	x16emu -scale 2 -prg ./XVI -run -trace

io-test:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-10.4-all.jar -target cx16 src/file-io-test.p8

iso-test:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-10.4-all.jar -target cx16 src/iso-test.p8

txt-viewer:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-10.4-all.jar -target cx16 src/txt-viewer.p8

debug:
	x16emu -scale 2 -prg ./XVI -run -debug

clean:
	rm -fv xvi XVI *.asm
