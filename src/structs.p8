%import textio
%import strings
%import conv
%import syslib
%import diskio
%import verafx
%option no_sysinit
%zeropage basicsafe
%encoding iso

main {
  struct Document {
    ubyte tabNum         ; 0
    ubyte charset        ; 0 = ISO, 1 = PETSCI
    ubyte startBank      ; actual bank number for switching
    uword firstLineAddr  ; address of the first line
    uword eof            ; address of the very last datum of the file
  }

  struct Line {
    ^^Line prev
    ^^Line next
    str text
  }

  ^^Document doc        = $A000
  uword buffer          = $A000 + sizeof(Document)
  uword next            = buffer

  sub allocLine(str initial) -> uword {
    uword result = next     ; first time this is called, it gets buffer's addr
    ^^Line line = result
    line.text = " " * 80
    line.text = initial

    txt.nl()
    txt.print("Line start address: ")
    txt.print_uwhex(result, true) 
    txt.nl()

    defer next += sizeof(Line)+80  ; next is updated for the next call

    return result           ; returns pointer of type ubyte for ^^Line instantiation
  }

  sub freeAll() {
    next = buffer
  }

  sub start () {
    txt.iso()
    doc.tabNum               = 0            ; future proofing
    doc.charset              = 0            ; future proofing
    doc.startBank            = 0            ; future proofing
    doc.eof                  = &doc.eof     ; address of last useful data in doc
    doc.firstLineAddr        = &doc.eof + 2 ; start of first line, inits as next address after doc.eof's addr
                                            ; but since doc.firstLineAddr is eof + 2, no data is there yet

    txt.print("tab index            \n ")
    txt.print_ub(doc.tabNum) 
    txt.nl()
    txt.print("initial buffer address")
    txt.print_uwhex(buffer, true) 
    txt.nl()
    txt.print("initial next address  ")
    txt.print_uwhex(next, true) 
    txt.nl()
    txt.print("first line (no data)  ")
    txt.print_uwhex(doc.firstLineAddr, true)
    txt.nl()
    txt.print("current actual eof    ")
    txt.print_uwhex(doc.eof, true)
    txt.nl()

    ubyte i
    for i in 1 to 5 {
      ^^Line line  = allocLine("this is the initial text") 
      
      txt.nl()
      txt.print(line.text)
    }

  }
}
