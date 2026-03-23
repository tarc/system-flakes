{ pkgs, ... }:
{
  home.packages = with pkgs; [
    git
    git-credential-manager
  ];

  programs.git = {
    enable = true;

    ignores = [
      ".*.swp"
      ".DS_Store"
    ];

    settings = {
      alias = {
        f = "fetch --all -p";
        di = "diff --ignore-all-space";
        dc = "di --cached";
        fix = "commit --amend --no-edit";
        st = "status -s";
        br = "branch -a";
        ll = "log --graph --pretty=format:'%C(yellow)%h %ad%Cred%d %Creset%+s%Cblue [%cn]' --decorate --numstat --date=short";
      };

      commit.verbose = true;
      fetch.prune = true;
      http.sslVerify = true;

      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
      };
      push = {
        default = "simple";
      };
      color = {
        ui = "auto";
      };
    };

    signing.format = null;
    lfs.enable = true;
  };

  programs.delta = {
    enable = false;
    options = {
      side-by-side = true;
      line-numbers = true;
    };
  };

  programs.difftastic.enable = true;
  programs.difftastic.git.enable = true;
}
