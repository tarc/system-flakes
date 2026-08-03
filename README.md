# system-flakes — [NixOS-WSL]/[Home Manger] configuration

This project is based on the [`flake-parts`]' [`ez-configs`] module, with binary caching supported by [Cachix].

## Custom commands

To push a specific version of the flake inputs to the cache, run this command on the root of a local checkout of this repository:

```shell
flake-archive | cachix-cache push
```

## Useful commands

### `nix flake show`

Show the outpus provided by a flake.

Variants:

- `nix flake show . --no-pure-eval`
- `nix flake show 'github:nix-community/NixOS-WSL'`
- `nix flake show 'github:karaolidis/NixOS-WSL/wl-clipboard-wsl'`
- `nix flake show 'github:nixos/nixpkgs/nixpkgs-unstable'`

### `nix run`

Run a Nix application.

Variants:

- `nix run 'github:nixos/nixpkgs/nixpkgs-unstable#jq'`

### `glxinfo -B`

Variants:

- `nix run 'github:nixos/nixpkgs/nixpkgs-unstable#jq'`
- `GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA glxinfo -B | grep "OpenGL renderer"`

### `vulkaninfo`

Variants:

- `vulkaninfo --summary`

### Garbage collecting

```sh > text $
nix-collect-garbage --delete-old 2>&1 | tail -n 10
```

<!-- BEGIN mdsh -->
```text
deleting '/nix/store/9yhf5jasabwp5l02yyyy56ldbn4hmni2-getopt-1.1.6.tar.gz.drv'
deleting '/nix/store/q738l2mv8lw2i6g53lk70zg2489166dc-source'
deleting '/nix/store/zzmspl8wdn2a3ancrz8dg3kci887nw6d-builder.pl'
deleting '/nix/store/41d462rhm7akbbsyas4ijrivviqzkp09-source.drv'
deleting '/nix/store/2vcx03d5hnir75m4na319f7937n9q03m-unit-script-sleep-actions-start.drv'
deleting '/nix/store/fh934gq2y4xbz8ld2qcbaclv8s9smpp0-file-5.48.tar.gz.drv'
deleting '/nix/store/mmzfxdq98zdf9rlv7n2dw8nlw67n8vzy-source-salted-wqdb5z5z17lc.drv'
deleting unused links...
note: hard linking is currently saving 23.5 GiB
3966 store paths deleted, 3.5 GiB freed
```
<!-- END mdsh -->

```sh > text $
sudo nix-collect-garbage --delete-old 2>&1 | tail -n 10
```

<!-- BEGIN mdsh -->
```text
deleting '/nix/store/idvyswwbwhvailivzzss5ryx4w1qi9il-source'
deleting '/nix/store/q385mvcvvg80j24rswwp1rg7d9546k7r-options.json.drv'
deleting '/nix/store/5ksjmh7c43v8wpvbn3drsbjmky99xy69-boot.json.drv'
deleting '/nix/store/55z08f1cchp4qk1m5v0z8ckz4x79vmy7-source.drv'
deleting '/nix/store/vpfk2x76y6bnhwx1skipi3i2w5cmnyrr-etc-os-release.drv'
deleting '/nix/store/1334ak8aamnsk4nxsbmi47aqnvw4v7ak-nixos-version.drv'
deleting '/nix/store/9pd46mh8p51zm2ahsscjm84s558jigsz-options.json.drv'
deleting unused links...
note: hard linking is currently saving 23.3 GiB
89 store paths deleted, 497.5 MiB freed
```
<!-- END mdsh -->

### `nix fmt`

Calls the flake default formatter.

> [!WARNING]
> This will run commands embedded in markdown.

After a successful and non-idempotent `just switch`, it may make sense to free up disk space by running `nix-collect-garbage`. Formatting the `README.md` file is an unusual way to accomplish this:

```shell
touch README.md
nix fmt
```

### Optimizing VHD size

Be sure to know the name of your WSL distribution:

```sh
wsl --list -v
```

