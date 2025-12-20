%encoding iso
%import textio
%import string

main {
    str userinput = "x"*80;

    sub start() {
      txt.clear_screen();
      txt.iso()

      ; test dailog and input ith 'input_chars'
      txt.print("Type something:")
      txt.nl(); txt.nl()
      txt.input_chars(userinput)
      txt.nl()
      txt.print(userinput);
      txt.nl(); txt.nl()

      ; loops until a 'Y' or a 'y' is provided
      str Yn = "?"
      while (Yn != "Y" and Yn != "y") {
        txt.print("Quit Y/n? ")
        txt.input_chars(Yn)
        txt.nl()
      }
    }
}
