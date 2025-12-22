%zeropage basicsafe
%option no_sysinit
%encoding iso

%import textio
%import strings
%import conv
%import syslib
%import diskio

mode {
  const ubyte NAV           = 1  ; modal state for navigation, default state
  const ubyte INSERT        = 2  ; modal state for insert mode, triggered with ctrl-i
  const ubyte REPLACE       = 3  ; modal state for replacement mode, triggered with ctrl-r
  const ubyte COMMAND       = 4  ; modal state for entering a 
}

view {
  const ubyte LEFT_MARGIN   = 3
  const ubyte RIGHT_MARGIN  = 78
  const ubyte HEIGHT        = 56 ; absolute height of the edit/view area
  const ubyte TOP_LINE      = 2  ; row+1 of the first line of the document (FIRST_LINE_IDX)
  const ubyte MIDDLE_LINE   = 27
  const ubyte BOTTOM_LINE   = 57 ; row+1 of the last line of the view port (LAST_LINE_IDX)
  const ubyte FOOTER_LINE   = 59
  str         BLANK_LINE    = " " * 79
  uword       CURR_TOP_LINE = 1  ; tracks which actual doc line is at TOP_LINE

  sub r() -> ubyte {
    return txt.get_row()
  }

  sub c() -> ubyte {
    return txt.get_column()
  }
}

cursor {
  str cmdBuffer = " " * 60
  ubyte saved_char

  sub save_char(ubyte c, ubyte r) {
    saved_char = txt.getchr(c,r)
  }

  sub save_current_char(ubyte c, ubyte r) {
    save_char(c,r)
  }

  sub restore_current_char() {
    ubyte c = view.c()
    ubyte r = view.r()
    txt.plot(c,r)
    txt.chrout(saved_char)
    txt.plot(c,r)
  }

  sub hide() {
    restore_current_char()
  }

  ; the cursor is the underlying character, with the color scheme inverted
  sub place(ubyte new_c, ubyte new_r) {
    restore_current_char()  ;; restore char in current cursor location
    txt.plot(new_c,new_r)   ;; move cursor to new location
    save_current_char(new_c, new_r)     ;; save char in the current location (here, the new c,r)
    txt.chrout(saved_char)  ;; write save char
    txt.setclr(new_c,new_r,$16) ; inverses color
    txt.plot(new_c,new_r)   ;; move cursor back after txt.chrout advances cursor
  }

  ; the cursor is the underlying character, with the color scheme inverted
  sub replace(ubyte new_c, ubyte new_r) {
    save_current_char(new_c, new_r)     ;; save char in the current location (here, the new c,r)
    txt.setclr(new_c,new_r,$16) ; inverses color
    txt.plot(new_c,new_r)   ;; move cursor back after txt.chrout advances cursor
  }

  sub command_prompt () {
     ubyte cmdchar
     txt.plot(0, view.FOOTER_LINE) ; move cursor to the starting position for writing
     txt.print(view.BLANK_LINE)
     txt.plot(0, view.FOOTER_LINE)
     txt.print(":")
     CMDINPUT:
       void, cmdchar = cbm.GETIN()
       if cmdchar != $0d { ; any character now but <ENTER>
         cbm.CHROUT(cmdchar)
       }
       else {
         ; reads in the command and puts it into view.cmdBuffer for additional
         ; processing in the view code
         ubyte i
         for i in 0 to strings.length(cmdBuffer) - 1 { 
           cmdBuffer[i] = txt.getchr(1+i, view.FOOTER_LINE)
         }
         strings.strip(cursor.cmdBuffer)
         return;
       } 
     goto CMDINPUT
  }

}

