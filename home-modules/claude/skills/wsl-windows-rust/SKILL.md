---
name: wsl-windows-rust
description: Build, check, test or run Rust natively on Windows (MSVC toolchain) from this WSL2 machine. Use whenever code has Windows-only paths (#[cfg(windows)], target_os = "windows") that a Linux build never compiles, when a GPUI/DirectX app must be built for Windows (it can't be cross-compiled), or when the user asks to verify something "on Windows".
---

# Native Windows Rust builds from WSL2

This machine is WSL2 (NixOS) on Windows 11. Windows has its own toolchain, so nothing needs to be installed:

- rustup and cargo at `C:\Users\tarci\.cargo\bin`, with `stable-x86_64-pc-windows-msvc` as the default (only the msvc target is installed). A `rust-toolchain.toml` in the copy is honored.
- Visual Studio Community 2022 with the VC x86/x64 tools. `cl.exe` isn't on PATH, and doesn't need to be: rustc finds the MSVC linker through the VS installer. No vcvars needed.

## How

Never build from `\\wsl.localhost\...`: it is slow and has file-locking problems. Mirror the checkout to a Windows-local copy and run cargo there:

```sh
~/.claude/skills/wsl-windows-rust/scripts/win-run.sh -- cargo check --workspace
~/.claude/skills/wsl-windows-rust/scripts/win-run.sh -- cargo test -p mycrate --lib
```

- The copy defaults to `%USERPROFILE%\Projects\<repo name>`. `--tree /mnt/c/...` picks another, and `--print-tree` shows where it is.
- Mirroring is `robocopy /MIR`, which skips `.git target .claude .devenv .direnv node_modules result`. `target/` therefore lives only on the Windows side and stays warm between runs. The mirror deletes Windows-only files in the copy that aren't in the source, apart from the skipped directories.
- The command runs in PowerShell in the copy, and its exit code is passed through. Quote PowerShell syntax as one argument when needed.
- Run long builds in the background (`run_in_background`). A first GPUI build on Windows takes several minutes.
- Windows locks running `.exe` files, so stop a running binary before rebuilding it.
- Extra cargo config that shouldn't be committed (for example a `[patch.crates-io]` pointing at a git revision): write the TOML into the Windows copy *after* mirroring, outside any mirrored path that could be deleted, such as `<copy>\target\local-patch.toml` (target is never mirrored). Then pass `--config target\local-patch.toml`. On the next run use `--no-mirror`, or rewrite the file after mirroring.

## When not to use it

- Plain crates that need no Windows SDK tools can be cross-compiled from WSL with `cargo xwin build --target x86_64-pc-windows-msvc` (available through devenv). GPUI apps can't, because the DirectX renderer needs Windows' shader compiler.
- macOS can't be built from this machine. Say so instead of claiming a macOS check.

Origin: generalized from `~/projects/factorseal/scripts/windows-desktop-check/build-windows.sh`, which adds FactorSeal-specific release builds and desktop checks on top.

## Footprint

Every mirror (`%USERPROFILE%\Projects\<repo>`) grows a Windows-side `target\` of several GB, and git dependencies land in `C:\Users\tarci\.cargo\git\checkouts`. Record each new mirror in `~/.claude/footprint.md`. To remove one: `rm -rf /mnt/c/Users/tarci/Projects/<repo>/target`, or the whole mirror.
