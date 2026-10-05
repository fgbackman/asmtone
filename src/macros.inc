// macros.inc — shared assembler macros for asmtone (ARM64).
//
// The app is built for macOS (Mach-O). The modem files (fec.s, dsp.s, modem.s,
// selftest.s) also assemble as ELF when LINUX is defined, so the DSP can be tested
// natively on any ARM64 Linux box:  as --defsym LINUX=1
//
// Frame layout used by every non-leaf function (ENTER/LEAVE):
//   sp + 0   .. 31   : outgoing variadic-argument slots (Apple ABI puts them on the stack)
//   sp + 32  .. 47   : saved x29, x30          (x29 points here)
//   sp + 48  .. 95   : saved x19 .. x24
//   sp + 96  ..      : locals (\locals bytes, multiple of 16)
//
// d8..d15 are callee-saved; functions that use them save them in their locals.

.macro ENTER locals
    sub  sp, sp, #(96 + \locals)
    stp  x29, x30, [sp, #32]
    add  x29, sp, #32
    stp  x19, x20, [sp, #48]
    stp  x21, x22, [sp, #64]
    stp  x23, x24, [sp, #80]
.endm

.macro LEAVE locals
    ldp  x19, x20, [sp, #48]
    ldp  x21, x22, [sp, #64]
    ldp  x23, x24, [sp, #80]
    ldp  x29, x30, [sp, #32]
    add  sp, sp, #(96 + \locals)
    ret
.endm

.ifdef LINUX
.macro ADRL reg, sym
    adrp \reg, \sym
    add  \reg, \reg, :lo12:\sym
.endm
.macro LDS sreg, sym
    adrp x16, \sym
    ldr  \sreg, [x16, :lo12:\sym]
.endm
.macro LDD dreg, sym
    adrp x16, \sym
    ldr  \dreg, [x16, :lo12:\sym]
.endm
.macro CALLC fn
    bl   \fn
.endm
.macro RODATA
    .section .rodata
.endm
.else
.macro ADRL reg, sym
    adrp \reg, \sym@PAGE
    add  \reg, \reg, \sym@PAGEOFF
.endm
.macro LDS sreg, sym
    adrp x16, \sym@PAGE
    ldr  \sreg, [x16, \sym@PAGEOFF]
.endm
.macro LDD dreg, sym
    adrp x16, \sym@PAGE
    ldr  \dreg, [x16, \sym@PAGEOFF]
.endm
.macro CALLC fn
    bl   _\fn
.endm
.macro RODATA
    .section __TEXT,__const
.endm
// address of an external (dylib/framework) data symbol, via the GOT
.macro LDGOT reg, sym
    adrp \reg, \sym@GOTPAGE
    ldr  \reg, [\reg, \sym@GOTPAGEOFF]
.endm
.endif

// ---------------------------------------------------------------------------
// Objective-C shortcuts (Mac only)
// ---------------------------------------------------------------------------
.macro CLS namesym
    ADRL x0, \namesym
    bl   _objc_getClass
.endm
.macro MSG0 selsym
    ADRL x1, \selsym
    bl   _msg0
.endm
.macro MSG1 selsym
    ADRL x1, \selsym
    bl   _msg1
.endm
.macro MSG2 selsym
    ADRL x1, \selsym
    bl   _msg2
.endm
.macro MSG3 selsym
    ADRL x1, \selsym
    bl   _msg3
.endm
.macro MSG4 selsym
    ADRL x1, \selsym
    bl   _msg4
.endm
// register a selector by name into x1 (clobbers x0)
.macro SELX1 selsym
    ADRL x0, \selsym
    bl   _sel_registerName
    mov  x1, x0
.endm

// ---------------------------------------------------------------------------
// The modem
// ---------------------------------------------------------------------------
.set SR,          48000
.set NMODES,      5
.set MODE_PIANO,  0
.set MODE_CHIRP,  1
.set MODE_FAST,   2
.set MODE_SILENT, 3
.set MODE_DUET,   4
.set NPRE,        8          // preamble symbols
.set LEAD,        14400      // 300 ms of silence before a message: speakers fade in when sound starts
.set PLEN,        11520      // how long a piano note rings (240 ms)
.set RING,        8192       // receive ring (stored twice, so any window is contiguous)
.set HIST,        128        // hops of history per mode

// mode table (_modes): 512 bytes per mode
.set M_NT,        0          // tones in the filter bank (a multiple of 16, at most 128)
.set M_NG,        4          // tone groups sounding at once (1 or 4); each carries a nibble
.set M_S,         8          // samples per symbol
.set M_W,         12         // samples in the detection window
.set M_HOP,       16         // samples between detections (S / 8)
.set M_K,         20         // hops per symbol (8)
.set M_NR,        24         // Reed–Solomon parity bytes
.set M_WIN,       28         // 1: Hann window (notes off the FFT grid)
.set M_QMIN,      32         // float: how clean a preamble symbol must be
.set M_VOICE,     36         // 0 piano, 1 chirp, 2 fast, 3 silent
.set M_AMP,       40         // float
.set M_TAIL,      44         // samples after the last symbol
.set M_HARM,      48         // 3: score each note with its 2nd and 3rd harmonics (rows 2 and 3)
.set M_NV,        52         // tones each group can play (16 + M_KEX)
.set M_KEX,       56         // tones left out because they're still echoing (the last KEX played)
.set M_BPS,       60         // bits each symbol carries
.set M_PAIR,      64         // 1: two notes at once (Piano's two hands): 6 bits a beat
.set M_QLOW,      68         // float: a symbol this unclear counts as silence (sender gone)
.set M_PRE,       72         // 8 bytes: the preamble's tones
.set M_FREQ,      80         // up to 108 floats: group g's tone v is M_FREQ[g * NV + v]
.set MODE_SHIFT,  9

// receiver state (_rx): 4096 bytes per mode
.set R_NEXT,      0          // u64: sample count of the next detection
.set R_HOPN,      8          // u64: detections so far
.set R_STATE,     16         // 0 hunting, 1 aligning, 2 receiving
.set R_NIB,       20         // bits received
.set R_CAND,      24         // u64: chosen alignment (a hop number)
.set R_NEED,      36         // bits the frame needs (0 until the header is in)
.set R_DHOP,      40         // u64: hop of the next data symbol
.set R_H0,        48         // u64: first hop of the aligning stretch
.set R_LEN,       56         // payload length from the header
.set R_QSUM,      60         // float: summed quality while receiving
.set R_COEF,      64         // 128 floats: Goertzel coefficients
.set R_HBEST,     576        // HIST x 4 bytes: best tone per group, per hop
.set R_HQ,        1088       // HIST floats: quality per hop
.set R_NIBS,      1600       // 544 bytes: the bits, packed, high bit first
.set R_ENER,      2144       // 128 floats
.set R_BYTES,     2656       // 272 bytes
.set R_RSC,       2944       // 16 floats: alignment scores
.set R_STATS,     3008       // u64 x 4: ok, repaired, lost, length unreadable
.set R_LOWQ,      3040       // symbols in a row that were barely there
.set R_THIST,     3048       // 4 groups x 8 bytes: the last 8 tones each group played
.set RX_SHIFT,    12
