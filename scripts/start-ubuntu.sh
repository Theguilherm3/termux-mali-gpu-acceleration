#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  start-ubuntu.sh  -  Termux side launcher
# =============================================================================
#  Runs on the TERMUX host (NOT inside the proot distro).
#  It resets a clean X server, starts the virgl/ANGLE->Vulkan GPU server,
#  brings up Termux:X11, and logs into the proot distro to start the desktop.
#
#  >>> EDIT THESE TWO LINES FOR YOUR SETUP <<<
USER_NAME="guilherme"          # your username inside the proot distro
UDROID_DISTRO="jammy:xfce4"    # your udroid distro tag (e.g. jammy:xfce4)
# -----------------------------------------------------------------------------
#  This script assumes you use "udroid". If you use proot-distro instead,
#  replace the final "udroid login ..." line with the equivalent
#  "proot-distro login ... --shared-tmp -- /home/$USER_NAME/start-xfce.sh".
# =============================================================================

# 1. Kill the whole Termux:X11 Android app. This is the ONLY way to truly
#    destroy a stale X server holding zombie clients (a leftover WM, etc).
am force-stop com.termux.x11 2>/dev/null

# 2. Exorcise leftover host-side processes.
pkill -9 -f termux-x11 2>/dev/null
pkill -9 -f Xwayland   2>/dev/null
~/vgl q                2>/dev/null   # ask vgl to stop its virgl server
pkill -9 -f virgl      2>/dev/null
sleep 2

# 3. Clean stale sockets/locks.
rm -f  "$TMPDIR"/.X*-lock     2>/dev/null
rm -rf "$TMPDIR"/.X11-unix    2>/dev/null
rm -f  "$TMPDIR"/.virgl_test  2>/dev/null
mkdir -p "$TMPDIR"/.X11-unix
chmod 1777 "$TMPDIR"/.X11-unix

# 4. Start the virgl server in ANGLE -> Vulkan mode.
#    THIS is the line that gives Mali GPUs working acceleration. It needs the
#    vulkan ICD fix from the README to be applied first, otherwise ANGLE falls
#    back to Mali's broken OpenGL path and the texture errors return.
~/vgl angle=vulkan
sleep 2

# 5. Start the X server. NOTE: do NOT add -legacy-drawing; combined with virgl
#    it causes "X_GetImage BadMatch" and a blank screen.
termux-x11 :1 -ac -dpi 192 >/dev/null 2>&1 &
sleep 3
am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1

# 6. Log into the proot distro and launch the desktop.
#    --bind $TMPDIR:/tmp is REQUIRED so the guest Mesa can reach the virgl
#    socket (/tmp/.virgl_test) created by the server on the host.
udroid login --user "$USER_NAME" \
  --bind /storage/emulated/0:/home/$USER_NAME/Celular \
  --bind "$TMPDIR":/tmp \
  "$UDROID_DISTRO" /home/$USER_NAME/start-xfce.sh
