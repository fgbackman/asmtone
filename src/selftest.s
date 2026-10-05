// selftest.s — asmtone's self-tests: CRC, Reed–Solomon, and every mode played into the
// receiver through a simulated room (two echoes and hiss), plus clock drift, a burst
// of noise, back-to-back messages and five seconds of noise that must stay silent.
//   asmtone --selftest      (also built and run natively on ARM64 Linux: see test/)

.include "macros.inc"

RODATA
Ls_crc_in:   .ascii "123456789"
Ls_msg:      .asciz "Hello from asmtone \342\231\252 piano, chirp & fast - 0123456789"
Ls_pass:     .asciz "PASS  "
Ls_fail:     .asciz "FAIL  "
Ls_t_crc:    .asciz "crc16 check value (0x906E)"
Ls_t_rs8:    .asciz "reed-solomon: 8 parity bytes repair 4 damaged bytes"
Ls_t_rs12:   .asciz "reed-solomon: 12 parity bytes repair 6 damaged bytes"
Ls_t_rs16:   .asciz "reed-solomon: 16 parity bytes repair 8 damaged bytes"
Ls_t_rs0:    .asciz "reed-solomon: a clean block needs no repairs"
Ls_t_piano:  .asciz "piano: through a room with echoes and hiss"
Ls_t_chirp:  .asciz "chirp: through a room with echoes and hiss"
Ls_t_fast:   .asciz "fast: through a room with echoes and hiss"
Ls_t_drift:  .asciz "fast: with the two sound cards' clocks 200 ppm apart"
Ls_t_cdrift: .asciz "chirp: with the clocks 200 ppm apart"
Ls_t_burst:  .asciz "fast: a 30 ms burst of loud noise is repaired"
Ls_t_two:    .asciz "chirp then fast, back to back: both heard"
Ls_t_quiet:  .asciz "five seconds of hiss: nothing heard"
Ls_t_silent: .asciz "silent: 18-19.4 kHz through a room with echoes and hiss"
Ls_t_sdrift: .asciz "silent: with the clocks 200 ppm apart"
Ls_t_phigh:  .asciz "piano: through a tiny speaker that loses the low notes"
Ls_t_pdrift: .asciz "piano: with the clocks 200 ppm apart"
Ls_t_stop:   .asciz "a message cut off half way is given up quickly"
Ls_t_long:   .asciz "fast: the longest message (237 bytes)"
Ls_t_max:    .asciz "a message one byte too long is refused"
Ls_done:     .asciz "self-tests done"

.p2align 2
Lk_inv23:    .float 1.1920928955078125e-07
Lk_gain:     .float 0.3
Lk_e1:       .float 0.105
Lk_e2:       .float 0.045
Lk_hiss:     .float 0.01
Lk_burst:    .float 0.3
Lk_quiet:    .float 0.05
Lk_hp:       .float 0.86424              // one pole of a 1.2 kHz high-pass
.p2align 3
Lk_drift:    .double 1.0002

.data
.p2align 4
_t_got:      .space 288
_t_line:     .space 256
_t_blk:      .space 256
_t_ref:      .space 256
_t_long:     .space 256
.p2align 3
_t_len:      .quad 0
_t_fixed:    .quad 0
_t_mode:     .quad 0
_t_count:    .quad 0
_t_fails:    .quad 0
_t_seed:     .quad 12345
_t_ch:       .quad 0
_t_chn:      .quad 0

.text
.p2align 2

