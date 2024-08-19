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

    sub restore_char(ubyte c, ubyte r) {
      txt.plot(c,r)
      txt.chrout(saved_char)
      txt.plot(c,r)
    }

    sub restore_current_char() {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      restore_char(c,r)
    }

    sub place_cursor(ubyte new_c, ubyte new_r) {
      restore_current_char() ;; restore char in current cursor location
      txt.plot(new_c,new_r)  ;; move cursor to new location
      save_current_char()    ;; save char in the current location (here, the new c,r)
      txt.chrout($5d)        ;; write cursor charactor, "]"
      txt.plot(new_c,new_r)  ;; move cursor back after txt.chrout advances cursor
    }
}
