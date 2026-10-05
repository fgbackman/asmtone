// fec.s — error correction for asmtone: Reed–Solomon over GF(256) with any number
// of parity bytes (2..32), CRC-16/X.25, and data whitening.
//
// A block is data then parity, first byte = highest power. Roots alpha^0 .. alpha^(nr-1),
// so a block with nr parity bytes repairs up to nr/2 damaged bytes.
// (The decoder is the one from asmmesh's fm_fec.s, with the parity count made a parameter.)

.include "macros.inc"

.data
.p2align 4
.globl _gf_exp
_gf_exp:    .space 512               // alpha^i, twice over so sums of logs need no mod
.globl _gf_log
_gf_log:    .space 256
_rs_g:      .space 64                // generator g_0 .. g_(nr-1) (g_nr = 1)
_rs_S:      .space 64
_rs_Lam:    .space 64
_rs_B:      .space 64
_rs_T:      .space 64
_rs_Om:     .space 64
_rs_pos:    .space 64
.p2align 3
_rs_gnr:    .quad 0                  // nr the generator was built for

.text
.p2align 2

// void _gf_init(void) — exp/log tables for x^8 + x^4 + x^3 + x^2 + 1
.globl _gf_init
_gf_init:
    ADRL x0, _gf_exp
    ADRL x1, _gf_log
    mov  w2, #1
    mov  x3, #0
    mov  w5, #0x11d
1:  strb w2, [x0, x3]
    add  x4, x3, #255
    strb w2, [x0, x4]
    strb w3, [x1, x2]
    lsl  w2, w2, #1
    tst  w2, #0x100
    b.eq 2f
    eor  w2, w2, w5
2:  add  x3, x3, #1
    cmp  x3, #255
    b.lo 1b
    strb wzr, [x1]
    ADRL x0, _rs_gnr
    str  xzr, [x0]
    ret

// w0 = w0 * w1        (touches only x0, x9-x11)
_gfm:
    cbz  w0, 1f
    cbz  w1, 2f
    ADRL x9, _gf_log
    ldrb w10, [x9, w0, uxtw]
    ldrb w11, [x9, w1, uxtw]
    add  w10, w10, w11
    ADRL x9, _gf_exp
    ldrb w0, [x9, w10, uxtw]
    ret
2:  mov  w0, #0
1:  ret

// w0 = w0 / w1 (w1 != 0)
_gfd:
    cbz  w0, 1f
    ADRL x9, _gf_log
    ldrb w10, [x9, w0, uxtw]
    ldrb w11, [x9, w1, uxtw]
    sub  w10, w10, w11
    add  w10, w10, #255
    ADRL x9, _gf_exp
    ldrb w0, [x9, w10, uxtw]
1:  ret

// w0 = alpha^(-w0), 0 <= w0 < 255
_gfinv_pow:
    mov  w10, #255
    sub  w0, w10, w0
    ADRL x9, _gf_exp
    ldrb w0, [x9, w0, uxtw]
    ret

// void _rs_gen(long nr) — g(x) = (x - a^0)(x - a^1)...(x - a^(nr-1))
_rs_gen:
    ENTER 0
    ADRL x8, _rs_gnr
    ldr  x9, [x8]
    cmp  x9, x0
    b.eq Lgen_done
    str  x0, [x8]
    mov  x19, x0
    ADRL x20, _rs_T
    mov  x0, x20
    mov  w1, #0
    mov  x2, #64
    CALLC memset
    mov  w9, #1
    strb w9, [x20]
    mov  x21, #0
Lgen_i:
    cmp  x21, x19
    b.hs Lgen_copy
    ADRL x9, _gf_exp
    ldrb w22, [x9, x21]
    add  x23, x21, #1
Lgen_j:
    ldrb w0, [x20, x23]
    mov  w1, w22
    bl   _gfm
    cbz  x23, Lgen_j0
    sub  x9, x23, #1
    ldrb w9, [x20, x9]
    eor  w0, w0, w9
    strb w0, [x20, x23]
    sub  x23, x23, #1
    b    Lgen_j
