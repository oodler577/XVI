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
    str blankLine           = " " * 79 
    str printBuffer         = " " * DATSZ 
    str lineBuffer          = " " * DATSZ 
    const ubyte CMDBUFFER_SIZE = 50
    str cmdBuffer           = " " * CMDBUFFER_SIZE
    uword TOT_LINES         = 0
    uword FIRST_LINE_INDEX  = 0           ; buffer index of the line that is in the topmost line of the TEXTBOX
    str currFilename        = " " * 128   ; for defining the path of the file to open

    const uword PTRSZ       = 2 ; in Bytes
    const uword RECSZ       = PTRSZ + DATSZ + PTRSZ 

    ; video and buffer base addresses
    const ubyte CURRENT_BANK = 1
    const uword BASE_PTR     = $A000 ; assumed beginning of CURRENT_BANK
    const uword VERA_ADDR_L  = $9F20
    const uword VERA_ADDR_M  = $9F21
    const uword VERA_ADDR_H  = $9F22
    const uword VERA_DATA0   = $9F23
    const uword VERA_DATA1   = $9F24
    const uword VERA_CTRL    = $9F25

    ; view port dimensions
    const ubyte TOP_TEXTBOX_LINE     = 1
    const ubyte LEFT_TEXTBOX_MARGIN  = 3
    const ubyte RIGHT_TEXTBOX_MARGIN = 78
    const ubyte MID_TEXTBOX_LINE  = 27
    const ubyte BOT_TEXTBOX_LINE  = 56
    const ubyte TEXTBOX_HEIGHT    = BOT_TEXTBOX_LINE - TOP_TEXTBOX_LINE
    const ubyte FOOTER_LINE       = 58

    ; defined mode constants
    const ubyte NAV            = 1 ; modal state for navigation, default state
    const ubyte EDI            = 2 ; modal state for insert mode, triggered with ctrl-i
    const ubyte REPLACE        = 3 ; modal state for replacement mode, triggered with ctrl-r
    const ubyte COMMAND        = 3 ; modal state for entering a 

    ; current mode
    ubyte MODE              = NAV ; set initial state to navigation
 

    sub vtg(ubyte col, ubyte row) {
      vtui.gotoxy(col, row)
    }

    sub init_canvas() {
      vtui.initialize()
      vtui.screen_set(0)
      vtui.clr_scr(' ', $50)
      vtg(main.LEFT_TEXTBOX_MARGIN-1,main.TOP_TEXTBOX_LINE-1)
      vtui.fill_box(' ', main.RIGHT_TEXTBOX_MARGIN, main.BOT_TEXTBOX_LINE, $c6)
      vtg(main.LEFT_TEXTBOX_MARGIN-1,main.TOP_TEXTBOX_LINE-1)
      vtui.border(1, RIGHT_TEXTBOX_MARGIN+1, BOT_TEXTBOX_LINE+1, $00)
    }

    ubyte    nngN  = 0        ; NN SHIFT+g counter
    ubyte[2] numb  = [0] * 2  ; digit for "NN SHIFT+g"
    uword    tmprow

    ; jumps to the very end of the document
    sub cursor_down_on_G () { ;; BROKEN
      main.FIRST_LINE_INDEX = main.TOT_LINES-main.TEXTBOX_HEIGHT
      txt.clear_screen()
      txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
      blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_INDEX, main.FIRST_LINE_INDEX-1+main.BOT_TEXTBOX_LINE-1)
      cursor.update_tracker()
      cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN,main.BOT_TEXTBOX_LINE-1)
    }

    sub cursor_down_on_nG() {
      nngN = 0 ; reset leading number counter
      if numb[0]-1 < main.FIRST_LINE_INDEX { ; covers case when 1-9 is above the visible top line
        main.FIRST_LINE_INDEX = 0
        txt.clear_screen();
        txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
        blocks.draw_range(CURRENT_BANK, main.TOP_TEXTBOX_LINE-1, main.BOT_TEXTBOX_LINE-1)
      }
      cursor.update_tracker()
      tmprow = (main.TOP_TEXTBOX_LINE+numb[0]-1)
      cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN, tmprow as ubyte)
    }

    sub cursor_down_on_nnG() {
      nngN = 0 ; reset leading number counter
      uword LINE = (numb[0]*10+numb[1]); combine array elements to an actual LINE

      ; condition LINE to be in bounds of the text document
      if LINE < 1 { 
        LINE = 1
      }
      else if LINE > main.TOT_LINES {
        LINE = main.TOT_LINES
      }

      uword LINE_INDEX = LINE - 1 ; dealing with buffer indexes for the rest of this subroutine

      ;; visible portion - between current top line and last line
      if LINE_INDEX >= main.FIRST_LINE_INDEX and LINE_INDEX <= main.FIRST_LINE_INDEX + main.BOT_TEXTBOX_LINE-1 {
        ;; within current visible range - don't update FIRST_LINE_INDEX
        tmprow=(LINE-main.FIRST_LINE_INDEX)
        cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN, tmprow as ubyte)
        cursor.update_tracker()
      }

