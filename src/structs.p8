%zeropage basicsafe
%option no_sysinit
%encoding iso

%import textio
%import strings
%import conv
%import syslib
%import diskio

view {
  const ubyte LEFT_MARGIN  = 3
  const ubyte RIGHT_MARGIN = 79
  const ubyte HEIGHT       = 56
  const ubyte TOP_LINE     = 2  ; row+1 of the first line of the document (FIRST_LINE_IDX)
  const ubyte MIDDLE_LINE  = 27
  const ubyte BOTTOM_LINE  = 56 ; row+1 of the last line of the view port (LAST_LINE_IDX)
  const ubyte FOOTER_LINE  = 58
}

main {
  struct Document {
    ubyte tabNum    ; 0
    ubyte charset   ; 0 = ISO, 1 = PETSCI
    ubyte startBank ; actual bank number for switching
    uword firstLine ; address of the first line
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

  const uword MaxLines   = 400
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
    next = doc.firstLine
  }

  sub load_file(str filepath) {
    strings.copy(filepath,doc.filepath)
    cbm.CLEARST() ; set so READST() is initially known to be clear
    if diskio.f_open(filepath) {
      while cbm.READST() == 0 {
        ;; reset these buffers
        str lineBuffer  = " " * (MaxLength + 1)
        ; read line
        ubyte length
        length, void = diskio.f_readline(lineBuffer)
        uword lineAddr = allocLine(lineBuffer)
      }
      diskio.f_close()
      txt.clear_screen()
    }
  }

  sub show_empty_buffer() {
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
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
    say("~                             Sponsor XVI development!             ")
    say("~                  type  :help sponsor<Enter>    for information   ")
    say("~                                                                  ")
    say("~                  type  :q<Enter>               to exit           ")
    say("~                  type  :help<Enter>  or  <F1>  for on-line help  ")
    say("~                  type  :help version2<Enter>   for version info  ")
    repeat 25 {
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

    show_empty_buffer()

    sys.wait(60)

    load_file("sample6.txt")

    uword addr = Buffer
    txt.plot(view.LEFT_MARGIN, view.TOP_LINE)
    repeat view.BOTTOM_LINE {
      txt.plot(view.LEFT_MARGIN, txt.get_row())
      ^^Line line = addr
      say(line.text)
      addr = line.next
    }

WAIT:
goto WAIT

  }

  ; util functions

  sub say (str x) {
    txt.print(x)
    txt.nl()
  }

  sub sayb (ubyte x) {
    txt.print_ub(x)
    txt.nl()
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