main {
  ubyte MODE               = mode.NAV ; initial mode is NAV

  struct Document {
    ubyte tabNum    ; 0
    ubyte charset   ; 0 = ISO, 1 = PETSCI
    ubyte startBank ; actual bank number for switching
    uword firstLine ; address of the first line of the document
    uword lineCount ; number of lines
    ^^ubyte filepath
    ubyte data00, data01, data02, data03, data04, data05, data06, data07
    ubyte data08, data09, data10, data11, data12, data13, data14, data15
    ubyte data16, data17, data18, data19, data20, data21, data22, data23
    ubyte data24, data25, data26, data27, data28, data29, data30, data31
    ubyte data32, data33, data34, data35, data36, data37, data38, data39
    ubyte data40, data41, data42, data43, data44, data45, data46, data47
    ubyte data48, data49, data50, data51, data52, data53, data54, data55
    ubyte data56, data57, data58, data59, data60, data61, data62, data63
    ubyte data64, data65, data66, data67, data68, data69, data70, data71
    ubyte data72, data73, data74, data75, data76, data77, data78, data79
    ubyte nullbyte
  }

  struct Line {
    ^^Line prev
    ^^Line next
    ^^ubyte text 
    ubyte data00, data01, data02, data03, data04, data05, data06, data07
    ubyte data08, data09, data10, data11, data12, data13, data14, data15
    ubyte data16, data17, data18, data19, data20, data21, data22, data23
    ubyte data24, data25, data26, data27, data28, data29, data30, data31
    ubyte data32, data33, data34, data35, data36, data37, data38, data39
    ubyte data40, data41, data42, data43, data44, data45, data46, data47
    ubyte data48, data49, data50, data51, data52, data53, data54, data55
    ubyte data56, data57, data58, data59, data60, data61, data62, data63
    ubyte data64, data65, data66, data67, data68, data69, data70, data71
    ubyte data72, data73, data74, data75, data76, data77, data78, data79
    ubyte nullbyte
  }

  ^^Document doc

  const uword MaxLength  = 80
  const uword LineSize   = sizeof(Line)

  const uword MaxLines   = 250
  const uword BufferSize = MaxLines * LineSize
  uword Buffer           = memory("Buffer", BufferSize, 1)

  ^^Line next = Buffer
  ^^Line head = 0 ; points to first line 
  ^^Line tail = 0 ; points to last line

  ; Allocator for linked list of Line instances contributed
  ; by MarkTheStrange on #prog8-dev
  sub allocLine(^^ubyte initial) -> ^^Line {
    ^^Line this = next                   ; return next space 
    next += 1                            ; advance to end of struct
    uword txtbuf = next as uword         ; use space after struct as buffer for text 
    next = next as uword + MaxLength + 1 ; and advance past buffer space
    ; link the new line in 
    if head == 0 {
        head = this
    } else {
        tail.next = this
    }

    ; populate the fields
    this.prev = tail
    this.next = 0
    this.text = txtbuf
    strings.copy(initial, this.text)

    tail = this
    ; and return
    return this
  }

  sub freeAll() {
    next = Buffer
    sys.memset(next, BufferSize, 0)
  }

  sub draw_initial_screen () {
      uword addr = Buffer
      ubyte i
      if doc.lineCount > view.BOTTOM_LINE - 1 {
        i = view.BOTTOM_LINE - 1
      }
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      repeat i {
        txt.plot(view.LEFT_MARGIN, txt.get_row())
        ^^Line line = addr
        say(line.text)
        addr = line.next
      }
  }

  sub load_file(str filepath) {
    ubyte i
    strings.strip(filepath)
    freeAll()
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
    strings.copy(filepath,doc.filepath)
    txt.print("Loading ")
    say(doc.filepath)
    sys.wait(20)
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
     doc.lineCount = 0

    ubyte tries = 0
    READFILE:
    cbm.CLEARST() ; set so READST() is initially known to be clear
    if diskio.f_open(filepath) {
      while cbm.READST() == 0 {
        ;; reset these buffers
        str lineBuffer  = " " * (MaxLength + 1)
        ; read line
        ubyte length
        length, void = diskio.f_readline(lineBuffer)
        strings.rstrip(lineBuffer)
        if length > MaxLength {
          str tmp = " " * (MaxLength + 1)
          strings.slice(lineBuffer, 0, MaxLength, tmp) 
          strings.copy(tmp, lineBuffer)
        } 
        uword lineAddr = allocLine(lineBuffer)
        doc.lineCount++
      }
      diskio.f_close()
      txt.clear_screen()
    }
    else {
      tries++
      diskio.f_close()
      if tries <= 15 {
        goto READFILE
      }
      else {
        txt.plot(0, view.BOTTOM_LINE)
        say(view.BLANK_LINE)
        txt.plot(view.LEFT_MARGIN, view.BOTTOM_LINE)
        txt.print("can't open file after 15 attempts ...")
        sys.wait(120)
        splash()
      }
    }
  }

  sub splash() {
    txt.clear_screen()
    txt.plot(0,view.TOP_LINE)
    repeat 20 {
      txt.plot(0, txt.get_row())
      say("~") 
    }
    say("~                             XVI - Commander X16 Vi               ")
    say("~                                                                  ")
    say("~                                 version 2.0.0                    ")
    say("~                             by Brett Estrade et al.              ")
    say("~                    XVI is open source and freely distributable   ")
    say("~                                                                  ")
    say("~                             Sponsor Prog8 development!           ")
    say("~                                  http://p8ug.org                 ")
    say("~                                                                  ")
    say("~                  type  :e filepath<Enter>    to load file to edit")
    say("~                  type  :q<Enter>             to exit             ")
    say("~                  type  :help<Enter> or <F1>  for on-line help    ")
    say("~                  type  :help version2<Enter> for version info    ")
    repeat 24 {
      txt.plot(0, txt.get_row())
      say("~") 
    }
  }

  sub start () {
    txt.iso()
    doc.tabNum               = 0 ; for future proofing
    doc.charset              = 0 ; for future proofing
    doc.startBank            = 1 ; for future proofing
    doc.lineCount            = 0
    doc.firstLine            = Buffer 
    doc.filepath             = " " * 81

    txt.plot(0,1)
    splash()

    ;sys.wait(120)
    load_file("sample6.txt")
    draw_initial_screen()
    cursor.place(view.LEFT_MARGIN, view.TOP_LINE)

    main.update_tracker()
    main.MODE = mode.NAV

    ubyte char = 0 
    NAVCHARLOOP:
     void, char = cbm.GETIN()
      when char {
        $1b -> {       ; ESC key, throw into NAV mode from any other mode
          main.MODE = mode.NAV
        }
        $3a -> {       ; ':',  mode
          if main.MODE == mode.NAV {
             main.MODE = mode.COMMAND

             cursor.command_prompt()

             ; clear command line
             txt.plot(0, view.FOOTER_LINE)
             prints(view.BLANK_LINE)

             ; parse out file name (everything after ":N")
             str fn1 = " " * 60
             strings.slice(cursor.cmdBuffer, 1, strings.length(cursor.cmdBuffer)-1, fn1)
             strings.strip(fn1)

             when cursor.cmdBuffer[0] {
               'e' -> {
                 load_file(fn1)
                 draw_initial_screen()
                 cursor.place(view.LEFT_MARGIN, view.TOP_LINE)
                 main.update_tracker()
                 main.MODE = mode.NAV
                }
               'q' -> {
                 txt.iso_off()
                 sys.exit(0)
               }
             }
          }
        }
        'g' -> {
          if main.MODE == mode.NAV {
           jump_to_begin()
          }
        }
        'G' -> {
          if main.MODE == mode.NAV {
           jump_to_end()
          }
        }
        'k',$91 -> {       ;  UP
          if main.MODE == mode.NAV {
            cursor_up_on_k()
          }
        }
        'j', $11 -> {      ; DOWN
          if main.MODE == mode.NAV {
            cursor_down_on_j()
          }
        }
        'h',$9d -> {       ; LEFT 
          if main.MODE == mode.NAV {
            cursor_left_on_h()
          }
        }
        'l',$1d -> {       ; RIGHT 
          if main.MODE == mode.NAV {
            cursor_right_on_l()
          }
        }
      }
      goto NAVCHARLOOP 
  }

  sub incr_top_line() -> uword {
    if  view.CURR_TOP_LINE + view.HEIGHT <= doc.lineCount {
      view.CURR_TOP_LINE++
    }
    return view.CURR_TOP_LINE     ; stops ++'ing with the last HEIGHT lines in the document 
  }

  sub decr_top_line() -> uword {
    if  view.CURR_TOP_LINE > 1 {
      view.CURR_TOP_LINE--
    }
    return view.CURR_TOP_LINE     ; returns 1 at the minimum
  }

  sub draw_screen (uword startingLine) {
      uword addr = Buffer         ; start address of memory allocation for document
      repeat startingLine-1 {     ; find starting line, linear search; may need an index
        ^^Line skip = addr
        addr = skip.next
      }
      ubyte c = view.c()
      ubyte row
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      repeat view.HEIGHT {
        row = view.r()
        ^^Line line = addr
        addr = line.next

        txt.plot(0, row)
        say(view.BLANK_LINE)
        txt.plot(view.LEFT_MARGIN, row)
        say(line.text)
      }
  }

  sub draw_bottom_line (uword lineNum) {
      uword addr = Buffer         ; start address of memory allocation for document
      repeat lineNum {            ; find starting line, linear search; may need an index
        ^^Line skip = addr
        addr = skip.next
      }
      ^^Line line = addr
      addr = line.next
      txt.plot(0, view.BOTTOM_LINE)
      say(view.BLANK_LINE)
      txt.plot(view.LEFT_MARGIN, view.BOTTOM_LINE)
      say(line.text)
  }

  sub draw_top_line (uword lineNum) {
      uword addr = Buffer         ; start address of memory allocation for document
      repeat lineNum {            ; find starting line, linear search; may need an index
        ^^Line skip = addr
        addr = skip.next
      }
      ^^Line line = addr
      addr = line.next
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      prints(line.text)
  }

  sub jump_to_begin() {
      ubyte c = view.c()
      view.CURR_TOP_LINE = 1
      draw_screen(view.CURR_TOP_LINE) 
      cursor.replace(c, view.TOP_LINE)
  }

  sub jump_to_end() {
      ubyte c = view.c()
      view.CURR_TOP_LINE = doc.lineCount - view.HEIGHT + 1
      draw_screen(view.CURR_TOP_LINE) 
      cursor.replace(c, view.BOTTOM_LINE)
  }

  sub cursor_up_on_k () {
    ; k (up) from going past line 1
    if view.CURR_TOP_LINE == 1 and view.r() == view.TOP_LINE {
      return
    }
    ubyte curr_line = view.r()
    ubyte curr_col  = view.c()
    ubyte next_line = curr_line-1;
    if curr_line == view.TOP_LINE {
      cursor.hide()
      txt.scroll_down()
      decr_top_line()
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      draw_top_line(view.CURR_TOP_LINE-1) 
      txt.plot(0, view.BOTTOM_LINE+1) ; blank footer line
      prints(view.BLANK_LINE)
      cursor.replace(curr_col, curr_line)
    }
    else {
      cursor.place(curr_col,next_line)
    }
    main.update_tracker()
  }

  sub cursor_down_on_j () {
    ; j (down) from going past doc.lineCount
    if view.CURR_TOP_LINE == doc.lineCount - view.HEIGHT + 1 and view.r() == view.BOTTOM_LINE {
      return
    }
    ubyte curr_line = view.r()
    ubyte curr_col  = view.c()
    ubyte next_line = curr_line+1;
    if curr_line == view.BOTTOM_LINE {
      cursor.hide()
      incr_top_line()               ; increment CURR_TOP_LINE
      txt.plot(0, view.FOOTER_LINE) ; blank footer line
      prints(view.BLANK_LINE)
      txt.plot(0, 1)    ; blank top line
      say(view.BLANK_LINE)
      prints(view.BLANK_LINE)
      txt.scroll_up()
      draw_bottom_line(view.CURR_TOP_LINE+view.HEIGHT-1-1)
      cursor.replace(curr_col, curr_line)
    }
    else {
      cursor.place(view.c(), next_line)
    }
    main.update_tracker()
  }

  sub cursor_left_on_h () {
    if view.c() > view.LEFT_MARGIN {
      cursor.place(view.c()-1,view.r())
    }
    main.update_tracker()
  }

  sub cursor_right_on_l () {
    if view.c() < view.RIGHT_MARGIN {
      cursor.place(view.c()+1,view.r())
    }
    main.update_tracker()
  }

  ; util functions

  sub update_tracker () {
    ubyte X = view.c()
    ubyte Y = view.r() 
    txt.plot(0, view.FOOTER_LINE)
    prints(view.BLANK_LINE)
    txt.plot(1, view.FOOTER_LINE)
    printw(doc.lineCount)
    prints(" lines, x: ")
    printw(X - view.LEFT_MARGIN + 1)
    prints(", y: ")
    printw(Y - view.TOP_LINE    + 1)
    prints(" - max line: ")
    printw(view.CURR_TOP_LINE+view.HEIGHT-1)
    txt.plot(X,Y)
  }

  sub prints (str x) {
    txt.print(x)
  }

  sub say (str x) {
    txt.print(x)
    txt.nl()
  }

  sub printb (ubyte x) {
    txt.print_ub(x)
  }

  sub sayb (ubyte x) {
    txt.print_ub(x)
    txt.nl()
  }

  sub printw (uword x) {
    txt.print_uw0(x) 
  }

  sub sayw (uword x) {
    txt.print_uw0(x) 
    txt.nl()
  }

  sub sayhex (uword x) {
    txt.print_uwhex(x, true) 
    txt.nl()
  }
}
