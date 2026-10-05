// audio.s — asmtone's speaker and microphone, through AudioToolbox's AudioQueue.
// Both run 48 kHz mono float; AudioQueue converts to whatever the hardware uses.
// Callbacks arrive on AudioQueue's own threads; anything for the window is passed
// to the main thread with performSelectorOnMainThread.

.include "macros.inc"

.set OUT_FRAMES, 4096
.set REC_N,      2880000             // the last 60 s of microphone sound, for Save Last Minute of Sound
.set IN_FRAMES,  2048
// AudioQueueBuffer
.set AB_DATA,    8
.set AB_SIZE,    16

.section __TEXT,__const
.p2align 3
Lasbd:      .double 48000.0
            .word 0x6C70636D             // 'lpcm'
            .word 9                      // float | packed
            .word 4, 1, 4, 1, 32, 0      // bytes/packet, frames/packet, bytes/frame, channels, bits

.section __TEXT,__cstring
Ls_played:  .asciz "played:"
Ls_heard:   .asciz "heard:"
Ls_NSData:  .asciz "NSData"
Ls_alloc:   .asciz "alloc"
Ls_initB:   .asciz "initWithBytes:length:"
Ls_release: .asciz "release"
Ls_perform: .asciz "performSelectorOnMainThread:withObject:waitUntilDone:"
Ls_wb:      .asciz "wb"

.data
.p2align 3
_aq_out:    .quad 0
_aq_in:     .quad 0
_out_buf:   .quad 0, 0, 0
_in_buf:    .quad 0, 0, 0
_tx_len:    .quad 0
_tx_pos:    .quad 0
_tx_live:   .quad 0                  // buffers out with the speaker
.globl _tx_active
_tx_active: .quad 0
.globl _audio_ctl
_audio_ctl: .quad 0                  // who hears about it (the controller)
_sinkbuf:   .space 2064
_rec_buf:   .quad 0
_rec_i:     .quad 0                  // where the next sample goes
_rec_tot:   .quad 0                  // samples ever recorded
Lwav_hdr:   .ascii "RIFF"
            .word 0
            .ascii "WAVEfmt "
            .word 16
            .short 1, 1
            .word 48000, 96000
            .short 2, 16
            .ascii "data"
            .word 0

.text
.p2align 2

// long _audio_init(void) — the output queue and its buffers; 0 = fine, else OSStatus
.globl _audio_init
_audio_init:
    ENTER 0
    ADRL x0, Lasbd
    ADRL x1, _out_cb
    mov  x2, #0
    mov  x3, #0
    mov  x4, #0
    mov  w5, #0
    ADRL x6, _aq_out
    bl   _AudioQueueNewOutput
    cbnz w0, 9f
    mov  x19, #0
1:  ADRL x9, _aq_out
    ldr  x0, [x9]
    mov  w1, #(OUT_FRAMES * 4)
    ADRL x2, _out_buf
    add  x2, x2, x19, lsl #3
    bl   _AudioQueueAllocateBuffer
    cbnz w0, 9f
    add  x19, x19, #1
    cmp  x19, #3
    b.lo 1b
    mov  x0, #(REC_N & 0xffff)
    movk x0, #(REC_N >> 16), lsl #16
    mov  x1, #4
    bl   _calloc
    ADRL x9, _rec_buf
    str  x0, [x9]
    ADRL x9, _rx_sink                // the receiver reports to us
    ADRL x10, _app_sink
    str  x10, [x9]
    mov  x0, #0
9:  sxtw x0, w0
    LEAVE 0

// long _audio_play(long samples) — play _tx_buf; 1 started, 0 busy or failed
.globl _audio_play
_audio_play:
    ENTER 0
    ADRL x9, _tx_active
    ldr  x10, [x9]
    cbnz x10, 8f
    ADRL x10, _aq_out
    ldr  x10, [x10]
    cbz  x10, 8f
    ADRL x10, _tx_len
    str  x0, [x10]
    ADRL x10, _tx_pos
    str  xzr, [x10]
    ADRL x10, _tx_live
    str  xzr, [x10]
    mov  x10, #1
    str  x10, [x9]
    ADRL x9, _rx_mute                // don't decode ourselves
    str  x10, [x9]
    mov  x19, #0
