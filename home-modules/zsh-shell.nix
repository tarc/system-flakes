{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.home) username;

  aliases = rec {
    ls = "${pkgs.coreutils-full}/bin/ls --color=auto -h";
    la = "${ls} -a";
    ll = "${ls} -la";
    lt = "${ls} -latr";
    dush = "${pkgs.coreutils-full}/bin/du -sh */ | ${pkgs.coreutils-full}/bin/sort -h";
  };

  mkPath = path: ''
    case ":$PATH:" in
      *:"${path}":*)
        ;;
      *)
        export PATH="${path}:$PATH"
        ;;
    esac
  '';

  commonVariables = {
    GPG_TTY = "/dev/ttys000";
    DEFAULT_USER = "${username}";
    CLICOLOR = 1;
    TERM = "xterm-256color";
    DISABLE_MAGIC_FUNCTIONS = (toString true);
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
    GALLIUM_DRIVER = "d3d12";
  };
in
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    options = [
      "--hook pwd"
    ];
  };

  programs.fzf =
    let
      fd = lib.getExe pkgs.fd;
    in
    rec {
      enable = true;
      defaultCommand = "${fd} -H --type f";
      defaultOptions = [ "--height 50%" ];
      fileWidget = {
        command = "${defaultCommand}";
        options = [
          "--preview '${lib.getExe pkgs.bat} --color=always --plain --line-range=:200 {}'"
        ];
      };
      changeDirWidget = {
        command = "${fd} -H --type d";
        options = [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
      };
      historyWidget.options = [ ];
    };

  programs.zsh =
    let
      mkZshPlugin =
        {
          pkg,
          file ? "${pkg.pname}.plugin.zsh",
        }:
        {
          name = pkg.pname;
          src = pkg.src;
          inherit file;
        };
    in
    {
      # zsh
      enable = true;
      autocd = true;
      dotDir = "${config.xdg.configHome}/zsh";
      sessionVariables = commonVariables // { };
      shellAliases = aliases;
      initContent = ''
        ${mkPath "$HOME/.local/bin"}
        unset RPS1
      '';
      plugins = with pkgs; [
        # (mkZshPlugin { pkg = zsh-autopair; })
        (mkZshPlugin { pkg = zsh-completions; })
        (mkZshPlugin { pkg = zsh-autosuggestions; })
        (mkZshPlugin {
          pkg = zsh-fast-syntax-highlighting;
          file = "fast-syntax-highlighting.plugin.zsh";
        })
        (mkZshPlugin { pkg = zsh-history-substring-search; })
      ];
      oh-my-zsh = {
        enable = true;
        plugins = [ "sudo" ];
      };
    };
}
