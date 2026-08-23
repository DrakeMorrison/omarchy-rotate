#!/bin/bash
# Wire omarchy-rotate into this machine: CLI symlink, default config, hooks, systemd timer.
# Safe to re-run. Undo with ./uninstall.sh
exec "$(dirname "$(realpath "$0")")/bin/omarchy-rotate" install
