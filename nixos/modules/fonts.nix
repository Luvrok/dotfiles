{ pkgs, ... }:

{
  fonts = {
    enableDefaultPackages = true;
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
      sarasa-gothic
      noto-fonts-cjk-sans
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.hack
      nerd-fonts.roboto-mono
      nerd-fonts.droid-sans-mono
      nerd-fonts.ubuntu
      nerd-fonts.iosevka
      nerd-fonts.meslo-lg
      nerd-fonts.victor-mono
    ];
  };
}
