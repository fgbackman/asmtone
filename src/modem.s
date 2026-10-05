// modem.s — asmtone's sound modem: four voices, one receiver that listens for all of them.
//
// A message on the air (each symbol is one note, or four tones at once in Fast):
//
//   100 ms silence
//   preamble   8 symbols rising: tone 0 2 4 5 7 9 10 12 (on the piano: D4 G4 C5 D5 G5 C6 D6 G6)
//   header     the payload length L, three times (6 nibbles), decided by majority
//   body       payload + CRC-16 + Reed–Solomon parity, whitened, high nibble first
//   (piano only) a closing chord nobody decodes
//
// The sink hears every outcome: len >= 0 a message (fixed = bytes repaired), -1 a message
// too damaged to repair, -2 a preamble whose length couldn't be read.
//
//            tones            symbol   window   parity   a tone rests   speed
//   Piano    22 notes         150 ms   85 ms    12       6 symbols      ~3 characters/s
//   Chirp    24, 4-8.3 kHz     36 ms   21 ms    16       8              ~14 characters/s
//   Fast     4 x 22 at once    40 ms   21 ms    20       6              ~50 characters/s
//   Silent   22, 17.6-19.6 kHz 40 ms   21 ms    16       6              ~12 characters/s
//
// (A wrong tone also upsets the next few symbols, whose ranks are counted around it, so
// every mode carries more parity than a clean channel would need.)
//
// Rooms echo. A few feet away most of what a microphone hears is the room still ringing with
// the last few tones, so a tone isn't played again until it has rested for M_KEX symbols, and
// the receiver ignores those tones when it picks the next one: each symbol's nibble is the
// rank of its tone among the tones allowed at that moment (both ends keep the same history,
// starting from the preamble).
//
// Piano notes are judged with their 2nd and 3rd harmonics added in (half weight): small
// speakers and echoes can bury a note's fundamental, and the octave or fifth above it is
// another note of the scale.
//
// The receiver runs a Goertzel bank for every mode every 1/8 symbol, keeps which tone
// won and how clearly, and watches for the preamble. Once it sees one it settles on
// the middle of the best-sounding alignment and reads one symbol every 8 hops.

.include "macros.inc"

RODATA
.p2align 4
.globl _modes
_modes:
// ---- Piano: G major pentatonic, D4 .. E8 (22 notes; a note waits 6 notes before it plays again) ----
    .word 80, 1, 7200, 4096, 900, 8, 12, 1
    .float 0.30
    .word 0
    .float 0.30
    .word 14400
    .word 3, 22, 6, 0
    .float 293.6600, 329.6300, 392.0000, 440.0000, 523.2500, 587.3300, 659.2600, 783.9900
    .float 880.0000, 1046.5000, 1174.6600, 1318.5100, 1567.9800, 1760.0000, 2093.0000, 2349.3200
    .float 2637.0200, 3135.9600, 3520.0000, 4186.0100, 4698.6300, 5274.0400, 587.3200, 659.2600
    .float 784.0000, 880.0000, 1046.5000, 1174.6600, 1318.5200, 1567.9800, 1760.0000, 2093.0000
    .float 2349.3200, 2637.0200, 3135.9600, 3520.0000, 4186.0000, 4698.6400, 5274.0400, 6271.9200
    .float 7040.0000, 8372.0200, 9397.2600, 10548.0800, 880.9800, 988.8900, 1176.0000, 1320.0000
    .float 1569.7500, 1761.9900, 1977.7800, 2351.9700, 2640.0000, 3139.5000, 3523.9800, 3955.5300
    .float 4703.9400, 5280.0000, 6279.0000, 7047.9600, 7911.0600, 9407.8800, 10560.0000, 12558.0300
    .float 14095.8900, 15822.1200, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000
    .float 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000
    .space 128
// ---- Chirp: 24 tones on the 1024-point grid, 4.0 - 8.3 kHz, each sliding up into place ----
    .word 32, 1, 1728, 1024, 216, 8, 16, 0
    .float 0.45
    .word 1
    .float 0.50
    .word 4800
    .word 1, 24, 8, 0
    .float 4031.2500, 4218.7500, 4406.2500, 4593.7500, 4781.2500, 4968.7500, 5156.2500, 5343.7500
    .float 5531.2500, 5718.7500, 5906.2500, 6093.7500, 6281.2500, 6468.7500, 6656.2500, 6843.7500
    .float 7031.2500, 7218.7500, 7406.2500, 7593.7500, 7781.2500, 7968.7500, 8156.2500, 8343.7500
    .float 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000
    .space 320
