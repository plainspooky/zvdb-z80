# I Ported SAP* to a 1976 CPU. It Wasn't That Slow.

*Or: I built a vector database for SAP, then ported it to a 1976 processor—for ~~scien...~~ fun!*

**TL;DR:** [github/oisee/zvdb-z80](https://github.com/oisee/zvdb-z80)

## When Two Retro Technologies Meet

Last month, I was cleaning up old code and rediscovered ZVDB—a vector database I'd built in ABAP about a year and a half ago. Looking at it again, I had a realization that made me smile.

ABAP (born 1983) and ZX Spectrum 48k (born 1982) are practically contemporaries. They grew up in the same era of computing—when memory was precious, cycles were counted, and every byte mattered. No wonder they understand each other so well.

My ZVDB wasn't just written in ABAP. It was ABAP written with 40 years of Z80 wisdom.

## The Kindred Spirits

When SAP created ABAP in 1983, the Z80 was already powering millions of computers worldwide. Both were born from the same constraints:

- Limited memory (64KB was luxury)
- Expensive CPU cycles (measure twice, compute once)
- No floating point (integers or go home)
- Direct hardware access (abstractions are for the future)

When I built ZVDB, I deliberately applied every Z80 optimization I knew. Why? Because these "old" techniques are timeless—they just happen to make modern code blazingly fast**:

```abap
METHOD dp_1536. "dot product for 1536-bit vectors
  DATA(d) = ix_0 BIT-XOR ix_1.
  " Straight from the Z80 playbook: unrolled loops, lookup tables
  rv_ = rv_ + g[ d+01(2) + 1 ] + g[ d+02(2) + 1 ] + g[ d+03(2) + 1 ]...
  " 96 lookups because memory access beats arithmetic - Z80 taught me this
ENDMETHOD.
```

## Z80 Wisdom Applied to ABAP

Every "trick" in ZVDB came from my Z80 experience:

```abap
" Pre-compute everything - classic Z80 optimization
METHOD init_signed_counter_tab_16bit.
  DO 65536 TIMES.
    " Build 64KB lookup table - because Z80 taught me:
    " one memory read beats eight bit tests
    lx_ = sy-index - 1.
    " ... bit counting logic ...
    APPEND lv_v TO rt_.
  ENDDO.
ENDMETHOD.
```

This wasn't ABAP trying to be clever. It was more like embedded programming habits quietly guiding the design.

## The Proof: It Actually IS Z80 Code

When I ported ZVDB to actual Z80 assembly, I barely had to change anything. Because it was already thinking in Z80:

```asm
; This isn't a port – it's a homecoming
compare_vectors:
    LD B, 192       ; Process 192 bytes
    LD C, 0         ; Popcount accumulator = 0
    
next_byte:
    LD A, (DE)      ; Load byte from Vector B
    XOR (HL)        ; XOR with Vector A

    ; Popcount via lookup table
    LD H, HIGH popcount_table
    LD L, A
    LD A, (HL)      ; Get number of 1s
    ADD A, C
    LD C, A         ; Accumulate result

    INC HL          ; Next byte
    INC DE
    DJNZ next_byte

    RET             ; Result now in C
```

## The Numbers That Vindicate Old-School Thinking

- **ZVDB on SAP**: 10-20ms (Z80 algorithms on modern hardware)
- **ZVDB on Z80**: 50-60ms (Z80 algorithms on Z80 hardware)

Only 3-6x slower despite 857x clock speed difference? That's not surprising—these optimizations were born for the Z80. They just happen to be universally optimal.

## Why Z80 Thinking Still Wins in 2025

Every Z80 lesson I applied to ABAP remains valid on modern hardware:

1. **Lookup tables are always faster than calculation**
   - Z80: Save those precious cycles
   - Modern CPU: Cache-friendly access patterns

2. **Sequential memory access is king**
   - Z80: One cycle vs four for random access
   - HANA: Columnar storage loves sequential patterns

3. **Bit operations are universal**
   - Z80: Native CPU instructions
   - Modern CPU: SIMD does the same thing, faster

4. **Pre-computation beats runtime math**
   - Z80: Can't afford to calculate
   - Modern systems: Why calculate what you can remember?

## The Beautiful Truth

In 2025, I'm using 1983 technology (ABAP) with 1976 optimizations (Z80) to solve 2020s problems (vector search). And it works surprisingly well, thanks to lessons that stuck with me from low-level programming days. ^_^

Those years with Z80 assembly weren't just nostalgic—they shaped how I think about performance today. Every cycle counted then, and guess what? Every cycle still counts now. The scale changed. The principles didn't.

When I port this to HANA AMDP, it'll be even faster. And I expect AMDP will parallelise those same Z80-flavoured optimisations even further. But the core insight—lookup beats calculation, sequential beats random—that came from 1976.

## The Real Lesson

Sometimes, the best optimisations come not from new tools, but from understanding the fundamentals—the metal underneath —whether that metal is from 1976 or 2025.

Z80 taught me how computers actually think. 40 years later, they still think the same way—just faster.

---

*Alice Vinogradova is a Senior Software Engineer at Microsoft who deliberately writes ABAP like it's Z80 assembly—because those optimizations are timeless. Her ZX Spectrum-compatible machine proves she was right all along.*

**SAP\*** - Ported not SAP itself, but ZVDB of course!

**Blazingly Fast\*\*** - in some specific cases. As pointed out by other colleagues, what works on z80 might not translate to the speed-up in modern low-level languages, close to CPU, but it will still give advantage on VM and in ABAP VM in particular.

**P.S.** Let me know if you want version for CP/M? (or Yamaha MSX?) or... Altair? @Scott Hanselman
**N.B.** CP/M version has beed added.
