;
; provides the storage layer for XVI 2.0+
;

blocks {
  ; +----------+----------------------------------------------+----------+
  ; | PREV_PTR |                 DATA - LINE TEXT             | NEXT_PTR |
  ; | 2 Bytes  |                 128 Bytes                    | 2 Bytes  |
  ; +----------+----------------------------------------------+----------+
  ; ^
  ; |-- main.BASE_PTR+main.RECSZ*recNo

  uword i;

  ;; writes line to memory
  sub poke_line_data (ubyte bank, uword line) {
  ;;; TODO - update pointer records for PREV/NEXT
    uword REC_START = main.BASE_PTR + (main.RECSZ * line)
    ubyte j = 0
    for i in 0 to main.DATSZ-1 {
       @(REC_START + main.PTRSZ + i) = main.lineBuffer[j]  ;; write to the memory bank
       j = j + 1
    }
  }

  sub draw_range (ubyte bank, uword startLine, uword numLines ) {
    ubyte j
    uword REC_START, line
    for line in startLine to numLines {
      j = 0
      for i in 0 to main.DATSZ-1 {
         main.printBuffer[j] = 00 
         j = j + 1
      }
      j = 0
      REC_START = main.BASE_PTR + (main.RECSZ * line)
      for i in 0 to main.DATSZ-1 {
         main.printBuffer[j] = @(REC_START + main.PTRSZ + i)
         j = j + 1
      }
      print_line(line)
    }
  }

  sub print_line (uword line) {
    conv.str_uw(line+1)
    ; start printing at main.minCol, keep row the same
    txt.plot(main.minCol, txt.get_row())
    txt.print(main.blankLine)
    txt.plot(0, txt.get_row())
    txt.print(conv.string_out)
    txt.plot(main.minCol, txt.get_row())
    txt.print(main.printBuffer)
    txt.nl()
  }
}
