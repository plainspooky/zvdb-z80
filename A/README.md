# CP/M Disk Structure for Testing

This directory contains the CP/M disk structure for testing zvdb_cpm.com with RunCPM emulator.

## Structure
- `A/0/` - CP/M drive A: user area 0
- `A/0/ZVDB_CPM.COM` - The ZVDB CP/M executable

## Testing with RunCPM

1. Build RunCPM (if not already built):
   ```bash
   git clone https://github.com/MockbaTheBorg/RunCPM.git
   cd RunCPM/RunCPM
   make -f Makefile.posix
   cd ../..
   ```

2. Run the emulator:
   ```bash
   ./RunCPM/RunCPM
   ```

3. In the CP/M prompt, run:
   ```
   A0>ZVDB_CPM
   ```

4. Use the following keys:
   - W/S or J/K - Navigate up/down
   - Enter - Search for similar vectors
   - Q - Quit to CP/M

## Notes
- The program requires ANSI terminal support
- Tested with RunCPM v6.7
- The .COM file must be in uppercase for CP/M compatibility