{
  ...
}:
(final: prev: {
  devenv = prev.writeShellApplication {
    name = "devenv";

    runtimeInputs = with prev; [ devenv ];

    text = ''
      devenv --override-input devenv 'github:tarc/devenv/feature/conan-flake-2.1.2' "$@"
    '';
  };
})
