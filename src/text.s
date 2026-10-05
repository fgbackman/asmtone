// text.s — shrinking messages before they're played: a static Huffman code tuned for
// English (space and common letters 3-5 bits, any other byte still codable, emoji too).
//
// A packed message is one flag byte, then:
//   1  the Huffman bits, high bit first, ending with the end-of-text code, zero-padded
//   0  the bytes as they were (used whenever packing wouldn't make it shorter)

.include "macros.inc"

RODATA
.include "text_tables.inc"

.text
.p2align 2

// long _pack(const uint8 *in, long n, uint8 *out, long cap) -> bytes written, or -1 if they
// won't fit in cap. Leaf.
.globl _pack
_pack:
    ADRL x9, Lhuf_len                 // how many bits, packed?
    mov  x10, #0
    mov  x11, #0
1:  cmp  x11, x1
    b.hs 2f
    ldrb w12, [x0, x11]
    ldrb w12, [x9, x12]
    add  x10, x10, x12
    add  x11, x11, #1
    b    1b
2:  mov  x12, #HUF_EOT
    ldrb w12, [x9, x12]
    add  x10, x10, x12
    add  x10, x10, #7
    lsr  x10, x10, #3
    add  x10, x10, #1                 // packed size
    add  x11, x1, #1                  // plain size
    cmp  x10, x11
    b.hs Lpk_raw
    cmp  x10, x3
    b.hi Lpk_no
    mov  w12, #1
    strb w12, [x2]
    mov  x4, #1                       // out position
    mov  x5, #0                       // bit accumulator
    mov  x6, #0                       // bits in it
    ADRL x7, Lhuf_code
    mov  x11, #0
3:  cmp  x11, x1                      // each byte, then end-of-text
    b.hi 6f
    mov  x12, #HUF_EOT
    b.eq 4f
    ldrb w12, [x0, x11]
4:  ldr  w13, [x7, x12, lsl #2]
    ldrb w14, [x9, x12]
    lsl  x5, x5, x14
    orr  x5, x5, x13
    add  x6, x6, x14
5:  cmp  x6, #8
    b.lo 7f
    sub  x6, x6, #8
    lsr  x15, x5, x6
    strb w15, [x2, x4]
    add  x4, x4, #1
    b    5b
7:  add  x11, x11, #1
    b    3b
6:  cbz  x6, 8f                       // the last few bits, padded with zeros
    mov  x15, #8
    sub  x15, x15, x6
    lsl  x5, x5, x15
    strb w5, [x2, x4]
    add  x4, x4, #1
8:  mov  x0, x4
    ret
Lpk_raw:
    cmp  x11, x3
    b.hi Lpk_no
    strb wzr, [x2]
    mov  x11, #0
9:  cmp  x11, x1
    b.hs 10f
    ldrb w12, [x0, x11]
    add  x13, x11, #1
    strb w12, [x2, x13]
    add  x11, x11, #1
    b    9b
10: add  x0, x1, #1
    ret
Lpk_no:
    mov  x0, #-1
    ret

// long _pack_len(const uint8 *in, long n) -> the size _pack would write. Leaf.
.globl _pack_len
_pack_len:
    ADRL x9, Lhuf_len
    mov  x10, #0
    mov  x11, #0
1:  cmp  x11, x1
    b.hs 2f
    ldrb w12, [x0, x11]
    ldrb w12, [x9, x12]
    add  x10, x10, x12
    add  x11, x11, #1
    b    1b
2:  mov  x12, #HUF_EOT
    ldrb w12, [x9, x12]
    add  x10, x10, x12
    add  x10, x10, #7
    lsr  x10, x10, #3
    add  x10, x10, #1
    add  x11, x1, #1
    cmp  x10, x11
    csel x0, x10, x11, lo
    ret

// long _unpack(const uint8 *in, long n, uint8 *out, long cap) -> the text's length, or -1
// if it isn't a well-formed packed message. Leaf.
.globl _unpack
_unpack:
    cbz  x1, Lup_no
    ldrb w9, [x0]
    cbnz w9, 1f
    sub  x10, x1, #1                  // stored plain
    cmp  x10, x3
    b.hi Lup_no
    mov  x11, #0
2:  cmp  x11, x10
    b.hs 3f
    add  x12, x11, #1
    ldrb w12, [x0, x12]
    strb w12, [x2, x11]
    add  x11, x11, #1
    b    2b
3:  mov  x0, x10
    ret
1:  cmp  w9, #1
    b.ne Lup_no
    ADRL x4, Lhuf_first
    ADRL x5, Lhuf_count
    ADRL x6, Lhuf_offs
    ADRL x7, Lhuf_syms
    mov  x8, #0                       // out position
    mov  w10, #0                      // code so far
    mov  x11, #0                      // its length
    mov  x12, #1                      // in position
4:  cmp  x12, x1
    b.hs Lup_no                       // ran out before end-of-text
    ldrb w13, [x0, x12]
    mov  x14, #7                      // bit 7 .. 0
5:  lsr  w15, w13, w14
    and  w15, w15, #1
    orr  w10, w15, w10, lsl #1
    add  x11, x11, #1
    cmp  x11, #HUF_MAX
    b.hi Lup_no
    ldr  w15, [x4, x11, lsl #2]
    sub  w15, w10, w15                // index among the codes of this length
    ldr  w9, [x5, x11, lsl #2]
    cmp  w15, w9
    b.hs 6f
    ldr  w9, [x6, x11, lsl #2]
    add  w15, w15, w9
    ldrh w15, [x7, x15, lsl #1]       // the symbol
    cmp  w15, #HUF_EOT
    b.eq 7f
    cmp  x8, x3
    b.hs Lup_no
    strb w15, [x2, x8]
    add  x8, x8, #1
    mov  w10, #0
    mov  x11, #0
6:  cbz  x14, 8f
    sub  x14, x14, #1
    b    5b
8:  add  x12, x12, #1
    b    4b
7:  mov  x0, x8
    ret
Lup_no:
    mov  x0, #-1
    ret
