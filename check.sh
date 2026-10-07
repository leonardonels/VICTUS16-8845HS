#!/bin/bash
# Shows whether this laptop is set up as README.md describes. Changes nothing.
#   ./check.sh          state only
#   ./check.sh --load   also a 10 s all-core load test (tools/load-test.sh)
REPO=$(cd "$(dirname "$0")" && pwd)

row() { printf '%-28s %s\n' "$1" "$2"; }
mains=0 usbc=0
for s in /sys/class/power_supply/*; do
  [ "$(cat "$s/online" 2>/dev/null)" = "1" ] || continue
  case "$(cat "$s/type" 2>/dev/null)" in Mains) mains=1 ;; USB) usbc=1 ;; esac
done
if [ "$usbc" = 1 ]; then on_ac="USB-C"; elif [ "$mains" = 1 ]; then on_ac="barrel charger"; else on_ac=battery; fi

row "kernel" "$(uname -r)"
row "BIOS" "$(cat /sys/class/dmi/id/bios_version 2>/dev/null) ($(cat /sys/class/dmi/id/bios_date 2>/dev/null))"
row "board" "$(cat /sys/class/dmi/id/board_name 2>/dev/null) (8C9C = Victus 16-s1000)"
row "power source" "$on_ac"
row "amd_pmf blacklisted" "$([ -e /etc/modprobe.d/blacklist-amd-pmf.conf ] && echo yes || echo NO)"
row "amd_pmf loaded" "$(lsmod | grep -q '^amd_pmf' && echo 'YES (collapse likely)' || echo no)"
row "platform profile" "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo 'none')"
row "ryzenadj" "$(command -v ryzenadj || echo 'not installed')"
row "charger udev rule" "$([ -e /etc/udev/rules.d/99-victus16-power.rules ] && echo installed || echo 'not installed')"
row "limits service""$(systemctl is-enabled victus16-power.service 2>/dev/null || echo 'not installed'), last run: $(systemctl show -p ActiveEnterTimestamp --value victus16-power.service 2>/dev/null)"
if [ -r /etc/victus16/power-limits.conf ]; then
  # shellcheck source=/dev/null
  . /etc/victus16/power-limits.conf
  row "limits, barrel" "STAPM $((BARREL_STAPM_LIMIT / 1000)) W, slow $((BARREL_SLOW_LIMIT / 1000)) W, fast $((BARREL_FAST_LIMIT / 1000)) W, Tctl $BARREL_TCTL_TEMP C"
  if [ -n "${OTHER_STAPM_LIMIT:-}" ]; then
    row "limits, battery/USB-C" "STAPM $((OTHER_STAPM_LIMIT / 1000)) W, slow $((OTHER_SLOW_LIMIT / 1000)) W, fast $((OTHER_FAST_LIMIT / 1000)) W, Tctl $OTHER_TCTL_TEMP C"
  else
    row "limits, battery/USB-C" "firmware's"
  fi
fi
[ "$(id -u)" = 0 ] && command -v ryzenadj >/dev/null && ryzenadj --info | grep -E "STAPM|PPT LIMIT|THM LIMIT"
[ "${1:-}" = "--load" ] && "$REPO/tools/load-test.sh" 16 10
exit 0
