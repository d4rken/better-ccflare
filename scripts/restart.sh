#!/bin/sh
# restart.sh — Rebuild dashboard, then restart the systemd-managed proxy.
#
# Why this exists:
#   The previous setup ran `bun run build:dashboard` as an ExecStartPre=, so
#   the build (~10-20s) happened AFTER the old process had already been
#   killed — that whole window was downtime. This script flips the order:
#   build first while the old process is still serving, then restart. The
#   actual unavailability window shrinks to just server init (~5s).
#
# Prerequisite (one-time, run by hand with sudo):
#   sudo mv /etc/systemd/system/better-ccflare.service.d/dashboard-build.conf \
#           /etc/systemd/system/better-ccflare.service.d/dashboard-build.conf.bak
#   sudo systemctl daemon-reload
#
# Usage:
#   bun run restart
#   # or directly:
#   ./scripts/restart.sh
#
# Behavior:
#   - `set -e` aborts on the first failure. If `bun run build:dashboard`
#     fails, systemctl restart is NOT triggered — the old build keeps
#     serving. You see the build error, fix it, and try again.
#   - Uses `sudo systemctl` so it works for the non-root `darken` user.
#     Configure a passwordless sudoers entry if you want it fully
#     non-interactive.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE="better-ccflare"

cd "$REPO_ROOT"

printf '==> Building dashboard (old proxy still serving)...\n'
bun run build:dashboard

printf '==> Build succeeded. Restarting %s...\n' "$SERVICE"
sudo systemctl restart "$SERVICE"

printf '==> Done. Tail logs with: journalctl -u %s -f\n' "$SERVICE"
