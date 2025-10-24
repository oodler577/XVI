%zeropage basicsafe
%option no_sysinit
%encoding iso

%import textio
%import strings
%import conv
%import syslib


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
    uword this = next    ; first time this is called, it gets addr stored as doc.firstLine
    ^^Line line = this
    line.text = " " * 80
    line.text = initial
    prev       = this - sizeof(Line)-80
    line.prev  = prev
    next      += sizeof(Line)+80 ; next is updated for the next call
    line.next  = next
    doc.lineCount += 1
    return this ; addr of newly initiated Line
  }

  sub freeAll() {
    next = doc.firstLineAddr
  }

  sub start () {
    ; cx16.rambank(1)

    txt.iso()
    doc.tabNum               = 0            ; future proofing
    doc.charset              = 0            ; future proofing
    doc.startBank            = 0            ; future proofing
    doc.lineCount            = 0
    doc.firstLineAddr        = next

    txt.print("tab index             ")
    txt.print_ub(doc.tabNum) 
    txt.print("\nfirst line (no data)  ")
    txt.print_uwhex(doc.firstLineAddr, true)
    txt.print("\nLine Count    ")
    txt.print_uw0(doc.lineCount)

    uword i
    str text = " " * 80
    for i in doc.firstLineAddr to $9EFF step sizeof(Line)+80 { ; max is $BFFF
      txt.print("\n\n")
      text = "this is initial text for line instance, $"
      strings.append(text,conv.str_uwhex(i))
      ^^Line line  = allocLine(text) 
      if strings.compare(text,line.text) == 0 {
        txt.print("     Line: text, PASS!\n")
      }
      else {
        txt.print("     Line: text, FAIL!\n")
      }
      text = " " * 80

      ; some instance member info
      txt.print("Prev Line: ")
      txt.print_uwhex(line.prev, true) 
      txt.print("\nThis Line: ")
      txt.print_uwhex(line, true) 
      txt.print("\nNext Line: ")
      txt.print_uwhex(line.next, true) 
    }

    txt.nl()
    txt.print("\nLine Count    ")
    txt.print_uw0(doc.lineCount)
  }
}