```text
  NAME                      STATE           VERSION
* NixOS                     Running         2
  podman-machine-default    Stopped         2
  docker-desktop            Stopped         2
```

It must not be sparsed already:

```sh
wsl --manage NixOS --set-sparse false
```

Learn the path of its VHDX file:

```sh
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*"
```

```text
State               : 1
Version             : 2
BasePath            : C:\Users\tarci\AppData\Local\wsl\{7527fb51-83d7-4564-bc19-617c2e6b096a}
Flags               : 15
DefaultUid          : 0
RunOOBE             : 0
VhdFileName         : ext4.vhdx
DistributionName    : NixOS
Modern              : 1
ShortcutPath        : C:\Users\tarci\AppData\Roaming\Microsoft\Windows\Start Menu\NixOS.lnk
TerminalProfilePath : C:\Users\tarci\AppData\Local\Microsoft\Windows Terminal\Fragments\Microsoft.WSL\{96dc692a-1006-5fa5-bc6b-f63e8df2226b}.json
Flavor              : nixos
OsVersion           : 26.11
PSPath              : Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\{7527fb51-83d7-4564-bc19-617c2e6b096a}
PSParentPath        : Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss
PSChildName         : {7527fb51-83d7-4564-bc19-617c2e6b096a}
PSDrive             : HKCU
PSProvider          : Microsoft.PowerShell.Core\Registry
```

Optimize the disk:

```sh
optimize-vhd -Path  'C:\Users\tarci\AppData\Local\wsl\{7527fb51-83d7-4564-bc19-617c2e6b096a}\ext4.vhdx'  -Mode full
```

(Re)Enable sparse mode:

```sh
wsl --manage NixOS --set-sparse true --allow-unsafe
```

## Related projects

- [`ez-configs`]'s author own dotfiles: [ehllie/dotfiles]

## References

- [NVIDIA][nixos/nvidia] ([Official NixOS Wiki][nixos])
- [CUDA][nixos/cuda] ([Official NixOS Wiki][nixos])

## Troubleshooting

- [How would i set a cursor on NixOS using Home Manager?][how-set-cursor-on-nixos-home-manager]

```nix
home.pointerCursor = {
  gtk.enable = true;
  x11.enable = true;
  package = pkgs.vanilla-dmz;
  name = "Vanilla-DMZ";
  size = 28;
};
```

Verify:

```shell
env | grep -i cursor
```

Expected:

```text
XCURSOR_PATH=/home/tarci/.nix-profile/share/icons:/home/tarci/.icons:/home/tarci/.local/share/icons:/home/tarci/.nix-profile/share/icons:/home/tarci/.nix-profile/share/pixmaps:/nix/profile/share/icons:/nix/profile/share/pixmaps:/home/tarci/.local/state/nix/profile/share/icons:/home/tarci/.local/state/nix/profile/share/pixmaps:/etc/profiles/per-user/tarci/share/icons:/etc/profiles/per-user/tarci/share/pixmaps:/nix/var/nix/profiles/default/share/icons:/nix/var/nix/profiles/default/share/pixmaps:/run/current-system/sw/share/icons:/run/current-system/sw/share/pixmaps
XCURSOR_SIZE=28
XCURSOR_THEME=Vanilla-DMZ
```

[cachix]: https://www.cachix.org/
[ehllie/dotfiles]: https://github.com/ehllie/dotfiles
[home manger]: https://github.com/nix-community/home-manager
[how-set-cursor-on-nixos-home-manager]: https://www.reddit.com/r/hyprland/s/y1e6uGyMPG
[nixos]: https://wiki.nixos.org/wiki/NixOS_Wiki
[nixos-wsl]: https://github.com/nix-community/NixOS-WSL
[nixos/cuda]: https://wiki.nixos.org/wiki/CUDA
[nixos/nvidia]: https://wiki.nixos.org/wiki/NVIDIA
[`ez-configs`]: https://github.com/ehllie/ez-configs
[`flake-parts`]: https://flake.parts
