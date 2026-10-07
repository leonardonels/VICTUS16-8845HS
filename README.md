# VICTUS16-8845HS

**Machine:** HP Victus 16-s1xxx (board 8C9C), AMD Ryzen 7 8845HS, BIOS F.15, Ubuntu 22.04, kernel 6.8.

## Known problems and fixes

| Date | Problem | Fix | Details |
|---|---|---|---|
| 2026-10-07 | Heavy load on all 16 threads drops to ~1 GHz / 8 W (Windows: 4.45 GHz / 60 W) | blacklist `amd_pmf` | [docs](docs/2026-10-07-all-core-collapse.md) |
| 2026-10-07 | Linux stays at the default 45 W, Windows reaches ~60 W | power limits with `ryzenadj`, or kernel 6.14+ (`hp-wmi` knows board 8C9C) | same |

## Restore after a reinstall

### 1. Stop the all-core collapse (needed)
```sh
sudo cp etc/modprobe.d/blacklist-amd-pmf.conf /etc/modprobe.d/
sudo update-initramfs -u
sudo modprobe -r amd_pmf      # the blacklist covers the next boots
```

### 2. Raise the power limit to Windows' ~60 W (optional)
Build [RyzenAdj](https://github.com/FlyGoat/RyzenAdj) (v0.19.0 supports the 8845HS, "Hawk Point").
With Secure Boot off and the kernel does not set `CONFIG_IO_STRICT_DEVMEM`, so it reaches the
processor through `/dev/mem`; no extra kernel module is needed.
```sh
sudo apt install build-essential cmake git libpci-dev
git clone --depth 1 --branch v0.19.0 https://github.com/FlyGoat/RyzenAdj.git /tmp/RyzenAdj
cmake -S /tmp/RyzenAdj -B /tmp/RyzenAdj/build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/RyzenAdj/build -j
sudo install -m 755 /tmp/RyzenAdj/build/ryzenadj /usr/local/bin/ryzenadj
sudo ryzenadj --info | head -30     # shows the current limits (STAPM, PPT FAST/SLOW, THM)
```
Apply the limits in [etc/victus16/power-limits.conf](etc/victus16/power-limits.conf) once:
```sh
sudo ryzenadj --stapm-limit=60000 --slow-limit=60000 --fast-limit=65000 --tctl-temp=95
```
They last until the next reboot, sleep or charger change (unplugging and replugging the barrel jack
resets them to 45 W).

### Steps 1 and 2 in one go, with the limits kept on AC
```sh
sudo ./install.sh
```
Installs the blacklist, builds ryzenadj if missing, and applies the limits for the current power
source at boot, after resume (`victus16-power.service`) and whenever the barrel charger or a USB-C
source is plugged in or out (`/etc/udev/rules.d/99-victus16-power.rules`):

| Power source | Limits |
|---|---|
| Barrel charger | 60 W sustained, 65 W bursts (Windows' values) |
| Battery, USB-C charger or dock | 45 W (the processor's default; the firmware alone sets ~25 W on battery) |
| Barrel and USB-C together | 45 W (both look the same to Linux, so the safe side) |

Change the limits in `/etc/victus16/power-limits.conf`, then
`sudo systemctl restart victus16-power.service`.

### 3. Check
```sh
./check.sh            # kernel, BIOS, amd_pmf, ryzenadj, limits
./check.sh --load     # plus a 10 s all-core load test
```
Healthy on the barrel charger: 16 threads hold 3+ GHz at ~60 W (45 W without the limits). The fault
looked like ~1 GHz and ~8 W within 1–2 s.

## Undo
`sudo ./uninstall.sh` removes the limits service, the udev rule and ryzenadj; `--with-blacklist` also allows
`amd_pmf` again.

## Layout
| Path | What |
|---|---|
| `docs/` | one file per problem: symptoms, measurements, cause, fix |
| `etc/` | files that belong in `/etc` |
| `ryzenadj/` | apply script, systemd service and udev rule for the power limits |
| `install.sh` / `uninstall.sh` | set everything up / remove it again |
| `tools/load-test.sh` | all-core load with clock and package power, no root needed |
| `check.sh` | current state, changes nothing |
