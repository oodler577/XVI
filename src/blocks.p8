%import syslib
%import textio

;
; provides the storage layer for XVI 2.0+
;

blocks2 {

  struct Line {
    ^^Line prev
    ^^Line next
    str data
  }

  const uword MAX_LINES  = 256
  const uword LINE_BYTES = mkword(00,78) ; # of characters
  const uword LINE_SIZE   = LINE_BYTES + mkword(00,16) + mkword(00,16)

  const uword BUFFER_SIZE = MAX_LINES * LINE_SIZE
  uword buffer_ptr = memory("buffer", BUFFER_SIZE, 1)

  uword next_ptr = buffer_ptr

  sub newLine(str text) -> ^^Line {
    if next_ptr >= buffer_ptr + BUFFER_SIZE {
        txt.print("PANIC: out of memory")
        sys.exit(1)
    }
    ^^Line result = next_ptr
    next_ptr += sizeof(Line)
    return result
  }
}

blocks {

  ; +--------------------+----------------------------------------------+--------------------+
  ; | PREV_PTR           |                 DATA - LINE TEXT             |           NEXT_PTR |
  ; | main.METASZ Bytes  |    main.DATASZ Bytes                         |  main.METASZ Bytes |
  ; +--------------------+----------------------------------------------+--------------------+
  ; ^
  ; |-- main.BASE_PTR+main.RECSZ*recNo
  uword i;

  ; given line, returns prev start address
  sub get_prev_PTR (uword line) -> uword {
    if line < 1 {
      return main.BASE_PTR
    }
    return main.BASE_PTR + (main.RECSZ * (line - 1))  ; start addr of prev line
  }
  
  ; give line, returns current start address
  sub get_curr_PTR (uword line) -> uword  {
    return main.BASE_PTR + (main.RECSZ * line)        ; start addr of current line
  }

  ; given line, returns next start address
  sub get_next_PTR (uword line) -> uword {
    return main.BASE_PTR + (main.RECSZ * (line + 1))  ; start addr of next line
  }

  ; given current link, fills in header and footer pointer information
  sub insert_links (uword curr_PTR, ubyte bank, uword prev_PTR, uword next_PTR ) {
    ; write PREV_PTR section
    poke(curr_PTR, bank)
    pokew(curr_PTR+1, prev_PTR)
    ; write next_PTR section
    poke(curr_PTR + main.METASZ + main.DATASZ, bank)
    pokew(curr_PTR + main.METASZ + main.DATASZ + 1, next_PTR)
  }

  sub insert_data (uword curr_PTR) {
    ubyte j = 0
    for i in 0 to main.DATASZ-1 {
       poke(curr_PTR + main.METASZ + i, main.lineBuffer[j])    ; fill bank addrs with text DATA
       j = j + 1
    }
  }

  ;; writes line to memory
  sub poke_line_data (ubyte bank, uword line) {
    ; compute addresses - assuming before/after addresses is only valid on first
    uword curr_PTR = get_curr_PTR(line)  ; start addr of current line
    uword next_PTR = get_next_PTR(line)  ; start addr of next line

    ; adds prev/next and bank info to record starting at curr_PTR
    insert_links(curr_PTR, bank, get_prev_PTR(line), get_next_PTR(line))
    insert_data(curr_PTR)

    ; a
    curr_PTR = next_PTR
  }

  sub row2line(ubyte row) -> uword {
    ; both row and FIRST_LINE_IDX are zero-based, so they can
    ; be used directly here to compute the buffer index of the
    ; file as it is in memory
    uword line = mkword($00, row+1) - main.FIRST_LINE_IDX
    return line
  }

  ; by-passes line by moving "next" point from previous line to point
  ; to the next line (of current line) - if possible, add an "undo" here
  sub cut_line(ubyte bank, uword line) {
    uword prev_PTR = get_prev_PTR(line)  ; start addr of prevent line
    uword next_PTR = get_next_PTR(line)  ; start addr of next line

    ; point prev "next" to current "next"
    ; case 0
       ; line being removed is the very first line on screen, has no previous line record
       ; swap pointers accordingly
    ; case 1
       ; line being removed is the very last line of the document, has no next line record
       ; swap pointers accordingly
    ; case 2
      ; all lines between first and last line

    ; set bank of prev_PTR's footer "bank" ubyte 

    ; TODO ~> we should save current record data in clip board for pasting
    ;      ~> perhaps add this to main.lineBuffer since this is what that 
    ;      ~> buffer is for, to temporarily store the data of single line ...

    ; Note:
    ; The "cut" operation is really a re-wiring of the records to the left
    ; and right of the line being cut, to by-pass their linkages
    ;

    poke(prev_PTR+main.METASZ+main.DATASZ, bank)
    pokew(prev_PTR+main.METASZ+main.DATASZ+1, next_PTR) ; set next_PRT of prev_PTR's footer "next_PTR" uword 

    poke(next_PTR, bank)
    pokew(next_PTR+1, next_PTR) ; set next_PRT of next_PTR's footer "prev_PTR" uword 
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

  sub redraw_screen (ubyte bank) {
    ubyte c = txt.get_column()
    ubyte r = txt.get_row()
    txt.plot(main.LEFT_MARGIN,main.TOP_LINE)                  ; position for full screen redraw
    draw_range(bank, main.FIRST_LINE_IDX, main.LAST_LINE_IDX) ; full screen redraw
    txt.plot(c,r)                                             ; put back to where txt plot was
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
