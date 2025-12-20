5  REM: Code originally from, https://www.commanderx16.com/forum/viewtopic.php?t=7108
10 PRINT"FILE TO RUN? (OR 'Q') "
20 INPUT F$
30 BLOAD F$, 8, 1, $A000
40 POKE PEEK(781) + 256 * PEEK(782), 0
50 EXEC $A000, 1
60 NEW
