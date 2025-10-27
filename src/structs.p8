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
    str text
  }

  ^^Document doc = $1000
  uword next     = $1000 + sizeof(Document)
  uword prev     = $0000

  sub allocLine(str initial) -> uword {
    uword this = next
    ^^Line line = this
    line.text = " " * 80
    line.text = initial
    prev       = this - sizeof(Line)-80
    line.prev  = prev
    next      += sizeof(Line)+80 ; next is updated for the next call
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

    say("tab index             ")
    sayb(doc.tabNum) 
    say("\nfirst line (no data)  ")
    sayhex(doc.firstLineAddr)
    say("\nLine Count    ")
    sayw(doc.lineCount)

    uword i = doc.firstLineAddr
    str text = " " * 80
    repeat 5 {
      say("\n\n")
      text = "this is initial text for line instance, $"
      strings.append(text,conv.str_uwhex(i))
      uword line_addr  = allocLine(text) 

      ^^Line line = line_addr

      ; testing to make sure string got written properly
      if strings.compare(text,line.text) == 0 {
        say("     Line: text, PASS!\n")
      }
      else {
        say(text)
        say(line.text)
        say("     Line: text, FAIL!\n")
      }
      text = " " * 80

      ; some instance member info
      say("Prev Line: ")
      sayhex(line.prev) 
      say("\nThis Line: ")
      sayhex(line) 
      say("\nNext Line: ")
      sayhex(line.next) 

      i = i + sizeof(Line)+80
    }

    txt.nl()
    say("\nLine Count    ")
    sayw(doc.lineCount)

    say("re-reading")

    i = doc.firstLineAddr
    repeat 5 {
      say("\n\n")
      text = "this is initial text for line instance, $"
      strings.append(text,conv.str_uwhex(i))
      line_addr  = i

      line = line_addr

      ; testing to make sure string got written properly
      say(text)
      say(line.text)
      if strings.compare(text,line.text) == 0 {
        say("     Line: text, PASS!\n")
      }
      else {
        say(text)
        say(line.text)
        say("     Line: text, FAIL!\n")
      }
      text = " " * 80

      ; some instance member info
      say("Prev Line: ")
      sayhex(line.prev) 
      say("\nThis Line: ")
      sayhex(line) 
      say("\nNext Line: ")
      sayhex(line.next) 

      i = i + sizeof(Line)+80
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
