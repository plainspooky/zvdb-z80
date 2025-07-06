# zvdb-z80 Paged Memory Version

Extended implementation supporting 256KB RAM using the Scorpion's memory paging system.

## Features

- **896 vectors capacity**: 14 pages × 64 vectors per page
- **Automatic page switching**: Transparent access to vectors across pages
- **256-byte alignment**: Maintained for fast addressing within pages
- **Full 256KB utilization**: Uses pages 0-13 for vector storage

## Memory Organization

### Page Layout

| Page | Address Range | Usage |
|------|--------------|-------|
| 0-13 | #C000-#FFFF | Vector storage (896 vectors total) |
| 14-15 | Reserved | System/screen |
| Work | #8000-#BFFF | Hash index, buffers, code |

### Working Page (#8000-#BFFF) Layout

| Offset | Size | Description |
|--------|------|-------------|
| #0000 | 1KB | Hash index (256 × 4 bytes) |
| #0400 | 256B | Hyperplanes (8 × 32 bytes) |
| #0500 | 64B | Query/temp vectors |
| #0540 | 1.8KB | Vector index table |
| #0D00 | 256B | Popcount lookup table |
| #0E00+ | ~10KB | Code and variables |

### Vector Storage

- Each page holds 64 vectors (16KB / 256 bytes)
- Vector address calculation:
  - Page = index / 64
  - Offset = (index & 63) × 256
- Pages 0-13 used for vectors (14 × 64 = 896 vectors)

## Page Switching

The implementation handles page switching automatically:

```z80
; Switch to page containing vector
; HL = vector index (0-895)
switch_vector_page:
    ; Calculate page (index / 64)
    ; Map page to #C000-#FFFF
    ; Return pointer to vector
```

## Enhanced Hash Index

Each hash bucket now stores:
- **Index** (2 bytes): Vector index (0-895)
- **Count** (1 byte): Number of entries in bucket
- **Next** (1 byte): Pointer to overflow chain

## Performance Considerations

### Page Switch Overhead
- Page switches cached to avoid redundant operations
- Sequential access patterns minimize switches
- Batch operations on same page when possible

### Search Optimization
- Hash search checks page-local candidates first
- Brute-force search processes vectors page by page
- Working buffers avoid repeated page switches

## API Functions

### Core Operations

```z80
; Add vector (auto-assigns to next available slot)
; HL = source vector pointer
add_vector:
    ; Automatically handles page selection
    ; Updates vector index table

; Brute-force search across all pages
; HL = query vector
; Returns: DE = best index, BC = score
bf_search:
    ; Searches all 896 vectors
    ; Handles page switching internally

; Hash-based search
; HL = query vector
; Returns: DE = match index, BC = score
hash_search:
    ; Fast approximate search
    ; Returns first hash match
```

### Utility Functions

```z80
; Copy vector from any page to buffer
; HL = vector index, DE = destination
copy_vector_to_buffer:

; Switch to page containing vector
; HL = vector index
; Returns: HL = vector pointer at #C000
switch_vector_page:
```

## Building

Requires sjasmplus with 128K support:

```bash
make test_paged.asm
```

Creates `zvdb_paged_test.sna` for 256KB Scorpion emulators.

## Usage Example

```z80
; Initialize database
CALL init_db

; Add vectors (up to 896)
LD   B,100        ; Add 100 vectors
.loop:
    LD   HL,vector_data
    CALL add_vector
    DJNZ .loop

; Reindex for hash search
CALL reindex

; Search for nearest
LD   HL,query_vector
CALL bf_search    ; Full search
; or
CALL hash_search  ; Fast approximate
```

## Limitations

- Maximum 896 vectors (architectural limit)
- Page switches add ~20 T-states overhead
- Hash collisions not fully handled (simplified)
- No vector deletion implemented

## Future Enhancements

- Full hash collision handling with chains
- Multi-probe hash search
- Vector deletion and defragmentation
- Compressed vector storage (2-bit, 4-bit)
- DMA support for faster page copies