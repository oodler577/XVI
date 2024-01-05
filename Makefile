all:
	java -jar /Users/tempuser/Desktop/x16/prog8compiler-9.7-all.jar -target cx16 src/VICL1.p8
	mv VICL1.prg vi

run:
	x16emu -scale 2 -prg ./vi -run

debug:
	x16emu -scale 2 -prg ./vi -run -debug
