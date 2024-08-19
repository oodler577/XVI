%import textio
%import string
%import conv
%import syslib
%import diskio
%option no_sysinit
%zeropage basicsafe
%encoding iso

main {
    str userinput        = "x"*80
    str currFilename     = " "*80
    str lineBuffer       = " " * 128
    str printBuffer      = " " * 128
    ubyte line           = 0
    const ubyte DATSZ    = 128
    const ubyte PTRSZ    = 2 ; in Bytes
    const ubyte RECSZ    = PTRSZ + DATSZ + PTRSZ 
    const ubyte BANK1    = 1
    const ubyte HEIGHT   = 54 ; max number of lines to show at a given time
    const ubyte WIDTH    = 79 ; max number of columns to show at any given time

    sub start() {
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      load_file("src/txt-viewer.p8", BANK1) 

    navcharloop:
      void, char = cbm.GETIN()
      when char {
        $6a -> {       ; 'j', DOWN
          cursor_down_on_j()
        }
        $6b -> {       ; 'k', UP
          cursor_up_on_k()
        }
        $71 -> {       ; 'q'
          txt.iso_off()
          sys.exit(0)
        }
      }
      goto navcharloop 
    }

    sub cursor_down_on_j () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      cursor.place_cursor(c,r+1)   ;; move actual cursor
    }

    sub cursor_up_on_k () {
      ubyte c = txt.get_column()
      ubyte r = txt.get_row()
      cursor.place_cursor(c,r-1)   ;; move actual cursor
    }

    sub load_file(str filepath, ubyte BANK) {
        uword BASE_PTR  = $A000
        cbm.CLEARST() ; set so READST() is initially known to be clear
        if diskio.f_open(filepath) {
          main.currFilename = filepath
          ubyte i = 0
          while cbm.READST() == 0 {
            ;; reset these buffers
            lineBuffer  = " " * 128
            printBuffer = " " * 128
            ; read line
            ubyte length = diskio.f_readline(lineBuffer)
            ; write line to memory as a fixed width record
            blocks.write_record(BASE_PTR, BANK1, line)
            line += 1
            if (line <= 58) {
              ;; PRINT TO SCREEN PROOF OF CONCEPT
              ;; but only first 54 lines
              blocks.print_test()
            }
          }
          diskio.f_close()
          ;; print status at bottom, will be replaced with the final status system
          conv.str_ub(line)
          txt.print(conv.string_out)
          txt.print(" lines, x:")
          conv.str_ub(txt.get_column())
          txt.print(conv.string_out)
          txt.print(", y:")
          conv.str_ub(txt.get_row())
          txt.print(conv.string_out)
          txt.nl()
;;; TODO DRAW CURSOR ...
;;;   then move it i/j/h/k
;;;   then scripe file by redrawing a "window of lines"
;;;   handle off screen columns or wrap??
          cursor.place_cursor(0,0)
        }
     }
  }

  ; maybe external module contribution to deal with cursor movements
  cursor {
      ubyte saved_char
      sub save_char(ubyte c, ubyte r) {
        saved_char = txt.getchr(c,r)
      }
  
      sub restore_char(ubyte c, ubyte r) {
        txt.plot(c,r)
        txt.chrout(saved_char << 8)
        txt.plot(c,r)
      }
  
      sub restore_current_char() {
        ubyte c = txt.get_column()
        ubyte r = txt.get_row()
        restore_char(c,r)
      }
  
      sub place_cursor(ubyte c, ubyte r) {
        restore_current_char() ;;
        save_char(c,r)         ;; save char in the next cursor destination
        txt.plot(c,r)          ;; move cursor to ne location
        txt.chrout($5d)        ;; write cursor charactor, "]"
        txt.plot(c,r)          ;; move cursor back after txt.chrout
      }
  
  }

  blocks {
    ; +----------+----------------------------------------------+----------+
    ; | PREV_PTR |                 DATA - LINE TEXT             | NEXT_PTR |
    ; | 1 Word   |                 128 Bytes                    | 1 Word   |
    ; +----------+----------------------------------------------+----------+

    sub write_record (uword BASE_PTR, ubyte bank, ubyte line) {
      ubyte i;

;;; TODO - update pointer records for PREV/NEXT

      for i in 0 to main.DATSZ-1 {
         uword THIS_REC = BASE_PTR + main.RECSZ * line
         @(THIS_REC + main.PTRSZ + i) = main.lineBuffer[i] ;; write to the memory bank
         main.printBuffer[i] = @(THIS_REC + main.PTRSZ + i)    ;; copy from the memory bank to regular str variable
      }
    }

    ;; draw lines to screen based on starting record number
    ;; and the screen size, HEIGHT x WIDTH
    sub draw_range (ubyte startLine) {

    } 

    sub print_test () {
      txt.print(main.printBuffer)
      txt.nl()
    }
  }


  ; MarkTheStrange's fixed length records example ...
  ;  pokew (address, value)
  ;    writes the word value at the given address in memory, in usual little-endian lsb/msb byte order.
  ;  peekw (address)
  ;    reads the word value at the given address in memory. Word is read as usual little-endian lsb/msb byte order.

;;   blocks {
;;     const ubyte off_prev = 0
;;     const ubyte off_next = 2
;;     const ubyte off_size = 4
;;     const ubyte off_data = 5
;;     sub prev(uword blk) -> uword { return peekw(blk + off_prev) }
;;     sub set_prev(uword blk, uword value) { pokew(blk + off_prev, value) }
;;   ;  ...
;;     sub size(uword blk) -> ubyte { return @(blk + off_size) }
;;     sub set_size(uword blk, ubyte value) { @(blk + off_size) = value }
;;   ;  ...
;; }

; TODO
;  1. initially show just the visible line to screen
;  2. but save all line to BANK via fixed records (see start below in the "block" package ...)
;  3. implement up/down (k/j) and left/right (h/l) so we can get as far as navigating files
;     such that the line shift up or down - or if the line is too long (what's that MAX here?)
;     the line will shift left or right
;  4. OPEN file (:tabedit)
;     * right time to consider tabs? - each file is comfortably saved in each bank
;     * gt (tab right), gT (tab left)
;  5. implement line operations:
;     + yy (yank)
;     + dd (cut)
;     + o  (new line below)
;     + O  (new line above)
;     + p  (paste clipboard buffer below)
;     + P  (paste clipboard buffer above) 
;  6. sort out INSERT mode, REPLACE mode
;  7. SAVE (<ESC>+w, wq, q!)
;  8. Other things
;    * dogfood mode - work on this project inside of the emu,
;    *   - multiple undo
;    *   - temp file auto-save via .swp file  
;    * jump to line N
;    * jump to top
;    * jump to bottom
;    * "transparent" cursor
;    * cycle over different color schemes
;    * multi-line copy/paste ("visual" mode)
;    * elite hacker mode
;        - ability to play music loops for developer flow
;        - support "compile / run" workflow without having to quit for,
;          + BASIC  (PETSCII mode required?) - BASLOAD, etc
;          + PASCAL (PETSCII mode required?) - compiler, run
;          + or suspend/resume via "sysNNNN" - e.g., "ctrl-z"/"fg"

