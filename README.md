# zvdb-z80

Minimal Z80 assembly implementation of ZVDB (Zero-Vector Database) for Scorpion ZS-256-Turbo+ clone.

## Features

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

Requires sjasmplus assembler:

```bash
make
```

This creates `zvdb_test.sna` snapshot file for Scorpion emulator.

## Usage

The test program demonstrates:
1. Initializing the database
2. Adding test vectors
3. Reindexing
4. Searching for nearest vector

## Future Enhancements

- Multi-level hashing (HR2, HH1, HH2)
- Hamming distance search in hash space
- Vector deletion/update
- Persistent storage
- Larger vector support (512, 1024 bits)