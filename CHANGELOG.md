# Changelog

All notable changes to ZVDB-Z80 will be documented in this file.

## [Unreleased] - 2025-08-09

### Added
- **MSX** version (`zvdb_msx.asm`) for MSX machines running MSX-DOS
  - Runs in any MSX2, MSX2+ ou MSX turbo R computers
  - Also runs in MSX with 80 columns card installed
  - Same features of CP/M version (sprites, scroller and box drawing chars) and memory constraints as well. 
  - Interactive vector selection using arrow keys
  - Builds to standard MSX-DOS executable (.COM)

## [Unreleased] - 2025-07-10

### Added
- **CP/M version** (`zvdb_cpm.asm`) for Amstrad CPC and other CP/M systems
  - ANSI terminal-based UI with box drawing characters
  - Interactive vector selection with W/S or J/K keys
  - Visual representation of vectors as 8x8 ASCII "sprites"
  - Scrolling greetings text at bottom of screen
  - Full vector search functionality within CP/M memory constraints
  - Builds to standard .COM executable

- **ZX Spectrum UI Demo** (`zvdb_ui.asm`) with graphical interface
  - Visual display of vectors as 8x8 bit patterns
  - Cursor key navigation with visual highlighting
  - Plasma effect using attribute cycling
  - Smooth horizontal text scroller with greetings
  - Real-time vector search with result display
  - Ready for PT3 music integration

- **Sinclair Cambridge Programmable Calculator** implementation
  - World's smallest vector database in just 36 calculator steps!
  - Stores up to 9 vectors (one per calculator register)
  - Each vector packed as single decimal number (0-255)
  - Search using simple subtraction and minimum finding
  - See `zvdb_cambridge.txt` for complete program

- **PT3 Music Player Stub** (`pt3player_stub.asm`)
  - Framework for integrating ProTracker 3 music
  - Basic AY-3-8912 register control
  - Ready for integration with full PT3 player
  - Selected track: "216 cycles of moon" by oisee/4d (2000)

- **MIT License** file added to repository

### Changed
- Updated Makefile to include new build targets
- Enhanced README with new version information
- Added visual UI elements to demonstrate vector data

### Technical Details
- Both UI versions display first 8 bytes of each 32-byte vector as 8x8 bit patterns
- Interactive selection allows browsing through vector database
- Search functionality finds nearest neighbor using Hamming distance
- CP/M version uses ANSI escape sequences for terminal control
- ZX Spectrum version uses native graphics and attribute manipulation

## [0.1.0] - 2024-07-09

### Initial Release
- Basic ZVDB implementation for ZX Spectrum 128K
- Support for 256-bit vectors with 1-bit quantization
- Brute-force nearest neighbor search
- Random hyperplane indexing with 8-bit hash
- Three variants:
  - Basic version: 256 vectors maximum
  - Paged version: 896 vectors using extended memory
  - Compact version: 7,168 vectors with optimized storage
- Popcount lookup table for fast bit counting
- Test programs for all variants
