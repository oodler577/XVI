; maybe external module contribution to deal with cursor movements
cursor {
    ubyte saved_char

    sub init() {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      save_char(c,r)
    }

    sub save_char(ubyte c, ubyte r) {
      saved_char = txt.getchr(c,r)
    }

    sub save_current_char() {
      init()
    }

    sub restore_current_char() {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      txt.plot(c,r)
      txt.chrout(saved_char)
      txt.plot(c,r)
    }

    ; the cursor is the underlying character, with the color scheme inverted
    sub place_cursor(ubyte new_c, ubyte new_r) {
      restore_current_char()  ;; restore char in current cursor location
      txt.plot(new_c,new_r)   ;; move cursor to new location
      save_current_char()     ;; save char in the current location (here, the new c,r)
      txt.chrout(saved_char)  ;; write save char
      txt.setclr(new_c,new_r,$16) ; inverses color
      txt.plot(new_c,new_r)   ;; move cursor back after txt.chrout advances cursor
    }

     sub update_tracker () {
       txt.color2(7,0)

       ubyte c = txt.get_column() ; get current
       ubyte r = txt.get_row()
       txt.plot(0, main.FOOTER_LINE) ; move cursor to the starting position for writing
       txt.print(main.blankLine)
       txt.plot(0, main.FOOTER_LINE) ; move cursor to the starting position for writing
       txt.print(conv.str_uw(main.DOC_LENGTH))
       txt.print(" lines, x: ")
       ubyte col = c - main.LEFT_MARGIN + 1
       txt.print(conv.str_ub(col))
       txt.print(", y: ")
       uword X = r - main.TOP_LINE + main.FIRST_LINE_IDX + 1
       txt.print(conv.str_uw(X))

;;; mostly for debugging
       txt.color2(4,0)

       txt.print("  first line idx: ")
       txt.print(conv.str_uw(main.FIRST_LINE_IDX))
       txt.print(", last line idx: ")
       txt.print(conv.str_uw(main.LAST_LINE_IDX))
;;; mostly for debugging

       txt.plot(c,r)

       txt.color2(5,0)
     }

     sub command_prompt () {
        ubyte cmdchar
        txt.plot(0, main.FOOTER_LINE) ; move cursor to the starting position for writing
        txt.print(main.blankLine)
        txt.plot(0, main.FOOTER_LINE)
        txt.print(": ")
        CMDINPUT:
          void, cmdchar = cbm.GETIN()
          if cmdchar != $0d { ; any character now but <ENTER>
            cbm.CHROUT(cmdchar)
          }
          else {
            ; reads in the command and puts it into main.cmdBuffer for additional
            ; processing in the main code
            ubyte i
            for i in 0 to strings.length(main.cmdBuffer) - 1 { 
              main.cmdBuffer[i] = txt.getchr(2+i, main.FOOTER_LINE)
            }
            return;
          } 
        goto CMDINPUT
     }
}
