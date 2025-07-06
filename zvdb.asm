; zvdb-z80 - Minimal Z80 implementation of ZVDB
; For Scorpion ZS-256-Turbo+ (256-bit vectors)
; Uses 1-bit quantization and random hyperplane indexing

        DEVICE ZXSPECTRUM128

; Constants
VECTOR_BITS     EQU     256     ; Bits per vector (Scorpion specific)
VECTOR_BYTES    EQU     32      ; Bytes per vector (256/8)
MAX_VECTORS     EQU     256     ; Maximum vectors (8KB / 32 bytes)
HASH_BITS       EQU     8       ; Bits for hash (256 buckets)
HYPERPLANES     EQU     8       ; Number of hyperplanes for hashing

; Memory layout
        ORG     #8000

; Vector database structure (32 bytes per vector)
vectors_db:
        DEFS    VECTOR_BYTES * MAX_VECTORS      ; Vector storage (8KB)

; Hash index (256 entries, each pointing to vector list)
hash_index:
        DEFS    256 * 2         ; 256 16-bit pointers

; Hyperplanes for hashing (8 hyperplanes × 32 bytes each)
hyperplanes:
        DEFS    HYPERPLANES * VECTOR_BYTES

; Working buffers
query_vector:
        DEFS    VECTOR_BYTES    ; Query vector buffer
temp_vector:
        DEFS    VECTOR_BYTES    ; Temporary vector buffer
result_scores:
        DEFS    MAX_VECTORS * 2 ; 16-bit scores for each vector

; Variables
vector_count:   DEFB    0       ; Current number of vectors (max 32)
best_score:     DEFW    0       ; Best score found
best_index:     DEFB    0       ; Index of best match

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
        XOR     A
        LD      (vector_count),A
        
        ; Clear hash index
        LD      HL,hash_index
        LD      DE,hash_index+1
        LD      BC,256*2-1
        LD      (HL),0
        LDIR
        
        ; Initialize random hyperplanes (simplified - would need proper random init)
        LD      HL,hyperplanes
        LD      BC,HYPERPLANES * VECTOR_BYTES
        LD      A,#55
.init_hyper:
        LD      (HL),A         ; Simple pattern for now
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.init_hyper
        
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
; HL = vector1, DE = vector2
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
        LD      A,(vector_count)
        CP      MAX_VECTORS
        JR      NC,.db_full
        
        ; Calculate destination address using << 5 (multiply by 32)
        ; Address = vectors_db + (vector_count << 5)
        LD      L,A
        LD      H,0
        ; Multiply by 32
        ADD     HL,HL          ; *2
        ADD     HL,HL          ; *4
        ADD     HL,HL          ; *8
        ADD     HL,HL          ; *16
        ADD     HL,HL          ; *32
        LD      DE,vectors_db
        ADD     HL,DE          ; HL = destination address
        EX      DE,HL          ; DE = destination address
        
        ; Copy vector (32 bytes)
        POP     HL             ; Source vector
        PUSH    HL
        LD      BC,VECTOR_BYTES
        LDIR
        
        ; Increment vector count
        LD      A,(vector_count)
        INC     A
        LD      (vector_count),A
        
.db_full:
        POP     HL
        RET


; Brute force search for nearest vector
; HL = query vector
; Returns: A = best index, BC = best score
bf_search:
        PUSH    HL
        
        ; Initialize best score to minimum
        LD      HL,#8000       ; -32768 (worst possible score)
        LD      (best_score),HL
        XOR     A
        LD      (best_index),A
        
        ; Check each vector
        LD      B,0            ; Vector index
.search_loop:
        PUSH    BC
        
        ; Check if we've searched all vectors
        LD      A,B
        LD      C,A
        LD      A,(vector_count)
        CP      C
        JR      Z,.search_done
        JR      C,.search_done
        
        ; Calculate vector address using << 5 (multiply by 32)
        ; Address = vectors_db + (index << 5)
        LD      A,C            ; A = vector index
        LD      L,A
        LD      H,0
        ; Multiply by 32
        ADD     HL,HL          ; *2
        ADD     HL,HL          ; *4
        ADD     HL,HL          ; *8
        ADD     HL,HL          ; *16
        ADD     HL,HL          ; *32
        LD      DE,vectors_db
        ADD     HL,DE          ; HL = vector address
        
        ; Calculate dot product
        POP     BC
        POP     DE             ; Get query vector from stack
        PUSH    DE             ; Put it back
        PUSH    BC
        PUSH    HL             ; Save current vector address
        EX      DE,HL          ; HL = query vector
        CALL    dot_product_1bit ; BC = score
        POP     HL             ; Restore vector address
        
        ; Compare with best score
        LD      HL,(best_score)
        OR      A
        SBC     HL,BC
        JR      NC,.not_better
        
        ; New best score
        LD      (best_score),BC
        POP     DE
        POP     BC
        LD      A,B
        LD      (best_index),A
        PUSH    BC
        JR      .next_vector
        
.not_better:
        POP     DE
.next_vector:
        POP     BC
        INC     B
        JR      .search_loop
        
.search_done:
        POP     BC
        POP     HL
        LD      A,(best_index)
        LD      BC,(best_score)
        RET

; Calculate hash for a vector using hyperplanes
; HL = vector pointer
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
        
        ; Negative - bit stays 0
        JR      .next_plane
        
.set_bit:
        ; Positive - set bit in hash
        POP     HL
        POP     BC
        LD      A,C
        SCF                    ; Set carry
        RLA                    ; Rotate left with carry
        LD      C,A
        PUSH    BC
        PUSH    HL
        
.next_plane:
        POP     HL
        POP     BC
        
        ; Move to next hyperplane
        LD      A,VECTOR_BYTES
        ADD     A,E
        LD      E,A
        JR      NC,.no_carry
        INC     D
.no_carry:
        
        ; Shift hash left for next bit
        LD      A,C
        SLA     A
        LD      C,A
        
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
        LD      BC,256*2-1
        LD      (HL),0
        LDIR
        
        ; Process each vector
        LD      C,0            ; Vector counter
.reindex_loop:
        ; Check if done
        LD      A,(vector_count)
        CP      C
        RET     Z              ; Done if C == vector_count
        RET     C              ; Done if C > vector_count
        
        ; Calculate vector address using << 5 (multiply by 32)
        ; Address = vectors_db + (C << 5)
        LD      L,C
        LD      H,0
        ; Multiply by 32
        ADD     HL,HL          ; *2
        ADD     HL,HL          ; *4
        ADD     HL,HL          ; *8
        ADD     HL,HL          ; *16
        ADD     HL,HL          ; *32
        LD      DE,vectors_db
        ADD     HL,DE          ; HL = vector address
        
        ; Calculate hash
        PUSH    BC
        CALL    calc_hash      ; A = hash
        POP     BC
        
        ; Add to hash bucket (simplified - just store first match)
        LD      L,A
        LD      H,0
        ADD     HL,HL          ; *2 for 16-bit entries
        LD      DE,hash_index
        ADD     HL,DE
        
        ; Store vector index if bucket empty
        LD      A,(HL)
        INC     HL
        OR      (HL)
        JR      NZ,.bucket_full
        
        DEC     HL
        LD      (HL),C         ; Store index low
        INC     HL
        LD      (HL),0         ; Store index high (always 0 since max 256 vectors)
        
.bucket_full:
        INC     C
        JR      .reindex_loop

        END     main