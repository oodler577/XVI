============================================================
XVI2 EDITOR — ASCII REGRESSION TEST PLAN
============================================================

This document is intended to be run VERBATIM as a manual test
checklist. Do not skip steps. Record failures inline.

------------------------------------------------------------
PRE-TEST SETUP (REQUIRED EVERY RUN)
------------------------------------------------------------

[ ] Cold start xvi2.prg
[ ] Start from known clean state (no prior buffer reuse)
[ ] Line numbers ENABLED (if supported by build)
[ ] Screen filled with >1 full screen of text when applicable

NOTE:
- Tests are ordered to surface memory, redraw, and boundary bugs
- Several tests intentionally overlap old + new code paths

------------------------------------------------------------
TEST 0 — BASELINE SCREEN + LINE NUMBER SANITY
------------------------------------------------------------

1. Open or create a file with ~40 lines
   - Mix of short, long, and empty lines

2. Scroll down 10 lines
3. Scroll up 10 lines

EXPECTED:
- No missing rows
- No stale characters
- Line numbers aligned with text rows
- No digits drawn inside text area

------------------------------------------------------------
TEST 1 — INSERT vs APPEND (BASIC BEHAVIOR)
------------------------------------------------------------

Buffer line:
  A B C

1. Put cursor on the B
2. Press: i
3. Type: X
4. Escape

EXPECTED:
- Result: A X B C
- Cursor and line number stable

5. Put cursor back on B
6. Press: a
7. Type: Y
8. Escape

EXPECTED:
- Result: A B Y C
- No redraw artifacts
- Line number unchanged

------------------------------------------------------------
TEST 1B — INSERT/APPEND MID-SCREEN END-OF-BUFFER (CRITICAL)
------------------------------------------------------------

Purpose:
Catch corruption when typing near buffer limits mid-screen

1. Create NEW EMPTY BUFFER
2. Insert lines until cursor is ~mid-screen (10–15 lines down)
3. On a mid-screen line:
   - Enter insert mode
   - Type until near max line width
   - Continue typing 5–10 characters past expected safe end

EXPECTED:
- No corruption of earlier characters
- Cursor never jumps to invalid column
- Adjacent lines unchanged
- Line numbers render correctly

VARIATION A:
- Repeat on a blank or spaces-only line

VARIATION B:
- Scroll so the line becomes mid-screen due to scrolling
- Repeat the typing test

------------------------------------------------------------
TEST 2 — BACKSPACE IN INSERT MODE
------------------------------------------------------------

1. Press: i
2. Type: hello
3. Press backspace 3 times

EXPECTED:
- Text becomes: he
- Cursor moves left normally

EDGE CASES:
4. Backspace at column 0
EXPECTED:
- No crash
- Safe no-op or defined behavior

5. Backspace on blank line
EXPECTED:
- Stable cursor
- No redraw corruption

------------------------------------------------------------
TEST 3 — REPLACE MODE + QUOTES
------------------------------------------------------------

1. Press: R
2. Type exactly:
   He said "OK".

EXPECTED:
- Quotes render normally
- Replace mode remains active
- No mode break

