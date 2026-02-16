{ ... }:

{
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard"; # use Ctrl+C and Ctrl+V for copy & paste
    };
  };
}