// long _selftest(void) -> number of failures
.globl _selftest
_selftest:
    ENTER 16
    ADRL x9, _t_fails
    str  xzr, [x9]
    ADRL x9, _test_sink
    ADRL x10, _rx_sink
    str  x9, [x10]

    ADRL x0, Ls_crc_in                // CRC-16/X.25 of "123456789" is 0x906E
    mov  x1, #9
    bl   _crc16
    mov  w9, #0x906E
    cmp  w0, w9
    cset x0, eq
    ADRL x1, Ls_t_crc
    bl   _result

    mov  x0, #8
    bl   _t_rs
    ADRL x1, Ls_t_rs8
    bl   _result
    mov  x0, #12
    bl   _t_rs
    ADRL x1, Ls_t_rs12
    bl   _result
    mov  x0, #16
    bl   _t_rs
    ADRL x1, Ls_t_rs16
    bl   _result
    ADRL x0, _t_ref                   // the last block, now repaired, decodes clean
    mov  x1, #56
    mov  x2, #16
    bl   _rs_decode
    cmp  x0, #0
    cset x0, eq
    ADRL x1, Ls_t_rs0
    bl   _result

    mov  x0, #MODE_PIANO
    mov  x1, #0
    bl   _t_loop
    ADRL x1, Ls_t_piano
    bl   _result
    mov  x0, #MODE_CHIRP
    mov  x1, #0
    bl   _t_loop
    ADRL x1, Ls_t_chirp
    bl   _result
    mov  x0, #MODE_FAST
    mov  x1, #0
    bl   _t_loop
    ADRL x1, Ls_t_fast
    bl   _result
    mov  x0, #MODE_FAST
    mov  x1, #2
    bl   _t_loop
    ADRL x1, Ls_t_drift
    bl   _result
    mov  x0, #MODE_CHIRP
    mov  x1, #2
    bl   _t_loop
    ADRL x1, Ls_t_cdrift
    bl   _result
    mov  x0, #MODE_FAST
    mov  x1, #4
    bl   _t_loop
    ADRL x1, Ls_t_burst
    bl   _result
    mov  x0, #MODE_FAST
    mov  x1, #8
    bl   _t_loop
    ADRL x1, Ls_t_long
    bl   _result
    mov  x0, #MODE_SILENT
    mov  x1, #0
    bl   _t_loop
    ADRL x1, Ls_t_silent
    bl   _result
    mov  x0, #MODE_SILENT
    mov  x1, #2
    bl   _t_loop
    ADRL x1, Ls_t_sdrift
    bl   _result
    mov  x0, #MODE_PIANO
    mov  x1, #16
    bl   _t_loop
    ADRL x1, Ls_t_phigh
    bl   _result
    mov  x0, #MODE_PIANO
    mov  x1, #2
    bl   _t_loop
    ADRL x1, Ls_t_pdrift
    bl   _result
    bl   _t_cut
    ADRL x1, Ls_t_stop
    bl   _result
    bl   _t_two
    ADRL x1, Ls_t_two
    bl   _result
    bl   _t_quiet
    ADRL x1, Ls_t_quiet
    bl   _result

    mov  x0, #MODE_FAST               // 238 bytes in Fast: refused
    ADRL x1, _t_long
    mov  x2, #238
    bl   _tx_render
    cmp  x0, #0
    cset x0, eq
    ADRL x1, Ls_t_max
    bl   _result

    ADRL x9, _rx_sink
    str  xzr, [x9]
    bl   _rx_reset
    ADRL x0, Ls_done
    CALLC puts
    ADRL x9, _t_fails
    ldr  x0, [x9]
    LEAVE 16

// _result(long ok, const char *name) — "PASS  name" / "FAIL  name"
_result:
    ENTER 0
    mov  x19, x0
    mov  x20, x1
    ADRL x1, Ls_pass
    cbnz x19, 1f
    ADRL x9, _t_fails
    ldr  x10, [x9]
    add  x10, x10, #1
    str  x10, [x9]
    ADRL x1, Ls_fail
1:  ADRL x0, _t_line
    CALLC strcpy
    ADRL x0, _t_line
    mov  x1, x20
    CALLC strcat
    ADRL x0, _t_line
    CALLC puts
    LEAVE 0

// the receiver's sink while testing: keep the last message
_test_sink:
    ENTER 0
    mov  x19, x1
    mov  x20, x2
    ADRL x9, _t_mode
    str  x0, [x9]
    ADRL x9, _t_len
    str  x2, [x9]
    ADRL x9, _t_fixed
    str  x3, [x9]
    ADRL x9, _t_count
    ldr  x10, [x9]
    add  x10, x10, #1
    str  x10, [x9]
    cmp  x20, #0
    b.le 1f
    ADRL x0, _t_got
    mov  x1, x19
    mov  x2, x20
    CALLC memcpy
1:  LEAVE 0

// s0 = noise in [-1, 1). Leaf: x9-x12, s0, s1, x16.
_trand:
    ADRL x9, _t_seed
    ldr  w10, [x9]
    mov  w11, #0x4E6D
    movk w11, #0x41C6, lsl #16
    mov  w12, #12345
    madd w10, w10, w11, w12
    str  w10, [x9]
    lsr  w10, w10, #8
    ucvtf s0, w10
    LDS  s1, Lk_inv23
    fmul s0, s0, s1
    fmov s1, #1.0
    fsub s0, s0, s1
    ret

