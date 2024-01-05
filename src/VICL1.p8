%import   textio
%import   conv
%import   syslib
%option   no_sysinit
%zeropage basicsafe

; simple test program for the "VTUI" text user interface library
; see:  https://github.com/JimmyDansbo/VTUIlib

main {
    ubyte originX = 3
    ubyte originY = 3
    ubyte line    = originY
    ubyte col     = originX 
    ubyte maxCol  = 76
    ubyte Y       = 0

    sub init_canvas() {
        vtui.initialize()

        ;txt.lowercase()
        vtui.screen_set(0)
        vtui.clr_scr(' ', $50)
        vtui.gotoxy(2,2)
        vtui.fill_box(' ', 76, 56, $c6)
        vtui.gotoxy(2,2)
        vtui.border(3, 76, 56, $00)
    }

    sub reset_cursor() {
        vtui.gotoxy(originX, originY)
        vtui.fill_box(' ', 1, 1, $e1)
    }

    sub updateXY_ticker() {
        ubyte x = cx16.VERA_ADDR_L / 2   ; cursor X coordinate
        ubyte y = cx16.VERA_ADDR_M - $b0 ; cursor Y coordinate

        vtui.gotoxy(68, 57)
        vtui.fill_box(' ', 7, 1, $00)
        vtui.gotoxy(68, 57)

        conv.str_ub0(x-3)
        vtui.print_str2(conv.string_out, $01, true)

        vtui.print_str2(" ", $01, true)

        conv.str_ub0(y-3)
        vtui.print_str2(", ", $01, true)
        vtui.print_str2(conv.string_out, $01, true)

        ;main.col  = x
        ;main.line = y
        vtui.gotoxy(main.col,main.line)
    }

    sub start() {
        init_canvas()
        updateXY_ticker()
        ;reset_cursor()
        vtui.gotoxy(main.originX,main.originY);
        navMode()
        vtui.fill_box(' ', 1, 1, $e1)
        str inputbuffer = "?" * 73 ; this is the width of the inner box vtui box 
        while 1 {
           vtui.gotoxy(main.col,main.line)
           updateXY_ticker()

           ; if the last key is ESC, input_str will exit - we check to see
           ; if it was ESC (not RET), put in navMode if ESC, go to next line
           ; in "editMode" if not - getting very close to vi-like modalities

           uword AX       = vtui.input_str_retboth(inputbuffer, len(inputbuffer), $c6)
           ubyte lastkey  = lsb(AX)
           ubyte inputLen = msb(AX)

           if lastkey == $1b {                ; $1b is <ESC>
             main.col  = cx16.VERA_ADDR_L / 2   ; cursor X coordinate
             main.line = cx16.VERA_ADDR_M - $b0 ; cursor Y coordinate
             
             updateXY_ticker()
             navMode()
           }

           main.col  = 3
           main.line = main.line + 1
edit_mode:
        }
   }

   sub navMode() {
navstart:
      vtui.fill_box(' ', 1, 1, $e1)
navcharloop:
      ubyte char = cbm.GETIN()
      when char {
          $1b -> { ; ESC key
            goto navcharloop
          }
          $49 -> { ; insert (I) 
            goto main.start.edit_mode 
          }
; TODO: make cursor movements non-destructive (using
; save_rect and rest_rect)
          $4b -> { ; nav up (K)
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $c6)
            main.line = main.line - 1;
            if (main.line < 3) {
              main.line = 3 
            }
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $e1)
            updateXY_ticker()
          }
          $4a -> { ; nav down (J)
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $c6)
            main.line = main.line + 1;
            if (main.line > 56) {
              main.line = 56 
            }
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $e1)
            updateXY_ticker()
          }
          $48 -> { ; nav left (H)
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $c6)
            main.col = main.col - 1;
            if (main.col < 3) {
              main.col  = 56 
              main.line = main.line - 1
              if (main.line < 3) {
                main.col  = main.originX ; prevent infinite L-R on the topmost line
                main.line = main.originY 
              }
            }
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $e1)
            updateXY_ticker()
          }
          $4c -> { ; nav right (L)
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $c6)
            main.col = main.col + 1;
            if (main.col > main.maxCol) {
              main.col  = 3
              main.line = main.line + 1
              if (main.line > 56) {
                main.col  = main.maxCol 
                main.line = 56 
              }
            }
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $e1)
            updateXY_ticker()
          }
          $3a -> { ; colon (:)
            vtui.gotoxy(2,58);
            vtui.fill_box(' ', 50, 1, $06)
            vtui.gotoxy(2,58);
            vtui.print_str2(": ", $01, true); 
            str cmdbuffer = " " * 10 
            vtui.gotoxy(3,58);
            vtui.input_str(cmdbuffer, 10, $01)
            if (cmdbuffer[0] == 'q') {
              vtui.gotoxy(1,1)
              txt.clear_screen()
              txt.print("thank you for using vicl1, the vi clone for the x16!\n\n")
              txt.print("for updates, please visit\n\n")
              txt.print("https://github.com/oodler577/vicl1\n")
              sys.exit(0)
            }
            else {
              vtui.gotoxy(2,58);
              vtui.fill_box(' ', 50, 1, $21)
              vtui.gotoxy(2,58);
              vtui.print_str2("not an editor command: ", $21, true)
              vtui.print_str2(cmdbuffer, $21, true)
              sys.wait(50)
              vtui.gotoxy(2,58);
              vtui.fill_box(' ', 50, 1, $50)
            }
          }
      }
      goto navcharloop
   }
}

