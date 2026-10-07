# 2026-10-07 — all-core load collapses to 1 GHz / 8 W on Linux

## Machine
HP Victus 16-s1xxx (board 8C9C), AMD Ryzen 7 8845HS (8 cores / 16 threads, Hawk Point), BIOS F.15
(2025-03-26), Ubuntu 22.04 with kernel 6.8.0-138, HP barrel charger (a Dell dock on USB-C was also
connected at first; it made no difference).

## Symptom
Found with the Prismark benchmark: 3D rendering got faster up to 8 threads and then much slower at
16 threads (8.4 vs 22.6 M samples/s); compiling likewise (13 vs 30 builds/h). Reproduced without
any benchmark (`tools/load-test.sh`): plain shell busy loops on all 16 threads.

| Load (Linux, AC) | Clock | Package power | Temperature |
|---|---|---|---|
| 8 threads | 4.4 GHz | 41–50 W | ~55 °C |
| 16 threads | **~1.0–1.1 GHz** after 1–2 s | **~8 W** (idle is 6–9 W) | falling, ~40 °C |
| 16 threads, very light loop | 4.4 GHz | 37 W | — |

Not heat (temperature falls) and not an ordinary power limit (that holds power *at* the limit):
something forces the processor to its minimum, like an emergency brake (PROCHOT). Heavy loads
trigger it, light ones do not. The battery stayed "Full" throughout.

## Windows, same laptop (Cinebench R23 multi-core, HWiNFO)
| | Clock | Package power | Tctl |
|---|---|---|---|
| Barrel charger | ~4.45 GHz | ~60 W (APU STAPM 60.4 W) | 95–99 °C |
| Battery | ~3.25 GHz | ~26 W | ~68–83 °C |

Score on AC: 13179. No collapse, so the hardware and the charger are fine: the fault is in how
Linux sets the laptop up.

## Cause
Kernel 6.8 lets only one driver own the power profile (`/sys/firmware/acpi/platform_profile`).
AMD's `amd_pmf` registered first (HP's `hp_wmi` lost) and applies power settings it reads from the
BIOS. With this BIOS they produce the collapse. The boot log has BIOS table bugs ("Attempt to
CreateField of length zero", failing `\_SB.WMID.*` methods) that fit a bad value being read.
`amd_pmf` provides nothing else here: it logs "No Smart PC policy present".

## Fix
`sudo modprobe -r amd_pmf` (now), `blacklist amd_pmf` in `/etc/modprobe.d` plus
`update-initramfs -u` (permanently). Re-applying the profile alone (balanced → performance) did not
help; it was run just before the `modprobe -r`.

After removing `amd_pmf` (Prismark, 3D rendering, all cores):

| Threads | 1 | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| M samples/s | 3.19 | 6.97 | 13.5 | 24.6 | **32.5** (was 8.4) |
| Clock | 4.97 GHz | 4.89 | 4.86 | 4.49 | 4.25 |
| Package power | 18 W | 25 W | 42 W | 44 W | 45 W, steady |

## Still missing: Windows' 60 W
Without `amd_pmf` the processor runs at its default 45 W. Windows reaches ~60 W because HP's
software switches the laptop to its performance mode. Linux 6.8's `hp_wmi` does not know this
board; **kernel 6.14 and later** do: `hp-wmi.c` lists board 8C9C ("Victus 16-s1000") with a
performance mode that also sets the CPU power limits (PL1/PL2) through HP's interface, noting that
on 8C9C (BIOS F.11, F.13) the limits need re-triggering in performance mode and after switching to
AC. Not yet tried here. Meanwhile, `ryzenadj` sets the limits directly (`etc/victus16/power-limits.conf`).

## Unrelated, seen on the way
- `WARNING ... ieee80211_vif_use_reserved_switch` (mac80211): a Wi-Fi driver issue.
- `linux-firmware` is the 2022 Ubuntu 22.04 package; it affects graphics, not CPU power.
