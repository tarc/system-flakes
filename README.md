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
deleting '/nix/store/gx78n9g226hcbw65rr02a2x8wxmfwvmm-rust_half-2.7.1'
deleting '/nix/store/hyp5rxndlip8wv8zx0sglm9lyszxwnga-config-install-wrapper.drv'
deleting '/nix/store/ga25hcbl2ffkbjgjf1c0945p5w8a0lyr-rust_clap_lex-1.1.0'
deleting '/nix/store/kj942d8daa4gix45m69jk0b39143rgfd-rust_convert_case-0.10.0'
deleting '/nix/store/4p3kbm4bjmfqcmpnrczlp0bxvs0w58xw-rust_potential_utf-0.1.5'
deleting '/nix/store/c97ni9hbdvc2m6m35l85977p6wzslfz8-rust_notify-types-2.1.0'
deleting '/nix/store/27igdgy5x1rw35bcmg00n4yd1mz4pn7a-rust_ref-cast-impl-1.0.25'
deleting unused links...
note: hard linking is currently saving 23.4 GiB
1330 store paths deleted, 5.3 GiB freed
```
<!-- END mdsh -->

```sh > text $
sudo nix-collect-garbage --delete-old 2>&1 | tail -n 10
```

<!-- BEGIN mdsh -->
```text
deleting '/nix/store/66vhr92pkz20pmzih3dpnzr0mfn4c1pf-nixos-configuration-reference-manpage.drv'
deleting '/nix/store/ivabyvcwqzy9i132vsk111kfadf3sac2-options.json.drv'
deleting '/nix/store/587nli4l03pba7yxylz3k6zv8bd5kx3k-issue'
deleting '/nix/store/0bza673imxv62raxzyswksfb86jakzx9-issue.drv'
deleting '/nix/store/ywhvkv3bzb973m7ii2c2cs8mrjjb0yb8-nixos-version'
deleting '/nix/store/50q45qj8476ib1mm06bv7c07k4xaxmkd-boot.json.drv'
deleting '/nix/store/9r7h785fwrw3i3dfmfqmn5w2iakqypy3-nixos-version.drv'
deleting unused links...
note: hard linking is currently saving 23.4 GiB
51 store paths deleted, 42.5 MiB freed
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
