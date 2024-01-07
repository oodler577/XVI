%import   textio
%import   conv
%import   syslib
%option   no_sysinit
%zeropage basicsafe

; simple test program for the "VTUI" text user interface library
; see:  https://github.com/JimmyDansbo/VTUIlib

main {
    ubyte minCol  = 3
    ubyte maxCol  = 76
    ubyte minLine = 3
    ubyte maxLine = 56
    ubyte line    = minLine
    ubyte col     = minCol
    ubyte Y       = 0

    sub init_canvas() {
        vtui.initialize()
        vtui.screen_set(0)
        vtui.clr_scr(' ', $50)
        vtui.gotoxy(2,2)
        vtui.fill_box('-', 76, 56, $c6)
        vtui.gotoxy(2,2)
        vtui.border(1, 76, 56, $00)
    }

    sub updateXY_ticker() {
        ubyte x = main.col  ;cx16.VERA_ADDR_L / 2   ; cursor X coordinate
        ubyte y = main.line ;cx16.VERA_ADDR_M - $b0 ; cursor Y coordinate

        vtui.gotoxy(68, 57)
        vtui.fill_box(' ', 7, 1, $00)
        vtui.gotoxy(68, 57)

        conv.str_ub0(x-2)
        vtui.print_str2(conv.string_out, $01, true)

        vtui.print_str2(" ", $01, true)

        conv.str_ub0(y-2)
        vtui.print_str2(",", $01, true)
        vtui.print_str2(conv.string_out, $01, true)

        vtui.gotoxy(main.col,main.line)
    }

    sub start() {
        init_canvas()

        ; init saved chars for non-destructive cursor moves
        vtui.gotoxy(main.minCol,main.minLine);
        vtui.save_rect($80, 1, $0100, 1, 1)

        ; place cursor initial position
        vtui.gotoxy(main.minCol,main.minLine);
        vtui.fill_box(' ', 1, 1, $e1)

        vtui.gotoxy(main.minCol,main.minLine);
        vtui.save_rect($80, 1, $0000, 1, 1)

        navMode()

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
      updateXY_ticker()
navstart:
      vtui.fill_box(' ', 1, 1, $e1)
navcharloop:
      ubyte newx = main.col
      ubyte newy = main.line
      ubyte char = cbm.GETIN()
      ubyte xtra
      when char {
          $1b -> { ; ESC key
            goto navcharloop
          }
          $49 -> { ; insert (I)
            goto main.start.edit_mode
          }
          $4b -> { ; nav up (K)
            if newy > minLine {
              newy--
            }
            move_cursor()
            updateXY_ticker()
          }
          $4a -> { ; nav down (J)
            if newy < maxLine {
              newy++
            }
            move_cursor()
            updateXY_ticker()
          }
          $48 -> { ; nav left (H)
            if newx > minCol {
              newx--
            }
            move_cursor()
            updateXY_ticker()
          }
          $4c -> { ; nav right (L)
            if newx < maxCol {
              newx++
            }
            move_cursor()
            updateXY_ticker()
          }
          $58 -> { ; delete, move left (X)
            vtui.gotoxy(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $c6)
            vtui.save_rect($80, 1, $0100, 1, 1)
            if newx > minCol {
              newx--
            }
            move_cursor()
            updateXY_ticker()
          }
          $5E -> { ; ^ (SHIFT+6), jump to start of the line
            newx = main.minCol
            move_cursor()
            updateXY_ticker()
          }
          $24 -> { ; $ (SHIFT+4), jump to start of the line
            newx = main.maxCol
            move_cursor()
            updateXY_ticker()
          }
          $59 -> { ; copy (Y)
; TODO - trigger on "YY"
            vtui.gotoxy(main.minCol,main.line)
            vtui.save_rect($80, 1, $0022, 73, 1)  ; save rectangle

            if newy < maxLine {
              newy++
            }
            move_cursor()
            updateXY_ticker()
          }
          $44 -> { ; cut (D)
; TODO - trigger on "DD"

; TODO - fix "streak" left by cursor
            vtui.gotoxy(main.minCol,main.line)
            vtui.save_rect($80, 1, $0022, 73, 1)  ; save rectangle

            vtui.gotoxy(main.minCol,main.line)    ; stay on current line, go to starting col
            vtui.fill_box(' ', 75, 1, $c6)        ; draw over (eventually needs to shift up

            if newy < maxLine {
              newy++
            }
            move_cursor()
            updateXY_ticker()
          }
          $50 -> { ; paste (P)
            ubyte prevy = main.line
            if newy < maxLine {
              newy++
              move_cursor()
              updateXY_ticker()

              vtui.gotoxy(main.minCol,prevy)
              vtui.rest_rect($80, 1, $0022, 74, 1)  ; restore saved memory here
            }
            else {
              vtui.rest_rect($80, 1, $0022, 74, 1)  ; restore saved memory here
              vtui.gotoxy(main.minCol,prevy)
              vtui.save_rect($80, 1, $0100, 1, 1)
            }
            move_cursor()
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
     sub move_cursor() {
       vtui.gotoxy(main.col, main.line)
       vtui.rest_rect($80, 1, $0100, 1, 1)
       vtui.gotoxy(newx, newy)
       vtui.save_rect($80, 1, $0100, 1, 1)
       vtui.gotoxy(newx, newy)
       vtui.rest_rect($80, 1, $0000, 1, 1)
       main.col  = newx
       main.line = newy
     }
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