1:  ADRL x9, _out_buf
    ldr  x0, [x9, x19, lsl #3]
    bl   _out_fill
    add  x19, x19, #1
    cmp  x19, #3
    b.lo 1b
    ADRL x9, _aq_out
    ldr  x0, [x9]
    mov  x1, #0
    bl   _AudioQueueStart
    cbnz w0, 7f
    mov  x0, #1
    LEAVE 0
7:  ADRL x9, _tx_active
    str  xzr, [x9]
    ADRL x9, _rx_mute
    str  xzr, [x9]
8:  mov  x0, #0
    LEAVE 0

// void _audio_stop(void) — stop playing now
.globl _audio_stop
_audio_stop:
    ENTER 0
    ADRL x9, _tx_active
    str  xzr, [x9]
    ADRL x9, _aq_out
    ldr  x0, [x9]
    cbz  x0, 1f
    mov  w1, #1
    bl   _AudioQueueStop
1:  LEAVE 0

// long _out_fill(AudioQueueBufferRef) — next piece of the message into it; 1 if queued
_out_fill:
    ENTER 0
    mov  x19, x0
    ADRL x9, _tx_len
    ldr  x10, [x9]
    ADRL x9, _tx_pos
    ldr  x11, [x9]
    subs x12, x10, x11
    b.le 8f
    mov  x13, #OUT_FRAMES
    cmp  x12, x13
    csel x20, x12, x13, lo
    ldr  x0, [x19, #AB_DATA]
    ADRL x9, _tx_buf
    ldr  x1, [x9]
    add  x1, x1, x11, lsl #2
    lsl  x2, x20, #2
    str  w2, [x19, #AB_SIZE]
    add  x11, x11, x20
    ADRL x9, _tx_pos
    str  x11, [x9]
    bl   _memcpy
    ADRL x9, _aq_out
    ldr  x0, [x9]
    mov  x1, x19
    mov  w2, #0
    mov  x3, #0
    bl   _AudioQueueEnqueueBuffer
    cbnz w0, 8f
    ADRL x9, _tx_live
    ldr  x10, [x9]
    add  x10, x10, #1
    str  x10, [x9]
    mov  x0, #1
    LEAVE 0
8:  mov  x0, #0
    LEAVE 0

// output callback(void *user, AudioQueueRef aq, AudioQueueBufferRef buf)
_out_cb:
    ENTER 0
    mov  x19, x1
    mov  x20, x2
    ADRL x9, _tx_active
    ldr  x9, [x9]
    cbz  x9, 9f
    ADRL x9, _tx_live
    ldr  x10, [x9]
    sub  x10, x10, #1
    str  x10, [x9]
    mov  x0, x20
    bl   _out_fill
    cbnz x0, 9f
    ADRL x9, _tx_live
    ldr  x10, [x9]
    cbnz x10, 9f
    ADRL x9, _tx_active               // everything has played
    str  xzr, [x9]
    mov  x0, x19
    mov  w1, #0
    bl   _AudioQueueStop
    bl   _objc_autoreleasePoolPush
    mov  x21, x0
    ADRL x9, _audio_ctl
    ldr  x0, [x9]
    cbz  x0, 8f
    ADRL x0, Ls_played
    bl   _sel_registerName
    mov  x22, x0
    ADRL x9, _audio_ctl
    ldr  x0, [x9]
    mov  x2, x22
    mov  x3, #0
    mov  x4, #0
    ADRL x1, Ls_perform
    bl   _msg3
8:  mov  x0, x21
    bl   _objc_autoreleasePoolPop
9:  LEAVE 0

// long _audio_listen(long on) — start/stop the microphone; 0 = fine, else OSStatus
.globl _audio_listen
_audio_listen:
    ENTER 0
    cbz  x0, Lal_off
    ADRL x9, _aq_in
    ldr  x9, [x9]
    cbnz x9, Lal_ok
    bl   _rx_reset
    ADRL x0, Lasbd
    ADRL x1, _in_cb
    mov  x2, #0
    mov  x3, #0
    mov  x4, #0
    mov  w5, #0
    ADRL x6, _aq_in
    bl   _AudioQueueNewInput
    cbnz w0, Lal_err
    mov  x19, #0
1:  ADRL x9, _aq_in
    ldr  x0, [x9]
    mov  w1, #(IN_FRAMES * 4)
    ADRL x2, _in_buf
    add  x2, x2, x19, lsl #3
    bl   _AudioQueueAllocateBuffer
    cbnz w0, Lal_err
    ADRL x9, _aq_in
    ldr  x0, [x9]
    ADRL x9, _in_buf
    ldr  x1, [x9, x19, lsl #3]
    mov  w2, #0
    mov  x3, #0
    bl   _AudioQueueEnqueueBuffer
    cbnz w0, Lal_err
    add  x19, x19, #1
    cmp  x19, #3
    b.lo 1b
    ADRL x9, _aq_in
    ldr  x0, [x9]
    mov  x1, #0
    bl   _AudioQueueStart
    cbnz w0, Lal_err
Lal_ok:
    mov  x0, #0
    LEAVE 0
Lal_err:
    mov  x19, x0
    bl   _listen_close
    sxtw x0, w19
    LEAVE 0
Lal_off:
    bl   _listen_close
    mov  x0, #0
    LEAVE 0

_listen_close:
    ENTER 0
    ADRL x9, _aq_in
    ldr  x19, [x9]
    cbz  x19, 1f
    str  xzr, [x9]                    // the callback stops re-queueing
    mov  x0, x19
    mov  w1, #1
    bl   _AudioQueueStop
    mov  x0, x19
    mov  w1, #1
    bl   _AudioQueueDispose
1:  LEAVE 0

// long _audio_listening(void)
.globl _audio_listening
_audio_listening:
    ADRL x9, _aq_in
    ldr  x0, [x9]
    cmp  x0, #0
    cset x0, ne
    ret

// input callback(void *user, AudioQueueRef aq, AudioQueueBufferRef buf, ...)
_in_cb:
    ENTER 0
    mov  x19, x1
    mov  x20, x2
    ldr  x0, [x20, #AB_DATA]
    ldr  w1, [x20, #AB_SIZE]
    lsr  x1, x1, #2
    bl   _rec_push
    ldr  x0, [x20, #AB_DATA]
    ldr  w1, [x20, #AB_SIZE]
    lsr  x1, x1, #2
    bl   _rx_feed
    ADRL x9, _aq_in
    ldr  x9, [x9]
    cbz  x9, 1f
    mov  x0, x19
    mov  x1, x20
    mov  w2, #0
    mov  x3, #0
    bl   _AudioQueueEnqueueBuffer
1:  LEAVE 0

// the receiver's sink (on the microphone thread): wrap it as NSData and send it to the
// main thread.  NSData: [mode][repaired][lost][0] then the text
_app_sink:
    ENTER 16
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    mov  x22, x3
    bl   _objc_autoreleasePoolPush
    mov  x23, x0
    ADRL x24, _sinkbuf
    strb w19, [x24]
    strb w22, [x24, #1]
    mov  w9, #0                       // 0 a message, 1 too damaged, 2 length unreadable
    cmp  x21, #-1
    b.ne 1f
    mov  w9, #1
1:  cmp  x21, #-2
    b.ne 2f
    mov  w9, #2
2:  strb w9, [x24, #2]
    strb wzr, [x24, #3]
    cmp  x21, #0
    csel x21, xzr, x21, lt
    add  x0, x24, #4
    mov  x1, x20
    mov  x2, x21
    bl   _memcpy
    CLS  Ls_NSData
    MSG0 Ls_alloc
    mov  x2, x24
    add  x3, x21, #4
    MSG2 Ls_initB
    mov  x20, x0
    ADRL x0, Ls_heard
    bl   _sel_registerName
    mov  x2, x0
    ADRL x9, _audio_ctl
    ldr  x0, [x9]
    mov  x3, x20
    mov  x4, #0
    ADRL x1, Ls_perform
    bl   _msg3
    mov  x0, x20
    MSG0 Ls_release
    mov  x0, x23
    bl   _objc_autoreleasePoolPop
    LEAVE 16

// _rec_push(const float *x, long n) — into the 30-second ring. Leaf.
_rec_push:
    ADRL x9, _rec_buf
    ldr  x10, [x9]
    cbz  x10, 9f
    ADRL x11, _rec_i
    ldr  x12, [x11]
    mov  x13, #(REC_N & 0xffff)
    movk x13, #(REC_N >> 16), lsl #16
    ADRL x14, _rec_tot
    ldr  x15, [x14]
    add  x15, x15, x1
    str  x15, [x14]
1:  cbz  x1, 2f
    ldr  w15, [x0], #4
    str  w15, [x10, x12, lsl #2]
    add  x12, x12, #1
    cmp  x12, x13
    csel x12, xzr, x12, hs
    sub  x1, x1, #1
    b    1b
2:  str  x12, [x11]
9:  ret

// long _rec_save(const char *path) — the last 60 s (or less) as a 16-bit 48 kHz WAV; 0 = saved
.globl _rec_save
_rec_save:
    ENTER 32
    mov  x19, x0
    ADRL x9, _rec_buf
    ldr  x20, [x9]
    cbz  x20, 8f
    mov  x13, #(REC_N & 0xffff)
    movk x13, #(REC_N >> 16), lsl #16
    ADRL x9, _rec_tot
    ldr  x21, [x9]
    cmp  x21, x13
    csel x21, x21, x13, lo            // samples to write
    cbz  x21, 8f
    ADRL x9, _rec_i                   // the oldest of them
    ldr  x22, [x9]
    sub  x22, x22, x21
    add  x9, x22, x13
    cmp  x22, #0
    csel x22, x9, x22, lt
    lsl  x0, x21, #1
    bl   _malloc
    cbz  x0, 8f
    mov  x23, x0
    mov  x9, #0                       // float -> saturated 16-bit
    mov  x13, #(REC_N & 0xffff)
    movk x13, #(REC_N >> 16), lsl #16
    mov  w10, #0xFE00                 // 32767.0f = 0x46FFFE00
    movk w10, #0x46FF, lsl #16
    fmov s1, w10
1:  ldr  s0, [x20, x22, lsl #2]
    fmul s0, s0, s1
    fcvtzs s0, s0
    sqxtn h0, s0
    str  h0, [x23, x9, lsl #1]
    add  x22, x22, #1
    cmp  x22, x13
    csel x22, xzr, x22, hs
    add  x9, x9, #1
    cmp  x9, x21
    b.lo 1b
    mov  x0, x19
    ADRL x1, Ls_wb
    bl   _fopen
    cbz  x0, 7f
    mov  x24, x0
    ADRL x9, Lwav_hdr
    lsl  x10, x21, #1
    str  w10, [x9, #40]
    add  x10, x10, #36
    str  w10, [x9, #4]
    mov  x0, x9
    mov  x1, #1
    mov  x2, #44
    mov  x3, x24
    bl   _fwrite
    mov  x0, x23
    mov  x1, #2
    mov  x2, x21
    mov  x3, x24
    bl   _fwrite
    mov  x22, x0
    mov  x0, x24
    bl   _fclose
    mov  x0, x23
    bl   _free
    cmp  x22, x21
    b.ne 8f
    mov  x0, #0
    LEAVE 32
7:  mov  x0, x23
    bl   _free
8:  mov  x0, #-1
    LEAVE 32