Lgen_j0:
    strb w0, [x20]
    add  x21, x21, #1
    b    Lgen_i
Lgen_copy:
    ADRL x0, _rs_g
    mov  x1, x20
    mov  x2, #64
    CALLC memcpy
Lgen_done:
    LEAVE 0

// void _rs_encode(const uint8 *data, long k, uint8 *parity, long nr)
.globl _rs_encode
_rs_encode:
    ENTER 0
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    mov  x24, x3
    mov  x0, x24
    bl   _rs_gen
    mov  x0, x21
    mov  w1, #0
    mov  x2, x24
    CALLC memset
    mov  x22, #0
Lre_byte:
    cmp  x22, x20
    b.hs Lre_done
    ldrb w23, [x19, x22]
    ldrb w9, [x21]
    eor  w23, w23, w9                 // feedback
    sub  x13, x24, #1
    mov  x12, #0
Lre_shift:
    cmp  x12, x13
    b.hs Lre_shift_end
    add  x10, x12, #1
    ldrb w11, [x21, x10]
    strb w11, [x21, x12]
    mov  x12, x10
    b    Lre_shift
Lre_shift_end:
    strb wzr, [x21, x13]
    cbz  w23, Lre_next
    mov  x12, #0                      // rem[j] ^= f * g[nr-1-j]
Lre_mix:
    sub  x13, x24, #1
    sub  x13, x13, x12
    ADRL x10, _rs_g
    ldrb w1, [x10, x13]
    mov  w0, w23
    bl   _gfm
    ldrb w9, [x21, x12]
    eor  w9, w9, w0
    strb w9, [x21, x12]
    add  x12, x12, #1
    cmp  x12, x24
    b.lo Lre_mix
Lre_next:
    add  x22, x22, #1
    b    Lre_byte
Lre_done:
    LEAVE 0

