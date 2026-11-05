# Ember runtime and footprint measurements

November 4, 2026. Before: `4e14f44`. After: the Horizon/runtime branch. Same Apple Silicon Mac and Xcode 27.0. MB, KB and mJ are decimal.

| Measure | Before | After |
| --- | ---: | ---: |
| Median physical memory, panel never opened | 27.21 MB | 17.71 MB |
| Process CPU time over 90 seconds | 1.128 ms | 0.112 ms |
| Interrupt wakeups over 90 seconds | 34 | 10 |
| Package idle wakeups over 90 seconds | 0 | 0 |
| Process energy over 90 seconds | 54.40 mJ | 2.14 mJ |
| Process start to panel submission, median of 12 | 181.21 ms | 157.19 ms |
| First panel open, AppKit test | 29.15 ms | 34.79 ms |
| Panel reopen, median of 20 in AppKit test | 4.31 ms | 8.88 ms |
| Local universal Release DMG | 4,889,987 bytes | 4,542,720 bytes |

The idle run uses an isolated Debug bundle ID, an active daylight schedule, and a closed panel. In scratch builds the probe leaves the real model and timers in place, skips setup, license and analytics startup, and stops the tick before it touches display hardware or other apps. It samples `proc_pid_rusage(RUSAGE_INFO_V6)` every five seconds after a three-second warmup. Memory is the median physical footprint; CPU, wakeups and energy are counter deltas over the same window. One window per build is directional: these are process counters on this Mac, not wall power, battery life, or a measurement of an active display fade. `powermetrics` required administrator access and was not run.

Startup uses `python3 scripts/benchmark-startup.py <isolated Debug Ember.app> --runs 12`. It times process spawn to the first panel submission; it excludes physical tint, login changes, LicenseKit refresh and live location. Maximum samples were 256.18 ms before and 809.10 ms after, so the median does not establish a tail improvement. The retained panel stays fast once open. It is now created at first click, which saves launch footprint and moves some work to that click. AppKit timings are submission timings, not time to displayed pixels.

The size comparison uses two ad hoc signed universal Release builds, the same HFS+/UDZO settings and Applications symlink, and no Finder backdrop or notarization ticket. Compare the two local images with each other; the shipped 0.6.1 DMG is 4,622,790 bytes and was made by the release script. The Finder backdrop generator still produces a byte-for-byte match after moving the two build-only fonts. The new app bundle no longer includes the fonts and does not enable Swift testability in Release. `hdiutil verify` and `codesign --verify --deep --strict` passed locally. No Developer ID signing, notarization, or distribution was performed.

Stable daylight and night use one deadline for the next transition, midnight, or a clock change. Morning settling and evening ramps still receive updates. The app stops schedule polling while off or the displays sleep. A fade reuses one set of channel buffers, and repeated requests for the same target skip gamma writes. The regression suite covers deadlines, the startup license gate, suppression of redundant writes, and sleep/wake preview behavior. Physical HDR/EDR, external-display behavior, live licensing, and VoiceOver speech were not exercised.
