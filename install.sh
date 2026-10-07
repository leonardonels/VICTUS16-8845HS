#!/bin/bash
# Sets this laptop up as README.md describes. Run from the repo with sudo; safe to run again.
#
#   sudo ./install.sh              amd_pmf blacklist, ryzenadj (built if missing), 60 W limits on AC
#                                  at boot, after resume and when the charger is plugged in
#   sudo ./install.sh --rebuild    also rebuild ryzenadj when it is already installed
set -euo pipefail

RYZENADJ_TAG=v0.19.0 # https://github.com/FlyGoat/RyzenAdj/releases
REPO=$(cd "$(dirname "$0")" && pwd)
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

echo "== amd_pmf blacklist"
install -m 644 "$REPO/etc/modprobe.d/blacklist-amd-pmf.conf" /etc/modprobe.d/blacklist-amd-pmf.conf
update-initramfs -u
modprobe -r amd_pmf 2>/dev/null || true # effective now as well, not only after a reboot

if [ ! -x /usr/local/bin/ryzenadj ] || [ "${1:-}" = "--rebuild" ]; then
  echo "== ryzenadj $RYZENADJ_TAG"
  apt-get install -y build-essential cmake git libpci-dev
  SRC=$(mktemp -d)
  git clone --depth 1 --branch "$RYZENADJ_TAG" https://github.com/FlyGoat/RyzenAdj.git "$SRC/RyzenAdj"
  rm -rf "$SRC/RyzenAdj/win32"
  cmake -S "$SRC/RyzenAdj" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$SRC/build" -j"$(nproc)"
  install -m 755 "$SRC/build/ryzenadj" /usr/local/bin/ryzenadj
  rm -rf "$SRC"
fi

echo "== power limits on AC"
install -d /etc/victus16
# an existing, possibly edited, limits file is kept
[ -e /etc/victus16/power-limits.conf ] || install -m 644 "$REPO/etc/victus16/power-limits.conf" /etc/victus16/
install -m 755 "$REPO/ryzenadj/victus16-power-apply" /usr/local/sbin/victus16-power-apply
install -m 644 "$REPO/ryzenadj/victus16-power.service" /etc/systemd/system/victus16-power.service
install -m 644 "$REPO/ryzenadj/99-victus16-power.rules" /etc/udev/rules.d/99-victus16-power.rules
systemctl daemon-reload
udevadm control --reload
systemctl enable victus16-power.service
systemctl restart victus16-power.service
journalctl -u victus16-power.service -n 2 --no-pager -o cat

echo "== done; check with ./check.sh --load"
