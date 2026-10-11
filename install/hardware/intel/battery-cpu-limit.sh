# Cap Intel CPU package power on battery: full-turbo spikes can droop the
# power source until the BMS cuts all power (a hard shutdown with nothing in
# the journal). power-saver only hints EPP, it never caps frequency or package
# power.

if omarchy-hw-intel && omarchy-battery-present; then
  rule_src="$OMARCHY_PATH/default/udev/battery-cpu-limit.rules"
  hook_src="$OMARCHY_PATH/default/systemd/system-sleep/battery-cpu-limit"
  rule_dest=/etc/udev/rules.d/99-omarchy-battery-cpu-limit.rules
  hook_dest=/usr/lib/systemd/system-sleep/battery-cpu-limit
  dropin_src="$OMARCHY_PATH/default/systemd/system/thermald.service.d/battery-cpu-limit.conf"
  dropin_dest=/etc/systemd/system/thermald.service.d/battery-cpu-limit.conf
  activated_marker=/var/lib/omarchy/battery-cpu-limit/activated

  # Machine-wide repair through a per-user runner (migration): no-op once
  # another user already published and activated the files, so later users
  # never prompt for sudo or block behind an already-applied repair. The
  # marker is written only after activation succeeds, so a failed reload or
  # restart is retried even though the files already match.
  if [[ ! -e $activated_marker ]] || ! cmp -s "$rule_src" "$rule_dest" ||
    ! cmp -s "$hook_src" "$hook_dest" || ! cmp -s "$dropin_src" "$dropin_dest"; then
    sudo rm -f "$activated_marker"
    sudo install -Dm644 "$rule_src" "$rule_dest"
    sudo install -Dm755 "$hook_src" "$hook_dest"
    sudo install -Dm644 "$dropin_src" "$dropin_dest"
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=power_supply --action=change
    sudo systemctl daemon-reload

    # A running thermald already snapshotted the uncapped PL1. Restart it so
    # the drop-in re-caps before it re-reads.
    if systemctl is-active --quiet thermald.service; then
      sudo systemctl restart thermald.service
    fi

    sudo install -Dm644 /dev/null "$activated_marker"
  fi
fi