// long _t_rs(long nr) — 40 data bytes + nr parity, nr/2 bytes damaged, repaired?
_t_rs:
    ENTER 0
    mov  x19, x0
    ADRL x20, _t_ref
    mov  x9, #0
1:  mov  x10, #7
    mul  x10, x9, x10
    add  x10, x10, #3
    strb w10, [x20, x9]
    add  x9, x9, #1
    cmp  x9, #40
    b.lo 1b
    mov  x0, x20
    mov  x1, #40
    add  x2, x20, #40
    mov  x3, x19
    bl   _rs_encode
    ADRL x21, _t_blk
    mov  x0, x21
    mov  x1, x20
    add  x2, x19, #40
    CALLC memcpy
    add  x22, x19, #40                // n
    lsr  x23, x19, #1                 // errors to make
    mov  x9, #0
2:  mov  x10, #11                     // position 11i + 5 mod n
    mul  x10, x9, x10
    add  x10, x10, #5
    udiv x11, x10, x22
    msub x10, x11, x22, x10
    add  x11, x9, #1
    mov  x12, #37
    mul  x11, x11, x12
    orr  x11, x11, #1
    ldrb w12, [x21, x10]
    eor  w12, w12, w11
    strb w12, [x21, x10]
    add  x9, x9, #1
    cmp  x9, x23
    b.lo 2b
    mov  x0, x21
    mov  x1, x22
    mov  x2, x19
    bl   _rs_decode
    cmp  x0, x23
    b.ne 3f
    mov  x0, x21
    mov  x1, x20
    mov  x2, x22
    CALLC memcmp
    cmp  w0, #0
    cset x0, eq
    LEAVE 0
3:  mov  x0, #0
    LEAVE 0

