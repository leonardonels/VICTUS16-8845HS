#!/bin/bash
# Undoes install.sh. The power limits return to the firmware's after a reboot (or a charger replug).
#
#   sudo ./uninstall.sh                  remove the limits service and ryzenadj, keep the blacklist
#   sudo ./uninstall.sh --with-blacklist     also allow amd_pmf again
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

systemctl disable --now victus16-power.service 2>/dev/null || true
rm -f /etc/systemd/system/victus16-power.service /usr/local/sbin/victus16-power-apply /usr/local/bin/ryzenadj \
  /etc/udev/rules.d/99-victus16-power.rules
systemctl daemon-reload
udevadm control --reload
echo "kept /etc/victus16/power-limits.conf (delete it by hand if unwanted)"

if [ "${1:-}" = "--with-blacklist" ]; then
  rm -f /etc/modprobe.d/blacklist-amd-pmf.conf
  update-initramfs -u
  echo "amd_pmf allowed again from the next boot"
fi
