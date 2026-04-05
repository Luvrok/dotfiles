{ pkgs, ... }:

{
  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      # --- icons ---
      adwaita-icon-theme
      gtk-engine-murrine
      vimix-gtk-themes
      material-icons
      material-design-icons

      # --- fonts ---
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      fira-code-symbols
      jetbrains-mono
      font-awesome_6
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.dejavu-sans-mono
    ];
  };
}
