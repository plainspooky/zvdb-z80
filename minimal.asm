        DEVICE ZXSPECTRUM128
        
        ORG #8000
start:
        LD A,#42
        HALT
        
        SAVESNA "minimal.sna", start