{
  config,
  lib,
  ...
}:
let
  # Out-of-store links into the working copy, not store copies: Claude Code and
  # the skills edit these files at runtime (notes.json, stack.json, CLAUDE.md).
  # Must be an absolute string; a path literal would point into the flake's
  # read-only store copy.
  repo = "${config.home.homeDirectory}/projects/system-flakes/home-modules/claude";
  link = path: { source = config.lib.file.mkOutOfStoreSymlink "${repo}/${path}"; };

  # Only these skills are managed; gsd-* and synced/ in ~/.claude/skills are
  # installed by their own tools and must stay untouched.
  skills = [
    "ci-local"
    "gh-tracker"
    "pr-stack"
    "wsl-windows-rust"
  ];
in
{
  home.file = {
    ".claude/CLAUDE.md" = link "CLAUDE.md";
  }
  // lib.genAttrs (map (s: ".claude/skills/${s}") skills) (
    name: link (lib.removePrefix ".claude/" name)
  );
}
