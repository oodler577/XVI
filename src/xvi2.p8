%zeropage basicsafe
%option no_sysinit
%encoding iso

%import textio
%import strings
%import conv
%import syslib
%import diskio
%import debug

mode {
  const ubyte NAV             = 1  ; modal state for navigation, default state
  const ubyte INSERT          = 2  ; modal state for insert mode, triggered with ctrl-i
  const ubyte REPLACE         = 3  ; modal state for replacement mode, triggered with ctrl-r
  const ubyte COMMAND         = 4  ; modal state for entering a 
}

view {
  const ubyte LEFT_MARGIN     = 4
  const ubyte RIGHT_MARGIN    = 79
  const ubyte HEIGHT          = 56 ; absolute height of the edit/view area
  const ubyte TOP_LINE        = 2  ; row+1 of the first line of the document (FIRST_LINE_IDX)
  const ubyte MIDDLE_LINE     = 27
  const ubyte BOTTOM_LINE     = 57 ; row+1 of the last line of the view port (LAST_LINE_IDX)
  const ubyte FOOTER_LINE     = 59
  str         BLANK_LINE      = " " * 79
  uword       CURR_TOP_LINE   = 1  ; tracks which actual doc line is at TOP_LINE
  uword[main.MaxLines] INDEX       ; Line to address look up
  ubyte FREEIDX               = 0
  uword[main.MaxLines] FREE        ; freed addresses to reuse 
  uword       CLIPBOARD       = 0  ; holds the address of the current line we can "paste"

  sub push_freed (uword addr) -> ubyte {
    view.FREE[view.FREEIDX] = addr
    ubyte addr_idx = view.FREEIDX
    view.FREEIDX++
    return addr_idx 
  }

  sub r() -> ubyte {
    return txt.get_row()
  }

  sub c() -> ubyte {
    return txt.get_column()
  }

  sub insert_line_before (uword new_addr, uword curr_line, uword lineCount) -> uword {
    uword newLineCount = lineCount + 1    ; new line count
    uword curr_idx     = curr_line - 1    ; array index in view.INDEX to put the new line addres
    uword last_idx     = newLineCount - 1 ; idx of the last line in the document

    uword i
    ; Note: the range decrements by 1 from last_idx to the idx right before new_idx,
    ; which is new_idx+1, since we're decrementing; ensures old contents in new_idx
    ; get copied into the slot 'below' it ...
    for i in last_idx downto curr_idx+1 step -1 {
      ubyte idx = i as ubyte
      view.INDEX[idx] = view.INDEX[idx-1]
    }

    ; finally, insert new address into the new_idx slot 
    view.INDEX[curr_idx as ubyte] = new_addr 

    return newLineCount
  }

  sub insert_line_after (uword new_addr, uword curr_line, uword lineCount) -> uword {
    uword next_line    = curr_line + 1    ; next line number
    uword newLineCount = lineCount + 1    ; new line count
    uword new_idx      = next_line - 1    ; array index in view.INDEX to put the new line addres
    uword last_idx     = newLineCount - 1 ; idx of the last line in the document

    uword i
    ; Note: the range decrements by 1 from last_idx to the idx right before new_idx,
    ; which is new_idx+1, since we're decrementing; ensures old contents in new_idx
    ; get copied into the slot 'below' it ...
    for i in last_idx downto new_idx+1 step -1 {
      ubyte idx = (i as ubyte) - 1
      view.INDEX[idx] = view.INDEX[idx-1]
    }

    ; finally, insert new address into the new_idx slot 
    view.INDEX[new_idx as ubyte] = new_addr 

    return newLineCount
  }

  sub delete_item (uword curr_line, uword lineCount) -> uword {
    uword newLineCount = lineCount - 1
    uword i
    for i in curr_line-1 to newLineCount {
      ubyte idx = i as ubyte
      view.INDEX[idx] = view.INDEX[idx + 1]
    }
    return newLineCount
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
     main.prints(view.BLANK_LINE)
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

  const uword MaxLines   = 256 
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
    void strings.copy(initial, this.text)

    tail = this
    ; and return
    return this
  }

  sub allocNewLine(^^ubyte initial) -> ^^Line {
    ^^Line this = next                   ; return next space 
    next += 1                            ; advance to end of struct
    uword txtbuf = next as uword         ; use space after struct as buffer for text 
    next = next as uword + MaxLength + 1 ; and advance past buffer space
    ; populate the fields
    this.prev = 0 
    this.next = 0
    this.text = txtbuf
    void strings.copy(initial, this.text)
    return this
  }

  sub freeAll() {
    next = Buffer
    sys.memset(next, BufferSize, 0)
  }

  sub load_file(str filepath) {
    strings.strip(filepath)
    freeAll()
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
    void strings.copy(filepath,doc.filepath)
    txt.print("Loading ")
    say(doc.filepath)
    sys.wait(20)
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
    doc.lineCount = 0

    ubyte tries = 0
    ubyte idx   = 0
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
          void strings.copy(tmp, lineBuffer)
        } 
        uword lineAddr = allocLine(lineBuffer)
        idx = doc.lineCount as ubyte
        view.INDEX[idx] = lineAddr
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
        prints(view.BLANK_LINE)
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

; todo:
; - replace mode <esc>r
; - insert mode  <esc>i (most commonly used writing mode)
; - :w filetosave.txt
; - fix bug in dd that crashes when dd'd last line
; - :set number / :set nonumber (turns line numbers on/off)

; DONE:
; - dd, o
; - yy, p, P, O

    ubyte char = 0 
    NAVCHARLOOP:
      void, char = cbm.GETIN()
      when char {
        $0c -> {
          view.CURR_TOP_LINE = 1
          draw_initial_screen()
          cursor.replace(view.LEFT_MARGIN, view.TOP_LINE)
          main.update_tracker()
          main.MODE = mode.NAV
        }
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
        'd' -> {
          if main.MODE == mode.NAV {
            DDLOOP:
            void, char = cbm.GETIN()
            when char {
              $1b -> {       ; ESC key, throw into NAV mode from any other mode
                main.MODE = mode.NAV
                goto NAVCHARLOOP 
              }
              'd' -> {
                main.do_dd()
                goto NAVCHARLOOP 
              }
            }
            goto DDLOOP
          }
        }
        'O' -> {
          if main.MODE == mode.NAV {
            main.insert_line_above()
          }
        }
        'o' -> {
          if main.MODE == mode.NAV {
            main.insert_line_below()
          }
        }
        'y' -> {
          if main.MODE == mode.NAV {
            YYLOOP:
            void, char = cbm.GETIN()
            when char {
              $1b -> {       ; ESC key, throw into NAV mode from any other mode
                main.MODE = mode.NAV
                goto NAVCHARLOOP 
              }
              'y' -> {
                main.do_yy()
                goto NAVCHARLOOP 
              }
            }
            goto YYLOOP
          }
        }
        'P' -> {
          if main.MODE == mode.NAV {
            main.paste_line_above()
          }
        }
        'p' -> {
          if main.MODE == mode.NAV {
            main.paste_line_below()
          }
        }
        ; N A V I G A T I O N
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
        $06,$46 -> {  ; ctrl+f / shift+f
          if main.MODE == mode.NAV {
            page_forward()
          }
        }
        $02,$42 -> {  ; ctrl+b / shift+b
          if main.MODE == mode.NAV {
            page_backward()
          }
        }
      }
      goto NAVCHARLOOP 
  }

  sub alert(str message, ubyte ret_col, ubyte ret_row, ubyte delay, ubyte color) {
    txt.plot(67, 1)
    txt.color(color)
    prints(message)
    sys.wait(delay)
    txt.plot(67, 1)
    str BLANK = " " * 11 
    txt.color($1) ; sets text back to white
    prints(BLANK)
    txt.plot(ret_col, ret_row)
  }

  sub get_line_num(ubyte r) -> uword {
    const uword top = mkword(00,view.TOP_LINE)
    uword row       = mkword(00,r)
    uword curr_line = view.CURR_TOP_LINE + row - top
    return curr_line
  }

  sub get_Line_addr(ubyte r) -> uword {
    uword curr_line = main.get_line_num(r)
    ubyte idx = (curr_line as ubyte) - 1
    return view.INDEX[idx]
  }

  sub paste_line_above() {
    if view.CLIPBOARD == 0 { ; indicates empty clipboard (nothing copied yet)
      return
    }

    ubyte c = view.c()
    ubyte r = view.r()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)        ; gets memory addr of current Line
    ^^Line old_prev  = curr_addr.prev
    ^^Line copy_addr = view.CLIPBOARD
    ^^Line new_prev  = main.allocNewLine(copy_addr.text) ; new line with text from copied address

    old_prev.next  = new_prev 
    new_prev.next  = curr_addr
    curr_addr.prev = new_prev
    new_prev.prev  = old_prev

    ;; call to update INDEX
    doc.lineCount  = view.insert_line_before(new_prev, main.get_line_num(r), doc.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], new_prev, debug.EQ, "INDEX[curr_line as ubyte - 1] == new_prev")
    void debug.assert(view.INDEX[curr_line as ubyte], curr_addr, debug.EQ, "INDEX[curr_line as ubyte] == curr_addr")

    draw_screen()     ; should be draw_screen(), but this is a much simpler function to debug with
    txt.plot(c,r+1)

    cursor.replace(c, r+1)
    main.update_tracker()
  }


  sub paste_line_below() {
    if view.CLIPBOARD == 0 { ; indicates empty clipboard (nothing copied yet)
      return
    }

    ubyte c = view.c()
    ubyte r = view.r()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)        ; gets memory addr of current Line
    ^^Line copy_addr = view.CLIPBOARD
    ^^Line new_next  = main.allocNewLine(copy_addr.text) ; new line with text from copied address

    new_next.prev  = curr_addr
    new_next.next  = curr_addr.next 
    curr_addr.next = new_next

    ;; call to update INDEX
    doc.lineCount  = view.insert_line_after(new_next, main.get_line_num(r), doc.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], curr_addr, debug.EQ, "INDEX[curr_line as ubyte - 1] == curr_addr")
    void debug.assert(view.INDEX[curr_line as ubyte], new_next, debug.EQ, "INDEX[curr_line as ubyte] == new_next")

    draw_screen()     ; should be draw_screen(), but this is a much simpler function to debug with
    txt.plot(c,r+1)

    cursor.replace(c, r+1)
    main.update_tracker()
  }

  sub insert_line_above() {
    ubyte c = view.c()
    ubyte r = view.r()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)        ; gets memory addr of current Line
    ^^Line old_prev  = curr_addr.prev
    ^^Line new_prev  = main.allocNewLine("  ") ; creates new Line instance to insert

    old_prev.next  = new_prev 
    new_prev.next  = curr_addr
    curr_addr.prev = new_prev
    new_prev.prev  = old_prev

    ;; call to update INDEX
    doc.lineCount  = view.insert_line_before(new_prev, main.get_line_num(r), doc.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], new_prev, debug.EQ, "INDEX[curr_line as ubyte - 1] == new_prev")
    void debug.assert(view.INDEX[curr_line as ubyte], curr_addr, debug.EQ, "INDEX[curr_line as ubyte] == curr_addr")

    draw_screen()     ; should be draw_screen(), but this is a much simpler function to debug with
    txt.plot(c,r+1)

    cursor.replace(c, r+1)
    main.update_tracker()
  }

  sub insert_line_below() {
    ubyte c = view.c()
    ubyte r = view.r()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)        ; gets memory addr of current Line
    ^^Line new_next  = main.allocNewLine("  ") ; creates new Line instance to insert

    new_next.prev  = curr_addr
    new_next.next  = curr_addr.next 
    curr_addr.next = new_next

    ;; call to update INDEX
    doc.lineCount  = view.insert_line_after(new_next, main.get_line_num(r), doc.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], curr_addr, debug.EQ, "INDEX[curr_line as ubyte - 1] == curr_addr")
    void debug.assert(view.INDEX[curr_line as ubyte], new_next, debug.EQ, "INDEX[curr_line as ubyte] == new_next")

    draw_screen()     ; should be draw_screen(), but this is a much simpler function to debug with
    txt.plot(c,r+1)

    cursor.replace(c, r+1)
    main.update_tracker()
  }

  sub do_yy() {
    ubyte col = view.c()
    ubyte row = view.r()

    ^^Line curr_addr = get_Line_addr(row) ; line being deleted
    ^^Line prev_addr = curr_addr.prev     ; line before line being deleted
    ^^Line next_addr = curr_addr.next     ; line after line being deleted

    view.CLIPBOARD   = curr_addr
    alert("COPIED!", col, row, 60, $7)
  }

