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
    ubyte line          = 0
    const ubyte DATSZ    = 128
    const ubyte PTRSZ    = 2 ; in Bytes
    const ubyte RECSZ    = PTRSZ + DATSZ + PTRSZ 
    const ubyte BANK1    = 1


    sub start() {
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      open_file("src/txt-viewer.p8", initial_bank)

    navcharloop:
      void, char = cbm.GETIN()
      when char {
        $71 -> {       ; 'q'
          txt.iso_off()
          sys.exit(0)
        }
      }
      goto navcharloop 
    }

    sub open_file(str filepath, ubyte BANK) {
        uword BASE_PTR  = $A000

        ; +----------+----------------------------------------------+----------+
        ; | PREV_PTR |                 DATA - LINE TEXT             | NEXT_PTR |
        ; | 1 Word   |                 128 Bytes                    | 1 Word   |
        ; +----------+----------------------------------------------+----------+

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
            blocks.save_rec(BASE_PTR, BANK1, line)

         ;; PRINT TO SCREEN PROOF OF CONCEPT
            blocks.print_test()

            line += 1
            if (line == 54) {
              break
            }
          }

          diskio.f_close()

          conv.str_ub(line)
          txt.print(conv.string_out)
          txt.print(" line")
          txt.nl()
        }
     }
  }

  blocks {
    sub save_rec (uword BASE_PTR, ubyte bank, ubyte line) {
      ubyte i;

;;; TODO - update pointer records for PREV/NEXT

      for i in 0 to main.DATSZ-1 {
         uword THIS_REC = BASE_PTR + main.RECSZ * line
         @(THIS_REC + main.PTRSZ + i) = main.lineBuffer[i] ;; write to the memory bank
         main.printBuffer[i] = @(THIS_REC + main.PTRSZ + i)    ;; copy from the memory bank to regular str variable
      }
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

