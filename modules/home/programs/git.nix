{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.git;
    settings = {
      user.email = "pawel.2020.navtop@gmail.com";
      user.name = "Luvrok";
      init.defaultBranch = "master";
    };
  };

  home.packages = with pkgs; [
    gh
    git-crypt
  ];
}
