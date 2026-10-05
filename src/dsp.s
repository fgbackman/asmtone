// dsp.s — the signal processing in asmtone: a NEON Goertzel filter bank (how the
// receiver hears which notes are sounding) and the three voices that make the sound.

.include "macros.inc"

RODATA
.p2align 3
Lk_w_d:      .double 0.00013089969389957471   // 2*pi / 48000
.p2align 2
Lk_w:        .float 0.00013089969389957471
Lk_2pi:      .float 6.283185307179586
Lk_inv96:    .float 0.010416666666666666
Lk_harm:     .float 0.22, 0.10, 0.04          // piano overtones 2, 3, 4
Lk_peak:     .float 0.7

.text
.p2align 2

// ---------------------------------------------------------------------------
// void _gz_bank(const float *x, long n, const float *coef, long ntones,
//               float *energy, const float *win)
//   Goertzel energy of n samples at each of ntones frequencies (coef = 2cos(w)),
//   16 tones at a time in four NEON registers, two samples per loop with the
//   state registers trading places (no moves). n even, ntones a multiple of 16.
//   win (n floats) or 0 for a plain window. Leaf; uses v0-v7, v16-v31 only.
// ---------------------------------------------------------------------------
.globl _gz_bank
_gz_bank:
    mov  x9, #0
Lgz_block:
    cmp  x9, x3
    b.hs Lgz_done
    add  x10, x2, x9, lsl #2
    ld1  {v0.4s, v1.4s, v2.4s, v3.4s}, [x10]
    movi v4.16b, #0
    movi v5.16b, #0
    movi v6.16b, #0
    movi v7.16b, #0
    movi v16.16b, #0
    movi v17.16b, #0
    movi v18.16b, #0
    movi v19.16b, #0
    mov  x11, x0
    mov  x12, x5
    lsr  x13, x1, #1
    cbz  x13, Lgz_energy
    cbz  x5, Lgz_plain
Lgz_win:
    ldp  s20, s21, [x11], #8
    ldp  s22, s23, [x12], #8
    fmul s20, s20, s22
    fmul s21, s21, s23
    dup  v20.4s, v20.s[0]
    dup  v21.4s, v21.s[0]
    fsub v16.4s, v20.4s, v16.4s       // s0 = x - s2 + c*s1  -> into the s2 registers
    fsub v17.4s, v20.4s, v17.4s
    fsub v18.4s, v20.4s, v18.4s
    fsub v19.4s, v20.4s, v19.4s
    fmla v16.4s, v0.4s, v4.4s
    fmla v17.4s, v1.4s, v5.4s
    fmla v18.4s, v2.4s, v6.4s
    fmla v19.4s, v3.4s, v7.4s
    fsub v4.4s, v21.4s, v4.4s         // and the next sample back the other way
    fsub v5.4s, v21.4s, v5.4s
    fsub v6.4s, v21.4s, v6.4s
    fsub v7.4s, v21.4s, v7.4s
    fmla v4.4s, v0.4s, v16.4s
    fmla v5.4s, v1.4s, v17.4s
    fmla v6.4s, v2.4s, v18.4s
    fmla v7.4s, v3.4s, v19.4s
    subs x13, x13, #1
    b.ne Lgz_win
    b    Lgz_energy
Lgz_plain:
    ld1r {v20.4s}, [x11], #4
    ld1r {v21.4s}, [x11], #4
    fsub v16.4s, v20.4s, v16.4s
    fsub v17.4s, v20.4s, v17.4s
    fsub v18.4s, v20.4s, v18.4s
    fsub v19.4s, v20.4s, v19.4s
    fmla v16.4s, v0.4s, v4.4s
    fmla v17.4s, v1.4s, v5.4s
    fmla v18.4s, v2.4s, v6.4s
    fmla v19.4s, v3.4s, v7.4s
    fsub v4.4s, v21.4s, v4.4s
    fsub v5.4s, v21.4s, v5.4s
    fsub v6.4s, v21.4s, v6.4s
    fsub v7.4s, v21.4s, v7.4s
    fmla v4.4s, v0.4s, v16.4s
    fmla v5.4s, v1.4s, v17.4s
    fmla v6.4s, v2.4s, v18.4s
    fmla v7.4s, v3.4s, v19.4s
    subs x13, x13, #1
    b.ne Lgz_plain
Lgz_energy:                           // |X|^2 = s1^2 + s2^2 - c*s1*s2
    fmul v24.4s, v4.4s, v4.4s
    fmul v25.4s, v5.4s, v5.4s
    fmul v26.4s, v6.4s, v6.4s
    fmul v27.4s, v7.4s, v7.4s
    fmla v24.4s, v16.4s, v16.4s
    fmla v25.4s, v17.4s, v17.4s
    fmla v26.4s, v18.4s, v18.4s
    fmla v27.4s, v19.4s, v19.4s
    fmul v28.4s, v4.4s, v16.4s
    fmul v29.4s, v5.4s, v17.4s
    fmul v30.4s, v6.4s, v18.4s
    fmul v31.4s, v7.4s, v19.4s
    fmls v24.4s, v28.4s, v0.4s
    fmls v25.4s, v29.4s, v1.4s
    fmls v26.4s, v30.4s, v2.4s
    fmls v27.4s, v31.4s, v3.4s
    add  x10, x4, x9, lsl #2
    st1  {v24.4s, v25.4s, v26.4s, v27.4s}, [x10]
    add  x9, x9, #16
    b    Lgz_block
Lgz_done:
    ret

