# Overlay with own builds (suckless forks from flake inputs) and small wrappers.
inputs: final: prev: {
  dwm = final.callPackage ./dwm {
    inherit (prev) dwm;
    src = inputs.dwm;
  };
  st = final.callPackage ./st {
    inherit (prev) st;
    src = inputs.st;
  };
  slock = final.callPackage ./slock {
    inherit (prev) slock;
    src = inputs.slock;
  };
  dwmblocks = final.callPackage ./dwmblocks {
    inherit (prev) dwmblocks;
    src = inputs.dwmblocks;
  };
  dmenu = final.callPackage ./dmenu {
    inherit (prev) dmenu;
    src = inputs.dmenu;
  };

  ssh-term-fix = final.callPackage ./extraShell.nix { };
}