// long _t_loop(long mode, long flags) — play the test message through a simulated
// room into the receiver. flags: 2 = clock drift, 4 = noise burst, 8 = longest message
_t_loop:
    ENTER 48
    stp  d8, d9, [sp, #96]
    stp  d10, d11, [sp, #112]
    mov  x19, x0
    mov  x20, x1
    tbz  x20, #3, 1f
    ADRL x22, _t_long                 // 237 bytes of text
    mov  x9, #0
0:  mov  x10, #33
    udiv x11, x9, x10
    msub x10, x11, x10, x9
    add  x10, x10, #65
    strb w10, [x22, x9]
    add  x9, x9, #1
    cmp  x9, #237
    b.lo 0b
    mov  x23, #237
    b    2f
1:  ADRL x22, Ls_msg
    mov  x0, x22
    CALLC strlen
    mov  x23, x0
2:  mov  x0, x19
    mov  x1, x22
    mov  x2, x23
    bl   _tx_render
    cbz  x0, Ltl_fail
    mov  x21, x0                      // samples
    mov  x9, #8000
    add  x0, x21, x9
    str  x0, [sp, #128]
    mov  x1, #4
    CALLC calloc
    cbz  x0, Ltl_fail
    mov  x24, x0
    mov  x0, x19                      // where the message starts: an odd offset
    mov  x9, #777
    mov  x10, #1234
    madd x0, x0, x9, x10
    str  x0, [sp, #136]
    add  x0, x24, x0, lsl #2
    mov  x1, x21
    mov  x2, x20
    bl   _t_room
    ldr  x0, [sp, #128]
    mov  x1, x24
    bl   _t_hiss
    tbz  x20, #2, 3f
    ldr  x9, [sp, #136]               // a loud 30 ms crackle in the middle
    add  x9, x9, x21, lsr #1
    add  x0, x24, x9, lsl #2
    mov  x1, #1440
    LDS  s0, Lk_burst
    bl   _t_noise
3:  tbz  x20, #4, 4f                 // a small speaker: two passes of a 1.2 kHz high-pass
    mov  x0, x24                      // (G4 comes out 20 dB down)
    ldr  x1, [sp, #128]
    bl   _t_highpass
    mov  x0, x24
    ldr  x1, [sp, #128]
    bl   _t_highpass
4:  ADRL x9, _t_count
    str  xzr, [x9]
    bl   _rx_reset
    mov  x0, x24
    ldr  x1, [sp, #128]
    bl   _t_feed
    mov  x0, x24
    CALLC free
    ADRL x9, _t_count                 // exactly one message, the right one
    ldr  x9, [x9]
    cmp  x9, #1
    b.ne Ltl_fail
    ADRL x9, _t_mode
    ldr  x9, [x9]
    cmp  x9, x19
    b.ne Ltl_fail
    ADRL x9, _t_len
    ldr  x9, [x9]
    cmp  x9, x23
    b.ne Ltl_fail
    ADRL x0, _t_got
    mov  x1, x22
    mov  x2, x23
    CALLC memcmp
    cmp  w0, #0
    cset x0, eq
    b    Ltl_out
Ltl_fail:
    mov  x0, #0
Ltl_out:
    ldp  d8, d9, [sp, #96]
    ldp  d10, d11, [sp, #112]
    LEAVE 48

// _t_room(float *dst, long n, long flags) — add _tx_buf (n samples) to dst as a room
// would: quieter, plus echoes 15 ms and 60 ms later; flags & 2 resamples by 1.0002
_t_room:
    ENTER 32
    stp  d8, d9, [sp, #96]
    stp  d10, d11, [sp, #112]
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    ADRL x9, _tx_buf
    ldr  x22, [x9]
    LDS  s8, Lk_gain
    LDS  s9, Lk_e1
    LDS  s10, Lk_e2
    LDD  d11, Lk_drift
    mov  x23, #0
Lrm_loop:
    cmp  x23, x20
    b.hs Lrm_done
    tbz  x21, #1, 1f
    ucvtf d0, x23                     // drifting clock: read between samples
    fmul d0, d0, d11
    fcvtzu x9, d0
    ucvtf d1, x9
    fsub d0, d0, d1
    fcvt s2, d0                       // fraction
    add  x10, x9, #1
    cmp  x10, x20
    b.hs Lrm_done
    ldr  s3, [x22, x9, lsl #2]
    ldr  s4, [x22, x10, lsl #2]
    fsub s4, s4, s3
    fmadd s0, s4, s2, s3
    b    2f
1:  ldr  s0, [x22, x23, lsl #2]
2:  fmul s1, s0, s8
    ldr  s5, [x19, x23, lsl #2]
    fadd s5, s5, s1
    str  s5, [x19, x23, lsl #2]
    add  x9, x23, #720
    fmul s1, s0, s9
    ldr  s5, [x19, x9, lsl #2]
    fadd s5, s5, s1
    str  s5, [x19, x9, lsl #2]
    mov  x9, #2880
    add  x9, x23, x9
    fmul s1, s0, s10
    ldr  s5, [x19, x9, lsl #2]
    fadd s5, s5, s1
    str  s5, [x19, x9, lsl #2]
    add  x23, x23, #1
    b    Lrm_loop
Lrm_done:
    ldp  d8, d9, [sp, #96]
    ldp  d10, d11, [sp, #112]
    LEAVE 32

// _t_hiss(long n, float *dst) — steady background hiss
_t_hiss:
    mov  x9, x0
    mov  x0, x1
    mov  x1, x9
    LDS  s0, Lk_hiss
    b    _t_noise

// _t_noise(float *dst, long n, float amp) — add noise
_t_noise:
    ENTER 16
    str  s0, [sp, #96]
    mov  x19, x0
    mov  x20, x1
1:  cbz  x20, 2f
    bl   _trand
    ldr  s1, [sp, #96]
    fmul s0, s0, s1
    ldr  s1, [x19]
    fadd s1, s1, s0
    str  s1, [x19], #4
    sub  x20, x20, #1
    b    1b
2:  LEAVE 16

// _t_feed(const float *x, long n) — into the receiver 1000 samples at a time
_t_feed:
    ENTER 0
    mov  x19, x0
    mov  x20, x1
1:  cbz  x20, 2f
    mov  x1, #1000
    cmp  x20, x1
    csel x1, x20, x1, lo
    sub  x20, x20, x1
    mov  x0, x19
    add  x19, x19, x1, lsl #2
    bl   _rx_feed
    b    1b
2:  LEAVE 0

// long _t_two(void) — a Chirp message and then a Fast one in the same stream
_t_two:
    ENTER 16
    ADRL x0, Ls_msg
    CALLC strlen
    mov  x22, x0
    mov  x0, #MODE_CHIRP
    ADRL x1, Ls_msg
    mov  x2, x22
    bl   _tx_render
    mov  x19, x0
    mov  x0, #MODE_FAST
    mov  x1, x22
    bl   _tx_samples
    add  x20, x19, x0
    mov  x9, #8000
    add  x20, x20, x9                 // total
    mov  x0, x20
    mov  x1, #4
    CALLC calloc
    mov  x21, x0
    add  x0, x21, #400
    mov  x1, x19
    mov  x2, #0
    bl   _t_room
    mov  x0, #MODE_FAST
    ADRL x1, Ls_msg
    mov  x2, x22
    bl   _tx_render
    mov  x1, x0
    add  x0, x21, x19, lsl #2
    add  x0, x0, #400
    mov  x2, #0
    bl   _t_room
    mov  x0, x20
    mov  x1, x21
    bl   _t_hiss
    ADRL x9, _t_count
    str  xzr, [x9]
    bl   _rx_reset
    mov  x0, x21
    mov  x1, x20
    bl   _t_feed
    mov  x0, x21
    CALLC free
    ADRL x9, _t_count
    ldr  x9, [x9]
    cmp  x9, #2
    b.ne 1f
    ADRL x9, _t_mode                  // the second one was Fast, and intact
    ldr  x9, [x9]
    cmp  x9, #MODE_FAST
    b.ne 1f
    ADRL x9, _t_len
    ldr  x9, [x9]
    cmp  x9, x22
    b.ne 1f
    ADRL x0, _t_got
    ADRL x1, Ls_msg
    mov  x2, x22
    CALLC memcmp
    cmp  w0, #0
    cset x0, eq
    LEAVE 16
1:  mov  x0, #0
    LEAVE 16

// long _t_quiet(void) — five seconds of hiss must not produce a message
_t_quiet:
    ENTER 0
    mov  x19, #0xA9C0
    movk x19, #0x3, lsl #16           // 240000
    mov  x0, x19
    mov  x1, #4
    CALLC calloc
    mov  x20, x0
    mov  x1, x19
    LDS  s0, Lk_quiet
    bl   _t_noise
    ADRL x9, _t_count
    str  xzr, [x9]
    bl   _rx_reset
    mov  x0, x20
    mov  x1, x19
    bl   _t_feed
    mov  x0, x20
    CALLC free
    ADRL x9, _t_count
    ldr  x9, [x9]
    cmp  x9, #0
    cset x0, eq
    LEAVE 0

// _t_highpass(float *x, long n) — one pole, in place. Leaf.
_t_highpass:
    LDS  s3, Lk_hp
    fmov s1, wzr                      // previous input
    fmov s2, wzr                      // previous output
    cbz  x1, 2f
1:  ldr  s0, [x0]
    fsub s4, s0, s1
    fadd s4, s4, s2
    fmul s4, s4, s3
    fmov s1, s0
    fmov s2, s4
    str  s4, [x0], #4
    subs x1, x1, #1
    b.ne 1b
2:  ret

// long _t_cut(void) — a Fast message that stops after a third: the receiver reports it lost
// within half a second of the silence, instead of waiting out the whole message
_t_cut:
    ENTER 16
    mov  x0, #MODE_FAST
    ADRL x1, _t_long
    mov  x2, #200
    bl   _tx_render
    mov  x19, x0                      // the whole message (about 4.5 s)
    mov  x20, #0xA9C0
    movk x20, #0x3, lsl #16           // a 5 s stream
    mov  x0, x20
    mov  x1, #4
    bl   _t_calloc
    mov  x21, x0
    mov  x22, #48000                  // only the first second of the message is played
    ADRL x9, _tx_buf
    ldr  x1, [x9]
    mov  x0, x21
    lsl  x2, x22, #2
    CALLC memcpy
    mov  x0, x20
    mov  x1, x21
    bl   _t_hiss
    ADRL x9, _t_count
    str  xzr, [x9]
    bl   _rx_reset
    mov  x0, x21                      // 1.5 s in: the message has stopped half a second ago
    mov  x1, #0x2000
    movk x1, #0x1, lsl #16            // 73728
    bl   _t_feed
    ADRL x9, _t_count
    ldr  x23, [x9]
    ADRL x9, _t_len
    ldr  x24, [x9]
    mov  x0, x21
    CALLC free
    cmp  x23, #1
    b.ne 1f
    cmp  x24, #-1
    cset x0, eq
    LEAVE 16
1:  mov  x0, #0
    LEAVE 16

_t_calloc:
    ENTER 0
    CALLC calloc
    LEAVE 0
