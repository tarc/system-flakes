When devenv.nix doesn't exist and a command/tool is missing, create ad-hoc environment:

    $ devenv -O languages.rust.enable:bool true -O packages:pkgs "mypackage mypackage2" shell -- cli args

When the setup is becomes complex create `devenv.nix` and run commands within:

    $ devenv shell -- cli args

See https://devenv.sh/ad-hoc-developer-environments/

## System configuration is Nix-managed

Never edit, or suggest editing, `~/.zshrc`, `~/.config/*`, or any other system/user configuration file directly. They are home-manager/NixOS symlinks into the read-only Nix store. The configuration is versioned in `~/projects/system-flakes/` (home-manager modules in `home-modules/`). When a config change is needed, first check whether system-flakes already handles it (e.g. `programs.devenv.enable` already installs devenv and its zsh hook); if not, propose the change as an edit to the relevant module there.

Exception: `~/.claude/CLAUDE.md` and `~/.claude/skills/{ci-local,gh-tracker,pr-stack,wsl-windows-rust}` are out-of-store links (`mkOutOfStoreSymlink`, from `home-modules/claude-code.nix`) into `~/projects/system-flakes/home-modules/claude/`. Although `readlink` shows a `/nix/store` hop, they resolve to the working copy: edit them in place, and the edits become uncommitted changes in system-flakes. Adding, removing or renaming one needs an edit to `home-modules/claude-code.nix` and a `just switch`. A new skill (e.g. from skill-creator) starts as an ordinary directory in `~/.claude/skills/`; move it into the repo and add it to the module if it should be versioned. Everything else in `~/.claude` (`settings.json`, `rules/`, `scripts/`, `footprint.md`, GSD files, runtime state) stays unmanaged and is edited as usual.

## Footprint: build artifacts and Nix GC roots

Keep `~/.claude/footprint.md` current. It's the ledger of everything you create outside tracked files that is large or pins Nix store paths: Cargo `target/` dirs, Windows mirrors and their `target\`, cargo git checkouts, and above all every `.devenv/` or `.direnv/` or `result` link left by ad-hoc devenv/nix-direnv/nix build, since those are GC roots that stop `nix store gc`. Before starting an ad-hoc devenv shell, run it from a directory you will record, never a repo root or a random cwd. Add the entry when you create it; when the user asks to clean up, measure, remove from the ledger's commands, and confirm with `nix-store --gc --print-roots`. Don't remove anything on your own initiative: keep it until the work is done, the disk is filling up, or the user needs the space. In those cases, bring it up and propose what to remove.

On this machine (WSL2), the whole Linux filesystem lives in one virtual disk on C: (`C:\Users\tarci\AppData\Local\wsl\{7527fb51-…}\ext4.vhdx`, already sparse: space freed in Linux returns to C: on its own, with a lag of minutes; Explorer needs F5 and `df` may lag too, so re-check before concluding nothing was freed), and C: is the drive that fills up. Linux `df` can show plenty free while C: is full: check `df -h /mnt/c` too. Large Rust builds (a full gpui-ce test build is ~80 GB) grow that file, so delete check builds (`target/ci-local`) as soon as a PR check is done.

## Tool usage notes

- GitHub auth: always use `$GITHUB_TOKEN` (a classic token), never the interactive login. The global `credential.helper` is Git Credential Manager (`manager`), which opens a login window and stalls the command. For `gh`, prefix `GH_TOKEN=$GITHUB_TOKEN`. For `git push`/`fetch` over HTTPS, bypass GCM per command:

      GH_TOKEN=$GITHUB_TOKEN GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push ...

- Never pipe `git push` (or `fetch`/`pull`) through `tail`, `head` or `grep`: the pipeline's exit status becomes the last command's, so a failed push reports success. It happened in gsd-core while GitHub's API and SSH were unreachable and the rest of the internet was up. Run the push bare and check its exit code, then confirm with `git ls-remote origin <branch>`.

- Never call `ScheduleWakeup` to wait on a `Bash(run_in_background: true)` command or other harness-tracked async work (e.g. a Monitor-tracked process). Just end the turn — the harness re-invokes automatically on completion. This is a recurring slip across projects (system-flakes `/update-devenv`, `/upgrade-system`) despite `ScheduleWakeup`'s own tool description saying not to do this. Reserve `ScheduleWakeup` for `/loop` dynamic-pacing mode, or for actively polling *external* state the harness cannot observe (a CI run, a remote queue).

- `gh pr checks` prints a `cancelled` check as `fail`. `cancel-in-progress` concurrency cancels superseded runs on every new push and on PR `edited` events, so several "failures" completing in the same second are usually supersession. Read `conclusion` from `gh api repos/<owner>/<repo>/commits/<sha>/check-runs` before reporting red.

- `yq` (mikefarah yq-go, v4.53 tested) is not jq: a string literal after a filter that emitted nothing still emits (`[select(false) | "x"] | length` is 1, not 0), so `(cond | select(.) | "a") // "b"` always yields `"a"`; and `if … then … else … end` is a lexer error. Apply `//` only to real paths (`.run // "x"`), and do conditional logic outside yq (awk, shell).

- In Bash tool commands, `\\` is collapsed to `\` — even inside a quoted `<<'EOF'` heredoc, where bash itself would keep it. Lone backslashes survive, so a doubled backslash in a regex or escape is silently halved. Write content containing `\\` with the Write tool, not a heredoc or `echo`.

## Verify before asserting

- Before stating that something can't work, is missing, has no owner, or behaves a certain way ("it aborts", "it retries", "it caches"), run the one command that would disprove it — above all when the claim is load-bearing or about to be posted publicly. Plausible reasoning has repeatedly produced confident, wrong conclusions. A normalisation ("A tracks B") is a claim too: check it against like-for-like data.
