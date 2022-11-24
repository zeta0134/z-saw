# Z-Saw

Play sawtooth waveforms using the NES's DMC channel in a small and game-friendly library.

Used in my 2022 NESDev compo entry: [Tactus](https://zeta0134.itch.io/tactus).

# Setup

**Important**: Z-Saw will be in control of both the IRQ and NMI vectors, due to its strict timing requirements.

For now, Z-Saw only supports the cc65 compiler suite. Pull requests for other assembler suites are welcome.

Place `zsaw.s` and `zsaw.inc` in your source directory, and ensure that `zsaw.s` is built and linked to your project.

Edit `zsaw.inc` and configure the following, adjusting segment names to match your project conventions:
```
; Z-Saw requires 11 bytes in zeropage
ZSAW_ZP_SEGMENT = "ZEROPAGE"
; interrupt vectors and lookup tables
ZSAW_FIXED_SEGMENT = "PRG_C000"
ZSAW_SAMPLES_SEGMENT = "PRG_C000"
; Shadow OAM high page, for OAM DMA
ZSAW_SHADOW_OAM = $02
; Your custom NMI handler, will be called automatically when vblank begins
; Note: 
;   - Do not perform OAM DMA, Z-Saw will handle that for you
;   - Interrupts will be enabled upon entry, please leave them enabled for proper operation
;   - All registers will be preserved on your behalf
ZSAW_NMI_GAME_HANDLER = nmi_handler
```

Include `zsaw.inc` in any code files that need to interface with the library.

Make sure zsaw is configured to handle both irq and nmi vectors:
```
        .segment "VECTORS"
        .addr zsaw_nmi
        .addr reset
        .addr zsaw_irq
```

Finally, during your game's reset sequence, run `jsr zsaw_init` once. Now Z-Saw is ready for use.

# Usage

Note: Please assume that all zsaw functions clobber flags, a, x, and y.

Basic note playback:

```
; Setting the volume:
lda #64
sta zsaw_volume
; Playing a note:
lda #ZSAW_C4
jsr zsaw_play_note ; enables DMC IRQ
; Silencing the channel
jsr zsaw_silence ; disables DMC IRQ
```

The variable `zsaw_volume` may be written at any time, even during note playback.

For integrating with a sound engine: 
  - `ZSAW_B1` is the lowest note available. 
    - This matches MIDI index 23, with a frequency of 30.87 Hz. 
  - `ZSAW_C7` is the highest note available
    - This approximates MIDI index 84, with a frequency of 1055.29 Hz
  - This range is chosen to be compatible with FamiTracker's pitch table

Caveats:
- There is no fine pitch control
- Notes above G5 begin to lose maximum volume capacity
- Notes above C6 start to become noticeably out of tune
- Higher notes may be subject to occasional artifacts, as the OAM DMA timing window is borderline in these cases

# How it Works

The idea to use the DMC channel to play arbitrary sawtooth waveforms was originally [documented by Blargg](http://slack.net/~ant/misc/nes-saw/). A 1-byte sample is played which ramps the DMC channel towards 0 over time. When this sample ends an IRQ is fired, the CPU sets a new PCM level and then queues the sample again. By stringing several samples back to back with different playback rates, the sawtooth can be tuned to many different frequencies. The tuning is decent enough to play melodic tones alongside the 2A03's other channels.

Due to some quirks of DMC playback, there are a number of strict timing requirements:

- At the fastest playback rate ($F):
  - There are just **54 cycles** to write the new playback rate
  - Missing this window introduces a minor timing artifact, lasting just one sample
  - There are **432 cycles** before the entire sample byte is played
  - Missing this window introduces a **major** timing artifact, lasting 8 samples

OAM DMA throws a wrengh into these requirements: it takes 513-514 cycles to complete, which is longer than the sample byte playback window. Attempting to use the sawtooth during gameplay without compensation introduces a rather nasty 60 Hz buzzing artifact.

The Z-Saw library works around this problem in several ways:
- The fastest playback rate for DMC is restricted to $E
  - The timing window for playback rate writes increases to 72 cycles
  - A full sample byte now takes at minimum 576 cycles to complete
  - This gives *just barely* enough time to get OAM DMA done without introducing a timing artifact
- The timing of NMI is controlled by the library
  - IRQ has ultimate priority, so that we can reliably hit the shorter 72 cycle window
  - If NMI interrupts IRQ, it is deferred until after IRQ is finished
- The timing of OAM is also controlled by the library
  - If the sawtooth is playing, NMI defers OAM DMA until the after next IRQ finishes
- The minimum playback rate is restricted to $8
  - A full byte will take at most 1520 cycles to play back
  - There are 2273 cycles in the vblank period on NTSC systems
  - When OAM DMA is deferred, the next IRQ is guarantted to have enough time to complete the transfer before the start of rendering

In a nutshell, we trade tuning ability and complexity for the ability to run the sawtooth during normal gameplay with minimal audible artifacts.

# Drawbacks

While the sawtooth is active, an IRQ will be fired and serviced every time DMC playback ends. The service routine takes around 80 cycles to complete. This means:

- There is about a 13% penalty to CPU usage while the sawtooth is playing
  - This penalty is somewhat relaxed for low notes
- The Z-Saw has control of the IRQ vector, so IRQ usage for other purposes is forbidden
- Checks for sprite zero / sprite overflow may be interrupted by the Z-Saw routine
- Effectively, raster effects are difficult / impossible while the sawtooth is playing
- Z-Saw consumes the DMC channel. DPCM samples and Z-Saw cannot play at the same time.

# Tips

In FamiTracker, you can configure the N163 expansion module with 1 channel enabled. In an N163 instrument, generates a sawtooth waveform with a length of **16**. This will roughly approximate the sound of Z-Saw, and is very helpful when composing. I find that a `Z40` in the DPCM channel loosely approximates the resulting mix.

# Credits

[Blargg](http://slack.net/~ant/) - original idea to generate sawtooth waveforms with DMC interrupts

[Damian "PinoBatch" Yerrick](https://github.com/pinobatch) - idea to restrict DMC playback rates to facilitate OAM DMA alongside clean playback

[NESDev](https://www.nesdev.org/) - a wealth of high quality documentation for NES and FamiCom hardware behaviors