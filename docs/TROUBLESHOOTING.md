# Troubleshooting

Each section is a wall we hit (in order) and how we got past it. Symptoms are
quoted so you can match log output.

## `texImage2D ... 0x0502 (GL_INVALID_OPERATION)` + `EGL_BAD_ACCESS`

```
ERR: ... renderer/gl/TextureGL.cpp ... generated error 0x00000502
vrend_winsys_make_context_current: Error switching context: EGL_BAD_ACCESS
```

ANGLE is using its **OpenGL** backend, which is broken on Mali via virgl. The
error path says `renderer/gl/` - you want `vulkan`. Two causes:

1. The server wasn't started in Vulkan mode. Start it with `~/vgl angle=vulkan`
   (not `virgl_test_server_android --angle-vulkan`, which falls back to GL).
2. The Vulkan ICD fix wasn't applied, so ANGLE can't find Mali's Vulkan and
   reverts to GL. Apply step 2 in the README.

Success looks like `using virgl angle=vulkan` and the texture errors gone.

## `Another Window Manager (unknown) is already running`

```
xfwm4: Another Window Manager (unknown) is already running on screen :1.0
xfwm4: Could not find a screen to manage, exiting
```

Two distinct causes, fix both:

- **Stale X server.** `pkill termux-x11` only kills the launcher; the real X
  server lives in the **Termux:X11 Android app**, which survives between runs
  with old clients still attached. Kill it for real:
  `am force-stop com.termux.x11` (already in `start-ubuntu.sh`).
- **Ghost session on disk.** XFCE restores a saved session from
  `~/.cache/sessions/` that contains a phantom WM. It survives any process
  kill because it's a *file*. The final scripts avoid this entirely by not
  using a session manager (below). If you do use `startxfce4`, add
  `rm -rf ~/.cache/sessions/*` before launching.

## `dbus-launch` segfault / `Failed to connect to session manager` / `ICE I/O Error`

```
_IceTransmkdir: Owner of /tmp/.ICE-unix should be set to root
Failed to connect to session manager: ... IO error
Segmentation fault   dbus-launch --exit-with-session startxfce4
```

`dbus-launch` is fragile in proot, and `xfce4-session`'s ICE socket on the
bind-mounted `/tmp` is a coin flip (works one run, crashes the next).

**Fix that ends the whole class of problems:** drop the session manager. Launch
the components by hand under `dbus-run-session`, exactly as in
`scripts/start-xfce.sh`:

```bash
dbus-run-session -- bash -c '
  xfsettingsd & sleep 2
  xfwm4 & sleep 1
  xfdesktop & xfce4-panel &
  wait
'
```

This kills ICE flakiness, the ghost WM, and the WM-respawn loop in one move,
and the boot becomes deterministic. The trade-off: no graphical logout button
(close via the Termux:X11 app or Ctrl+C).

## Blank screen - processes run but nothing shows; `glxinfo` gives `X_GetImage BadMatch`

```
X Error of failed request:  BadMatch (invalid parameter attributes)
  Major opcode of failed request:  73 (X_GetImage)
```

You're forcing the **whole desktop** through virgl. The 2D shell renders to a
virgl-backed surface that doesn't present to Termux:X11 - blank screen, even
though every process is alive.

Fix: run the desktop **shell in software** (`LIBGL_ALWAYS_SOFTWARE=1`,
`GALLIUM_DRIVER=llvmpipe`) and use the GPU **per app** via the `gpu` alias.
This is exactly what `scripts/start-xfce.sh` does. Also remove `-legacy-drawing`
from the `termux-x11` line - combined with virgl it triggers the same BadMatch.

`glxgears` and WebGL still render under the per-app GPU path; the `X_GetImage`
error is a probing quirk of `glxinfo`/`MESA_BACK_BUFFER=pixmap`, not a real
break.

## `vgl: command not found` inside the distro

`vgl` lives in **Termux**, not in the proot distro. You don't need it inside -
the server is already running on the host (started by `start-ubuntu.sh`). Inside
the distro just use the `gpu` alias, which sets `GALLIUM_DRIVER=virpipe`
directly.

## Firefox icon still opens in software

If the **menu/panel** item is the generic XFCE "Web Browser" (an `exo`
launcher), it ignores `firefox.desktop` entirely. Two options:

- Use the actual **Firefox** menu item (Internet -> Firefox) - after editing
  its `.desktop` (see below) and running `xfce4-panel -r`.
- Or point the default browser at the wrapper: install `config/firefox-gpu` to
  `~/.local/bin/`, then `exo-preferred-applications` -> Internet -> Web Browser
  -> Other... -> `/home/<you>/.local/bin/firefox-gpu`.

To make the Firefox `.desktop` itself accelerated:

```bash
mkdir -p ~/.local/share/applications
src=$(ls /usr/share/applications/firefox*.desktop 2>/dev/null | head -1)
cp "$src" ~/.local/share/applications/
sed -i 's|^Exec=|Exec=env -u LIBGL_ALWAYS_SOFTWARE MOZ_X11_EGL=1 GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.1COMPAT MESA_GLSL_VERSION_OVERRIDE=410 |' ~/.local/share/applications/$(basename "$src")
update-desktop-database ~/.local/share/applications 2>/dev/null
xfce4-panel -r
```

For WebGL, also set in `about:config`: `webgl.force-enabled = true` and
`gfx.webrender.all = false`.

## Harmless log noise (safe to ignore)

- `Xlib: extension "DPMS" missing` - Termux:X11 has no DPMS.
- `Failed to connect to session manager: SESSION_MANAGER ... not defined` -
  expected; we removed the session manager on purpose.
- `CanShutdown/CanRestart failed` - no SM, so logout buttons are inert.
- `fuse`, `pipewire`, `colord`, system-bus warnings - normal proot noise.
- `virgl_fence_set_fd: failed err=-9` - known virgl fence-export limitation.
