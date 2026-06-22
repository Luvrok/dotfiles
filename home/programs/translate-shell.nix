{ ... }:

{
  programs.translate-shell = {
    enable = true;
    settings = {
      verbose = false;
      engine = "google";
      target = "ru";
      "no-auto" = true;
      "no-ansi" = true;
      "show-original" = false;
    };
  };
}