EDGE:
3. Type: """""
4. Escape
5. Press R again and overwrite part of line

EXPECTED:
- No stuck mode
- No redraw glitches
- Line numbers intact

------------------------------------------------------------
TEST 4 — dd ON LAST LINE
------------------------------------------------------------

CASE A: SINGLE LINE BUFFER

1. Buffer contains exactly ONE line
2. Press: dd

EXPECTED:
- Line clears
- Buffer still has one (empty) line
- Cursor in valid position

CASE B: TWO LINES, CURSOR ON LAST

1. Buffer contains two lines
2. Cursor on last line
3. Press: dd

EXPECTED:
- Last line removed
- Cursor lands safely
- No crash

CASE C: LAST LINE IS BLANK

1. Make last line spaces-only
2. Press: dd

EXPECTED:
- Stable buffer
- Cursor valid
- No redraw issues

------------------------------------------------------------
TEST 5 — yy / p / P
------------------------------------------------------------

1. Yank a line using: yy
2. Paste below using: p
3. Paste above using: P

EXPECTED:
- Correct placement
- No duplicated garbage
- Line numbers correct

EDGE CASES:
- Paste at top of file
- Paste at bottom of file
- Paste when current line is blank

------------------------------------------------------------
TEST 6 — END-OF-LINE ON BLANK LINES
------------------------------------------------------------

1. Move to empty or spaces-only line
2. Press: $

EXPECTED:
- Cursor lands safely
- No crash

STRESS:
3. Press $ repeatedly (10 times)
4. Press: i
5. Type one character
6. Escape

EXPECTED:
- Stable cursor
- Clean redraw

------------------------------------------------------------
TEST 7 — SAVE TEST (BLACK SCREEN REGRESSION)
------------------------------------------------------------

CASE A: SAVE WITHOUT SCROLL

1. Make small edit near top
2. :w testA.txt

EXPECTED:
- Returns to editor
- Screen intact

CASE B: SAVE AFTER SCROLL

1. Scroll down ~1 screen
2. Edit mid-screen
3. :w testB.txt

EXPECTED:
- No black screen
- Cursor and line numbers visible

CASE C: MULTIPLE SAVES

1. Make edit
2. :w testC.txt
3. Repeat edit + save 3 times

EXPECTED:
- No progressive screen loss
- No forced reload

CASE D: SAVE AFTER END-OF-BUFFER TEST

1. Perform TEST 1B
2. Immediately :w testD.txt

EXPECTED:
- Save succeeds
- Editor remains visible

------------------------------------------------------------
TEST 8 — LINE NUMBER RENDERING TORTURE
------------------------------------------------------------

Purpose:
Catch "line numbers rendered in weird ways"

1. Load file with at least 120 lines
2. Scroll from line 1 to 130 and back

EXPECTED:
- Clean transition from 1→2→3 digit line numbers
- No stale digits
- No overlap into text

INTERACTION:
On lines 9, 10, 99, 100:
- i + type 1 char + Esc
- a + type 1 char + Esc
- R + type 1 char + Esc
- dd then p

EXPECTED:
- Line numbers stay aligned
- No redraw artifacts

------------------------------------------------------------
TEST 9 — NEW BUFFER + SCROLL + EDIT
------------------------------------------------------------

1. New empty buffer
2. Insert enough lines to scroll
3. Scroll up and down
4. yy / p on newly created lines
5. dd on last visible line

EXPECTED:
- No corruption
- Stable rendering
- No crash

------------------------------------------------------------
TEST 10 — MODE SWITCH STRESS
------------------------------------------------------------

Repeat 5 times on same line:

- i → type x → Esc
- a → type y → Esc
- R → type z → Esc
- Move cursor up/down

EXPECTED:
- Cursor stable
- No redraw artifacts
- No line number glitches

------------------------------------------------------------
TEST 11 — CURSOR SAFETY AT SCREEN EDGES
------------------------------------------------------------

1. Move to top-left editable cell
2. Press left/up repeatedly

EXPECTED:
- No crash
- Cursor clamped safely

3. Move to bottom-right editable cell
4. Press right/down repeatedly

EXPECTED:
- No memory corruption

5. Press $
6. Press a
7. Type 5 chars

EXPECTED:
- Clean insert
- Stable screen

------------------------------------------------------------
KNOWN LIMITATIONS
------------------------------------------------------------

- No undo
- Fixed line width (76 columns)
- No multi-line visual mode
- Pre-ALPHA: bugs expected

------------------------------------------------------------
FAILURE NOTES (FILL IN)
------------------------------------------------------------

Test ID:
Cursor mid-screen? (Y/N):
Scroll active? (Y/N):
Failure type:
- text corruption
- line number corruption
- redraw loss
- black screen
- crash

Can editor still accept input blindly? (Y/N):
Did save succeed? (Y/N):
Dropped to monitor? (Y/N):

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