// ---------------------------------------------------------------------------
// void _v_piano(float *dst, long n, float freq, float amp)
//   Adds one piano-like note (fundamental + three overtones, quick attack, ringing
//   decay from _penv) to dst, at most min(n, PLEN) samples. The sine comes from a
//   rotating vector in double precision; overtones from the Chebyshev identities.
// ---------------------------------------------------------------------------
.globl _v_piano
_v_piano:
    ENTER 32
    mov  x19, x0
    mov  x20, x1
    str  s1, [sp, #96]
    fcvt d0, s0
    LDD  d1, Lk_w_d
    fmul d0, d0, d1
    str  d0, [sp, #104]
    CALLC cos
    str  d0, [sp, #112]
    ldr  d0, [sp, #104]
    CALLC sin
    fmov d17, d0                      // sin(w)
    ldr  d16, [sp, #112]              // cos(w)
    ldr  s20, [sp, #96]               // amp
    ADRL x12, Lk_harm
    ldp  s21, s22, [x12]
    ldr  s23, [x12, #8]
    ADRL x9, _penv
    mov  x10, #PLEN
    cmp  x20, x10
    csel x20, x20, x10, lo
    fmov d18, #1.0                    // c = cos(phase)
    fmov d19, xzr                     // s = sin(phase)
    mov  x11, #0
Lvp_loop:
    cmp  x11, x20
    b.hs Lvp_done
    fcvt s0, d18
    fcvt s1, d19
    fmul s2, s0, s0                   // c^2
    fmul s3, s1, s0
    fadd s3, s3, s3                   // sin 2p = 2sc
    fmov s4, #4.0
    fmul s4, s4, s2
    fmov s5, #1.0
    fsub s4, s4, s5
    fmul s4, s4, s1                   // sin 3p = s(4c^2 - 1)
    fadd s5, s2, s2
    fmov s6, #1.0
    fsub s5, s5, s6                   // cos 2p
    fmul s5, s5, s3
    fadd s5, s5, s5                   // sin 4p = 2 sin2p cos2p
    fmadd s6, s3, s21, s1
    fmadd s6, s4, s22, s6
    fmadd s6, s5, s23, s6
    ldr  s7, [x9, x11, lsl #2]
    fmul s6, s6, s7
    fmul s6, s6, s20
    ldr  s7, [x19, x11, lsl #2]
    fadd s7, s7, s6
    str  s7, [x19, x11, lsl #2]
    fmul d2, d18, d16                 // rotate by w
    fmsub d2, d19, d17, d2
    fmul d3, d19, d16
    fmadd d3, d18, d17, d3
    fmov d18, d2
    fmov d19, d3
    add  x11, x11, #1
    b    Lvp_loop
Lvp_done:
    LEAVE 32

// ---------------------------------------------------------------------------
// void _v_tone(float *dst, long n, float f0, float f1, long glide, float amp)
//   Adds a sine that slides from f0 to f1 over the first `glide` samples (a chirp)
//   and then holds f1, with 2 ms ramps at both ends so symbols don't click.
// ---------------------------------------------------------------------------
.globl _v_tone
_v_tone:
    ENTER 48
    stp  d8, d9, [sp, #96]
    stp  d10, d11, [sp, #112]
    stp  d12, d13, [sp, #128]
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    fmov s8, s0
    fmov s9, s1
    fmov s10, s2
    fmov s11, wzr                     // phase
    LDS  s12, Lk_w
    LDS  s13, Lk_2pi
    mov  x22, #0
Lvt_loop:
    cmp  x22, x20
    b.hs Lvt_done
    fmov s0, s9
    cmp  x22, x21
    b.hs 1f
    ucvtf s1, x22
    ucvtf s2, x21
    fdiv s1, s1, s2
    fsub s2, s9, s8
    fmadd s0, s2, s1, s8
1:  fmul s0, s0, s12
    fadd s11, s11, s0
    fcmp s11, s13
    b.lt 2f
    fsub s11, s11, s13
2:  fmov s0, s11
    CALLC sinf
    fmul s0, s0, s10
    mov  x9, #96
    cmp  x22, x9
    b.hs 3f
    ucvtf s1, x22
    LDS  s2, Lk_inv96
    fmul s1, s1, s2
    fmul s0, s0, s1
3:  sub  x10, x20, x22
    cmp  x10, x9
    b.hi 4f
    ucvtf s1, x10
    LDS  s2, Lk_inv96
    fmul s1, s1, s2
    fmul s0, s0, s1
4:  ldr  s1, [x19, x22, lsl #2]
    fadd s1, s1, s0
    str  s1, [x19, x22, lsl #2]
    add  x22, x22, #1
    b    Lvt_loop
Lvt_done:
    ldp  d8, d9, [sp, #96]
    ldp  d10, d11, [sp, #112]
    ldp  d12, d13, [sp, #128]
    LEAVE 48

// ---------------------------------------------------------------------------
// void _normalize(float *x, long n) — scale so the loudest sample is 0.7
// ---------------------------------------------------------------------------
.globl _normalize
_normalize:
    cbz  x1, 9f
    fmov s0, wzr
    mov  x9, x0
    mov  x10, x1
1:  ldr  s1, [x9], #4
    fabs s1, s1
    fmax s0, s0, s1
    subs x10, x10, #1
    b.ne 1b
    fcmp s0, #0.0
    b.eq 9f
    LDS  s2, Lk_peak
    fdiv s2, s2, s0
2:  ldr  s1, [x0]
    fmul s1, s1, s2
    str  s1, [x0], #4
    subs x1, x1, #1
    b.ne 2b
9:  ret

// float _peak_abs(const float *x, long n)
.globl _peak_abs
_peak_abs:
    fmov s0, wzr
    cbz  x1, 9f
1:  ldr  s1, [x0], #4
    fabs s1, s1
    fmax s0, s0, s1
    subs x1, x1, #1
    b.ne 1b
9:  ret