// ---- Fast: four groups of 22, interleaved on the grid (bin 32 + 4v + g), 1.5 - 5.6 kHz ----
    .word 96, 4, 1920, 1024, 240, 8, 20, 0
    .float 0.35
    .word 2
    .float 0.22
    .word 4800
    .word 1, 22, 6, 0
    .float 1500.0000, 1687.5000, 1875.0000, 2062.5000, 2250.0000, 2437.5000, 2625.0000, 2812.5000
    .float 3000.0000, 3187.5000, 3375.0000, 3562.5000, 3750.0000, 3937.5000, 4125.0000, 4312.5000
    .float 4500.0000, 4687.5000, 4875.0000, 5062.5000, 5250.0000, 5437.5000, 1546.8750, 1734.3750
    .float 1921.8750, 2109.3750, 2296.8750, 2484.3750, 2671.8750, 2859.3750, 3046.8750, 3234.3750
    .float 3421.8750, 3609.3750, 3796.8750, 3984.3750, 4171.8750, 4359.3750, 4546.8750, 4734.3750
    .float 4921.8750, 5109.3750, 5296.8750, 5484.3750, 1593.7500, 1781.2500, 1968.7500, 2156.2500
    .float 2343.7500, 2531.2500, 2718.7500, 2906.2500, 3093.7500, 3281.2500, 3468.7500, 3656.2500
    .float 3843.7500, 4031.2500, 4218.7500, 4406.2500, 4593.7500, 4781.2500, 4968.7500, 5156.2500
    .float 5343.7500, 5531.2500, 1640.6250, 1828.1250, 2015.6250, 2203.1250, 2390.6250, 2578.1250
    .float 2765.6250, 2953.1250, 3140.6250, 3328.1250, 3515.6250, 3703.1250, 3890.6250, 4078.1250
    .float 4265.6250, 4453.1250, 4640.6250, 4828.1250, 5015.6250, 5203.1250, 5390.6250, 5578.1250
    .float 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000
    .space 64
// ---- Silent: 22 tones on the grid, 17.6 - 19.6 kHz, faded in and out over 5 ms ----
    .word 32, 1, 1920, 1024, 240, 8, 16, 0
    .float 0.40
    .word 3
    .float 0.50
    .word 4800
    .word 1, 22, 6, 0
    .float 17625.0000, 17718.7500, 17812.5000, 17906.2500, 18000.0000, 18093.7500, 18187.5000, 18281.2500
    .float 18375.0000, 18468.7500, 18562.5000, 18656.2500, 18750.0000, 18843.7500, 18937.5000, 19031.2500
    .float 19125.0000, 19218.7500, 19312.5000, 19406.2500, 19500.0000, 19593.7500, 0.0000, 0.0000
    .float 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000
    .space 320

_pre:       .byte 0, 2, 4, 5, 7, 9, 10, 12
_chord:     .byte 4, 6, 7, 9               // C5 E5 G5 C6

.p2align 2
Lk_w:       .float 0.00013089969389957471  // 2*pi / 48000
Lk_hann:    .float 0.0015347187720751934   // 2*pi / 4095
Lk_tau:     .float -0.00037878787878787879 // -1 / 2640 (55 ms decay)
Lk_att:     .float 0.0069444444444444444   // 1 / 144 (3 ms attack)
Lk_tiny:    .float 1.0e-12
Lk_tie:     .float 0.97
Lk_lowq:    .float 0.25
Lk_glide:   .float 0.85
Lk_chordamp: .float 0.55

.data
.p2align 4
.globl _rx
_rx:        .space (4096 * NMODES)
.globl _rx_ring
_rx_ring:   .space (RING * 8)
.globl _hann
_hann:      .space 16384
.globl _penv
_penv:      .space (PLEN * 4)
_tx_bytes:  .space 288
_tx_nibs:   .space 640
.p2align 3
.globl _rx_total
_rx_total:  .quad 0
.globl _rx_mute
_rx_mute:   .quad 0                // non-zero: the receiver hears silence (we're playing)
.globl _rx_sink
_rx_sink:   .quad 0                // void sink(long mode, const uint8 *bytes, long len, long fixed)
.globl _rx_peak
_rx_peak:   .quad 0                // float: loudest input sample since the meter last looked
.globl _tx_buf
_tx_buf:    .quad 0
_tx_cap:    .quad 0

.text
.p2align 2

// ---------------------------------------------------------------------------
// void _modem_init(void) — tables, filter coefficients, window, piano envelope
// ---------------------------------------------------------------------------
.globl _modem_init
_modem_init:
    ENTER 16
    bl   _gf_init
    mov  x19, #0
