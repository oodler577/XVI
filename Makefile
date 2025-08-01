all: clean build bundle run

build:
	java -jar /Users/tempuser/Desktop/x16/prog8c-10.5.1-all.jar -target cx16 src/xvi.p8

bundle:
	rm -rfv ./XVI
	mkdir ./XVI 
	cp xvi.prg XVI/XVI.PRG
	cp xvi.prg XVI/AUTOBOOT.X16 
	cp BASLOAD XVI/BASLOAD
	
	cp readme.txt XVI/readme.txt
	zip XVI-1.2.0.zip XVI/ 
	mkdir ./releases 2> /dev/null || echo -n
	cp *.zip releases/

run:
	cd XVI && x16emu -scale 2

trace:
	x16emu -scale 2 -prg ./XVI -run -trace

io-test:
	java -jar /Users/tempuser/Desktop/x16/prog8c-10.5.1-all.jar -target cx16 src/file-io-test.p8

iso-test:
	java -jar /Users/tempuser/Desktop/x16/prog8c-10.5.1-all.jar -target cx16 src/iso-test.p8

xvi2:
	java -jar /Users/tempuser/Desktop/x16/prog8c-10.5.1-all.jar -target cx16 src/xvi2.p8

sendtox16:
	cp xvi2.prg xvi2
	curl -F "file=@xvi2" http://192.168.0.1/upload.cgi > /dev/null

run2:
	x16emu -scale 2 -prg ./xvi2.prg -run

run2demo:
	x16emu -scale 2 -prg ./xvi2.prg -run -gif demo.gif

run-xvi2-no-scale:
	x16emu -prg ./xvi2.prg -run -debug

debug:
	x16emu -scale 2 -prg ./XVI -run -debug

clean:
	rm -fv xvi xvi.prg *.asm 2> /dev/null || echo -n
	rm -rf ./XVI *.zip       2> /dev/null || echo -n
