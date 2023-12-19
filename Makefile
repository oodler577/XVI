all:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-9.7-all.jar -target cx16 src/VICL1.p8

run:
	x16emu -scale 2 -prg ./VICL1.prg -run

debug:
	x16emu -scale 2 -prg ./VICL1.prg -run -debug
