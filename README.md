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
deleting '/nix/store/dl0999vzig90cv7n5v9xjcsyzxickj6j-notify-8.2.0'
deleting '/nix/store/8wqfkrkl0hmf08l3px15r7lps4nkddih-python3.14-charset-normalizer-3.5.1'
deleting '/nix/store/nx7bncf095avdxaqwdin6qgb5d61qkq0-setuptools-rust-hook.sh.drv'
deleting '/nix/store/c2q3c32db38c3fpyynv4y9mnybaj5nj0-unicode-script-0.5.8'
deleting '/nix/store/d3p6hkbfvd9ylk3gd7lhp0pvdngz6vh4-wayland-cursor-0.31.14'
deleting '/nix/store/papxwgajjqb60yf5k036j0bgjxp1zdsf-shuttle-0.8.1'
deleting '/nix/store/rhgz9j8szbpknzzjd87nsjxbfrahq5zx-object-0.37.3'
deleting unused links...
note: hard linking is currently saving 11.7 GiB
2418 store paths deleted, 9.2 GiB freed
```
<!-- END mdsh -->

```sh > text $
sudo nix-collect-garbage --delete-old 2>&1 | tail -n 10
```

<!-- BEGIN mdsh -->
```text
deleting '/nix/store/n19r6nhrn58xzm90lm5vp8kcmcnnjbfv-ktextwidgets-6.31.0.tar.xz.drv'
deleting '/nix/store/3812b3l4kvmgd5fggi4xsknhm7k7pja7-karchive-6.31.0.tar.xz.drv'
deleting '/nix/store/71xywbmqn75m4ikx2s25vd6wllfn6z8g-kconfig-6.31.0.tar.xz.drv'
deleting '/nix/store/6r9kkvpc0mg15wl8jxmkr9klm1pdi0lf-kjobwidgets-6.31.0.tar.xz.drv'
deleting '/nix/store/9w7g2mgwcx3yf4ma77ay533q8l878xrm-unit-gcr-ssh-agent.socket.drv'
deleting '/nix/store/krbqqk8ajv2qg7yq0dgpq4hn83bjbqg7-qtconnectivity-6.12.0.drv'
deleting '/nix/store/r1jih6w2m4hj9qlm02zq44q62ymmlspr-nixos-version.drv'
deleting unused links...
note: hard linking is currently saving 10.9 GiB
518 store paths deleted, 2.6 GiB freed
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
