#!/usr/bin/env bash
# DPMS Reset for Hyprland to fix black screen on wake
hyprctl dispatch dpms off
sleep 1
hyprctl dispatch dpms on
