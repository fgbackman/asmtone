/* Writes one WAV per mode (48 kHz, 16-bit mono) of a message as asmtone plays it,
 * using the same assembly modem. Built by test/make_samples.sh on ARM64 Linux. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
extern void _modem_init(void);
extern long _tx_render(long, const unsigned char *, long);
extern float *_tx_buf;
static void put32(FILE *f, uint32_t v) { fwrite(&v, 4, 1, f); }
static void put16(FILE *f, uint16_t v) { fwrite(&v, 2, 1, f); }
int main(int argc, char **argv) {
    const char *msg = argc > 1 ? argv[1] : "Hello from asmtone!";
    const char *names[] = { "piano", "chirp", "fast" };
    _modem_init();
    for (int m = 0; m < 3; m++) {
        long n = _tx_render(m, (const unsigned char *)msg, (long)strlen(msg));
        if (!n) { fprintf(stderr, "too long for %s\n", names[m]); continue; }
        char path[256]; snprintf(path, sizeof path, "%s/%s.wav", argc > 2 ? argv[2] : ".", names[m]);
        FILE *f = fopen(path, "wb");
        fwrite("RIFF", 1, 4, f); put32(f, 36 + n * 2); fwrite("WAVEfmt ", 1, 8, f);
        put32(f, 16); put16(f, 1); put16(f, 1); put32(f, 48000); put32(f, 96000); put16(f, 2); put16(f, 16);
        fwrite("data", 1, 4, f); put32(f, n * 2);
        for (long i = 0; i < n; i++) { float x = _tx_buf[i] * 32767.0f; put16(f, (uint16_t)(int16_t)x); }
        fclose(f);
        printf("%s: %.1f s\n", path, n / 48000.0);
    }
    return 0;
}
