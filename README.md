# asmtone

Send text from one Mac to another as sound — no Wi-Fi, Bluetooth, pairing or accounts.
Type a message, press Return, and the other Mac (running asmtone with Listen on) writes it down.
A Cocoa app with a Dock icon and a menu-bar item, written in ARM64 assembly for Apple Silicon.

## Three voices

| Mode  | Sounds like                                  | Speed                 | Repairs            |
|-------|----------------------------------------------|-----------------------|--------------------|
| Piano | 22 notes of the G pentatonic scale, D4–E8; a rising arpeggio first, a C-major chord last | ~3 characters/s | 6 bad bytes / message |
| Chirp | 24 short bird-like slides, 4–8.3 kHz         | ~14 characters/s      | 8 bad bytes        |
| Fast  | four tones at once (4 × 22), 1.5–5.6 kHz — Macs within a few feet | ~50 characters/s | 10 bad bytes |
| Silent | 22 tones, 17.6–19.6 kHz, faded in and out — above most adults' hearing | ~12 characters/s | 8 bad bytes |

The receiver listens for all four at the same time — you only pick the mode when sending.
One message carries up to 241 bytes in Piano, 237 in Chirp and Silent, 233 in Fast.

## Using it

- **Window:** pick Piano / Chirp / Fast, type, press Return (or Play). The line under the box
  says how many seconds of sound it will be. Heard messages appear below with the time and mode;
  `◂` heard, `▸` sent. Copy Last puts the last message heard on the clipboard.
- **Menu bar (piano keys):** Send Clipboard as Piano / Chirp / Fast, Listen on/off, Copy Last
  Message, Open, Quit. While a message is coming in, the icon shows how far along it is (e.g. ` 40%`).
  The icon dims when asmtone isn't listening.
- **Dock:** click to open the window; right-click for the same send items; a badge counts messages
  heard while you were in another app.
- The first time it listens, macOS asks for the microphone. If you said no:
  System Settings › Privacy & Security › Microphone › asmtone.

## How it works

```
100 ms silence | preamble: 8 rising symbols | length ×3 | payload + CRC-16 + Reed–Solomon parity
```

- **Sending** (`modem.s`, `dsp.s`): each nibble picks one of 16 tones; Fast sends four nibbles at once.
  Piano notes are a sine plus three overtones with a 3 ms attack and 55 ms ring (a rotating
  vector in double precision, overtones from Chebyshev identities); chirps slide up into
  their tone over the first quarter of the symbol. The bytes are whitened so repeated letters
  don't become repeated notes.
- **Hearing** (`modem.s`, `dsp.s`): every 1/8 symbol, for every mode, a NEON Goertzel filter bank
  (16 tones per 4 registers, two samples per loop) measures each tone. The receiver keeps which
  tone won and by how much, waits for the preamble in every group, scores one symbol's worth of
  alignments and settles on the middle of the best ones, then reads a symbol every 8 hops.
- **Echo** (2.0): a few feet away most of what a microphone hears is the room still ringing with
  the last few tones. So a tone rests for a few symbols after it plays (6 in Piano, Silent and
  Fast, 8 in Chirp); each nibble is the rank of its tone among the tones allowed at that
  moment, and the receiver leaves the resting tones out when it listens — both ends keep the same
  history, starting from the preamble. In simulated rooms where the echo is as loud as the sound,
  every mode now gets through; Piano, Chirp and Silent also when it is 5 dB louder (`test/room_test.py`).
  This changed what's on the air: 2.0 and 1.x don't understand each other.
- **Piano notes in real rooms**: small speakers and echoes can bury a note's fundamental, and
  its octave and fifth are other notes of the scale, so each note is scored as its own energy
  plus half that of its 2nd and 3rd harmonics (tones 16–47 of the filter bank). Found with a
  recording from the Mac mini; it's a test fixture now (`test/fixtures/room-piano.wav`).
- **Giving up**: four symbols in a row with next to nothing in them and the receiver reports the
  message lost instead of waiting for the rest; a preamble without a readable length is reported too.
- **Save Last 30 Seconds of Sound** (menu bar / app menu, ⌘S) writes what the microphone heard to
  `~/Developer/asmtone/recordings` (or the Desktop); `sh test/analyze.sh <wav>` replays it through
  the receiver and prints every lock, symbol and result.
- **Repairing** (`fec.s`): Reed–Solomon over GF(256) with 8 / 12 / 16 parity bytes (Berlekamp–Massey,
  Chien, Forney — the decoder from asmmesh's FM link with the parity count made a parameter),
  then a CRC-16/X.25 check.
- **Sound** (`audio.s`): AudioQueue in and out at 48 kHz mono float. While playing, the receiver
  hears silence (and for 0.4 s after) so it doesn't decode itself.

## Files

| File | What |
|---|---|
| `src/main.s` | app, controller class, menus, window, menu-bar item, Dock menu |
| `src/util.s` | Objective-C messaging and AppKit helpers |
| `src/audio.s` | AudioQueue speaker + microphone |
| `src/modem.s` | modes, framing, sending, the receiver's state machine |
| `src/dsp.s` | NEON Goertzel bank, piano and tone voices |
| `src/fec.s` | Reed–Solomon, CRC-16, whitening |
| `src/selftest.s` | self-tests (`asmtone --selftest`) |
| `test/run_linux.sh` | the modem + self-tests built natively on ARM64 Linux |
| `icon/make_icon.py` | draws the icon |

## Download

Double-click **Make Download.command** (or `make dist`): it runs the self-tests and writes
`dist/asmtone-<version>-mac-arm64.zip` — asmtone.app plus INSTALL.txt — and its SHA-256. Install steps
for other Macs are in `INSTALL.txt` (Apple Silicon, macOS 12+; first launch needs Open Anyway, since the
app isn't notarized).

## Building

Double-click **Install asmtone.command** — it runs the self-tests, builds, signs (Apple Development
identity if there is one, otherwise ad-hoc, hardened runtime), installs to /Applications,
pins it to the Dock, launches it and commits the build to git. Or `make`, `make selftest`, `make install`.

`sh test/run_linux.sh` also plays every mode through simulated echoing rooms.
The self-tests play every mode through a simulated room (two echoes and hiss), with the two
sound cards' clocks 200 ppm apart, with a burst of loud noise, back to back, at the maximum
length, and check that five seconds of hiss produce nothing. The modem files also assemble as
ELF (`LINUX` defined), so `sh test/run_linux.sh` runs the same tests on any ARM64 Linux machine.
