; DOING: <- start here!!
; - (PRIORITY) insert mode  <esc>i (most commonly used writing mode)
; -- build on current functionality of 'i' which is to shift right and insert space
; -- also add 'a', which is going to append to the right of the current x,y
; - add fast "scroll_down" on in 'R' and hit 'enter' (currently way to slow
; -- when it hits draw_screen() on new buffer)

; TODO:
; - use 'R' mode over and over again - record and triage bugs
; - fast "save_line_buffer"

; BUGS
; - get crash and monitor prompt at the end of the document in some case;
; -- need to figure out how to reproduce it
; - ^,$  (jump to line start, line end) both do not properly replace the letter under the cursor

; STRETCH TODO:
; - :set number / :set nonumber (turns line numbers on/off)
; - wq! - force save, force save and quit
; - allow many more lines (convert Line to use str instead permanent line)
; - do not write contiguous spaces (fully blank linkes, trim when writing)
; - stack based "undo" (p/P, o/O, dd)

; PARTIALLY DONE:
; - implement flag-based "do stuff" idea for alerts (from Tony)

; DONE:
; - made cursor be placed more like vim does it, based on line ending and the
; -- current "default_col"
; - (BUG) when in 'R' mode, entering in double quotes (") breaks replace mode
; -- due to "quotes mode", solution is to cbm.CHROUT($80) first if char == $22 (quote)
; -- then cbm.CHROUT($22) ...
; - saving now detects last visible character, and adds new line in the file there
; - 'i' now inserts a space and shifts right
; - add mode status, e.g., "-- REPLACE --" / "-- INSERT --" when in the correct modes
; - ALERTs need to be non-blocking (probably need to use interrupts?)
; - "shift left" for 'x'
; - o/O need an efficient redraw routine for section affected by shift-down
; see CHANGELOG for full archive of items
; - trying to get <return> when in REPLACE mode working, see BUGS
;   - can't get <return> to do the right thing when in REPLACE mode; i.e.,
;   -- I want it to save the current line, do the equivalent of 'o' (insert
;   -- line after), and return back to edit mode (replace or insert, whatever
;   -- it was)
; - :e on splash to start new document buffer (PRIORITY)

%zeropage basicsafe
%option no_sysinit
%encoding iso

%import textio
%import strings
%import conv
%import syslib
%import diskio
%import debug
;;; %import messages

mode {
  const ubyte INIT            = 0
  const ubyte NAV             = 1  ; modal state for navigation, default state
  const ubyte INSERT          = 2  ; modal state for insert mode, triggered with ctrl-i
  const ubyte REPLACE         = 3  ; modal state for replacement mode, triggered with ctrl-r
  const ubyte COMMAND         = 4  ; modal state for entering a command
}

flags {
  ; display flags
  ubyte       MESSAGE         = 0  ; could be an array, I suppose and cycle messages I suppose ...
  bool        UNSAVED         = false
  bool        SAVE_AS_PETSCII = false
}

view {
  const ubyte LEFT_MARGIN     = 4
  const ubyte RIGHT_MARGIN    = 79
  const ubyte HEIGHT          = 56 ; absolute height of the edit/view area
  const ubyte TOP_LINE        = 2  ; row+1 of the first line of the document (FIRST_LINE_IDX)
  const ubyte MIDDLE_LINE     = 27
  const ubyte BOTTOM_LINE     = 57 ; row+1 of the last line of the view port (LAST_LINE_IDX)
  const ubyte FOOTER_LINE     = 59
  str         BLANK_LINE79    = " " * 79
  str         BLANK_LINE76    = " " * 76
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
      ubyte idx = i as ubyte
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
    saved_char = $20
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
     void strings.copy(" " * 60, cmdBuffer)
     txt.plot(0, view.FOOTER_LINE) ; move cursor to the starting position for writing
     main.prints(view.BLANK_LINE79)
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
           cmdBuffer[i] = txt.getchr(i+1, view.FOOTER_LINE)
         }
         strings.strip(cursor.cmdBuffer)
         return;
       }
     goto CMDINPUT
  }

}

