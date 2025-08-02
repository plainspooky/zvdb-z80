# CP/M Testing Guide

This guide explains how to test the CP/M version of ZVDB-Z80 using RunCPM emulator.

## Directory Structure
- `A/0/` - CP/M drive A: user area 0
- `A/0/ZVDB_CPM.COM` - The ZVDB CP/M executable

## Setting up RunCPM

1. Clone and build RunCPM:
   ```bash
   git clone https://github.com/MockbaTheBorg/RunCPM.git
   cd RunCPM/RunCPM
   make -f Makefile.posix
   cd ../..
   ```

2. The CP/M disk structure is already set up in the `A/` directory.

## Running ZVDB-Z80 CP/M Version

1. Start the emulator:
   ```bash
   ./RunCPM/RunCPM
   ```

2. At the CP/M prompt, run:
   ```
   A0>ZVDB_CPM
   ```

3. The program will display an ANSI terminal UI with:
   - Vector list (initially empty)
   - Plasma effect animation
   - Scrolling greetings message

4. Controls:
   - **W/S** or **J/K** - Navigate up/down through vectors
   - **Enter** - Search for similar vectors to the selected one
   - **Q** - Quit back to CP/M

## Requirements
- ANSI terminal support (most modern terminals)
- RunCPM emulator (or real CP/M system)
- The .COM file must be in uppercase for CP/M compatibility

## Tested With
- RunCPM v6.7
- Linux terminal with ANSI support