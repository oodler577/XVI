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
       ubyte c = txt.get_column() ; get current
       ubyte r = txt.get_row()
       txt.plot(0, main.FOOTER_LINE) ; move cursor to the starting position for writing
       conv.str_uw(main.TOT_LINES)
       txt.print(main.blankLine)
       txt.plot(0, main.FOOTER_LINE) ; move cursor to the starting position for writing
       txt.print(conv.string_out)
       txt.print(" lines, x:")
       ubyte col = c - main.LEFT_TEXTBOX_MARGIN + 1
       conv.str_ub(col)
       txt.print(conv.string_out)
       txt.print(", y:")
       uword row = r - main.TOP_TEXTBOX_LINE + main.FIRST_LINE_INDEX + 1
       conv.str_uw(row)
       txt.print(conv.string_out)
       txt.plot(c,r)
     }

     sub command_prompt () {
        ubyte c = txt.get_column()
        ubyte r = txt.get_row()
        txt.plot(0, main.FOOTER_LINE) ; move cursor to the starting position for writing
        txt.print(main.blankLine)
        txt.plot(1, main.FOOTER_LINE)
        txt.print("<CMD> : ")
     }

}
