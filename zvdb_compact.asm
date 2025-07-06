; zvdb-z80 - Compact version with 32-byte alignment
; For Scorpion ZS-256-Turbo+ with 256KB RAM
; Uses address calculation by << 5 (multiply by 32)

        DEVICE ZXSPECTRUM128

; Constants
VECTOR_BITS     EQU     256     ; Bits per vector
VECTOR_BYTES    EQU     32      ; Bytes per vector (256/8)
VECTOR_SHIFT    EQU     5       ; Shift for *32 multiplication
VECTORS_PER_PAGE EQU    512     ; Vectors per 16KB page (16384/32)
MAX_PAGES       EQU     14      ; Maximum pages for vectors (pages 0-13)
MAX_VECTORS     EQU     7168    ; Maximum vectors (14 pages × 512 vectors)
HASH_BITS       EQU     8       ; Bits for hash (256 buckets)
HYPERPLANES     EQU     8       ; Number of hyperplanes for hashing

; Scorpion memory paging ports
PORT_7FFD       EQU     #7FFD   ; Standard 128K port
PORT_1FFD       EQU     #1FFD   ; Scorpion extended memory port

; Memory pages
PAGE_VECTORS    EQU     #C000   ; Window for vector access (page 3)
PAGE_WORK       EQU     #8000   ; Working page (page 2)

