{ ... }:

{
  imports = [
    ../../nixos/config/barnard.nix
  ];

  environment.sessionVariables = {
    XFT_DPI = "109";
    XCURSOR_THEME = "Vanilla-DMZ";
    XCURSOR_SIZE = "32";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.extraInit = ''
    #Turn off gui for ssh auth
    unset -v SSH_ASKPASS
  '';

  # Issue: kernel panic "BUG at mm/vmalloc.c:3167" occurring ~once a week since last year, sometimes more often.
  # Context: AMD + amdgpu with dual-monitor setup (both 120 Hz); may be related (see forum thread).
  # Mitigation: temporarily using motherboard display outputs to observe; consider pinning an older kernel (has other regressions). Best solution yet: pin the Linux 6.12 kernel.
  # Ref: https://bbs.archlinux.org/viewtopic.php?id=306587

  environment.etc."X11/xorg.conf.d/60-monitor.conf".text = ''
    Section "Monitor"
        Identifier "DisplayPort-0"
        Modeline "2560x1440R" 497.25 2560 2608 2640 2720 1440 1443 1448 1525 +hsync -vsync
        Option "PreferredMode" "2560x1440R"
        Option "Position" "0 0"
    EndSection

    Section "Monitor"
        Identifier "DisplayPort-1"
        Modeline "2560x1440R" 497.25 2560 2608 2640 2720 1440 1443 1448 1525 +hsync -vsync
        Option "PreferredMode" "2560x1440R"
        Option "Position" "2560 0"
        Option "Primary" "true"
    EndSection
  '';
}
