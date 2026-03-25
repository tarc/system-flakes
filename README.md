# system-flakes - [NixOS-WSL]/[Home Manger] configuration

This is based on the [`flake-parts`]' [`ez-configs`] module, with binary caching supported by [Cachix].

[NixOS-WSL]: https://github.com/nix-community/NixOS-WSL
[Home Manger]: https://github.com/nix-community/home-manager
[`flake-parts`]: https://flake.parts
[`ez-configs`]: https://github.com/ehllie/ez-configs
[Cachix]: https://www.cachix.org/


## Custom commands

To push a specific version of the flake inputs to the cache, run this command on the root of a local checkout of this repository:

```shell
flake-archive | cachix-cache push
```