;;        ;; above current top line
;;        if number-1 < main.FIRST_LINE_INDEX {
;;          txt.clear_screen();
;;          txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
;;          if number <= main.BOT_TEXTBOX_LINE {
;;            main.FIRST_LINE_INDEX = 0
;;            blocks.draw_range(CURRENT_BANK, main.TOP_TEXTBOX_LINE-1, main.BOT_TEXTBOX_LINE-1)
;;            cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN, number as ubyte)
;;          }
;;          else {
;;            main.FIRST_LINE_INDEX = number-1 ; set number to be that top most line now (shifts down)
;;            blocks.draw_range(CURRENT_BANK, number-1, main.BOT_TEXTBOX_LINE-1)
;;            cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
;;          }
;;        }
;;        ; first IF block covers the situation where number
;;        ;   is above the first currently visible line
;;        else if number-1 >= main.FIRST_LINE_INDEX + main.BOT_TEXTBOX_LINE {
;;          ;; below current visible range
;;          main.FIRST_LINE_INDEX = number-1-22
;;          txt.clear_screen();
;;          txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
;;          blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_INDEX, main.BOT_TEXTBOX_LINE) ;;          cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN, main.BOT_TEXTBOX_LINE) ;;        }
    }

    sub start() {
      init_canvas()
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      load_file("samples/sample6.txt", CURRENT_BANK) 
     NAVCHARLOOP:
      void, char = cbm.GETIN()
      ; catch leading numbers for "NN SHIFT+g"
      when char {
          $47 -> { ; jump to the bottom (SHIFT+g)
            when nngN {
              0 -> { ;; just "SHIFT+g" (no leading number)
                cursor_down_on_G()
              }
              1 -> { ;; single leading number + "SHIFT+g", (only covers case of lines 1-9)
                cursor_down_on_nG()
                goto NAVCHARLOOP
              }
              2 -> { ;; double leading number + "SHIFT+g"
                cursor_down_on_nnG()
                goto NAVCHARLOOP
              }
            }
          }
          $30 -> { ; bare '0' jumps to start of line
            when nngN {
              0 -> {
                ;; jump to start of the current line
                ubyte r   = txt.get_row()
                cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN,r)      ;; move actual cursor
                cursor.update_tracker()
              }
              1 -> {
                numb[nngN] = char - $30
                nngN++
              }
              else -> {
                nngN = 0
              }

            }
            goto NAVCHARLOOP
          }
          $31,$32,$33,$34,$35,$36,$37,$38,$39 -> { ; digits 1-9
            if nngN < 2 {
              numb[nngN] = char - $30
              nngN++
            }
            else {
              nngN = 0
            }
            goto NAVCHARLOOP
          }
      }
