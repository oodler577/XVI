XVI 2.0 (pre-ALPHA) - Quick Help + Test Sheet (Commander X16)
 
This file is meant to be READ inside of XVI and als used as a TEST script.
Try the actions exactly as written and verify the result feels Vim-like.
 
------------------------------------------------------------------------
STARTUP
------------------------------------------------------------------------
 
Splash screen:
 
  :e         filename<Enter> Load a file
  <esc>R     New buffer in REPLACE mode
  <esc>i     New buffer in INSERT mode
 
Notes:
 
  - This editor is modal (like Vim)
  - Cursor is constrained to a fixed text box (no long lines yet).
 
------------------------------------------------------------------------
MODES
------------------------------------------------------------------------
 
NAV mode:
 
  - i insert before cursor (Vim-like)
  - a append after cursor (Vim-like)
  - Text shifts right as you type.
  - Backspace deletes to the left within the line.
 
REPLACE mode:
 
  - R replace characters under the cursor.
  - Typed characters overwrite existing text.
  - Backspace moves lef without inserting junk.
 
Status indicator:
                                                                            
  "-- INSERT --" or "--REPLACE --" appears on screen.
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
