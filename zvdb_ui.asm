; zvdb-z80 UI Demo for ZX Spectrum
; Vector database with UI, plasma effect, and scroller
; For ZX Spectrum 128K

        DEVICE ZXSPECTRUM128
        OUTPUT "zvdb_ui.sna"

; Memory layout
        ORG     #8000

; System variables
LAST_K          EQU     #5C08
FRAMES          EQU     #5C78
ATTR_P          EQU     #5C8D
SCREEN          EQU     #4000
ATTRS           EQU     #5800

; Colors
BLACK           EQU     0
BLUE            EQU     1
RED             EQU     2
MAGENTA         EQU     3
GREEN           EQU     4
CYAN            EQU     5
YELLOW          EQU     6
WHITE           EQU     7
BRIGHT          EQU     #40
FLASH           EQU     #80

; Constants from zvdb.asm
VECTOR_BITS     EQU     256
VECTOR_BYTES    EQU     32
MAX_VECTORS     EQU     64      ; Reduced for demo
HASH_BITS       EQU     6
HYPERPLANES     EQU     8

; UI constants
VECTORS_PER_PAGE EQU    8       ; Vectors shown at once
SPRITE_Y        EQU     8       ; Y position for sprites
SPRITE_X        EQU     2       ; X position start

main:
        DI
        LD      SP,#7FFF
        
        ; Initialize
        CALL    init_system
        CALL    init_db
        CALL    load_demo_vectors
        CALL    init_plasma
        CALL    init_scroller
        
        ; Main loop
main_loop:
        CALL    clear_screen
        CALL    draw_title
        CALL    display_vector_list
        CALL    update_plasma
        CALL    update_scroller
        
        ; Wait for VBlank
        HALT
        
        ; Check keys
        CALL    check_keys
        JR      main_loop

