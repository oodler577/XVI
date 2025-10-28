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
  struct Document {
    ubyte tabNum         ; 0
    ubyte charset        ; 0 = ISO, 1 = PETSCI
    ubyte startBank      ; actual bank number for switching
    uword firstLineAddr  ; address of the first line
    uword lineCount      ; number of lines
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

  ^^Document doc = $1000
  uword next     = $1000 + sizeof(Document)
  uword prev     = $0000

  str readBuffer = " " * 81

  sub allocLine() -> uword {
    uword this = next
    ^^Line line = this
    line.text  = " " * 81
    line.text  = readBuffer
    prev       = this - sizeof(Line)
    line.prev  = prev
    next      += sizeof(Line) ; next is updated for the next call
    line.next  = next
    doc.lineCount += 1
    return this                  ; addr of newly initiated Line
  }

  sub freeAll() {
    next = doc.firstLineAddr
  }

  sub start () {
    txt.iso()
    doc.tabNum               = 0 ; for future proofing
    doc.charset              = 0 ; for future proofing
    doc.startBank            = 1 ; for future proofing
    doc.lineCount            = 0
    doc.firstLineAddr        = next

    cx16.rambank(doc.startBank)
    uword i = doc.firstLineAddr
    str TXT = " " * 81

    cbm.CLEARST()
    diskio.f_open("sample6.txt")
    say("reading ...")
    repeat 11 {
      readBuffer = " " * 81
      ubyte length
      ;length, void = diskio.f_readline(readBuffer)
       readBuffer = "0" * 80
      uword line_addr  = allocLine() 
      ^^Line line = line_addr
sayhex(line.text)
say(line.text)
      i = i + sizeof(Line)+81
    }
    say("done reading ...")

WAIT:
goto WAIT

    txt.nl()
    say("\nLine Count    ")
    sayw(doc.lineCount)

    say("re-reading")

    i = doc.firstLineAddr
    repeat 11 {
      say("\n\n")
      TXT = "this is initial text for line instance, $"
      strings.append(TXT,conv.str_uwhex(i))
      line_addr  = i

      line = line_addr

      ; testing to make sure string got written properly
      say(TXT)
      say(line.text)
      if strings.compare(TXT,line.text) == 0 {
        say("     Line: text, PASS!\n")
      }
      else {
        say(TXT)
        say(line.text)
        say("     Line: text, FAIL!\n")
      }
      TXT = " " * 81

      ; some instance member info
      say("Prev Line: ")
      sayhex(line.prev) 
      say("\nThis Line: ")
      sayhex(line) 
      say("\nNext Line: ")
      sayhex(line.next) 

      i = i + sizeof(Line)+81
    }
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
