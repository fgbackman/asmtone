/* Writes a message as asmtone would play it, as a 16-bit 48 kHz WAV.
 *   render <mode 0-3> "<text>" out.wav       (built by test/run_linux.sh) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
extern void _modem_init(void);
extern long _tx_render(long, const unsigned char *, long);
extern float *_tx_buf;
int main(int argc, char **argv) {
    if (argc < 4) return 2;
    _modem_init();
    long n = _tx_render(atol(argv[1]), (const unsigned char *)argv[2], (long)strlen(argv[2]));
    if (!n) return 1;
    FILE *f = fopen(argv[3], "wb");
    char h[44] = {0};
    memcpy(h, "RIFF", 4); *(uint32_t *)(h + 4) = 36 + n * 2; memcpy(h + 8, "WAVEfmt ", 8);
    *(uint32_t *)(h + 16) = 16; *(uint16_t *)(h + 20) = 1; *(uint16_t *)(h + 22) = 1;
    *(uint32_t *)(h + 24) = 48000; *(uint32_t *)(h + 28) = 96000; *(uint16_t *)(h + 32) = 2;
    *(uint16_t *)(h + 34) = 16; memcpy(h + 36, "data", 4); *(uint32_t *)(h + 40) = n * 2;
    fwrite(h, 1, 44, f);
    for (long i = 0; i < n; i++) { int16_t s = (int16_t)(_tx_buf[i] * 32767); fwrite(&s, 2, 1, f); }
    fclose(f);
    return 0;
}
