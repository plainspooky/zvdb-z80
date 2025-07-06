; Combined test with ZVDB
        DEVICE ZXSPECTRUM128
        OUTPUT "zvdb_combined.bin"
        
        ORG #6000
        
        JP start
        
        ; Include test runner
        INCBIN "test_runner.bin"
        
        ; ZVDB code at #8000
        ORG #8000
        INCBIN "zvdb_code.bin",0,#840   ; Just the code part (2112 bytes)
        
        ; Create TAP file for loading
        EMPTYTAP "zvdb_test.tap"
        SAVETAP "zvdb_test.tap", BASIC, "zvdbtest", start, 100, 1
        SAVETAP "zvdb_test.tap", CODE, "zvdb", #6000, #4000
        
start   EQU #6000