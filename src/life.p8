; conway's game of life.

%import math
%import textio

;
; Keyboard Command & Control
;   0     triggers full initial seeding to take place
;
; 1-9     randomly generates N 3x3 blocks; all cells are guaranteed to be alive
;         except the middle one, where it has a "math.rnd()&1" chance of being so
;
;   k     causes a mass kill event - mainly for testing the other key functions
;
;   p     toggles "perturb" mode on/off (starts "off") - if "on", the population
;         is checked, and if it falls below some threshhold (set in the code), it 
;         seeds more areas; this is to keep it always moving (for screen savers, etc) 

main {
    const ubyte WIDTH = 80
    const ubyte HEIGHT = 60-4
    const uword STRIDE = $0002+WIDTH
    uword world1 = memory("world1", (WIDTH+2)*(HEIGHT+2), 0)
    uword world2 = memory("world2", (WIDTH+2)*(HEIGHT+2), 0)
    uword @requirezp active_world = world1
    bool perturb = false

   sub start() {
        ; cx16.set_screen_mode(3)
        txt.cls()
        txt.color(8)
        txt.plot(50,0)
        txt.print("prog8 - conway's game of life")
        sys.memset(world1, (WIDTH+2)*(HEIGHT+2), 0)
        sys.memset(world2, (WIDTH+2)*(HEIGHT+2), 0)

        set_start_gen()

        ubyte gen_add
        uword gen, pop_size
        ubyte char
        repeat {
            if gen_add==0
                cbm.SETTIM(0,0,0)

            next_gen()

            gen++
            txt.home()
            txt.color(5)
            txt.print(" gen ")
            txt.print_uw(gen)

            gen_add++
            if gen_add==10 {
                txt.print("  jiffies/10 gens: ")
                txt.print_uw(cbm.RDTIM16())
                txt.print("  ")
                gen_add=0
            }

            ; seed if population is low
            if (perturb == true) {
              pop_size = pop_count()
              if (pop_size < 2500) {
                add_random_seeds(9)
              }
            }

            ; keyboard controls for fun and long living populations (screen saver)
            void, char = cbm.GETIN()
            when char {
              $31,$32,$33,$34,$35,$36,$37,$38,$39 -> { ; digits 1-9
                add_random_seeds(char - $30)
              }
              $30 -> { ; digit 0
                set_start_gen()
              }
              $4b -> { ; k - causes mass extinction event
                extinguish()
              }
              $50 -> { ; p - toggle perturb mode
                if (perturb == false) {
                  perturb = true
                }
                else {
                  perturb = false 
                }
              }
              $51 -> { ; q - quit
                sys.exit(0)
              }
            }
        }
    }

    ; count curret population
    sub pop_count() -> uword {
        uword offset = STRIDE+1
        uword count  = 0
        ubyte x
        ubyte y
        for y in 0 to HEIGHT-1 {
            for x in 0 to WIDTH-1 {
                if (active_world[offset+x] == 1) {
                  count++
                } 
            }
            offset += STRIDE
        }
        return count
    }

    ; mass extinction even
    sub extinguish() {
        uword offset = STRIDE+1
        ubyte x
        ubyte y
        for y in 0 to HEIGHT-1 {
            for x in 0 to WIDTH-1 {
                active_world[offset+x] = 0 
            }
            offset += STRIDE
        }
    }

    sub add_random_seeds(ubyte numToAdd) {
        uword offset
        ubyte x,y,topX,topY
        repeat numToAdd {
          offset = STRIDE+1
          ; select valid top left of the 3x3 seed block
          topY = math.rnd() % (HEIGHT-1-3)
          topX = math.rnd() % (WIDTH-1-3)
          for y in topY to topY+2 {
            for x in topX to topX+2 {
                active_world[offset+x] =  1
            }
            offset += STRIDE
          }
          offset = (topY+1)*STRIDE
          active_world[offset+topX+1] =  math.rnd() & 1
        }
    }

    sub set_start_gen() {

; some way to set a custom start generation:
;        str start_gen = "                " +
;                        "                " +
;                        "                " +
;                        "          **    " +
;                        "        *    *  " +
;                        "       *        " +
;                        "       *     *  " +
;                        "       ******   " +
;                        "                " +
;                        "                " +
;                        "                " +
;                        "                " +
;                        "                " +
;                        "                " +
;                        "                " +
;                        "               "
;
;        for y in 0 to 15 {
;            for x in 0 to 15 {
;                if start_gen[y*16 + x]=='*'
;                    active_world[offset + x] = 1
;            }
;            offset += STRIDE
;        }

        ; randomize whole world
        uword offset = STRIDE+1
        ubyte x
        ubyte y
        for y in 0 to HEIGHT-1 {
            for x in 0 to WIDTH-1 {
                active_world[offset+x] = math.rnd() & 1
            }
            offset += STRIDE
        }
    }

    sub next_gen() {
        const ubyte DXOFFSET = 0
        const ubyte DYOFFSET = 2
        uword voffset = STRIDE+1-DXOFFSET
        uword @zp offset
        ubyte[2] cell_chars = [sc:' ', sc:'●']

        uword @requirezp new_world = world1
        if active_world == world1
            new_world = world2

        ubyte x
        ubyte y
        for y in DYOFFSET to HEIGHT+DYOFFSET-1 {

            cx16.vaddr_autoincr(1, $b000 + 256*y, 0, 2)     ;  allows us to use simple Vera data byte assigns later instead of setchr() calls

            for x in DXOFFSET to WIDTH+DXOFFSET-1 {
                offset = voffset + x

                ; count the living neighbors
                ubyte cell = active_world[offset]
                uword @requirezp ptr = active_world + offset - STRIDE - 1
                ubyte neighbors = @(ptr) + @(ptr+1) + @(ptr+2) +
                                  @(ptr+STRIDE) + cell + @(ptr+STRIDE+2) +
                                  @(ptr+STRIDE*2) + @(ptr+STRIDE*2+1) + @(ptr+STRIDE*2+2)

                ; apply game of life rules
                if neighbors==3
                    cell=1
                else if neighbors!=4
                    cell=0
                new_world[offset] = cell

                ; draw new cell
                ; txt.setchr(x,y,cell_chars[cell])
                cx16.VERA_DATA0 = cell_chars[cell]
            }
            voffset += STRIDE
        }

        active_world = new_world
    }
}

