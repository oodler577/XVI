messages {
  ubyte FILE_SAVING          = 1
  ubyte FILE_SAVED           = 2
  ubyte WARN_UNSAVED_CHANGES = 3 
  ubyte WARN_CLIPBOARD_EMPTY = 4

  uword ALARM_COUNT = 0
  uword ALARM_SET   = 0

  sub alarm(uword count) {
    ALARM_SET = 0
    if count > 0 {
      ALARM_SET = ALARM_COUNT + count 
    }
  }

  sub alert(str message, ubyte color1, ubyte color2) {
    ubyte length = strings.length(message)
    txt.plot(78-length, 0)
    txt.color2(color1, color2)
    txt.print(message)
    txt.plot(78-length, 0)
    txt.color2($1, $6) ; sets text back to default, white on blue
    txt.plot(view.LEFT_MARGIN, 0)
    txt.print(view.BLANK_LINE79)
  }

  sub info(str message) {
    alert(message, $7, $6)
    alarm(0)
  }

  sub show_if_set(ubyte message_id) {
    ubyte c = view.c()
    ubyte r = view.r()
    when message_id {
      FILE_SAVING -> {
        info("Saving file ...")
        alarm(120)
      }
      FILE_SAVED -> {
        info("File saved ...")
        alarm(120)
      }
    }
    flag.MESSAGE = 0 ; unset, but when to clear?
    
    txt.plot(c,r)
  }

  sub process(ubyte message_flag) {
    show_if_set(message_flag)
  }
}
