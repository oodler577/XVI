all:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-10.2-all.jar -target cx16 src/xvi.p8
	cp xvi.prg xvi
	mv xvi.prg xvi-rc1.0.prg

run:
	x16emu -scale 2 -prg ./xvi -run

trace:
	x16emu -scale 2 -prg ./xvi -run -trace

test:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-10.2-all.jar -target cx16 src/file-io-test.p8

debug:
	x16emu -scale 2 -prg ./xvi -run -debug

clean:
	rm -fv xvi xvi-rc1.0.prg *.asm
