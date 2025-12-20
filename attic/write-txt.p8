%import textio
%import diskio
%import string
%zeropage basicsafe
%option no_sysinit

; simple test program for the "VTUI" text user interface library
; see:  https://github.com/JimmyDansbo/VTUIlib

main {
    ubyte minCol         = 3
    ubyte maxCol         = 76
    ubyte minLine        = 3
    ubyte maxLine        = 56
    ubyte line           = minLine
    ubyte col            = minCol
    str filename         = " " * 64

    sub start() {
      vtui.initialize()
      vtui.screen_set(0)
      vtui.clr_scr(' ', $50)
      open_file("3test.txt")
      diskio.f_open_w_seek("@0:3test.txt")      ; open file for writing
      ubyte j,i
      for j in 3 to 56 {
        for i in 3 to 76 {
          vtui.gotoxy(i, 3)                       ; go to location of char to get
          ubyte char = vtui.scan_char()           ; get screen code
          vtui.gotoxy(i, 3)                       ; go to next line
          ubyte petchar = vtui.scr2pet(char)      ; convert screen code to petscii, for writing to file
          diskio.f_write(&petchar, 1)             ; write to file (using reference to "petchar")
          vtui.plot_char(char, $50)               ; plot character using screencode just scan'd
        }
       diskio.f_write("\x0a", 1)
      }
      diskio.f_close_w()
    }

    sub open_file(str filepath) {
        if diskio.f_open(filepath) {
          repeat 53 { ;;;; number of lines, will need to be dynamic when dealing with files beyond view port
            str foo = " " * 75
            uword size = diskio.f_readline(foo)
            string.rstrip(foo)
;            vtg(main.minCol,main.line)
            vtui.print_str2(foo, $c6, true)
          }
          diskio.f_close()
        }
        else {
          txt.print("oof error opening ")
          txt.print(filepath) 
          txt.print("...") 
        }
    }

    sub vtg(ubyte col, ubyte line) {
      vtui.gotoxy(col, line)
    }
}

vtui $8800 {
    %option no_symbol_prefixing
    %asmbinary "VTUI-C1C7.BIN", 2     ; skip the 2 dummy load address bytes
    ; NOTE: base address $1000 here must be the same as the block's memory address, for obvious reasons!
    ; The routines below are for VTUI 1.0
    romsub $8800 = initialize() clobbers(A, X, Y)
    romsub $8802 = screen_set(ubyte mode @A) clobbers(A, X, Y)
    romsub $880e = clr_scr(ubyte char @A, ubyte colors @X) clobbers(Y)
    romsub $8811 = gotoxy(ubyte column @A, ubyte row @Y)
    romsub $8814 = plot_char(ubyte char @A, ubyte colors @X)
    romsub $8817 = scan_char() -> ubyte @A
    romsub $8820 = print_str(str txtstring @R0, ubyte length @Y, ubyte colors @X, ubyte convertchars @A) clobbers(A, Y)
    romsub $8826 = pet2scr(ubyte char @A) -> ubyte @A
    romsub $8829 = scr2pet(ubyte char @A) -> ubyte @A

    ; -- helper function to do string length counting for you internally, and turn the convertchars flag into a boolean again
    asmsub print_str2(str txtstring @R0, ubyte colors @X, bool convertchars @Pc) clobbers(A, Y) {
        %asm {{
            lda  #0
            bcs  +
            lda  #$80
+           pha
            lda  cx16.r0
            ldy  cx16.r0+1
            jsr  prog8_lib.strlen
            pla
            jmp  print_str
        }}
    }
}
