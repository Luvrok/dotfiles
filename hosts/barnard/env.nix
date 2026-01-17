{ config, pkgs, lib, ... }:

{
  imports = [
    ../../nixos/config/barnard.nix
  ];

  environment.sessionVariables = {
    XFT_DPI = "112";
    XCURSOR_THEME = "Vanilla-DMZ";
    XCURSOR_SIZE = "32";
  };

  environment.extraInit = ''
    #Turn off gui for ssh auth
    unset -v SSH_ASKPASS
  '';

  # Issue: kernel panic "BUG at mm/vmalloc.c:3167" reproduced 4–5 times (2025-09-15 → 2025-09-17).
  # Context: AMD + amdgpu with dual-monitor setup; may be related (see forum thread).
  # Mitigation: temporarily using motherboard display outputs to observe; consider pinning an older kernel (has other regressions). No good solution found yet.
  # Ref: https://bbs.archlinux.org/viewtopic.php?id=306587

  environment.etc."X11/xorg.conf.d/60-monitor.conf".text = ''
    Section "Monitor"
      Identifier "HDMI-A-1"
      Modeline "2560x1440R"  497.25  2560 2608 2640 2720  1440 1443 1448 1525 +hsync -vsync
      Option "PreferredMode" "2560x1440R"
      Option "Position" "0 0"
      Option "Primary" "true"
    EndSection
  '';
}