main {
  ubyte MODE         = mode.NAV ; initial mode is NAV
  uword NAVCHARCOUNT = 0        ; the main "clock"
  uword lineCount

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
    ubyte data72, data73, data74, data75, nullbyte
  }

  ^^Document doc

  const uword MaxLength  = 76
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
    strings.trim(initial)
    void strings.copy(view.BLANK_LINE79, this.text) ; initialize with BLANK_LINE79, eliminates random garbage
    void strings.copy(initial, this.text)         ; then add text
    return this
  }

  sub freeAll() {
    next = Buffer
    sys.memset(next, BufferSize, 0)
  }

  ; initiates initial buffer without a file, jumps to REPLACEMODE
  ; so user can start typing right away
  sub init_empty_buffer(ubyte lines) {
    freeAll()
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
    flags.UNSAVED = false
    main.lineCount = 0

    ubyte idx   = 0
    str lineBuffer  = " " * (MaxLength + 1)
    repeat lines {
      uword lineAddr = allocLine(lineBuffer)
      idx = main.lineCount as ubyte
      view.INDEX[idx] = lineAddr
      main.lineCount++
    }
    flags.UNSAVED = true
    main.draw_screen()
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
    cursor.place(view.c(), view.r())
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
    flags.UNSAVED = false
    main.lineCount = 0

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
        idx = main.lineCount as ubyte
        view.INDEX[idx] = lineAddr
        main.lineCount++
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
        prints(view.BLANK_LINE79)
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

  sub save_current_file() {
     str oldback = " " * 60
     void strings.copy(doc.filepath,oldback)
     strings.trim(oldback)
     void strings.append(oldback, ".swp") ; basically vi's .swp file
     if diskio.exists(oldback) {
       diskio.delete(oldback)
     }
     diskio.rename(doc.filepath, oldback)
     save_as(doc.filepath)
  }

;; mostly working, but some kinks left - for another time!!
  sub save_as(str filepath) {
    info_noblock("saving ...")

    ubyte i
    ubyte ub
    void diskio.f_open_w_seek(filepath)
    ^^Line line = view.INDEX[0]
    str tmp = " " * MaxLength
    void strings.copy(line.text, tmp)
    void strings.rstrip(tmp)
    do {
      for i in 0 to strings.length(tmp)-1 {
        ub = tmp[i]
        if ub >= 32 and ub <= 126 {
          void diskio.f_write(&ub, 1)
        }
      }
      ;; trying to get the line endings correct (ChatGPT!)
      ub = $0a
      void diskio.f_write(&ub, 1) ; LF
      line = line.next
    } until line == 0
    diskio.f_close_w()

    flags.UNSAVED = false

    info_noblock("          ")
  }

  sub navchar_start() {
    main.NAVCHARCOUNT++
  }

  sub toggle_nav() {
    main.MODE = mode.NAV
    main.update_tracker()
  }

  sub start () {
    txt.iso()
    doc.tabNum               = 0 ; for future proofing
    doc.charset              = 0 ; for future proofing
    doc.startBank            = 1 ; for future proofing
    doc.firstLine            = Buffer
    doc.filepath             = " " * 76

    main.lineCount            = 0
    main.MODE = mode.INIT

    txt.plot(0,1)
    splash()

    sys.wait(20)
    ;load_file("sample6.txt")

    draw_initial_screen()
    cursor.place(view.LEFT_MARGIN, view.TOP_LINE)

    main.update_tracker()

    ubyte char = 0
    ubyte col
    ubyte row

    ; this is the main loop
    NAVCHARLOOP:
      void, char = cbm.GETIN()
      col = view.c()
      row = view.r()

    SKIP_NAVCHARLOOP:               ; jump to here to skip input

      navchar_start()               ; event hook

      if char == $00 {
        goto NAVCHARLOOP
      }
      else if char != ':' and char != $1b and main.MODE == mode.INIT {
        main.MODE = mode.NAV
        cursor.cmdBuffer[0] = 'e'
        goto SKIP_COMMANDPROMPT   ; simulate ":e" from initial screen
      }

      when char {
        $0c -> {  ; this is a "form feed", and I have no idea why I put this here
          view.CURR_TOP_LINE = 1
          draw_initial_screen()
          cursor.replace(view.LEFT_MARGIN, view.TOP_LINE)
          toggle_nav()
        }
        $1b -> {       ; ESC key, throw into NAV mode from any other mode
          toggle_nav()
        }
        $3a -> {       ; ':',  mode
          if main.MODE == mode.NAV {
            main.MODE = mode.COMMAND

            cursor.command_prompt() ; populates cursor.cmdBuffer

            ; clear command line
            txt.plot(0, view.FOOTER_LINE)
            prints(view.BLANK_LINE79)
            main.update_tracker()

            ; sets the string index to do the strings.slice below, will change if there is a "!"
            ; it'll also necessarily change if a command is detected;
            ; :w filename
            ; :w! filename
            ; :q
            ; :q!
            ; :wq
            ; :wq!
            ; :!some-external-looking-command

            SKIP_COMMANDPROMPT:          ; simulate keyboard input by setting cursor.commandBuffer, goto here

            ubyte cmd_offset = 1
            bool force = false
            if cursor.cmdBuffer[1] == $21 { ; $21 is "!"
              force = true
              cmd_offset = 2
            }

            ; parse out file name (everything after ":N")
            str cmd = " " * 60
            ubyte cmd_length = strings.copy(cursor.cmdBuffer, cmd)
            str fn1 = " " * 60

            strings.slice(cmd, cmd_offset, cmd_length-cmd_offset, fn1) ; <- somehow this is affecting main.lineCount ...

            strings.strip(fn1) ; prep filename

            when cursor.cmdBuffer[0] {
              'e' -> {
                if strings.length(fn1) > 0 {
                  load_file(fn1)
                  draw_initial_screen()
                  col = view.LEFT_MARGIN
                  row = view.TOP_LINE
                }
                else {
                  init_empty_buffer(3)
                  char = 'R'
                  goto main.start.SKIP_NAVCHARLOOP
                }
              }
              'q' -> {
                if flags.UNSAVED == true and not force {
                    warn("Unsaved changes exist. Use q! to override ...")
                }
              }
              'w' -> {
                ; 'w' is for "write" - fn1 is the filename
                if strings.length(fn1) > 0 {
                  if diskio.exists(fn1) and not force {
                    warn("File Exists. Use w! to override ...")
                  }
                  else {
                    diskio.delete(fn1)
                    save_as(fn1)
                    void strings.copy(fn1, doc.filepath)
                  }
                }
                else {
                  save_current_file()
                }
              }
              else -> {
                warn("Unknown command ...")
              }
            }
          }

          ;debug.assert(main.lineCount, 93, debug.EQ, "ln 515 ... main.lineCount == 93")
          toggle_nav()
          cursor.replace(col, row)
          main.update_tracker()
        }
        'd' -> {
          if main.MODE == mode.NAV {
            DDLOOP:
            void, char = cbm.GETIN()
            when char {
              $1b -> {       ; ESC key, throw into NAV mode from any other mode
                toggle_nav()
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
            goto RLOOP2 ; REPLACE mode, start editing blank line immediately
          }
        }
        'o' -> {
          if main.MODE == mode.NAV {
            main.insert_line_below()
            goto RLOOP2 ; REPLACE mode, start editing blank line immediately
          }
        }
        'y' -> {
          if main.MODE == mode.NAV {
            YYLOOP:
            void, char = cbm.GETIN()
            when char {
              $1b -> {       ; ESC key, throw into NAV mode from any other mode
                toggle_nav()
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

        ; E D I T I N G
        'r' -> { ; replace char
          if main.MODE == mode.NAV {
            RLOOP1:
            void, char = cbm.GETIN()
            ; go back to RLOOP1 if there's nothing input via keyboard
            if char == $00 {
              goto RLOOP1
            }
            when char {
              $1b -> {       ; ESC key, throw into NAV mode from any other mode
                toggle_nav()
                goto NAVCHARLOOP
              }
              else -> {
                goto REPLACECHAR
              }
            }
            goto RLOOP1
            REPLACECHAR:
            main.replace_char(char)
          }
        }
        'x' -> {
          if main.MODE == mode.NAV {
            main.delete_xy_shift_left()
          }
        }
        'i' -> {
          if main.MODE == mode.NAV {
            main.MODE = mode.INSERT
            main.update_tracker()
            main.insert_space_xy_shift_right() ; initially just adds space, then drop to 'R'
            main.MODE = mode.NAV
            main.update_tracker()
          }
        }
        ;'I' -> {
        ;  flags.SAVE_AS_PETSCII = true;
        ;}
        'R' -> { ; edit mode (initially copy of replace writing mode)
          if main.MODE == mode.NAV {
            main.MODE = mode.REPLACE
            main.update_tracker()
            RLOOP2:
            main.MODE = mode.REPLACE
            void, char = cbm.GETIN()
            if char == $00 {
              goto RLOOP2
            }
            when char {
              $1b -> {       ; <esc> throw into NAV mode from any other mode
                toggle_nav()
                main.save_line_buffer()
                goto NAVCHARLOOP
              }
              $0d -> {       ; <return> replicate <esc>, would like to also followed by an immediate 'o' 
                ; this part is the same as <esc>
                toggle_nav()
                main.save_line_buffer()
                ; this part simulates the pressing of 'o'
                char = $6f ; 'o' 
                ; this jumpts to right after NAVACHARLOOP: and reads char as if 'o' was pressed
                goto SKIP_NAVCHARLOOP
              }
              else -> { ; backspace
                goto REPLACEMODE
              }
            }
            goto RLOOP2
            REPLACEMODE:
            if view.c() < view.LEFT_MARGIN {       ; this is where to handle backspace past left margine
              cursor.hide()
              txt.plot(view.LEFT_MARGIN, view.r())
              cursor.place(view.c(),view.r())
              goto RLOOP2
            }
            if view.c() == view.RIGHT_MARGIN {   ; this is where to handle back
              cursor.hide()
              txt.plot(view.RIGHT_MARGIN-1, view.r())
              cursor.place(view.c(),view.r())
              goto RLOOP2
            }
            if char == $22 {
              cbm.CHROUT($80) ; disables "quote mode" in ROM
            }
            cbm.CHROUT(char)
            cursor.place(view.c(),view.r())
            main.update_tracker()
            goto RLOOP2
          }
        }

        ; N A V I G A T I O N
        '^' -> { ; jump to start of line
          if main.MODE == mode.NAV {
            jump_to_left()
          }
        }
        '$' -> { ; jump top end of line
          if main.MODE == mode.NAV {
            jump_to_right()
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
        'L' -> { ; redraw current screen
          if main.MODE == mode.NAV {
            ubyte c = view.c()
            ubyte r = view.r()
            draw_screen()
            txt.plot(c, r)
            cursor.replace(c, r)
            main.update_tracker()
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
        'l',$20,$1d -> {   ; RIGHT
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

  sub get_line_num(ubyte r) -> uword {
    const uword top = mkword(00,view.TOP_LINE)
    uword row       = mkword(00,r)
    uword curr_line = view.CURR_TOP_LINE + row - top
    return curr_line
  }

  sub get_Line_addr(ubyte r) -> uword {
    uword curr_line = main.get_line_num(r) ; 1-based
    ubyte idxw = (curr_line as ubyte) - 1  ; 0-based
    return view.INDEX[idxw]                ; only OK if you guarantee idxw <= 255
  }

  sub paste_line_above() {
    if view.CLIPBOARD == 0 { ; indicates empty clipboard (nothing copied yet)
      warn("Clipboard is empty ..")
      return
    }

    ubyte r = view.r()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)    ; gets memory addr of current Line
    ^^Line old_prev  = curr_addr.prev
    ^^Line copy_addr = view.CLIPBOARD
    ^^Line new_prev  = main.allocNewLine(copy_addr.text) ; new line with text from copied address

    old_prev.next  = new_prev
    new_prev.next  = curr_addr
    curr_addr.prev = new_prev
    new_prev.prev  = old_prev

    ;; call to update INDEX
    main.lineCount = view.insert_line_before(new_prev, main.get_line_num(r), main.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], new_prev, debug.EQ, "INDEX[curr_line as ubyte - 1] == new_prev")
    void debug.assert(view.INDEX[curr_line as ubyte], curr_addr, debug.EQ, "INDEX[curr_line as ubyte] == curr_addr")

    ;info("P ...")
    flags.UNSAVED = true

    if r == view.TOP_LINE {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }
    else if r == view.BOTTOM_LINE {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }
    else {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }

    main.update_tracker()
  }


  sub paste_line_below() {
    if view.CLIPBOARD == 0 { ; indicates empty clipboard (nothing copied yet)
      warn("Clipboard is empty ..")
      return
    }

    ubyte r = view.r()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)        ; gets memory addr of current Line
    ^^Line copy_addr = view.CLIPBOARD
    ^^Line new_next  = main.allocNewLine(copy_addr.text) ; new line with text from copied address

    new_next.prev  = curr_addr
    new_next.next  = curr_addr.next
    curr_addr.next = new_next

    ;; call to update INDEX
    main.lineCount = view.insert_line_after(new_next, main.get_line_num(r), main.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], curr_addr, debug.EQ, "INDEX[curr_line as ubyte - 1] == curr_addr")
    void debug.assert(view.INDEX[curr_line as ubyte], new_next, debug.EQ, "INDEX[curr_line as ubyte] == new_next")

    ;info("p ...")
    flags.UNSAVED = true

    if r == view.TOP_LINE {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r+1)
      cursor.replace(view.LEFT_MARGIN,r+1)
    }
    else if r == view.BOTTOM_LINE {
      void incr_top_line(1)
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }
    else {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r+1)
      cursor.replace(view.LEFT_MARGIN,r+1)
    }

    main.update_tracker()
  }

  sub insert_line_above() {
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
    main.lineCount = view.insert_line_before(new_prev, main.get_line_num(r), main.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], new_prev, debug.EQ, "INDEX[curr_line as ubyte - 1] == new_prev")
    void debug.assert(view.INDEX[curr_line as ubyte], curr_addr, debug.EQ, "INDEX[curr_line as ubyte] == curr_addr")

    ;info("O ...")
    flags.UNSAVED = true

    if r == view.TOP_LINE {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }
    else if r == view.BOTTOM_LINE {
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }
    else {
      txt.scrolldown_nlast(r, view.LEFT_MARGIN) ; 2nd param is column offset to start
      txt.plot(view.LEFT_MARGIN,r)
      prints(view.BLANK_LINE76)
      txt.plot(0,view.BOTTOM_LINE+1)
      prints(view.BLANK_LINE79)
      txt.plot(view.LEFT_MARGIN,r)
      cursor.hide()
      cursor.place(view.LEFT_MARGIN,r)
    }

    main.update_tracker()
  }

  sub insert_line_below() {
    ubyte r = view.r()

    cursor.hide()

    uword curr_line = main.get_line_num(r) ; next_line is +1

    ^^Line curr_addr = get_Line_addr(r)        ; gets memory addr of current Line
    ^^Line new_next  = main.allocNewLine("  ") ; creates new Line instance to insert

    new_next.prev  = curr_addr
    new_next.next  = curr_addr.next
    curr_addr.next = new_next

    ;; call to update INDEX
    main.lineCount = view.insert_line_after(new_next, main.get_line_num(r), main.lineCount)

    ; need to assert new address got inserted into view.INDEX
    void debug.assert(view.INDEX[curr_line as ubyte - 1], curr_addr, debug.EQ, "INDEX[curr_line as ubyte - 1] == curr_addr")
    void debug.assert(view.INDEX[curr_line as ubyte], new_next, debug.EQ, "INDEX[curr_line as ubyte] == new_next")

    ;info("o ...")
    flags.UNSAVED = true

    if r == view.BOTTOM_LINE {
      void incr_top_line(1)
      draw_screen()
      txt.plot(view.LEFT_MARGIN,r)
      cursor.replace(view.LEFT_MARGIN,r)
    }
    else {
      txt.scrolldown_nlast(r+1, view.LEFT_MARGIN)
      txt.plot(view.LEFT_MARGIN,r+1)
      prints(view.BLANK_LINE76)
      txt.plot(0,view.BOTTOM_LINE+1)
      prints(view.BLANK_LINE79)
      txt.plot(view.LEFT_MARGIN,r+1)
      cursor.place(view.LEFT_MARGIN,r+1)
    }

    main.printLineNum(curr_line+1)

    main.update_tracker()
  }

  sub do_yy() {
    ubyte c = view.c()
    ubyte r = view.r()

    ;info("yy")

    ^^Line curr_addr = get_Line_addr(r) ; line being deleted

    view.CLIPBOARD = curr_addr

    cursor.replace(c, r)
    main.update_tracker()
  }

  sub do_dd() {
    ubyte c = view.c()
    ubyte r = view.r()

    info_noblock("dd ...")

    ^^Line curr_addr = get_Line_addr(r) ; line being deleted
    ^^Line prev_addr = curr_addr.prev   ; line before line being deleted
    ^^Line next_addr = curr_addr.next   ; line after line being deleted

    ; track "freed" Lines, returns index in view.FREE
    void view.push_freed(curr_addr)

    ; short circuit curr_line out of links
    prev_addr.next = next_addr
    if next_addr != 0 {                   ; make sure curr_line is not last line of doc
      next_addr.prev = prev_addr
    }

    main.lineCount = view.delete_item(main.get_line_num(r), main.lineCount)

    draw_screen()

    view.CLIPBOARD   = curr_addr ; save deleted address to clipboard for later pasting

    flags.UNSAVED = true

    info_noblock("      ")

    cursor.replace(c, r)
    main.update_tracker()
  }

  sub incr_top_line(uword value) -> uword {
    if  view.CURR_TOP_LINE + value <= main.lineCount {
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
    ubyte c = view.c()
    txt.plot(0, view.r())
    txt.color($f)
    prints("    ")
    txt.plot(0, view.r())
    printW(number)
    txt.color($1)
    txt.plot(c, view.r())
  }

  sub draw_initial_screen () {
      uword addr = view.INDEX[0]
      ubyte i = main.lineCount as ubyte ; won't be used if > view.HEIGHT
      ; catch docs that go beyond screen
      if main.lineCount > view.HEIGHT {
        i = view.HEIGHT
      }
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      ubyte r = view.TOP_LINE
      uword lineNum = 1
      repeat i {
        txt.plot(0, r)
        main.printLineNum(lineNum)
        txt.plot(view.LEFT_MARGIN,r)
        ^^Line line = addr
        prints(line.text)
        addr = line.next
        r++
        lineNum++
      }
  }

  sub draw_screen () {               ; NOTE: assumes view.CURR_TOP_LINE is correct
      info_noblock("redrawing ...")
      ubyte idx = (view.CURR_TOP_LINE as ubyte) - 1
      ^^Line line = view.INDEX[idx]
      ubyte r
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      ubyte m,n
      uword remaining = main.lineCount - view.CURR_TOP_LINE + 1
      if remaining >= view.HEIGHT {
        m = view.HEIGHT
        n = 0
      }
      else {
        m = remaining as ubyte
        n = (view.HEIGHT - remaining) as ubyte
      }
      uword lineNum = view.CURR_TOP_LINE
      str tmp = " " *main.MaxLength
      repeat m {
        r = view.r()
        txt.plot(0, r)
        prints(view.BLANK_LINE79)
        txt.plot(0, r)
        main.printLineNum(lineNum)
        txt.plot(view.LEFT_MARGIN, r)

        void strings.copy(line.text,tmp) ; also figure out why I have to do this to get rid of errant space in next line
        strings.rstrip(tmp)
        prints(tmp)
        txt.plot(view.LEFT_MARGIN, r+1)


        ; get next Line
        line = line.next
        lineNum++
      }
      repeat n {
        r = view.r()
        prints(view.BLANK_LINE79)
        txt.plot(0,r)
        prints("~")
        txt.plot(0,r+1)
      }

      info_noblock("             ")
  }

  sub draw_bottom_line (uword lineNum) {
      if lineNum > main.lineCount {
        return
      }
      ubyte idx = lineNum as ubyte - 1
      uword addr = view.INDEX[idx]
      ^^Line line = addr
      addr = line.next
      txt.plot(0, view.BOTTOM_LINE)
      prints(view.BLANK_LINE79)
      txt.plot(0, view.BOTTOM_LINE)
      main.printLineNum(lineNum)
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
      main.printLineNum(lineNum)
  }

  sub page_forward() {
      ubyte c = view.c()
      uword last_page_start = main.lineCount - view.HEIGHT + 1
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

  ubyte default_col ; used by j & k to track the default column to feel more like what vim does 

  ; ^
  sub jump_to_left() {
      cursor.restore_current_char()
      txt.plot(view.LEFT_MARGIN, view.r())
      default_col = view.c()
      cursor.replace(view.LEFT_MARGIN, view.r())
      main.update_tracker()
  }

  sub get_end_col(ubyte r) -> ubyte {
      ^^Line curr_addr = get_Line_addr(r) ; line being deleted
      str rstripped = " " * main.MaxLength
      void strings.copy(curr_addr.text, rstripped)
      void strings.rstrip(rstripped)
      return view.LEFT_MARGIN+strings.length(rstripped)-1
  }

  ; $
  sub jump_to_right() {
      ; find last visible character - need something like "strings.ltrimmed" but for the right side
      ubyte end_col = get_end_col(view.r())
      cursor.restore_current_char()
      txt.plot(end_col, view.r())
      default_col = view.c()
      cursor.replace(end_col, view.r())
      main.update_tracker()
  }

  ; g
  sub jump_to_begin() {
      if main.lineCount > view.HEIGHT {
        view.CURR_TOP_LINE = 1
        draw_screen()
      }
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      cursor.replace(view.c(), view.r())
      main.update_tracker()
  }

  ; G
  sub jump_to_end() {
      if main.lineCount > view.HEIGHT {
        view.CURR_TOP_LINE = main.lineCount - view.HEIGHT + 1
        draw_screen()
        cursor.replace(view.LEFT_MARGIN, view.BOTTOM_LINE)
      }
      else {
        cursor.place(view.LEFT_MARGIN, (main.lineCount as ubyte) + 1)
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
    ubyte curr_end  = get_end_col(view.c())
    ubyte next_col  = curr_col
    ubyte next_end  = get_end_col(next_line)

    ; track end of line if at end of line in the curr_line
    if curr_col == curr_end or curr_col >= next_end {
      default_col = curr_col
      next_col = next_end
    }
    else {
      next_col = default_col
    }

    if next_col < view.LEFT_MARGIN {
      next_col = view.LEFT_MARGIN
    }

    if curr_line == view.TOP_LINE {
      cursor.hide()
      txt.scrolldown()
      void decr_top_line(1)
      txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
      draw_top_line(view.CURR_TOP_LINE)
      txt.plot(0, view.BOTTOM_LINE+1) ; blank footer line
      prints(view.BLANK_LINE79)
      cursor.replace(next_col, curr_line)
    }
    else {
      cursor.place(next_col,next_line)
    }
    main.update_tracker()
  }

  sub cursor_down_on_j () {
    ; j (down) from going past main.lineCount

    ; compute last possible top line (clamp so it never underflows)
    uword lastTop
    if main.lineCount > view.HEIGHT {
      lastTop = main.lineCount - view.HEIGHT + 1
    } else {
      lastTop = 1
    }

    ; if we're already showing the last page and the cursor is on the bottom row, stop
    if view.CURR_TOP_LINE == lastTop and view.r() == view.BOTTOM_LINE {
      return
    }

    ubyte curr_line = view.r()
    ubyte curr_col  = view.c()
    ubyte next_line = curr_line + 1
    ubyte curr_end  = get_end_col(view.c())
    ubyte next_col  = curr_col
    ubyte next_end  = get_end_col(next_line)

    ; track end of line if at end of line in the curr_line
    if curr_col == curr_end or curr_col >= next_end {
      default_col = curr_col
      next_col = next_end
    }
    else {
      next_col = default_col
    }

    if next_col < view.LEFT_MARGIN {
      next_col = view.LEFT_MARGIN
    }

    if curr_line == view.BOTTOM_LINE {
      cursor.hide()
      void incr_top_line(1)          ; increment CURR_TOP_LINE

      txt.plot(0, view.FOOTER_LINE)  ; blank footer line
      prints(view.BLANK_LINE79)

      txt.plot(0, 1)                 ; blank top line
      say(view.BLANK_LINE79)
      prints(view.BLANK_LINE79)

      txt.scroll_up()
      draw_bottom_line(view.CURR_TOP_LINE + view.HEIGHT - 1)

      cursor.replace(next_col, curr_line)
    } else {
      ; Only move the cursor down if there is a real document line there.
      ; Map current screen row -> document line number:
      ; docLine = CURR_TOP_LINE + (screenRow - TOP_LINE)
      uword docLine = view.CURR_TOP_LINE + (curr_line - view.TOP_LINE)

      if docLine < main.lineCount {
        cursor.place(next_col, next_line)
      }
    }

    main.update_tracker()
  }

  ; prints address 'addr' at row 'r'
  sub redraw_line(^^Line addr, ubyte r) -> ubyte {
    ;info_noblock("line saved to buffer ...")

    txt.plot(view.LEFT_MARGIN,r)
    prints(view.BLANK_LINE76)
    txt.plot(view.LEFT_MARGIN,r)
    str tmp = " " * 76 ; main.MaxLength 
    void strings.copy(addr.text, tmp)
    strings.rstrip(tmp) ; <- to get rid of straw CR or LF, but is this necessary?
    prints(tmp)
    return strings.length(tmp) ; <- still we can get length, and this can be helpful
  }

  ; save text written to the video RAM and saves it into the document's line buffer
  sub save_line_buffer() {
    ubyte c = view.c()
    ubyte r = view.r()

    ^^Line curr_addr = get_Line_addr(r)    ; gets memory addr of current Line

    ubyte i
    for i in view.LEFT_MARGIN to view.RIGHT_MARGIN {
      @(curr_addr.text+(i-view.LEFT_MARGIN-1)) = txt.getchr(i-1,r)
    }

    cursor.replace(c,r)
    txt.plot(c,r)
    main.update_tracker()
  }

  ; in NAV mode, `r <char>`
  sub replace_char(ubyte char) {
    ubyte c = view.c()
    ubyte r = view.r()

    ^^Line curr_addr = get_Line_addr(r)    ; gets memory addr of current Line

    ; remove char at (c,r) then shift everything to the left

    @(curr_addr.text+c-view.LEFT_MARGIN) = char
    cursor.saved_char = char

    ; prints address 'curr_addr' at row 'r'
    void redraw_line(curr_addr, r)

    cursor.replace(c,r)

    txt.plot(c,r)
    main.update_tracker()
  }

  sub insert_space_xy_shift_right() {
    ubyte c = view.c()
    ubyte r = view.r()

    ^^Line curr_addr = get_Line_addr(r)    ; gets memory addr of current Line

    ubyte i
    for i in view.RIGHT_MARGIN-1 to c+1 step -1 {
      @(curr_addr.text+i-view.LEFT_MARGIN) = @(curr_addr.text+i-view.LEFT_MARGIN-1)
    }
    @(curr_addr.text+c-view.LEFT_MARGIN) = $20 
    cursor.saved_char = $20

    ; prints address 'curr_addr' at row 'r'
    void redraw_line(curr_addr, r)

    cursor.replace(c,r)

    txt.plot(c,r)
    default_col = view.c()
    main.update_tracker()
  }

  sub delete_xy_shift_left() {
    ubyte c = view.c()
    ubyte r = view.r()

    ^^Line curr_addr = get_Line_addr(r)    ; gets memory addr of current Line

    ; remove char at (c,r) then shift everything to the left

    @(curr_addr.text+c-view.LEFT_MARGIN) = $20
    cursor.saved_char = $20

    uword i
    for i in c to 80-1 {
      @(curr_addr.text+i-view.LEFT_MARGIN) = @(curr_addr.text+i-view.LEFT_MARGIN+1)
    }
    @(curr_addr.text+80-view.LEFT_MARGIN) = $20

    ; prints address 'curr_addr' at row 'r'
    ubyte length = redraw_line(curr_addr, r)

    ; this will keep the site of subsequent 'x' in the right space
    ; if in the middle of a line; if the end of the line has been
    ; reached it follows the last character in the line
    if c >= view.LEFT_MARGIN + length {
      c = view.LEFT_MARGIN + length - 1
    }

    ; don't go too far left
    if c < view.LEFT_MARGIN {
      c = view.LEFT_MARGIN
    }

    txt.plot(c,r)
    default_col = view.c()
    cursor.replace(c,r)

    main.update_tracker()
  }

  sub cursor_left_on_h () {
    if view.c() > view.LEFT_MARGIN {
      cursor.place(view.c()-1,view.r())
    }
    default_col = view.c()
    main.update_tracker()
  }

  sub cursor_right_on_l () {
    if view.c() < view.RIGHT_MARGIN {
      cursor.place(view.c()+1,view.r())
    }
    default_col = view.c()
    main.update_tracker()
  }

  ; util functions

  sub update_tracker () {
    ubyte X = view.c()
    ubyte Y = view.r()
    txt.plot(0, view.FOOTER_LINE)
    prints(view.BLANK_LINE79)
    txt.plot(1, view.FOOTER_LINE)
    printw(main.lineCount)
    prints(" lines, x: ")
    printw(X - view.LEFT_MARGIN + 1)
    prints(", y: ")
    printw(Y - view.TOP_LINE    + 1)
    prints(" TOP: ")
    printw(view.CURR_TOP_LINE)
    prints(" BOT: ")
    printw(view.CURR_TOP_LINE+view.HEIGHT-1)
    prints(" CNT: ")
    printw(main.NAVCHARCOUNT)
    txt.plot(79-9, view.r())
    if flags.UNSAVED == true {
      txt.color2($6,$1)
      prints("(UNSAVED)")
      txt.color2($1,$6)
    }
    else {
      prints("( SAVED )")
    }
    ; update mode (upper left)
    if main.MODE == mode.REPLACE {
      info_noblock_LEFT("-- REPLACE --")
    }
    else if main.MODE == mode.INSERT {   ; (i)nsert is not implemented yet
      info_noblock_LEFT("-- INSERT  --")
    }
    else if main.MODE == mode.NAV {
      info_noblock_LEFT("             ")
    }
    else {
      info_noblock_LEFT("             ")
    }
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

;  sub printb (ubyte x) {
;    txt.print_ub0(x)
;  }

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

;  sub sayH (uword x) {
;    main.printH(x)
;    txt.nl()
;  }

  sub info_noblock_LEFT(str message) {
    alert_noblock_LEFT(message, $7, $6)
  }

  sub alert_noblock_LEFT(str message, ubyte color1, ubyte color2) {
    ubyte length = strings.length(message)
    txt.plot(1, 0)
    txt.color2(color1, color2)
    prints(message)
    txt.color2($1, $6) ; sets text back to default, white on blue
  }

  sub info_noblock(str message) {
    alert_noblock(message, $7, $6)
  }

  sub alert_noblock(str message, ubyte color1, ubyte color2) {
    ubyte length = strings.length(message)
    txt.plot(78-length, 0)
    txt.color2(color1, color2)
    prints(message)
    txt.color2($1, $6) ; sets text back to default, white on blue
  }

  sub info(str message) {
    alert(message, 15, $7, $6)
  }

  sub warn(str message) {
    alert(message, 120, $2, $1)
  }

  sub alert(str message, ubyte delay, ubyte color1, ubyte color2) {
    ubyte c = view.c()
    ubyte r = view.r()
    ubyte length = strings.length(message)
    txt.plot(78-length, 0)
    txt.color2(color1, color2)
    prints(message)
    sys.wait(delay)
    txt.plot(78-length, 0)
    txt.color2($1, $6) ; sets text back to default, white on blue
    txt.plot(view.LEFT_MARGIN, 0)
    prints(view.BLANK_LINE79)
    txt.plot(c,r)
  }

  sub infoW(uword message) {
    alertW(message, 15, $7, $6)
  }

;  sub warnW(uword message) {
;    alertW(message, 120, $2, $1)
;  }

  sub alertW(uword message, ubyte delay, ubyte color1, ubyte color2) {
    ubyte c = view.c()
    ubyte r = view.r()
    txt.plot(74, 0)
    txt.color2(color1, color2)
    printW(message)
    sys.wait(delay)
    txt.plot(74, 0)
    txt.color2($1, $6) ; sets text back to default, white on blue
    txt.plot(view.LEFT_MARGIN, 0)
    prints(view.BLANK_LINE79)
    txt.plot(c,r)
  }

;  sub infoH(uword message) {
;    alertH(message, 15, $7, $6)
;  }
;
;  sub warnH(uword message) {
;    alertH(message, 120, $2, $1)
;  }
;
;  sub alertH(uword message, ubyte delay, ubyte color1, ubyte color2) {
;    txt.plot(74, 0)
;    txt.color2(color1, color2)
;    printH(message)
;    sys.wait(delay)
;    txt.plot(74, 0)
;    txt.color2($1, $6) ; sets text back to default, white on blue
;    txt.plot(view.LEFT_MARGIN, 0)
;    prints(view.BLANK_LINE79)
;  }

}

txt {
%option merge
  ; !!! experimental - pure p8 version of txt.scroll_down_nlast, but takes a column offset 

  sub scrolldown_nlast(ubyte top_row, ubyte col_start) {
    ubyte columns, rows, j
    columns, rows = txt.size()
    rows--
    while rows>top_row {
        rows--
        uword vera_addr = lsw(txt.VERA_TEXTMATRIX) + 256*rows
        cx16.vaddr(msw(txt.VERA_TEXTMATRIX), vera_addr+col_start,     0 ,1) ; source row
        cx16.vaddr(msw(txt.VERA_TEXTMATRIX), vera_addr+col_start+256, 1, 1) ; target row
        for j in col_start to columns {
            cx16.VERA_DATA1 = cx16.VERA_DATA0       ; copy tile
            cx16.VERA_DATA1 = cx16.VERA_DATA0       ; copy color
        }
    }
  }

  sub scrolldown() {
    ubyte columns, rows
    columns, rows = txt.size()
    rows--
    while rows>0 {
        rows--
        uword vera_addr = lsw(txt.VERA_TEXTMATRIX) + 256*rows
        cx16.vaddr(msw(txt.VERA_TEXTMATRIX), vera_addr, 0 ,1)       ; source row
        cx16.vaddr(msw(txt.VERA_TEXTMATRIX), vera_addr+256, 1, 1)   ; target row
        repeat columns {
            cx16.VERA_DATA1 = cx16.VERA_DATA0       ; copy tile
            cx16.VERA_DATA1 = cx16.VERA_DATA0       ; copy color
        }
    }
  }
}
