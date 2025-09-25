;
; provides the storage layer for XVI 2.0+
;

blocks {
  ; +----------+----------------------------------------------+------------------------------+
  ; | PREV_PTR           |                 DATA - LINE TEXT             | NEXT_PTR           |
  ; | main.METASZ Bytes  |    main.DATASZ Bytes                         | main.METASZ Bytes  |
  ; +----------+----------------------------------------------+------------------------------+
  ; ^
  ; |-- main.BASE_PTR+main.RECSZ*recNo

; TODO - store bank in header?

  uword i;

  ;; writes line to memory
  sub poke_line_data (ubyte bank, uword line) {
    ; compute addresses - assuming before/after addresses is only valid on first
    uword curr_PTR = main.BASE_PTR + (main.RECSZ * line)        ; start addr of current line
    uword prev_PTR = main.BASE_PTR + (main.RECSZ * (line - 1))  ; start addr of prev line
    uword next_PTR = main.BASE_PTR + (main.RECSZ * (line + 1))  ; start addr of next line
    if line < 1 {
      prev_PTR = main.BASE_PTR
    }
    ; write PREV_PTR section
    poke(curr_PTR, bank)
    pokew(curr_PTR+1, prev_PTR)
    ; write NEXT_PTR section
    poke(curr_PTR + main.METASZ + main.DATASZ, bank)
    pokew(curr_PTR + main.METASZ + main.DATASZ + 1, next_PTR)
    ; add DATA
    ubyte j = 0
    for i in 0 to main.DATASZ-1 {
       poke(curr_PTR + main.METASZ + i, main.lineBuffer[j])    ; fill bank addrs with text DATA
       j = j + 1
    }
    curr_PTR = next_PTR
  }

  ; by-passes line by moving "next" point from previous line to point
  ; to the next line (of current line) - if possible, add an "undo" here
  sub cut_line(ubyte bank, uword LINE_IDX) {
    ; point prev "next" to current "next"
    uword curr_PTR = main.BASE_PTR + (main.RECSZ * LINE_IDX)
    if LINE_IDX == main.TOP_LINE {         ; case 0
      ; line being removed is the very first line on screen, has no previous line record
; swap pointers accordingly
    }
    else if LINE_IDX == main.BOTTOM_LINE { ; case 2
      ; line being removed is the very last line of the document, has no next line record
; swap pointers accordingly
    }
    else {                                 ; case 3
      ; all lines between first and last line
; swap pointers accordingly
    }
; now, redraw visible - being sure to adjust the first line up if case 0
    ; have status indicator of what just happened
    ; save for undo
    ; keep line in buffer for paste
    ; figure out opportunities to compact memory space (save to tmp and reload?)
    ; implement basic .swp and auto save?
  }

  sub yank_line() {
    txt.plot(main.LEFT_MARGIN, txt.get_row())
  }

  sub draw_range (ubyte bank, uword startIndex, uword endIndex) {
    ubyte j
    uword line
    uword curr_PTR = main.BASE_PTR + (main.RECSZ * startIndex)
    for line in startIndex to endIndex {
      j = 0
      for i in 0 to main.DATASZ-1 {
         main.printBuffer[j] = 0
         j += 1
      }
      j = 0
      for i in 0 to main.DATASZ-1 {
         main.printBuffer[j] = peek(curr_PTR + main.METASZ + i)
         j += 1
      }
      print_line(line)
      curr_PTR = peekw(curr_PTR + main.METASZ + main.DATASZ + 1)
    }
    txt.plot(main.LEFT_MARGIN, txt.get_row() - 1)
  }

  sub print_line (uword line) {
    ; start printing at main.LEFT_MARGIN, keep row the same
    txt.plot(0, txt.get_row())
    txt.print(main.blankLine)
    txt.plot(0, txt.get_row())
    ; print line number
    if main.shownumbers == 1 {
      void conv.str_uw(line + 1)
      txt.print(conv.string_out)
    }
    ; print line
    txt.plot(main.LEFT_MARGIN, txt.get_row())
    txt.print(main.printBuffer)
    txt.nl()
  }

  sub clear_bank () {
    uword A;
    for A in main.BASE_PTR to $BFFF {
      @(A) = 0 ; poke 0 to memory address
        A += 1 ; increment memory address by 1
    }
  }
}
