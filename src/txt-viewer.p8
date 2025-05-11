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
    const uword DATSZ        = 76
    str blankLine            = " " * 79 
    str printBuffer          = " " * DATSZ 
    str lineBuffer           = " " * DATSZ 
    const ubyte CMDBUFFER_SIZE = 50
    str cmdBuffer            = " " * CMDBUFFER_SIZE
    str currFilename         = " " * 128   ; for defining the path of the file to open

    const uword PTRSZ        = 2 ; in Bytes
    const uword RECSZ        = PTRSZ + DATSZ + PTRSZ 

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
    const ubyte TOP_LINE     = 1
    const ubyte LEFT_MARGIN  = 3
    const ubyte RIGHT_MARGIN = 78
    const ubyte HEIGHT       = 56
    const ubyte MIDDLE_LINE  = 27
    const ubyte BOTTOM_LINE  = 57
    const ubyte FOOTER_LINE  = 58

    ; define segment of the document buffer that is currently visible via
    ; the view port (TEXTBOX)
    uword DOC_LENGTH     = 0
    uword FIRST_LINE_IDX  = 0 ; buffer index of the line that is shown at the top of the TEXTBOX (view port)
    uword LAST_LINE_IDX       ; buffer index of the line that is show at the bottom of the TEXTBOX 

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
      vtg(main.LEFT_MARGIN-1,main.TOP_LINE-1)
      vtui.fill_box(' ', main.RIGHT_MARGIN, main.HEIGHT, $c6)
      vtg(main.LEFT_MARGIN-1,main.TOP_LINE-1)
      vtui.border(1, RIGHT_MARGIN+1, HEIGHT+1, $00)
    }

    ubyte    nngN  = 0        ; NN SHIFT+g counter
    ubyte[2] numb  = [0] * 2  ; digit for "NN SHIFT+g"
    uword    tmpline

    ; jumps to the very end of the document
    sub cursor_down_on_G () {
      ; the following mapping of text box line to file line index
      ; prints the 
      main.FIRST_LINE_IDX = main.DOC_LENGTH-main.HEIGHT
      main.LAST_LINE_IDX  = main.DOC_LENGTH-1
      ; prep screen
      txt.clear_screen()
      ; move cursor to the top left of the textbox
      txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
      blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_IDX, main.LAST_LINE_IDX)
      cursor.update_tracker()
      ; place cursor at the end of the written text
      uword eot = main.LAST_LINE_IDX-main.FIRST_LINE_IDX+1 ; finds the TEXTBOX line where file should end
      cursor.place_cursor(main.LEFT_MARGIN, eot as ubyte)  ; place cursor where the text ends
    }

    ; handles <number>+SHIFT+G
    sub cursor_down_on_nG() {
      nngN = 0 ; reset leading number counter

      if numb[0]-1 < main.FIRST_LINE_IDX { ; covers case when 1-9 is above the visible top line
        ; we want 1 to be the first line here
        main.FIRST_LINE_IDX = 0
        main.LAST_LINE_IDX  = main.HEIGHT-1 
        txt.clear_screen();
        txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_IDX, main.LAST_LINE_IDX)
      }
      cursor.update_tracker()
      tmpline = (main.TOP_LINE+numb[0]-1)
      cursor.place_cursor(main.LEFT_MARGIN, tmpline as ubyte)
    }

   ; handles <number><number>+SHIFT+G
    sub cursor_down_on_nnG() {
      nngN = 0 ; reset leading number counter
      uword NEXT_LINE = (numb[0]*10+numb[1]); combine array elements to an actual LINE
      uword LINE_IDX = NEXT_LINE - 1

      ;; NEXT_LINE is in current view, so just jump cursor to that line; no re-rendering or reassigning FIRST_LINE_IDX
      if LINE_IDX >= main.FIRST_LINE_IDX and LINE_IDX <= main.HEIGHT {
        cursor.update_tracker()
        cursor.place_cursor(main.LEFT_MARGIN, LINE_IDX+main.TOP_LINE-main.FIRST_LINE_IDX as ubyte) ; place cursor where the text ends
      }
      ;; NEXT_LINE is somewhere above current view
      else if LINE_IDX < main.FIRST_LINE_IDX {
        ; update FIRST_LINE_IDX
        main.FIRST_LINE_IDX = LINE_IDX
        main.LAST_LINE_IDX  = main.FIRST_LINE_IDX+main.HEIGHT-1
        txt.clear_screen();
        ; move cursor  to top of visible text box
        txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
        ; print range to the screen 
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_IDX, main.LAST_LINE_IDX)
        cursor.update_tracker()
        cursor.place_cursor(main.LEFT_MARGIN, main.TOP_LINE as ubyte)  ; place cursor where the text ends
      }
      else if LINE_IDX > main.LAST_LINE_IDX {
        ; update FIRST_LINE_IDX
        main.FIRST_LINE_IDX = LINE_IDX
        main.LAST_LINE_IDX  = main.FIRST_LINE_IDX+main.HEIGHT-1
        ; bound last line in draw range to not go beyond the current lenth of the document
        if (main.LAST_LINE_IDX >= main.DOC_LENGTH-1) {
          main.LAST_LINE_IDX  = main.DOC_LENGTH-1
          main.FIRST_LINE_IDX = main.LAST_LINE_IDX+1-main.HEIGHT
        }
        txt.clear_screen();
        ; move cursor  to top of visible text box
        txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
        ; print range to the screen 
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_IDX, main.LAST_LINE_IDX)
        cursor.update_tracker()
        uword eot = main.HEIGHT-(main.LAST_LINE_IDX-LINE_IDX) ; finds the TEXTBOX line where cursor should be
        cursor.place_cursor(main.LEFT_MARGIN, eot as ubyte)   ; place cursor where the text ends
      }
    }
    ; need one that handles <number><number><number>+SHIFT+G

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
                cursor.place_cursor(main.LEFT_MARGIN,r)      ;; move actual cursor
                cursor.update_tracker()
              }
              1 -> {
                numb[nngN] = char - $30
                nngN++
              }
              2 -> {
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
                  txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
                  cursor.update_tracker()
                  goto NAVCHARLOOP
                }
                $0d -> { ; <ENTER> ... dispatch commands  here
                  txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
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
      if next_row <= main.HEIGHT { ;; enforce bottom line bounds
        cursor.place_cursor(c,next_row)      ;; move actual cursor
        cursor.update_tracker()
      }
      else if (main.FIRST_LINE_IDX + main.HEIGHT < main.DOC_LENGTH) {
        main.FIRST_LINE_IDX += 1
        ;txt.clear_screen()
        txt.plot(main.LEFT_MARGIN,main.TOP_LINE) ; position for full screen redraw
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_IDX, main.FIRST_LINE_IDX+main.HEIGHT-1) ; full screen redraw
        cursor.place_cursor(c,r)           ;; move actual cursor
        cursor.update_tracker()
      }
    }

    sub cursor_up_on_k () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if r > main.TOP_LINE {       ;; enforce bottom line bounds
        cursor.place_cursor(c,r-1)         ;; move actual cursor
        cursor.update_tracker()
      }
      else if (main.FIRST_LINE_IDX > 0) {
        main.FIRST_LINE_IDX -= 1
        ;txt.clear_screen()
        txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
        blocks.draw_range(CURRENT_BANK, main.FIRST_LINE_IDX, main.FIRST_LINE_IDX+main.HEIGHT-1)
        cursor.update_tracker()
        cursor.place_cursor(c,r)           ;; move actual cursor
      }
    }

    sub cursor_left_on_h () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if c-1 >= main.LEFT_MARGIN {  ;; enforce LHS bounds
        cursor.place_cursor(c-1,r)  ;; move actual cursor
        cursor.update_tracker()
      }
    }

    sub cursor_right_on_l () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      if c+1 <= main.RIGHT_MARGIN { ;; enforce RHS bounds
        cursor.place_cursor(c+1,r)  ;; move actual cursor
        cursor.update_tracker()
      }
    }

    sub load_file(str filepath, ubyte BANK) {
        blocks.clear_bank()
        cbm.CLEARST() ; set so READST() is initially known to be clear
        if diskio.f_open(filepath) {
          main.DOC_LENGTH = 0
          main.currFilename = filepath
          while cbm.READST() == 0 {
            ;; reset these buffers
            lineBuffer  = " " * DATSZ
            printBuffer = " " * DATSZ 
            ; read line
            ubyte length
            length, void = diskio.f_readline(lineBuffer)
            ; write line to memory as a fixed width record
            blocks.poke_line_data(CURRENT_BANK, DOC_LENGTH)
            DOC_LENGTH += 1
          }
          diskio.f_close()
          txt.clear_screen()
          txt.plot(main.LEFT_MARGIN,main.TOP_LINE)
          blocks.draw_range(CURRENT_BANK, 0, main.HEIGHT-1)
          cursor.update_tracker()
          cursor.init()
          cursor.place_cursor(main.LEFT_MARGIN,main.TOP_LINE) ;; move actual cursor
        }
     }
  }
