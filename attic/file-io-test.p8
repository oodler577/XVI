%import textio
%import diskio
%zeropage basicsafe
%option no_sysinit

; simple test program for the "VTUI" text user interface library
; see:  https://github.com/JimmyDansbo/VTUIlib

main {
    sub open_file(str filepath) {
        if diskio.f_open(filepath) {
          move_cursor(main.minCol,main.line)
          repeat 53 { ;;;; number of lines, will need to be dynamic when dealing with files beyond view port
            str foo = " " * 75
            uword size = diskio.f_readline(foo)
            string.rstrip(foo)
            blank_line(main.line)
            vtg(main.minCol,main.line)
            vtui.print_str2(foo, $c6, true)
            cursor_presave(main.col,main.line)
            move_cursor(main.minCol, main.line+1)
          }
          diskio.f_close()
          move_cursor(main.minCol,main.minLine)
        }
        else {
          txt.print("oof error opening ")
          txt.print(filepath) 
          txt.print("...") 
        }
    }

    sub start() {
      open_file("default.txt")
    }
}
