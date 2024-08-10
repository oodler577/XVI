%encoding iso
%import textio
%import string
%import conv
%import syslib
%import diskio
%option no_sysinit
%zeropage basicsafe

main {
    str userinput        = "x"*80
    str currFilename     = " "*80

    sub start() {
      ubyte char = 0 
      txt.clear_screen();
      txt.iso()
      open_file("default2.txt")

navcharloop:
      void, char = cbm.GETIN()
      when char {
        $71 -> {
          sys.exit(0)
        }
      }
      goto navcharloop 
    }

    sub open_file(str filepath) {
        ubyte j, retcode, length
        str stringout = " " * 80
        ubyte lines   = 0
        cbm.CLEARST() ; set so READST() is initially known 
        if diskio.f_open(filepath) {
          main.currFilename = filepath
          while cbm.READST() == 0 {
            str lineBuffer = " " *  100 
            length = diskio.f_readline(lineBuffer)
            string.rstrip(lineBuffer)
            txt.print(lineBuffer)
            txt.nl()
            lines += 1
          }
          conv.str_ub(lines)
          txt.print(conv.string_out)
          txt.print(" lines")
          txt.nl()
          diskio.f_close()
        }
    }
}
