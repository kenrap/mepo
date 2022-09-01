# Installation guide

Mepo is available currently for postmarketOS (edge), NixOS, the AUR, and
as a flatpak.

## PostmarketOS / Alpine Linux

To install on postmarketOS, depending on your targeted enviroment install
either `mepo-wayland`, `mepo-xorg`, or `mepo-framebuffer`. For Sxmo or desktop
X use mepo-xorg,  for Phosh, Swmo, sway, or desktop wayland use mepo-wayland, 
or for framebuffer use `mepo-framebuffer`

Examples install command:
```sh
apk add mepo-wayland
```

On Phosh, a new icon will appear for Mepo, and in S{x,w}mo, mepo will
appear in the applications menu. To launch on desktop, you can directly
run the command `mepo`.

## Flatpak

Eventually mepo will be added to flathub proper, a flatpak may be built from
the source directory in the interim as follows:

```
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.freedesktop.Platform//21.08 org.freedesktop.Sdk//21.08 runtime/org.freedesktop.Sdk.Extension.ziglang/x86_64/21.08
flatpak-builder build-dir com.milesalan.mepo.yml --force-clean
flatpak run com.milesalan.mepo
```
