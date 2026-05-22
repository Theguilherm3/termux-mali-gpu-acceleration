# GPU compatibility

The real question isn't "Mali or not" - it's **"Adreno or not."**

## The dividing line: `/dev/kgsl`

Qualcomm **Adreno** GPUs expose `/dev/kgsl` to userspace, so Termux can talk to
the GPU directly. That unlocks the fast methods (Turnip, Zink). **Everything
else** - Mali, Xclipse, PowerVR - lacks that device, so without root you are
limited to `virglrenderer` wrapping the system driver. That is the method this
repo documents.

| GPU family | Direct access (`/dev/kgsl`) | Fast path | This repo applies? |
|---|---|---|---|
| Qualcomm Adreno 6xx/7xx | Yes | **Turnip / Zink** (near-native) | Not needed - use Turnip |
| ARM Mali (Midgard/Bifrost/Valhall) | No | virgl + ANGLE -> Vulkan | **Yes** |
| Samsung Xclipse (AMD RDNA, Exynos 2200/2400/1580) | No | virgl + ANGLE -> Vulkan (likely) | Probably; under-tested |
| Imagination PowerVR | No | virgl (system GL) | Likely, same constraints |

Notes:

- **Turnip** is a direct Vulkan driver for Adreno 600/700 only. **Zink**
  (OpenGL-on-Vulkan) works well only on Qualcomm. Neither works on Mali.
- **Panfrost** (the open Mesa driver for Mali) needs a custom **kernel** +
  root - not viable on a stock, unrooted Android phone.
- **Xclipse** (e.g. Galaxy Tab S10 FE / Exynos 1580) is AMD RDNA-based, not
  Mali, but still has no `/dev/kgsl`, so it lands in the same virgl-only bucket.
  The Mali-specific GL bug may differ there; community testing is thin.

## Performance context

Public benchmarks are mostly Adreno (Mali users rarely post numbers because it
barely runs). For reference, a Snapdragon 870 / **Adreno 650** in a Debian proot:

| Method (proot) | glmark2 | Firefox WebGL |
|---|---|---|
| llvmpipe (CPU) | 93 | 4 fps |
| **VIRGL** | 70-77 | ~20 fps |
| Turnip (Adreno only) | 197-198 | crashes |

On the **Mali-G57 MC2** (a modest 2-core mobile GPU) the WebGL Aquarium runs
~15 fps with 500 fish - roughly 75% of what a flagship Adreno 650 does over
virgl, while also paying for the extra ANGLE->Vulkan hop. That's a good result
for the hardware tier, not a poor one.

The ceiling everyone hits: virgl's bridge overhead caps throughput around ~10%
of native, independent of GPU. The bottleneck is the translation, not the chip.

## Sources

- Termux maintainer on Mali vs `/dev/kgsl`:
  `github.com/termux/termux-packages/discussions/23961`
- Mali OpenGL/ANGLE bug:
  `github.com/termux/termux-packages/issues/23042`
- Vulkan ICD fix: `github.com/ar37-rs/virgl-angle/issues/1`
- Benchmarks (Adreno 650): `github.com/LinuxDroidMaster/Termux-Desktops`
- virgl overhead / OpenGL 2.1 ceiling:
  `github.com/termux/termux-packages/issues/17579`
