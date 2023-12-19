%import textio
%option no_sysinit
%zeropage basicsafe

; simple test program for the "VTUI" text user interface library
; see:  https://github.com/JimmyDansbo/VTUIlib

main {
    sub start() {
        vtui.initialize()

        ;txt.lowercase()
        vtui.screen_set(0)
        vtui.clr_scr(' ', $50)
        vtui.gotoxy(2,2)
        vtui.fill_box(' ', 76, 56, $c6)
        vtui.gotoxy(2,2)
        vtui.border(3, 76, 56, $00)

        str inputbuffer = "?" * 73 
        ubyte line = 2
        navMode()

        while 1 {
           vtui.gotoxy(45,1);
           vtui.fill_box(' ', 33, 1, $e0)
           vtui.gotoxy(45,1);
           vtui.print_str2("ins", $01, true); 
           vtui.gotoxy(3,line)
           ; if the last key is ESC, input_str will exit - we check to see
           ; if it was ESC (not RET), put in navMode if ESC, go to next line
           ; in "editMode" if not - getting very close to vi-like modalities
           ubyte lastkey = vtui.input_str_lastkey(inputbuffer, len(inputbuffer), $c6)
           if lastkey == $1b {
             navMode()
           }
edit_mode:
           line = line + 1
        }

   }

   sub navMode() {
navstart:
      vtui.gotoxy(45,1);
      vtui.fill_box(' ', 33, 1, $e0)
      vtui.gotoxy(45,1);
      vtui.print_str2("nav ", $01, true); 
nav:
      ubyte char = cbm.GETIN()
      when char {
          $1b -> { ; ESC key
              goto main.start.edit_mode 
          }
          $3a -> { ; colon (:)
            vtui.gotoxy(45,1);
            vtui.print_str2("cmd ", $01, true); 
            str cmdbuffer = "?" * 29 
            vtui.gotoxy(49,1);
            vtui.input_str(cmdbuffer, 28, $e0)
            goto navstart
          }
      }
      goto nav
   }
}

vtui $1000 {

    %option no_symbol_prefixing
    %asmbinary "VTUI-C1C7.BIN", 2     ; skip the 2 dummy load address bytes

    ; NOTE: base address $1000 here must be the same as the block's memory address, for obvious reasons!
    ; The routines below are for VTUI 1.0
    romsub $1000  =  initialize() clobbers(A, X, Y)
    romsub $1002  =  screen_set(ubyte mode @A) clobbers(A, X, Y)
    romsub $1005  =  set_bank(bool bank1 @Pc) clobbers(A)
    romsub $1008  =  set_stride(ubyte stride @A) clobbers(A)
    romsub $100b  =  set_decr(bool incrdecr @Pc) clobbers(A)
    romsub $100e  =  clr_scr(ubyte char @A, ubyte colors @X) clobbers(Y)
    romsub $1011  =  gotoxy(ubyte column @A, ubyte row @Y)
    romsub $1014  =  plot_char(ubyte char @A, ubyte colors @X)
    romsub $1017  =  scan_char() -> ubyte @A, ubyte @X
    romsub $101a  =  hline(ubyte char @A, ubyte length @Y, ubyte colors @X) clobbers(A)
    romsub $101d  =  vline(ubyte char @A, ubyte height @Y, ubyte colors @X) clobbers(A)
    romsub $1020  =  print_str(str txtstring @R0, ubyte length @Y, ubyte colors @X, ubyte convertchars @A) clobbers(A, Y)
    romsub $1023  =  fill_box(ubyte char @A, ubyte width @R1, ubyte height @R2, ubyte colors @X) clobbers(A, Y)
    romsub $1026  =  pet2scr(ubyte char @A) -> ubyte @A
    romsub $1029  =  scr2pet(ubyte char @A) -> ubyte @A
    romsub $102c  =  border(ubyte mode @A, ubyte width @R1, ubyte height @R2, ubyte colors @X) clobbers(Y)       ; NOTE: mode 6 means 'custom' characters taken from r3 - r6
    romsub $102f  =  save_rect(ubyte ramtype @A, bool vbank1 @Pc, uword address @R0, ubyte width @R1, ubyte height @R2) clobbers(A, X, Y)
    romsub $1032  =  rest_rect(ubyte ramtype @A, bool vbank1 @Pc, uword address @R0, ubyte width @R1, ubyte height @R2) clobbers(A, X, Y)
    romsub $1035  =  input_str(uword buffer @R0, ubyte buflen @Y, ubyte colors @X) clobbers (A) -> ubyte @Y         ; NOTE: returns string length
    romsub $1035  =  input_str_lastkey(uword buffer @R0, ubyte buflen @Y, ubyte colors @X) clobbers (Y) -> ubyte @A ; NOTE: returns lastkey press
    romsub $1038  =  get_bank() clobbers (A) -> bool @Pc
    romsub $103b  =  get_stride() -> ubyte @A
    romsub $103e  =  get_decr() clobbers (A) -> bool @Pc

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
