# zvdb-z80

Minimal Z80 assembly implementation of [ZVDB (ABAP Vector Database)](https://github.com/oisee/zvdb) for multiple platforms including ZX Spectrum, CP/M systems, and even programmable calculators!

✨ **NEW**: CP/M version, UI demos, and world's smallest vector database (36 calculator steps!) - see [CHANGELOG.md](CHANGELOG.md)

## Quick Start

```bash
# Build everything
make clean && make

# Run on ZX Spectrum emulator
fuse build/zvdb_ui.sna

# Run on CP/M system
cpm build/zvdb_cpm.com
```

## But Why???

   **[ZVDB-Z80-ABAP.md](ZVDB-Z80-ABAP.md)**
   
   📰 **Press Coverage**: [The Register - "From mainframes to 8-bit microcomputers: Porting an ABAP database to the ZX Spectrum"](https://www.theregister.com/2025/07/08/sap_abap_db_spectrum_port/)

## Available Versions

### 🖥️ ZX Spectrum Versions
- **Basic**: 256 vectors, standard 128K memory
- **Paged**: 896 vectors, uses extended memory  
- **Compact**: 7,168 vectors, optimized storage
- **UI Demo**: Interactive graphical interface with plasma effects

### 💾 CP/M Version (NEW!)
- Works on Amstrad CPC, PCW, and other CP/M systems
- ANSI terminal UI with vector visualization
- Interactive selection and search
- See [Issue #1](https://github.com/oisee/zvdb-z80/issues/1)

### 🧮 Sinclair Cambridge Programmable (NEW!)
- World's smallest vector database - just 36 steps!
- Up to 9 vectors using calculator registers
- See `zvdb_cambridge.txt`

## Core Features

- **1-bit quantization**: Each vector component is quantized to 1 bit (positive/negative)
- **256-bit vectors**: Optimized for Scorpion's 256-bit architecture (32 bytes per vector)
- **Compact storage**: Vectors stored at 32-byte intervals using shift-by-5 addressing
- **Brute-force search**: Find nearest vector by computing dot products
- **Random hyperplane hashing**: 8-bit hash for fast approximate search
- **Reindexing**: Rebuild hash index for all vectors

## Implementation Details

### Vector Representation
- Each vector is 256 bits (32 bytes)
- Bit value: 0 = positive component, 1 = negative component
- Vectors stored at 32-byte intervals (address = base + index << 5)
- Maximum 256 vectors in database (8KB total)

### Core Operations

1. **1-bit Dot Product**
   - XOR two vectors byte by byte
   - Count total differing bits (Hamming distance)
   - Similarity = 256 - 2 × Hamming distance
   - Range: -256 to +256

2. **Brute-Force Search**
   - Computes dot product with all vectors
   - Returns index and score of best match

3. **Hash Calculation**
   - Uses 8 hyperplanes (256-bit each)
   - Dot product with each hyperplane determines hash bit
   - Results in 8-bit hash (256 buckets)

4. **Reindex**
   - Recalculates hashes for all vectors
   - Updates hash index for faster search

### Memory Layout

| Address | Size | Description |
|---------|------|-------------|
| #8000 | 8KB | Vector database (256 × 32 bytes) |
| #A000 | 512B | Hash index (256 × 2 bytes) |
| #A200 | 256B | Hyperplanes (8 × 32 bytes) |
| #A300 | 256B | Popcount lookup table |

### Address Calculation by << 5

- **Fast addressing**: Vector address = `#8000 + (index << 5)`
- **5 shift operations**: ADD HL,HL five times for ×32
- **8× more vectors**: Store 256 vectors vs 32 with page alignment
- **Efficient**: Only 11 cycles for address calculation

### Performance

- Bit counting: O(1) using lookup table
- 1-bit dot product: 32 iterations (one per byte)
- Brute-force search: O(n) where n = number of vectors
- Hash calculation: 8 dot products

## Building

Requires [sjasmplus](https://github.com/z00m128/sjasmplus) assembler:

```bash
make clean
make
```

This creates the following files in the `build/` directory:
- `zvdb_test.sna` - Basic version test
- `zvdb_paged_test.sna` - Paged memory version test
- `zvdb_compact_test.sna` - Compact version test
- `zvdb_ui.sna` - Interactive UI demo (NEW!)
- `zvdb_cpm.com` - CP/M executable (NEW!)

**Note**: There are currently some duplicate label issues with the assembly files. Pre-built binaries are available in the `build/` directory:
- `zvdb_test.tap` - TAP file for loading in ZX Spectrum emulators
- `test_runner.bin` - Binary test runner
- `zvdb_code.bin` - Core ZVDB implementation binary

## Running the Code

### Option 1: Using a ZX Spectrum Emulator

1. **Install an emulator** (choose one):
   - [Fuse](http://fuse-emulator.sourceforge.net/) - Cross-platform, accurate emulation
   - [ZEsarUX](https://github.com/chernandezba/zesarux) - Multi-machine emulator with debugging
   - [Speccy](https://fms.komkon.org/Speccy/) - Windows/Android emulator
   - [Retro Virtual Machine](http://www.retrovirtualmachine.org/) - macOS focused

2. **Load the program**:
   - Open your emulator
   - Load `build/zvdb_test.tap` file (File → Open or drag and drop)
   - The program will auto-run after loading

3. **What you'll see**:
   - "ZVDB-Z80 Test Program" header
   - "Added 3 test vectors" - confirms vector addition
   - "Database reindexed" - hash index rebuilt
   - "Nearest vector: #XX Score: #XXXX" - search result
   - "Test complete" - program finished

### Option 2: Using Online Emulators

1. Visit [JSSpeccy](https://jsspeccy.zxdemo.org/) or [Qaop/JS](http://torinak.com/qaop/en)
2. Upload the `build/zvdb_test.tap` file
3. The program will run automatically

### Option 3: Running on Real Hardware

If you have a real ZX Spectrum or Scorpion:
1. Transfer `build/zvdb_test.tap` to the machine via:
   - Audio loading from WAV file
   - DivIDE/DivMMC interface
   - Other modern storage solutions
2. LOAD "" and the program will execute

## Usage

The test program demonstrates:
1. Initializing the database
2. Adding test vectors
3. Reindexing
4. Searching for nearest vector

### API Functions

- `init_db` - Initialize database (clear vectors, reset count)
- `add_vector` - Add vector at HL to database, returns index in A
- `bf_search` - Search for vector at HL, returns index in A and score in BC
- `calc_hash` - Calculate hash for vector at HL, returns hash in A
- `reindex` - Rebuild hash index for all vectors

### Memory Requirements

- 8KB for vector storage (#8000-#9FFF)
- 512 bytes for hash index (#A000-#A1FF)
- 512 bytes for hyperplanes and lookup table (#A200-#A3FF)

## Future Enhancements

- Multi-level hashing (HR2, HH1, HH2)
- Hamming distance search in hash space
- Vector deletion/update
- Persistent storage
- Larger vector support (512, 1024 bits)

## Extreme Minimalism: Sinclair Cambridge Programmable

The ultimate minimalist implementation - ZVDB in just 36 calculator steps:

- **1 vector = 1 number** (8 bits packed as decimal 0-255)
- **Maximum 9 vectors** (limited by calculator registers)
- **Search = subtraction + find minimum**
- **Complete program: 36 steps!**

This is probably the world's smallest vector database implementation. See `zvdb_cambridge.txt` for the complete program.

## Interactive Demos

### 🎨 ZX Spectrum UI Demo (`zvdb_ui.sna`)
- **Visual Interface**: Vectors displayed as 8x8 bit patterns
- **Navigation**: Use cursor keys to browse, Enter to search
- **Effects**: Animated plasma effect and smooth scrolling text
- **Music Ready**: PT3 player stub included for ProTracker music
- **Greetings**: Classic demoscene-style scrolling message

### 🖥️ CP/M Terminal UI (`zvdb_cpm.com`)
- **ANSI Graphics**: Works on any CP/M system with ANSI terminal
- **ASCII Sprites**: Vectors shown as 8x8 ASCII art patterns
- **Controls**: W/S or J/K to navigate, Enter to search, Q to quit
- **Compatibility**: Tested for Amstrad CPC and PCW systems
- **Memory Efficient**: Fits within CP/M TPA constraints

## License

MIT