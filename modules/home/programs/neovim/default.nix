{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.vim.enable = true;

  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  # store paths the lua config needs: qmlls' import paths (lua/lsp.lua)
  home.file.".config/nvim/lua/nix.lua".text = ''
    return {
      qmlImportPaths = {
        "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml",
        "${pkgs.quickshell}/lib/qt-6/qml",
      },
    }
  '';
}