Lmi_mode:
    ADRL x20, _modes
    add  x20, x20, x19, lsl #MODE_SHIFT
    ADRL x21, _rx
    add  x21, x21, x19, lsl #RX_SHIFT
    ldr  w22, [x20, #M_NT]
    mov  x23, #0
Lmi_tone:
    add  x9, x20, #M_FREQ
    ldr  s0, [x9, x23, lsl #2]
    LDS  s1, Lk_w
    fmul s0, s0, s1
    CALLC cosf
    fadd s0, s0, s0
    add  x9, x21, #R_COEF
    str  s0, [x9, x23, lsl #2]
    add  x23, x23, #1
    cmp  x23, x22
    b.lo Lmi_tone
    add  x19, x19, #1
    cmp  x19, #NMODES
    b.lo Lmi_mode

    ADRL x20, _hann
    mov  x19, #0
Lmi_hann:
    ucvtf s0, w19
    LDS  s1, Lk_hann
    fmul s0, s0, s1
    CALLC cosf
    fmov s1, #0.5
    fmul s0, s0, s1
    fsub s0, s1, s0
    str  s0, [x20, x19, lsl #2]
    add  x19, x19, #1
    cmp  x19, #4096
    b.lo Lmi_hann

    ADRL x20, _penv
    mov  x19, #0
Lmi_env:
    ucvtf s0, w19
    LDS  s1, Lk_tau
    fmul s0, s0, s1
    CALLC expf
    cmp  x19, #144
    b.hs 1f
    ucvtf s1, w19
    LDS  s2, Lk_att
    fmul s1, s1, s2
    fmul s0, s0, s1
1:  str  s0, [x20, x19, lsl #2]
    add  x19, x19, #1
    mov  x9, #PLEN
    cmp  x19, x9
    b.lo Lmi_env
    bl   _rx_reset
    LEAVE 16

// ---------------------------------------------------------------------------
// void _rx_reset(void) — forget everything heard (filter coefficients stay)
// ---------------------------------------------------------------------------
.globl _rx_reset
_rx_reset:
    ENTER 0
    ADRL x0, _rx_ring
    mov  w1, #0
    mov  x2, #(RING * 8)
    CALLC memset
    ADRL x9, _rx_total
    str  xzr, [x9]
    mov  x19, #0
1:  ADRL x20, _modes
    add  x20, x20, x19, lsl #MODE_SHIFT
    ADRL x21, _rx
    add  x21, x21, x19, lsl #RX_SHIFT
    ldr  w9, [x20, #M_W]
    str  x9, [x21, #R_NEXT]
    str  xzr, [x21, #R_HOPN]
    str  wzr, [x21, #R_STATE]
    str  wzr, [x21, #R_NIB]
    str  wzr, [x21, #R_NEED]
    add  x0, x21, #R_HBEST
    mov  w1, #0
    mov  x2, #1024                    // R_HBEST and R_HQ
    CALLC memset
    add  x19, x19, #1
    cmp  x19, #NMODES
    b.lo 1b
    LEAVE 0

// ---------------------------------------------------------------------------
// void _rx_feed(const float *x, long n) — n samples from the microphone (48 kHz)
// ---------------------------------------------------------------------------
.globl _rx_feed
_rx_feed:
    ENTER 16
    mov  x19, x0
    mov  x20, x1
    bl   _peak_abs
    ADRL x9, _rx_peak
    ldr  s1, [x9]
    fmax s1, s1, s0
    str  s1, [x9]
    ADRL x21, _rx_ring
    ADRL x22, _rx_total
Lrf_loop:
    cbz  x20, Lrf_done
    ldr  s0, [x19], #4
    ADRL x9, _rx_mute
    ldr  x9, [x9]
    cbz  x9, 1f
    fmov s0, wzr
1:  ldr  x23, [x22]
    and  x9, x23, #(RING - 1)
    str  s0, [x21, x9, lsl #2]
    add  x9, x9, #RING
    str  s0, [x21, x9, lsl #2]
    add  x23, x23, #1
    str  x23, [x22]
    mov  x24, #0
Lrf_m:
    ADRL x9, _rx
    add  x9, x9, x24, lsl #RX_SHIFT
    ldr  x10, [x9, #R_NEXT]
    cmp  x23, x10
    b.lo Lrf_next
    ADRL x11, _modes
    add  x11, x11, x24, lsl #MODE_SHIFT
    ldr  w11, [x11, #M_HOP]
    add  x10, x10, x11
    str  x10, [x9, #R_NEXT]
    mov  x0, x24
    bl   _rx_hop
Lrf_next:
    add  x24, x24, #1
    cmp  x24, #NMODES
    b.lo Lrf_m
    sub  x20, x20, #1
    b    Lrf_loop
Lrf_done:
    LEAVE 16

// float _rx_peak_take(void) — the meter's reading, and start a new one
.globl _rx_peak_take
_rx_peak_take:
    ADRL x9, _rx_peak
    ldr  s0, [x9]
    str  wzr, [x9]
    ret

// long _rx_progress(long mode) — percent of a message heard so far, or -1 when idle
.globl _rx_progress
_rx_progress:
    ADRL x9, _rx
    add  x9, x9, x0, lsl #RX_SHIFT
    ldr  w10, [x9, #R_STATE]
    cbz  w10, 2f
    ldr  w11, [x9, #R_NEED]
    cbz  w11, 1f
    ldr  w12, [x9, #R_NIB]
    mov  w13, #100
    mul  w12, w12, w13
    udiv w0, w12, w11
    ret
1:  mov  x0, #0
    ret
2:  mov  x0, #-1
    ret

// ---------------------------------------------------------------------------
// _rx_hop(long mode) — one detection: which tone won in each group and how clearly,
// then the hunt / align / receive state machine
// ---------------------------------------------------------------------------
_rx_hop:
    ENTER 32
    mov  x19, x0
    ADRL x20, _modes
    add  x20, x20, x19, lsl #MODE_SHIFT
    ADRL x21, _rx
    add  x21, x21, x19, lsl #RX_SHIFT
    ADRL x9, _rx_total
    ldr  x9, [x9]
    ldr  w10, [x20, #M_W]
    sub  x9, x9, x10
    and  x9, x9, #(RING - 1)
    ADRL x0, _rx_ring
    add  x0, x0, x9, lsl #2
    mov  x1, x10
    add  x2, x21, #R_COEF
    ldr  w3, [x20, #M_NT]
    add  x4, x21, #R_ENER
    mov  x5, #0
    ldr  w9, [x20, #M_WIN]
    cbz  w9, 1f
    ADRL x5, _hann
1:  bl   _gz_bank
    ldr  w9, [x20, #M_HARM]           // piano: each note's score counts its overtones too
    cmp  w9, #3
    b.ne Lh_nofold
    add  x10, x21, #R_ENER
    ldr  w13, [x20, #M_NV]
    mov  x11, #0
Lh_fold:
    ldr  s0, [x10, x11, lsl #2]
    add  x12, x11, x13
    ldr  s1, [x10, x12, lsl #2]
    add  x12, x12, x13
    ldr  s2, [x10, x12, lsl #2]
    fadd s1, s1, s2
    fmov s3, #0.5
    fmadd s0, s1, s3, s0              // note + (octave + fifth above) / 2
    str  s0, [x10, x11, lsl #2]
    add  x11, x11, #1
    cmp  x11, x13
    b.lo Lh_fold
Lh_nofold:

    ldr  x22, [x21, #R_HOPN]          // h
    and  x9, x22, #(HIST - 1)
    add  x23, x21, #R_HBEST
    add  x23, x23, x9, lsl #2         // this hop's best tone per group
    ldr  w24, [x20, #M_NG]
    add  x10, x21, #R_ENER
    ldr  w15, [x20, #M_NV]
    mov  x11, #0
    fmov s6, wzr
    LDS  s3, Lk_tiny
Lh_g:
    mov  x17, #0                      // tones still echoing: the winners of the last KEX
    ldr  w6, [x20, #M_K]              // symbols at this same alignment are left out
    ldr  w7, [x20, #M_KEX]
    mov  x8, x6
1:  cbz  x7, 3f
    cmp  x22, x8
    b.lo 3f
    sub  x9, x22, x8
    and  x9, x9, #(HIST - 1)
    add  x9, x21, x9, lsl #2
    add  x9, x9, #R_HBEST
    ldrb w9, [x9, x11]
    mov  x16, #1
    lsl  x16, x16, x9
    orr  x17, x17, x16
    add  x8, x8, x6
    sub  x7, x7, #1
    b    1b
3:  mul  x12, x11, x15                // group g's tones start at g * NV
    add  x12, x10, x12, lsl #2
    fmov s1, wzr
    fmov s2, wzr
    mov  x13, #0
    mov  x14, #0
Lh_t:
    lsr  x9, x17, x13
    tbnz x9, #0, 2f
    ldr  s0, [x12, x13, lsl #2]
    fadd s2, s2, s0
    fcmp s0, s1
    b.le 2f
    fmov s1, s0
    mov  x14, x13
2:  add  x13, x13, #1
    cmp  x13, x15
    b.lo Lh_t
    fadd s2, s2, s3
    fdiv s1, s1, s2                   // the winner's share of the group's energy
    fadd s6, s6, s1
    fmov s4, #0.25                    // barely a winner (silence, hiss): not a tone at all,
    fcmp s1, s4                       // so it mustn't be left out of the next symbols
    mov  x9, #255
    csel x14, x9, x14, lt
    strb w14, [x23, x11]
    add  x11, x11, #1
    cmp  x11, x24
    b.lo Lh_g
    ucvtf s0, w24
    fdiv s6, s6, s0
    and  x9, x22, #(HIST - 1)
    add  x10, x21, #R_HQ
    str  s6, [x10, x9, lsl #2]
    add  x9, x22, #1
    str  x9, [x21, #R_HOPN]

    ldr  w9, [x21, #R_STATE]
    cmp  w9, #2
    b.eq Lh_recv
    mov  x0, x21
    mov  x1, x20
    mov  x2, x22
    bl   _pre_score
    ldr  w9, [x21, #R_STATE]
    cbnz w9, Lh_align
    fcmp s0, #0.0                     // hunting
    b.lt Lh_done
    mov  w9, #1
    str  w9, [x21, #R_STATE]
    str  x22, [x21, #R_H0]
    add  x10, x21, #R_RSC
    fmov s1, #-1.0
    mov  x11, #0
3:  str  s1, [x10, x11, lsl #2]
    add  x11, x11, #1
    cmp  x11, #16
    b.lo 3b
    str  s0, [x10]
    b    Lh_done

Lh_align:                             // score one symbol's worth of alignments
    ldr  x10, [x21, #R_H0]
    sub  x11, x22, x10
    add  x12, x21, #R_RSC
    str  s0, [x12, x11, lsl #2]
    ldr  w13, [x20, #M_K]
    sub  x13, x13, #1
    cmp  x11, x13
    b.lo Lh_done
    fmov s1, #-1.0                    // the best score ...
    mov  x14, #0
4:  ldr  s2, [x12, x14, lsl #2]
    fmax s1, s1, s2
    add  x14, x14, #1
    cmp  x14, x13
    b.ls 4b
    LDS  s3, Lk_tie                   // ... and the middle of everything within 3% of it
    fmul s3, s3, s1
    mov  x15, #-1
    mov  x17, #0
    mov  x14, #0
5:  ldr  s2, [x12, x14, lsl #2]
    fcmp s2, s3
    b.lt 6f
    cmp  x15, #0
    csel x15, x14, x15, lt
    mov  x17, x14
6:  add  x14, x14, #1
    cmp  x14, x13
    b.ls 5b
    add  x15, x15, x17
    lsr  x15, x15, #1
    add  x15, x15, x10
    ldr  w14, [x20, #M_K]
    add  x15, x15, x14
    str  x15, [x21, #R_DHOP]
    mov  w9, #2
    str  w9, [x21, #R_STATE]
    str  wzr, [x21, #R_NIB]
    str  wzr, [x21, #R_NEED]
    str  wzr, [x21, #R_QSUM]
    str  wzr, [x21, #R_LOWQ]
    ADRL x9, _pre                     // both ends start the tone history with the preamble
    ldr  x10, [x9]
    str  x10, [x21, #R_THIST]
    str  x10, [x21, #(R_THIST + 8)]
    str  x10, [x21, #(R_THIST + 16)]
    str  x10, [x21, #(R_THIST + 24)]
    b    Lh_done

Lh_recv:
    ldr  x10, [x21, #R_DHOP]
    cmp  x22, x10
    b.ne Lh_done
    ldr  w11, [x20, #M_K]
    add  x10, x10, x11
    str  x10, [x21, #R_DHOP]
    ldr  s1, [x21, #R_QSUM]
    fadd s1, s1, s6
    str  s1, [x21, #R_QSUM]
    mov  x0, x21                      // each group's tone, skipping those still echoing
    mov  x1, x20
    bl   _rx_symbol
    ldr  w12, [x21, #R_NIB]
    add  x13, x21, #R_NIBS
    ldr  w9, [x21, #R_LOWQ]           // the sender has stopped (or we lost it): don't wait
    LDS  s1, Lk_lowq                  // for the rest of a message that isn't coming
    fcmp s6, s1
    csinc w9, wzr, w9, ge
    str  w9, [x21, #R_LOWQ]
    cmp  w9, #4
    b.hs Lh_gone
    ldr  w15, [x21, #R_NEED]
    cbnz w15, Lh_check
    cmp  w12, #6
    b.lo Lh_done
    ldrb w0, [x13]                    // the length, three times: majority wins
    ldrb w1, [x13, #1]
    orr  w0, w1, w0, lsl #4
    ldrb w1, [x13, #2]
    ldrb w2, [x13, #3]
    orr  w1, w2, w1, lsl #4
    ldrb w2, [x13, #4]
    ldrb w3, [x13, #5]
    orr  w2, w3, w2, lsl #4
    cmp  w0, w1
    b.eq 9f
    cmp  w0, w2
    b.eq 9f
    mov  w0, w1
    cmp  w1, w2
    b.ne Lh_nohdr
9:  cbz  w0, Lh_nohdr
    ldr  w9, [x20, #M_NR]
    mov  w10, #253
    sub  w10, w10, w9
    cmp  w0, w10
    b.hi Lh_nohdr
    str  w0, [x21, #R_LEN]
    add  w10, w0, #2
    add  w10, w10, w9
    lsl  w10, w10, #1
    add  w10, w10, #6
    str  w10, [x21, #R_NEED]
    mov  w15, w10
Lh_check:
    cmp  w12, w15
    b.lo Lh_done
    mov  x0, x19
    bl   _rx_finish
    str  wzr, [x21, #R_STATE]
    b    Lh_done
Lh_gone:                              // four symbols in a row of next to nothing
    str  wzr, [x21, #R_STATE]
    ldr  x11, [x21, #(R_STATS + 16)]
    add  x11, x11, #1
    str  x11, [x21, #(R_STATS + 16)]
    ADRL x9, _rx_sink
    ldr  x9, [x9]
    cbz  x9, Lh_done
    mov  x0, x19
    add  x1, x21, #R_NIBS
    mov  x2, #-1
    mov  x3, #0
    blr  x9
    b    Lh_done
Lh_nohdr:                             // a preamble with no sensible header: say so, hunt again
    str  wzr, [x21, #R_STATE]
    ldr  x11, [x21, #(R_STATS + 24)]
    add  x11, x11, #1
    str  x11, [x21, #(R_STATS + 24)]
    ADRL x9, _rx_sink
    ldr  x9, [x9]
    cbz  x9, Lh_done
    mov  x0, x19
    add  x1, x21, #R_NIBS
    mov  x2, #-2
    mov  x3, #0
    blr  x9
Lh_done:
    LEAVE 32

// _rx_symbol(rx *x0, mode *x1) — read one data symbol from this hop's energies: in each
// group the loudest tone that hasn't played in the last KEX symbols (the room is still
// ringing with those), its rank among the allowed tones is the nibble. Leaf.
_rx_symbol:
    ldr  w2, [x1, #M_NG]
    ldr  w3, [x1, #M_NV]
    ldr  w4, [x1, #M_KEX]
    mov  x16, #8
    sub  x16, x16, x4                 // the excluded tones are hist[8-KEX .. 7]
    add  x5, x0, #R_ENER
    ldr  w6, [x0, #R_NIB]
    mov  x7, #0
Lrs_g:
    add  x8, x0, #R_THIST
    add  x8, x8, x7, lsl #3
    mul  x9, x7, x3
    add  x9, x5, x9, lsl #2
    mov  x10, #-1                     // best tone so far
    mov  x11, #0
Lrs_v:
    mov  x12, x16
1:  cmp  x12, #8
    b.hs 2f
    ldrb w13, [x8, x12]
    cmp  w13, w11
    b.eq Lrs_vnext                    // still echoing
    add  x12, x12, #1
    b    1b
2:  ldr  s0, [x9, x11, lsl #2]
    tbnz x10, #63, 3f
    fcmp s0, s1
    b.le Lrs_vnext
3:  fmov s1, s0
    mov  x10, x11
Lrs_vnext:
    add  x11, x11, #1
    cmp  x11, x3
    b.lo Lrs_v
    mov  x14, #0                      // rank among the allowed tones
    mov  x11, #0
Lrs_r:
    cmp  x11, x10
    b.hs Lrs_rdone
    mov  x12, x16
4:  cmp  x12, #8
    b.hs 5f
    ldrb w13, [x8, x12]
    cmp  w13, w11
    b.eq 6f
    add  x12, x12, #1
    b    4b
5:  add  x14, x14, #1
6:  add  x11, x11, #1
    b    Lrs_r
Lrs_rdone:
    and  x14, x14, #15
    ldr  x15, [x8]                    // remember the tone (newest in the top byte)
    lsr  x15, x15, #8
    orr  x15, x15, x10, lsl #56
    str  x15, [x8]
    add  x15, x0, #R_NIBS
    cmp  w6, #540
    b.hs 7f
    strb w14, [x15, x6]
    add  w6, w6, #1
7:  add  x7, x7, #1
    cmp  x7, x2
    b.lo Lrs_g
    str  w6, [x0, #R_NIB]
    ret

// _tx_tones(mode *x0, uint8 *nibs x1, long count x2) — turn the nibbles after the preamble
// into tones the same way: nibble d is the d-th tone not played in the last KEX symbols
// of its group. Leaf.
_tx_tones:
    sub  sp, sp, #32
    ldr  w3, [x0, #M_NG]
    ldr  w4, [x0, #M_KEX]
    mov  x16, #8
    sub  x16, x16, x4
    ADRL x9, _pre
    ldr  x10, [x9]
    stp  x10, x10, [sp]
    stp  x10, x10, [sp, #16]
    mov  x5, #NPRE
    mul  x5, x5, x3                   // first nibble after the preamble
Ltt_i:
    cmp  x5, x2
    b.hs Ltt_done
    udiv x6, x5, x3
    msub x6, x6, x3, x5               // group
    add  x8, sp, x6, lsl #3
    ldrb w7, [x1, x5]                 // d
    mov  x11, #0                      // candidate tone
Ltt_v:
    mov  x12, x16
1:  cmp  x12, #8
    b.hs 2f
    ldrb w13, [x8, x12]
    cmp  w13, w11
    b.eq 3f
    add  x12, x12, #1
    b    1b
2:  cbz  x7, Ltt_found                // the d-th allowed tone
    sub  x7, x7, #1
3:  add  x11, x11, #1
    b    Ltt_v
Ltt_found:
    strb w11, [x1, x5]
    ldr  x15, [x8]
    lsr  x15, x15, #8
    orr  x15, x15, x11, lsl #56
    str  x15, [x8]
    add  x5, x5, #1
    b    Ltt_i
Ltt_done:
    add  sp, sp, #32
    ret

// float _pre_score(rx *x0, mode *x1, long h x2) — if at least 7 of the 8 symbols ending at
// hop h are the preamble's (in every group, clearly enough), their summed quality; else -1. Leaf.
_pre_score:
    ldr  w9, [x1, #M_K]
    mov  x10, #(NPRE - 1)
    mul  x10, x10, x9
    cmp  x2, x10
    b.lo Lps_no
    ldr  w11, [x1, #M_NG]
    ldr  s2, [x1, #M_QMIN]
    fmov s0, wzr
    mov  x6, #0                       // symbols missed
    mov  x12, #0
    ADRL x13, _pre
Lps_j:
    mov  x14, #(NPRE - 1)
    sub  x14, x14, x12
    mul  x14, x14, x9
    sub  x14, x2, x14
    and  x14, x14, #(HIST - 1)
    add  x15, x0, #R_HQ
    ldr  s1, [x15, x14, lsl #2]
    ldrb w16, [x13, x12]
    add  x15, x0, #R_HBEST
    add  x15, x15, x14, lsl #2
    mov  x17, #0
Lps_g:
    ldrb w3, [x15, x17]
    cmp  w3, w16
    b.ne Lps_miss
    add  x17, x17, #1
    cmp  x17, x11
    b.lo Lps_g
    fcmp s1, s2
    b.lt Lps_miss
    fadd s0, s0, s1
    b    Lps_next
Lps_miss:
    add  x6, x6, #1
    cmp  x6, #1
    b.hi Lps_no
Lps_next:
    add  x12, x12, #1
    cmp  x12, #NPRE
    b.lo Lps_j
    ret
Lps_no:
    fmov s0, #-1.0
    ret

// _rx_finish(long mode) — nibbles to bytes, unwhiten, repair, check, hand over
_rx_finish:
    ENTER 16
    mov  x19, x0
    ADRL x20, _modes
    add  x20, x20, x19, lsl #MODE_SHIFT
    ADRL x21, _rx
    add  x21, x21, x19, lsl #RX_SHIFT
    ldr  w22, [x21, #R_LEN]
    ldr  w23, [x20, #M_NR]
    add  x24, x22, #2
    add  x24, x24, x23                // n
    add  x9, x21, #R_NIBS
    add  x9, x9, #6
    add  x10, x21, #R_BYTES
    mov  x11, #0
1:  ldrb w12, [x9], #1
    ldrb w13, [x9], #1
    orr  w12, w13, w12, lsl #4
    strb w12, [x10, x11]
    add  x11, x11, #1
    cmp  x11, x24
    b.lo 1b
    add  x0, x21, #R_BYTES
    mov  x1, x24
    bl   _whiten
    add  x0, x21, #R_BYTES
    mov  x1, x24
    mov  x2, x23
    bl   _rs_decode
    str  x0, [sp, #96]
    tbnz x0, #63, Lf_lost
    add  x0, x21, #R_BYTES
    mov  x1, x22
    bl   _crc16
    add  x9, x21, #R_BYTES
    add  x9, x9, x22
    ldrb w10, [x9]
    ldrb w11, [x9, #1]
    orr  w10, w10, w11, lsl #8
    cmp  w0, w10
    b.ne Lf_lost
    ldr  x9, [sp, #96]
    mov  x10, #R_STATS
    mov  x11, #(R_STATS + 8)
    cmp  x9, #0
    csel x10, x10, x11, eq
    ldr  x11, [x21, x10]
    add  x11, x11, #1
    str  x11, [x21, x10]
    ADRL x9, _rx_sink
    ldr  x9, [x9]
    cbz  x9, Lf_done
    mov  x0, x19
    add  x1, x21, #R_BYTES
    mov  x2, x22
    ldr  x3, [sp, #96]
    blr  x9
    b    Lf_done
Lf_lost:
    ldr  x11, [x21, #(R_STATS + 16)]
    add  x11, x11, #1
    str  x11, [x21, #(R_STATS + 16)]
    ADRL x9, _rx_sink
    ldr  x9, [x9]
    cbz  x9, Lf_done
    mov  x0, x19
    add  x1, x21, #R_BYTES
    mov  x2, #-1
    mov  x3, #0
    blr  x9
Lf_done:
    LEAVE 16

// ---------------------------------------------------------------------------
// Sending
// ---------------------------------------------------------------------------

// long _tx_maxlen(long mode) — the longest message one frame can carry
.globl _tx_maxlen
_tx_maxlen:
    ADRL x9, _modes
    add  x9, x9, x0, lsl #MODE_SHIFT
    ldr  w10, [x9, #M_NR]
    mov  x0, #253
    sub  x0, x0, x10
    ret

// long _tx_samples(long mode, long len) — how many samples a message of len bytes takes
.globl _tx_samples
_tx_samples:
    ADRL x9, _modes
    add  x9, x9, x0, lsl #MODE_SHIFT
    ldr  w10, [x9, #M_NR]
    ldr  w11, [x9, #M_NG]
    add  x12, x1, #2
    add  x12, x12, x10
    lsl  x12, x12, #1
    add  x12, x12, #6                 // header + body nibbles
    mov  x13, #NPRE
    madd x12, x13, x11, x12           // + preamble
    add  x12, x12, x11
    sub  x12, x12, #1
    udiv x12, x12, x11                // symbols
    ldr  w13, [x9, #M_S]
    mul  x0, x12, x13
    mov  x17, #LEAD
    add  x0, x0, x17
    ldr  w13, [x9, #M_TAIL]
    add  x0, x0, x13
    ret

// long _tx_render(long mode, const uint8 *msg, long len)
//   Builds the whole message as sound in _tx_buf (48 kHz mono float) and returns
//   the number of samples, or 0 if the message is empty or too long.
.globl _tx_render
_tx_render:
    ENTER 64                          // [96] n  [104] symbols  [112] samples  [120] room
    mov  x19, x0
    ADRL x20, _modes
    add  x20, x20, x19, lsl #MODE_SHIFT
    mov  x21, x2
    mov  x22, x1
    ldr  w23, [x20, #M_NR]
    cbz  x21, Ltx_bad
    mov  x9, #253
    sub  x9, x9, x23
    cmp  x21, x9
    b.hi Ltx_bad
    ADRL x24, _tx_bytes
    mov  x0, x24
    mov  x1, x22
    mov  x2, x21
    CALLC memcpy
    mov  x0, x24
    mov  x1, x21
    bl   _crc16
    strb w0, [x24, x21]
    lsr  w0, w0, #8
    add  x9, x21, #1
    strb w0, [x24, x9]
    mov  x0, x24
    add  x1, x21, #2
    add  x2, x24, x1
    mov  x3, x23
    bl   _rs_encode
    add  x9, x21, #2
    add  x9, x9, x23
    str  x9, [sp, #96]
    mov  x0, x24
    mov  x1, x9
    bl   _whiten

    ADRL x22, _tx_nibs                // the symbols, as nibbles
    mov  x10, #0
    ldr  w11, [x20, #M_NG]
    ADRL x12, _pre
    mov  x13, #0
1:  ldrb w14, [x12, x13]
    mov  x15, #0
2:  strb w14, [x22, x10]
    add  x10, x10, #1
    add  x15, x15, #1
    cmp  x15, x11
    b.lo 2b
    add  x13, x13, #1
    cmp  x13, #NPRE
    b.lo 1b
    mov  x13, #0
3:  lsr  w14, w21, #4
    strb w14, [x22, x10]
    add  x10, x10, #1
    and  w14, w21, #15
    strb w14, [x22, x10]
    add  x10, x10, #1
    add  x13, x13, #1
    cmp  x13, #3
    b.lo 3b
    ldr  x9, [sp, #96]
    mov  x13, #0
4:  ldrb w14, [x24, x13]
    lsr  w15, w14, #4
    strb w15, [x22, x10]
    add  x10, x10, #1
    and  w15, w14, #15
    strb w15, [x22, x10]
    add  x10, x10, #1
    add  x13, x13, #1
    cmp  x13, x9
    b.lo 4b
5:  udiv x13, x10, x11
    msub x13, x13, x11, x10
    cbz  x13, 6f
    strb wzr, [x22, x10]
    add  x10, x10, #1
    b    5b
6:  str  x10, [sp, #120]
    mov  x0, x20                      // nibbles -> tones (resting the echoing ones)
    mov  x1, x22
    mov  x2, x10
    bl   _tx_tones
    ldr  x10, [sp, #120]
    ldr  w11, [x20, #M_NG]
    udiv x13, x10, x11
    str  x13, [sp, #104]
    ldr  w14, [x20, #M_S]
    mul  x15, x13, x14
    mov  x17, #LEAD
    add  x15, x15, x17
    ldr  w14, [x20, #M_TAIL]
    add  x15, x15, x14
    str  x15, [sp, #112]

    ADRL x9, _tx_cap                  // room for it
    ldr  x10, [x9]
    cmp  x15, x10
    b.ls 7f
    ADRL x9, _tx_buf
    ldr  x0, [x9]
    lsl  x1, x15, #2
    CALLC realloc
    cbz  x0, Ltx_bad
    ADRL x9, _tx_buf
    str  x0, [x9]
    ldr  x15, [sp, #112]
    ADRL x9, _tx_cap
    str  x15, [x9]
7:  ADRL x9, _tx_buf
    ldr  x0, [x9]
    mov  w1, #0
    ldr  x2, [sp, #112]
    lsl  x2, x2, #2
    CALLC memset

    mov  x23, #0                      // symbol s
Lsym:
    ldr  x9, [sp, #104]
    cmp  x23, x9
    b.hs Ltail
    ldr  w10, [x20, #M_S]
    mul  x11, x23, x10
    mov  x17, #LEAD
    add  x11, x11, x17
    ADRL x9, _tx_buf
    ldr  x9, [x9]
    add  x24, x9, x11, lsl #2
    ldr  x12, [sp, #112]
    sub  x12, x12, x11
    str  x12, [sp, #120]
    ldr  w9, [x20, #M_VOICE]
    cmp  w9, #1
    b.eq Lv_chirp
    cmp  w9, #2
    b.eq Lv_fast
    cmp  w9, #3
    b.eq Lv_silent
    ldrb w9, [x22, x23]               // piano
    add  x10, x20, #M_FREQ
    ldr  s0, [x10, x9, lsl #2]
    ldr  s1, [x20, #M_AMP]
    mov  x0, x24
    ldr  x1, [sp, #120]
    bl   _v_piano
    b    Lsym_next
Lv_chirp:
    ldrb w9, [x22, x23]
    add  x10, x20, #M_FREQ
    ldr  s1, [x10, x9, lsl #2]
    LDS  s0, Lk_glide
    fmul s0, s0, s1
    ldr  s2, [x20, #M_AMP]
    mov  x0, x24
    ldr  w1, [x20, #M_S]
    lsr  x2, x1, #2
    mov  x3, #96
    bl   _v_tone
    b    Lsym_next
Lv_fast:
    mov  x21, #0                      // group g (the length isn't needed any more)
Lvf_g:
    lsl  x9, x23, #2
    add  x9, x9, x21
    ldrb w9, [x22, x9]
    ldr  w10, [x20, #M_NV]
    madd x9, x21, x10, x9             // group g's tones start at g * NV
    add  x10, x20, #M_FREQ
    ldr  s0, [x10, x9, lsl #2]
    fmov s1, s0
    ldr  s2, [x20, #M_AMP]
    mov  x0, x24
    ldr  w1, [x20, #M_S]
    mov  x2, #0
    mov  x3, #96
    bl   _v_tone
    add  x21, x21, #1
    cmp  x21, #4
    b.lo Lvf_g
    b    Lsym_next
Lv_silent:                            // one high tone, faded in and out over 5 ms
    ldrb w9, [x22, x23]
    add  x10, x20, #M_FREQ
    ldr  s0, [x10, x9, lsl #2]
    fmov s1, s0
    ldr  s2, [x20, #M_AMP]
    mov  x0, x24
    ldr  w1, [x20, #M_S]
    mov  x2, #0
    mov  x3, #240
    bl   _v_tone
Lsym_next:
    add  x23, x23, #1
    b    Lsym

Ltail:                                // the piano ends on a chord
    ldr  w9, [x20, #M_VOICE]
    cbnz w9, Lnorm
    ldr  x9, [sp, #104]
    ldr  w10, [x20, #M_S]
    mul  x11, x9, x10
    mov  x17, #LEAD
    add  x11, x11, x17
    ADRL x9, _tx_buf
    ldr  x9, [x9]
    add  x24, x9, x11, lsl #2
    ldr  x12, [sp, #112]
    sub  x12, x12, x11
    str  x12, [sp, #120]
    mov  x23, #0
Lchord:
    ADRL x9, _chord
    ldrb w9, [x9, x23]
    add  x10, x20, #M_FREQ
    ldr  s0, [x10, x9, lsl #2]
    ldr  s1, [x20, #M_AMP]
    LDS  s2, Lk_chordamp
    fmul s1, s1, s2
    mov  x0, x24
    ldr  x1, [sp, #120]
    bl   _v_piano
    add  x23, x23, #1
    cmp  x23, #4
    b.lo Lchord
Lnorm:
    ADRL x9, _tx_buf
    ldr  x0, [x9]
    ldr  x1, [sp, #112]
    bl   _normalize
    ldr  x0, [sp, #112]
    LEAVE 64
Ltx_bad:
    mov  x0, #0
    LEAVE 64
