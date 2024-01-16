%import textio
%import conv
%import syslib
%import diskio
%option no_sysinit
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

    sub vtg(ubyte x, ubyte y) {
      vtui.gotoxy(x,y)
    }

    sub init_canvas() {
        vtui.initialize()
        vtui.screen_set(0)
        vtui.clr_scr(' ', $50)
        vtg(2,2)
        vtui.fill_box(' ', 76, 56, $c6)
        vtg(2,2)
        vtui.border(1, 76, 56, $00)
    }

    sub blank_line(ubyte line)  {
      vtg(main.minCol,line)
      vtui.fill_box(' ', 74, 1, $c6)      ; blank out line being moved in original position
    }

    sub copy_line(ubyte line, uword addr) {
      vtg(main.minCol,line)
      vtui.save_rect($80, 1, addr, 74, 1)  ; save line so it's available to (P)aste
    }

    sub cut_line(ubyte line, uword addr)  {
      copy_line(line, addr)               ; copy
      vtg(main.minCol,line)               ; go to line again, for "cut"
      vtui.fill_box(' ', 74, 1, $c6)      ; blank out line being moved in original position
    }

    sub paste_line(ubyte line, uword addr) {
      vtg(main.minCol,line)
      vtui.rest_rect($80, 1, addr, 74, 1)  ; restore rectangle
    }

    sub updateXY_ticker() {
        ubyte x = main.col  ;cx16.VERA_ADDR_L / 2   ; cursor X coordinate
        ubyte y = main.line ;cx16.VERA_ADDR_M - $b0 ; cursor Y coordinate

        vtg(68, 57)
        vtui.fill_box(' ', 7, 1, $00)
        vtg(68, 57)

        conv.str_ub0(x-2)
        vtui.print_str2(conv.string_out, $01, true)

        vtui.print_str2(" ", $01, true)

        conv.str_ub0(y-2)
        vtui.print_str2(",", $01, true)
        vtui.print_str2(conv.string_out, $01, true)

        vtg(main.col,main.line)
    }

    sub draw_cursor(ubyte col, ubyte line) {
        vtg(col,line);
        vtui.fill_box(' ', 1, 1, $e1)
    }

    sub init_spot(ubyte col, ubyte line) {  ; this is only used once in the beginning
        vtg(col,line);
        vtui.save_rect($80, 1, $0000, 1, 1) ; initialize what will be the cursor
    }

    sub cursor_presave(ubyte x, ubyte y) {
      vtg(x,y)
      vtui.save_rect($80, 1, $0100, 1, 1)   ; save what is under cursor for save_rect
    }

    sub cursor_restore(ubyte x, ubyte y) {
      vtg(x,y)
      vtui.rest_rect($80, 1, $0100, 1, 1)   ; restore what is under cursor for save_rect
    }

    sub place_cursor(ubyte x, ubyte y) {
      vtg(x,y)
      vtui.rest_rect($80, 1, $0000, 1, 1)   ; restore cursor
    }

    sub init_cursor(ubyte col, ubyte line) {; full initial set up of cursor
        cursor_presave(col,line);
        draw_cursor(col,line)
        init_spot(col,line)
    }

    sub start() {
        init_canvas()
        init_cursor(main.minCol,main.minLine)
        navMode() ; start off in nav mode, which is expected

        str inputbuffer = "?" * 73 ; this is the width of the inner box vtui box
        while 1 {
           vtg(main.col,main.line)
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
      ubyte    delN  = 0    ; dd (delete line) counter
      ubyte    cpyN  = 0    ; YY (copy) counter
      ubyte    nngN  = 0    ; NN SHIFT+g counter
      ubyte[2] numb  = 0    ; digit for "NN SHIFT+g"
      str      digit = "??"
navcharloop:
      ubyte newx = main.col
      ubyte newy = main.line
      ubyte char = cbm.GETIN()

      ; catch leading numbers for "NN SHIFT+g"
      when char {
          $c7 -> { ; jump to the bottom (SHIFT+g)
            if nngN == 1 {
              newy = main.minLine - 1 + numb[0]
            }
            if nngN == 2 {
              newy = main.minLine - 1 + (numb[0]*10+numb[1])
            }
            if nngN == 1 or nngN == 2 {
              nngN = 0          ; reset digit counter for "NN SHIFT+g"
              newx = main.minCol
              move_cursor()
              goto navcharloop
            }
            ; pass through since SHIFT+g is used below by itself
          }
          $30,$31,$32,$33,$34,$35,$36,$37,$38,$39 -> { ; digits 0-9
            if nngN < 2 {
              numb[nngN] = char - $30
              nngN++
            }
            else {
              nngN = 0
            }
            goto navcharloop
          }
      }

      when char {
          $1b -> { ; ESC key
            goto navcharloop
          }
          $49 -> { ; insert (i)
            goto main.start.edit_mode
          }
          $4b -> { ; nav up (k)
            if newy > minLine {
              newy--
            }
            move_cursor()
          }
          $4a -> { ; nav down (j)
            if newy < maxLine {
              newy++
            }
            move_cursor()
          }
          $48 -> { ; nav left (h)
            if newx > minCol {
              newx--
            }
            move_cursor()
          }
          $4c -> { ; nav right (l)
            if newx < maxCol {
              newx++
            }
            move_cursor()
          }
          $c7 -> { ; jump to the bottom (SHIFT+g)
            newx = main.minCol
            newy = main.maxLine
            move_cursor()
          }
          $58 -> { ; delete, move left (x)
            vtg(main.col,main.line)
            vtui.fill_box(' ', 1, 1, $c6)
            vtui.save_rect($80, 1, $0100, 1, 1)
            if newx > minCol {
              newx--
            }
            move_cursor()
          }
          $5E -> { ; ^ (SHIFT+6), jump to start of the line
            newx = main.minCol
            move_cursor()
          }
          $24 -> { ; $ (SHIFT+4), jump to start of the line
            newx = main.maxCol
            move_cursor()
          }
          $44 -> { ; cut (d+d) delete current line, shift all lines from main.line to main.maxLine up 1
            when delN {
              0 -> {
                delN++
                goto navcharloop
              }
              1 -> {
                delN = 0
              }
            }

            ; do delete
            if main.line+1 <= main.maxLine {
              cursor_restore(main.col,main.line)    ; restore what is under cursor

              copy_line(main.line, $0022)

              ; cut
              copy_line(1+main.line, $0400)         ; save line to move up
              blank_line(1+main.line)

              ; paste
              paste_line(main.line, $0400)          ; restore line being moved up
              cursor_presave(main.col, main.line)   ; save what's in the space the cursor is about to occupy 

              ubyte j
              for j in main.line+1 to main.maxLine-1 {
                copy_line(j+1, $0400) ; save line
                paste_line(j, $0400)  ; restore rectangle
              }

              blank_line(main.maxLine)              ; <~ confirm what this line is doing (replace when handling files that are more than 56 lines)
              cursor_restore(main.col,main.line)
              cursor_presave(main.col, main.line)   ; save what's in the space the cursor is about to occupy 
              cursor_restore(main.col,main.line)
              place_cursor(main.col,main.line)
            }
          }
          $59 -> { ; copy (Y+Y), no cursor advancement
            when cpyN {
              0 -> {
                cpyN++
                goto navcharloop
              }
              1 -> {
                cpyN = 0
              }
            }

            ; do copy
            cursor_restore(main.col,main.line)      ; restore what is under cursor for save_rect

            copy_line(main.line,$0022)

            place_cursor(main.col,main.line)        ; place cursor where user last saw it

            newx = main.col
            newy = main.line
            move_cursor()
          }
          $4f -> { ; lowercase "oh" (o), insert line below; switch to INSERT mode
            down_shift_o()
            newx = main.minCol
            if main.line != 56 {
              newy = main.line + 1
            }
            move_cursor()
            goto main.start.edit_mode
          }
          $cf -> { ; uppercase "oh" (SHIFT+o), insert line above
            down_shift_O()
            newx = main.minCol
            newy = main.line
            move_cursor()
            goto main.start.edit_mode
          }
          $50 -> { ; paste (p)
            down_shift_o()

            ; do update stuff
            paste_line(main.line, $0022)

            cursor_presave(main.col,main.line)      ; save what's going underneath cursor

            place_cursor(main.col,main.line)        ; restore cursor where user last saw it
          }
          $3a -> { ; colon (:)
            vtg(2,58);
            vtui.fill_box(' ', 50, 1, $06)
            vtg(2,58);
            vtui.print_str2(": ", $01, true);
            str cmdbuffer = " " * 10
            vtg(3,58);
            vtui.input_str(cmdbuffer, 10, $01)
            if (cmdbuffer[0] == 'q') {
              vtg(1,1)
              txt.clear_screen()
              txt.print("thank you for using vicl1, the vi clone for the x16!\n\n")
              txt.print("for updates, please visit\n\n")
              txt.print("https://github.com/oodler577/vicl1\n")
              sys.exit(0)
            }
            else {
              vtg(2,58);
              vtui.fill_box(' ', 50, 1, $21)
              vtg(2,58);
              vtui.print_str2("not an editor command: ", $21, true)
              vtui.print_str2(cmdbuffer, $21, true)
              sys.wait(50)
              vtg(2,58);
              vtui.fill_box(' ', 50, 1, $50)
            }
          }
     }
     goto navcharloop
     sub down_shift_o() {
       ubyte j
       for j in main.maxLine-1 to main.line+1 step -1 { ; descending from 2nd to last line to current line
         if j == main.line {  ; break if the first line is hit
           break
         }
         cut_line(j, $0400) ; copy line
         paste_line(j+1, $0400) ; paste line
       }
     }
     sub down_shift_O() {
       ubyte j
       for j in main.maxLine-1 to main.line+1 step -1 { ; descending from 2nd to last line to current line
         if j == main.line {  ; break if the first line is hit
           break
         }
         cut_line(j-1, $0400) ; copy line
         paste_line(j, $0400) ; paste line
       }
     }
     sub move_cursor() {
       cursor_restore(main.col, main.line)   ; restore what was under the cursor
       cursor_presave(newx, newy)            ; save what's current in the new position
       place_cursor(newx, newy)              ; place cursor in new position
       main.col  = newx
       main.line = newy
       updateXY_ticker()
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
