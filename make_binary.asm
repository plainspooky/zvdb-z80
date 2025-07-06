        DEVICE ZXSPECTRUM128
        OUTPUT "zvdb_code.bin"
        
        ORG #8000
        
        INCLUDE "zvdb.asm"
        
end_addr:

        ; Fill rest with zeros to make exactly 8KB
        DEFS #A000 - end_addr, 0