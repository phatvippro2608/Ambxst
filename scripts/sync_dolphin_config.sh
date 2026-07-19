#!/usr/bin/env bash
# === Backward compatibility wrapper for sync_user_config.sh ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/sync_user_config.sh" "$@"
