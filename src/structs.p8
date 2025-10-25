%zeropage basicsafe
%option no_sysinit
%encoding iso

%import textio
%import strings
%import conv
%import syslib
%import diskio

view {
  const ubyte LEFT_MARGIN  = 1
  const ubyte RIGHT_MARGIN = 79
  const ubyte HEIGHT       = 56
  const ubyte TOP_LINE     = 1  ; row+1 of the first line of the document (FIRST_LINE_IDX)
  const ubyte MIDDLE_LINE  = 27
  const ubyte BOTTOM_LINE  = 57 ; row+1 of the last line of the view port (LAST_LINE_IDX)
  const ubyte FOOTER_LINE  = 58
  uword FIRST_LINE_ADDR    = 0  ; buffer index of the line that is shown at the top of the TEXTBOX (view port)
}

main {
  const ubyte NAV          = 1 ; modal state for navigation, default state
  const ubyte INSERT       = 2 ; modal state for insert mode, triggered with ctrl-i
  const ubyte REPLACE      = 3 ; modal state for replacement mode, triggered with ctrl-r
  const ubyte COMMAND      = 4 ; modal state for entering a 
  ubyte LEFT_MARGIN        = view.LEFT_MARGIN
  ubyte RIGHT_MARGIN       = view.RIGHT_MARGIN
  ubyte HEIGHT             = view.HEIGHT
  ubyte TOP_LINE           = view.TOP_LINE  ; row+1 of the first line of the document (FIRST_LINE_IDX)
  ubyte MIDDLE_LINE        = view.MIDDLE_LINE
  ubyte BOTTOM_LINE        = view.BOTTOM_LINE ; row+1 of the last line of the view port (LAST_LINE_IDX)
  ubyte FOOTER_LINE        = view.FOOTER_LINE

  struct Document {
    ubyte tabNum         ; 0
    ubyte charset        ; 0 = ISO, 1 = PETSCI
    ubyte startBank      ; actual bank number for switching
    ubyte mode           ; NAV/INSERT/REPLACE/COMMAND
    uword firstLineAddr  ; address of the first line
    uword lineCount      ; number of lines
  }

  struct Line {
    ^^Line prev
    ^^Line next
    str text
  }

  ^^Document doc   = $1000
  uword next       = $1000 + sizeof(Document)
  uword prev       = $0000

  sub allocLine(str initial) -> uword {
    uword this     = next
    ^^Line line    = this
    line.text      = " " * 80
    line.text      = initial
    prev           = this - sizeof(Line)-80
    line.prev      = prev
    next          += sizeof(Line)+80 ; next is updated for the next call
    line.next      = next
    doc.lineCount += 1
    return this                      ; addr of newly initiated Line
  }

  sub freeAll() {
    next = doc.firstLineAddr
  }

  sub clear_bank () {
    uword A;
    for A in $1000 to $9EFF {
      @(A) = 0 ; poke 0 to memory address
        A += 1 ; increment memory address by 1
    }
  }

  sub load_file(str filepath) {
    cbm.CLEARST() ; set so READST() is initially known to be clear
    txt.plot(view.LEFT_MARGIN,view.TOP_LINE)
    if diskio.f_open(filepath) {
      while cbm.READST() == 0 {
        str lineBuffer  = " " * 80
        ubyte length
        length, void = diskio.f_readline(lineBuffer)
        str trimmedLine = " " * 80
        strings.slice(lineBuffer,0,79,trimmedLine) 
        ^^Line line  = allocLine(trimmedLine) 
      }
      diskio.f_close()
    }
  }

  sub start () {
    txt.iso()
    doc.tabNum               = 0   ; (not used atm) for future proofing
    doc.charset              = 0   ; (not used atm) for future proofing
    doc.startBank            = 1   ; (not used atm) for future proofing
    doc.lineCount            = 0
    doc.firstLineAddr        = next
    doc.mode                 = NAV ; starting mode

    cx16.rambank(doc.startBank)

    load_file("sample6.txt") 

    ; put cursor to the start position of where to write
    txt.plot(view.LEFT_MARGIN,view.TOP_LINE)

    ; iterate
    uword thisLine = doc.firstLineAddr
    ubyte i
    for i in view.TOP_LINE to view.BOTTOM_LINE {
      txt.plot(view.LEFT_MARGIN,txt.get_row())
      ^^Line line = thisLine
; this is not printing the line I am expecting; is the issue
; in the data structure of linked list traversal/pointers??
      txt.print_uwhex(&&line.text,true)
      txt.print(" ")
      txt.print(line.text)
      txt.nl()
      thisLine = line.next
    }

    LOOP:
    goto LOOP
  }
}
