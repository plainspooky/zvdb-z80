        DEVICE ZXSPECTRUM128
        
        ORG #6000

start:
        DI
        LD SP,#5FFF
        
        ; Initialize ZVDB
        CALL #8000
        
        ; Test adding vectors
        LD B,10
        LD HL,testvec
loop:   
        PUSH BC
        LD A,B
        LD (HL),A
        CALL #8000 + add_vector - main
        POP BC
        DJNZ loop
        
        ; Search
        LD HL,testvec
        CALL #8000 + bf_search - main
        
        HALT

testvec:
        DEFS 32,#AA
        
        ORG #8000
main:
        INCLUDE "zvdb.asm"

        ; Generate output file
        OUTPUT "zvdb_test.bin"
        
        ; Include all code from #6000 to current
        ORG #6000
        INCBIN "zvdb_test.bin"
        
        ; Also try snapshot
        SAVESNA "zvdb_snapshot.sna", start