;
; Below this line is the bindings using for the VTUI library via Prog8's "romsub" keyword
;

vtui $1000 {

    %option no_symbol_prefixing
    %asmbinary "VTUI-C1C7.BIN", 2     ; skip the 2 dummy load address bytes

    ; NOTE: base address $1000 here must be the same as the block's memory address, for obvious reasons!
    ; The routines below are for VTUI 1.0
    romsub $1000 = initialize() clobbers(A, X, Y)
    romsub $1002 = screen_set(ubyte mode @A) clobbers(A, X, Y)
    romsub $1005 = set_bank(bool bank1 @Pc) clobbers(A)
    romsub $1008 = set_stride(ubyte stride @A) clobbers(A)
    romsub $100b = set_decr(bool incrdecr @Pc) clobbers(A)
    romsub $100e = clr_scr(ubyte char @A, ubyte colors @X) clobbers(Y)
    romsub $1011 = gotoxy(ubyte column @A, ubyte row @Y)
    romsub $1014 = plot_char(ubyte char @A, ubyte colors @X)
    romsub $1017 = scan_char() -> ubyte @A, ubyte @X
    romsub $101a = hline(ubyte char @A, ubyte length @Y, ubyte colors @X) clobbers(A)
    romsub $101d = vline(ubyte char @A, ubyte height @Y, ubyte colors @X) clobbers(A)
    romsub $1020 = print_str(str txtstring @R0, ubyte length @Y, ubyte colors @X, ubyte convertchars @A) clobbers(A, Y)
    romsub $1023 = fill_box(ubyte char @A, ubyte width @R1, ubyte height @R2, ubyte colors @X) clobbers(A, Y)
    romsub $1026 = pet2scr(ubyte char @A) -> ubyte @A
    romsub $1029 = scr2pet(ubyte char @A) -> ubyte @A
    romsub $102c = border(ubyte mode @A, ubyte width @R1, ubyte height @R2, ubyte colors @X) clobbers(Y)              ; NOTE: mode 6 means 'custom' characters taken from r3 - r6
    romsub $102f = save_rect(ubyte ramtype @A, bool vbank1 @Pc, uword address @R0, ubyte width @R1, ubyte height @R2) clobbers(A, X, Y)
    romsub $1032 = rest_rect(ubyte ramtype @A, bool vbank1 @Pc, uword address @R0, ubyte width @R1, ubyte height @R2) clobbers(A, X, Y)
    romsub $1035 = input_str(uword buffer @R0, ubyte buflen @Y, ubyte colors @X) clobbers (A) -> ubyte @Y             ; NOTE: returns string length
    romsub $1035 = input_str_lastkey(uword buffer @R0, ubyte buflen @Y, ubyte colors @X) clobbers (Y) -> ubyte @A     ; NOTE: returns lastkey press
    romsub $1035 = input_str_retboth(uword buffer @R0, ubyte buflen @Y, ubyte colors @X) clobbers () -> uword @AY     ; NOTE: returns lastkey press, string length
    romsub $1038 = get_bank() clobbers (A) -> bool @Pc
    romsub $103b = get_stride() -> ubyte @A
    romsub $103e = get_decr() clobbers (A) -> bool @Pc

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
