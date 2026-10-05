/* Runs asmtone's modem self-tests on ARM64 Linux: the same assembly as the app
 * (fec.s, dsp.s, modem.s, selftest.s), assembled as ELF with LINUX defined. */
extern void _modem_init(void);
extern long _selftest(void);
int main(void) { _modem_init(); return (int)_selftest(); }
