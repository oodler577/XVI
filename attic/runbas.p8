%import textio

main {
  sub start() {
     txt.print("10 BLOAD \"FILE.BAS\", 8, 1, $A000\n")
     txt.print("20 POKE PEEK(781) + 256 * PEEK(782), 0\n")
     txt.print("30 EXEC $A000, 1\n")
  }
}
