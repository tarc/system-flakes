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
deleting '/nix/store/jkhrym497h1iz0lchaaali64l13cnax3-fhsenv-ensure-gsettings-schemas-directory'
deleting '/nix/store/3vvvgxggqj0rbvjk46y1n9xg8nbpzk2m-glib-2.88.1-bin'
deleting '/nix/store/59i3w5yw4bsvj9cb0hx2lpndlyyc8n6s-python3.14-mccabe-0.7.0'
deleting '/nix/store/xwhfbyyfxxkflkbfql877lm3hy3jsz3g-matplotlib-3.11.0.tar.gz.drv'
deleting '/nix/store/lx6fmhlq0p4g2wqzc48n8cgynn0radlv-fonts.conf'
deleting '/nix/store/yy2gr1nxnb6vvrnw7hv66fi07sa96b51-clap_builder-4.6.0'
deleting '/nix/store/k4hpbh3jfip9zvwmsx35l7q2bzr55g8z-systemd-journal-logger-2.2.2'
deleting unused links...
note: hard linking is currently saving 20.5 GiB
650 store paths deleted, 11.5 GiB freed
```
<!-- END mdsh -->

```sh > text $
sudo nix-collect-garbage --delete-old 2>&1 | tail -n 10
```

<!-- BEGIN mdsh -->
```text
deleting '/nix/store/c8s6b99xdkr7n0ic7jd10dm58lca953b-options.json.drv'
deleting '/nix/store/q75vrf0spilic2l8r9ric7kwg58k3daa-kservice-6.27.0.tar.xz.drv'
deleting '/nix/store/fm645zx9wmqaqky2qgvkq0m1nh1p60w6-baloo-6.27.0.tar.xz.drv'
deleting '/nix/store/xd6ivw04hlv12m7jad1raq87k1h39pjk-kidletime-6.27.0.tar.xz.drv'
deleting '/nix/store/qmny5k3dx6ggq686bdj8x78nkjw43kq6-attica-6.27.0.tar.xz.drv'
deleting '/nix/store/8bq5sr4ryqp8l6dlfbj1wmfn9hfs67vm-kdeclarative-6.27.0.tar.xz.drv'
deleting '/nix/store/5p83hw9s7alcsn6gr2la2lblm19wj2f1-nixos-render-docs-0.0.drv'
deleting unused links...
note: hard linking is currently saving 20.4 GiB
303 store paths deleted, 1.3 GiB freed
```
<!-- END mdsh -->

### `nix fmt`

Calls the flake default formatter.

> [!WARNING]
> This will run commands embedded in markdown.

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
