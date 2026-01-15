------------------------------------------------------------
TEST 12 — OPEN MANY FILES IN SUCCESSION (SAME INSTANCE)
------------------------------------------------------------

Purpose:
Catch weird failures when opening many files back-to-back without
restarting xvi2.prg (state leaks, redraw bugs, buffer pointer bugs,
line number bugs, save/monitor drop regressions).

Preconditions:
- Remain in SAME running instance (do NOT reload xvi2.prg)
- Have a set of small test files available (or create them):
  f01.txt ... f12.txt
  Mix content:
    - short lines
    - long lines near max width
    - blank lines
    - file with >120 lines (line number digit-width changes)
    - file with 1 line only
    - file with spaces-only lines

If you do not have files:
- Create them quickly by saving different buffers as f01..f12 using :w

------------------------------------------------------------
CASE A — OPEN SERIES, NO EDITS (PURE OPEN/CLOSE STRESS)
------------------------------------------------------------

1. Open f01.txt
2. Scroll down 1 screen, scroll up 1 screen
3. Open f02.txt
4. Scroll down 1 screen, scroll up 1 screen
5. Repeat until f12.txt opened

EXPECTED:
- No crash
- No screen corruption
- No line-number corruption
- No stale text/ghost digits from previous file
- Cursor position valid on each open

Record any file number where failure begins: ______

------------------------------------------------------------
CASE B — OPEN SERIES WITH SMALL EDITS (STATE LEAK STRESS)
------------------------------------------------------------

For each file f01..f12:

1. Open file
2. Move to mid-screen line
3. Press i, type: X, Esc
4. Press a, type: Y, Esc
5. Press R, type: Z, Esc
6. Press $ once
7. Backspace once in insert mode (i then backspace then Esc)

EXPECTED (each file):
- Edits only affect current file buffer
- No random corruption mid-screen
- Line numbers remain aligned
- No redraw artifacts after mode switches

------------------------------------------------------------
CASE C — OPEN SERIES + SAVE EACH TIME (BLACK SCREEN REGRESSION)
------------------------------------------------------------

For each file f01..f12:

1. Open file
2. Make a small edit (one character)
3. :w tmpNN.txt   (NN = 01..12)

EXPECTED:
- Save succeeds
- Screen remains visible
- Returns to editor (no monitor drop)
- No forced reload of xvi2.prg needed

If screen goes black:
- Can you still type commands blindly? (Y/N): ____
- Did file save anyway? (Y/N): ____
- Did it drop to monitor? (Y/N): ____

------------------------------------------------------------
CASE D — OPEN SERIES WITH EDGE CONTENT (BOUNDARY / LINE NUMBERS)
------------------------------------------------------------

1. Open file with >120 lines (3-digit line numbers)
2. Scroll across transitions:
   - line 8→12
   - line 98→102
3. Open file with 1 line only
4. Press dd
5. Open file with long lines near max width
6. Perform TEST 1B typing past expected safe end (brief)
7. Open file with many blank/spaces-only lines
8. Press $ on several blank lines

EXPECTED:
- No leftover line-number digits from previous file
- No buffer corruption after switching from long-line file to blank-line file
- Cursor safe on all opens and operations

------------------------------------------------------------
CASE E — REOPEN SAME FILE REPEATEDLY (POINTER REUSE BUGS)
------------------------------------------------------------

1. Open f05.txt
2. Scroll and edit one character
3. Open f06.txt
4. Open f05.txt again
5. Repeat toggling f05 <-> f06 ten times

EXPECTED:
- No progressive corruption
- No increasing redraw glitches
- No wrong content shown (must match correct file)
- Cursor + line numbers stable

------------------------------------------------------------
CASE F — OPEN MANY FILES THEN RUN CORE COMMANDS
------------------------------------------------------------

1. Open f01..f12 in succession (as in Case A)
2. After opening f12, run:
   - yy, p, P
   - dd on last line
   - $ on blank line
   - :w final.txt

EXPECTED:
- All commands behave normally
- No crash
- No black screen
- No corrupted line numbers

------------------------------------------------------------
FAILURE NOTES (FILL IN)
------------------------------------------------------------

Test 12 Case: (A/B/C/D/E/F) ____
File number / name: ____
Symptom:
- crash
- black screen
- line numbers weird
- buffer corruption
- wrong file content shown
- cursor invalid jump

After failure, can continue editing? (Y/N): ____
Needs reload xvi2.prg to recover? (Y/N): ____
------------------------------------------------------------