// long _rs_decode(uint8 *block, long n, long nr) -> bytes repaired (0 clean), or -1
.globl _rs_decode
_rs_decode:
    ENTER 48                          // [96] p  [104] coef  [112] count  [120] d  [128] nr
    mov  x19, x0
    mov  x20, x1
    str  x2, [sp, #128]
    cmp  x20, x2
    b.ls Lrd_fail
    cmp  x20, #255
    b.hi Lrd_fail
    mov  x21, #0                      // syndromes S[i] = r(alpha^i)
    mov  x24, #0
Lrd_syn:
    ADRL x9, _gf_exp
    ldrb w22, [x9, x21]
    mov  w0, #0
    mov  x23, #0
Lrd_syn_j:
    mov  w1, w22
    bl   _gfm
    ldrb w9, [x19, x23]
    eor  w0, w0, w9
    add  x23, x23, #1
    cmp  x23, x20
    b.lo Lrd_syn_j
    ADRL x9, _rs_S
    strb w0, [x9, x21]
    orr  w24, w24, w0
    add  x21, x21, #1
    ldr  x9, [sp, #128]
    cmp  x21, x9
    b.lo Lrd_syn
    cbnz w24, Lrd_bm
    mov  x0, #0
    LEAVE 48

Lrd_bm:                               // Berlekamp–Massey
    ADRL x0, _rs_Lam
    mov  w1, #0
    mov  x2, #64
    CALLC memset
    ADRL x0, _rs_B
    mov  w1, #0
    mov  x2, #64
    CALLC memset
    mov  w9, #1
    ADRL x10, _rs_Lam
    strb w9, [x10]
    ADRL x10, _rs_B
    strb w9, [x10]
    mov  x22, #0                      // L
    mov  x23, #1                      // m
    mov  x24, #1                      // b
    mov  x21, #0                      // k
Lrd_k:
    ADRL x9, _rs_S
    ldrb w9, [x9, x21]
    str  x9, [sp, #120]
    mov  x9, #1
    str  x9, [sp, #112]
Lrd_d:
    ldr  x9, [sp, #112]
    cmp  x9, x22
    b.hi Lrd_d_end
    ADRL x10, _rs_Lam
    ldrb w0, [x10, x9]
    sub  x11, x21, x9
    ADRL x10, _rs_S
    ldrb w1, [x10, x11]
    bl   _gfm
    ldr  x9, [sp, #120]
    eor  x9, x9, x0
    str  x9, [sp, #120]
    ldr  x9, [sp, #112]
    add  x9, x9, #1
    str  x9, [sp, #112]
    b    Lrd_d
Lrd_d_end:
    ldr  x9, [sp, #120]
    cbnz x9, Lrd_upd
    add  x23, x23, #1
    b    Lrd_k_next
Lrd_upd:
    mov  w0, w9
    mov  w1, w24
    bl   _gfd
    str  x0, [sp, #104]
    ADRL x0, _rs_T
    ADRL x1, _rs_Lam
    mov  x2, #64
    CALLC memcpy
    mov  x9, #0
    str  x9, [sp, #112]
Lrd_upd_i:
    ldr  x9, [sp, #112]
    ldr  x10, [sp, #128]
    sub  x10, x10, x23
    cmp  x9, x10
    b.gt Lrd_upd_end
    ADRL x10, _rs_B
    ldrb w1, [x10, x9]
    ldr  x0, [sp, #104]
    bl   _gfm
    ldr  x9, [sp, #112]
    add  x10, x9, x23
    ADRL x11, _rs_Lam
    ldrb w12, [x11, x10]
    eor  w12, w12, w0
    strb w12, [x11, x10]
    add  x9, x9, #1
    str  x9, [sp, #112]
    b    Lrd_upd_i
Lrd_upd_end:
    lsl  x9, x22, #1
    cmp  x9, x21
    b.hi Lrd_upd_m
    add  x22, x21, #1
    sub  x22, x22, x9, lsr #1
    ADRL x0, _rs_B
    ADRL x1, _rs_T
    mov  x2, #64
    CALLC memcpy
    ldr  x24, [sp, #120]
    mov  x23, #1
    b    Lrd_k_next
Lrd_upd_m:
    add  x23, x23, #1
Lrd_k_next:
    add  x21, x21, #1
    ldr  x9, [sp, #128]
    cmp  x21, x9
    b.lo Lrd_k
    lsr  x9, x9, #1
    cmp  x22, x9                      // more than nr/2 errors: beyond repair
    b.hi Lrd_fail

    mov  x21, #0                      // Chien search
    str  xzr, [sp, #112]
Lrd_ch:
    cmp  x21, x20
    b.hs Lrd_ch_end
    mov  w0, w21
    bl   _gfinv_pow
    mov  w23, w0
    mov  w0, #0
    mov  x24, x22
Lrd_ch_i:
    mov  w1, w23
    bl   _gfm
    ADRL x9, _rs_Lam
    ldrb w9, [x9, x24]
    eor  w0, w0, w9
    cbz  x24, Lrd_ch_v
    sub  x24, x24, #1
    b    Lrd_ch_i
Lrd_ch_v:
    cbnz w0, Lrd_ch_next
    ldr  x9, [sp, #112]
    ldr  x10, [sp, #128]
    cmp  x9, x10
    b.hs Lrd_fail
    ADRL x10, _rs_pos
    strb w21, [x10, x9]
    add  x9, x9, #1
    str  x9, [sp, #112]
Lrd_ch_next:
    add  x21, x21, #1
    b    Lrd_ch
Lrd_ch_end:
    ldr  x9, [sp, #112]
    cmp  x9, x22
    b.ne Lrd_fail

    mov  x21, #0                      // Omega = S * Lam mod x^nr
Lrd_om:
    mov  x23, #0
    str  xzr, [sp, #120]
Lrd_om_j:
    cmp  x23, x21
    b.hi Lrd_om_set
    sub  x9, x21, x23
    ADRL x10, _rs_S
    ldrb w0, [x10, x9]
    ADRL x10, _rs_Lam
    ldrb w1, [x10, x23]
    bl   _gfm
    ldr  x9, [sp, #120]
    eor  x9, x9, x0
    str  x9, [sp, #120]
    add  x23, x23, #1
    b    Lrd_om_j
Lrd_om_set:
    ldr  x9, [sp, #120]
    ADRL x10, _rs_Om
    strb w9, [x10, x21]
    add  x21, x21, #1
    ldr  x9, [sp, #128]
    cmp  x21, x9
    b.lo Lrd_om

    mov  x21, #0                      // Forney
Lrd_fx:
    cmp  x21, x22
    b.hs Lrd_ok
    ADRL x9, _rs_pos
    ldrb w9, [x9, x21]
    str  x9, [sp, #96]
    mov  w0, w9
    bl   _gfinv_pow
    mov  w23, w0                      // xinv
    mov  w0, #0
    ldr  x24, [sp, #128]
    sub  x24, x24, #1
Lrd_num:
    mov  w1, w23
    bl   _gfm
    ADRL x9, _rs_Om
    ldrb w9, [x9, x24]
    eor  w0, w0, w9
    cbz  x24, Lrd_num_end
    sub  x24, x24, #1
    b    Lrd_num
Lrd_num_end:
    str  x0, [sp, #104]
    mov  w0, w23
    mov  w1, w23
    bl   _gfm
    str  x0, [sp, #112]
    mov  x24, #1
    mov  x9, #1
    str  x9, [sp, #120]
    mov  w23, #0
Lrd_den:
    cmp  x24, x22
    b.hi Lrd_den_end
    ADRL x9, _rs_Lam
    ldrb w0, [x9, x24]
    ldr  x1, [sp, #120]
    bl   _gfm
    eor  w23, w23, w0
    ldr  x0, [sp, #120]
    ldr  x1, [sp, #112]
    bl   _gfm
    str  x0, [sp, #120]
    add  x24, x24, #2
    b    Lrd_den
Lrd_den_end:
    cbz  w23, Lrd_fail
    ldr  x0, [sp, #104]
    mov  w1, w23
    bl   _gfd
    mov  w23, w0
    ldr  x9, [sp, #96]
    ADRL x10, _gf_exp
    ldrb w1, [x10, x9]
    mov  w0, w23
    bl   _gfm
    ldr  x9, [sp, #96]
    sub  x10, x20, #1
    sub  x10, x10, x9
    ldrb w11, [x19, x10]
    eor  w11, w11, w0
    strb w11, [x19, x10]
    add  x21, x21, #1
    b    Lrd_fx
Lrd_ok:
    mov  x0, x22
    LEAVE 48
Lrd_fail:
    mov  x0, #-1
    LEAVE 48

// w0 = CRC-16/X.25 of (x0, x1)
.globl _crc16
_crc16:
    mov  w2, #0xFFFF
    mov  w5, #0x8408
    cbz  x1, 3f
1:  ldrb w3, [x0], #1
    eor  w2, w2, w3
    mov  w4, #8
2:  tst  w2, #1
    lsr  w2, w2, #1
    eor  w3, w2, w5
    csel w2, w3, w2, ne
    subs w4, w4, #1
    b.ne 2b
    subs x1, x1, #1
    b.ne 1b
3:  mov  w3, #0xFFFF
    eor  w0, w2, w3
    ret

// void _whiten(uint8 *buf, long n) — XOR with a fixed pseudo-random stream (its own inverse),
// so long runs of the same byte don't become the same note over and over
.globl _whiten
_whiten:
    mov  w2, #0x5EED
    mov  w3, #0x4E6D
    movk w3, #0x41C6, lsl #16         // 1103515245
    mov  w4, #12345
    cbz  x1, 2f
1:  madd w2, w2, w3, w4
    lsr  w5, w2, #16
    ldrb w6, [x0]
    eor  w6, w6, w5
    strb w6, [x0], #1
    subs x1, x1, #1
    b.ne 1b
2:  ret
