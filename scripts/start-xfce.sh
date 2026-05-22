#!/bin/bash
# =============================================================================
#  start-xfce.sh  -  proot (guest) side desktop launcher
# =============================================================================
#  Runs INSIDE the proot distro, invoked by start-ubuntu.sh.
#
#  Key design decisions (the hard-won ones):
#   * The desktop SHELL runs in SOFTWARE (llvmpipe). It is 2D and does not need
#     the GPU; forcing the whole desktop through virgl breaks presentation
#     (blank screen / X_GetImage BadMatch). GPU acceleration is applied
#     per-app instead (see the "gpu" alias in config/gpu.alias).
#   * No session manager. xfce4-session's ICE socket is unreliable on the
#     bind-mounted /tmp (intermittent crashes). We launch the components by
#     hand under dbus-run-session. This also kills the ghost-WM and ICE issues.
# =============================================================================

# Kill leftovers from a previous session (these live inside the proot).
pkill -9 xfwm4             2>/dev/null
pkill -9 xfce4-session     2>/dev/null
pkill -9 xfdesktop         2>/dev/null
pkill -9 xfce4-panel       2>/dev/null
pkill -9 xfsettingsd       2>/dev/null
pkill -9 xfce4-screensaver 2>/dev/null
sleep 1

export DISPLAY=:1
export PULSE_SERVER=127.0.0.1

# HiDPI scaling (tune for your screen, or remove).
export GDK_SCALE=2
export QT_SCALE_FACTOR=1.5
export QT_FONT_DPI=144

# Desktop shell -> software rendering: visible and rock-solid.
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

xrandr --dpi 192 2>/dev/null

# Launch the desktop WITHOUT a session manager: each piece by hand, fixed order.
# 'wait' keeps the session alive (panel/xfdesktop run forever).
dbus-run-session -- bash -c '
  xfsettingsd &
  sleep 2
  xfwm4 &
  sleep 1
  xfdesktop &
  xfce4-panel &
  wait
'
