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
    str cmdBuffer           = " " * DATSZ
    uword TOT_LINES         = 0
    uword lineShift         = 0           ; track by how many lines the view port has shift from 0,0 
    str currFilename        = " " * 128   ; for defining the path of the file to open

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

    const ubyte minCol      = 3
    const ubyte minLine     = 1
    const ubyte maxCol      = 78
    const ubyte midLine     = 27
    const ubyte maxLine     = 56
    const ubyte footerLine  = 58

    const ubyte NAV         = 1 ; modal state for navigation, default state
    const ubyte EDI         = 2 ; modal state for insert mode, triggered with ctrl-i
    const ubyte REPLACE     = 3 ; modal state for replacement mode, triggered with ctrl-r
    const ubyte COMMAND     = 3 ; modal state for entering a command

    ubyte MODE              = main.NAV ; set initial state to navigation
 

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
      blocks.draw_range(BANK1, main.lineShift, main.lineShift-1+main.maxLine-1)
      update_tracker()
      ;; move actual cursor
      cursor.place_cursor(main.minCol,main.maxLine-1)
    }

    sub start() {
      init_canvas()
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      load_file("samples/sample6.txt", BANK1) 

      ubyte    delN  = 0        ; dd (delete line) counter
      ubyte    cpyN  = 0        ; YY (copline) counter
      ubyte    nngN  = 0        ; NN SHIFT+g counter
      ubyte[2] numb  = [0] * 2  ; digit for "NN SHIFT+g"
      uword    tmprow

    navcharloop:
      void, char = cbm.GETIN()

      ; catch leading numbers for "NN SHIFT+g"
      when char {
          $47 -> { ; jump to the bottom (SHIFT+g)
            when nngN {
              0 -> { ;; just "SHIFT+g" (no leading number)
                cursor_down_on_G()
              }
              1 -> { ;; single leading number + "SHIFT+g", (only covers case of lines 1-9)
                nngN = 0 ; reset leading number counter
                if numb[0]-1 < main.lineShift { ; covers case when 1-9 is above the visible top line
                  main.lineShift = 0
                  txt.clear_screen();
                  txt.plot(main.minCol,main.minLine)
                  blocks.draw_range(BANK1, main.minLine-1, main.maxLine-1)
                  tmprow = (main.minLine+numb[0]-1)
                  cursor.place_cursor(main.minCol, tmprow as ubyte)
                }
                else {                          ; covers any other case, assumes 1-9 are in view goes there directly
                  tmprow = (main.minLine+numb[0]-1)
                  cursor.place_cursor(main.minCol, tmprow as ubyte)
                }
                update_tracker()
                goto navcharloop
              }
              2 -> { ;; double leading number + "SHIFT+g"
                nngN = 0 ; reset leading number counter
                uword number = (numb[0]*10+numb[1]); combine array elements to an actual number
                ;; above current top line
                if number-1 < main.lineShift {
                  txt.clear_screen();
                  txt.plot(main.minCol,main.minLine)
                  if number <= main.maxLine {
                    main.lineShift = 0
                    blocks.draw_range(BANK1, main.minLine-1, main.maxLine-1)
                    cursor.place_cursor(main.minCol, number as ubyte)
                  }
                  else {
                    main.lineShift = number-1 ; set number to be that top most line now (shifts down)
                    blocks.draw_range(BANK1, number-1, main.maxLine-1)
                    cursor.place_cursor(main.minCol,main.minLine)
                  }
                }
                ;; visible portion - between current top line and last line
                else if number-1 >= main.lineShift and number-1 <= main.lineShift + main.maxLine-1 {
                  ;; within current visible range - don't update lineShift
                  tmprow=(number-main.lineShift)
                  cursor.place_cursor(main.minCol,tmprow as ubyte)
                }
                ; first IF block covers the situation where number
                ;   is above the first currently visible line
                else if number-1 >= main.lineShift + main.maxLine {
                  ;; below current visible range
                  main.lineShift = number-1-22
                  txt.clear_screen();
                  txt.plot(main.minCol,main.minLine)
                  blocks.draw_range(BANK1, main.lineShift, main.maxLine)
                  cursor.place_cursor(main.minCol, main.maxLine)
                }
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
        $1b -> {       ; ESC key, throw into NAV mode from any other mode
          update_tracker()
          main.MODE = main.NAV
        }
;; IN PROGRESS - working on COMMAND MODE and accepting commands ...
        $3a -> {       ; ':', command mode
          if main.MODE == main.NAV {
            main.MODE = main.COMMAND
            command_prompt()
            ubyte cmdchar  = $60
            ubyte cmdi     = 0
            cmdcharloop:
              void, cmdchar = cbm.GETIN()
              when cmdchar {
                $1b -> {
                  txt.plot(main.minCol,main.minLine)
                  update_tracker()
                  goto navcharloop
                }
                $0d -> {                                   ; <ENTER> ... dispatch command here
                  txt.plot(main.minCol,main.minLine)
;; DEBUG - now parse command and do something (first: open up file with "e FILENAME")
;txt.plot(main.minCol, main.minLine)
;txt.print(blankLine)
;txt.plot(main.minCol, main.minLine)
                  if main.cmdBuffer[0] == $65 {
                    txt.plot(1, main.footerLine)
                    txt.print(main.blankLine)
                    txt.plot(1, main.footerLine)
                    txt.print("opening file ...")
                  }
;txt.print(main.cmdBuffer)
                  sys.wait(10)
                  update_tracker()
;; ALSO TODO - 
;; * organize the code into subroutines
;; * add some comments around state/flow control
;; ....
                  goto navcharloop ; go back to main navloop
                }
                else -> {
                  if cmdchar >= $20 and cmdchar <= $7f  {
;; HOW to handle backspace in CMD window???
                    if cmdchar == $7f or cmdchar == $08 {
                      cmdi--
                    }
                    else {
                      main.cmdBuffer[cmdi] = cmdchar ;; .. !! NEXT - need to figure out this assignment
                      cmdi++
                    }
                    cbm.CHROUT(cmdchar)
                  }
                }
              }
              goto cmdcharloop
          }
        }
        $65 -> {       ; 'e', for :e[dit] FILENAME

        }
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

     sub command_prompt () {
        ubyte c = txt.get_column()
        ubyte r = txt.get_row()
        txt.plot(0, main.footerLine) ; move cursor to the starting position for writing
        txt.print(main.blankLine)
        txt.plot(1, main.footerLine)
        txt.print("<CMD> : ")
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
        uword row = r - main.minLine + main.lineShift + 1
        conv.str_uw(row)
        txt.print(conv.string_out)
        txt.plot(c,r)
     }
  }
