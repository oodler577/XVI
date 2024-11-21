%import textio
%import string
%import conv
%import syslib
%import diskio
%import cursor
%import vtui
%option no_sysinit
%zeropage basicsafe
%encoding iso

main {
    str currFilename        = " " * 128
    str lineBuffer          = " " * 128
    str printBuffer         = " " * 128
    uword line              = 0
    const uword DATSZ       = 128
    const uword PTRSZ       = 2 ; in Bytes
    const uword RECSZ       = PTRSZ + DATSZ + PTRSZ 
    const ubyte BANK1       = 1

    const uword BASE_PTR    = $A000
    const uword VERA_ADDR_L = $9F20
    const uword VERA_ADDR_M = $9F21
    const uword VERA_ADDR_H = $9F22
    const uword VERA_DATA0  = $9F23
    const uword VERA_DATA1  = $9F24
    const uword VERA_CTRL   = $9F25

    ubyte lowLine                 = 0
    const ubyte minCol            = 2
    const ubyte minLine           = 1
    const ubyte maxCol            = 78
    const ubyte maxLine           = 56
    const ubyte footerLine        = 58

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

    sub start() {
      init_canvas()
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      load_file("samples/sample3.txt", BANK1) 

    navcharloop:
      void, char = cbm.GETIN()
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

    sub cursor_down_on_j () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if r+1 <= main.maxLine {        ;; enforce bottom line bounds
        cursor.place_cursor(c,r+1)    ;; move actual cursor
        update_tracker()
      }
      else if (lowLine + main.maxLine <= line) {
        lowLine += 1
        txt.plot(main.minCol,main.minLine)
        blocks.draw_range(BANK1, lowLine, main.maxLine-1)
        update_tracker()
        cursor.place_cursor(c,r)      ;; move actual cursor
      }
    }

    sub cursor_up_on_k () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if r-1 >= main.minLine {       ;; enforce bottom line bounds
        cursor.place_cursor(c,r-1)   ;; move actual cursor
        update_tracker()
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
            lineBuffer  = " " * 128
            printBuffer = " " * 128
            ; read line
            ubyte length
            length, void = diskio.f_readline(lineBuffer)
            ; write line to memory as a fixed width record
            blocks.poke_line_data(BANK1, line)
            line += 1
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
        txt.plot(58, main.footerLine)
        conv.str_uw(line)
        txt.print(conv.string_out)
        txt.print(" lines, x:")
        conv.str_ub(c)
        txt.print(conv.string_out)
        txt.print(", y:")
        conv.str_ub(r)
        txt.print(conv.string_out)
        txt.nl()
        txt.plot(c,r)
     }
  }

  blocks {
    ; +----------+----------------------------------------------+----------+
    ; | PREV_PTR |                 DATA - LINE TEXT             | NEXT_PTR |
    ; | 2 Bytes  |                 128 Bytes                    | 2 Bytes  |
    ; +----------+----------------------------------------------+----------+
    ; ^
    ; |-- main.BASE_PTR+main.RECSZ*recNo

    uword i;

    ;; writes line to memory
    sub poke_line_data (ubyte bank, uword line) {
;;; TODO - update pointer records for PREV/NEXT
      uword REC_START = main.BASE_PTR + (main.RECSZ * line)
      ubyte j = 0
      for i in 0 to main.DATSZ-1 {
         @(REC_START + main.PTRSZ + i) = main.lineBuffer[j]  ;; write to the memory bank
         j = j + 1
      }
    }

    sub draw_range (ubyte bank, uword startLine, uword numLines ) {
      ubyte j
      uword REC_START, line
      for line in startLine to numLines {
        j = 0
        REC_START = main.BASE_PTR + (main.RECSZ * line)
        for i in 0 to main.DATSZ {
           main.printBuffer[j] = @(REC_START + main.PTRSZ + i)
           j = j + 1
        }
        print_line()
      }
    }

    sub print_line () {
      ; start printing at main.minCol, keep row the same
      txt.plot(main.minCol, txt.get_row())
      txt.print(main.printBuffer)
      txt.nl()
    }
  }
