# system-flakes - [NixOS-WSL]/[Home Manger] configuration

This is based on the [`flake-parts`]' [`ez-configs`] module, with binary caching supported by [Cachix].

## Custom commands

To push a specific version of the flake inputs to the cache, run this command on the root of a local checkout of this repository:

```shell
flake-archive | cachix-cache push
```

[cachix]: https://www.cachix.org/
[home manger]: https://github.com/nix-community/home-manager
[nixos-wsl]: https://github.com/nix-community/NixOS-WSL
[`ez-configs`]: https://github.com/ehllie/ez-configs
[`flake-parts`]: https://flake.parts
