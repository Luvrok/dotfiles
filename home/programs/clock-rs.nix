{ ... }:

{
  programs.clock-rs = {
    enable = true;

    settings = {
      general = {
        color = "#d65d0e";
        interval = 250;
        blink = false;
        bold = true;
      };

      position = {
        horizontal = "center";
        vertical = "center";
      };
    };
  };
}
