#!/usr/bin/env bash

MODE="${1:-extend}" # extend, mirror, internal, external

# Get all monitors
ALL_MONITORS=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[].name' || true)

if [ -z "$ALL_MONITORS" ]; then
	# Fallback if hyprctl or jq fails
	echo "Error: Could not query monitors"
	exit 1
fi

# Identify internal monitor (starts with eDP or LVDS)
INTERNAL_MONITOR=""
EXTERNAL_MONITORS=()

for mon in $ALL_MONITORS; do
	if [[ "$mon" =~ ^(eDP|LVDS) ]]; then
		INTERNAL_MONITOR="$mon"
	else
		EXTERNAL_MONITORS+=("$mon")
	fi
done

# If no internal monitor detected, fallback to first monitor
if [ -z "$INTERNAL_MONITOR" ] && [ ${#EXTERNAL_MONITORS[@]} -gt 0 ]; then
	INTERNAL_MONITOR="${EXTERNAL_MONITORS[0]}"
	EXTERNAL_MONITORS=("${EXTERNAL_MONITORS[@]:1}")
fi

echo "Internal monitor: $INTERNAL_MONITOR"
echo "External monitors: ${EXTERNAL_MONITORS[*]}"
echo "Mode: $MODE"

case "$MODE" in
internal)
	# Enable internal, disable all external
	if [ -n "$INTERNAL_MONITOR" ]; then
		hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,1"
	fi
	for ext in "${EXTERNAL_MONITORS[@]}"; do
		hyprctl keyword monitor "$ext,disable"
	done
	;;
external)
	# Enable all external, disable internal
	for ext in "${EXTERNAL_MONITORS[@]}"; do
		hyprctl keyword monitor "$ext,preferred,auto,1"
	done
	if [ -n "$INTERNAL_MONITOR" ] && [ ${#EXTERNAL_MONITORS[@]} -gt 0 ]; then
		hyprctl keyword monitor "$INTERNAL_MONITOR,disable"
	fi
	;;
mirror)
	# Enable internal, make external mirror internal
	if [ -n "$INTERNAL_MONITOR" ]; then
		hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,1"
		for ext in "${EXTERNAL_MONITORS[@]}"; do
			hyprctl keyword monitor "$ext,preferred,auto,1,mirror,$INTERNAL_MONITOR"
		done
	fi
	;;
extend | *)
	# Enable all
	if [ -n "$INTERNAL_MONITOR" ]; then
		hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,1"
	fi
	for ext in "${EXTERNAL_MONITORS[@]}"; do
		hyprctl keyword monitor "$ext,preferred,auto,1"
	done
	;;
esac
