/* Replays a recording (16-bit mono 48 kHz WAV, e.g. from Save Last 30 Seconds) through
 * asmtone's receiver and prints what it does: preamble locks, alignment scores, every
 * symbol it reads with how clearly it heard it, headers and results.
 *   sh test/analyze.sh recording.wav            (ARM64 Linux) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
extern void _modem_init(void); extern void _rx_reset(void);
extern void _rx_feed(const float *, long);
extern unsigned char _rx[]; extern void *_rx_sink; extern long _rx_total;
static const char *names[] = { "piano", "chirp", "fast", "silent" };
static const int NG[] = { 1, 1, 4, 1 }, K = 8;
static void sink(long m, const unsigned char *b, long len, long fixed) {
    if (len >= 0) printf("  >>> %s MESSAGE (%ld bytes, %ld repaired): %.*s\n", names[m], len, fixed, (int)len, b);
    else if (len == -1) printf("  >>> %s: too damaged to repair\n", names[m]);
    else printf("  >>> %s: header unreadable (nibbles %d %d %d %d %d %d)\n", names[m], b[0], b[1], b[2], b[3], b[4], b[5]);
}
#define U32(p) (*(uint32_t *)(p))
#define U64(p) (*(uint64_t *)(p))
#define F32(p) (*(float *)(p))
int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb"); if (!f) { perror(argv[1]); return 1; }
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 44, SEEK_SET);
    long n = (sz - 44) / 2; int16_t *pcm = malloc(n * 2); fread(pcm, 2, n, f); fclose(f);
    float *x = malloc(n * 4); double pk = 0;
    for (long i = 0; i < n; i++) { x[i] = pcm[i] / 32768.0f; if (abs(pcm[i]) > pk) pk = abs(pcm[i]); }
    printf("%s: %.1f s, peak %.0f/32767\n", argv[1], n / 48000.0, pk);
    _modem_init(); _rx_sink = (void *)sink; _rx_reset();
    int lastst[4] = {0}; uint64_t lastnib[4] = {0}; int verbose = argc > 2;
    for (long i = 0; i < n; i += 240) {
        long c = n - i < 240 ? n - i : 240;
        _rx_feed(x + i, c);
        for (int m = 0; m < 4; m++) {
            unsigned char *r = _rx + m * 4096;
            int st = U32(r + 16), nib = U32(r + 20);
            uint64_t hop = U64(r + 8);
            if (st != lastst[m]) {
                if (st == 1) printf("%7.3fs %s: preamble seen at hop %lu\n", i / 48000.0, names[m], (unsigned long)U64(r + 48));
                if (st == 2) {
                    printf("%7.3fs %s: locked; scores", i / 48000.0, names[m]);
                    for (int k = 0; k < 8; k++) printf(" %.2f", F32(r + 2944 + 4 * k));
                    printf("; first data hop %lu\n", (unsigned long)U64(r + 40));
                }
                if (st == 0 && lastst[m] == 2) printf("%7.3fs %s: back to hunting after %d nibbles (need %d)\n", i / 48000.0, names[m], (int)lastnib[m], U32(r + 36));
                lastst[m] = st;
            }
            if (st == 2 && nib != (int)lastnib[m]) {
                uint64_t h = hop - 1; int idx = h & 127;
                printf("        %s sym hop %lu: nib", names[m], (unsigned long)h);
                for (int g = 0; g < NG[m] && nib - NG[m] + g >= 0; g++) printf(" %2d", r[1600 + nib - NG[m] + g]);
                printf("  q %.2f", F32(r + 1088 + idx * 4));
                if (verbose) {   /* the neighbouring hops, to see if the alignment is off */
                    printf("   [");
                    for (int d = -4; d <= 4; d++) { int j = (h + d) & 127; if (d > 0) break;
                        printf(" %d:%d/%.2f", d, r[576 + j * 4], F32(r + 1088 + j * 4)); }
                    printf(" ]");
                }
                printf("\n");
            }
            lastnib[m] = st == 2 ? nib : 0;
        }
    }
    return 0;
}