;
;; IN PROGRESS - working on COMMAND MODE and accepting s ...
;
      when char {
        $1b -> {       ; ESC key, throw into NAV mode from any other mode
          cursor.update_tracker()
          main.MODE = main.NAV
        }
        $3a -> {       ; ':',  mode
          if main.MODE == main.NAV {
            main.MODE = main.COMMAND
            cursor.command_prompt()
            ubyte cmdchar  = $60
            ubyte cmdi     = 0
           CMDCHARLOOP:
              void, cmdchar = cbm.GETIN()
              when cmdchar {
                $1b -> {
                  txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
                  cursor.update_tracker()
                  goto NAVCHARLOOP
                }
                $0d -> { ; <ENTER> ... dispatch commands  here
                  txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
                  when main.cmdBuffer[0] {
                    'e' -> {
                      txt.plot(1, main.FOOTER_LINE)
                      txt.print(main.blankLine)
                      txt.plot(1, main.FOOTER_LINE)
                      str fn1 = " " * main.CMDBUFFER_SIZE 
                      ; parse out file name (everything after ":e")
                      string.slice(main.cmdBuffer, 2, string.length(main.cmdBuffer), fn1)
                      string.strip(fn1)
                      load_file(fn1, CURRENT_BANK)
                    }
                    'q' -> {
                      txt.iso_off()
                      sys.exit(0)
                    }
                  }
                  sys.wait(10)
                  cursor.update_tracker()
                  goto NAVCHARLOOP ; go back to main navloop
                }
                else -> {
                  if cmdchar >= $20 and cmdchar <= $7f  {
                    ;; TODO - figure out how handle backspace in the CMD window???
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
              goto CMDCHARLOOP
          }
        }
        'h',$9d -> {       ; $68, LEFT 
          cursor_left_on_h()
        }
        'j',$11 -> {       ; $6a, DOWN
          cursor_down_on_j()
        }
        'k',$91 -> {       ; $6b, UP
          cursor_up_on_k()
        }
        'l',$1d -> {       ; $6c, RIGHT 
          cursor_right_on_l()
        }
      }
      goto NAVCHARLOOP 
    }

    sub cursor_down_on_j () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      ubyte next_row = r + 1
      if next_row <= main.BOT_TEXTBOX_LINE { ;; enforce bottom line bounds
        cursor.place_cursor(c,next_row)      ;; move actual cursor
        cursor.update_tracker()
      }
      else if (main.FIRST_LINE_INDEX + main.BOT_TEXTBOX_LINE < main.TOT_LINES) {
        main.FIRST_LINE_INDEX += 1
        ;txt.clear_screen()
        txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE) ; position for full screen redraw
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_INDEX, main.FIRST_LINE_INDEX+main.BOT_TEXTBOX_LINE-1) ; full screen redraw
        cursor.place_cursor(c,r)           ;; move actual cursor
        cursor.update_tracker()
      }
    }

    sub cursor_up_on_k () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if r > main.TOP_TEXTBOX_LINE {       ;; enforce bottom line bounds
        cursor.place_cursor(c,r-1)         ;; move actual cursor
        cursor.update_tracker()
      }
      else if (main.FIRST_LINE_INDEX > 0) {
        main.FIRST_LINE_INDEX -= 1
        ;txt.clear_screen()
        txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_INDEX, main.FIRST_LINE_INDEX+main.BOT_TEXTBOX_LINE-1)
        cursor.update_tracker()
        cursor.place_cursor(c,r)           ;; move actual cursor
      }
    }

    sub cursor_left_on_h () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if c-1 >= main.LEFT_TEXTBOX_MARGIN {  ;; enforce LHS bounds
        cursor.place_cursor(c-1,r)          ;; move actual cursor
        cursor.update_tracker()
      }
    }

    sub cursor_right_on_l () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if c+1 <= main.RIGHT_TEXTBOX_MARGIN { ;; enforce RHS bounds
        cursor.place_cursor(c+1,r)          ;; move actual cursor
        cursor.update_tracker()
      }
    }

    sub load_file(str filepath, ubyte BANK) {
        blocks.clear_bank()
        cbm.CLEARST() ; set so READST() is initially known to be clear
        if diskio.f_open(filepath) {
          main.TOT_LINES = 0
          main.currFilename = filepath
          while cbm.READST() == 0 {
            ;; reset these buffers
            lineBuffer  = " " * DATSZ
            printBuffer = " " * DATSZ 
            ; read line
            ubyte length
            length, void = diskio.f_readline(lineBuffer)
            ; write line to memory as a fixed width record
            blocks.poke_line_data(CURRENT_BANK, TOT_LINES)
            TOT_LINES += 1
          }
          diskio.f_close()
          txt.clear_screen()
          txt.plot(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE)
          blocks.draw_range(CURRENT_BANK, 0, main.BOT_TEXTBOX_LINE-1)
          cursor.update_tracker()
          cursor.init()
          cursor.place_cursor(main.LEFT_TEXTBOX_MARGIN,main.TOP_TEXTBOX_LINE) ;; move actual cursor
        }
     }
  }