; Initialize system
init_system:
        ; Set border
        XOR     A
        OUT     (#FE),A
        
        ; Clear screen
        LD      HL,SCREEN
        LD      DE,SCREEN+1
        LD      BC,6143
        LD      (HL),0
        LDIR
        
        ; Set attributes
        LD      HL,ATTRS
        LD      DE,ATTRS+1
        LD      BC,767
        LD      (HL),WHITE
        LDIR
        
        RET

; Clear screen preserving bottom area
clear_screen:
        LD      HL,SCREEN
        LD      DE,SCREEN+1
        LD      BC,#1400        ; Clear top part only
        LD      (HL),0
        LDIR
        RET

; Draw title
draw_title:
        LD      HL,title_text
        LD      DE,SCREEN + 0
        CALL    print_string
        
        ; Draw line
        LD      HL,SCREEN + 32
        LD      B,32
.line_loop:
        LD      (HL),#FF
        INC     HL
        DJNZ    .line_loop
        
        RET

title_text:
        DEFM    " ZVDB-Z80 VECTOR DATABASE DEMO  "
        DEFB    0

; Display vector list with sprites
display_vector_list:
        LD      A,(page_offset)
        LD      C,A
        LD      B,VECTORS_PER_PAGE
        
        LD      DE,SCREEN + 3*32  ; Start position
        
.display_loop:
        PUSH    BC
        PUSH    DE
        
        ; Check if vector exists
        LD      A,C
        LD      HL,vector_count
        CP      (HL)
        JR      NC,.skip_vector
        
        ; Check if selected
        LD      A,(selected_vector)
        CP      C
        JR      NZ,.not_selected
        
        ; Highlight selected
        PUSH    DE
        ; Calculate attribute position
        LD      A,D
        AND     #18
        RRCA
        RRCA
        RRCA
        LD      H,A
        LD      A,D
        AND     #07
        OR      #58
        LD      H,A
        LD      L,E
        LD      B,16            ; Width in chars
.attr_loop:
        LD      (HL),BLUE + BRIGHT + (WHITE << 3)
        INC     HL
        DJNZ    .attr_loop
        POP     DE
        
.not_selected:
        ; Display vector number
        LD      A,C
        PUSH    BC
        PUSH    DE
        CALL    print_hex_at_de
        POP     DE
        POP     BC
        
        ; Move to sprite position
        INC     E
        INC     E
        INC     E
        
        ; Display 8x8 sprite
        PUSH    BC
        PUSH    DE
        LD      A,C
        CALL    draw_vector_sprite
        POP     DE
        POP     BC
        
.skip_vector:
        ; Next line (16 pixels = 2 chars)
        EX      DE,HL
        LD      DE,32*16
        ADD     HL,DE
        EX      DE,HL
        
        POP     DE
        POP     BC
        INC     C
        DJNZ    .display_loop
        
        RET

; Draw 8x8 sprite for vector A at position DE
draw_vector_sprite:
        ; Calculate vector address
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x2
        ADD     HL,HL           ; x4
        ADD     HL,HL           ; x8
        ADD     HL,HL           ; x16
        ADD     HL,HL           ; x32
        LD      BC,vectors_db
        ADD     HL,BC
        
        ; Draw 8x8 sprite
        LD      B,8
.sprite_loop:
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        
        ; Next screen line
        INC     D
        LD      A,D
        AND     7
        JR      NZ,.same_third
        LD      A,E
        ADD     A,32
        LD      E,A
        JR      C,.next_third
        LD      A,D
        SUB     8
        LD      D,A
        JR      .same_third
.next_third:
        LD      A,D
        SUB     8
        LD      D,A
.same_third:
        DJNZ    .sprite_loop
        
        RET

; Print hex byte A at position DE
print_hex_at_de:
        PUSH    AF
        PUSH    DE
        
        ; High nibble
        RRA
        RRA
        RRA
        RRA
        AND     #0F
        CP      10
        JR      C,.digit1
        ADD     A,7
.digit1:
        ADD     A,'0'
        CALL    print_char_at_de
        
        ; Low nibble
        POP     DE
        INC     E
        POP     AF
        AND     #0F
        CP      10
        JR      C,.digit2
        ADD     A,7
.digit2:
        ADD     A,'0'
        CALL    print_char_at_de
        RET

; Print character A at position DE
print_char_at_de:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        
        ; Get character bitmap
        SUB     32
        LD      L,A
        LD      H,0
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      BC,font_data - 32*8
        ADD     HL,BC
        
        ; Copy to screen
        LD      B,8
.char_loop:
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     D
        DJNZ    .char_loop
        
        POP     BC
        POP     DE
        POP     HL
        RET

; Simple plasma effect
update_plasma:
        LD      A,(plasma_phase)
        INC     A
        LD      (plasma_phase),A
        
        ; Update bottom third attributes
        LD      HL,ATTRS + 20*32
        LD      B,4             ; 4 lines
.plasma_line:
        PUSH    BC
        LD      B,32
.plasma_loop:
        LD      A,(plasma_phase)
        ADD     A,B
        AND     7
        OR      BRIGHT
        LD      (HL),A
        INC     HL
        DJNZ    .plasma_loop
        POP     BC
        DJNZ    .plasma_line
        
        RET

; Initialize plasma
init_plasma:
        XOR     A
        LD      (plasma_phase),A
        RET

; Update scrolling text
update_scroller:
        ; Shift scroll buffer left
        LD      HL,scroll_buffer+1
        LD      DE,scroll_buffer
        LD      BC,31
        LDIR
        
        ; Get next character
        LD      HL,(scroll_ptr)
        LD      A,(HL)
        OR      A
        JR      NZ,.not_end
        LD      HL,scroll_text
        LD      A,(HL)
.not_end:
        INC     HL
        LD      (scroll_ptr),HL
        
        ; Add to buffer
        LD      (scroll_buffer+31),A
        
        ; Display scroll buffer
        LD      HL,scroll_buffer
        LD      DE,SCREEN + 23*32
        LD      B,32
.display_scroll:
        LD      A,(HL)
        PUSH    HL
        PUSH    BC
        PUSH    DE
        CALL    print_char_at_de
        POP     DE
        POP     BC
        POP     HL
        INC     HL
        INC     E
        DJNZ    .display_scroll
        
        RET

; Initialize scroller
init_scroller:
        LD      HL,scroll_text
        LD      (scroll_ptr),HL
        
        ; Clear scroll buffer
        LD      HL,scroll_buffer
        LD      B,32
        LD      A,' '
.clear_scroll:
        LD      (HL),A
        INC     HL
        DJNZ    .clear_scroll
        
        RET

scroll_text:
        DEFM    "*** ZVDB-Z80 SPECTRUM DEMO *** "
        DEFM    "GREETINGS TO ALL ZX SPECTRUM CODERS! "
        DEFM    "VECTOR DATABASE WITH 1-BIT QUANTIZATION... "
        DEFM    "USE CURSOR KEYS TO SELECT, ENTER TO SEARCH... "
        DEFM    "CODE BY OISEE WITH HELP FROM CLAUDE... "
        DEFM    "                                "
        DEFB    0

; Check keyboard
check_keys:
        ; Read keyboard
        LD      A,#EF           ; 0-6
        IN      A,(#FE)
        BIT     0,A             ; 0 - Down
        JR      Z,move_down
        
        LD      A,#F7           ; 1-5
        IN      A,(#FE)
        BIT     4,A             ; 5 - Left/Up
        JR      Z,move_up
        
        LD      A,#BF           ; ENTER-H
        IN      A,(#FE)
        BIT     0,A             ; ENTER
        JR      Z,do_search
        
        RET

move_down:
        LD      A,(selected_vector)
        INC     A
        LD      B,A
        LD      A,(vector_count)
        CP      B
        RET     C
        LD      A,B
        LD      (selected_vector),A
        RET

move_up:
        LD      A,(selected_vector)
        OR      A
        RET     Z
        DEC     A
        LD      (selected_vector),A
        RET

do_search:
        CALL    perform_search
        CALL    show_results
        
        ; Wait for key release
.wait_release:
        LD      A,#BF
        IN      A,(#FE)
        BIT     0,A
        JR      Z,.wait_release
        
        RET

; Perform search using selected vector
perform_search:
        ; Copy selected vector to query
        LD      A,(selected_vector)
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x32
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      DE,vectors_db
        ADD     HL,DE
        LD      DE,query_vector
        LD      BC,VECTOR_BYTES
        LDIR
        
        ; Do brute force search
        CALL    bf_search
        RET

; Show search results
show_results:
        ; Clear middle of screen
        LD      HL,SCREEN + 10*32
        LD      B,64
.clear_loop:
        PUSH    BC
        PUSH    HL
        LD      B,32
        XOR     A
.clear_line:
        LD      (HL),A
        INC     HL
        DJNZ    .clear_line
        POP     HL
        LD      DE,32
        ADD     HL,DE
        POP     BC
        DJNZ    .clear_loop
        
        ; Show result
        LD      HL,result_text
        LD      DE,SCREEN + 12*32 + 8
        CALL    print_string
        
        ; Show best match index
        LD      A,(best_index)
        LD      DE,SCREEN + 13*32 + 16
        CALL    print_hex_at_de
        
        ; Wait for key
.wait_key:
        XOR     A
        IN      A,(#FE)
        AND     #1F
        CP      #1F
        JR      Z,.wait_key
        
        RET

result_text:
        DEFM    "BEST MATCH:"
        DEFB    0

; Print string HL at position DE
print_string:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        CALL    print_char_at_de
        POP     HL
        INC     HL
        INC     E
        JR      print_string

; Load demo vectors
load_demo_vectors:
        LD      B,16            ; Create 16 demo vectors
        XOR     A
        LD      (vector_count),A
        
.create_loop:
        PUSH    BC
        
        ; Generate pattern
        LD      A,(vector_count)
        LD      C,A
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x32
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      DE,vectors_db
        ADD     HL,DE
        
        ; Create pattern based on index
        LD      B,VECTOR_BYTES
.pattern_loop:
        LD      A,C
        ADD     A,B
        RLCA
        XOR     B
        LD      (HL),A
        INC     HL
        DJNZ    .pattern_loop
        
        LD      A,(vector_count)
        INC     A
        LD      (vector_count),A
        
        POP     BC
        DJNZ    .create_loop
        
        RET

; Include core ZVDB routines
init_db:
        XOR     A
        LD      (vector_count),A
        
        ; Clear hash index
        LD      HL,hash_index
        LD      DE,hash_index+1
        LD      BC,64*2-1
        LD      (HL),0
        LDIR
        
        ; Initialize hyperplanes
        LD      HL,hyperplanes
        LD      BC,HYPERPLANES * VECTOR_BYTES
        LD      A,#AA
.init_hyper:
        LD      (HL),A
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.init_hyper
        
        RET

; Brute force search
bf_search:
        LD      HL,#0000
        LD      (best_score),HL
        XOR     A
        LD      (best_index),A
        
        LD      A,(vector_count)
        OR      A
        RET     Z
        
        LD      B,A
        XOR     A
        LD      (current_index),A
        
.search_loop:
        PUSH    BC
        
        ; Get vector address
        LD      A,(current_index)
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x32
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      DE,vectors_db
        ADD     HL,DE
        
        ; Calculate similarity
        LD      DE,query_vector
        CALL    dot_product_1bit
        
        ; Compare with best
        LD      DE,(best_score)
        OR      A
        SBC     HL,DE
        JR      C,.not_better
        ADD     HL,DE
        LD      (best_score),HL
        LD      A,(current_index)
        LD      (best_index),A
        
.not_better:
        LD      A,(current_index)
        INC     A
        LD      (current_index),A
        
        POP     BC
        DJNZ    .search_loop
        
        RET

; Dot product for 1-bit vectors
dot_product_1bit:
        PUSH    BC
        PUSH    DE
        
        LD      BC,0            ; Hamming distance
        LD      A,VECTOR_BYTES
        
.dot_loop:
        PUSH    AF
        LD      A,(DE)
        XOR     (HL)
        
        ; Count bits
        CALL    count_bits
        ADD     A,C
        LD      C,A
        JR      NC,.no_carry
        INC     B
.no_carry:
        
        INC     HL
        INC     DE
        POP     AF
        DEC     A
        JR      NZ,.dot_loop
        
        ; Calculate 256 - 2*hamming
        LD      H,B
        LD      L,C
        ADD     HL,HL
        EX      DE,HL
        LD      HL,256
        OR      A
        SBC     HL,DE
        
        POP     DE
        POP     BC
        RET

; Count bits in A
count_bits:
        PUSH    HL
        LD      H,popcount_table/256
        LD      L,A
        LD      A,(HL)
        POP     HL
        RET

; Variables
vector_count:   DEFB    0
selected_vector: DEFB   0
page_offset:    DEFB    0
current_index:  DEFB    0
best_score:     DEFW    0
best_index:     DEFB    0
plasma_phase:   DEFB    0
scroll_ptr:     DEFW    scroll_text
scroll_buffer:  DEFS    32

; Buffers
query_vector:   DEFS    VECTOR_BYTES
temp_vector:    DEFS    VECTOR_BYTES

; Database
vectors_db:     DEFS    VECTOR_BYTES * MAX_VECTORS
hash_index:     DEFS    64 * 2
hyperplanes:    DEFS    HYPERPLANES * VECTOR_BYTES

; Popcount table
        ALIGN   256
popcount_table:
        DEFB    0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8

; Basic font data (subset)
font_data:
        ; Space (32)
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        ; ! (33)
        DEFB    #18,#18,#18,#18,#00,#00,#18,#00
        ; ... would include full font set
        ; For demo, using ROM font would be better

        SAVEBIN "zvdb_ui.bin",#8000,$-#8000
        SAVESNA "zvdb_ui.sna",main