; Memory layout in page 2 (#8000-#BFFF)
        ORG     #8000

; Hash index (256 entries × 4 bytes each)
hash_index:
        DEFS    256 * 4         ; 1KB

; Hyperplanes for hashing (8 hyperplanes × 32 bytes each)
hyperplanes:
        DEFS    HYPERPLANES * VECTOR_BYTES      ; 256 bytes

; Working buffers
query_vector:
        DEFS    VECTOR_BYTES    ; Query vector buffer
temp_vector:
        DEFS    VECTOR_BYTES    ; Temporary vector buffer

; Variables
vector_count:   DEFW    0       ; Current number of vectors (16-bit)
best_score:     DEFW    0       ; Best score found
best_index:     DEFW    0       ; Index of best match
current_page:   DEFB    #FF     ; Currently mapped page at #C000

; Bit counting lookup table (0-255 -> count of 1 bits)
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

; Main entry point
main:
        DI                      ; Disable interrupts
        LD      SP,#7FFF       ; Set stack
        CALL    init_db        ; Initialize database
        RET

; Initialize database
init_db:
        ; Clear vector count
        XOR     A
        LD      (vector_count),A
        LD      (vector_count+1),A
        
        ; Clear hash index
        LD      HL,hash_index
        LD      DE,hash_index+1
        LD      BC,256*4-1
        LD      (HL),0
        LDIR
        
        ; Initialize random hyperplanes
        LD      HL,hyperplanes
        LD      BC,HYPERPLANES * VECTOR_BYTES
.init_hyper:
        LD      A,R            ; Use R register for pseudo-random
        XOR     B
        LD      (HL),A
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.init_hyper
        
        ; Mark current page as invalid
        LD      A,#FF
        LD      (current_page),A
        
        RET

; Fast multiply by 32 using shifts
; HL = value to multiply
; Returns: HL = value * 32
mul32:
        ADD     HL,HL          ; *2
        ADD     HL,HL          ; *4
        ADD     HL,HL          ; *8
        ADD     HL,HL          ; *16
        ADD     HL,HL          ; *32
        RET

; Switch to page containing vector
; HL = vector index (0-7167)
; Returns: HL = pointer to vector in PAGE_VECTORS window
; Preserves: DE
switch_vector_page:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        
        ; Calculate page number (index / 512)
        ; Since 512 = 2^9, we need to shift right by 9
        PUSH    HL
        LD      B,7            ; We'll shift by 7 after getting high byte
        LD      A,H
        AND     A
        JR      Z,.page_zero   ; If H=0, index < 256, page = 0
        
.shift_loop:
        SRL     H
        RR      L
        DJNZ    .shift_loop
        
        LD      A,L            ; A = page number
        JR      .got_page
        
.page_zero:
        XOR     A              ; Page 0
        
.got_page:
        LD      C,A            ; Save page number
        
        ; Check if already mapped
        LD      A,(current_page)
        CP      C
        JR      Z,.same_page
        
        ; Map new page
        LD      A,C
        CALL    set_page_c000
        LD      (current_page),A
        
.same_page:
        ; Calculate offset within page (index & 511) * 32
        POP     HL             ; Restore index
        LD      A,H
        AND     #01            ; Keep only bit 0 of H (for modulo 512)
        LD      H,A
        
        ; Now HL = index modulo 512
        ; Multiply by 32
        CALL    mul32
        
        ; Add base address
        LD      DE,PAGE_VECTORS
        ADD     HL,DE
        
        POP     DE
        POP     BC
        POP     AF
        RET

; Set page at #C000-#FFFF
; A = page number (0-15)
set_page_c000:
        PUSH    BC
        LD      C,A
        LD      B,A
        
        ; Read current port values
        LD      A,(#5B5C)      ; System variable for last OUT to 7FFD
        AND     #F8            ; Clear bits 0-2
        OR      C              ; Set new page
        LD      BC,PORT_7FFD
        OUT     (C),A
        LD      (#5B5C),A      ; Update system variable
        
        POP     BC
        RET

; Count bits in a byte (A -> A)
count_bits:
        PUSH    HL
        LD      H,popcount_table/256
        LD      L,A
        LD      A,(HL)
        POP     HL
        RET

; Calculate 1-bit dot product between two vectors
; HL = vector1 pointer, DE = vector2 pointer
; Returns: BC = similarity score (256 - 2*hamming_distance)
dot_product_1bit:
        PUSH    HL
        PUSH    DE
        
        LD      BC,0           ; Bit difference counter
        PUSH    BC             ; Save counter on stack
        
        LD      B,VECTOR_BYTES
.dot_loop:
        LD      A,(DE)         ; Get byte from vector2
        XOR     (HL)           ; XOR with vector1 byte
        CALL    count_bits     ; Count different bits
        
        ; Add to total
        LD      C,A
        LD      B,0
        EX      (SP),HL        ; Get counter from stack
        ADD     HL,BC          ; Add bit count
        EX      (SP),HL        ; Put counter back
        
        INC     HL
        INC     DE
        DJNZ    .dot_loop
        
        ; Calculate final score: 256 - 2*hamming_distance
        POP     BC             ; Get hamming distance
        SLA     C              ; Multiply by 2
        RL      B
        
        LD      HL,VECTOR_BITS
        OR      A              ; Clear carry
        SBC     HL,BC          ; 256 - 2*hamming
        LD      B,H
        LD      C,L
        
        POP     DE
        POP     HL
        RET

; Add vector to database
; HL = pointer to vector data
add_vector:
        PUSH    HL
        
        ; Check if database is full
        LD      HL,(vector_count)
        LD      DE,MAX_VECTORS
        OR      A
        SBC     HL,DE
        JR      NC,.db_full
        
        ; Get vector count
        LD      HL,(vector_count)
        PUSH    HL
        
        ; Switch to appropriate page
        CALL    switch_vector_page ; HL = destination in paged memory
        
        ; Copy vector
        EX      DE,HL          ; DE = destination
        POP     HL             ; Restore vector count
        POP     HL             ; HL = source vector
        PUSH    HL
        LD      BC,VECTOR_BYTES
        LDIR
        
        ; Increment vector count
        LD      HL,(vector_count)
        INC     HL
        LD      (vector_count),HL
        
.db_full:
        POP     HL
        RET

; Copy vector from paged memory to working buffer
; HL = vector index
; DE = destination buffer
copy_vector_to_buffer:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        
        CALL    switch_vector_page ; HL = vector pointer
        
        ; Copy to buffer
        POP     BC             ; Get index back
        POP     DE             ; Destination
        PUSH    DE
        PUSH    BC
        LD      BC,VECTOR_BYTES
        LDIR
        
        POP     HL
        POP     DE
        POP     BC
        RET

; Brute force search for nearest vector
; HL = query vector pointer
; Returns: DE = best index, BC = best score
bf_search:
        PUSH    HL
        
        ; Copy query to buffer
        LD      DE,query_vector
        LD      BC,VECTOR_BYTES
        LDIR
        
        ; Initialize best score to minimum
        LD      HL,#8000       ; -32768 (worst possible score)
        LD      (best_score),HL
        LD      HL,0
        LD      (best_index),HL
        
        ; Check each vector
        LD      HL,0           ; Vector index
.search_loop:
        PUSH    HL
        
        ; Check if we've searched all vectors
        LD      DE,(vector_count)
        OR      A
        SBC     HL,DE
        JR      NC,.search_done_pop
        
        ; Copy vector to temp buffer
        POP     HL
        PUSH    HL
        LD      DE,temp_vector
        CALL    copy_vector_to_buffer
        
        ; Calculate dot product
        LD      HL,query_vector
        LD      DE,temp_vector
        CALL    dot_product_1bit ; BC = score
        
        ; Compare with best score
        LD      HL,(best_score)
        OR      A
        SBC     HL,BC
        JR      NC,.not_better
        
        ; New best score
        LD      (best_score),BC
        POP     HL
        LD      (best_index),HL
        PUSH    HL
        
.not_better:
        POP     HL
        INC     HL
        JR      .search_loop
        
.search_done_pop:
        POP     HL
.search_done:
        POP     HL
        LD      DE,(best_index)
        LD      BC,(best_score)
        RET

; Calculate hash for a vector using hyperplanes
; HL = vector pointer (must be in accessible memory)
; Returns: A = 8-bit hash
calc_hash:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        
        LD      C,0            ; Hash accumulator
        LD      DE,hyperplanes
        
        ; Process each hyperplane
        LD      B,HASH_BITS
.hash_loop:
        PUSH    BC
        PUSH    HL
        
        ; Calculate dot product with hyperplane
        CALL    dot_product_1bit
        
        ; Check if positive (BC >= 128)
        LD      A,B
        OR      A
        JR      NZ,.set_bit    ; High byte non-zero = positive
        LD      A,C
        CP      128
        JR      NC,.set_bit
        
        ; Negative - rotate hash left with 0
        POP     HL
        POP     BC
        SLA     C              ; Shift left, 0 enters
        JR      .next_plane
        
.set_bit:
        ; Positive - rotate hash left with 1
        POP     HL
        POP     BC
        SCF                    ; Set carry
        RL      C              ; Rotate left through carry
        
.next_plane:
        PUSH    BC
        PUSH    HL
        
        ; Move to next hyperplane
        LD      HL,VECTOR_BYTES
        ADD     HL,DE
        EX      DE,HL
        
        POP     HL
        POP     BC
        DJNZ    .hash_loop
        
        LD      A,C            ; Return hash in A
        POP     BC
        POP     DE
        POP     HL
        RET

; Reindex all vectors (rebuild hash index)
reindex:
        ; Clear hash index
        LD      HL,hash_index
        LD      DE,hash_index+1
        LD      BC,256*4-1
        LD      (HL),0
        LDIR
        
        ; Process each vector
        LD      HL,0           ; Vector counter
.reindex_loop:
        PUSH    HL
        
        ; Check if done
        LD      DE,(vector_count)
        OR      A
        SBC     HL,DE
        JR      NC,.reindex_done_pop
        
        ; Copy vector to temp buffer
        POP     HL
        PUSH    HL
        LD      DE,temp_vector
        CALL    copy_vector_to_buffer
        
        ; Calculate hash
        LD      HL,temp_vector
        CALL    calc_hash      ; A = hash
        
        ; Get hash bucket address
        LD      L,A
        LD      H,0
        ADD     HL,HL          ; *2
        ADD     HL,HL          ; *4 for 4-byte entries
        LD      DE,hash_index
        ADD     HL,DE
        
        ; Check if bucket empty
        LD      A,(HL)
        INC     HL
        OR      (HL)
        DEC     HL
        JR      NZ,.bucket_used
        
        ; Store in primary slot
        POP     DE             ; Vector index
        PUSH    DE
        LD      A,E
        LD      (HL),A         ; Store index low
        INC     HL
        LD      A,D
        LD      (HL),A         ; Store index high
        INC     HL
        LD      (HL),1         ; Count = 1
        INC     HL
        LD      (HL),#FF       ; No next entry
        JR      .next_vector
        
.bucket_used:
        ; For now, skip collision handling
        
.next_vector:
        POP     HL
        INC     HL
        JR      .reindex_loop
        
.reindex_done_pop:
        POP     HL
        RET

; Fast batch search - process multiple queries efficiently
; HL = pointer to array of query vectors
; DE = pointer to result array
; B = number of queries
batch_search:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        
.batch_loop:
        PUSH    BC
        
        ; Search for current query
        CALL    bf_search      ; DE = index, BC = score
        
        ; Store result
        POP     AF             ; Get counter
        PUSH    AF
        LD      HL,SP+4        ; Get result pointer
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        LD      SP+4,HL       ; Update result pointer
        
        ; Move to next query
        LD      HL,SP+6        ; Get query pointer
        LD      BC,VECTOR_BYTES
        ADD     HL,BC
        LD      SP+6,HL       ; Update query pointer
        
        POP     BC
        DJNZ    .batch_loop
        
        POP     HL
        POP     DE
        POP     BC
        RET

        END     main