;; `dd` on very last line causes emulator to crash ...
  sub do_dd() {
    ubyte col = view.c()
    ubyte row = view.r()

    ^^Line curr_addr = get_Line_addr(row) ; line being deleted
    ^^Line prev_addr = curr_addr.prev     ; line before line being deleted
    ^^Line next_addr = curr_addr.next     ; line after line being deleted

    ; track "freed" Lines, returns index in view.FREE
    void view.push_freed(curr_addr)

    ; short circuit curr_line out of links
    prev_addr.next = next_addr
    next_addr.prev = prev_addr

    doc.lineCount = view.delete_item(main.get_line_num(row), doc.lineCount)

    draw_screen()

    cursor.replace(col, row)
    main.update_tracker()

    view.CLIPBOARD   = curr_addr ; save deleted address to clipboard for later pasting
    alert("DELETED!", col, row, 20, $2)
  }

  sub incr_top_line(uword value) -> uword {
    if  view.CURR_TOP_LINE + value <= doc.lineCount {
      view.CURR_TOP_LINE += value
    }
    return view.CURR_TOP_LINE     ; stops ++'ing with the last HEIGHT lines in the document 
  }

  sub decr_top_line(uword value) -> uword {
    if  view.CURR_TOP_LINE - value >= 1 {
      view.CURR_TOP_LINE -= value
    }
    return view.CURR_TOP_LINE     ; returns 1 at the minimum
  }

  sub printLineNum (uword number) {
    txt.color($f)
    printW(number)
    txt.color($1)
  }

  sub draw_initial_screen () {
      uword addr = view.INDEX[0]
      ubyte i = doc.lineCount as ubyte ; won't be used if > view.HEIGHT
      ; catch docs that go beyond screen
      if doc.lineCount > view.HEIGHT {
        i = view.HEIGHT
      }
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      ubyte row = view.TOP_LINE
      uword lineNum = 1
      repeat i {
        txt.plot(0, row)
        printLineNum(lineNum)
        txt.plot(view.LEFT_MARGIN,row)
        ^^Line line = addr
        say(line.text)
        addr = line.next
        row++
        lineNum++
      }
  }

  sub draw_screen () {               ; NOTE: assumes view.CURR_TOP_LINE is correct
      ubyte idx = (view.CURR_TOP_LINE as ubyte) - 1
      ^^Line line = view.INDEX[idx]
      void view.c()
      ubyte row
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      ubyte m,n
      if (doc.lineCount / view.CURR_TOP_LINE > 1) {
        m = view.HEIGHT
        n = 0
      }
      else {
        m = (doc.lineCount % view.CURR_TOP_LINE) as ubyte + 1
        n = view.HEIGHT - (doc.lineCount - view.CURR_TOP_LINE) as ubyte - 1
      }
      uword lineNum = view.CURR_TOP_LINE
      repeat m {
        row = view.r()
        txt.plot(0, row)
        prints(view.BLANK_LINE)
        txt.plot(0, row)
        printLineNum(lineNum)
        txt.plot(view.LEFT_MARGIN, row)
        say(line.text)
    
        ; get next Line
        line = line.next
        lineNum++
      }
      repeat n {
        row = view.r()
        prints(view.BLANK_LINE)
        txt.plot(0,row)
        say("~")
      }
  }

  sub draw_bottom_line (uword lineNum) {
      if lineNum > doc.lineCount {
        return
      }
      ubyte idx = lineNum as ubyte - 1
      uword addr = view.INDEX[idx]
      ^^Line line = addr
      addr = line.next
      txt.plot(0, view.BOTTOM_LINE)
      prints(view.BLANK_LINE)
      txt.plot(0, view.BOTTOM_LINE)
      printLineNum(lineNum)
      txt.plot(view.LEFT_MARGIN, view.BOTTOM_LINE)
      say(line.text)
  }

  sub draw_top_line (uword lineNum) {
      if lineNum < 1 {
        return
      }
      ubyte idx = lineNum as ubyte - 1
      uword addr = view.INDEX[idx]
      ^^Line line = addr
      addr = line.next
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      prints(line.text)
      txt.plot(0, view.TOP_LINE)
      printLineNum(lineNum)
  }

  sub page_forward() {
      ubyte c = view.c()
      uword last_page_start = doc.lineCount - view.HEIGHT + 1
      if view.CURR_TOP_LINE + view.HEIGHT < last_page_start {
        void incr_top_line(view.HEIGHT)
      }
      else {
        view.CURR_TOP_LINE = last_page_start
      }
      draw_screen() 
      cursor.replace(c, view.BOTTOM_LINE)
      main.update_tracker()
  }

  sub page_backward() {
      ubyte c = view.c()
      if view.CURR_TOP_LINE > view.HEIGHT {
        view.CURR_TOP_LINE = view.CURR_TOP_LINE - view.HEIGHT; 
      }
      else {
        view.CURR_TOP_LINE = 1
      }
      draw_screen() 
      cursor.replace(c, view.TOP_LINE)
      main.update_tracker()
  }

  sub jump_to_begin() {
      ubyte c = view.c()
      if doc.lineCount > view.HEIGHT {
        view.CURR_TOP_LINE = 1
        draw_screen() 
      }
      cursor.replace(c, view.TOP_LINE)
      main.update_tracker()
  }

  sub jump_to_end() {
      ubyte c = view.c()
      if doc.lineCount > view.HEIGHT {
        view.CURR_TOP_LINE = doc.lineCount - view.HEIGHT + 1
        draw_screen() 
        cursor.replace(c, view.BOTTOM_LINE)
      }
      else {
        cursor.place(c, (doc.lineCount as ubyte) + 1)
      }
      main.update_tracker()
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
      void decr_top_line(1)
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      draw_top_line(view.CURR_TOP_LINE) 
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
      void incr_top_line(1)               ; increment CURR_TOP_LINE
      txt.plot(0, view.FOOTER_LINE) ; blank footer line
      prints(view.BLANK_LINE)
      txt.plot(0, 1)    ; blank top line
      say(view.BLANK_LINE)
      prints(view.BLANK_LINE)
      txt.scroll_up()
      draw_bottom_line(view.CURR_TOP_LINE+view.HEIGHT-1)
      cursor.replace(curr_col, curr_line)
    }
    else if next_line < doc.lineCount+view.TOP_LINE {
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
    prints(" - TOP: ")
    printw(view.CURR_TOP_LINE)
    prints(" - BOT: ")
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

;  sub sayb (ubyte x) {
;    printb(x)
;    txt.nl()
;  }
;
;  sub printb (ubyte x) {
;    txt.print_ub0(x) 
;  }
;
;  sub printB (ubyte x) {
;    txt.print_ub(x) 
;  }

  sub printw (uword x) {
    txt.print_uw0(x) 
  }

  sub printW (uword x) {
    txt.print_uw(x) 
  }

;  sub printH (uword x) {
;    txt.print_uwhex(x, true)
;  }
;
;  sub sayH (uword x) {
;    main.printH(x)
;    txt.nl()
;  }

}
