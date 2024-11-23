%import textio
%import string
%import conv
%import syslib
%import diskio
%import blocks
%import cursor
%import vtui
%option no_sysinit
%zeropage basicsafe
%encoding iso

main {
    const uword DATSZ       = 76
    str blankLine           = " " * DATSZ 
    str printBuffer         = " " * DATSZ 
    str lineBuffer          = " " * DATSZ 
    ubyte TOT_LINES         = 0
    const uword PTRSZ       = 2 ; in Bytes
    const uword RECSZ       = PTRSZ + DATSZ + PTRSZ 
    const ubyte BANK1       = 1

    ; for defining the path of the file to open
    str currFilename        = " " * 128

    const uword BASE_PTR    = $A000
    const uword VERA_ADDR_L = $9F20
    const uword VERA_ADDR_M = $9F21
    const uword VERA_ADDR_H = $9F22
    const uword VERA_DATA0  = $9F23
    const uword VERA_DATA1  = $9F24
    const uword VERA_CTRL   = $9F25

    ubyte lineShift         = 0 ; track by how many lines the view port has shift from 0,0 
    const ubyte minCol      = 3
    const ubyte minLine     = 1
    const ubyte maxCol      = 78
    const ubyte maxLine     = 56
    const ubyte footerLine  = 58

    sub vtg(ubyte col, ubyte row) {
      vtui.gotoxy(col, row)
    }

    sub init_canvas() {
      vtui.initialize()
      vtui.screen_set(0)
      vtui.clr_scr(' ', $50)
      vtg(main.minCol-1,main.minLine-1)
      vtui.fill_box(' ', main.maxCol, main.maxLine, $c6)
      vtg(main.minCol-1,main.minLine-1)
      vtui.border(1, maxCol+1, maxLine+1, $00)
    }

    sub cursor_down_on_j () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      ubyte next_row = r + 1
      if next_row <= main.maxLine {    ;; enforce bottom line bounds
        cursor.place_cursor(c,next_row)    ;; move actual cursor
        update_tracker()
      }
      else if (main.lineShift + main.maxLine < main.TOT_LINES) {
        main.lineShift += 1
        txt.plot(main.minCol,main.minLine)
        blocks.draw_range(BANK1, main.lineShift, main.lineShift+main.maxLine-1)
        update_tracker()
        cursor.place_cursor(main.minCol,main.maxLine) ;; move actual cursor
      }
    }

    sub cursor_down_on_G () {
      main.lineShift = main.TOT_LINES-main.maxLine
      txt.plot(main.minCol,main.minLine)
      blocks.draw_range(BANK1, main.lineShift, main.lineShift+main.maxLine-1)
      update_tracker()
      ;; move actual cursor
      cursor.place_cursor(main.minCol,main.maxLine)
    }

    sub start() {
      init_canvas()
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      load_file("samples/sample4.txt", BANK1) 

      ubyte    delN  = 0        ; dd (delete line) counter
      ubyte    cpyN  = 0        ; YY (copline) counter
      ubyte    nngN  = 0        ; NN SHIFT+g counter
      ubyte[2] numb  = [0] * 2  ; digit for "NN SHIFT+g"

    navcharloop:
      void, char = cbm.GETIN()

      ; catch leading numbers for "NN SHIFT+g"
      when char {
          $47 -> { ; jump to the bottom (SHIFT+g)
            when nngN {
              0 -> { ;; just "SHIFT+g" (no leading number)
                cursor_down_on_G()
              }
              1 -> { ;; single leading number + "SHIFT+g",
                nngN = 0 ; reset leading number counter
                if numb[0]-1 < main.lineShift {
                  main.lineShift = 0
                  txt.clear_screen();
                  txt.plot(main.minCol,main.minLine)
                  blocks.draw_range(BANK1, main.minLine-1, main.maxLine-1)
                  cursor.place_cursor(main.minCol,main.minLine+numb[0]-1)
                }
                else {
                  cursor.place_cursor(main.minCol,main.minLine+numb[0]-1)
                }
                update_tracker()
                goto navcharloop
              }
              2 -> { ;; double leading number + "SHIFT+g"
                nngN = 0 ; reset leading number counter
                ;main.lineShift = numb[1] 
                ubyte number = (numb[0]*10+numb[1]) ; combine array elements to an actual number
                cursor.place_cursor(main.minCol,main.minLine+number-1)
                update_tracker()
                goto navcharloop
              }
            }
          }
          $30 -> { ; bare '0' jumps to start of line
            when nngN {
              0 -> {
                ;; jump to start of the current line
                ubyte r   = txt.get_row()
                cursor.place_cursor(main.minCol,r)      ;; move actual cursor
                update_tracker()
              }
              1 -> {
                numb[nngN] = char - $30
                nngN++
              }
              else -> {
                nngN = 0
              }

            }
            goto navcharloop
          }
          $31,$32,$33,$34,$35,$36,$37,$38,$39 -> { ; digits 1-9
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
        $68 -> {       ; 'h', LEFT 
          cursor_left_on_h()
        }
        $6a -> {       ; 'j', DOWN
          cursor_down_on_j()
        }
        $6b -> {       ; 'k', UP
          cursor_up_on_k()
        }
        $6c -> {       ; 'l', RIGHT 
          cursor_right_on_l()
        }
        $71 -> {       ; 'q'
          txt.iso_off()
          sys.exit(0)
        }
      }
      goto navcharloop 
    }

    sub cursor_up_on_k () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if r-1 >= main.minLine {       ;; enforce bottom line bounds
        cursor.place_cursor(c,r-1)   ;; move actual cursor
        update_tracker()
      }
      else if (main.lineShift > 0) {
        main.lineShift -= 1
        txt.plot(main.minCol,main.minLine)
        blocks.draw_range(BANK1, main.lineShift, main.lineShift+main.maxLine-1)
        update_tracker()
        cursor.place_cursor(c,r)      ;; move actual cursor
      }
    }

    sub cursor_left_on_h () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if c-1 >= main.minCol {        ;; enforce LHS bounds
        cursor.place_cursor(c-1,r)   ;; move actual cursor
        update_tracker()
      }
    }

    sub cursor_right_on_l () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if c+1 <= main.maxCol {        ;; enforce RHS bounds
        cursor.place_cursor(c+1,r)   ;; move actual cursor
        update_tracker()
      }
    }

    sub load_file(str filepath, ubyte BANK) {
        cbm.CLEARST() ; set so READST() is initially known to be clear
        if diskio.f_open(filepath) {
          main.currFilename = filepath
          while cbm.READST() == 0 {
            ;; reset these buffers
            lineBuffer  = " " * 76
            printBuffer = " " * 76
            ; read line
            ubyte length
            length, void = diskio.f_readline(lineBuffer)
            ; write line to memory as a fixed width record
            blocks.poke_line_data(BANK1, TOT_LINES)
            TOT_LINES += 1
          }
          diskio.f_close()
          txt.plot(main.minCol,main.minLine)
          blocks.draw_range(BANK1, 0, main.maxLine-1)
          update_tracker()
          cursor.init()
          cursor.place_cursor(main.minCol,main.minLine) ;; move actual cursor
        }
     }

     sub update_tracker () {
        ubyte c = txt.get_column()
        ubyte r = txt.get_row()
        txt.plot(0, main.footerLine) ; move cursor to the starting position for writing
        conv.str_uw(main.TOT_LINES)
        txt.print(main.blankLine)
        txt.plot(0, main.footerLine) ; move cursor to the starting position for writing
        txt.print(conv.string_out)
        txt.print(" lines, x:")
        ubyte col = c - main.minCol + 1
        conv.str_ub(col)
        txt.print(conv.string_out)
        txt.print(", y:")
        ubyte row = r - main.minLine + 1
        conv.str_ub(row)
        txt.print(conv.string_out)
        txt.plot(c,r)
     }
  }
